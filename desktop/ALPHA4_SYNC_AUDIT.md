# Desktop Alpha 4 synchronization audit

This audit compares the standalone Alpha 4 scope with the official Lua
`0.7.23` changelog. It exists to distinguish an actual desktop omission from a
feature intentionally scheduled for a later desktop stage.

## Restored or verified through RC6

- Lua-style named navigation groups, including persistent expanded/collapsed
  state instead of anonymous arrows.
- Draggable vertical and horizontal scrollbar thumbs plus Shift+wheel result
  navigation.
- Pinned, resizable and persistently configurable result columns.
- Preview-history root navigation, newest-first ordering and persistent counts.
- Warm current/previous-session audition highlighting with independent restore,
  clear-current and clear-saved actions.
- Pitch, Rate and Gain wheel adjustment, double-click reset, inline numeric
  entry and shortcut isolation while an editor is active.
- Preserve Pitch/Rate separation with an offline DSP regression check.
- Fade-protected preview start, restart, loop and scrub pipeline replacement.
- Chinese/English switching for the primary shell and settings center.
- Dark themed collection, saved-search, Facet, ComboBox and context-menu
  surfaces.
- Safe repeated runtime localization. Translating WPF `Run` collections no
  longer invalidates the active enumerator, and all named navigation sections
  are covered by the English/Chinese acceptance test.
- Lua appearance parity for the early 0.6 line: Dark and Classic presets,
  framework and accent colors, played-text color, normal/selected/played/marked
  waveform colors, selection and playhead colors, system color picker, live
  preview and preset restoration.
- Lua waveform-state priority `selected > marked > played > normal`, with the
  played-waveform recolor kept as an independent opt-in.
- User-selectable Space behavior: normal pause/resume or restart from the
  current waveform selection start.
- Real Thumb gesture verification for both scrollbar orientations, not only
  programmatic value binding.

## Complete Alpha 4 organization surface

- Favorites, marks and workflow states.
- Playlists and project bins with batch add/remove and live counts.
- Saved searches that restore query, library, collection, workflow and sort.
- Preview history and recently inserted views.
- Non-destructive metadata editing, bounded undo, UCS filename parsing and CSV
  interchange.
- Category, format and channel Facets.

## Not yet synchronized (scheduled after Alpha 4)

- Watch-folder recovery, scan checkpointing and missing-file relink.
- Saved waveform Regions, transient suggestions and loudness analysis.
- Transfer processing, normalization, smart tails, batch variants and reports.
- REAPER Bridge insertion/project association.
- Embedded-container Artwork and reusable metadata presets.
- Full folder-hierarchy hover navigation and folder-scoped browsing parity.
- Arbitrary multichannel groups beyond the current source-channel solo/downmix.

The full acceptance state remains in `FEATURE_PARITY_0_7_23.md`. Desktop 1.0
targets complete Lua `0.7.23` parity; REAPER-only operations will be delivered
through the optional Bridge rather than silently removed.
