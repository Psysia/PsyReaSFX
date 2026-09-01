namespace PsyReaSFX.Desktop.Services;

/// <summary>
/// Owns preview job replacement and cancellation. The audio engine only owns
/// device/DSP resources; callers no longer create competing preview leases.
/// </summary>
public sealed class PreviewController : IPreviewController
{
    private readonly IJobCoordinator _jobs;
    private readonly IPreviewEngine _engine;
    private bool _disposed;

    public PreviewController(IJobCoordinator jobs, IPreviewEngine engine)
    {
        _jobs = jobs;
        _engine = engine;
    }

    public event EventHandler? PlaybackEnded
    {
        add => _engine.PlaybackEnded += value;
        remove => _engine.PlaybackEnded -= value;
    }

    public event EventHandler<Exception>? PlaybackFailed
    {
        add => _engine.PlaybackFailed += value;
        remove => _engine.PlaybackFailed -= value;
    }

    public bool IsOpen => _engine.IsOpen;
    public bool IsPlaying => _engine.IsPlaying;
    public string Path => _engine.Path;
    public double Duration => _engine.Duration;
    public double Position { get => _engine.Position; set => _engine.Position = value; }
    public double Rate { get => _engine.Rate; set => _engine.Rate = value; }
    public double PitchSemitones { get => _engine.PitchSemitones; set => _engine.PitchSemitones = value; }
    public double GainDb { get => _engine.GainDb; set => _engine.GainDb = value; }
    public bool PreservePitch { get => _engine.PreservePitch; set => _engine.PreservePitch = value; }
    public bool Reverse => _engine.Reverse;
    public IReadOnlyList<int> AuditionChannels => _engine.AuditionChannels;

    public void SetAuditionChannels(IReadOnlyList<int>? auditionChannels) =>
        _engine.SetAuditionChannels(auditionChannels);

    public Task<bool> OpenAsync(
        string path,
        double sourcePosition,
        bool autoplay,
        CancellationToken cancellationToken = default) =>
        RunReplacingAsync(token => _engine.OpenAsync(path, sourcePosition, autoplay, token), cancellationToken,
            BackgroundJobPriority.Realtime);

    public Task<bool> ReconfigureAsync(
        bool reverse,
        IReadOnlyList<int>? auditionChannels = null,
        CancellationToken cancellationToken = default) =>
        RunReplacingAsync(token => _engine.ReconfigureAsync(reverse, auditionChannels, token), cancellationToken,
            BackgroundJobPriority.UserInitiated);

    public void Play()
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        _engine.Play();
    }

    public Task PauseAsync(CancellationToken cancellationToken = default)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        return _engine.PauseAsync(cancellationToken);
    }

    public async Task StopAsync(CancellationToken cancellationToken = default)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        _jobs.Cancel(BackgroundJobKind.Preview);
        await _engine.StopAsync(cancellationToken);
    }

    private async Task<bool> RunReplacingAsync(
        Func<CancellationToken, Task> operation,
        CancellationToken externalToken,
        BackgroundJobPriority priority)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        using var job = _jobs.TryStart(
            BackgroundJobKind.Preview,
            BackgroundJobResource.PreviewEngine,
            true,
            priority);
        if (job == null) return false;
        using var linked = CancellationTokenSource.CreateLinkedTokenSource(job.Token, externalToken);
        try
        {
            await operation(linked.Token);
            return !linked.IsCancellationRequested && job.IsCurrent;
        }
        catch (OperationCanceledException) when (linked.IsCancellationRequested)
        {
            return false;
        }
        catch (Exception exception)
        {
            job.MarkFailed(exception);
            throw;
        }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        _jobs.Cancel(BackgroundJobKind.Preview);
        _engine.Dispose();
    }
}
