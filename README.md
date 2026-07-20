# PsyReaSFX 0.6.15 Stable RC4

PsyReaSFX is a REAPER sound-effects browser, audition, waveform, metadata, region and asset-management ReaScript.

**Author:** Psysia  
**Release stage:** 0.6 stable candidate (RC4)

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

Load `PsyReaSFX_v0_6_15_Stable_RC4.lua` from REAPER's Action List. ReaImGui is required; SWS Extension is strongly recommended.

## Release package structure

```text
PsyReaSFX_v0_6_15_Stable_RC4.lua
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


## 0.6.15 Stable RC4 highlights

- Completes the English localization audit for Settings, help, maintenance,
  waveform controls, status messages, and the bottom preview summary.
- Keeps user-authored filenames, library names, metadata, and collection names
  unchanged while translating application-owned interface text.
- Adds a horizontal scrollbar when visible result columns exceed the workspace.
- Keeps the pinned header aligned with horizontally scrolled result columns.
- Preserves configured column widths instead of crushing dense layouts into the
  current window width.
- Adds compact and Focus-mode screenshots to the GitHub project landing page.
- Preserves the official project link in both script metadata and About.
