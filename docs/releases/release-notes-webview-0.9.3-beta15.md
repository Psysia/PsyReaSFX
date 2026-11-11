# PsyReaSFX 0.9.3 Beta 15

针对从 REAPER 停靠切回浮动窗口时的卡死／闪退，更新运行库至 `0.3.9.30-prs.2`：结构切换期间恢复宿主重绘控制，并延后 WebView2 布局、图标和焦点处理。关闭停靠窗口使用相同保护。

更新 ReaPack 中 **PsyReaSFX WebView Runtime 0.3.9.30-beta3** 后，必须完全退出并重启 REAPER。应用脚本更新本身不会替换进程中已加载的 DLL。

验证包含共享 Docker 的重绘／销毁回归、运行时入口检查及测试进程中的真实 WebView2 往返切换。用户这次崩溃未留下完整转储，原生 REAPER 实机验收仍待确认。详见 [排查与验收说明](https://github.com/Psysia/PsyReaSFX/blob/v0.9.3-beta15/docs/WEBVIEW_UNDOCK_BETA15_zh-CN.md)。
