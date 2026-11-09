# PsyReaSFX 0.9.a WebView Beta 2

ReaPack 版本号为 `0.9.3-beta2`，面向 Windows x64。

## 前置组件安装引导

- 启动时缺少 ReaWebAPI，或已安装版本缺少所需接口，会弹出安装提示。
- 点击“是”后，直接打开 ReaPack 软件包浏览器并搜索 `PsyReaSFX WebView Runtime`。
- 提示中说明启用预发布、同步软件包，以及安装后重启 REAPER。
- 未安装 ReaPack，或打开 ReaPack 失败时，可跳转到项目发布页下载完整测试版安装包。
- 点击“否”会结束本次启动。软件包安装由用户在 ReaPack 中确认。

更新 `PsyReaSFX.lua` 即可获得新引导。运行时组件继续使用 `0.3.9.30-beta1`。ReaPack Versions 提供旧界面 `0.9.2-beta4` 和稳定版 `0.9.1`。

此版仍属于早期界面迁移测试。已完成的原生测试和待迁移功能见 [Beta 1 验证范围](release-notes-webview-0.9.3-beta1.md)。

## English

Add a startup prerequisite dialog. Accepting opens ReaPack with `PsyReaSFX WebView Runtime` already searched. The message explains pre-release visibility and restarting REAPER. If ReaPack is unavailable or fails to open, the dialog offers the project's release downloads. Declining exits the launch. Users confirm package installation in ReaPack.

The independently versioned runtime remains `0.3.9.30-beta1`. This release continues the early Windows x64 interface migration beta.
