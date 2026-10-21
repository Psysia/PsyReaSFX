## PsyReaSFX 0.9.0 Beta 7.8

This update removes the redundant remote candidate-reranking stage from AI
semantic search and makes result paging immediate.

### AI search workflow

- Uses the configured AI API once to convert the natural-language request into
  bounded bilingual retrieval terms.
- Keeps filenames, Description, Keywords, UCS metadata, directories, paths and
  audio local; candidate metadata is no longer sent to the API.
- Ranks up to 2,400 candidates locally and displays the first 120 immediately
  after recall finishes.
- Loads each additional 120-result page directly from the in-memory candidate
  pool without another API call.
- Removes the AI relevance column and background reranking state. Find Similar
  Sounds retains its existing local similarity score and ordering.
- Clears stale AI results when a new search begins, preventing old results from
  appearing underneath the new search status.

### ReaPack installation

Synchronize the repository, enable pre-release versions for `PsyReaSFX.lua`,
select `0.9.0-beta7.8`, install the update, and restart PsyReaSFX.

### Assets

- `PsyReaSFX_v0_9_0_beta7_8.zip` — Lua application and bundled assets.
- `PsyReaSFX_Neural_Similarity_v0_9_0_beta7_8_win_x64.zip` — optional manual neural component installer.
- `PsyReaSFX.NeuralSidecar_v0_9_0_beta7_8_win_x64.exe` — ReaPack-delivered neural sidecar.
- `SHA256SUMS-0.9.0-beta7.8.txt` — release asset checksums.
