# PsyReaSFX 0.9.2 Beta 1 (pre-release)

A performance and reliability pass for testing. **The stable channel stays at 0.9.1.** In ReaPack enable pre-releases (`Extensions → ReaPack → Manage repositories → Enable pre-releases`), synchronize, and install `0.9.2-beta1` under **Versions**; then close the old window and rerun PsyReaSFX. The 0.9.0 neural component, existing databases and caches remain compatible.

供测试的性能与可靠性专项预发布，**稳定通道仍为 0.9.1**。在 ReaPack 中启用预发布并同步后，于 **Versions** 安装 `0.9.2-beta1`，关闭旧窗口后重新运行 PsyReaSFX。0.9.0 神经组件、现有数据库和缓存继续兼容。

## What changed / 变化

- Selecting all results, the inspector, folder reachability dots, cover thumbnails, the theme and list waveforms no longer redo work on every frame. / 全选结果、检查器、目录在线状态点、封面缩略图、主题和列表波形不再每帧重复计算。
- Search queries and view filters are parsed once per rebuild. / 查询词和视图过滤条件每次重建只解析一次。
- Imports finish several ready assets per frame; the missing-file audit is time-bounded. / 导入每帧可完成多个就绪素材；缺失文件审计按时间分帧。
- Faster hashing, duplicate fingerprints, TSV loading, journals, sorting, similarity ranking and neural parsing; saved formats are unchanged. / 哈希、重复指纹、TSV 加载、日志、排序、相似度排名和神经解析更快，数据格式不变。
- Saves no longer skip entries when the catalog changes mid-save; the inspector keeps your typing when an asset refreshes. / 保存期间目录变化不再漏写；素材刷新时检查器保留你的输入。

## Please check / 请重点试用

1. Ctrl+A on a very large result set with the inspector open. / 在检查器打开时对超大结果集 Ctrl+A。
2. Scrolling long lists in the English interface; scrolling back should not rebuild waveforms. / 英文界面下滚动长列表，回滚时不应重新生成波形。
3. A library whose source is on an offline network drive. / 来源在离线网络盘上的音效库。
4. Importing or rescanning a large folder; relinking a source root. / 导入或重新扫描大文件夹；重新定位来源根目录。
5. Anything that feels slower, shows a wrong count, or loses an edit. / 任何变慢、计数不对或编辑丢失的情况。

Downloads: `PsyReaSFX_v0_9_2_beta1.zip` (script, assets, docs, provenance manifest). The neural component is unchanged; keep using the 0.9.0 package. Verify against `SHA256SUMS-0.9.2-beta1.txt`. / 神经组件未变化，继续使用 0.9.0 组件；请用 `SHA256SUMS-0.9.2-beta1.txt` 校验下载。
