using System.Globalization;
using System.Text;
using PsyReaSFX.Data;

namespace PsyReaSFX.Desktop.Services;

internal static class LuaWaveCache
{
    private static readonly Lazy<(string Directory, int MiniPoints)> Settings = new(FindSettings);

    public static bool TryRead(string sourcePath, int requestedPoints, bool preserveChannels, out float[][] waveform)
    {
        waveform = [];
        var settings = Settings.Value;
        if (settings.Directory.Length == 0 || !Directory.Exists(settings.Directory)) return false;
        long size;
        try { size = new FileInfo(sourcePath).Length; }
        catch { return false; }

        var candidates = new List<int> { requestedPoints };
        if (!preserveChannels && settings.MiniPoints > 0 && !candidates.Contains(settings.MiniPoints))
            candidates.Add(settings.MiniPoints);
        if (preserveChannels && requestedPoints < 4096) candidates.Add(4096);

        foreach (var points in candidates)
        {
            var suffix = preserveChannels ? "|channels-rwf3" : "";
            var key = Fnv1a(NormalizePath(sourcePath) + "|" + size + "|" + points + suffix);
            var cachePath = Path.Combine(settings.Directory, key + ".rwf");
            if (!File.Exists(cachePath)) continue;
            if (!TryReadFile(cachePath, out var cached)) continue;
            waveform = Resample(cached, requestedPoints);
            return waveform.Length > 0;
        }
        return false;
    }

    private static bool TryReadFile(string path, out float[][] waveform)
    {
        waveform = [];
        try
        {
            using var stream = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            var headerBytes = new List<byte>(40);
            while (headerBytes.Count < 80)
            {
                var value = stream.ReadByte();
                if (value < 0 || value == '\n') break;
                if (value != '\r') headerBytes.Add((byte)value);
            }
            var parts = Encoding.ASCII.GetString([.. headerBytes]).Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length < 2 || (parts[0] != "RWF2" && parts[0] != "RWF3")) return false;
            if (!int.TryParse(parts[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out var count) || count is <= 0 or > 65536) return false;
            var channels = parts[0] == "RWF3" && parts.Length >= 3 && int.TryParse(parts[2], out var parsedChannels)
                ? Math.Clamp(parsedChannels, 1, 8) : 1;
            var bytes = new byte[checked(count * channels * 2)];
            stream.ReadExactly(bytes);
            waveform = Enumerable.Range(0, channels).Select(_ => new float[count]).ToArray();
            for (var point = 0; point < count; point++)
            for (var channel = 0; channel < channels; channel++)
            {
                var offset = (point * channels + channel) * 2;
                waveform[channel][point] = (bytes[offset] | bytes[offset + 1] << 8) / 65535f;
            }
            return true;
        }
        catch { waveform = []; return false; }
    }

    private static float[][] Resample(float[][] source, int points)
    {
        if (source.Length == 0 || points <= 0) return [];
        if (source[0].Length == points) return source;
        var result = Enumerable.Range(0, source.Length).Select(_ => new float[points]).ToArray();
        for (var channel = 0; channel < source.Length; channel++)
        for (var point = 0; point < points; point++)
        {
            var start = point * source[channel].Length / points;
            var end = Math.Max(start + 1, (point + 1) * source[channel].Length / points);
            var peak = 0f;
            for (var index = start; index < Math.Min(end, source[channel].Length); index++)
                peak = Math.Max(peak, source[channel][index]);
            result[channel][point] = peak;
        }
        return result;
    }

    private static (string Directory, int MiniPoints) FindSettings()
    {
        var data = LuaDataLocator.Find();
        if (data is null) return ("", 512);
        var directory = Path.Combine(data, "wave_cache_v3");
        var miniPoints = 512;
        try
        {
            foreach (var line in File.ReadLines(Path.Combine(data, "config.tsv")))
            {
                var fields = line.Split('\t');
                if (fields.Length < 3 || fields[0] != "setting") continue;
                if (fields[1] == "wave_cache_dir" && fields[2].Length > 0) directory = fields[2];
                else if (fields[1] == "mini_wave_points" && int.TryParse(fields[2], out var parsed)) miniPoints = parsed;
            }
        }
        catch { }
        return (directory, Math.Clamp(miniPoints, 128, 4096));
    }

    private static string NormalizePath(string path) => path.Replace('/', '\\').ToLowerInvariant();

    private static string Fnv1a(string value)
    {
        uint hash = 2166136261;
        foreach (var valueByte in Encoding.UTF8.GetBytes(value)) hash = (hash ^ valueByte) * 16777619;
        return hash.ToString("x8", CultureInfo.InvariantCulture);
    }
}
