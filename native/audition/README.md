# PRS audition extension for Windows x64

This extension supplies a transient REAPER PCM source, incremental peak decoding and an optional SQLite search index in REAPER's own Data directory. It registers no media file extensions. The search index uses Windows' system copy of SQLite when it supports FTS5 trigram. PRS can browse without the index.

Build from the repository root using Zig 0.15.2 and Python. The build reads the bundled Cockos SDK header. Only the decoder class uses the Win64 MSVC C++ ABI.

```powershell
python native/audition/build.py --zig C:/tools/zig/zig.exe --out dist/audition-build
python tools/test_audition_native.py dist/audition-build/reaper_prs_audition.dll --out dist/audition-test
```

The vendored dr_wav, dr_flac and dr_mp3 headers are from [dr_libs commit 0901cdc](https://github.com/mackron/dr_libs/tree/0901cdc54e719e2175827cb60b78fe725e581fe2). Their license ships in `licenses/audition/dr_libs.txt`. FFmpeg is used only to generate additional synthetic formats in the developer test.
