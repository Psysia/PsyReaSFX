using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Data;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Threading;
using Microsoft.VisualBasic;
using Microsoft.Win32;
using PsyReaSFX.Data;
using PsyReaSFX.Desktop.Controls;
using PsyReaSFX.Desktop.Services;

namespace PsyReaSFX.Desktop;

public partial class MainWindow : Window
{
    private enum BrowseMode { All, Favorites, RecentUsed, PreviewHistory }
    private enum SortMode { Name, Duration, Library, RecentlyPreviewed }
    private readonly record struct QueryToken(string Field, string Term, bool Exclude);

    private readonly StateStore _store = new();
    private readonly DesktopPreferencesStore _preferencesStore = new();
    private readonly LibraryIndexer _indexer = new();
    private readonly CatalogReliabilityService _reliability;
    private readonly LibraryWatchService _watchFolders = new();
    private ObservableCollection<AudioAsset> _assets = [];
    private readonly LowLatencyPreviewEngine _previewEngine = new();
    private readonly DispatcherTimer _timer = new() { Interval = TimeSpan.FromMilliseconds(100) };
    private readonly DispatcherTimer _searchTimer = new() { Interval = TimeSpan.FromMilliseconds(180) };
    private readonly DispatcherTimer _autoPreviewTimer = new() { Interval = TimeSpan.FromMilliseconds(110) };
    private readonly DispatcherTimer _activitySaveTimer = new() { Interval = TimeSpan.FromMilliseconds(900) };
    private readonly HashSet<string> _activityDirty = new(StringComparer.OrdinalIgnoreCase);
    private bool _activitySaveInFlight;
    private PersistedState _state = new();
    private DesktopPreferences _preferences = new();
    private ICollectionView _view;
    private CancellationTokenSource? _scanCancellation;
    private AudioAsset? _selected;
    private AudioAsset? _previewing;
    private string _libraryIdFilter = "";
    private string _sourceFilter = "";
    private string _statusFilter = "";
    private BrowseMode _browseMode;
    private SortMode _sortMode;
    private bool _sortDescending;
    private bool _autoPreview = true;
    private bool _isPlaying;
    private bool _initialized;
    private bool _focusMode;
    private bool _navigationVisible = true;
    private bool _inspectorVisible = true;
    private bool _suppressSelectionPreview;
    private double _pendingSeekRatio;
    private CancellationTokenSource? _previewCancellation;
    private long _lastTimeTextUpdateTick;
    private long _playbackClockAnchorTicks;
    private double _playbackClockAnchorSeconds;
    private double _playbackRate = 1;
    private double _pitchSemitones;
    private double _gainDb;
    private bool _reverseAudition;
    private bool _preservePitch = true;
    private GridLength _navigationWidth = new(240);
    private GridLength _inspectorWidth = new(292);
    private Point _dragStart;
    private List<QueryToken> _queryTokens = [];
    private int _visibleCount;
    private double _selectionStartRatio = -1;
    private double _selectionEndRatio = -1;
    private bool _loopSelection;
    private bool _spaceRestartsSelection;
    private int _channelMode;
    private string _collectionIdFilter = "";
    private HashSet<string>? _activeCollectionPaths;
    private string _categoryFacet = "";
    private string _formatFacet = "";
    private int _channelFacet;
    private bool _updatingFacetControls;
    private readonly Stack<MetadataSnapshot[]> _metadataUndo = new();
    private readonly Dictionary<string, string> _metadataBaseline = new(StringComparer.Ordinal);
    private string? _editingParameter;
    private bool _committingParameterEditor;
    private HashSet<string> _savedSessionPlayed = new(StringComparer.OrdinalIgnoreCase);
    private bool _skipSessionSnapshotSave;
    private readonly ObservableCollection<RegionRecord> _previewRegions = [];
    private bool _loadingPreviewRegions;
    private Point _selectionDragStart;
    private bool _selectionDragArmed;
    private CancellationTokenSource? _selectionDragPreparation;
    private CancellationTokenSource? _analysisCancellation;
    private LoudnessRecord? _currentLoudness;
    private string? _preparedSelectionDragPath;
    private string _preparedSelectionDragKey = "";
    private bool _watchScanPending;
    private HelpWindow? _helpWindow;

    public static readonly DependencyProperty InlineWaveformResolutionProperty = DependencyProperty.Register(
        nameof(InlineWaveformResolution), typeof(int), typeof(MainWindow), new PropertyMetadata(512));
    public int InlineWaveformResolution
    {
        get => (int)GetValue(InlineWaveformResolutionProperty);
        set => SetValue(InlineWaveformResolutionProperty, value);
    }

    public MainWindow()
    {
        _reliability = new CatalogReliabilityService(_store.DataDirectory);
        InitializeComponent();
        _preferences = _preferencesStore.Load();
        LuaWaveCache.Configure(_preferences.WaveformCacheDirectory);
        ApplyPreferences(_preferences, false);
        _view = CollectionViewSource.GetDefaultView(_assets);
        _view.Filter = FilterAsset;
        AssetGrid.ItemsSource = _view;
        RegionSelector.ItemsSource = _previewRegions;

        _previewEngine.PlaybackEnded += (_, _) => Dispatcher.Invoke(() =>
        {
            if (_loopSelection && HasValidSelection() && _previewing != null)
            {
                StartPreview(_selectionStartRatio);
                return;
            }
            _isPlaying = false;
            SetPlaybackClock(_previewing?.DurationSeconds ?? 0);
            PlayButton.Icon = "play";
            if (_previewing != null) _previewing.PreviewPlayhead = -1;
            SetDetailPlayhead(0, false);
        });
        _previewEngine.PlaybackFailed += (_, exception) => Dispatcher.Invoke(() =>
        {
            _isPlaying = false;
            SetPlaybackClock(0);
            PlayButton.Icon = "play";
            StatusText.Text = T($"无法试听：{exception.Message}", $"Preview failed: {exception.Message}");
            AppDiagnostics.Write("Media preview failed.", exception);
        });
        _timer.Tick += (_, _) => UpdatePreviewTime();
        _timer.Start();
        CompositionTarget.Rendering += PlaybackRendering;
        _searchTimer.Tick += (_, _) =>
        {
            _searchTimer.Stop();
            _queryTokens = ParseSearchQuery(SearchBox.Text);
            RefreshView();
        };
        _autoPreviewTimer.Tick += (_, _) =>
        {
            _autoPreviewTimer.Stop();
            if (_autoPreview && _selected != null) StartPreview(0);
        };
        _activitySaveTimer.Tick += async (_, _) =>
        {
            _activitySaveTimer.Stop();
            await FlushPreviewActivityAsync();
        };

        AutoPreviewButton.Foreground = _autoPreview
            ? (Brush)FindResource("AccentBrightBrush")
            : (Brush)FindResource("MutedBrush");
        AutoPreviewButton.IsActive = _autoPreview;
        UpdateBrowseNavState();
        StatusText.Text = T("正在打开 PsyReaSFX 数据库…", "Opening the PsyReaSFX database…");
        UpdateCount();
        SourceInitialized += (_, _) => EnableDarkTitleBar();
        Loaded += MainWindow_Loaded;
        _watchFolders.ChangeDetected += WatchFolders_ChangeDetected;
    }

    private string T(string zh, string en) => UiLocalization.Text(zh, en, _preferences.Language);

    private void EnableDarkTitleBar()
    {
        if (!OperatingSystem.IsWindows()) return;
        try
        {
            var handle = new WindowInteropHelper(this).Handle;
            var enabled = 1;
            _ = DwmSetWindowAttribute(handle, 20, ref enabled, sizeof(int));
        }
        catch (Exception exception) { AppDiagnostics.Write("Dark title bar setup failed.", exception); }
    }

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr window, int attribute, ref int value, int size);

    private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        try
        {
            var state = await Task.Run(() => _store.LoadAsync());
            _state = state;
            ApplyArtworkFallbacks(state);
            foreach (var item in state.Index) item.IsFavorite = state.Favorites.Contains(item.FilePath);
            _assets = new ObservableCollection<AudioAsset>(state.Index);
            _savedSessionPlayed = _assets.Where(asset => asset.IsSessionPlayed).Select(asset => asset.FilePath)
                .ToHashSet(StringComparer.OrdinalIgnoreCase);
            foreach (var asset in _assets) asset.UiLanguage = _preferences.Language;
            _view = CollectionViewSource.GetDefaultView(_assets);
            _view.Filter = FilterAsset;
            AssetGrid.ItemsSource = _view;
            CollectionList.ItemsSource = _state.Collections;
            SavedSearchList.ItemsSource = _state.SavedSearches;
            ApplySort();
            RebuildLibraryTree();
            RebuildFacets();
            RefreshView();
            if (_view.Cast<object>().FirstOrDefault() is AudioAsset first)
            {
                AssetGrid.SelectedItem = first;
                AssetGrid.ScrollIntoView(first);
            }
            _initialized = true;
            _ = ResolveMissingSourceArtworkAsync();

            ConfigureWatchFolders();
            if (_preferences.AutomaticCatalogBackup)
                _ = Task.Run(async () =>
                {
                    try { await _reliability.EnsureDailyBackupAsync(_store.DatabasePath, _preferences.CatalogBackupRetention); }
                    catch (Exception exception) { AppDiagnostics.Write("Automatic catalog backup failed.", exception); }
                });

            if (_store.LastError is not null)
                StatusText.Text = T($"数据库打开失败 · 日志：{AppDiagnostics.CurrentLogPath}", $"Database open failed · Log: {AppDiagnostics.CurrentLogPath}");
            else if (_store.LastMigration is { Imported: true } migration)
                StatusText.Text = T($"已迁移 Lua 数据：{migration.Libraries} 个库 · {migration.Assets:N0} 个素材", $"Migrated Lua data: {migration.Libraries} libraries · {migration.Assets:N0} assets");
            else
                StatusText.Text = T($"就绪：{_assets.Count:N0} 个素材", $"Ready: {_assets.Count:N0} assets");

            var interrupted = _reliability.LoadCheckpoint() is { Active: true };
            if (_state.Libraries.Count > 0 && ((_state.Index.Count == 0) || (interrupted && _preferences.ResumeInterruptedScan)))
            {
                if (interrupted) StatusText.Text = T("正在恢复上次中断的增量扫描…", "Resuming the interrupted incremental scan…");
                await RescanAsync(false);
            }
        }
        catch (Exception exception)
        {
            AppDiagnostics.Write("Asynchronous workspace initialization failed.", exception);
            StatusText.Text = T($"启动失败 · 日志：{AppDiagnostics.CurrentLogPath}", $"Startup failed · Log: {AppDiagnostics.CurrentLogPath}");
        }
    }

    private bool FilterAsset(object item)
    {
        if (item is not AudioAsset asset) return false;
        if (_libraryIdFilter.Length > 0 && !asset.LibraryId.Equals(_libraryIdFilter, StringComparison.OrdinalIgnoreCase)) return false;
        if (_sourceFilter.Length > 0 && !asset.SourcePath.Equals(_sourceFilter, StringComparison.OrdinalIgnoreCase)) return false;
        if (_statusFilter.Length > 0 && !asset.WorkflowStatus.Equals(_statusFilter, StringComparison.OrdinalIgnoreCase)) return false;
        if (_activeCollectionPaths is not null && !_activeCollectionPaths.Contains(asset.FilePath)) return false;
        if (_categoryFacet.Length > 0 && !asset.Category.Equals(_categoryFacet, StringComparison.OrdinalIgnoreCase)) return false;
        if (_formatFacet.Length > 0 && !asset.Format.Equals(_formatFacet, StringComparison.OrdinalIgnoreCase)) return false;
        if (_channelFacet > 0 && asset.Channels != _channelFacet) return false;
        if (_browseMode == BrowseMode.Favorites && !asset.IsFavorite) return false;
        if (_browseMode == BrowseMode.RecentUsed && asset.UsedCount <= 0) return false;
        if (_browseMode == BrowseMode.PreviewHistory && asset.PreviewCount <= 0) return false;

        if (_queryTokens.Count == 0) return true;
        foreach (var queryToken in _queryTokens)
        {
            var field = queryToken.Field;
            var term = queryToken.Term;
            var matched = field switch
            {
                "library" => Contains(asset.LibraryName, term),
                "category" => Contains(asset.Category, term),
                "subcategory" => Contains(asset.Subcategory, term),
                "catid" => Contains(asset.CatId, term),
                "status" => Contains(asset.WorkflowStatus, term),
                "path" or "folder" => Contains(asset.FilePath, term) || Contains(asset.RelativeFolder, term),
                "keyword" or "keywords" => Contains(asset.Keywords, term),
                "description" or "desc" => Contains(asset.Description, term),
                "format" => Contains(asset.Format, term),
                "channels" or "ch" => asset.Channels.ToString() == term,
                _ => Contains(asset.FileName, term) || Contains(asset.Description, term) || Contains(asset.Keywords, term)
                     || Contains(asset.Category, term) || Contains(asset.Subcategory, term) || Contains(asset.LibraryName, term)
                     || Contains(asset.RelativeFolder, term)
            };
            if ((!queryToken.Exclude && !matched) || (queryToken.Exclude && matched)) return false;
        }
        return true;
    }

    private static List<QueryToken> ParseSearchQuery(string query)
    {
        var tokens = new List<QueryToken>();
        foreach (Match match in Regex.Matches(query.Trim(), "-?(?:[A-Za-z]+:)?(?:\\\"[^\\\"]*\\\"|[^\\s]+)"))
        {
            var token = match.Value;
            if (token.Length == 0) continue;
            var exclude = token.StartsWith('-');
            if (exclude) token = token[1..];
            var separator = token.IndexOf(':');
            var field = separator > 0 ? token[..separator].ToLowerInvariant() : "";
            var term = (separator > 0 ? token[(separator + 1)..] : token).Trim('"');
            if (term.Length > 0) tokens.Add(new QueryToken(field, term, exclude));
        }
        return tokens;
    }

    private static bool Contains(string? value, string term) =>
        !string.IsNullOrEmpty(value) && value.Contains(term, StringComparison.OrdinalIgnoreCase);

    private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        SearchHint.Visibility = string.IsNullOrEmpty(SearchBox.Text) ? Visibility.Visible : Visibility.Collapsed;
        _searchTimer.Stop();
        _searchTimer.Start();
    }
    private void ClearSearch_Click(object sender, RoutedEventArgs e) { SearchBox.Clear(); SearchBox.Focus(); }

    private void RefreshView()
    {
        _view.Filter = FilterAsset;
        _view.Refresh();
        _visibleCount = _view.Cast<object>().Count();
        UpdateCount();
        UpdateBreadcrumb();
    }

    private void ApplySort()
    {
        using (_view.DeferRefresh())
        {
            _view.SortDescriptions.Clear();
            var direction = _sortDescending ? ListSortDirection.Descending : ListSortDirection.Ascending;
            var property = _sortMode switch
            {
                SortMode.Duration => nameof(AudioAsset.DurationSeconds),
                SortMode.Library => nameof(AudioAsset.LibraryName),
                SortMode.RecentlyPreviewed => nameof(AudioAsset.LastPreviewed),
                _ => nameof(AudioAsset.FileName)
            };
            _view.SortDescriptions.Add(new SortDescription(property, direction));
        }
        SortButton.Content = $"{T("排序", "Sort")}: {SortLabel()}";
    }

    private string SortLabel() => _sortMode switch
    {
        SortMode.Duration => T("时长", "Duration"),
        SortMode.Library => T("音效库", "Library"),
        SortMode.RecentlyPreviewed => T("最近试听", "Recently previewed"),
        _ => T("名称", "Name")
    } + (_sortDescending ? " ↓" : "");

    private void Sort_Click(object sender, RoutedEventArgs e)
    {
        if (Keyboard.Modifiers.HasFlag(ModifierKeys.Shift)) _sortDescending = !_sortDescending;
        else _sortMode = (SortMode)(((int)_sortMode + 1) % Enum.GetValues<SortMode>().Length);
        if (_view != null) ApplySort();
    }

    private async void Rescan_Click(object sender, RoutedEventArgs e) => await RescanAsync(true);
    private async Task RescanAsync(bool announce)
    {
        if (_scanCancellation != null) return;
        _scanCancellation = new CancellationTokenSource();
        RescanButton.IsEnabled = false;
        StatusText.Text = T("正在增量扫描音效库…", "Scanning libraries incrementally…");
        _reliability.BeginScan();
        try
        {
            var progress = new Progress<(int Count, string File)>(p =>
            {
                StatusText.Text = T($"正在索引 {p.Count:N0} · {Path.GetFileName(p.File)}", $"Indexing {p.Count:N0} · {Path.GetFileName(p.File)}");
                _reliability.UpdateScan(p.Count, p.File);
            });
            var indexed = await _indexer.BuildAsync(_state.Libraries, _assets, progress, _scanCancellation.Token);
            foreach (var asset in indexed) asset.IsFavorite = _state.Favorites.Contains(asset.FilePath);
            _assets = new ObservableCollection<AudioAsset>(indexed);
            foreach (var asset in _assets) asset.UiLanguage = _preferences.Language;
            _view = CollectionViewSource.GetDefaultView(_assets);
            _view.Filter = FilterAsset;
            AssetGrid.ItemsSource = _view;
            _state.Index = indexed;
            await Task.Run(() => _store.Save(_state));
            ApplySort();
            RebuildLibraryTree();
            RebuildFacets();
            RefreshView();
            _reliability.CompleteScan(_indexer.LastFailures);
            // The set of active source roots may have changed while the scan
            // was running (library management, removable media, restore).
            // Rebuild watchers only after the committed catalog is coherent.
            ConfigureWatchFolders();
            StatusText.Text = _indexer.LastFailures.Count == 0
                ? T($"扫描完成：{indexed.Count:N0} 个素材", $"Scan complete: {indexed.Count:N0} assets")
                : T($"扫描完成：{indexed.Count:N0} 个素材 · {_indexer.LastFailures.Count:N0} 个失败任务可重试",
                    $"Scan complete: {indexed.Count:N0} assets · {_indexer.LastFailures.Count:N0} failed tasks can be retried");
            if (announce && indexed.Count == 0) MessageBox.Show("没有找到受支持的音频文件。", "PsyReaSFX Desktop");
        }
        catch (OperationCanceledException) { StatusText.Text = T("扫描已取消", "Scan cancelled"); }
        catch (Exception ex) { StatusText.Text = T("扫描失败", "Scan failed"); AppDiagnostics.Write("Library scan failed.", ex); MessageBox.Show(ex.Message, T("扫描失败", "Scan failed")); }
        finally
        {
            _scanCancellation.Dispose(); _scanCancellation = null; RescanButton.IsEnabled = true;
            if (_watchScanPending)
            {
                _watchScanPending = false;
                _ = Dispatcher.BeginInvoke(async () => await RescanAsync(false), DispatcherPriority.Background);
            }
        }
    }

    private void ConfigureWatchFolders()
    {
        _watchFolders.Stop();
        if (_preferences.WatchFoldersEnabled)
            _watchFolders.Start(_state.Libraries, TimeSpan.FromSeconds(_preferences.WatchFolderDebounceSeconds));
    }

    private void WatchFolders_ChangeDetected(object? sender, EventArgs e) => Dispatcher.BeginInvoke(async () =>
    {
        if (!_initialized || !_preferences.WatchFoldersEnabled) return;
        if (_scanCancellation != null) { _watchScanPending = true; return; }
        StatusText.Text = T("检测到音效库变化，准备增量更新…", "Library changes detected; preparing an incremental update…");
        await RescanAsync(false);
    });

    private void NewLibrary_Click(object sender, RoutedEventArgs e)
    {
        var name = Interaction.InputBox("为逻辑音效库命名：", "新建逻辑音效库", "New Library").Trim();
        if (string.IsNullOrWhiteSpace(name)) return;
        if (_state.Libraries.Any(l => l.Name.Equals(name, StringComparison.OrdinalIgnoreCase)))
        { MessageBox.Show("已经存在同名逻辑音效库。", "PsyReaSFX Desktop"); return; }
        var library = new LibraryDefinition { Name = name };
        _state.Libraries.Add(library);
        _store.SaveWorkspace(_state);
        RebuildLibraryTree();
        SelectLibrary(library);
        StatusText.Text = $"已建立逻辑音效库：{name}";
    }

    private async void AddSource_Click(object? sender, RoutedEventArgs? e)
    {
        var library = SelectedLibrary();
        if (library == null) { MessageBox.Show("请先在左侧选择一个逻辑音效库。", "PsyReaSFX Desktop"); return; }
        var dialog = new OpenFolderDialog { Title = $"向 {library.Name} 添加素材文件夹", Multiselect = false };
        if (dialog.ShowDialog(this) != true) return;
        if (library.Sources.Any(s => s.Path.Equals(dialog.FolderName, StringComparison.OrdinalIgnoreCase))) return;
        var artwork = ArtworkFinder.FindForSource(dialog.FolderName);
        library.Sources.Add(new LibrarySource { Path = dialog.FolderName, ArtworkPath = artwork });
        _store.SaveWorkspace(_state);
        RebuildLibraryTree();
        await RescanAsync(false);
    }

    private LibraryDefinition? SelectedLibrary() => LibraryTree.SelectedItem switch
    {
        TreeViewItem { Tag: LibraryDefinition library } => library,
        TreeViewItem { Tag: LibrarySource, Parent: TreeViewItem { Tag: LibraryDefinition parent } } => parent,
        _ => _state.Libraries.FirstOrDefault()
    };

    private void RebuildLibraryTree()
    {
        LibraryTree.Items.Clear();
        foreach (var library in _state.Libraries)
        {
            var count = _assets.Count(asset => asset.LibraryId.Equals(library.Id, StringComparison.OrdinalIgnoreCase)
                                              || asset.LibraryName.Equals(library.Name, StringComparison.OrdinalIgnoreCase));
            var node = new TreeViewItem { Header = $"{library.Name}  {count:N0}", Tag = library, IsExpanded = library.IsExpanded };
            node.Expanded += (_, _) => library.IsExpanded = true;
            node.Collapsed += (_, _) => library.IsExpanded = false;
            node.ContextMenu = BuildLibraryMenu(library);
            foreach (var source in library.Sources)
            {
                var sourceCount = _assets.Count(asset => asset.SourcePath.Equals(source.Path, StringComparison.OrdinalIgnoreCase));
                var child = new TreeViewItem { Header = $"●  {source.DisplayName}  {sourceCount:N0}", Tag = source, ToolTip = source.Path };
                child.ContextMenu = BuildSourceMenu(library, source);
                node.Items.Add(child);
            }
            LibraryTree.Items.Add(node);
        }
        AllSoundsCount.Text = _assets.Count.ToString("N0");
        FavoritesCount.Text = _state.Favorites.Count.ToString("N0");
    }

    private ContextMenu BuildLibraryMenu(LibraryDefinition library)
    {
        var menu = new ContextMenu();
        var add = new MenuItem { Header = "添加实体文件夹…" }; add.Click += (_, _) => { SelectLibrary(library); AddSource_Click(null, null); };
        var rename = new MenuItem { Header = "重命名逻辑库…" }; rename.Click += (_, _) => RenameLibrary(library);
        var remove = new MenuItem { Header = "移除逻辑库" }; remove.Click += (_, _) => RemoveLibrary(library);
        menu.Items.Add(add); menu.Items.Add(rename); menu.Items.Add(new Separator()); menu.Items.Add(remove);
        return menu;
    }

    private ContextMenu BuildSourceMenu(LibraryDefinition library, LibrarySource source)
    {
        var menu = new ContextMenu();
        var reveal = new MenuItem { Header = "打开文件夹" }; reveal.Click += (_, _) => OpenFolder(source.Path);
        var chooseArtwork = new MenuItem { Header = "为此路径指定封面…" }; chooseArtwork.Click += (_, _) => ChooseArtworkForSource(library, source);
        var detectArtwork = new MenuItem { Header = "重新自动查找封面" }; detectArtwork.Click += async (_, _) => await DetectArtworkForSourceAsync(source, true);
        var remove = new MenuItem { Header = "从逻辑库移除" }; remove.Click += (_, _) => RemoveSource(library, source);
        menu.Items.Add(reveal); menu.Items.Add(new Separator()); menu.Items.Add(chooseArtwork); menu.Items.Add(detectArtwork);
        menu.Items.Add(new Separator()); menu.Items.Add(remove); return menu;
    }

    private void SelectLibrary(LibraryDefinition library)
    {
        foreach (TreeViewItem item in LibraryTree.Items)
            if (ReferenceEquals(item.Tag, library)) { item.IsSelected = true; item.BringIntoView(); return; }
    }

    private void RenameLibrary(LibraryDefinition library)
    {
        var name = Interaction.InputBox("输入新的逻辑库名称：", "重命名", library.Name).Trim();
        if (name.Length == 0 || _state.Libraries.Any(item => !ReferenceEquals(item, library) && item.Name.Equals(name, StringComparison.OrdinalIgnoreCase))) return;
        var old = library.Name; library.Name = name;
        foreach (var asset in _assets.Where(asset => asset.LibraryId.Equals(library.Id, StringComparison.OrdinalIgnoreCase) || asset.LibraryName.Equals(old, StringComparison.OrdinalIgnoreCase))) asset.LibraryName = name;
        _store.Save(_state); RebuildLibraryTree(); RefreshView();
    }

    private void RemoveLibrary(LibraryDefinition library)
    {
        if (MessageBox.Show($"从 PsyReaSFX 移除逻辑库“{library.Name}”？\n\n不会删除硬盘中的源文件。", "移除逻辑库", MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes) return;
        _state.Libraries.Remove(library);
        var removed = _assets.Where(asset => asset.LibraryId.Equals(library.Id, StringComparison.OrdinalIgnoreCase) || asset.LibraryName.Equals(library.Name, StringComparison.OrdinalIgnoreCase)).ToList();
        foreach (var asset in removed) _assets.Remove(asset);
        _state.Index = _assets.ToList();
        _libraryIdFilter = ""; _sourceFilter = "";
        _store.Save(_state); RebuildLibraryTree(); RefreshView();
    }

    private void RemoveSource(LibraryDefinition library, LibrarySource source)
    {
        if (MessageBox.Show($"从“{library.Name}”移除路径？\n{source.Path}\n\n不会删除硬盘文件。", "移除实体路径", MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes) return;
        library.Sources.Remove(source);
        foreach (var asset in _assets.Where(asset => asset.SourcePath.Equals(source.Path, StringComparison.OrdinalIgnoreCase)).ToList()) _assets.Remove(asset);
        _state.Index = _assets.ToList(); _sourceFilter = "";
        _store.Save(_state); RebuildLibraryTree(); RefreshView();
    }

    private void ManageLibraries_Click(object sender, RoutedEventArgs e)
    {
        foreach (TreeViewItem item in LibraryTree.Items) item.IsExpanded = true;
        StatusText.Text = "右键逻辑库可添加路径、重命名或移除；右键实体路径可打开或移除。";
    }

    private void LibraryTree_SelectedItemChanged(object sender, RoutedPropertyChangedEventArgs<object> e)
    {
        _browseMode = BrowseMode.All; _statusFilter = "";
        _collectionIdFilter = ""; _activeCollectionPaths = null;
        switch (e.NewValue)
        {
            case TreeViewItem { Tag: LibraryDefinition library }:
                _libraryIdFilter = library.Id; _sourceFilter = ""; BreadcrumbText.Text = $"Home  /  {library.Name}"; break;
            case TreeViewItem { Tag: LibrarySource source, Parent: TreeViewItem { Tag: LibraryDefinition parent } }:
                _libraryIdFilter = parent.Id; _sourceFilter = source.Path; BreadcrumbText.Text = $"Home  /  {parent.Name}  /  {source.DisplayName}"; break;
        }
        UpdateBrowseNavState();
        RefreshView();
    }

    private void AllSounds_Click(object sender, RoutedEventArgs e) => SetBrowse(BrowseMode.All);
    private void Favorites_Click(object sender, RoutedEventArgs e) => SetBrowse(BrowseMode.Favorites);
    private void RecentUsed_Click(object sender, RoutedEventArgs e) => SetBrowse(BrowseMode.RecentUsed);
    private void PreviewHistory_Click(object sender, RoutedEventArgs e)
    {
        SetBrowse(BrowseMode.PreviewHistory);
        _sortMode = SortMode.RecentlyPreviewed;
        _sortDescending = true;
        ApplySort();
        RefreshView();
        var first = _view.Cast<object>().OfType<AudioAsset>().FirstOrDefault();
        if (first != null)
        {
            _suppressSelectionPreview = true;
            AssetGrid.SelectedItem = first;
            AssetGrid.ScrollIntoView(first);
            _suppressSelectionPreview = false;
        }
        StatusText.Text = first == null
            ? T("还没有试听记录。试听素材后会立即出现在这里。", "No preview history yet. Audition an asset and it will appear here immediately.")
            : T($"试听历史：{_visibleCount:N0} 个素材", $"Preview history: {_visibleCount:N0} assets");
    }
    private void AllStatus_Click(object sender, RoutedEventArgs e) { _statusFilter = ""; RefreshView(); }
    private void StatusFilter_Click(object sender, RoutedEventArgs e) { _statusFilter = (sender as Button)?.Tag as string ?? ""; RefreshView(); }

    private void SetBrowse(BrowseMode mode)
    {
        _browseMode = mode; _libraryIdFilter = ""; _sourceFilter = ""; _statusFilter = "";
        _collectionIdFilter = ""; _activeCollectionPaths = null;
        // Primary navigation represents a new root view. Hidden query/facet
        // state made Preview history appear empty even though activity existed.
        _categoryFacet = _formatFacet = ""; _channelFacet = 0;
        _queryTokens = [];
        if (SearchBox != null && SearchBox.Text.Length > 0) SearchBox.Clear();
        if (_initialized) RebuildFacets();
        if (CollectionList != null) CollectionList.SelectedItem = null;
        UpdateBrowseNavState();
        RefreshView();
    }

    private void UpdateBrowseNavState()
    {
        if (AllSoundsButton == null || FavoritesButton == null || RecentUsedButton == null || PreviewHistoryButton == null) return;
        var buttons = new[] { AllSoundsButton, FavoritesButton, RecentUsedButton, PreviewHistoryButton };
        foreach (var button in buttons)
        {
            button.Background = Brushes.Transparent;
            button.Foreground = (Brush)FindResource("TextBrush");
        }
        Button? active = (_activeCollectionPaths != null || _libraryIdFilter.Length > 0 || _sourceFilter.Length > 0)
            ? null
            : _browseMode switch
        {
            BrowseMode.Favorites => FavoritesButton,
            BrowseMode.RecentUsed => RecentUsedButton,
            BrowseMode.PreviewHistory => PreviewHistoryButton,
            _ => AllSoundsButton
        };
        if (active != null)
        {
            active.Background = (Brush)FindResource("AccentBrush");
            active.Foreground = Brushes.White;
        }
    }

    private void ClearSessionPlayed_Click(object sender, RoutedEventArgs e)
    {
        foreach (var asset in _assets.Where(asset => asset.IsSessionPlayed)) asset.IsSessionPlayed = false;
        _skipSessionSnapshotSave = true;
        StatusText.Text = T("已清除本次启动的试听高亮；历史记录仍然保留。", "Cleared highlights from this session; preview history is preserved.");
    }

    private void RestoreSessionPlayed_Click(object sender, RoutedEventArgs e)
    {
        foreach (var asset in _assets) asset.IsSessionPlayed = _savedSessionPlayed.Contains(asset.FilePath);
        _skipSessionSnapshotSave = false;
        StatusText.Text = T($"已恢复上次试听高亮：{_savedSessionPlayed.Count:N0} 个素材", $"Restored previous audition highlights: {_savedSessionPlayed.Count:N0} assets");
    }

    private void ClearSavedSessionPlayed_Click(object sender, RoutedEventArgs e)
    {
        _savedSessionPlayed.Clear();
        _skipSessionSnapshotSave = true;
        try { _store.SaveSessionPlayed([]); }
        catch (Exception exception) { AppDiagnostics.Write("Saved preview highlights could not be cleared.", exception); }
        StatusText.Text = T("已清除保存的试听高亮快照。", "Cleared the saved audition highlight snapshot.");
    }

    private void UpdateBreadcrumb()
    {
        if (_sourceFilter.Length > 0 || _libraryIdFilter.Length > 0) return;
        BreadcrumbText.Text = _browseMode switch
        {
            BrowseMode.Favorites => T("Home  /  收藏", "Home  /  Favorites"),
            BrowseMode.RecentUsed => T("Home  /  最近插入", "Home  /  Recently inserted"),
            BrowseMode.PreviewHistory => T("Home  /  试听历史", "Home  /  Preview history"),
            _ => "Home"
        };
    }

    private void RebuildFacets()
    {
        _updatingFacetControls = true;
        try
        {
            CategoryFacet.ItemsSource = new[] { T("全部分类", "All categories") }.Concat(_assets.Select(asset => asset.Category)
                .Where(value => !string.IsNullOrWhiteSpace(value)).Distinct(StringComparer.OrdinalIgnoreCase).Order()).ToArray();
            FormatFacet.ItemsSource = new[] { T("全部格式", "All formats") }.Concat(_assets.Select(asset => asset.Format)
                .Where(value => !string.IsNullOrWhiteSpace(value)).Distinct(StringComparer.OrdinalIgnoreCase).Order()).ToArray();
            ChannelFacet.ItemsSource = new[] { T("全部声道", "All channels") }.Concat(_assets.Select(asset => asset.Channels).Where(value => value > 0)
                .Distinct().Order().Select(value => $"{value} ch")).ToArray();
            CategoryFacet.SelectedIndex = string.IsNullOrWhiteSpace(_categoryFacet) ? 0 : Math.Max(0, CategoryFacet.Items.IndexOf(_categoryFacet));
            FormatFacet.SelectedIndex = string.IsNullOrWhiteSpace(_formatFacet) ? 0 : Math.Max(0, FormatFacet.Items.IndexOf(_formatFacet));
            ChannelFacet.SelectedIndex = _channelFacet == 0 ? 0 : Math.Max(0, ChannelFacet.Items.IndexOf($"{_channelFacet} ch"));
        }
        finally { _updatingFacetControls = false; }
    }

    private void Facet_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_updatingFacetControls || !_initialized) return;
        _categoryFacet = CategoryFacet.SelectedIndex > 0 ? CategoryFacet.SelectedItem?.ToString() ?? "" : "";
        _formatFacet = FormatFacet.SelectedIndex > 0 ? FormatFacet.SelectedItem?.ToString() ?? "" : "";
        var channelText = ChannelFacet.SelectedIndex > 0 ? ChannelFacet.SelectedItem?.ToString() ?? "" : "";
        _channelFacet = int.TryParse(channelText.Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault(), out var channels) ? channels : 0;
        RefreshView();
    }

    private void ClearFacets_Click(object sender, RoutedEventArgs e)
    {
        _categoryFacet = _formatFacet = ""; _channelFacet = 0;
        RebuildFacets(); RefreshView();
    }

    private void CollectionList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (CollectionList.SelectedItem is not AssetCollection collection) return;
        _collectionIdFilter = collection.Id;
        _activeCollectionPaths = collection.Items.ToHashSet(StringComparer.OrdinalIgnoreCase);
        _browseMode = BrowseMode.All; _libraryIdFilter = _sourceFilter = _statusFilter = "";
        UpdateBrowseNavState();
        RefreshView();
        BreadcrumbText.Text = $"Home  /  {collection.Name}";
    }

    private void NewPlaylist_Click(object sender, RoutedEventArgs e) => CreateCollection("playlist", T("新建播放列表", "New playlist"));
    private void NewProjectBin_Click(object sender, RoutedEventArgs e) => CreateCollection("project_bin", T("新建项目素材箱", "New project bin"));

    private void CreateCollection(string kind, string title)
    {
        var name = Interaction.InputBox(T("集合名称：", "Collection name:"), title, kind == "playlist" ? "New playlist" : "New project bin").Trim();
        if (name.Length == 0) return;
        var collection = new AssetCollection { Name = name, Kind = kind };
        foreach (var asset in SelectedAssets()) collection.Items.Add(asset.FilePath);
        _state.Collections.Add(collection);
        PersistOrganization();
        RefreshCollectionLists(collection);
        StatusText.Text = T($"已建立 {name}，包含 {collection.Items.Count:N0} 个素材", $"Created {name} with {collection.Items.Count:N0} assets");
    }

    private void AddToCollection_Click(object sender, RoutedEventArgs e)
    {
        if (CollectionList.SelectedItem is not AssetCollection collection)
        {
            MessageBox.Show(T("请先选择一个播放列表或项目素材箱。", "Select a playlist or project bin first."), "PsyReaSFX Desktop"); return;
        }
        var existing = collection.Items.ToHashSet(StringComparer.OrdinalIgnoreCase);
        var added = 0;
        foreach (var asset in SelectedAssets()) if (existing.Add(asset.FilePath)) { collection.Items.Add(asset.FilePath); added++; }
        _activeCollectionPaths = existing;
        PersistOrganization(); RefreshCollectionLists(collection); RefreshView();
        StatusText.Text = T($"已向 {collection.Name} 加入 {added:N0} 个素材", $"Added {added:N0} assets to {collection.Name}");
    }

    private void RemoveFromCollection_Click(object sender, RoutedEventArgs e)
    {
        if (CollectionList.SelectedItem is not AssetCollection collection) return;
        var remove = SelectedAssets().Select(asset => asset.FilePath).ToHashSet(StringComparer.OrdinalIgnoreCase);
        var count = collection.Items.Count(path => remove.Contains(path));
        for (var index = collection.Items.Count - 1; index >= 0; index--) if (remove.Contains(collection.Items[index])) collection.Items.RemoveAt(index);
        _activeCollectionPaths = collection.Items.ToHashSet(StringComparer.OrdinalIgnoreCase);
        PersistOrganization(); RefreshCollectionLists(collection); RefreshView();
        StatusText.Text = T($"已从 {collection.Name} 移出 {count:N0} 个素材", $"Removed {count:N0} assets from {collection.Name}");
    }

    private void RefreshCollectionLists(AssetCollection? selected = null)
    {
        CollectionViewSource.GetDefaultView(CollectionList.ItemsSource)?.Refresh();
        if (selected != null) CollectionList.SelectedItem = selected;
    }

    private void CollectionList_RightClick(object sender, MouseButtonEventArgs e)
    {
        var item = FindAncestor<ListBoxItem>(e.OriginalSource as DependencyObject);
        if (item?.DataContext is not AssetCollection collection) return;
        CollectionList.SelectedItem = collection;
        var menu = new ContextMenu();
        var rename = new MenuItem { Header = T("重命名…", "Rename…") };
        rename.Click += (_, _) =>
        {
            var name = Interaction.InputBox(T("输入新的集合名称：", "Enter a new collection name:"), T("重命名集合", "Rename collection"), collection.Name).Trim();
            if (name.Length == 0) return;
            collection.Name = name; PersistOrganization(); RefreshCollectionLists(collection);
        };
        var clear = new MenuItem { Header = T("清空成员", "Clear members") };
        clear.Click += (_, _) => { collection.Items.Clear(); _activeCollectionPaths?.Clear(); PersistOrganization(); RefreshCollectionLists(collection); RefreshView(); };
        var delete = new MenuItem { Header = T("删除集合", "Delete collection") };
        delete.Click += (_, _) =>
        {
            if (MessageBox.Show(T($"删除集合“{collection.Name}”？\n不会删除源文件。", $"Delete collection “{collection.Name}”?\nSource files will not be deleted."), T("删除集合", "Delete collection"), MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes) return;
            _state.Collections.Remove(collection); _collectionIdFilter = ""; _activeCollectionPaths = null;
            PersistOrganization(); RefreshCollectionLists(); RefreshView();
        };
        menu.Items.Add(rename); menu.Items.Add(clear); menu.Items.Add(new Separator()); menu.Items.Add(delete);
        menu.PlacementTarget = item; menu.IsOpen = true; e.Handled = true;
    }

    private void SaveSearch_Click(object sender, RoutedEventArgs e)
    {
        var name = Interaction.InputBox("保存当前查询与筛选条件：", "保存搜索", SearchBox.Text.Length > 0 ? SearchBox.Text : "Saved search").Trim();
        if (name.Length == 0) return;
        var saved = new SavedSearchDefinition
        {
            Name = name, Query = BuildSavedQuery(), View = _browseMode.ToString(), LibraryId = _libraryIdFilter,
            Root = _sourceFilter, StatusFilter = _statusFilter, CollectionId = _collectionIdFilter,
            SortMode = _sortMode.ToString(), SortDescending = _sortDescending
        };
        _state.SavedSearches.Add(saved); PersistOrganization();
        SavedSearchList.SelectedItem = saved;
        StatusText.Text = T($"已保存搜索：{name}", $"Saved search: {name}");
    }

    private string BuildSavedQuery()
    {
        var parts = new List<string>();
        if (!string.IsNullOrWhiteSpace(SearchBox.Text)) parts.Add(SearchBox.Text.Trim());
        if (_categoryFacet.Length > 0) parts.Add($"category:\"{_categoryFacet}\"");
        if (_formatFacet.Length > 0) parts.Add($"format:{_formatFacet}");
        if (_channelFacet > 0) parts.Add($"channels:{_channelFacet}");
        return string.Join(' ', parts);
    }

    private void SavedSearchList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (SavedSearchList.SelectedItem is not SavedSearchDefinition saved) return;
        SearchBox.Text = saved.Query;
        _browseMode = Enum.TryParse<BrowseMode>(saved.View, true, out var view) ? view : BrowseMode.All;
        _libraryIdFilter = saved.LibraryId; _sourceFilter = saved.Root; _statusFilter = saved.StatusFilter;
        _collectionIdFilter = saved.CollectionId;
        var collection = _state.Collections.FirstOrDefault(item => item.Id.Equals(saved.CollectionId, StringComparison.OrdinalIgnoreCase));
        _activeCollectionPaths = collection?.Items.ToHashSet(StringComparer.OrdinalIgnoreCase);
        _sortMode = Enum.TryParse<SortMode>(saved.SortMode, true, out var sort) ? sort : SortMode.Name;
        _sortDescending = saved.SortDescending;
        ApplySort(); RefreshView();
        StatusText.Text = T($"已载入保存搜索：{saved.Name}", $"Loaded saved search: {saved.Name}");
    }

    private void DeleteSavedSearch_Click(object sender, RoutedEventArgs e)
    {
        if (SavedSearchList.SelectedItem is not SavedSearchDefinition saved) return;
        _state.SavedSearches.Remove(saved); PersistOrganization();
    }

    private void PersistOrganization()
    {
        _state.Index = _assets.ToList();
        try { _store.SaveWorkspace(_state); }
        catch (Exception exception) { AppDiagnostics.Write("Organization data could not be saved.", exception); }
    }

    private async void AssetGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        _selected = AssetGrid.SelectedItem as AudioAsset;
        var selectedAssets = AssetGrid.SelectedItems.Cast<AudioAsset>().ToArray();
        InspectorSelectionCount.Text = $"{selectedAssets.Length:N0} selected";
        if (_selected == null) return;
        PreviewTitle.Text = _selected.FileName;
        PreviewTechnical.Text = $"{_selected.DurationText}  ·  {_selected.Channels}ch  ·  {(_selected.SampleRate / 1000.0):0.#}k  ·  {_selected.LibraryName}";
        PreviewLoudness.Text = "";
        _currentLoudness = null;
        _previewRegions.Clear();
        DetailWaveform.Regions = [];
        RegionSelector.Visibility = Visibility.Collapsed;
        DetailWaveform.FilePath = _selected.FilePath;
        DetailWaveform.ClearSelection();
        _selectionStartRatio = _selectionEndRatio = -1;
        CancelPreparedSelectionDrag();
        CancelCancellation(ref _analysisCancellation);
        SelectionDragCapsule.Visibility = Visibility.Collapsed;
        SetDetailPlayhead(0, false);
        InspectorName.Text = _selected.FileName;
        InspectorLibrary.Text = _selected.LibraryName;
        LoadMetadataEditor(selectedAssets);
        UpdateWorkflowControls(selectedAssets);
        InspectorTechnical.Text = _selected.TechnicalText + " · " + _selected.DurationText;
        InspectorPath.Text = _selected.FilePath;
        ArtworkImage.FilePath = _selected.ArtworkPath;
        ArtworkPlaceholder.Visibility = !string.IsNullOrWhiteSpace(_selected.ArtworkPath) && File.Exists(_selected.ArtworkPath)
            ? Visibility.Collapsed : Visibility.Visible;
        OutTimeText.Text = FormatTimeCompact(_selected.DurationSeconds);
        InTimeText.Text = "0.000";
        DurationTimeText.Text = FormatTimeCompact(_selected.DurationSeconds);
        if (_selected.Channels <= _channelMode && _channelMode != 0)
        {
            _channelMode = 0;
        }
        UpdateChannelModePresentation();
        ChannelModeButton.Visibility = _selected.Channels >= 2 ? Visibility.Visible : Visibility.Collapsed;
        await LoadPreviewAnalysisAsync(_selected);
        UpdateCount();
        if (_initialized && _autoPreview && !_suppressSelectionPreview)
        {
            _autoPreviewTimer.Stop();
            _autoPreviewTimer.Start();
        }
    }

    private void AssetGrid_MouseDoubleClick(object sender, MouseButtonEventArgs e) { if (_selected != null) StartPreview(0); }
    private void AssetGrid_PreviewMouseRightButtonUp(object sender, MouseButtonEventArgs e)
    {
        if (FindAncestor<DataGridColumnHeader>(e.OriginalSource as DependencyObject) == null)
        {
            var row = FindAncestor<DataGridRow>(e.OriginalSource as DependencyObject);
            if (row?.Item is not AudioAsset asset) return;
            if (!row.IsSelected)
            {
                AssetGrid.SelectedItems.Clear();
                row.IsSelected = true;
                AssetGrid.SelectedItem = asset;
            }
            var rowMenu = new ContextMenu();
            rowMenu.Items.Add(CreateStatusMenuItem(T("未标记", "Unmarked"), "none"));
            rowMenu.Items.Add(CreateStatusMenuItem(T("候选", "Candidate"), "candidate"));
            rowMenu.Items.Add(CreateStatusMenuItem(T("已采用", "Approved"), "approved"));
            rowMenu.Items.Add(CreateStatusMenuItem(T("已排除", "Rejected"), "rejected"));
            rowMenu.Items.Add(new Separator());
            var mark = new MenuItem { Header = SelectedAssets().All(item => item.Marked) ? T("取消标记", "Unmark assets") : T("标记素材", "Mark assets") };
            mark.Click += Mark_Click;
            rowMenu.Items.Add(mark);
            rowMenu.IsOpen = true;
            e.Handled = true;
            return;
        }
        var menu = new ContextMenu();
        foreach (var column in AssetGrid.Columns)
        {
            var item = new MenuItem
            {
                Header = column.Header?.ToString() ?? "Column",
                IsCheckable = true,
                IsChecked = column.Visibility == Visibility.Visible,
                Tag = column
            };
            item.Click += (_, _) =>
            {
                if (item.Tag is not DataGridColumn target) return;
                var visible = AssetGrid.Columns.Count(candidate => candidate.Visibility == Visibility.Visible);
                if (!item.IsChecked && visible <= 1) { item.IsChecked = true; return; }
                target.Visibility = item.IsChecked ? Visibility.Visible : Visibility.Collapsed;
                SaveResultColumnPreferences();
            };
            menu.Items.Add(item);
        }
        menu.IsOpen = true;
        e.Handled = true;
    }

    private MenuItem CreateStatusMenuItem(string label, string status)
    {
        var item = new MenuItem { Header = label, Tag = status };
        item.Click += WorkflowStatus_Click;
        return item;
    }

    private static T? FindAncestor<T>(DependencyObject? value) where T : DependencyObject
    {
        while (value != null)
        {
            if (value is T found) return found;
            value = VisualTreeHelper.GetParent(value);
        }
        return null;
    }

    private static T? FindVisualChild<T>(DependencyObject? value) where T : DependencyObject
    {
        if (value == null) return null;
        for (var index = 0; index < VisualTreeHelper.GetChildrenCount(value); index++)
        {
            var child = VisualTreeHelper.GetChild(value, index);
            if (child is T found) return found;
            var nested = FindVisualChild<T>(child);
            if (nested != null) return nested;
        }
        return null;
    }

    private void AssetGrid_PreviewMouseWheel(object sender, MouseWheelEventArgs e)
    {
        if (!Keyboard.Modifiers.HasFlag(ModifierKeys.Shift)) return;
        var viewer = AssetGrid.Template?.FindName("DG_ScrollViewer", AssetGrid) as ScrollViewer
                     ?? FindVisualChild<ScrollViewer>(AssetGrid);
        if (viewer == null || viewer.ScrollableWidth <= 0) return;
        var step = Math.Max(64, Math.Min(240, SystemParameters.WheelScrollLines * 36));
        viewer.ScrollToHorizontalOffset(Math.Clamp(viewer.HorizontalOffset - Math.Sign(e.Delta) * step, 0, viewer.ScrollableWidth));
        e.Handled = true;
    }
    private void InlineWaveform_SeekRequested(object? sender, double ratio)
    {
        if (sender is FrameworkElement { DataContext: AudioAsset asset })
        {
            _autoPreviewTimer.Stop();
            if (!ReferenceEquals(AssetGrid.SelectedItem, asset))
            {
                _suppressSelectionPreview = true;
                try { AssetGrid.SelectedItem = asset; AssetGrid.ScrollIntoView(asset); }
                finally { _suppressSelectionPreview = false; }
            }
            _selected = asset;
            StartPreview(ratio);
        }
    }

    protected override void OnPreviewMouseLeftButtonDown(MouseButtonEventArgs e) { _dragStart = e.GetPosition(this); base.OnPreviewMouseLeftButtonDown(e); }
    private void AssetGrid_PreviewMouseMove(object sender, MouseEventArgs e)
    {
        if (e.LeftButton != MouseButtonState.Pressed) return;
        // File dragging must only start from a result row. Previously this
        // handler also intercepted the column-header resize thumb, which made
        // the dividers appear impossible to drag.
        if (FindAncestor<DataGridRow>(e.OriginalSource as DependencyObject) == null) return;
        var position = e.GetPosition(this);
        if (Math.Abs(position.X - _dragStart.X) < SystemParameters.MinimumHorizontalDragDistance && Math.Abs(position.Y - _dragStart.Y) < SystemParameters.MinimumVerticalDragDistance) return;
        var files = AssetGrid.SelectedItems.Cast<AudioAsset>().Select(a => a.FilePath).Where(File.Exists).Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
        if (files.Length == 0) return;
        var effect = DragDrop.DoDragDrop(AssetGrid, new DataObject(DataFormats.FileDrop, files), DragDropEffects.Copy);
        if ((effect & DragDropEffects.Copy) != 0)
        {
            var usedAt = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() / 1000.0;
            foreach (var asset in SelectedAssets())
            {
                asset.UsedCount++;
                asset.LastUsed = usedAt;
                _activityDirty.Add(asset.FilePath);
            }
            _activitySaveTimer.Stop();
            _activitySaveTimer.Start();
            if (_browseMode == BrowseMode.RecentUsed) RefreshView();
        }
    }

    private void DetailWaveform_SeekRequested(object? sender, double ratio) { if (_selected != null) StartPreview(ratio); }
    private void DetailWaveform_ScrubRequested(object? sender, double ratio)
    {
        if (_selected == null) return;
        // Rebuild the preview pipeline at the requested position. Mutating the
        // decoder position underneath the pitch shifter leaves buffered samples
        // from the previous position and is the source of seek/scrub clicks.
        StartPreview(ratio);
    }
    private void DetailWaveform_SelectionChanged(object? sender, Controls.WaveformSelectionChangedEventArgs e)
    {
        _selectionStartRatio = e.Start;
        _selectionEndRatio = e.End;
        if (_selected == null || !HasValidSelection())
        {
            CancelPreparedSelectionDrag();
            SelectionDragCapsule.Visibility = Visibility.Collapsed;
            InTimeText.Text = "0.000";
            OutTimeText.Text = _selected == null ? "0.000" : FormatTimeCompact(_selected.DurationSeconds);
            DurationTimeText.Text = _selected == null ? "0.000" : FormatTimeCompact(_selected.DurationSeconds);
            return;
        }
        var duration = _selected.DurationSeconds;
        SelectionDragCapsule.Visibility = Visibility.Visible;
        PositionSelectionDragCapsule();
        InTimeText.Text = FormatTimeCompact(_selectionStartRatio * duration);
        OutTimeText.Text = FormatTimeCompact(_selectionEndRatio * duration);
        DurationTimeText.Text = FormatTimeCompact((_selectionEndRatio - _selectionStartRatio) * duration);
        ScheduleSelectionDragPreparation();
    }

    private void DetailWaveform_ZoomChanged(object? sender, double zoom)
    {
        if (ZoomText != null) ZoomText.Text = $"×{zoom:0.0}";
        PositionSelectionDragCapsule();
    }

    private void DetailWaveformHost_SizeChanged(object sender, SizeChangedEventArgs e) => PositionSelectionDragCapsule();

    private bool HasValidSelection() => _selectionStartRatio >= 0 && _selectionEndRatio > _selectionStartRatio + .00001;

    private void PositionSelectionDragCapsule()
    {
        if (SelectionDragCapsule == null || SelectionDragOverlay == null || !HasValidSelection()) return;
        Dispatcher.BeginInvoke(() =>
        {
            var bounds = DetailWaveform.GetSelectionDisplayBounds();
            if (bounds.IsEmpty) return;
            SelectionDragCapsule.Measure(new Size(double.PositiveInfinity, double.PositiveInfinity));
            var width = Math.Max(1, SelectionDragCapsule.DesiredSize.Width);
            var available = Math.Max(0, SelectionDragOverlay.ActualWidth - width);
            var left = Math.Clamp(bounds.Left + (bounds.Width - width) / 2, 0, available);
            Canvas.SetLeft(SelectionDragCapsule, left);
        }, System.Windows.Threading.DispatcherPriority.Loaded);
    }

    private async Task LoadPreviewAnalysisAsync(AudioAsset asset)
    {
        try
        {
            var regionsTask = _store.LoadRegionsAsync(asset.FilePath);
            var loudnessTask = _store.LoadLoudnessAsync(asset.FilePath);
            await Task.WhenAll(regionsTask, loudnessTask);
            if (!ReferenceEquals(_selected, asset)) return;

            _loadingPreviewRegions = true;
            try
            {
                _previewRegions.Clear();
                foreach (var region in regionsTask.Result) _previewRegions.Add(region);
                UpdateRegionOverlays();
                RegionSelector.SelectedItem = null;
                RegionSelector.Visibility = _previewRegions.Count > 0 ? Visibility.Visible : Visibility.Collapsed;
            }
            finally { _loadingPreviewRegions = false; }

            var loudness = loudnessTask.Result;
            if (loudness != null && (loudness.Size <= 0 || loudness.Size == asset.FileSize))
            {
                _currentLoudness = loudness;
                DisplayLoudness(loudness);
                ConfigurePreviewParameters();
            }
            else if (_preferences.ShowLoudnessMetrics || _preferences.LoudnessMatchAudition) _ = AnalyzeLoudnessAsync(asset, false);
        }
        catch (Exception exception)
        {
            AppDiagnostics.Write("Preview Region/loudness data could not be loaded.", exception);
        }
    }

    private void DisplayLoudness(LoudnessRecord loudness)
    {
        if (!_preferences.ShowLoudnessMetrics) { PreviewLoudness.Text = ""; return; }
        var values = new List<string>();
        if (_preferences.ShowLufsI && loudness.LufsI is double integrated) values.Add($"LUFS-I {integrated:0.0}");
        if (_preferences.ShowLufsM && loudness.LufsM is double momentary) values.Add($"M {momentary:0.0}");
        if (_preferences.ShowLufsS && loudness.LufsS is double shortTerm) values.Add($"S {shortTerm:0.0}");
        if (_preferences.ShowTruePeak && loudness.TruePeak is double peak) values.Add($"TP {peak:0.0}");
        PreviewLoudness.Text = string.Join("  ·  ", values);
    }

    private async Task AnalyzeLoudnessAsync(AudioAsset asset, bool force)
    {
        if (!_preferences.ShowLoudnessMetrics && !_preferences.LoudnessMatchAudition && !force) return;
        var cancellation = ReplaceCancellation(ref _analysisCancellation);
        var token = cancellation.Token;
        if (ReferenceEquals(_selected, asset)) PreviewLoudness.Text = T("分析响度…", "Analyzing loudness…");
        try
        {
            var result = await LoudnessAnalyzer.AnalyzeAsync(asset.FilePath, asset.FileSize, token);
            await _store.SaveLoudnessAsync(result, token);
            if (!token.IsCancellationRequested && ReferenceEquals(_selected, asset))
            {
                _currentLoudness = result;
                DisplayLoudness(result);
                ConfigurePreviewParameters();
            }
        }
        catch (OperationCanceledException) { }
        catch (Exception exception)
        {
            if (ReferenceEquals(_selected, asset)) PreviewLoudness.Text = T("响度不可用", "Loudness unavailable");
            AppDiagnostics.Write("Loudness analysis failed.", exception);
        }
        finally
        {
            if (ReferenceEquals(_analysisCancellation, cancellation)) _analysisCancellation = null;
            cancellation.Dispose();
        }
    }

    private void RegionSelector_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_loadingPreviewRegions || RegionSelector.SelectedItem is not RegionRecord region || _selected == null || _selected.DurationSeconds <= 0) return;
        _selectionStartRatio = Math.Clamp(region.Start / _selected.DurationSeconds, 0, 1);
        _selectionEndRatio = Math.Clamp(region.Finish / _selected.DurationSeconds, 0, 1);
        DetailWaveform.SelectionStart = _selectionStartRatio;
        DetailWaveform.SelectionEnd = _selectionEndRatio;
        InTimeText.Text = FormatTimeCompact(region.Start);
        OutTimeText.Text = FormatTimeCompact(region.Finish);
        DurationTimeText.Text = FormatTimeCompact(region.Finish - region.Start);
        SelectionDragCapsule.Visibility = HasValidSelection() ? Visibility.Visible : Visibility.Collapsed;
        PositionSelectionDragCapsule();
        ScheduleSelectionDragPreparation();
        StartPreview(_selectionStartRatio);
    }

    private async Task SaveCurrentRegionAsync()
    {
        if (_selected == null || !HasValidSelection())
        {
            StatusText.Text = T("请先在大波形中建立选区。", "Create a selection in the detail waveform first.");
            return;
        }
        var suggested = $"Region {_previewRegions.Count + 1}";
        var name = Interaction.InputBox(T("输入 Region 名称：", "Enter a Region name:"), "PsyReaSFX", suggested).Trim();
        if (name.Length == 0) return;
        var region = new RegionRecord(_selected.FilePath, _selectionStartRatio * _selected.DurationSeconds,
            _selectionEndRatio * _selected.DurationSeconds, name, "manual", "desktop");
        await _store.SaveRegionAsync(region);
        var existing = _previewRegions.FirstOrDefault(item => item.Start == region.Start && item.Finish == region.Finish && item.Name == region.Name);
        if (existing != null) _previewRegions.Remove(existing);
        _previewRegions.Add(region);
        UpdateRegionOverlays();
        RegionSelector.Visibility = Visibility.Visible;
        RegionSelector.SelectedItem = region;
        StatusText.Text = T($"已保存 Region：{name}", $"Saved Region: {name}");
    }

    private async Task DeleteCurrentRegionAsync()
    {
        if (RegionSelector.SelectedItem is not RegionRecord region) return;
        await _store.DeleteRegionAsync(region);
        _previewRegions.Remove(region);
        UpdateRegionOverlays();
        RegionSelector.SelectedItem = null;
        RegionSelector.Visibility = _previewRegions.Count > 0 ? Visibility.Visible : Visibility.Collapsed;
        StatusText.Text = T($"已删除 Region：{region.Name}", $"Deleted Region: {region.Name}");
    }

    private void UpdateRegionOverlays()
    {
        if (_selected == null || _selected.DurationSeconds <= 0) { DetailWaveform.Regions = []; return; }
        DetailWaveform.Regions = _previewRegions.Select(region => new Controls.WaveformRegion(
            Math.Clamp(region.Start / _selected.DurationSeconds, 0, 1),
            Math.Clamp(region.Finish / _selected.DurationSeconds, 0, 1),
            region.Source.Equals("transient", StringComparison.OrdinalIgnoreCase))).ToArray();
    }

    private async Task DetectTransientsAsync()
    {
        if (_selected == null) return;
        var asset = _selected;
        StatusText.Text = T("正在检测瞬态…", "Detecting transients…");
        try
        {
            if (_preferences.ReplaceTransientSuggestions)
            {
                foreach (var old in _previewRegions.Where(item => item.Source.Equals("transient", StringComparison.OrdinalIgnoreCase)).ToArray())
                { await _store.DeleteRegionAsync(old); _previewRegions.Remove(old); }
            }
            var options = new TransientDetectionOptions(_preferences.TransientThresholdDb, _preferences.TransientSmoothingMs,
                _preferences.TransientMinIntervalMs, _preferences.TransientPreRollMs, _preferences.TransientPostRollMs,
                _preferences.TransientMaxRegions);
            var rows = await TransientDetector.DetectAsync(asset.FilePath, asset.DurationSeconds, options);
            if (!ReferenceEquals(_selected, asset)) return;
            foreach (var row in rows) { await _store.SaveRegionAsync(row); _previewRegions.Add(row); }
            UpdateRegionOverlays();
            RegionSelector.Visibility = _previewRegions.Count > 0 ? Visibility.Visible : Visibility.Collapsed;
            StatusText.Text = T($"已生成 {rows.Count:N0} 个瞬态 Region 建议。", $"Generated {rows.Count:N0} transient Region suggestions.");
        }
        catch (Exception exception)
        {
            StatusText.Text = T($"瞬态检测失败：{exception.Message}", $"Transient detection failed: {exception.Message}");
            AppDiagnostics.Write("Transient detection failed.", exception);
        }
    }

    private async Task UndoLastTransientDetectionAsync()
    {
        var latest = _previewRegions.LastOrDefault(item => item.Source.Equals("transient", StringComparison.OrdinalIgnoreCase));
        if (latest == null) return;
        var rows = _previewRegions.Where(item => item.Source.Equals("transient", StringComparison.OrdinalIgnoreCase)
                                                 && item.BatchId == latest.BatchId).ToArray();
        foreach (var row in rows) { await _store.DeleteRegionAsync(row); _previewRegions.Remove(row); }
        UpdateRegionOverlays();
        RegionSelector.Visibility = _previewRegions.Count > 0 ? Visibility.Visible : Visibility.Collapsed;
        StatusText.Text = T($"已撤销 {rows.Length:N0} 个瞬态建议。", $"Removed {rows.Length:N0} transient suggestions.");
    }

    private async Task ClearTransientSuggestionsAsync()
    {
        var rows = _previewRegions.Where(item => item.Source.Equals("transient", StringComparison.OrdinalIgnoreCase)).ToArray();
        foreach (var row in rows) { await _store.DeleteRegionAsync(row); _previewRegions.Remove(row); }
        UpdateRegionOverlays();
        RegionSelector.Visibility = _previewRegions.Count > 0 ? Visibility.Visible : Visibility.Collapsed;
        StatusText.Text = T("已清除全部瞬态建议。", "Cleared all transient suggestions.");
    }

    private void SelectionDragCapsule_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (!HasValidSelection() || string.IsNullOrWhiteSpace(_preparedSelectionDragPath) || !File.Exists(_preparedSelectionDragPath))
        {
            StatusText.Text = T("选区正在准备，完成后即可拖出。", "The selection is being prepared for drag-out.");
            ScheduleSelectionDragPreparation();
            return;
        }
        _selectionDragStart = e.GetPosition(this);
        _selectionDragArmed = true;
        SelectionDragCapsule.CaptureMouse();
        e.Handled = true;
    }

    private void SelectionDragCapsule_PreviewMouseMove(object sender, MouseEventArgs e)
    {
        if (!_selectionDragArmed || e.LeftButton != MouseButtonState.Pressed || _selected == null || !HasValidSelection()
            || string.IsNullOrWhiteSpace(_preparedSelectionDragPath) || !File.Exists(_preparedSelectionDragPath)) return;
        var point = e.GetPosition(this);
        if (Math.Abs(point.X - _selectionDragStart.X) < SystemParameters.MinimumHorizontalDragDistance
            && Math.Abs(point.Y - _selectionDragStart.Y) < SystemParameters.MinimumVerticalDragDistance) return;
        _selectionDragArmed = false;
        SelectionDragCapsule.ReleaseMouseCapture();
        var asset = _selected;
        try
        {
            var effect = DragDrop.DoDragDrop(SelectionDragCapsule,
                new DataObject(DataFormats.FileDrop, new[] { _preparedSelectionDragPath }), DragDropEffects.Copy);
            if ((effect & DragDropEffects.Copy) != 0)
            {
                asset.UsedCount++;
                asset.LastUsed = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() / 1000.0;
                _activityDirty.Add(asset.FilePath);
                _activitySaveTimer.Stop();
                _activitySaveTimer.Start();
                StatusText.Text = T("已拖出波形选区。", "Waveform selection dragged out.");
            }
        }
        catch (Exception exception)
        {
            StatusText.Text = T($"无法拖出选区：{exception.Message}", $"Could not drag selection: {exception.Message}");
            AppDiagnostics.Write("Waveform selection drag failed.", exception);
        }
    }

    private void SelectionDragCapsule_MouseLeftButtonUp(object sender, MouseButtonEventArgs e)
    {
        _selectionDragArmed = false;
        if (SelectionDragCapsule.IsMouseCaptured) SelectionDragCapsule.ReleaseMouseCapture();
    }

    private string CurrentSelectionDragKey()
    {
        if (_selected == null || !HasValidSelection()) return "";
        return $"{_selected.FilePath}|{_selectionStartRatio:R}|{_selectionEndRatio:R}|{_selected.FileSize}";
    }

    private void CancelPreparedSelectionDrag()
    {
        CancelCancellation(ref _selectionDragPreparation);
        _preparedSelectionDragPath = null;
        _preparedSelectionDragKey = "";
        if (SelectionDragCapsuleText != null) SelectionDragCapsuleText.Text = T("拖出选区", "Drag selection");
    }

    private async void ScheduleSelectionDragPreparation()
    {
        if (_selected == null || !HasValidSelection()) { CancelPreparedSelectionDrag(); return; }
        var key = CurrentSelectionDragKey();
        if (key == _preparedSelectionDragKey && !string.IsNullOrWhiteSpace(_preparedSelectionDragPath) && File.Exists(_preparedSelectionDragPath)) return;
        var cancellation = ReplaceCancellation(ref _selectionDragPreparation);
        var token = cancellation.Token;
        var asset = _selected;
        var start = _selectionStartRatio * asset.DurationSeconds;
        var finish = _selectionEndRatio * asset.DurationSeconds;
        SelectionDragCapsuleText.Text = T("准备选区…", "Preparing…");
        SelectionDragCapsule.Opacity = .65;
        try
        {
            await Task.Delay(90, token);
            var path = await SelectionDragExporter.ExportAsync(asset.FilePath, start, finish, token);
            if (token.IsCancellationRequested || key != CurrentSelectionDragKey()) return;
            _preparedSelectionDragPath = path;
            _preparedSelectionDragKey = key;
            SelectionDragCapsuleText.Text = T("拖出选区", "Drag selection");
            SelectionDragCapsule.Opacity = 1;
        }
        catch (OperationCanceledException) { }
        catch (Exception exception)
        {
            if (token.IsCancellationRequested) return;
            SelectionDragCapsuleText.Text = T("选区不可拖出", "Drag unavailable");
            SelectionDragCapsule.Opacity = .65;
            StatusText.Text = T($"无法准备选区拖放：{exception.Message}", $"Could not prepare selection drag: {exception.Message}");
            AppDiagnostics.Write("Waveform selection pre-export failed.", exception);
        }
        finally
        {
            if (ReferenceEquals(_selectionDragPreparation, cancellation)) _selectionDragPreparation = null;
            cancellation.Dispose();
        }
    }

    private async void StartPreview(double ratio)
    {
        if (_selected == null || !File.Exists(_selected.FilePath)) return;
        var asset = _selected;
        CancellationTokenSource? cancellation = null;
        try
        {
            _autoPreviewTimer.Stop();
            cancellation = ReplaceCancellation(ref _previewCancellation);
            var token = cancellation.Token;
            if (_previewing != null && !ReferenceEquals(_previewing, asset)) _previewing.PreviewPlayhead = -1;
            _previewing = asset;
            _pendingSeekRatio = Math.Clamp(ratio, 0, 1);
            asset.PreviewPlayhead = _pendingSeekRatio;
            var startAt = _pendingSeekRatio * Math.Max(0, asset.DurationSeconds);

            ConfigurePreviewParameters();
            // Reopening the processing chain on an explicit seek clears the
            // pitch shifter's overlap buffer. Reusing that buffer mixed a few
            // frames from the old position into the new one and caused clicks.
            StatusText.Text = T($"正在准备试听：{asset.FileName}", $"Preparing preview: {asset.FileName}");
            await _previewEngine.OpenAsync(asset.FilePath, startAt, true, token);
            if (token.IsCancellationRequested || !ReferenceEquals(_previewing, asset)) return;
            _isPlaying = true;
            SetPlaybackClock(startAt);
            PlayButton.Icon = "pause";
            SetDetailPlayhead(_pendingSeekRatio, true);
            StatusText.Text = T($"试听：{asset.FileName}", $"Previewing: {asset.FileName}");
            MarkPreviewActivity(asset);
        }
        catch (OperationCanceledException) { }
        catch (Exception exception)
        {
            _isPlaying = false;
            PlayButton.Icon = "play";
            StatusText.Text = T($"无法试听：{exception.Message}", $"Preview failed: {exception.Message}");
            AppDiagnostics.Write("Preview start failed.", exception);
        }
        finally
        {
            if (cancellation != null) CompleteCancellation(ref _previewCancellation, cancellation);
        }
    }

    private void ConfigurePreviewParameters()
    {
        _previewEngine.Rate = _playbackRate;
        _previewEngine.PitchSemitones = _pitchSemitones;
        var matchGain = _preferences.LoudnessMatchAudition && _currentLoudness?.LufsI is double integrated
            ? Math.Clamp(_preferences.LoudnessMatchTarget - integrated, -18, 18)
            : 0;
        _previewEngine.GainDb = _gainDb + matchGain;
        _previewEngine.PreservePitch = _preservePitch;
    }

    private void MarkPreviewActivity(AudioAsset asset)
    {
        asset.IsSessionPlayed = true;
        _skipSessionSnapshotSave = false;
        asset.PreviewCount++;
        asset.LastPreviewed = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() / 1000.0;
        _activityDirty.Add(asset.FilePath);
        _activitySaveTimer.Stop();
        _activitySaveTimer.Start();
        if (PreviewHistoryCount != null)
            PreviewHistoryCount.Text = _assets.Count(item => item.PreviewCount > 0).ToString("N0");
        if (_browseMode == BrowseMode.PreviewHistory) RefreshView();
    }

    private async Task FlushPreviewActivityAsync()
    {
        if (_activitySaveInFlight || _activityDirty.Count == 0) return;
        _activitySaveInFlight = true;
        var paths = _activityDirty.ToArray();
        var pathSet = paths.ToHashSet(StringComparer.OrdinalIgnoreCase);
        var changed = _assets.Where(asset => pathSet.Contains(asset.FilePath)).ToArray();
        try
        {
            await _store.SaveActivitiesAsync(changed);
            foreach (var path in paths) _activityDirty.Remove(path);
        }
        catch (Exception exception)
        {
            AppDiagnostics.Write("Preview activity could not be persisted.", exception);
            _activitySaveTimer.Start();
        }
        finally { _activitySaveInFlight = false; }
    }

    private async void Play_Click(object sender, RoutedEventArgs e)
    {
        if (_selected == null) return;
        if (_isPlaying)
        {
            var pausedAt = _previewEngine.Position;
            await _previewEngine.PauseAsync();
            _isPlaying = false;
            SetPlaybackClock(pausedAt);
            PlayButton.Icon = "play";
        }
        else if (_previewEngine.IsOpen && _previewEngine.Path.Equals(_selected.FilePath, StringComparison.OrdinalIgnoreCase))
        {
            var duration = _previewEngine.Duration > 0 ? _previewEngine.Duration : _selected.DurationSeconds;
            var restartAt = HasValidSelection() ? _selectionStartRatio * duration : 0;
            var stopAt = HasValidSelection() ? _selectionEndRatio * duration : duration;
            var resumeAt = _previewEngine.Position;
            if (duration > 0 && resumeAt >= stopAt - .01)
            {
                StartPreview(duration > 0 ? restartAt / duration : 0);
                return;
            }
            _previewEngine.Play(); _isPlaying = true; PlayButton.Icon = "pause";
            SetPlaybackClock(resumeAt);
        }
        else StartPreview(0);
    }

    private async void Stop_Click(object sender, RoutedEventArgs e)
    {
        await _previewEngine.StopAsync(); _isPlaying = false; PlayButton.Icon = "play";
        SetPlaybackClock(0);
        if (_previewing != null) _previewing.PreviewPlayhead = -1;
        SetDetailPlayhead(0, false); UpdatePreviewTime();
    }

    private void UpdatePreviewTime()
    {
        if (_selected == null) { PreviewTime.Text = ""; CurrentTimeText.Text = "0.000"; return; }
        var current = _previewEngine.IsOpen ? _previewEngine.Position : GetPlaybackClockSeconds();
        var previewAsset = _previewing ?? _selected;
        var duration = _previewEngine.Duration > 0 ? _previewEngine.Duration : previewAsset.DurationSeconds;
        if (_isPlaying && _loopSelection && HasValidSelection() && duration > 0
            && current >= _selectionEndRatio * duration)
        {
            StartPreview(_selectionStartRatio);
            return;
        }
        var ratio = duration > 0 ? Math.Clamp(current / duration, 0, 1) : 0;
        SetDetailPlayhead(ratio, ReferenceEquals(_selected, previewAsset) && (_isPlaying || current > 0));
        if (_previewing != null)
            _previewing.PreviewPlayhead = _isPlaying || current > 0 ? ratio : -1;
        var now = Environment.TickCount64;
        if (now - _lastTimeTextUpdateTick >= 32 || !_isPlaying)
        {
            _lastTimeTextUpdateTick = now;
            PreviewTime.Text = $"{FormatTime(current)} / {FormatTime(duration)}";
            CurrentTimeText.Text = FormatTimeCompact(current);
        }
    }

    private void PlaybackRendering(object? sender, EventArgs e)
    {
        if (_isPlaying) UpdatePreviewTime();
    }

    private void SetPlaybackClock(double seconds)
    {
        _playbackClockAnchorSeconds = Math.Max(0, seconds);
        _playbackClockAnchorTicks = Stopwatch.GetTimestamp();
    }

    private double GetPlaybackClockSeconds()
    {
        if (!_isPlaying) return _playbackClockAnchorSeconds;
        var elapsed = Stopwatch.GetElapsedTime(_playbackClockAnchorTicks).TotalSeconds;
        return _playbackClockAnchorSeconds + elapsed * _playbackRate;
    }

    private void SetDetailPlayhead(double ratio, bool visible)
    {
        DetailWaveform.Playhead = visible ? Math.Clamp(ratio, 0, 1) : -1;
    }

    private void RateSlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (RateValue == null) return;
        var current = GetPlaybackClockSeconds();
        RateValue.Text = $"{e.NewValue:0.00}x";
        _playbackRate = e.NewValue;
        SetPlaybackClock(current);
        _previewEngine.Rate = e.NewValue;
    }

    private void PitchSlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (PitchValue == null) return;
        _pitchSemitones = e.NewValue;
        PitchValue.Text = $"{e.NewValue:+0.0;-0.0;+0.0} st";
        _previewEngine.PitchSemitones = e.NewValue;
    }

    private void GainSlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (GainValue == null) return;
        GainValue.Text = $"{e.NewValue:+0.0;-0.0;+0.0} dB";
        _gainDb = e.NewValue;
        _previewEngine.GainDb = e.NewValue;
    }

    private void ParameterValue_DoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (e.ClickCount < 2 || sender is not FrameworkElement { Tag: string parameter }) return;
        BeginParameterEdit(parameter);
        e.Handled = true;
    }

    private void ParameterReset_DoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (e.ClickCount < 2 || sender is not FrameworkElement { Tag: string parameter }) return;
        SetParameterValue(parameter, parameter == "rate" ? 1 : 0);
        StatusText.Text = T($"{ParameterDisplayName(parameter)} 已恢复默认值", $"{ParameterDisplayName(parameter)} reset to default");
        e.Handled = true;
    }

    private void ParameterSlider_PreviewMouseWheel(object sender, MouseWheelEventArgs e)
    {
        if (sender is not Slider { Tag: string parameter } slider) return;
        var increment = parameter == "rate" ? .05 : parameter == "gain" ? .5 : 1;
        SetParameterValue(parameter, slider.Value + Math.Sign(e.Delta) * increment);
        e.Handled = true;
    }

    private void BeginParameterEdit(string parameter)
    {
        if (_editingParameter != null) CommitParameterEdit();
        _editingParameter = parameter;
        var editor = ParameterEditor(parameter);
        var value = ParameterSlider(parameter).Value;
        editor.Text = parameter == "rate" ? value.ToString("0.00", CultureInfo.CurrentCulture) : value.ToString("0.0", CultureInfo.CurrentCulture);
        ParameterText(parameter).Visibility = Visibility.Collapsed;
        editor.Visibility = Visibility.Visible;
        editor.BorderBrush = (Brush)FindResource("AccentBrightBrush");
        editor.SelectAll();
        editor.Focus();
    }

    private void ParameterEditor_PreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter) { CommitParameterEdit(); e.Handled = true; }
        else if (e.Key == Key.Escape) { CancelParameterEdit(); e.Handled = true; }
    }

    private void ParameterEditor_LostKeyboardFocus(object sender, KeyboardFocusChangedEventArgs e)
    {
        if (!_committingParameterEditor && _editingParameter != null) CommitParameterEdit();
    }

    private void CommitParameterEdit()
    {
        if (_editingParameter is not { } parameter || _committingParameterEditor) return;
        _committingParameterEditor = true;
        try
        {
            var editor = ParameterEditor(parameter);
            var normalized = editor.Text.Trim().Replace("x", "", StringComparison.OrdinalIgnoreCase)
                .Replace("st", "", StringComparison.OrdinalIgnoreCase).Replace("dB", "", StringComparison.OrdinalIgnoreCase).Trim();
            if (!double.TryParse(normalized, NumberStyles.Float, CultureInfo.CurrentCulture, out var value)
                && !double.TryParse(normalized, NumberStyles.Float, CultureInfo.InvariantCulture, out value))
            {
                System.Media.SystemSounds.Beep.Play();
                editor.SelectAll();
                editor.Focus();
                return;
            }
            SetParameterValue(parameter, value);
            EndParameterEdit(parameter);
        }
        finally { _committingParameterEditor = false; }
    }

    private void CancelParameterEdit()
    {
        if (_editingParameter is not { } parameter) return;
        EndParameterEdit(parameter);
    }

    private void EndParameterEdit(string parameter)
    {
        ParameterEditor(parameter).Visibility = Visibility.Collapsed;
        ParameterText(parameter).Visibility = Visibility.Visible;
        _editingParameter = null;
        AssetGrid.Focus();
    }

    private void SetParameterValue(string parameter, double value)
    {
        var slider = ParameterSlider(parameter);
        slider.Value = Math.Clamp(value, slider.Minimum, slider.Maximum);
    }

    private Slider ParameterSlider(string parameter) => parameter switch
    {
        "pitch" => PitchSlider,
        "rate" => RateSlider,
        "gain" => GainSlider,
        _ => throw new ArgumentOutOfRangeException(nameof(parameter))
    };

    private TextBlock ParameterText(string parameter) => parameter switch
    {
        "pitch" => PitchValue,
        "rate" => RateValue,
        "gain" => GainValue,
        _ => throw new ArgumentOutOfRangeException(nameof(parameter))
    };

    private TextBox ParameterEditor(string parameter) => parameter switch
    {
        "pitch" => PitchValueEditor,
        "rate" => RateValueEditor,
        "gain" => GainValueEditor,
        _ => throw new ArgumentOutOfRangeException(nameof(parameter))
    };

    private static string ParameterDisplayName(string parameter) => parameter switch
    {
        "pitch" => "Pitch",
        "rate" => "Rate",
        "gain" => "Gain",
        _ => parameter
    };

    private void Loop_Click(object sender, RoutedEventArgs e)
    {
        _loopSelection = !_loopSelection;
        LoopButton.Foreground = _loopSelection ? (Brush)FindResource("AccentBrightBrush") : (Brush)FindResource("MutedBrush");
        LoopButton.IsActive = _loopSelection;
        StatusText.Text = _loopSelection ? T("选区循环已开启", "Selection loop enabled") : T("选区循环已关闭", "Selection loop disabled");
    }

    private void ResetWaveform_Click(object sender, RoutedEventArgs e)
    {
        DetailWaveform.ClearSelection();
        DetailWaveform.ResetView();
        _selectionStartRatio = _selectionEndRatio = -1;
        CancelPreparedSelectionDrag();
        SelectionDragCapsule.Visibility = Visibility.Collapsed;
        if (_selected != null)
        {
            InTimeText.Text = "0.000";
            OutTimeText.Text = DurationTimeText.Text = FormatTimeCompact(_selected.DurationSeconds);
        }
    }

    private async void ChannelMode_Click(object sender, RoutedEventArgs e)
    {
        if (_selected == null || _selected.Channels < 2) return;
        _channelMode = (_channelMode + 1) % (_selected.Channels + 1);
        await ApplyChannelModeAsync();
    }

    private async Task ApplyChannelModeAsync()
    {
        if (_selected == null) return;
        var channels = CurrentAuditionChannels();
        UpdateChannelModePresentation();
        var cancellation = ReplaceCancellation(ref _previewCancellation);
        try { await _previewEngine.ReconfigureAsync(_reverseAudition, channels, cancellation.Token); }
        catch (OperationCanceledException) { return; }
        catch (Exception exception) { AppDiagnostics.Write("Channel audition reconfiguration failed.", exception); }
        finally { CompleteCancellation(ref _previewCancellation, cancellation); }
    }

    private int[] CurrentAuditionChannels() => _channelMode == 0 ? [] : [_channelMode - 1];

    private void UpdateChannelModePresentation()
    {
        if (_selected == null) return;
        var channels = CurrentAuditionChannels();
        DetailWaveform.AuditionChannels = channels;
        _previewEngine.SetAuditionChannels(channels);
        ChannelModeButton.Icon = _channelMode switch { 1 => "channel_left", 2 => "channel_right", _ => "channel_stereo" };
        ChannelModeButton.Foreground = _channelMode == 0
            ? (Brush)FindResource("MutedBrush")
            : (Brush)FindResource("AccentBrightBrush");
        ChannelModeButton.IsActive = _channelMode != 0;
        ChannelModeButton.ToolTip = _channelMode switch
        {
            1 => T("仅监听 CH 1 · 点击切换下一声道", "Audition CH 1 only · click for next channel"),
            2 => T("仅监听 CH 2 · 点击切换下一声道", "Audition CH 2 only · click for next channel"),
            > 2 => T($"仅监听 CH {_channelMode} · 点击切换下一声道", $"Audition CH {_channelMode} only · click for next channel"),
            _ => T("监听全部声道 · 点击切换 CH 1", "Audition all channels · click for CH 1")
        };
        StatusText.Text = _channelMode == 0
            ? T("监听全部声道", "Auditioning all channels")
            : T($"仅监听 CH {_channelMode}；大波形已同步", $"Auditioning CH {_channelMode} only; detail waveform synchronized");
    }

    private async void Reverse_Click(object sender, RoutedEventArgs e)
    {
        _reverseAudition = !_reverseAudition;
        ReverseButton.IsActive = _reverseAudition;
        ReverseButton.Foreground = _reverseAudition ? (Brush)FindResource("AccentBrightBrush") : (Brush)FindResource("MutedBrush");
        var cancellation = ReplaceCancellation(ref _previewCancellation);
        try { await _previewEngine.ReconfigureAsync(_reverseAudition, _channelMode == 0 ? [] : [_channelMode - 1], cancellation.Token); }
        catch (OperationCanceledException) { }
        catch (Exception exception) { StatusText.Text = exception.Message; AppDiagnostics.Write("Reverse audition failed.", exception); }
        finally { CompleteCancellation(ref _previewCancellation, cancellation); }
    }

    private async void PreservePitch_Click(object sender, RoutedEventArgs e)
    {
        _preservePitch = !_preservePitch;
        _previewEngine.PreservePitch = _preservePitch;
        PreservePitchButton.IsActive = _preservePitch;
        PreservePitchButton.Foreground = _preservePitch ? (Brush)FindResource("AccentBrightBrush") : (Brush)FindResource("MutedBrush");
        StatusText.Text = _preservePitch ? T("变速时保持音高", "Pitch is preserved while changing speed") : T("变速会同步改变音高", "Pitch follows playback speed");
        if (_previewEngine.IsOpen)
        {
            var cancellation = ReplaceCancellation(ref _previewCancellation);
            try { await _previewEngine.ReconfigureAsync(_reverseAudition, _channelMode == 0 ? [] : [_channelMode - 1], cancellation.Token); }
            catch (OperationCanceledException) { }
            catch (Exception exception) { AppDiagnostics.Write("Preserve-pitch pipeline rebuild failed.", exception); }
            finally { CompleteCancellation(ref _previewCancellation, cancellation); }
        }
    }

    private void LoudnessMatch_Click(object sender, RoutedEventArgs e)
    {
        _preferences.LoudnessMatchAudition = !_preferences.LoudnessMatchAudition;
        LoudnessMatchButton.IsActive = _preferences.LoudnessMatchAudition;
        LoudnessMatchButton.Foreground = _preferences.LoudnessMatchAudition
            ? (Brush)FindResource("AccentBrightBrush") : (Brush)FindResource("MutedBrush");
        ConfigurePreviewParameters();
        _preferencesStore.Save(_preferences);
        StatusText.Text = _preferences.LoudnessMatchAudition
            ? T($"响度匹配已开启（目标 {_preferences.LoudnessMatchTarget:0.#} LUFS）", $"Loudness matching enabled (target {_preferences.LoudnessMatchTarget:0.#} LUFS)")
            : T("响度匹配已关闭", "Loudness matching disabled");
        if (_preferences.LoudnessMatchAudition && _currentLoudness == null && _selected != null)
            _ = AnalyzeLoudnessAsync(_selected, true);
    }

    private static string FormatTime(double seconds) => TimeSpan.FromSeconds(Math.Max(0, seconds)).ToString(seconds >= 3600 ? @"hh\:mm\:ss\.fff" : @"mm\:ss\.fff");
    private static string FormatTimeCompact(double seconds) => Math.Max(0, seconds).ToString("0.000");

    private static CancellationTokenSource ReplaceCancellation(ref CancellationTokenSource? source)
    {
        CancelCancellation(ref source);
        source = new CancellationTokenSource();
        return source;
    }

    private static void CancelCancellation(ref CancellationTokenSource? source)
    {
        var previous = source;
        source = null;
        if (previous == null) return;
        try { previous.Cancel(); }
        catch (ObjectDisposedException) { }
        // The asynchronous operation that owns this source disposes it in its
        // own finally block. Disposing here races with token registrations that
        // are still unwinding when the user changes selection rapidly.
    }

    private static void CompleteCancellation(ref CancellationTokenSource? source, CancellationTokenSource completed)
    {
        if (ReferenceEquals(source, completed)) source = null;
        completed.Dispose();
    }

    private AudioAsset[] SelectedAssets() => AssetGrid.SelectedItems.Cast<AudioAsset>().ToArray();

    private void LoadMetadataEditor(IReadOnlyList<AudioAsset> selectedAssets)
    {
        static string Common(IReadOnlyList<AudioAsset> items, Func<AudioAsset, string> selector)
        {
            if (items.Count == 0) return "";
            var value = selector(items[0]) ?? "";
            return items.Skip(1).All(item => string.Equals(value, selector(item) ?? "", StringComparison.Ordinal)) ? value : "";
        }

        void Set(TextBox box, string key, Func<AudioAsset, string> selector)
        {
            var value = Common(selectedAssets, selector);
            _metadataBaseline[key] = value;
            box.Text = value;
            box.ToolTip = selectedAssets.Count > 1 && selectedAssets.Any(item => !string.Equals(value, selector(item), StringComparison.Ordinal))
                ? "所选素材包含多个不同值；输入新内容后将批量替换，保持空白则不修改。"
                : null;
        }

        Set(InspectorDescription, "description", item => item.Description);
        Set(InspectorKeywords, "keywords", item => item.Keywords);
        Set(InspectorCategory, "category", item => item.Category);
        Set(InspectorSubcategory, "subcategory", item => item.Subcategory);
        Set(InspectorCatId, "catid", item => item.CatId);
        SaveMetadataButton.Content = selectedAssets.Count > 1 ? $"批量保存元数据（{selectedAssets.Count}）" : "保存元数据";
    }

    private void UpdateWorkflowControls(IReadOnlyList<AudioAsset> selectedAssets)
    {
        var commonStatus = selectedAssets.Count > 0 && selectedAssets.All(item => item.WorkflowStatus == selectedAssets[0].WorkflowStatus)
            ? selectedAssets[0].WorkflowStatus : "";
        foreach (var button in new[] { StatusNoneButton, StatusCandidateButton, StatusApprovedButton, StatusRejectedButton })
        {
            var active = string.Equals(button.Tag as string, commonStatus, StringComparison.OrdinalIgnoreCase);
            button.Background = active ? (Brush)FindResource("AccentBrush") : (Brush)FindResource("PanelRaisedBrush");
            button.BorderBrush = active ? (Brush)FindResource("AccentBrightBrush") : (Brush)FindResource("LineBrush");
        }
        var allMarked = selectedAssets.Count > 0 && selectedAssets.All(item => item.Marked);
        MarkButton.Content = allMarked ? "取消标记 · M" : "标记素材 · M";
        MarkButton.Background = allMarked ? (Brush)FindResource("AccentBrush") : (Brush)FindResource("PanelRaisedBrush");
    }

    private async void WorkflowStatus_Click(object sender, RoutedEventArgs e)
    {
        var status = (sender as FrameworkElement)?.Tag as string;
        if (string.IsNullOrWhiteSpace(status)) return;
        var selectedAssets = SelectedAssets();
        if (selectedAssets.Length == 0) return;
        foreach (var asset in selectedAssets) asset.WorkflowStatus = status;
        await SaveAssetDetailsAsync(selectedAssets, $"已更新 {selectedAssets.Length:N0} 个素材的工作流状态");
        UpdateWorkflowControls(selectedAssets);
        RefreshView();
    }

    private async void Mark_Click(object sender, RoutedEventArgs e)
    {
        var selectedAssets = SelectedAssets();
        if (selectedAssets.Length == 0) return;
        var newValue = !selectedAssets.All(item => item.Marked);
        foreach (var asset in selectedAssets) asset.Marked = newValue;
        await SaveAssetDetailsAsync(selectedAssets, newValue
            ? $"已标记 {selectedAssets.Length:N0} 个素材"
            : $"已取消标记 {selectedAssets.Length:N0} 个素材");
        UpdateWorkflowControls(selectedAssets);
    }

    private async void SaveMetadata_Click(object sender, RoutedEventArgs e)
    {
        var selectedAssets = SelectedAssets();
        if (selectedAssets.Length == 0) return;
        PushMetadataUndo(selectedAssets);
        var changes = 0;
        changes += ApplyMetadataChange(selectedAssets, "description", InspectorDescription.Text, (asset, value) => asset.Description = value);
        changes += ApplyMetadataChange(selectedAssets, "keywords", InspectorKeywords.Text, (asset, value) => asset.Keywords = value);
        changes += ApplyMetadataChange(selectedAssets, "category", InspectorCategory.Text, (asset, value) => asset.Category = value);
        changes += ApplyMetadataChange(selectedAssets, "subcategory", InspectorSubcategory.Text, (asset, value) => asset.Subcategory = value);
        changes += ApplyMetadataChange(selectedAssets, "catid", InspectorCatId.Text, (asset, value) => asset.CatId = value);
        if (changes == 0)
        {
            StatusText.Text = "元数据没有变化";
            return;
        }
        await SaveAssetDetailsAsync(selectedAssets, $"已保存 {selectedAssets.Length:N0} 个素材的元数据");
        LoadMetadataEditor(selectedAssets);
        RefreshView();
    }

    private void PushMetadataUndo(IEnumerable<AudioAsset> assets)
    {
        _metadataUndo.Push(assets.Select(asset => new MetadataSnapshot(asset.FilePath, asset.Description, asset.Keywords,
            asset.Category, asset.Subcategory, asset.CatId, asset.WorkflowStatus, asset.Marked)).ToArray());
        while (_metadataUndo.Count > 20)
        {
            var keep = _metadataUndo.Reverse().Take(20).Reverse().ToArray();
            _metadataUndo.Clear(); foreach (var item in keep) _metadataUndo.Push(item);
        }
    }

    private async void UndoMetadata_Click(object sender, RoutedEventArgs e)
    {
        if (_metadataUndo.Count == 0) { StatusText.Text = "没有可撤销的元数据修改"; return; }
        var snapshots = _metadataUndo.Pop();
        var byPath = _assets.ToDictionary(asset => asset.FilePath, StringComparer.OrdinalIgnoreCase);
        var changed = new List<AudioAsset>();
        foreach (var snapshot in snapshots)
        {
            if (!byPath.TryGetValue(snapshot.Path, out var asset)) continue;
            asset.Description = snapshot.Description; asset.Keywords = snapshot.Keywords; asset.Category = snapshot.Category;
            asset.Subcategory = snapshot.Subcategory; asset.CatId = snapshot.CatId; asset.WorkflowStatus = snapshot.WorkflowStatus; asset.Marked = snapshot.Marked;
            changed.Add(asset);
        }
        await SaveAssetDetailsAsync(changed, $"已撤销 {changed.Count:N0} 个素材的元数据修改");
        LoadMetadataEditor(SelectedAssets()); RefreshView();
    }

    private async void ParseUcs_Click(object sender, RoutedEventArgs e)
    {
        var assets = SelectedAssets(); if (assets.Length == 0) return;
        PushMetadataUndo(assets);
        foreach (var asset in assets)
        {
            var stem = Path.GetFileNameWithoutExtension(asset.FileName);
            var prefix = stem.Split('_', '-', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault() ?? "";
            var match = Regex.Match(prefix, "^(?<cat>[A-Z]{2,6})(?<sub>[A-Za-z]{2,16})$");
            if (match.Success)
            {
                asset.CatId = prefix; asset.Category = match.Groups["cat"].Value; asset.Subcategory = match.Groups["sub"].Value;
            }
            else
            {
                var parts = stem.Split('_', '-', StringSplitOptions.RemoveEmptyEntries);
                if (parts.Length > 0) asset.Category = parts[0];
                if (parts.Length > 1) asset.Subcategory = parts[1];
            }
        }
        await SaveAssetDetailsAsync(assets, $"已从文件名解析 {assets.Length:N0} 个素材");
        LoadMetadataEditor(assets); RebuildFacets(); RefreshView();
    }

    private void ExportCsv_Click(object sender, RoutedEventArgs e)
    {
        var assets = SelectedAssets();
        if (assets.Length == 0) assets = _view.Cast<AudioAsset>().ToArray();
        if (assets.Length == 0) return;
        var dialog = new SaveFileDialog { Title = "导出 PsyReaSFX 元数据", Filter = "CSV 文件|*.csv", FileName = "PsyReaSFX_metadata.csv" };
        if (dialog.ShowDialog(this) != true) return;
        var lines = new List<string> { "Path,FileName,Description,Keywords,CatID,Category,SubCategory,Library,Status,Marked" };
        lines.AddRange(assets.Select(asset => string.Join(',', new[] { asset.FilePath, asset.FileName, asset.Description, asset.Keywords,
            asset.CatId, asset.Category, asset.Subcategory, asset.LibraryName, asset.WorkflowStatus, asset.Marked ? "true" : "false" }.Select(CsvEscape))));
        File.WriteAllLines(dialog.FileName, lines, new UTF8Encoding(true));
        StatusText.Text = $"已导出 {assets.Length:N0} 条元数据";
    }

    private async void ImportCsv_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog { Title = "导入 PsyReaSFX 元数据", Filter = "CSV 文件|*.csv", CheckFileExists = true };
        if (dialog.ShowDialog(this) != true) return;
        try
        {
            var rows = File.ReadLines(dialog.FileName).Select(ParseCsvLine).ToArray();
            if (rows.Length < 2) return;
            var header = rows[0].Select((value, index) => (value, index)).ToDictionary(item => item.value, item => item.index, StringComparer.OrdinalIgnoreCase);
            var byPath = _assets.ToDictionary(asset => asset.FilePath, StringComparer.OrdinalIgnoreCase);
            var changed = new List<AudioAsset>();
            var targetPaths = rows.Skip(1).Select(row => header.TryGetValue("Path", out var index) && index < row.Length ? row[index] : "")
                .Where(path => byPath.ContainsKey(path)).Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
            PushMetadataUndo(targetPaths.Select(path => byPath[path]));
            foreach (var row in rows.Skip(1))
            {
                string Get(string key) => header.TryGetValue(key, out var index) && index < row.Length ? row[index] : "";
                if (!byPath.TryGetValue(Get("Path"), out var asset)) continue;
                changed.Add(asset); asset.Description = Get("Description"); asset.Keywords = Get("Keywords"); asset.CatId = Get("CatID");
                asset.Category = Get("Category"); asset.Subcategory = Get("SubCategory");
                if (Get("Status").Length > 0) asset.WorkflowStatus = Get("Status");
                if (bool.TryParse(Get("Marked"), out var marked)) asset.Marked = marked;
            }
            await SaveAssetDetailsAsync(changed, $"已导入 {changed.Count:N0} 条元数据");
            RebuildFacets(); LoadMetadataEditor(SelectedAssets()); RefreshView();
        }
        catch (Exception exception) { AppDiagnostics.Write("CSV import failed.", exception); MessageBox.Show(exception.Message, "CSV 导入失败"); }
    }

    private static string CsvEscape(string? value)
    {
        value ??= "";
        return value.IndexOfAny([',', '"', '\r', '\n']) >= 0 ? $"\"{value.Replace("\"", "\"\"")}\"" : value;
    }

    private static string[] ParseCsvLine(string line)
    {
        var values = new List<string>(); var value = new StringBuilder(); var quoted = false;
        for (var index = 0; index < line.Length; index++)
        {
            var character = line[index];
            if (character == '"')
            {
                if (quoted && index + 1 < line.Length && line[index + 1] == '"') { value.Append('"'); index++; }
                else quoted = !quoted;
            }
            else if (character == ',' && !quoted) { values.Add(value.ToString()); value.Clear(); }
            else value.Append(character);
        }
        values.Add(value.ToString()); return values.ToArray();
    }

    private int ApplyMetadataChange(IEnumerable<AudioAsset> selectedAssets, string key, string value, Action<AudioAsset, string> apply)
    {
        value ??= "";
        if (_metadataBaseline.TryGetValue(key, out var baseline) && string.Equals(value, baseline, StringComparison.Ordinal)) return 0;
        foreach (var asset in selectedAssets) apply(asset, value);
        _metadataBaseline[key] = value;
        return 1;
    }

    private async Task SaveAssetDetailsAsync(IEnumerable<AudioAsset> assets, string successMessage)
    {
        var rows = assets.DistinctBy(asset => asset.FilePath, StringComparer.OrdinalIgnoreCase).ToArray();
        try
        {
            await _store.SaveAssetDetailsAsync(rows);
            StatusText.Text = successMessage;
        }
        catch (Exception exception)
        {
            StatusText.Text = "保存素材信息失败；关闭软件前请勿继续修改";
            AppDiagnostics.Write("Asset details could not be saved.", exception);
        }
    }

    private void Favorite_Click(object sender, RoutedEventArgs e)
    {
        if (_selected == null) return;
        _selected.IsFavorite = !_selected.IsFavorite;
        if (_selected.IsFavorite) _state.Favorites.Add(_selected.FilePath); else _state.Favorites.Remove(_selected.FilePath);
        _store.SaveWorkspace(_state); RebuildLibraryTree(); RefreshView();
    }

    private void Reveal_Click(object sender, RoutedEventArgs e)
    {
        if (_selected == null || !File.Exists(_selected.FilePath)) return;
        Process.Start(new ProcessStartInfo("explorer.exe", $"/select,\"{_selected.FilePath}\"") { UseShellExecute = true });
    }

    private static void OpenFolder(string path)
    {
        try
        {
            if (Directory.Exists(path)) Process.Start(new ProcessStartInfo("explorer.exe", path) { UseShellExecute = true });
        }
        catch (Exception exception) { AppDiagnostics.Write($"Could not open directory: {path}", exception); }
    }

    private void OpenData_Click(object sender, RoutedEventArgs e)
    {
        Directory.CreateDirectory(_store.DataDirectory);
        Process.Start(new ProcessStartInfo("explorer.exe", _store.DataDirectory) { UseShellExecute = true });
    }

    private void Settings_Click(object sender, RoutedEventArgs e)
    {
        var previousCacheDirectory = LuaWaveCache.CacheDirectory;
        var window = new SettingsWindow(_preferences, _store.DataDirectory, _reliability, _store.DatabasePath) { Owner = this };
        if (window.ShowDialog() != true) return;
        _preferences = window.Preferences;
        LuaWaveCache.Configure(_preferences.WaveformCacheDirectory);
        if (!previousCacheDirectory.Equals(LuaWaveCache.CacheDirectory, StringComparison.OrdinalIgnoreCase))
        {
            WaveformControl.ClearMemoryCache();
            if (_selected != null)
            {
                var selectedPath = _selected.FilePath;
                DetailWaveform.FilePath = "";
                DetailWaveform.FilePath = selectedPath;
                UpdateChannelModePresentation();
            }
        }
        _preferencesStore.Save(_preferences);
        ApplyPreferences(_preferences, true);
        ConfigureWatchFolders();
        RebuildFacets();
        RefreshView();
        StatusText.Text = T("设置已保存", "Settings saved");
        if (window.RetryFailedRequested) _ = RescanAsync(false);
    }

    private void Transfer_Click(object sender, RoutedEventArgs e)
    {
        var selected = SelectedAssets();
        var window = new TransferWindow(_preferences, _selected, selected,
            _selectionStartRatio, _selectionEndRatio, _pitchSemitones, _playbackRate,
            _gainDb, _reverseAudition, _preservePitch) { Owner = this };
        window.ShowDialog();
        ApplyPreferences(_preferences, false);
    }

    private void ApplyPreferences(DesktopPreferences preferences, bool refreshWaveforms)
    {
        ThemeManager.Apply(preferences);
        _autoPreview = preferences.AutoPreview;
        _pitchSemitones = preferences.AuditionPitchSemitones;
        _playbackRate = preferences.AuditionRate;
        _gainDb = preferences.AuditionGainDb;
        _preservePitch = preferences.PreservePitch;
        _reverseAudition = preferences.ReverseAudition;
        _loopSelection = preferences.LoopSelection;
        _spaceRestartsSelection = preferences.SpaceKeyBehavior.Equals("restart_selection", StringComparison.OrdinalIgnoreCase);
        if (PitchSlider != null) PitchSlider.Value = _pitchSemitones;
        if (RateSlider != null) RateSlider.Value = _playbackRate;
        if (GainSlider != null) GainSlider.Value = _gainDb;
        if (PreservePitchButton != null)
        {
            PreservePitchButton.IsActive = _preservePitch;
            PreservePitchButton.Foreground = _preservePitch ? (Brush)FindResource("AccentBrightBrush") : (Brush)FindResource("MutedBrush");
        }
        if (ReverseButton != null) ReverseButton.IsActive = _reverseAudition;
        if (LoopButton != null) LoopButton.IsActive = _loopSelection;
        if (LoudnessMatchButton != null)
        {
            LoudnessMatchButton.IsActive = preferences.LoudnessMatchAudition;
            LoudnessMatchButton.Foreground = preferences.LoudnessMatchAudition
                ? (Brush)FindResource("AccentBrightBrush") : (Brush)FindResource("MutedBrush");
        }
        ConfigurePreviewParameters();
        InlineWaveformResolution = preferences.InlineWaveformResolution is 256 or 512
            ? preferences.InlineWaveformResolution : 512;
        DetailWaveform.Resolution = preferences.DetailWaveformResolution is 2048 or 4096
            ? preferences.DetailWaveformResolution : 4096;
        AutoPreviewButton.Foreground = _autoPreview
            ? (Brush)FindResource("AccentBrightBrush")
            : (Brush)FindResource("MutedBrush");
        AutoPreviewButton.IsActive = _autoPreview;
        ApplyResultColumnPreferences();
        ApplySidebarSectionPreferences();
        SetNavigationVisible(preferences.NavigationVisible);
        SetInspectorVisible(preferences.InspectorVisible);
        UiLocalization.Apply(this, preferences.Language);
        foreach (var asset in _assets) asset.UiLanguage = preferences.Language;
        if (_view != null) ApplySort();
        if (refreshWaveforms && _selected != null) DetailWaveform.FilePath = _selected.FilePath;
    }

    private void ApplyResultColumnPreferences()
    {
        foreach (var column in AssetGrid.Columns)
        {
            var key = column.Header?.ToString();
            if (string.IsNullOrWhiteSpace(key)) continue;
            if (_preferences.ResultColumnVisibility.TryGetValue(key, out var visible))
                column.Visibility = visible ? Visibility.Visible : Visibility.Collapsed;
            if (_preferences.ResultColumnWidths.TryGetValue(key, out var width) && width >= column.MinWidth && width <= 1800)
                column.Width = new DataGridLength(width, DataGridLengthUnitType.Pixel);
        }
    }

    private void SaveResultColumnPreferences()
    {
        foreach (var column in AssetGrid.Columns)
        {
            var key = column.Header?.ToString();
            if (string.IsNullOrWhiteSpace(key)) continue;
            _preferences.ResultColumnVisibility[key] = column.Visibility == Visibility.Visible;
            var width = column.ActualWidth;
            if (double.IsFinite(width) && width >= column.MinWidth)
                _preferences.ResultColumnWidths[key] = width;
        }
        try { _preferencesStore.Save(_preferences); }
        catch (Exception exception) { AppDiagnostics.Write("Result column preferences could not be saved.", exception); }
    }

    private void ApplySidebarSectionPreferences()
    {
        var sections = new (string Key, Expander Control)[]
        {
            ("sounds", SoundsSection), ("libraries", LibrariesSection),
            ("collections", CollectionsSection), ("saved_searches", SavedSearchesSection),
            ("facets", FacetsSection), ("workflow", WorkflowSection), ("activity", ActivitySection)
        };
        foreach (var (key, control) in sections)
            if (_preferences.SidebarSectionExpanded.TryGetValue(key, out var expanded)) control.IsExpanded = expanded;
    }

    private void SaveSidebarSectionPreferences()
    {
        _preferences.SidebarSectionExpanded["sounds"] = SoundsSection.IsExpanded;
        _preferences.SidebarSectionExpanded["libraries"] = LibrariesSection.IsExpanded;
        _preferences.SidebarSectionExpanded["collections"] = CollectionsSection.IsExpanded;
        _preferences.SidebarSectionExpanded["saved_searches"] = SavedSearchesSection.IsExpanded;
        _preferences.SidebarSectionExpanded["facets"] = FacetsSection.IsExpanded;
        _preferences.SidebarSectionExpanded["workflow"] = WorkflowSection.IsExpanded;
        _preferences.SidebarSectionExpanded["activity"] = ActivitySection.IsExpanded;
    }

    private static void ApplyArtworkFallbacks(PersistedState state)
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
            if (source == null && !string.IsNullOrWhiteSpace(asset.SourcePath)) sourcesByPath.TryGetValue(asset.SourcePath, out source);
            if (source != null && !string.IsNullOrWhiteSpace(source.ArtworkPath) && File.Exists(source.ArtworkPath))
                asset.ArtworkPath = source.ArtworkPath;
        }
    }

    private async Task ResolveMissingSourceArtworkAsync()
    {
        try
        {
            var missing = _state.Libraries.SelectMany(library => library.Sources)
                .Where(source => Directory.Exists(source.Path) && (string.IsNullOrWhiteSpace(source.ArtworkPath) || !File.Exists(source.ArtworkPath)))
                .ToList();
            var changed = false;
            foreach (var source in missing)
            {
                var artwork = await Task.Run(() => ArtworkFinder.FindForSource(source.Path));
                if (string.IsNullOrWhiteSpace(artwork)) continue;
                ApplySourceArtwork(source, artwork);
                changed = true;
                await Dispatcher.Yield(DispatcherPriority.Background);
            }
            if (changed)
            {
                _state.Index = _assets.ToList();
                await Task.Run(() => _store.Save(_state));
                StatusText.Text = "已补全可识别的音效库封面";
            }
        }
        catch (Exception exception) { AppDiagnostics.Write("Background artwork discovery failed.", exception); }
    }

    private void ApplySourceArtwork(LibrarySource source, string artwork)
    {
        source.ArtworkPath = artwork;
        source.ArtworkChecked = true;
        foreach (var asset in _assets.Where(asset => asset.RootId.Equals(source.Id, StringComparison.OrdinalIgnoreCase)
                                                     || asset.SourcePath.Equals(source.Path, StringComparison.OrdinalIgnoreCase)))
            asset.ArtworkPath = artwork;
        if (_selected != null && (_selected.RootId.Equals(source.Id, StringComparison.OrdinalIgnoreCase)
                                  || _selected.SourcePath.Equals(source.Path, StringComparison.OrdinalIgnoreCase)))
        {
            ArtworkImage.FilePath = artwork;
            ArtworkPlaceholder.Visibility = Visibility.Collapsed;
        }
    }

    private async Task DetectArtworkForSourceAsync(LibrarySource source, bool announce)
    {
        var artwork = await Task.Run(() => ArtworkFinder.FindForSource(source.Path));
        if (string.IsNullOrWhiteSpace(artwork))
        {
            if (announce) MessageBox.Show("没有在该实体路径或其 Artwork/Cover 子目录中找到合适图片。", "PsyReaSFX Desktop");
            return;
        }
        ApplySourceArtwork(source, artwork);
        _state.Index = _assets.ToList();
        await Task.Run(() => _store.Save(_state));
        if (announce) StatusText.Text = $"已应用封面：{Path.GetFileName(artwork)}";
    }

    private void ChooseArtworkForSource(LibraryDefinition library, LibrarySource source)
    {
        var dialog = new OpenFileDialog
        {
            Title = $"为 {library.Name} / {source.DisplayName} 指定封面",
            Filter = "图片文件|*.png;*.jpg;*.jpeg;*.webp|所有文件|*.*",
            CheckFileExists = true
        };
        if (dialog.ShowDialog(this) != true) return;
        ApplySourceArtwork(source, dialog.FileName);
        _state.Index = _assets.ToList();
        _ = Task.Run(() => _store.Save(_state));
    }

    private void ChooseArtwork_Click(object sender, RoutedEventArgs e)
    {
        if (_selected == null) return;
        var library = _state.Libraries.FirstOrDefault(item => item.Id.Equals(_selected.LibraryId, StringComparison.OrdinalIgnoreCase));
        var source = library?.Sources.FirstOrDefault(item => item.Id.Equals(_selected.RootId, StringComparison.OrdinalIgnoreCase)
                                                            || item.Path.Equals(_selected.SourcePath, StringComparison.OrdinalIgnoreCase));
        if (library != null && source != null) ChooseArtworkForSource(library, source);
    }

    private async void AutoArtwork_Click(object sender, RoutedEventArgs e)
    {
        if (_selected == null) return;
        var source = _state.Libraries.SelectMany(library => library.Sources)
            .FirstOrDefault(item => item.Id.Equals(_selected.RootId, StringComparison.OrdinalIgnoreCase)
                                    || item.Path.Equals(_selected.SourcePath, StringComparison.OrdinalIgnoreCase));
        if (source != null) await DetectArtworkForSourceAsync(source, true);
    }

    private void Help_Click(object sender, RoutedEventArgs e)
    {
        if (_helpWindow is { IsLoaded: true })
        {
            if (_helpWindow.WindowState == WindowState.Minimized) _helpWindow.WindowState = WindowState.Normal;
            _helpWindow.Activate();
            return;
        }

        _helpWindow = new HelpWindow(_preferences.Language) { Owner = this };
        _helpWindow.Closed += (_, _) => _helpWindow = null;
        _helpWindow.Show();
    }

    private void MoreActions_Click(object sender, RoutedEventArgs e)
    {
        var menu = new ContextMenu();
        var reveal = new MenuItem { Header = T("在资源管理器中显示", "Show in File Explorer") }; reveal.Click += Reveal_Click;
        var favorite = new MenuItem { Header = _selected?.IsFavorite == true ? T("取消收藏", "Remove favorite") : T("收藏", "Favorite") }; favorite.Click += Favorite_Click;
        var saveRegion = new MenuItem { Header = T("保存当前选区为 Region…", "Save selection as Region…"), IsEnabled = HasValidSelection() };
        saveRegion.Click += async (_, _) => await SaveCurrentRegionAsync();
        var deleteRegion = new MenuItem { Header = T("删除当前 Region", "Delete current Region"), IsEnabled = RegionSelector.SelectedItem is RegionRecord };
        deleteRegion.Click += async (_, _) => await DeleteCurrentRegionAsync();
        var detectTransients = new MenuItem { Header = T("检测瞬态 Region…", "Detect transient Regions…"), IsEnabled = _selected != null };
        detectTransients.Click += async (_, _) => await DetectTransientsAsync();
        var undoTransients = new MenuItem { Header = T("撤销上次瞬态检测", "Undo last transient detection"), IsEnabled = _previewRegions.Any(item => item.Source == "transient") };
        undoTransients.Click += async (_, _) => await UndoLastTransientDetectionAsync();
        var clearTransients = new MenuItem { Header = T("清除全部瞬态建议", "Clear all transient suggestions"), IsEnabled = _previewRegions.Any(item => item.Source == "transient") };
        clearTransients.Click += async (_, _) => await ClearTransientSuggestionsAsync();
        var reanalyzeLoudness = new MenuItem { Header = T("重新分析当前素材响度", "Reanalyze current loudness"), IsEnabled = _selected != null };
        reanalyzeLoudness.Click += async (_, _) => { if (_selected != null) await AnalyzeLoudnessAsync(_selected, true); };
        var clearPlayed = new MenuItem { Header = T("清除本次试听高亮", "Clear current audition highlights") };
        clearPlayed.Click += ClearSessionPlayed_Click;
        var data = new MenuItem { Header = T("打开 PsyReaSFX 数据目录", "Open PsyReaSFX data directory") }; data.Click += OpenData_Click;
        menu.Items.Add(reveal); menu.Items.Add(favorite); menu.Items.Add(new Separator());
        menu.Items.Add(saveRegion); menu.Items.Add(deleteRegion); menu.Items.Add(detectTransients); menu.Items.Add(undoTransients); menu.Items.Add(clearTransients);
        menu.Items.Add(reanalyzeLoudness); menu.Items.Add(new Separator());
        menu.Items.Add(clearPlayed); menu.Items.Add(data);
        menu.PlacementTarget = sender as FrameworkElement; menu.IsOpen = true;
    }

    private void AutoPreview_Click(object sender, RoutedEventArgs e)
    {
        _autoPreview = !_autoPreview;
        _preferences.AutoPreview = _autoPreview;
        _preferencesStore.Save(_preferences);
        AutoPreviewButton.Foreground = _autoPreview ? (Brush)FindResource("AccentBrightBrush") : (Brush)FindResource("MutedBrush");
        AutoPreviewButton.IsActive = _autoPreview;
        StatusText.Text = _autoPreview ? T("自动试听已开启", "Auto preview enabled") : T("自动试听已关闭", "Auto preview disabled");
    }

    private void NavigationToggle_Click(object sender, RoutedEventArgs e) => SetNavigationVisible(!_navigationVisible);
    private void InspectorToggle_Click(object sender, RoutedEventArgs e) => SetInspectorVisible(!_inspectorVisible);
    private void FocusToggle_Click(object sender, RoutedEventArgs e)
    {
        _focusMode = !_focusMode;
        if (_focusMode) { SetNavigationVisible(false); SetInspectorVisible(false); }
        else { SetNavigationVisible(true); SetInspectorVisible(true); }
        FocusToggle.Foreground = _focusMode ? (Brush)FindResource("AccentBrightBrush") : (Brush)FindResource("TextBrush");
        FocusToggle.IsActive = _focusMode;
    }

    private void SetNavigationVisible(bool visible)
    {
        if (_navigationVisible && NavigationColumn.Width.Value > 0) _navigationWidth = NavigationColumn.Width;
        _navigationVisible = visible; NavigationPanel.Visibility = NavigationSplitter.Visibility = visible ? Visibility.Visible : Visibility.Collapsed;
        NavigationColumn.MinWidth = visible ? 190 : 0;
        NavigationColumn.Width = visible ? _navigationWidth : new GridLength(0); NavigationSplitterColumn.Width = visible ? new GridLength(5) : new GridLength(0);
        NavigationToggle.IsActive = visible;
    }

    private void SetInspectorVisible(bool visible)
    {
        if (_inspectorVisible && InspectorColumn.Width.Value > 0) _inspectorWidth = InspectorColumn.Width;
        _inspectorVisible = visible; InspectorPanel.Visibility = InspectorSplitter.Visibility = visible ? Visibility.Visible : Visibility.Collapsed;
        InspectorColumn.MinWidth = visible ? 230 : 0;
        InspectorColumn.Width = visible ? _inspectorWidth : new GridLength(0); InspectorSplitterColumn.Width = visible ? new GridLength(5) : new GridLength(0);
        InspectorToggle.IsActive = visible;
    }

    private void Window_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.T && Keyboard.Modifiers == ModifierKeys.Control)
        {
            Transfer_Click(sender, e);
            e.Handled = true;
            return;
        }
        if (_editingParameter != null || Keyboard.FocusedElement is TextBox or ComboBox) return;
        if (e.Key == Key.Space && !SearchBox.IsKeyboardFocusWithin) { _ = HandleSpaceKeyAsync(); e.Handled = true; }
        else if (e.Key == Key.Escape) { Stop_Click(sender, e); e.Handled = true; }
        else if (e.Key == Key.F9) { NavigationToggle_Click(sender, e); e.Handled = true; }
        else if (e.Key == Key.F10) { InspectorToggle_Click(sender, e); e.Handled = true; }
        else if (e.Key == Key.F11) { FocusToggle_Click(sender, e); e.Handled = true; }
        else if (e.Key == Key.F && Keyboard.Modifiers == ModifierKeys.Control) { SearchBox.Focus(); SearchBox.SelectAll(); e.Handled = true; }
        else if (e.Key == Key.R && Keyboard.Modifiers == ModifierKeys.Control) { Rescan_Click(sender, e); e.Handled = true; }
        else if (e.Key == Key.F && !SearchBox.IsKeyboardFocusWithin) { Favorite_Click(sender, e); e.Handled = true; }
        else if (e.Key == Key.M && !SearchBox.IsKeyboardFocusWithin) { Mark_Click(sender, e); e.Handled = true; }
    }

    private async Task HandleSpaceKeyAsync()
    {
        if (_selected == null) return;
        if (!_spaceRestartsSelection)
        {
            Play_Click(this, new RoutedEventArgs());
            return;
        }

        if (_isPlaying)
        {
            await _previewEngine.StopAsync();
            _isPlaying = false;
            PlayButton.Icon = "play";
        }
        StartPreview(HasValidSelection() ? _selectionStartRatio : 0);
    }

    private void UpdateCount()
    {
        var shown = _visibleCount;
        CountText.Text = UiLocalization.IsEnglish(_preferences.Language) ? $"{shown:N0} results" : $"{shown:N0} 个结果";
        ActivityText.Text = UiLocalization.IsEnglish(_preferences.Language)
            ? $"Results {shown:N0}\nSelected {AssetGrid?.SelectedItems.Count ?? 0:N0}\nIndexed {_assets.Count:N0}\nPreview Desktop"
            : $"结果 {shown:N0}\n已选 {AssetGrid?.SelectedItems.Count ?? 0:N0}\n索引 {_assets.Count:N0}\n试听 Desktop";
        AllSoundsCount.Text = _assets.Count.ToString("N0"); FavoritesCount.Text = _state.Favorites.Count.ToString("N0");
        PreviewHistoryCount.Text = _assets.Count(asset => asset.PreviewCount > 0).ToString("N0");
    }

    private void Window_Closing(object? sender, CancelEventArgs e)
    {
        CompositionTarget.Rendering -= PlaybackRendering;
        CancelPreparedSelectionDrag();
        CancelCancellation(ref _analysisCancellation);
        CancelCancellation(ref _selectionDragPreparation);
        CancelCancellation(ref _previewCancellation);
        _scanCancellation?.Cancel(); _watchFolders.Dispose(); _autoPreviewTimer.Stop(); _activitySaveTimer.Stop(); _timer.Stop(); _previewEngine.Dispose();
        _preferences.NavigationVisible = _navigationVisible;
        _preferences.InspectorVisible = _inspectorVisible;
        _preferences.AutoPreview = _autoPreview;
        _preferences.AuditionPitchSemitones = _pitchSemitones;
        _preferences.AuditionRate = _playbackRate;
        _preferences.AuditionGainDb = _gainDb;
        _preferences.PreservePitch = _preservePitch;
        _preferences.ReverseAudition = _reverseAudition;
        _preferences.LoopSelection = _loopSelection;
        SaveSidebarSectionPreferences();
        SaveResultColumnPreferences();
        try { _preferencesStore.Save(_preferences); }
        catch (Exception exception) { AppDiagnostics.Write("Desktop preferences could not be saved.", exception); }
        if (_initialized)
        {
            _state.Index = _assets.ToList();
            try
            {
                if (!_skipSessionSnapshotSave)
                {
                    _savedSessionPlayed = _assets.Where(asset => asset.IsSessionPlayed).Select(asset => asset.FilePath)
                        .ToHashSet(StringComparer.OrdinalIgnoreCase);
                    _store.SaveSessionPlayed(_savedSessionPlayed);
                }
                _store.SaveWorkspace(_state);
                if (_activityDirty.Count > 0)
                    _store.SaveActivities(_assets.Where(asset => _activityDirty.Contains(asset.FilePath)));
            }
            catch (Exception exception) { AppDiagnostics.Write("Catalog save during shutdown failed.", exception); }
        }
        AppDiagnostics.Write("Desktop shutdown completed.");
    }
}
