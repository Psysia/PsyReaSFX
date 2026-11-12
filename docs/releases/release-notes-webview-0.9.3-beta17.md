# PsyReaSFX 0.9.3 Beta 17

- 修复每次浏览、试听新素材都会弹出 REAPER“标准化为 LUFS-I”进度窗口的问题。普通浏览和试听只读取已有响度缓存。
- 精确响度计算改为主动触发：点击响度区的 **↻** 或设置中的“重新分析当前素材”。新素材分析后缓存 LUFS-I/M/S 与 True Peak；手动分析仍可能显示 REAPER 进度窗口。
- 已有响度读数和估算响度匹配继续使用。新增回归测试验证连续浏览不触发计算、缓存显示、手动分析和音频源释放。

在 ReaPack 中同步并更新 **PsyReaSFX 0.9.3-beta17**，关闭后重新打开 PRS 即可生效，无需重启 REAPER。运行库沿用 **0.3.9.30-beta3**（实际 `0.3.9.30-prs.2`），无需再次更新 DLL。

The preview now reads cached loudness without starting native analysis. Click **↻** to measure and cache a new asset; explicit analysis may still show REAPER progress. Existing readings and estimated audition matching remain available.
