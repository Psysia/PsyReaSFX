## PsyReaSFX 0.9.0 Beta 7.5

This hotfix improves compatibility with the current DeepSeek JSON Output and
default thinking-mode behavior.

### DeepSeek structured output

- Explicitly disables DeepSeek thinking mode for the structured planning and
  reranking requests used by AI semantic search.
- Accepts valid JSON wrapped in explanatory prose, Markdown code fences, or
  text content blocks.
- Correctly scans balanced JSON objects even when strings contain braces.
- Retries once with a stricter prompt when DeepSeek returns empty or malformed
  JSON, an occasional behavior documented by DeepSeek.
- Retains the Beta 7.4 fix that prevents waveform and catalog-maintenance jobs
  from blocking AI search with `resource_busy`.

### ReaPack installation

Synchronize the repository, enable pre-release versions for `PsyReaSFX.lua`,
select `0.9.0-beta7.5`, install the update, and restart PsyReaSFX.

### Assets

- `PsyReaSFX_v0_9_0_beta7_5.zip` — Lua application and bundled assets.
- `PsyReaSFX_Neural_Similarity_v0_9_0_beta7_5_win_x64.zip` — optional manual neural component installer.
- `PsyReaSFX.NeuralSidecar_v0_9_0_beta7_5_win_x64.exe` — ReaPack-delivered neural sidecar.
- `SHA256SUMS-0.9.0-beta7.5.txt` — release asset checksums.
