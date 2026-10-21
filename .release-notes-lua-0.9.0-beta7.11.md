# PsyReaSFX 0.9.0 Beta 7.11

打开窗口时先显示界面，再分帧读取索引和校验增量日志。自动恢复只显示单行文字及取消按钮，未完成素材直接从索引接续，避免因为一条记录重新扫描全部来源。

- 加速 TSV 和增量日志解析；同版本日志减少重复字段转换。
- 启动恢复开关同时控制自动接续检查，已记录失败的素材通过维护页手动重试。
- 取消自动接续保留已有索引；加载中关闭窗口不会写回部分数据。
- 日志完整校验、历史与用户修改继续保留。

测试使用真实 60,548 条素材索引及约 8.5 MB 增量日志进行只读校验，解析 CPU 时间从约 4.55 秒降到约 2.73 秒。该数字为解析基准，不包含完整 REAPER 界面和磁盘等待时间；窗口已改为在加载前显示。

ReaPack 同步后将 `PsyReaSFX.lua` 更新为 `0.9.0-beta7.11`，关闭旧窗口并重新运行即可。不需要重新导入素材库，也不需要更新可选神经组件才能获得本次修复。

The window now appears before catalog loading, and catalog/journal work yields across frames. Automatic recovery resumes unfinished indexed assets directly and uses compact text instead of a repeatedly cycling progress bar. Closing during loading never saves a partial catalog, and saved journal changes remain fully validated.
