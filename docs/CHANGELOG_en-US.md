# PsyReaSFX Changelog

## 0.6.17 Stable RC6

### Result navigation

- Replaced the permanent full-row system scrollbar with a hover overlay.
- The slim navigator appears while the result table is hovered, dragged, or
  Shift-scrolled; the pinned header remains synchronized.

### Multichannel waveform preview

- Added the `RWF3` cache format with separate peak lanes for up to eight source
  channels.
- Mono uses `M`, stereo uses `L / R`, and multichannel files use `CH 1–8`.
- Existing `RWF2` list thumbnails stay valid; only channel-aware high-resolution
  previews are generated on demand.
- High-resolution precaching now produces channel-aware waveform data.

### Preview toolbar

- Consolidated preview actions and parameters into a lightweight Studio Strip.
- Reduced vector-icon, border, spacing, and parameter-card dimensions.
- Narrow windows use a two-row layout instead of overlapping controls.

## 0.6.16 Stable RC5

### Blocking fix

- Fixed the ReaImGui `EndChild` assertion introduced by RC4's horizontally
  synchronized fixed header.
- The header interaction layer now submits a zero-size layout item after its
  temporary `SetCursorScreenPos` calls, satisfying ReaImGui's parent-boundary
  contract.
- The fix preserves the pinned header, horizontal scrolling, and draggable
  column dividers.

## 0.6.15 Stable RC4

### English localization

- Completed the English audit for Settings, Maintenance, Appearance, Waveforms,
  help, status messages, and the bottom preview summary.
- Added English rules for dynamic scan, import, precache, transient, collection,
  and cache-migration messages.
- User-authored filenames, library names, metadata, and collection names remain
  untouched.

### Results table

- Added a horizontal scrollbar when visible fields exceed the workspace width.
- Kept the pinned header synchronized with horizontally scrolled rows.
- Preserved configured column widths instead of forcing every field into the
  current window.

### Project page

- Added compact-workspace and Focus-mode screenshots to the README.
- Preserved the GitHub project URL in script metadata and About.

## 0.6.14 Stable RC3

### Previous-session highlights

- Added `last_played_session_v1.tsv` for the previous yellow-highlight snapshot.
- Added manual restore, optional startup restore, current-view clear, and saved-snapshot clear.
- Clearing the current view does not immediately destroy the recoverable snapshot.
- Autosave and normal shutdown persist changed highlight sets.
- Full preview history remains separate in `history_v1.tsv`.

### Color-picker fix

- Fixed color swatches not responding to clicks.
- Removed the full-row `InvisibleButton` that consumed the click.
- The row now uses a non-interactive `Dummy` for layout.
- Clicks reach the `ColorEdit3` swatch directly.
- Live application, swatch preview, read-only hex value, and per-field reset remain available.

### Stable candidate

- No new major subsystem is added in this build.
- This is the 0.6 Stable RC1 package.
- After REAPER/ReaImGui/SWS verification, it can be promoted to final 0.6 Stable.

## 0.6.11

### Settings Center

- Fixed left-navigation titles showing only one character or clipped descriptions.
- Replaced the old selectable rows with custom two-line navigation cards.
- Increased navigation width and added an About page.

### Color pickers

- Replaced editable color-code fields with ReaImGui `ColorEdit3` picker controls.
- Clicking a swatch opens the full picker and applies changes immediately.
- Added a live swatch and read-only `#RRGGBB` reference.
- Accent and waveform-state colors now share one reusable component.
- Removed redundant apply-color actions while retaining per-color and full-palette reset actions.

### About

- Added product identity, version, author, and 0.6 stabilization status.
- Added REAPER, OS, ReaImGui, SWS, and preview-backend information.
- Added open-data-folder, open-documentation-folder, and copy-diagnostics actions.
- Reserved release fields for license, website, and support contact.

### Code and performance

- Centralized color conversion, picker rendering, and live-apply logic.
- Removed layered text drawing from settings navigation.
- Color pickers only run while Settings is open and add no background browsing tasks.

## 0.6.10

### Forge-style played state

- Played text is now a current-launch session state with a configurable warm-yellow default.
- Filename, Keywords/Description, Duration, Library and other text columns share the played color.
- Reopening the script resets visual played colors without deleting persistent preview history.
- Added a main-toolbar action to clear current-session played highlighting.
- The same reset command is available from View and Settings.
- Played waveform coloring is now an independent option and is disabled by default.

### Compact result list

- Added a complete Forge Compact preset.
- Compact rows now use one vertically centered line, fixing clipped secondary text.
- The preset enables Waveform, Filename, Keywords/Description, Artwork and Duration.
- It can be applied from a preset card or the header context menu.

### Artwork

- Added an optional Artwork column with list thumbnails.
- Added automatic PNG/JPEG folder-art discovery.
- Parent-folder search stops at the library root and uses a maximum depth.
- The metadata inspector now shows full Artwork with choose, redetect and clear actions.
- Added pinned cover mode so Artwork stays fixed while metadata scrolls.
- Artwork paths are stored in the PsyReaSFX database and do not modify audio files.

### Settings Center

- Rebuilt Settings as a modern two-column interface.
- Added Forge Compact, Aether Standard and Review preset cards.
- Reorganized Appearance, Artwork, state-color, waveform and maintenance options.
- Settings now follows the main application's visual language.

### Code and performance

- Changed the script author field to `Psysia`.
- Added positive and negative folder caches for Artwork discovery.
- Artwork uses a low-priority single-job queue that yields during input, scans and imports.
- Image objects use a bounded memory cache and are detached during cleanup.
- Images are requested only for visible Artwork rows and the selected asset.
- State-color lookups use normalized path hash tables.
- The project remains in the 0.6.x stabilization stage.


## 0.6.9

### Fixes

- Fixed missing hover help for icons in the bottom preview console.
- Icon help now uses ReaImGui's foreground draw layer so it renders above all child panels.
- Top and bottom icons continue to share the same delayed, non-popup hover-help system.

### Appearance redesign

- Removed the visually subtle Clean Cards/Compact switch.
- Added Comfortable, Balanced and Compact global density profiles.
- Density now changes row height, header height, icons, parameter cards, spacing and rounding.
- Added Flat, Layered and High Contrast surface styles.
- Added Full, Focused and Minimal preview-console modes.
- Low-frequency preview toggles move to More Actions in Focused and Minimal modes without losing functionality.
- Added migration for legacy `ui_style` and console-layout settings.

### Performance

- Appearance profiles only change layout, dimensions and colors.
- No additional waveform, loudness, scan or database jobs are introduced.

## 0.6.8

### Completed 0.6 waveform-state plan

- Added separate list-waveform colors for Normal, Selected, Played, and Marked states.
- Added configurable color fields for all four states.
- Defined stable priority: Selected > Marked > Played > Normal.
- Added a small visual dot to marked waveform cells.

### Mark system

- Added an independent `marked` asset flag.
- Added the `M` shortcut.
- Added single-item and bulk mark/unmark context actions.
- Added `marked:true`, `marked:false`, `played:true`, and `played:false` search filters.
- Added the `marked` field to `index_v3.tsv` with backward-compatible loading.

### Code organization and performance

- Centralized waveform-state resolution and removed duplicated row color branching.
- Reused one normalized path key per row render.
- Converted waveform color settings to a data-driven field definition.
- Added one-click waveform palette reset.
- Added no new waveform analysis, disk scan, or loudness jobs.

### Documentation

- Converted README into a release landing page.
- Split the user manual and changelog into separate documents.
- Added independently maintained Simplified Chinese and English versions.

## 0.6.7

- Replaced ordinary ImGui Tooltip windows with a main-window DrawList overlay.
- Fixed occasional large blank flashes while moving between icons.
- Moved the 0.6 branch into stabilization.

## 0.6.6

- Unified asset information and loudness into one preview header.
- Removed duplicate borders and separators between results and preview.
- Added delayed and constrained tooltip sizing.

## 0.6.5

- Added detailed transient detection settings, undo, and suggestion clearing.
- Added LUFS-I, LUFS-M, LUFS-S, and True Peak display.
- Added direct selection-drag transfer from the large waveform.

## 0.6.4

- Rebuilt the bottom control deck.
- Replaced mixed knobs and native sliders with consistent parameter cards.
- Reorganized frequent and secondary actions.
- Added responsive control layouts.

## 0.6.3

- Added a resizable bottom panel.
- Added multiple regions, transient suggestions, channel audition, and estimated loudness matching.
- Added independent waveform, selection, playhead, and region colors.

## 0.6.2

- Fixed clipped bottom controls.
- Fixed vertically stacked Chinese tooltip text.

## 0.6.1

- Fixed nested scroll containers producing multiple central scrollbars.
- Added vector icons, waveform zoom, pan, scrub, and preview presets.

## 0.6.0

- Added Chinese/English interface switching.
- Increased list waveform resolution to 256/512 points.
- Added 2048/4096-point library precaching.
- Added Clean Cards and Compact interface styles.

## 0.5.2

- Fixed theme style-stack errors.
- Preserved the current library view after creating collections.
- Added responsive window layout and higher-resolution large waveforms.

## 0.5.1

- Fixed the Lua main-chunk 200-local-variable compilation limit.

## 0.5.0

- Added collapsible side panels and focus mode.
- Added playlists, project bins, saved searches, workflow status, and preview history.

## 0.4.0

- Added a pinned header, configurable fields, resizable columns, and metadata inspector.
- Added non-destructive metadata editing and a Aether-inspired three-panel layout.

## 0.3.2

- Fixed text drawing across column boundaries and fixed the Help popup.

## 0.3.1

- Fixed unsafe UTF-8 truncation.
- Added resizable columns and a mini list playhead.

## 0.3.0

- Added staged library import, peak building, multi-selection, and drag transfer into REAPER.
- Added large-waveform selection preview.

## 0.2.1

- Renamed the project to PsyReaSFX.
- Fixed the invalid sort comparator.

## 0.2.0

- Added a Forge-style dark result table.
- Added click-to-seek list waveforms and persistent waveform caching.

## 0.1.0

- First runnable prototype with multi-library scanning, search, favorites, preview parameters, and basic insertion.
