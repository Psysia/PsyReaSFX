<p align="center">
  <img src="assets/brand/psyreasfx-hero.png" alt="Psysia REAPER Tools" width="100%">
</p>

<h1 align="center">Psysia REAPER Tools</h1>

<p align="center">
  Practical REAPER tools for sound design, track organization, rendering, project navigation, and sound-asset workflows.
</p>

<p align="center">
  <strong>English</strong> · <a href="README_zh-CN.md">Chinese</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Host-REAPER-13253D" alt="REAPER">
  <img src="https://img.shields.io/badge/Install-ReaPack-1F6FCC" alt="ReaPack">
  <img src="https://img.shields.io/badge/Author-Psysia-555555" alt="Psysia">
</p>

## Overview

This repository contains two parts:

- **PsyReaSFX** — a larger sound-asset workflow environment built inside REAPER.
- **REAPER Utilities** — focused ReaScripts for editing, folder management, rendering, display, and project workflow.

Every utility can be installed independently. PsyReaSFX is not required unless you want the asset-browser workflow itself.

## Install

In REAPER, open `Extensions → ReaPack → Import repositories...` and add:

```text
https://raw.githubusercontent.com/Psysia/PsyReaSFX/main/index.xml
```

Then run `Extensions → ReaPack → Synchronize packages` and install the tools you need.

For PsyReaSFX preview releases, enable pre-release versions in ReaPack. The optional **PsyReaSFX Neural Similarity** package is only needed for local neural similar-sound search on Windows x64.

## REAPER Utilities

| Category | Tool | Purpose |
|---|---|---|
| Rendering | Create Folder Region and Render Matrix | Build Regions from the current selection and assign matching Region Render Matrix targets. |
| Rendering | Smart Tail Render Panel | Configure render tail, silence trimming, and safety padding. |
| Rendering | Open Render Dialog with Auto Tail | Apply saved tail settings before opening REAPER's Render dialog. |
| Track management | Sort Tracks by Earliest Item Position | Folder-aware sorting that preserves complete folder subtrees. |
| Track management | Create Folder from Selected Tracks with Pro-L 2 | Wrap sibling tracks or complete folder subtrees in a new Folder Bus and insert Pro-L 2. |
| Track management | Cycle Selected Folders Unified Compact State | Adaptive two-state or four-state folder display cycling for flat and nested structures. |
| Track management | Rename Selected Tracks from Parent Folder Name | Rename selected child tracks from the immediate parent folder and add numbered suffixes. |
| Item editing | Remove Gaps Between Selected Items | Close gaps between selected items while preserving their order. |
| Item editing | Split Selected Items to New Tracks | Move selected items to new tracks while preserving timeline positions. |
| Item editing | Reverse Selected Items in Place | Reverse selected items through a single undoable Take workflow. |
| Project workflow | Open All Subprojects | Recursively open all subprojects referenced by the current project. |
| Display | Toggle LUFS-M and Spectrogram | Switch between LUFS-M spectral-peak display and spectrogram view. |
| Display | Video Item Track Name Overlay | Show the current track name inside each video Item; directly switch to the filename mode when needed. |\n| Display | Video Item Source Filename Overlay | Show the source video filename without its extension; directly switch back to track-name mode at any time. |

Detailed behavior, edge cases, dependencies, and shortcut suggestions are documented in the [REAPER Tools Guide](docs/REAPER_TOOLS_GUIDE_en-US.md).

## PsyReaSFX

**PsyReaSFX** is a dockable sound-asset workspace for REAPER. It combines library management, waveform browsing, audition, metadata, collections, search, REAPER insertion, and processed delivery in one workflow.

| Channel | Version | Notes |
|---|---|---|
| Stable | **0.8.5** | Recommended for everyday use. |
| Preview | **0.9.0 Beta 7.8** | Current pre-release line; AI expands the query once, then ranking and paging stay local. |
| Optional component | **PsyReaSFX Neural Similarity** | Local neural similar-sound search for Windows x64. |

PsyReaSFX keeps normal acoustic search available without the optional neural component. AI semantic search is a separate API-based feature; user audio is not uploaded by that feature.

### Development status

- **Stable channel: 0.8.5** — the default ReaPack release for everyday use.
- **Preview channel: 0.9.0 Beta 7.8** — removes remote AI reranking and keeps result ranking and paging local.
- **No conversion library** — source audio is decoded, downmixed and resampled to the model's 32 kHz input in memory. PsyReaSFX does not create converted audio copies; the persistent cache stores only compact 320-dimensional FP16 embeddings and the HNSW index.

The 0.9 preview retains the current 15-dimensional acoustic search as a dependency-free baseline. The neural similarity component remains optional, runs locally, and never uploads user audio.

Beta 7.8 includes the separate **AI semantic search** implementation. It remains separate from Find Similar Sounds: press `Enter` for normal search or click the gold AI button for semantic search. The AI only converts the natural-language request into bilingual retrieval terms. Candidate recall, ranking, and 120-result paging then run locally, so **Load next 120** appends immediately without another API request. Audio, filenames, metadata, directories, and file paths are never uploaded; only the query is sent. On Windows, the API key is encrypted for the current user with DPAPI.

> **ReaPack setup:** install `PsyReaSFX.lua` for the application. To enable neural search on Windows x64, install `PsyReaSFX Neural Similarity` from the same repository as a second package. ReaPack updates both packages independently; the manual ZIP remains available only as a fallback.

### Main capabilities

- Logical libraries with multiple physical source folders.
- Inline waveforms and detailed mono, stereo, and multichannel preview.
- Filename, path, metadata, UCS-field, library, and workflow-state search.
- A separate AI semantic-search entry point with DeepSeek, OpenAI and OpenAI-compatible APIs for query expansion, followed by local candidate recall and ranking.
- Explainable audio-content similarity using envelope, onset, dynamics and spectral features.
- Favorites, playlists, project bins, workflow states, and non-destructive metadata.
- Regions, transient suggestions, LUFS / True Peak display, Pitch / Rate / Gain, and channel audition.
- Insert to current track, new track, BWF position, and drag selections directly into REAPER.
- Transfer with naming templates, format conversion, sample-rate/channel options, fades, normalization, and collision handling.

### PsyReaSFX releases

- [Latest PsyReaSFX Stable](https://github.com/Psysia/PsyReaSFX/releases/latest)
- [PsyReaSFX 0.9.0 Beta 7.8 preview](https://github.com/Psysia/PsyReaSFX/releases/tag/v0.9.0-beta7.8)
- [Manual ZIP fallback for the optional Beta 7.8 neural component](https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0-beta7.8/PsyReaSFX_Neural_Similarity_v0_9_0_beta7_8_win_x64.zip)
- [PsyReaSFX 0.7.23 Stable archive](https://github.com/Psysia/PsyReaSFX/releases/tag/v0.7.23)
- [All releases](https://github.com/Psysia/PsyReaSFX/releases)
- [Desktop project notes](desktop/README.md)

[Releases](https://github.com/Psysia/PsyReaSFX/releases) · [User Guide](docs/USER_GUIDE_en-US.md) · [Changelog](docs/CHANGELOG_en-US.md)

## Documentation

| Document | Scope |
|---|---|
| [REAPER Tools Guide](docs/REAPER_TOOLS_GUIDE_en-US.md) | Installation and usage for the utility scripts. |
| [PsyReaSFX User Guide](docs/USER_GUIDE_en-US.md) | Main application workflow and features. |
| [PsyReaSFX Changelog](docs/CHANGELOG_en-US.md) | Release history and version notes. |
| [Neural Similarity](neural/README.md) | Optional local neural component and reproducible model notes. |
| [Desktop Project](desktop/README.md) | Desktop development notes. |

Development and architecture notes are kept under `docs/` and are intentionally separated from the main project page.

## Repository Layout

```text
Scripts/Psysia/   REAPER utility scripts
docs/             User guides, changelogs, and technical notes
assets/           Artwork, fonts, screenshots, and packaged data
neural/           Optional neural-similarity component
desktop/          Desktop development files
website/          Project website
index.xml         ReaPack repository index
```

## License

Created by **Psysia**.

Copyright © 2026 Psysia. All rights reserved.

See [LICENSE](LICENSE) for repository licensing details. Third-party assets retain their respective licenses.
