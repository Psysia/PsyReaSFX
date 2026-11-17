PsyReaSFX 0.9.4 Beta 1 WebView - Windows x64 prerelease

The default stable release remains 0.9.3. This beta retains the Beta18 fixes.
See docs/WEBVIEW_HARDENING_BETA18_zh-CN.md for evidence and verification limits.
Ordinary browsing and audition read cached loudness; use the refresh control
for explicit native measurement.

Soundminer import reads the observed V6/V7 SQLite catalogs and compatible
overview caches into independent catalogs. Soundminer may remain open. Select a database, optionally
map an old audio root to its current location, then use the import action.
See docs/SOUNDMINER_FORMAT_zh-CN.md for supported formats and cache limits.
Active journals or changes stop PRS imports. All original media use shared
read-only access; native playback, analysis, insertion and dragging use private
copies. These require extra disk space and first-use preparation. Copies remain
available to REAPER projects and may be created again in a new PRS session.
Transfer uses the PRS export directory and does not overwrite existing files.

This beta requires the bundled 0.3.9.30-prs.3 shared-read runtime. Native REAPER
acceptance remains pending. Install-PsyReaSFX-Beta.cmd supplies the explicit
-AllowUnverifiedRuntime candidate opt-in. The normal installer refuses a new
candidate runtime without this option.

1. In REAPER, use Options > Show REAPER resource path. Note this folder.
2. Close REAPER. Extract this entire ZIP outside that resource folder.
3. Double-click Install-PsyReaSFX-Beta.cmd and select the resource folder.
4. Restart REAPER. Actions > Show action list > New action > Load ReaScript.
   Select Scripts/PsyReaSFX-WebView/PsyReaSFX.lua inside the resource folder.

The package includes a SHA-256-pinned ReaWebAPI extension. An existing different
extension is preserved by default. Startup checks contracts and shows its actual
version. An older runtime can browse existing indexes but cannot read originals.
To explicitly switch to the bundled candidate runtime after closing REAPER:

powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-PsyReaSFX.ps1 -ReaperResourcePath "YOUR RESOURCE FOLDER" -AllowUnverifiedRuntime -UseBundledRuntime

Restore-PsyReaSFX.cmd restores the latest installation transaction. Backups are
retained under Data/PsyReaSFX-WebView/transactions. A subsequently changed shared
extension is protected from automatic rollback. Catalog data remains managed by
the existing PsyReaSFX backend.

Use a reasonably short resource path. The installer preflights destination and
backup paths against Windows PowerShell 5.1 limits before writing install state.

Automated source-isolation tests do not replace native REAPER acceptance.
CPU, disk and shared audio-device behavior still require native validation. Windows
must provide the Microsoft Edge WebView2 Runtime required by ReaWebAPI.

THIRD-PARTY SOFTWARE
ReaWebAPI is LGPL-3.0-or-later. Its license texts and third-party notices are in
licenses/reawebapi. The complete corresponding source archive is in sources/.
The 0.3.9.30-prs.3 compatibility build is modified; see licenses/reawebapi/PRS_PATCH.md.
It retains dock/float fixes and adds bounded shared read-only source access.
Updating only the PRS Lua/frontend does not update an externally managed DLL.
ReaPack users must enable pre-releases and update both the script to 0.9.4-beta1
and PsyReaSFX WebView Runtime to 0.3.9.30-beta4, then restart REAPER.
PsyReaSFX licensing does not replace these component licenses. The native DLL
is installed as a separate, replaceable shared REAPER extension.
