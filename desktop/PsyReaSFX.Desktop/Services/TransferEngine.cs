using System.Diagnostics;
using System.Globalization;
using System.Text;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;

namespace PsyReaSFX.Desktop.Services;

/// <summary>
/// Standalone counterpart of the Lua Transfer pipeline. It always reads source
/// media and writes a new file; project tracks and the REAPER master bus are
/// deliberately outside this processing path.
/// </summary>
public sealed class TransferEngine
{
    private const int MaximumJobs = 4096;
    private const int MaximumVariantsPerAsset = 128;

    public static IReadOnlyList<TransferVariant> BuildVariants(TransferOptions options)
    {
        if (!options.VariantsEnabled)
            return [new TransferVariant(options.Pitch, options.Rate, options.Gain, options.Reverse, 1)];

        // Match the Lua 0.7.23 Transfer ranges. These are intentionally wider
        // than the interactive audition controls because offline variation
        // design is allowed to be more extreme.
        var pitches = ParseNumbers(options.VariantPitches, -48, 48, options.Pitch);
        var rates = ParseNumbers(options.VariantRates, .1, 4, options.Rate);
        var gains = ParseNumbers(options.VariantGains, -60, 24, options.Gain);
        var directions = options.VariantReverse ? new[] { false, true } : new[] { options.Reverse };
        if ((long)pitches.Count * rates.Count * gains.Count * directions.Length > MaximumVariantsPerAsset)
            throw new InvalidOperationException($"Variant combinations exceed {MaximumVariantsPerAsset}; reduce the number of values.");
        var variants = new List<TransferVariant>();
        foreach (var pitch in pitches)
        foreach (var rate in rates)
        foreach (var gain in gains)
        foreach (var reverse in directions)
        {
            variants.Add(new TransferVariant(pitch, rate, gain, reverse, variants.Count + 1));
        }
        if (variants.Count == 0) return [new TransferVariant(options.Pitch, options.Rate, options.Gain, options.Reverse, 1)];
        for (var index = 0; index < variants.Count; index++) variants[index] = variants[index] with { Count = variants.Count };
        return variants;
    }

    public async Task<TransferRunResult> RunAsync(
        IReadOnlyList<TransferRequest> requests,
        TransferOptions options,
        IProgress<TransferProgress>? progress,
        CancellationToken token)
    {
        if (requests.Count == 0) throw new InvalidOperationException("No assets were selected.");
        if (requests.Count > MaximumJobs) throw new InvalidOperationException($"A Transfer run is limited to {MaximumJobs:N0} jobs.");
        Directory.CreateDirectory(options.OutputDirectory);
        var result = new TransferRunResult();
        for (var index = 0; index < requests.Count; index++)
        {
            token.ThrowIfCancellationRequested();
            var request = requests[index];
            progress?.Report(new TransferProgress(index, requests.Count, request.Asset.FileName,
                $"{index + 1:N0} / {requests.Count:N0}"));
            try
            {
                result.Items.Add(await RenderAsync(request, options, token));
            }
            catch (OperationCanceledException) { throw; }
            catch (Exception exception)
            {
                AppDiagnostics.Write($"Transfer failed: {request.Asset.FilePath}", exception);
                result.Items.Add(new TransferItemResult(request.Asset.FilePath, "", false, false,
                    exception.Message, request.Variant, 0));
            }
        }
        result.ReportPath = WriteReport(result, options.OutputDirectory);
        progress?.Report(new TransferProgress(requests.Count, requests.Count, "", "Complete"));
        return result;
    }

    private static async Task<TransferItemResult> RenderAsync(TransferRequest request, TransferOptions options, CancellationToken token)
    {
        var asset = request.Asset;
        if (!File.Exists(asset.FilePath)) throw new FileNotFoundException("Source media was not found.", asset.FilePath);
        var extension = options.Format.Equals("flac", StringComparison.OrdinalIgnoreCase) ? ".flac" : ".wav";
        var baseName = ExpandName(options.NamingTemplate, request);
        if (options.Lowercase) baseName = baseName.ToLowerInvariant();
        if (options.VariantAutoSuffix && request.Variant.Count > 1 && !ContainsVariantToken(options.NamingTemplate))
            baseName += "_" + request.Variant.Token;
        var proposed = Path.Combine(options.OutputDirectory, SanitizeName(baseName) + extension);
        var outputPath = ResolveCollision(proposed, options.CollisionPolicy, out var skipped);
        if (skipped)
            return new TransferItemResult(asset.FilePath, proposed, false, true, "Existing file skipped", request.Variant, 0);

        var scratchDirectory = Path.Combine(options.OutputDirectory, ".psyreasfx-transfer");
        Directory.CreateDirectory(scratchDirectory);
        var rawPath = Path.Combine(scratchDirectory, Guid.NewGuid().ToString("N") + ".float.wav");
        var encodedWav = Path.Combine(scratchDirectory, Guid.NewGuid().ToString("N") + ".wav");
        try
        {
            var render = await Task.Run(() => RenderFloatIntermediate(request, options, rawPath, token), token);
            var measured = await MeasureAsync(rawPath, options.NormalizeMode, render.Peak, render.Rms, token);
            var normalizationDb = options.NormalizeMode.Equals("off", StringComparison.OrdinalIgnoreCase)
                ? 0 : Math.Clamp(options.NormalizeTarget - measured, -60, 60);
            var bitDepth = options.Format switch { "wav16" => 16, "wav32" => 32, _ => 24 };
            await Task.Run(() => EncodeWave(rawPath, encodedWav, bitDepth, normalizationDb, options, token), token);
            if (options.Format.Equals("flac", StringComparison.OrdinalIgnoreCase))
                await EncodeFlacAsync(encodedWav, outputPath, token);
            else
                File.Move(encodedWav, outputPath, true);

            if (options.PreserveMetadata)
            {
                if (Path.GetExtension(outputPath).Equals(".wav", StringComparison.OrdinalIgnoreCase))
                    CopyWaveMetadataChunks(asset.FilePath, outputPath);
                var sourceInfo = new FileInfo(asset.FilePath);
                File.SetCreationTimeUtc(outputPath, sourceInfo.CreationTimeUtc);
                File.SetLastWriteTimeUtc(outputPath, sourceInfo.LastWriteTimeUtc);
                CopyMetadataSidecars(asset.FilePath, outputPath);
            }
            return new TransferItemResult(asset.FilePath, outputPath, true, false, "OK", request.Variant, render.Duration);
        }
        finally
        {
            TryDelete(rawPath);
            TryDelete(encodedWav);
            try { if (Directory.Exists(scratchDirectory) && !Directory.EnumerateFileSystemEntries(scratchDirectory).Any()) Directory.Delete(scratchDirectory); } catch { }
        }
    }

    private static RenderMeasurement RenderFloatIntermediate(TransferRequest request, TransferOptions options, string path, CancellationToken token)
    {
        using var reader = new NAudio.Wave.AudioFileReader(request.Asset.FilePath);
        var sourceDuration = reader.TotalTime.TotalSeconds;
        var start = options.Scope == "selection" && request.SelectionStartRatio >= 0
            ? Math.Clamp(request.SelectionStartRatio, 0, 1) * sourceDuration : 0;
        var end = options.Scope == "selection" && request.SelectionEndRatio > request.SelectionStartRatio
            ? Math.Clamp(request.SelectionEndRatio, 0, 1) * sourceDuration : sourceDuration;
        if (options.SmartTail && end < sourceDuration)
            end = DetectTailEnd(request.Asset.FilePath, end, options, token);
        reader.CurrentTime = TimeSpan.FromSeconds(start);
        ISampleProvider provider = new OffsetSampleProvider(reader)
        {
            Take = TimeSpan.FromSeconds(Math.Max(.001, end - start))
        };

        provider = new TransferChannelSampleProvider(provider, options.Channels);
        if (request.Variant.Reverse)
            provider = BufferedReverseSampleProvider.Create(provider, 160_000_000, token);
        var pitch = new SmbPitchShiftingSampleProvider(provider)
        {
            PitchFactor = (float)Math.Clamp(
                Math.Pow(2, request.Variant.Pitch / 12.0) * (options.PreservePitch ? 1 / Math.Max(.01, request.Variant.Rate) : 1), .125, 8)
        };
        provider = new RateSampleProvider(pitch) { Rate = request.Variant.Rate };
        var targetRate = ResolveSampleRate(options.SampleRate, provider.WaveFormat.SampleRate);
        if (targetRate != provider.WaveFormat.SampleRate) provider = new WdlResamplingSampleProvider(provider, targetRate);
        provider = new VolumeSampleProvider(provider) { Volume = (float)Math.Pow(10, request.Variant.Gain / 20) };

        using var writer = new WaveFileWriter(path, WaveFormat.CreateIeeeFloatWaveFormat(targetRate, provider.WaveFormat.Channels));
        var buffer = new float[32768 - (32768 % provider.WaveFormat.Channels)];
        double sumSquares = 0; double peak = 0; long samples = 0;
        int read;
        while ((read = provider.Read(buffer, 0, buffer.Length)) > 0)
        {
            token.ThrowIfCancellationRequested();
            writer.WriteSamples(buffer, 0, read);
            for (var i = 0; i < read; i++) { var sample = buffer[i]; peak = Math.Max(peak, Math.Abs(sample)); sumSquares += sample * sample; }
            samples += read;
        }
        var frames = samples / Math.Max(1, provider.WaveFormat.Channels);
        return new RenderMeasurement(peak, Math.Sqrt(sumSquares / Math.Max(1, samples)), frames / (double)targetRate);
    }

    private static async Task<double> MeasureAsync(string path, string mode, double peak, double rms, CancellationToken token)
    {
        return mode.ToLowerInvariant() switch
        {
            "peak" => ToDb(peak),
            "rms-i" => ToDb(rms),
            "true-peak" => (await LoudnessAnalyzer.AnalyzeAsync(path, new FileInfo(path).Length, token)).TruePeak ?? ToDb(peak),
            "lufs-i" => (await LoudnessAnalyzer.AnalyzeAsync(path, new FileInfo(path).Length, token)).LufsI ?? ToDb(rms),
            _ => 0
        };
    }

    private static void EncodeWave(string sourcePath, string outputPath, int bitDepth, double gainDb, TransferOptions options, CancellationToken token)
    {
        using var reader = new NAudio.Wave.AudioFileReader(sourcePath);
        var format = new WaveFormat(reader.WaveFormat.SampleRate, bitDepth, reader.WaveFormat.Channels);
        using var writer = new WaveFileWriter(outputPath, format);
        var totalFrames = Math.Max(1L, (long)(reader.TotalTime.TotalSeconds * reader.WaveFormat.SampleRate));
        var fadeInFrames = (long)(Math.Clamp(options.FadeInMs, 0, 30000) * reader.WaveFormat.SampleRate / 1000.0);
        var fadeOutFrames = (long)(Math.Clamp(options.FadeOutMs, 0, 30000) * reader.WaveFormat.SampleRate / 1000.0);
        var amplitude = Math.Pow(10, gainDb / 20);
        var random = new Random(7319);
        var errors = new double[reader.WaveFormat.Channels];
        var buffer = new float[32768 - (32768 % reader.WaveFormat.Channels)];
        long frameIndex = 0;
        int read;
        while ((read = reader.Read(buffer, 0, buffer.Length)) > 0)
        {
            token.ThrowIfCancellationRequested();
            for (var i = 0; i < read; i++)
            {
                var frame = frameIndex + i / reader.WaveFormat.Channels;
                var fade = fadeInFrames > 0 && frame < fadeInFrames ? frame / (double)fadeInFrames : 1;
                if (fadeOutFrames > 0 && frame >= totalFrames - fadeOutFrames)
                    fade = Math.Min(fade, (totalFrames - frame) / (double)fadeOutFrames);
                var value = buffer[i] * amplitude * Math.Clamp(fade, 0, 1);
                var channel = i % reader.WaveFormat.Channels;
                if (options.NoiseShaping) value += errors[channel] * .5;
                if (options.Dither && bitDepth < 32)
                {
                    var lsb = 1.0 / (1L << (bitDepth - 1));
                    value += (random.NextDouble() - random.NextDouble()) * lsb;
                }
                var clipped = Math.Clamp(value, -1, 1);
                if (options.NoiseShaping) errors[channel] = value - clipped;
                writer.WriteSample((float)clipped);
            }
            frameIndex += read / reader.WaveFormat.Channels;
        }
    }

    private static double DetectTailEnd(string path, double selectionEnd, TransferOptions options, CancellationToken token)
    {
        using var reader = new NAudio.Wave.AudioFileReader(path);
        reader.CurrentTime = TimeSpan.FromSeconds(selectionEnd);
        var threshold = Math.Pow(10, Math.Clamp(options.TailThresholdDb, -120, 0) / 20);
        var maximumEnd = Math.Min(reader.TotalTime.TotalSeconds, selectionEnd + Math.Clamp(options.TailMaximumMs, 0, 60000) / 1000);
        var holdFrames = (long)(Math.Clamp(options.TailHoldMs, 0, 10000) * reader.WaveFormat.SampleRate / 1000);
        var buffer = new float[16384 - (16384 % reader.WaveFormat.Channels)];
        long silentFrames = 0; var lastActive = selectionEnd; var current = selectionEnd;
        while (current < maximumEnd)
        {
            token.ThrowIfCancellationRequested();
            var read = reader.Read(buffer, 0, buffer.Length);
            if (read <= 0) break;
            var frames = read / reader.WaveFormat.Channels;
            for (var frame = 0; frame < frames; frame++)
            {
                var active = false;
                for (var channel = 0; channel < reader.WaveFormat.Channels; channel++)
                    active |= Math.Abs(buffer[frame * reader.WaveFormat.Channels + channel]) >= threshold;
                current += 1.0 / reader.WaveFormat.SampleRate;
                if (active) { lastActive = current; silentFrames = 0; }
                else if (++silentFrames >= holdFrames && holdFrames > 0) return Math.Min(maximumEnd, lastActive + options.TailHoldMs / 1000);
                if (current >= maximumEnd) break;
            }
        }
        return Math.Max(selectionEnd, Math.Min(maximumEnd, lastActive + options.TailHoldMs / 1000));
    }

    private static async Task EncodeFlacAsync(string sourceWav, string outputPath, CancellationToken token)
    {
        var ffmpeg = FindExecutable("ffmpeg.exe") ?? throw new InvalidOperationException(
            "FLAC export requires ffmpeg.exe in PATH. WAV export remains available without it.");
        var start = new ProcessStartInfo(ffmpeg,
            $"-hide_banner -loglevel error -y -i \"{sourceWav}\" -map_metadata 0 -c:a flac \"{outputPath}\"")
        { UseShellExecute = false, CreateNoWindow = true, RedirectStandardError = true };
        using var process = Process.Start(start) ?? throw new InvalidOperationException("Could not start the FLAC encoder.");
        await process.WaitForExitAsync(token);
        if (process.ExitCode != 0) throw new InvalidOperationException((await process.StandardError.ReadToEndAsync(token)).Trim());
    }

    public static string ExpandName(string template, TransferRequest request)
    {
        var asset = request.Asset;
        var name = Path.GetFileNameWithoutExtension(asset.FileName);
        var region = request.SelectionEndRatio > request.SelectionStartRatio ? "selection" : "full";
        var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["name"] = name, ["category"] = asset.Category, ["subcategory"] = asset.Subcategory,
            ["library"] = asset.LibraryName, ["index"] = request.AssetIndex.ToString("D3", CultureInfo.InvariantCulture),
            ["date"] = DateTime.Now.ToString("yyyyMMdd", CultureInfo.InvariantCulture), ["region"] = region,
            ["pitch"] = request.Variant.Pitch.ToString("+0.###;-0.###;0", CultureInfo.InvariantCulture),
            ["rate"] = request.Variant.Rate.ToString("0.###", CultureInfo.InvariantCulture),
            ["gain"] = request.Variant.Gain.ToString("+0.###;-0.###;0", CultureInfo.InvariantCulture),
            ["direction"] = request.Variant.Direction, ["variant"] = request.Variant.Token,
            ["variant_index"] = request.Variant.Index.ToString("D3", CultureInfo.InvariantCulture)
        };
        var expanded = string.IsNullOrWhiteSpace(template) ? "{name}" : template;
        foreach (var pair in map) expanded = expanded.Replace("{" + pair.Key + "}", pair.Value ?? "", StringComparison.OrdinalIgnoreCase);
        return expanded;
    }

    private static List<double> ParseNumbers(string text, double minimum, double maximum, double fallback)
    {
        var tokens = (text ?? "").Split([',', ';', ' ', '\t'], StringSplitOptions.RemoveEmptyEntries);
        if (tokens.Length == 0) return [Math.Clamp(fallback, minimum, maximum)];
        if (tokens.Length > 16) throw new InvalidOperationException("Each variant parameter accepts at most 16 values.");
        var values = new List<double>();
        foreach (var token in tokens)
        {
            if (!double.TryParse(token.Replace(',', '.'), NumberStyles.Float, CultureInfo.InvariantCulture, out var parsed)
                || parsed < minimum || parsed > maximum)
                throw new InvalidOperationException($"Invalid variant value '{token}'. Allowed range: {minimum:0.###} to {maximum:0.###}.");
            if (!values.Contains(parsed)) values.Add(parsed);
        }
        values.Sort();
        return values;
    }

    private static int ResolveSampleRate(string value, int source) => value.ToLowerInvariant() switch
    { "44100" => 44100, "48000" => 48000, "96000" => 96000, "192000" => 192000, _ => source };
    private static double ToDb(double value) => 20 * Math.Log10(Math.Max(1e-12, value));
    private static bool ContainsVariantToken(string template) => new[] { "{pitch}", "{rate}", "{gain}", "{direction}", "{variant}", "{variant_index}" }.Any(token => template.Contains(token, StringComparison.OrdinalIgnoreCase));
    private static string SanitizeName(string value)
    {
        foreach (var character in Path.GetInvalidFileNameChars()) value = value.Replace(character, '_');
        value = value.Trim().TrimEnd('.');
        return string.IsNullOrWhiteSpace(value) ? "psyreasfx_transfer" : value;
    }

    private static string ResolveCollision(string path, string policy, out bool skipped)
    {
        skipped = false;
        if (!File.Exists(path) || policy.Equals("overwrite", StringComparison.OrdinalIgnoreCase)) return path;
        if (policy.Equals("skip", StringComparison.OrdinalIgnoreCase)) { skipped = true; return path; }
        var directory = Path.GetDirectoryName(path)!; var stem = Path.GetFileNameWithoutExtension(path); var extension = Path.GetExtension(path);
        for (var index = 2; index < 10000; index++)
        {
            var candidate = Path.Combine(directory, $"{stem}_{index:D2}{extension}");
            if (!File.Exists(candidate)) return candidate;
        }
        throw new IOException("Could not allocate a unique output filename.");
    }

    private static void CopyMetadataSidecars(string source, string output)
    {
        var sourceBase = Path.Combine(Path.GetDirectoryName(source)!, Path.GetFileNameWithoutExtension(source));
        var outputBase = Path.Combine(Path.GetDirectoryName(output)!, Path.GetFileNameWithoutExtension(output));
        foreach (var extension in new[] { ".xml", ".ixml", ".json", ".csv" })
        {
            var sidecar = sourceBase + extension;
            if (File.Exists(sidecar)) File.Copy(sidecar, outputBase + extension, true);
        }
    }

    /// <summary>
    /// Carries the common broadcast/asset-management RIFF chunks into a newly
    /// rendered WAV. Audio format and data chunks intentionally remain those of
    /// the rendered file. Unknown and unsafe chunks are ignored.
    /// </summary>
    private static void CopyWaveMetadataChunks(string source, string output)
    {
        if (!Path.GetExtension(source).Equals(".wav", StringComparison.OrdinalIgnoreCase)) return;
        var allowed = new HashSet<string>(StringComparer.Ordinal)
        { "bext", "iXML", "axml", "LIST", "cue ", "smpl", "id3 ", "ID3 ", "cart", "DISP" };
        var chunks = new List<(string Id, byte[] Data)>();
        try
        {
            using (var input = new BinaryReader(File.Open(source, FileMode.Open, FileAccess.Read, FileShare.ReadWrite), Encoding.ASCII, false))
            {
                if (Encoding.ASCII.GetString(input.ReadBytes(4)) != "RIFF") return;
                _ = input.ReadUInt32();
                if (Encoding.ASCII.GetString(input.ReadBytes(4)) != "WAVE") return;
                while (input.BaseStream.Position + 8 <= input.BaseStream.Length)
                {
                    var id = Encoding.ASCII.GetString(input.ReadBytes(4));
                    var size = input.ReadUInt32();
                    if (size > 32 * 1024 * 1024 || input.BaseStream.Position + size > input.BaseStream.Length) break;
                    if (allowed.Contains(id)) chunks.Add((id, input.ReadBytes((int)size)));
                    else input.BaseStream.Seek(size, SeekOrigin.Current);
                    if ((size & 1) != 0 && input.BaseStream.Position < input.BaseStream.Length) input.BaseStream.Seek(1, SeekOrigin.Current);
                }
            }
            if (chunks.Count == 0) return;
            using var destination = new FileStream(output, FileMode.Open, FileAccess.ReadWrite, FileShare.None);
            destination.Seek(0, SeekOrigin.End);
            using (var writer = new BinaryWriter(destination, Encoding.ASCII, true))
            {
                foreach (var chunk in chunks)
                {
                    writer.Write(Encoding.ASCII.GetBytes(chunk.Id));
                    writer.Write((uint)chunk.Data.Length);
                    writer.Write(chunk.Data);
                    if ((chunk.Data.Length & 1) != 0) writer.Write((byte)0);
                }
            }
            destination.Seek(4, SeekOrigin.Begin);
            using var sizeWriter = new BinaryWriter(destination, Encoding.ASCII, true);
            sizeWriter.Write((uint)Math.Min(uint.MaxValue, destination.Length - 8));
        }
        catch (Exception exception)
        {
            // Metadata preservation is best effort and must never invalidate an
            // otherwise valid render.
            AppDiagnostics.Write($"WAV metadata preservation skipped: {source}", exception);
        }
    }

    private static string? FindExecutable(string name)
    {
        foreach (var directory in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(Path.PathSeparator))
        {
            try { var candidate = Path.Combine(directory.Trim(), name); if (File.Exists(candidate)) return candidate; } catch { }
        }
        return null;
    }

    private static string WriteReport(TransferRunResult result, string directory)
    {
        var path = Path.Combine(directory, "transfer_report_latest.tsv");
        using var writer = new StreamWriter(path, false, new UTF8Encoding(true));
        writer.WriteLine("status\tsource\toutput\tpitch\trate\tgain\tdirection\tduration\tmessage");
        foreach (var item in result.Items)
            writer.WriteLine(string.Join('\t', item.Success ? "ok" : item.Skipped ? "skipped" : "failed",
                Clean(item.SourcePath), Clean(item.OutputPath), item.Variant.Pitch.ToString(CultureInfo.InvariantCulture),
                item.Variant.Rate.ToString(CultureInfo.InvariantCulture), item.Variant.Gain.ToString(CultureInfo.InvariantCulture),
                item.Variant.Direction, item.DurationSeconds.ToString("0.###", CultureInfo.InvariantCulture), Clean(item.Message)));
        return path;
    }

    private static string Clean(string value) => (value ?? "").Replace('\t', ' ').Replace('\r', ' ').Replace('\n', ' ');
    private static void TryDelete(string path) { try { if (File.Exists(path)) File.Delete(path); } catch { } }
    private sealed record RenderMeasurement(double Peak, double Rms, double Duration);
}

internal sealed class TransferChannelSampleProvider : ISampleProvider
{
    private readonly ISampleProvider _source;
    private readonly string _mode;
    private float[] _sourceBuffer = [];
    public TransferChannelSampleProvider(ISampleProvider source, string mode)
    {
        _source = source; _mode = mode.ToLowerInvariant();
        var channels = _mode == "mono" ? 1 : _mode == "stereo" ? 2 : source.WaveFormat.Channels;
        WaveFormat = WaveFormat.CreateIeeeFloatWaveFormat(source.WaveFormat.SampleRate, channels);
    }
    public WaveFormat WaveFormat { get; }
    public int Read(float[] buffer, int offset, int count)
    {
        var sourceChannels = _source.WaveFormat.Channels; var outputChannels = WaveFormat.Channels;
        if (sourceChannels == outputChannels && _mode == "source") return _source.Read(buffer, offset, count);
        var framesRequested = count / outputChannels; var sourceSamples = framesRequested * sourceChannels;
        if (_sourceBuffer.Length < sourceSamples) _sourceBuffer = new float[sourceSamples];
        var read = _source.Read(_sourceBuffer, 0, sourceSamples); var frames = read / sourceChannels;
        for (var frame = 0; frame < frames; frame++)
        {
            var sourceOffset = frame * sourceChannels;
            if (outputChannels == 1)
            {
                double sum = 0; for (var channel = 0; channel < sourceChannels; channel++) sum += _sourceBuffer[sourceOffset + channel];
                buffer[offset + frame] = (float)(sum / sourceChannels);
            }
            else
            {
                var left = _sourceBuffer[sourceOffset]; var right = sourceChannels > 1 ? _sourceBuffer[sourceOffset + 1] : left;
                buffer[offset + frame * 2] = left; buffer[offset + frame * 2 + 1] = right;
            }
        }
        return frames * outputChannels;
    }
}
