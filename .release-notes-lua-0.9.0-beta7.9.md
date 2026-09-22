## PsyReaSFX 0.9.0 Beta 7.9

This hotfix repairs AI-search completion and waveform peak generation for files
whose REAPER peak cache is not immediately ready.

### Fixes

- Explicitly clears the active AI session after local recall reaches 100%, so
  the top status closes instead of remaining visible indefinitely.
- Restores **Load next 120**: later pages append immediately from the in-memory
  Top-2400 candidate pool without another API request.
- Clears stale AI paging state when starting a new search or leaving AI results.
- Always runs REAPER waveform peak building through Init, Run and Finish, even
  when Init returns zero. This fixes repeated `GetPeaks = 0` failures seen with
  long 96 kHz/24-bit WAV files and other files whose peaks are not yet ready.
- Adds regression tests for AI-session cleanup and the complete REAPER
  peak-builder sequence.

### ReaPack installation

Synchronize the repository, enable pre-release versions for `PsyReaSFX.lua`,
select `0.9.0-beta7.9`, install the update, and restart PsyReaSFX.

Waveform failures recorded by an earlier version can be retried from
**Settings → Reliability and recovery → Retry all failed tasks**. PsyReaSFX
will also rebuild visible waveforms on demand after the failed records are
cleared or retried.

### Assets

- `PsyReaSFX_v0_9_0_beta7_9.zip` — Lua application and bundled assets.
- `PsyReaSFX_Neural_Similarity_v0_9_0_beta7_9_win_x64.zip` — optional manual neural component installer.
- `PsyReaSFX.NeuralSidecar_v0_9_0_beta7_9_win_x64.exe` — ReaPack-delivered neural sidecar.
- `SHA256SUMS-0.9.0-beta7.9.txt` — release asset checksums.
