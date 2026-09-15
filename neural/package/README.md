# PsyReaSFX Neural Similarity component

This is the optional Windows x64 local component for PsyReaSFX 0.9.0 Beta 6.
It generates audio embeddings with the frozen EfficientAT `mn04_as` model and
uses HNSW for fast full-library similar-sound recall. Audio stays on this
computer and is never uploaded.

## Install

1. Install or update to PsyReaSFX 0.9.0 Beta 6 through ReaPack.
2. Extract this ZIP and double-click `Install-NeuralSimilarity.cmd`.
3. Restart PsyReaSFX after installation.

The default destination is:

```text
%APPDATA%\REAPER\Scripts\PsyReaSFX\neural_similarity\
```

For portable REAPER, pass its resource directory in PowerShell:

```powershell
.\Install-NeuralSimilarity.ps1 -ReaperResourcePath "D:\REAPER Portable"
```

## Audio format support

The built-in Windows path supports common sample rates and PCM16/PCM24/PCM32/
float WAV, plus AIFF, FLAC, MP3, and M4A. If FFmpeg is installed, OGG, Opus,
WavPack, and CAF are enabled too. Set `PSYREASFX_FFMPEG` to an explicit FFmpeg
executable, place `ffmpeg.exe` beside the sidecar, or make it available on
`PATH`.

Audio is decoded, downmixed, and resampled to the model's 32 kHz input in
memory. No converted audio copies are created. An unsupported or damaged file
is skipped and reported; other successfully embedded assets remain searchable.

The first full-library search builds an embedding cache and HNSW index with
visible, cancelable progress. Later searches reuse data under:

```text
<REAPER Resource Path>\Scripts\PsyReaSFX\neural_similarity\
```

## Uninstall

Double-click `Uninstall-NeuralSimilarity.cmd`. It preserves the rebuildable
cache by default so a later reinstall can reuse it. To remove the cache too:

```powershell
.\Uninstall-NeuralSimilarity.ps1 -RemoveCache
```

Removing or breaking this optional component does not disable PsyReaSFX;
similarity search transparently returns to the baseline algorithm.
