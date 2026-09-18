<p align="center">
  <img src="assets/brand/psyreasfx-hero.png" alt="Psysia REAPER Tools" width="100%">
</p>

<h1 align="center">Psysia REAPER Tools</h1>

<p align="center">
  A collection of practical REAPER tools for sound design, editing, track management, rendering, and asset workflows.
</p>

<p align="center">
  <a href="README_zh-CN.md">简体中文</a> · <strong>English</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Host-REAPER-13253D" alt="REAPER">
  <img src="https://img.shields.io/badge/Install-ReaPack-1F6FCC" alt="ReaPack">
  <img src="https://img.shields.io/badge/Author-Psysia-555555" alt="Psysia">
</p>

## About this repository

This repository is the home of **Psysia's REAPER tools**.

It contains both focused utility scripts and larger workflow tools. **PsyReaSFX** is the largest tool in the collection, but it is only one part of the repository. Each utility can be installed independently through the same ReaPack source.

## Install with ReaPack

In REAPER, open:

`Extensions → ReaPack → Import repositories...`

Import this repository:

```text
https://github.com/Psysia/PsyReaSFX/raw/main/index.xml
```

Then synchronize packages and search for the tool you want. For PsyReaSFX,
enable pre-release versions for the package and install `PsyReaSFX.lua` Beta
7; on Windows x64, also enable/install the separate optional
`PsyReaSFX Neural Similarity` package if you want neural similar-sound search.

You do **not** need to install PsyReaSFX in order to install the smaller utility scripts.

## Tool collection

### Asset workflow

| Tool | Description |
|---|---|
| **PsyReaSFX** | Sound-asset browser and workflow workspace for library management, waveform audition, metadata, REAPER insertion, and Transfer. |

### Rendering

| Tool | Description |
|---|---|
| **Create Folder Region and Render Matrix** | Creates Regions from selected items, derives Region names from track/folder hierarchy, and writes matching Region Render Matrix targets. |
| **Smart Tail Render Panel** | Configures REAPER's native render tail, silence-trim threshold, and safety padding for Region and time-selection rendering. |
| **Open Render Dialog with Auto Tail** | Applies saved auto-tail settings before opening REAPER's Render dialog. |

### Track and item workflow

| Tool | Description |
|---|---|
| **Sort Tracks by Earliest Item Position** | Sorts selected tracks, or tracks containing selected media items, by the earliest relevant item position. Selected items take priority when present. |
| **Remove Gaps Between Selected Items** | Moves selected items together so each item begins at the end of the previous one. |
| **Split Selected Items to New Tracks** | Moves selected items to newly created tracks while keeping their timeline positions and naming the new tracks from Take names. |
| **Reverse Selected Items in Place** | Reverses selected items in place using a reversed Take workflow that can be undone in one step. |
| **Create Folder from Selected Tracks with Pro-L 2** | Wraps selected tracks in a new parent folder and inserts Pro-L 2 on the new folder bus. |
| **Cycle Selected Folders Unified Compact State** | Adaptive cycle: flat folders toggle Fully Expanded / Fully Collapsed; nested structures automatically use Normal Expanded / Compact / Fully Collapsed / Deep Expanded. |

### Display workflow

| Tool | Description |
|---|---|
| **Toggle LUFS-M and Spectrogram** | Switches REAPER's peak display between LUFS-M spectral peaks and the standard spectrogram view. |

## PsyReaSFX

<p align="center">
  <strong>Browse · Organize · Preview · Deliver</strong><br>
  A high-performance sound-asset workspace built inside REAPER.
</p>

PsyReaSFX is designed for game-audio designers, sound designers, and REAPER users who maintain large personal or production sound libraries.

It combines library management, waveform browsing, search, audition, metadata, collections, REAPER placement, and processed delivery in one dockable workspace.

### Development status

- **Stable channel: 0.8.5** — the default ReaPack release for everyday use.
- **Preview channel: 0.9.0 Beta 7.3** — fixes legacy-journal `field_mismatch` and blocked API-key saving, and includes the DeepSeek Flash / V4 Pro and AI-settings updates.
- **No conversion library** — source audio is decoded, downmixed and resampled to the model's 32 kHz input in memory. PsyReaSFX does not create converted audio copies; the persistent cache stores only compact 320-dimensional FP16 embeddings and the HNSW index.

The 0.9 preview retains the current 15-dimensional acoustic search as a dependency-free baseline. The neural similarity component remains optional, runs locally, and never uploads user audio.

Beta 7.3 includes the separate **AI semantic search** implementation. It remains separate from Find Similar Sounds: press `Enter` in the top search field for normal search, or click the gold AI button to run semantic search directly with the same text. DeepSeek now defaults to the current official API model `deepseek-flash`, with `deepseek-v4-pro` also available; legacy model settings migrate automatically. Endpoint, key, model, and usage guidance are collected in Settings, with inline key-save feedback. Beta 7.3 also fixes old catalog journals triggering `field_mismatch` and incorrectly blocking key storage. Audio and full file paths are never uploaded; only the query and up to 120 locally recalled metadata candidates are sent. On Windows, the API key is encrypted for the current user with DPAPI.

> **ReaPack setup:** install `PsyReaSFX.lua` for the application. To enable neural search on Windows x64, install `PsyReaSFX Neural Similarity` from the same repository as a second package. ReaPack updates both packages independently; the manual ZIP remains available only as a fallback.

### Main capabilities

- Logical libraries with multiple physical source folders.
- Inline waveforms and detailed mono, stereo, and multichannel preview.
- Filename, path, metadata, UCS-field, library, and workflow-state search.
- A separate AI semantic-search entry point with DeepSeek, OpenAI and OpenAI-compatible APIs, local candidate recall, and description-based reranking.
- Explainable audio-content similarity using envelope, onset, dynamics and spectral features.
- Favorites, playlists, project bins, workflow states, and non-destructive metadata.
- Regions, transient suggestions, LUFS / True Peak display, Pitch / Rate / Gain, and channel audition.
- Insert to current track, new track, BWF position, and drag selections directly into REAPER.
- Transfer with naming templates, format conversion, sample-rate/channel options, fades, normalization, and collision handling.

### PsyReaSFX releases

- [Latest PsyReaSFX Stable](https://github.com/Psysia/PsyReaSFX/releases/latest)
- [PsyReaSFX 0.9.0 Beta 7.3 preview](https://github.com/Psysia/PsyReaSFX/releases/tag/v0.9.0-beta7.3)
- [Manual ZIP fallback for the optional Beta 7.3 neural component](https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0-beta7.3/PsyReaSFX_Neural_Similarity_v0_9_0_beta7_3_win_x64.zip)
- [PsyReaSFX 0.7.23 Stable archive](https://github.com/Psysia/PsyReaSFX/releases/tag/v0.7.23)
- [All releases](https://github.com/Psysia/PsyReaSFX/releases)
- [Desktop project notes](desktop/README.md)

## Documentation

### Utility scripts

- [REAPER Utility Guide — English](docs/ReaScripts_Guide.md)
- [REAPER 工具使用手册 — 简体中文](docs/ReaScripts_Guide_zh-CN.md)

### PsyReaSFX

- [User Guide — English](docs/USER_GUIDE_en-US.md)
- [用户使用说明书 — 简体中文](docs/USER_GUIDE_zh-CN.md)
- [Changelog — English](docs/CHANGELOG_en-US.md)
- [更新日志 — 简体中文](docs/CHANGELOG_zh-CN.md)
- [0.9 → 1.0 roadmap (Chinese)](docs/ROADMAP_0_9_TO_1_0_zh-CN.md)
- [0.9 similarity architecture (Chinese)](docs/SIMILARITY_ARCHITECTURE_0_9_zh-CN.md)
- [0.9 neural audio similarity architecture (Chinese)](docs/NEURAL_SIMILARITY_ARCHITECTURE_0_9_zh-CN.md)
- [0.9 AI semantic search architecture (Chinese)](docs/AI_SEMANTIC_SEARCH_ARCHITECTURE_0_9_zh-CN.md)
- [Neural similarity sidecar and reproducible model](neural/README.md)

## Repository structure

```text
Scripts/Psysia/    REAPER utility scripts
assets/            PsyReaSFX artwork, fonts, and screenshots
docs/              User guides and changelogs
desktop/           PsyReaSFX Desktop development files
neural/            Optional neural similarity sidecar
website/           Project website
index.xml          ReaPack repository index
```

## Author and license

Created by **Psysia**.

Copyright © 2026 Psysia. All rights reserved.

See [LICENSE](LICENSE) for repository licensing details. Bundled third-party assets retain their respective licenses.
