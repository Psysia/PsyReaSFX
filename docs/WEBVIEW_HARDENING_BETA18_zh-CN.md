# PsyReaSFX Beta 18：交互、数据与后台任务加固

日期：2026-11-13。范围：WebView 前端、Lua 素材服务、Desktop Transfer／Bridge／恢复服务、神经组件解码路径。所有本机验证在后台或隔离的模拟宿主内完成，未启动 REAPER。

## 交付版本

| 部分 | 新版本 | 更新方式 |
|---|---|---|
| WebView | 0.9.3-beta18 | ReaPack 启用预发布后更新主程序，或使用完整离线 ZIP |
| 神经数据包 | 0.9.1-beta1；sidecar 0.5.2 | 同一仓库的独立可选数据包，或 Beta18 Release 内完整神经 ZIP |
| Desktop | 0.7.23 Alpha 8 Light RC2 | 独立 Windows x64 ZIP，仍需 .NET 8 Desktop Runtime |

运行库继续使用 ReaWebAPI `0.3.9.30-prs.2`，ReaPack 显示 `0.3.9.30-beta3`。本轮无需再次安装 DLL。正式主程序 `0.9.1`、神经组件 `0.9.0` 与历史回退版本继续保留。旧 ReaImGui 生成脚本保持独立的 `0.9.2-beta4` 版本号。

## 已复现并修复的问题

| 触发条件 | 原有结果 | 修复后的行为与验证 |
|---|---|---|
| 输入元数据、提交保存，等待响应时继续输入 | 较新的草稿可能被较早的保存结果清空 | 只确认本次提交的值；下一次保存以已提交值作为原值；浏览器延迟响应回归 |
| 保存 A 时切换到 B，或旧编辑器继续收到事件 | A 的保存或旧 DOM 事件可能影响 B 的草稿 | 草稿、保存状态与事件绑定素材／批量选择身份；切换、返回与脱离 DOM 回归 |
| 同时切换素材和批量选择，或完成批量保存 | 重复构造编辑器并生成多个快照 | 每次状态更新合并详情和列表刷新，保存后只重建一次；浏览器验证有效 token 和请求数 |
| 拖动 FX 后马上复位，或发送中再次复位 | 延迟输入重新覆盖复位结果 | 参数提交串行；等待中的新值合并；复位移除同字段待发送值；未完成请求不回写旧显示 |
| 打开 Region 菜单后切换素材／修改 Region 列表 | 旧操作可能作用于新的素材或序号 | 同时验证素材路径、整数序号、起止时间与名称；保存／清除带捕获路径与范围 |
| SECTION 试听时更换当前选择、反向或暂停后恢复 | 可能改播新素材或丢失实际播放区间 | 从正在播放的素材、时间映射与进度恢复；Lua seek 与宿主回归 |
| 请求排队时关闭窗口；宿主发送失败后恢复 | 已关闭连接仍发送；新响应越过旧消息 | 关闭幂等、发送前复核请求；outbox 保持 FIFO；保留 Stop／Cancel 请求槽 |
| 大字段使单页达到宿主字节预算 | 返回行数不足，视口可能出现空缺 | 有界请求剩余行；旧 revision 或跨分片 revision 不一致时拒绝页面 |
| 导出命名与当前／另一素材路径重合 | 可能覆盖来源音频 | 捕获 catalog 路径集合，规范路径后在命名和提交两处检查；覆盖与别名回归 |
| 导出时改动 UI 设置／命名／素材对象；取消或编码器失败 | 批次混用新设置、破坏已有输出或遗留子进程 | 捕获批次设置及素材路径／命名字段，先 staging 后提交；保留旧输出；杀死并等待本任务编码器进程树 |
| FFmpeg 大量 stderr 输出、损坏 PCM 或用户取消 | 管道可能互相等待，解码取消迟缓 | stdout／stderr 并行读取，stderr 有界，识别读取任务故障；逐块取消；异常后清理所有任务 |
| 损坏／未来 schema／锁定数据库恢复；快速连续备份 | 恢复可能混合数据库与 WAL，备份名可能冲突 | 独立 staging、完整性与 schema 检查、WAL checkpoint、保持文件保护直到替换；保留最新 rollback；唯一备份名 |
| 运行自测／benchmark | 可能读取本机恢复标记、偏好或真实缓存 | 测试入口先隔离日志、偏好和波形缓存，显式关闭测试进程 |
| 畸形 JSON、重复 key、非有限数、过量宿主请求 | 解析／参数边界较松，可能进入变更分支 | JSON 深度／字节／数字／Unicode／重复 key 校验；RPC envelope 和参数形状校验；变体数值拒绝 NaN／Infinity |

Beta17 的行为继续保留：普通浏览、试听只读取响度缓存，只有主动点击 **↻** 或重新分析才调用 REAPER 原生精确响度分析。

## 性能证据

批量元数据原实现逐字节计算 32 位摘要 token；它不能无碰撞地确认原值，也会重复扫描长描述。新实现保存选中素材和字段值引用，并在提交时比较身份与完整值。

| 合成场景 | 原实现 | 新实现 |
|---|---:|---:|
| 25,000 个素材、每条共享 8 KiB 描述，生成批量快照 | 1.771 秒 CPU 时间 | 0.015 秒 CPU 时间 |
| 同场景验证快照 | — | 0.015 秒 CPU 时间 |
| 同场景快照额外内存 | — | 约 2,057 KiB |

这是隔离合成数据的函数测量，不能当作整体界面速度或真实磁盘性能承诺。

Desktop 容量测试：25,000 条合成记录，保存约 7.80 秒，载入约 185 ms，检索约 1.73 ms，SQLite 完整性 `ok`。1,000 条生成 WAV 的真实索引测试约 1.05 秒；无变化保存约 18.6 ms，修改写入数为 0。

神经 FFmpeg 路径直接把流式 float PCM 写入最终数组，去掉原先 MemoryStream、ToArray 和 float 数组三份同时驻留的路径。单文件解码结果限制为 128 × 1024 × 1024 个 float（512 MiB），解码时限 10 分钟；超过限制会报错并跳过该文件。该限制是结果数组预算，不代表进程总内存上限。

## 验证与持续集成

- 42 项 Lua 回归覆盖 50 万条容量、UCS、相似检索、启动、任务、存储、锁定文件故障注入、波形、响度、预览和宿主行为；最新生成包另做 SECTION 暂停恢复检查。
- Headless 浏览器使用真正的页面、控件和 DOM 事件，配合可延迟响应的模拟宿主；覆盖 50 万条视口、分片分页、单条／批量编辑、FX 时序、任务取消、Transfer 草稿、设置、语言和主题。
- 新增 14 组 CoreSelfTest 服务回归，直接调用生产服务：任务冲突、Bridge 取消／畸形响应、源路径保护、批次设置捕获、有限数值、编码器管道与取消、解码管道与取消、SQLite 恢复。
- Desktop 完整隔离自测和两种 benchmark 通过；发布 ZIP 内的 Desktop 再执行一次相同隔离自测。
- 神经模型 golden、多种真实 FFmpeg 音频格式和 job 协议验证通过；golden 最大绝对误差不超过约 3.4e-8，余弦相似度为 1，模型与缓存格式保持兼容。
- NuGet 审查覆盖直接与传递依赖；退出码异常、无效／不完整 JSON 或 feed 警告都视为失败，不能把未完成审查报告当成无漏洞。当前报告未列出已知漏洞。
- 生成脚本一致性、Lua 作用域／架构边界、JS lint／DOM／RPC 对照、翻译、ReaPack 版本／来源、离线安装回退和包内哈希验证均进入发布检查。关键新回归已接入 Code quality CI。

## 验证边界

这些检查不等于正式安全认证或 REAPER 实机听验。没有在用户前台操作，也没有启动 REAPER；真实播放设备、原生窗口、跨窗口拖入和真实工程 FX 仍需实机验收。

源覆盖检查覆盖规范化的普通路径、大小写、dot segments、Windows 扩展前缀和尾部点／空格。它主要依赖词法身份，尚未对所有 junction、symlink、硬链接和映射盘别名做 physical file ID 比对。

批量元数据实际应用仍是同步 O(n)；极大选择与大型来源迁移仍可能暂时阻塞宿主。这里优化的是快照／验证成本及交互竞争，没有将它们改成完整事务式后台迁移。

## 重建

```powershell
./tools/Build-LuaRelease.ps1 -Version 0.9.2-beta4 -OutputPath PsyReaSFX_v0_7_23_Stable.lua
./tools/Build-LuaRelease.ps1 -Ui webview -Version 0.9.3-beta18 -OutputPath PsyReaSFX_WebView.lua
./tools/Build-WebLauncher.ps1 -Version 0.9.3-beta18 -OutputPath PsyReaSFX_Launcher.lua
./tools/Build-WebRelease.ps1 -OutputPath dist/webview-fresh/package
./tools/Build-NeuralPackage.ps1 -OutputDirectory dist/neural-fresh
./tools/Build-DesktopPackage.ps1 -OutputDirectory dist/desktop-fresh
```

输出目录和 ZIP 必须是新的，避免把旧包与新源码混用。神经包版本由 `neural/package/package.json` 管理；旧发布来源保留各自固定 URL 和哈希，不能以当前 README 替换历史 README。
