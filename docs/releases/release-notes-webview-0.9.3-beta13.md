# PsyReaSFX 0.9.3 Beta 13

全部 Codex 主题正式接入：29 个主题、44 个明暗版本，默认 GitHub 深色。走带与音量居中，任务在左下角；修复选区拖入依赖网页松开事件的问题。

- 设置 → 外观与布局：深色、浅色、跟随系统；保留主题原名及真实背景/前景/强调色，列表和大波形同底色；支持自定义和旧设置迁移。
- 选区拖入：按住按钮拖到 REAPER 编排区，Lua 端检测松开并在对应轨道/时间插入捕获范围；Esc、无效落点、工程切换和过期请求不会误插入。需要 SWS、js_ReaScriptAPI。这是内部编排区插入，原文件拖出仍用 Alt+拖动列表行。
- 官网及用户指南换用已提供的 WebView 实机图；设置截图如实标明 Beta 12 常规页，移除旧版工作区和 Transfer 图片。

安装：ReaPack 同步后为 `PsyReaSFX.lua` 选择 `0.9.3-beta13`，并安装 `PsyReaSFX WebView Runtime`；或下载本页完整 ZIP。先关闭旧 PRS，再重新运行公共动作。

验证：浏览器覆盖 44 套配色、系统模式、保存迁移、900/1000/1600 像素布局与拖动交接；Lua 覆盖无网页松开事件时插入、选区捕获、取消/迟到/重复/切换工程及异常撤销清理。网站覆盖中英文、手机/桌面、新图和下载通道。另验证安装/回滚和 ReaPack。没有使用桌面操作，也未启动额外 REAPER；真实跨窗口拖入及听音结果仍需按[验收清单](../WEBVIEW_ACCEPTANCE_0_9_3_zh-CN.md)确认。

English: all 29 Codex theme families / 44 variants, centered transport, activity at bottom left, native selection-drag release handling with cancellation and undo cleanup, and replacement of legacy PRS screenshots across the site and guides.
