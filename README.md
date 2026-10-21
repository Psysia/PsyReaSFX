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

<p align="center">
  <a href="https://psysia.github.io/PsyReaSFX/">
    <img src="website/assets/showcase/prs-workspace-0-9.png" alt="PsyReaSFX 0.9 Beta 7.10 real application interface" width="1000">
  </a>
</p>
<p align="center"><em>Actual PsyReaSFX 0.9 Beta 7.10 workspace · UCS navigation, sound lists, inline waveforms and detailed audition.</em></p>
<p align="center"><a href="https://psysia.github.io/PsyReaSFX/">Website / 官网</a> · <a href="https://psysia.github.io/PsyReaSFX/#scripts">Live GIF demos / 动态演示</a> · <a href="https://github.com/Psysia/PsyReaSFX/releases">Releases</a></p>

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

### Neural similar-sound search: download and installation

**Find Similar Sounds automatically chooses between two engines: built-in
15-feature acoustic search, and EfficientAT neural search, which requires a
separate component. Updating the main script does not install that component.**
AI semantic search is a separate feature and does not require it.

**[Download the complete neural ZIP · Beta 7.14 · Windows x64 · about 42.4 MB][neural-download]**
(includes executable, model and installers; the standalone Release EXE does not include the model).

- **Recommended — ReaPack:** synchronize the repository above, open
  `Extensions → ReaPack → Browse packages`, search for
  [PsyReaSFX Neural Similarity][neural-download], and select the separate data package,
  not the main script. Right-click → **Enable pre-releases (bleeding-edge)** →
  **Versions** → `0.9.0-beta7.14`; uncheck **Pin current version**, click
  **Apply / OK**, wait for downloads, then close the old window and rerun PsyReaSFX.
- **Manual:** download the complete ZIP above, extract everything, double-click
  `Install-NeuralSimilarity.cmd`, then restart PsyReaSFX.
  For portable REAPER, see the [resource-path instructions](neural/package/README.md#manual-zip-fallback).

Choose one installation method. ReaPack installs to
`<REAPER Resource Path>\Data\PsyReaSFX\neural_similarity\`;
the manual installer defaults to `%APPDATA%\REAPER\Scripts\PsyReaSFX\neural_similarity\`.
No separate Python or .NET runtime is required. Audio stays local and no
converted copies are created. First use builds a cancelable embedding cache
and index; a missing or failed component automatically falls back to acoustic search.

### Want the newest features? Install the 0.9 Beta

Normal synchronization follows Stable; **it does not opt you into Beta**. New UCS classification, similar-sound search, AI semantic search and startup animation are in the 0.9 Beta:

1. Run `Extensions → ReaPack → Synchronize packages`, open `Browse packages`, and search for `PsyReaSFX`.
2. Right-click the main `PsyReaSFX` script package (`PsyReaSFX.lua`) and enable **Enable pre-releases (bleeding-edge)**.
3. Right-click again → **Versions** → select the newest `0.9.0-beta…` (currently `0.9.0-beta7.14`). Leave **Pin current version** unchecked; unpin it first if needed.
4. Click **Apply**, or **OK** to confirm installation. After downloads finish, close the old PsyReaSFX window and rerun it from REAPER's Action List.

<p><a href="website/assets/screenshots/reapack-enable-beta.jpg"><img src="website/assets/screenshots/reapack-enable-beta.jpg" alt="ReaPack context menu: Enable pre-releases and Versions, then Apply or OK to install the latest Beta" width="800"></a></p>

The screenshot illustrates the menu locations and was captured before pruning older Betas. After synchronization, Versions contains only the newest Beta, 0.8.5 Stable and 0.7.23 Stable. Historical releases remain on GitHub Releases.

**Neural search requires a separate package; AI search requires your own API settings.** On Windows x64, repeat the pre-release/install steps for [PsyReaSFX Neural Similarity][neural-download] to enable local neural retrieval, then restart the main script. AI semantic search does not require that component, but needs your own DeepSeek / OpenAI / compatible API key and model in Settings. Enter remains normal search; the gold AI button triggers semantic search. Updating the main script does not require rebuilding your libraries.

## REAPER Utilities

| Category | Tool | Purpose |
|---|---|---|
| Rendering | Create Folder Region and Render Matrix | Single-source Regions use the exact source track for both naming and Matrix; multi-track selections use the nearest common parent. |
| Rendering | Smart Bounce (Track FX / Parent FX) | Merge selected Items or Folder/track content into one WAV (5 s max tail), without altering Solo; new-item peaks rebuild automatically. |
| Rendering | Create Nearest Parent Folder Region and Render Matrix | Single child tracks use the immediate parent Folder for both Region naming and Matrix targeting. |
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
| Display | Video Item Track Name Overlay | Show the current track name inside each video Item; directly switch to the filename mode when needed. |
| Display | Video Item Source Filename Overlay | Show the source video filename without its extension; directly switch back to track-name mode at any time. |

Detailed behavior, edge cases, dependencies, and shortcut suggestions are documented in the [REAPER Tools Guide](docs/REAPER_TOOLS_GUIDE_en-US.md).

## See the REAPER tools in action

**Real GIF recordings — not mockups.** Every clip below is a working ReaScript demonstration captured in REAPER. Individual tools can be installed through the same ReaPack repository.

[**Explore the animated gallery on the website ↗**](https://psysia.github.io/PsyReaSFX/#scripts) · [All scripts](Scripts/Psysia/) · [Full tool guide](docs/REAPER_TOOLS_GUIDE_en-US.md)

<table>
  <tr>
    <td width="50%" align="center"><strong>Smart Bounce</strong><br><img src="website/assets/showcase/smart-bounce.gif" width="440" alt="Smart Bounce REAPER workflow GIF"></td>
    <td width="50%" align="center"><strong>Video item track name overlay</strong><br><img src="website/assets/showcase/video-track-overlay.gif" width="440" alt="Video item track name overlay REAPER workflow GIF"></td>
  </tr>
  <tr>
    <td width="50%" align="center"><strong>Folder regions & render matrix</strong><br><img src="website/assets/showcase/folder-region-matrix.gif" width="440" alt="Folder regions & render matrix REAPER workflow GIF"></td>
    <td width="50%" align="center"><strong>Cycle folder compact state</strong><br><img src="website/assets/showcase/cycle-folder-compact.gif" width="440" alt="Cycle folder compact state REAPER workflow GIF"></td>
  </tr>
</table>

<details>
<summary><strong>Show 8 more REAPER tool demos</strong></summary>

<table>
  <tr>
    <td width="50%" align="center"><strong>Sort tracks by earliest item</strong><br><img src="website/assets/showcase/sort-tracks.gif" width="440" alt="Sort tracks by earliest item REAPER workflow GIF"></td>
    <td width="50%" align="center"><strong>Nearest parent folder regions</strong><br><img src="website/assets/showcase/parent-folder-region-matrix.gif" width="440" alt="Nearest parent folder regions REAPER workflow GIF"></td>
  </tr>
  <tr>
    <td width="50%" align="center"><strong>Rename from parent folder</strong><br><img src="website/assets/showcase/rename-from-parent.gif" width="440" alt="Rename from parent folder REAPER workflow GIF"></td>
    <td width="50%" align="center"><strong>Split selected items</strong><br><img src="website/assets/showcase/split-items.gif" width="440" alt="Split selected items REAPER workflow GIF"></td>
  </tr>
  <tr>
    <td width="50%" align="center"><strong>Remove gaps between items</strong><br><img src="website/assets/showcase/remove-item-gaps.gif" width="440" alt="Remove gaps between items REAPER workflow GIF"></td>
    <td width="50%" align="center"><strong>Reverse items in place</strong><br><img src="website/assets/showcase/reverse-items.gif" width="440" alt="Reverse items in place REAPER workflow GIF"></td>
  </tr>
  <tr>
    <td width="50%" align="center"><strong>Toggle LUFS-M and spectrogram</strong><br><img src="website/assets/showcase/toggle-lufs-spectrogram.gif" width="440" alt="Toggle LUFS-M and spectrogram REAPER workflow GIF"></td>
    <td width="50%" align="center"><strong>Create Folder with Pro-L 2</strong><br><img src="website/assets/showcase/create-folder-prol2.gif" width="440" alt="Create Folder with Pro-L 2 REAPER workflow GIF"></td>
  </tr>
</table>

</details>

## PsyReaSFX

**PsyReaSFX** is a dockable sound-asset workspace for REAPER. It combines library management, waveform browsing, audition, metadata, collections, search, REAPER insertion, and processed delivery in one workflow.

| Channel | Version | Notes |
|---|---|---|
| Stable | **0.8.5** | Recommended for everyday use. |
| Preview | **0.9.0 Beta 7.14** | Named AI API presets, independent encrypted keys and safe switching/testing. |
| Optional component | [PsyReaSFX Neural Similarity][neural-download] | Local neural similar-sound search for Windows x64. |

PsyReaSFX keeps normal acoustic search available without the [optional neural component][neural-download]. AI semantic search is a separate API-based feature; user audio is not uploaded by that feature.

### Feature comparison

REAPER / Lua editions only. Beta includes the Stable feature set; “—” means unavailable in that version.

| Feature | 0.7.23 Stable | 0.8.5 Stable | Latest 0.9 Beta (7.13) |
|---|---|---|---|
| Browse, waveform audition, metadata, collections and Transfer | Included | Retained | Retained |
| Interrupted-scan recovery, retries, backups and cache checks | — | Added | Retained and refined |
| Missing/duplicate checks, source relinking and project usage | — | Added | Retained |
| Incremental persistence and frame-budgeted large-library tasks | Earlier implementation | Hardened | Further startup optimization |
| Official UCS classification, review queue and virtual folders | Basic UCS fields only | Basic UCS fields only | Added |
| Spectral peak coloring | — | — | Added; opt-in |
| Audio-content similar-sound retrieval | — | — | Built-in 15-feature acoustic retrieval |
| EfficientAT local neural similarity | — | — | [Required for neural retrieval · Windows x64 ZIP][neural-download] |
| AI semantic search: query expansion, local recall and paging | — | — | Your API key/model; no [neural package][neural-download] needed |
| Branded startup animation and live loading status | — | — | Added; no fixed intro delay |

See the [Changelog](docs/CHANGELOG_en-US.md) for detailed additions and fixes,
or the [illustrated Beta installation guide](https://psysia.github.io/PsyReaSFX/#beta-install) to enable them.

### Development status

The ReaPack Versions menu keeps only the latest Beta, 0.8.5 Stable and 0.7.23 Stable; the [optional neural package][neural-download] keeps only the latest Beta. Older previews remain available on GitHub Releases. Existing installations and asset data are not deleted.

- **Stable channel: 0.8.5** — the default ReaPack release for everyday use.
- **Preview channel: 0.9.0 Beta 7.14** — up to 32 named AI API presets with independent encrypted keys, session drafts and preset-specific connection tests. Migrates your current setup; switching to a compatible service no longer overwrites DeepSeek. Retains startup optimizations and the branded splash.
- **No conversion library** — source audio is decoded, downmixed and resampled to the model's 32 kHz input in memory. PsyReaSFX does not create converted audio copies; the persistent cache stores only compact 320-dimensional FP16 embeddings and the HNSW index.

The 0.9 preview retains the current 15-dimensional acoustic search as a dependency-free baseline. The [neural similarity component][neural-download] remains optional, runs locally, and never uploads user audio.

Beta 7.14 includes the separate **AI semantic search** implementation. It remains separate from Find Similar Sounds: press `Enter` for normal search or click the gold AI button for semantic search. The AI only converts the natural-language request into bilingual retrieval terms. Candidate recall, ranking, and 120-result paging then run locally, so **Load next 120** appends immediately without another API request. Audio, filenames, metadata, directories, and file paths are never uploaded; only the query is sent. On Windows, the API key is encrypted for the current user with DPAPI.

> **ReaPack setup:** install `PsyReaSFX.lua` for the application. To enable neural search on Windows x64, install [PsyReaSFX Neural Similarity][neural-download] from the same repository as a second package. ReaPack updates both packages independently; the manual ZIP remains available only as a fallback.

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
- [PsyReaSFX 0.9.0 Beta 7.14 preview](https://github.com/Psysia/PsyReaSFX/releases/tag/v0.9.0-beta7.14)
- [Complete Beta 7.14 neural component ZIP download][neural-download]
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
| [Neural Similarity](neural/README.md) | Optional local [neural component][neural-download] and reproducible model notes. |
| [Desktop Project](desktop/README.md) | Desktop development notes. |

Development and architecture notes are kept under `docs/` and are intentionally separated from the main project page. Historical release-note drafts are preserved in [docs/releases](docs/releases/README.md); use the Changelog or GitHub Releases for version history.

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

[neural-download]: https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0-beta7.14/PsyReaSFX_Neural_Similarity_v0_9_0_beta7_14_win_x64.zip
