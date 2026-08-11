using NAudio.Dsp;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;
using PsyReaSFX.Data;

namespace PsyReaSFX.Desktop.Services;

/// <summary>Offline BS.1770-style analysis for browser comparison and caching.</summary>
public static class LoudnessAnalyzer
{
    public static Task<LoudnessRecord> AnalyzeAsync(string path, long size, CancellationToken token = default) => Task.Run(() =>
    {
        using var reader = new NAudio.Wave.AudioFileReader(path);
        var rate = reader.WaveFormat.SampleRate;
        var channels = reader.WaveFormat.Channels;
        var highPass = Enumerable.Range(0, channels).Select(_ => BiQuadFilter.HighPassFilter(rate, 60, .5f)).ToArray();
        var shelf = Enumerable.Range(0, channels).Select(_ => BiQuadFilter.HighShelf(rate, 4000, .707f, 4)).ToArray();
        var blockFrames = Math.Max(1, rate / 10); // 100 ms building blocks
        var blockEnergy = new List<double>();
        var buffer = new float[Math.Max(4096, blockFrames * channels / 4)];
        double sum = 0; var frames = 0; var absolutePeak = 0d;
        int read;
        while ((read = reader.Read(buffer, 0, buffer.Length)) > 0)
        {
            token.ThrowIfCancellationRequested();
            for (var i = 0; i + channels <= read; i += channels)
            {
                double frameEnergy = 0;
                for (var channel = 0; channel < channels; channel++)
                {
                    var raw = buffer[i + channel];
                    absolutePeak = Math.Max(absolutePeak, Math.Abs(raw));
                    var weighted = shelf[channel].Transform(highPass[channel].Transform(raw));
                    frameEnergy += weighted * weighted;
                }
                sum += frameEnergy / Math.Max(1, channels); frames++;
                if (frames < blockFrames) continue;
                blockEnergy.Add(sum / frames); sum = 0; frames = 0;
            }
        }
        if (frames > 0) blockEnergy.Add(sum / frames);
        if (blockEnergy.Count == 0) return new LoudnessRecord(path, size, -120, -120, -120, -120);

        var momentary = WindowEnergies(blockEnergy, 4).Select(ToLufs).ToArray();
        var shortTerm = WindowEnergies(blockEnergy, 30).Select(ToLufs).ToArray();
        var gated = momentary.Where(value => value > -70).ToArray();
        var ungatedEnergy = gated.Length == 0 ? 0 : gated.Select(FromLufs).Average();
        var relativeGate = ToLufs(ungatedEnergy) - 10;
        var accepted = momentary.Where(value => value > -70 && value >= relativeGate).Select(FromLufs).ToArray();
        var integrated = accepted.Length == 0 ? -120 : ToLufs(accepted.Average());
        var truePeak = MeasureTruePeak(path, rate, absolutePeak, token);
        var peakDb = 20 * Math.Log10(Math.Max(1e-12, truePeak));
        return new LoudnessRecord(path, size, integrated,
            momentary.Length == 0 ? -120 : momentary.Max(), shortTerm.Length == 0 ? -120 : shortTerm.Max(), peakDb);
    }, token);

    private static IEnumerable<double> WindowEnergies(IReadOnlyList<double> values, int window)
    {
        if (values.Count == 0) yield break;
        double sum = 0;
        for (var index = 0; index < values.Count; index++)
        {
            sum += values[index];
            if (index >= window) sum -= values[index - window];
            if (index + 1 >= Math.Min(window, values.Count)) yield return sum / Math.Min(index + 1, window);
        }
    }

    private static double ToLufs(double energy) => -0.691 + 10 * Math.Log10(Math.Max(1e-12, energy));
    private static double FromLufs(double lufs) => Math.Pow(10, (lufs + .691) / 10);

    private static double MeasureTruePeak(string path, int sourceRate, double samplePeak, CancellationToken token)
    {
        // Four-times band-limited oversampling catches inter-sample peaks that
        // a plain sample maximum misses while remaining cheap for on-demand
        // browser analysis.
        using var peakReader = new NAudio.Wave.AudioFileReader(path);
        var oversampled = new WdlResamplingSampleProvider(peakReader, Math.Min(768000, sourceRate * 4));
        var peakBuffer = new float[16384];
        var peak = samplePeak;
        int count;
        while ((count = oversampled.Read(peakBuffer, 0, peakBuffer.Length)) > 0)
        {
            token.ThrowIfCancellationRequested();
            for (var index = 0; index < count; index++) peak = Math.Max(peak, Math.Abs(peakBuffer[index]));
        }
        return peak;
    }
}
