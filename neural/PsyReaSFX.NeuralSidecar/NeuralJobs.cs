using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.ML.OnnxRuntime;

namespace PsyReaSFX.NeuralSidecar;

internal static class NeuralJobs
{
    private const string JobSchema = "PsyReaSFX-Neural-Job-v1";
    private const string StatusSchema = "PsyReaSFX-Neural-Job-Status-v1";
    private const string ResultSchema = "PsyReaSFX-Neural-Job-Result-v1";
    private const string CacheMagic = "PSYNEMB1";
    private const uint CacheVersion = 1;
    private const int SignatureLength = 16;
    private const int MaximumTopK = 1_000;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
    };

    public static int Run(string modelDirectory, string[] args)
    {
        if (args.Length != 1)
        {
            throw new ArgumentException("run-job requires exactly one request JSON path.");
        }

        var model = Program.ModelBundle.LoadAndVerify(modelDirectory);
        var requestPath = Path.GetFullPath(args[0]);
        var request = JobRequest.Load(requestPath);
        ValidateWritablePaths(modelDirectory, requestPath, request);
        try
        {
            WriteStatus(request, "running", "starting", 0, 0, false, null);
            return request.Operation switch
            {
                "build-cache" => RunBuildCache(model, request),
                "query" => RunQuery(model, request),
                _ => throw new InvalidDataException($"Unsupported neural job operation: {request.Operation}"),
            };
        }
        catch (Exception error)
        {
            WriteStatus(request, "failed", "failed", 0, 0, false, error.Message);
            throw;
        }
    }

    public static object RunSelfTest(Program.ModelBundle model)
    {
        var root = Path.Combine(Path.GetTempPath(), $"PsyReaSFX-neural-jobs-{Guid.NewGuid():N}");
        Directory.CreateDirectory(root);
        var cases = 0;
        try
        {
            var first = UnitVector(model.Dimensions, 0);
            var second = TwoValueUnitVector(model.Dimensions, 0, 1);
            var tie = TwoValueUnitVector(model.Dimensions, 0, 1);
            var fourth = UnitVector(model.Dimensions, 1);
            var records = new[]
            {
                new CacheRecord("0000000000000001", 101, 1_001, ToHalf(first)),
                new CacheRecord("0000000000000002", 102, 1_002, ToHalf(second)),
                new CacheRecord("0000000000000003", 103, 1_003, ToHalf(tie)),
                new CacheRecord("0000000000000004", 104, 1_004, ToHalf(fourth)),
            };
            var cachePath = Path.Combine(root, "roundtrip.bin");
            WriteCacheAtomic(cachePath, model, records);
            var roundTrip = ReadCache(cachePath, model);
            Program.Require(roundTrip.Count == 4 && roundTrip["0000000000000001"].Size == 101,
                "Neural cache round-trip failed.");
            cases++;

            var ranking = Rank(roundTrip, "0000000000000001", null, 10, null);
            Program.Require(ranking.Count == 3
                && ranking[0].Signature == "0000000000000002"
                && ranking[1].Signature == "0000000000000003"
                && ranking[2].Signature == "0000000000000004"
                && Math.Abs(ranking[0].Score - MathF.Sqrt(0.5f)) < 0.001f,
                "Neural cosine ranking or tie ordering is invalid.");
            cases++;

            Program.Require(CanReuse(roundTrip["0000000000000001"], 101, 1_001),
                "Unchanged neural cache record was not reusable.");
            cases++;

            Program.Require(!CanReuse(roundTrip["0000000000000001"], 101, 9_999),
                "Changed neural cache mtime was incorrectly reusable.");
            cases++;

            var offlineAssets = Path.Combine(root, "offline-assets.tsv");
            File.WriteAllText(offlineAssets,
                $"0000000000000001\t101\t1001\t{JsonSerializer.Serialize(Path.Combine(root, "missing.wav"))}{Environment.NewLine}");
            var offlineRequest = CreateSelfTestRequest(root, "offline", cachePath, offlineAssets);
            RunBuildCache(model, offlineRequest);
            using (var offlineResult = JsonDocument.Parse(File.ReadAllText(offlineRequest.ResultPath)))
            {
                Program.Require(offlineResult.RootElement.GetProperty("reused").GetInt32() == 1
                    && offlineResult.RootElement.GetProperty("failed").GetInt32() == 0,
                    "Offline unchanged neural record was not reused.");
            }
            cases++;

            var changedAssets = Path.Combine(root, "changed-assets.tsv");
            File.WriteAllText(changedAssets,
                $"0000000000000001\t101\t9999\t{JsonSerializer.Serialize(Path.Combine(root, "missing.wav"))}{Environment.NewLine}");
            var changedRequest = CreateSelfTestRequest(root, "changed", cachePath, changedAssets);
            RunBuildCache(model, changedRequest);
            using (var changedResult = JsonDocument.Parse(File.ReadAllText(changedRequest.ResultPath)))
            {
                Program.Require(changedResult.RootElement.GetProperty("reused").GetInt32() == 0
                    && changedResult.RootElement.GetProperty("failed").GetInt32() == 1,
                    "Changed offline neural record was incorrectly reused.");
            }
            cases++;

            WriteCacheAtomic(cachePath, model, records);
            var truncatedPath = Path.Combine(root, "truncated.bin");
            var bytes = File.ReadAllBytes(cachePath);
            File.WriteAllBytes(truncatedPath, bytes[..^1]);
            ExpectInvalidData(() => ReadCache(truncatedPath, model), "Truncated neural cache was accepted.");
            cases++;

            var duplicatePath = Path.Combine(root, "duplicate.bin");
            WriteCacheUnchecked(duplicatePath, model, new[] { records[0], records[0] });
            ExpectInvalidData(() => ReadCache(duplicatePath, model), "Duplicate neural cache signature was accepted.");
            cases++;

            WriteCacheAtomic(cachePath, model, records);
            var originalHash = Program.HashFile(cachePath);
            var cancelAssets = Path.Combine(root, "cancel-assets.tsv");
            File.WriteAllText(cancelAssets,
                $"0000000000000001\t101\t1001\t{JsonSerializer.Serialize(Path.Combine(root, "missing.wav"))}{Environment.NewLine}");
            var cancelRequest = CreateSelfTestRequest(root, "cancel", cachePath, cancelAssets);
            File.WriteAllText(cancelRequest.CancelPath!, string.Empty);
            RunBuildCache(model, cancelRequest);
            Program.Require(Program.HashFile(cachePath) == originalHash, "Cancelled build replaced the neural cache.");
            cases++;

            var atomicResult = Path.Combine(root, "atomic-result.json");
            Program.AtomicWrite(atomicResult, "{\"complete\":true}\n");
            using (var result = JsonDocument.Parse(File.ReadAllText(atomicResult)))
            {
                Program.Require(result.RootElement.GetProperty("complete").GetBoolean(),
                    "Atomic neural result write failed.");
            }
            Program.Require(!Directory.EnumerateFiles(root, $".{Path.GetFileName(atomicResult)}.*.tmp").Any(),
                "Atomic neural result left a temporary file.");
            cases++;

            var duplicateAssets = Path.Combine(root, "duplicate-assets.tsv");
            File.WriteAllText(duplicateAssets,
                $"0000000000000001\t101\t1001\t\"a.wav\"{Environment.NewLine}"
                + $"0000000000000001\t101\t1001\t\"b.wav\"{Environment.NewLine}");
            ExpectInvalidData(() => ReadAssets(duplicateAssets), "Duplicate requested signature was accepted.");
            cases++;

            return new { result = "passed", cases };
        }
        finally
        {
            if (Directory.Exists(root))
            {
                Directory.Delete(root, true);
            }
        }
    }

    private static int RunBuildCache(Program.ModelBundle model, JobRequest request)
    {
        Program.Require(request.AssetsFile is not null, "build-cache requires assetsFile.");
        var assets = ReadAssets(request.AssetsFile!);
        var outputPaths = new[] { request.CachePath, request.StatusPath, request.ResultPath };
        foreach (var asset in assets)
        {
            Program.Require(!outputPaths.Contains(asset.Path, StringComparer.OrdinalIgnoreCase),
                $"Neural job output must not overwrite source audio: {asset.Path}");
        }

        Dictionary<string, CacheRecord> oldCache;
        string? rejectedCacheError = null;
        if (File.Exists(request.CachePath))
        {
            try
            {
                oldCache = ReadCache(request.CachePath, model);
            }
            catch (Exception error) when (error is InvalidDataException or EndOfStreamException or OverflowException)
            {
                rejectedCacheError = error.Message;
                oldCache = new Dictionary<string, CacheRecord>(StringComparer.Ordinal);
            }
        }
        else
        {
            oldCache = new Dictionary<string, CacheRecord>(StringComparer.Ordinal);
        }
        var output = new List<CacheRecord>(assets.Count);
        var reused = 0;
        var embedded = 0;
        var failed = 0;
        var failures = new List<object>();
        InferenceSession? session = null;
        try
        {
            WriteStatus(request, "running", "building-cache", 0, assets.Count, false, null);
            if (IsCancelled(request))
            {
                return FinishCancelledBuild(request, assets.Count, 0, reused, embedded, failed);
            }

            for (var index = 0; index < assets.Count; index++)
            {
                var asset = assets[index];
                if (oldCache.TryGetValue(asset.Signature, out var existing)
                    && CanReuse(existing, asset.Size, asset.MtimeUtcTicks))
                {
                    output.Add(existing);
                    reused++;
                }
                else
                {
                    try
                    {
                        ValidateAssetFile(asset);
                        session ??= Program.CreateSession(model.ModelPath);
                        var samples = Program.WavePcm16.ReadMono32k(asset.Path);
                        Program.Require(samples.Length >= Program.MinimumSamples,
                            $"Audio is too short; at least {Program.MinimumSamples} samples are required.");
                        ValidateAssetFile(asset);
                        var vector = Program.RunSceneEmbedding(session, samples, model.Dimensions);
                        ValidateAssetFile(asset);
                        output.Add(new CacheRecord(asset.Signature, asset.Size, asset.MtimeUtcTicks, ToHalf(vector)));
                        embedded++;
                    }
                    catch (Exception error)
                    {
                        failed++;
                        if (failures.Count < 100)
                        {
                            failures.Add(new { asset.Signature, error = error.Message });
                        }
                    }
                }

                var completed = index + 1;
                if (completed == assets.Count || completed % 32 == 0)
                {
                    WriteStatus(request, "running", "building-cache", completed, assets.Count, false, null);
                }
                if (IsCancelled(request))
                {
                    return FinishCancelledBuild(request, assets.Count, completed, reused, embedded, failed);
                }
            }
        }
        finally
        {
            session?.Dispose();
        }

        output.Sort((left, right) => string.CompareOrdinal(left.Signature, right.Signature));
        WriteCacheAtomic(request.CachePath, model, output);
        var cacheHash = Program.HashFile(request.CachePath);
        WriteResult(request, new
        {
            requested = assets.Count,
            written = output.Count,
            reused,
            embedded,
            failed,
            cancelled = false,
            cacheSha256 = cacheHash,
            rejectedCacheError,
            failures,
        });
        WriteStatus(request, "completed", "completed", assets.Count, assets.Count, false, null);
        return 0;
    }

    private static int FinishCancelledBuild(
        JobRequest request,
        int requested,
        int completed,
        int reused,
        int embedded,
        int failed)
    {
        WriteResult(request, new
        {
            requested,
            written = 0,
            reused,
            embedded,
            failed,
            cancelled = true,
            cacheSha256 = (string?)null,
        });
        WriteStatus(request, "cancelled", "cancelled", completed, requested, true, null);
        return 0;
    }

    private static int RunQuery(Program.ModelBundle model, JobRequest request)
    {
        Program.Require(request.ReferenceSignature is not null, "query requires referenceSignature.");
        var referenceSignature = request.ReferenceSignature!;
        ValidateSignature(referenceSignature);
        Program.Require(request.TopK is >= 1 and <= MaximumTopK,
            $"query topK must be between 1 and {MaximumTopK}.");

        var cache = ReadCache(request.CachePath, model);
        HashSet<string>? candidates = null;
        if (request.CandidateSignaturesFile is not null)
        {
            candidates = ReadCandidates(request.CandidateSignaturesFile);
            if (candidates.Count == 0)
            {
                candidates = null;
            }
        }
        Program.Require(cache.ContainsKey(referenceSignature),
            $"Reference signature is not present in the neural cache: {referenceSignature}");

        if (IsCancelled(request))
        {
            WriteResult(request, new { referenceSignature, cancelled = true, matches = Array.Empty<object>() });
            WriteStatus(request, "cancelled", "cancelled", 0, candidates?.Count ?? cache.Count, true, null);
            return 0;
        }

        var scanned = 0;
        var totalCandidates = candidates?.Count ?? cache.Count;
        WriteStatus(request, "running", "querying", 0, totalCandidates, false, null);
        var matches = Rank(cache, referenceSignature, candidates, request.TopK,
            () =>
            {
                scanned++;
                if (scanned % 4_096 == 0)
                {
                    WriteStatus(request, "running", "querying", scanned, totalCandidates, false, null);
                    return IsCancelled(request);
                }
                return false;
            });
        if (IsCancelled(request))
        {
            WriteResult(request, new { referenceSignature, cancelled = true, matches = Array.Empty<object>() });
            WriteStatus(request, "cancelled", "cancelled", scanned, totalCandidates, true, null);
            return 0;
        }

        var missing = candidates?.Count(signature => !cache.ContainsKey(signature)) ?? 0;
        WriteResult(request, new
        {
            referenceSignature,
            requestedCandidates = totalCandidates,
            availableCandidates = totalCandidates - missing,
            missingCandidates = missing,
            topK = request.TopK,
            cancelled = false,
            matches = matches.Select(match => new { signature = match.Signature, score = match.Score }),
        });
        WriteStatus(request, "completed", "completed", scanned, totalCandidates, false, null);
        return 0;
    }

    private static List<QueryMatch> Rank(
        IReadOnlyDictionary<string, CacheRecord> cache,
        string referenceSignature,
        HashSet<string>? candidates,
        int topK,
        Func<bool>? shouldCancel)
    {
        var reference = cache[referenceSignature].Embedding;
        var referenceNorm = VectorNorm(reference);
        var queue = new PriorityQueue<QueryMatch, QueryMatch>(new WorstMatchComparer());
        IEnumerable<string> signatures = candidates is null ? cache.Keys : candidates;
        foreach (var signature in signatures)
        {
            if (shouldCancel?.Invoke() == true)
            {
                break;
            }
            if (signature == referenceSignature || !cache.TryGetValue(signature, out var candidate))
            {
                continue;
            }

            double dot = 0;
            double candidateSquared = 0;
            for (var index = 0; index < reference.Length; index++)
            {
                var value = (float)candidate.Embedding[index];
                dot += (float)reference[index] * value;
                candidateSquared += value * value;
            }
            var score = (float)(dot / (referenceNorm * Math.Sqrt(candidateSquared)));
            Program.Require(float.IsFinite(score), $"Neural cosine is invalid for signature: {signature}");
            var match = new QueryMatch(signature, score);
            queue.Enqueue(match, match);
            if (queue.Count > topK)
            {
                queue.Dequeue();
            }
        }

        var matches = new List<QueryMatch>(queue.Count);
        while (queue.TryDequeue(out var match, out _))
        {
            matches.Add(match);
        }
        matches.Sort((left, right) =>
        {
            var score = right.Score.CompareTo(left.Score);
            return score != 0 ? score : string.CompareOrdinal(left.Signature, right.Signature);
        });
        return matches;
    }

    private static double VectorNorm(Half[] embedding)
    {
        double squared = 0;
        foreach (var half in embedding)
        {
            var value = (float)half;
            squared += value * value;
        }
        var norm = Math.Sqrt(squared);
        Program.Require(norm > 1e-12 && double.IsFinite(norm), "Neural cache vector norm is invalid.");
        return norm;
    }

    private static Dictionary<string, CacheRecord> ReadCache(string path, Program.ModelBundle model)
    {
        using var stream = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.Read);
        using var reader = new BinaryReader(stream, Encoding.UTF8, leaveOpen: true);
        Program.Require(Encoding.ASCII.GetString(reader.ReadBytes(8)) == CacheMagic, "Neural cache magic mismatch.");
        Program.Require(reader.ReadUInt32() == CacheVersion, "Unsupported neural cache version.");
        var dimensions = reader.ReadUInt32();
        Program.Require(dimensions == model.Dimensions, "Neural cache dimensions mismatch.");
        var count = reader.ReadUInt32();
        Program.Require(count <= int.MaxValue, "Neural cache record count is too large.");
        var profileLength = reader.ReadUInt16();
        Program.Require(profileLength > 0, "Neural cache profile is missing.");
        var profile = Encoding.UTF8.GetString(ReadExactly(reader, profileLength));
        Program.Require(profile == model.Profile, "Neural cache profile mismatch.");
        var modelHash = Convert.ToHexString(ReadExactly(reader, 32)).ToLowerInvariant();
        Program.Require(modelHash == Program.ExpectedModelSha256, "Neural cache model hash mismatch.");

        var recordBytes = SignatureLength + sizeof(long) + sizeof(long) + model.Dimensions * sizeof(ushort);
        var expectedLength = checked(stream.Position + (long)count * recordBytes);
        Program.Require(stream.Length == expectedLength, "Neural cache length mismatch.");
        var records = new Dictionary<string, CacheRecord>((int)count, StringComparer.Ordinal);
        for (var recordIndex = 0; recordIndex < count; recordIndex++)
        {
            var signature = Encoding.ASCII.GetString(ReadExactly(reader, SignatureLength));
            ValidateSignature(signature);
            var size = reader.ReadInt64();
            var mtime = reader.ReadInt64();
            Program.Require(size >= 0 && mtime >= 0, "Neural cache metadata is invalid.");
            var embedding = new Half[model.Dimensions];
            for (var index = 0; index < embedding.Length; index++)
            {
                embedding[index] = BitConverter.UInt16BitsToHalf(reader.ReadUInt16());
                Program.Require(Half.IsFinite(embedding[index]), "Neural cache contains a non-finite value.");
            }
            Program.Require(records.TryAdd(signature, new CacheRecord(signature, size, mtime, embedding)),
                $"Duplicate neural cache signature: {signature}");
        }
        return records;
    }

    private static void WriteCacheAtomic(
        string path,
        Program.ModelBundle model,
        IReadOnlyCollection<CacheRecord> records)
    {
        var directory = Path.GetDirectoryName(path)
            ?? throw new InvalidOperationException("Neural cache path must include a directory.");
        Directory.CreateDirectory(directory);
        var temporary = Path.Combine(directory, $".{Path.GetFileName(path)}.{Guid.NewGuid():N}.tmp");
        try
        {
            WriteCacheUnchecked(temporary, model, records);
            File.Move(temporary, path, true);
        }
        finally
        {
            if (File.Exists(temporary))
            {
                File.Delete(temporary);
            }
        }
    }

    private static void WriteCacheUnchecked(
        string path,
        Program.ModelBundle model,
        IReadOnlyCollection<CacheRecord> records)
    {
        using var stream = File.Open(path, FileMode.CreateNew, FileAccess.Write, FileShare.None);
        using var writer = new BinaryWriter(stream, Encoding.UTF8, leaveOpen: false);
        writer.Write(Encoding.ASCII.GetBytes(CacheMagic));
        writer.Write(CacheVersion);
        writer.Write((uint)model.Dimensions);
        writer.Write((uint)records.Count);
        var profile = Encoding.UTF8.GetBytes(model.Profile);
        Program.Require(profile.Length <= ushort.MaxValue, "Neural cache profile is too long.");
        writer.Write((ushort)profile.Length);
        writer.Write(profile);
        writer.Write(Convert.FromHexString(Program.ExpectedModelSha256));
        foreach (var record in records)
        {
            ValidateSignature(record.Signature);
            Program.Require(record.Embedding.Length == model.Dimensions, "Neural cache vector dimension mismatch.");
            writer.Write(Encoding.ASCII.GetBytes(record.Signature));
            writer.Write(record.Size);
            writer.Write(record.MtimeUtcTicks);
            foreach (var value in record.Embedding)
            {
                Program.Require(Half.IsFinite(value), "Neural cache contains a non-finite value.");
                writer.Write(BitConverter.HalfToUInt16Bits(value));
            }
        }
        writer.Flush();
        stream.Flush(true);
    }

    private static List<AssetRequest> ReadAssets(string path)
    {
        var fullPath = Path.GetFullPath(path);
        var directory = Path.GetDirectoryName(fullPath)
            ?? throw new InvalidOperationException("Assets TSV path must include a directory.");
        var assets = new List<AssetRequest>();
        var signatures = new HashSet<string>(StringComparer.Ordinal);
        var lineNumber = 0;
        foreach (var line in File.ReadLines(fullPath, Encoding.UTF8))
        {
            lineNumber++;
            if (string.IsNullOrWhiteSpace(line))
            {
                continue;
            }
            var fields = line.Split('\t', 4);
            Program.Require(fields.Length == 4, $"Invalid assets TSV line {lineNumber}.");
            ValidateSignature(fields[0]);
            Program.Require(signatures.Add(fields[0]), $"Duplicate requested signature: {fields[0]}");
            Program.Require(long.TryParse(fields[1], out var size) && size >= 0,
                $"Invalid asset size on line {lineNumber}.");
            Program.Require(long.TryParse(fields[2], out var mtime) && mtime >= 0,
                $"Invalid asset mtime on line {lineNumber}.");
            var assetPath = JsonSerializer.Deserialize<string>(fields[3]);
            Program.Require(!string.IsNullOrWhiteSpace(assetPath), $"Invalid asset path on line {lineNumber}.");
            var decodedPath = assetPath!;
            assets.Add(new AssetRequest(fields[0], size, mtime,
                Path.GetFullPath(Path.IsPathRooted(decodedPath) ? decodedPath : Path.Combine(directory, decodedPath))));
        }
        return assets;
    }

    private static HashSet<string> ReadCandidates(string path)
    {
        var candidates = new HashSet<string>(StringComparer.Ordinal);
        foreach (var raw in File.ReadLines(path, Encoding.UTF8))
        {
            var signature = raw.Trim();
            if (signature.Length == 0)
            {
                continue;
            }
            ValidateSignature(signature);
            candidates.Add(signature);
        }
        return candidates;
    }

    private static bool CanReuse(CacheRecord record, long size, long mtimeUtcTicks) =>
        record.Size == size && record.MtimeUtcTicks == mtimeUtcTicks;

    private static void ValidateAssetFile(AssetRequest asset)
    {
        var info = new FileInfo(asset.Path);
        Program.Require(info.Exists, $"Audio file is unavailable: {asset.Path}");
        Program.Require(info.Length == asset.Size, $"Audio file size changed: {asset.Path}");
        Program.Require(info.LastWriteTimeUtc.Ticks == asset.MtimeUtcTicks,
            $"Audio file modification time changed: {asset.Path}");
    }

    private static Half[] ToHalf(float[] values)
    {
        var result = new Half[values.Length];
        for (var index = 0; index < values.Length; index++)
        {
            result[index] = (Half)values[index];
            Program.Require(Half.IsFinite(result[index]), "Embedding cannot be represented as FP16.");
        }
        return result;
    }

    private static float[] UnitVector(int dimensions, int index)
    {
        var vector = new float[dimensions];
        vector[index] = 1;
        return vector;
    }

    private static float[] TwoValueUnitVector(int dimensions, int first, int second)
    {
        var vector = new float[dimensions];
        var value = MathF.Sqrt(0.5f);
        vector[first] = value;
        vector[second] = value;
        return vector;
    }

    private static byte[] ReadExactly(BinaryReader reader, int count)
    {
        var bytes = reader.ReadBytes(count);
        Program.Require(bytes.Length == count, "Neural cache is truncated.");
        return bytes;
    }

    private static void ValidateSignature(string signature)
    {
        Program.Require(signature.Length == SignatureLength
            && signature.All(character => character is >= '0' and <= '9' or >= 'a' and <= 'f'),
            $"Invalid neural asset signature: {signature}");
    }

    private static bool IsCancelled(JobRequest request) =>
        request.CancelPath is not null && File.Exists(request.CancelPath);

    private static void ValidateWritablePaths(string modelDirectory, string requestPath, JobRequest request)
    {
        var outputs = new[] { request.CachePath, request.StatusPath, request.ResultPath };
        Program.Require(outputs.Distinct(StringComparer.OrdinalIgnoreCase).Count() == outputs.Length,
            "Neural cache, status, and result paths must be distinct.");
        var modelRoot = Path.GetFullPath(modelDirectory).TrimEnd(Path.DirectorySeparatorChar)
            + Path.DirectorySeparatorChar;
        foreach (var path in outputs)
        {
            Program.Require(!path.StartsWith(modelRoot, StringComparison.OrdinalIgnoreCase),
                "Neural job output must not be written into the read-only model directory.");
            Program.Require(!string.Equals(path, requestPath, StringComparison.OrdinalIgnoreCase),
                "Neural job output must not overwrite its request file.");
        }
        foreach (var input in new[] { request.AssetsFile, request.CandidateSignaturesFile })
        {
            if (input is not null)
            {
                Program.Require(!outputs.Contains(input, StringComparer.OrdinalIgnoreCase),
                    "Neural job output must not overwrite an input list.");
            }
        }
        if (request.CancelPath is not null)
        {
            Program.Require(!outputs.Contains(request.CancelPath, StringComparer.OrdinalIgnoreCase),
                "Neural job cancel path must be distinct from output paths.");
            Program.Require(!string.Equals(request.CancelPath, requestPath, StringComparison.OrdinalIgnoreCase),
                "Neural job cancel path must not overwrite its request file.");
        }
    }

    private static void WriteStatus(
        JobRequest request,
        string state,
        string phase,
        int completed,
        int total,
        bool cancelled,
        string? error)
    {
        Program.AtomicWrite(request.StatusPath, JsonSerializer.Serialize(new
        {
            schema = StatusSchema,
            sidecarVersion = Program.SidecarVersion,
            request.RequestId,
            request.Operation,
            state,
            phase,
            completed,
            total,
            cancelled,
            error,
            updatedUtc = DateTimeOffset.UtcNow,
        }, JsonOptions) + Environment.NewLine);
    }

    private static void WriteResult(JobRequest request, object payload)
    {
        var result = new JsonObject
        {
            ["schema"] = ResultSchema,
            ["sidecarVersion"] = Program.SidecarVersion,
            ["requestId"] = request.RequestId,
            ["operation"] = request.Operation,
            ["profile"] = Program.ExpectedProfile,
            ["dimensions"] = Program.ExpectedDimensions,
        };
        var payloadObject = JsonSerializer.SerializeToNode(payload, JsonOptions)?.AsObject()
            ?? throw new InvalidDataException("Neural job result payload must be a JSON object.");
        foreach (var property in payloadObject)
        {
            Program.Require(!result.ContainsKey(property.Key), $"Reserved neural result property: {property.Key}");
            result[property.Key] = property.Value?.DeepClone();
        }
        Program.AtomicWrite(request.ResultPath, result.ToJsonString(JsonOptions) + Environment.NewLine);
    }

    private static void ExpectInvalidData(Action action, string message)
    {
        try
        {
            action();
        }
        catch (InvalidDataException)
        {
            return;
        }
        throw new InvalidDataException(message);
    }

    private static JobRequest CreateSelfTestRequest(
        string root,
        string name,
        string cachePath,
        string assetsFile) => new(
            "self-test",
            "build-cache",
            cachePath,
            Path.Combine(root, $"{name}-status.json"),
            Path.Combine(root, $"{name}-result.json"),
            Path.Combine(root, $"{name}-cancel"),
            assetsFile,
            null,
            null,
            200);

    private sealed record AssetRequest(string Signature, long Size, long MtimeUtcTicks, string Path);

    private sealed record CacheRecord(string Signature, long Size, long MtimeUtcTicks, Half[] Embedding);

    private sealed record QueryMatch(string Signature, float Score);

    private sealed class WorstMatchComparer : IComparer<QueryMatch>
    {
        public int Compare(QueryMatch? left, QueryMatch? right)
        {
            if (ReferenceEquals(left, right))
            {
                return 0;
            }
            if (left is null)
            {
                return -1;
            }
            if (right is null)
            {
                return 1;
            }
            var score = left.Score.CompareTo(right.Score);
            return score != 0 ? score : string.CompareOrdinal(right.Signature, left.Signature);
        }
    }

    private sealed record JobRequest(
        string RequestId,
        string Operation,
        string CachePath,
        string StatusPath,
        string ResultPath,
        string? CancelPath,
        string? AssetsFile,
        string? CandidateSignaturesFile,
        string? ReferenceSignature,
        int TopK)
    {
        public static JobRequest Load(string requestPath)
        {
            using var document = JsonDocument.Parse(File.ReadAllText(requestPath));
            var root = document.RootElement;
            Program.Require(root.ValueKind == JsonValueKind.Object, "Neural job request must be a JSON object.");
            Program.Require(GetRequiredString(root, "schema") == JobSchema, "Unsupported neural job schema.");
            var requestDirectory = Path.GetDirectoryName(requestPath)
                ?? throw new InvalidOperationException("Neural job request path must include a directory.");
            var requestId = GetRequiredString(root, "requestId");
            Program.Require(requestId.Length <= 128, "Neural job requestId is too long.");
            var operation = GetRequiredString(root, "operation");
            var cachePath = ResolvePath(requestDirectory, GetRequiredString(root, "cachePath"));
            var statusPath = ResolvePath(requestDirectory, GetRequiredString(root, "statusPath"));
            var resultPath = ResolvePath(requestDirectory, GetRequiredString(root, "resultPath"));
            var cancelPath = GetOptionalString(root, "cancelPath");
            var assetsFile = GetOptionalString(root, "assetsFile");
            var candidatesFile = GetOptionalString(root, "candidateSignaturesFile");
            var referenceSignature = GetOptionalString(root, "referenceSignature");
            var topK = root.TryGetProperty("topK", out var topKElement) ? topKElement.GetInt32() : 200;
            return new JobRequest(
                requestId,
                operation,
                cachePath,
                statusPath,
                resultPath,
                cancelPath is null ? null : ResolvePath(requestDirectory, cancelPath),
                assetsFile is null ? null : ResolvePath(requestDirectory, assetsFile),
                candidatesFile is null ? null : ResolvePath(requestDirectory, candidatesFile),
                referenceSignature,
                topK);
        }

        private static string GetRequiredString(JsonElement root, string name)
        {
            Program.Require(root.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String,
                $"Neural job request requires string property: {name}");
            var text = value.GetString();
            Program.Require(!string.IsNullOrWhiteSpace(text), $"Neural job request property is empty: {name}");
            return text!;
        }

        private static string? GetOptionalString(JsonElement root, string name)
        {
            if (!root.TryGetProperty(name, out var value) || value.ValueKind == JsonValueKind.Null)
            {
                return null;
            }
            Program.Require(value.ValueKind == JsonValueKind.String, $"Neural job request property must be a string: {name}");
            var text = value.GetString();
            return string.IsNullOrWhiteSpace(text) ? null : text;
        }

        private static string ResolvePath(string directory, string path) =>
            Path.GetFullPath(Path.IsPathRooted(path) ? path : Path.Combine(directory, path));
    }
}
