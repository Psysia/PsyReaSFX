using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace PsyReaSFX.Desktop;

public sealed class LibraryDefinition : INotifyPropertyChanged
{
    private string _name = "Library";
    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public string Name { get => _name; set { _name = value; OnPropertyChanged(); } }
    public string ArtworkPath { get; set; } = "";
    public bool IsExpanded { get; set; } = true;
    public ObservableCollection<LibrarySource> Sources { get; set; } = [];
    public event PropertyChangedEventHandler? PropertyChanged;
    private void OnPropertyChanged([CallerMemberName] string? name = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}

public sealed class LibrarySource
{
    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public string Path { get; set; } = "";
    public string Alias { get; set; } = "";
    public bool Enabled { get; set; } = true;
    public string ArtworkPath { get; set; } = "";
    public bool ArtworkChecked { get; set; }
    public int ArtworkScanVersion { get; set; }
    public string DisplayName => System.IO.Path.GetFileName(Path.TrimEnd(System.IO.Path.DirectorySeparatorChar)) is { Length: > 0 } n ? n : Path;
}

public sealed class AudioAsset : INotifyPropertyChanged
{
    private bool _isFavorite;
    private int _previewCount;
    private double _lastPreviewed;
    private string _artworkPath = "";
    private double _previewPlayhead = -1;
    private string _description = "";
    private string _keywords = "";
    private string _catId = "";
    private string _category = "";
    private string _subcategory = "";
    private string _workflowStatus = "none";
    private bool _marked;
    public string FilePath { get; set; } = "";
    public string FileName { get; set; } = "";
    public string LibraryName { get; set; } = "";
    public string SourcePath { get; set; } = "";
    public string RelativeFolder { get; set; } = "";
    public string Format { get; set; } = "";
    public long FileSize { get; set; }
    public long LastWriteUtcTicks { get; set; }
    public double DurationSeconds { get; set; }
    public int Channels { get; set; }
    public int SampleRate { get; set; }
    public int BitDepth { get; set; }
    public string ArtworkPath { get => _artworkPath; set { if (_artworkPath == value) return; _artworkPath = value; OnPropertyChanged(); } }
    public double PreviewPlayhead
    {
        get => _previewPlayhead;
        set
        {
            // Playback progress is a lightweight overlay now, so keep every
            // display-frame update instead of quantizing long files to large
            // visible jumps.
            if (Math.Abs(_previewPlayhead - value) < 0.000001) return;
            _previewPlayhead = value;
            OnPropertyChanged();
        }
    }
    public string Description { get => _description; set { if (_description == value) return; _description = value; OnPropertyChanged(); OnPropertyChanged(nameof(SearchDescription)); } }
    public string Keywords { get => _keywords; set { if (_keywords == value) return; _keywords = value; OnPropertyChanged(); OnPropertyChanged(nameof(SearchDescription)); } }
    public string CatId { get => _catId; set { if (_catId == value) return; _catId = value; OnPropertyChanged(); } }
    public string Category { get => _category; set { if (_category == value) return; _category = value; OnPropertyChanged(); OnPropertyChanged(nameof(SearchDescription)); } }
    public string Subcategory { get => _subcategory; set { if (_subcategory == value) return; _subcategory = value; OnPropertyChanged(); OnPropertyChanged(nameof(SearchDescription)); } }
    public string WorkflowStatus
    {
        get => _workflowStatus;
        set
        {
            value = string.IsNullOrWhiteSpace(value) ? "none" : value;
            if (_workflowStatus == value) return;
            _workflowStatus = value;
            OnPropertyChanged();
            OnPropertyChanged(nameof(WorkflowStatusText));
        }
    }
    public bool Marked { get => _marked; set { if (_marked == value) return; _marked = value; OnPropertyChanged(); OnPropertyChanged(nameof(MarkedText)); } }
    public int PreviewCount { get => _previewCount; set { _previewCount = value; OnPropertyChanged(); OnPropertyChanged(nameof(HasBeenPreviewed)); } }
    public double LastPreviewed { get => _lastPreviewed; set { _lastPreviewed = value; OnPropertyChanged(); } }
    public bool Indexed { get; set; }
    public bool Ready { get; set; }
    public int UsedCount { get; set; }
    public double LastUsed { get; set; }
    public string RootId { get; set; } = "";
    public string LibraryId { get; set; } = "";
    public bool IsFavorite { get => _isFavorite; set { _isFavorite = value; OnPropertyChanged(); OnPropertyChanged(nameof(FavoriteGlyph)); } }
    public string FavoriteGlyph => IsFavorite ? "★" : "☆";
    public bool HasBeenPreviewed => PreviewCount > 0;
    public string WorkflowStatusText => WorkflowStatus switch
    {
        "candidate" => "候选",
        "approved" => "已采用",
        "rejected" => "已排除",
        _ => "未标记"
    };
    public string MarkedText => Marked ? "●" : "";
    public string SearchDescription => !string.IsNullOrWhiteSpace(Description)
        ? Description
        : !string.IsNullOrWhiteSpace(Keywords)
            ? Keywords
            : string.Join(" · ", new[] { Category, Subcategory }.Where(value => !string.IsNullOrWhiteSpace(value)));
    public string DurationText => DurationSeconds > 0
        ? TimeSpan.FromSeconds(DurationSeconds).ToString(DurationSeconds >= 3600 ? @"hh\:mm\:ss\.fff" : @"mm\:ss\.fff")
        : "—";
    public string TechnicalText => Channels > 0
        ? $"{Format.ToUpperInvariant()} · {Channels}ch · {(SampleRate > 0 ? (SampleRate / 1000.0).ToString("0.#") + " kHz" : "—")}{(BitDepth > 0 ? " · " + BitDepth + "-bit" : "")}" 
        : Format.ToUpperInvariant();
    public event PropertyChangedEventHandler? PropertyChanged;
    private void OnPropertyChanged([CallerMemberName] string? name = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}

public sealed class PersistedState
{
    public ObservableCollection<LibraryDefinition> Libraries { get; set; } = [];
    public List<AudioAsset> Index { get; set; } = [];
    public HashSet<string> Favorites { get; set; } = new(StringComparer.OrdinalIgnoreCase);
    public string Language { get; set; } = "zh-CN";
}
