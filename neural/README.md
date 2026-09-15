# PsyReaSFX neural similarity sidecar

This directory contains the optional local neural-audio component. It is not
required by the default ReaPack installation and does not upload audio.

The first frozen profile is `mn04_as_scene_320_v1`:

- EfficientAT `mn04_as` AudioSet weights;
- mono float PCM at 32 kHz;
- frozen EfficientAT mel preprocessing inside the ONNX graph;
- pooled `b5`, `b11`, `b13`, `b15` features plus 128 mel averages;
- 320 raw values per window;
- 10-second windows with a 2.5-second hop for long audio;
- mean pooling followed by L2 normalization in the sidecar.

The current sidecar foundation exposes:

```text
PsyReaSFX.NeuralSidecar capabilities <model-directory>
PsyReaSFX.NeuralSidecar self-test <model-directory>
PsyReaSFX.NeuralSidecar embed <model-directory> <input.wav> [output.json]
```

Protocol v1 accepts PCM16 WAV input at 32 kHz and downmixes multiple channels
to mono. General media decoding and resampling are intentionally deferred to
the next sidecar phase. Output files are written through same-directory atomic
replacement.

## Reproduce the frozen model

Run from the repository root:

```powershell
./tools/Export-NeuralSimilarityModel.ps1
```

The script checks out the pinned EfficientAT_HEAR commit, verifies the upstream
checkpoint hash, installs pinned development-only dependencies in an isolated
temporary virtual environment, exports the model, and regenerates all golden
assets. The resulting files must match `manifest-v1.json` exactly.

## Build and verify

```powershell
dotnet build neural/PsyReaSFX.NeuralSidecar/PsyReaSFX.NeuralSidecar.csproj -c Release
dotnet run --project neural/PsyReaSFX.NeuralSidecar/PsyReaSFX.NeuralSidecar.csproj `
  -c Release --no-build -- self-test assets/neural/mn04_as_scene_320_v1
```

HNSW indexing, persistent embedding caches, cancellation files, Lua capability
discovery, and transparent fallback to the existing 15-dimensional search are
the next implementation phase.
