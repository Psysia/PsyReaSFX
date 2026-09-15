using System.Security.Cryptography;
using System.Text;
using System.Buffers.Binary;

namespace PsyReaSFX.NeuralSidecar;

internal static partial class NeuralJobs
{
    private const string HnswMagic = "PSYHNSW1";
    private const uint HnswVersion = 1;
    private const int MaximumHnswLevel = 32;
    private const int MaximumEf = 10_000;

    private static int RunBuildIndex(Program.ModelBundle model, JobRequest request)
    {
        Program.Require(request.IndexPath is not null, "build-index requires indexPath.");
        Program.Require(request.M is >= 4 and <= 64, "build-index m must be between 4 and 64.");
        Program.Require(request.EfConstruction >= request.M && request.EfConstruction <= MaximumEf,
            $"build-index efConstruction must be between m and {MaximumEf}.");

        var cacheHash = Program.HashFile(request.CachePath);
        var cache = ReadCache(request.CachePath, model);
        Program.Require(Program.HashFile(request.CachePath) == cacheHash,
            "Embedding cache changed while it was being loaded.");
        WriteStatus(request, "running", "building-index", 0, cache.Count, false, null);
        if (IsCancelled(request))
        {
            return FinishCancelledIndex(request, cache.Count, 0);
        }

        var completed = 0;
        var graph = BuildHnsw(cache, request.M, request.EfConstruction, (current, total) =>
        {
            completed = current;
            if (current == total || current % 32 == 0)
            {
                WriteStatus(request, "running", "building-index", current, total, false, null);
            }
            return IsCancelled(request);
        });
        if (graph is null)
        {
            return FinishCancelledIndex(request, cache.Count, completed);
        }

        Program.Require(Program.HashFile(request.CachePath) == cacheHash,
            "Embedding cache changed while the HNSW index was being built.");
        WriteHnswAtomic(request.IndexPath!, model, cacheHash, graph);
        var indexHash = Program.HashFile(request.IndexPath!);
        WriteResult(request, new
        {
            records = graph.Nodes.Length,
            graph.M,
            graph.EfConstruction,
            graph.MaxLevel,
            graph.EntryPoint,
            cacheSha256 = cacheHash,
            indexSha256 = indexHash,
            cancelled = false,
        });
        WriteStatus(request, "completed", "completed", cache.Count, cache.Count, false, null);
        return 0;
    }

    private static int FinishCancelledIndex(JobRequest request, int total, int completed)
    {
        WriteResult(request, new
        {
            records = 0,
            cacheSha256 = (string?)null,
            indexSha256 = (string?)null,
            cancelled = true,
        });
        WriteStatus(request, "cancelled", "cancelled", completed, total, true, null);
        return 0;
    }

    private static HnswGraph? BuildHnsw(
        IReadOnlyDictionary<string, CacheRecord> cache,
        int m,
        int efConstruction,
        Func<int, int, bool>? progress)
    {
        var records = cache.Values.OrderBy(record => record.Signature, StringComparer.Ordinal).ToArray();
        var nodes = new HnswNode[records.Length];
        for (var id = 0; id < records.Length; id++)
        {
            var level = DeterministicLevel(records[id].Signature, m);
            nodes[id] = new HnswNode(records[id], level);
        }
        var graph = new HnswGraph(m, efConstruction, -1, -1, nodes);

        for (var id = 0; id < nodes.Length; id++)
        {
            var node = nodes[id];
            if (graph.EntryPoint < 0)
            {
                graph.EntryPoint = id;
                graph.MaxLevel = node.Level;
            }
            else
            {
                var entry = graph.EntryPoint;
                for (var level = graph.MaxLevel; level > node.Level; level--)
                {
                    entry = GreedySearch(graph, node.Record.Embedding, entry, level, id);
                }

                for (var level = Math.Min(node.Level, graph.MaxLevel); level >= 0; level--)
                {
                    var nearest = SearchLayer(graph, node.Record.Embedding, new[] { entry },
                        efConstruction, level, id, null);
                    var selected = nearest.Take(m).Select(candidate => candidate.Id).ToArray();
                    foreach (var neighbor in selected)
                    {
                        node.Neighbors[level].Add(neighbor);
                        nodes[neighbor].Neighbors[level].Add(id);
                        PruneConnections(graph, neighbor, level, m, id + 1);
                    }
                    if (nearest.Count > 0)
                    {
                        entry = nearest[0].Id;
                    }
                }

                if (node.Level > graph.MaxLevel)
                {
                    graph.EntryPoint = id;
                    graph.MaxLevel = node.Level;
                }
            }

            if (progress?.Invoke(id + 1, nodes.Length) == true)
            {
                return null;
            }
        }
        return graph;
    }

    private static List<QueryMatch> QueryHnsw(
        HnswGraph graph,
        IReadOnlyDictionary<string, CacheRecord> cache,
        string referenceSignature,
        int topK,
        int efSearch,
        Func<bool>? shouldCancel)
    {
        Program.Require(efSearch is >= 1 and <= MaximumEf,
            $"query efSearch must be between 1 and {MaximumEf}.");
        if (graph.EntryPoint < 0)
        {
            return new List<QueryMatch>();
        }
        var query = cache[referenceSignature].Embedding;
        var entry = graph.EntryPoint;
        for (var level = graph.MaxLevel; level > 0; level--)
        {
            entry = GreedySearch(graph, query, entry, level, graph.Nodes.Length);
        }
        var nearest = SearchLayer(graph, query, new[] { entry }, Math.Max(efSearch, topK + 1),
            0, graph.Nodes.Length, shouldCancel);
        return nearest
            .Where(candidate => graph.Nodes[candidate.Id].Record.Signature != referenceSignature)
            .Take(topK)
            .Select(candidate => new QueryMatch(
                graph.Nodes[candidate.Id].Record.Signature,
                1f - candidate.Distance))
            .ToList();
    }

    private static int GreedySearch(HnswGraph graph, Half[] query, int entry, int level, int activeCount)
    {
        var current = entry;
        var currentDistance = CosineDistance(query, graph.Nodes[current].Record.Embedding);
        var changed = true;
        while (changed)
        {
            changed = false;
            foreach (var neighbor in graph.Nodes[current].Neighbors[level])
            {
                if (neighbor >= activeCount)
                {
                    continue;
                }
                var distance = CosineDistance(query, graph.Nodes[neighbor].Record.Embedding);
                if (distance < currentDistance || distance == currentDistance && neighbor < current)
                {
                    current = neighbor;
                    currentDistance = distance;
                    changed = true;
                }
            }
        }
        return current;
    }

    private static List<NodeDistance> SearchLayer(
        HnswGraph graph,
        Half[] query,
        IEnumerable<int> entryPoints,
        int ef,
        int level,
        int activeCount,
        Func<bool>? shouldCancel)
    {
        var visited = new HashSet<int>();
        var candidates = new PriorityQueue<int, (float Distance, int Id)>();
        var results = new PriorityQueue<int, (float NegativeDistance, int NegativeId)>();
        foreach (var entry in entryPoints)
        {
            if (entry < 0 || entry >= activeCount || !visited.Add(entry))
            {
                continue;
            }
            var distance = CosineDistance(query, graph.Nodes[entry].Record.Embedding);
            candidates.Enqueue(entry, (distance, entry));
            results.Enqueue(entry, (-distance, -entry));
        }

        while (candidates.TryDequeue(out var current, out var candidatePriority))
        {
            if (shouldCancel?.Invoke() == true)
            {
                break;
            }
            results.TryPeek(out var worstId, out var worstPriority);
            var worstDistance = -worstPriority.NegativeDistance;
            if (results.Count >= ef && candidatePriority.Distance > worstDistance)
            {
                break;
            }

            foreach (var neighbor in graph.Nodes[current].Neighbors[level])
            {
                if (neighbor >= activeCount || !visited.Add(neighbor))
                {
                    continue;
                }
                var distance = CosineDistance(query, graph.Nodes[neighbor].Record.Embedding);
                results.TryPeek(out worstId, out worstPriority);
                worstDistance = -worstPriority.NegativeDistance;
                if (results.Count < ef
                    || distance < worstDistance
                    || distance == worstDistance && neighbor < worstId)
                {
                    candidates.Enqueue(neighbor, (distance, neighbor));
                    results.Enqueue(neighbor, (-distance, -neighbor));
                    if (results.Count > ef)
                    {
                        results.Dequeue();
                    }
                }
            }
        }

        var ordered = new List<NodeDistance>(results.Count);
        while (results.TryDequeue(out var id, out var priority))
        {
            ordered.Add(new NodeDistance(id, -priority.NegativeDistance));
        }
        ordered.Sort((left, right) =>
        {
            var distance = left.Distance.CompareTo(right.Distance);
            return distance != 0 ? distance : left.Id.CompareTo(right.Id);
        });
        return ordered;
    }

    private static void PruneConnections(HnswGraph graph, int nodeId, int level, int m, int activeCount)
    {
        var neighbors = graph.Nodes[nodeId].Neighbors[level];
        if (neighbors.Count <= m)
        {
            return;
        }
        var vector = graph.Nodes[nodeId].Record.Embedding;
        var selected = neighbors
            .Where(id => id < activeCount && id != nodeId)
            .Distinct()
            .Select(id => new NodeDistance(id, CosineDistance(vector, graph.Nodes[id].Record.Embedding)))
            .OrderBy(candidate => candidate.Distance)
            .ThenBy(candidate => candidate.Id)
            .Take(m)
            .Select(candidate => candidate.Id)
            .ToArray();
        neighbors.Clear();
        neighbors.AddRange(selected);
    }

    private static float CosineDistance(Half[] left, Half[] right)
    {
        double dot = 0;
        double leftSquared = 0;
        double rightSquared = 0;
        for (var index = 0; index < left.Length; index++)
        {
            var leftValue = (float)left[index];
            var rightValue = (float)right[index];
            dot += leftValue * rightValue;
            leftSquared += leftValue * leftValue;
            rightSquared += rightValue * rightValue;
        }
        var denominator = Math.Sqrt(leftSquared * rightSquared);
        Program.Require(denominator > 1e-12 && double.IsFinite(denominator), "HNSW vector norm is invalid.");
        var similarity = Math.Clamp(dot / denominator, -1.0, 1.0);
        return (float)(1.0 - similarity);
    }

    private static int DeterministicLevel(string signature, int m)
    {
        var hash = SHA256.HashData(Encoding.ASCII.GetBytes(signature));
        var value = BinaryPrimitives.ReadUInt64LittleEndian(hash);
        var uniform = (value + 1.0) / (ulong.MaxValue + 2.0);
        return Math.Min(MaximumHnswLevel, (int)Math.Floor(-Math.Log(uniform) / Math.Log(m)));
    }

    private static void WriteHnswAtomic(
        string path,
        Program.ModelBundle model,
        string cacheHash,
        HnswGraph graph)
    {
        var directory = Path.GetDirectoryName(path)
            ?? throw new InvalidOperationException("HNSW index path must include a directory.");
        Directory.CreateDirectory(directory);
        var temporary = Path.Combine(directory, $".{Path.GetFileName(path)}.{Guid.NewGuid():N}.tmp");
        try
        {
            WriteHnswUnchecked(temporary, model, cacheHash, graph);
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

    private static void WriteHnswUnchecked(
        string path,
        Program.ModelBundle model,
        string cacheHash,
        HnswGraph graph)
    {
        using var stream = File.Open(path, FileMode.CreateNew, FileAccess.Write, FileShare.None);
        using var writer = new BinaryWriter(stream, Encoding.UTF8, leaveOpen: false);
        writer.Write(Encoding.ASCII.GetBytes(HnswMagic));
        writer.Write(HnswVersion);
        writer.Write((uint)model.Dimensions);
        writer.Write((uint)graph.Nodes.Length);
        writer.Write((uint)graph.M);
        writer.Write((uint)graph.EfConstruction);
        writer.Write(graph.EntryPoint);
        writer.Write(graph.MaxLevel);
        var profile = Encoding.UTF8.GetBytes(model.Profile);
        writer.Write((ushort)profile.Length);
        writer.Write(profile);
        writer.Write(Convert.FromHexString(Program.ExpectedModelSha256));
        writer.Write(Convert.FromHexString(cacheHash));
        foreach (var node in graph.Nodes)
        {
            writer.Write(Encoding.ASCII.GetBytes(node.Record.Signature));
            writer.Write(node.Level);
            for (var level = 0; level <= node.Level; level++)
            {
                var neighbors = node.Neighbors[level].Order().ToArray();
                writer.Write((ushort)neighbors.Length);
                foreach (var neighbor in neighbors)
                {
                    writer.Write(neighbor);
                }
            }
        }
        writer.Flush();
        stream.Flush(true);
    }

    private static HnswGraph ReadHnsw(
        string path,
        Program.ModelBundle model,
        IReadOnlyDictionary<string, CacheRecord> cache,
        string cacheHash)
    {
        using var stream = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.Read);
        using var reader = new BinaryReader(stream, Encoding.UTF8, leaveOpen: true);
        Program.Require(Encoding.ASCII.GetString(ReadExactly(reader, 8)) == HnswMagic, "HNSW index magic mismatch.");
        Program.Require(reader.ReadUInt32() == HnswVersion, "Unsupported HNSW index version.");
        Program.Require(reader.ReadUInt32() == model.Dimensions, "HNSW index dimensions mismatch.");
        var count = reader.ReadUInt32();
        Program.Require(count <= int.MaxValue, "HNSW index record count is too large.");
        Program.Require(count == cache.Count, "HNSW index record count does not match the embedding cache.");
        var m = checked((int)reader.ReadUInt32());
        var efConstruction = checked((int)reader.ReadUInt32());
        Program.Require(m is >= 4 and <= 64, "HNSW index m is invalid.");
        Program.Require(efConstruction >= m && efConstruction <= MaximumEf, "HNSW efConstruction is invalid.");
        var entryPoint = reader.ReadInt32();
        var maxLevel = reader.ReadInt32();
        Program.Require(count == 0 ? entryPoint == -1 && maxLevel == -1 : entryPoint >= 0 && entryPoint < count,
            "HNSW entry point is invalid.");
        Program.Require(maxLevel is >= -1 and <= MaximumHnswLevel, "HNSW maximum level is invalid.");
        var profileLength = reader.ReadUInt16();
        Program.Require(profileLength > 0, "HNSW index profile is missing.");
        var profile = Encoding.UTF8.GetString(ReadExactly(reader, profileLength));
        Program.Require(profile == model.Profile, "HNSW index profile mismatch.");
        var modelHash = Convert.ToHexString(ReadExactly(reader, 32)).ToLowerInvariant();
        Program.Require(modelHash == Program.ExpectedModelSha256, "HNSW index model hash mismatch.");
        var storedCacheHash = Convert.ToHexString(ReadExactly(reader, 32)).ToLowerInvariant();
        Program.Require(storedCacheHash == cacheHash, "HNSW index does not match the embedding cache.");

        var nodes = new HnswNode[count];
        var signatures = new HashSet<string>(StringComparer.Ordinal);
        string? previousSignature = null;
        for (var id = 0; id < count; id++)
        {
            var signature = Encoding.ASCII.GetString(ReadExactly(reader, SignatureLength));
            ValidateSignature(signature);
            Program.Require(previousSignature is null || string.CompareOrdinal(previousSignature, signature) < 0,
                "HNSW signatures are not in deterministic order.");
            previousSignature = signature;
            Program.Require(signatures.Add(signature), $"Duplicate HNSW signature: {signature}");
            Program.Require(cache.TryGetValue(signature, out var record),
                $"HNSW signature is missing from the embedding cache: {signature}");
            var level = reader.ReadInt32();
            Program.Require(level is >= 0 and <= MaximumHnswLevel, "HNSW node level is invalid.");
            Program.Require(level <= maxLevel, "HNSW node level exceeds the declared maximum.");
            var node = new HnswNode(record!, level);
            for (var layer = 0; layer <= level; layer++)
            {
                var neighbors = reader.ReadUInt16();
                Program.Require(neighbors <= m, "HNSW neighbor count exceeds m.");
                var unique = new HashSet<int>();
                for (var neighborIndex = 0; neighborIndex < neighbors; neighborIndex++)
                {
                    var neighbor = reader.ReadInt32();
                    Program.Require(neighbor >= 0 && neighbor < count && neighbor != id,
                        "HNSW neighbor ID is invalid.");
                    Program.Require(unique.Add(neighbor), "HNSW node contains duplicate neighbors.");
                    node.Neighbors[layer].Add(neighbor);
                }
            }
            nodes[id] = node;
        }
        Program.Require(stream.Position == stream.Length, "HNSW index contains trailing data.");
        Program.Require(count == 0 || nodes[entryPoint].Level == maxLevel,
            "HNSW entry point does not match the maximum level.");
        for (var id = 0; id < nodes.Length; id++)
        {
            foreach (var layer in nodes[id].Neighbors.Select((neighbors, level) => (neighbors, level)))
            {
                foreach (var neighbor in layer.neighbors)
                {
                    Program.Require(nodes[neighbor].Level >= layer.level,
                        "HNSW neighbor does not exist at the referenced level.");
                }
            }
        }
        return new HnswGraph(m, efConstruction, entryPoint, maxLevel, nodes);
    }

    private static int RunHnswSelfTest(Program.ModelBundle model, string root)
    {
        var cases = 0;
        var records = CreateHnswSelfTestRecords(model.Dimensions, 1_024);
        var cache = records.ToDictionary(record => record.Signature, StringComparer.Ordinal);
        var cachePath = Path.Combine(root, "hnsw-cache.bin");
        WriteCacheAtomic(cachePath, model, records);
        var cacheHash = Program.HashFile(cachePath);
        var graph = BuildHnsw(cache, 16, 128, null)
            ?? throw new InvalidDataException("HNSW self-test build was cancelled.");
        var indexPath = Path.Combine(root, "hnsw-index.bin");
        WriteHnswAtomic(indexPath, model, cacheHash, graph);
        var loaded = ReadHnsw(indexPath, model, cache, cacheHash);
        Program.Require(loaded.Nodes.Length == records.Length && loaded.EntryPoint >= 0,
            "HNSW persistence round-trip failed.");
        cases++;

        var recallSum = 0.0;
        var minimumRecall = 1.0;
        foreach (var referenceId in Enumerable.Range(0, 16).Select(index => index * 61 + 17))
        {
            var reference = records[referenceId].Signature;
            var exact = Rank(cache, reference, null, 20, null);
            var approximate = QueryHnsw(loaded, cache, reference, 20, 128, null);
            var recalled = approximate.Select(match => match.Signature)
                .Intersect(exact.Select(match => match.Signature), StringComparer.Ordinal).Count();
            var recall = recalled / 20.0;
            recallSum += recall;
            minimumRecall = Math.Min(minimumRecall, recall);
        }
        var averageRecall = recallSum / 16;
        Program.Require(averageRecall >= 0.95 && minimumRecall >= 0.80,
            $"HNSW self-test Recall@20 is too low: average {averageRecall:P1}, minimum {minimumRecall:P1}");
        cases++;

        var secondPath = Path.Combine(root, "hnsw-index-second.bin");
        WriteHnswAtomic(secondPath, model, cacheHash, graph);
        Program.Require(Program.HashFile(indexPath) == Program.HashFile(secondPath),
            "HNSW serialization is not deterministic.");
        cases++;

        var truncated = Path.Combine(root, "hnsw-truncated.bin");
        var bytes = File.ReadAllBytes(indexPath);
        File.WriteAllBytes(truncated, bytes[..^1]);
        ExpectInvalidData(() => ReadHnsw(truncated, model, cache, cacheHash),
            "Truncated HNSW index was accepted.");
        cases++;

        ExpectInvalidData(() => ReadHnsw(indexPath, model, cache, new string('0', 64)),
            "HNSW index accepted the wrong cache hash.");
        cases++;

        var originalHash = Program.HashFile(indexPath);
        var cancelRequest = new JobRequest(
            "hnsw-self-test",
            "build-index",
            cachePath,
            Path.Combine(root, "hnsw-cancel-status.json"),
            Path.Combine(root, "hnsw-cancel-result.json"),
            Path.Combine(root, "hnsw-cancel"),
            indexPath,
            null,
            null,
            null,
            10,
            16,
            128,
            128,
            "auto");
        File.WriteAllText(cancelRequest.CancelPath!, string.Empty);
        RunBuildIndex(model, cancelRequest);
        Program.Require(Program.HashFile(indexPath) == originalHash,
            "Cancelled HNSW build replaced the previous index.");
        cases++;
        return cases;
    }

    private static CacheRecord[] CreateHnswSelfTestRecords(int dimensions, int count)
    {
        var random = new Random(0x505359);
        var records = new CacheRecord[count];
        for (var id = 0; id < count; id++)
        {
            var vector = new float[dimensions];
            double squared = 0;
            for (var index = 0; index < vector.Length; index++)
            {
                var value = (float)(random.NextDouble() * 2.0 - 1.0);
                vector[index] = value;
                squared += value * value;
            }
            var norm = (float)Math.Sqrt(squared);
            for (var index = 0; index < vector.Length; index++)
            {
                vector[index] /= norm;
            }
            records[id] = new CacheRecord(id.ToString("x16"), id, id, ToHalf(vector));
        }
        return records;
    }

    private sealed class HnswGraph(
        int m,
        int efConstruction,
        int entryPoint,
        int maxLevel,
        HnswNode[] nodes)
    {
        public int M { get; } = m;
        public int EfConstruction { get; } = efConstruction;
        public int EntryPoint { get; set; } = entryPoint;
        public int MaxLevel { get; set; } = maxLevel;
        public HnswNode[] Nodes { get; } = nodes;
    }

    private sealed class HnswNode(CacheRecord record, int level)
    {
        public CacheRecord Record { get; } = record;
        public int Level { get; } = level;
        public List<int>[] Neighbors { get; } = Enumerable.Range(0, level + 1)
            .Select(_ => new List<int>())
            .ToArray();
    }

    private sealed record NodeDistance(int Id, float Distance);
}
