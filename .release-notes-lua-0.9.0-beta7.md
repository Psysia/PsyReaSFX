## PsyReaSFX 0.9.0 Beta 7

This preview introduces a separate AI semantic-search workflow for finding
sound effects from natural-language descriptions. It does not replace or mix
with the existing acoustic and optional neural similar-sound search.

### AI semantic search

- Open the gold `AI` toolbar button or press `Ctrl+Shift+F`.
- Configure DeepSeek, OpenAI, or a custom OpenAI-compatible Chat Completions
  endpoint and model under `Settings → AI Search`.
- DeepSeek defaults to `https://api.deepseek.com/chat/completions` with
  `deepseek-chat`; `deepseek-reasoner` is also available as a preset.
- PsyReaSFX first recalls a fixed local Top 120 from the active library,
  folder, collection, and workflow scope, then asks the API to rerank them.
- Only the query and bounded filename/metadata fields are sent. Audio, full
  paths, and the complete catalog are never uploaded.
- On Windows, the API key is encrypted for the current user with DPAPI and is
  excluded from normal configuration, backups, logs, and command lines.
- Includes a dedicated AI-results view, relevance scores, progress,
  cancellation, connection testing, timeout cleanup, and a local fallback if
  API reranking fails.

### ReaPack installation

1. Synchronize the PsyReaSFX repository in ReaPack.
2. Enable pre-release versions for `PsyReaSFX.lua`, choose `0.9.0-beta7`
   under **Versions**, and install or update it.
3. On Windows x64, install the matching optional `PsyReaSFX Neural Similarity`
   Beta 7 package only if you also want local neural similar-sound search.
4. Restart PsyReaSFX.

The AI semantic search is included in the main Lua package and does not require
the neural similarity add-on. API usage may be billed by the selected provider.

### Assets

- `PsyReaSFX_v0_9_0_beta7.zip` — Lua application and bundled assets.
- `PsyReaSFX_Neural_Similarity_v0_9_0_beta7_win_x64.zip` — optional manual neural component installer.
- `PsyReaSFX.NeuralSidecar_v0_9_0_beta7_win_x64.exe` — ReaPack-delivered neural sidecar.
- `SHA256SUMS-0.9.0-beta7.txt` — release asset checksums.
