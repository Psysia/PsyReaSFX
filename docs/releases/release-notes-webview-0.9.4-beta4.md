# PsyReaSFX 0.9.4 Beta 4

日期：2026-11-17。本版修复搜索结果波形长时间停在“正在读取波形缓存”的问题，继续作为预发布；默认稳定版仍为 0.9.3。

- 缓存读取独立于耗时解码任务。前面某条音频未完成，不再阻塞后面已经有缓存的结果；交互和独占任务期间仍可读取 PRS 已有缓存。
- 导入和后台预缓存不再暂停交互波形生成，二者使用独立节拍。选中素材优先处理；切换时释放旧任务的原生源和复制任务，避免遗留占用。
- 共享只读 WAV 每次最多处理 64 点，并在约 3 毫秒预算后让出下一帧，替代固定每帧 4 点。不会改用原音频原生解码；原生峰值分析仍只使用 PRS 私有副本。
- 大波形等待期间可先显示列表概览；中英文界面区分排队、准备私有副本、生成及暂停，并显示直接读取进度。处理中也可重试，重试会真正取消并重建对应任务。
- 旧解码错误不再阻止首次读取已有缓存。单个任务抛出异常时释放任务并允许重试；原生峰值构建超过 10 分钟会退出并提示检查文件，后续结果继续处理。

更新 ReaPack 的 **PsyReaSFX.lua**，关闭后重新打开 PRS。离线完整包使用 **Install-PsyReaSFX.cmd**。配套原生组件仍为 `0.3.9.30-prs.3`；Beta 2/3 已正常使用的用户无需更换组件或重启 REAPER。无需清空已有缓存或重新导入素材库。

回归覆盖：慢任务后的缓存命中、导入和预缓存共存、交互暂停、旧错误、选中优先、解码异常、重试取消、后台新写入缓存、WAV 帧预算、原生构建超时、中英文进度界面及源文件保护。合成 SQLite 并发测试验证外部写入继续提交、PRS 检测变更并停止。当前会话未获准访问 REAPER 界面，因此未将真实 REAPER / Soundminer 双开验收标记为完成。

Beta 4 fixes search-result waveforms remaining at “Reading waveform cache”. Cache reads proceed independently of slow decoders, interaction pauses and exclusive jobs. Interactive generation continues during import/precache, uses a separate cadence, and prioritizes the selected asset while releasing preempted native/copy ownership.

Protected WAV reads process at most 64 points per step and yield after an approximately 3 ms budget. Original audio still uses shared read-only access; native peak analysis uses private PRS copies. An available list overview can appear while detail is pending. Chinese and English status distinguishes queuing, copy preparation, generation and pauses, with direct-read progress and a working retry action. Decoder exceptions are contained; native peak builds exit with a retryable error after 10 minutes.

Update **PsyReaSFX.lua** and reopen PRS, or use **Install-PsyReaSFX.cmd** from the complete ZIP. Working Beta 2/3 users need no native component update or REAPER restart. Existing caches and catalogs can be reused. Automated queue, decoder, bilingual UI, package and source-protection regressions cover the change. Live REAPER access was unavailable during this investigation; real REAPER/Soundminer coexistence acceptance remains pending. This is a prerelease; **0.9.3 remains stable**.
