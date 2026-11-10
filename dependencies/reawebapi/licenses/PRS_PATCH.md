# PsyReaSFX Windows compatibility build

This is a modified LGPL-3.0-or-later build, `0.3.9.30-prs.1`, based exactly on
upstream commit `f3d83ee333a5df0f1242b20efc706ce5a893dabf` (v0.3.9.30).
It is not an upstream release. Main and upstream release tags remain untouched.

The Docker WebView redraw workaround now applies only to child containers.
Top-level windows, including REAPER's main window, retain WM_SETREDRAW batching.
Previously the hook consumed FALSE/TRUE messages at every ancestor, bypassing
the DAW's redraw suspension while a visible WebView was docked.

The isolated Windows regression creates only its own offscreen windows. It
checks DAW batching, Docker surface protection, repeated layout notifications,
multiple docked tabs and hook cleanup. It does not claim native REAPER/WebView2
visual acceptance; Docker resizing and inactive-tab restore still need that
acceptance. No audio, DSP, IPC or public API contracts are changed.

Full corresponding source accompanies the patched binary. Future upstream
updates must retain this fix or pass the same regression before promotion.
