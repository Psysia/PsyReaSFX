using System.Collections.Concurrent;

namespace PsyReaSFX.Desktop.Services;

public sealed class LibraryIndexer
{
    public async Task<List<AudioAsset>> BuildAsync(
        IEnumerable<LibraryDefinition> libraries,
        IEnumerable<AudioAsset> previous,
        IProgress<(int Count, string File)> progress,
        CancellationToken cancellationToken)
    {
        var previousMap = previous.ToDictionary(a => a.FilePath, StringComparer.OrdinalIgnoreCase);
        var result = new ConcurrentBag<AudioAsset>();
        var files = new List<(LibraryDefinition Library, LibrarySource Source, string Path)>();

        await Task.Run(() =>
        {
            foreach (var library in libraries)
            foreach (var source in library.Sources)
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
                catch { }
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
                AudioAsset asset;
                if (previousMap.TryGetValue(entry.Path, out var cached) &&
                    cached.FileSize == fileInfo.Length &&
                    (cached.LastWriteUtcTicks == 0 || cached.LastWriteUtcTicks == fileInfo.LastWriteTimeUtc.Ticks))
                {
                    asset = cached;
                    asset.LibraryName = entry.Library.Name;
                    asset.SourcePath = entry.Source.Path;
                    asset.LibraryId = entry.Library.Id;
                    asset.RootId = entry.Source.Id;
                    asset.LastWriteUtcTicks = fileInfo.LastWriteTimeUtc.Ticks;
                    if (!string.IsNullOrWhiteSpace(entry.Source.ArtworkPath)) asset.ArtworkPath = entry.Source.ArtworkPath;
                }
                else
                {
                    var info = AudioFileReader.ReadInfo(entry.Path);
                    asset = new AudioAsset
                    {
                        FilePath = entry.Path,
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
                        RootId = entry.Source.Id,
                        LibraryId = entry.Library.Id,
                        Indexed = true,
                        Ready = info.Duration > 0
                    };
                }
                result.Add(asset);
            }
            catch { }
            var count = Interlocked.Increment(ref done);
            if (count % 50 == 0 || count == files.Count) progress.Report((count, entry.Path));
            return ValueTask.CompletedTask;
        });

        return result.OrderBy(a => a.FileName, StringComparer.OrdinalIgnoreCase).ToList();
    }
}
