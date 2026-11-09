# PsyReaSFX 0.9.a WebView Beta 1

ReaPack 版本号为 `0.9.3-beta1`，面向 Windows x64。此版开始测试新的 WebView 界面，沿用 Lua 素材库、扫描、试听、元数据和交付服务。

## 安装

1. 在 ReaPack 管理软件源中启用预发布，然后同步软件包。
2. 将 `PsyReaSFX.lua` 更新到 `0.9.3-beta1`。
3. 安装同仓库的 `PsyReaSFX WebView Runtime`，版本为 `0.3.9.30-beta1`，随后重启 REAPER。
4. 运行原来的 `PsyReaSFX.lua` 动作。界面版本显示 `0.9.3 Beta 1`。

已有其他软件源管理 ReaWebAPI 时，可以使用已有扩展并让应用检查兼容性。同一个共享 DLL 由一个 ReaPack 软件包管理，遇到归属冲突时先核对来源。

手动 ZIP 包提供 `Install-PsyReaSFX-Beta.cmd`，显式选择候选运行时。建议先选择独立的 REAPER 测试资源目录。普通安装器对尚未完成原生验收的运行时设有安装限制。

## 界面与工作流

- 暗色、波形优先的列表，每条音频默认显示小预览波形，可在列设置里关闭。
- 素材序号默认隐藏，列宽和列显示可调整。
- 左右侧栏影响上方浏览区，底部试听波形保持全宽。
- Pitch、Rate 和增益放入默认收起的 FX 面板。
- 提供搜索、选择、UCS、元数据、集合、标签页、AI 设置、基本 Transfer 和插入功能。
- 使用共享前端与宿主协议，为后续 Windows Desktop 容器复用做准备。

## 验证范围

独立 REAPER 7.85 配置中已通过真实窗口创建、前后端握手、音频导入、素材选择、波形读取和媒体插入测试。浏览器测试覆盖模拟 50 万条素材的虚拟列表、侧栏和 FX 展开时的波形宽度、可选列与主题持久化。安装测试覆盖校验、备份、回滚、并发锁与中断恢复。

高级弹窗的完整迁移、磁吸布局、复杂试听和 Transfer 原生验收、大型真实素材库性能、Desktop 可执行程序仍在进行中。此版属于早期界面迁移测试版。

开发环境曾出现原生操作列表与电脑操作辅助进程的 UI Automation 交互异常，停止辅助进程并重启 REAPER 后恢复，唯一根因尚未确认。后续原生验证避免对大型操作列表进行整树无障碍读取。

## 运行时

固定未修改的 ReaWebAPI `0.3.9.30`，DLL SHA-256 为 `1fe73ba0a4363c8cfa9faedaf2166506fa5a3114300eaa2de31d47e1a187130e`。上游更新先生成候选清单，经过回归后再晋升。运行时的许可证、第三方声明和对应源码归档随组件提供。

## 回退

关闭 PsyReaSFX 窗口，在 ReaPack 的 Versions 中选择 `0.9.2-beta4` 可回到旧界面，选择 `0.9.1` 可回到稳定版。需移除运行时时，在 ReaPack 单独卸载 `PsyReaSFX WebView Runtime` 并重启 REAPER。素材库继续由既有持久化服务管理。

## English

Windows x64 WebView beta, published as `0.9.3-beta1`. Enable ReaPack pre-releases, update `PsyReaSFX.lua`, install the companion `PsyReaSFX WebView Runtime` beta `0.3.9.30-beta1`, then restart REAPER and run the existing action. A compatible ReaWebAPI installation can also be used.

Native smoke coverage includes window creation, transport, import, selection, waveform loading and media insertion in an isolated REAPER 7.85 profile. Advanced feature parity and wider native acceptance remain in progress. Versions retains `0.9.2-beta4` for the legacy renderer and `0.9.1` for stable use. Runtime licensing and matching source are included with the companion component.
