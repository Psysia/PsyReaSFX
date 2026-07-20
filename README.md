# PsyReaSFX 0.6.14 Stable RC3

PsyReaSFX is a REAPER sound-effects browser, audition, waveform, metadata, region and asset-management ReaScript.

**Author:** Psysia  
**Release stage:** 0.6 stable candidate (RC1)

## Documentation

### 简体中文

- [用户使用说明书](docs/USER_GUIDE_zh-CN.md)
- [更新日志](docs/CHANGELOG_zh-CN.md)

### English

- [User Guide](docs/USER_GUIDE_en-US.md)
- [Changelog](docs/CHANGELOG_en-US.md)

## Installation

Load `PsyReaSFX_v0_6_14_Stable_RC3.lua` from REAPER's Action List. ReaImGui is required; SWS Extension is strongly recommended.

## Release package structure

```text
PsyReaSFX_v0_6_14_Stable_RC3.lua
README.md
docs/
  USER_GUIDE_zh-CN.md
  USER_GUIDE_en-US.md
  CHANGELOG_zh-CN.md
  CHANGELOG_en-US.md
```

The user guide and changelog are maintained as separate bilingual documents, which keeps operational documentation distinct from version history.


## 0.6.11 highlights

- Rebuilt the Settings Center navigation to prevent clipped labels and descriptions.
- Replaced editable color-code fields with clickable color pickers and live swatch previews.
- Added an About page with runtime details, data/document paths, diagnostics, and release identity placeholders.


## 0.6.14 Stable RC3 highlights

- Saves the current yellow played-highlight set as a lightweight previous-session snapshot.
- Adds manual restore, current-view clear, saved-snapshot clear, and optional startup restore.
- Keeps the full preview history independent from the yellow highlight snapshot.
- Fixes color swatches so the click reaches `ColorEdit3` and opens the picker.
- This package is the 0.6 stable candidate. After REAPER-side verification, it can be promoted to the final 0.6 stable build without adding new features.


## 0.6.14 Stable RC3 highlights

- Removes the redundant Preview and Collections menus from the top bar.
- Uses original PsyReaSFX preset names: Forge Compact and Aether Standard.
- Adds a configurable waveform-cache directory.
- Existing cache files can be moved to the new directory or left in place.
- Moves runtime diagnostics and directory controls to Maintenance.
- Reduces About to a minimal product, version, copyright, and GitHub card.
- Copyright is © 2026 Psysia. All rights reserved.
- A single `PROJECT_URL` constant is reserved for the future GitHub repository.


## 0.6.14 Stable RC3 highlights

- Fixes the English sort caption so both the prefix and active sort field are localized.
- Adds a persistent `project_url.txt` value under the PsyReaSFX data directory.
- Preserves a hard-coded `PROJECT_URL`.
- When the new script has an empty URL, it can migrate `PROJECT_URL`, `@link`, or `@website` from an adjacent older PsyReaSFX script.
- The migrated project homepage is then independent from later script-file replacements.
