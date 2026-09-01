using System.Collections.Concurrent;
using PsyReaSFX.Data;

namespace PsyReaSFX.Desktop.Services;

public sealed class LibraryIndexer
{
    private readonly ConcurrentBag<FailedScanItem> _failures = [];
    public IReadOnlyList<FailedScanItem> LastFailures => _failures.OrderBy(item => item.Path, StringComparer.OrdinalIgnoreCase).ToArray();

    public async Task<List<AudioAsset>> BuildAsync(
        IEnumerable<LibraryDefinition> libraries,
        IEnumerable<AudioAsset> previous,
        IProgress<(int Count, string File)> progress,
        CancellationToken cancellationToken)
    {
        while (_failures.TryTake(out _)) { }
        var librarySnapshot = libraries.ToArray();
        var previousSnapshot = previous.ToArray();
        var previousMap = previousSnapshot.Where(asset => !string.IsNullOrWhiteSpace(asset.FilePath))
            .GroupBy(asset => asset.FilePath, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase);
        var previousIdentityMap = previousSnapshot
            .Where(asset => !string.IsNullOrWhiteSpace(asset.RootId))
            .Select(asset => new
            {
                Asset = asset,
                Key = PathIdentity.AssetKey(asset.RootId,
                    string.IsNullOrWhiteSpace(asset.RelativePath)
                        ? PathIdentity.RelativeTo(asset.SourcePath, asset.FilePath)
                        : asset.RelativePath)
            })
            .GroupBy(item => item.Key, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(group => group.Key, group => group.First().Asset, StringComparer.OrdinalIgnoreCase);
        var result = new ConcurrentBag<AudioAsset>();
        var files = new List<(LibraryDefinition Library, LibrarySource Source, string Path)>();

        await Task.Run(() =>
        {
            foreach (var library in librarySnapshot)
            foreach (var source in library.Sources.Where(source => source.Enabled))
            {
                cancellationToken.ThrowIfCancellationRequested();
                if (!Directory.Exists(source.Path)) continue;
                try
                {
                    var options = new EnumerationOptions
                    {
                        IgnoreInaccessible = true,
                        RecurseSubdirectories = true,
                        AttributesToSkip = FileAttributes.Hidden | FileAttributes.System,
                        ReturnSpecialDirectories = false
                    };
                    foreach (var path in Directory.EnumerateFiles(source.Path, "*", options))
                    {
                        if (AudioFileReader.SupportedExtensions.Contains(Path.GetExtension(path)))
                            files.Add((library, source, path));
                    }
                }
                catch (Exception exception)
                {
                    _failures.Add(new FailedScanItem(source.Path, exception.Message, DateTimeOffset.UtcNow, 1));
                }
            }
        }, cancellationToken);

        var done = 0;
        await Parallel.ForEachAsync(files, new ParallelOptions
        {
            CancellationToken = cancellationToken,
            MaxDegreeOfParallelism = Math.Clamp(Environment.ProcessorCount / 2, 2, 6)
        }, (entry, token) =>
        {
            token.ThrowIfCancellationRequested();
            try
            {
                var fileInfo = new FileInfo(entry.Path);
                var relativePath = PathIdentity.RelativeTo(entry.Source.Path, entry.Path);
                var identityKey = PathIdentity.AssetKey(entry.Source.Id, relativePath);
                AudioAsset asset;
                previousMap.TryGetValue(entry.Path, out var cached);
                if (cached == null) previousIdentityMap.TryGetValue(identityKey, out cached);
                if (cached != null &&
                    cached.FileSize == fileInfo.Length &&
                    (cached.LastWriteUtcTicks == 0 || cached.LastWriteUtcTicks == fileInfo.LastWriteTimeUtc.Ticks))
                {
                    asset = CloneAsset(cached);
                    asset.AssetId = string.IsNullOrWhiteSpace(asset.AssetId)
                        ? PathIdentity.CreateAssetId(entry.Source.Id, relativePath)
                        : asset.AssetId;
                    asset.FilePath = entry.Path;
                    asset.FileName = Path.GetFileName(entry.Path);
                    asset.RelativePath = relativePath;
                    asset.RelativeFolder = Path.GetDirectoryName(relativePath) ?? "";
                    asset.LibraryName = entry.Library.Name;
                    asset.SourcePath = entry.Source.Path;
                    asset.LibraryId = entry.Library.Id;
                    asset.RootId = entry.Source.Id;
                    asset.LastWriteUtcTicks = fileInfo.LastWriteTimeUtc.Ticks;
                    asset.LastSeenUtc = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
                    asset.ArtworkPath = RelocateRootedPath(asset.ArtworkPath, cached.SourcePath, entry.Source.Path);
                    if (!string.IsNullOrWhiteSpace(entry.Source.ArtworkPath)) asset.ArtworkPath = entry.Source.ArtworkPath;
                }
                else
                {
                    var info = AudioFileReader.ReadInfo(entry.Path);
                    asset = new AudioAsset
                    {
                        AssetId = cached?.AssetId is { Length: > 0 } existingId
                            ? existingId
                            : PathIdentity.CreateAssetId(entry.Source.Id, relativePath),
                        FilePath = entry.Path,
                        RelativePath = relativePath,
                        FileName = Path.GetFileName(entry.Path),
                        LibraryName = entry.Library.Name,
                        SourcePath = entry.Source.Path,
                        RelativeFolder = Path.GetDirectoryName(Path.GetRelativePath(entry.Source.Path, entry.Path)) ?? "",
                        Format = Path.GetExtension(entry.Path).TrimStart('.'),
                        FileSize = fileInfo.Length,
                        LastWriteUtcTicks = fileInfo.LastWriteTimeUtc.Ticks,
                        DurationSeconds = info.Duration,
                        Channels = info.Channels,
                        SampleRate = info.SampleRate,
                        BitDepth = info.BitDepth,
                        ArtworkPath = entry.Source.ArtworkPath,
                        Description = cached?.Description ?? "",
                        Keywords = cached?.Keywords ?? "",
                        CatId = cached?.CatId ?? "",
                        Category = cached?.Category ?? "",
                        Subcategory = cached?.Subcategory ?? "",
                        WorkflowStatus = cached?.WorkflowStatus ?? "none",
                        Marked = cached?.Marked == true,
                        PreviewCount = cached?.PreviewCount ?? 0,
                        LastPreviewed = cached?.LastPreviewed ?? 0,
                        UsedCount = cached?.UsedCount ?? 0,
                        LastUsed = cached?.LastUsed ?? 0,
                        IsFavorite = cached?.IsFavorite == true,
                        IsSessionPlayed = cached?.IsSessionPlayed == true,
                        RootId = entry.Source.Id,
                        LibraryId = entry.Library.Id,
                        LastSeenUtc = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
                        Indexed = true,
                        Ready = info.Duration > 0
                    };
                }
                result.Add(asset);
            }
            catch (Exception exception)
            {
                _failures.Add(new FailedScanItem(entry.Path, exception.Message, DateTimeOffset.UtcNow, 1));
            }
            var count = Interlocked.Increment(ref done);
            if (count % 50 == 0 || count == files.Count) progress.Report((count, entry.Path));
            return ValueTask.CompletedTask;
        });

        var indexed = result.ToList();
        var currentIdentities = indexed.Select(asset => PathIdentity.AssetKey(asset.RootId, asset.RelativePath))
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        var sourcesById = librarySnapshot.SelectMany(library => library.Sources.Select(source => (Library: library, Source: source)))
            .GroupBy(item => item.Source.Id, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase);

        foreach (var old in previousSnapshot.Where(asset => !string.IsNullOrWhiteSpace(asset.RootId)))
        {
            if (!sourcesById.TryGetValue(old.RootId, out var owner)) continue;
            var relative = string.IsNullOrWhiteSpace(old.RelativePath)
                ? PathIdentity.RelativeTo(old.SourcePath, old.FilePath)
                : old.RelativePath;
            if (!currentIdentities.Add(PathIdentity.AssetKey(old.RootId, relative))) continue;
            var missing = CloneAsset(old);
            missing.RelativePath = relative;
            missing.FilePath = PathIdentity.Normalize(Path.Combine(owner.Source.Path, relative));
            missing.FileName = Path.GetFileName(missing.FilePath);
            missing.RelativeFolder = Path.GetDirectoryName(relative) ?? "";
            missing.SourcePath = owner.Source.Path;
            missing.LibraryId = owner.Library.Id;
            missing.LibraryName = owner.Library.Name;
            missing.Ready = false;
            missing.ArtworkPath = RelocateRootedPath(missing.ArtworkPath, old.SourcePath, owner.Source.Path);
            indexed.Add(missing);
        }

        return indexed.OrderBy(a => a.FileName, StringComparer.OrdinalIgnoreCase).ToList();
    }

    private static string RelocateRootedPath(string candidate, string oldRoot, string newRoot)
    {
        if (string.IsNullOrWhiteSpace(candidate) || string.IsNullOrWhiteSpace(oldRoot)) return candidate;
        try
        {
            var relative = Path.GetRelativePath(PathIdentity.Normalize(oldRoot), PathIdentity.Normalize(candidate));
            if (relative == "." || relative.Equals("..", StringComparison.Ordinal)
                || relative.StartsWith(".." + Path.DirectorySeparatorChar, StringComparison.Ordinal)) return candidate;
            return PathIdentity.Normalize(Path.Combine(newRoot, relative));
        }
        catch { return candidate; }
    }

    private static AudioAsset CloneAsset(AudioAsset source) => new()
    {
        AssetId = source.AssetId,
        FilePath = source.FilePath,
        RelativePath = source.RelativePath,
        FileName = source.FileName,
        LibraryName = source.LibraryName,
        SourcePath = source.SourcePath,
        RelativeFolder = source.RelativeFolder,
        Format = source.Format,
        FileSize = source.FileSize,
        LastWriteUtcTicks = source.LastWriteUtcTicks,
        DurationSeconds = source.DurationSeconds,
        Channels = source.Channels,
        SampleRate = source.SampleRate,
        BitDepth = source.BitDepth,
        ArtworkPath = source.ArtworkPath,
        Description = source.Description,
        Keywords = source.Keywords,
        CatId = source.CatId,
        Category = source.Category,
        Subcategory = source.Subcategory,
        WorkflowStatus = source.WorkflowStatus,
        Marked = source.Marked,
        PreviewCount = source.PreviewCount,
        LastPreviewed = source.LastPreviewed,
        Indexed = source.Indexed,
        Ready = source.Ready,
        UsedCount = source.UsedCount,
        LastUsed = source.LastUsed,
        RootId = source.RootId,
        LibraryId = source.LibraryId,
        LastSeenUtc = source.LastSeenUtc,
        IsFavorite = source.IsFavorite,
        IsSessionPlayed = source.IsSessionPlayed,
        UiLanguage = source.UiLanguage
    };
}
