<p align="right">
  <a href="README.md"><img src="https://img.shields.io/badge/Language-English-2f81f7" alt="English"></a>
  <a href="README_zh-CN.md"><img src="https://img.shields.io/badge/Language-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-555555" alt="简体中文"></a>
</p>

# PsyReaSFX 0.7.4 Beta 6

PsyReaSFX is a sound-asset browser, waveform audition, metadata, region,
collection, insertion, and Transfer workflow built inside REAPER.

**Author:** Psysia  
**Package version:** 0.7.4-beta.6  
**Release stage:** Beta

<p align="center">
  <img src="assets/screenshots/compact-workspace.png" alt="PsyReaSFX workspace with navigation and metadata panels" width="100%">
</p>

## Library navigation and shared Artwork

Beta 6 is a focused UI-state hotfix. It defines the theme accent and muted
colors used by the new disclosure control, Library Manager, and folder-drop
overlay. Opening the left panel no longer interrupts the active ImGui child,
so closing PsyReaSFX does not produce the secondary `Missing EndChild()` error.

- The disclosure arrow beside a logical library is now a real control: click
  it once to expand or collapse source folders. The state is saved.
- Artwork discovery always checks the physical source root even when an asset
  is nested more than seven folders deep.
- Common `Artwork`, `Images`, `Docs`, and `Documentation` subfolders are also
  checked, with additional library/product/preview cover filenames.
- A logical library can store one shared cover used by both the Artwork column
  and the pinned metadata inspector. Choose it from the library context menu
  or Library Manager when automatic discovery cannot locate the image.
- Failed image decodes use a short retry delay instead of retrying every frame.

## Multi-root logical libraries

Beta 4 lets a logical library exist before any source folder is attached.
Choose **New library**, name it, and add or drop source folders whenever they
become available. This keeps library organization independent of disk layout.

The multi-root model separates the library users browse from physical folders that are
scanned. A single logical library can now aggregate any number of source
folders across drives while remaining one searchable library in the sidebar.

- Click a logical library to browse every source folder it owns.
- Expand it to browse an individual source folder; hover it to inspect paths,
  online status, and indexed-file counts.
- Drop Explorer/Finder folders on a library to add sources, on **All
  libraries** to create libraries, or in the results area to use the current
  library context.
- Multiple dropped folders can become separate libraries or one combined
  logical library.
- Exact duplicates, overlapping parent/child roots, and cross-library
  ownership are checked before scanning. Moving a root never moves disk files.
- Legacy one-folder libraries migrate automatically and keep their existing
  database, metadata, collections, and waveform cache.

The source hierarchy is stored in `libraries_v2.tsv`. Playlists and project
bins remain virtual collections and are intentionally separate from library
ownership.

## Duration and large-library responsiveness

- Duration cells now use a fixed `MM:SS.mmm` timecode such as `00:04.947`.
- Directory scanning uses an indexed queue instead of repeatedly shifting the
  remaining directory list.
- New files inherit their known source folder directly instead of searching
  every configured root again.
- Results and library counts rebuild once at scan/import boundaries rather
  than once per discovered file.
- Adding several dropped source folders rebuilds the library map once for the
  batch.

## 0.7 Transfer

The first 0.7 build adds a non-destructive Transfer panel for turning the
current file, its waveform selection, or multiple selected assets into new
audio files.

- Name files with `{name}`, `{category}`, `{subcategory}`, `{library}`,
  `{index}`, `{date}`, and `{region}` tokens.
- Export WAV 24-bit PCM or FLAC at the source, 44.1, 48, 96, or 192 kHz.
- Keep source channels, or convert to mono or stereo.
- Apply the current Pitch, Rate, Gain, Reverse, and Preserve Pitch settings.
- Add render fades and Peak, True Peak, or LUFS-I normalization.
- Increment, skip, or explicitly overwrite name collisions.
- Optionally insert each completed file back into REAPER.

Open Transfer from the lower toolbar or press `Ctrl+T`.

## System metadata filtering

Beta 2 no longer indexes macOS AppleDouble `._*` sidecars or common metadata
folders such as `__MACOSX`, `.AppleDouble`, and `@eaDir`. These files can keep
an audio extension while containing no playable audio. Existing false entries
are ignored automatically when the new version opens; source files are never
deleted.

> Beta 1 renders the source media dry. Track FX, sends, and Master FX are not
> included. Batch Transfer uses each complete source file; waveform selection
> is available for the current asset.

## Workspace preview

The unified workspace keeps library navigation, inline waveforms, Artwork,
metadata, and the multichannel audition waveform in one responsive window.

### Focus mode

<p align="center">
  <img src="assets/screenshots/focus-workspace.png" alt="PsyReaSFX focus mode with an expanded results table and waveform preview" width="100%">
</p>

Focus mode collapses both side panels so the result table and detailed waveform
can use the full REAPER workspace.

## Installation with ReaPack

Import this repository URL once in
`Extensions > ReaPack > Import repositories...`:

```text
https://github.com/Psysia/PsyReaSFX/raw/main/index.xml
```

Synchronize ReaPack, search for `PsyReaSFX`, then install it. Future updates
are available directly from ReaPack.

ReaImGui is required. SWS Extension is strongly recommended and is required
for Reverse Transfer and several advanced audition operations.

## Manual installation

Load `PsyReaSFX_v0_7_4_Beta_6.lua` from REAPER's Action List.

## Documentation

- [English User Guide](docs/USER_GUIDE_en-US.md)
- [English Changelog](docs/CHANGELOG_en-US.md)
- [简体中文用户使用说明书](docs/USER_GUIDE_zh-CN.md)
- [简体中文更新日志](docs/CHANGELOG_zh-CN.md)

## Package structure

```text
PsyReaSFX_v0_7_4_Beta_6.lua
README.md
README_zh-CN.md
index.xml
assets/screenshots/
docs/
```

PsyReaSFX 0.6 Stable remains the recommended fallback while 0.7 Transfer is
being tested against different REAPER, ReaImGui, SWS, file-format, and project
configurations.

