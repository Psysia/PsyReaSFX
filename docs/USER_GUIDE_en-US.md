# PsyReaSFX 0.6.18 Stable RC7 User Guide

## 1. Purpose

PsyReaSFX is a REAPER-based sound-asset browser, search, audition, waveform-selection, region, metadata, collection, and insertion tool. It uses a high-density asset table and a modular workspace, with the original Forge Compact and Aether Standard workflow presets.

This guide documents the current 0.6 feature set. Release-by-release changes are kept in the separate changelog.

## 2. Requirements

### Required

- REAPER 7.x
- ReaImGui 0.10 or later

### Strongly recommended

- SWS Extension

SWS is used for precise waveform seeking, selection preview, Pitch/Rate/Gain preview controls, channel audition, drag-and-drop into the REAPER arrange view, and several Preview API parameters. Without SWS, basic browsing, searching, and indexing still work, but advanced preview and transfer features are limited.

## 3. Installation and upgrade

1. Extract the release package.
2. Open REAPER's Action List.
3. Choose `ReaScript: Load...`.
4. Load `PsyReaSFX_v0_6_18_Stable_RC7.lua`.
5. Reassign any shortcut previously bound to an older release.
6. Stop older PsyReaSFX instances.

Data is stored under:

```text
<REAPER Resource Path>/Scripts/PsyReaSFX/
```

Existing libraries, indexes, collections, regions, loudness results, and waveform caches remain compatible. The new `marked` database field is written automatically on the next database save.

## 4. Interface layout

- Top bar: search, auto-preview, scan, settings, and panel toggles.
- Left panel: libraries, playlists, project bins, saved searches, and workflow filters.
- Center: pinned column header and result list.
- Right panel: non-destructive metadata inspector.
- Bottom panel: high-resolution waveform, timeline, loudness, regions, preview, and insertion controls.

Use `F9`, `F10`, and `F11` to toggle navigation, metadata, and focus mode.


## 4.1 Appearance and Settings Center

0.6.11 uses a dark two-column Settings Center matching the main application. The left side is page navigation; the right side is scrollable content.

Pages:

- **General**: language, panels, insertion naming and fades;
- **Appearance**: full interface presets, density, surface hierarchy, console, Artwork and state colors;
- **Waveforms**: resolution, precache, navigation, transients and loudness;
- **Maintenance**: cache, database rebuild and factory reset;
- **About**: product version, runtime details, data paths, diagnostics, and support identity.

### Interface presets

```text
Settings → Appearance → Interface preset
```

- **Forge Compact**: single-line high-density rows with Waveform, Filename, Keywords/Description, Artwork and Duration;
- **Aether Standard**: layered panels and more comfortable spacing;
- **Review**: emphasizes status, metadata and comparison.

Presets change multiple related settings at once. Columns, colors and the preview console remain individually editable afterwards.

### Density and hierarchy

- **Comfortable / Balanced / Compact** alter row height, headers, icons, spacing and rounding;
- **Flat / Layered / High Contrast** alter surface separation, grid strength and text contrast;
- **Studio Strip / Focus / Minimal** control how much of the preview toolbar stays visible.

### Forge-style compact list

Compact rows now draw one vertically centered line instead of forcing a secondary line into a short row. This removes the clipped lower text shown by older builds.

### Settings navigation

The left navigation now uses custom two-line cards: page title on the first line and a short description on the second. Fixed layout and clipping bounds prevent truncated Chinese or English labels.

### Color pickers and live preview

All editable colors now use ReaImGui color pickers:

```text
Settings → Appearance → Theme / Waveform colors
```

- Click a swatch to open the picker.
- Changes apply immediately.
- The current `#RRGGBB` value is shown as reference only.
- Every color row has an independent reset action.
- Manual color-code entry is no longer required.

Editable colors include the accent, normal/selected/played/marked waveforms, played text, selection, playhead, and Region colors.


### If a color swatch does not open

0.6.12 RC1 removes the full-row `InvisibleButton` that previously consumed the click before it reached `ColorEdit3`. Click the small swatch, choose a color, and the result applies immediately. Use Reset to restore the default for that field.

### About page

```text
Settings → About
```

The page shows:

- PsyReaSFX version and author;
- REAPER, operating system, ReaImGui, and SWS status;
- current preview backend;
- data directory;
- open-data-folder and open-documentation-folder actions;
- copyable diagnostics.

License, official website, and support-contact fields are currently placeholders.


## 5. Libraries

Use `+ Add library` to select a root folder. PsyReaSFX scans subfolders recursively, reads metadata, and prepares list waveforms in staged background tasks.

The library manager can open a root folder, rebuild its index, or remove it from PsyReaSFX. Removing a library never deletes source audio files.

## 6. Search

### Plain text

```text
cinematic whoosh
metal impact
magic ui
```

### Field filters

```text
category:impact
subcategory:metal
catid:WPN
library:boom
description:heavy
keywords:magic
channels:2
status:candidate
marked:true
played:true
```

### Exclusions

```text
whoosh -long
impact -debris
```

Filters can be combined in one query.

## 7. Columns

The header remains pinned while the result list scrolls. Drag column dividers to resize them; double-click a divider to restore default widths. Right-click the header to show or hide waveform, filename, status, description, category, duration, format, library, path, and other fields.

When the combined field width exceeds the center workspace, no horizontal scrollbar is drawn. Hover the pinned header or any result row and use `Shift + mouse wheel`. Scrolling is clamped from the first position through the rightmost field, and the pinned header follows the same horizontal position.

### Compact preview information

The file or selection range, Region count, channel-monitoring mode, loudness-match state, and current operation status share the metric row. The separate summary and green status rows have been removed, allowing the waveform to use the released height.

### Separate channel lanes

Enable `Settings → Waveforms → Show separate channel lanes` to display the high-resolution preview as `M` for mono, `L` / `R` for stereo, or `CH 1–8` for multichannel files. Selections, Regions, the ruler, and the playhead span all lanes.

Channel lanes use the new `RWF3` high-resolution cache. Existing `RWF2` list thumbnails remain compatible, so upgrading does not rebuild the entire thumbnail library. High-resolution precaching creates reusable channel-aware data.

Hidden fields are not drawn, which reduces UI work for large result sets.

### Artwork column

Right-click the fixed header and enable `Artwork` to display square thumbnails. The Forge Compact preset enables it by default.

Artwork lookup checks the source folder and then parent folders up to the library root, with a seven-level limit. Preferred names include `artwork`, `cover`, `folder`, `front`, `album` and `thumbnail`, using PNG or JPEG files. A cover can also be selected manually from the metadata inspector.

Artwork discovery uses a low-priority queue and folder-level negative caching. Hidden Artwork columns do not request thumbnails for invisible rows.

## 8. Selection, favorites, and marks

| Action | Result |
|---|---|
| Click | Single selection |
| Ctrl+click | Add or remove one item |
| Shift+click | Range selection |
| Ctrl+A | Select all visible results |
| F | Toggle favorite |
| M | Toggle mark |

Favorites are intended for long-term organization. Marks are a lightweight review state for temporary filtering and visual identification. Search marked assets with `marked:true`.

The row context menu supports bulk favorite, mark, workflow status, collection, and insertion actions.

## 9. State colors and session-played highlighting

Open:

```text
Settings → Appearance → Colors and states
```

The palette includes normal, selected, played and marked waveforms; played text; selection; playhead; and Region colors.

### Forge-style played text

After an asset actually starts previewing during the current launch, text columns such as Filename, Keywords/Description, Duration and Library use the configurable played color. The default is a warm yellow close to Forge.

This is a **session-only visual state**:

- reopening the script resets the text to its normal color;
- persistent preview history in `history_v1.tsv` is not deleted;
- `played:true` still searches historical preview records;
- the main toolbar reset icon clears the current session immediately;
- the same command is available from View and Settings.

Played waveform coloring is optional and disabled by default to avoid competing with selection and mark colors.

Waveform priority remains:

```text
selected > marked > played waveform (when enabled) > normal
```


## 10. List waveforms

List waveforms use 256 points by default and can be increased to 512 points. Click any position in a list waveform to start preview from that time. The active preview row displays a mini playhead.

High-resolution library precaching supports 2048 or 4096 points and writes results to disk without keeping the entire library in memory.

## 11. Large waveform

### Navigation

- Mouse wheel: zoom around the pointer.
- Shift+wheel: horizontal pan.
- Middle drag: horizontal pan.
- Double-click: reset zoom.
- Right drag: scrub preview.

### Selection

Left-drag to create a selection. Preview only the selection, auto-loop it, or drag the selection handle directly into the REAPER arrange view.

### Loudness

The information bar can display LUFS-I, maximum momentary LUFS, maximum short-term LUFS, and True Peak. Results are calculated on demand and cached in `loudness_v1.tsv`.

## 12. Regions and transient detection

A long recording can contain multiple non-destructive regions. Region data is saved to `regions_v1.tsv` and never modifies the source WAV.

Transient detection supports:

- dBFS threshold
- envelope smoothing
- minimum transient gap
- pre-roll and post-roll
- maximum region count
- replacement of previous transient suggestions

Detected regions are tagged `[T]`; manual regions are tagged `[M]`. You can undo the latest detection, clear all transient suggestions, or delete individual regions.

## 13. Preview

Supported controls include:

- Pitch: -24 to +24 semitones
- Rate: 0.25x to 4x
- Gain: -36 dB to +18 dB
- Preserve Pitch
- Loop
- Reverse
- Original, left, right, and mono audition
- Estimated loudness matching
- Pitch and rate presets

Estimated matching is intended for quick comparison and is not a standards-compliant LUFS measurement. It affects preview only.

## 14. Insertion and drag transfer

PsyReaSFX can:

- Insert on the current track
- Insert on a new track
- Insert at the BWF timestamp
- Insert only the current waveform selection
- Stack multiple selected files on separate tracks
- Drag list files or waveform selections into the REAPER arrange view

This is an internal PsyReaSFX-to-REAPER workflow, not general Windows file drag-and-drop.

## 15. Collections and workflow

Create multiple playlists and project bins, add or remove files in bulk, and save search states including query text, library filter, collection, workflow status, and sort order.

Workflow status values are Unmarked, Candidate, Approved, and Rejected. Workflow status is separate from the independent `marked` flag added in 0.6.8.

## 16. Metadata and pinned Artwork

The inspector edits Description, Keywords, Category, SubCategory, CatID, Library and Artwork path without modifying source audio metadata.

For a single selected asset, the full cover can be pinned above the scrolling metadata area:

- cover, asset name and cover controls remain fixed;
- metadata and file information scroll independently below;
- the cover does not move while reviewing long metadata;
- users can choose a cover, rerun automatic detection or explicitly clear the cover;
- disabling pinning makes the cover scroll with metadata.

Artwork currently uses external PNG/JPEG files. Embedded artwork inside audio containers is not extracted in this version.


## 17. Appearance and performance

### Interface

The application provides three complete presets, three density levels, three surface styles, adjustable columns, a fixed header, collapsible panels and a responsive preview console.

### 0.6.10 optimization work

- session-played state uses a path hash table for constant-time lookup;
- Artwork discovery caches negative folder results and does not rescan empty folders every frame;
- Artwork processing is a low-priority single-job queue that yields during input, scanning and imports;
- ReaImGui image objects are attached for persistence and capped by an image-cache limit;
- thumbnails are requested only for visible Artwork rows and the selected asset;
- compact rows render one primary text line, reducing clipping and duplicate drawing;
- the Settings Center is drawn only while open and adds no database work to normal browsing.

### General performance rules

- only visible rows are drawn;
- hidden columns are skipped;
- scan, metadata, loudness and waveform jobs are frame-budgeted;
- heavy jobs yield during mouse interaction;
- high-resolution precache writes to disk instead of holding the full library in memory;
- Regions, collections, history and loudness use separate lightweight files.


## 18. Data files

| File | Purpose |
|---|---|
| `config.tsv` | UI, theme, language, roots, and column settings |
| `index_v3.tsv` | Asset index, metadata, workflow, preview history, and marks |
| `wave_cache_v3/` | Multi-resolution waveform cache |
| `collections_v1.tsv` | Playlists and project bins |
| `saved_searches_v1.tsv` | Saved searches |
| `history_v1.tsv` | Preview history |
| `last_played_session_v1.tsv` | Previous-session yellow highlight snapshot |
| `regions_v1.tsv` | Regions and transient suggestions |
| `loudness_v1.tsv` | Loudness analysis cache |

Back up the entire PsyReaSFX data directory regularly.

## 19. Shortcuts

| Shortcut | Action |
|---|---|
| Space | Play or stop |
| Up / Down | Move selection |
| Enter | Insert |
| Ctrl+Enter | Insert on a new track |
| Ctrl+A | Select all current results |
| Ctrl+F | Focus search |
| Ctrl+R | Incremental scan |
| F | Toggle favorite |
| M | Toggle mark |
| L | Toggle loop |
| F9 | Toggle navigation |
| F10 | Toggle metadata inspector |
| F11 | Toggle focus mode |

## 20. Maintenance and troubleshooting

The Maintenance tab can clear waveform caches, reset interface settings, rebuild the database while keeping roots, or perform a factory reset.

Common issues:

- Waveforms are slow on first display: allow the visible-row cache to finish or run high-resolution precache.
- Precise waveform seeking does not work: install or update SWS.
- Drag transfer fails: release the pointer over the REAPER arrange view.
- Some text is garbled: the source file metadata may use a legacy encoding.
- Large libraries feel slow: hide unused columns, use focus mode, and do not run multiple PsyReaSFX versions.

## 21. Development stage

The primary 0.6 feature set is complete. Version 0.6.10 remains a 0.6 stabilization, interface-refinement and gap-closing release. Artwork, compact layout, session-state reset and Settings Center behavior should be validated before the project enters the 0.7 Transfer stage.
