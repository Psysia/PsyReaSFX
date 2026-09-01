# PsyReaSFX 0.8 架构边界

本文件记录稳定化期间建立的内部边界。它们不改变用户功能和数据格式，目的是让后续修复可以在小范围内验证和回退。

## Desktop

| 边界 | 接口 | 当前实现 | 职责 |
|---|---|---|---|
| Storage | `IStorageService` | `StateStore` | SQLite 快照、工作区、活动、Region、响度和工程使用记录 |
| Catalog | `ICatalogIndexer` | `LibraryIndexer` + `CatalogViewModel` | 从稳定来源快照构建素材目录，并统一持有可替换的 WPF 目录视图 |
| Jobs | `IJobCoordinator` | `BackgroundJobCoordinator` | generation、取消、资源互斥和退出收敛 |
| PathIdentity | `IPathIdentityService` | `PathIdentityService` | 路径规范化、来源实体识别和相对路径 |
| Preview | `IPreviewController` / `IPreviewEngine` | `PreviewController` + `LowLatencyPreviewEngine` | 控制器拥有替换、取消和失败生命周期；引擎只拥有设备与 DSP 资源 |
| Transfer | `ITransferService` | `TransferEngine` | 独立输出、批量变体和任务报告 |
| Artwork | `IArtworkService` | `ArtworkService` | 封面查找、来源封面应用和回退 |
| Organization | `IOrganizationService` | `OrganizationService` | 集合成员去重、增删和保存搜索快照构造 |
| UI state | `WindowStateController` | `WindowStateController` | 左右栏、专注模式和栏宽记忆；不直接持有控件 |

`MainWindow` 只通过以上接口调用后台能力。目录集合的替换、筛选刷新和排序入口已迁入 `CatalogViewModel`。窗口状态的计算已迁入独立控制器，WPF 层只渲染返回状态。封面选择规则和素材封面批量应用也已从窗口中移出。

## 约束

- 后台服务不能直接枚举或修改正在显示的 WPF 集合。
- 存储层只接受调用时冻结的快照。
- 预览和目录写任务必须经过统一任务协调器。
- 新增功能不得重新绕过接口直接创建第二套存储、试听或任务生命周期。
- 每次继续拆分前后都运行 Desktop 完整自检和 Lua 解析检查。

## Lua 发布源

Lua 的可维护源已按职责机械拆分到 `src/lua/`，顺序为启动与常量、UI 核心、任务与存储、目录、分析、运行时 UI。`tools/Build-LuaRelease.ps1` 按固定清单合并模块，并统一写入 `@version`，最终仍产出 ReaPack 所需的单个 Lua 文件。

当前历史文件名仍作为兼容发布镜像保留；CI 会重新合并模块并逐字（忽略换行格式）比较，镜像过期时直接失败。待 0.8 发布元数据切换完成后，再把 ReaPack 源地址改为统一的 `PsyReaSFX.lua`，避免在稳定化分支中同时改变源结构和安装地址。

## 后续拆分顺序

1. 将仍在窗口中的搜索语法、筛选条件和目录选择策略继续移入 `CatalogViewModel`。
2. 将仍在窗口中的收藏、集合菜单、保存搜索载入和试听活动继续移入 `OrganizationService`。
3. 将剩余的播放按钮文案与进度显示编排逐步移出窗口；试听替换、取消和管线重建已经由 `PreviewController` 统一管理。
4. 将剩余窗口布局与偏好写回移入 `WindowStateController`。
5. 集中尚未进入 `UiLocalization` 的中英文运行时文本。

这些步骤必须按行为等价重构处理，不夹带新功能。
