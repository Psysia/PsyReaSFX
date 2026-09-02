# PsyReaSFX 0.8 稳定化基线

记录日期：2026-08-31
分支：`hardening/0.8`

## 冻结范围

在 0.8 RC1 前停止新增用户功能。当前行为基线以以下三个已发布包、现有 Lua/Desktop 功能对照文档和 Desktop 完整自检为准：

| 基线 | 文件 | SHA-256 |
|---|---|---|
| Lua Stable | `PsyReaSFX_v0_7_23_Stable.zip` | `F4478B3F4E529F848EB717CC9EFA9E556C6D33D70E18DF25559B184F981CD2EA` |
| Lua 0.8 Beta 3 | `PsyReaSFX_v0_8_0_Beta_3.zip` | `27932CAB800751665127559DF924CE83E44008F0809CBA32BAD3221E26EF771B` |
| Desktop Alpha 8 Light RC1 | `PsyReaSFX_Desktop_v0_7_23_Alpha_8_Light_RC1.zip` | `21F3476D88356418FE20E3F5FB7D65A688C3E43DCFB086C4E9D4EF49E7812A71` |

功能基线文档：

- `desktop/FEATURE_PARITY_0_7_23.md`
- `desktop/FEATURE_PARITY_0_7_23_zh-CN.md`
- `docs/DESKTOP_ALPHA_zh-CN.md`
- `docs/CHANGELOG_zh-CN.md`
- `docs/CODE_REVIEW_2026-08-31_zh-CN.md`

## 可重复测试素材库

`tools/generate_hardening_library.py` 可以从空目录确定性生成 1 到 250,000 条 WAV，包含：

- 多层目录和独立 `2. Artwork` 封面目录；
- 方形 PNG 封面；
- 可配置的完整重复文件对；
- 可配置的四声道文件；
- 离线来源路径参考和 JSON 清单。

推荐固定规模：

```text
5,000：日常 PR 基准
50,000：RC 性能门槛
200,000：容量与长时间压力测试
```

生成器拒绝默认写入非空目录，所有夹具都只能放在一次性测试位置。

## 5,000 条 Desktop 初始性能基线

机器：16 个逻辑处理器，Windows 10.0.19045，.NET 8.0.29。

| 项目 | 结果 |
|---|---:|
| 索引 | 1,344.20 ms |
| SQLite 保存 | 2,013.02 ms |
| SQLite 加载 | 51.17 ms |
| 内存增量 | 12,224,296 bytes |
| 索引/保存/加载数量 | 5,000 / 5,000 / 5,000 |
| 读取失败 | 0 |

原始报告保存在本地测试产物 `hardening-baseline-5k.json`。该产物不进入发布包。

## 当前自动门槛

每个 PR 与 `main` 推送必须通过：

1. Lua 5.3 完整语法解析；
2. 由固定 SHA-256 的临时 Lua 运行时执行持久化故障注入与成组恢复回滚测试；
3. 用真实文件执行 Lua 分块完整内容比较测试；
4. Desktop Release 构建（零警告、零错误）；
5. NuGet 已知漏洞审计；
6. Desktop 完整自检；
7. 一次性素材库生成与无界面索引/保存/加载基准。

Desktop 自检已经覆盖数据库迁移、未来版本拒写、带 schema 的 Lua 导入（包括
database schema 3 的附加指纹列）、组织数据往返、Region、试听声道、Transfer、
备份恢复、缓存路径和关键 UI 交互。

组织数据往返使用一次性 SQLite 目录，明确覆盖收藏、试听次数与最后试听时间、
播放列表及条目、保存搜索、会话高亮、Region 新增/删除、响度记录和 REAPER
工程使用记录；断言均基于关闭写事务后重新读取的值。

Lua 持久化自检会在一次性目录中验证：写入失败时旧文件不变、备份后提交失败时自动恢复、不完整备份被拒绝、两文件恢复在第一项提交或事务标记写入失败时整体回滚，以及启动时分别处理未提交与已提交恢复留下的事务文件。CI 还会用独立 Windows 文件句柄锁住旧文件，验证真实外部占用无法替换且不会损坏旧数据。重复检查自检使用真实文件验证分块逐字节比较、指纹算法版本、大小/修改时间失效和可选文件状态 API 缺失时的保守降级。测试目录与临时 Lua 运行时均不进入发布包。

Lua schema 自检还会验证 database `0→1→2→3` 的显式逐级路径、v2 可读、
当前版本写出 v3，以及未来 v4 必须触发只读保护。迁移注册表缺少任一相邻步骤
时会在创建或写入新数据前停止，不允许直接跨版本跳写。

## Lua / Desktop 数据所有权

- Lua 只读写 REAPER 资源目录中的 TSV 与缓存。
- Desktop 只读写自己的 `catalog-v1.sqlite3`、桌面设置与桌面缓存。
- Desktop 对 Lua 数据仅执行一次性、只读导入；导入完成后以迁移键锁定，绝不回写 Lua TSV。
- 两端之间的后续协作只能通过显式 Bridge/导入流程完成，不能把同一文件设为双写源。

## 尚需真实环境确认

自动基线不能替代 REAPER。进入 RC1 前仍需在真实 REAPER/SWS/ReaImGui 环境完成：

- Lua 0.7.23 与 0.8 数据迁移数量对照；
- 扫描中断、磁盘满、无权限和文件占用故障；
- 50,000/200,000 条库的滚动、试听、退出和恢复；
- 不同 DPI、离线盘、映射盘、UNC、多声道与无 FFmpeg 环境；
- 连续两小时快速试听和后台任务压力测试。
