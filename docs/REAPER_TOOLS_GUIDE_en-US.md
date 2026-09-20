# Psysia REAPER Tools Guide

Practical ReaScripts for sound-design editing, track management, rendering, display, and project workflow.

[Chinese version](./REAPER_TOOLS_GUIDE_zh-CN.md)

## Installation

### ReaPack

Import the repository in `Extensions → ReaPack → Import repositories...`:

```text
https://raw.githubusercontent.com/Psysia/PsyReaSFX/main/index.xml
```

Then run `Extensions → ReaPack → Synchronize packages`.

### Manual installation

Utility scripts are stored under `Scripts/Psysia/`. Copy the required `.lua` file into REAPER's Scripts directory, then load it from `Actions → Show action list → New action → Load ReaScript...`.

## Tool Index

| Tool | Version | Primary use |
|---|---:|---|
| Create Folder Region and Render Matrix | 2.4 | Region creation and Region Render Matrix setup. |
| Sort Tracks by Earliest Item Position | 1.4 | Folder-aware track ordering. |
| Open Render Dialog with Auto Tail | 1.0 | Apply saved tail settings before rendering. |
| Smart Tail Render Panel | 1.1 | Configure render tail and ending-silence trimming. |
| Remove Gaps Between Selected Items | 1.0 | Close gaps between selected items. |
| Toggle LUFS-M and Spectrogram | 1.1 | Switch peak-display modes. |
| Video Item Filename Overlay | 1.5 | Draw adaptive extension-free video filenames inside Arrange View items. |
| Create Folder from Selected Tracks with Pro-L 2 | 1.1 | Build a parent bus around tracks or folders. |
| Split Selected Items to New Tracks | 1.0 | Move selected items onto separate tracks. |
| Reverse Selected Items in Place | 1.0 | Reverse selected items with one undo step. |
| Open All Subprojects | 1.0 | Recursively open referenced subprojects. |
| Cycle Selected Folders Unified Compact State | 1.4 | Adaptive folder display cycling. |
| Rename Selected Tracks from Parent Folder Name | 1.0 | Rename children from the immediate parent folder. |

## Rendering

### Create Folder Region and Render Matrix · 2.4

Creates or updates Regions from the current item or track selection, resolves the relevant folder hierarchy, derives a Region name, and writes the matching Region Render Matrix target.

It supports nested folders and multiple logical Regions that share the same time range. A Region is treated as the same logical output only when both its time range and render target match.

### Smart Tail Render Panel · 1.1

Provides a compact control surface for REAPER's native Render Tail and ending-silence trimming. Use it when reverbs, delays, or long decays would otherwise be cut by the render bounds.

The script changes render timing behavior only; it does not modify routing.

### Open Render Dialog with Auto Tail · 1.0

Applies the saved auto-tail settings to the current project, then opens REAPER's native Render dialog. It is intended as a replacement for a normal Render shortcut when the Smart Tail workflow is in use.

## Track Management

### Sort Tracks by Earliest Item Position · 1.4

Sorts at the nearest common hierarchy level instead of moving folder-parent tracks individually.

- Ordinary tracks move as single units.
- Folder parents move with their complete descendant subtrees.
- Selected media items take priority over incidental track selection.
- Unselected sibling units keep their original slots.

### Create Folder from Selected Tracks with Pro-L 2 · 1.1

Creates a new `Folder Bus` above a continuous group of sibling tracks or existing sibling folders, preserves complete folder subtrees, and inserts `Pro-L 2` on the new parent.

When existing folders are selected, selecting only their folder-parent tracks is sufficient. Cross-parent or discontinuous selections are rejected to avoid absorbing unrelated tracks.

### Cycle Selected Folders Unified Compact State · 1.4

Uses different behavior for flat and nested folder structures.

Flat folders:

```text
Fully Expanded ↔ Fully Collapsed
```

Nested folders:

```text
Deep Expanded
→ Child Folders Collapsed
→ Child Folders Compact
→ Fully Collapsed
→ Deep Expanded
```

The third state keeps the outer selected folders open and applies compact view only to nested child folders.

### Rename Selected Tracks from Parent Folder Name · 1.0

Renames selected tracks from their **immediate** parent folder, using top-to-bottom numbering:

```text
ParentName_01
ParentName_02
ParentName_03
```

Different parent folders are numbered independently. Tracks without a named immediate parent are skipped.

## Item Editing

### Remove Gaps Between Selected Items · 1.0

Moves selected items together so each item begins at the end of the previous selected item.

### Split Selected Items to New Tracks · 1.0

Moves selected items onto newly created tracks while preserving their timeline positions. New tracks are named from the active Take when a Take name is available.

### Reverse Selected Items in Place · 1.0

Runs REAPER's reverse-to-new-Take action and then crops to the active Take, producing an in-place reversed result that remains undoable as one operation.

## Project and Display

### Open All Subprojects · 1.0

Finds subprojects referenced by the current project, opens them in project tabs, and recursively discovers nested subprojects. Already-open projects are reused. Missing project files are reported.

SWS is optional; when available, it can improve exact subproject path resolution.

### Toggle LUFS-M and Spectrogram · 1.1

Switches between REAPER's LUFS-M spectral-peak display and the standard spectrogram view. The script resolves localized action names dynamically and caches validated command IDs.

### Video Item Filename Overlay · 1.5

Runs as a toggleable Arrange View overlay. To avoid playback-scroll flicker completely, v1.5 hides the filename overlay during Play and Record, then restores it immediately after Stop or Pause.

- File paths and extensions are always hidden.
- Font size adapts to the currently visible item width and height as the Arrange View is zoomed.
- The complete multi-line text block is centered horizontally and vertically below REAPER's normal item-title/icon strip.
- The complete filename is wrapped across multiple balanced lines instead of being truncated. v1.4 uses a more conservative width model so wrapping begins earlier, and can temporarily shrink below the configured preferred minimum down to 5 px when necessary.
- Supported video sources are detected from common video extensions and VIDEO-type media sources.

Use the companion **Video Item Filename Overlay Settings** action to set:

- font face;
- minimum font size;
- maximum font size;
- font weight.

The overlay requires **js_ReaScriptAPI**.

## Suggested Shortcuts

| Tool | Suggested access |
|---|---|
| Create Folder Region and Render Matrix | Frequent shortcut |
| Sort Tracks by Earliest Item Position | Frequent shortcut |
| Cycle Selected Folders Unified Compact State | Frequent shortcut |
| Rename Selected Tracks from Parent Folder Name | Shortcut |
| Split Selected Items to New Tracks | Shortcut |
| Remove Gaps Between Selected Items | Shortcut |
| Reverse Selected Items in Place | Shortcut |
| Open All Subprojects | Shortcut |
| Toggle LUFS-M and Spectrogram | Toolbar or shortcut |
| Video Item Filename Overlay | Toolbar toggle |
| Video Item Filename Overlay Settings | Occasional settings action |
| Smart Tail Render Panel | Toolbar |
| Open Render Dialog with Auto Tail | Replace the normal Render shortcut |
| Create Folder from Selected Tracks with Pro-L 2 | Toolbar or shortcut |

## Dependencies

Most utilities use only native REAPER ReaScript APIs.

- **SWS Extension:** optional for Open All Subprojects path resolution.
- **Pro-L 2:** required only by Create Folder from Selected Tracks with Pro-L 2.
- **js_ReaScriptAPI:** required by Video Item Filename Overlay.
- **ReaPack:** installation/update mechanism only; not a runtime dependency for the scripts themselves.

## Updating

Run `Extensions → ReaPack → Synchronize packages` to receive published updates.
