using System.Text.Json;

namespace PsyReaSFX.Desktop.Services;

public sealed class DesktopPreferences
{
    public int SchemaVersion { get; set; } = 12;
    public string Language { get; set; } = "zh-CN";
    public bool AutoPreview { get; set; } = true;
    public bool NavigationVisible { get; set; } = true;
    public bool InspectorVisible { get; set; } = true;
    public int InlineWaveformResolution { get; set; } = 256;
    public int DetailWaveformResolution { get; set; } = 4096;
    public string WaveformCacheDirectory { get; set; } = "";
    public double AuditionPitchSemitones { get; set; }
    public double AuditionRate { get; set; } = 1;
    public double AuditionGainDb { get; set; }
    public bool PreservePitch { get; set; } = true;
    public bool ReverseAudition { get; set; }
    public bool LoopSelection { get; set; }
    public string SpaceKeyBehavior { get; set; } = "pause_resume";
    public string ThemePreset { get; set; } = "dark";
    public string FrameColor { get; set; } = "#090B0F";
    public string PanelColor { get; set; } = "#0F1217";
    public string HeaderColor { get; set; } = "#171C23";
    public string LineColor { get; set; } = "#27313C";
    public string TextColor { get; set; } = "#DCE2E8";
    public string MutedTextColor { get; set; } = "#8C97A3";
    public string AccentColor { get; set; } = "#1684D8";
    public string SelectedRowColor { get; set; } = "#247CCB";
    public string PlayedTextColor { get; set; } = "#F1C84B";
    public string WaveformColor { get; set; } = "#D7E0E8";
    public string SelectedWaveformColor { get; set; } = "#FFFFFF";
    public string PlayedWaveformColor { get; set; } = "#F1C84B";
    public bool HighlightPlayedWaveform { get; set; }
    public string MarkedWaveformColor { get; set; } = "#19D8FF";
    public string SelectionColor { get; set; } = "#1684D8";
    public string PlayheadColor { get; set; } = "#19D8FF";
    public string RegionColor { get; set; } = "#4F9DE8";
    public bool ShowLoudnessMetrics { get; set; } = true;
    public bool ShowLufsI { get; set; } = true;
    public bool ShowLufsM { get; set; } = true;
    public bool ShowLufsS { get; set; }
    public bool ShowTruePeak { get; set; }
    public bool LoudnessMatchAudition { get; set; }
    public double LoudnessMatchTarget { get; set; } = -18;
    public double TransientThresholdDb { get; set; } = -12.4;
    public double TransientSmoothingMs { get; set; } = 8;
    public double TransientMinIntervalMs { get; set; } = 140;
    public double TransientPreRollMs { get; set; } = 20;
    public double TransientPostRollMs { get; set; } = 180;
    public int TransientMaxRegions { get; set; } = 64;
    public bool ReplaceTransientSuggestions { get; set; } = true;
    public string TransferOutputDirectory { get; set; } = "";
    public string TransferNamingTemplate { get; set; } = "{name}";
    public bool TransferLowercase { get; set; }
    public string TransferScope { get; set; } = "selection";
    public string TransferFormat { get; set; } = "wav24";
    public string TransferSampleRate { get; set; } = "source";
    public string TransferChannels { get; set; } = "source";
    public bool TransferPreserveMetadata { get; set; } = true;
    public double TransferFadeInMs { get; set; } = 5;
    public double TransferFadeOutMs { get; set; } = 20;
    public string TransferNormalizeMode { get; set; } = "off";
    public double TransferNormalizeTarget { get; set; } = -1;
    public bool TransferDither { get; set; }
    public bool TransferNoiseShaping { get; set; }
    public bool TransferSmartTail { get; set; }
    public double TransferTailThresholdDb { get; set; } = -60;
    public double TransferTailMaximumMs { get; set; } = 5000;
    public double TransferTailHoldMs { get; set; } = 180;
    public bool TransferVariantsEnabled { get; set; }
    public string TransferVariantPitches { get; set; } = "0";
    public string TransferVariantRates { get; set; } = "1";
    public string TransferVariantGains { get; set; } = "0";
    public bool TransferVariantReverse { get; set; }
    public bool TransferVariantAutoSuffix { get; set; } = true;
    public string TransferCollisionPolicy { get; set; } = "increment";
    public bool TransferOpenFolderAfter { get; set; }
    public bool WatchFoldersEnabled { get; set; } = true;
    public int WatchFolderDebounceSeconds { get; set; } = 5;
    public bool ResumeInterruptedScan { get; set; } = true;
    public bool AutomaticCatalogBackup { get; set; } = true;
    public int CatalogBackupRetention { get; set; } = 10;
    public Dictionary<string, bool> ResultColumnVisibility { get; set; } = new(StringComparer.OrdinalIgnoreCase);
    public Dictionary<string, double> ResultColumnWidths { get; set; } = new(StringComparer.OrdinalIgnoreCase);
    public Dictionary<string, bool> SidebarSectionExpanded { get; set; } = new(StringComparer.OrdinalIgnoreCase);

    public DesktopPreferences Copy() => new()
    {
        SchemaVersion = SchemaVersion,
        Language = Language,
        AutoPreview = AutoPreview,
        NavigationVisible = NavigationVisible,
        InspectorVisible = InspectorVisible,
        InlineWaveformResolution = InlineWaveformResolution,
        DetailWaveformResolution = DetailWaveformResolution,
        WaveformCacheDirectory = WaveformCacheDirectory,
        AuditionPitchSemitones = AuditionPitchSemitones,
        AuditionRate = AuditionRate,
        AuditionGainDb = AuditionGainDb,
        PreservePitch = PreservePitch,
        ReverseAudition = ReverseAudition,
        LoopSelection = LoopSelection,
        SpaceKeyBehavior = SpaceKeyBehavior,
        ThemePreset = ThemePreset,
        FrameColor = FrameColor,
        PanelColor = PanelColor,
        HeaderColor = HeaderColor,
        LineColor = LineColor,
        TextColor = TextColor,
        MutedTextColor = MutedTextColor,
        AccentColor = AccentColor,
        SelectedRowColor = SelectedRowColor,
        PlayedTextColor = PlayedTextColor,
        WaveformColor = WaveformColor,
        SelectedWaveformColor = SelectedWaveformColor,
            PlayedWaveformColor = PlayedWaveformColor,
            HighlightPlayedWaveform = HighlightPlayedWaveform,
        MarkedWaveformColor = MarkedWaveformColor,
        SelectionColor = SelectionColor,
        PlayheadColor = PlayheadColor,
        RegionColor = RegionColor,
        ShowLoudnessMetrics = ShowLoudnessMetrics,
        ShowLufsI = ShowLufsI,
        ShowLufsM = ShowLufsM,
        ShowLufsS = ShowLufsS,
        ShowTruePeak = ShowTruePeak,
        LoudnessMatchAudition = LoudnessMatchAudition,
        LoudnessMatchTarget = LoudnessMatchTarget,
        TransientThresholdDb = TransientThresholdDb,
        TransientSmoothingMs = TransientSmoothingMs,
        TransientMinIntervalMs = TransientMinIntervalMs,
        TransientPreRollMs = TransientPreRollMs,
        TransientPostRollMs = TransientPostRollMs,
        TransientMaxRegions = TransientMaxRegions,
        ReplaceTransientSuggestions = ReplaceTransientSuggestions,
        TransferOutputDirectory = TransferOutputDirectory,
        TransferNamingTemplate = TransferNamingTemplate,
        TransferLowercase = TransferLowercase,
        TransferScope = TransferScope,
        TransferFormat = TransferFormat,
        TransferSampleRate = TransferSampleRate,
        TransferChannels = TransferChannels,
        TransferPreserveMetadata = TransferPreserveMetadata,
        TransferFadeInMs = TransferFadeInMs,
        TransferFadeOutMs = TransferFadeOutMs,
        TransferNormalizeMode = TransferNormalizeMode,
        TransferNormalizeTarget = TransferNormalizeTarget,
        TransferDither = TransferDither,
        TransferNoiseShaping = TransferNoiseShaping,
        TransferSmartTail = TransferSmartTail,
        TransferTailThresholdDb = TransferTailThresholdDb,
        TransferTailMaximumMs = TransferTailMaximumMs,
        TransferTailHoldMs = TransferTailHoldMs,
        TransferVariantsEnabled = TransferVariantsEnabled,
        TransferVariantPitches = TransferVariantPitches,
        TransferVariantRates = TransferVariantRates,
        TransferVariantGains = TransferVariantGains,
        TransferVariantReverse = TransferVariantReverse,
        TransferVariantAutoSuffix = TransferVariantAutoSuffix,
        TransferCollisionPolicy = TransferCollisionPolicy,
        TransferOpenFolderAfter = TransferOpenFolderAfter,
        WatchFoldersEnabled = WatchFoldersEnabled,
        WatchFolderDebounceSeconds = WatchFolderDebounceSeconds,
        ResumeInterruptedScan = ResumeInterruptedScan,
        AutomaticCatalogBackup = AutomaticCatalogBackup,
        CatalogBackupRetention = CatalogBackupRetention,
        ResultColumnVisibility = new Dictionary<string, bool>(ResultColumnVisibility, StringComparer.OrdinalIgnoreCase),
        ResultColumnWidths = new Dictionary<string, double>(ResultColumnWidths, StringComparer.OrdinalIgnoreCase),
        SidebarSectionExpanded = new Dictionary<string, bool>(SidebarSectionExpanded, StringComparer.OrdinalIgnoreCase)
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
            if (preferences.SidebarSectionExpanded == null) { preferences.SidebarSectionExpanded = new(StringComparer.OrdinalIgnoreCase); migrated = true; }
            if (string.IsNullOrWhiteSpace(preferences.Language)) { preferences.Language = "zh-CN"; migrated = true; }
            if (string.IsNullOrWhiteSpace(preferences.SpaceKeyBehavior)) { preferences.SpaceKeyBehavior = "pause_resume"; migrated = true; }
            if (string.IsNullOrWhiteSpace(preferences.ThemePreset)) { preferences.ThemePreset = "dark"; migrated = true; }
            if (preferences.SchemaVersion < 8)
            {
                var preset = preferences.ThemePreset.Equals("classic", StringComparison.OrdinalIgnoreCase) ? "classic" : "dark";
                ThemeManager.FillMissingThemeColors(preferences, preset);
                preferences.SchemaVersion = 8;
                migrated = true;
            }
            if (preferences.SchemaVersion < 9)
            {
                preferences.SchemaVersion = 9;
                migrated = true;
            }
            if (preferences.SchemaVersion < 10)
            {
                preferences.TransferVariantAutoSuffix = true;
                preferences.SchemaVersion = 10;
                migrated = true;
            }
            if (preferences.SchemaVersion < 11)
            {
                preferences.WatchFoldersEnabled = true;
                preferences.WatchFolderDebounceSeconds = 5;
                preferences.ResumeInterruptedScan = true;
                preferences.AutomaticCatalogBackup = true;
                preferences.CatalogBackupRetention = 10;
                preferences.SchemaVersion = 11;
                migrated = true;
            }
            if (preferences.SchemaVersion < 12)
            {
                preferences.WaveformCacheDirectory = LuaWaveCache.DefaultCacheDirectory;
                preferences.SchemaVersion = 12;
                migrated = true;
            }
            if (string.IsNullOrWhiteSpace(preferences.WaveformCacheDirectory))
            {
                preferences.WaveformCacheDirectory = LuaWaveCache.DefaultCacheDirectory;
                migrated = true;
            }
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
