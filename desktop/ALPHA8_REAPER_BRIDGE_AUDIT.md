# PsyReaSFX Desktop Alpha 8 REAPER Bridge audit

Alpha 8 closes the remaining direct-delivery gap between the standalone
Desktop application and the Lua 0.7.23 workflow. The integration is optional:
Desktop never requires REAPER to launch, browse, audition, organize or export.

## Delivered

- Bundled persistent `PsyReaSFX_REAPER_Bridge.lua` ReaScript.
- Non-blocking heartbeat and atomic per-request file queue under the current
  user's LocalAppData directory.
- Current-track delivery, new-track delivery and BWF timestamp spotting.
- Exact waveform-selection delivery for current/new-track commands; the source
  file is never modified.
- Toolbar connection state, connection test and queue-directory access.
- Keyboard parity: Enter, Ctrl+Enter and Shift+Enter.
- Persistent project-use history with source, project, track and position.
- Chinese/English labels and dedicated vector icons matching the Desktop shell.

## Safety and performance

- Request files are written to a temporary path and atomically renamed.
- Desktop times out instead of blocking when REAPER stops responding.
- Bridge polling is lightweight and never scans the sound catalog.
- BWF Spot always uses the original media file; temporary selections are used
  only for current/new-track range delivery.
- The protocol and project-usage database paths are covered by the packaged
  automated self-test.

## Remaining boundary

Rendering through a project's track FX, sends or Master FX is not part of A8.
That requires a future render contract, not direct media insertion, and remains
separate from the now-complete Lua direct-delivery parity path.
