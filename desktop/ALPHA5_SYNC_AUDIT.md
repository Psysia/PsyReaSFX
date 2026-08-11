# PsyReaSFX Desktop Alpha 5 synchronization audit

This audit compares the standalone Light edition with the Lua 0.7.23 Stable
waveform and analysis workflow. A migrated database row or visible placeholder
does not count as a connected feature.

## Connected in Alpha 5

- Result scrollbars use immediate two-way tracking. Both orientations expose a
  rectangular inset thumb whose full geometry remains inside the DataGrid
  clipping boundary. The real DataGrid regression fixture requires a vertical
  thumb of at least 42 px and a horizontal thumb of at least 60 px.
- A detail-waveform range is prepared asynchronously, then the visible
  `Drag selection out` capsule follows that range and starts a synchronous
  Windows file drag. The exported temporary WAV contains only the selected
  frames, preserves complete audio blocks (including 24-bit stereo), and does
  not modify source media.
- Multiple named Regions are persisted and drawn together. Manual Regions and
  automatic transient suggestions use distinct outlines and can be recalled or
  deleted independently.
- Transient detection exposes threshold, smoothing, minimum interval, pre-roll,
  post-roll and maximum-count controls. Suggestion batches can replace previous
  suggestions, be undone as a batch, or be cleared without touching manual
  Regions.
- New source files can be analyzed offline for LUFS-I, maximum LUFS-M/S and peak
  statistics. Results are cached by source path and file-size signature.
- Optional loudness-matched audition applies a bounded gain offset toward a
  configurable target while preserving the user's Gain control and source file.
- Dark and Classic presets remain available. Every major shell surface, text
  role, selected row and waveform state has an independent system color picker.
- Rapid selection, preview, selection-export and loudness cancellation use an
  owner-disposal lifecycle so a superseded background task cannot access a
  prematurely disposed cancellation source.

## Automated acceptance

The packaged Alpha 5 self-test verifies:

- vertical and horizontal scrollbar value binding, simulated drag gestures and
  complete thumb containment;
- selection export duration, channel count and valid generated media;
- Region save/load/delete, multiple overlay rendering and transient detection;
- offline loudness calculation and cache persistence;
- UI construction, panel toggles, resizable columns and playhead-layer isolation;
- Chinese/English switching, Dark/Classic switching, organization state,
  metadata editing and Preserve Pitch independence;
- representative 64-file thumbnail processing without unbounded UI work.

## Deliberate later-stage work

Transfer/export, watch-folder recovery, catalog repair and the optional REAPER
Bridge belong to later desktop migration stages. They are tracked in
`FEATURE_PARITY_0_7_23.md` and are not represented by non-functional controls.
