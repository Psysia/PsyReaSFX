using System.Globalization;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;

namespace PsyReaSFX.Desktop.Controls;

/// <summary>
/// Font-independent toolbar button that follows the geometry used by the Lua
/// edition. Keeping icons as vectors avoids platform glyph substitutions and
/// makes the Desktop and ReaImGui shells visually consistent.
/// </summary>
public sealed class VectorIconButton : FrameworkElement
{
    public static readonly DependencyProperty IconProperty = DependencyProperty.Register(
        nameof(Icon), typeof(string), typeof(VectorIconButton),
        new FrameworkPropertyMetadata("more", FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty ForegroundProperty = DependencyProperty.Register(
        nameof(Foreground), typeof(Brush), typeof(VectorIconButton),
        new FrameworkPropertyMetadata(Brushes.White, FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty AccentProperty = DependencyProperty.Register(
        nameof(Accent), typeof(Brush), typeof(VectorIconButton),
        new FrameworkPropertyMetadata(new SolidColorBrush(Color.FromRgb(25, 216, 255)), FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty IsActiveProperty = DependencyProperty.Register(
        nameof(IsActive), typeof(bool), typeof(VectorIconButton),
        new FrameworkPropertyMetadata(false, FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly RoutedEvent ClickEvent = EventManager.RegisterRoutedEvent(
        nameof(Click), RoutingStrategy.Bubble, typeof(RoutedEventHandler), typeof(VectorIconButton));

    private bool _pressed;

    public string Icon { get => (string)GetValue(IconProperty); set => SetValue(IconProperty, value); }
    public Brush Foreground { get => (Brush)GetValue(ForegroundProperty); set => SetValue(ForegroundProperty, value); }
    public Brush Accent { get => (Brush)GetValue(AccentProperty); set => SetValue(AccentProperty, value); }
    public bool IsActive { get => (bool)GetValue(IsActiveProperty); set => SetValue(IsActiveProperty, value); }
    public event RoutedEventHandler Click { add => AddHandler(ClickEvent, value); remove => RemoveHandler(ClickEvent, value); }

    public VectorIconButton()
    {
        Focusable = true;
        Cursor = Cursors.Hand;
        Width = 34;
        Height = 34;
        SnapsToDevicePixels = true;
    }

    protected override Size MeasureOverride(Size availableSize) => new(Width, Height);

    protected override void OnMouseEnter(MouseEventArgs e) { base.OnMouseEnter(e); InvalidateVisual(); }
    protected override void OnMouseLeave(MouseEventArgs e) { base.OnMouseLeave(e); _pressed = false; InvalidateVisual(); }
    protected override void OnMouseLeftButtonDown(MouseButtonEventArgs e)
    {
        base.OnMouseLeftButtonDown(e);
        if (!IsEnabled) return;
        _pressed = true;
        CaptureMouse();
        Focus();
        InvalidateVisual();
        e.Handled = true;
    }

    protected override void OnMouseLeftButtonUp(MouseButtonEventArgs e)
    {
        base.OnMouseLeftButtonUp(e);
        if (!_pressed) return;
        _pressed = false;
        ReleaseMouseCapture();
        InvalidateVisual();
        if (new Rect(RenderSize).Contains(e.GetPosition(this))) RaiseEvent(new RoutedEventArgs(ClickEvent, this));
        e.Handled = true;
    }

    protected override void OnKeyDown(KeyEventArgs e)
    {
        base.OnKeyDown(e);
        if (!IsEnabled || (e.Key != Key.Space && e.Key != Key.Enter)) return;
        RaiseEvent(new RoutedEventArgs(ClickEvent, this));
        e.Handled = true;
    }

    protected override void OnRender(DrawingContext dc)
    {
        base.OnRender(dc);
        var size = Math.Min(ActualWidth, ActualHeight);
        if (size <= 1) return;

        if (IsMouseOver || IsActive || _pressed)
        {
            var baseColor = BrushColor(IsActive ? Accent : Foreground);
            var alpha = IsActive ? (byte)50 : _pressed ? (byte)38 : (byte)20;
            dc.DrawRoundedRectangle(new SolidColorBrush(Color.FromArgb(alpha, baseColor.R, baseColor.G, baseColor.B)), null,
                new Rect(0, 0, ActualWidth, ActualHeight), 5, 5);
        }

        var brush = IsMouseOver || IsActive ? Accent : Foreground;
        if (!IsEnabled) brush = new SolidColorBrush(Color.FromArgb(90, 220, 226, 232));
        DrawGlyph(dc, Icon, new Rect((ActualWidth - size) / 2, (ActualHeight - size) / 2, size, size), brush);
    }

    private static Color BrushColor(Brush brush) => brush is SolidColorBrush solid ? solid.Color : Colors.White;

    private static void DrawGlyph(DrawingContext dc, string icon, Rect bounds, Brush brush)
    {
        var x = bounds.X; var y = bounds.Y; var s = bounds.Width;
        // One optical box for every toolbar glyph. Individual icons used to
        // mix 14 px and 19 px silhouettes inside the same 34 px button.
        var left = x + s * .24; var right = x + s * .76;
        var top = y + s * .24; var bottom = y + s * .76;
        var cx = x + s * .5; var cy = y + s * .5;
        var thickness = Math.Max(1.35, s * .052);
        var pen = new Pen(brush, thickness) { StartLineCap = PenLineCap.Round, EndLineCap = PenLineCap.Round, LineJoin = PenLineJoin.Round };
        if (pen.CanFreeze) pen.Freeze();

        void Line(double x1, double y1, double x2, double y2) => dc.DrawLine(pen, new Point(x1, y1), new Point(x2, y2));
        void Triangle(Point a, Point b, Point c)
        {
            var geometry = new StreamGeometry();
            using (var context = geometry.Open()) { context.BeginFigure(a, true, true); context.LineTo(b, true, false); context.LineTo(c, true, false); }
            geometry.Freeze(); dc.DrawGeometry(brush, null, geometry);
        }

        switch ((icon ?? "").ToLowerInvariant())
        {
            case "panel_left":
            case "panel_right":
                dc.DrawRoundedRectangle(null, pen, new Rect(left, top, right - left, bottom - top), 2, 2);
                var divider = string.Equals(icon, "panel_left", StringComparison.OrdinalIgnoreCase) ? x + s * .425 : x + s * .575;
                Line(divider, top, divider, bottom);
                break;
            case "focus":
                var arm = s * .12;
                Line(left, top + arm, left, top); Line(left, top, left + arm, top);
                Line(right - arm, top, right, top); Line(right, top, right, top + arm);
                Line(left, bottom - arm, left, bottom); Line(left, bottom, left + arm, bottom);
                Line(right - arm, bottom, right, bottom); Line(right, bottom, right, bottom - arm);
                break;
            case "close":
                Line(left, top, right, bottom); Line(right, top, left, bottom);
                break;
            case "refresh":
                DrawArc(dc, pen, cx, cy, s * .21, -45, 285);
                Triangle(new Point(cx + s * .235, cy - s * .13), new Point(cx + s * .08, cy - s * .145), new Point(cx + s * .17, cy - s * .015));
                break;
            case "history_reset":
                DrawArc(dc, pen, cx, cy, s * .21, -62, 292);
                Triangle(new Point(cx - s * .24, cy - s * .12), new Point(cx - s * .08, cy - s * .14), new Point(cx - s * .17, cy - s * .005));
                Line(cx, cy - s * .13, cx, cy + s * .015);
                Line(cx, cy + s * .015, cx + s * .105, cy + s * .07);
                break;
            case "transfer":
                Line(cx, top, cx, cy + s * .03);
                Triangle(new Point(cx, cy + s * .15), new Point(cx - s * .12, cy + s * .02), new Point(cx + s * .12, cy + s * .02));
                Line(left, bottom - s * .08, left, bottom);
                Line(left, bottom, right, bottom);
                Line(right, bottom, right, bottom - s * .08);
                break;
            case "bridge":
                dc.DrawRoundedRectangle(null, pen, new Rect(left, top + s * .04, right - left, bottom - top - s * .08), 2, 2);
                Line(left + s * .11, cy, right - s * .11, cy);
                dc.DrawEllipse(brush, null, new Point(left + s * .11, cy), s * .03, s * .03);
                dc.DrawEllipse(brush, null, new Point(right - s * .11, cy), s * .03, s * .03);
                Line(cx, top - s * .04, cx, top + s * .04);
                Line(cx, bottom - s * .04, cx, bottom + s * .04);
                break;
            case "insert_current":
                Line(left, top, left, bottom); Line(right, top, right, bottom);
                Line(cx - s * .13, cy, cx + s * .08, cy);
                Triangle(new Point(cx + s * .17, cy), new Point(cx + s * .05, cy - s * .09), new Point(cx + s * .05, cy + s * .09));
                break;
            case "insert_new":
                Line(left, top, left, bottom); Line(right, top, right, bottom);
                Line(cx - s * .15, cy, cx + s * .04, cy);
                Triangle(new Point(cx + s * .13, cy), new Point(cx + s * .01, cy - s * .09), new Point(cx + s * .01, cy + s * .09));
                Line(right - s * .055, top - s * .02, right - s * .055, top + s * .13);
                Line(right - s * .13, top + s * .055, right + s * .02, top + s * .055);
                break;
            case "bwf_spot":
                dc.DrawEllipse(null, pen, new Point(cx, cy), s * .21, s * .21);
                Line(cx, cy - s * .12, cx, cy + s * .02);
                Line(cx, cy + s * .02, cx + s * .1, cy + s * .075);
                Line(left - s * .02, bottom + s * .02, right + s * .02, bottom + s * .02);
                break;
            case "speaker":
                dc.DrawRectangle(brush, null, new Rect(left, cy - s * .055, s * .08, s * .11));
                Triangle(new Point(left + s * .06, cy - s * .07), new Point(cx, top + s * .02), new Point(cx, bottom - s * .02));
                DrawArc(dc, pen, cx - s * .025, cy, s * .16, -52, 104);
                DrawArc(dc, pen, cx - s * .025, cy, s * .235, -45, 90);
                break;
            case "help":
                dc.DrawEllipse(null, pen, new Point(cx, cy), s * .235, s * .235);
                var q = new StreamGeometry();
                using (var c = q.Open())
                {
                    c.BeginFigure(new Point(cx - s * .065, cy - s * .075), false, false);
                    c.BezierTo(new Point(cx - s * .055, cy - s * .16), new Point(cx + s * .09, cy - s * .15), new Point(cx + s * .075, cy - s * .045), true, false);
                    c.BezierTo(new Point(cx + s * .065, cy + s * .005), new Point(cx, cy), new Point(cx, cy + s * .07), true, false);
                }
                q.Freeze(); dc.DrawGeometry(null, pen, q); dc.DrawEllipse(brush, null, new Point(cx, cy + s * .145), s * .018, s * .018);
                break;
            case "settings":
                dc.DrawEllipse(null, pen, new Point(cx, cy), s * .09, s * .09);
                dc.DrawEllipse(null, pen, new Point(cx, cy), s * .185, s * .185);
                for (var i = 0; i < 8; i++)
                {
                    var angle = i * Math.PI / 4;
                    Line(cx + Math.Cos(angle) * s * .185, cy + Math.Sin(angle) * s * .185,
                        cx + Math.Cos(angle) * s * .255, cy + Math.Sin(angle) * s * .255);
                }
                break;
            case "play":
                Triangle(new Point(left + s * .035, top), new Point(right, cy), new Point(left + s * .035, bottom));
                break;
            case "pause":
                dc.DrawRectangle(brush, null, new Rect(left + s * .04, top, s * .09, bottom - top));
                dc.DrawRectangle(brush, null, new Rect(right - s * .13, top, s * .09, bottom - top));
                break;
            case "stop":
                dc.DrawRoundedRectangle(brush, null, new Rect(left + s * .025, top + s * .025, right - left - s * .05, bottom - top - s * .05), 1.5, 1.5);
                break;
            case "star":
                var points = new List<Point>(10);
                for (var i = 0; i < 10; i++)
                {
                    var radius = s * (i % 2 == 0 ? .22 : .095); var angle = -Math.PI / 2 + i * Math.PI / 5;
                    points.Add(new Point(cx + Math.Cos(angle) * radius, cy + Math.Sin(angle) * radius));
                }
                var star = new StreamGeometry();
                using (var c = star.Open()) { c.BeginFigure(points[0], false, true); c.PolyLineTo(points.Skip(1).ToArray(), true, false); }
                star.Freeze(); dc.DrawGeometry(null, pen, star);
                break;
            case "loop":
                Line(left + s * .04, top + s * .08, right - s * .07, top + s * .08);
                Triangle(new Point(right, top + s * .08), new Point(right - s * .12, top - s * .015), new Point(right - s * .12, top + s * .175));
                Line(right - s * .04, bottom - s * .08, left + s * .07, bottom - s * .08);
                Triangle(new Point(left, bottom - s * .08), new Point(left + s * .12, bottom - s * .175), new Point(left + s * .12, bottom + s * .015));
                break;
            case "reverse":
                Line(left + s * .03, top + s * .08, right - s * .04, top + s * .08);
                Triangle(new Point(left, top + s * .08), new Point(left + s * .12, top - s * .015), new Point(left + s * .12, top + s * .175));
                Line(right - s * .03, bottom - s * .08, left + s * .04, bottom - s * .08);
                Triangle(new Point(right, bottom - s * .08), new Point(right - s * .12, bottom - s * .175), new Point(right - s * .12, bottom + s * .015));
                break;
            case "pitch_lock":
                Line(left, cy + s * .12, left, cy - s * .02);
                Line(left + s * .09, cy + s * .12, left + s * .09, cy - s * .11);
                Line(left + s * .18, cy + s * .12, left + s * .18, cy - s * .18);
                dc.DrawRoundedRectangle(null, pen, new Rect(cx + s * .025, cy - s * .005, s * .18, s * .16), 2, 2);
                DrawArc(dc, pen, cx + s * .115, cy - s * .005, s * .07, 180, 180);
                break;
            case "channel_stereo":
                Line(left, top, left, bottom); Line(right, top, right, bottom);
                break;
            case "loudness_match":
                Line(cx - s * .16, bottom, cx - s * .16, cy + s * .02);
                Line(cx - s * .055, bottom, cx - s * .055, cy - s * .12);
                Line(cx + s * .055, bottom, cx + s * .055, top);
                Line(cx + s * .16, bottom, cx + s * .16, cy - s * .04);
                break;
            case "channel_left":
                Line(left, top, left, bottom); Line(right, top + s * .07, right, bottom - s * .07);
                break;
            case "channel_right":
                Line(left, top + s * .07, left, bottom - s * .07); Line(right, top, right, bottom);
                break;
            case "zoom_reset":
                dc.DrawEllipse(null, pen, new Point(cx - s * .04, cy - s * .035), s * .14, s * .14);
                Line(cx + s * .06, cy + s * .065, right, bottom); Line(cx - s * .12, cy - s * .035, cx + s * .04, cy - s * .035);
                break;
            default:
                for (var i = -1; i <= 1; i++) dc.DrawEllipse(brush, null, new Point(cx + i * s * .12, cy), s * .027, s * .027);
                break;
        }
    }

    private static void DrawArc(DrawingContext dc, Pen pen, double cx, double cy, double radius, double startDegrees, double sweepDegrees)
    {
        var start = startDegrees * Math.PI / 180; var end = (startDegrees + sweepDegrees) * Math.PI / 180;
        var geometry = new StreamGeometry();
        using (var context = geometry.Open())
        {
            context.BeginFigure(new Point(cx + Math.Cos(start) * radius, cy + Math.Sin(start) * radius), false, false);
            context.ArcTo(new Point(cx + Math.Cos(end) * radius, cy + Math.Sin(end) * radius), new Size(radius, radius), 0,
                Math.Abs(sweepDegrees) > 180, sweepDegrees >= 0 ? SweepDirection.Clockwise : SweepDirection.Counterclockwise, true, false);
        }
        geometry.Freeze(); dc.DrawGeometry(null, pen, geometry);
    }
}
