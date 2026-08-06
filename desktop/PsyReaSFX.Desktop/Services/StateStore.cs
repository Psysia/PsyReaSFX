using PsyReaSFX.Data;

namespace PsyReaSFX.Desktop.Services;

public sealed class StateStore
{
    private readonly PsyReaSFXDatabase _database = new();
    public string DataDirectory => _database.DataDirectory;
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

    public Task SaveAssetDetailsAsync(IEnumerable<AudioAsset> assets, CancellationToken cancellationToken = default) =>
        _database.SaveAssetDetailsAsync(assets.Select(ToAsset), cancellationToken);

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
