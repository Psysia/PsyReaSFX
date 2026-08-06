namespace PsyReaSFX.Data;

internal sealed class LuaImportBundle
{
    public List<LibraryRecord> Libraries { get; } = [];
    public List<SourceRecord> Sources { get; } = [];
    public List<AssetRecord> Assets { get; } = [];
    public List<CollectionRecord> Collections { get; } = [];
    public List<(string CollectionId, string Path, int SortOrder)> CollectionItems { get; } = [];
    public List<SavedSearchRecord> SavedSearches { get; } = [];
    public List<(string Path, int Count, double Last)> History { get; } = [];
    public HashSet<string> SessionPlayed { get; } = new(StringComparer.OrdinalIgnoreCase);
    public List<RegionRecord> Regions { get; } = [];
    public List<LoudnessRecord> Loudness { get; } = [];
    public Dictionary<string, string> Settings { get; } = new(StringComparer.OrdinalIgnoreCase);
}

internal static class LuaDataImporter
{
    private static readonly string[] DatabaseFields =
    [
        "path", "name", "folder", "root", "library", "duration", "channels", "sample_rate", "bit_depth",
        "source_type", "size", "description", "keywords", "catid", "category", "subcategory", "artwork_path",
        "workflow_status", "marked", "preview_count", "last_previewed", "indexed", "ready", "used_count",
        "last_used", "root_id", "library_id"
    ];

    public static async Task<LuaImportBundle> ReadAsync(string directory, CancellationToken cancellationToken)
    {
        var result = new LuaImportBundle();
        await ReadLibrariesAsync(Path.Combine(directory, "libraries_v2.tsv"), result, cancellationToken);
        await ReadAssetsAsync(Path.Combine(directory, "index_v3.tsv"), result, cancellationToken);
        await ReadCollectionsAsync(Path.Combine(directory, "collections_v1.tsv"), result, cancellationToken);
        await ReadSearchesAsync(Path.Combine(directory, "saved_searches_v1.tsv"), result, cancellationToken);
        await ReadHistoryAsync(Path.Combine(directory, "history_v1.tsv"), result, cancellationToken);
        await ReadSessionAsync(Path.Combine(directory, "last_played_session_v1.tsv"), result, cancellationToken);
        await ReadRegionsAsync(Path.Combine(directory, "regions_v1.tsv"), result, cancellationToken);
        await ReadLoudnessAsync(Path.Combine(directory, "loudness_v1.tsv"), result, cancellationToken);
        await ReadSettingsAsync(Path.Combine(directory, "config.tsv"), result, cancellationToken);
        return result;
    }

    private static async Task ReadLibrariesAsync(string path, LuaImportBundle result, CancellationToken token)
    {
        await foreach (var fields in RowsAsync(path, token))
        {
            if (fields.Length >= 3 && fields[0] == "library")
                result.Libraries.Add(new LibraryRecord(fields[1], fields[2], Field(fields, 3), Field(fields, 4) != "0"));
            else if (fields.Length >= 4 && fields[0] == "root")
                result.Sources.Add(new SourceRecord(fields[1], fields[2], fields[3], Field(fields, 4), Field(fields, 5) != "0", Field(fields, 6), LuaTsv.Boolean(Field(fields, 7)), LuaTsv.Integer(Field(fields, 8))));
        }
    }

    private static async Task ReadAssetsAsync(string path, LuaImportBundle result, CancellationToken token)
    {
        if (!File.Exists(path)) return;
        using var reader = new StreamReader(path, detectEncodingFromByteOrderMarks: true);
        var headerLine = await reader.ReadLineAsync(token);
        if (headerLine is null) return;
        var headers = LuaTsv.Split(headerLine);
        var known = headers.Select((field, index) => (field, index)).ToDictionary(x => x.field, x => x.index, StringComparer.OrdinalIgnoreCase);
        if (!DatabaseFields.All(known.ContainsKey)) return;

        while (await reader.ReadLineAsync(token) is { } line)
        {
            token.ThrowIfCancellationRequested();
            var f = LuaTsv.Split(line);
            string V(string name) => known.TryGetValue(name, out var index) && index < f.Length ? f[index] : "";
            var assetPath = V("path");
            if (string.IsNullOrWhiteSpace(assetPath)) continue;
            result.Assets.Add(new AssetRecord
            {
                Path = assetPath, Name = V("name"), Folder = V("folder"), Root = V("root"), Library = V("library"),
                Duration = LuaTsv.Number(V("duration")), Channels = LuaTsv.Integer(V("channels")), SampleRate = LuaTsv.Integer(V("sample_rate")),
                BitDepth = LuaTsv.Integer(V("bit_depth")), SourceType = V("source_type"), Size = LuaTsv.Long(V("size")),
                Description = V("description"), Keywords = V("keywords"), CatId = V("catid"), Category = V("category"), Subcategory = V("subcategory"), ArtworkPath = V("artwork_path"),
                WorkflowStatus = string.IsNullOrWhiteSpace(V("workflow_status")) ? "none" : V("workflow_status"), Marked = LuaTsv.Boolean(V("marked")),
                PreviewCount = LuaTsv.Integer(V("preview_count")), LastPreviewed = LuaTsv.Number(V("last_previewed")), Indexed = LuaTsv.Boolean(V("indexed")) || LuaTsv.Number(V("duration")) > 0,
                Ready = LuaTsv.Boolean(V("ready")), UsedCount = LuaTsv.Integer(V("used_count")), LastUsed = LuaTsv.Number(V("last_used")), RootId = V("root_id"), LibraryId = V("library_id")
            });
        }
    }

    private static async Task ReadCollectionsAsync(string path, LuaImportBundle result, CancellationToken token)
    {
        var orderByCollection = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        await foreach (var f in RowsAsync(path, token))
        {
            if (f.Length >= 3 && f[0] == "collection") result.Collections.Add(new CollectionRecord(f[1], f[2], Field(f, 3) == "project" ? "project" : "playlist"));
            else if (f.Length >= 3 && f[0] == "item")
            {
                var order = orderByCollection.TryGetValue(f[1], out var current) ? current : 0;
                result.CollectionItems.Add((f[1], f[2], order)); orderByCollection[f[1]] = order + 1;
            }
        }
    }

    private static async Task ReadSearchesAsync(string path, LuaImportBundle result, CancellationToken token)
    {
        await foreach (var f in RowsAsync(path, token))
            if (f.Length >= 3 && f[0] == "search")
                result.SavedSearches.Add(new SavedSearchRecord(f[1], f[2], Field(f, 3), EmptyDefault(Field(f, 4), "all"), Field(f, 5), EmptyDefault(Field(f, 6), "name"), Field(f, 7) == "1", EmptyNull(Field(f, 8)), EmptyNull(Field(f, 9)), EmptyNull(Field(f, 10))));
    }

    private static async Task ReadHistoryAsync(string path, LuaImportBundle result, CancellationToken token)
    {
        await foreach (var f in RowsAsync(path, token))
            if (f.Length >= 2 && f[0] == "preview") result.History.Add((f[1], LuaTsv.Integer(Field(f, 2)), LuaTsv.Number(Field(f, 3))));
    }

    private static async Task ReadSessionAsync(string path, LuaImportBundle result, CancellationToken token)
    {
        await foreach (var f in RowsAsync(path, token))
            if (f.Length >= 2 && f[0] == "played") result.SessionPlayed.Add(f[1]);
    }

    private static async Task ReadRegionsAsync(string path, LuaImportBundle result, CancellationToken token)
    {
        await foreach (var f in RowsAsync(path, token))
            if (f.Length >= 4) result.Regions.Add(new RegionRecord(f[0], LuaTsv.Number(f[1]), LuaTsv.Number(f[2]), f[3], EmptyDefault(Field(f, 4), "manual"), Field(f, 5)));
    }

    private static async Task ReadLoudnessAsync(string path, LuaImportBundle result, CancellationToken token)
    {
        await foreach (var f in RowsAsync(path, token))
            if (f.Length >= 2) result.Loudness.Add(new LoudnessRecord(f[0], LuaTsv.Long(f[1]), LuaTsv.NullableNumber(Field(f, 2)), LuaTsv.NullableNumber(Field(f, 3)), LuaTsv.NullableNumber(Field(f, 4)), LuaTsv.NullableNumber(Field(f, 5))));
    }

    private static async Task ReadSettingsAsync(string path, LuaImportBundle result, CancellationToken token)
    {
        await foreach (var f in RowsAsync(path, token))
            if (f.Length >= 3 && f[0] == "setting") result.Settings[f[1]] = f[2];
    }

    private static async IAsyncEnumerable<string[]> RowsAsync(string path, [System.Runtime.CompilerServices.EnumeratorCancellation] CancellationToken token)
    {
        if (!File.Exists(path)) yield break;
        using var reader = new StreamReader(path, detectEncodingFromByteOrderMarks: true);
        while (await reader.ReadLineAsync(token) is { } line)
        {
            token.ThrowIfCancellationRequested();
            if (line.Length > 0) yield return LuaTsv.Split(line);
        }
    }

    private static string Field(string[] fields, int index) => index >= 0 && index < fields.Length ? fields[index] : "";
    private static string EmptyDefault(string value, string fallback) => string.IsNullOrWhiteSpace(value) ? fallback : value;
    private static string? EmptyNull(string value) => string.IsNullOrWhiteSpace(value) ? null : value;
}
