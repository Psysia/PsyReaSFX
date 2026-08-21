# PsyReaSFX Desktop 0.7.23 Alpha 8 Light RC1

PsyReaSFX Desktop is the standalone Windows migration of the PsyReaSFX
0.7.23 Stable product model. During desktop development, only the **Light**
edition is published. Portable and installer editions will be produced after
the Desktop Stable feature set is frozen.

Alpha 8 adds the optional **REAPER Bridge** without making REAPER a startup
dependency. Keep the bundled `PsyReaSFX_REAPER_Bridge.lua` running in REAPER,
then Desktop can send the full source or the current waveform selection to the
current track, create a new track, or spot the original source using its BWF
timestamp. Successful deliveries are recorded with project, track, position
and source identity in a dedicated project-usage history.

Bridge shortcuts are `Enter` for the current track, `Ctrl+Enter` for a new
track, and `Shift+Enter` for BWF Spot. The bridge icon in the main toolbar
shows connection state and provides connection testing and queue diagnostics.
If the Bridge script is not running, every standalone browse, audition,
organization and Transfer feature continues to work normally.

Alpha 7 Hotfix 2 replaces the platform Help message box with a branded,
modeless Help Center. Its navigation, cards, search syntax, waveform guidance
and shortcut reference follow the same Dark/Classic palette as the main shell,
remain usable while browsing, and switch with the selected interface language.

Alpha 7 Hotfix 1 completes two Lua-parity paths that were previously listed
too optimistically. Selecting CH 1…CH N now changes the actual stereo audition
feed to a dual-mono isolation of that source channel, and the detail waveform
immediately redraws only the same source lane. The selected mode is also kept
for the next preview instead of depending on an already-open player.

The waveform cache is now a real Desktop-owned setting under **Settings →
Maintenance**. Choose any directory, move validated existing RWF caches or
switch without moving them, restore the default path, and open or repair the
active directory. Newly generated inline and high-resolution waveforms are
written to that location; source audio is never moved.

Alpha 7 completes the standalone **catalog reliability** stage. Enabled source
folders are monitored recursively, noisy file-system changes are coalesced into
one incremental rebuild, interrupted scans can resume, and unreadable files are
kept as explicit retryable tasks instead of being silently ignored. The
maintenance center now owns verified SQLite backup/restore and waveform-cache
integrity repair without touching source media.

Alpha 6 completed the standalone **Transfer** workflow from Lua 0.7.23. It can
render the current waveform selection or complete files through a dedicated,
non-destructive export queue, while carrying the active Pitch, Rate, Gain,
Reverse and Preserve Pitch processing into the result. WAV and FLAC output,
sample-rate/channel conversion, metadata preservation, normalization, fades,
smart source tails, batch variants, collision policies, progress, cancellation
and task reports are connected and regression-tested.

Alpha 5 built on the standalone organization and audition core completed in
Alpha 4. It keeps
the high-resolution waveform and Lua UI-parity work from Alpha 3, then connects
playlists, project bins, saved searches, Facet filtering, metadata interchange
and a new independent low-latency preview engine to the desktop SQLite catalog.

Hotfix 1 resolves the blocking issues found in the first Alpha 5 package. The
real result DataGrid now uses a rectangular scrollbar thumb with a verified
minimum length of 42 px, rather than allowing a large catalog to collapse it
into a clipped dot. Selection drag-out accepts block-aligned formats including
24-bit stereo WAV, and its capsule follows the selected range when the waveform
is zoomed or resized. Rapid multi-selection no longer disposes cancellation
objects while background preview and loudness work are still unwinding. Theme
surface brushes are dynamic, so framework colors update immediately instead of
only after reopening a window.

RC1 rebuilt the performance and shell-layout path. RC2 removes the hidden-panel
column gutters and replaces font glyphs with the same quiet, hover-highlighted
vector icon language used by the Lua edition. RC3 separates playback progress
from waveform rendering, uses a display-synchronized playback clock and keeps
result columns at stable pixel widths so preview motion and F9/F10/F11 panel
switches no longer rebuild the waveform surface or the full results layout.
It also repairs the Alpha 4 organization and settings path: preview activity is
saved during the session, history navigation clears unrelated hidden filters,
collection counts update without rebinding the list, scrollbars use immediate
orientation-correct tracking, and all popup/list surfaces use the dark shell.
The preview DSP chain now verifies Preserve Pitch independently from Rate in an
offline self-test. Chinese and English can be switched from General settings.
RC4 fixes the remaining navigation-surface regressions found during real-world
testing: every collapsible section renders its full title, Facet selectors and
popup menus stay dark on Windows light themes, and both scrollbar thumbs use a
verified two-way value binding so they can be dragged rather than merely
displayed. Preview history is now an explicit root view with a visible active
state, selects its newest entry when opened, and shows a clear empty-state
message. Assets auditioned during the current launch turn warm yellow in the
result list; right-clicking Preview history can clear that temporary highlight
without deleting the persistent history.
RC5 completes the follow-up against the official Lua changelog: sidebar group
titles and their expanded states now follow the Lua navigation model; the
result scrollbar has a real two-way Track/Thumb connection and Shift+wheel
horizontal navigation; Pitch, Rate and Gain provide wider professional ranges,
wheel adjustment, double-click reset and inline numeric entry without invoking
global shortcuts. The last audition-highlight session can be restored or
cleared independently. Preview start, repeat and scrub rebuild the pitch/rate
pipeline behind short fades so buffered samples from the previous position are
not mixed into the new start point.
RC6 repairs runtime localization at its source: switching language no longer
mutates WPF inline collections while they are being enumerated, all navigation
group titles switch with the rest of the shell, and this path is now exercised
by the packaged self-test. It also restores the Lua appearance model with Dark
and Classic presets, a system color picker for the framework, accent, played
text and waveform-state colors, live preview, preset restoration, and the
Lua priority `selected > marked > played > normal`. Vertical and horizontal
scrollbar thumbs retain a visible full-length rail and are verified by a real
drag-gesture test. General settings now let Space either pause/resume or restart
from the waveform selection start.
Alpha 5 RC1 closes three visible parity gaps. The result scrollbars now use a
centered, fully contained pill thumb instead of a clipped edge fragment. A
dedicated command in the main toolbar clears current-session audition coloring
without erasing Preview history. Dragging a range on the detail waveform now
reveals a `Drag selection out` capsule; dragging that capsule creates an exact
temporary WAV and hands it to REAPER or any Windows file-drop target. Manual
waveform Regions can be named, recalled and deleted, and migrated loudness rows
are displayed for the selected source when their file-size signature is still
valid.
The final Alpha 5 build completes this migration stage: Regions are drawn
simultaneously over the detail waveform; configurable transient detection can
create, replace, undo and clear suggestion batches; the desktop now computes
and caches LUFS-I, maximum LUFS-M/S and peak statistics for new files; and an
optional target-LUFS audition mode applies bounded comparison gain without
modifying the source. Selection drag-out is prepared before the pointer drag
starts, so the Windows file-drop gesture remains synchronous and reliable.
Appearance preferences now cover the complete shell hierarchy, text, selected
rows and every waveform state instead of recoloring only the accent.
Alpha 4 RC1 also fixes result-column divider dragging: file drag-and-drop now
starts only from an actual asset row, so it no longer steals pointer movement
from the pinned header resize handles. Visible fields and resized pixel widths
continue to persist across launches. The performance work removes unbounded thumbnail
and Artwork caches, stops preloading off-screen DataGrid pages, reuses the
existing Lua `RWF2/RWF3` waveform cache when available, and keeps both side
panels full-height while the result list and preview share only the center
workspace.

## Alpha 6 Transfer

- Open Transfer from the main command bar or press `Ctrl+T`.
- Export the active waveform selection, or use complete-file scope. Batch
  export always processes each complete source safely.
- Use naming tokens: `{name}`, `{category}`, `{subcategory}`, `{library}`,
  `{index}`, `{date}`, `{region}`, `{pitch}`, `{rate}`, `{gain}`,
  `{direction}`, `{variant}` and `{variant_index}`.
- Choose WAV 16/24/32-bit PCM or FLAC, source/44.1/48/96/192 kHz, and
  source/mono/stereo channels. FLAC requires `ffmpeg` on `PATH` in Light.
- Apply Peak, True Peak, RMS-I or LUFS-I normalization, fade in/out, dither,
  optional noise shaping and a threshold/maximum/hold smart source-tail rule.
- Generate Cartesian Pitch/Rate/Gain/normal-reverse variants. Lua-compatible
  limits are retained: 16 values per parameter, 128 variants per asset and
  4,096 jobs per run. Safe suffixing can be disabled when the naming template
  already guarantees unique output names.
- Preserve common WAV metadata chunks (`bext`, iXML, axml, LIST, cue, smpl,
  ID3, cart and DISP) and recognized sidecar metadata when possible.
- Choose increment, skip or overwrite collision behavior. Every run produces a
  TSV report and can reveal the latest output/report or automatically open the
  output directory.

Transfer never changes source media. The standalone build processes source
files directly. Alpha 8 covers direct current-track/new-track/BWF delivery;
rendering through project tracks, sends, project FX or Master FX remains a
separate future bridge-rendering feature.

## Alpha 7 catalog reliability

- Watch every enabled physical source recursively, with a configurable
  debounce so large copy/extract operations produce one incremental scan.
- Persist an atomic scan checkpoint and resume an interrupted catalog rebuild
  after an unexpected close.
- Record individual directory and media failures without aborting the whole
  library; retry or clear them from **Settings → Maintenance**.
- Create verified SQLite backups manually or once per day, keep a configurable
  number of generations, and stage the latest backup for safe next-launch
  restore while retaining a pre-restore copy.
- Validate generated RWF waveform caches and remove only damaged entries so
  they rebuild lazily when next requested.
- Change the waveform-cache directory, optionally migrate validated caches,
  or restore the default location without moving source media.

All reliability tasks are included in the packaged regression self-test. They
never move, rewrite or delete source audio.

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
  double-click reset, selection looping and multichannel lane labels. A valid
  selection exposes an in-waveform drag capsule that exports only that range
  to a temporary WAV without changing the source file.
- CH 1…CH N audition is true source-channel isolation rather than a visual-only
  selector. The detail waveform shows the same isolated lane while the preview
  engine routes it to both output speakers.
- Waveform selections can be saved as named per-asset Regions, recalled from
  the preview strip and deleted. Region data is persisted in SQLite and remains
  compatible with migrated Lua Region rows.
- Pitch, Rate and Gain are applied to preview playback. Their values can be
  entered directly by double-clicking the number, reset by double-clicking the
  label or slider, and adjusted across `-24…+24 st`, `0.25…4.00x` and
  `-36…+18 dB`. Column visibility can be
  changed from the pinned header context menu. Column visibility and resized
  widths now persist across launches.
- The inspector can apply Unmarked, Candidate, Approved or Rejected to one or
  many selected assets. `M` toggles an independent mark flag, also available
  from a result-row context menu.
- Description, Keywords, Category, SubCategory and CatID can be edited without
  touching the source audio. In a multi-selection, only fields changed in the
  inspector are replaced; untouched mixed fields remain intact.
- Playlists and project bins support batch add/remove, rename, clear and delete.
  Saved searches restore the current query, library, collection, workflow and
  sort context. Category, format and channel Facets can be combined with field
  search without rescanning the catalog.
- Metadata edits have a bounded undo stack. UCS-style filename parsing and
  UTF-8 CSV import/export support batch catalog cleanup without modifying WAVs.
- The preview path no longer uses WPF `MediaPlayer`. NAudio provides lower
  latency start/seek, independent Pitch/Rate/Gain, Preserve Pitch, Reverse,
  source-channel audition and continuous right-button waveform scrub.
- Preview history and recently inserted views are updated in the active session
  and persisted incrementally; they no longer depend on a clean application
  shutdown. Opening either activity view resets unrelated library, collection,
  workflow and Facet filters so matching rows remain visible.
- Opening Preview history highlights the navigation entry, sorts newest first
  and selects the newest matching asset. Assets heard in the current launch use
  a warm-yellow filename/metadata treatment; the temporary color can be cleared
  independently from the stored audition history.
- Current-session audition coloring can be cleared from the top command bar,
  the Activity section or the preview More menu. This operation never deletes
  persistent Preview history.
- General settings provide immediate Simplified Chinese / English switching for
  the primary shell and settings center. User filenames, paths, library names
  and metadata are always preserved verbatim.
- Appearance settings provide Lua-aligned Dark and Classic presets plus a
  system color picker for the framework, panels, headers, dividers, primary
  and muted text, accent, selected rows, played text, normal/selected/
  played/marked waveforms, waveform selection, playhead and Regions. Played-waveform
  recoloring remains independently optional. Cancel restores the original
  palette; Save persists the previewed palette.
- Space can use standard pause/resume behavior or restart playback from the
  current selection start. This preference affects Space only; the transport
  button keeps conventional pause/resume behavior.
- Vertical and horizontal scrollbars use immediate tracking rather than
  deferred scrolling. RC6 verifies both orientations of the
  Thumb-to-ScrollBar two-way binding
  in the packaged self-test, including simulated Thumb drag gestures rather
  than value-only binding checks. List, combo, context-menu and submenu surfaces
  share the dark theme instead of falling back to white Windows templates.

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

Keep the release folder together so the Bridge script, checksum, feature matrix
and diagnostics guide remain available beside the small framework-dependent
executable.

## Enable the optional REAPER Bridge

1. In REAPER open **Actions → Show action list → ReaScript: Load**.
2. Load the bundled `PsyReaSFX_REAPER_Bridge.lua`.
3. Run it once and leave it active; its toolbar toggle remains lit.
4. Return to Desktop. The Bridge icon changes from offline to the accent color.
5. Use `Enter`, `Ctrl+Enter`, `Shift+Enter`, or the three delivery icons below
   the waveform.

The Bridge and Desktop exchange only short local request files under
`%LOCALAPPDATA%\PsyReaSFX\bridge`. No network service, administrator permission
or catalog rescan is required.

If startup fails, attach the newest file from:

```text
%LOCALAPPDATA%\PsyReaSFX\logs
```

## Current boundary

Alpha 8 adds optional direct REAPER delivery to the completed standalone
reliability stage. Browse, organization,
preview, waveform Regions, transient suggestions, loudness analysis, selection
drag-out, Transfer, Watch Folder recovery, catalog backup/restore and cache
repair, current/new-track delivery, BWF Spot and project-use association are
connected and covered by the packaged self-test. Processing through REAPER
track sends, project FX or Master FX remains a later extension.

If a capability is not listed as complete in the matrix, it is pending rather
than a hidden preference. The Light UI does not show placeholder controls for
pending capabilities.

See the [English feature matrix](FEATURE_PARITY_0_7_23.md) or the
[中文功能对照表](FEATURE_PARITY_0_7_23_zh-CN.md) for feature scope,
[ALPHA8_REAPER_BRIDGE_AUDIT.md](ALPHA8_REAPER_BRIDGE_AUDIT.md) for the current
Bridge audit,
and [UI_ACCEPTANCE_LUA_0_7_23.md](UI_ACCEPTANCE_LUA_0_7_23.md) for the visual
and interaction acceptance contract.

Copyright © 2026 Psysia. All rights reserved.
