# PsyReaSFX Desktop Alpha 7 reliability audit

Alpha 7 turns the standalone catalog from a one-shot scanner into a recoverable long-running library service. The audit covers the failure paths that matter when a sound library contains many roots, removable volumes or unreadable media.

## Completed

- Recursive Watch Folder service for every enabled physical source.
- Configurable debounce so a copy or extraction burst causes one incremental rebuild instead of hundreds.
- Atomic scan checkpoint recording the processed count and last file.
- Automatic startup resume for an interrupted scan.
- Per-file and per-directory failure records that survive restart and can be retried or cleared.
- SQLite online backups, integrity verification, retention and one-backup-per-day automation.
- Safe next-launch restore that retains a pre-restore copy of the current catalog.
- RWF waveform-cache validation and removal of damaged entries for lazy rebuild.
- Maintenance-center controls and Chinese/English localization for every Alpha 7 action.

## Safety rules

- Source audio is never modified, moved or deleted.
- Watch events are coalesced and never run two scans concurrently.
- A catalog restore is staged and performed before the database is opened.
- Failed source files do not abort a full library scan.
- Cache repair deletes only invalid generated RWF cache files.

## Automated acceptance

The packaged self-test verifies checkpoint persistence, failure recovery, a backed-up database integrity result of `ok`, restore staging and cache validation. Existing browsing, UI, preview, waveform, Regions, analysis and Transfer checks run in the same suite to catch regressions.

## Remaining boundary

REAPER current-track/new-track/BWF spotting and project-use association require a future optional Bridge. They are not represented as standalone controls because the desktop process has no authoritative REAPER project context.
