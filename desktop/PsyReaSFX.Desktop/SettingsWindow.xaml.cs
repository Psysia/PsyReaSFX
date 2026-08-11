using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using PsyReaSFX.Desktop.Controls;
using PsyReaSFX.Desktop.Services;

namespace PsyReaSFX.Desktop;

public partial class SettingsWindow : Window
{
    private readonly DesktopPreferences _originalPreferences;
    private readonly CatalogReliabilityService _reliability;
    private readonly string _databasePath;
    private bool _committed;
    private bool _moveExistingCache;
    public DesktopPreferences Preferences { get; }

    public bool RetryFailedRequested { get; private set; }

    public SettingsWindow(DesktopPreferences preferences, string dataDirectory, CatalogReliabilityService reliability, string databasePath)
    {
        _originalPreferences = preferences.Copy();
        Preferences = preferences.Copy();
        _reliability = reliability;
        _databasePath = databasePath;
        InitializeComponent();
        ChineseLanguage.IsChecked = !UiLocalization.IsEnglish(Preferences.Language);
        EnglishLanguage.IsChecked = UiLocalization.IsEnglish(Preferences.Language);
        AutoPreviewCheck.IsChecked = Preferences.AutoPreview;
        SpacePauseResume.IsChecked = !Preferences.SpaceKeyBehavior.Equals("restart_selection", StringComparison.OrdinalIgnoreCase);
        SpaceRestartSelection.IsChecked = Preferences.SpaceKeyBehavior.Equals("restart_selection", StringComparison.OrdinalIgnoreCase);
        NavigationCheck.IsChecked = Preferences.NavigationVisible;
        InspectorCheck.IsChecked = Preferences.InspectorVisible;
        Inline256.IsChecked = Preferences.InlineWaveformResolution <= 256;
        Inline512.IsChecked = Preferences.InlineWaveformResolution > 256;
        Detail2048.IsChecked = Preferences.DetailWaveformResolution <= 2048;
        Detail4096.IsChecked = Preferences.DetailWaveformResolution > 2048;
        DarkTheme.IsChecked = Preferences.ThemePreset.Equals("dark", StringComparison.OrdinalIgnoreCase);
        ClassicTheme.IsChecked = Preferences.ThemePreset.Equals("classic", StringComparison.OrdinalIgnoreCase);
        PlayedWaveformHighlightCheck.IsChecked = Preferences.HighlightPlayedWaveform;
        ShowLoudnessCheck.IsChecked = Preferences.ShowLoudnessMetrics;
        ShowLufsICheck.IsChecked = Preferences.ShowLufsI;
        ShowLufsMCheck.IsChecked = Preferences.ShowLufsM;
        ShowLufsSCheck.IsChecked = Preferences.ShowLufsS;
        ShowTruePeakCheck.IsChecked = Preferences.ShowTruePeak;
        LoudnessMatchCheck.IsChecked = Preferences.LoudnessMatchAudition;
        LoudnessMatchTargetText.Text = Preferences.LoudnessMatchTarget.ToString("0.#", System.Globalization.CultureInfo.InvariantCulture);
        TransientThresholdText.Text = Preferences.TransientThresholdDb.ToString("0.0", System.Globalization.CultureInfo.InvariantCulture);
        TransientSmoothingText.Text = Preferences.TransientSmoothingMs.ToString("0.#", System.Globalization.CultureInfo.InvariantCulture);
        TransientIntervalText.Text = Preferences.TransientMinIntervalMs.ToString("0.#", System.Globalization.CultureInfo.InvariantCulture);
        TransientPreRollText.Text = Preferences.TransientPreRollMs.ToString("0.#", System.Globalization.CultureInfo.InvariantCulture);
        TransientPostRollText.Text = Preferences.TransientPostRollMs.ToString("0.#", System.Globalization.CultureInfo.InvariantCulture);
        TransientMaxText.Text = Preferences.TransientMaxRegions.ToString(System.Globalization.CultureInfo.InvariantCulture);
        ReplaceTransientCheck.IsChecked = Preferences.ReplaceTransientSuggestions;
        UpdateColorButtons();
        DataPathText.Text = dataDirectory;
        LogPathText.Text = AppDiagnostics.LogDirectory;
        TransferOutputPathText.Text = Preferences.TransferOutputDirectory;
        WatchFoldersCheck.IsChecked = Preferences.WatchFoldersEnabled;
        WatchDebounceText.Text = Preferences.WatchFolderDebounceSeconds.ToString(System.Globalization.CultureInfo.InvariantCulture);
        ResumeScanCheck.IsChecked = Preferences.ResumeInterruptedScan;
        AutomaticBackupCheck.IsChecked = Preferences.AutomaticCatalogBackup;
        BackupRetentionText.Text = Preferences.CatalogBackupRetention.ToString(System.Globalization.CultureInfo.InvariantCulture);
        if (string.IsNullOrWhiteSpace(Preferences.WaveformCacheDirectory))
            Preferences.WaveformCacheDirectory = LuaWaveCache.DefaultCacheDirectory;
        CacheDirectoryText.Text = Preferences.WaveformCacheDirectory;
        RefreshReliabilityStatus();
        UiLocalization.Apply(this, Preferences.Language);
    }

    private void Page_Checked(object sender, RoutedEventArgs e)
    {
        if (!IsInitialized) return;
        GeneralPage.Visibility = GeneralNav.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        AppearancePage.Visibility = AppearanceNav.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        WaveformPage.Visibility = WaveformNav.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        TransferPage.Visibility = TransferNav.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        MaintenancePage.Visibility = MaintenanceNav.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        AboutPage.Visibility = AboutNav.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
    }

    private static void OpenDirectory(string path)
    {
        Directory.CreateDirectory(path);
        Process.Start(new ProcessStartInfo("explorer.exe", path) { UseShellExecute = true });
    }

    private void OpenData_Click(object sender, RoutedEventArgs e) => OpenDirectory(DataPathText.Text);
    private void OpenLogs_Click(object sender, RoutedEventArgs e) => OpenDirectory(AppDiagnostics.LogDirectory);
    private void OpenTransferOutput_Click(object sender, RoutedEventArgs e) => OpenDirectory(Preferences.TransferOutputDirectory);
    private void OpenBackups_Click(object sender, RoutedEventArgs e) => OpenDirectory(_reliability.BackupDirectory);
    private void OpenCacheDirectory_Click(object sender, RoutedEventArgs e) => OpenDirectory(Preferences.WaveformCacheDirectory);

    private void ChangeCacheDirectory_Click(object sender, RoutedEventArgs e)
    {
        using var dialog = new System.Windows.Forms.FolderBrowserDialog
        {
            Description = T("选择 PsyReaSFX 波形缓存目录", "Choose the PsyReaSFX waveform cache directory"),
            SelectedPath = Preferences.WaveformCacheDirectory,
            UseDescriptionForTitle = true,
            ShowNewFolderButton = true
        };
        if (dialog.ShowDialog() != System.Windows.Forms.DialogResult.OK) return;
        StageCacheDirectory(dialog.SelectedPath);
    }

    private void RestoreCacheDirectory_Click(object sender, RoutedEventArgs e) => StageCacheDirectory(LuaWaveCache.DefaultCacheDirectory);

    private void StageCacheDirectory(string path)
    {
        var target = Path.GetFullPath(path);
        if (target.Equals(Preferences.WaveformCacheDirectory, StringComparison.OrdinalIgnoreCase)) return;
        var answer = MessageBox.Show(T(
                "是否在保存设置时把已有波形缓存移动到新目录？\n\n是：移动并切换\n否：只切换，旧缓存保留\n取消：不更改",
                "Move the existing waveform cache when settings are saved?\n\nYes: move and switch\nNo: switch and keep the old cache\nCancel: no change"),
            "PsyReaSFX Desktop", MessageBoxButton.YesNoCancel, MessageBoxImage.Question);
        if (answer == MessageBoxResult.Cancel) return;
        Preferences.WaveformCacheDirectory = target;
        CacheDirectoryText.Text = target;
        _moveExistingCache = answer == MessageBoxResult.Yes;
        CacheMoveStatusText.Text = _moveExistingCache
            ? T("保存时将迁移已有缓存。", "Existing cache will be migrated when saved.")
            : T("保存时只切换目录；旧缓存会保留。", "Only the directory will change; the old cache will remain.");
    }

    private void RefreshReliabilityStatus()
    {
        var checkpoint = _reliability.LoadCheckpoint();
        var failures = _reliability.LoadFailures();
        CheckpointStatusText.Text = checkpoint is { Active: true }
            ? T($"发现中断任务：已处理 {checkpoint.ProcessedFiles:N0} 个文件 · {Path.GetFileName(checkpoint.LastFile)}",
                $"Interrupted scan found: {checkpoint.ProcessedFiles:N0} files · {Path.GetFileName(checkpoint.LastFile)}")
            : T($"没有中断任务 · 失败文件 {failures.Count:N0} 个", $"No interrupted task · {failures.Count:N0} failed files");
        var latest = _reliability.LatestBackup();
        BackupStatusText.Text = latest == null
            ? T("尚无数据库备份", "No catalog backup yet")
            : T($"最新：{Path.GetFileName(latest)}", $"Latest: {Path.GetFileName(latest)}");
    }

    private void RetryFailed_Click(object sender, RoutedEventArgs e)
    {
        RetryFailedRequested = true;
        _reliability.ClearFailures();
        CheckpointStatusText.Text = T("关闭设置后将重新执行增量扫描。", "An incremental scan will run after closing Settings.");
    }

    private void ClearRecovery_Click(object sender, RoutedEventArgs e)
    {
        _reliability.ClearCheckpoint();
        _reliability.ClearFailures();
        RefreshReliabilityStatus();
    }

    private async void CreateBackup_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            BackupStatusText.Text = T("正在创建并验证备份…", "Creating and validating backup…");
            var path = await _reliability.CreateBackupAsync(_databasePath, (int)ReadDouble(BackupRetentionText, 10, 2, 50));
            BackupStatusText.Text = T($"备份完成：{Path.GetFileName(path)}", $"Backup complete: {Path.GetFileName(path)}");
        }
        catch (Exception exception) { BackupStatusText.Text = T($"备份失败：{exception.Message}", $"Backup failed: {exception.Message}"); }
    }

    private async void RestoreLatest_Click(object sender, RoutedEventArgs e)
    {
        if (MessageBox.Show(T("将在下次启动时恢复最新备份。当前数据库会保留一份恢复前副本。继续吗？",
                "The latest backup will be restored on next launch. A pre-restore copy will be retained. Continue?"),
                "PsyReaSFX Desktop", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes) return;
        try
        {
            await _reliability.StageRestoreLatestAsync();
            BackupStatusText.Text = T("恢复已安排；请关闭并重新打开 PsyReaSFX。", "Restore scheduled; close and reopen PsyReaSFX.");
        }
        catch (Exception exception) { BackupStatusText.Text = T($"无法安排恢复：{exception.Message}", $"Could not schedule restore: {exception.Message}"); }
    }

    private async void CheckCache_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            CacheStatusText.Text = T("正在验证缓存…", "Validating cache…");
            var report = await _reliability.CheckWaveCacheAsync(true);
            CacheStatusText.Text = T($"已检查 {report.Checked:N0} · 有效 {report.Valid:N0} · 移除损坏 {report.Removed:N0} · 删除失败 {report.Failed:N0}",
                $"Checked {report.Checked:N0} · valid {report.Valid:N0} · corrupt removed {report.Removed:N0} · removal failures {report.Failed:N0}");
        }
        catch (Exception exception) { CacheStatusText.Text = T($"缓存检查失败：{exception.Message}", $"Cache check failed: {exception.Message}"); }
    }

    private void Language_Checked(object sender, RoutedEventArgs e)
    {
        if (!IsInitialized || ChineseLanguage == null || EnglishLanguage == null) return;
        Preferences.Language = EnglishLanguage.IsChecked == true ? "en-US" : "zh-CN";
        UiLocalization.Apply(this, Preferences.Language);
        UpdateColorButtons();
    }

    private void ThemePreset_Checked(object sender, RoutedEventArgs e)
    {
        if (!IsInitialized || DarkTheme == null || ClassicTheme == null) return;
        ThemeManager.ApplyPreset(Preferences, ClassicTheme.IsChecked == true ? "classic" : "dark");
        ThemeManager.Apply(Preferences);
        UpdateColorButtons();
    }

    private void ColorButton_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button { Tag: string propertyName } button) return;
        var property = typeof(DesktopPreferences).GetProperty(propertyName);
        if (property?.GetValue(Preferences) is not string current) return;
        var color = ThemeManager.Parse(current, Colors.Black);
        using var dialog = new System.Windows.Forms.ColorDialog
        {
            FullOpen = true,
            AnyColor = true,
            Color = System.Drawing.Color.FromArgb(color.R, color.G, color.B)
        };
        if (dialog.ShowDialog() != System.Windows.Forms.DialogResult.OK) return;
        var next = $"#{dialog.Color.R:X2}{dialog.Color.G:X2}{dialog.Color.B:X2}";
        property.SetValue(Preferences, next);
        Preferences.ThemePreset = "custom";
        DarkTheme.IsChecked = ClassicTheme.IsChecked = false;
        ThemeManager.Apply(Preferences);
        UpdateColorButtons();
        button.Focus();
    }

    private void ResetThemeColors_Click(object sender, RoutedEventArgs e)
    {
        var preset = ClassicTheme.IsChecked == true ? "classic" : "dark";
        ThemeManager.ApplyPreset(Preferences, preset);
        DarkTheme.IsChecked = preset == "dark";
        ClassicTheme.IsChecked = preset == "classic";
        ThemeManager.Apply(Preferences);
        UpdateColorButtons();
    }

    private void UpdateColorButtons()
    {
        if (FrameColorButton == null) return;
        SetColorButton(FrameColorButton, T("框架底色", "Frame color"), Preferences.FrameColor);
        SetColorButton(PanelColorButton, T("面板底色", "Panel color"), Preferences.PanelColor);
        SetColorButton(HeaderColorButton, T("表头与卡片", "Header and cards"), Preferences.HeaderColor);
        SetColorButton(LineColorButton, T("分隔线", "Dividers"), Preferences.LineColor);
        SetColorButton(TextColorButton, T("主要文字", "Primary text"), Preferences.TextColor);
        SetColorButton(MutedTextColorButton, T("次要文字", "Muted text"), Preferences.MutedTextColor);
        SetColorButton(AccentColorButton, T("强调色", "Accent color"), Preferences.AccentColor);
        SetColorButton(SelectedRowColorButton, T("选中行", "Selected row"), Preferences.SelectedRowColor);
        SetColorButton(PlayedTextColorButton, T("已播放文字", "Played text"), Preferences.PlayedTextColor);
        SetColorButton(WaveformColorButton, T("普通波形", "Normal waveform"), Preferences.WaveformColor);
        SetColorButton(SelectedWaveformColorButton, T("选中波形", "Selected waveform"), Preferences.SelectedWaveformColor);
        SetColorButton(PlayedWaveformColorButton, T("已播放波形", "Played waveform"), Preferences.PlayedWaveformColor);
        SetColorButton(MarkedWaveformColorButton, T("已标记波形", "Marked waveform"), Preferences.MarkedWaveformColor);
        SetColorButton(SelectionColorButton, T("选区颜色", "Selection color"), Preferences.SelectionColor);
        SetColorButton(PlayheadColorButton, T("播放指针", "Playhead"), Preferences.PlayheadColor);
        SetColorButton(RegionColorButton, T("Region", "Region"), Preferences.RegionColor);
    }

    private string T(string zh, string en) => UiLocalization.Text(zh, en, Preferences.Language);

    private static void SetColorButton(Button button, string label, string value)
    {
        var normalized = ThemeManager.Normalize(value, "#000000");
        var color = ThemeManager.Parse(normalized, Colors.Black);
        button.Content = $"{label}     {normalized}";
        button.Background = new SolidColorBrush(color);
        button.Foreground = new SolidColorBrush((color.R * .299 + color.G * .587 + color.B * .114) > 145 ? Colors.Black : Colors.White);
    }

    private async void Save_Click(object sender, RoutedEventArgs e)
    {
        Preferences.AutoPreview = AutoPreviewCheck.IsChecked == true;
        Preferences.SpaceKeyBehavior = SpaceRestartSelection.IsChecked == true ? "restart_selection" : "pause_resume";
        Preferences.Language = EnglishLanguage.IsChecked == true ? "en-US" : "zh-CN";
        Preferences.NavigationVisible = NavigationCheck.IsChecked == true;
        Preferences.InspectorVisible = InspectorCheck.IsChecked == true;
        Preferences.InlineWaveformResolution = Inline512.IsChecked == true ? 512 : 256;
        Preferences.DetailWaveformResolution = Detail4096.IsChecked == true ? 4096 : 2048;
        Preferences.HighlightPlayedWaveform = PlayedWaveformHighlightCheck.IsChecked == true;
        Preferences.ShowLoudnessMetrics = ShowLoudnessCheck.IsChecked == true;
        Preferences.ShowLufsI = ShowLufsICheck.IsChecked == true;
        Preferences.ShowLufsM = ShowLufsMCheck.IsChecked == true;
        Preferences.ShowLufsS = ShowLufsSCheck.IsChecked == true;
        Preferences.ShowTruePeak = ShowTruePeakCheck.IsChecked == true;
        Preferences.LoudnessMatchAudition = LoudnessMatchCheck.IsChecked == true;
        Preferences.LoudnessMatchTarget = ReadDouble(LoudnessMatchTargetText, -18, -36, -6);
        Preferences.TransientThresholdDb = ReadDouble(TransientThresholdText, -12.4, -72, 0);
        Preferences.TransientSmoothingMs = ReadDouble(TransientSmoothingText, 8, 0, 250);
        Preferences.TransientMinIntervalMs = ReadDouble(TransientIntervalText, 140, 10, 10000);
        Preferences.TransientPreRollMs = ReadDouble(TransientPreRollText, 20, 0, 10000);
        Preferences.TransientPostRollMs = ReadDouble(TransientPostRollText, 180, 0, 30000);
        Preferences.TransientMaxRegions = (int)ReadDouble(TransientMaxText, 64, 1, 512);
        Preferences.ReplaceTransientSuggestions = ReplaceTransientCheck.IsChecked == true;
        Preferences.WatchFoldersEnabled = WatchFoldersCheck.IsChecked == true;
        Preferences.WatchFolderDebounceSeconds = (int)ReadDouble(WatchDebounceText, 5, 2, 120);
        Preferences.ResumeInterruptedScan = ResumeScanCheck.IsChecked == true;
        Preferences.AutomaticCatalogBackup = AutomaticBackupCheck.IsChecked == true;
        Preferences.CatalogBackupRetention = (int)ReadDouble(BackupRetentionText, 10, 2, 50);
        var oldCacheDirectory = LuaWaveCache.CacheDirectory;
        if (!oldCacheDirectory.Equals(Preferences.WaveformCacheDirectory, StringComparison.OrdinalIgnoreCase))
        {
            try
            {
                IsEnabled = false;
                CacheMoveStatusText.Text = _moveExistingCache
                    ? T("正在迁移波形缓存…", "Migrating waveform cache…")
                    : T("正在切换波形缓存目录…", "Switching waveform cache directory…");
                if (_moveExistingCache)
                {
                    var result = await LuaWaveCache.MigrateAsync(oldCacheDirectory, Preferences.WaveformCacheDirectory, true);
                    CacheMoveStatusText.Text = T($"已迁移 {result.Copied:N0} 个缓存 · 失败 {result.Failed:N0} 个",
                        $"Migrated {result.Copied:N0} cache files · {result.Failed:N0} failed");
                }
                LuaWaveCache.Configure(Preferences.WaveformCacheDirectory);
                WaveformControl.ClearMemoryCache();
            }
            catch (Exception exception)
            {
                IsEnabled = true;
                MessageBox.Show(T($"无法切换缓存目录：{exception.Message}", $"Could not switch cache directory: {exception.Message}"),
                    "PsyReaSFX Desktop", MessageBoxButton.OK, MessageBoxImage.Error);
                return;
            }
            finally { IsEnabled = true; }
        }
        ThemeManager.Apply(Preferences);
        _committed = true;
        DialogResult = true;
    }

    private static double ReadDouble(TextBox box, double fallback, double minimum, double maximum)
    {
        var text = box.Text.Trim().Replace(',', '.');
        return double.TryParse(text, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var value)
            ? Math.Clamp(value, minimum, maximum) : fallback;
    }

    private void Cancel_Click(object sender, RoutedEventArgs e)
    {
        ThemeManager.Apply(_originalPreferences);
        DialogResult = false;
    }

    protected override void OnClosed(EventArgs e)
    {
        if (!_committed) ThemeManager.Apply(_originalPreferences);
        base.OnClosed(e);
    }
}
