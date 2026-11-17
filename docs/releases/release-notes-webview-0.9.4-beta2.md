# PsyReaSFX 0.9.4 Beta 2

日期：2026-11-17。本版将运行库整合进 PRS 主包，继续作为预发布；默认稳定版仍是 0.9.3。

ReaPack 用户只需安装／更新 **PsyReaSFX.lua**。主包已包含配套原生组件、校验清单、完整对应源码和许可证，无需另找运行库或选择其版本。首次运行时自动准备组件；如果已加载旧版 PRS 组件，助手会等待所有 REAPER 窗口退出后更新，并提示重新打开。不会自动关闭 REAPER，也不会控制 Soundminer。

离线用户下载完整 ZIP，运行 **Install-PsyReaSFX.cmd**，一次安装本体及配套组件。已识别的 PRS 旧组件会自动备份并升级；未知来源的共享组件保持原样，避免覆盖其他脚本的依赖。该例外会显示原因，用户可自行决定是否通过完整安装器显式替换。

原生组件仍为已发布的 `0.3.9.30-prs.3`，没有重新编译，也没有把实机验收状态改成通过。安装授权绑定本版主程序及 DLL、源码的精确 SHA-256；任意上游或自定义候选不能继承自动安装许可。

保留 Beta 1 的 Soundminer 独立库、波形缓存导入及所有素材的共享只读／私有副本保护。首次启用或更新已加载组件需要重启一次 REAPER；后续普通使用直接启动。副本仍占用额外磁盘空间，实际双开的音频设备表现仍待实机验收。

Beta 2 bundles its native component in the main application. ReaPack users only install/update **PsyReaSFX.lua**; offline users run **Install-PsyReaSFX.cmd**. First launch prepares the included component automatically. Known PRS versions are backed up and upgraded after REAPER closes; unknown shared runtimes are preserved. No process is terminated. A restart is required when enabling or replacing a loaded component. The existing prerelease DLL and its native-acceptance status are unchanged. Stable remains 0.9.3.
