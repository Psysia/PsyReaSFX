# PsyReaSFX Desktop 0.7.23 Alpha 4 Light RC1

PsyReaSFX Desktop is the standalone Windows migration of the PsyReaSFX
0.7.23 Stable product model. During desktop development, only the **Light**
edition is published. Portable and installer editions will be produced after
the Desktop Stable feature set is frozen.

Alpha 4 begins the organization and metadata workflow phase. It keeps the
high-resolution audition and Lua UI-parity work from Alpha 3, while adding
editable workflow states, an independent mark flag and non-destructive single
or batch metadata editing backed by the desktop SQLite catalog.

RC1 rebuilt the performance and shell-layout path. RC2 removes the hidden-panel
column gutters and replaces font glyphs with the same quiet, hover-highlighted
vector icon language used by the Lua edition. RC3 separates playback progress
from waveform rendering, uses a display-synchronized playback clock and keeps
result columns at stable pixel widths so preview motion and F9/F10/F11 panel
switches no longer rebuild the waveform surface or the full results layout.
Alpha 4 RC1 also fixes result-column divider dragging: file drag-and-drop now
starts only from an actual asset row, so it no longer steals pointer movement
from the pinned header resize handles. Visible fields and resized pixel widths
continue to persist across launches. The performance work removes unbounded thumbnail
and Artwork caches, stops preloading off-screen DataGrid pages, reuses the
existing Lua `RWF2/RWF3` waveform cache when available, and keeps both side
panels full-height while the result list and preview share only the center
workspace.

## What is working

- The desktop version follows the Lua release baseline: `0.7.23`.
- A SQLite catalog with WAL mode, indexed fields and full-text search storage.
- Read-only discovery and one-time migration of the existing Lua data folder.
- Migration of logical libraries, source folders, all 27 asset fields,
  collections, saved searches, preview history, last-session highlights,
  Regions, loudness results and settings.
- Existing desktop browsing, waveform, responsive basic preview, Artwork, favorites and
  drag-to-REAPER behavior read and write the new catalog.
- List and detail Artwork load away from the UI thread. Smart discovery checks
  the source root, Artwork/Cover children and sibling folders such as
  `2. Artwork`; a source can also be assigned manually from its context menu.
- Settings opens a real in-app settings center for auto-preview, startup
  panels, waveform resolution, data/log folders and product information.
- The window is displayed before the database is opened or migrated, so a slow
  disk or first migration no longer looks like an application that failed to
  launch.
- Startup and unexpected errors are recorded in a user-readable log.
- The currently auditioned list row has a cyan mini playhead. Only that asset
  receives progress notifications.
- Fast wheel scrolling defers waveform reads until a recycled row has remained
  stable; older RC2 default settings migrate from 512 to 256-point inline
  thumbnails while 512 remains an explicit user option.
- Result thumbnails use one aggregate lane like Lua Stable. Source files are
  sparsely sampled when no disk cache exists instead of allocating and reading
  up to 32 MB for every visible row.
- The detail waveform supports drag selection, wheel zoom, Shift+wheel pan,
  double-click reset, selection looping and multichannel lane labels.
- Rate and Gain are applied to preview playback. Column visibility can be
  changed from the pinned header context menu. Column visibility and resized
  widths now persist across launches.
- The inspector can apply Unmarked, Candidate, Approved or Rejected to one or
  many selected assets. `M` toggles an independent mark flag, also available
  from a result-row context menu.
- Description, Keywords, Category, SubCategory and CatID can be edited without
  touching the source audio. In a multi-selection, only fields changed in the
  inspector are replaced; untouched mixed fields remain intact.

The Lua files are never modified by migration. The desktop database is stored
at `%LOCALAPPDATA%\PsyReaSFX\catalog-v1.sqlite3`.

## Automatic Lua data discovery

The first launch checks these locations in order:

1. `PSYREASFX_REAPER_DATA` environment variable.
2. `%APPDATA%\REAPER\Scripts\PsyReaSFX`.
3. `%USERPROFILE%\Music\Reaper\Scripts\PsyReaSFX`.

The imported source path and migration state are recorded so a completed
migration is not repeated on every launch.

## Run the Light edition

1. Install the [.NET 8 Desktop Runtime (Windows x64)](https://dotnet.microsoft.com/en-us/download/dotnet/8.0/runtime).
2. Extract the **entire ZIP** to a normal folder.
3. Run `PsyReaSFX.Desktop.exe` from the extracted folder.

Do not move only the EXE out of the folder: the Light edition deliberately
keeps its required DLL files beside the executable to remain small and start
without self-extraction.

If startup fails, attach the newest file from:

```text
%LOCALAPPDATA%\PsyReaSFX\logs
```

## Current boundary

Alpha 4 is an active desktop migration build. Pitch/preserve-pitch, reverse,
advanced channel routing, saved Regions, collection and saved-search UI,
Transfer processing and the REAPER Bridge remain
tracked in the feature matrix and will be migrated in subsequent `0.7.23
Desktop Alpha` builds.

If a capability is not listed as complete in the matrix, it is pending rather
than a hidden preference. The Light UI does not show placeholder controls for
pending capabilities.

See [FEATURE_PARITY_0_7_23.md](FEATURE_PARITY_0_7_23.md) for feature scope and
[UI_ACCEPTANCE_LUA_0_7_23.md](UI_ACCEPTANCE_LUA_0_7_23.md) for the visual and
interaction acceptance contract.

Copyright © 2026 Psysia. All rights reserved.
