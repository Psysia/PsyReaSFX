<p align="right">
  <a href="README.md"><img src="https://img.shields.io/badge/Language-English-555555" alt="English"></a>
  <a href="README_zh-CN.md"><img src="https://img.shields.io/badge/Language-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-2f81f7" alt="简体中文"></a>
</p>

<p align="center">
  <img src="assets/brand/psyreasfx-hero.png" alt="PsyReaSFX — Sound Assets Organized" width="100%">
</p>

<p align="center">
  <strong>音效资产井然有序</strong><br>
  浏览 · 整理 · 试听
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-0.7.5--beta.7-19D8FF" alt="版本 0.7.5 beta 7">
  <img src="https://img.shields.io/badge/Host-REAPER-13253D" alt="REAPER">
  <img src="https://img.shields.io/badge/Install-ReaPack-0A1020" alt="ReaPack">
</p>

# PsyReaSFX 0.7.5 Beta 7

PsyReaSFX 是运行在 REAPER 内部的音效资产浏览、波形试听、元数据、Region、集合、插入与 Transfer 工作流。

**作者：** Psysia  
**包版本：** 0.7.5-beta.7  
**发布阶段：** Beta

<p align="center">
  <img src="assets/screenshots/compact-workspace.png" alt="PsyReaSFX 主工作区，展开导航与元数据面板" width="100%">
</p>

## 品牌焕新与来源独立封面

Beta 7 将正式 PsyReaSFX 视觉规范应用到项目，并让 Artwork 的归属与实体来源路径保持一致。

- 逻辑音效库旁的箭头现在是可点击控件，单击即可展开或折叠来源路径，并保存当前状态。
- 默认界面采用品牌规范中的 Deep Navy、Dark Slate、Electric Cyan、Soft White 与 Cool Gray。
- About 页面使用随包安装的 PsyReaSFX 图标，并以极简产品卡展示版本、版权和项目主页。
- 每个实体来源路径拥有独立封面；一个来源找到的封面不会扩散到同一逻辑库的其他来源。
- 右键实体来源路径可以指定、重新自动查找或清除该来源自己的封面。
- 素材单独指定的封面仍然优先于实体来源封面。
- 同时检查常见的 `Artwork`、`Images`、`Docs`、`Documentation` 子目录，以及 library/product/preview 等封面文件名。
- 图片解码失败后使用短暂重试间隔，不再逐帧重复加载。

## 多来源逻辑音效库

Beta 4 允许先建立没有任何路径的空逻辑音效库。点击“新建音效库”，先命名，再按需要逐步添加或拖入来源文件夹；库的组织方式不再由硬盘目录强制决定。

多来源模型将用户浏览的逻辑音效库与实际扫描的文件夹分离。一个逻辑音效库可以聚合位于不同硬盘上的多个来源路径，并在左侧保持为一个可搜索的库。

- 点击逻辑音效库可浏览其全部来源路径的聚合结果。
- 展开后可单独浏览某条来源；悬停可查看路径、在线状态与索引数量。
- 从资源管理器拖文件夹到某个库可直接加入；拖到“全部音效库”会新建库；拖到结果区会沿用当前逻辑库上下文。
- 同时拖入多个文件夹时，可分别建立音效库，或合并为一个逻辑库。
- 扫描前会检查完全重复、父子路径重叠和跨库归属；移动来源归属不会移动硬盘文件。
- 旧版“一条路径一个库”会自动迁移，并保留数据库、元数据、集合与波形缓存。

来源结构保存在 `libraries_v2.tsv`。播放列表和项目素材箱继续作为虚拟集合，与音效库的路径归属明确分离。

## 时长显示与大型库性能

- Duration 列统一使用 `MM:SS.mmm` 时间码，例如 `00:04.947`。
- 目录扫描改为索引队列，不再反复搬动尚未扫描的目录列表。
- 新素材直接继承当前来源路径，不再逐个遍历全部已配置根目录。
- 结果列表和库数量只在扫描/导入边界集中刷新，不再每发现一个文件就重建。
- 一次拖入多个来源文件夹时，只重建一次逻辑库映射。

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

## 系统元数据过滤

Beta 2 不再索引 macOS AppleDouble `._*` 旁车文件，以及 `__MACOSX`、`.AppleDouble`、`@eaDir` 等常见系统元数据目录。这些文件可能保留 `.wav` 扩展名，但内部不是可播放音频。新版启动时会自动忽略旧索引中的错误条目，不会删除任何硬盘源文件。

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

在 REAPER 动作列表中加载 `PsyReaSFX_v0_7_5_Beta_7.lua`。

## 文档

- [用户使用说明书](docs/USER_GUIDE_zh-CN.md)
- [更新日志](docs/CHANGELOG_zh-CN.md)
- [English User Guide](docs/USER_GUIDE_en-US.md)
- [English Changelog](docs/CHANGELOG_en-US.md)

## 发布包结构

```text
PsyReaSFX_v0_7_5_Beta_7.lua
README.md
README_zh-CN.md
index.xml
assets/brand/
assets/screenshots/
docs/
```

在 0.7 Transfer 完成不同 REAPER、ReaImGui、SWS、音频格式与工程配置的测试前，0.6 Stable 仍可作为稳定回退版本。

