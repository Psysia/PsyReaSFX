using System.Text;
using System.Text.Json;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using PsyReaSFX.Desktop.Services;
using PsyReaSFX.Data;

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
            var info = AudioFileReader.ReadInfo(wavPath);
            var waveform = AudioFileReader.ReadWaveform(wavPath, 256);
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
            var assetDetailsPassed = savedDetails.Description == "after" && savedDetails.Keywords == "impact, test"
                                     && savedDetails.WorkflowStatus == "approved" && savedDetails.Marked;

            var liveAsset = catalog.Assets.FirstOrDefault(asset => File.Exists(asset.Path) &&
                (Path.GetExtension(asset.Path).Equals(".wav", StringComparison.OrdinalIgnoreCase) || Path.GetExtension(asset.Path).Equals(".wave", StringComparison.OrdinalIgnoreCase)));
            var liveWaveform = liveAsset is null ? [] : AudioFileReader.ReadWaveform(liveAsset.Path, 256);
            var thumbnailStress = System.Diagnostics.Stopwatch.StartNew();
            var thumbnailStressCount = 0;
            foreach (var asset in catalog.Assets.Where(asset => File.Exists(asset.Path)).Take(64))
            {
                _ = AudioFileReader.ReadWaveform(asset.Path, 256);
                thumbnailStressCount++;
            }
            thumbnailStress.Stop();
            var uiSmokePassed = false;
            var panelCollapsePassed = false;
            var playheadLayerPassed = false;
            var playheadStaticRebuilds = 0;
            var columnResizePassed = false;
            string? uiSmokeError = null;
            try
            {
                // Constructing the shell catches missing resources, duplicate
                // styles and invalid XAML event bindings without showing it or
                // opening the user's catalog.
                var shell = new MainWindow();
                columnResizePassed = shell.AssetGrid.CanUserResizeColumns && shell.AssetGrid.Columns.All(column => column.CanUserResize);
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

                var waveformControl = new Controls.WaveformControl { Width = 960, Height = 180 };
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
                uiSmokePassed = panelCollapsePassed && playheadLayerPassed && columnResizePassed;
            }
            catch (Exception exception)
            {
                uiSmokeError = exception.ToString();
                AppDiagnostics.Write("Desktop UI smoke test failed.", exception);
            }
            var passed = info.Duration > .45 && info.Duration < .55
                         && info.Channels == 2
                         && info.SampleRate == 48000
                         && waveform.Length == 1
                         && waveform.All(channel => channel.Length == 256 && channel.Max() > .1f)
                         && indexed.Count == 1
                         && indexed[0].DurationSeconds > .45
                         && migrationPassed
                         && assetDetailsPassed
                         && uiSmokePassed
                         && (thumbnailStressCount == 0 || thumbnailStress.Elapsed < TimeSpan.FromSeconds(12));

            TryWriteReport(reportPath, new
            {
                passed,
                version = "0.7.23-desktop-alpha.4-light-rc.1",
                audio = new { info.Duration, info.Channels, info.SampleRate, info.BitDepth },
                waveformChannels = waveform.Length,
                waveformBuckets = waveform.FirstOrDefault()?.Length ?? 0,
                indexedAssets = indexed.Count,
                uiSmokePassed,
                panelCollapsePassed,
                playheadLayerPassed,
                playheadStaticRebuilds,
                columnResizePassed,
                assetDetailsPassed,
                uiSmokeError,
                importedWaveform = new
                {
                    path = liveAsset?.Path,
                    channels = liveWaveform.Length,
                    peak = liveWaveform.SelectMany(channel => channel).DefaultIfEmpty().Max()
                },
                thumbnailStress = new { count = thumbnailStressCount, elapsedMs = thumbnailStress.Elapsed.TotalMilliseconds },
                luaMigration = new
                {
                    source = luaDirectory,
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

    private sealed class InlineProgress<T> : IProgress<T>
    {
        public void Report(T value) { }
    }
}
