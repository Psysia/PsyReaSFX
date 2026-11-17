# PsyReaSFX 0.9.4 Beta 3

日期：2026-11-17。本版修复 Beta 2 随包组件弹窗写死中文的问题，继续作为预发布；默认稳定版仍为 0.9.3。

安装引导根据 Windows 显示语言选择文案：中文系统使用中文，英文及其他系统语言使用英文；检测失败也使用英文。语言选择不受地区或数字格式影响，安装等待、重启、完成和异常提示使用同一种语言。启动文件缺失或助手无法启动时也有英文提示；正常启动不额外运行语言查询。

ReaPack 仍只需更新 **PsyReaSFX.lua**；离线包使用 **Install-PsyReaSFX.cmd**。原生组件仍为 `0.3.9.30-prs.3`。已经启用 Beta 2 的配套组件时，本次语言修复无需再次更换组件或重启 REAPER。未知共享组件仍保留，Soundminer 源文件保护逻辑未变，双开音频设备实机验收仍待完成。

项目开发规范加入中英文同步要求。回归覆盖中文、英文、繁体中文环境、其他语言和检测失败的英文回退，以及 Windows 显示语言与地区格式不一致的情况。

Beta 3 fixes Chinese-only bundled-component dialogs. Setup uses Chinese for a Chinese Windows display language and English otherwise, including detection failures. The choice is independent of regional number/date formats. First-launch failures, close/restart instructions, completion and error dialogs now have matching language support; normal ready launches do not run an extra language query.

Update only **PsyReaSFX.lua** through ReaPack, or use **Install-PsyReaSFX.cmd** in the complete offline ZIP. The native component is unchanged, so an already working Beta 2 installation needs no additional native update or REAPER restart. Unknown shared components and Soundminer source protection remain unchanged. This is a prerelease; 0.9.3 remains stable. Real REAPER/Soundminer audio-device coexistence acceptance remains pending.
