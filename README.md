# PsyReaSFX 0.6.19 Stable RC8

PsyReaSFX is a REAPER sound-effects browser, audition, waveform, metadata, region and asset-management ReaScript.

**Author:** Psysia  
**Release stage:** 0.6 stable candidate (RC8)

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

Load `PsyReaSFX_v0_6_19_Stable_RC8.lua` from REAPER's Action List. ReaImGui is required; SWS Extension is strongly recommended.

## Release package structure

```text
PsyReaSFX_v0_6_19_Stable_RC8.lua
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


## 0.6.19 Stable RC8 highlights

- Fixes Aether Standard in short windows by allocating the result list, splitter,
  and lower preview from one exact runtime height budget.
- Lets the detailed waveform reduce its minimum height progressively before any
  preview controls can be clipped outside the PsyReaSFX window.
- Makes the Studio Strip more legible with taller, equally sized buttons and
  parameter cards, wider cards, and clearer spacing.
- Shortens duplicate preview filenames in the inline status and clips remaining
  context to the actual free width.
- Keeps the scrollbar-free result table and complete `Shift + mouse wheel`
  navigation through every overflowing field.
- Retains the RC6 `RWF3` mono, stereo, and multichannel waveform lanes.
