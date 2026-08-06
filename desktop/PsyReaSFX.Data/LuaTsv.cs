using System.Globalization;
using System.Text;

namespace PsyReaSFX.Data;

internal static class LuaTsv
{
    public static string[] Split(string line)
    {
        var raw = line.Split('\t');
        for (var i = 0; i < raw.Length; i++) raw[i] = Unescape(raw[i]);
        return raw;
    }

    public static string Unescape(string value)
    {
        if (value.IndexOf('%') < 0) return value;
        var result = new StringBuilder(value.Length);
        for (var i = 0; i < value.Length; i++)
        {
            if (value[i] == '%' && i + 2 < value.Length &&
                byte.TryParse(value.AsSpan(i + 1, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var b))
            {
                result.Append((char)b);
                i += 2;
            }
            else result.Append(value[i]);
        }
        return result.ToString();
    }

    public static bool Boolean(string? value) => value is "1" or "true";
    public static int Integer(string? value) => int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var result) ? result : 0;
    public static long Long(string? value) => long.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var result) ? result : 0;
    public static double Number(string? value) => double.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out var result) ? result : 0;
    public static double? NullableNumber(string? value) => double.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out var result) ? result : null;
}
