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

The neural component uses the AudioSet-trained [EfficientAT `mn04_as`](https://github.com/fschmid56/EfficientAT) model to turn audio into compact learned features (embeddings), finds nearby sounds with HNSW, then refines results using acoustic features. It compares audio characteristics rather than interpreting a text request. Inference runs locally and caches features; audio is never uploaded. Thanks to the EfficientAT / [EfficientAT_HEAR](https://github.com/fschmid56/EfficientAT_HEAR) authors for their MIT-licensed model and implementation, and to Google’s [AudioSet](https://research.google.com/audioset/) project for the upstream training dataset. [Model provenance and license](assets/neural/mn04_as_scene_320_v1/manifest-v1.json).

**Find Similar Sounds automatically chooses between two engines: built-in
15-feature acoustic search, and EfficientAT neural search, which requires a
separate component. Updating the main script does not install that component.**
AI semantic search is a separate feature and does not require it.

**[Download the complete neural ZIP · 0.9.0 · Windows x64 · about 42.4 MB][neural-download]**
(includes executable, model and installers; the standalone Release EXE does not include the model).

- **Recommended — ReaPack:** synchronize the repository above, open
  `Extensions → ReaPack → Browse packages`, search for
  [PsyReaSFX Neural Similarity][neural-download], and select the separate data package,
  not the main script. Select **Install** or **Versions** → `0.9.0`; uncheck **Pin current version**, click
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

### Update to 0.9.0 Stable

0.9.0 is now the default stable release and includes all Beta 8.7 features. **Normal ReaPack synchronization is sufficient; Enable pre-releases is not required.**

1. Run `Extensions → ReaPack → Synchronize packages`, open `Browse packages`, and search for `PsyReaSFX`.
2. If an older version is pinned, right-click the main `PsyReaSFX.lua` package and uncheck **Pin current version**.
3. Install/update `0.9.0` under **Versions** and click **Apply / OK**.
4. After downloads finish, close the old window and rerun PsyReaSFX from REAPER's Action List.

<p><a href="website/assets/screenshots/reapack-enable-beta.jpg"><img src="website/assets/screenshots/reapack-enable-beta.jpg" alt="Historical ReaPack menu example: Versions, Pin current version and Apply / OK" width="800"></a></p>

This historical Beta screenshot shows the menu locations. The pre-release checkbox is only for future test builds. Versions now retains 0.9.0, 0.8.5 and 0.7.23 Stable; historical Betas remain on GitHub Releases.

**Neural search needs the separate [PsyReaSFX Neural Similarity][neural-download] package.** Install its stable 0.9.0 data package through ReaPack or use the complete ZIP above. Components from Beta 8.5 onward remain compatible. **AI semantic search needs your own API settings**, configured in Settings; Enter runs normal search and the gold AI button runs AI search. Updating the main script requires no library rebuild.

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
| Stable | **0.9.0** | Default release; includes the complete Beta 8.7 feature set. |
| Archived Stable | **0.8.5 / 0.7.23** | Retained in ReaPack Versions and GitHub Releases. |
| Optional component | [PsyReaSFX Neural Similarity][neural-download] | Local neural similar-sound search for Windows x64. |

PsyReaSFX keeps normal acoustic search available without the [optional neural component][neural-download]. AI semantic search is a separate API-based feature; user audio is not uploaded by that feature.

### Feature comparison

REAPER / Lua editions only. 0.9.0 includes the earlier Stable feature set; “—” means unavailable in that version.

| Feature | 0.7.23 Stable | 0.8.5 Stable | 0.9.0 Stable |
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
| 10–24 px font scaling and adaptive waveform columns | — | — | Added; Settings → Font & navigation |
| Independent search/browsing tabs | — | — | Added; + under search, Ctrl+N / Ctrl+Tab |
| Sidebar folder hierarchy / roots-only and module visibility | — | — | Added; library, folder or both views |

See the [Changelog](docs/CHANGELOG_en-US.md) for detailed additions and fixes,
or the [illustrated Stable update guide](https://psysia.github.io/PsyReaSFX/#beta-install) to enable them.

### Development status

The ReaPack Versions menu keeps 0.9.0, 0.8.5 and 0.7.23 Stable; the [optional neural package][neural-download] keeps 0.9.0 Stable. Older previews remain available on GitHub Releases. Existing installations and asset data are not deleted.

- **Stable channel: 0.9.0** — the default ReaPack release for everyday use.
- **Included in 0.9.0** — right-click the metadata inspector to locate the specific publisher product (e.g. BOOM Cinematic Hits) using source Library/Album/product metadata, artwork and ancestor names. Without reliable evidence, browse the asset's current folder. A logical library or vendor collection such as Aki/BOOM is not used to group unrelated products. No popup.

**For this navigation fix, update `PsyReaSFX.lua` to 0.9.0 and restart. If your [PsyReaSFX Neural Similarity][neural-download] component is already Beta 8.5, no component update is required.** The neural executable/model and existing caches are compatible. First global computation remains costly for uncached libraries; later searches reuse the cache. Turning Watch Folder off stops future automatic checks while existing import/completion work finishes.
- **No conversion library** — source audio is decoded, downmixed and resampled to the model's 32 kHz input in memory. PsyReaSFX does not create converted audio copies; the persistent cache stores only compact 320-dimensional FP16 embeddings and the HNSW index.

0.9.0 Stable retains the current 15-dimensional acoustic search as a dependency-free baseline. The [neural similarity component][neural-download] remains optional, runs locally, and never uploads user audio.

0.9.0 includes the separate **AI semantic search** implementation. It remains separate from Find Similar Sounds: press `Enter` for normal search or click the gold AI button for semantic search. The AI only converts the natural-language request into bilingual retrieval terms. Candidate recall, ranking, and 120-result paging then run locally, so **Load next 120** appends immediately without another API request. Audio, filenames, metadata, directories, and file paths are never uploaded; only the query is sent. On Windows, the API key is encrypted for the current user with DPAPI.

> **ReaPack setup:** install `PsyReaSFX.lua` for the application. To enable neural search on Windows x64, install [PsyReaSFX Neural Similarity][neural-download] from the same repository as a second package. ReaPack updates both packages independently; the manual ZIP remains available only as a fallback.

### Main capabilities

**Browsing tabs:** the tab bar under search keeps each page's query, library/folder/collection scope, sort, selection and scroll. Click **+** or press `Ctrl+N`; right-click for duplicate, rename, close others/right and move left/right. `Ctrl+Shift+N` duplicates, `Ctrl+W` closes, `Ctrl+Tab` switches. Completed AI/similarity results and AI paging stay in memory; running requests must finish or be canceled before switching. Names/order and normal filters restore on restart, without automatic API/audio searches. Update the main script and reopen—no neural-package update or index rebuild required. [Design and performance notes](docs/UI_WORKSPACE_ARCHITECTURE_0_9_zh-CN.md).

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
- [PsyReaSFX 0.9.0 Stable](https://github.com/Psysia/PsyReaSFX/releases/tag/v0.9.0)
- [Complete 0.9.0 neural component ZIP download][neural-download]
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

**Free use, including commercial projects:** individuals and teams may use PsyReaSFX for paid sound design, games and other productions. You may deliver and sell your creative outputs. Republishing modified versions, redistributing or selling the software itself requires prior permission. Using protected project materials to train, fine-tune or distill AI models, or to generate copies/ports, is also restricted. Private internal modifications remain permitted; GitHub platform rights and third-party licenses are preserved. This is a source-available license.

Release builds include a project identifier and reproducible source fingerprint in the Lua script and diagnostics, plus `RELEASE-PROVENANCE.json` in the ZIP packages. Compare suspicious copies with official release files and SHA-256 checksums. These markers assist attribution; they cannot prevent removal or copying and perform no network tracking.

See [LICENSE](LICENSE) for repository licensing details. Third-party assets retain their respective licenses.

[neural-download]: https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip
