<p align="right">
  <a href="README.md"><img src="https://img.shields.io/badge/Language-English-555555" alt="English"></a>
  <a href="README_zh-CN.md"><img src="https://img.shields.io/badge/Language-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-2f81f7" alt="简体中文"></a>
</p>

# PsyReaSFX 0.7 Beta 1

PsyReaSFX 是运行在 REAPER 内部的音效资产浏览、波形试听、元数据、Region、集合、插入与 Transfer 工作流。

**作者：** Psysia  
**包版本：** 0.7.0-beta.1  
**发布阶段：** Beta

<p align="center">
  <img src="assets/screenshots/compact-workspace.png" alt="PsyReaSFX 主工作区，展开导航与元数据面板" width="100%">
</p>

## 0.7 Transfer

首个 0.7 版本加入非破坏性的 Transfer 面板，可把当前完整文件、当前波形选区或多个已选素材生成新的音频文件。

- 使用 `{name}`、`{category}`、`{subcategory}`、`{library}`、`{index}`、`{date}`、`{region}` 组合命名。
- 导出 WAV 24-bit PCM 或 FLAC；采样率可跟随源文件或选择 44.1、48、96、192 kHz。
- 保留源声道，或转换为单声道、立体声。
- 写入当前 Pitch、Rate、Gain、Reverse 和 Preserve Pitch 设置。
- 添加渲染淡入淡出，并可使用 Peak、True Peak 或 LUFS-I 标准化。
- 重名时可自动递增、跳过，或经过确认后覆盖。
- 完成后可自动插回 REAPER。

从下方工具条打开 Transfer，或按 `Ctrl+T`。

> Beta 1 使用干声源素材渲染，不经过工程轨道 FX、发送或 Master FX。批量 Transfer 始终使用每个完整源文件；当前素材可使用大波形选区。

## 工作区预览

统一工作区可在同一个自适应窗口中显示音效库导航、列表内联波形、Artwork、元数据和多声道大波形。

### 专注模式

<p align="center">
  <img src="assets/screenshots/focus-workspace.png" alt="PsyReaSFX 专注模式，展开结果表与波形预览" width="100%">
</p>

专注模式会折叠左右面板，让结果列表与大波形使用完整 REAPER 工作区。

## 使用 ReaPack 安装

在 `Extensions → ReaPack → Import repositories...` 中一次性导入：

```text
https://github.com/Psysia/PsyReaSFX/raw/main/index.xml
```

同步仓库，搜索并安装 `PsyReaSFX`。后续可直接通过 ReaPack 更新。

必须安装 ReaImGui。强烈建议安装 SWS Extension；Reverse Transfer 和部分高级试听操作需要 SWS。

## 手动安装

在 REAPER 动作列表中加载 `PsyReaSFX_v0_7_0_Beta_1.lua`。

## 文档

- [用户使用说明书](docs/USER_GUIDE_zh-CN.md)
- [更新日志](docs/CHANGELOG_zh-CN.md)
- [English User Guide](docs/USER_GUIDE_en-US.md)
- [English Changelog](docs/CHANGELOG_en-US.md)

## 发布包结构

```text
PsyReaSFX_v0_7_0_Beta_1.lua
README.md
README_zh-CN.md
index.xml
assets/screenshots/
docs/
```

在 0.7 Transfer 完成不同 REAPER、ReaImGui、SWS、音频格式与工程配置的测试前，0.6 Stable 仍可作为稳定回退版本。
