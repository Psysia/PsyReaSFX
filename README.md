# PsyReaSFX 0.6.17 Stable RC6

PsyReaSFX is a REAPER sound-effects browser, audition, waveform, metadata, region and asset-management ReaScript.

**Author:** Psysia  
**Release stage:** 0.6 stable candidate (RC6)

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

## Installation

Load `PsyReaSFX_v0_6_17_Stable_RC6.lua` from REAPER's Action List. ReaImGui is required; SWS Extension is strongly recommended.

## Release package structure

```text
PsyReaSFX_v0_6_17_Stable_RC6.lua
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


## 0.6.17 Stable RC6 highlights

- Replaces the permanent full-width result scrollbar with a slim overlay that
  appears while the result table is hovered, dragged, or Shift-scrolled.
- Keeps the fixed header synchronized and preserves every configured column
  width without dedicating a full row to navigation.
- Adds the `RWF3` high-resolution cache format with separate waveform lanes for
  mono, stereo (`L` / `R`), and up to eight-channel source files (`CH 1–8`).
- Keeps existing `RWF2` list thumbnails compatible; only high-resolution channel
  previews are generated again on demand.
- Consolidates preview actions, Pitch, Rate, Gain, and optional monitoring
  switches into a lightweight studio strip with smaller vector icons.
