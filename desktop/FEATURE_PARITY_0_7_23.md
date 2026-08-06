# PsyReaSFX 0.7.23 Desktop parity matrix

This matrix is the acceptance contract for the standalone migration. A feature
is complete only when its behavior is available outside REAPER or, where REAPER
is inherently required, through the optional Bridge.

| Area | Lua 0.7.23 capability | Desktop status |
|---|---|---|
| Catalog | Logical libraries with multiple source folders | Alpha 2 complete |
| Catalog | Incremental scan, Watch Folder, failure recovery | Incremental scan complete; watch/recovery pending |
| Catalog | SQLite large-library persistence and full-text index | Foundation complete |
| Compatibility | Import existing Lua libraries and all asset fields | Complete |
| Compatibility | Import collections, searches, history, Regions, loudness and settings | Complete |
| Browse | Virtualized results, configurable pinned columns, folder hierarchy | Alpha 3 virtualized results and persistent header column chooser complete; folder tools pending |
| Search | Filename, path, metadata, UCS, field filters, exclusions | Alpha 2 browsing syntax complete; UCS facets pending |
| Artwork | Smart discovery, per-source overrides, inspector display | Alpha 2 complete; embedded artwork pending |
| Organize | Favorites, marks and workflow status | Alpha 4 favorites, multi-selection marks and workflow editing complete |
| Organize | Playlists, project bins, saved searches and history views | Data migrated; UI pending |
| Metadata | Non-destructive single and batch editing | Alpha 4 core fields complete; field presets/CSV pending |
| Preview | Gap-free audition, click-to-seek, loop and scrub | Click-to-seek, auto-preview, Space and selection loop complete; gapless/scrub pending |
| Waveform | Cached inline and high-resolution multichannel waveform | Alpha 3 progressive cache, list playhead and lane labels complete |
| Waveform | Selection, zoom, pan, draggable selection and saved Regions | Selection/zoom/pan complete; drag export and saved Regions pending |
| Channels | Original/L/R/mono and multichannel lane selection | Pending |
| Processing | Pitch, Rate, Gain, Reverse and Preserve Pitch | Alpha 3 Rate/Gain complete; Pitch/Reverse/Preserve Pitch pending low-latency engine |
| Analysis | LUFS-I/M/S, True Peak, loudness matching | Data migrated; engine pending |
| Analysis | Transient Region suggestions | Data migrated; engine pending |
| Transfer | Output path, naming templates, formats, rates and channels | Pending |
| Transfer | Fades, normalization, smart tail, variants and reports | Pending |
| REAPER | Drag files and selections into REAPER | Full-file drag available |
| REAPER | Current track/new track/BWF insertion and project association | Bridge pending |
| Product | Chinese/English UI, themes, settings and diagnostics | Lua-aligned dark shell, real settings and diagnostics complete; full localization/themes pending |

## Delivery rule

The version remains `0.7.23` while Alpha/Beta labels identify the desktop
migration stage. Desktop is not declared Stable until every row above is either
complete or explicitly documented as a Bridge-only operation.

## Desktop Alpha visibility rule

The desktop UI only exposes controls that are connected in the current build.
Migrated data whose editor or workflow has not yet reached desktop parity stays
safe in SQLite but is not presented as a disabled or misleading control. The
matrix above is the source of truth for pending work.
