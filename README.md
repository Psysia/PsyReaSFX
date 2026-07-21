# PsyReaSFX 0.6.20 Stable RC9

PsyReaSFX is a REAPER sound-effects browser, audition, waveform, metadata, region and asset-management ReaScript.

**Author:** Psysia  
**Release stage:** 0.6 stable candidate (RC9)

<p align="center">
  <img src="assets/screenshots/compact-workspace.png" alt="PsyReaSFX compact workspace with navigation and metadata panels" width="100%">
</p>

## Workspace preview

The compact workspace keeps library navigation, inline waveforms, Artwork,
metadata, and the large audition waveform visible in one window.

### Focus mode

<p align="center">
  <img src="assets/screenshots/focus-workspace.png" alt="PsyReaSFX focus mode with an expanded results table and waveform preview" width="100%">
</p>

Focus mode collapses both side panels so the result table and detailed waveform
can use the full REAPER workspace.

## Documentation

### 简体中文

- [用户使用说明书](docs/USER_GUIDE_zh-CN.md)
- [更新日志](docs/CHANGELOG_zh-CN.md)

### English

- [User Guide](docs/USER_GUIDE_en-US.md)
- [Changelog](docs/CHANGELOG_en-US.md)

## Installation with ReaPack

Import this repository URL in `Extensions > ReaPack > Import repositories...`:

```text
https://github.com/Psysia/PsyReaSFX/raw/main/index.xml
```

Synchronize ReaPack, search for `PsyReaSFX`, then install it. Future versions
can be installed from ReaPack's package browser without downloading a new ZIP.

ReaImGui is required; SWS Extension is strongly recommended.

## Manual installation

Load `PsyReaSFX_v0_6_20_Stable_RC9.lua` from REAPER's Action List.

## Release package structure

```text
PsyReaSFX_v0_6_20_Stable_RC9.lua
index.xml
README.md
assets/
  screenshots/
    compact-workspace.png
    focus-workspace.png
docs/
  USER_GUIDE_zh-CN.md
  USER_GUIDE_en-US.md
  CHANGELOG_zh-CN.md
  CHANGELOG_en-US.md
```

The user guide and changelog are maintained as separate bilingual documents, which keeps operational documentation distinct from version history.


## 0.6.20 Stable RC9 highlights

- Consolidates the product around one compact, flat, responsive interface while
  keeping columns, navigation, metadata, focus mode, and panel height adjustable.
- Removes outer frames from time metrics and Pitch, Rate, and Gain controls;
  interactive icon buttons retain their consistent bordered treatment.
- Increases the lower-panel safety reserve so the icon row remains visible in
  short windows.
- Adds the official `index.xml` ReaPack channel for one-time installation and
  future in-app updates.
- Keeps the scrollbar-free result table and complete `Shift + mouse wheel`
  navigation through every overflowing field.
- Retains the RC6 `RWF3` mono, stereo, and multichannel waveform lanes.
