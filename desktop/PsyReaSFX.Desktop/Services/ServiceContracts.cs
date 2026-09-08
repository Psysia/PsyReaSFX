using PsyReaSFX.Data;

namespace PsyReaSFX.Desktop.Services;

public interface IStorageService
{
    string DataDirectory { get; }
    string DatabasePath { get; }
    MigrationSummary? LastMigration { get; }
    Exception? LastError { get; }
    bool CanWrite { get; }
    Task<PersistedState> LoadAsync(CancellationToken cancellationToken = default);
    Task SaveAsync(PersistedState state, CancellationToken cancellationToken = default);
    Task SaveWorkspaceAsync(PersistedState state, CancellationToken cancellationToken = default);
    Task SaveActivitiesAsync(IEnumerable<AudioAsset> assets, CancellationToken cancellationToken = default);
    Task SaveAssetDetailsAsync(IEnumerable<AudioAsset> assets, CancellationToken cancellationToken = default);
    void SaveSessionPlayed(IEnumerable<string> paths);
    Task SaveSessionPlayedAsync(IEnumerable<string> paths, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<RegionRecord>> LoadRegionsAsync(string assetPath, CancellationToken cancellationToken = default);
    Task SaveRegionAsync(RegionRecord region, CancellationToken cancellationToken = default);
    Task DeleteRegionAsync(RegionRecord region, CancellationToken cancellationToken = default);
    Task<LoudnessRecord?> LoadLoudnessAsync(string assetPath, CancellationToken cancellationToken = default);
    Task SaveLoudnessAsync(LoudnessRecord row, CancellationToken cancellationToken = default);
    Task AddProjectUsageAsync(ProjectUsageRecord row, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<ProjectUsageRecord>> LoadProjectUsageAsync(int limit = 500, CancellationToken cancellationToken = default);
}

public interface ICatalogIndexer
{
    IReadOnlyList<FailedScanItem> LastFailures { get; }
    Task<List<AudioAsset>> BuildAsync(
        IEnumerable<LibraryDefinition> libraries,
        IEnumerable<AudioAsset> previous,
        IProgress<(int Count, string File)> progress,
        CancellationToken cancellationToken);
}

public interface IJobCoordinator
{
    BackgroundJobLease? TryStart(
        BackgroundJobKind kind,
        BackgroundJobResource resource,
        bool replaceSameKind,
        BackgroundJobPriority priority = BackgroundJobPriority.Normal);
    bool IsActive(BackgroundJobKind kind);
    void Cancel(BackgroundJobKind kind);
    Task StopAcceptingAndCancelAsync(TimeSpan timeout);
    IReadOnlyList<BackgroundJobSnapshot> Snapshot();
}

public interface IPreviewEngine : IDisposable
{
    event EventHandler? PlaybackEnded;
    event EventHandler<Exception>? PlaybackFailed;
    bool IsOpen { get; }
    bool IsPlaying { get; }
    string Path { get; }
    double Duration { get; }
    double Position { get; set; }
    double Rate { get; set; }
    double PitchSemitones { get; set; }
    double GainDb { get; set; }
    bool PreservePitch { get; set; }
    bool Reverse { get; }
    IReadOnlyList<int> AuditionChannels { get; }
    void SetAuditionChannels(IReadOnlyList<int>? auditionChannels);
    Task OpenAsync(string path, double sourcePosition, bool autoplay, CancellationToken cancellationToken = default);
    Task ReconfigureAsync(bool reverse, IReadOnlyList<int>? auditionChannels = null, CancellationToken cancellationToken = default);
    void Play();
    Task PauseAsync(CancellationToken cancellationToken = default);
    Task StopAsync(CancellationToken cancellationToken = default);
}

public interface IPreviewController : IDisposable
{
    event EventHandler? PlaybackEnded;
    event EventHandler<Exception>? PlaybackFailed;
    bool IsOpen { get; }
    bool IsPlaying { get; }
    string Path { get; }
    double Duration { get; }
    double Position { get; set; }
    double Rate { get; set; }
    double PitchSemitones { get; set; }
    double GainDb { get; set; }
    bool PreservePitch { get; set; }
    bool Reverse { get; }
    IReadOnlyList<int> AuditionChannels { get; }
    void SetAuditionChannels(IReadOnlyList<int>? auditionChannels);
    Task<bool> OpenAsync(string path, double sourcePosition, bool autoplay, CancellationToken cancellationToken = default);
    Task<bool> ReconfigureAsync(bool reverse, IReadOnlyList<int>? auditionChannels = null, CancellationToken cancellationToken = default);
    void Play();
    Task PauseAsync(CancellationToken cancellationToken = default);
    Task StopAsync(CancellationToken cancellationToken = default);
}

public interface IArtworkService
{
    string FindForSource(string sourcePath);
    Task<string> FindForSourceAsync(string sourcePath, CancellationToken cancellationToken = default);
    void ApplyFallbacks(PersistedState state);
    void ApplyToSource(LibrarySource source, IEnumerable<AudioAsset> assets, string artworkPath);
}

public interface IPathIdentityService
{
    SourcePathIdentity CaptureSource(string path);
    string Normalize(string path);
    string RelativeTo(string rootPath, string filePath);
    bool SamePhysicalSource(SourcePathIdentity left, SourcePathIdentity right);
}

public interface ITransferService
{
    Task<TransferRunResult> RunAsync(
        IReadOnlyList<TransferRequest> requests,
        TransferOptions options,
        IProgress<TransferProgress>? progress,
        CancellationToken cancellationToken);
}

public interface IOrganizationService
{
    AssetCollection CreateCollection(string kind, string name, IEnumerable<AudioAsset> assets);
    int AddAssets(AssetCollection collection, IEnumerable<AudioAsset> assets);
    int RemoveAssets(AssetCollection collection, IEnumerable<AudioAsset> assets);
    HashSet<string> ActivePaths(AssetCollection collection);
    string BuildSavedQuery(string text, string category, string format, int channels);
    SavedSearchDefinition CreateSavedSearch(
        string name, string query, string view, string libraryId, string root,
        string statusFilter, string collectionId, string sortMode, bool sortDescending);
}
