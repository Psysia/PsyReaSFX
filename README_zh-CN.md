<p align="right">
  <a href="README.md"><img src="https://img.shields.io/badge/Language-English-555555" alt="English"></a>
  <a href="README_zh-CN.md"><img src="https://img.shields.io/badge/Language-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-2f81f7" alt="简体中文"></a>
</p>

# PsyReaSFX 0.6 Stable

PsyReaSFX 是运行在 REAPER 内部的音效浏览、试听、波形、元数据、Region 与资产管理 ReaScript。

**作者：** Psysia  
**包版本：** 0.6.21  
**发布阶段：** Stable

<p align="center">
  <img src="assets/screenshots/compact-workspace.png" alt="PsyReaSFX 紧凑工作区，展开导航和元数据面板" width="100%">
</p>

## 工作区预览

统一紧凑工作区可在同一个窗口中显示音效库导航、列表内联波形、Artwork、元数据和高精度试听波形。

### 专注模式

<p align="center">
  <img src="assets/screenshots/focus-workspace.png" alt="PsyReaSFX 专注模式，展开结果表和波形预览" width="100%">
</p>

专注模式会折叠左右面板，让结果列表与大波形使用完整 REAPER 工作区。

## 文档

- [用户使用说明书](docs/USER_GUIDE_zh-CN.md)
- [更新日志](docs/CHANGELOG_zh-CN.md)
- [English User Guide](docs/USER_GUIDE_en-US.md)
- [English Changelog](docs/CHANGELOG_en-US.md)

## 使用 ReaPack 安装

在 `Extensions → ReaPack → Import repositories...` 中导入：

```text
https://github.com/Psysia/PsyReaSFX/raw/main/index.xml
```

同步仓库，搜索并安装 `PsyReaSFX`。后续版本可直接通过 ReaPack 同步和更新，无需重新下载 ZIP。

必须安装 ReaImGui；强烈建议安装 SWS Extension。

## 手动安装

在 REAPER 动作列表中加载 `PsyReaSFX_v0_6_21_Stable.lua`。

## 发布包结构

```text
PsyReaSFX_v0_6_21_Stable.lua
README.md
README_zh-CN.md
index.xml
assets/
  screenshots/
    compact-workspace.png
    focus-workspace.png
docs/
  USER_GUIDE_zh-CN.md
  USER_GUIDE_en-US.md
  CHANGELOG_zh-CN.md
  CHANGELOG_en-US.md
```

## 0.6 Stable 重点

- 只维护一套紧凑、扁平、自适应界面，同时保留列、左右面板、专注模式与下方面板高度调整。
- 时间指标和 Pitch、Rate、Gain 使用无外框设计，交互图标保留统一边框。
- 底部时间指标、选区摘要和操作状态统一到同一文字基线。
- 大波形支持单声道、立体声和最多八声道的独立声道显示。
- 结果表不显示横向滚动条，使用 `Shift + 鼠标滚轮`完整查看溢出字段。
- 提供官方 ReaPack 安装与自动更新渠道。
