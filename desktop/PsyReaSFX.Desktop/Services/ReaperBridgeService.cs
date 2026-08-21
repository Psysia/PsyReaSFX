using System.Diagnostics;
using System.Globalization;
using System.Text;

namespace PsyReaSFX.Desktop.Services;

public sealed record ReaperBridgeRequest(
    string Action,
    string MediaPath,
    string AssetPath,
    string DisplayName,
    double SelectionStart = 0,
    double SelectionEnd = 0);

public sealed record ReaperBridgeResult(
    bool Success,
    string Message,
    string Action,
    string AssetPath,
    string InsertedPath,
    string ProjectPath,
    string ProjectName,
    string TrackName,
    int TrackIndex,
    double Position);

/// <summary>
/// Small file-queue bridge. The Desktop app remains fully standalone while a
/// persistent ReaScript consumes requests inside REAPER. Atomic renames avoid
/// partial reads and the heartbeat makes availability checks non-blocking.
/// </summary>
public sealed class ReaperBridgeService
{
    public string RootDirectory { get; }
    public string RequestsDirectory => Path.Combine(RootDirectory, "requests");
    public string ResponsesDirectory => Path.Combine(RootDirectory, "responses");
    public string HeartbeatPath => Path.Combine(RootDirectory, "heartbeat.tsv");

    public ReaperBridgeService(string? rootDirectory = null)
    {
        RootDirectory = rootDirectory ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PsyReaSFX", "bridge");
    }

    public bool IsOnline(TimeSpan? tolerance = null)
    {
        try
        {
            if (!File.Exists(HeartbeatPath)) return false;
            return DateTime.UtcNow - File.GetLastWriteTimeUtc(HeartbeatPath) <= (tolerance ?? TimeSpan.FromSeconds(4));
        }
        catch { return false; }
    }

    public async Task<ReaperBridgeResult> ExecuteAsync(
        ReaperBridgeRequest request,
        TimeSpan? timeout = null,
        CancellationToken cancellationToken = default)
    {
        Directory.CreateDirectory(RequestsDirectory);
        Directory.CreateDirectory(ResponsesDirectory);
        var id = Guid.NewGuid().ToString("N");
        var requestPath = Path.Combine(RequestsDirectory, id + ".request");
        var responsePath = Path.Combine(ResponsesDirectory, id + ".response");
        var tempPath = requestPath + ".tmp";
        var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["id"] = id,
            ["action"] = request.Action,
            ["media"] = request.MediaPath,
            ["asset"] = request.AssetPath,
            ["display"] = request.DisplayName,
            ["selection_start"] = request.SelectionStart.ToString("R", CultureInfo.InvariantCulture),
            ["selection_end"] = request.SelectionEnd.ToString("R", CultureInfo.InvariantCulture),
            ["created_utc"] = DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString(CultureInfo.InvariantCulture)
        };
        await File.WriteAllTextAsync(tempPath, Serialize(values), new UTF8Encoding(false), cancellationToken);
        File.Move(tempPath, requestPath, true);

        var expires = DateTime.UtcNow + (timeout ?? TimeSpan.FromSeconds(6));
        while (DateTime.UtcNow < expires)
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (File.Exists(responsePath))
            {
                string payload;
                try { payload = await File.ReadAllTextAsync(responsePath, cancellationToken); }
                catch (IOException) { await Task.Delay(35, cancellationToken); continue; }
                try { File.Delete(responsePath); } catch { }
                var response = Parse(payload);
                return new ReaperBridgeResult(
                    ParseBool(response, "success"), Get(response, "message"), Get(response, "action"), Get(response, "asset"),
                    Get(response, "inserted"), Get(response, "project_path"), Get(response, "project_name"), Get(response, "track_name"),
                    ParseInt(response, "track_index", -1), ParseDouble(response, "position"));
            }
            await Task.Delay(50, cancellationToken);
        }

        try { File.Delete(requestPath); } catch { }
        return new ReaperBridgeResult(false, "REAPER Bridge timeout", request.Action, request.AssetPath, request.MediaPath, "", "", "", -1, 0);
    }

    public Task<ReaperBridgeResult> PingAsync(CancellationToken cancellationToken = default) =>
        ExecuteAsync(new ReaperBridgeRequest("ping", "", "", "PsyReaSFX Desktop"), TimeSpan.FromSeconds(3), cancellationToken);

    public void OpenDirectory()
    {
        Directory.CreateDirectory(RootDirectory);
        Process.Start(new ProcessStartInfo { FileName = RootDirectory, UseShellExecute = true });
    }

    internal static string Serialize(IReadOnlyDictionary<string, string> values) =>
        string.Join('\n', values.Select(pair => pair.Key + "=" + Uri.EscapeDataString(pair.Value ?? ""))) + "\n";

    internal static Dictionary<string, string> Parse(string payload)
    {
        var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var line in payload.Replace("\r", "").Split('\n', StringSplitOptions.RemoveEmptyEntries))
        {
            var split = line.IndexOf('=');
            if (split <= 0) continue;
            try { values[line[..split]] = Uri.UnescapeDataString(line[(split + 1)..]); }
            catch { values[line[..split]] = line[(split + 1)..]; }
        }
        return values;
    }

    private static string Get(IReadOnlyDictionary<string, string> values, string key) => values.TryGetValue(key, out var value) ? value : "";
    private static bool ParseBool(IReadOnlyDictionary<string, string> values, string key) =>
        values.TryGetValue(key, out var value) && (value == "1" || bool.TryParse(value, out var parsed) && parsed);
    private static int ParseInt(IReadOnlyDictionary<string, string> values, string key, int fallback) =>
        values.TryGetValue(key, out var value) && int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed) ? parsed : fallback;
    private static double ParseDouble(IReadOnlyDictionary<string, string> values, string key) =>
        values.TryGetValue(key, out var value) && double.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out var parsed) ? parsed : 0;
}
