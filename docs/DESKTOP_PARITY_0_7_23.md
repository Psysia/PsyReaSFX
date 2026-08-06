# PsyReaSFX 0.7.23 Desktop parity matrix

This matrix is the acceptance contract for the standalone migration. A feature
is complete only when its behavior is available outside REAPER or, where REAPER
is inherently required, through the optional Bridge.

| Area | Lua 0.7.23 capability | Desktop status |
|---|---|---|
| Catalog | Logical libraries with multiple source folders | Foundation complete |
| Catalog | Incremental scan, Watch Folder, failure recovery | In progress |
| Catalog | SQLite large-library persistence and full-text index | Foundation complete |
| Compatibility | Import existing Lua libraries and all asset fields | Complete |
| Compatibility | Import collections, searches, history, Regions, loudness and settings | Complete |
| Browse | Virtualized results, configurable pinned columns, folder hierarchy | Partial |
| Search | Filename, path, metadata, UCS, field filters, exclusions | Partial |
| Artwork | Smart discovery, per-source overrides, inspector display | Partial |
| Organize | Favorites, marks and workflow status | Partial |
| Organize | Playlists, project bins, saved searches and history views | Data migrated; UI pending |
| Metadata | Non-destructive single and batch editing | Pending |
| Preview | Gap-free audition, click-to-seek, loop and scrub | Basic preview only |
| Waveform | Cached inline and high-resolution multichannel waveform | Partial |
| Waveform | Selection, zoom, pan, draggable selection and saved Regions | Pending |
| Channels | Original/L/R/mono and multichannel lane selection | Pending |
| Processing | Pitch, Rate, Gain, Reverse and Preserve Pitch | Pending |
| Analysis | LUFS-I/M/S, True Peak, loudness matching | Data migrated; engine pending |
| Analysis | Transient Region suggestions | Data migrated; engine pending |
| Transfer | Output path, naming templates, formats, rates and channels | Pending |
| Transfer | Fades, normalization, smart tail, variants and reports | Pending |
| REAPER | Drag files and selections into REAPER | Full-file drag available |
| REAPER | Current track/new track/BWF insertion and project association | Bridge pending |
| Product | Chinese/English UI, themes, settings and diagnostics | Pending migration |

## Delivery rule

The version remains `0.7.23` while Alpha/Beta labels identify the desktop
migration stage. Desktop is not declared Stable until every row above is either
complete or explicitly documented as a Bridge-only operation.
