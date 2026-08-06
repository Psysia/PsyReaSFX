# PsyReaSFX Desktop 0.7.23 Alpha 1

桌面版现在与 Lua Stable 统一使用 `0.7.23` 产品基线。Alpha 1 已经用正式的
SQLite 大库目录和 Lua 只读兼容迁移层，替换此前独立的 0.1 原型数据模型。

## Alpha 1 已实现

- 面向大型素材库的 SQLite/WAL 目录和全文索引底座。
- 自动查找现有 PsyReaSFX Lua 数据目录。
- 一次性迁移逻辑库、实体路径、全部 27 个素材字段、集合、保存搜索、试听历史、
  上次浏览状态、Region、响度分析和设置。
- 现有桌面浏览、搜索、波形、Artwork、收藏和文件拖放已接入新目录。
- 启动时直接打开已有目录，不再自动强制重扫所有硬盘路径。

迁移过程不会写入或修改 Lua 文件。桌面目录保存于：
`%LOCALAPPDATA%\PsyReaSFX\catalog-v1.sqlite3`。

Alpha 1 是完整移植的基础版本，还不是功能完全对齐的桌面稳定版。高级试听、
多声道控制、Region、元数据编辑、集合界面、Transfer 和可选 REAPER Bridge
会在后续 `0.7.23 Desktop Alpha` 构建中继续迁移。
