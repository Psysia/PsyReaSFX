## PsyReaSFX 0.9.0 Beta 6.1

This update makes the optional neural similarity component installable and
updatable directly through the PsyReaSFX ReaPack repository on Windows x64.

### ReaPack installation

1. Synchronize the PsyReaSFX repository in ReaPack.
2. Enable pre-release versions for `PsyReaSFX.lua`, choose
   `0.9.0-beta6.1` under **Versions**, and install or update it.
3. On Windows x64, enable pre-release versions for the separate optional
   package `PsyReaSFX Neural Similarity`, choose `0.9.0-beta6.1`, and install it.
4. Restart PsyReaSFX.

ReaPack manages the sidecar, frozen EfficientAT model, golden assets and license
files under REAPER's `Data` directory. Embedding caches, the HNSW index and job
files remain under `Scripts/PsyReaSFX/neural_similarity`, so uninstalling the
optional package does not remove rebuildable cache data.

The Beta 6 manual ZIP installer remains available as a fallback. The component
is self-contained, runs locally, never uploads audio, and continues to support
common WAV, AIFF, FLAC, MP3 and M4A input without converted copies. FFmpeg can
extend support to OGG, Opus, WavPack and CAF.

### Assets

- `PsyReaSFX_v0_9_0_beta6_1.zip` — Lua application and bundled assets.
- `PsyReaSFX_Neural_Similarity_v0_9_0_beta6_1_win_x64.zip` — manual neural component installer.
- `PsyReaSFX.NeuralSidecar_v0_9_0_beta6_1_win_x64.exe` — ReaPack-delivered sidecar.
- `SHA256SUMS-0.9.0-beta6.1.txt` — release asset checksums.
