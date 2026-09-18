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

Detailed behavior, edge cases, dependencies, and shortcut suggestions are documented in the [REAPER Tools Guide](docs/REAPER_TOOLS_GUIDE_en-US.md).

## PsyReaSFX

**PsyReaSFX** is a dockable sound-asset workspace for REAPER. It combines library management, waveform browsing, audition, metadata, collections, search, REAPER insertion, and processed delivery in one workflow.

| Channel | Version | Notes |
|---|---|---|
| Stable | **0.8.5** | Recommended for everyday use. |
| Preview | **0.9.0 Beta 7.3** | Current pre-release line with AI semantic search and optional neural similarity support. |
| Optional component | **PsyReaSFX Neural Similarity** | Local neural similar-sound search for Windows x64. |

PsyReaSFX keeps normal acoustic search available without the optional neural component. AI semantic search is a separate API-based feature; user audio is not uploaded by that feature.

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
