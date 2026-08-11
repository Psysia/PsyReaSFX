using System.Globalization;
using System.Windows;
using System.Windows.Media;

namespace PsyReaSFX.Desktop.Services;

public static class ThemeManager
{
    public static readonly IReadOnlyDictionary<string, string> DarkDefaults = new Dictionary<string, string>
    {
        [nameof(DesktopPreferences.FrameColor)] = "#090B0F",
        [nameof(DesktopPreferences.PanelColor)] = "#0F1217",
        [nameof(DesktopPreferences.HeaderColor)] = "#171C23",
        [nameof(DesktopPreferences.LineColor)] = "#27313C",
        [nameof(DesktopPreferences.TextColor)] = "#DCE2E8",
        [nameof(DesktopPreferences.MutedTextColor)] = "#8C97A3",
        [nameof(DesktopPreferences.AccentColor)] = "#1684D8",
        [nameof(DesktopPreferences.SelectedRowColor)] = "#247CCB",
        [nameof(DesktopPreferences.PlayedTextColor)] = "#F1C84B",
        [nameof(DesktopPreferences.WaveformColor)] = "#D7E0E8",
        [nameof(DesktopPreferences.SelectedWaveformColor)] = "#FFFFFF",
        [nameof(DesktopPreferences.PlayedWaveformColor)] = "#F1C84B",
        [nameof(DesktopPreferences.MarkedWaveformColor)] = "#19D8FF",
        [nameof(DesktopPreferences.SelectionColor)] = "#1684D8",
        [nameof(DesktopPreferences.PlayheadColor)] = "#19D8FF",
        [nameof(DesktopPreferences.RegionColor)] = "#4F9DE8"
    };

    public static readonly IReadOnlyDictionary<string, string> ClassicDefaults = new Dictionary<string, string>
    {
        [nameof(DesktopPreferences.FrameColor)] = "#050B15",
        [nameof(DesktopPreferences.PanelColor)] = "#08111E",
        [nameof(DesktopPreferences.HeaderColor)] = "#10233B",
        [nameof(DesktopPreferences.LineColor)] = "#1D3B5D",
        [nameof(DesktopPreferences.TextColor)] = "#E4EBF3",
        [nameof(DesktopPreferences.MutedTextColor)] = "#8193A8",
        [nameof(DesktopPreferences.AccentColor)] = "#087F96",
        [nameof(DesktopPreferences.SelectedRowColor)] = "#126B7F",
        [nameof(DesktopPreferences.PlayedTextColor)] = "#F0C94C",
        [nameof(DesktopPreferences.WaveformColor)] = "#D7E0E8",
        [nameof(DesktopPreferences.SelectedWaveformColor)] = "#FFFFFF",
        [nameof(DesktopPreferences.PlayedWaveformColor)] = "#F0C94C",
        [nameof(DesktopPreferences.MarkedWaveformColor)] = "#19D8FF",
        [nameof(DesktopPreferences.SelectionColor)] = "#087F96",
        [nameof(DesktopPreferences.PlayheadColor)] = "#19D8FF",
        [nameof(DesktopPreferences.RegionColor)] = "#19B9D5"
    };

    public static void ApplyPreset(DesktopPreferences preferences, string preset)
    {
        var values = preset.Equals("classic", StringComparison.OrdinalIgnoreCase) ? ClassicDefaults : DarkDefaults;
        preferences.ThemePreset = preset.Equals("classic", StringComparison.OrdinalIgnoreCase) ? "classic" : "dark";
        preferences.FrameColor = values[nameof(DesktopPreferences.FrameColor)];
        preferences.PanelColor = values[nameof(DesktopPreferences.PanelColor)];
        preferences.HeaderColor = values[nameof(DesktopPreferences.HeaderColor)];
        preferences.LineColor = values[nameof(DesktopPreferences.LineColor)];
        preferences.TextColor = values[nameof(DesktopPreferences.TextColor)];
        preferences.MutedTextColor = values[nameof(DesktopPreferences.MutedTextColor)];
        preferences.AccentColor = values[nameof(DesktopPreferences.AccentColor)];
        preferences.SelectedRowColor = values[nameof(DesktopPreferences.SelectedRowColor)];
        preferences.PlayedTextColor = values[nameof(DesktopPreferences.PlayedTextColor)];
        preferences.WaveformColor = values[nameof(DesktopPreferences.WaveformColor)];
        preferences.SelectedWaveformColor = values[nameof(DesktopPreferences.SelectedWaveformColor)];
        preferences.PlayedWaveformColor = values[nameof(DesktopPreferences.PlayedWaveformColor)];
        preferences.MarkedWaveformColor = values[nameof(DesktopPreferences.MarkedWaveformColor)];
        preferences.SelectionColor = values[nameof(DesktopPreferences.SelectionColor)];
        preferences.PlayheadColor = values[nameof(DesktopPreferences.PlayheadColor)];
        preferences.RegionColor = values[nameof(DesktopPreferences.RegionColor)];
    }

    public static void FillMissingThemeColors(DesktopPreferences preferences, string preset)
    {
        var values = preset.Equals("classic", StringComparison.OrdinalIgnoreCase) ? ClassicDefaults : DarkDefaults;
        static bool Missing(string? value) => string.IsNullOrWhiteSpace(value);
        if (Missing(preferences.PanelColor)) preferences.PanelColor = values[nameof(DesktopPreferences.PanelColor)];
        if (Missing(preferences.HeaderColor)) preferences.HeaderColor = values[nameof(DesktopPreferences.HeaderColor)];
        if (Missing(preferences.LineColor)) preferences.LineColor = values[nameof(DesktopPreferences.LineColor)];
        if (Missing(preferences.TextColor)) preferences.TextColor = values[nameof(DesktopPreferences.TextColor)];
        if (Missing(preferences.MutedTextColor)) preferences.MutedTextColor = values[nameof(DesktopPreferences.MutedTextColor)];
        if (Missing(preferences.SelectedRowColor)) preferences.SelectedRowColor = values[nameof(DesktopPreferences.SelectedRowColor)];
        if (Missing(preferences.RegionColor)) preferences.RegionColor = values[nameof(DesktopPreferences.RegionColor)];
    }

    public static void Apply(DesktopPreferences preferences)
    {
        var frame = Parse(preferences.FrameColor, Color.FromRgb(9, 11, 15));
        var panel = Parse(preferences.PanelColor, Mix(frame, Colors.White, .025));
        var header = Parse(preferences.HeaderColor, Mix(frame, Colors.White, .075));
        var line = Parse(preferences.LineColor, Mix(frame, Colors.White, .15));
        var text = Parse(preferences.TextColor, Color.FromRgb(220, 226, 232));
        var muted = Parse(preferences.MutedTextColor, Mix(text, frame, .43));
        var accent = Parse(preferences.AccentColor, Color.FromRgb(22, 132, 216));
        Set("BgBrush", frame);
        Set("PanelBrush", panel);
        Set("PanelRaisedBrush", Mix(panel, Colors.White, .045));
        Set("PanelHoverBrush", Mix(panel, Colors.White, .09));
        Set("HeaderBrush", header);
        Set("LineBrush", line);
        Set("LineSoftBrush", Mix(line, frame, .35));
        Set("TextBrush", text);
        Set("MutedBrush", muted);
        Set("AccentBrush", accent);
        Set("AccentBrightBrush", Lighten(accent, .25));
        Set("SelectedBrush", Parse(preferences.SelectedRowColor, Lighten(accent, .08)));
        Set("PlayedBrush", Parse(preferences.PlayedTextColor, Color.FromRgb(241, 200, 75)));
        Set("SuccessBrush", Parse("#56D47C", Colors.LimeGreen));
        Set("WaveformBrush", Parse(preferences.WaveformColor, Color.FromRgb(215, 224, 232)));
        Set("SelectedWaveformBrush", Parse(preferences.SelectedWaveformColor, Colors.White));
        Set("PlayedWaveformBrush", preferences.HighlightPlayedWaveform
            ? Parse(preferences.PlayedWaveformColor, Color.FromRgb(241, 200, 75))
            : Parse(preferences.WaveformColor, Color.FromRgb(215, 224, 232)));
        Set("MarkedWaveformBrush", Parse(preferences.MarkedWaveformColor, Color.FromRgb(25, 216, 255)));
        Set("WaveformBackgroundBrush", Mix(frame, Colors.Black, .35));
        Set("WaveformSelectionBrush", WithAlpha(Parse(preferences.SelectionColor, accent), 78));
        Set("WaveformPlayheadBrush", Parse(preferences.PlayheadColor, Color.FromRgb(25, 216, 255)));
        Set("WaveformRegionBrush", Parse(preferences.RegionColor, Color.FromRgb(79, 157, 232)));
    }

    public static string Normalize(string? value, string fallback)
    {
        var color = Parse(value, Parse(fallback, Colors.Black));
        return $"#{color.R:X2}{color.G:X2}{color.B:X2}";
    }

    public static Color Parse(string? value, Color fallback)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(value)) return fallback;
            var text = value.Trim().TrimStart('#');
            if (text.Length == 8) text = text[2..];
            if (text.Length != 6) return fallback;
            return Color.FromRgb(byte.Parse(text[..2], NumberStyles.HexNumber),
                byte.Parse(text.Substring(2, 2), NumberStyles.HexNumber),
                byte.Parse(text.Substring(4, 2), NumberStyles.HexNumber));
        }
        catch { return fallback; }
    }

    private static void Set(string key, Color color)
    {
        if (Application.Current.Resources[key] is SolidColorBrush brush && !brush.IsFrozen)
            brush.Color = color;
        else
            Application.Current.Resources[key] = new SolidColorBrush(color);
    }

    private static Color WithAlpha(Color color, byte alpha) => Color.FromArgb(alpha, color.R, color.G, color.B);
    private static Color Lighten(Color color, double amount) => Mix(color, Colors.White, amount);
    private static Color Mix(Color a, Color b, double amount)
    {
        amount = Math.Clamp(amount, 0, 1);
        return Color.FromRgb((byte)(a.R + (b.R - a.R) * amount),
            (byte)(a.G + (b.G - a.G) * amount), (byte)(a.B + (b.B - a.B) * amount));
    }
}
