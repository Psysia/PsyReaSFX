namespace PsyReaSFX.Desktop.Services;

public sealed class OrganizationService : IOrganizationService
{
    public AssetCollection CreateCollection(string kind, string name, IEnumerable<AudioAsset> assets)
    {
        var collection = new AssetCollection { Name = name, Kind = kind };
        AddAssets(collection, assets);
        return collection;
    }

    public int AddAssets(AssetCollection collection, IEnumerable<AudioAsset> assets)
    {
        var existing = ActivePaths(collection);
        var added = 0;
        foreach (var path in assets.Select(asset => asset.FilePath).Where(path => !string.IsNullOrWhiteSpace(path)))
        {
            if (!existing.Add(path)) continue;
            collection.Items.Add(path);
            added++;
        }
        return added;
    }

    public int RemoveAssets(AssetCollection collection, IEnumerable<AudioAsset> assets)
    {
        var remove = assets.Select(asset => asset.FilePath).ToHashSet(StringComparer.OrdinalIgnoreCase);
        var removed = 0;
        for (var index = collection.Items.Count - 1; index >= 0; index--)
        {
            if (!remove.Contains(collection.Items[index])) continue;
            collection.Items.RemoveAt(index);
            removed++;
        }
        return removed;
    }

    public HashSet<string> ActivePaths(AssetCollection collection) =>
        collection.Items.ToHashSet(StringComparer.OrdinalIgnoreCase);

    public string BuildSavedQuery(string text, string category, string format, int channels)
    {
        var parts = new List<string>();
        if (!string.IsNullOrWhiteSpace(text)) parts.Add(text.Trim());
        if (!string.IsNullOrWhiteSpace(category)) parts.Add($"category:\"{category}\"");
        if (!string.IsNullOrWhiteSpace(format)) parts.Add($"format:{format}");
        if (channels > 0) parts.Add($"channels:{channels}");
        return string.Join(' ', parts);
    }

    public SavedSearchDefinition CreateSavedSearch(
        string name, string query, string view, string libraryId, string root,
        string statusFilter, string collectionId, string sortMode, bool sortDescending) => new()
    {
        Name = name,
        Query = query,
        View = view,
        LibraryId = libraryId,
        Root = root,
        StatusFilter = statusFilter,
        CollectionId = collectionId,
        SortMode = sortMode,
        SortDescending = sortDescending
    };
}
