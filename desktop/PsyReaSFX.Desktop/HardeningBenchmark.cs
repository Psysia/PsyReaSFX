using System.Diagnostics;
using System.Text.Json;
using PsyReaSFX.Data;
using PsyReaSFX.Desktop.Services;

namespace PsyReaSFX.Desktop;

internal static class HardeningBenchmark
{
    public static async Task<int> RunAsync(string sourceRoot, string reportPath)
    {
        sourceRoot = Path.GetFullPath(sourceRoot);
        if (!Directory.Exists(sourceRoot))
            throw new DirectoryNotFoundException(sourceRoot);

        var working = Path.Combine(Path.GetTempPath(), "PsyReaSFX-HardeningBenchmark-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(working);
        try
        {
            GC.Collect();
            GC.WaitForPendingFinalizers();
            GC.Collect();
            var memoryBefore = GC.GetTotalMemory(true);

            var library = new LibraryDefinition { Id = "benchmark-library", Name = "Hardening Benchmark" };
            library.Sources.Add(new LibrarySource { Id = "benchmark-source", Path = sourceRoot });
            var indexer = new LibraryIndexer();

            var indexTimer = Stopwatch.StartNew();
            var assets = await indexer.BuildAsync([library], [], new NullProgress<(int Count, string File)>(), CancellationToken.None);
            indexTimer.Stop();

            var snapshot = new CatalogSnapshot();
            snapshot.Libraries.Add(new LibraryRecord(library.Id, library.Name, "", true));
            snapshot.Sources.Add(new SourceRecord(library.Sources[0].Id, library.Id, sourceRoot, "", true, "", false, 0));
            snapshot.Assets.AddRange(assets.Select(asset => new AssetRecord
            {
                Path = asset.FilePath,
                Name = asset.FileName,
                Folder = asset.RelativeFolder,
                Root = asset.SourcePath,
                Library = asset.LibraryName,
                Duration = asset.DurationSeconds,
                Channels = asset.Channels,
                SampleRate = asset.SampleRate,
                BitDepth = asset.BitDepth,
                SourceType = asset.Format,
                Size = asset.FileSize,
                ArtworkPath = asset.ArtworkPath,
                Indexed = asset.Indexed,
                Ready = asset.Ready,
                RootId = asset.RootId,
                LibraryId = asset.LibraryId
            }));

            var database = new PsyReaSFXDatabase(Path.Combine(working, "database"));
            await database.InitializeAsync();
            var saveTimer = Stopwatch.StartNew();
            await database.SaveDesktopSnapshotAsync(snapshot);
            saveTimer.Stop();

            var loadTimer = Stopwatch.StartNew();
            var loaded = await database.LoadSnapshotAsync();
            loadTimer.Stop();

            var searchTimer = Stopwatch.StartNew();
            var matches = loaded.Assets.Count(asset =>
                asset.Name.Contains("TEST_00", StringComparison.OrdinalIgnoreCase)
                || asset.Folder.Contains("Category-00", StringComparison.OrdinalIgnoreCase));
            searchTimer.Stop();

            var memoryAfter = GC.GetTotalMemory(true);
            var expected = Directory.EnumerateFiles(sourceRoot, "*", SearchOption.AllDirectories)
                .Count(path => AudioFileReader.SupportedExtensions.Contains(Path.GetExtension(path)));
            var passed = assets.Count == expected
                         && loaded.Assets.Count == expected
                         && indexer.LastFailures.Count == 0;

            WriteReport(reportPath, new
            {
                passed,
                sourceRoot,
                expectedAssets = expected,
                indexedAssets = assets.Count,
                loadedAssets = loaded.Assets.Count,
                failedAssets = indexer.LastFailures.Count,
                matches,
                elapsedMs = new
                {
                    index = indexTimer.Elapsed.TotalMilliseconds,
                    save = saveTimer.Elapsed.TotalMilliseconds,
                    load = loadTimer.Elapsed.TotalMilliseconds,
                    search = searchTimer.Elapsed.TotalMilliseconds
                },
                managedMemoryBytes = new { before = memoryBefore, after = memoryAfter, delta = memoryAfter - memoryBefore },
                machine = new { Environment.ProcessorCount, framework = Environment.Version.ToString(), os = Environment.OSVersion.ToString() },
                timestampUtc = DateTimeOffset.UtcNow
            });
            return passed ? 0 : 2;
        }
        catch (Exception exception)
        {
            WriteReport(reportPath, new { passed = false, error = exception.ToString(), timestampUtc = DateTimeOffset.UtcNow });
            return 1;
        }
        finally
        {
            try { Directory.Delete(working, true); } catch { }
        }
    }

    private static void WriteReport(string path, object report)
    {
        path = Path.GetFullPath(path);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var temporary = path + ".tmp";
        File.WriteAllText(temporary, JsonSerializer.Serialize(report, new JsonSerializerOptions { WriteIndented = true }));
        File.Move(temporary, path, true);
    }

    private sealed class NullProgress<T> : IProgress<T>
    {
        public void Report(T value) { }
    }
}
