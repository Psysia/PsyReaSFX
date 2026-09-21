<p align="center">
  <img src="assets/brand/psyreasfx-hero.png" alt="Psysia REAPER Tools" width="100%">
</p>

<h1 align="center">Psysia REAPER 工具集</h1>

<p align="center">
  面向声音设计、轨道整理、渲染、工程管理与音效资产工作流的实用 REAPER 工具集。
</p>

<p align="center">
  <strong>简体中文</strong> · <a href="README.md">English</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/宿主-REAPER-13253D" alt="REAPER">
  <img src="https://img.shields.io/badge/安装-ReaPack-1F6FCC" alt="ReaPack">
  <img src="https://img.shields.io/badge/作者-Psysia-555555" alt="Psysia">
</p>

## 项目简介

这个仓库包含两部分：

- **PsyReaSFX**：运行在 REAPER 内部的完整音效资产工作区。
- **REAPER 实用工具**：面向剪辑、文件夹管理、渲染、显示与工程操作的轻量 ReaScript。

所有轻量工具都可以独立安装，不需要先安装 PsyReaSFX。

## 安装

在 REAPER 中打开 `扩展 → ReaPack → 导入仓库...`，添加：

```text
https://raw.githubusercontent.com/Psysia/PsyReaSFX/main/index.xml
```

随后执行 `扩展 → ReaPack → 同步软件包`，直接搜索需要的工具并安装即可。使用 Beta 7.6 时，先为软件包启用
预发布版本并安装 `PsyReaSFX.lua`；如需 Windows x64 神经相似声音检索，再为同仓库
中的独立可选包 `PsyReaSFX Neural Similarity` 启用预发布并安装。

如需安装 PsyReaSFX 预发布版本，请在 ReaPack 中启用预发布版本。**PsyReaSFX Neural Similarity** 是 Windows x64 下的可选本地神经相似声音组件，不是主程序必需依赖。

## REAPER 实用工具

| 分类 | 工具 | 用途 |
|---|---|---|
| 渲染 | 创建文件夹区域与渲染矩阵 | 根据当前选择建立 Region，并自动配置对应的 Region Render Matrix。 |
| 渲染 | 智能尾音渲染面板 | 配置渲染尾音、静音裁切阈值与安全留白。 |
| 渲染 | 打开渲染窗口并应用自动尾音 | 在打开原生渲染窗口前应用已保存的尾音设置。 |
| 轨道管理 | 按最早素材位置排序轨道 | 文件夹感知排序，完整保留 Folder 子树结构。 |
| 轨道管理 | 从选中轨道创建文件夹并挂载 Pro-L 2 | 将同级轨道或完整 Folder 子树包进新的总线，并挂载 Pro-L 2。 |
| 轨道管理 | 统一轮换选中文件夹折叠状态 | 根据是否存在嵌套，自动使用两状态或四状态折叠逻辑。 |
| 轨道管理 | 根据父级文件夹名重命名选中轨道 | 使用最近一级父文件夹名称给子轨编号命名。 |
| 素材编辑 | 移除选中素材间隙 | 按现有顺序将选中素材首尾相接。 |
| 素材编辑 | 拆分选中素材到新轨道 | 保持时间位置，将选中素材移动到独立新轨道。 |
| 素材编辑 | 原位反转选中素材 | 通过可一次撤销的 Take 流程反转选中素材。 |
| 工程管理 | 打开全部子工程 | 递归打开当前工程引用的全部子工程。 |
| 显示 | 切换 LUFS-M 与频谱图 | 在 LUFS-M 频谱峰值显示与频谱图之间切换。 |
| 显示 | 视频素材轨道名覆盖显示 | 在视频 Item 内显示当前轨道名称并自适应多行排版；修改轨道名后覆盖内容自动更新。 |

详细使用方式、边界条件、依赖关系与快捷键建议见 [REAPER 工具手册](docs/REAPER_TOOLS_GUIDE_zh-CN.md)。

## PsyReaSFX

**PsyReaSFX** 是一个可停靠在 REAPER 内部的音效资产工作区，集中提供素材库管理、波形浏览、试听、元数据、集合、搜索、REAPER 插入与处理后交付。

| 通道 | 版本 | 说明 |
|---|---|---|
| 稳定版 | **0.8.5** | 推荐日常使用。 |
| 预发布版 | **0.9.0 Beta 7.6** | 当前预发布线；显著加速大型素材库的 AI 本地候选召回。 |
| 可选组件 | **PsyReaSFX Neural Similarity** | Windows x64 本地神经相似声音检索组件。 |

未安装神经组件时，PsyReaSFX 仍可使用原有声学相似检索。AI 语义搜索是独立的 API 功能，不会上传用户音频。

### 当前开发状态

- **稳定通道：0.8.5** — 面向日常使用的默认 ReaPack 版本。
- **预发布通道：0.9.0 Beta 7.6** — 通过查询词预编译和两级候选评分加速 AI 本地召回。
- **不会建立转码素材库** — 源音频只在内存中解码、下混并重采样为模型所需的 32 kHz，不会生成转换后的音频副本；持久缓存只保存紧凑的 320 维 FP16 embedding 和 HNSW 索引。

0.9 预发布始终保留当前 15 维声学特征检索作为无需额外组件的基础模式。神经相似度组件保持可选、仅在本地运行，不上传用户音频。

Beta 7.6 包含独立的 **AI 语义搜索**。它与“查找相似声音”完全分离：顶部搜索框按 `Enter` 执行普通搜索，点击金色 AI 按钮则直接按当前文字执行语义搜索。本地召回会预编译扩展词，先用合并文本快速粗筛，再只对命中素材做字段加权评分，显著缩短大型素材库的等待时间。DeepSeek 结构化请求会关闭思考模式、兼容外层包裹 JSON，并对偶发空响应自动重试一次。音频和完整文件路径不会上传；API 只会收到查询，以及本地召回出的最多 120 条候选文本元数据。

> **ReaPack 安装方式：** 安装 `PsyReaSFX.lua` 即可使用主程序；Windows x64 用户如需神经检索，再从同一仓库安装第二个包 `PsyReaSFX Neural Similarity`。两个包都由 ReaPack 独立更新，手动 ZIP 仅作为备用方案。

### 主要能力

- 一个逻辑音效库可聚合多个实体来源文件夹。
- 列表内联波形，以及单声道、立体声和多声道详细预览。
- 联合搜索文件名、路径、元数据、UCS 字段、音效库和工作流状态。
- 独立 AI 语义搜索入口：支持 DeepSeek、OpenAI 与 OpenAI-compatible API，先在本地召回候选，再按声音描述进行语义重排。
- 使用包络、起音、动态与频谱特征进行可解释的音频内容相似检索。
- 收藏、播放列表、项目素材箱、工作流状态与非破坏性元数据。
- Region、瞬态建议、LUFS / True Peak、Pitch / Rate / Gain 与声道监听。
- 插入当前轨、新轨、BWF 位置，以及把波形选区直接拖入 REAPER。
- Transfer 支持命名模板、格式转换、采样率与声道设置、淡化、标准化和重名策略。

### PsyReaSFX 下载

- [PsyReaSFX 最新稳定版](https://github.com/Psysia/PsyReaSFX/releases/latest)
- [PsyReaSFX 0.9.0 Beta 7.6 预发布](https://github.com/Psysia/PsyReaSFX/releases/tag/v0.9.0-beta7.6)
- [Beta 7.6 可选神经组件手动 ZIP 备用下载](https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0-beta7.6/PsyReaSFX_Neural_Similarity_v0_9_0_beta7_6_win_x64.zip)
- [PsyReaSFX 0.7.23 Stable 历史版本](https://github.com/Psysia/PsyReaSFX/releases/tag/v0.7.23)
- [全部 Releases](https://github.com/Psysia/PsyReaSFX/releases)
- [Desktop 项目说明](desktop/README.md)

[版本发布](https://github.com/Psysia/PsyReaSFX/releases) · [用户手册](docs/USER_GUIDE_zh-CN.md) · [更新日志](docs/CHANGELOG_zh-CN.md)

## 文档

| 文档 | 内容 |
|---|---|
| [REAPER 工具手册](docs/REAPER_TOOLS_GUIDE_zh-CN.md) | 轻量脚本的安装、功能与使用方式。 |
| [PsyReaSFX 用户手册](docs/USER_GUIDE_zh-CN.md) | 主程序工作流与功能说明。 |
| [PsyReaSFX 更新日志](docs/CHANGELOG_zh-CN.md) | 版本历史与更新内容。 |
| [0.9 → 1.0 开发路线](docs/ROADMAP_0_9_TO_1_0_zh-CN.md) | 版本演进与开发计划。 |
| [相似声音架构](docs/SIMILARITY_ARCHITECTURE_0_9_zh-CN.md) | 0.9 相似声音系统设计。 |
| [神经音频相似度架构](docs/NEURAL_SIMILARITY_ARCHITECTURE_0_9_zh-CN.md) | 本地神经检索架构。 |
| [AI 语义搜索架构](docs/AI_SEMANTIC_SEARCH_ARCHITECTURE_0_9_zh-CN.md) | API 语义搜索架构。 |

其余开发、性能与技术归档统一保存在 `docs/`，不再堆叠在项目首页。

## 仓库结构

```text
Scripts/Psysia/   REAPER 实用脚本
docs/             使用手册、更新日志与技术文档
assets/           图片、字体、截图与随附数据
neural/           可选神经相似度组件
desktop/          Desktop 开发文件
website/          项目网站
index.xml         ReaPack 仓库索引
```

## 许可

作者：**Psysia**

Copyright © 2026 Psysia. All rights reserved.

仓库许可详情见 [LICENSE](LICENSE)，第三方资源继续遵循各自许可。
