using System.Collections.Concurrent;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using PsyReaSFX.Desktop.Services;

namespace PsyReaSFX.Desktop.Controls;

public sealed class WaveformSelectionChangedEventArgs(double start, double end) : EventArgs
{
    public double Start { get; } = start;
    public double End { get; } = end;
}

public sealed record WaveformRegion(double Start, double End, bool Automatic);

public sealed class WaveformControl : FrameworkElement
{
    private long _lastScrubTick;
    private static readonly ConcurrentDictionary<string, Task<float[][]>> Cache = new(StringComparer.OrdinalIgnoreCase);
    private static readonly ConcurrentQueue<string> CacheOrder = new();
    private static readonly SemaphoreSlim DecodeSlots = new(1, 1);
    private const int MaxCachedWaveforms = 320;
    private static readonly Brush LabelBackground = new SolidColorBrush(Color.FromArgb(205, 12, 16, 21));
    private static readonly Pen BaselinePen = new(new SolidColorBrush(Color.FromRgb(54, 68, 80)), 1);
    private static readonly Pen DividerPen = new(new SolidColorBrush(Color.FromRgb(24, 39, 50)), 1);
    private float[][] _data = [];
    private bool _loading;
    private bool _failed;
    private int _loadVersion;
    private bool _dragging;
    private bool _selectionMoved;
    private bool _scrubbing;
    private Point _dragOrigin;
    private double _selectionAnchor;
    private double _viewStart;
    private double _zoom = 1;
    private DrawingGroup? _staticDrawing;
    private Pen? _playheadPen;
    private Brush? _playheadPenBrush;
    private Size _staticDrawingSize;
    internal int StaticDrawingBuildCount { get; private set; }

    public static readonly DependencyProperty FilePathProperty = DependencyProperty.Register(
        nameof(FilePath), typeof(string), typeof(WaveformControl),
        new FrameworkPropertyMetadata("", FrameworkPropertyMetadataOptions.AffectsRender, OnWaveformChanged));
    public static readonly DependencyProperty ResolutionProperty = DependencyProperty.Register(
        nameof(Resolution), typeof(int), typeof(WaveformControl),
        new FrameworkPropertyMetadata(256, FrameworkPropertyMetadataOptions.AffectsRender, OnWaveformChanged));
    public static readonly DependencyProperty PlayheadProperty = DependencyProperty.Register(
        nameof(Playhead), typeof(double), typeof(WaveformControl),
        new FrameworkPropertyMetadata(-1d, FrameworkPropertyMetadataOptions.AffectsRender));
    public static readonly DependencyProperty SelectionStartProperty = DependencyProperty.Register(
        nameof(SelectionStart), typeof(double), typeof(WaveformControl),
        new FrameworkPropertyMetadata(-1d, FrameworkPropertyMetadataOptions.AffectsRender, OnStaticVisualChanged));
    public static readonly DependencyProperty SelectionEndProperty = DependencyProperty.Register(
        nameof(SelectionEnd), typeof(double), typeof(WaveformControl),
        new FrameworkPropertyMetadata(-1d, FrameworkPropertyMetadataOptions.AffectsRender, OnStaticVisualChanged));
    public static readonly DependencyProperty AllowSelectionProperty = DependencyProperty.Register(
        nameof(AllowSelection), typeof(bool), typeof(WaveformControl), new PropertyMetadata(false));
    public static readonly DependencyProperty AllowZoomProperty = DependencyProperty.Register(
        nameof(AllowZoom), typeof(bool), typeof(WaveformControl), new PropertyMetadata(false));
    public static readonly DependencyProperty ShowChannelLabelsProperty = DependencyProperty.Register(
        nameof(ShowChannelLabels), typeof(bool), typeof(WaveformControl),
        new FrameworkPropertyMetadata(false, FrameworkPropertyMetadataOptions.AffectsRender, OnStaticVisualChanged));
    public static readonly DependencyProperty WaveBrushProperty = DependencyProperty.Register(nameof(WaveBrush), typeof(Brush), typeof(WaveformControl),
        new FrameworkPropertyMetadata(Brushes.White, FrameworkPropertyMetadataOptions.AffectsRender, OnStaticVisualChanged));
    public static readonly DependencyProperty SelectedWaveBrushProperty = DependencyProperty.Register(nameof(SelectedWaveBrush), typeof(Brush), typeof(WaveformControl),
        new FrameworkPropertyMetadata(Brushes.White, FrameworkPropertyMetadataOptions.AffectsRender, OnStaticVisualChanged));
    public static readonly DependencyProperty PlayedWaveBrushProperty = DependencyProperty.Register(nameof(PlayedWaveBrush), typeof(Brush), typeof(WaveformControl),
        new FrameworkPropertyMetadata(Brushes.Gold, FrameworkPropertyMetadataOptions.AffectsRender, OnStaticVisualChanged));
    public static readonly DependencyProperty MarkedWaveBrushProperty = DependencyProperty.Register(nameof(MarkedWaveBrush), typeof(Brush), typeof(WaveformControl),
        new FrameworkPropertyMetadata(Brushes.Cyan, FrameworkPropertyMetadataOptions.AffectsRender, OnStaticVisualChanged));
    public static readonly DependencyProperty BackgroundFillProperty = DependencyProperty.Register(nameof(BackgroundFill), typeof(Brush), typeof(WaveformControl),
        new FrameworkPropertyMetadata(Brushes.Black, FrameworkPropertyMetadataOptions.AffectsRender, OnStaticVisualChanged));
    public static readonly DependencyProperty SelectionFillProperty = DependencyProperty.Register(nameof(SelectionFill), typeof(Brush), typeof(WaveformControl),
        new FrameworkPropertyMetadata(Brushes.DodgerBlue, FrameworkPropertyMetadataOptions.AffectsRender, OnStaticVisualChanged));
    public static readonly DependencyProperty PlayheadBrushProperty = DependencyProperty.Register(nameof(PlayheadBrush), typeof(Brush), typeof(WaveformControl),
        new FrameworkPropertyMetadata(Brushes.Cyan, FrameworkPropertyMetadataOptions.AffectsRender));
    public static readonly DependencyProperty RegionBrushProperty = DependencyProperty.Register(nameof(RegionBrush), typeof(Brush), typeof(WaveformControl),
        new FrameworkPropertyMetadata(Brushes.SteelBlue, FrameworkPropertyMetadataOptions.AffectsRender, OnStaticVisualChanged));
    public static readonly DependencyProperty RegionsProperty = DependencyProperty.Register(nameof(Regions), typeof(IReadOnlyList<WaveformRegion>), typeof(WaveformControl),
        new FrameworkPropertyMetadata(Array.Empty<WaveformRegion>(), FrameworkPropertyMetadataOptions.AffectsRender, OnStaticVisualChanged));
    public static readonly DependencyProperty IsRowSelectedProperty = DependencyProperty.Register(nameof(IsRowSelected), typeof(bool), typeof(WaveformControl),
        new FrameworkPropertyMetadata(false, FrameworkPropertyMetadataOptions.AffectsRender, OnStaticVisualChanged));
    public static readonly DependencyProperty IsPlayedProperty = DependencyProperty.Register(nameof(IsPlayed), typeof(bool), typeof(WaveformControl),
        new FrameworkPropertyMetadata(false, FrameworkPropertyMetadataOptions.AffectsRender, OnStaticVisualChanged));
    public static readonly DependencyProperty IsMarkedProperty = DependencyProperty.Register(nameof(IsMarked), typeof(bool), typeof(WaveformControl),
        new FrameworkPropertyMetadata(false, FrameworkPropertyMetadataOptions.AffectsRender, OnStaticVisualChanged));
    public static readonly DependencyProperty AuditionChannelsProperty = DependencyProperty.Register(nameof(AuditionChannels), typeof(IReadOnlyList<int>), typeof(WaveformControl),
        new FrameworkPropertyMetadata(Array.Empty<int>(), FrameworkPropertyMetadataOptions.AffectsRender, OnStaticVisualChanged));

    public string FilePath { get => (string)GetValue(FilePathProperty); set => SetValue(FilePathProperty, value); }
    public int Resolution { get => (int)GetValue(ResolutionProperty); set => SetValue(ResolutionProperty, value); }
    public double Playhead { get => (double)GetValue(PlayheadProperty); set => SetValue(PlayheadProperty, value); }
    public double SelectionStart { get => (double)GetValue(SelectionStartProperty); set => SetValue(SelectionStartProperty, value); }
    public double SelectionEnd { get => (double)GetValue(SelectionEndProperty); set => SetValue(SelectionEndProperty, value); }
    public bool AllowSelection { get => (bool)GetValue(AllowSelectionProperty); set => SetValue(AllowSelectionProperty, value); }
    public bool AllowZoom { get => (bool)GetValue(AllowZoomProperty); set => SetValue(AllowZoomProperty, value); }
    public bool ShowChannelLabels { get => (bool)GetValue(ShowChannelLabelsProperty); set => SetValue(ShowChannelLabelsProperty, value); }
    public Brush WaveBrush { get => (Brush)GetValue(WaveBrushProperty); set => SetValue(WaveBrushProperty, value); }
    public Brush SelectedWaveBrush { get => (Brush)GetValue(SelectedWaveBrushProperty); set => SetValue(SelectedWaveBrushProperty, value); }
    public Brush PlayedWaveBrush { get => (Brush)GetValue(PlayedWaveBrushProperty); set => SetValue(PlayedWaveBrushProperty, value); }
    public Brush MarkedWaveBrush { get => (Brush)GetValue(MarkedWaveBrushProperty); set => SetValue(MarkedWaveBrushProperty, value); }
    public Brush BackgroundFill { get => (Brush)GetValue(BackgroundFillProperty); set => SetValue(BackgroundFillProperty, value); }
    public Brush SelectionFill { get => (Brush)GetValue(SelectionFillProperty); set => SetValue(SelectionFillProperty, value); }
    public Brush PlayheadBrush { get => (Brush)GetValue(PlayheadBrushProperty); set => SetValue(PlayheadBrushProperty, value); }
    public Brush RegionBrush { get => (Brush)GetValue(RegionBrushProperty); set => SetValue(RegionBrushProperty, value); }
    public IReadOnlyList<WaveformRegion> Regions { get => (IReadOnlyList<WaveformRegion>)GetValue(RegionsProperty); set => SetValue(RegionsProperty, value); }
    public bool IsRowSelected { get => (bool)GetValue(IsRowSelectedProperty); set => SetValue(IsRowSelectedProperty, value); }
    public bool IsPlayed { get => (bool)GetValue(IsPlayedProperty); set => SetValue(IsPlayedProperty, value); }
    public bool IsMarked { get => (bool)GetValue(IsMarkedProperty); set => SetValue(IsMarkedProperty, value); }
    public IReadOnlyList<int> AuditionChannels { get => (IReadOnlyList<int>)GetValue(AuditionChannelsProperty); set => SetValue(AuditionChannelsProperty, value); }
    public double Zoom => _zoom;

    public Rect GetSelectionDisplayBounds()
    {
        if (SelectionStart < 0 || SelectionEnd <= SelectionStart || ActualWidth <= 0 || ActualHeight <= 0)
            return Rect.Empty;
        var left = Math.Clamp(XAt(SelectionStart), 0, ActualWidth);
        var right = Math.Clamp(XAt(SelectionEnd), 0, ActualWidth);
        return right > left ? new Rect(left, 0, right - left, ActualHeight) : Rect.Empty;
    }

    public event EventHandler<double>? SeekRequested;
    public event EventHandler<double>? ScrubRequested;
    public event EventHandler<WaveformSelectionChangedEventArgs>? SelectionChanged;
    public event EventHandler<double>? ZoomChanged;

    public WaveformControl()
    {
        ClipToBounds = true;
        Cursor = Cursors.Hand;
        MouseLeftButtonDown += OnMouseDown;
        MouseMove += OnMouseMove;
        MouseLeftButtonUp += OnMouseUp;
        MouseWheel += OnMouseWheel;
        MouseRightButtonDown += OnScrubDown;
        MouseRightButtonUp += OnScrubUp;
    }

    public static void ClearMemoryCache()
    {
        Cache.Clear();
        while (CacheOrder.TryDequeue(out _)) { }
    }

    public void ClearSelection()
    {
        SelectionStart = SelectionEnd = -1;
        SelectionChanged?.Invoke(this, new(-1, -1));
    }

    public void ResetView()
    {
        _zoom = 1;
        _viewStart = 0;
        InvalidateStaticDrawing();
        InvalidateVisual();
        ZoomChanged?.Invoke(this, _zoom);
    }

    private void OnMouseDown(object sender, MouseButtonEventArgs e)
    {
        if (ActualWidth <= 0) return;
        if (e.ClickCount == 2 && AllowZoom)
        {
            ResetView();
            e.Handled = true;
            return;
        }
        _dragOrigin = e.GetPosition(this);
        _selectionAnchor = RatioAt(_dragOrigin.X);
        _selectionMoved = false;
        _dragging = AllowSelection;
        if (_dragging) CaptureMouse();
        e.Handled = true;
    }

    private void OnMouseMove(object sender, MouseEventArgs e)
    {
        if (_scrubbing && e.RightButton == MouseButtonState.Pressed)
        {
            var now = Environment.TickCount64;
            if (now - _lastScrubTick >= 75)
            {
                _lastScrubTick = now;
                ScrubRequested?.Invoke(this, RatioAt(e.GetPosition(this).X));
            }
            e.Handled = true;
            return;
        }
        if (!_dragging || e.LeftButton != MouseButtonState.Pressed) return;
        var point = e.GetPosition(this);
        if (!_selectionMoved && Math.Abs(point.X - _dragOrigin.X) < 4) return;
        _selectionMoved = true;
        var ratio = RatioAt(point.X);
        SelectionStart = Math.Min(_selectionAnchor, ratio);
        SelectionEnd = Math.Max(_selectionAnchor, ratio);
        SelectionChanged?.Invoke(this, new(SelectionStart, SelectionEnd));
    }

    private void OnScrubDown(object sender, MouseButtonEventArgs e)
    {
        _scrubbing = true; CaptureMouse();
        _lastScrubTick = Environment.TickCount64;
        ScrubRequested?.Invoke(this, RatioAt(e.GetPosition(this).X));
        e.Handled = true;
    }

    private void OnScrubUp(object sender, MouseButtonEventArgs e)
    {
        if (_scrubbing) ScrubRequested?.Invoke(this, RatioAt(e.GetPosition(this).X));
        _scrubbing = false; if (IsMouseCaptured) ReleaseMouseCapture(); e.Handled = true;
    }

    private void OnMouseUp(object sender, MouseButtonEventArgs e)
    {
        var ratio = RatioAt(e.GetPosition(this).X);
        if (_dragging) ReleaseMouseCapture();
        _dragging = false;
        if (!_selectionMoved) SeekRequested?.Invoke(this, ratio);
        e.Handled = true;
    }

    private void OnMouseWheel(object sender, MouseWheelEventArgs e)
    {
        if (!AllowZoom) return;
        if ((Keyboard.Modifiers & ModifierKeys.Shift) != 0 && _zoom > 1)
        {
            var span = 1 / _zoom;
            _viewStart = Math.Clamp(_viewStart + (e.Delta > 0 ? -span * .12 : span * .12), 0, 1 - span);
        }
        else
        {
            var anchor = RatioAt(e.GetPosition(this).X);
            var oldSpan = 1 / _zoom;
            _zoom = Math.Clamp(e.Delta > 0 ? _zoom * 1.3 : _zoom / 1.3, 1, 32);
            var newSpan = 1 / _zoom;
            var local = ActualWidth <= 0 ? .5 : Math.Clamp(e.GetPosition(this).X / ActualWidth, 0, 1);
            _viewStart = Math.Clamp(anchor - local * newSpan, 0, 1 - newSpan);
            if (Math.Abs(oldSpan - newSpan) < .0001) return;
        }
        InvalidateStaticDrawing();
        InvalidateVisual();
        ZoomChanged?.Invoke(this, _zoom);
        e.Handled = true;
    }

    private double RatioAt(double x)
    {
        var span = 1 / _zoom;
        return Math.Clamp(_viewStart + Math.Clamp(x / Math.Max(1, ActualWidth), 0, 1) * span, 0, 1);
    }

    private double XAt(double ratio) => (ratio - _viewStart) / (1 / _zoom) * ActualWidth;

    private static void OnWaveformChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        var control = (WaveformControl)d;
        control._data = [];
        control._loading = false;
        control._failed = false;
        control._loadVersion++;
        control.InvalidateStaticDrawing();
        control.ResetView();
        control.InvalidateVisual();
        control.BeginLoad();
    }

    private static void OnStaticVisualChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        ((WaveformControl)d).InvalidateStaticDrawing();
    }

    private void InvalidateStaticDrawing()
    {
        _staticDrawing = null;
        _staticDrawingSize = default;
    }

    protected override void OnRender(DrawingContext dc)
    {
        base.OnRender(dc);
        if (_staticDrawing == null || _staticDrawingSize != RenderSize)
            RebuildStaticDrawing();
        if (_staticDrawing != null)
            dc.DrawDrawing(_staticDrawing);

        var span = 1 / _zoom;
        if (Playhead >= _viewStart && Playhead <= _viewStart + span)
        {
            var x = XAt(Playhead);
            if (!ReferenceEquals(_playheadPenBrush, PlayheadBrush))
            {
                _playheadPenBrush = PlayheadBrush;
                _playheadPen = new Pen(PlayheadBrush, 1.5);
            }
            dc.DrawLine(_playheadPen, new Point(x, 0), new Point(x, ActualHeight));
        }
    }

    private void RebuildStaticDrawing()
    {
        StaticDrawingBuildCount++;
        var group = new DrawingGroup();
        using var dc = group.Open();
        dc.DrawRectangle(BackgroundFill, null, new Rect(RenderSize));
        if (_data.Length == 0)
        {
            dc.DrawLine(BaselinePen, new Point(0, ActualHeight / 2), new Point(ActualWidth, ActualHeight / 2));
            _staticDrawing = group;
            _staticDrawingSize = RenderSize;
            BeginLoad();
            return;
        }

        var visibleChannels = AuditionChannels is { Count: > 0 }
            ? AuditionChannels.Where(channel => channel >= 0 && channel < _data.Length).Distinct().ToArray()
            : Enumerable.Range(0, _data.Length).ToArray();
        if (visibleChannels.Length == 0) visibleChannels = Enumerable.Range(0, _data.Length).ToArray();
        var laneHeight = ActualHeight / visibleChannels.Length;
        var span = 1 / _zoom;
        var waveformPen = new Pen(IsRowSelected ? SelectedWaveBrush : IsMarked ? MarkedWaveBrush : IsPlayed ? PlayedWaveBrush : WaveBrush, 1);
        for (var lane = 0; lane < visibleChannels.Length; lane++)
        {
            var channel = visibleChannels[lane];
            var samples = _data[channel];
            var center = lane * laneHeight + laneHeight / 2;
            if (lane > 0) dc.DrawLine(DividerPen, new Point(0, lane * laneHeight), new Point(ActualWidth, lane * laneHeight));
            for (var x = 0; x < ActualWidth; x++)
            {
                var ratio = _viewStart + x / Math.Max(1, ActualWidth) * span;
                var index = Math.Min(samples.Length - 1, Math.Max(0, (int)(ratio * samples.Length)));
                var h = samples[index] * laneHeight * .42;
                dc.DrawLine(waveformPen, new Point(x, center - h), new Point(x, center + h));
            }

            if (ShowChannelLabels && laneHeight >= 15)
            {
                var label = _data.Length == 2 ? (channel == 0 ? "L" : "R") : $"CH {channel + 1}";
                var text = new FormattedText(label, System.Globalization.CultureInfo.CurrentUICulture,
                    FlowDirection.LeftToRight, new Typeface("Segoe UI"), 10,
                    new SolidColorBrush(Color.FromRgb(125, 151, 174)), VisualTreeHelper.GetDpi(this).PixelsPerDip);
                var left = Math.Max(2, ActualWidth - text.Width - 9);
                dc.DrawRoundedRectangle(LabelBackground, null, new Rect(left - 4, center - text.Height / 2 - 2, text.Width + 8, text.Height + 4), 3, 3);
                dc.DrawText(text, new Point(left, center - text.Height / 2));
            }
        }

        if (Regions is { Count: > 0 })
        {
            foreach (var region in Regions)
            {
                var left = Math.Max(0, XAt(region.Start));
                var right = Math.Min(ActualWidth, XAt(region.End));
                if (right <= left) continue;
                var pen = new Pen(RegionBrush, region.Automatic ? 1 : 1.5)
                    { DashStyle = region.Automatic ? DashStyles.Dash : DashStyles.Solid };
                dc.DrawRectangle(null, pen, new Rect(left, 1, Math.Max(1, right - left), Math.Max(1, ActualHeight - 2)));
            }
        }

        if (SelectionStart >= 0 && SelectionEnd > SelectionStart)
        {
            var left = Math.Max(0, XAt(SelectionStart));
            var right = Math.Min(ActualWidth, XAt(SelectionEnd));
            if (right > left) dc.DrawRectangle(SelectionFill, null, new Rect(left, 0, right - left, ActualHeight));
        }
        _staticDrawing = group;
        _staticDrawingSize = RenderSize;
    }

    private async void BeginLoad()
    {
        if (_loading || _failed || string.IsNullOrWhiteSpace(FilePath) || !File.Exists(FilePath)) return;
        _loading = true;
        var requestedPath = FilePath;
        var requestedResolution = Resolution;
        var version = _loadVersion;
        try
        {
            await Task.Delay(requestedResolution <= 512 ? 125 : 90);
            if (version != _loadVersion || !requestedPath.Equals(FilePath, StringComparison.OrdinalIgnoreCase)) return;
            var key = requestedPath + "|" + requestedResolution;
            var task = Cache.GetOrAdd(key, _ =>
            {
                CacheOrder.Enqueue(key);
                TrimCache();
                return DecodeAsync(requestedPath, requestedResolution);
            });
            var result = await task;
            if (version != _loadVersion || !requestedPath.Equals(FilePath, StringComparison.OrdinalIgnoreCase)) return;
            _data = result;
            _failed = result.Length == 0;
            InvalidateStaticDrawing();
            InvalidateVisual();
        }
        catch
        {
            Cache.TryRemove(requestedPath + "|" + requestedResolution, out _);
            if (version == _loadVersion) { _data = []; _failed = true; InvalidateStaticDrawing(); InvalidateVisual(); }
        }
        finally { if (version == _loadVersion) _loading = false; }
    }

    private static async Task<float[][]> DecodeAsync(string path, int resolution)
    {
        await DecodeSlots.WaitAsync();
        try { return await Task.Run(() => AudioFileReader.ReadWaveform(path, resolution)); }
        finally { DecodeSlots.Release(); }
    }

    private static void TrimCache()
    {
        while (Cache.Count > MaxCachedWaveforms && CacheOrder.TryDequeue(out var oldest))
            Cache.TryRemove(oldest, out _);
    }
}
