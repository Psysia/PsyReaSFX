# PsyReaSFX 0.9.4 Beta 1

日期：2026-11-17。本次为 Windows x64 WebView 预发布，新增 Soundminer 独立库；默认稳定版为沿用 Beta 18 功能的 **0.9.3**。

从 **文件／音效库 → 导入 Soundminer 音效库** 或设置打开，选择自动发现的数据库或指定 `.sqlite` 文件，按 **一键导入** 创建独立库并打开对应窗口。更换硬盘／平台后可填写原路径与本机路径映射，保留离线条目。原有 PRS 库与每个 Soundminer 导入库的索引、元数据、设置和缓存分开保存；相同音频不会导致不同库合并或覆盖。

窗口右上角显示当前库；**选择独立库** 打开所选库，已打开的窗口直接切到前台。取消或失败后通过 **继续导入** 补全，保留已完成条目。再次选择相同数据库与路径映射时复用已保存的库，可修正缓存路径与波形选项；通过 **继续导入** 应用到待补全的缓存。独立 Soundminer 库不自动扫描来源目录，避免加入数据库未收录的音频。

读取已观察的 **V6/V7 SQLite 素材库与 `Caches/waveforms.sqlite` 的 `overviews` 格式**，兼容峰值转换为当前独立库的 RWF2／RWF3 缓存。路径、声道、帧数或编码校验不通过时，回到 PRS 波形生成流程。实现为纯 Lua，无需安装 Python、SQLite 或 zlib。未知历史／未来格式不保证兼容；格式、限额与实际样本记录见 [Soundminer 兼容记录](../SOUNDMINER_FORMAT_zh-CN.md)。

导入前请关闭 Soundminer。原数据库、缓存和音频保持只读，有活动 WAL／journal 的数据库拒绝读取。

在 ReaPack 启用预发布后，将 `PsyReaSFX.lua` 更新到 **0.9.4-beta1**；首次安装需另装 **PsyReaSFX WebView Runtime 0.3.9.30** 并重启 REAPER。运行库实际二进制仍为 `0.3.9.30-prs.2`，实机验收状态保持原记录。可从 Versions 返回 **0.9.3 稳定版**，PRS 原有数据目录保持兼容。

This is **0.9.4 Beta 1**, a prerelease for Windows x64. The default stable release remains **0.9.3**, which promotes the existing Beta 18 feature set. Soundminer imports open independent catalogs with separate metadata, indexes, settings and waveform caches. Choosing a catalog opens or focuses its own window; canceled or failed imports can be resumed. Automatic folder discovery is disabled in Soundminer catalogs so files absent from the selected database are not added automatically. Sources remain read-only. Compatibility covers the observed V6/V7 SQLite and overview formats; unsupported waveforms fall back to PRS generation. Enable ReaPack pre-releases to install `0.9.4-beta1` and install the separate runtime `0.3.9.30` if needed. See the compatibility record for validation limits.
