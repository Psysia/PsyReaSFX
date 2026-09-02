using System.Diagnostics;
using System.Text.Json;
using PsyReaSFX.Data;
using PsyReaSFX.Desktop.Services;

namespace PsyReaSFX.Desktop;

internal static class HardeningBenchmark
{
    public const int MaximumCapacityAssets = 500_000;
    private const double MaximumInitialSaveMilliseconds = 300_000;
    private const double MaximumStateLoadMilliseconds = 30_000;
    private const double MaximumSearchMilliseconds = 1_000;
    private const double MaximumIntegrityCheckMilliseconds = 120_000;
    private const long MaximumDatabaseBytes = 1L * 1024 * 1024 * 1024;
    private const long MaximumManagedStateBytes = 1536L * 1024 * 1024;
    private const long MaximumPeakWorkingSetBytes = 2560L * 1024 * 1024;

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
                AssetId = asset.AssetId,
                Path = asset.FilePath,
                RelativePath = asset.RelativePath,
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
            var initialWriteStats = database.LastSnapshotWriteStats;
            var initialWriteTimings = database.LastSnapshotWriteTimings;

            var unchangedSaveTimer = Stopwatch.StartNew();
            await database.SaveDesktopSnapshotAsync(snapshot);
            unchangedSaveTimer.Stop();
            var unchangedWriteStats = database.LastSnapshotWriteStats;
            var unchangedWriteTimings = database.LastSnapshotWriteTimings;

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
                    unchangedSave = unchangedSaveTimer.Elapsed.TotalMilliseconds,
                    load = loadTimer.Elapsed.TotalMilliseconds,
                    search = searchTimer.Elapsed.TotalMilliseconds
                },
                writes = new { initialWriteStats, unchangedWriteStats },
                writeTimings = new { initialWriteTimings, unchangedWriteTimings },
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

    public static async Task<int> RunCapacityAsync(int count, string reportPath)
    {
        if (count < 1 || count > MaximumCapacityAssets)
            throw new ArgumentOutOfRangeException(nameof(count), count,
                $"Capacity benchmark supports 1 to {MaximumCapacityAssets:N0} assets.");

        var working = Path.Combine(Path.GetTempPath(), "PsyReaSFX-CapacityBenchmark-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(working);
        try
        {
            GC.Collect();
            GC.WaitForPendingFinalizers();
            GC.Collect();
            var memoryBefore = GC.GetTotalMemory(true);
            var virtualRoot = Path.Combine(working, "virtual-source");
            CatalogSnapshot? snapshot = new();
            snapshot.Libraries.Add(new LibraryRecord("capacity-library", "Capacity Benchmark", "", true));
            snapshot.Sources.Add(new SourceRecord(
                "capacity-source", "capacity-library", virtualRoot, "", true, "", false, 0));

            var generationTimer = Stopwatch.StartNew();
            for (var index = 0; index < count; index++)
            {
                var category = $"Category-{index % 64:00}";
                var group = $"Group-{index / 64 % 64:00}";
                var name = $"CAPACITY_{index:000000}.wav";
                var relative = Path.Combine(category, group, name);
                snapshot.Assets.Add(new AssetRecord
                {
                    AssetId = $"capacity-{index:000000}",
                    Path = Path.Combine(virtualRoot, relative),
                    RelativePath = relative,
                    Name = name,
                    Folder = Path.Combine(category, group),
                    Root = virtualRoot,
                    Library = "Capacity Benchmark",
                    Duration = 1 + index % 600 / 10.0,
                    Channels = index % 997 == 0 ? 4 : 2,
                    SampleRate = 48_000,
                    BitDepth = 24,
                    SourceType = "WAV",
                    Size = 4_096 + index % 65_536,
                    Category = category,
                    Subcategory = group,
                    Indexed = true,
                    Ready = true,
                    RootId = "capacity-source",
                    LibraryId = "capacity-library",
                    LastSeenUtc = 1_777_777_777
                });
            }
            generationTimer.Stop();
            var memoryWithSnapshot = GC.GetTotalMemory(true);

            var database = new PsyReaSFXDatabase(Path.Combine(working, "database"));
            await database.InitializeAsync();
            var saveTimer = Stopwatch.StartNew();
            await database.SaveDesktopSnapshotAsync(snapshot);
            saveTimer.Stop();
            var writeStats = database.LastSnapshotWriteStats;
            var writeTimings = database.LastSnapshotWriteTimings;

            snapshot = null;
            GC.Collect();
            GC.WaitForPendingFinalizers();
            GC.Collect();
            var memoryAfterSnapshotRelease = GC.GetTotalMemory(true);

            var loadTimer = Stopwatch.StartNew();
            var loadedSnapshot = await database.LoadSnapshotAsync();
            var loaded = StateStore.FromSnapshot(loadedSnapshot);
            loadedSnapshot = null;
            loadTimer.Stop();
            var memoryWithLoaded = GC.GetTotalMemory(true);
            using var process = Process.GetCurrentProcess();
            process.Refresh();
            var peakWorkingSetBytes = process.PeakWorkingSet64;

            var searchTimer = Stopwatch.StartNew();
            var matches = loaded.Index.Count(asset =>
                asset.Category == "Category-00"
                || asset.FileName.Contains("9999", StringComparison.Ordinal));
            searchTimer.Stop();

            var integrityTimer = Stopwatch.StartNew();
            var integrity = await PsyReaSFXDatabase.CheckIntegrityAsync(database.DatabasePath);
            integrityTimer.Stop();
            var databaseBytes = new FileInfo(database.DatabasePath).Length;
            var managedStateDelta = memoryWithLoaded - memoryAfterSnapshotRelease;
            var capacityTargetPassed = saveTimer.Elapsed.TotalMilliseconds <= MaximumInitialSaveMilliseconds
                                       && loadTimer.Elapsed.TotalMilliseconds <= MaximumStateLoadMilliseconds
                                       && searchTimer.Elapsed.TotalMilliseconds <= MaximumSearchMilliseconds
                                       && integrityTimer.Elapsed.TotalMilliseconds <= MaximumIntegrityCheckMilliseconds
                                       && databaseBytes <= MaximumDatabaseBytes
                                       && managedStateDelta <= MaximumManagedStateBytes
                                       && peakWorkingSetBytes <= MaximumPeakWorkingSetBytes;
            var passed = loaded.Index.Count == count
                         && writeStats.ChangedAssets == count
                         && writeStats.RemovedAssets == 0
                         && matches > 0
                         && integrity.Equals("ok", StringComparison.OrdinalIgnoreCase)
                         && capacityTargetPassed;

            WriteReport(reportPath, new
            {
                passed,
                mode = "synthetic-capacity",
                requestedAssets = count,
                loadedAssets = loaded.Index.Count,
                matches,
                integrity,
                databaseBytes,
                capacityTargetPassed,
                capacityBudgets = new
                {
                    initialSaveMilliseconds = MaximumInitialSaveMilliseconds,
                    stateLoadMilliseconds = MaximumStateLoadMilliseconds,
                    searchMilliseconds = MaximumSearchMilliseconds,
                    integrityCheckMilliseconds = MaximumIntegrityCheckMilliseconds,
                    databaseBytes = MaximumDatabaseBytes,
                    managedStateBytes = MaximumManagedStateBytes,
                    peakWorkingSetBytes = MaximumPeakWorkingSetBytes
                },
                elapsedMs = new
                {
                    generation = generationTimer.Elapsed.TotalMilliseconds,
                    save = saveTimer.Elapsed.TotalMilliseconds,
                    load = loadTimer.Elapsed.TotalMilliseconds,
                    search = searchTimer.Elapsed.TotalMilliseconds,
                    integrity = integrityTimer.Elapsed.TotalMilliseconds
                },
                writes = writeStats,
                writeTimings,
                managedMemoryBytes = new
                {
                    before = memoryBefore,
                    withSnapshot = memoryWithSnapshot,
                    afterSnapshotRelease = memoryAfterSnapshotRelease,
                    withLoaded = memoryWithLoaded,
                    snapshotDelta = memoryWithSnapshot - memoryBefore,
                    loadedDelta = managedStateDelta,
                    peakWorkingSet = peakWorkingSetBytes
                },
                machine = new
                {
                    Environment.ProcessorCount,
                    framework = Environment.Version.ToString(),
                    os = Environment.OSVersion.ToString()
                },
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
