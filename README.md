<p align="right">
  <a href="README.md"><img src="https://img.shields.io/badge/Language-English-2f81f7" alt="English"></a>
  <a href="README_zh-CN.md"><img src="https://img.shields.io/badge/Language-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-555555" alt="简体中文"></a>
</p>

<p align="center">
  <img src="assets/brand/psyreasfx-hero.png" alt="PsyReaSFX — Sound Assets Organized" width="100%">
</p>

<p align="center">
  <strong>Sound Assets Organized</strong><br>
  Browse · Organize · Preview
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-0.7.5--beta.7-19D8FF" alt="Version 0.7.5 beta 7">
  <img src="https://img.shields.io/badge/Host-REAPER-13253D" alt="REAPER">
  <img src="https://img.shields.io/badge/Install-ReaPack-0A1020" alt="ReaPack">
</p>

# PsyReaSFX 0.7.5 Beta 7

PsyReaSFX is a sound-asset browser, waveform audition, metadata, region,
collection, insertion, and Transfer workflow built inside REAPER.

**Author:** Psysia  
**Package version:** 0.7.5-beta.7  
**Release stage:** Beta

<p align="center">
  <img src="assets/screenshots/compact-workspace.png" alt="PsyReaSFX workspace with navigation and metadata panels" width="100%">
</p>

## Brand refresh and source-owned Artwork

Beta 7 applies the official PsyReaSFX visual system across the project and
makes Artwork ownership match the physical source structure.

- The disclosure arrow beside a logical library is now a real control: click
  it once to expand or collapse source folders. The state is saved.
- The default interface uses Deep Navy, Dark Slate, Electric Cyan, Soft White,
  and Cool Gray from the PsyReaSFX brand palette.
- About now displays the packaged PsyReaSFX icon, product line, version,
  copyright, and project link in one minimal product card.
- Every physical source folder owns its own Artwork. A cover found under one
  source never propagates to sibling sources in the same logical library.
- Right-click a source folder to choose, rediscover, or clear its cover.
- An asset-specific cover still takes priority over its source-folder cover.
- Common `Artwork`, `Images`, `Docs`, and `Documentation` subfolders are also
  checked, with additional library/product/preview cover filenames.
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

Load `PsyReaSFX_v0_7_5_Beta_7.lua` from REAPER's Action List.

## Documentation

- [English User Guide](docs/USER_GUIDE_en-US.md)
- [English Changelog](docs/CHANGELOG_en-US.md)
- [简体中文用户使用说明书](docs/USER_GUIDE_zh-CN.md)
- [简体中文更新日志](docs/CHANGELOG_zh-CN.md)

## Package structure

```text
PsyReaSFX_v0_7_5_Beta_7.lua
README.md
README_zh-CN.md
index.xml
assets/brand/
assets/screenshots/
docs/
```

PsyReaSFX 0.6 Stable remains the recommended fallback while 0.7 Transfer is
being tested against different REAPER, ReaImGui, SWS, file-format, and project
configurations.

