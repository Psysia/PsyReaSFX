namespace PsyReaSFX.Desktop.Services;

public enum BackgroundJobKind
{
    CatalogScan,
    Preview,
    LoudnessAnalysis,
    SelectionDrag,
    CatalogSave,
    Maintenance
}

[Flags]
public enum BackgroundJobResource
{
    None = 0,
    CatalogWriter = 1,
    PreviewEngine = 2,
    AudioAnalysis = 4,
    DragExport = 8,
    Maintenance = 16
}

public enum BackgroundJobState
{
    Waiting,
    Running,
    Cancelling,
    Completed,
    Cancelled,
    Failed
}

public enum BackgroundJobPriority
{
    Idle = 0,
    Background = 10,
    Normal = 50,
    UserInitiated = 100,
    Realtime = 200
}

public sealed record BackgroundJobSnapshot(
    BackgroundJobKind Kind,
    long Generation,
    BackgroundJobPriority Priority,
    BackgroundJobState State,
    DateTimeOffset StartedUtc,
    DateTimeOffset? FinishedUtc,
    string? Error);

/// <summary>
/// Owns cancellation generations and exclusive background resources. The
/// coordinator requests cancellation but never disposes another operation's
/// token source; the lease owner does that after its awaits have unwound.
/// </summary>
public sealed class BackgroundJobCoordinator
{
    private readonly object _gate = new();
    private readonly Dictionary<BackgroundJobKind, BackgroundJobLease> _current = [];
    private readonly Dictionary<long, BackgroundJobLease> _active = [];
    private readonly Queue<BackgroundJobSnapshot> _history = new();
    private TaskCompletionSource _idle = CompletedIdleSource();
    private long _generation;
    private bool _accepting = true;

    public BackgroundJobLease? TryStart(
        BackgroundJobKind kind,
        BackgroundJobResource resource,
        bool replaceSameKind,
        BackgroundJobPriority priority = BackgroundJobPriority.Normal)
    {
        lock (_gate)
        {
            if (!_accepting) return null;

            if (_current.TryGetValue(kind, out var previous))
            {
                if (!replaceSameKind) return null;
                previous.RequestCancellation();
            }

            if (_active.Values.Any(job =>
                    job.Kind != kind &&
                    resource != BackgroundJobResource.None &&
                    (job.Resource & resource) != 0))
                return null;

            if (_active.Count == 0)
                _idle = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);

            var lease = new BackgroundJobLease(
                this,
                kind,
                resource,
                priority,
                Interlocked.Increment(ref _generation));
            _active[lease.Generation] = lease;
            _current[kind] = lease;
            return lease;
        }
    }

    public BackgroundJobLease StartReplacing(
        BackgroundJobKind kind,
        BackgroundJobResource resource,
        BackgroundJobPriority priority = BackgroundJobPriority.Normal)
        => TryStart(kind, resource, true, priority)
           ?? throw new InvalidOperationException($"Background job {kind} cannot start because its resource is busy or shutdown has begun.");

    public bool IsActive(BackgroundJobKind kind)
    {
        lock (_gate) return _current.ContainsKey(kind);
    }

    public void Cancel(BackgroundJobKind kind)
    {
        lock (_gate)
            if (_current.TryGetValue(kind, out var lease)) lease.RequestCancellation();
    }

    public Task StopAcceptingAndCancelAsync(TimeSpan timeout)
    {
        Task idleTask;
        lock (_gate)
        {
            _accepting = false;
            foreach (var lease in _active.Values) lease.RequestCancellation();
            idleTask = _idle.Task;
        }
        return WaitWithTimeoutAsync(idleTask, timeout);
    }

    public IReadOnlyList<BackgroundJobSnapshot> Snapshot()
    {
        lock (_gate)
            return _active.Values.Select(job => job.ToSnapshot()).Concat(_history).ToArray();
    }

    internal bool IsCurrent(BackgroundJobLease lease)
    {
        lock (_gate)
            return _current.TryGetValue(lease.Kind, out var current) && ReferenceEquals(current, lease);
    }

    internal void Complete(BackgroundJobLease lease, BackgroundJobState state, Exception? error)
    {
        lock (_gate)
        {
            _active.Remove(lease.Generation);
            if (_current.TryGetValue(lease.Kind, out var current) && ReferenceEquals(current, lease))
                _current.Remove(lease.Kind);

            _history.Enqueue(lease.ToSnapshot(state, error));
            while (_history.Count > 64) _history.Dequeue();
            if (_active.Count == 0) _idle.TrySetResult();
        }
    }

    private static async Task WaitWithTimeoutAsync(Task idle, TimeSpan timeout)
    {
        using var timeoutSource = new CancellationTokenSource(timeout);
        try { await idle.WaitAsync(timeoutSource.Token); }
        catch (OperationCanceledException) when (timeoutSource.IsCancellationRequested) { }
    }

    private static TaskCompletionSource CompletedIdleSource()
    {
        var result = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        result.SetResult();
        return result;
    }
}

public sealed class BackgroundJobLease : IDisposable
{
    private readonly BackgroundJobCoordinator _owner;
    private readonly CancellationTokenSource _cancellation = new();
    private int _disposed;
    private BackgroundJobState _state = BackgroundJobState.Running;
    private Exception? _error;

    internal BackgroundJobLease(
        BackgroundJobCoordinator owner,
        BackgroundJobKind kind,
        BackgroundJobResource resource,
        BackgroundJobPriority priority,
        long generation)
    {
        _owner = owner;
        Kind = kind;
        Resource = resource;
        Priority = priority;
        Generation = generation;
        StartedUtc = DateTimeOffset.UtcNow;
    }

    public BackgroundJobKind Kind { get; }
    public BackgroundJobResource Resource { get; }
    public BackgroundJobPriority Priority { get; }
    public long Generation { get; }
    public DateTimeOffset StartedUtc { get; }
    public CancellationToken Token => _cancellation.Token;
    public bool IsCurrent => _owner.IsCurrent(this) && !Token.IsCancellationRequested;

    public void MarkFailed(Exception error)
    {
        _error = error;
        _state = BackgroundJobState.Failed;
    }

    internal void RequestCancellation()
    {
        if (_state == BackgroundJobState.Running) _state = BackgroundJobState.Cancelling;
        try { _cancellation.Cancel(); }
        catch (ObjectDisposedException) { }
    }

    internal BackgroundJobSnapshot ToSnapshot() => ToSnapshot(_state, _error, null);

    internal BackgroundJobSnapshot ToSnapshot(BackgroundJobState state, Exception? error) =>
        ToSnapshot(state, error, DateTimeOffset.UtcNow);

    private BackgroundJobSnapshot ToSnapshot(BackgroundJobState state, Exception? error, DateTimeOffset? finished) =>
        new(Kind, Generation, Priority, state, StartedUtc, finished, error?.Message);

    public void Dispose()
    {
        if (Interlocked.Exchange(ref _disposed, 1) != 0) return;
        var finalState = _state switch
        {
            BackgroundJobState.Failed => BackgroundJobState.Failed,
            BackgroundJobState.Cancelling => BackgroundJobState.Cancelled,
            _ when _cancellation.IsCancellationRequested => BackgroundJobState.Cancelled,
            _ => BackgroundJobState.Completed
        };
        _owner.Complete(this, finalState, _error);
        _cancellation.Dispose();
    }
}
