## PsyReaSFX 0.9.0 Beta 7.4

This hotfix prevents long-running local maintenance jobs from blocking AI
semantic search before an API request can start.

### AI semantic search

- Fixes `无法启动 AI 搜索：resource_busy` while waveform precaching, cache
  verification, catalog snapshots, or directory maintenance is active.
- Gives AI search and connection tests an independent background-job resource.
- Captures a stable asset-array snapshot when a search starts so later catalog
  list changes do not disturb the current candidate scan.
- Keeps cancellation and cleanup isolated from catalog-maintenance jobs.

### ReaPack installation

1. Synchronize the PsyReaSFX repository in ReaPack.
2. Enable pre-release versions for `PsyReaSFX.lua`, choose
   `0.9.0-beta7.4` under **Versions**, and install or update it.
3. On Windows x64, update the separate optional `PsyReaSFX Neural Similarity`
   package to Beta 7.4 only if you use local neural similar-sound search.
4. Restart PsyReaSFX.

AI semantic search remains part of the main Lua package and does not require
the neural similarity add-on.

### Assets

- `PsyReaSFX_v0_9_0_beta7_4.zip` — Lua application and bundled assets.
- `PsyReaSFX_Neural_Similarity_v0_9_0_beta7_4_win_x64.zip` — optional manual neural component installer.
- `PsyReaSFX.NeuralSidecar_v0_9_0_beta7_4_win_x64.exe` — ReaPack-delivered neural sidecar.
- `SHA256SUMS-0.9.0-beta7.4.txt` — release asset checksums.
