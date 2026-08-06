using System.Text.Json;

namespace PsyReaSFX.Desktop.Services;

public sealed class DesktopPreferences
{
    public int SchemaVersion { get; set; } = 3;
    public bool AutoPreview { get; set; } = true;
    public bool NavigationVisible { get; set; } = true;
    public bool InspectorVisible { get; set; } = true;
    public int InlineWaveformResolution { get; set; } = 256;
    public int DetailWaveformResolution { get; set; } = 4096;
    public Dictionary<string, bool> ResultColumnVisibility { get; set; } = new(StringComparer.OrdinalIgnoreCase);
    public Dictionary<string, double> ResultColumnWidths { get; set; } = new(StringComparer.OrdinalIgnoreCase);

    public DesktopPreferences Copy() => new()
    {
        SchemaVersion = SchemaVersion,
        AutoPreview = AutoPreview,
        NavigationVisible = NavigationVisible,
        InspectorVisible = InspectorVisible,
        InlineWaveformResolution = InlineWaveformResolution,
        DetailWaveformResolution = DetailWaveformResolution,
        ResultColumnVisibility = new Dictionary<string, bool>(ResultColumnVisibility, StringComparer.OrdinalIgnoreCase),
        ResultColumnWidths = new Dictionary<string, double>(ResultColumnWidths, StringComparer.OrdinalIgnoreCase)
    };
}

public sealed class DesktopPreferencesStore
{
    public string DirectoryPath { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PsyReaSFX", "Desktop");
    public string FilePath => Path.Combine(DirectoryPath, "settings-v1.json");

    public DesktopPreferences Load()
    {
        try
        {
            if (!File.Exists(FilePath)) return new DesktopPreferences();
            var preferences = JsonSerializer.Deserialize<DesktopPreferences>(File.ReadAllText(FilePath)) ?? new DesktopPreferences();
            var migrated = false;
            if (preferences.SchemaVersion < 2)
            {
                // Alpha 2 RC2 wrote 512 as a default even when the user never
                // selected it. Lua Stable uses 256 for its smooth compact list.
                preferences.InlineWaveformResolution = 256;
                migrated = true;
            }
            if (preferences.ResultColumnVisibility == null) { preferences.ResultColumnVisibility = new(StringComparer.OrdinalIgnoreCase); migrated = true; }
            if (preferences.ResultColumnWidths == null) { preferences.ResultColumnWidths = new(StringComparer.OrdinalIgnoreCase); migrated = true; }
            if (preferences.SchemaVersion < 3) { preferences.SchemaVersion = 3; migrated = true; }
            if (migrated) Save(preferences);
            return preferences;
        }
        catch (Exception exception)
        {
            AppDiagnostics.Write("Desktop preferences could not be loaded; defaults were used.", exception);
            return new DesktopPreferences();
        }
    }

    public void Save(DesktopPreferences preferences)
    {
        Directory.CreateDirectory(DirectoryPath);
        File.WriteAllText(FilePath, JsonSerializer.Serialize(preferences, new JsonSerializerOptions { WriteIndented = true }));
    }
}
