using System.Diagnostics;
using System.Globalization;
using System.Windows;
using PsyReaSFX.Desktop.Services;

namespace PsyReaSFX.Desktop;

public partial class TransferWindow : Window
{
    private readonly DesktopPreferences _preferences;
    private readonly AudioAsset? _current;
    private readonly AudioAsset[] _selected;
    private readonly double _selectionStart;
    private readonly double _selectionEnd;
    private readonly double _pitch;
    private readonly double _rate;
    private readonly double _gain;
    private readonly bool _reverse;
    private readonly bool _preservePitch;
    private CancellationTokenSource? _cancellation;
    private TransferRunResult? _lastResult;

    public TransferWindow(DesktopPreferences preferences, AudioAsset? current, IReadOnlyList<AudioAsset> selected,
        double selectionStart, double selectionEnd, double pitch, double rate, double gain, bool reverse, bool preservePitch)
    {
        _preferences = preferences;
        _current = current;
        _selected = selected.DistinctBy(asset => asset.FilePath, StringComparer.OrdinalIgnoreCase).ToArray();
        _selectionStart = selectionStart; _selectionEnd = selectionEnd;
        _pitch = pitch; _rate = rate; _gain = gain; _reverse = reverse; _preservePitch = preservePitch;
        InitializeComponent();
        LoadPreferences();
        AssetSummaryText.Text = T($"当前素材：{current?.FileName ?? "未选择"} · 已选 {_selected.Length:N0} 个",
            $"Current: {current?.FileName ?? "none"} · {_selected.Length:N0} selected");
        UiLocalization.Apply(this, preferences.Language);
    }

    private string T(string zh, string en) => UiLocalization.Text(zh, en, _preferences.Language);

    private void LoadPreferences()
    {
        OutputDirectoryText.Text = string.IsNullOrWhiteSpace(_preferences.TransferOutputDirectory)
            ? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyMusic), "PsyReaSFX", "Transfer")
            : _preferences.TransferOutputDirectory;
        NamingTemplateText.Text = _preferences.TransferNamingTemplate;
        LowercaseCheck.IsChecked = _preferences.TransferLowercase;
        Set(_preferences.TransferScope, ("selection", ScopeSelection), ("full", ScopeFull));
        Set(_preferences.TransferFormat, ("wav16", FormatWav16), ("wav24", FormatWav24), ("wav32", FormatWav32), ("flac", FormatFlac));
        Set(_preferences.TransferSampleRate, ("source", RateSource), ("44100", Rate44100), ("48000", Rate48000), ("96000", Rate96000), ("192000", Rate192000));
        Set(_preferences.TransferChannels, ("source", ChannelsSource), ("mono", ChannelsMono), ("stereo", ChannelsStereo));
        PreserveMetadataCheck.IsChecked = _preferences.TransferPreserveMetadata;
        FadeInText.Text = Number(_preferences.TransferFadeInMs); FadeOutText.Text = Number(_preferences.TransferFadeOutMs);
        NormalizeTargetText.Text = Number(_preferences.TransferNormalizeTarget);
        Set(_preferences.TransferNormalizeMode, ("off", NormalizeOff), ("peak", NormalizePeak), ("true-peak", NormalizeTruePeak), ("rms-i", NormalizeRms), ("lufs-i", NormalizeLufs));
        DitherCheck.IsChecked = _preferences.TransferDither; NoiseShapingCheck.IsChecked = _preferences.TransferNoiseShaping;
        SmartTailCheck.IsChecked = _preferences.TransferSmartTail; TailThresholdText.Text = Number(_preferences.TransferTailThresholdDb);
        TailMaximumText.Text = Number(_preferences.TransferTailMaximumMs); TailHoldText.Text = Number(_preferences.TransferTailHoldMs);
        VariantsCheck.IsChecked = _preferences.TransferVariantsEnabled; VariantPitchesText.Text = _preferences.TransferVariantPitches;
        VariantRatesText.Text = _preferences.TransferVariantRates; VariantGainsText.Text = _preferences.TransferVariantGains;
        VariantReverseCheck.IsChecked = _preferences.TransferVariantReverse;
        VariantAutoSuffixCheck.IsChecked = _preferences.TransferVariantAutoSuffix;
        Set(_preferences.TransferCollisionPolicy, ("increment", CollisionIncrement), ("skip", CollisionSkip), ("overwrite", CollisionOverwrite));
        OpenFolderAfterCheck.IsChecked = _preferences.TransferOpenFolderAfter;
    }

    private TransferOptions SaveAndBuildOptions()
    {
        _preferences.TransferOutputDirectory = OutputDirectoryText.Text.Trim();
        _preferences.TransferNamingTemplate = string.IsNullOrWhiteSpace(NamingTemplateText.Text) ? "{name}" : NamingTemplateText.Text.Trim();
        _preferences.TransferLowercase = LowercaseCheck.IsChecked == true;
        _preferences.TransferScope = ScopeFull.IsChecked == true ? "full" : "selection";
        _preferences.TransferFormat = FormatWav16.IsChecked == true ? "wav16" : FormatWav32.IsChecked == true ? "wav32" : FormatFlac.IsChecked == true ? "flac" : "wav24";
        _preferences.TransferSampleRate = Rate44100.IsChecked == true ? "44100" : Rate48000.IsChecked == true ? "48000" : Rate96000.IsChecked == true ? "96000" : Rate192000.IsChecked == true ? "192000" : "source";
        _preferences.TransferChannels = ChannelsMono.IsChecked == true ? "mono" : ChannelsStereo.IsChecked == true ? "stereo" : "source";
        _preferences.TransferPreserveMetadata = PreserveMetadataCheck.IsChecked == true;
        _preferences.TransferFadeInMs = Read(FadeInText.Text, 5, 0, 30000); _preferences.TransferFadeOutMs = Read(FadeOutText.Text, 20, 0, 30000);
        _preferences.TransferNormalizeMode = NormalizePeak.IsChecked == true ? "peak" : NormalizeTruePeak.IsChecked == true ? "true-peak" : NormalizeRms.IsChecked == true ? "rms-i" : NormalizeLufs.IsChecked == true ? "lufs-i" : "off";
        _preferences.TransferNormalizeTarget = Read(NormalizeTargetText.Text, -1, -60, 6);
        _preferences.TransferDither = DitherCheck.IsChecked == true; _preferences.TransferNoiseShaping = NoiseShapingCheck.IsChecked == true;
        _preferences.TransferSmartTail = SmartTailCheck.IsChecked == true; _preferences.TransferTailThresholdDb = Read(TailThresholdText.Text, -60, -120, 0);
        _preferences.TransferTailMaximumMs = Read(TailMaximumText.Text, 5000, 0, 60000); _preferences.TransferTailHoldMs = Read(TailHoldText.Text, 180, 0, 10000);
        _preferences.TransferVariantsEnabled = VariantsCheck.IsChecked == true; _preferences.TransferVariantPitches = VariantPitchesText.Text.Trim();
        _preferences.TransferVariantRates = VariantRatesText.Text.Trim(); _preferences.TransferVariantGains = VariantGainsText.Text.Trim();
        _preferences.TransferVariantReverse = VariantReverseCheck.IsChecked == true;
        _preferences.TransferVariantAutoSuffix = VariantAutoSuffixCheck.IsChecked == true;
        _preferences.TransferCollisionPolicy = CollisionSkip.IsChecked == true ? "skip" : CollisionOverwrite.IsChecked == true ? "overwrite" : "increment";
        _preferences.TransferOpenFolderAfter = OpenFolderAfterCheck.IsChecked == true;
        new DesktopPreferencesStore().Save(_preferences);
        return new TransferOptions
        {
            OutputDirectory = _preferences.TransferOutputDirectory, NamingTemplate = _preferences.TransferNamingTemplate,
            Lowercase = _preferences.TransferLowercase, Scope = _preferences.TransferScope, Format = _preferences.TransferFormat,
            SampleRate = _preferences.TransferSampleRate, Channels = _preferences.TransferChannels,
            PreserveMetadata = _preferences.TransferPreserveMetadata, FadeInMs = _preferences.TransferFadeInMs,
            FadeOutMs = _preferences.TransferFadeOutMs, NormalizeMode = _preferences.TransferNormalizeMode,
            NormalizeTarget = _preferences.TransferNormalizeTarget, Dither = _preferences.TransferDither,
            NoiseShaping = _preferences.TransferNoiseShaping, SmartTail = _preferences.TransferSmartTail,
            TailThresholdDb = _preferences.TransferTailThresholdDb, TailMaximumMs = _preferences.TransferTailMaximumMs,
            TailHoldMs = _preferences.TransferTailHoldMs, CollisionPolicy = _preferences.TransferCollisionPolicy,
            OpenFolderAfter = _preferences.TransferOpenFolderAfter, Pitch = _pitch, Rate = _rate, Gain = _gain,
            Reverse = _reverse, PreservePitch = _preservePitch, VariantsEnabled = _preferences.TransferVariantsEnabled,
            VariantPitches = _preferences.TransferVariantPitches, VariantRates = _preferences.TransferVariantRates,
            VariantGains = _preferences.TransferVariantGains, VariantReverse = _preferences.TransferVariantReverse,
            VariantAutoSuffix = _preferences.TransferVariantAutoSuffix
        };
    }

    private async void ExportCurrent_Click(object sender, RoutedEventArgs e)
    {
        if (_current == null) { MessageBox.Show(this, T("请先选择一个素材。", "Select an asset first.")); return; }
        await StartTransferAsync([_current], true);
    }

    private async void ExportSelected_Click(object sender, RoutedEventArgs e)
    {
        if (_selected.Length == 0) { MessageBox.Show(this, T("请先选择素材。", "Select one or more assets first.")); return; }
        await StartTransferAsync(_selected, false);
    }

    private async Task StartTransferAsync(IReadOnlyList<AudioAsset> assets, bool allowSelection)
    {
        if (_cancellation != null) return;
        TransferOptions options;
        try { options = SaveAndBuildOptions(); Directory.CreateDirectory(options.OutputDirectory); }
        catch (Exception exception) { MessageBox.Show(this, exception.Message, "PsyReaSFX Transfer", MessageBoxButton.OK, MessageBoxImage.Error); return; }
        IReadOnlyList<TransferVariant> variants;
        try { variants = TransferEngine.BuildVariants(options); }
        catch (Exception exception)
        {
            MessageBox.Show(this, exception.Message, T("变体设置无效", "Invalid variant settings"), MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }
        var requests = new List<TransferRequest>();
        for (var assetIndex = 0; assetIndex < assets.Count; assetIndex++)
        foreach (var variant in variants)
        {
            var useSelection = allowSelection && options.Scope == "selection" && _selectionEnd > _selectionStart;
            requests.Add(new TransferRequest(assets[assetIndex], useSelection ? _selectionStart : -1,
                useSelection ? _selectionEnd : -1, variant, assetIndex + 1));
        }
        if (requests.Count > 4096) { MessageBox.Show(this, T("本次任务超过 4096 个，请减少素材或变体。", "This run exceeds 4,096 jobs. Reduce assets or variants.")); return; }

        _cancellation = new CancellationTokenSource();
        SetRunning(true); TransferProgress.Maximum = Math.Max(1, requests.Count); TransferProgress.Value = 0;
        ResultText.Text = "";
        var progress = new Progress<TransferProgress>(value =>
        {
            TransferProgress.Value = value.Completed;
            ProgressText.Text = $"{value.Completed:N0} / {value.Total:N0}  {value.CurrentFile}";
            CurrentProcessingText.Text = value.Message;
        });
        try
        {
            _lastResult = await new TransferEngine().RunAsync(requests, options, progress, _cancellation.Token);
            ResultText.Text = T($"完成：{_lastResult.SuccessCount} 成功 · {_lastResult.SkippedCount} 跳过 · {_lastResult.FailedCount} 失败",
                $"Complete: {_lastResult.SuccessCount} succeeded · {_lastResult.SkippedCount} skipped · {_lastResult.FailedCount} failed");
            OpenLastOutputButton.IsEnabled = _lastResult.LastOutput != null; OpenReportButton.IsEnabled = File.Exists(_lastResult.ReportPath);
            if (options.OpenFolderAfter) OpenDirectory(options.OutputDirectory);
        }
        catch (OperationCanceledException) { ResultText.Text = T("任务已取消。", "Transfer cancelled."); }
        finally { _cancellation.Dispose(); _cancellation = null; SetRunning(false); }
    }

    private void SetRunning(bool running)
    {
        CancelTransferButton.IsEnabled = running; ExportCurrentButton.IsEnabled = !running; ExportSelectedButton.IsEnabled = !running;
    }

    private void CancelTransfer_Click(object sender, RoutedEventArgs e) => _cancellation?.Cancel();
    private void Close_Click(object sender, RoutedEventArgs e) { if (_cancellation == null) Close(); }
    private void ChooseOutput_Click(object sender, RoutedEventArgs e)
    {
        using var dialog = new System.Windows.Forms.FolderBrowserDialog { InitialDirectory = OutputDirectoryText.Text, UseDescriptionForTitle = true, Description = "PsyReaSFX Transfer" };
        if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK) OutputDirectoryText.Text = dialog.SelectedPath;
    }
    private void OpenOutput_Click(object sender, RoutedEventArgs e) => OpenDirectory(OutputDirectoryText.Text);
    private void OpenLastOutput_Click(object sender, RoutedEventArgs e)
    {
        var path = _lastResult?.LastOutput; if (path == null || !File.Exists(path)) return;
        Process.Start(new ProcessStartInfo("explorer.exe", $"/select,\"{path}\"") { UseShellExecute = true });
    }
    private void OpenReport_Click(object sender, RoutedEventArgs e)
    {
        var path = _lastResult?.ReportPath; if (path == null || !File.Exists(path)) return;
        Process.Start(new ProcessStartInfo("explorer.exe", $"/select,\"{path}\"") { UseShellExecute = true });
    }
    private static void OpenDirectory(string path)
    {
        if (string.IsNullOrWhiteSpace(path)) return; Directory.CreateDirectory(path);
        Process.Start(new ProcessStartInfo("explorer.exe", path) { UseShellExecute = true });
    }
    private static void Set(string value, params (string Key, System.Windows.Controls.RadioButton Button)[] choices)
    { (choices.FirstOrDefault(item => item.Key.Equals(value, StringComparison.OrdinalIgnoreCase)).Button ?? choices[0].Button).IsChecked = true; }
    private static double Read(string value, double fallback, double minimum, double maximum) =>
        double.TryParse(value.Trim().Replace(',', '.'), NumberStyles.Float, CultureInfo.InvariantCulture, out var parsed) ? Math.Clamp(parsed, minimum, maximum) : fallback;
    private static string Number(double value) => value.ToString("0.###", CultureInfo.InvariantCulture);
}
