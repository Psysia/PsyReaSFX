# PsyReaSFX 0.9.4 Beta 7 · Windows x64

## 中文

- 修复了 Soundminer 独立库首次导入中断后，重新打开一直显示 0 条的问题。更新后打开原来的独立库即可恢复。只有索引写入成功才会标记导入完成。手动取消后，可以点“继续导入”补全。
- 大库初次读取时显示已读记录数，写入阶段显示导入进度。素材分批出现在结果里，可以边导入边浏览。
- Windows 暂时占用 PRS 配置文件时，后台保存会自动重试。持续失败时会显示 PRS 配置路径和系统返回的原因。

在 ReaPack 启用预发布，更新 `PsyReaSFX.lua`，然后关闭并重新打开 PRS 窗口。离线安装请先关闭 REAPER，解压 ZIP 并运行 `Install-PsyReaSFX.cmd`。

## English

- Fixed Soundminer catalogs staying at zero results after an interrupted first import. Reopen the same catalog after updating to recover it. Imports are marked complete once the index is saved. After canceling an import, use **Resume import** to finish it.
- Large catalogs show the number of source records read, followed by import progress. Results appear in batches and can be browsed while the import runs.
- Background saves retry when Windows temporarily holds the PRS settings file. A persistent failure shows the PRS settings path and the system error.

In ReaPack, enable pre-releases, update `PsyReaSFX.lua`, then close and reopen the PRS windows. For offline installation, close REAPER, extract the ZIP and run `Install-PsyReaSFX.cmd`.
