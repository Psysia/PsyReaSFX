# PsyReaSFX 0.8 架构边界

本文件记录稳定化期间建立的内部边界。它们不改变用户功能和数据格式，目的是让后续修复可以在小范围内验证和回退。

## Desktop

| 边界 | 接口 | 当前实现 | 职责 |
|---|---|---|---|
| Storage | `IStorageService` | `StateStore` | SQLite 快照、工作区、活动、Region、响度和工程使用记录 |
| Catalog | `ICatalogIndexer` | `LibraryIndexer` + `CatalogViewModel` | 从稳定来源快照构建素材目录，并统一持有可替换的 WPF 目录视图 |
| Jobs | `IJobCoordinator` | `BackgroundJobCoordinator` | generation、取消、资源互斥和退出收敛 |
| PathIdentity | `IPathIdentityService` | `PathIdentityService` | 路径规范化、来源实体识别和相对路径 |
| Preview | `IPreviewController` | `LowLatencyPreviewEngine` | 打开、播放、暂停、参数和声道试听 |
| Transfer | `ITransferService` | `TransferEngine` | 独立输出、批量变体和任务报告 |
| Artwork | `IArtworkService` | `ArtworkService` | 封面查找、来源封面应用和回退 |
| UI state | `WindowStateController` | `WindowStateController` | 左右栏、专注模式和栏宽记忆；不直接持有控件 |

`MainWindow` 只通过以上接口调用后台能力。目录集合的替换、筛选刷新和排序入口已迁入 `CatalogViewModel`。窗口状态的计算已迁入独立控制器，WPF 层只渲染返回状态。封面选择规则和素材封面批量应用也已从窗口中移出。

## 约束

- 后台服务不能直接枚举或修改正在显示的 WPF 集合。
- 存储层只接受调用时冻结的快照。
- 预览和目录写任务必须经过统一任务协调器。
- 新增功能不得重新绕过接口直接创建第二套存储、试听或任务生命周期。
- 每次继续拆分前后都运行 Desktop 完整自检和 Lua 解析检查。

## 后续拆分顺序

1. 将仍在窗口中的搜索语法、筛选条件和目录选择策略继续移入 `CatalogViewModel`。
2. 将收藏、集合、保存搜索和试听活动移入 `OrganizationService`。
3. 将预览 UI 编排从窗口移入更高层 `PreviewController`，底层音频引擎继续实现 `IPreviewController`。
4. 将剩余窗口布局与偏好写回移入 `WindowStateController`。
5. 集中尚未进入 `UiLocalization` 的中英文运行时文本。

这些步骤必须按行为等价重构处理，不夹带新功能。
