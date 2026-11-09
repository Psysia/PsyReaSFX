# PsyReaSFX 0.9.2 Beta 3 (pre-release)

Replaces Beta 2: smoother window moving and resizing, plus frame-timing diagnostics. **The stable channel stays at 0.9.1.** In ReaPack enable pre-releases (`Extensions → ReaPack → Manage repositories → Enable pre-releases`), synchronize, install `0.9.2-beta3` under **Versions**, then close the old window and rerun PsyReaSFX. The About page should read `0.9.2 Beta 3`.

取代 Beta 2：窗口移动与缩放更流畅，并新增帧耗时诊断。**稳定通道仍为 0.9.1。** 在 ReaPack 中启用预发布并同步后，于 **Versions** 安装 `0.9.2-beta3`，关闭旧窗口后重新运行。关于页应显示 `0.9.2 Beta 3`。

## What changed since Beta 2 / 相对 Beta 2 的变化

- While the window is being moved or resized, waveforms draw a coarser envelope, tooltips and cover decoding wait, and background work, saving and folder checks pause; full detail returns 0.3 s after you let go. / 移动或缩放窗口时，波形改为较粗的包络，提示和封面解码暂缓，后台任务、保存和目录检查暂停；松手 0.3 秒后恢复完整细节。
- Settings → Maintenance → "show frame timing" displays fps and where each frame's time goes (toolbar, tabs, sidebar, results, preview, inspector, popups). **Copy diagnostics** includes the same numbers. If the window still feels slow, please send them. / 设置 → 维护 → “显示帧耗时”显示每秒帧数以及每帧时间的去向；“复制诊断信息”包含同样数据。若仍然卡顿，请把数据发给我。

Everything else is the Beta 1 performance and reliability pass. The neural component is unchanged. / 其余内容与 Beta 1 相同；神经组件未变化。

Downloads: `PsyReaSFX_v0_9_2_beta3.zip`; verify against `SHA256SUMS-0.9.2-beta3.txt`. / 请用 `SHA256SUMS-0.9.2-beta3.txt` 校验下载。
