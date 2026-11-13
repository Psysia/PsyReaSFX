using System.Text.Json;
using Microsoft.Data.Sqlite;
using PsyReaSFX.Data;

namespace PsyReaSFX.Desktop.Services;

public sealed record ScanCheckpoint(
    string Id,
    DateTimeOffset StartedUtc,
    DateTimeOffset UpdatedUtc,
    int ProcessedFiles,
    string LastFile,
    bool Active);

public sealed record FailedScanItem(string Path, string Error, DateTimeOffset FailedUtc, int Attempts);

public sealed record CacheIntegrityReport(int Checked, int Valid, int Removed, int Failed);

/// <summary>
/// Owns the small, recoverable files used by Alpha 7. All writes are atomic so
/// an interrupted scan cannot corrupt the recovery state itself.
/// </summary>
public sealed class CatalogReliabilityService
{
    private readonly JsonSerializerOptions _json = new() { WriteIndented = true };
    public string RootDirectory { get; }
    public string BackupDirectory { get; }
    public string CheckpointPath { get; }
    public string FailuresPath { get; }
    public string PendingRestorePath { get; }

    public CatalogReliabilityService(string dataDirectory)
    {
        RootDirectory = Path.Combine(dataDirectory, "Reliability");
        BackupDirectory = Path.Combine(dataDirectory, "Backups");
        CheckpointPath = Path.Combine(RootDirectory, "scan-checkpoint-v1.json");
        FailuresPath = Path.Combine(RootDirectory, "failed-scan-items-v1.json");
        PendingRestorePath = Path.Combine(RootDirectory, "restore-on-next-launch.sqlite3");
    }

    public ScanCheckpoint? LoadCheckpoint() => ReadJson<ScanCheckpoint>(CheckpointPath);
    public IReadOnlyList<FailedScanItem> LoadFailures() => ReadJson<List<FailedScanItem>>(FailuresPath) ?? [];

    public void BeginScan()
    {
        Directory.CreateDirectory(RootDirectory);
        var now = DateTimeOffset.UtcNow;
        WriteJsonAtomic(CheckpointPath, new ScanCheckpoint(Guid.NewGuid().ToString("N"), now, now, 0, "", true));
    }

    public void UpdateScan(int processedFiles, string lastFile)
    {
        var current = LoadCheckpoint();
        if (current is null || !current.Active) return;
        WriteJsonAtomic(CheckpointPath, current with
        {
            UpdatedUtc = DateTimeOffset.UtcNow,
            ProcessedFiles = Math.Max(0, processedFiles),
            LastFile = lastFile ?? ""
        });
    }

    public void CompleteScan(IEnumerable<FailedScanItem> failures)
    {
        var rows = failures.OrderBy(row => row.Path, StringComparer.OrdinalIgnoreCase).ToList();
        WriteJsonAtomic(FailuresPath, rows);
        TryDelete(CheckpointPath);
    }

    public void ClearFailures() => TryDelete(FailuresPath);
    public void ClearCheckpoint() => TryDelete(CheckpointPath);

    public async Task<string> CreateBackupAsync(string databasePath, int retention, CancellationToken token = default)
    {
        Directory.CreateDirectory(BackupDirectory);
        var destination = Path.Combine(BackupDirectory, $"catalog-{DateTime.Now:yyyyMMdd-HHmmss-fff}-{Guid.NewGuid():N}.sqlite3");
        var database = new PsyReaSFXDatabase(Path.GetDirectoryName(databasePath));
        try
        {
            await database.BackupAsync(destination, token);
            var integrity = await PsyReaSFXDatabase.CheckIntegrityAsync(destination, token);
            if (!integrity.Equals("ok", StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException($"Backup integrity check failed: {integrity}");
        }
        catch
        {
            TryDelete(destination);
            throw;
        }
        foreach (var stale in Directory.EnumerateFiles(BackupDirectory, "catalog-*.sqlite3")
                     .OrderByDescending(File.GetLastWriteTimeUtc).Skip(Math.Clamp(retention, 2, 50)))
            TryDelete(stale);
        return destination;
    }

    public async Task<string?> EnsureDailyBackupAsync(string databasePath, int retention, CancellationToken token = default)
    {
        if (!File.Exists(databasePath)) return null;
        Directory.CreateDirectory(BackupDirectory);
        var newest = Directory.EnumerateFiles(BackupDirectory, "catalog-*.sqlite3")
            .OrderByDescending(File.GetLastWriteTimeUtc).FirstOrDefault();
        if (newest != null && DateTime.UtcNow - File.GetLastWriteTimeUtc(newest) < TimeSpan.FromHours(20)) return newest;
        return await CreateBackupAsync(databasePath, retention, token);
    }

    public string? LatestBackup() => Directory.Exists(BackupDirectory)
        ? Directory.EnumerateFiles(BackupDirectory, "catalog-*.sqlite3").OrderByDescending(File.GetLastWriteTimeUtc).FirstOrDefault()
        : null;

    public async Task StageRestoreLatestAsync(CancellationToken token = default)
    {
        var latest = LatestBackup() ?? throw new FileNotFoundException("No catalog backup is available.");
        var integrity = await PsyReaSFXDatabase.CheckIntegrityAsync(latest, token);
        if (!integrity.Equals("ok", StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException($"Backup integrity check failed: {integrity}");
        Directory.CreateDirectory(RootDirectory);
        await CopyAtomicAsync(latest, PendingRestorePath, token);
    }

    public static void ApplyPendingRestore(string dataDirectory) =>
        ApplyPendingRestoreAsync(dataDirectory).GetAwaiter().GetResult();

    public static async Task ApplyPendingRestoreAsync(string dataDirectory, CancellationToken token = default)
    {
        var reliability = new CatalogReliabilityService(dataDirectory);
        if (!File.Exists(reliability.PendingRestorePath)) return;
        var databasePath = Path.Combine(dataDirectory, "catalog-v1.sqlite3");
        Directory.CreateDirectory(dataDirectory);
        var previous = databasePath + ".before-restore";
        var staged = databasePath + "." + Guid.NewGuid().ToString("N") + ".restore.tmp";
        try
        {
            await CopyAtomicAsync(reliability.PendingRestorePath, staged, token).ConfigureAwait(false);
            var integrity = await PsyReaSFXDatabase.CheckIntegrityAsync(staged, token).ConfigureAwait(false);
            if (!integrity.Equals("ok", StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException($"Restore integrity check failed: {integrity}");

            await using (var restored = new SqliteConnection(new SqliteConnectionStringBuilder
            {
                DataSource = staged, Mode = SqliteOpenMode.ReadOnly, Pooling = false
            }.ToString()))
            {
                await restored.OpenAsync(token).ConfigureAwait(false);
                using var schema = restored.CreateCommand();
                schema.CommandText = "SELECT MAX(version) FROM schema_info";
                var version = Convert.ToInt32(await schema.ExecuteScalarAsync(token).ConfigureAwait(false));
                if (version < 1 || version > PsyReaSFXDatabase.SupportedSchemaVersion)
                    throw new InvalidDataException($"Restore catalog schema {version} is not supported.");
            }

            var hadOriginal = File.Exists(databasePath);
            if (hadOriginal)
            {
                var original = new PsyReaSFXDatabase(dataDirectory);
                if (await original.GetSchemaVersionAsync(token).ConfigureAwait(false) > PsyReaSFXDatabase.SupportedSchemaVersion)
                    throw new InvalidDataException("A newer catalog cannot be replaced by this application's pending restore.");
                // Commit the original WAL before retaining it as the rollback
                // copy. A busy checkpoint or an external file owner aborts.
                await using (var connection = new SqliteConnection(new SqliteConnectionStringBuilder
                {
                    DataSource = databasePath, Mode = SqliteOpenMode.ReadWrite, Pooling = false
                }.ToString()))
                {
                    await connection.OpenAsync(token).ConfigureAwait(false);
                    using var checkpoint = connection.CreateCommand();
                    checkpoint.CommandText = "PRAGMA wal_checkpoint(TRUNCATE)";
                    await using var result = await checkpoint.ExecuteReaderAsync(token).ConfigureAwait(false);
                    if (await result.ReadAsync(token).ConfigureAwait(false) && result.GetInt32(0) != 0)
                        throw new IOException("The catalog is busy; close other catalog users before restoring.");
                }
            }
            // Keep readers and writers out until the replacement is complete.
            // Sharing delete allows File.Replace to retain the open original
            // as the rollback file without reopening a check-to-use gap.
            using var originalGuard = hadOriginal
                ? File.Open(databasePath, FileMode.Open, FileAccess.ReadWrite, FileShare.Delete)
                : null;
            token.ThrowIfCancellationRequested();
            // Do not swallow failed sidecar deletion: replacing a database
            // while its old WAL remains would mix two generations.
            File.Delete(databasePath + "-wal");
            File.Delete(databasePath + "-shm");
            if (hadOriginal) File.Replace(staged, databasePath, previous, true);
            else File.Move(staged, databasePath, false);
            TryDelete(reliability.PendingRestorePath);
        }
        finally { TryDelete(staged); }
    }

    public async Task<CacheIntegrityReport> CheckWaveCacheAsync(bool removeInvalid, CancellationToken token = default)
    {
        var directory = LuaWaveCache.CacheDirectory;
        if (string.IsNullOrWhiteSpace(directory) || !Directory.Exists(directory)) return new CacheIntegrityReport(0, 0, 0, 0);
        var checkedCount = 0; var valid = 0; var removed = 0; var failed = 0;
        foreach (var path in Directory.EnumerateFiles(directory, "*.rwf", SearchOption.TopDirectoryOnly))
        {
            token.ThrowIfCancellationRequested();
            checkedCount++;
            if (LuaWaveCache.ValidateFile(path)) valid++;
            else if (removeInvalid)
            {
                try { File.Delete(path); removed++; } catch { failed++; }
            }
            else failed++;
            if (checkedCount % 200 == 0) await Task.Yield();
        }
        return new CacheIntegrityReport(checkedCount, valid, removed, failed);
    }

    private T? ReadJson<T>(string path)
    {
        try { return File.Exists(path) ? JsonSerializer.Deserialize<T>(File.ReadAllText(path), _json) : default; }
        catch (Exception exception) { AppDiagnostics.Write($"Reliability state could not be read: {path}", exception); return default; }
    }

    private void WriteJsonAtomic<T>(string path, T value)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var temporary = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            File.WriteAllText(temporary, JsonSerializer.Serialize(value, _json));
            File.Move(temporary, path, true);
        }
        finally { TryDelete(temporary); }
    }

    private static async Task CopyAtomicAsync(string source, string destination, CancellationToken token)
    {
        var temporary = destination + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            await using (var input = new FileStream(source, FileMode.Open, FileAccess.Read, FileShare.Read, 1024 * 1024, true))
            await using (var output = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None, 1024 * 1024, true))
                await input.CopyToAsync(output, token).ConfigureAwait(false);
            token.ThrowIfCancellationRequested();
            File.Move(temporary, destination, true);
        }
        finally { TryDelete(temporary); }
    }

    private static void TryDelete(string path)
    {
        try { if (File.Exists(path)) File.Delete(path); } catch { }
    }
}

public sealed class LibraryWatchService : IDisposable
{
    private readonly List<FileSystemWatcher> _watchers = [];
    private readonly object _gate = new();
    private System.Threading.Timer? _timer;
    private TimeSpan _debounce = TimeSpan.FromSeconds(4);
    public event EventHandler? ChangeDetected;

    public void Start(IEnumerable<LibraryDefinition> libraries, TimeSpan debounce)
    {
        Stop();
        _debounce = TimeSpan.FromSeconds(Math.Clamp(debounce.TotalSeconds, 2, 120));
        foreach (var source in libraries.SelectMany(library => library.Sources).Where(source => source.Enabled && Directory.Exists(source.Path)))
        {
            try
            {
                var watcher = new FileSystemWatcher(source.Path)
                {
                    IncludeSubdirectories = true,
                    NotifyFilter = NotifyFilters.FileName | NotifyFilters.DirectoryName | NotifyFilters.LastWrite | NotifyFilters.Size,
                    InternalBufferSize = 64 * 1024,
                    EnableRaisingEvents = true
                };
                watcher.Created += OnChanged; watcher.Changed += OnChanged; watcher.Deleted += OnChanged; watcher.Renamed += OnChanged;
                watcher.Error += OnWatcherError;
                _watchers.Add(watcher);
            }
            catch (Exception exception) { AppDiagnostics.Write($"Watch Folder unavailable: {source.Path}", exception); }
        }
    }

    private void OnChanged(object sender, FileSystemEventArgs e)
    {
        if (!AudioFileReader.SupportedExtensions.Contains(Path.GetExtension(e.FullPath)) && Path.HasExtension(e.FullPath)) return;
        ScheduleChange();
    }

    private void OnWatcherError(object sender, ErrorEventArgs e)
    {
        AppDiagnostics.Write("Watch Folder event buffer overflowed or became unavailable; scheduling a full incremental scan.", e.GetException());
        ScheduleChange();
    }

    private void ScheduleChange()
    {
        lock (_gate)
        {
            _timer ??= new System.Threading.Timer(_ =>
            {
                try { ChangeDetected?.Invoke(this, EventArgs.Empty); }
                catch (Exception exception) { AppDiagnostics.Write("Watch Folder change notification failed.", exception); }
            });
            _timer.Change(_debounce, Timeout.InfiniteTimeSpan);
        }
    }

    public void Stop()
    {
        lock (_gate) { _timer?.Dispose(); _timer = null; }
        foreach (var watcher in _watchers) watcher.Dispose();
        _watchers.Clear();
    }

    public void Dispose() => Stop();
}
