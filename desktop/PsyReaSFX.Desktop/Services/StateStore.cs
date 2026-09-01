using PsyReaSFX.Data;

namespace PsyReaSFX.Desktop.Services;

public sealed class StateStore : IStorageService
{
    private readonly PsyReaSFXDatabase _database;
    private readonly SemaphoreSlim _writeGate = new(1, 1);
    private readonly object _workspaceQueueGate = new();
    private readonly List<TaskCompletionSource> _pendingWorkspaceWaiters = [];
    private CatalogSnapshot? _pendingWorkspace;
    private bool _workspacePumpRunning;
    private long _workspaceWritesExecuted;
    private long _workspaceWritesCoalesced;
    public string DataDirectory => _database.DataDirectory;
    public string DatabasePath => _database.DatabasePath;
    public MigrationSummary? LastMigration { get; private set; }
    public Exception? LastError { get; private set; }
    public bool CanWrite => LastError is null;
    internal long WorkspaceWritesExecuted => Interlocked.Read(ref _workspaceWritesExecuted);
    internal long WorkspaceWritesCoalesced => Interlocked.Read(ref _workspaceWritesCoalesced);

    public StateStore(PsyReaSFXDatabase? database = null) => _database = database ?? new PsyReaSFXDatabase();

    public async Task<PersistedState> LoadAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            AppDiagnostics.Write("Opening desktop catalog.");
            await _database.InitializeAsync(cancellationToken);
            LastMigration = await _database.ImportLuaIfNeededAsync(cancellationToken: cancellationToken);
            var snapshot = await _database.LoadSnapshotAsync(cancellationToken);
            var state = FromSnapshot(snapshot);
            LastError = null;
            AppDiagnostics.Write($"Catalog opened: {state.Libraries.Count} libraries, {state.Index.Count} assets.");
            return state;
        }
        catch (Exception exception)
        {
            LastError = exception;
            AppDiagnostics.Write("Catalog startup failed; opening an empty recoverable workspace.", exception);
            return new PersistedState();
        }
    }

    public PersistedState Load() => LoadAsync().GetAwaiter().GetResult();

    public void Save(PersistedState state)
    {
        SaveAsync(state).GetAwaiter().GetResult();
    }

    public Task SaveAsync(PersistedState state, CancellationToken cancellationToken = default)
    {
        EnsureWritable();
        // Capture mutable UI collections before the first await. The database
        // can then write in the background without enumerating live WPF state.
        var snapshot = ToSnapshot(state);
        return WriteSerializedAsync(token => _database.SaveDesktopSnapshotAsync(snapshot, token), cancellationToken);
    }

    public void SaveWorkspace(PersistedState state)
    {
        SaveWorkspaceAsync(state).GetAwaiter().GetResult();
    }

    public Task SaveWorkspaceAsync(PersistedState state, CancellationToken cancellationToken = default)
    {
        EnsureWritable();
        cancellationToken.ThrowIfCancellationRequested();
        var snapshot = ToWorkspaceSnapshot(state);
        var completion = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        lock (_workspaceQueueGate)
        {
            if (_pendingWorkspace is not null)
                Interlocked.Increment(ref _workspaceWritesCoalesced);
            _pendingWorkspace = snapshot;
            _pendingWorkspaceWaiters.Add(completion);
            if (!_workspacePumpRunning)
            {
                _workspacePumpRunning = true;
                _ = Task.Run(PumpWorkspaceWritesAsync);
            }
        }
        return cancellationToken.CanBeCanceled
            ? completion.Task.WaitAsync(cancellationToken)
            : completion.Task;
    }

    public void SaveActivities(IEnumerable<AudioAsset> assets)
    {
        SaveActivitiesAsync(assets).GetAwaiter().GetResult();
    }

    public Task SaveActivitiesAsync(IEnumerable<AudioAsset> assets, CancellationToken cancellationToken = default)
    {
        EnsureWritable();
        var rows = assets.Select(ToAsset).ToArray();
        return WriteSerializedAsync(token => _database.SaveAssetActivityAsync(rows, token), cancellationToken);
    }

    public Task SaveAssetDetailsAsync(IEnumerable<AudioAsset> assets, CancellationToken cancellationToken = default)
    {
        EnsureWritable();
        var rows = assets.Select(ToAsset).ToArray();
        return WriteSerializedAsync(token => _database.SaveAssetDetailsAsync(rows, token), cancellationToken);
    }

    public void SaveSessionPlayed(IEnumerable<string> paths)
    {
        SaveSessionPlayedAsync(paths).GetAwaiter().GetResult();
    }

    public Task SaveSessionPlayedAsync(IEnumerable<string> paths, CancellationToken cancellationToken = default)
    {
        EnsureWritable();
        var rows = paths.ToArray();
        return WriteSerializedAsync(token => _database.ReplaceSessionPlayedAsync(rows, token), cancellationToken);
    }

    public Task<IReadOnlyList<RegionRecord>> LoadRegionsAsync(string assetPath, CancellationToken cancellationToken = default) =>
        _database.LoadRegionsAsync(assetPath, cancellationToken);

    public Task SaveRegionAsync(RegionRecord region, CancellationToken cancellationToken = default)
    {
        EnsureWritable();
        return WriteSerializedAsync(token => _database.UpsertRegionAsync(region, token), cancellationToken);
    }

    public Task DeleteRegionAsync(RegionRecord region, CancellationToken cancellationToken = default)
    {
        EnsureWritable();
        return WriteSerializedAsync(token => _database.DeleteRegionAsync(region, token), cancellationToken);
    }

    public Task<LoudnessRecord?> LoadLoudnessAsync(string assetPath, CancellationToken cancellationToken = default) =>
        _database.LoadLoudnessAsync(assetPath, cancellationToken);

    public Task SaveLoudnessAsync(LoudnessRecord row, CancellationToken cancellationToken = default)
    {
        EnsureWritable();
        return WriteSerializedAsync(token => _database.UpsertLoudnessAsync(row, token), cancellationToken);
    }

    public Task AddProjectUsageAsync(ProjectUsageRecord row, CancellationToken cancellationToken = default)
    {
        EnsureWritable();
        return WriteSerializedAsync(token => _database.AddProjectUsageAsync(row, token), cancellationToken);
    }

    public Task<IReadOnlyList<ProjectUsageRecord>> LoadProjectUsageAsync(int limit = 500, CancellationToken cancellationToken = default) =>
        _database.LoadProjectUsageAsync(limit, cancellationToken);

    private async Task PumpWorkspaceWritesAsync()
    {
        while (true)
        {
            CatalogSnapshot snapshot;
            TaskCompletionSource[] waiters;
            lock (_workspaceQueueGate)
            {
                if (_pendingWorkspace is null)
                {
                    _workspacePumpRunning = false;
                    return;
                }
                snapshot = _pendingWorkspace;
                _pendingWorkspace = null;
                waiters = _pendingWorkspaceWaiters.ToArray();
                _pendingWorkspaceWaiters.Clear();
            }

            try
            {
                await WriteSerializedAsync(
                    token => _database.SaveWorkspaceAsync(snapshot, token),
                    CancellationToken.None).ConfigureAwait(false);
                Interlocked.Increment(ref _workspaceWritesExecuted);
                foreach (var waiter in waiters) waiter.TrySetResult();
            }
            catch (Exception exception)
            {
                foreach (var waiter in waiters) waiter.TrySetException(exception);
            }
        }
    }

    private Task WriteSerializedAsync(
        Func<CancellationToken, Task> writer,
        CancellationToken cancellationToken) =>
        Task.Run(async () =>
        {
            await _writeGate.WaitAsync(cancellationToken).ConfigureAwait(false);
            try { await writer(cancellationToken).ConfigureAwait(false); }
            finally { _writeGate.Release(); }
        });

    private void EnsureWritable()
    {
        if (LastError is not null)
            throw new InvalidOperationException(
                "Catalog writes are disabled because the database did not open successfully.", LastError);
    }

    private static PersistedState FromSnapshot(CatalogSnapshot snapshot)
    {
        var state = new PersistedState { Favorites = new HashSet<string>(snapshot.Favorites, StringComparer.OrdinalIgnoreCase) };
        var byId = new Dictionary<string, LibraryDefinition>(StringComparer.OrdinalIgnoreCase);
        foreach (var row in snapshot.Libraries)
        {
            var library = new LibraryDefinition { Id = row.Id, Name = row.Name, ArtworkPath = row.ArtworkPath, IsExpanded = row.Expanded };
            state.Libraries.Add(library); byId[row.Id] = library;
        }
        foreach (var row in snapshot.Sources)
            if (byId.TryGetValue(row.LibraryId, out var library)) library.Sources.Add(new LibrarySource
            {
                Id = row.Id, Path = row.Path, Alias = row.Alias, Enabled = row.Enabled, ArtworkPath = row.ArtworkPath,
                ArtworkChecked = row.ArtworkChecked, ArtworkScanVersion = row.ArtworkScanVersion,
                CanonicalPath = row.CanonicalPath, VolumeLabel = row.VolumeLabel,
                VolumeSerial = row.VolumeSerial, LastSeenUtc = row.LastSeenUtc
            });
        state.Index = snapshot.Assets.Select(FromAsset).ToList();
        foreach (var asset in state.Index)
            asset.IsSessionPlayed = snapshot.SessionPlayed.Contains(asset.FilePath);
        var collections = snapshot.Collections.ToDictionary(row => row.Id, row => new AssetCollection { Id = row.Id, Name = row.Name, Kind = row.Kind }, StringComparer.OrdinalIgnoreCase);
        foreach (var collection in collections.Values) state.Collections.Add(collection);
        foreach (var item in snapshot.CollectionItems.OrderBy(item => item.SortOrder))
            if (collections.TryGetValue(item.CollectionId, out var collection)) collection.Items.Add(item.Path);
        foreach (var row in snapshot.SavedSearches) state.SavedSearches.Add(new SavedSearchDefinition
        {
            Id = row.Id, Name = row.Name, Query = row.Query, View = row.View, Root = row.Root, SortMode = row.SortMode,
            SortDescending = row.SortDescending, StatusFilter = row.StatusFilter ?? "", CollectionId = row.CollectionId ?? "", LibraryId = row.LibraryId ?? ""
        });
        return state;
    }

    private static CatalogSnapshot ToSnapshot(PersistedState state)
    {
        var snapshot = ToWorkspaceSnapshot(state);
        snapshot.Assets.AddRange(state.Index.Select(ToAsset));
        snapshot.SessionPlayed.UnionWith(state.Index.Where(asset => asset.IsSessionPlayed).Select(asset => asset.FilePath));
        return snapshot;
    }

    private static CatalogSnapshot ToWorkspaceSnapshot(PersistedState state)
    {
        var snapshot = new CatalogSnapshot();
        foreach (var library in state.Libraries)
        {
            snapshot.Libraries.Add(new LibraryRecord(library.Id, library.Name, library.ArtworkPath, library.IsExpanded));
            foreach (var source in library.Sources)
                snapshot.Sources.Add(new SourceRecord(source.Id, library.Id, source.Path, source.Alias, source.Enabled,
                    source.ArtworkPath, source.ArtworkChecked, source.ArtworkScanVersion, source.CanonicalPath,
                    source.VolumeLabel, source.VolumeSerial, source.LastSeenUtc));
        }
        snapshot.Favorites.UnionWith(state.Favorites);
        foreach (var collection in state.Collections)
        {
            snapshot.Collections.Add(new CollectionRecord(collection.Id, collection.Name, collection.Kind));
            for (var i = 0; i < collection.Items.Count; i++) snapshot.CollectionItems.Add(new CollectionItemRecord(collection.Id, collection.Items[i], i));
        }
        foreach (var saved in state.SavedSearches)
            snapshot.SavedSearches.Add(new SavedSearchRecord(saved.Id, saved.Name, saved.Query, saved.View, saved.Root, saved.SortMode, saved.SortDescending,
                string.IsNullOrWhiteSpace(saved.StatusFilter) ? null : saved.StatusFilter, string.IsNullOrWhiteSpace(saved.CollectionId) ? null : saved.CollectionId,
                string.IsNullOrWhiteSpace(saved.LibraryId) ? null : saved.LibraryId));
        return snapshot;
    }

    private static AudioAsset FromAsset(AssetRecord row) => new()
    {
        AssetId = row.AssetId, FilePath = row.Path, RelativePath = row.RelativePath,
        FileName = row.Name, RelativeFolder = row.Folder, SourcePath = row.Root, LibraryName = row.Library,
        DurationSeconds = row.Duration, Channels = row.Channels, SampleRate = row.SampleRate, BitDepth = row.BitDepth,
        Format = row.SourceType, FileSize = row.Size, ArtworkPath = row.ArtworkPath, Description = row.Description,
        Keywords = row.Keywords, CatId = row.CatId, Category = row.Category, Subcategory = row.Subcategory,
        WorkflowStatus = row.WorkflowStatus, Marked = row.Marked, PreviewCount = row.PreviewCount,
        LastPreviewed = row.LastPreviewed, Indexed = row.Indexed, Ready = row.Ready, UsedCount = row.UsedCount,
        LastUsed = row.LastUsed, RootId = row.RootId, LibraryId = row.LibraryId, LastSeenUtc = row.LastSeenUtc
    };

    private static AssetRecord ToAsset(AudioAsset row) => new()
    {
        AssetId = row.AssetId, Path = row.FilePath, RelativePath = row.RelativePath,
        Name = row.FileName, Folder = row.RelativeFolder, Root = row.SourcePath, Library = row.LibraryName,
        Duration = row.DurationSeconds, Channels = row.Channels, SampleRate = row.SampleRate, BitDepth = row.BitDepth,
        SourceType = row.Format, Size = row.FileSize, ArtworkPath = row.ArtworkPath, Description = row.Description,
        Keywords = row.Keywords, CatId = row.CatId, Category = row.Category, Subcategory = row.Subcategory,
        WorkflowStatus = row.WorkflowStatus, Marked = row.Marked, PreviewCount = row.PreviewCount,
        LastPreviewed = row.LastPreviewed, Indexed = row.Indexed, Ready = row.Ready, UsedCount = row.UsedCount,
        LastUsed = row.LastUsed, RootId = row.RootId, LibraryId = row.LibraryId, LastSeenUtc = row.LastSeenUtc
    };
}
