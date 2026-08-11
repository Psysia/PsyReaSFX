using NAudio.Wave;
using NAudio.Wave.SampleProviders;

namespace PsyReaSFX.Desktop.Services;

/// <summary>
/// Creates a temporary WAV for a waveform selection so the selection can be
/// handed to REAPER or any Windows target that accepts file drops. Source files
/// are never modified.
/// </summary>
public static class SelectionDragExporter
{
    private static readonly string OutputDirectory = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "PsyReaSFX", "selection-drag");

    public static Task<string> ExportAsync(string sourcePath, double startSeconds, double endSeconds,
        CancellationToken cancellationToken = default) =>
        ExportToDirectoryAsync(sourcePath, startSeconds, endSeconds, OutputDirectory, cancellationToken);

    internal static Task<string> ExportToDirectoryAsync(string sourcePath, double startSeconds, double endSeconds,
        string outputDirectory, CancellationToken cancellationToken = default) => Task.Run(() =>
    {
        if (endSeconds <= startSeconds) throw new ArgumentOutOfRangeException(nameof(endSeconds));
        Directory.CreateDirectory(outputDirectory);
        CleanupOldFiles(outputDirectory);

        var safeName = string.Concat(Path.GetFileNameWithoutExtension(sourcePath)
            .Select(ch => Path.GetInvalidFileNameChars().Contains(ch) ? '_' : ch));
        var target = Path.Combine(outputDirectory,
            $"{safeName}_selection_{startSeconds:0.000}-{endSeconds:0.000}_{Guid.NewGuid():N}.wav");

        if (Path.GetExtension(sourcePath).Equals(".wav", StringComparison.OrdinalIgnoreCase)
            || Path.GetExtension(sourcePath).Equals(".wave", StringComparison.OrdinalIgnoreCase))
        {
            using var reader = new WaveFileReader(sourcePath);
            var blockAlign = Math.Max(1, reader.WaveFormat.BlockAlign);
            var start = Align((long)(startSeconds * reader.WaveFormat.AverageBytesPerSecond), blockAlign);
            var finish = Align((long)(endSeconds * reader.WaveFormat.AverageBytesPerSecond), blockAlign);
            reader.Position = Math.Clamp(start, 0, reader.Length);
            var remaining = Math.Max(0, Math.Min(reader.Length, finish) - reader.Position);
            using var writer = new WaveFileWriter(target, reader.WaveFormat);
            // WaveFileReader requires every read count to be a complete sample
            // frame.  128 KiB is not divisible by formats such as 24-bit stereo
            // (block align 6), which made every such selection fail.
            var bufferSize = Math.Max(blockAlign, (128 * 1024 / blockAlign) * blockAlign);
            var buffer = new byte[bufferSize];
            while (remaining > 0)
            {
                cancellationToken.ThrowIfCancellationRequested();
                var requested = (int)Math.Min(buffer.Length, remaining);
                requested -= requested % blockAlign;
                if (requested <= 0) break;
                var read = reader.Read(buffer, 0, requested);
                if (read <= 0) break;
                writer.Write(buffer, 0, read);
                remaining -= read;
            }
        }
        else
        {
            // NAudio decodes the common formats supported by the local Windows
            // media stack. The temporary interchange file is intentionally PCM.
            using var reader = new NAudio.Wave.AudioFileReader(sourcePath);
            var section = new OffsetSampleProvider(reader)
            {
                SkipOver = TimeSpan.FromSeconds(startSeconds),
                Take = TimeSpan.FromSeconds(endSeconds - startSeconds)
            };
            WaveFileWriter.CreateWaveFile16(target, section);
        }

        if (!File.Exists(target) || new FileInfo(target).Length <= 44)
            throw new InvalidDataException("The selected audio range could not be exported.");
        return target;
    }, cancellationToken);

    private static long Align(long value, int blockAlign) => value - value % blockAlign;

    private static void CleanupOldFiles(string directory)
    {
        try
        {
            foreach (var file in Directory.EnumerateFiles(directory, "*.wav"))
                if (File.GetLastWriteTimeUtc(file) < DateTime.UtcNow.AddDays(-2)) File.Delete(file);
        }
        catch { /* Temporary cleanup must never block a drag operation. */ }
    }
}
