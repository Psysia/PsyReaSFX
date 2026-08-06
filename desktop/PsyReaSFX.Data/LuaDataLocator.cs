namespace PsyReaSFX.Data;

public static class LuaDataLocator
{
    private static readonly string[] RequiredSignals = ["libraries_v2.tsv", "index_v3.tsv", "config.tsv"];

    public static string? Find()
    {
        var candidates = new List<string?>
        {
            Environment.GetEnvironmentVariable("PSYREASFX_REAPER_DATA"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "REAPER", "Scripts", "PsyReaSFX"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyMusic), "Reaper", "Scripts", "PsyReaSFX"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyMusic), "REAPER", "Scripts", "PsyReaSFX")
        };

        return candidates
            .Where(path => !string.IsNullOrWhiteSpace(path))
            .Select(path => Path.GetFullPath(path!))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .FirstOrDefault(path => Directory.Exists(path) && RequiredSignals.Any(file => File.Exists(Path.Combine(path, file))));
    }
}
