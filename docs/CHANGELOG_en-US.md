# PsyReaSFX Changelog

## 0.7.21 Beta 25

### Visible Transfer selection state

- Replaces Transfer's generic choice buttons with dedicated segmented
  controls.
- Fixes an ordering bug where the generic dark-button colors were pushed after
  the selected color and therefore hid the active state.
- Shows the active scope, format, sample rate, channel mode, normalization
  method and collision policy with an accent fill, distinct border and
  high-contrast text.
- Keeps neutral and hover states consistent with the selected theme.

## 0.7.20 Beta 24

### Transfer folder actions

- Gives Transfer settings, Latest output and report-folder buttons unique
  Dear ImGui IDs, removing the conflicting-visible-item warning.
- Replaces the single `ExecProcess` folder action with a validated,
  Unicode-safe opener that prefers SWS and falls back to a non-blocking
  operating-system command.
- Reports a missing or unopenable directory instead of silently doing nothing.

### Completion behavior

- Adds **Open output directory after export** beside the existing optional
  REAPER insertion behavior.
- Persists the option in `config.tsv`.
- Opens the directory only after a normal job completion with at least one
  successful output; canceled or fully failed jobs do not open it.

## 0.7.19 Beta 23

### Completed 0.7 Transfer feature set

- Adds explicit WAV 16-bit, 24-bit and 32-bit PCM output alongside FLAC.
- Adds integrated RMS normalization next to Peak, True Peak and LUFS-I.
- Adds optional supported-source metadata preservation and WAV 16-bit dither
  with optional noise shaping.
- Uses explicit REAPER sink configurations for each WAV bit depth.

### Batch Variants

- Adds custom comma-, space- or semicolon-separated Pitch, Rate and Gain lists.
- Builds bounded Cartesian combinations with optional normal and reverse
  directions.
- Adds `{pitch}`, `{rate}`, `{gain}`, `{direction}`, `{variant}` and
  `{variant_index}` naming tokens.
- Adds automatic safe variant suffixes when the template contains no variant
  field.
- Limits each parameter to 16 values, each asset to 128 variants and each job
  to 4,096 tasks.
- Adds Current values, Pitch ±3/±6 and Subtle variations presets.

### Job reliability and performance

- Replaces the synchronous all-files loop with one render task per defer cycle.
- Adds task progress and Stop after current file behavior.
- Writes a per-task TSV report with source, variant, output, result and timing.
- Prompts for overwrite mode once per job only when an existing or duplicate
  target is detected.
- Renders to a unique temporary path before touching a destination.
- Uses backup, commit and restore steps for overwrite mode, preventing the old
  file from being deleted before a successful render exists.
- Keeps Transfer task state out of the waveform, metadata and Artwork queues.

## 0.7.18 Beta 22

### Square-first Artwork selection

- Prefers square and near-square cover candidates before landscape or portrait
  images when several files are available.
- Uses recognized cover names, resolution and stable filename order as
  secondary selection rules.
- Reads PNG, JPEG, BMP and TGA dimensions from bounded file headers instead of
  decoding every candidate image.
- Limits each folder scan to 128 image candidates and caches dimension results,
  keeping discovery predictable for large libraries.
- Advances the Artwork discovery generation so earlier negative results are
  retried automatically.

### Collapsible navigation groups

- Makes Sounds, Libraries, Collections, Saved searches, Workflow and Activity
  independently collapsible.
- Persists each group's state in the interface configuration.
- Keeps the existing borderless, theme-aware navigation style.

### Cleaner missing-Artwork state

- Leaves the Artwork result cell empty when no cover is available.
- Retains the larger neutral empty state in the metadata inspector, where its
  context and cover actions are still useful.

## 0.7.17 Beta 21

### Product-aware Artwork discovery

- Detects covers stored beside source audio, inside direct cover folders, or
  in numbered sibling layouts such as `1. Audio / 2. Artwork`.
- Normalizes ordering prefixes and recognizes Artwork, Cover, Images,
  Graphics, Thumbnail, Album Art and equivalent Chinese folder roles.
- Searches nested cover folders with strict depth and directory-count budgets,
  preserving UI responsiveness on large commercial libraries.
- Invalidates negative Artwork results created by the older discovery model,
  so existing libraries retry automatically after the update.
- Keeps every discovered or manually assigned cover owned by its physical
  source folder; sibling sources in one logical library remain isolated.

### Smart source tail for Transfer

- Adds an optional smart-tail pass for waveform-selection exports.
- Scans the source audio after the selection for the last event above a
  configurable dBFS threshold, maximum extension and hold time.
- Reuses disk waveform caches when available and loads only a bounded envelope
  otherwise; no eager full-library analysis is introduced.
- Makes the source-only boundary explicit: project FX, sends, folder routing
  and Master FX are still outside the Transfer render path.

## 0.7.16 Beta 20

### Space-bar anti-click fix

- Explicitly captures keyboard input while the PsyReaSFX main window or one
  of its child panels has focus, preventing the same Space press from also
  reaching REAPER's global transport action.
- Keeps stopped Preview media sources alive for 100 ms so the SWS audio
  thread can finish its 25 ms release before the underlying Section and file
  sources are destroyed.
- Cleans retired Preview sources incrementally without adding a blocking wait
  to the interface.

### Privacy-safe project media

- Replaces the workspace and Focus-mode screenshots with current Beta 20
  captures.
- Replaces both Transfer screenshots with versions whose local output paths
  are concealed.
- Promotes the logical-library and waveform-to-REAPER demonstrations from the
  user guide to the main project page.

## 0.7.15 Beta 19

### Source-boundary anti-click path

- Wraps every SWS audio Preview in a Section Source with a 20 ms
  source-boundary fade, including playback started from the beginning with
  `Space`.
- Removes the UI-frame volume ramp introduced in Beta 18. Preview stops now
  use SWS's sample-accurate audio-thread fade with a 25 ms release.
- Keeps the Preview object's 20 ms safety fade-in as a second layer for older
  media and non-zero seek starts.

### Responsive Preview controls

- Keeps all six Preview-state icons available when the navigation and metadata
  panels are open.
- Computes action, parameter and toggle widths from one shared layout model.
  Controls stay beside Gain when they fit and wrap into a reserved row when
  they do not.
- Uses the same computed height for waveform reservation and control drawing,
  preventing responsive controls from being clipped.
- Removes manual vertical cursor relocation from the control deck, reducing
  ReaImGui Child-boundary risk.

## 0.7.14 Beta 18

### Preview anti-click handling

- Stops Space-bar and transport-button preview through a short 50 ms volume
  ramp before destroying the SWS Preview object.
- Extends Preview fade-in to 12 ms and fade-out to 18 ms.
- Writes a non-zero seek position before starting playback, avoiding the
  first-buffer jump from the beginning of the file.
- Clears pending fade state on every preview cleanup path.

### Channel-rail state

- Gives All Channels explicit selected, idle and subtle hover colors instead
  of inheriting the global button state.
- The All Channels fill now represents the real lane selection count.

## 0.7.13 Beta 17

### Inline rail hotfix

- Fixes a repeatable ReaImGui assertion when collapsing the inline channel
  rail in the same frame that changed the control-strip height.
- Skips the old cursor relocation immediately after collapse and submits a
  defensive layout item after explicit positioning.
- Renames right-click lane behavior from audition/solo to waveform focus,
  matching the actual SWS capability.
- Shows a status message that multichannel audio continues to follow REAPER's
  device routing.

## 0.7.12 Beta 16

### Inline multichannel rail

- Replaces the channel Popup with an inline channel rail inside the main
  preview strip, keeping application shortcuts and audition active.
- Left-clicking the multichannel icon expands or collapses the rail;
  right-clicking the icon restores all channels.
- Supports click, Ctrl-click, Shift-click and hover-scoped Ctrl+A selection.
- Right-clicking an individual lane focuses it immediately.
- Keeps selected waveform lanes bright and unselected lanes dimmed in real
  time, without creating hidden project tracks.
- Compresses channel buttons responsively for narrower main windows.

### Unified product identity

- Reuses the same vector symbol and Orbitron two-color wordmark in the About
  page and the main toolbar.
- Keeps the About card aligned with the active interface accent and shell.

## 0.7.11 Beta 15

### Numeric-editor shortcut isolation

- Prevents the Enter key used to confirm Pitch, Rate or Gain from reaching the
  global Insert-on-current-track shortcut in the same frame.
- Isolates the complete numeric-editor lifetime, including its activation and
  closing frame, from application-level keyboard commands.
- Preserves in-place input, Escape cancel, focus-loss confirmation, drag,
  wheel adjustment and label/track reset.

### Channel-aware audition control

- Replaces the static three-bar control with state-aware stereo, left, right,
  mono and multichannel glyphs.
- Left-click cycles the common modes for mono/stereo sources; right-click opens
  the complete channel menu.
- Uses mirrored mono hardware-output previews so Left, Right and Mono are heard
  in the center rather than from only one speaker.
- Opens a compact selector for 3–8 channel files with click, Ctrl-click,
  Shift-click and Ctrl+A selection behavior.
- Keeps selected waveform lanes at full intensity and dims unselected lanes
  immediately.
- Documents the SWS limitation for arbitrary multichannel source isolation;
  multichannel lane focus never creates hidden tracks or mutates the project.

## 0.7.10 Beta 14

### Numeric-editor hotfix

- Removes the unsupported `EnterReturnsTrue` flag from ReaImGui
  `InputDouble`, which caused an assertion immediately after double-clicking a
  Pitch, Rate, or Gain value.
- Uses active-item, Enter, Escape, and deactivation states to confirm or cancel
  exact numeric editing without changing the control-strip layout.
- Keeps label/track double-click reset and drag/wheel adjustment behavior.

### Transfer settings layout

- Changes the output-directory and naming-template controls to hidden internal
  labels so no duplicate label is drawn beyond the right edge.
- Prevents those labels from being clipped beneath the vertical scrollbar.

### User-guide media

- Adds the supplied logical-library workflow animation.
- Adds the waveform-selection-to-REAPER drag animation.
- Adds localized English and Chinese Transfer settings screenshots.

## 0.7.10 Beta 13

### Precision parameter editing

- Double-clicking the displayed Pitch, Rate, or Gain value opens an in-place
  numeric editor without resizing or reflowing the control strip.
- Uses an accent highlight while editing; Enter or focus loss accepts, and
  Escape restores the pre-edit value.
- Double-clicking a parameter label or track restores its default value.
- Resolves the old reset path being immediately overwritten by drag state.

### Toolbar ergonomics

- Returns the metadata-inspector toggle to the left workspace-control group
  beside Navigation and Focus.
- Uses one 32-pixel control height for toolbar icons and the search field.
- Calculates search-field vertical padding from the active font for a shared
  visual baseline.

### Concise in-product guidance

- Removes implementation details and historical commentary from Settings.
- Keeps only actionable choices, safety warnings, and essential gestures in
  the application.
- Leaves architecture, caching behavior, and detailed workflows in the user
  guide.
- Removes a non-shortcut Saved Search explanation from the quick Help window.

## 0.7.9 Beta 12

### Compact brand system

- Replaces the compressed square toolbar image with a theme-aware vector mark
  built from the stacked-diamond and waveform brand elements.
- Bundles the Orbitron variable font for the PsyReaSFX wordmark, with a safe
  fallback when the font cannot be loaded.
- Keeps the compact mark crisp at high DPI without loading another raster size.

### Borderless toolbar and panel placement

- Removes permanent frames from toolbar icon buttons.
- Reveals a subtle hit area and accent-colored glyph on hover, press, or active
  state while retaining the same click targets and delayed help labels.
- Places the navigation toggle at the far left and the metadata-inspector
  toggle at the far right, matching their controlled panels.

### Product documentation

- Rewrites the English and Chinese README files as product landing pages.
- Adds a same-page collapsible Chinese overview to the default English README.
- Rewrites both user guides around real tasks instead of release history.
- Separates product explanation, operating procedures, troubleshooting, and
  version changes into the appropriate documents.
- Includes the Orbitron SIL Open Font License in the release and ReaPack files.

## 0.7.8 Beta 11

### Unified branded toolbar

- Removes the internal menu strip to eliminate the color seam beneath the
  native window title bar.
- Replaces the plain top-left name with the packaged application icon and a
  theme-aware two-tone PsyReaSFX wordmark.
- Collapses the brand to the icon in narrow windows to protect search width.
- Adds a permanent Help icon beside Settings.
- Moves Watch Folder to General settings while keeping library, scan, cache,
  highlight, and panel controls in their existing permanent locations.
- Removes the unused menu-rendering path and menu-bar window flag.

## 0.7.7 Beta 10

### Help Child-stack hotfix

- Removes nested Child windows from the Help section renderer.
- Keeps one visible scrollable Child for the complete Help body.
- Prevents off-screen Help groups from prematurely popping the outer Child.
- Fixes the ReaImGui `EndChild` assertion reported when opening Help.

## 0.7.7 Beta 9

### Heritage selection contrast

- Keeps Electric Cyan as the Heritage accent while darkening the selected-row
  fill to a deeper teal.
- Uses high-contrast white selected text throughout the interface.
- Gives selection visual priority over played-state yellow text.
- Prevents selected-text styling from becoming unreadable in dark information
  panels.

### Localized Help and README previews

- Rebuilds Help as a fixed-size, scrollable quick-reference center.
- Groups shortcuts under Workspace, Results, Preview, Organize, and Transfer.
- Maintains Chinese and English Help descriptions independently to prevent
  mixed-language content.
- Replaces the README workspace and Focus-mode images with current captures.

## 0.7.6 Beta 8

### Appearance modes

- Restores the former neutral-black interface as the default **Dark mode**.
- Adds **Heritage mode**, using a deeper navy shell and Electric Cyan accent.
- Treats each mode as a complete preset covering surfaces, accents,
  waveforms, selection, and playhead colors.
- Migrates previous Aether/flat settings to Dark mode.

### Custom frame color

- Adds a color picker for the application frame base color.
- Automatically derives panel, header, hover, border, dim-text, row, button,
  and waveform-background hierarchy from the selected base color.
- Keeps the accent color independently editable.
- Makes the About card follow the active appearance instead of forcing the
  branded navy palette.

## 0.7.5 Beta 7

### Official visual identity

- Adds the official PsyReaSFX README hero and packaged application icon.
- Applies the Deep Navy, Dark Slate, Electric Cyan, Soft White, and Cool Gray
  brand palette to the default interface.
- Rebuilds About as a minimal product card with the icon, product line,
  version, copyright, and GitHub link.
- Includes the icon as a ReaPack-managed asset instead of relying on an
  external path.

### Source-owned Artwork

- Moves shared Artwork ownership from the logical library to each physical
  source folder.
- Prevents a cover found in one source from appearing on sibling sources in
  the same logical library.
- Adds source-folder context commands to choose, rediscover, or clear Artwork.
- Preserves asset-specific Artwork as the highest-priority override.
- Migrates an old shared cover only when the logical library has exactly one
  source; ambiguous multi-source associations are intentionally discarded.

## 0.7.4 Beta 6

### Left-panel crash hotfix

- Defines the theme accent color consumed by the new library disclosure button.
- Defines the muted color already used by Library Manager and folder-drop UI.
- Prevents `PushStyleColor` from receiving `nil` when the left panel opens.
- Removes the cascading `Missing EndChild()` shutdown error caused by that
  interrupted sidebar render.
- Adds a static audit covering every `COLOR.*` reference used by the script.

## 0.7.4 Beta 5

### Logical-library disclosure control

- Replaces the decorative library arrow with a dedicated clickable control.
- A single click expands or collapses physical source folders without changing
  the active library filter.
- Persists the expanded state in `libraries_v2.tsv`; older files remain
  compatible and default to expanded.

### Shared library Artwork

- Adds one persisted shared Artwork path per logical library.
- Uses shared Artwork in both result-list thumbnails and the metadata inspector.
- Always checks source roots after the per-file parent search, including deeply
  nested assets, and searches common Artwork/Images/Documentation subfolders.
- Adds manual library-cover selection and automatic rediscovery commands.
- Adds BMP/TGA discovery and a retry backoff for failed image decoding.

## 0.7.3 Beta 4

### Empty-first logical libraries

- `New library` now creates a named logical library without requiring a
  source folder.
- Empty libraries remain visible and can receive source folders later through
  the library context menu, library manager, or folder drag-and-drop.
- Creating a library no longer starts a scan until at least one source folder
  is attached.

### Duration display

- Duration cells now use the fixed `MM:SS.mmm` timecode format, for example
  `00:04.947`.
- The default Duration column width was adjusted for the fixed-width value.

### Large-library performance

- Replaces front-removal from the directory queue with an indexed scan cursor.
- Carries the known source root through recursive scanning, avoiding a full
  configured-root lookup for every new asset.
- Defers result-list and library-count rebuilds until scan/import boundaries.
- Rebuilds logical-library indexes once per multi-folder drop instead of once
  per source folder.

## 0.7.2 Beta 3

### Multi-root logical libraries

- Separates logical library identity from physical source-folder paths.
- Lets one logical library aggregate multiple folders across drives.
- Migrates legacy roots automatically without rebuilding waveform caches.
- Adds expandable source folders, aggregate library filtering, hover summaries,
  per-source scanning, renaming, and safe removal.
- Adds Explorer/Finder folder drops on libraries, All libraries, and the central
  results area, including a multi-folder organization choice.
- Blocks duplicate and overlapping roots, preserves offline sources, and
  confirms cross-library ownership moves without moving disk files.
- Stores stable library and root IDs in `libraries_v2.tsv` and saved searches.
- Caches per-library counts so the sidebar does not scan the full asset list for
  every visible library on every frame.

### Cross-platform metadata filtering

- Excludes macOS AppleDouble files whose names begin with `._`, even when the
  sidecar keeps a supported audio extension such as `.wav`.
- Skips common metadata directories including `__MACOSX`, `.AppleDouble`,
  `.Spotlight-V100`, `.Trashes`, and `@eaDir`.
- Automatically ignores false entries already stored in `index_v3.tsv` and
  rewrites the clean index during normal autosave.
- Reports the number of ignored system files without deleting any source or
  sidecar files from disk.

## 0.7.0 Beta 1

### Transfer workflow

- Added a dedicated Transfer panel and `Ctrl+T` shortcut for exporting the
  current asset, its waveform selection, or multiple selected assets.
- Added naming templates with `{name}`, `{category}`, `{subcategory}`,
  `{library}`, `{index}`, `{date}`, and `{region}` tokens plus optional
  lowercase conversion and Windows-safe filename cleanup.
- Added WAV 24-bit PCM and FLAC output, source or fixed sample rates, and source,
  mono, or stereo channel output.
- Writes the current Pitch, Rate, Gain, Reverse, and Preserve Pitch settings to
  the rendered file.
- Added render fade-in/fade-out and Peak, True Peak, or LUFS-I normalization.
- Added increment, skip, and confirmed-overwrite collision handling plus
  optional insertion of completed files into REAPER.

### Project-state and performance safety

- Transfer uses one temporary dry media item at a time instead of creating a
  new full-library analysis or render queue in memory.
- Captures and restores render settings, selected items and tracks, edit cursor,
  time selection, and project dirty state after every file.
- Removes the temporary track on success and failure paths and blocks Transfer
  while the project is playing.
- Batch Transfer uses complete source files; current-asset Transfer can use the
  detailed-waveform selection.

### Documentation and release channel

- Updated the bilingual README, user guides, changelogs, and ReaPack index for
  the 0.7 beta channel.
- Retains 0.6.21 as the formal stable fallback while Transfer compatibility is
  tested.

## 0.6.21 Stable

### Formal stable release

- Marks package 0.6.21 as PsyReaSFX 0.6 Stable; the GitHub Release is no longer
  published as a prerelease.
- Gives time metrics, file/selection context, and operation status the same
  22-pixel layout item with a shared `y + 4` text baseline.
- Keeps the repository-root README in English by default and adds one-click
  English / Simplified Chinese language buttons.
- Updates the ReaPack index to 0.6.21 and an immutable `v0.6.21` tagged source.

## 0.6.20 Stable RC9

### One maintained interface

- Removed the Aether Standard and Review interface presets and consolidated the
  product around one compact, flat, responsive layout.
- Existing settings migrate to the unified layout at startup; custom columns,
  side panels, focus mode, and lower-panel height remain available.
- Reduced the header menu to one Reset to Default Fields action.

### Lower workspace visuals and clipping

- Removed card backgrounds and frames from time metrics.
- Removed outer frames from Pitch, Rate, and Gain while retaining labels, values,
  and parameter tracks; interactive icon buttons keep consistent frames.
- Increased the lower control safety reserve to prevent icon clipping in short
  windows.

### ReaPack and release organization

- Added the official `index.xml` for one-time repository import and in-app
  PsyReaSFX updates.
- Added the ReaPack repository URL and bilingual installation instructions.
- Removed manually uploaded installer ZIPs from older GitHub Releases while
  preserving their notes and version tags.

## 0.6.19 Stable RC8

### Aether short-window fix

- Allocated the result list, splitter, and preview from one runtime height budget,
  so their combined height always matches the central workspace.
- Removed conflicting fixed minimums that allowed the preview controls to extend
  beyond PsyReaSFX and appear over the REAPER window behind it.
- Reduced the detailed waveform minimum progressively as space shrinks, keeping
  the metric row and Studio Strip visible first.

### Studio Strip and status context

- Kept action buttons and Pitch, Rate, and Gain equal in height while increasing
  their shared height, card width, and spacing.
- Preserved the responsive two-row layout and only shows monitor toggles when
  the available row width is sufficient.
- Removed duplicate preview filenames from inline status and clips the remaining
  message to the exact free width.

## 0.6.18 Stable RC7

### Bottom workspace and layout

- Moved file/selection context, Region count, channel mode, Match state, and the
  current status into the metric row.
- Removed the separate summary row, green status row, and their reserved space.
- Recalculated the lower panel from actual content so the waveform fills the
  released area in both Forge Compact and Aether Standard.
- Increased parameter-card spacing while retaining equal button and control
  heights.

### Horizontal result navigation

- Removed RC6's hover overlay navigator.
- Kept `Shift + mouse wheel` over both the pinned header and result rows.
- Clamped horizontal movement from the first position through the rightmost
  field while keeping the pinned header synchronized.

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

