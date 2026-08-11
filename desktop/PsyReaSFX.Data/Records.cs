namespace PsyReaSFX.Data;

public sealed record LibraryRecord(
    string Id,
    string Name,
    string ArtworkPath = "",
    bool Expanded = true);

public sealed record SourceRecord(
    string Id,
    string LibraryId,
    string Path,
    string Alias = "",
    bool Enabled = true,
    string ArtworkPath = "",
    bool ArtworkChecked = false,
    int ArtworkScanVersion = 0);

public sealed record AssetRecord
{
    public string Path { get; init; } = "";
    public string Name { get; init; } = "";
    public string Folder { get; init; } = "";
    public string Root { get; init; } = "";
    public string Library { get; init; } = "";
    public double Duration { get; init; }
    public int Channels { get; init; }
    public int SampleRate { get; init; }
    public int BitDepth { get; init; }
    public string SourceType { get; init; } = "";
    public long Size { get; init; }
    public string Description { get; init; } = "";
    public string Keywords { get; init; } = "";
    public string CatId { get; init; } = "";
    public string Category { get; init; } = "";
    public string Subcategory { get; init; } = "";
    public string ArtworkPath { get; init; } = "";
    public string WorkflowStatus { get; init; } = "none";
    public bool Marked { get; init; }
    public int PreviewCount { get; init; }
    public double LastPreviewed { get; init; }
    public bool Indexed { get; init; }
    public bool Ready { get; init; }
    public int UsedCount { get; init; }
    public double LastUsed { get; init; }
    public string RootId { get; init; } = "";
    public string LibraryId { get; init; } = "";
}

public sealed record CollectionRecord(string Id, string Name, string Kind);
public sealed record CollectionItemRecord(string CollectionId, string Path, int SortOrder);
public sealed record SavedSearchRecord(
    string Id,
    string Name,
    string Query,
    string View,
    string Root,
    string SortMode,
    bool SortDescending,
    string? StatusFilter,
    string? CollectionId,
    string? LibraryId);
public sealed record RegionRecord(string AssetPath, double Start, double Finish, string Name, string Source, string BatchId);
public sealed record LoudnessRecord(string AssetPath, long Size, double? LufsI, double? LufsM, double? LufsS, double? TruePeak);

public sealed class CatalogSnapshot
{
    public List<LibraryRecord> Libraries { get; } = [];
    public List<SourceRecord> Sources { get; } = [];
    public List<AssetRecord> Assets { get; } = [];
    public HashSet<string> Favorites { get; } = new(StringComparer.OrdinalIgnoreCase);
    public HashSet<string> SessionPlayed { get; } = new(StringComparer.OrdinalIgnoreCase);
    public List<CollectionRecord> Collections { get; } = [];
    public List<CollectionItemRecord> CollectionItems { get; } = [];
    public List<SavedSearchRecord> SavedSearches { get; } = [];
}

public sealed record MigrationSummary(
    string? SourceDirectory,
    int Libraries,
    int Sources,
    int Assets,
    int Collections,
    int SavedSearches,
    int HistoryRows,
    int Regions,
    int LoudnessRows,
    bool Imported);
