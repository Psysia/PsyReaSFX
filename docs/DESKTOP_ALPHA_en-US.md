# PsyReaSFX Desktop 0.7.23 Alpha 1

Desktop now follows the same `0.7.23` product baseline as the Lua Stable
edition. Alpha 1 replaces the earlier prototype data model with a production
SQLite catalog and a read-only Lua compatibility importer.

## Included in Alpha 1

- SQLite/WAL catalog prepared for large libraries and full-text indexing.
- Automatic discovery of the existing PsyReaSFX Lua data directory.
- One-time migration of logical libraries, source folders, all 27 asset
  fields, collections, saved searches, preview history, last-session state,
  Regions, loudness analysis and settings.
- Existing desktop library browsing, search, waveform preview, Artwork,
  favorites and file drag connected to the new catalog.
- Immediate catalog startup without an automatic full disk rescan.

Migration never writes to the Lua files. Desktop stores its catalog at
`%LOCALAPPDATA%\PsyReaSFX\catalog-v1.sqlite3`.

Alpha 1 is the data-foundation release, not the final feature-parity build.
Advanced audition, multichannel control, Regions, metadata editing,
collections UI, Transfer and the optional REAPER Bridge remain in active
migration.
