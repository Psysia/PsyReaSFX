# PsyReaSFX Windows compatibility build

This is a modified LGPL-3.0-or-later build, `0.3.9.30-prs.2`, based exactly on
upstream commit `f3d83ee333a5df0f1242b20efc706ce5a893dabf` (v0.3.9.30).
It is not an upstream release. Main and upstream release tags remain untouched.

The Docker WebView redraw workaround now applies only to child containers.
Top-level windows, including REAPER's main window, retain WM_SETREDRAW batching.
Previously the hook consumed FALSE/TRUE messages at every ancestor, bypassing
the DAW's redraw suspension while a visible WebView was docked.

The second patch also suspends the shared redraw workaround during structural
Docker operations. REAPER can then update its tab/control tree under its normal
redraw suspension, including closing a docked window. Native disable/enable
pairs remain balanced across the end of a transition and across shared tabs.
Browser layout, position notification, icon refresh and focus restoration wait
until the host operation has returned. WebView2 MoveFocus always uses a queued,
coalesced notification rather than a synchronous native focus callback.

The isolated Windows regressions create only process-owned offscreen windows.
They cover shared/nested transitions, late redraw enable, pending batches,
destroyed host lifetimes, and real WebView2 dock/float cycles with retained page
state. Runtime tests verify that both explicit undock and close use the scope.
No tests launch REAPER. These are compatibility regression tests, not proof
that the reported crash has been reproduced or eliminated in native REAPER.
The host fault was an invalid pointer read during a control/accessibility
query; a complete crash stack was not retained by Windows. Native REAPER
acceptance remains pending. No audio, DSP, IPC or public API contracts change.

Full corresponding source accompanies the patched binary. Future upstream
updates must retain this fix or pass the same regression before promotion.
