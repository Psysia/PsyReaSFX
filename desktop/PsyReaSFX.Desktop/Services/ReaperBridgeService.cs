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
            var age = DateTime.UtcNow - File.GetLastWriteTimeUtc(HeartbeatPath);
            return age >= TimeSpan.Zero && age <= (tolerance ?? TimeSpan.FromSeconds(4));
        }
        catch { return false; }
    }

    public async Task<ReaperBridgeResult> ExecuteAsync(
        ReaperBridgeRequest request,
        TimeSpan? timeout = null,
        CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (!double.IsFinite(request.SelectionStart) || !double.IsFinite(request.SelectionEnd)
            || request.SelectionStart < 0 || request.SelectionEnd < request.SelectionStart)
            throw new ArgumentException("REAPER Bridge selection must be a finite, ordered range.", nameof(request));
        var duration = timeout ?? TimeSpan.FromSeconds(6);
        if (duration <= TimeSpan.Zero) throw new ArgumentOutOfRangeException(nameof(timeout));
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
        var elapsed = Stopwatch.StartNew();
        try
        {
            await File.WriteAllTextAsync(tempPath, Serialize(values), new UTF8Encoding(false), cancellationToken);
            cancellationToken.ThrowIfCancellationRequested();
            File.Move(tempPath, requestPath);

            while (elapsed.Elapsed < duration)
            {
                cancellationToken.ThrowIfCancellationRequested();
                if (File.Exists(responsePath))
                {
                    string payload;
                    try
                    {
                        await using var input = new FileStream(responsePath, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, true);
                        if (input.Length > 256 * 1024)
                            throw new InvalidDataException("REAPER Bridge response exceeds the size limit.");
                        using var reader = new StreamReader(input, Encoding.UTF8);
                        payload = await reader.ReadToEndAsync(cancellationToken);
                    }
                    catch (IOException) { await Task.Delay(35, cancellationToken); continue; }
                    var response = Parse(payload);
                    if (Get(response, "id") != id)
                        throw new InvalidDataException("REAPER Bridge response identity does not match the request.");
                    return new ReaperBridgeResult(
                        ParseBool(response, "success"), Get(response, "message"), Get(response, "action"), Get(response, "asset"),
                        Get(response, "inserted"), Get(response, "project_path"), Get(response, "project_name"), Get(response, "track_name"),
                        ParseInt(response, "track_index", -1), ParseDouble(response, "position"));
                }
                await Task.Delay(50, cancellationToken);
            }
            return new ReaperBridgeResult(false, "REAPER Bridge timeout", request.Action, request.AssetPath, request.MediaPath, "", "", "", -1, 0);
        }
        finally
        {
            // Cancelling before REAPER consumes the file must not leave a
            // command that could execute on a later reconnect.
            foreach (var path in new[] { tempPath, requestPath, responsePath })
                try { File.Delete(path); } catch { }
        }
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
            if (values.ContainsKey(line[..split])) throw new InvalidDataException("REAPER Bridge response contains a duplicate field.");
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
    private static double ParseDouble(IReadOnlyDictionary<string, string> values, string key)
    {
        if (values.TryGetValue(key, out var value) && double.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out var parsed)
            && double.IsFinite(parsed)) return parsed;
        throw new InvalidDataException("REAPER Bridge response contains an invalid numeric field: " + key);
    }
}
