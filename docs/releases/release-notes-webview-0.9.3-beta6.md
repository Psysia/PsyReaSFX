# PsyReaSFX 0.9.a WebView Beta 6

ReaPack 版本 `0.9.3-beta6`，Windows x64。包含 Beta 5 的工作流补齐，并继续完成语言和 UCS 联想入口。

- 已试听素材的文字／波形颜色及开关、恢复／清除高亮、小波形播放位置线。
- 批量元数据、批量收藏、标记、工作流、声道试听、目录和集合管理、保存搜索、UCS 预览、瞬态与响度，以及高级 Transfer 设置。
- 中文／英文界面切换，复用 Lua 翻译表，增加 WebView 词条。素材名称、描述、路径和用户命名保留原文。
- UCS 搜索联想复用原 Lua 规则，最多 8 项，支持鼠标、方向键和 Enter，保留当前搜索范围。

已通过 Lua 回归、浏览器交互与五十万条虚拟列表测试、翻译与素材原文保护测试，以及离线安装／回滚检查。隔离 REAPER 原生验证覆盖真实试听高亮、设置、导入、声道、元数据、4096 点波形、插入和 WAV 导出。

跨窗口鼠标拖放、不同 DPI／多显示器及真实大型库组合操作仍待完整实机验收。已接入不等于这些场景已全部验收，详见[功能对照](https://github.com/Psysia/PsyReaSFX/blob/v0.9.3-beta6/docs/WEBVIEW_PARITY_0_9_3_zh-CN.md)。

ReaPack 同步后更新主脚本，关闭旧 PsyReaSFX 窗口并重新运行。已有兼容的 ReaWebAPI 可以继续使用。
