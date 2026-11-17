# PsyReaSFX 0.9.3 Stable

日期：2026-11-17。Windows x64 的 WebView 分支由 Beta 18 晋升为稳定版。

新增 **导入 Soundminer 音效库**：从音效库菜单或设置打开，选择自动发现的库或指定 `.sqlite` 文件，检查音频路径后点击 **一键导入**。更换硬盘／平台后可填写原路径与本机路径映射；导入保留离线条目，重复素材保留 PRS 现有数据，后台任务可取消。请先关闭 Soundminer；原数据库、缓存和音频只读，有活动 WAL 的数据库拒绝导入。

兼容范围以本次观察的 **V6/V7 SQLite 素材库与 `Caches/waveforms.sqlite` 的 `overviews` 格式**为准。可复用的峰值转换为 PRS 本地缓存；路径、声道、帧数或编码校验不通过时回到 PRS 原有波形生成流程。实现使用纯 Lua，无需用户安装 Python、SQLite 或 zlib 组件，不声称覆盖未知历史／未来格式。缓存格式、限额与真实样本验证见 [Soundminer 兼容记录](../SOUNDMINER_FORMAT_zh-CN.md)。

保留 Beta 18 的元数据草稿、FX 提交顺序、SECTION 试听恢复、Region 身份、Transfer 和后台任务修复。已有音效库、波形与神经缓存继续兼容。常规浏览与试听只读取响度缓存，主动点击 **↻** 才触发原生测量。[Beta 18 的测试证据与验证边界](../WEBVIEW_HARDENING_BETA18_zh-CN.md)。

在 ReaPack 普通同步后，将 `PsyReaSFX.lua` 更新到 **0.9.3**。首次安装需另装同仓库的 **PsyReaSFX WebView Runtime 0.3.9.30**，然后完全重启 REAPER；无需启用预发布。运行库实际二进制仍是 `0.3.9.30-prs.2`，与 `0.3.9.30-beta3` 的 DLL 和匹配源码哈希相同。Beta 18、旧界面测试版和 0.9.1 等历史正式版保留供回退。

运行库的实机验收状态仍按锁定清单记录；当前 `native_acceptance_pending` 不因发行通道变更而变为已验收。本次固定哈希的稳定发行基线可通过普通离线安装器安装；发行通道与实机验收是独立记录。自定义候选仍需显式测试选项，现有外部 DLL 默认保留。神经检索仍使用独立可选数据包，Desktop 仍独立发布。

The Windows x64 WebView line is promoted from Beta 18 to **0.9.3 Stable**. Soundminer import reads the observed V6/V7 SQLite catalog and compatible overview caches, supports path mapping and offline entries, preserves existing PRS assets on repeat import and runs as cancelable background work. Close Soundminer first; source databases, caches and audio remain read-only. Unknown or invalid waveform encodings fall back to ordinary PRS generation. Update the main script normally through ReaPack and install the separate **WebView Runtime 0.3.9.30** package for a first installation, then restart REAPER. No pre-release opt-in is required. The runtime binary remains `0.3.9.30-prs.2`; the pinned stable distribution is installable normally, while native-acceptance diagnostics remain pending and custom candidates still require explicit opt-in. Existing catalogs/caches and legacy rollback versions are retained.
