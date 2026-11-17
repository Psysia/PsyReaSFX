# PsyReaSFX 0.9.4 Beta 1

日期：2026-11-17。本次为 Windows x64 WebView 预发布，新增 Soundminer 独立库；默认稳定版为沿用 Beta 18 功能的 **0.9.3**。

从 **文件／音效库 → 导入 Soundminer 音效库** 或设置打开，选择自动发现的数据库或指定 `.sqlite` 文件，按 **一键导入** 创建独立库并打开对应窗口。更换硬盘／平台后可填写原路径与本机路径映射，保留离线条目。原有 PRS 库与每个 Soundminer 导入库的索引、元数据、设置和缓存分开保存；相同音频不会导致不同库合并或覆盖。

窗口右上角显示当前库；**选择独立库** 打开所选库，已打开的窗口直接切到前台。取消或失败后通过 **继续导入** 补全，保留已完成条目。再次选择相同数据库与路径映射时复用已保存的库，可修正缓存路径与波形选项；通过 **继续导入** 应用到待补全的缓存。独立 Soundminer 库不自动扫描来源目录，避免加入数据库未收录的音频。

读取已观察的 **V6/V7 SQLite 素材库与 `Caches/waveforms.sqlite` 的 `overviews` 格式**，兼容峰值转换为当前独立库的 RWF2／RWF3 缓存。路径、声道、帧数或编码校验不通过时，使用私有音频副本生成 PRS 波形。数据库及波形解析为 Lua 实现，无需安装 Python、SQLite 或 zlib；共享读取由配套原生运行库提供。未知历史／未来格式不保证兼容；格式、限额与实际样本记录见 [Soundminer 兼容记录](../SOUNDMINER_FORMAT_zh-CN.md)。

Soundminer 可以同时运行。数据库、缓存、原音频及封面使用共享只读句柄，允许其他程序写入、重命名和删除。遇到活动 WAL／journal 或源文件变化，PRS 停止本次导入；持续写入时可导入 Soundminer 生成的一致数据库副本。PRS 不控制 Soundminer 进程，不写回原库。

原有 PRS 库也启用源文件保护：首次原生试听、分析、插入、拖放或导出前，会在后台准备私有副本，可在任务中取消。副本占用额外磁盘，保留供 REAPER 工程引用；复用限于当前会话，重新打开后可能再次复制。Transfer 限定为 PRS 专属导出目录，不覆盖已有文件。波形缓存维护仅处理 PRS 自有格式文件。

在 ReaPack 启用预发布后，将 `PsyReaSFX.lua` 更新到 **0.9.4-beta1**，并将独立包 **PsyReaSFX WebView Runtime** 更新到 **0.3.9.30.3-beta1**（DLL `0.3.9.30-prs.3`），完全重启 REAPER。旧运行库仍可浏览索引，但不能进行新的源文件读取。离线安装候选运行库须显式传入 `-AllowUnverifiedRuntime`；已有旧 DLL 需同时使用 `-UseBundledRuntime` 才会替换。新运行库仍标记为候选，实机验收待补充。可从 Versions 返回 **0.9.3 稳定版**；稳定版运行库仍为 `0.3.9.30`。

共享句柄与合成并发读写、导入隔离、取消和缓存维护已纳入自动测试。实际 REAPER 与 Soundminer 同时使用时的音频设备、CPU 和磁盘争用仍需实机验收；不宣称“零资源影响”。

This is **0.9.4 Beta 1**, a Windows x64 prerelease; **0.9.3** remains stable. Soundminer catalogs are independent, resumable and excluded from automatic folder discovery. All original media, including the existing PRS library, use shared read-only access; native consumers receive private copies. Soundminer can remain open, while source changes or active journals stop PRS imports. Copies require additional storage and preparation time; Transfer uses the PRS export directory. Install both the script `0.9.4-beta1` and runtime `0.3.9.30.3-beta1` through ReaPack pre-releases, then restart REAPER. The offline candidate installer requires `-AllowUnverifiedRuntime`, plus `-UseBundledRuntime` to replace an existing DLL. The new `0.3.9.30-prs.3` runtime remains pending native acceptance. See the compatibility record for format and validation limits.
