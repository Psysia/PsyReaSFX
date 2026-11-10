# PsyReaSFX 0.9.3 Beta 14

本版处理停靠时的重绘兼容问题和后台来源扫描开销，并优化播放指针与品牌按钮。

- **后台检查**：试听、REAPER 播放／录音和界面交互时暂停自动来源检查；每次检查结束后才计算下次间隔，无变化时逐步延长，最多 15 分钟。每次只做短时间片，后台队列轮流执行。自动监视只发现新增素材，不因来源临时离线删除数据库或收藏；手动增量扫描和缺失检查仍可整理已删除素材。
- **停靠兼容**：随包 ReaWebAPI `0.3.9.30-prs.1` 是基于上游 `0.3.9.30` 的明确标记修改版。Docker 保护仅作用于子容器，不再吞掉 REAPER 主窗口的暂停／恢复重绘消息；合并重复尺寸通知，避免频繁重建列表。完整源码、修改说明和 LGPL 许可随包提供。
- **平滑走带**：大小波形指针按浏览器显示帧刷新，宿主继续校准实际位置；支持暂停、跳转、倍速、反向和选区循环。只移动指针，不逐帧重画波形或请求列表；失去宿主更新或窗口隐藏时停止动画。
- **外观**：FX 改为带说明与展开状态的效果图标；恢复旧版叠层波形标志，`SFX` 与波形随主题强调色着色。
- **上游同步**：继续检查和镜像作者最新版本；开发包在 Windows 原生回归通过后才采用候选。检查不通过时明确记录原因并使用已固定的兼容版本，不将已知停靠问题重新带入开发包。

更新：ReaPack 同步后，`PsyReaSFX.lua` 选 `0.9.3-beta14`，**`PsyReaSFX WebView Runtime` 更新到 `0.3.9.30-beta2`，完全退出并重启 REAPER**。设置 → 关于与帮助应显示实际运行时 `0.3.9.30-prs.1`；仅重启脚本不会换掉已加载的 DLL。

已有其他来源管理的 ReaWebAPI 时，不要让两个 ReaPack 包同时管理同一个 DLL。完整 ZIP 的安装器默认保留外部版本；需要切换时，在关闭 REAPER 后以 `-UseBundledRuntime -AllowUnverifiedRuntime` 运行安装器，安装事务保留回滚副本。具体步骤见包内 `README.txt`。

已通过浏览器交互、播放时钟、Lua 调度／宿主、安装与回滚、ReaPack 载荷和隔离 Windows 重绘测试。本轮没有操作桌面或启动额外 REAPER；真实 Docker 缩放、切换标签、工程负载和听音仍请按[验收清单](../WEBVIEW_ACCEPTANCE_0_9_3_zh-CN.md)检查。测试通过不等于已测量你当前工程的帧率。

English: idle/backed-off Watch Folder scheduling, cooperative background budgets, a source-matched Windows Docker redraw compatibility build, smooth host-corrected playheads, resize coalescing, legacy brand coloring and an accessible FX icon. Update the runtime component as well as the script, then restart REAPER.
