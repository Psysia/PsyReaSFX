# PsyReaSFX 0.7.23 Desktop parity matrix

This matrix is the acceptance contract for the standalone migration. A feature
is complete only when its behavior is available outside REAPER or, where REAPER
is inherently required, through the optional Bridge.

| Area | Lua 0.7.23 capability | Desktop status |
|---|---|---|
| Catalog | Logical libraries with multiple source folders | Alpha 2 complete |
| Catalog | Incremental scan, Watch Folder, failure recovery | Alpha 7 complete: enabled roots are monitored recursively with a configurable debounce; interrupted scans resume; individual failures persist and can be retried or cleared |
| Catalog | SQLite large-library persistence and full-text index | Foundation complete |
| Compatibility | Import existing Lua libraries and all asset fields | Complete |
| Compatibility | Import collections, searches, history, Regions, loudness and settings | Complete |
| Browse | Virtualized results, configurable pinned columns, folder hierarchy | Complete: virtualized results, persistent column chooser/widths and logical/source folder navigation |
| Search | Filename, path, metadata, UCS, field filters, exclusions | Complete for the Lua 0.7.23 field syntax and Category/Format/Channel facets |
| Artwork | Smart discovery, per-source overrides, inspector display | Alpha 2 complete; embedded artwork pending |
| Organize | Favorites, marks and workflow status | Alpha 4 favorites, multi-selection marks and workflow editing complete |
| Organize | Playlists, project bins, saved searches and history views | Alpha 4 complete; live counts, persistent history, explicit history navigation, current-session audition highlighting and last-session highlight restore verified in RC5 |
| Metadata | Non-destructive single and batch editing | Complete for Lua 0.7.23: core fields, bounded undo, UCS parsing and UTF-8 CSV interchange |
| Preview | Gap-free audition, click-to-seek, loop and scrub | Alpha 4 low-latency click/Space/loop and throttled right-button scrub complete; RC5 adds fade-protected pipeline rebuilds, while device-specific gapless validation remains pending |
| Waveform | Cached inline and high-resolution multichannel waveform | Alpha 3 progressive cache, list playhead and lane labels complete |
| Waveform | Custom cache location and cache migration | Alpha 7 Hotfix 1 complete: generated RWF caches use the selected path; existing caches can be validated and moved, left in place, or reset to the default without touching source media |
| Waveform | Selection, zoom, pan, draggable selection and saved Regions | Alpha 5 complete: prepared selection capsule drag exports an exact temporary WAV; named/manual and transient Regions persist, draw, recall and delete per asset |
| Channels | Original/L/R/mono and multichannel lane selection | Alpha 7 Hotfix 1: CH 1…CH N are actually isolated to dual mono and the detail waveform renders the matching source lane. Arbitrary standalone isolation exceeds the Lua/SWS output-routing limitation |
| Processing | Pitch, Rate, Gain, Reverse and Preserve Pitch | Alpha 4 independent preview engine complete; RC5 restores Lua-style inline numeric editing, reset gestures and wider ranges; Preserve Pitch/Rate has an offline DSP regression test; long-file Reverse is intentionally bounded |
| Analysis | LUFS-I/M/S, peak statistics, loudness matching | Alpha 5 computes, caches and displays offline comparison statistics and supports bounded target-LUFS audition gain |
| Analysis | Transient Region suggestions | Alpha 5 configurable detection, batch replace, undo and cleanup complete |
| Transfer | Output path, naming templates, formats, rates and channels | Alpha 6 complete: dedicated persistent output path; Lua token set; WAV 16/24/32 PCM and FLAC; source/44.1/48/96/192 kHz; source/mono/stereo; WAV chunks and sidecars preserved when possible |
| Transfer | Fades, normalization, smart tail, variants and reports | Alpha 6 complete: fades, Peak/True Peak/RMS-I/LUFS-I, dither/noise shaping, threshold/maximum/hold source tail, Lua-compatible Cartesian variants, collision policies, progress/cancel, latest-output reveal and TSV report |
| REAPER | Drag files and selections into REAPER | Full-file and selected-range file drag available; temporary range WAVs never modify the source |
| REAPER | Current track/new track/BWF insertion and project association | Alpha 8 complete through the optional bundled Bridge; successful deliveries persist project, track, position and source identity |
| Reliability | Watch folders, interrupted scans, failure recovery | Alpha 7 complete with recursive monitoring, debounced incremental rebuilds, atomic checkpoints and persistent retryable failures |
| Reliability | Catalog backup/restore and waveform-cache integrity | Alpha 7 complete: validated SQLite backups with retention and safe next-launch restore; damaged RWF caches can be checked, removed and rebuilt on demand |
| Product | Chinese/English UI, themes, settings and diagnostics | Complete for the standalone scope: runtime localization, persistent Dark/Classic palettes, full shell/waveform color control, diagnostics and the Alpha 7 maintenance center. Low-level exception text may still originate from Windows/FFmpeg |

## Delivery rule

The version remains `0.7.23` while Alpha/Beta labels identify the desktop
migration stage. Desktop is not declared Stable until every row above is either
complete or explicitly documented as a Bridge-only operation.

## Overall Lua relationship

Alpha 8 aligns the Lua direct-delivery workflow through the optional bundled
Bridge: current/new-track insertion, BWF spotting and project-use association
are connected. Desktop remains ahead in arbitrary-channel isolation, SQLite
reliability, Watch Folder recovery, validated backups and cache health.
Processing or rendering through REAPER tracks, sends or Master FX is a future
extension rather than part of the Lua direct-delivery parity path.

## Desktop Alpha visibility rule

The desktop UI only exposes controls that are connected in the current build.
Migrated data whose editor or workflow has not yet reached desktop parity stays
safe in SQLite but is not presented as a disabled or misleading control. The
matrix above is the source of truth for pending work.
