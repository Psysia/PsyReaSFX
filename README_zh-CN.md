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

随后执行 `扩展 → ReaPack → 同步软件包`，搜索并安装需要的工具。

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

详细使用方式、边界条件、依赖关系与快捷键建议见 [REAPER 工具手册](docs/REAPER_TOOLS_GUIDE_zh-CN.md)。

## PsyReaSFX

**PsyReaSFX** 是一个可停靠在 REAPER 内部的音效资产工作区，集中提供素材库管理、波形浏览、试听、元数据、集合、搜索、REAPER 插入与处理后交付。

| 通道 | 版本 | 说明 |
|---|---|---|
| 稳定版 | **0.8.5** | 推荐日常使用。 |
| 预发布版 | **0.9.0 Beta 7.3** | 当前预发布线，包含 AI 语义搜索与可选神经相似度支持。 |
| 可选组件 | **PsyReaSFX Neural Similarity** | Windows x64 本地神经相似声音检索组件。 |

未安装神经组件时，PsyReaSFX 仍可使用原有声学相似检索。AI 语义搜索是独立的 API 功能，不会上传用户音频。

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
