# PsyReaSFX 0.9.3 Beta 18

本轮集中修复编辑、试听、交付和后台任务的竞争与失败路径，并降低大批量编辑的快照开销。

- 元数据保存后继续输入、保存时切换素材、批量编辑和旧控件事件都保留各自草稿；切换／保存不再重复构造详情编辑器。
- FX 复位不再被延迟滑杆输入覆盖；SECTION 试听在反向和暂停恢复后保留正在播放的素材及区间。
- Region 操作验证素材和区域身份；大字段分页补齐视口；关闭窗口与宿主消息重试保留正确时序，并预留停止／取消通道。
- Transfer 捕获批次参数，阻止输出覆盖普通规范路径下的源素材；编码失败或取消保留已有输出。Desktop 恢复先检查数据库与 WAL，并保留回退副本。
- 神经组件 **0.9.1-beta1 / sidecar 0.5.2** 新增解码阶段取消、有界流式 PCM 和 FFmpeg 管道清理；模型和缓存继续兼容。
- 隔离合成测试中，25,000 条、每条 8 KiB 描述的批量快照从约 1.77 秒降至 0.015 秒 CPU 时间；这是函数测试结果，非整体界面速度承诺。

ReaPack 启用预发布后更新主程序到 **0.9.3-beta18**，关闭后重新打开 PRS。普通浏览／试听继续只读响度缓存，主动 **↻** 才触发原生分析。运行库保持 **0.3.9.30-beta3**（实际 `0.3.9.30-prs.2`），无需再次更新 DLL。

神经检索用户可另选同仓库的 **0.9.1-beta1** 数据包，或下载本 Release 的完整神经 ZIP（含模型与安装器）。Desktop 服务修复另见 **0.7.23 Alpha 8 Light RC2** 发布。

完整修复、测试证据和边界见 [Beta18 加固记录](../WEBVIEW_HARDENING_BETA18_zh-CN.md)。所有验证在后台或隔离模拟宿主完成；REAPER 实机听验、原生交互及全部物理路径别名仍是已说明的验证边界。

The update preserves metadata drafts across delayed saves and selection changes, orders FX updates, keeps the active SECTION preview during reverse/resume, validates Region identity, fills byte-limited pages and hardens export, cancellation and restore failures. The optional neural package now cancels during decoding and streams bounded PCM without changing the model or cache format. Background Lua, browser, Desktop, decoder and package regressions are included in the hardening record.
