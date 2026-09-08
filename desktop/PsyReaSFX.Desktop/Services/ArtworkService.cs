namespace PsyReaSFX.Desktop.Services;

public sealed class ArtworkService : IArtworkService
{
    public string FindForSource(string sourcePath) => ArtworkFinder.FindForSource(sourcePath);

    public Task<string> FindForSourceAsync(string sourcePath, CancellationToken cancellationToken = default) =>
        Task.Run(() =>
        {
            cancellationToken.ThrowIfCancellationRequested();
            var result = ArtworkFinder.FindForSource(sourcePath);
            cancellationToken.ThrowIfCancellationRequested();
            return result;
        }, cancellationToken);

    public void ApplyFallbacks(PersistedState state)
    {
        var sourcesById = state.Libraries.SelectMany(library => library.Sources)
            .Where(source => !string.IsNullOrWhiteSpace(source.Id))
            .GroupBy(source => source.Id, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase);
        var sourcesByPath = state.Libraries.SelectMany(library => library.Sources)
            .Where(source => !string.IsNullOrWhiteSpace(source.Path))
            .GroupBy(source => source.Path, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase);

        foreach (var asset in state.Index)
        {
            if (!string.IsNullOrWhiteSpace(asset.ArtworkPath) && File.Exists(asset.ArtworkPath)) continue;
            LibrarySource? source = null;
            if (!string.IsNullOrWhiteSpace(asset.RootId)) sourcesById.TryGetValue(asset.RootId, out source);
            if (source == null && !string.IsNullOrWhiteSpace(asset.SourcePath))
                sourcesByPath.TryGetValue(asset.SourcePath, out source);
            if (source != null && !string.IsNullOrWhiteSpace(source.ArtworkPath) && File.Exists(source.ArtworkPath))
                asset.ArtworkPath = source.ArtworkPath;
        }
    }

    public void ApplyToSource(LibrarySource source, IEnumerable<AudioAsset> assets, string artworkPath)
    {
        source.ArtworkPath = artworkPath;
        source.ArtworkChecked = true;
        foreach (var asset in assets.Where(asset =>
                     asset.RootId.Equals(source.Id, StringComparison.OrdinalIgnoreCase)
                     || asset.SourcePath.Equals(source.Path, StringComparison.OrdinalIgnoreCase)))
            asset.ArtworkPath = artworkPath;
    }
}
