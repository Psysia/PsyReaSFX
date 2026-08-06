using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
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
    private ObservableCollection<AudioAsset> _assets = [];
    private readonly MediaPlayer _player = new();
    private readonly DispatcherTimer _timer = new() { Interval = TimeSpan.FromMilliseconds(100) };
    private readonly DispatcherTimer _searchTimer = new() { Interval = TimeSpan.FromMilliseconds(180) };
    private readonly DispatcherTimer _autoPreviewTimer = new() { Interval = TimeSpan.FromMilliseconds(110) };
    private readonly HashSet<string> _activityDirty = new(StringComparer.OrdinalIgnoreCase);
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
    private string _loadedPreviewPath = "";
    private string _openingPreviewPath = "";
    private long _lastTimeTextUpdateTick;
    private long _playbackClockAnchorTicks;
    private double _playbackClockAnchorSeconds;
    private double _playbackRate = 1;
    private GridLength _navigationWidth = new(240);
    private GridLength _inspectorWidth = new(292);
    private Point _dragStart;
    private List<QueryToken> _queryTokens = [];
    private int _visibleCount;
    private double _selectionStartRatio = -1;
    private double _selectionEndRatio = -1;
    private bool _loopSelection;
    private int _channelMode;
    private readonly Dictionary<string, string> _metadataBaseline = new(StringComparer.Ordinal);

    public static readonly DependencyProperty InlineWaveformResolutionProperty = DependencyProperty.Register(
        nameof(InlineWaveformResolution), typeof(int), typeof(MainWindow), new PropertyMetadata(512));
    public int InlineWaveformResolution
    {
        get => (int)GetValue(InlineWaveformResolutionProperty);
        set => SetValue(InlineWaveformResolutionProperty, value);
    }

    public MainWindow()
    {
        InitializeComponent();
        _preferences = _preferencesStore.Load();
        ApplyPreferences(_preferences, false);
        _view = CollectionViewSource.GetDefaultView(_assets);
        _view.Filter = FilterAsset;
        AssetGrid.ItemsSource = _view;

        _player.MediaOpened += (_, _) => Dispatcher.Invoke(OnMediaOpened);
        _player.MediaEnded += (_, _) => Dispatcher.Invoke(() =>
        {
            if (_loopSelection && HasValidSelection() && _previewing != null)
            {
                _player.Position = TimeSpan.FromSeconds(_selectionStartRatio * _previewing.DurationSeconds);
                _player.Play();
                return;
            }
            _isPlaying = false;
            SetPlaybackClock(_previewing?.DurationSeconds ?? 0);
            PlayButton.Icon = "play";
            if (_previewing != null) _previewing.PreviewPlayhead = -1;
            SetDetailPlayhead(0, false);
        });
        _player.MediaFailed += (_, args) => Dispatcher.Invoke(() =>
        {
            _isPlaying = false;
            SetPlaybackClock(0);
            PlayButton.Icon = "play";
            _openingPreviewPath = "";
            StatusText.Text = $"无法试听：{args.ErrorException?.Message ?? "媒体格式不可用"}";
            AppDiagnostics.Write("Media preview failed.", args.ErrorException);
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

        AutoPreviewButton.Foreground = _autoPreview
            ? (Brush)FindResource("AccentBrightBrush")
            : (Brush)FindResource("MutedBrush");
        AutoPreviewButton.IsActive = _autoPreview;
        StatusText.Text = "正在打开 PsyReaSFX 数据库…";
        UpdateCount();
        SourceInitialized += (_, _) => EnableDarkTitleBar();
        Loaded += MainWindow_Loaded;
    }

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
            _view = CollectionViewSource.GetDefaultView(_assets);
            _view.Filter = FilterAsset;
            AssetGrid.ItemsSource = _view;
            ApplySort();
            RebuildLibraryTree();
            RefreshView();
            if (_view.Cast<object>().FirstOrDefault() is AudioAsset first)
            {
                AssetGrid.SelectedItem = first;
                AssetGrid.ScrollIntoView(first);
            }
            _initialized = true;
            _ = ResolveMissingSourceArtworkAsync();

            if (_store.LastError is not null)
                StatusText.Text = $"数据库打开失败 · 日志：{AppDiagnostics.CurrentLogPath}";
            else if (_store.LastMigration is { Imported: true } migration)
                StatusText.Text = $"已迁移 Lua 数据：{migration.Libraries} 个库 · {migration.Assets:N0} 个素材";
            else
                StatusText.Text = $"就绪：{_assets.Count:N0} 个素材";

            if (_state.Libraries.Count > 0 && _state.Index.Count == 0) await RescanAsync(false);
        }
        catch (Exception exception)
        {
            AppDiagnostics.Write("Asynchronous workspace initialization failed.", exception);
            StatusText.Text = $"启动失败 · 日志：{AppDiagnostics.CurrentLogPath}";
        }
    }

    private bool FilterAsset(object item)
    {
        if (item is not AudioAsset asset) return false;
        if (_libraryIdFilter.Length > 0 && !asset.LibraryId.Equals(_libraryIdFilter, StringComparison.OrdinalIgnoreCase)) return false;
        if (_sourceFilter.Length > 0 && !asset.SourcePath.Equals(_sourceFilter, StringComparison.OrdinalIgnoreCase)) return false;
        if (_statusFilter.Length > 0 && !asset.WorkflowStatus.Equals(_statusFilter, StringComparison.OrdinalIgnoreCase)) return false;
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
        foreach (Match match in Regex.Matches(query.Trim(), "(?:[^\\s\\\"]+|\\\"[^\\\"]*\\\")+"))
        {
            var token = match.Value.Trim('"');
            if (token.Length == 0) continue;
            var exclude = token.StartsWith('-');
            if (exclude) token = token[1..];
            var separator = token.IndexOf(':');
            var field = separator > 0 ? token[..separator].ToLowerInvariant() : "";
            var term = separator > 0 ? token[(separator + 1)..] : token;
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
        SortButton.Content = $"排序：{SortLabel()}";
    }

    private string SortLabel() => _sortMode switch
    {
        SortMode.Duration => "时长",
        SortMode.Library => "音效库",
        SortMode.RecentlyPreviewed => "最近试听",
        _ => "名称"
    } + (_sortDescending ? " ↓" : "");

    private void Sort_Click(object sender, RoutedEventArgs e)
    {
        if (Keyboard.Modifiers.HasFlag(ModifierKeys.Shift)) _sortDescending = !_sortDescending;
        else _sortMode = (SortMode)(((int)_sortMode + 1) % Enum.GetValues<SortMode>().Length);
        ApplySort();
    }

    private async void Rescan_Click(object sender, RoutedEventArgs e) => await RescanAsync(true);
    private async Task RescanAsync(bool announce)
    {
        if (_scanCancellation != null) return;
        _scanCancellation = new CancellationTokenSource();
        RescanButton.IsEnabled = false;
        StatusText.Text = "正在增量扫描音效库…";
        try
        {
            var progress = new Progress<(int Count, string File)>(p => StatusText.Text = $"正在索引 {p.Count:N0} · {Path.GetFileName(p.File)}");
            var indexed = await _indexer.BuildAsync(_state.Libraries, _assets, progress, _scanCancellation.Token);
            foreach (var asset in indexed) asset.IsFavorite = _state.Favorites.Contains(asset.FilePath);
            _assets = new ObservableCollection<AudioAsset>(indexed);
            _view = CollectionViewSource.GetDefaultView(_assets);
            _view.Filter = FilterAsset;
            AssetGrid.ItemsSource = _view;
            _state.Index = indexed;
            await Task.Run(() => _store.Save(_state));
            ApplySort();
            RebuildLibraryTree();
            RefreshView();
            StatusText.Text = $"扫描完成：{indexed.Count:N0} 个素材";
            if (announce && indexed.Count == 0) MessageBox.Show("没有找到受支持的音频文件。", "PsyReaSFX Desktop");
        }
        catch (OperationCanceledException) { StatusText.Text = "扫描已取消"; }
        catch (Exception ex) { StatusText.Text = "扫描失败"; AppDiagnostics.Write("Library scan failed.", ex); MessageBox.Show(ex.Message, "扫描失败"); }
        finally { _scanCancellation.Dispose(); _scanCancellation = null; RescanButton.IsEnabled = true; }
    }

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
        switch (e.NewValue)
        {
            case TreeViewItem { Tag: LibraryDefinition library }:
                _libraryIdFilter = library.Id; _sourceFilter = ""; BreadcrumbText.Text = $"Home  /  {library.Name}"; break;
            case TreeViewItem { Tag: LibrarySource source, Parent: TreeViewItem { Tag: LibraryDefinition parent } }:
                _libraryIdFilter = parent.Id; _sourceFilter = source.Path; BreadcrumbText.Text = $"Home  /  {parent.Name}  /  {source.DisplayName}"; break;
        }
        RefreshView();
    }

    private void AllSounds_Click(object sender, RoutedEventArgs e) => SetBrowse(BrowseMode.All);
    private void Favorites_Click(object sender, RoutedEventArgs e) => SetBrowse(BrowseMode.Favorites);
    private void RecentUsed_Click(object sender, RoutedEventArgs e) => SetBrowse(BrowseMode.RecentUsed);
    private void PreviewHistory_Click(object sender, RoutedEventArgs e) => SetBrowse(BrowseMode.PreviewHistory);
    private void AllStatus_Click(object sender, RoutedEventArgs e) { _statusFilter = ""; RefreshView(); }
    private void StatusFilter_Click(object sender, RoutedEventArgs e) { _statusFilter = (sender as Button)?.Tag as string ?? ""; RefreshView(); }

    private void SetBrowse(BrowseMode mode)
    {
        _browseMode = mode; _libraryIdFilter = ""; _sourceFilter = ""; _statusFilter = "";
        RefreshView();
    }

    private void UpdateBreadcrumb()
    {
        if (_sourceFilter.Length > 0 || _libraryIdFilter.Length > 0) return;
        BreadcrumbText.Text = _browseMode switch
        {
            BrowseMode.Favorites => "Home  /  Favorites",
            BrowseMode.RecentUsed => "Home  /  Recently inserted",
            BrowseMode.PreviewHistory => "Home  /  Preview history",
            _ => "Home"
        };
    }

    private void AssetGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        _selected = AssetGrid.SelectedItem as AudioAsset;
        var selectedAssets = AssetGrid.SelectedItems.Cast<AudioAsset>().ToArray();
        InspectorSelectionCount.Text = $"{selectedAssets.Length:N0} selected";
        if (_selected == null) return;
        PreviewTitle.Text = _selected.FileName;
        PreviewTechnical.Text = $"{_selected.DurationText}  ·  {_selected.Channels}ch  ·  {(_selected.SampleRate / 1000.0):0.#}k  ·  {_selected.LibraryName}";
        PreviewLoudness.Text = "";
        DetailWaveform.FilePath = _selected.FilePath;
        DetailWaveform.ClearSelection();
        _selectionStartRatio = _selectionEndRatio = -1;
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
        if (_selected.Channels != 2 && _channelMode != 0)
        {
            _channelMode = 0;
            ApplyChannelMode();
        }
        ChannelModeButton.Visibility = _selected.Channels == 2 ? Visibility.Visible : Visibility.Collapsed;
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
            rowMenu.Items.Add(CreateStatusMenuItem("未标记", "none"));
            rowMenu.Items.Add(CreateStatusMenuItem("候选", "candidate"));
            rowMenu.Items.Add(CreateStatusMenuItem("已采用", "approved"));
            rowMenu.Items.Add(CreateStatusMenuItem("已排除", "rejected"));
            rowMenu.Items.Add(new Separator());
            var mark = new MenuItem { Header = SelectedAssets().All(item => item.Marked) ? "取消标记" : "标记素材" };
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
        DragDrop.DoDragDrop(AssetGrid, new DataObject(DataFormats.FileDrop, files), DragDropEffects.Copy);
    }

    private void DetailWaveform_SeekRequested(object? sender, double ratio) { if (_selected != null) StartPreview(ratio); }
    private void DetailWaveform_SelectionChanged(object? sender, Controls.WaveformSelectionChangedEventArgs e)
    {
        _selectionStartRatio = e.Start;
        _selectionEndRatio = e.End;
        if (_selected == null || !HasValidSelection())
        {
            InTimeText.Text = "0.000";
            OutTimeText.Text = _selected == null ? "0.000" : FormatTimeCompact(_selected.DurationSeconds);
            DurationTimeText.Text = _selected == null ? "0.000" : FormatTimeCompact(_selected.DurationSeconds);
            return;
        }
        var duration = _selected.DurationSeconds;
        InTimeText.Text = FormatTimeCompact(_selectionStartRatio * duration);
        OutTimeText.Text = FormatTimeCompact(_selectionEndRatio * duration);
        DurationTimeText.Text = FormatTimeCompact((_selectionEndRatio - _selectionStartRatio) * duration);
    }

    private void DetailWaveform_ZoomChanged(object? sender, double zoom)
    {
        if (ZoomText != null) ZoomText.Text = $"×{zoom:0.0}";
    }

    private bool HasValidSelection() => _selectionStartRatio >= 0 && _selectionEndRatio > _selectionStartRatio + .00001;
    private void StartPreview(double ratio)
    {
        if (_selected == null || !File.Exists(_selected.FilePath)) return;
        try
        {
            _autoPreviewTimer.Stop();
            var path = _selected.FilePath;
            if (_previewing != null && !ReferenceEquals(_previewing, _selected))
                _previewing.PreviewPlayhead = -1;
            _previewing = _selected;
            _pendingSeekRatio = Math.Clamp(ratio, 0, 1);
            _previewing.PreviewPlayhead = _pendingSeekRatio;

            if (_loadedPreviewPath.Equals(path, StringComparison.OrdinalIgnoreCase) && _player.Source != null)
            {
                var duration = _player.NaturalDuration.HasTimeSpan
                    ? _player.NaturalDuration.TimeSpan.TotalSeconds
                    : _selected.DurationSeconds;
                var startAt = duration > 0 ? _pendingSeekRatio * duration : 0;
                if (duration > 0) _player.Position = TimeSpan.FromSeconds(startAt);
                _player.Play();
                _isPlaying = true;
                SetPlaybackClock(startAt);
                PlayButton.Icon = "pause";
                SetDetailPlayhead(_pendingSeekRatio, true);
                StatusText.Text = $"试听：{_selected.FileName}";
                MarkPreviewActivity(_selected);
                return;
            }

            if (_openingPreviewPath.Equals(path, StringComparison.OrdinalIgnoreCase))
            {
                StatusText.Text = $"正在准备试听：{_selected.FileName}";
                return;
            }

            _player.Close();
            _loadedPreviewPath = "";
            _openingPreviewPath = path;
            _player.Open(new Uri(path, UriKind.Absolute));
            _isPlaying = false;
            PlayButton.Icon = "play";
            StatusText.Text = $"试听：{_selected.FileName}";
        }
        catch (Exception ex) { AppDiagnostics.Write("Preview start failed.", ex); StatusText.Text = "无法试听当前文件"; }
    }

    private void OnMediaOpened()
    {
        if (string.IsNullOrWhiteSpace(_openingPreviewPath)) return;
        if (_player.Source is { IsFile: true } source
            && !source.LocalPath.Equals(_openingPreviewPath, StringComparison.OrdinalIgnoreCase)) return;
        _loadedPreviewPath = _openingPreviewPath;
        _openingPreviewPath = "";
        var duration = _player.NaturalDuration.HasTimeSpan ? _player.NaturalDuration.TimeSpan.TotalSeconds : _previewing?.DurationSeconds ?? 0;
        var startAt = duration > 0 ? Math.Clamp(_pendingSeekRatio, 0, 1) * duration : 0;
        if (duration > 0) _player.Position = TimeSpan.FromSeconds(startAt);
        _player.Play(); _isPlaying = true; PlayButton.Icon = "pause";
        SetPlaybackClock(startAt);
        if (_previewing != null) MarkPreviewActivity(_previewing);
        UpdatePreviewTime();
    }

    private void MarkPreviewActivity(AudioAsset asset)
    {
        asset.PreviewCount++;
        asset.LastPreviewed = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() / 1000.0;
        _activityDirty.Add(asset.FilePath);
        if (_browseMode == BrowseMode.PreviewHistory) RefreshView();
    }

    private void Play_Click(object sender, RoutedEventArgs e)
    {
        if (_selected == null) return;
        if (_isPlaying)
        {
            var pausedAt = GetPlaybackClockSeconds();
            _player.Pause();
            _isPlaying = false;
            SetPlaybackClock(pausedAt);
            PlayButton.Icon = "play";
        }
        else if (_loadedPreviewPath.Equals(_selected.FilePath, StringComparison.OrdinalIgnoreCase) && _player.Source != null)
        {
            var duration = _player.NaturalDuration.HasTimeSpan ? _player.NaturalDuration.TimeSpan.TotalSeconds : _selected.DurationSeconds;
            var restartAt = HasValidSelection() ? _selectionStartRatio * duration : 0;
            var stopAt = HasValidSelection() ? _selectionEndRatio * duration : duration;
            var resumeAt = GetPlaybackClockSeconds();
            if (duration > 0 && resumeAt >= stopAt - .01) resumeAt = restartAt;
            if (duration > 0) _player.Position = TimeSpan.FromSeconds(resumeAt);
            _player.Play(); _isPlaying = true; PlayButton.Icon = "pause";
            SetPlaybackClock(resumeAt);
        }
        else StartPreview(0);
    }

    private void Stop_Click(object sender, RoutedEventArgs e)
    {
        _player.Stop(); _player.Position = TimeSpan.Zero; _isPlaying = false; PlayButton.Icon = "play";
        SetPlaybackClock(0);
        if (_previewing != null) _previewing.PreviewPlayhead = -1;
        SetDetailPlayhead(0, false); UpdatePreviewTime();
    }

    private void UpdatePreviewTime()
    {
        if (_selected == null) { PreviewTime.Text = ""; CurrentTimeText.Text = "0.000"; return; }
        var current = GetPlaybackClockSeconds();
        var previewAsset = _previewing ?? _selected;
        var duration = previewAsset.DurationSeconds > 0 ? previewAsset.DurationSeconds : _player.NaturalDuration.HasTimeSpan ? _player.NaturalDuration.TimeSpan.TotalSeconds : 0;
        if (_isPlaying && _loopSelection && HasValidSelection() && duration > 0
            && current >= _selectionEndRatio * duration)
        {
            current = _selectionStartRatio * duration;
            _player.Position = TimeSpan.FromSeconds(current);
            _player.Play();
            SetPlaybackClock(current);
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
        try { _player.SpeedRatio = e.NewValue; }
        catch (Exception exception) { AppDiagnostics.Write("Preview rate could not be changed.", exception); }
    }

    private void GainSlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (GainValue == null) return;
        GainValue.Text = $"{e.NewValue:+0.0;-0.0;+0.0} dB";
        _player.Volume = Math.Clamp(Math.Pow(10, e.NewValue / 20), 0, 1);
    }

    private void Loop_Click(object sender, RoutedEventArgs e)
    {
        _loopSelection = !_loopSelection;
        LoopButton.Foreground = _loopSelection ? (Brush)FindResource("AccentBrightBrush") : (Brush)FindResource("MutedBrush");
        LoopButton.IsActive = _loopSelection;
        StatusText.Text = _loopSelection ? "选区循环已开启" : "选区循环已关闭";
    }

    private void ResetWaveform_Click(object sender, RoutedEventArgs e)
    {
        DetailWaveform.ClearSelection();
        DetailWaveform.ResetView();
        _selectionStartRatio = _selectionEndRatio = -1;
        if (_selected != null)
        {
            InTimeText.Text = "0.000";
            OutTimeText.Text = DurationTimeText.Text = FormatTimeCompact(_selected.DurationSeconds);
        }
    }

    private void ChannelMode_Click(object sender, RoutedEventArgs e)
    {
        if (_selected?.Channels != 2) return;
        _channelMode = (_channelMode + 1) % 3;
        ApplyChannelMode();
    }

    private void ApplyChannelMode()
    {
        _player.Balance = _channelMode switch { 1 => -1, 2 => 1, _ => 0 };
        ChannelModeButton.Icon = _channelMode switch { 1 => "channel_left", 2 => "channel_right", _ => "channel_stereo" };
        ChannelModeButton.Foreground = _channelMode == 0
            ? (Brush)FindResource("MutedBrush")
            : (Brush)FindResource("AccentBrightBrush");
        ChannelModeButton.IsActive = _channelMode != 0;
        ChannelModeButton.ToolTip = _channelMode switch
        {
            1 => "仅监听左声道 · 点击切换右声道",
            2 => "仅监听右声道 · 点击恢复立体声",
            _ => "立体声监听 · 点击切换左声道"
        };
    }

    private static string FormatTime(double seconds) => TimeSpan.FromSeconds(Math.Max(0, seconds)).ToString(seconds >= 3600 ? @"hh\:mm\:ss\.fff" : @"mm\:ss\.fff");
    private static string FormatTimeCompact(double seconds) => Math.Max(0, seconds).ToString("0.000");

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
        var window = new SettingsWindow(_preferences, _store.DataDirectory) { Owner = this };
        if (window.ShowDialog() != true) return;
        _preferences = window.Preferences;
        _preferencesStore.Save(_preferences);
        ApplyPreferences(_preferences, true);
        StatusText.Text = "设置已保存";
    }

    private void ApplyPreferences(DesktopPreferences preferences, bool refreshWaveforms)
    {
        _autoPreview = preferences.AutoPreview;
        InlineWaveformResolution = preferences.InlineWaveformResolution is 256 or 512
            ? preferences.InlineWaveformResolution : 512;
        DetailWaveform.Resolution = preferences.DetailWaveformResolution is 2048 or 4096
            ? preferences.DetailWaveformResolution : 4096;
        AutoPreviewButton.Foreground = _autoPreview
            ? (Brush)FindResource("AccentBrightBrush")
            : (Brush)FindResource("MutedBrush");
        AutoPreviewButton.IsActive = _autoPreview;
        ApplyResultColumnPreferences();
        SetNavigationVisible(preferences.NavigationVisible);
        SetInspectorVisible(preferences.InspectorVisible);
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

    private void Help_Click(object sender, RoutedEventArgs e) => MessageBox.Show(
        "搜索：输入普通关键词，或使用 library:、category:、status:、path:、channels:；前置 - 可排除。\n\n" +
        "试听：单击列表波形从对应位置开始；Space 播放或暂停；双击结果从头试听。\n\n" +
        "选择：Ctrl/Shift 多选，Ctrl+A 全选当前结果；拖动结果行可交给 REAPER 或其他支持文件拖放的软件。\n\n" +
        "面板：F9 导航，F10 元数据，F11 专注模式。右键逻辑库可管理实体路径。",
        "PsyReaSFX Desktop 使用说明", MessageBoxButton.OK, MessageBoxImage.Information);

    private void MoreActions_Click(object sender, RoutedEventArgs e)
    {
        var menu = new ContextMenu();
        var reveal = new MenuItem { Header = "在资源管理器中显示" }; reveal.Click += Reveal_Click;
        var favorite = new MenuItem { Header = _selected?.IsFavorite == true ? "取消收藏" : "收藏" }; favorite.Click += Favorite_Click;
        var data = new MenuItem { Header = "打开 PsyReaSFX 数据目录" }; data.Click += OpenData_Click;
        menu.Items.Add(reveal); menu.Items.Add(favorite); menu.Items.Add(new Separator()); menu.Items.Add(data);
        menu.PlacementTarget = sender as FrameworkElement; menu.IsOpen = true;
    }

    private void AutoPreview_Click(object sender, RoutedEventArgs e)
    {
        _autoPreview = !_autoPreview;
        _preferences.AutoPreview = _autoPreview;
        _preferencesStore.Save(_preferences);
        AutoPreviewButton.Foreground = _autoPreview ? (Brush)FindResource("AccentBrightBrush") : (Brush)FindResource("MutedBrush");
        AutoPreviewButton.IsActive = _autoPreview;
        StatusText.Text = _autoPreview ? "自动试听已开启" : "自动试听已关闭";
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
        if (e.Key == Key.Space && !SearchBox.IsKeyboardFocusWithin) { Play_Click(sender, e); e.Handled = true; }
        else if (e.Key == Key.Escape) { Stop_Click(sender, e); e.Handled = true; }
        else if (e.Key == Key.F9) { NavigationToggle_Click(sender, e); e.Handled = true; }
        else if (e.Key == Key.F10) { InspectorToggle_Click(sender, e); e.Handled = true; }
        else if (e.Key == Key.F11) { FocusToggle_Click(sender, e); e.Handled = true; }
        else if (e.Key == Key.F && Keyboard.Modifiers == ModifierKeys.Control) { SearchBox.Focus(); SearchBox.SelectAll(); e.Handled = true; }
        else if (e.Key == Key.R && Keyboard.Modifiers == ModifierKeys.Control) { Rescan_Click(sender, e); e.Handled = true; }
        else if (e.Key == Key.F && !SearchBox.IsKeyboardFocusWithin) { Favorite_Click(sender, e); e.Handled = true; }
        else if (e.Key == Key.M && !SearchBox.IsKeyboardFocusWithin) { Mark_Click(sender, e); e.Handled = true; }
    }

    private void UpdateCount()
    {
        var shown = _visibleCount;
        CountText.Text = $"{shown:N0} 个结果";
        ActivityText.Text = $"结果 {shown:N0}\n已选 {AssetGrid?.SelectedItems.Count ?? 0:N0}\n索引 {_assets.Count:N0}\n试听 Desktop";
        AllSoundsCount.Text = _assets.Count.ToString("N0"); FavoritesCount.Text = _state.Favorites.Count.ToString("N0");
    }

    private void Window_Closing(object? sender, CancelEventArgs e)
    {
        CompositionTarget.Rendering -= PlaybackRendering;
        _scanCancellation?.Cancel(); _autoPreviewTimer.Stop(); _timer.Stop(); _player.Close();
        _preferences.NavigationVisible = _navigationVisible;
        _preferences.InspectorVisible = _inspectorVisible;
        _preferences.AutoPreview = _autoPreview;
        SaveResultColumnPreferences();
        try { _preferencesStore.Save(_preferences); }
        catch (Exception exception) { AppDiagnostics.Write("Desktop preferences could not be saved.", exception); }
        if (_initialized)
        {
            _state.Index = _assets.ToList();
            try
            {
                _store.SaveWorkspace(_state);
                if (_activityDirty.Count > 0)
                    _store.SaveActivities(_assets.Where(asset => _activityDirty.Contains(asset.FilePath)));
            }
            catch (Exception exception) { AppDiagnostics.Write("Catalog save during shutdown failed.", exception); }
        }
        AppDiagnostics.Write("Desktop shutdown completed.");
    }
}
