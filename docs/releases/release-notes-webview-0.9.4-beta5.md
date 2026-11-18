# PsyReaSFX 0.9.4 Beta 5 · Windows x64

## 中文

打开 PRS 后即可输入关键词。PRS 在后台分批建立每个库自己的快速搜索索引。再次打开时，先校验当前库的快照与增量日志，再显示最多 32 条可点击试听的匹配项。首次使用或快照刚更换时，快速结果先从日志和快照开头取得。完整列表、筛选和编辑随正常载入恢复。日志损坏或过大时，PRS 保留输入，交给完整加载流程处理。

随包的 PRS 解码器可按需试听 WAV、AIFF、FLAC 和有帧数或时长信息的 MP3。它短时共享读取源文件，向 REAPER 传递匿名采样源。普通点击优先启动试听，小波形一旦生成即可刷新，详情先显示可用概览。波形缓存、原文件变化检测和各库隔离继续生效。其他格式、缺少 SWS 时的试听、插入、拖放及部分分析仍需 PRS 专用副本。

离线安装请关闭 REAPER，解压后运行 `Install-PsyReaSFX.cmd`，再打开 REAPER。安装包包含试听解码器和共享只读运行组件。两个程序同时运行时，声卡缓冲、设备共享设置、介质响应和 WebView 启动时间都会影响实际延迟。

## English

Type a query as soon as the workspace opens. PRS builds a separate quick-search index for each catalog in the background. On subsequent starts it checks the selected snapshot and journal, then offers up to 32 hits for audition. A new or changed snapshot can offer journal entries and the first snapshot rows while the full view loads. If the journal is too large or cannot be verified, PRS retains the query for the full catalog. Editing becomes available when the full catalog is ready.

The included PRS decoder streams WAV, AIFF, FLAC and MP3 files with known length. It reads short ranges with Windows sharing enabled and delivers a pathless audio source to REAPER. Playback takes priority on selection. Newly available list waveforms refresh immediately and the detail view can show an overview first. Other formats, playback without SWS, insertion, dragging and some analyses still use private copies.

Close REAPER, extract the offline ZIP, run `Install-PsyReaSFX.cmd` and reopen REAPER. The package includes the audition decoder and shared-read runtime. Actual latency also depends on the storage device, WebView startup and audio device configuration.
