using System.Diagnostics;
using System.Buffers.Binary;
using System.Security.Cryptography;
using NAudio.Wave;
using PsyReaSFX.Desktop;
using PsyReaSFX.Desktop.Services;
using PsyReaSFX.Data;
using PsyReaSFX.NeuralSidecar;
using Microsoft.Data.Sqlite;

// A console entry tests the production services without starting WPF, opening
// audio devices, restoring user data or communicating with a real REAPER.
if (args.Contains("-c:a") || args.Contains("pipe:1"))
{
    var pidPath = Environment.GetEnvironmentVariable("PSYREASFX_TEST_ENCODER_PID");
    if (pidPath is not null) File.WriteAllText(pidPath, Environment.ProcessId.ToString());
    var mode = Environment.GetEnvironmentVariable("PSYREASFX_TEST_ENCODER_MODE");
    if (args.Contains("pipe:1"))
    {
        if (mode == "decoder-stderr")
        {
            Console.Error.Write(new string('E', 256 * 1024));
            return 1;
        }
        using var pipe = Console.OpenStandardOutput();
        if (mode == "decoder-truncated")
        {
            pipe.Write([1, 2, 3]);
            return 0;
        }
        if (mode == "decoder-pcm")
        {
            var bytes = new byte[4 * 4];
            var samples = new[] { .25f, float.NaN, 2f, -2f };
            for (var index = 0; index < samples.Length; index++)
                BinaryPrimitives.WriteSingleLittleEndian(bytes.AsSpan(index * 4), samples[index]);
            // Float boundaries deliberately cross read boundaries.
            pipe.Write(bytes, 0, 3);
            pipe.Flush();
            await Task.Delay(80);
            pipe.Write(bytes, 3, bytes.Length - 3);
            return 0;
        }
        pipe.Write(new byte[32768]);
        pipe.Flush();
        await Task.Delay(30000);
        return 0;
    }
    File.WriteAllBytes(args[^1], [99, 88, 77]);
    if (mode == "stderr")
    {
        Console.Error.Write(new string('E', 256 * 1024));
        return 1;
    }
    await Task.Delay(30000);
    return 0;
}

var root = Path.Combine(Path.GetTempPath(), "PsyReaSFX-core-selftest-" + Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(root);
AppDiagnostics.ConfigureDirectory(Path.Combine(root, "logs"));
try
{
    await Check("resource conflicts preserve the previous job", TestJobReplacement);
    await Check("cancelled bridge requests leave no live queue entries", TestBridgeCancellation);
    await Check("invalid bridge responses fail before delivery", TestBridgeResponses);
    await Check("source audio survives overwrite exports", TestTransferSources);
    await Check("running exports keep captured settings", TestCapturedTransfer);
    await Check("cancelled and non-finite exports create no files", TestTransferBoundary);
    await Check("non-finite variant parameters are rejected", TestVariantNumbers);
    await Check("encoder stderr cannot deadlock or replace a valid output", () => TestEncoder("stderr"));
    await Check("encoder cancellation kills the child and preserves outputs", () => TestEncoder("cancel"));
    foreach (var mode in new[] { "pcm", "truncated", "stderr", "cancel" })
        await Check("decoder pipe " + mode, () => TestDecoderPipe(mode));
    await Check("failed restores preserve the current catalog and valid rollback copy", TestCatalogRestore);
    Console.WriteLine("Desktop core services: all regressions passed");
    return 0;
}
catch (Exception error)
{
    Console.Error.WriteLine(error);
    return 1;
}
finally
{
    try { Directory.Delete(root, true); } catch { }
}

static void Require(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
}
static async Task Check(string name, Func<Task> test)
{
    await test();
    Console.WriteLine("PASS " + name);
}

static Task TestJobReplacement()
{
    var jobs = new BackgroundJobCoordinator();
    using var previous = jobs.StartReplacing(BackgroundJobKind.Preview, BackgroundJobResource.PreviewEngine);
    using var blocker = jobs.StartReplacing(BackgroundJobKind.Maintenance, BackgroundJobResource.Maintenance);
    var replacement = jobs.TryStart(BackgroundJobKind.Preview, BackgroundJobResource.Maintenance, true);
    replacement?.Dispose();
    Require(replacement is null && previous.IsCurrent && !previous.Token.IsCancellationRequested,
        "A rejected replacement cancelled the previous job.");
    return Task.CompletedTask;
}

async Task TestBridgeCancellation()
{
    var bridge = new ReaperBridgeService(Path.Combine(root, "bridge"));
    using var cancellation = new CancellationTokenSource();
    var request = bridge.ExecuteAsync(new ReaperBridgeRequest("ping", "", "", "fixture"),
        TimeSpan.FromSeconds(10), cancellation.Token);
    await WaitUntil(() => Directory.Exists(bridge.RequestsDirectory)
        && Directory.EnumerateFiles(bridge.RequestsDirectory, "*.request").Any());
    cancellation.Cancel();
    try { await request; throw new InvalidOperationException("Cancelled bridge call completed successfully."); }
    catch (OperationCanceledException) { }
    Require(!Directory.EnumerateFiles(bridge.RequestsDirectory).Any(),
        "A cancelled bridge call left a request that REAPER could execute later.");
    var preCancelled = new ReaperBridgeService(Path.Combine(root, "bridge-pre-cancelled"));
    try
    {
        await preCancelled.ExecuteAsync(new ReaperBridgeRequest("ping", "", "", "fixture"),
            TimeSpan.FromSeconds(10), cancellation.Token);
        throw new InvalidOperationException("A pre-cancelled bridge request was accepted.");
    }
    catch (OperationCanceledException) { }
    Require(!Directory.Exists(preCancelled.RequestsDirectory), "Pre-cancellation must create no queue files.");
}

async Task TestBridgeResponses()
{
    foreach (var mode in new[] { "identity", "oversized", "number", "duplicate" })
    {
        var bridge = new ReaperBridgeService(Path.Combine(root, "bridge-response-" + mode));
        var call = bridge.PingAsync();
        await WaitUntil(() => Directory.Exists(bridge.RequestsDirectory)
            && Directory.EnumerateFiles(bridge.RequestsDirectory, "*.request").Any());
        var request = Directory.EnumerateFiles(bridge.RequestsDirectory, "*.request").Single();
        var id = Path.GetFileNameWithoutExtension(request);
        var response = Path.Combine(bridge.ResponsesDirectory, id + ".response");
        var payload = mode switch
        {
            "identity" => "id=another-request\nsuccess=1\nposition=0\n",
            "oversized" => new string('X', 256 * 1024 + 1),
            "number" => "id=" + id + "\nsuccess=1\nposition=NaN\n",
            _ => "id=" + id + "\nsuccess=0\nsuccess=1\nposition=0\n"
        };
        await File.WriteAllTextAsync(response + ".tmp", payload);
        File.Move(response + ".tmp", response);
        try
        {
            await call.WaitAsync(TimeSpan.FromSeconds(1));
            throw new InvalidOperationException("An invalid bridge response was accepted: " + mode);
        }
        catch (InvalidDataException) { }
        Require(!Directory.EnumerateFiles(bridge.RequestsDirectory).Any()
            && !Directory.EnumerateFiles(bridge.ResponsesDirectory).Any(),
            "A rejected bridge response left queue files: " + mode);
    }
}

async Task TestTransferSources()
{
    var directory = Path.Combine(root, "source protection");
    Directory.CreateDirectory(directory);
    var source = Path.Combine(directory, "fixture.wav");
    WriteWave(source);
    var before = SHA256.HashData(await File.ReadAllBytesAsync(source));
    var asset = new AudioAsset { FilePath = source, FileName = Path.GetFileName(source) };
    var options = new TransferOptions { OutputDirectory = directory, NamingTemplate = "{name}",
        CollisionPolicy = "overwrite", PreserveMetadata = false, Gain = -12 };
    var variant = new TransferVariant(0, 1, -12, false, 1);
    var result = await new TransferEngine().RunAsync(
        [new TransferRequest(asset, -1, -1, variant, 1)], options, null, CancellationToken.None);
    Require(before.SequenceEqual(SHA256.HashData(await File.ReadAllBytesAsync(source))),
        "An overwrite export changed its source audio.");
    Require(result.FailedCount == 1 || result.Items[0].OutputPath != source,
        "An export must reject or rename a protected source target.");
    var other = Path.Combine(directory, "other.wav");
    WriteWave(other);
    var otherHash = SHA256.HashData(await File.ReadAllBytesAsync(other));
    options.NamingTemplate = "other";
    options.SourcePaths = [other];
    result = await new TransferEngine().RunAsync([new TransferRequest(asset, -1, -1, variant, 1)], options, null, CancellationToken.None);
    Require(result.FailedCount == 1 && otherHash.SequenceEqual(SHA256.HashData(await File.ReadAllBytesAsync(other))),
        "An overwrite export replaced another catalog asset.");
}

async Task TestCapturedTransfer()
{
    var directory = Path.Combine(root, "captured-export");
    Directory.CreateDirectory(directory);
    var source = Path.Combine(directory, "fixture.wav");
    WriteWave(source);
    var laterSource = Path.Combine(directory, "later.wav");
    WriteWave(laterSource);
    var output = Path.Combine(directory, "output");
    var changed = Path.Combine(directory, "later-edit");
    var asset = new AudioAsset { FilePath = source, FileName = "fixture.wav", LibraryName = "batch" };
    var options = new TransferOptions { OutputDirectory = output, NamingTemplate = "{name}_{library}", PreserveMetadata = false };
    var progress = new InlineProgress<TransferProgress>(_ =>
    {
        options.OutputDirectory = changed;
        options.NamingTemplate = "changed";
        options.FadeInMs = double.NaN;
        asset.FilePath = laterSource;
        asset.FileName = "later.wav";
        asset.LibraryName = "edited";
    });
    var result = await new TransferEngine().RunAsync(
        [new TransferRequest(asset, -1, -1, new(0, 1, 0, false, 1), 1)],
        options, progress, CancellationToken.None);
    Require(result.SuccessCount == 1 && result.LastOutput == Path.Combine(output, "fixture_batch.wav")
        && result.Items[0].SourcePath == source && !Directory.Exists(changed),
        "Later UI edits changed a running export's source, destination or parameters.");
}

async Task TestTransferBoundary()
{
    var directory = Path.Combine(root, "invalid-export");
    var options = new TransferOptions { OutputDirectory = directory, FadeInMs = double.NaN };
    var requests = new[] { new TransferRequest(new AudioAsset { FilePath = "fixture.wav" }, -1, -1, new(0, 1, 0, false, 1), 1) };
    try { await new TransferEngine().RunAsync(requests, options, null, CancellationToken.None); throw new InvalidOperationException("NaN fade accepted."); }
    catch (ArgumentOutOfRangeException) { }
    using var cancellation = new CancellationTokenSource();
    cancellation.Cancel();
    try { await new TransferEngine().RunAsync(requests, options, null, cancellation.Token); throw new InvalidOperationException("Pre-cancelled export accepted."); }
    catch (OperationCanceledException) { }
    Require(!Directory.Exists(directory), "Invalid or pre-cancelled exports created an output directory.");
}

async Task TestDecoderPipe(string mode)
{
    var directory = Path.Combine(root, "decoder-" + mode);
    Directory.CreateDirectory(directory);
    var fakeEncoder = Path.Combine(AppContext.BaseDirectory, "ffmpeg.exe");
    File.Copy(Environment.ProcessPath!, fakeEncoder, false);
    var pidFile = Path.Combine(directory, "child.pid");
    Environment.SetEnvironmentVariable("PSYREASFX_TEST_ENCODER_PID", pidFile);
    Environment.SetEnvironmentVariable("PSYREASFX_TEST_ENCODER_MODE", "decoder-" + mode);
    using var cancellation = new CancellationTokenSource();
    Task<DecodedAudio>? task = null;
    int? childId = null;
    try
    {
        task = Task.Run(() => AudioDecoder.DecodeWithFfmpeg("isolated-fixture", fakeEncoder, () => cancellation.IsCancellationRequested));
        await WaitUntil(() => File.Exists(pidFile));
        childId = int.Parse(await File.ReadAllTextAsync(pidFile));
        if (mode == "cancel") cancellation.Cancel();
        try
        {
            var result = await task.WaitAsync(TimeSpan.FromSeconds(5));
            Require(mode == "pcm" && result.Samples.SequenceEqual(new[] { .25f, 0f, 1f, -1f }),
                "Decoder did not preserve split float samples and sanitize non-finite values.");
        }
        catch (InvalidDataException) when (mode is "truncated" or "stderr") { }
        catch (OperationCanceledException) when (mode == "cancel") { }
        await WaitUntil(() => !IsRunning(childId.Value));
    }
    finally
    {
        cancellation.Cancel();
        if (childId is int pid && IsRunning(pid))
        {
            using var child = Process.GetProcessById(pid);
            child.Kill(true);
            await child.WaitForExitAsync();
        }
        if (task is not null) try { await task.WaitAsync(TimeSpan.FromSeconds(5)); } catch { }
        Environment.SetEnvironmentVariable("PSYREASFX_TEST_ENCODER_PID", null);
        Environment.SetEnvironmentVariable("PSYREASFX_TEST_ENCODER_MODE", null);
        File.Delete(fakeEncoder);
    }
}

async Task TestCatalogRestore()
{
    var directory = Path.Combine(root, "restore");
    var database = new PsyReaSFXDatabase(directory);
    await database.InitializeAsync();
    var snapshot = new CatalogSnapshot();
    snapshot.Assets.Add(new AssetRecord { Path = Path.Combine(directory, "source.wav"), Name = "source.wav", Description = "backup generation", Ready = true });
    await database.SaveDesktopSnapshotAsync(snapshot);
    var reliability = new CatalogReliabilityService(directory);
    var backup = await reliability.CreateBackupAsync(database.DatabasePath, 3);
    var nextBackup = await reliability.CreateBackupAsync(database.DatabasePath, 3);
    Require(backup != nextBackup && File.Exists(backup), "Rapid backups reused the same destination.");
    Directory.CreateDirectory(reliability.RootDirectory);
    await File.WriteAllTextAsync(reliability.PendingRestorePath, "corrupt restore fixture");
    SqliteConnection.ClearAllPools();
    var originalHash = SHA256.HashData(await File.ReadAllBytesAsync(database.DatabasePath));
    try
    {
        await CatalogReliabilityService.ApplyPendingRestoreAsync(directory);
        throw new InvalidOperationException("A corrupt restore was installed.");
    }
    catch (Exception error) when (error is SqliteException or InvalidDataException) { }
    Require(originalHash.SequenceEqual(SHA256.HashData(await File.ReadAllBytesAsync(database.DatabasePath)))
        && File.Exists(reliability.PendingRestorePath), "A corrupt restore changed the original catalog or lost its recovery input.");

    File.Copy(backup, reliability.PendingRestorePath, true);
    await using (var future = new SqliteConnection(new SqliteConnectionStringBuilder
    {
        DataSource = reliability.PendingRestorePath, Mode = SqliteOpenMode.ReadWrite, Pooling = false
    }.ToString()))
    {
        await future.OpenAsync();
        using var schema = future.CreateCommand();
        schema.CommandText = "UPDATE schema_info SET version = 999";
        await schema.ExecuteNonQueryAsync();
    }
    try
    {
        await CatalogReliabilityService.ApplyPendingRestoreAsync(directory);
        throw new InvalidOperationException("A future-schema restore was installed.");
    }
    catch (InvalidDataException) { }
    Require(originalHash.SequenceEqual(SHA256.HashData(await File.ReadAllBytesAsync(database.DatabasePath)))
        && File.Exists(reliability.PendingRestorePath), "An unsupported restore changed the catalog or lost its recovery input.");

    await reliability.StageRestoreLatestAsync();
    SqliteConnection.ClearAllPools();
    using (var locked = File.Open(database.DatabasePath, FileMode.Open, FileAccess.Read, FileShare.Read))
    {
        try
        {
            await CatalogReliabilityService.ApplyPendingRestoreAsync(directory);
            throw new InvalidOperationException("A locked restore was installed.");
        }
        catch (Exception error) when (error is IOException or SqliteException) { }
    }
    Require(originalHash.SequenceEqual(SHA256.HashData(await File.ReadAllBytesAsync(database.DatabasePath)))
        && File.Exists(reliability.PendingRestorePath), "A locked restore changed the current catalog.");
    await database.SaveAssetDetailsAsync([snapshot.Assets[0] with { Description = "latest generation before restore" }]);
    SqliteConnection.ClearAllPools();
    await CatalogReliabilityService.ApplyPendingRestoreAsync(directory);
    Require(!File.Exists(reliability.PendingRestorePath)
        && (await database.LoadSnapshotAsync()).Assets.Single().Description == "backup generation",
        "A valid restore did not commit its staged backup.");
    var previous = database.DatabasePath + ".before-restore";
    Require(await PsyReaSFXDatabase.CheckIntegrityAsync(previous) == "ok", "The rollback catalog is invalid.");
    await using (var rollback = new SqliteConnection(new SqliteConnectionStringBuilder
    {
        DataSource = previous, Mode = SqliteOpenMode.ReadOnly, Pooling = false
    }.ToString()))
    {
        await rollback.OpenAsync();
        using var value = rollback.CreateCommand();
        value.CommandText = "SELECT description FROM assets LIMIT 1";
        Require((string?)await value.ExecuteScalarAsync() == "latest generation before restore",
            "The rollback copy lost the latest committed WAL generation.");
    }
    Require(!Directory.EnumerateFiles(directory, "*.tmp", SearchOption.AllDirectories).Any(),
        "Failed restores left incomplete staged databases.");
    SqliteConnection.ClearAllPools();
}

static Task TestVariantNumbers()
{
    foreach (var value in new[] { "NaN", "Infinity", "-Infinity", "1e999" })
    {
        try
        {
            TransferEngine.BuildVariants(new TransferOptions { VariantsEnabled = true, VariantPitches = value });
            throw new InvalidOperationException("Accepted non-finite variant: " + value);
        }
        catch (InvalidOperationException error) when (error.Message.StartsWith("Invalid variant value")) { }
    }
    return Task.CompletedTask;
}

async Task TestEncoder(string mode)
{
    var directory = Path.Combine(root, mode);
    Directory.CreateDirectory(directory);
    var source = Path.Combine(directory, "source.wav");
    WriteWave(source);
    var output = Path.Combine(directory, "export.flac");
    await File.WriteAllTextAsync(output, "valid previous output");
    var original = await File.ReadAllBytesAsync(output);
    var pidFile = Path.Combine(directory, "encoder.pid");
    // The renamed apphost still launches this test's embedded DLL. No external
    // encoder or installed application is modified by the fixture.
    var fakeEncoder = Path.Combine(AppContext.BaseDirectory, "ffmpeg.exe");
    File.Copy(Environment.ProcessPath!, fakeEncoder, false);
    var oldPath = Environment.GetEnvironmentVariable("PATH");
    Environment.SetEnvironmentVariable("PATH", AppContext.BaseDirectory + Path.PathSeparator + oldPath);
    Environment.SetEnvironmentVariable("PSYREASFX_TEST_ENCODER_PID", pidFile);
    Environment.SetEnvironmentVariable("PSYREASFX_TEST_ENCODER_MODE", mode);
    int? childId = null;
    try
    {
        using var cancellation = new CancellationTokenSource();
        var task = new TransferEngine().RunAsync(
            [new TransferRequest(new AudioAsset { FilePath = source }, -1, -1, new(0, 1, 0, false, 1), 1)],
            new TransferOptions { OutputDirectory = directory, NamingTemplate = "export", Format = "flac",
                PreserveMetadata = false, CollisionPolicy = "overwrite" }, null, cancellation.Token);
        await WaitUntil(() => File.Exists(pidFile));
        childId = int.Parse(await File.ReadAllTextAsync(pidFile));
        if (mode == "cancel") cancellation.Cancel();
        try
        {
            var result = await task.WaitAsync(TimeSpan.FromSeconds(4));
            Require(mode == "stderr" && result.FailedCount == 1, "Encoder failure was not reported.");
        }
        catch (OperationCanceledException) when (mode == "cancel") { }
        Require(original.SequenceEqual(await File.ReadAllBytesAsync(output)), "Encoder failure replaced an existing output.");
        await WaitUntil(() => !IsRunning(childId.Value));
        Require(!Directory.Exists(Path.Combine(directory, ".psyreasfx-transfer")), "Cancelled encoder left staged media.");
    }
    finally
    {
        if (childId is int pid && IsRunning(pid))
        {
            using var child = Process.GetProcessById(pid);
            child.Kill(true);
            await child.WaitForExitAsync();
        }
        Environment.SetEnvironmentVariable("PATH", oldPath);
        Environment.SetEnvironmentVariable("PSYREASFX_TEST_ENCODER_PID", null);
        Environment.SetEnvironmentVariable("PSYREASFX_TEST_ENCODER_MODE", null);
        File.Delete(fakeEncoder);
    }
}

static bool IsRunning(int pid)
{
    try { using var process = Process.GetProcessById(pid); return !process.HasExited; }
    catch (ArgumentException) { return false; }
}
static async Task WaitUntil(Func<bool> ready)
{
    var clock = Stopwatch.StartNew();
    while (!ready())
    {
        Require(clock.Elapsed < TimeSpan.FromSeconds(8), "Fixture timed out.");
        await Task.Delay(15);
    }
}
static void WriteWave(string path)
{
    using var writer = new WaveFileWriter(path, new WaveFormat(48000, 16, 1));
    for (var index = 0; index < 4800; index++) writer.WriteSample((float)(0.25 * Math.Sin(index * 0.1)));
}

sealed class InlineProgress<T>(Action<T> report) : IProgress<T>
{
    public void Report(T value) => report(value);
}
