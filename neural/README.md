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
PsyReaSFX.NeuralSidecar run-job <model-directory> <request.json>
```

Protocol v1 accepts PCM16 WAV input at 32 kHz and downmixes multiple channels
to mono. General media decoding and resampling are intentionally deferred to
the next sidecar phase. Output files are written through same-directory atomic
replacement.

`run-job` supports three operations through `PsyReaSFX-Neural-Job-v1` JSON
requests:

- `build-cache` incrementally writes a versioned binary cache keyed by the
  existing 16-character asset signature. Each record stores file size, UTC
  modification ticks, and a 320-dimensional FP16 embedding, but no path.
- `build-index` creates a deterministic, versioned HNSW graph bound to the
  complete embedding-cache SHA-256. The graph is atomically replaced only
  after construction succeeds.
- `query` uses HNSW for unrestricted searches, or exact cosine for a supplied
  candidate-signature set. It excludes the reference and returns a stable
  score-descending, signature-ascending Top-K list. `searchMode` may be `auto`,
  `exact`, or `hnsw`; `auto` falls back to exact search if an index is missing,
  corrupt, or stale.

Build inputs use UTF-8 TSV rows in the form
`signature<TAB>size<TAB>mtimeUtcTicks<TAB>JSON-string-path`. Unchanged records
are reusable while their source drive is offline. Changed or new records are
validated before and after reading. A cancellation file stops after the current
asset and leaves the previous cache generation untouched. Cache, status, and
result files are all replaced atomically.

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

The in-tree HNSW implementation adds no new runtime dependency. Its current
defaults are `m = 16`, `efConstruction = 128`, and `efSearch = 800`; all are
validated by the sidecar protocol. Candidate-filtered searches intentionally
remain exact so a small UI result scope cannot lose relevant records before
reranking.

General media decoding/resampling, Lua capability discovery, and transparent
fallback to the existing 15-dimensional search remain the next implementation
phase.
