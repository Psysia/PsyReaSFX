## PsyReaSFX 0.9.0 Beta 7.7

This update improves AI semantic-search browsing, progress presentation and
remote reranking latency for large sound libraries.

### AI search workflow

- Replaces the repeated large AI progress bar with one compact phase status
  line for planning, local recall, reranking and retry.
- Keeps up to 2,400 ranked local candidates and sends only the first 120 for
  the initial rerank.
- Adds **Load next 120** at the bottom of AI results; each requested batch is
  appended to the current results without discarding earlier pages.
- Uses compact candidate array rows and a `[candidate_id, score]` response
  format, reducing request size, generated tokens and latency.
- Fills any candidates omitted by the model from deterministic local recall,
  so a partial API response no longer leaves the page below 120 results.
- Keeps deterministic ordering by page, AI relevance, local recall score and
  path. The AI relevance control explains this ranking in its tooltip.

### ReaPack installation

Synchronize the repository, enable pre-release versions for `PsyReaSFX.lua`,
select `0.9.0-beta7.7`, install the update, and restart PsyReaSFX.

### Assets

- `PsyReaSFX_v0_9_0_beta7_7.zip` — Lua application and bundled assets.
- `PsyReaSFX_Neural_Similarity_v0_9_0_beta7_7_win_x64.zip` — optional manual neural component installer.
- `PsyReaSFX.NeuralSidecar_v0_9_0_beta7_7_win_x64.exe` — ReaPack-delivered neural sidecar.
- `SHA256SUMS-0.9.0-beta7.7.txt` — release asset checksums.
