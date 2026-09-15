# PsyReaSFX neural similarity sidecar

This directory contains the optional local neural-audio component. It is a
separate optional ReaPack data package and does not upload audio.

Beta 6.1 users can install `PsyReaSFX Neural Similarity` directly through the
same ReaPack repository as the Lua package. The self-contained Windows x64 ZIP
and `Install-NeuralSimilarity.cmd` remain a manual fallback; no separate .NET
runtime is required. Package and layout smoke tests are implemented by
`tools/Build-BetaRelease.ps1`, `tools/Test-NeuralPackage.ps1`, and
`tools/Test-ReaPackNeuralPackage.ps1`.

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
PsyReaSFX.NeuralSidecar capabilities <model-directory> [output.json]
PsyReaSFX.NeuralSidecar self-test <model-directory>
PsyReaSFX.NeuralSidecar embed <model-directory> <input-audio> [output.json]
PsyReaSFX.NeuralSidecar run-job <model-directory> <request.json>
```

Sidecar `0.5.0` decodes common WAV sample rates and PCM16/PCM24/PCM32/float
depths, AIFF, FLAC, MP3, and M4A through NAudio and Windows Media Foundation.
When FFmpeg is found through `PSYREASFX_FFMPEG`, beside the executable, or on
`PATH`, it also enables OGG, Opus, WavPack, and CAF. Decoded audio is downmixed
and WDL-resampled to mono 32 kHz in memory; no converted audio file is created.
Output metadata and job files use same-directory atomic replacement.

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

Sidecar `0.4.0` added the Lua integration contract: capability discovery may
write directly to an atomic JSON output, `-1` in the TSV mtime column asks the
sidecar to capture the exact UTC timestamp before processing, and job
processes lower their Windows priority so REAPER remains responsive.

Sidecar `0.5.0` publishes `decoderVersion`, `supportedExtensions`, and the
current FFmpeg fallback state through `capabilities`. Embedding-cache format 2
binds the cache to the decoder version. A build may skip and report individual
decode failures while keeping successfully embedded assets available.

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

Lua discovers the optional component without blocking REAPER, polls job
status/result files, exposes progress and cancellation, uses HNSW for complete
library searches, preserves exact candidate filtering for current-result
searches, and transparently falls back to the existing 15-dimensional search.
It uses the extensions advertised by the installed sidecar rather than imposing
a fixed sample-rate or bit-depth rule. Older sidecars without decoder capability
metadata keep the Beta 5 restriction for safety.
