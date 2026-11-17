PsyReaSFX 0.9.3 WebView Stable - Windows x64

This stable release retains Beta18 fixes for metadata/FX/Region/preview races and transfer/cancellation failures.
See docs/WEBVIEW_HARDENING_BETA18_zh-CN.md for evidence and verification limits.
Ordinary browsing and audition read cached loudness; use the refresh control
for explicit native measurement. The pinned runtime remains unchanged.

The pinned stable distribution installs normally with Install-PsyReaSFX.cmd.
Distribution approval is tied to its exact binary SHA-256 and is independent
of native REAPER acceptance, which remains pending in runtime diagnostics.
Custom candidate runtimes still require -AllowUnverifiedRuntime for testing
in an isolated profile. Install-PsyReaSFX-Beta.cmd supplies that candidate opt-in.

1. In REAPER, use Options > Show REAPER resource path. Note this folder.
2. Close REAPER. Extract this entire ZIP outside that resource folder.
3. Double-click Install-PsyReaSFX.cmd and select the resource folder.
4. Restart REAPER. Actions > Show action list > New action > Load ReaScript.
   Select Scripts/PsyReaSFX-WebView/PsyReaSFX.lua inside the resource folder.

The package includes a SHA-256-pinned ReaWebAPI extension. An existing different
extension is preserved by default. Startup checks contracts and shows its actual
version. To explicitly switch to the bundled stable runtime after closing REAPER:

powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-PsyReaSFX.ps1 -ReaperResourcePath "YOUR RESOURCE FOLDER" -UseBundledRuntime

Restore-PsyReaSFX.cmd restores the latest installation transaction. Backups are
retained under Data/PsyReaSFX-WebView/transactions. A subsequently changed shared
extension is protected from automatic rollback. Catalog data remains managed by
the existing PsyReaSFX backend.

Use a reasonably short resource path. The installer preflights destination and
backup paths against Windows PowerShell 5.1 limits before writing install state.

Stable distribution does not change the pending native REAPER acceptance
status. Upstream candidates are evaluated separately before changing the lock. Windows
must provide the Microsoft Edge WebView2 Runtime required by ReaWebAPI.

THIRD-PARTY SOFTWARE
ReaWebAPI is LGPL-3.0-or-later. Its license texts and third-party notices are in
licenses/reawebapi. The complete corresponding source archive is in sources/.
The 0.3.9.30-prs.2 compatibility build is modified; see licenses/reawebapi/PRS_PATCH.md.
It fixes docked redraw ownership and dock-to-floating transition handling.
Updating only the PRS Lua/frontend does not update an externally managed DLL.
ReaPack users of PsyReaSFX WebView Runtime should install/update it to 0.3.9.30 (the same DLL as beta3).
PsyReaSFX licensing does not replace these component licenses. The native DLL
is installed as a separate, replaceable shared REAPER extension.
