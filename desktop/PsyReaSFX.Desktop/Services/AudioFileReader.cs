using System.Buffers.Binary;

namespace PsyReaSFX.Desktop.Services;

public readonly record struct AudioInfo(double Duration, int Channels, int SampleRate, int BitDepth,
    long DataOffset, long DataLength, int BlockAlign, ushort FormatTag);

public static class AudioFileReader
{
    public static readonly HashSet<string> SupportedExtensions = new(StringComparer.OrdinalIgnoreCase)
    { ".wav", ".wave", ".aif", ".aiff", ".flac", ".mp3", ".ogg", ".opus", ".wv", ".m4a" };

    public static AudioInfo ReadInfo(string path)
    {
        if (!Path.GetExtension(path).Equals(".wav", StringComparison.OrdinalIgnoreCase) &&
            !Path.GetExtension(path).Equals(".wave", StringComparison.OrdinalIgnoreCase))
            return default;

        using var stream = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
        using var reader = new BinaryReader(stream);
        if (new string(reader.ReadChars(4)) != "RIFF") return default;
        _ = reader.ReadUInt32();
        if (new string(reader.ReadChars(4)) != "WAVE") return default;

        ushort format = 0;
        int channels = 0, rate = 0, bits = 0, blockAlign = 0;
        long dataOffset = 0, dataLength = 0;
        while (stream.Position + 8 <= stream.Length)
        {
            var id = new string(reader.ReadChars(4));
            var size = reader.ReadUInt32();
            var next = Math.Min(stream.Length, stream.Position + size + (size & 1));
            if (id == "fmt " && size >= 16)
            {
                format = reader.ReadUInt16();
                channels = reader.ReadUInt16();
                rate = reader.ReadInt32();
                _ = reader.ReadInt32();
                blockAlign = reader.ReadUInt16();
                bits = reader.ReadUInt16();
                if (format == 0xFFFE && size >= 40)
                {
                    stream.Position += 8;
                    var subFormat = reader.ReadBytes(16);
                    if (subFormat.Length >= 2) format = BinaryPrimitives.ReadUInt16LittleEndian(subFormat);
                }
            }
            else if (id == "data")
            {
                dataOffset = stream.Position;
                dataLength = size;
            }
            stream.Position = next;
            if (dataOffset > 0 && format > 0) break;
        }

        var duration = rate > 0 && blockAlign > 0 ? dataLength / (double)(rate * blockAlign) : 0;
        return new AudioInfo(duration, channels, rate, bits, dataOffset, dataLength, blockAlign, format);
    }

    public static float[][] ReadWaveform(string path, int buckets)
    {
        if (LuaWaveCache.TryRead(path, buckets, buckets > 512, out var cached)) return cached;
        var info = ReadInfo(path);
        if (info.DataOffset <= 0 || info.Channels <= 0 || info.BlockAlign <= 0 || buckets <= 0)
            return [];

        var bytesPerSample = Math.Max(1, info.BitDepth / 8);
        var frameCount = Math.Max(0L, info.DataLength / info.BlockAlign);
        if (frameCount == 0) return [];
        var step = Math.Max(1L, frameCount / buckets);
        // Result-list thumbnails must never read an entire source file. A large library can
        // otherwise turn a short scroll into gigabytes of I/O and allocations. Sample a small,
        // representative window from each bucket and aggregate its channels, matching the Lua
        // result list. The detailed selected waveform keeps independent channels below.
        if (buckets <= 512)
        {
            var thumbnail = new[] { new float[buckets] };
            SampleThumbnail(path, info, frameCount, thumbnail);
            LuaWaveCache.TryWrite(path, buckets, false, thumbnail);
            return thumbnail;
        }

        var result = Enumerable.Range(0, info.Channels).Select(_ => new float[buckets]).ToArray();

        // Most sound-effect files are small enough to sample from one sequential read.
        // This removes tens of thousands of tiny seek/read calls per visible list row,
        // which was the main reason thumbnails appeared blank for several seconds.
        const long memoryReadLimit = 32L * 1024 * 1024;
        if (info.DataLength <= memoryReadLimit && info.DataLength <= int.MaxValue)
        {
            using var stream = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            stream.Position = info.DataOffset;
            var audio = new byte[(int)info.DataLength];
            stream.ReadExactly(audio);
            SampleBuffer(audio, info, frameCount, step, result);
            LuaWaveCache.TryWrite(path, buckets, true, result);
            return result;
        }

        using var largeStream = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
        var frame = new byte[info.BlockAlign];

        for (var bucket = 0; bucket < buckets; bucket++)
        {
            var start = bucket * step;
            var end = bucket == buckets - 1 ? frameCount : Math.Min(frameCount, start + step);
            var sampleStride = Math.Max(1L, (end - start) / 48);
            for (var index = start; index < end; index += sampleStride)
            {
                largeStream.Position = info.DataOffset + index * info.BlockAlign;
                if (largeStream.Read(frame, 0, frame.Length) != frame.Length) break;
                for (var channel = 0; channel < info.Channels; channel++)
                {
                    var offset = channel * bytesPerSample;
                    if (offset + bytesPerSample > frame.Length) continue;
                    var amplitude = DecodeSample(frame.AsSpan(offset, bytesPerSample), info.FormatTag, info.BitDepth);
                    var target = result.Length == 1 ? 0 : channel;
                    result[target][bucket] = Math.Max(result[target][bucket], Math.Abs(amplitude));
                }
            }
        }
        LuaWaveCache.TryWrite(path, buckets, true, result);
        return result;
    }

    private static void SampleThumbnail(string path, AudioInfo info, long frameCount, float[][] result)
    {
        var bytesPerSample = Math.Max(1, info.BitDepth / 8);
        var buckets = result[0].Length;
        var framesPerBucket = Math.Max(1L, frameCount / buckets);
        var framesToRead = (int)Math.Clamp(framesPerBucket, 8, 96);
        var buffer = new byte[checked(framesToRead * info.BlockAlign)];
        using var stream = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
        for (var bucket = 0; bucket < buckets; bucket++)
        {
            var bucketStart = bucket * framesPerBucket;
            var startFrame = Math.Min(Math.Max(0, frameCount - framesToRead),
                bucketStart + Math.Max(0, (framesPerBucket - framesToRead) / 2));
            stream.Position = info.DataOffset + startFrame * info.BlockAlign;
            var requested = Math.Min(buffer.Length, (int)Math.Min(int.MaxValue,
                Math.Max(0, info.DataOffset + info.DataLength - stream.Position)));
            var read = stream.Read(buffer, 0, requested);
            var readFrames = read / info.BlockAlign;
            for (var frame = 0; frame < readFrames; frame++)
            {
                var frameOffset = frame * info.BlockAlign;
                for (var channel = 0; channel < info.Channels; channel++)
                {
                    var offset = frameOffset + channel * bytesPerSample;
                    if (offset + bytesPerSample > read) continue;
                    var amplitude = DecodeSample(buffer.AsSpan(offset, bytesPerSample), info.FormatTag, info.BitDepth);
                    var target = result.Length == 1 ? 0 : channel;
                    result[target][bucket] = Math.Max(result[target][bucket], Math.Abs(amplitude));
                }
            }
        }
    }

    private static void SampleBuffer(byte[] audio, AudioInfo info, long frameCount, long step, float[][] result)
    {
        var bytesPerSample = Math.Max(1, info.BitDepth / 8);
        for (var bucket = 0; bucket < result[0].Length; bucket++)
        {
            var start = bucket * step;
            var end = bucket == result[0].Length - 1 ? frameCount : Math.Min(frameCount, start + step);
            var sampleStride = Math.Max(1L, (end - start) / 64);
            for (var index = start; index < end; index += sampleStride)
            {
                var frameOffset = checked((int)(index * info.BlockAlign));
                for (var channel = 0; channel < info.Channels; channel++)
                {
                    var offset = frameOffset + channel * bytesPerSample;
                    if (offset < 0 || offset + bytesPerSample > audio.Length) continue;
                    var amplitude = DecodeSample(audio.AsSpan(offset, bytesPerSample), info.FormatTag, info.BitDepth);
                    result[channel][bucket] = Math.Max(result[channel][bucket], Math.Abs(amplitude));
                }
            }
        }
    }

    private static float DecodeSample(ReadOnlySpan<byte> data, ushort format, int bits)
    {
        if (format == 3 && bits == 32 && data.Length >= 4)
            return Math.Clamp(BitConverter.ToSingle(data), -1f, 1f);
        if (format != 1) return 0;
        return bits switch
        {
            8 when data.Length >= 1 => (data[0] - 128) / 128f,
            16 when data.Length >= 2 => BinaryPrimitives.ReadInt16LittleEndian(data) / 32768f,
            24 when data.Length >= 3 => Decode24(data) / 8388608f,
            32 when data.Length >= 4 => BinaryPrimitives.ReadInt32LittleEndian(data) / 2147483648f,
            _ => 0
        };
    }

    private static int Decode24(ReadOnlySpan<byte> data)
    {
        var value = data[0] | (data[1] << 8) | (data[2] << 16);
        if ((value & 0x800000) != 0) value |= unchecked((int)0xFF000000);
        return value;
    }
}
