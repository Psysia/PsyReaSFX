<p align="center">
  <img src="assets/brand/psyreasfx-hero.png" alt="PsyReaSFX — Sound Assets Organized" width="100%">
</p>

<p align="center">
  <strong>Browse · Organize · Preview · Deliver</strong><br>
  A high-performance sound-asset workspace built inside REAPER.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-0.7.23--beta.27-19D8FF" alt="Version 0.7.23 beta 27">
  <img src="https://img.shields.io/badge/Host-REAPER-13253D" alt="REAPER">
  <img src="https://img.shields.io/badge/UI-ReaImGui-0A1020" alt="ReaImGui">
  <img src="https://img.shields.io/badge/Install-ReaPack-1F6FCC" alt="ReaPack">
</p>

<details>
<summary><strong>简体中文概览（点击展开，不离开当前页面）</strong></summary>

### PsyReaSFX 是什么？

PsyReaSFX 是运行在 REAPER 内部的音效资产工作区，将素材库、波形浏览、搜索、试听、元数据、集合整理、工程插入与处理后导出集中到一个可停靠界面中。

它适合需要长期管理大型音效库的游戏音频设计师、声音设计师和 REAPER 用户：一个逻辑音效库可以聚合多个硬盘路径；列表内直接显示波形；点击波形任意位置即可试听；素材选区能够直接拖入工程或通过 Transfer 输出为新文件。

### 核心能力

- 多来源逻辑音效库、文件夹拖放导入与 Watch Folder。
- 高密度内联波形、立体声/多声道大波形和点击定位试听。
- 文件名、描述、关键词、UCS 字段、状态和库的联合搜索。
- Artwork、非破坏性元数据、收藏、播放列表、项目素材箱与工作流状态。
- Region、瞬态建议、LUFS/True Peak 显示、Pitch/Rate/Gain 与声道监听。
- 插入当前轨、新轨、BWF 位置，以及选区拖入 REAPER。
- Transfer 路径、命名模板、格式、采样率、声道、淡化、标准化和冲突策略。

### 安装

在 REAPER 中打开 `Extensions → ReaPack → Import repositories...`，导入：

```text
https://github.com/Psysia/PsyReaSFX/raw/main/index.xml
```

同步仓库后搜索并安装 `PsyReaSFX`。完整说明请阅读[中文用户手册](docs/USER_GUIDE_zh-CN.md)，版本变化请查看[中文更新日志](docs/CHANGELOG_zh-CN.md)。

</details>

## One workspace for the sound-library loop

PsyReaSFX turns REAPER into a focused sound-asset environment without
replacing the project workflow you already use. Search a library, audition at
the waveform, organize candidates, place a selection on the timeline, or
render a processed copy—all from one dockable interface.

It is designed for large personal and production libraries where folder paths,
metadata and project choices must remain understandable over time.

## The workflow

| Discover | Organize |
|---|---|
| Browse inline waveforms, search filenames and metadata, filter by library or workflow state, and audition from any point in a result waveform. | Group multiple source folders under one logical library, maintain Artwork and metadata, and collect sounds into playlists or project bins. |

| Audition | Deliver |
|---|---|
| Inspect high-resolution channel lanes, make a selection, loop or scrub it, change Pitch/Rate/Gain, compare loudness and save useful regions. | Insert files or selections into REAPER, use BWF placement, drag from the browser, or create processed files through Transfer. |

## Workspace

<p align="center">
  <img src="assets/screenshots/compact-workspace.png" alt="PsyReaSFX workspace with navigation and metadata panels" width="100%">
</p>

The workspace is intentionally modular:

- **Navigation** holds logical libraries, source folders, favorites,
  indexed folder hierarchy, collections, saved searches and workflow filters.
- **Results** keeps a pinned, configurable column header with inline waveform,
  metadata, Artwork and duration fields.
- **Inspector** provides pinned Artwork and non-destructive metadata editing.
- **Preview** shows accurate channel lanes, time selection, loudness, regions,
  audition controls and REAPER delivery actions.

The left and right panels can be hidden independently. Focus mode leaves only
the result list and preview area. Navigation groups can also be collapsed
individually, and their open/closed state is restored on the next launch.

<p align="center">
  <img src="assets/screenshots/focus-workspace.png" alt="PsyReaSFX focus mode" width="100%">
</p>

## See it in action

### Build one library from multiple source folders

Create a logical library first, expand it in place, and attach independent
source folders over time. Each source retains its own path, online state and
Artwork assignment.

<p align="center">
  <img src="assets/screenshots/logical-library-workflow.gif" alt="Expanding a logical library with multiple source folders" width="760">
</p>

### Select on the waveform and deliver to REAPER

Drag across the detailed waveform to define a precise range, audition the
selection, then drag that range directly into the REAPER arrange view.

<p align="center">
  <img src="assets/screenshots/waveform-edit-drag-reaper.gif" alt="Creating a waveform selection and dragging it into REAPER" width="100%">
</p>

## Core capabilities

### Libraries that match real storage

A logical library is not tied to one folder. Create the library first, then
attach source folders from different drives or locations. Each source keeps
its own path, online state and Artwork. Drag folders from Windows Explorer onto
a library, All Libraries, or the central drop target to choose the intended
relationship.

### Indexed folder hierarchy

Hover the borderless folder-search icon beside the search field to open a
native cascading browser: `logical library → physical source → indexed
subfolder`. Move sideways through the menus and click any level to show the
audio in that folder and all descendants. The browser closes immediately and
leaves only a compact, removable `Pathname` condition above the results.

The hierarchy is generated from the existing asset index in small background
batches. Hover navigation never rescans the drive, never reserves permanent
workspace height, and intentionally omits directories with no indexed audio.

### Search that stays close to the material

Plain text searches filenames, paths, descriptions, keywords, categories,
library names and UCS-derived fields. Structured filters such as
`category:impact`, `library:boom`, `status:candidate`, `marked:true` and
negative terms narrow results without changing the underlying library.

### Waveform-first audition

Every visible result can show a cached waveform. Click inside it to start from
that position. The detailed preview supports separate mono, stereo and
multichannel lanes, zoom, pan, scrub, selections, loops, regions and direct
selection drag into the REAPER arrange view.

### Organization without touching source files

Favorites, marks, workflow states, playlists, project bins, saved searches and
metadata edits live in the PsyReaSFX database. Source audio remains unchanged
unless you explicitly use a Transfer operation that writes a new output file.

### Transfer and REAPER delivery

Transfer can export the full file or current waveform selection using an
output directory, naming template, explicit WAV 16/24/32-bit PCM or FLAC,
sample rate, channel mode, fades, Peak/True Peak/RMS-I/LUFS-I normalization
and collision policy. Source metadata can be preserved where REAPER and the
target container support it; 16-bit WAV output offers optional dither and
noise shaping.

Batch Variants turn comma-separated Pitch, Rate and Gain lists into a bounded
set of normal/reverse deliverables. Variant-aware naming tokens keep outputs
distinct, while per-file progress, stop-after-current, a TSV task report and
safe temporary-file replacement make large jobs inspectable and recoverable.
Finished files can optionally be inserted into the current REAPER project.
The output folder can also open automatically after a successful job. Output,
latest-result and report-folder actions use one Unicode-safe system opener.

For selections that end before the source file does, optional **Smart source
tail** scans the remaining source audio for the last event above a configurable
threshold, then preserves a bounded hold period. This retains source-recorded
reverb and delay tails without adding the same fixed duration to every export.

<p align="center">
  <img src="assets/screenshots/transfer-settings-en.png" alt="Privacy-safe PsyReaSFX Transfer settings" width="860">
</p>

## Quick start

### Requirements

- REAPER 7.x
- ReaImGui 0.10 or newer
- SWS Extension strongly recommended for precise seeking, channel audition and
  arrange-view drag placement

### Install with ReaPack

1. Open `Extensions → ReaPack → Import repositories...`.
2. Paste this repository URL:

   ```text
   https://github.com/Psysia/PsyReaSFX/raw/main/index.xml
   ```

3. Synchronize packages.
4. Search for `PsyReaSFX` and install it.
5. Run the script from REAPER's Action List and assign a shortcut if desired.

ReaPack installs the script, application icon and Orbitron brand font. Future
updates arrive through the same repository URL.

### First library

1. Open the left navigation with `F9` if it is hidden.
2. Choose **New library** and name the logical library.
3. Add one or more source folders, or drag folders from Windows Explorer onto
   the library.
4. Allow the import progress task to finish.
5. Click a waveform in the result list to audition it.

## Performance model

PsyReaSFX avoids loading an entire library into the interface at once. Scans,
folder-hierarchy construction, metadata work, waveform construction and Artwork
discovery are divided into small tasks. Only visible result rows and the
selected file receive immediate high-priority work. Waveforms are cached on
disk and can be precached from Settings for predictable browsing on very large
libraries.

Artwork discovery supports both covers beside WAV files and commercial-library
layouts such as `1. Audio / 2. Artwork`. Numbered Artwork, Cover, Image and
Thumbnail folders are searched with strict depth and folder budgets. Each
physical source retains its own result, so one source never silently supplies
the cover for another source in the same logical library.

When several images are available, PsyReaSFX reads only their lightweight
headers and prefers a near-square cover before applying filename and resolution
tie-breakers. Missing covers leave the Artwork result cell empty; the larger
inspector retains its neutral empty-state illustration.

## Documentation

- [User Guide — English](docs/USER_GUIDE_en-US.md)
- [用户使用说明书 — 简体中文](docs/USER_GUIDE_zh-CN.md)
- [Changelog — English](docs/CHANGELOG_en-US.md)
- [更新日志 — 简体中文](docs/CHANGELOG_zh-CN.md)
- [Standalone Chinese project page](README_zh-CN.md)

## Release status

`0.7.23 Beta 27` replaces the persistent tree with icon-driven cascading folder
navigation and continues the
compatibility and regression phase for the 0.7 browsing, Transfer and delivery
workflows;
`0.6.21` remains the
stable fallback while this testing continues.

## Author and license

PsyReaSFX is created by **Psysia**.  
Copyright © 2026 Psysia. All rights reserved.

The bundled Orbitron font is distributed under the SIL Open Font License 1.1;
its license is included in `assets/fonts/OFL.txt`.

Project home: [github.com/Psysia/PsyReaSFX](https://github.com/Psysia/PsyReaSFX)
