# PsyReaSFX Desktop Preview

PsyReaSFX Desktop 是 REAPER 集成版的 Windows x64 独立伴侣。Preview 1 专注“浏览到 REAPER”的核心闭环：多来源逻辑库、增量索引、搜索、虚拟化列表波形、按声道显示的大波形、点击定位试听、Artwork、收藏和通过 Windows 文件拖放进入 REAPER。

请从 [GitHub Releases](https://github.com/Psysia/PsyReaSFX/releases/latest) 下载最新包，完整解压后运行 `PsyReaSFX.Desktop.exe`。发布包自带 Windows x64 .NET 运行时，可与 ReaPack 版并存。

首个预览版暂未与 PsyReaSFX 0.7 Stable 完全等价。详细波形优先支持 PCM/浮点 WAV；压缩格式试听取决于 Windows 解码器。元数据编辑、保存搜索、播放列表、Region、响度分析、Transfer 渲染和自动更新仍在桌面版路线图中。

本地数据位于 `%LOCALAPPDATA%\PsyReaSFX Desktop\state.json`，源音频保持只读。
