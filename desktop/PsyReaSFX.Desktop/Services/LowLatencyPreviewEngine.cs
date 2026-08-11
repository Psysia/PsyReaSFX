using NAudio.Wave;
using NAudio.Wave.SampleProviders;

namespace PsyReaSFX.Desktop.Services;

/// <summary>
/// Independent, low-latency audition path. All public positions are expressed
/// on the source timeline so the UI, loop selection and waveform stay aligned
/// even while rate processing is active.
/// </summary>
public sealed class LowLatencyPreviewEngine : IDisposable
{
    private readonly object _gate = new();
    private IWavePlayer? _output;
    private WaveStream? _reader;
    private RateSampleProvider? _rateProvider;
    private SmbPitchShiftingSampleProvider? _pitchProvider;
    private VolumeSampleProvider? _volumeProvider;
    private FadeInOutSampleProvider? _fadeProvider;
    private string _path = "";
    private int _openGeneration;
    private bool _closing;
    private bool _reverse;
    private bool _preservePitch = true;
    private double _rate = 1;
    private double _pitchSemitones;
    private double _gainDb;
    private IReadOnlyList<int> _auditionChannels = [];
    private double _sourceStartPosition;

    public event EventHandler? PlaybackEnded;
    public event EventHandler<Exception>? PlaybackFailed;

    public bool IsOpen => _reader != null;
    public bool IsPlaying => _output?.PlaybackState == PlaybackState.Playing;
    public string Path => _path;
    public double Duration => _reader?.TotalTime.TotalSeconds ?? 0;
    public double Position
    {
        get
        {
            if (_reader == null) return 0;
            if (_reverse) return Math.Clamp(Duration - (_sourceStartPosition + (_rateProvider?.SourceSeconds ?? 0)), 0, Duration);
            return Math.Clamp(_sourceStartPosition + (_rateProvider?.SourceSeconds ?? 0), 0, Duration);
        }
        set
        {
            lock (_gate)
            {
                if (_reader == null) return;
                _reader.CurrentTime = TimeSpan.FromSeconds(Math.Clamp(value, 0, Duration));
                _sourceStartPosition = Math.Clamp(value, 0, Duration);
                _rateProvider?.Reset();
            }
        }
    }

    public double Rate
    {
        get => _rate;
        set
        {
            _rate = Math.Clamp(value, .25, 4);
            if (_rateProvider != null) _rateProvider.Rate = _rate;
            UpdatePitchFactor();
        }
    }

    public double PitchSemitones
    {
        get => _pitchSemitones;
        set { _pitchSemitones = Math.Clamp(value, -24, 24); UpdatePitchFactor(); }
    }

    public double GainDb
    {
        get => _gainDb;
        set
        {
            _gainDb = Math.Clamp(value, -36, 18);
            if (_volumeProvider != null) _volumeProvider.Volume = DbToAmplitude(_gainDb);
        }
    }

    public bool PreservePitch
    {
        get => _preservePitch;
        set { _preservePitch = value; UpdatePitchFactor(); }
    }

    public bool Reverse => _reverse;
    public IReadOnlyList<int> AuditionChannels => _auditionChannels;

    public void SetAuditionChannels(IReadOnlyList<int>? auditionChannels)
    {
        // Keep the next OpenAsync call in sync with the channel selector even
        // when no preview is currently open. ReconfigureAsync still performs
        // the audible hot-swap for an already-open source.
        _auditionChannels = auditionChannels?.Where(channel => channel >= 0).Distinct().Order().ToArray() ?? [];
    }

    public async Task OpenAsync(string path, double sourcePosition, bool autoplay, CancellationToken cancellationToken = default)
    {
        var generation = Interlocked.Increment(ref _openGeneration);
        await FadeOutAsync(14, cancellationToken);
        var prepared = await Task.Run(() => Prepare(path, cancellationToken), cancellationToken);
        if (generation != _openGeneration) { prepared.Reader.Dispose(); return; }

        lock (_gate)
        {
            CloseCore();
            _path = path;
            _reader = prepared.Reader;
            _sourceStartPosition = Math.Clamp(sourcePosition, 0, prepared.Reader.TotalTime.TotalSeconds);
            _reader.CurrentTime = TimeSpan.FromSeconds(_reverse ? 0 : _sourceStartPosition);
            BuildPipeline(prepared.Provider);
            if (autoplay)
            {
                _fadeProvider?.BeginFadeIn(18);
                _output?.Play();
            }
        }
    }

    public async Task ReconfigureAsync(bool reverse, IReadOnlyList<int>? auditionChannels = null, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_path)) return;
        var position = Position;
        var playing = IsPlaying;
        _reverse = reverse;
        SetAuditionChannels(auditionChannels);
        await OpenAsync(_path, position, playing, cancellationToken);
    }

    public void Play()
    {
        _fadeProvider?.BeginFadeIn(14);
        _output?.Play();
    }

    public async Task PauseAsync(CancellationToken cancellationToken = default)
    {
        await FadeOutAsync(14, cancellationToken);
        lock (_gate) _output?.Pause();
    }

    public async Task StopAsync(CancellationToken cancellationToken = default)
    {
        await FadeOutAsync(18, cancellationToken);
        lock (_gate)
        {
            _closing = true;
            _output?.Stop();
            _closing = false;
            Position = 0;
        }
    }

    public void Dispose()
    {
        Interlocked.Increment(ref _openGeneration);
        lock (_gate) CloseCore();
    }

    private (WaveStream Reader, ISampleProvider Provider) Prepare(string path, CancellationToken token)
    {
        token.ThrowIfCancellationRequested();
        WaveStream reader;
        try { reader = new NAudio.Wave.AudioFileReader(path); }
        catch { reader = new MediaFoundationReader(path); }
        var source = reader.ToSampleProvider();
        ISampleProvider provider = new AuditionChannelSampleProvider(source, _auditionChannels);
        if (_reverse)
        {
            var maximumSamples = 24_000_000;
            provider = BufferedReverseSampleProvider.Create(provider, maximumSamples, token);
        }
        return (reader, provider);
    }

    private void BuildPipeline(ISampleProvider source)
    {
        // Pitch correction must run on the source before the rate resampler.
        // Applying it after frame skipping leaves the shifter chasing an
        // already-resampled stream and, on several audio devices, made the
        // Preserve Pitch switch sound indistinguishable or unstable.
        _pitchProvider = new SmbPitchShiftingSampleProvider(source);
        _rateProvider = new RateSampleProvider(_pitchProvider) { Rate = _rate };
        _volumeProvider = new VolumeSampleProvider(_rateProvider) { Volume = DbToAmplitude(_gainDb) };
        _fadeProvider = new FadeInOutSampleProvider(_volumeProvider, true);
        UpdatePitchFactor();

        var output = new WaveOutEvent { DesiredLatency = 56, NumberOfBuffers = 4 };
        output.PlaybackStopped += Output_PlaybackStopped;
        output.Init(_fadeProvider.ToWaveProvider());
        _output = output;
    }

    private void UpdatePitchFactor()
    {
        if (_pitchProvider == null) return;
        var independentPitch = Math.Pow(2, _pitchSemitones / 12.0);
        var compensation = _preservePitch ? 1 / Math.Max(.01, _rate) : 1;
        _pitchProvider.PitchFactor = (float)Math.Clamp(independentPitch * compensation, .125, 8);
    }

    private void Output_PlaybackStopped(object? sender, StoppedEventArgs e)
    {
        if (_closing) return;
        if (e.Exception != null) PlaybackFailed?.Invoke(this, e.Exception);
        else if (Position >= Duration - .01) PlaybackEnded?.Invoke(this, EventArgs.Empty);
    }

    private void CloseCore()
    {
        _closing = true;
        if (_output != null) _output.PlaybackStopped -= Output_PlaybackStopped;
        try { _output?.Stop(); } catch { }
        _output?.Dispose();
        _reader?.Dispose();
        _output = null;
        _reader = null;
        _rateProvider = null;
        _pitchProvider = null;
        _volumeProvider = null;
        _fadeProvider = null;
        _closing = false;
    }

    private async Task FadeOutAsync(int milliseconds, CancellationToken cancellationToken)
    {
        FadeInOutSampleProvider? fade;
        bool playing;
        lock (_gate)
        {
            fade = _fadeProvider;
            playing = _output?.PlaybackState == PlaybackState.Playing;
            if (playing) fade?.BeginFadeOut(milliseconds);
        }
        if (playing && fade != null)
            await Task.Delay(milliseconds + 3, cancellationToken);
    }

    private static float DbToAmplitude(double db) => (float)Math.Pow(10, db / 20.0);
}

internal sealed class AuditionChannelSampleProvider : ISampleProvider
{
    private readonly ISampleProvider _source;
    private readonly int[] _selected;
    private float[] _input = [];

    public AuditionChannelSampleProvider(ISampleProvider source, IReadOnlyList<int> selected)
    {
        _source = source;
        _selected = selected.Where(channel => channel >= 0 && channel < source.WaveFormat.Channels).Distinct().ToArray();
        WaveFormat = WaveFormat.CreateIeeeFloatWaveFormat(source.WaveFormat.SampleRate, 2);
    }

    public WaveFormat WaveFormat { get; }

    public int Read(float[] buffer, int offset, int count)
    {
        var requestedFrames = count / 2;
        var inputChannels = _source.WaveFormat.Channels;
        var requestedSamples = requestedFrames * inputChannels;
        if (_input.Length < requestedSamples) _input = new float[requestedSamples];
        var read = _source.Read(_input, 0, requestedSamples);
        var frames = read / inputChannels;
        for (var frame = 0; frame < frames; frame++)
        {
            var input = frame * inputChannels;
            float left;
            float right;
            if (_selected.Length > 0)
            {
                var sum = 0f;
                foreach (var channel in _selected) sum += _input[input + channel];
                left = right = sum / _selected.Length;
            }
            else if (inputChannels == 1)
            {
                left = right = _input[input];
            }
            else if (inputChannels == 2)
            {
                left = _input[input]; right = _input[input + 1];
            }
            else
            {
                var leftSum = 0f; var rightSum = 0f; var leftCount = 0; var rightCount = 0;
                for (var channel = 0; channel < inputChannels; channel++)
                {
                    if ((channel & 1) == 0) { leftSum += _input[input + channel]; leftCount++; }
                    else { rightSum += _input[input + channel]; rightCount++; }
                }
                left = leftSum / Math.Max(1, leftCount);
                right = rightSum / Math.Max(1, rightCount);
            }
            buffer[offset + frame * 2] = left;
            buffer[offset + frame * 2 + 1] = right;
        }
        return frames * 2;
    }
}

internal sealed class RateSampleProvider : ISampleProvider
{
    private readonly ISampleProvider _source;
    private float[] _buffer = [];
    private int _bufferedFrames;
    private double _position;
    private long _consumedFrames;
    public double Rate { get; set; } = 1;
    public WaveFormat WaveFormat => _source.WaveFormat;
    public double SourceSeconds => (_consumedFrames + _position) / Math.Max(1, WaveFormat.SampleRate);

    public RateSampleProvider(ISampleProvider source) => _source = source;

    public int Read(float[] buffer, int offset, int count)
    {
        var channels = WaveFormat.Channels;
        var wantedFrames = count / channels;
        var written = 0;
        while (written < wantedFrames)
        {
            EnsureFrames((int)_position + 2);
            if (_bufferedFrames == 0 || (int)_position >= _bufferedFrames) break;
            var first = (int)_position;
            var second = Math.Min(first + 1, _bufferedFrames - 1);
            var fraction = (float)(_position - first);
            for (var channel = 0; channel < channels; channel++)
            {
                var a = _buffer[first * channels + channel];
                var b = _buffer[second * channels + channel];
                buffer[offset + written * channels + channel] = a + (b - a) * fraction;
            }
            written++;
            _position += Math.Clamp(Rate, .25, 4);
            if (_position > 4096) Compact();
        }
        return written * channels;
    }

    public void Reset() { _bufferedFrames = 0; _position = 0; _consumedFrames = 0; }

    private void EnsureFrames(int frames)
    {
        var channels = WaveFormat.Channels;
        if (_buffer.Length < 16384 * channels) _buffer = new float[16384 * channels];
        while (_bufferedFrames < frames && _bufferedFrames < 16384)
        {
            var read = _source.Read(_buffer, _bufferedFrames * channels, (16384 - _bufferedFrames) * channels);
            if (read <= 0) break;
            _bufferedFrames += read / channels;
        }
    }

    private void Compact()
    {
        var consumed = Math.Min((int)_position, _bufferedFrames);
        if (consumed <= 0) return;
        var channels = WaveFormat.Channels;
        Array.Copy(_buffer, consumed * channels, _buffer, 0, (_bufferedFrames - consumed) * channels);
        _bufferedFrames -= consumed;
        _position -= consumed;
        _consumedFrames += consumed;
    }
}

internal sealed class BufferedReverseSampleProvider : ISampleProvider
{
    private readonly float[] _samples;
    private int _position;
    private BufferedReverseSampleProvider(float[] samples, WaveFormat format) { _samples = samples; WaveFormat = format; _position = samples.Length; }
    public WaveFormat WaveFormat { get; }

    public static BufferedReverseSampleProvider Create(ISampleProvider source, int maximumSamples, CancellationToken token)
    {
        var samples = new List<float>(Math.Min(maximumSamples, source.WaveFormat.SampleRate * source.WaveFormat.Channels * 20));
        var block = new float[16384];
        while (samples.Count < maximumSamples)
        {
            token.ThrowIfCancellationRequested();
            var read = source.Read(block, 0, Math.Min(block.Length, maximumSamples - samples.Count));
            if (read <= 0) break;
            samples.AddRange(block.AsSpan(0, read).ToArray());
        }
        if (samples.Count >= maximumSamples) throw new NotSupportedException("反向试听仅支持约五分钟以内的素材。");
        return new BufferedReverseSampleProvider(samples.ToArray(), source.WaveFormat);
    }

    public int Read(float[] buffer, int offset, int count)
    {
        var channels = WaveFormat.Channels;
        var written = 0;
        while (written + channels <= count && _position >= channels)
        {
            _position -= channels;
            Array.Copy(_samples, _position, buffer, offset + written, channels);
            written += channels;
        }
        return written;
    }
}
