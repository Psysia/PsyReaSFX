using PsyReaSFX.Data;

namespace PsyReaSFX.Desktop.Services;

public sealed record TransientDetectionOptions(double ThresholdDb, double SmoothingMs, double MinimumIntervalMs,
    double PreRollMs, double PostRollMs, int MaximumRegions);

public static class TransientDetector
{
    public static Task<IReadOnlyList<RegionRecord>> DetectAsync(string path, double duration,
        TransientDetectionOptions options, CancellationToken token = default) => Task.Run<IReadOnlyList<RegionRecord>>(() =>
    {
        const int buckets = 32768;
        token.ThrowIfCancellationRequested();
        var channels = AudioFileReader.ReadWaveform(path, buckets);
        if (channels.Length == 0 || duration <= 0) return [];
        var length = channels.Max(channel => channel.Length);
        var envelope = new double[length];
        for (var i = 0; i < length; i++)
            for (var channel = 0; channel < channels.Length; channel++)
                if (i < channels[channel].Length) envelope[i] = Math.Max(envelope[i], channels[channel][i]);

        var bucketMs = duration * 1000 / Math.Max(1, length);
        var smooth = Math.Max(1, (int)Math.Round(options.SmoothingMs / Math.Max(.001, bucketMs)));
        if (smooth > 1)
        {
            var sum = 0d;
            var copy = (double[])envelope.Clone();
            for (var i = 0; i < length; i++)
            {
                sum += copy[i];
                if (i >= smooth) sum -= copy[i - smooth];
                envelope[i] = sum / Math.Min(i + 1, smooth);
            }
        }

        var threshold = Math.Pow(10, options.ThresholdDb / 20);
        var minimum = Math.Max(1, (int)Math.Round(options.MinimumIntervalMs / Math.Max(.001, bucketMs)));
        var candidates = new List<int>();
        var last = -minimum;
        for (var i = 1; i < length - 1; i++)
        {
            if ((i & 2047) == 0) token.ThrowIfCancellationRequested();
            if (envelope[i] < threshold || envelope[i] < envelope[i - 1] || envelope[i] < envelope[i + 1]) continue;
            if (i - last < minimum)
            {
                if (candidates.Count > 0 && envelope[i] > envelope[candidates[^1]]) { candidates[^1] = i; last = i; }
                continue;
            }
            candidates.Add(i); last = i;
            if (candidates.Count >= Math.Clamp(options.MaximumRegions, 1, 512)) break;
        }

        var batch = Guid.NewGuid().ToString("N");
        var rows = new List<RegionRecord>(candidates.Count);
        for (var index = 0; index < candidates.Count; index++)
        {
            var center = candidates[index] / (double)Math.Max(1, length - 1) * duration;
            var start = Math.Max(0, center - options.PreRollMs / 1000);
            var finish = Math.Min(duration, center + options.PostRollMs / 1000);
            rows.Add(new RegionRecord(path, start, finish, $"[T] Transient {index + 1:00}", "transient", batch));
        }
        return rows;
    }, token);
}
