# PsyReaSFX 0.9.1 Stable

A reliability and performance update for 0.9.0. Update the main script through ReaPack and restart PsyReaSFX. The 0.9.0 neural component, existing databases and caches remain compatible; no library rebuild is required.

0.9.0 可靠性与性能更新。通过 ReaPack 更新主脚本后重开 PsyReaSFX 即可；0.9.0 神经组件、现有数据库和缓存继续兼容，无需重建音效库。

## Fixes / 修复

- Revisited list rows reload their saved `.rwf` waveform cache instead of re-decoding the source audio. / 列表行重新显示时直接读取已保存的波形缓存，不再重新解码源音频。
- Free-text searches for a workflow status reflect status changes immediately. / 修改工作流状态后，按状态文字搜索立即生效。
- Imported descriptions and keywords follow a fixed field priority (DESCRIPTION, COMMENT, TITLE, INAM) and skip blank values. / 导入的描述与关键词按固定字段顺序取值并跳过空值。
- A background job rejected because its resource is busy no longer cancels the job it would have replaced. / 因资源占用被拒绝的后台任务不再误取消原任务。
- The sidebar "Classify existing assets in Maintenance" button opens Settings again. / 侧栏“前往维护页分类现有素材”按钮恢复可用。
- Transfer reports no longer contain a stray seventh column. / Transfer 报告不再多出第 7 列。

## Performance / 性能

- English-interface translation of table cells is memoized instead of re-run every frame. / 英文界面表格单元格的翻译结果被缓存，不再每帧重算。
- UCS search suggestions are computed only while the popup is visible. / UCS 搜索提示仅在弹出时计算。
- TSV escaping skips fields that need none, reducing catalog save cost. / TSV 转义跳过无需转义的字段，降低保存开销。

## Downloads / 下载

- `PsyReaSFX_v0_9_1.zip` — Lua script, assets, documentation and provenance manifest. / Lua 脚本、资源、文档与来源清单。
- Neural similarity component: unchanged; use the [0.9.0 neural package](https://github.com/Psysia/PsyReaSFX/releases/download/v0.9.0/PsyReaSFX_Neural_Similarity_v0_9_0_win_x64.zip) or ReaPack. / 神经相似度组件未变化，继续使用 0.9.0 组件。

Verify downloads against `SHA256SUMS-0.9.1.txt`. / 请使用 `SHA256SUMS-0.9.1.txt` 校验下载文件。
