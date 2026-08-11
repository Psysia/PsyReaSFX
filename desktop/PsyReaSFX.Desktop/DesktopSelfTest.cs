using System.Text;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;
using PsyReaSFX.Desktop.Controls;
using PsyReaSFX.Desktop.Services;
using PsyReaSFX.Data;
using PsyAudioFileReader = PsyReaSFX.Desktop.Services.AudioFileReader;

namespace PsyReaSFX.Desktop;

internal static class DesktopSelfTest
{
    public static async Task<int> RunAsync(string reportPath)
    {
        var working = Path.Combine(Path.GetTempPath(), "PsyReaSFX-Desktop-SelfTest-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(working);
        try
        {
            var wavPath = Path.Combine(working, "desktop_self_test.wav");
            WriteTestWave(wavPath);
            AppendWaveChunk(wavPath, "iXML", Encoding.UTF8.GetBytes("<BWFXML><PROJECT>PsyReaSFX self test</PROJECT></BWFXML>"));
            var info = PsyAudioFileReader.ReadInfo(wavPath);
            var waveform = PsyAudioFileReader.ReadWaveform(wavPath, 256);
            var library = new LibraryDefinition { Name = "Self Test" };
            library.Sources.Add(new LibrarySource { Path = working });
            var indexed = await new LibraryIndexer().BuildAsync(
                [library], [], new InlineProgress<(int Count, string File)>(), CancellationToken.None);

            var database = new PsyReaSFXDatabase(Path.Combine(working, "database"));
            await database.InitializeAsync();
            var luaDirectory = LuaDataLocator.Find();
            var migration = await database.ImportLuaIfNeededAsync(luaDirectory);
            var catalog = await database.LoadSnapshotAsync();
            var migrationPassed = luaDirectory is null ||
                                  (migration.Imported && catalog.Libraries.Count > 0 && catalog.Assets.Count > 0);

            var detailDatabase = new PsyReaSFXDatabase(Path.Combine(working, "database-details"));
            await detailDatabase.InitializeAsync();
            var detailSnapshot = new CatalogSnapshot();
            detailSnapshot.Assets.Add(new AssetRecord { Path = wavPath, Name = Path.GetFileName(wavPath), Description = "before", Ready = true, Indexed = true });
            detailSnapshot.Collections.Add(new CollectionRecord("collection-a4", "A4 playlist", "playlist"));
            detailSnapshot.CollectionItems.Add(new CollectionItemRecord("collection-a4", wavPath, 0));
            detailSnapshot.SavedSearches.Add(new SavedSearchRecord("search-a4", "Impacts", "category:impact", "All", "", "Name", false, null, "collection-a4", null));
            detailSnapshot.SessionPlayed.Add(wavPath);
            await detailDatabase.SaveDesktopSnapshotAsync(detailSnapshot);
            await detailDatabase.SaveAssetDetailsAsync([
                new AssetRecord
                {
                    Path = wavPath, Name = Path.GetFileName(wavPath), Description = "after", Keywords = "impact, test",
                    Category = "TEST", Subcategory = "IMPACT", CatId = "TESTImp", WorkflowStatus = "approved", Marked = true,
                    Ready = true, Indexed = true
                }
            ]);
            var savedDetails = (await detailDatabase.LoadSnapshotAsync()).Assets.Single();
            var organizationSnapshot = await detailDatabase.LoadSnapshotAsync();
            var assetDetailsPassed = savedDetails.Description == "after" && savedDetails.Keywords == "impact, test"
                                     && savedDetails.WorkflowStatus == "approved" && savedDetails.Marked;
            var organizationPassed = organizationSnapshot.Collections.Count == 1 && organizationSnapshot.CollectionItems.Count == 1
                                     && organizationSnapshot.SavedSearches.Count == 1
                                     && organizationSnapshot.SessionPlayed.Contains(wavPath);

            var region = new RegionRecord(wavPath, .1, .3, "Self-test selection", "manual", "desktop-self-test");
            await detailDatabase.UpsertRegionAsync(region);
            var storedRegions = await detailDatabase.LoadRegionsAsync(wavPath);
            var regionPersistencePassed = storedRegions.Count == 1
                                          && Math.Abs(storedRegions[0].Start - .1) < .001
                                          && Math.Abs(storedRegions[0].Finish - .3) < .001;
            await detailDatabase.DeleteRegionAsync(region);
            regionPersistencePassed = regionPersistencePassed && (await detailDatabase.LoadRegionsAsync(wavPath)).Count == 0;

            string? selectionFile = null;
            string? selection24File = null;
            var selectionDragPassed = false;
            try
            {
                selectionFile = await SelectionDragExporter.ExportToDirectoryAsync(wavPath, .1, .3,
                    Path.Combine(working, "selection-drag"));
                var selectionInfo = PsyAudioFileReader.ReadInfo(selectionFile);
                var wav24Path = Path.Combine(working, "desktop_self_test_24bit_stereo.wav");
                WriteTestWave24BitStereo(wav24Path);
                selection24File = await SelectionDragExporter.ExportToDirectoryAsync(wav24Path, .1, .3,
                    Path.Combine(working, "selection-drag"));
                var selection24Info = PsyAudioFileReader.ReadInfo(selection24File);
                selectionDragPassed = selectionInfo.Duration is > .19 and < .21 && selectionInfo.Channels == 2
                                      && selection24Info.Duration is > .19 and < .21
                                      && selection24Info.Channels == 2 && selection24Info.BitDepth == 24;
            }
            finally
            {
                try { if (selectionFile != null) File.Delete(selectionFile); } catch { }
                try { if (selection24File != null) File.Delete(selection24File); } catch { }
            }

            var loudness = await LoudnessAnalyzer.AnalyzeAsync(wavPath, new FileInfo(wavPath).Length);
            await detailDatabase.UpsertLoudnessAsync(loudness);
            var storedLoudness = await detailDatabase.LoadLoudnessAsync(wavPath);
            var loudnessAnalysisPassed = storedLoudness != null
                                         && double.IsFinite(storedLoudness.LufsI ?? double.NaN)
                                         && double.IsFinite(storedLoudness.LufsM ?? double.NaN)
                                         && double.IsFinite(storedLoudness.LufsS ?? double.NaN)
                                         && double.IsFinite(storedLoudness.TruePeak ?? double.NaN);

            var detectedTransients = await TransientDetector.DetectAsync(wavPath, info.Duration,
                new TransientDetectionOptions(-60, 0, 40, 5, 60, 16));
            var transientDetectionPassed = detectedTransients.Count > 0
                                           && detectedTransients.All(row => row.Start >= 0 && row.Finish > row.Start
                                                                               && row.Finish <= info.Duration + .001);

            var liveAsset = catalog.Assets.FirstOrDefault(asset => File.Exists(asset.Path) &&
                (Path.GetExtension(asset.Path).Equals(".wav", StringComparison.OrdinalIgnoreCase) || Path.GetExtension(asset.Path).Equals(".wave", StringComparison.OrdinalIgnoreCase)));
            var liveWaveform = liveAsset is null ? [] : PsyAudioFileReader.ReadWaveform(liveAsset.Path, 256);
            var thumbnailStress = System.Diagnostics.Stopwatch.StartNew();
            var thumbnailStressCount = 0;
            foreach (var asset in catalog.Assets.Where(asset => File.Exists(asset.Path)).Take(64))
            {
                _ = PsyAudioFileReader.ReadWaveform(asset.Path, 256);
                thumbnailStressCount++;
            }
            thumbnailStress.Stop();
            var uiSmokePassed = false;
            var panelCollapsePassed = false;
            var playheadLayerPassed = false;
            var playheadStaticRebuilds = 0;
            var columnResizePassed = false;
            var scrollBarDragBindingPassed = false;
            var scrollBarThumbGesturePassed = false;
            var scrollBarVisualPassed = false;
            var dataGridScrollBarVisualPassed = false;
            string? dataGridScrollBarProbe = null;
            var expanderHeaderPassed = false;
            var languageSwitchPassed = false;
            var settingsLanguageSwitchPassed = false;
            var helpWindowPassed = false;
            var transferWindowPassed = false;
            var themeSwitchPassed = false;
            string? themeProbeColors = null;
            string? uiSmokeError = null;
            try
            {
                // Constructing the shell catches missing resources, duplicate
                // styles and invalid XAML event bindings without showing it or
                // opening the user's catalog.
                var shell = new MainWindow();
                columnResizePassed = shell.AssetGrid.CanUserResizeColumns && shell.AssetGrid.Columns.All(column => column.CanUserResize);

                static (bool Binding, bool Gesture, bool Visual) TrackBindingWorks(Orientation orientation)
                {
                    var testScrollBar = new ScrollBar
                    {
                        Style = (Style)Application.Current.FindResource(typeof(ScrollBar)),
                        Orientation = orientation,
                        Minimum = 0,
                        Maximum = 100,
                        ViewportSize = 12,
                        Value = 5,
                        Width = orientation == Orientation.Horizontal ? 320 : 22,
                        Height = orientation == Orientation.Vertical ? 240 : 22
                    };
                    var size = new Size(testScrollBar.Width, testScrollBar.Height);
                    testScrollBar.Measure(size);
                    testScrollBar.Arrange(new Rect(new Point(), size));
                    testScrollBar.ApplyTemplate();
                    if (testScrollBar.Template?.FindName("PART_Track", testScrollBar) is not Track testTrack) return (false, false, false);
                    testTrack.Value = 61;
                    var binding = Math.Abs(testScrollBar.Value - 61) < .001
                           && double.IsNaN(testTrack.ViewportSize)
                           && testTrack.Thumb != null;
                    if (testTrack.Thumb == null) return (binding, false, false);
                    testTrack.Thumb.UpdateLayout();
                    var thumbOrigin = testTrack.Thumb.TranslatePoint(new Point(), testScrollBar);
                    var visual = orientation == Orientation.Vertical
                        ? testTrack.Thumb.ActualWidth >= 7 && thumbOrigin.X >= 0
                          && thumbOrigin.X + testTrack.Thumb.ActualWidth <= testScrollBar.ActualWidth + .1
                        : testTrack.Thumb.ActualHeight >= 7 && thumbOrigin.Y >= 0
                          && thumbOrigin.Y + testTrack.Thumb.ActualHeight <= testScrollBar.ActualHeight + .1;
                    var before = testScrollBar.Value;
                    testTrack.Thumb.RaiseEvent(new DragStartedEventArgs(0, 0));
                    testTrack.Thumb.RaiseEvent(new DragDeltaEventArgs(orientation == Orientation.Horizontal ? 40 : 0,
                        orientation == Orientation.Vertical ? 40 : 0));
                    testTrack.Thumb.RaiseEvent(new DragCompletedEventArgs(40, 40, false));
                    return (binding, Math.Abs(testScrollBar.Value - before) > .001, visual);
                }
                var verticalScroll = TrackBindingWorks(Orientation.Vertical);
                var horizontalScroll = TrackBindingWorks(Orientation.Horizontal);
                scrollBarDragBindingPassed = verticalScroll.Binding && horizontalScroll.Binding;
                scrollBarThumbGesturePassed = verticalScroll.Gesture && horizontalScroll.Gesture;
                scrollBarVisualPassed = verticalScroll.Visual && horizontalScroll.Visual;

                var integratedGrid = new DataGrid
                {
                    ItemsSource = Enumerable.Range(0, 300).Select(index => new { Name = $"Asset {index:000}", Description = new string('x', 160) }).ToArray(),
                    AutoGenerateColumns = true,
                    VerticalScrollBarVisibility = ScrollBarVisibility.Visible,
                    HorizontalScrollBarVisibility = ScrollBarVisibility.Visible
                };
                var integratedHost = new Window
                {
                    Width = 520,
                    Height = 230,
                    Content = integratedGrid,
                    ShowInTaskbar = false,
                    ShowActivated = false,
                    AllowsTransparency = true,
                    Background = Brushes.Transparent,
                    Opacity = 0,
                    WindowStyle = WindowStyle.None,
                    ResizeMode = ResizeMode.NoResize,
                    Left = -10000,
                    Top = -10000
                };
                integratedHost.Show();
                try
                {
                    integratedHost.UpdateLayout();
                    var integratedScrollbars = FindVisualChildren<ScrollBar>(integratedGrid)
                        .Where(bar => bar.ActualWidth > 0 && bar.ActualHeight > 0)
                        .ToArray();
                    var verticalIntegrated = integratedScrollbars.FirstOrDefault(bar => bar.Orientation == Orientation.Vertical);
                    var horizontalIntegrated = integratedScrollbars.FirstOrDefault(bar => bar.Orientation == Orientation.Horizontal);
                    static bool IntegratedThumbFits(ScrollBar? bar)
                    {
                        if (bar == null) return false;
                        bar.ApplyTemplate();
                        bar.UpdateLayout();
                        if (bar.Template.FindName("PART_Track", bar) is not Track track || track.Thumb == null) return false;
                        var origin = track.Thumb.TranslatePoint(new Point(), bar);
                        return bar.Orientation == Orientation.Vertical
                            ? track.Thumb.ActualWidth >= 7 && track.Thumb.ActualHeight >= 36 && origin.X >= 0
                              && origin.X + track.Thumb.ActualWidth <= bar.ActualWidth + .1
                            : track.Thumb.ActualHeight >= 7 && track.Thumb.ActualWidth >= 50 && origin.Y >= 0
                              && origin.Y + track.Thumb.ActualHeight <= bar.ActualHeight + .1;
                    }
                    dataGridScrollBarVisualPassed = IntegratedThumbFits(verticalIntegrated)
                                                        && IntegratedThumbFits(horizontalIntegrated);
                    if (verticalIntegrated?.Template.FindName("PART_Track", verticalIntegrated) is Track verticalTrack
                        && horizontalIntegrated?.Template.FindName("PART_Track", horizontalIntegrated) is Track horizontalTrack)
                    {
                        dataGridScrollBarProbe = $"vertical={verticalIntegrated.ActualWidth:0.0}x{verticalIntegrated.ActualHeight:0.0}," +
                                                 $" thumb={verticalTrack.Thumb.ActualWidth:0.0}x{verticalTrack.Thumb.ActualHeight:0.0};" +
                                                 $" horizontal={horizontalIntegrated.ActualWidth:0.0}x{horizontalIntegrated.ActualHeight:0.0}," +
                                                 $" thumb={horizontalTrack.Thumb.ActualWidth:0.0}x{horizontalTrack.Thumb.ActualHeight:0.0}";
                    }
                }
                finally
                {
                    integratedHost.Close();
                }

                var testExpander = new Expander
                {
                    Style = (Style)Application.Current.FindResource(typeof(Expander)),
                    Header = "FACETS",
                    Content = new Border()
                };
                testExpander.Measure(new Size(240, 180));
                testExpander.Arrange(new Rect(0, 0, 240, 180));
                testExpander.ApplyTemplate();
                if (testExpander.Template?.FindName("HeaderSite", testExpander) is ToggleButton testHeader)
                {
                    testHeader.ApplyTemplate();
                    expanderHeaderPassed = testHeader.Template.FindName("HeaderContent", testHeader) is TextBlock label
                                             && label.Text == "FACETS";
                }
                UiLocalization.Apply(shell, "en-US");
                var englishSidebar = Equals(shell.SoundsSection.Header, "SOUNDS") && Equals(shell.LibrariesSection.Header, "LIBRARIES");
                UiLocalization.Apply(shell, "zh-CN");
                var chineseSidebar = Equals(shell.SoundsSection.Header, "素材") && Equals(shell.LibrariesSection.Header, "音效库")
                                     && Equals(shell.CollectionsSection.Header, "集合") && Equals(shell.FacetsSection.Header, "筛选");
                UiLocalization.Apply(shell, "en-US");
                languageSwitchPassed = englishSidebar && chineseSidebar;
                var settingsDatabase = Path.Combine(working, "settings-catalog.sqlite3");
                var settings = new SettingsWindow(new DesktopPreferences(), working,
                    new CatalogReliabilityService(working), settingsDatabase);
                UiLocalization.Apply(settings, "en-US");
                var settingsEnglish = settings.Title.Contains("Settings", StringComparison.Ordinal);
                UiLocalization.Apply(settings, "zh-CN");
                var settingsChinese = settings.Title.Contains("设置", StringComparison.Ordinal);
                UiLocalization.Apply(settings, "en-US");
                settingsLanguageSwitchPassed = settingsEnglish && settingsChinese;
                var helpWindow = new HelpWindow("en-US");
                helpWindow.Measure(new Size(900, 680));
                helpWindow.Arrange(new Rect(0, 0, 900, 680));
                var helpEnglish = helpWindow.Title.Contains("Help", StringComparison.Ordinal)
                                  && Equals(helpWindow.StartNav.Content, "Quick start")
                                  && Equals(helpWindow.ShortcutNav.Content, "Shortcuts");
                UiLocalization.Apply(helpWindow, "zh-CN");
                var helpChinese = helpWindow.Title.Contains("帮助", StringComparison.Ordinal)
                                  && Equals(helpWindow.StartNav.Content, "快速开始")
                                  && Equals(helpWindow.ShortcutNav.Content, "快捷键");
                helpWindowPassed = helpEnglish && helpChinese
                                   && helpWindow.WindowStyle == WindowStyle.None
                                   && helpWindow.ResizeMode == ResizeMode.CanResize;
                var transferWindow = new TransferWindow(new DesktopPreferences(), null, [], -1, -1, 0, 1, 0, false, true);
                transferWindow.Measure(new Size(1120, 780));
                transferWindow.Arrange(new Rect(0, 0, 1120, 780));
                UiLocalization.Apply(transferWindow, "en-US");
                var transferEnglish = Equals(transferWindow.ExportCurrentButton.Content, "Export current asset")
                                      && Equals(transferWindow.OpenReportButton.Content, "Open task report");
                UiLocalization.Apply(transferWindow, "zh-CN");
                var transferChinese = Equals(transferWindow.ExportCurrentButton.Content, "导出当前素材")
                                      && Equals(transferWindow.OpenReportButton.Content, "打开任务报告");
                transferWindowPassed = transferWindow.AssetSummaryText.Text.Length > 0
                                       && transferWindow.ExportCurrentButton != null
                                       && transferWindow.ExportSelectedButton != null
                                       && transferEnglish && transferChinese;

                var themeSurface = new Border { Background = (Brush)Application.Current.Resources["BgBrush"] };
                var themeProbe = new DesktopPreferences();
                ThemeManager.ApplyPreset(themeProbe, "classic");
                ThemeManager.Apply(themeProbe);
                var classicColor = ((SolidColorBrush)Application.Current.Resources["BgBrush"]).Color;
                ThemeManager.ApplyPreset(themeProbe, "dark");
                ThemeManager.Apply(themeProbe);
                var darkColor = ((SolidColorBrush)Application.Current.Resources["BgBrush"]).Color;
                var surfaceColor = ((SolidColorBrush)themeSurface.Background).Color;
                themeProbeColors = $"classic={classicColor};dark={darkColor};surface={surfaceColor}";
                themeSwitchPassed = classicColor != darkColor && surfaceColor == darkColor;
                static bool ColumnMatches(Visibility visibility, double width) =>
                    visibility == Visibility.Visible ? width > 0 : width == 0;
                shell.NavigationToggle.RaiseEvent(new RoutedEventArgs(Controls.VectorIconButton.ClickEvent));
                var navigationFirst = ColumnMatches(shell.NavigationPanel.Visibility, shell.NavigationColumn.ActualWidth + shell.NavigationColumn.Width.Value);
                shell.NavigationToggle.RaiseEvent(new RoutedEventArgs(Controls.VectorIconButton.ClickEvent));
                var navigationSecond = ColumnMatches(shell.NavigationPanel.Visibility, shell.NavigationColumn.ActualWidth + shell.NavigationColumn.Width.Value);
                shell.InspectorToggle.RaiseEvent(new RoutedEventArgs(Controls.VectorIconButton.ClickEvent));
                var inspectorFirst = ColumnMatches(shell.InspectorPanel.Visibility, shell.InspectorColumn.ActualWidth + shell.InspectorColumn.Width.Value);
                shell.InspectorToggle.RaiseEvent(new RoutedEventArgs(Controls.VectorIconButton.ClickEvent));
                var inspectorSecond = ColumnMatches(shell.InspectorPanel.Visibility, shell.InspectorColumn.ActualWidth + shell.InspectorColumn.Width.Value);
                panelCollapsePassed = navigationFirst && navigationSecond && inspectorFirst && inspectorSecond;

                var waveformControl = new Controls.WaveformControl
                {
                    Width = 960,
                    Height = 180,
                    Regions = [new Controls.WaveformRegion(.12, .28, false), new Controls.WaveformRegion(.52, .64, true)]
                };
                waveformControl.Measure(new Size(960, 180));
                waveformControl.Arrange(new Rect(0, 0, 960, 180));
                var bitmap = new RenderTargetBitmap(960, 180, 96, 96, PixelFormats.Pbgra32);
                bitmap.Render(waveformControl);
                var initialBuilds = waveformControl.StaticDrawingBuildCount;
                for (var frame = 0; frame < 120; frame++)
                {
                    waveformControl.Playhead = frame / 119.0;
                    bitmap.Render(waveformControl);
                }
                playheadStaticRebuilds = waveformControl.StaticDrawingBuildCount - initialBuilds;
                playheadLayerPassed = playheadStaticRebuilds == 0;
                uiSmokePassed = panelCollapsePassed && playheadLayerPassed && columnResizePassed
                                && scrollBarDragBindingPassed && scrollBarThumbGesturePassed && expanderHeaderPassed
                                && scrollBarVisualPassed && dataGridScrollBarVisualPassed
                                && languageSwitchPassed && settingsLanguageSwitchPassed && helpWindowPassed
                                && transferWindowPassed && themeSwitchPassed;
            }
            catch (Exception exception)
            {
                uiSmokeError = exception.ToString();
                AppDiagnostics.Write("Desktop UI smoke test failed.", exception);
            }
            var collectionNotifications = 0;
            var collection = new AssetCollection { Name = "A4 collection" };
            collection.PropertyChanged += (_, args) => { if (args.PropertyName == nameof(AssetCollection.DisplayText)) collectionNotifications++; };
            collection.Items.Add(wavPath);
            collection.Name = "A4 renamed";
            var collectionBindingPassed = collection.DisplayText.Contains("1") && collectionNotifications >= 2;
            var pitchRate = VerifyPitchRatePipeline();
            var preservePitchPassed = pitchRate.Preserved is > 390 and < 490
                                      && pitchRate.Coupled is > 580 and < 740;

            var transferDirectory = Path.Combine(working, "transfer");
            var transferAsset = new AudioAsset
            {
                FilePath = wavPath,
                FileName = Path.GetFileName(wavPath),
                FileSize = new FileInfo(wavPath).Length,
                DurationSeconds = info.Duration,
                Channels = info.Channels,
                SampleRate = info.SampleRate,
                BitDepth = info.BitDepth,
                LibraryName = "Self Test",
                Category = "TEST",
                Subcategory = "TRANSFER"
            };
            var transferOptions = new TransferOptions
            {
                OutputDirectory = transferDirectory,
                NamingTemplate = "{name}_{category}",
                Scope = "selection",
                Format = "wav16",
                SampleRate = "44100",
                Channels = "mono",
                FadeInMs = 3,
                FadeOutMs = 8,
                NormalizeMode = "peak",
                NormalizeTarget = -3,
                Dither = true,
                NoiseShaping = true,
                VariantsEnabled = true,
                VariantPitches = "0,3",
                VariantRates = "1",
                VariantGains = "0",
                VariantReverse = true,
                VariantAutoSuffix = true,
                CollisionPolicy = "increment",
                PreserveMetadata = true
            };
            var transferVariants = TransferEngine.BuildVariants(transferOptions);
            var transferRequests = transferVariants.Select((variant, index) =>
                new TransferRequest(transferAsset, .1, .3, variant, index + 1)).ToArray();
            var transferResult = await new TransferEngine().RunAsync(transferRequests, transferOptions,
                new InlineProgress<TransferProgress>(), CancellationToken.None);
            var transferFiles = transferResult.Items.Where(item => item.Success).Select(item => item.OutputPath).ToArray();
            var transferInfos = transferFiles.Select(PsyAudioFileReader.ReadInfo).ToArray();
            var transferPassed = transferVariants.Count == 4
                                 && transferResult.SuccessCount == 4
                                 && transferResult.FailedCount == 0
                                 && File.Exists(transferResult.ReportPath)
                                  && transferInfos.All(row => row.Channels == 1 && row.SampleRate == 44100 && row.BitDepth == 16)
                                  && transferInfos.All(row => row.Duration is > .08 and < .14);
            var autoVariantSuffixPassed = transferFiles.Distinct(StringComparer.OrdinalIgnoreCase).Count() == 4
                                          && transferFiles.All(path => Path.GetFileNameWithoutExtension(path).Contains("_p", StringComparison.OrdinalIgnoreCase));
            var wideVariantRangePassed = TransferEngine.BuildVariants(new TransferOptions
            {
                VariantsEnabled = true,
                VariantPitches = "-48,48",
                VariantRates = "0.1,4",
                VariantGains = "-60,24",
                VariantReverse = false
            }).Count == 8;
            var waveMetadataPassed = transferFiles.All(path => WaveHasChunk(path, "iXML"));

            var flacDirectory = Path.Combine(working, "transfer-flac");
            var flacOptions = new TransferOptions
            {
                OutputDirectory = flacDirectory,
                NamingTemplate = "{name}_flac",
                Scope = "full",
                Format = "flac",
                SampleRate = "source",
                Channels = "source",
                NormalizeMode = "off",
                Dither = false,
                NoiseShaping = false,
                VariantsEnabled = false,
                VariantReverse = false,
                Pitch = 0,
                Rate = 1,
                Gain = 0,
                Reverse = false,
                PreservePitch = true,
                PreserveMetadata = true,
                CollisionPolicy = "increment"
            };
            var flacVariant = TransferEngine.BuildVariants(flacOptions)[0];
            var flacResult = await new TransferEngine().RunAsync(
                [new TransferRequest(transferAsset, -1, -1, flacVariant, 1)], flacOptions,
                new InlineProgress<TransferProgress>(), CancellationToken.None);
            var flacPath = flacResult.LastOutput;
            var flacPassed = flacResult.SuccessCount == 1 && flacResult.FailedCount == 0
                             && flacPath != null && File.Exists(flacPath) && new FileInfo(flacPath).Length > 100;

            var reliability = new CatalogReliabilityService(Path.Combine(working, "reliability-data"));
            reliability.BeginScan();
            reliability.UpdateScan(150, wavPath);
            var checkpointPassed = reliability.LoadCheckpoint() is { Active: true, ProcessedFiles: 150 } checkpoint
                                   && checkpoint.LastFile == wavPath;
            reliability.CompleteScan([new FailedScanItem("broken.wav", "self test", DateTimeOffset.UtcNow, 1)]);
            var failureRecoveryPassed = reliability.LoadCheckpoint() is null
                                        && reliability.LoadFailures() is [{ Path: "broken.wav", Attempts: 1 }];
            var backupPath = await reliability.CreateBackupAsync(detailDatabase.DatabasePath, 3);
            var backupPassed = File.Exists(backupPath)
                               && await PsyReaSFXDatabase.CheckIntegrityAsync(backupPath) == "ok";
            await reliability.StageRestoreLatestAsync();
            var restoreStagingPassed = File.Exists(reliability.PendingRestorePath);
            var rwfValidPath = Path.Combine(working, "valid.rwf");
            await File.WriteAllBytesAsync(rwfValidPath, Encoding.ASCII.GetBytes("RWF2 2\n\0\0\xff\xff"));
            var cacheValidationPassed = LuaWaveCache.ValidateFile(rwfValidPath)
                                        && !LuaWaveCache.ValidateFile(Path.Combine(working, "missing.rwf"));
            var channelSource = new FiniteChannelProvider(48000, 4,
                [.1f, .2f, .3f, .4f, .15f, .25f, .35f, .45f]);
            var isolatedChannel = new AuditionChannelSampleProvider(channelSource, [2]);
            var isolatedBuffer = new float[4];
            var isolatedRead = isolatedChannel.Read(isolatedBuffer, 0, isolatedBuffer.Length);
            var channelIsolationPassed = isolatedRead == 4
                                         && Math.Abs(isolatedBuffer[0] - .3f) < .0001f
                                         && Math.Abs(isolatedBuffer[1] - .3f) < .0001f
                                         && Math.Abs(isolatedBuffer[2] - .35f) < .0001f
                                         && Math.Abs(isolatedBuffer[3] - .35f) < .0001f;
            var channelWaveform = new WaveformControl { AuditionChannels = [2] };
            var channelWaveformStatePassed = channelWaveform.AuditionChannels.SequenceEqual([2]);

            var originalCacheDirectory = LuaWaveCache.CacheDirectory;
            var customCacheDirectory = Path.Combine(working, "custom-wave-cache");
            var migratedCacheDirectory = Path.Combine(working, "migrated-wave-cache");
            bool customCachePassed;
            try
            {
                LuaWaveCache.Configure(customCacheDirectory);
                var detailWaveform = PsyAudioFileReader.ReadWaveform(wavPath, 2048);
                var writtenCache = Directory.EnumerateFiles(customCacheDirectory, "*.rwf").FirstOrDefault();
                var cacheMigration = await LuaWaveCache.MigrateAsync(customCacheDirectory, migratedCacheDirectory, true);
                customCachePassed = detailWaveform.Length == 2
                                    && writtenCache != null
                                    && cacheMigration.Copied >= 1
                                    && cacheMigration.Failed == 0
                                    && !File.Exists(writtenCache)
                                    && Directory.EnumerateFiles(migratedCacheDirectory, "*.rwf").Any(LuaWaveCache.ValidateFile);
            }
            finally { LuaWaveCache.Configure(originalCacheDirectory); }
            using (var watchProbe = new LibraryWatchService()) watchProbe.Start([], TimeSpan.FromSeconds(2));

            var passed = info.Duration > .45 && info.Duration < .55
                         && info.Channels == 2
                         && info.SampleRate == 48000
                         && waveform.Length == 1
                         && waveform.All(channel => channel.Length == 256 && channel.Max() > .1f)
                         && indexed.Count == 1
                         && indexed[0].DurationSeconds > .45
                         && migrationPassed
                         && assetDetailsPassed
                         && organizationPassed
                         && regionPersistencePassed
                         && selectionDragPassed
                         && loudnessAnalysisPassed
                         && transientDetectionPassed
                          && collectionBindingPassed
                           && preservePitchPassed
                           && transferPassed
                           && autoVariantSuffixPassed
                           && wideVariantRangePassed
                           && waveMetadataPassed
                           && flacPassed
                           && checkpointPassed
                           && failureRecoveryPassed
                           && backupPassed
                           && restoreStagingPassed
                           && cacheValidationPassed
                           && channelIsolationPassed
                           && channelWaveformStatePassed
                           && customCachePassed
                           && uiSmokePassed
                         && (thumbnailStressCount == 0 || thumbnailStress.Elapsed < TimeSpan.FromSeconds(12));

            TryWriteReport(reportPath, new
            {
                passed,
                version = "0.7.23-desktop-alpha.7-light-hotfix.2",
                audio = new { info.Duration, info.Channels, info.SampleRate, info.BitDepth },
                waveformChannels = waveform.Length,
                waveformBuckets = waveform.FirstOrDefault()?.Length ?? 0,
                indexedAssets = indexed.Count,
                uiSmokePassed,
                panelCollapsePassed,
                playheadLayerPassed,
                playheadStaticRebuilds,
                columnResizePassed,
                scrollBarDragBindingPassed,
                scrollBarThumbGesturePassed,
                scrollBarVisualPassed,
                dataGridScrollBarVisualPassed,
                dataGridScrollBarProbe,
                expanderHeaderPassed,
                languageSwitchPassed,
                settingsLanguageSwitchPassed,
                helpWindowPassed,
                transferWindowPassed,
                themeSwitchPassed,
                themeProbeColors,
                assetDetailsPassed,
                organizationPassed,
                regionPersistencePassed,
                selectionDragPassed,
                loudnessAnalysisPassed,
                loudness = new { loudness.LufsI, loudness.LufsM, loudness.LufsS, loudness.TruePeak },
                transientDetectionPassed,
                transientRegions = detectedTransients.Count,
                collectionBindingPassed,
                preservePitchPassed,
                pitchRate = new { pitchRate.Preserved, pitchRate.Coupled },
                transferPassed,
                autoVariantSuffixPassed,
                wideVariantRangePassed,
                waveMetadataPassed,
                flacPassed,
                reliability = new
                {
                    checkpointPassed,
                    failureRecoveryPassed,
                    backupPassed,
                    restoreStagingPassed,
                    cacheValidationPassed,
                    channelIsolationPassed,
                    channelWaveformStatePassed,
                    customCachePassed
                },
                flacOutput = flacPath is null ? null : Path.GetFileName(flacPath),
                transfer = new
                {
                    jobs = transferResult.Items.Count,
                    transferResult.SuccessCount,
                    transferResult.SkippedCount,
                    transferResult.FailedCount,
                    report = Path.GetFileName(transferResult.ReportPath),
                    files = transferFiles.Select(Path.GetFileName).ToArray(),
                    formats = transferInfos.Select(row => new { row.Duration, row.Channels, row.SampleRate, row.BitDepth }).ToArray()
                },
                uiSmokeError,
                importedWaveform = new
                {
                    file = liveAsset is null ? null : Path.GetFileName(liveAsset.Path),
                    channels = liveWaveform.Length,
                    peak = liveWaveform.SelectMany(channel => channel).DefaultIfEmpty().Max()
                },
                thumbnailStress = new { count = thumbnailStressCount, elapsedMs = thumbnailStress.Elapsed.TotalMilliseconds },
                luaMigration = new
                {
                    sourceDetected = luaDirectory is not null,
                    migration.Imported,
                    libraries = catalog.Libraries.Count,
                    sources = catalog.Sources.Count,
                    assets = catalog.Assets.Count,
                    migration.Collections,
                    migration.SavedSearches,
                    migration.HistoryRows,
                    migration.Regions,
                    migration.LoudnessRows
                },
                timestampUtc = DateTime.UtcNow
            });
            return passed ? 0 : 2;
        }
        catch (Exception ex)
        {
            TryWriteReport(reportPath, new { passed = false, error = ex.ToString(), timestampUtc = DateTime.UtcNow });
            return 1;
        }
        finally
        {
            try { Directory.Delete(working, true); } catch { }
        }
    }

    private static void TryWriteReport(string path, object value)
    {
        try
        {
            if (Directory.Exists(path)) path = Path.Combine(path, "PsyReaSFX-Desktop-self-test.json");
            var directory = Path.GetDirectoryName(Path.GetFullPath(path));
            if (!string.IsNullOrEmpty(directory)) Directory.CreateDirectory(directory);
            File.WriteAllText(path, JsonSerializer.Serialize(value, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch (Exception exception) { AppDiagnostics.Write("Unable to write desktop self-test report.", exception); }
    }

    private static IEnumerable<T> FindVisualChildren<T>(DependencyObject root) where T : DependencyObject
    {
        for (var index = 0; index < VisualTreeHelper.GetChildrenCount(root); index++)
        {
            var child = VisualTreeHelper.GetChild(root, index);
            if (child is T match) yield return match;
            foreach (var nested in FindVisualChildren<T>(child)) yield return nested;
        }
    }

    private static void AppendWaveChunk(string path, string id, byte[] data)
    {
        if (id.Length != 4) throw new ArgumentException("RIFF chunk IDs must contain four characters.", nameof(id));
        using var stream = new FileStream(path, FileMode.Open, FileAccess.ReadWrite, FileShare.None);
        stream.Seek(0, SeekOrigin.End);
        using (var writer = new BinaryWriter(stream, Encoding.ASCII, true))
        {
            writer.Write(Encoding.ASCII.GetBytes(id));
            writer.Write((uint)data.Length);
            writer.Write(data);
            if ((data.Length & 1) != 0) writer.Write((byte)0);
        }
        stream.Seek(4, SeekOrigin.Begin);
        using var sizeWriter = new BinaryWriter(stream, Encoding.ASCII, true);
        sizeWriter.Write((uint)(stream.Length - 8));
    }

    private static bool WaveHasChunk(string path, string wanted)
    {
        using var reader = new BinaryReader(File.Open(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite), Encoding.ASCII);
        if (Encoding.ASCII.GetString(reader.ReadBytes(4)) != "RIFF") return false;
        _ = reader.ReadUInt32();
        if (Encoding.ASCII.GetString(reader.ReadBytes(4)) != "WAVE") return false;
        while (reader.BaseStream.Position + 8 <= reader.BaseStream.Length)
        {
            var id = Encoding.ASCII.GetString(reader.ReadBytes(4));
            var size = reader.ReadUInt32();
            if (id == wanted) return true;
            if (reader.BaseStream.Position + size > reader.BaseStream.Length) return false;
            reader.BaseStream.Seek(size + (size & 1), SeekOrigin.Current);
        }
        return false;
    }

    private static void WriteTestWave(string path)
    {
        const int sampleRate = 48000;
        const int channels = 2;
        const int bits = 16;
        const double duration = .5;
        var frames = (int)(sampleRate * duration);
        var dataLength = frames * channels * (bits / 8);
        using var stream = File.Create(path);
        using var writer = new BinaryWriter(stream, Encoding.ASCII, leaveOpen: false);
        writer.Write(Encoding.ASCII.GetBytes("RIFF"));
        writer.Write(36 + dataLength);
        writer.Write(Encoding.ASCII.GetBytes("WAVEfmt "));
        writer.Write(16);
        writer.Write((ushort)1);
        writer.Write((ushort)channels);
        writer.Write(sampleRate);
        writer.Write(sampleRate * channels * (bits / 8));
        writer.Write((ushort)(channels * (bits / 8)));
        writer.Write((ushort)bits);
        writer.Write(Encoding.ASCII.GetBytes("data"));
        writer.Write(dataLength);
        for (var frame = 0; frame < frames; frame++)
        {
            var sample = (short)(Math.Sin(frame * Math.Tau * 440 / sampleRate) * short.MaxValue * .35);
            writer.Write(sample);
            writer.Write((short)-sample);
        }
    }

    private static void WriteTestWave24BitStereo(string path)
    {
        const int sampleRate = 48000;
        const int channels = 2;
        const int bits = 24;
        const double duration = .5;
        var frames = (int)(sampleRate * duration);
        var blockAlign = channels * bits / 8;
        var dataLength = frames * blockAlign;
        using var stream = File.Create(path);
        using var writer = new BinaryWriter(stream, Encoding.ASCII, leaveOpen: false);
        writer.Write(Encoding.ASCII.GetBytes("RIFF"));
        writer.Write(36 + dataLength);
        writer.Write(Encoding.ASCII.GetBytes("WAVEfmt "));
        writer.Write(16);
        writer.Write((ushort)1);
        writer.Write((ushort)channels);
        writer.Write(sampleRate);
        writer.Write(sampleRate * blockAlign);
        writer.Write((ushort)blockAlign);
        writer.Write((ushort)bits);
        writer.Write(Encoding.ASCII.GetBytes("data"));
        writer.Write(dataLength);
        for (var frame = 0; frame < frames; frame++)
        {
            var sample = (int)(Math.Sin(frame * Math.Tau * 440 / sampleRate) * 0x7FFFFF * .35);
            Write24(writer, sample);
            Write24(writer, -sample);
        }

        static void Write24(BinaryWriter writer, int value)
        {
            writer.Write((byte)(value & 0xFF));
            writer.Write((byte)((value >> 8) & 0xFF));
            writer.Write((byte)((value >> 16) & 0xFF));
        }
    }

    private static (double Preserved, double Coupled) VerifyPitchRatePipeline()
    {
        static double Measure(bool preserve)
        {
            const int sampleRate = 48000;
            const double rate = 1.5;
            ISampleProvider source = new InfiniteSineProvider(sampleRate, 2, 440);
            var pitch = new SmbPitchShiftingSampleProvider(source)
            {
                PitchFactor = preserve ? (float)(1 / rate) : 1f
            };
            var provider = new RateSampleProvider(pitch) { Rate = rate };
            var block = new float[4096];
            var warmupSamples = sampleRate * 2;
            while (warmupSamples > 0)
            {
                var read = provider.Read(block, 0, Math.Min(block.Length, warmupSamples));
                if (read <= 0) break;
                warmupSamples -= read;
            }
            var wantedFrames = sampleRate;
            var crossings = 0;
            var frames = 0;
            var previous = 0f;
            var hasPrevious = false;
            while (frames < wantedFrames)
            {
                var read = provider.Read(block, 0, Math.Min(block.Length, (wantedFrames - frames) * 2));
                if (read <= 0) break;
                for (var sample = 0; sample + 1 < read; sample += 2)
                {
                    var current = block[sample];
                    if (hasPrevious && previous <= 0 && current > 0) crossings++;
                    previous = current;
                    hasPrevious = true;
                    frames++;
                }
            }
            return frames > 0 ? crossings * sampleRate / (double)frames : 0;
        }

        return (Measure(true), Measure(false));
    }

    private sealed class InfiniteSineProvider(int sampleRate, int channels, double frequency) : ISampleProvider
    {
        private long _frame;
        public WaveFormat WaveFormat { get; } = WaveFormat.CreateIeeeFloatWaveFormat(sampleRate, channels);

        public int Read(float[] buffer, int offset, int count)
        {
            var frames = count / channels;
            for (var frame = 0; frame < frames; frame++)
            {
                var value = (float)(Math.Sin((_frame + frame) * Math.Tau * frequency / sampleRate) * .35);
                for (var channel = 0; channel < channels; channel++) buffer[offset + frame * channels + channel] = value;
            }
            _frame += frames;
            return frames * channels;
        }
    }

    private sealed class FiniteChannelProvider(int sampleRate, int channels, float[] samples) : ISampleProvider
    {
        private int _position;
        public WaveFormat WaveFormat { get; } = WaveFormat.CreateIeeeFloatWaveFormat(sampleRate, channels);
        public int Read(float[] buffer, int offset, int count)
        {
            var available = Math.Min(count, samples.Length - _position);
            if (available <= 0) return 0;
            Array.Copy(samples, _position, buffer, offset, available);
            _position += available;
            return available;
        }
    }

    private sealed class InlineProgress<T> : IProgress<T>
    {
        public void Report(T value) { }
    }
}
