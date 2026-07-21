# PsyReaSFX 0.6.18 Stable RC7

PsyReaSFX is a REAPER sound-effects browser, audition, waveform, metadata, region and asset-management ReaScript.

**Author:** Psysia  
**Release stage:** 0.6 stable candidate (RC7)

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

Load `PsyReaSFX_v0_6_18_Stable_RC7.lua` from REAPER's Action List. ReaImGui is required; SWS Extension is strongly recommended.

## Release package structure

```text
PsyReaSFX_v0_6_18_Stable_RC7.lua
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


## 0.6.18 Stable RC7 highlights

- Removes the result-table scrollbar entirely. `Shift + mouse wheel` pans every
  overflowing column from the first position through the rightmost field.
- Moves file/selection context, Region count, channel mode, loudness-match state,
  and operation status into the compact metric row.
- Removes the separate bottom status row and its reserved window area.
- Sizes the lower preview panel from its actual header, waveform, metric row, and
  Studio Strip content so Forge and Aether layouts no longer leave a blank block.
- Keeps action buttons and Pitch, Rate, and Gain controls at the same height while
  increasing spacing between parameter cards.
- Retains the RC6 `RWF3` mono, stereo, and multichannel waveform lanes.
