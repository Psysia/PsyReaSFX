# PsyReaSFX 0.9.3 Beta 12

列表小波形恢复“点哪播哪”；统一工作区与试听区域的明度，默认使用石墨蓝。官网同步新版界面、安装步骤与下载通道。

- 修复选择素材后列表重建导致点击坐标失效；双击波形不再触发整行从头播放。Ctrl/Shift 点击仍用于多选，悬停显示对应时间。
- 取消已过期的点击试听：后续选择、停止、切换标签或搜索不会被较迟的选择响应覆盖。
- 七套主题统一搜索框、列表、菜单和波形；纸灰/雾蓝降低亮度；深海青的行线、暮色紫的圆角页签、纸白墨绿的细线排版和雾白蓝的轻浮工具栏各有区分。保留已有自定义颜色。
- 关于页加入品牌 Logo。官网使用用户提供的 Beta 11 实机截图，旧原生演示明确标注，稳定版与 WebView 下载分别更新。

安装：ReaPack 同步后，为 `PsyReaSFX.lua` 启用预发布，选择 `0.9.3-beta12`，并安装 `PsyReaSFX WebView Runtime`。关闭旧 PRS 窗口后运行公共动作；新装原生扩展时重启 REAPER。也可使用本页完整 ZIP。

验证：浏览器覆盖 15%/55%/85% 点击定位、双击、多选、延迟响应后的停止、主题和 Logo；官网覆盖中英文桌面/手机布局及独立下载通道。包安装、回滚、ReaPack 与 Lua 宿主回归单独验证。没有启动额外 REAPER 或插件扫描，真实音频起播位置仍需实机听音确认。

完整功能与设置：[验收清单](../WEBVIEW_ACCEPTANCE_0_9_3_zh-CN.md)。

English: fixes click-position audition in virtualized waveform rows, cancels stale click continuations, makes graphite blue the default, adds coordinated dark/soft-light palettes and a branded About card, and refreshes the bilingual website with separate Stable and WebView downloads. Native audio audition remains a manual acceptance step.
