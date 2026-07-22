# PsyReaSFX 0.7.4 Beta 6 User Guide (package 0.7.4-beta.6)

## 1. Purpose

PsyReaSFX is a REAPER-based sound-asset browser, search, audition, waveform-selection, region, metadata, collection, and insertion tool. It now uses one unified high-density, responsive workspace to reduce duplicated layout behavior and maintenance.

This guide documents the current 0.7 beta feature set. Release-by-release changes are kept in the separate changelog.

## 2. Requirements

### Required

- REAPER 7.x
- ReaImGui 0.10 or later

### Strongly recommended

- SWS Extension

SWS is used for precise waveform seeking, selection preview, Pitch/Rate/Gain preview controls, channel audition, drag-and-drop into the REAPER arrange view, and several Preview API parameters. Without SWS, basic browsing, searching, and indexing still work, but advanced preview and transfer features are limited.

## 3. Installation and upgrade

### ReaPack installation (recommended)

Import this URL from `Extensions → ReaPack → Import repositories...`:

```text
https://github.com/Psysia/PsyReaSFX/raw/main/index.xml
```

Synchronize repositories, search for `PsyReaSFX`, and install it. Future updates can be synchronized and installed from ReaPack without downloading another ZIP or rebinding the action.

### Manual installation

1. Extract the release package.
2. Open REAPER's Action List.
3. Choose `ReaScript: Load...`.
4. Load `PsyReaSFX_v0_7_4_Beta_6.lua`.
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
- **Appearance**: unified layout, lower-panel height, Artwork, themes and state colors;
- **Waveforms**: resolution, precache, navigation, transients and loudness;
- **Maintenance**: cache, database rebuild and factory reset;
- **About**: product version, runtime details, data paths, diagnostics, and support identity.

### Unified interface

```text
Settings → Appearance → Unified interface
```

PsyReaSFX now maintains one compact, flat, responsive interface. Columns and widths remain customizable from the pinned header, while navigation, metadata, and focus mode remain independently collapsible. Restore Unified Interface resets the default fields without deleting libraries or database content.

### Unified compact list

Rows use one vertically centered line instead of forcing secondary text into a short row. Right-click the pinned header and choose Reset to Default Fields when needed.

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


## 5. Logical libraries and source folders

A logical library is the name shown in the sidebar. It can own one or many
physical source folders. Clicking the library aggregates all of its sources;
expanding it lets you filter one source folder. Hover the library to see its
paths, online status, and indexed count.

Click the arrow immediately before a logical-library name to expand or
collapse its physical source folders. This does not change the current filter,
and the state is restored on the next launch.

### Add folders

- Click `+ New library`, enter a name, and create the logical library without
  selecting a folder. Add source folders whenever they become available.
- Right-click a logical library and choose `Add source folder…` to attach
  another path.
- Drop Explorer/Finder folders on a library, **All libraries**, or the central
  result area. The central target adds to the current logical library; without
  a library context it creates a new one.
- When multiple folders are dropped without a target, choose one logical
  library per folder or combine all folders into one library.

Exact duplicate and overlapping parent/child roots are blocked to prevent
duplicate indexing. Dropping a source already owned by another library offers
to move its logical ownership. None of these operations moves or deletes disk
files. Offline folders remain visible and can be restored when the drive is
available again.

Legacy root entries migrate automatically to `libraries_v2.tsv` as one logical
library with one source folder. Playlists and project bins stay separate,
virtual collections.

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

Duration uses a fixed `MM:SS.mmm` timecode such as `00:04.947`.

When the combined field width exceeds the center workspace, no horizontal scrollbar is drawn. Hover the pinned header or any result row and use `Shift + mouse wheel`. Scrolling is clamped from the first position through the rightmost field, and the pinned header follows the same horizontal position.

### Compact preview information

The file or selection range, Region count, channel-monitoring mode, loudness-match state, and current operation status share the metric row. The separate summary and green status rows have been removed, allowing the waveform to use the released height.

In short windows, the unified interface allocates the result list, splitter, and preview from one exact runtime height budget. The detailed waveform progressively reduces its minimum height before controls can leave the PsyReaSFX window. Time metrics and Pitch, Rate, and Gain use clean borderless text and parameter tracks; interactive icon buttons retain consistent frames. Preview status omits the filename already shown in the header and clips safely to the remaining width.

### Separate channel lanes

Enable `Settings → Waveforms → Show separate channel lanes` to display the high-resolution preview as `M` for mono, `L` / `R` for stereo, or `CH 1–8` for multichannel files. Selections, Regions, the ruler, and the playhead span all lanes.

Channel lanes use the new `RWF3` high-resolution cache. Existing `RWF2` list thumbnails remain compatible, so upgrading does not rebuild the entire thumbnail library. High-resolution precaching creates reusable channel-aware data.

Hidden fields are not drawn, which reduces UI work for large result sets.

### Artwork column

Right-click the fixed header and enable `Artwork` to display square thumbnails. The unified default field layout enables it by default.

Artwork lookup checks the source folder and then parent folders up to the library root, with a seven-level limit. Preferred names include `artwork`, `cover`, `folder`, `front`, `album` and `thumbnail`, using PNG or JPEG files. A cover can also be selected manually from the metadata inspector.

Artwork discovery uses a low-priority queue and folder-level negative caching. Hidden Artwork columns do not request thumbnails for invisible rows.

PsyReaSFX also checks each physical source root and common `Artwork`, `Images`,
`Docs`, and `Documentation` subfolders. A cover found there becomes shared
logical-library Artwork, so the result column and metadata inspector use the
same image. If the cover lives elsewhere, right-click the library and choose
`Choose library artwork…`, or use the Artwork button in Library Manager.

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

### Played text

After an asset actually starts previewing during the current launch, text columns such as Filename, Keywords/Description, Duration and Library use the configurable warm-yellow played color.

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

## 15. Transfer export

Open Transfer from the lower toolbar or press `Ctrl+T`. Transfer creates new
audio files without modifying the source media.

### Output and naming

Choose an output directory and a naming template. Available tokens are:

| Token | Value |
|---|---|
| `{name}` | Source filename without extension |
| `{category}` | Category metadata |
| `{subcategory}` | SubCategory metadata |
| `{library}` | Library name |
| `{index}` | Two-digit batch index |
| `{date}` | Export date as `YYYYMMDD` |
| `{region}` | Active saved Region, `selection`, or `full` |

Names are sanitized for Windows filenames. Optional lowercase conversion is
applied after token expansion.

### Scope, format, and channels

- Current asset: export the current waveform selection or the complete file.
- Multiple selected assets: each complete source file is exported.
- Format: WAV 24-bit PCM or FLAC using REAPER's default FLAC sink.
- Sample rate: source, 44.1, 48, 96, or 192 kHz.
- Channels: source channel count, mono, or stereo.

### Processing and completion

The exported audio includes the current Pitch, Rate, Gain, Reverse, and
Preserve Pitch settings. Optional render fades and Peak, True Peak, or LUFS-I
normalization are available. Name collisions can increment, skip, or overwrite
after explicit confirmation. Completed files can optionally be inserted into
REAPER.

Transfer temporarily creates a dry media item, renders it with REAPER's native
selected-media-item renderer, and restores the previous render settings,
selection, cursor, time selection, and project dirty state. The temporary item
is removed after every file, including failure paths.

Beta 1 does not pass audio through track FX, sends, folders, or Master FX. Stop
project playback before starting Transfer. Reverse Transfer requires SWS.

## 16. Collections and workflow

Create multiple playlists and project bins, add or remove files in bulk, and save search states including query text, library filter, collection, workflow status, and sort order.

Workflow status values are Unmarked, Candidate, Approved, and Rejected. Workflow status is separate from the independent `marked` flag added in 0.6.8.

## 17. Metadata and pinned Artwork

The inspector edits Description, Keywords, Category, SubCategory, CatID, Library and Artwork path without modifying source audio metadata.

For a single selected asset, the full cover can be pinned above the scrolling metadata area:

- cover, asset name and cover controls remain fixed;
- metadata and file information scroll independently below;
- the cover does not move while reviewing long metadata;
- users can choose a cover, rerun automatic detection or explicitly clear the cover;
- disabling pinning makes the cover scroll with metadata.

Artwork currently uses external PNG/JPEG files. Embedded artwork inside audio containers is not extracted in this version.


## 18. Appearance and performance

### Interface

The application maintains one compact, flat, responsive interface with adjustable columns, a fixed header, collapsible side panels, focus mode, and an adjustable preview workspace.

### Current performance strategy

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


## 19. Data files

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

## 20. Shortcuts

| Shortcut | Action |
|---|---|
| Space | Play or stop |
| Up / Down | Move selection |
| Enter | Insert |
| Ctrl+Enter | Insert on a new track |
| Ctrl+A | Select all current results |
| Ctrl+F | Focus search |
| Ctrl+R | Incremental scan |
| Ctrl+T | Open Transfer |
| F | Toggle favorite |
| M | Toggle mark |
| L | Toggle loop |
| F9 | Toggle navigation |
| F10 | Toggle metadata inspector |
| F11 | Toggle focus mode |

## 21. Maintenance and troubleshooting

The Maintenance tab can clear waveform caches, reset interface settings, rebuild the database while keeping roots, or perform a factory reset.

Common issues:

- Rows named `._filename.wav` show no waveform: these are macOS AppleDouble
  metadata sidecars, not audio files. Beta 2 filters them during scanning and
  removes them from the loaded index automatically without deleting disk files.
- Waveforms are slow on first display: allow the visible-row cache to finish or run high-resolution precache.
- Precise waveform seeking does not work: install or update SWS.
- Drag transfer fails: release the pointer over the REAPER arrange view.
- Some text is garbled: the source file metadata may use a legacy encoding.
- Large libraries feel slow: hide unused columns, use focus mode, and do not run multiple PsyReaSFX versions.

## 22. Development stage

Package 0.7.4 Beta 6 hotfixes the left-panel theme-color crash and its cascading ImGui child-stack shutdown error. PsyReaSFX 0.6.21 remains the stable fallback while Transfer is tested across different REAPER, ReaImGui, SWS, file-format, and project configurations.

