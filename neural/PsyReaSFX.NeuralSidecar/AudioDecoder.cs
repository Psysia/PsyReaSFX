using System.Buffers.Binary;
using System.Diagnostics;
using System.Runtime.InteropServices;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;

namespace PsyReaSFX.NeuralSidecar;

internal readonly record struct DecodedAudio(
    float[] Samples,
    int SourceSampleRate,
    int SourceChannels,
    string Decoder);

internal static class AudioDecoder
{
    internal const int DecoderVersion = 1;
    private static readonly string[] WindowsExtensions =
    [
        "wav", "wave", "aif", "aiff", "flac", "mp3", "m4a",
    ];
    private static readonly string[] FfmpegExtensions =
    [
        "wav", "wave", "aif", "aiff", "flac", "mp3", "ogg", "opus", "wv", "caf", "m4a",
    ];

    private static readonly Lazy<string?> FfmpegPath = new(FindFfmpeg);

    internal static bool FfmpegAvailable => FfmpegPath.Value is not null;
    internal static string[] SupportedExtensions =>
        (FfmpegAvailable ? FfmpegExtensions : WindowsExtensions).ToArray();

    internal static DecodedAudio DecodeMono32k(string path)
    {
        var fullPath = Path.GetFullPath(path);
        Program.Require(File.Exists(fullPath), $"Audio file was not found: {fullPath}");
        var nativeErrors = new List<string>();
        foreach (var factory in ReaderFactories(fullPath))
        {
            try
            {
                return DecodeWithNAudio(factory);
            }
            catch (Exception error) when (IsDecodeFailure(error))
            {
                nativeErrors.Add(error.Message);
            }
        }

        if (FfmpegPath.Value is not null)
        {
            try
            {
                return DecodeWithFfmpeg(fullPath, FfmpegPath.Value);
            }
            catch (Exception ffmpegError)
            {
                throw new InvalidDataException(
                    $"Could not decode audio with Windows or FFmpeg. Windows: {string.Join(" | ", nativeErrors)}; "
                    + $"FFmpeg: {ffmpegError.Message}", ffmpegError);
            }
        }

        throw new InvalidDataException(
            $"Could not decode audio with the available Windows codecs: {string.Join(" | ", nativeErrors)}");
    }

    internal static object RunSelfTest()
    {
        var root = Path.Combine(Path.GetTempPath(), $"PsyReaSFX-audio-decoder-{Guid.NewGuid():N}");
        Directory.CreateDirectory(root);
        var cases = new List<object>();
        try
        {
            foreach (var fixture in new[]
            {
                new WaveFixture("pcm16-44100-mono.wav", 44_100, 1, WaveFixtureFormat.Pcm16),
                new WaveFixture("pcm24-48000-stereo.wav", 48_000, 2, WaveFixtureFormat.Pcm24),
                new WaveFixture("pcm32-96000-stereo.wav", 96_000, 2, WaveFixtureFormat.Pcm32),
                new WaveFixture("float32-48000-mono.wav", 48_000, 1, WaveFixtureFormat.Float32),
            })
            {
                var path = Path.Combine(root, fixture.Name);
                WriteWaveFixture(path, fixture.SampleRate, fixture.Channels, fixture.Format);
                var decoded = DecodeMono32k(path);
                var expected = Program.ExpectedSampleRate * 2;
                Program.Require(Math.Abs(decoded.Samples.Length - expected) <= 16,
                    $"Resampled length mismatch for {fixture.Name}: {decoded.Samples.Length}");
                Program.Require(decoded.Samples.All(float.IsFinite),
                    $"Decoder produced non-finite samples for {fixture.Name}.");
                var frequency = EstimateFrequency(decoded.Samples, Program.ExpectedSampleRate);
                Program.Require(Math.Abs(frequency - 440) < 3,
                    $"Resampled frequency mismatch for {fixture.Name}: {frequency:F3} Hz");
                cases.Add(new
                {
                    fixture.Name,
                    fixture.SampleRate,
                    fixture.Channels,
                    format = fixture.Format.ToString(),
                    outputSamples = decoded.Samples.Length,
                    frequency,
                    decoded.Decoder,
                });
            }
            return new
            {
                result = "passed",
                decoderVersion = DecoderVersion,
                ffmpegAvailable = FfmpegAvailable,
                cases,
            };
        }
        finally
        {
            try { Directory.Delete(root, true); } catch { }
        }
    }

    private static DecodedAudio DecodeWithNAudio(Func<WaveStream> factory)
    {
        using var reader = factory();
        var sourceRate = reader.WaveFormat.SampleRate;
        var sourceChannels = reader.WaveFormat.Channels;
        Program.Require(sourceRate > 0, "Audio sample rate is invalid.");
        Program.Require(sourceChannels > 0, "Audio channel count is invalid.");

        ISampleProvider provider = reader.ToSampleProvider();
        if (provider.WaveFormat.Channels != 1)
        {
            provider = new MonoMixSampleProvider(provider);
        }
        if (provider.WaveFormat.SampleRate != Program.ExpectedSampleRate)
        {
            provider = new WdlResamplingSampleProvider(provider, Program.ExpectedSampleRate);
        }

        var expectedSamples = reader.TotalTime.TotalSeconds > 0
            ? checked((long)Math.Ceiling(reader.TotalTime.TotalSeconds * Program.ExpectedSampleRate) + 32)
            : 0;
        Program.Require(expectedSamples <= int.MaxValue,
            "Decoded audio is too large for the current embedding pipeline.");
        var samples = ReadAll(provider, expectedSamples);
        Program.Require(samples.Length > 0, "The decoder returned no audio samples.");
        return new DecodedAudio(samples, sourceRate, sourceChannels,
            reader is WaveFileReader ? "naudio-wave"
            : reader is AiffFileReader ? "naudio-aiff"
            : "windows-media-foundation");
    }

    private static IEnumerable<Func<WaveStream>> ReaderFactories(string path)
    {
        switch (Path.GetExtension(path).ToLowerInvariant())
        {
            case ".wav":
            case ".wave":
                yield return () => new WaveFileReader(path);
                yield return () => new MediaFoundationReader(path);
                break;
            case ".aif":
            case ".aiff":
                yield return () => new AiffFileReader(path);
                yield return () => new MediaFoundationReader(path);
                break;
            default:
                yield return () => new MediaFoundationReader(path);
                break;
        }
    }

    private static bool IsDecodeFailure(Exception error) => error is InvalidDataException
        or NotSupportedException
        or ArgumentException
        or IOException
        or COMException;

    private static float[] ReadAll(ISampleProvider provider, long expectedSamples)
    {
        var initial = expectedSamples > 0 && expectedSamples <= int.MaxValue
            ? checked((int)expectedSamples)
            : 32_768;
        initial = Math.Max(Program.MinimumSamples, initial);
        var output = new float[initial];
        var buffer = new float[32_768];
        var count = 0;
        while (true)
        {
            var read = provider.Read(buffer, 0, buffer.Length);
            if (read <= 0) break;
            if (count > int.MaxValue - read)
            {
                throw new InvalidDataException("Decoded audio is too large for the current embedding pipeline.");
            }
            var required = count + read;
            if (required > output.Length)
            {
                var grown = Math.Max(required, checked(output.Length + Math.Max(output.Length / 2, 32_768)));
                Array.Resize(ref output, grown);
            }
            for (var index = 0; index < read; index++)
            {
                var sample = buffer[index];
                output[count + index] = float.IsFinite(sample) ? Math.Clamp(sample, -1f, 1f) : 0;
            }
            count += read;
        }
        Array.Resize(ref output, count);
        return output;
    }

    private static DecodedAudio DecodeWithFfmpeg(string path, string ffmpegPath)
    {
        var start = new ProcessStartInfo
        {
            FileName = ffmpegPath,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        };
        foreach (var argument in new[]
        {
            "-v", "error", "-nostdin", "-i", path, "-map_metadata", "-1", "-vn",
            "-ac", "1", "-ar", Program.ExpectedSampleRate.ToString(), "-f", "f32le", "pipe:1",
        })
        {
            start.ArgumentList.Add(argument);
        }

        using var process = Process.Start(start)
            ?? throw new InvalidOperationException("Could not start FFmpeg.");
        var errorTask = process.StandardError.ReadToEndAsync();
        using var output = new MemoryStream();
        process.StandardOutput.BaseStream.CopyTo(output);
        process.WaitForExit();
        var error = errorTask.GetAwaiter().GetResult().Trim();
        if (process.ExitCode != 0)
        {
            throw new InvalidDataException(string.IsNullOrWhiteSpace(error)
                ? $"FFmpeg exited with code {process.ExitCode}."
                : error);
        }
        var bytes = output.ToArray();
        Program.Require(bytes.Length % sizeof(float) == 0, "FFmpeg returned truncated float PCM.");
        var samples = new float[bytes.Length / sizeof(float)];
        for (var index = 0; index < samples.Length; index++)
        {
            var sample = BinaryPrimitives.ReadSingleLittleEndian(
                bytes.AsSpan(index * sizeof(float), sizeof(float)));
            samples[index] = float.IsFinite(sample) ? Math.Clamp(sample, -1f, 1f) : 0;
        }
        return new DecodedAudio(samples, 0, 0, "ffmpeg");
    }

    private static string? FindFfmpeg()
    {
        var explicitPath = Environment.GetEnvironmentVariable("PSYREASFX_FFMPEG");
        if (!string.IsNullOrWhiteSpace(explicitPath) && File.Exists(explicitPath))
        {
            return Path.GetFullPath(explicitPath);
        }
        var adjacent = Path.Combine(AppContext.BaseDirectory,
            OperatingSystem.IsWindows() ? "ffmpeg.exe" : "ffmpeg");
        if (File.Exists(adjacent)) return Path.GetFullPath(adjacent);
        foreach (var directory in (Environment.GetEnvironmentVariable("PATH") ?? "")
            .Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            try
            {
                var candidate = Path.Combine(directory, OperatingSystem.IsWindows() ? "ffmpeg.exe" : "ffmpeg");
                if (File.Exists(candidate)) return Path.GetFullPath(candidate);
            }
            catch { }
        }
        return null;
    }

    private static void WriteWaveFixture(
        string path,
        int sampleRate,
        int channels,
        WaveFixtureFormat format)
    {
        const int seconds = 2;
        var frames = checked(sampleRate * seconds);
        var bits = format == WaveFixtureFormat.Pcm16 ? 16
            : format == WaveFixtureFormat.Pcm24 ? 24 : 32;
        var bytesPerSample = bits / 8;
        var dataBytes = checked(frames * channels * bytesPerSample);
        using var stream = File.Create(path);
        using var writer = new BinaryWriter(stream);
        writer.Write("RIFF"u8);
        writer.Write(36 + dataBytes);
        writer.Write("WAVE"u8);
        writer.Write("fmt "u8);
        writer.Write(16);
        writer.Write((ushort)(format == WaveFixtureFormat.Float32 ? 3 : 1));
        writer.Write((ushort)channels);
        writer.Write(sampleRate);
        writer.Write(sampleRate * channels * bytesPerSample);
        writer.Write((ushort)(channels * bytesPerSample));
        writer.Write((ushort)bits);
        writer.Write("data"u8);
        writer.Write(dataBytes);
        for (var frame = 0; frame < frames; frame++)
        {
            var value = Math.Sin(frame * Math.Tau * 440 / sampleRate) * .4;
            for (var channel = 0; channel < channels; channel++)
            {
                var sample = channel == 0 ? value : value * .75;
                switch (format)
                {
                    case WaveFixtureFormat.Pcm16:
                        writer.Write((short)Math.Round(sample * short.MaxValue));
                        break;
                    case WaveFixtureFormat.Pcm24:
                        var pcm24 = (int)Math.Round(sample * 0x7FFFFF);
                        writer.Write((byte)pcm24);
                        writer.Write((byte)(pcm24 >> 8));
                        writer.Write((byte)(pcm24 >> 16));
                        break;
                    case WaveFixtureFormat.Pcm32:
                        writer.Write((int)Math.Round(sample * int.MaxValue));
                        break;
                    case WaveFixtureFormat.Float32:
                        writer.Write((float)sample);
                        break;
                }
            }
        }
    }

    private static double EstimateFrequency(float[] samples, int sampleRate)
    {
        var crossings = 0;
        for (var index = 1; index < samples.Length; index++)
        {
            if (samples[index - 1] <= 0 && samples[index] > 0) crossings++;
        }
        return crossings * sampleRate / (double)Math.Max(1, samples.Length);
    }

    private sealed class MonoMixSampleProvider : ISampleProvider
    {
        private readonly ISampleProvider source;
        private readonly int channels;
        private float[] sourceBuffer = [];

        public MonoMixSampleProvider(ISampleProvider source)
        {
            this.source = source;
            channels = source.WaveFormat.Channels;
            Program.Require(channels > 1, "Mono mixer requires a multichannel source.");
            WaveFormat = WaveFormat.CreateIeeeFloatWaveFormat(source.WaveFormat.SampleRate, 1);
        }

        public WaveFormat WaveFormat { get; }

        public int Read(float[] buffer, int offset, int count)
        {
            var requested = checked(count * channels);
            if (sourceBuffer.Length < requested) sourceBuffer = new float[requested];
            var read = source.Read(sourceBuffer, 0, requested);
            var frames = read / channels;
            for (var frame = 0; frame < frames; frame++)
            {
                double sum = 0;
                var frameOffset = frame * channels;
                for (var channel = 0; channel < channels; channel++)
                {
                    sum += sourceBuffer[frameOffset + channel];
                }
                buffer[offset + frame] = (float)(sum / channels);
            }
            return frames;
        }
    }

    private readonly record struct WaveFixture(
        string Name,
        int SampleRate,
        int Channels,
        WaveFixtureFormat Format);

    private enum WaveFixtureFormat
    {
        Pcm16,
        Pcm24,
        Pcm32,
        Float32,
    }
}
