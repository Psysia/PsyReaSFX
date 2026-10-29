# PsyReaSFX Neural Similarity component

This is the optional Windows x64 local component for PsyReaSFX 0.9.0 Stable.
It generates audio embeddings with the frozen EfficientAT `mn04_as` model and
uses HNSW for fast full-library similar-sound recall. Audio stays on this
computer and is never uploaded.

## Recommended: install with ReaPack

**Neural retrieval requires this package; built-in acoustic search and AI semantic
search do not. Updating the main script does not install it.**

**[Complete neural ZIP download · 0.9.0 · Windows x64 · about 42.4 MB][neural-download]**
includes the model and installers, unlike the standalone EXE.

1. Import and synchronize the [PsyReaSFX repository](https://github.com/Psysia/PsyReaSFX/raw/main/index.xml).
2. Install `PsyReaSFX.lua`.
3. Open `Extensions → ReaPack → Browse packages`, search for the separate
   [PsyReaSFX Neural Similarity][neural-download] data package. Choose **Install** or **Versions** → `0.9.0` (Stable); uncheck **Pin current version**, then click **Apply / OK**.
4. Restart PsyReaSFX.

ReaPack installs the component under REAPER's `Data` directory and handles
future component updates and uninstallation. Rebuildable embedding and HNSW
caches remain separately under `Scripts/PsyReaSFX/neural_similarity`.

## Manual ZIP fallback

1. Install or update the main PsyReaSFX 0.9.0 Stable through ReaPack.
2. Download the [complete neural ZIP][neural-download], extract everything,
   and double-click `Install-NeuralSimilarity.cmd`.
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

## 0.9.0 compatibility

The 0.9.0 inspector navigation fix requires only the main script update and
restart. An existing Beta 8.5 component does not need updating. Older components
need an update for the window progress introduced in Beta 8.5.
Sidecar 0.5.1 reports model loading, decoding and audio-window progress and checks
cancellation between windows. Decoding or one inference can still take time.
The first global search computes every uncached file; later searches reuse the
existing compatible cache. The model and full-window embedding algorithm are
unchanged, and no cache rebuild or audio conversion is required.

## Uninstall

Double-click `Uninstall-NeuralSimilarity.cmd`. It preserves the rebuildable
cache by default so a later reinstall can reuse it. To remove the cache too:

```powershell
.\Uninstall-NeuralSimilarity.ps1 -RemoveCache
```

Removing or breaking this optional component does not disable PsyReaSFX;
similarity search transparently returns to the baseline algorithm.

[neural-download]: https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip
