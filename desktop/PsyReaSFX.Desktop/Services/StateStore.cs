using PsyReaSFX.Data;

namespace PsyReaSFX.Desktop.Services;

public sealed class StateStore
{
    private readonly PsyReaSFXDatabase _database = new();
    public string DataDirectory => _database.DataDirectory;
    public string DatabasePath => _database.DatabasePath;
    public MigrationSummary? LastMigration { get; private set; }
    public Exception? LastError { get; private set; }

    public async Task<PersistedState> LoadAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            AppDiagnostics.Write("Opening desktop catalog.");
            await _database.InitializeAsync(cancellationToken);
            LastMigration = await _database.ImportLuaIfNeededAsync(cancellationToken: cancellationToken);
            var snapshot = await _database.LoadSnapshotAsync(cancellationToken);
            var state = FromSnapshot(snapshot);
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
        _database.SaveDesktopSnapshotAsync(ToSnapshot(state)).GetAwaiter().GetResult();
    }

    public void SaveWorkspace(PersistedState state) =>
        _database.SaveWorkspaceAsync(ToSnapshot(state)).GetAwaiter().GetResult();

    public void SaveActivities(IEnumerable<AudioAsset> assets) =>
        _database.SaveAssetActivityAsync(assets.Select(ToAsset)).GetAwaiter().GetResult();

    public Task SaveActivitiesAsync(IEnumerable<AudioAsset> assets, CancellationToken cancellationToken = default) =>
        _database.SaveAssetActivityAsync(assets.Select(ToAsset).ToArray(), cancellationToken);

    public Task SaveAssetDetailsAsync(IEnumerable<AudioAsset> assets, CancellationToken cancellationToken = default) =>
        _database.SaveAssetDetailsAsync(assets.Select(ToAsset), cancellationToken);

    public void SaveSessionPlayed(IEnumerable<string> paths) =>
        _database.ReplaceSessionPlayedAsync(paths).GetAwaiter().GetResult();

    public Task<IReadOnlyList<RegionRecord>> LoadRegionsAsync(string assetPath, CancellationToken cancellationToken = default) =>
        _database.LoadRegionsAsync(assetPath, cancellationToken);

    public Task SaveRegionAsync(RegionRecord region, CancellationToken cancellationToken = default) =>
        _database.UpsertRegionAsync(region, cancellationToken);

    public Task DeleteRegionAsync(RegionRecord region, CancellationToken cancellationToken = default) =>
        _database.DeleteRegionAsync(region, cancellationToken);

    public Task<LoudnessRecord?> LoadLoudnessAsync(string assetPath, CancellationToken cancellationToken = default) =>
        _database.LoadLoudnessAsync(assetPath, cancellationToken);

    public Task SaveLoudnessAsync(LoudnessRecord row, CancellationToken cancellationToken = default) =>
        _database.UpsertLoudnessAsync(row, cancellationToken);

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
                ArtworkChecked = row.ArtworkChecked, ArtworkScanVersion = row.ArtworkScanVersion
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
        var snapshot = new CatalogSnapshot();
        foreach (var library in state.Libraries)
        {
            snapshot.Libraries.Add(new LibraryRecord(library.Id, library.Name, library.ArtworkPath, library.IsExpanded));
            foreach (var source in library.Sources)
                snapshot.Sources.Add(new SourceRecord(source.Id, library.Id, source.Path, source.Alias, source.Enabled, source.ArtworkPath, source.ArtworkChecked, source.ArtworkScanVersion));
        }
        snapshot.Assets.AddRange(state.Index.Select(ToAsset));
        snapshot.Favorites.UnionWith(state.Favorites);
        snapshot.SessionPlayed.UnionWith(state.Index.Where(asset => asset.IsSessionPlayed).Select(asset => asset.FilePath));
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
        FilePath = row.Path, FileName = row.Name, RelativeFolder = row.Folder, SourcePath = row.Root, LibraryName = row.Library,
        DurationSeconds = row.Duration, Channels = row.Channels, SampleRate = row.SampleRate, BitDepth = row.BitDepth,
        Format = row.SourceType, FileSize = row.Size, ArtworkPath = row.ArtworkPath, Description = row.Description,
        Keywords = row.Keywords, CatId = row.CatId, Category = row.Category, Subcategory = row.Subcategory,
        WorkflowStatus = row.WorkflowStatus, Marked = row.Marked, PreviewCount = row.PreviewCount,
        LastPreviewed = row.LastPreviewed, Indexed = row.Indexed, Ready = row.Ready, UsedCount = row.UsedCount,
        LastUsed = row.LastUsed, RootId = row.RootId, LibraryId = row.LibraryId
    };

    private static AssetRecord ToAsset(AudioAsset row) => new()
    {
        Path = row.FilePath, Name = row.FileName, Folder = row.RelativeFolder, Root = row.SourcePath, Library = row.LibraryName,
        Duration = row.DurationSeconds, Channels = row.Channels, SampleRate = row.SampleRate, BitDepth = row.BitDepth,
        SourceType = row.Format, Size = row.FileSize, ArtworkPath = row.ArtworkPath, Description = row.Description,
        Keywords = row.Keywords, CatId = row.CatId, Category = row.Category, Subcategory = row.Subcategory,
        WorkflowStatus = row.WorkflowStatus, Marked = row.Marked, PreviewCount = row.PreviewCount,
        LastPreviewed = row.LastPreviewed, Indexed = row.Indexed, Ready = row.Ready, UsedCount = row.UsedCount,
        LastUsed = row.LastUsed, RootId = row.RootId, LibraryId = row.LibraryId
    };
}
