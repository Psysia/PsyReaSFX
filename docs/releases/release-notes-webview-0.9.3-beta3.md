# PsyReaSFX 0.9.a WebView Beta 3

ReaPack 版本号为 `0.9.3-beta3`，面向 Windows x64。

## 修正共享运行时的安装引导

- 优先使用已有 ReaWebAPI。独立测试中，原作者源的 `0.3.9.29` 已通过窗口连接、导入、选择、波形和插入测试。
- 缺少接口时先查询 DLL 的 ReaPack 归属，显示原软件源、软件包和登记版本。
- 已由其他组件管理时，确认后打开原组件页面检查安装和更新。已存在的手动安装 DLL 会收到重启及更新原组件的提示。
- 首次安装且没有发现已有归属或 DLL 时，提供本仓库的 `PsyReaSFX WebView Runtime` 入口。
- 引导中的归属对象会在确认、取消及页面打开失败时释放。

## 已遇到归属冲突时

关闭错误报告，在 ReaPack 中取消本次 `PsyReaSFX WebView Runtime` 的待安装操作，使用原作者组件。更新主脚本到 `0.9.3-beta3` 后运行 PsyReaSFX，应用会检查接口兼容性。安装或更新原组件后重启 REAPER。

`PsyReaSFX WebView Runtime` 是首次安装的可选入口。ReaWebAPI 的共享 DLL 由一个 ReaPack 软件包管理。

新界面完整迁移和更广泛的原生验收继续进行，详情见 [Beta 1 验证范围](release-notes-webview-0.9.3-beta1.md)。

## English

Fix duplicate-runtime installation guidance. Reuse existing ReaWebAPI installations. When native functions are missing, inspect ReaPack file ownership and open the owning package for updates. Prompt for restarting an existing manually installed DLL. Offer the companion runtime package for first-time installation.

The upstream 0.3.9.29 runtime passed isolated native bootstrap, import, selection, waveform and insertion tests. Update the main script to 0.9.3-beta3. Cancel a queued duplicate companion-runtime installation after an ownership conflict.
