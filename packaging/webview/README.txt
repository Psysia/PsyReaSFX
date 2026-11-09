PsyReaSFX 0.9.a WebView preview - Windows x64

Candidate runtimes pending native acceptance are blocked from default install
and replacement. Maintainers may use -AllowUnverifiedRuntime when testing an
isolated REAPER profile. Use a native-accepted release for normal installation.
Install-PsyReaSFX-Beta.cmd explicitly opts into the pinned candidate runtime.
The beta launcher is intended for an isolated REAPER resource folder.

1. In REAPER, use Options > Show REAPER resource path. Note this folder.
2. Close REAPER. Extract this entire ZIP outside that resource folder.
3. Double-click Install-PsyReaSFX.cmd and select the resource folder.
4. Restart REAPER. Actions > Show action list > New action > Load ReaScript.
   Select Scripts/PsyReaSFX-WebView/PsyReaSFX.lua inside the resource folder.

The package includes a SHA-256-pinned ReaWebAPI extension. An existing different
extension is preserved by default. Startup checks contracts and shows its actual
version. To explicitly switch to the bundled candidate after closing REAPER:

powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-PsyReaSFX.ps1 -ReaperResourcePath "YOUR ISOLATED RESOURCE FOLDER" -UseBundledRuntime -AllowUnverifiedRuntime

Restore-PsyReaSFX.cmd restores the latest installation transaction. Backups are
retained under Data/PsyReaSFX-WebView/transactions. A subsequently changed shared
extension is protected from automatic rollback. Catalog data remains managed by
the existing PsyReaSFX backend.

Use a reasonably short resource path. The installer preflights destination and
backup paths against Windows PowerShell 5.1 limits before writing install state.

The pinned runtime is a candidate pending native REAPER acceptance. Upstream
updates are evaluated separately before changing the dependency lock. Windows
must provide the Microsoft Edge WebView2 Runtime required by ReaWebAPI.

THIRD-PARTY SOFTWARE
ReaWebAPI is LGPL-3.0-or-later. Its license texts and third-party notices are in
licenses/reawebapi. The matching, unmodified source archive is in sources/.
PsyReaSFX licensing does not replace these component licenses. The native DLL
is installed as a separate, replaceable shared REAPER extension.
