using System.Text;

namespace PsyReaSFX.Desktop.Services;

internal static class AppDiagnostics
{
    private static readonly object Sync = new();
    public static string LogDirectory { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PsyReaSFX", "logs");
    public static string CurrentLogPath { get; } = Path.Combine(LogDirectory, $"desktop-{DateTime.Now:yyyyMMdd}.log");

    public static void Write(string message, Exception? exception = null)
    {
        try
        {
            Directory.CreateDirectory(LogDirectory);
            var text = new StringBuilder()
                .Append(DateTimeOffset.Now.ToString("O"))
                .Append(" [")
                .Append(Environment.ProcessId)
                .Append("] ")
                .AppendLine(message);
            if (exception is not null) text.AppendLine(exception.ToString());
            lock (Sync) File.AppendAllText(CurrentLogPath, text.ToString(), Encoding.UTF8);
        }
        catch { }
    }
}
