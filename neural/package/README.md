# PsyReaSFX Neural Similarity component

This is the optional Windows x64 local component for PsyReaSFX 0.9.0 Beta 5.
It generates audio embeddings with the frozen EfficientAT `mn04_as` model and
uses HNSW for fast full-library similar-sound recall. Audio stays on this
computer and is never uploaded.

## Install

1. Install or update to PsyReaSFX 0.9.0 Beta 5 through ReaPack.
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

## Current format scope

The neural path currently activates only when every asset in the requested
search scope is a **32 kHz PCM16 WAV**. Other sample rates, bit depths, and
formats transparently use the existing 15-feature acoustic search.

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
