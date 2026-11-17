# PsyReaSFX 0.9.3 Stable

日期：2026-11-17。Windows x64 的 WebView 分支由 Beta 18 晋升为稳定版，功能以 Beta 18 为基线。

保留 Beta 18 的元数据草稿、FX 提交顺序、SECTION 试听恢复、Region 身份、Transfer 和后台任务修复。已有音效库、波形与神经缓存继续兼容。常规浏览与试听只读取响度缓存，主动点击 **↻** 才触发原生测量。[Beta 18 的测试证据与验证边界](../WEBVIEW_HARDENING_BETA18_zh-CN.md)。

在 ReaPack 普通同步后，将 `PsyReaSFX.lua` 更新到 **0.9.3**。首次安装需另装同仓库的 **PsyReaSFX WebView Runtime 0.3.9.30**，然后完全重启 REAPER；无需启用预发布。运行库实际二进制仍是 `0.3.9.30-prs.2`，与 `0.3.9.30-beta3` 的 DLL 和匹配源码哈希相同。Beta 18、旧界面测试版和 0.9.1 等历史正式版保留供回退；其他平台继续使用经典版。

运行库的实机验收状态仍按锁定清单记录；当前 `native_acceptance_pending` 不因发行通道变更而变为已验收。本次固定哈希的稳定发行基线可通过普通离线安装器安装；发行通道与实机验收是独立记录。自定义候选仍需显式测试选项，现有外部 DLL 默认保留。神经检索仍使用独立可选数据包，Desktop 仍独立发布。

The Windows x64 WebView line is promoted from Beta 18 to **0.9.3 Stable**, retaining its editing, preview, Transfer and background-service fixes. Update the main script normally through ReaPack and install the separate **WebView Runtime 0.3.9.30** package for a first installation, then restart REAPER. No pre-release opt-in is required. The runtime binary remains `0.3.9.30-prs.2`; the pinned stable distribution is installable normally, while native-acceptance diagnostics remain pending and custom candidates still require explicit opt-in. Existing catalogs/caches and legacy rollback versions are retained. Other platforms can continue using the classic edition.
