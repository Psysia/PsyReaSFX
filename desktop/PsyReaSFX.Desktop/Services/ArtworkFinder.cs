namespace PsyReaSFX.Desktop.Services;

public static class ArtworkFinder
{
    private static readonly string[] Names = ["artwork", "cover", "folder", "front", "album", "thumbnail"];
    private static readonly HashSet<string> Extensions = new(StringComparer.OrdinalIgnoreCase) { ".png", ".jpg", ".jpeg", ".webp" };

    public static string FindForSource(string sourcePath)
    {
        if (!Directory.Exists(sourcePath)) return "";
        var candidates = new List<string>();
        Collect(sourcePath, candidates);
        CollectArtworkChildren(sourcePath, candidates);
        try
        {
            var parent = Directory.GetParent(sourcePath)?.FullName;
            if (!string.IsNullOrWhiteSpace(parent)) CollectArtworkChildren(parent, candidates);
            foreach (var folder in Directory.EnumerateDirectories(sourcePath).Take(100))
            {
                var name = Path.GetFileName(folder).ToLowerInvariant();
                if (Names.Any(n => name.Contains(n, StringComparison.OrdinalIgnoreCase)) || name.StartsWith("2."))
                    Collect(folder, candidates, true);
            }
        }
        catch { }
        return candidates
            .Select(path => (Path: path, Score: Score(path)))
            .OrderBy(x => x.Score)
            .ThenBy(x => x.Path.Length)
            .Select(x => x.Path)
            .FirstOrDefault() ?? "";
    }

    private static void CollectArtworkChildren(string root, List<string> candidates)
    {
        try
        {
            foreach (var folder in Directory.EnumerateDirectories(root).Take(160))
            {
                var name = Path.GetFileName(folder).ToLowerInvariant();
                if (Names.Any(token => name.Contains(token, StringComparison.OrdinalIgnoreCase))
                    || name.StartsWith("2.") || name.StartsWith("02"))
                    Collect(folder, candidates, true);
            }
        }
        catch { }
    }

    private static void Collect(string folder, List<string> target, bool recurse = false)
    {
        try
        {
            var option = recurse ? SearchOption.AllDirectories : SearchOption.TopDirectoryOnly;
            target.AddRange(Directory.EnumerateFiles(folder, "*", option)
                .Where(p => Extensions.Contains(Path.GetExtension(p))).Take(300));
        }
        catch { }
    }

    private static int Score(string path)
    {
        var name = Path.GetFileNameWithoutExtension(path).ToLowerInvariant();
        var score = 100;
        for (var i = 0; i < Names.Length; i++)
            if (name.Equals(Names[i], StringComparison.OrdinalIgnoreCase)) score = Math.Min(score, i);
            else if (name.Contains(Names[i], StringComparison.OrdinalIgnoreCase)) score = Math.Min(score, 20 + i);
        try
        {
            using var stream = File.OpenRead(path);
            var decoder = System.Windows.Media.Imaging.BitmapDecoder.Create(stream,
                System.Windows.Media.Imaging.BitmapCreateOptions.DelayCreation,
                System.Windows.Media.Imaging.BitmapCacheOption.None);
            var frame = decoder.Frames[0];
            var ratio = frame.PixelHeight > 0 ? frame.PixelWidth / (double)frame.PixelHeight : 10;
            score += (int)(Math.Abs(1 - ratio) * 40);
        }
        catch { score += 50; }
        return score;
    }
}
