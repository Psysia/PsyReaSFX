PsyReaSFX 0.9.4 Beta 5 WebView - Windows x64 prerelease

The default stable release remains 0.9.3. This beta retains the Beta18 fixes.
Setup prompts follow the Windows display language: Chinese for Chinese UI,
English for other languages or when detection is unavailable. This includes
first-launch errors, waiting/restart instructions and completion messages.
See docs/WEBVIEW_HARDENING_BETA18_zh-CN.md for evidence and verification limits.
Ordinary browsing and audition read cached loudness; use the refresh control
for explicit native measurement.

Soundminer import reads the observed V6/V7 SQLite catalogs and compatible
overview caches into independent catalogs. Soundminer may remain open. Select a database, optionally
map an old audio root to its current location, then use the import action.
See docs/SOUNDMINER_FORMAT_zh-CN.md for supported formats and cache limits.
Active journals or changes stop PRS imports. All original media use shared
read-only access. The included PRS decoder streams WAV, AIFF, FLAC and MP3
for audition. Unsupported formats, insertion, dragging and some analyses use private
copies. These require extra disk space and first-use preparation. Copies remain
available to REAPER projects and may be created again in a new PRS session.
WAV、AIFF、FLAC、MP3 由随包共享只读解码器试听。插入、拖放、其他格式及部分分析仍使用专用副本。
Transfer uses the PRS export directory and does not overwrite existing files.

The main package includes the 0.3.9.30-prs.3 shared-read component. No separate
runtime download or version selection is needed. Native REAPER acceptance
remains pending. Automatic installation is limited to the exact DLL and source
hashes approved for this release; custom candidates still require opt-in.

1. In REAPER, use Options > Show REAPER resource path. Note this folder.
2. Close REAPER. Extract this entire ZIP outside that resource folder.
3. Double-click Install-PsyReaSFX.cmd and select the resource folder.
4. Restart REAPER. Actions > Show action list > New action > Load ReaScript.
   Select Scripts/PsyReaSFX-WebView/PsyReaSFX.lua inside the resource folder.

Known previous PRS components are backed up and upgraded automatically. Unknown
shared extensions are preserved. Startup checks contracts and shows the actual
version. To explicitly replace an unknown shared runtime after closing REAPER:

powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-PsyReaSFX.ps1 -ReaperResourcePath "YOUR RESOURCE FOLDER" -UseBundledRuntime

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
ReaPack users enable pre-releases and update only PsyReaSFX.lua to 0.9.4-beta4.
First launch prepares the included component. A known old component is upgraded
after all REAPER windows close, with a completion message before reopening.
No process is terminated. Initial native setup requires one REAPER restart;
later launches start normally. The helper does not access Soundminer files.
PsyReaSFX licensing does not replace these component licenses. The native DLL
is installed as a separate, replaceable shared REAPER extension.
