# PsyReaSFX 0.9.4 Beta 8 · Windows x64

## 中文

- 修复了 Soundminer 中可以试听、PRS 却提示“文件不存在”的跨平台素材路径。PRS 会读取所选库对应的 V6／V7 已启用 Live Relink 规则。更新后可直接打开原来的独立库，继续使用已有收藏、备注和波形。
- 大库使用 Windows 内置 SQLite 读取素材记录。已知来源根目录可以边读边浏览。在后台导入期间输入普通搜索词，PRS 会优先取回 Soundminer 全文索引命中的记录。
- 列表和详情按需读取 Soundminer 波形。首次导入省去了逐条生成多个分辨率缓存的等待。
- 源数据库继续使用共享只读访问。若 Soundminer 正在提交变更，PRS 会结束本次读取。可以保持 Soundminer 开启，稍后继续，或选择一致的数据库副本。

在 ReaPack 启用预发布，更新 **PsyReaSFX.lua**，然后完整退出并重新启动 REAPER，以加载新版原生读取组件。离线安装请先退出 REAPER，解压 ZIP 并运行 **Install-PsyReaSFX.cmd**。0.9.3 仍为稳定版。

## English

- Fixed cross-platform paths that played in Soundminer but raised “File not found” in PRS. PRS reads the enabled Live Relink rules for the selected V6 or V7 catalog. Reopen your existing independent catalog after updating to keep using its favorites, notes and waveforms.
- Large catalogs use the SQLite engine included with Windows. Browsing can begin as records arrive for recognized source roots. During import, ordinary search terms bring forward matching records from Soundminer’s full-text index.
- The list and detail view read Soundminer overviews on demand. Initial import skips generating multiple waveform resolutions for every record.
- Source databases are opened for shared reading. If Soundminer commits a change, PRS stops the current read. Leave Soundminer running and resume later, or select a consistent database copy.

Enable pre-releases in ReaPack, update **PsyReaSFX.lua**, then fully quit and restart REAPER to load the updated native reader. For offline installation, quit REAPER, extract the ZIP and run **Install-PsyReaSFX.cmd**. The stable release remains 0.9.3.
