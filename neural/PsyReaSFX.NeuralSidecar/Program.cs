using System.Buffers.Binary;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.ML.OnnxRuntime;
using Microsoft.ML.OnnxRuntime.Tensors;

namespace PsyReaSFX.NeuralSidecar;

internal static class Program
{
    internal const string SidecarVersion = "0.2.0";
    internal const string ExpectedSchema = "PsyReaSFX-Neural-Model-v1";
    internal const string ExpectedProfile = "mn04_as_scene_320_v1";
    internal const string ExpectedModelSha256 = "5efdf45af4562190f8a8076b0460ecb51200b52e2080a5e250e25af577a79054";
    internal const int ExpectedDimensions = 320;
    internal const int ExpectedSampleRate = 32_000;
    internal const int MinimumSamples = 514;
    internal const int MaximumSamples = ExpectedSampleRate * 10;
    internal const int SceneHopSamples = ExpectedSampleRate * 5 / 2;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
    };

    public static int Main(string[] args)
    {
        try
        {
            if (args.Length < 2)
            {
                WriteUsage();
                return 2;
            }

            var command = args[0];
            var modelDirectory = Path.GetFullPath(args[1]);
            return command switch
            {
                "capabilities" => RunCapabilities(modelDirectory),
                "self-test" => RunSelfTest(modelDirectory),
                "embed" => RunEmbed(modelDirectory, args.Skip(2).ToArray()),
                "run-job" => NeuralJobs.Run(modelDirectory, args.Skip(2).ToArray()),
                _ => throw new ArgumentException($"Unknown command: {command}"),
            };
        }
        catch (Exception error)
        {
            Console.Error.WriteLine(JsonSerializer.Serialize(new
            {
                schema = "PsyReaSFX-Neural-Error-v1",
                sidecarVersion = SidecarVersion,
                error = error.Message,
            }, JsonOptions));
            return 1;
        }
    }

    private static int RunCapabilities(string modelDirectory)
    {
        var model = ModelBundle.LoadAndVerify(modelDirectory);
        WriteJson(new
        {
            schema = "PsyReaSFX-Neural-Capabilities-v1",
            sidecarVersion = SidecarVersion,
            protocolVersion = 1,
            operations = new[] { "capabilities", "embed", "run-job", "self-test" },
            jobOperations = new[] { "build-cache", "query" },
            profiles = new[]
            {
                new
                {
                    model.Profile,
                    model.Dimensions,
                    model.SampleRate,
                    input = "mono PCM16 WAV at 32000 Hz",
                    minimumSamples = MinimumSamples,
                    maximumWindowSamples = MaximumSamples,
                    sceneHopSamples = SceneHopSamples,
                    longAudioWindowing = true,
                },
            },
        });
        return 0;
    }

    private static int RunSelfTest(string modelDirectory)
    {
        var model = ModelBundle.LoadAndVerify(modelDirectory);
        var goldenPath = Path.Combine(modelDirectory, "golden-v1.json");
        using var golden = JsonDocument.Parse(File.ReadAllText(goldenPath));
        var root = golden.RootElement;
        Require(root.GetProperty("schema").GetString() == "PsyReaSFX-Neural-Golden-v1", "Golden schema mismatch.");
        Require(root.GetProperty("profile").GetString() == model.Profile, "Golden profile mismatch.");
        var maxAbsLimit = root.GetProperty("tolerance").GetProperty("max_abs").GetSingle();
        var minimumCosine = root.GetProperty("tolerance").GetProperty("minimum_cosine").GetSingle();

        var reports = new List<object>();
        using var session = CreateSession(model.ModelPath);
        foreach (var testCase in root.GetProperty("cases").EnumerateArray())
        {
            var name = testCase.GetProperty("name").GetString() ?? throw new InvalidDataException("Golden name is missing.");
            var audioFile = testCase.GetProperty("audio_file").GetString() ?? throw new InvalidDataException("Golden audio file is missing.");
            var audioPath = Path.Combine(modelDirectory, audioFile);
            Require(HashFile(audioPath) == testCase.GetProperty("audio_sha256").GetString(), $"Golden audio hash mismatch: {name}");
            var samples = WavePcm16.ReadMono32k(audioPath);
            var actual = RunSceneEmbedding(session, samples, model.Dimensions);
            var expected = testCase.GetProperty("embedding").EnumerateArray().Select(value => value.GetSingle()).ToArray();
            var metrics = Compare(expected, actual);
            Require(metrics.MaxAbsolute <= maxAbsLimit, $"Golden max-absolute mismatch for {name}: {metrics.MaxAbsolute}");
            Require(metrics.Cosine >= minimumCosine, $"Golden cosine mismatch for {name}: {metrics.Cosine}");
            reports.Add(new { name, samples = samples.Length, metrics.MaxAbsolute, metrics.Cosine });
        }

        WriteJson(new
        {
            schema = "PsyReaSFX-Neural-SelfTest-v1",
            sidecarVersion = SidecarVersion,
            profile = model.Profile,
            result = "passed",
            cases = reports,
            cacheProtocol = NeuralJobs.RunSelfTest(model),
        });
        return 0;
    }

    private static int RunEmbed(string modelDirectory, string[] args)
    {
        if (args.Length < 1)
        {
            throw new ArgumentException("embed requires an input WAV path and optional output JSON path.");
        }

        var model = ModelBundle.LoadAndVerify(modelDirectory);
        var inputPath = Path.GetFullPath(args[0]);
        var outputPath = args.Length >= 2 ? Path.GetFullPath(args[1]) : null;
        if (outputPath is not null)
        {
            Require(!string.Equals(inputPath, outputPath, StringComparison.OrdinalIgnoreCase),
                "Embedding output must not overwrite the input audio.");
            var modelRoot = Path.GetFullPath(modelDirectory).TrimEnd(Path.DirectorySeparatorChar)
                + Path.DirectorySeparatorChar;
            Require(!outputPath.StartsWith(modelRoot, StringComparison.OrdinalIgnoreCase),
                "Embedding output must not be written into the read-only model directory.");
        }
        var samples = WavePcm16.ReadMono32k(inputPath);
        Require(samples.Length >= MinimumSamples, $"Audio is too short; at least {MinimumSamples} samples are required.");

        using var session = CreateSession(model.ModelPath);
        var embedding = RunSceneEmbedding(session, samples, model.Dimensions);
        var result = new
        {
            schema = "PsyReaSFX-Neural-Embedding-v1",
            sidecarVersion = SidecarVersion,
            profile = model.Profile,
            dimensions = model.Dimensions,
            sampleRate = model.SampleRate,
            samples = samples.Length,
            audioSha256 = HashFile(inputPath),
            embeddingSha256Float32Le = HashFloats(embedding),
            embedding,
        };

        var json = JsonSerializer.Serialize(result, JsonOptions) + Environment.NewLine;
        if (outputPath is null)
        {
            Console.Write(json);
        }
        else
        {
            AtomicWrite(outputPath, json);
        }
        return 0;
    }

    internal static InferenceSession CreateSession(string modelPath)
    {
        var options = new SessionOptions
        {
            ExecutionMode = ExecutionMode.ORT_SEQUENTIAL,
            GraphOptimizationLevel = GraphOptimizationLevel.ORT_ENABLE_ALL,
            IntraOpNumThreads = Math.Max(1, Math.Min(Environment.ProcessorCount, 4)),
            InterOpNumThreads = 1,
        };
        return new InferenceSession(modelPath, options);
    }

    internal static float[] RunSceneEmbedding(InferenceSession session, float[] samples, int dimensions)
    {
        if (samples.Length <= MaximumSamples)
        {
            return Normalize(RunRawEmbedding(session, samples, dimensions));
        }

        var sum = new float[dimensions];
        var windows = 0;
        for (var start = 0; start <= samples.Length; start += SceneHopSamples)
        {
            var window = new float[MaximumSamples];
            for (var index = 0; index < window.Length; index++)
            {
                var source = start + index - MaximumSamples / 2;
                if (source < 0)
                {
                    source = -source;
                }
                else if (source >= samples.Length)
                {
                    source = 2 * samples.Length - 2 - source;
                }
                window[index] = samples[source];
            }

            var current = RunRawEmbedding(session, window, dimensions);
            for (var index = 0; index < dimensions; index++)
            {
                sum[index] += current[index];
            }
            windows++;
        }

        for (var index = 0; index < dimensions; index++)
        {
            sum[index] /= windows;
        }
        return Normalize(sum);
    }

    private static float[] RunRawEmbedding(InferenceSession session, float[] samples, int dimensions)
    {
        var tensor = new DenseTensor<float>(samples, new[] { 1, samples.Length });
        var input = NamedOnnxValue.CreateFromTensor("waveform", tensor);
        using var results = session.Run(new[] { input });
        var embedding = results.Single(result => result.Name == "embedding_raw").AsTensor<float>().ToArray();
        Require(embedding.Length == dimensions, $"Expected {dimensions} embedding values, got {embedding.Length}.");
        Require(embedding.All(float.IsFinite), "Embedding contains a non-finite value.");
        return embedding;
    }

    private static float[] Normalize(float[] embedding)
    {
        double squared = 0;
        foreach (var value in embedding)
        {
            squared += value * value;
        }
        var scale = (float)Math.Sqrt(squared);
        Require(scale > 1e-12f && float.IsFinite(scale), "Embedding norm is invalid.");
        for (var index = 0; index < embedding.Length; index++)
        {
            embedding[index] /= scale;
        }
        return embedding;
    }

    private static (float MaxAbsolute, float Cosine) Compare(float[] expected, float[] actual)
    {
        Require(expected.Length == actual.Length, "Embedding dimension mismatch.");
        double dot = 0;
        double expectedNorm = 0;
        double actualNorm = 0;
        var maxAbsolute = 0f;
        for (var index = 0; index < expected.Length; index++)
        {
            maxAbsolute = Math.Max(maxAbsolute, Math.Abs(expected[index] - actual[index]));
            dot += expected[index] * actual[index];
            expectedNorm += expected[index] * expected[index];
            actualNorm += actual[index] * actual[index];
        }
        return (maxAbsolute, (float)(dot / Math.Sqrt(expectedNorm * actualNorm)));
    }

    internal static string HashFloats(float[] values)
    {
        var bytes = new byte[values.Length * sizeof(float)];
        for (var index = 0; index < values.Length; index++)
        {
            BinaryPrimitives.WriteSingleLittleEndian(bytes.AsSpan(index * sizeof(float), sizeof(float)), values[index]);
        }
        return Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
    }

    internal static string HashFile(string path)
    {
        using var stream = File.OpenRead(path);
        return Convert.ToHexString(SHA256.HashData(stream)).ToLowerInvariant();
    }

    internal static void AtomicWrite(string path, string content)
    {
        var directory = Path.GetDirectoryName(path);
        if (string.IsNullOrEmpty(directory))
        {
            throw new InvalidOperationException("Output path must include a directory.");
        }
        Directory.CreateDirectory(directory);
        var temporary = Path.Combine(directory, $".{Path.GetFileName(path)}.{Guid.NewGuid():N}.tmp");
        try
        {
            File.WriteAllText(temporary, content);
            File.Move(temporary, path, true);
        }
        finally
        {
            if (File.Exists(temporary))
            {
                File.Delete(temporary);
            }
        }
    }

    private static void WriteJson(object value) =>
        Console.WriteLine(JsonSerializer.Serialize(value, JsonOptions));

    internal static void Require(bool condition, string message)
    {
        if (!condition)
        {
            throw new InvalidDataException(message);
        }
    }

    private static void WriteUsage() => Console.Error.WriteLine(
        "Usage: PsyReaSFX.NeuralSidecar <capabilities|self-test|embed|run-job> <model-directory> [arguments]");

    internal sealed record ModelBundle(string Profile, int Dimensions, int SampleRate, string ModelPath)
    {
        public static ModelBundle LoadAndVerify(string directory)
        {
            var manifestPath = Path.Combine(directory, "manifest-v1.json");
            if (!File.Exists(manifestPath))
            {
                throw new FileNotFoundException("Neural model manifest was not found.", manifestPath);
            }

            using var document = JsonDocument.Parse(File.ReadAllText(manifestPath));
            var root = document.RootElement;
            var schema = root.GetProperty("schema").GetString();
            var profile = root.GetProperty("profile").GetString();
            var dimensions = root.GetProperty("dimensions").GetInt32();
            var sampleRate = root.GetProperty("sample_rate").GetInt32();
            Require(schema == ExpectedSchema, $"Unsupported model schema: {schema}");
            Require(profile == ExpectedProfile, $"Unsupported model profile: {profile}");
            Require(dimensions == ExpectedDimensions, $"Unexpected embedding dimensions: {dimensions}");
            Require(sampleRate == ExpectedSampleRate, $"Unexpected model sample rate: {sampleRate}");

            var modelRoot = Path.GetFullPath(directory).TrimEnd(Path.DirectorySeparatorChar)
                + Path.DirectorySeparatorChar;
            foreach (var artifact in root.GetProperty("artifacts").EnumerateObject())
            {
                var artifactPath = Path.GetFullPath(Path.Combine(directory, artifact.Name));
                Require(artifactPath.StartsWith(modelRoot, StringComparison.OrdinalIgnoreCase),
                    $"Unsafe artifact path: {artifact.Name}");
                Require(File.Exists(artifactPath), $"Missing model artifact: {artifact.Name}");
                var expectedBytes = artifact.Value.GetProperty("bytes").GetInt64();
                var expectedHash = artifact.Value.GetProperty("sha256").GetString();
                Require(new FileInfo(artifactPath).Length == expectedBytes, $"Artifact size mismatch: {artifact.Name}");
                Require(HashFile(artifactPath) == expectedHash, $"Artifact hash mismatch: {artifact.Name}");
            }

            var modelPath = Path.Combine(directory, $"{ExpectedProfile}.onnx");
            Require(HashFile(modelPath) == ExpectedModelSha256,
                $"Frozen model hash mismatch for {ExpectedProfile}.");
            return new ModelBundle(profile!, dimensions, sampleRate, modelPath);
        }
    }

    internal static class WavePcm16
    {
        public static float[] ReadMono32k(string path)
        {
            using var stream = File.OpenRead(path);
            using var reader = new BinaryReader(stream);
            Require(new string(reader.ReadChars(4)) == "RIFF", "Only little-endian RIFF WAV is supported.");
            _ = reader.ReadUInt32();
            Require(new string(reader.ReadChars(4)) == "WAVE", "Invalid WAVE header.");

            ushort format = 0;
            ushort channels = 0;
            uint sampleRate = 0;
            ushort bitsPerSample = 0;
            byte[]? data = null;
            while (stream.Position + 8 <= stream.Length)
            {
                var chunkId = new string(reader.ReadChars(4));
                var chunkSize = reader.ReadUInt32();
                var next = stream.Position + chunkSize + (chunkSize & 1);
                if (chunkId == "fmt ")
                {
                    format = reader.ReadUInt16();
                    channels = reader.ReadUInt16();
                    sampleRate = reader.ReadUInt32();
                    _ = reader.ReadUInt32();
                    _ = reader.ReadUInt16();
                    bitsPerSample = reader.ReadUInt16();
                }
                else if (chunkId == "data")
                {
                    data = reader.ReadBytes(checked((int)chunkSize));
                }
                stream.Position = next;
            }

            Require(format == 1 && bitsPerSample == 16, "Protocol v1 supports PCM16 WAV only.");
            Require(channels > 0, "WAV channel count is invalid.");
            Require(sampleRate == ExpectedSampleRate, $"Protocol v1 requires {ExpectedSampleRate} Hz audio.");
            Require(data is not null, "WAV data chunk is missing.");
            var payload = data ?? throw new InvalidDataException("WAV data chunk is missing.");
            Require(payload.Length % (channels * 2) == 0, "WAV PCM payload is truncated.");

            var frames = payload.Length / (channels * 2);
            var mono = new float[frames];
            var offset = 0;
            for (var frame = 0; frame < frames; frame++)
            {
                var sum = 0f;
                for (var channel = 0; channel < channels; channel++)
                {
                    sum += BinaryPrimitives.ReadInt16LittleEndian(payload.AsSpan(offset, 2)) / 32768f;
                    offset += 2;
                }
                mono[frame] = sum / channels;
            }
            return mono;
        }
    }
}
