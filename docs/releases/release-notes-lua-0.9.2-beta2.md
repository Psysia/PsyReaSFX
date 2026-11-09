# PsyReaSFX 0.9.2 Beta 2 (pre-release)

Replaces Beta 1 and fixes the displayed version. **The stable channel stays at 0.9.1.** In ReaPack enable pre-releases (`Extensions → ReaPack → Manage repositories → Enable pre-releases`), synchronize, install `0.9.2-beta2` under **Versions**, then close the old window and rerun PsyReaSFX.

取代 Beta 1 并修正版本号显示。**稳定通道仍为 0.9.1。** 在 ReaPack 中启用预发布并同步后，于 **Versions** 安装 `0.9.2-beta2`，关闭旧窗口后重新运行 PsyReaSFX。

## What changed since Beta 1 / 相对 Beta 1 的变化

- The title bar, About page, splash screen and saved manifests now show `0.9.2 Beta 2`. They read "0.9.0 Stable" in 0.9.0, 0.9.1 and Beta 1 because the displayed name was a hand-edited literal that was missed. It is now derived from the release version at build time, and the release checks fail when the two disagree. / 标题栏、关于页、启动画面和保存清单现在显示 `0.9.2 Beta 2`。此前 0.9.0、0.9.1 和 Beta 1 都显示“0.9.0 Stable”，原因是显示名称是被遗漏的手工字面量。现在由构建根据发布版本生成，发布检查在两者不一致时会失败。

Everything else is the Beta 1 performance and reliability pass (selection, search, import, saving, relinking); see the [changelog](https://github.com/Psysia/PsyReaSFX/blob/main/docs/CHANGELOG_en-US.md) and the Beta 1 checklist. / 其余内容与 Beta 1 相同，详见更新日志与 Beta 1 的试用清单。

Downloads: `PsyReaSFX_v0_9_2_beta2.zip`. The neural component is unchanged; keep using the 0.9.0 package. Verify against `SHA256SUMS-0.9.2-beta2.txt`. / 神经组件未变化，继续使用 0.9.0 组件；请用 `SHA256SUMS-0.9.2-beta2.txt` 校验。
