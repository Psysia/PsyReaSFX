# PRS audition extension for Windows x64

This extension supplies a transient REAPER PCM source, incremental peak decoding and an optional SQLite search index in REAPER's own Data directory. It registers no media file extensions. The search index uses Windows' system copy of SQLite when it supports FTS5 trigram. PRS can browse without the index.

The Soundminer reader uses Windows' system SQLite to page through metadata, look up waveform records, and search a library's own FTS3/4 index when available. Source handles allow shared reading, writing and deletion. PRS checks the source generation before and after each batch and stops if Soundminer changes the file or a transaction journal becomes active. Supported libraries can still use the portable reader when system SQLite is unavailable.

Soundminer 读取器调用 Windows 自带的 SQLite 分批读取元数据、按索引定位波形，并在库包含兼容的 FTS3/4 索引时直接搜索。读取期间允许其他程序读写或重命名源文件。PRS 在每批读取前后核对文件状态，遇到库文件变更或活跃事务日志时停止本次读取。系统 SQLite 不可用时，兼容的库仍可使用内置的只读解析器。

`PRS_SM_Open`, `PRS_SM_Valid`, `PRS_SM_Read`, `PRS_SM_Search` and `PRS_SM_Close` use a private read-only SQLite VFS. SQLite sees an opaque database token. Only the adapter opens a source handle, and only for the duration of an operation. `PRS_SM_LocalDrives` lists fixed, removable and RAM drive letters for path translation.

上述 `PRS_SM_*` 数据库接口共用私有只读 SQLite VFS。SQLite 通过标识访问库，适配器仅在每次操作期间持有源文件句柄。`PRS_SM_LocalDrives` 为路径转换提供固定磁盘、可移动磁盘和内存磁盘的盘符。

Build from the repository root using Zig 0.15.2 and Python. The build reads the bundled Cockos SDK header. Only the decoder class uses the Win64 MSVC C++ ABI.

```powershell
python native/audition/build.py --zig C:/tools/zig/zig.exe --out dist/audition-build
python tools/test_audition_native.py dist/audition-build/reaper_prs_audition.dll --out dist/audition-test
```

The vendored dr_wav, dr_flac and dr_mp3 headers are from [dr_libs commit 0901cdc](https://github.com/mackron/dr_libs/tree/0901cdc54e719e2175827cb60b78fe725e581fe2). Their license ships in `licenses/audition/dr_libs.txt`. FFmpeg is used only to generate additional synthetic formats in the developer test.
