## PsyReaSFX 0.9.0 Beta 7.6

This hotfix makes AI semantic search practical for large sound libraries by
removing repeated per-field work from the local candidate-recall stage.

### AI local recall performance

- Uses a two-stage local recall pipeline: one combined-text prefilter per
  asset, then weighted field scoring only for matching assets.
- Compiles the AI-expanded query terms once per search rather than repeatedly
  lowercasing and splitting them for every catalog row.
- Reuses existing normal-search text caches when available without retaining
  new per-asset cache data solely for AI search.
- Raises frame throughput while retaining a small time budget so REAPER stays
  responsive during very large catalog searches.
- Adds a 100,000-asset capacity regression test; local recall completes in
  about 0.6 seconds in the test environment.

### ReaPack installation

Synchronize the repository, enable pre-release versions for `PsyReaSFX.lua`,
select `0.9.0-beta7.6`, install the update, and restart PsyReaSFX.

### Assets

- `PsyReaSFX_v0_9_0_beta7_6.zip` — Lua application and bundled assets.
- `PsyReaSFX_Neural_Similarity_v0_9_0_beta7_6_win_x64.zip` — optional manual neural component installer.
- `PsyReaSFX.NeuralSidecar_v0_9_0_beta7_6_win_x64.exe` — ReaPack-delivered neural sidecar.
- `SHA256SUMS-0.9.0-beta7.6.txt` — release asset checksums.
