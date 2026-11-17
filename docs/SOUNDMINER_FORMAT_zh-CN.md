# Soundminer 数据库与波形兼容记录

本记录描述 2026-11-17 在本机既有 V6/V7 数据目录中只读观察到的格式，以及 PsyReaSFX 的兼容边界。它不是 Soundminer 官方格式保证，不能据此宣称兼容所有历史或未来版本。

## 素材与缓存关联

- 素材库为 SQLite，`justinmetadata` 包含 `FilePath`、`Filename`、`Pathname`、`Channels`、`SampleRate`、`TotalFrames`、`_Time`、`_FilePathHash` 及描述、关键词、分类等字段。
- 全局缓存位于 Soundminer 数据目录下的 `Caches/waveforms.sqlite`。观察到的 schema 标识为 `Soundminer`、版本 `0`。
- `overviews` 表字段为 `id INTEGER PRIMARY KEY`、`filepath TEXT`、`filepathhash TEXT`、`timestamp date`、`overviews BLOB`；`fphash` 是 `filepathhash` 的唯一索引。
- 样本中 `justinmetadata._FilePathHash` 与 `overviews.filepathhash` 匹配。读到缓存后仍须比较 BLOB 内原始路径、声道和帧数；文件路径重定位之后，匹配缓存时继续使用重定位前的 Soundminer 路径。
- 库内还存在 `waveform(recid, FilePath, hash, created_at, updated_at, refcount, waveformrep)`。本次检查的两个小型库此表为空；没有把未经观察的 `waveformrep` 编码宣称为已支持。

素材库 schema 由 REA SQLite 只读检查建立，证据 ID：`ev_9a7b000a696efb1a3c8173857a5e5ea321a5b7c2a67df634486d45170dfa5c1c`。全局缓存超过该工具 256 MiB 的输入上限，后续使用 Python 标准库 SQLite `mode=ro`、`query_only` 对指定行进行检查；没有修改源数据库或音频。

## 已观察的 overview 编码

外层采用 [Protocol Buffers wire format](https://protobuf.dev/programming-guides/encoding/)：

| 层 | 字段号 | Wire type | 观察到的含义 |
|---|---:|---:|---|
| 外层 | 1 | 2 | 原始文件路径 UTF-8 文本 |
| 外层 | 2，可重复 | 2 | 单个声道消息 |
| 声道 | 1 | 0 | 从 0 开始的声道编号 |
| 声道 | 2 | 2 | zlib 压缩峰值数据 |
| 声道 | 3 | 0 | 本次样本均为 1；其他值拒绝 |

压缩流遵循 [RFC 1950](https://www.rfc-editor.org/rfc/rfc1950) 与 [RFC 1951](https://www.rfc-editor.org/rfc/rfc1951)。解压后每两字节是一组 signed int8 的最大值、最小值；归一化以 127 为分母，并将绝对值限制到 1。每组对应 512 个源音频帧；观察到的组数为 `floor(TotalFrames / 512) + 1`。源帧数恰好为 512 整数倍时，样本包含最后一个零组。实现保留该组，不从尾部猜测或裁掉静音。

转换为 PRS 波形时取 `max(abs(maximum), abs(minimum))`，各声道分别保留，并对全部声道取最大值生成聚合峰值。缩小分辨率使用覆盖范围的最大值，避免丢失短瞬态；放大只重复已有采样范围，不声称获得更高精度。

## 校验与限制

- 只接受上述字段、版本、完整声道集合和一致长度。重复字段、重复声道、未知 wire type、损坏 zlib、错误 Adler-32、非法回引用和 extrema 次序错误均拒绝。
- 对照原始路径；Windows 盘符/UNC 路径允许分隔符和大小写等价，POSIX 路径保留大小写。路径重定位不降低原始缓存身份校验。
- 有 `TotalFrames` 时精确检查点数；否则可通过 `_Time × SampleRate` 恢复整数帧数再检查。帧数/声道不匹配的缓存交回原有波形生成流程。
- 单个 BLOB 上限 4 MiB，每声道最多 262,144 个点，最多 8 声道。超过限额的缓存跳过，不对未知数据作近似解释。
- 无需 Python、zlib DLL 或其他用户侧运行时。Lua 解压器可通过回调在输出 8,192 字节、转换 4,096 点或完成压缩块时暂停，重采样每处理 4,096 个源点也可暂停，供后台协程分帧执行。
- 路径哈希不等于音频内容哈希。路径、声道及帧数校验不能识别同一路径下等长音频被替换的情况；需要时使用 PRS 原有缓存重建功能。

## 验证证据

### PRS 导入行为

入口为 **文件／音效库 → 导入 Soundminer 音效库**，也可从设置中的音效库页打开。自动发现本机 Soundminer 数据目录，或选择独立 `.sqlite` 文件；可指定缓存路径和音频路径前缀映射。按数据库组织新来源，已存在的 PRS 来源保留归属。描述、关键词、分类、音频参数和备注进入 PRS 索引，其他非内部的文本／数字字段保存在 `soundminer_metadata` JSON 列中；它们不会自动变成 PRS 搜索字段。重复路径保留已有 PRS 元数据和编辑。

数据库读取器只遍历普通 SQLite rowid 表及已确认的单列 BINARY 升序索引，不执行库中的 SQL、视图、触发器或扩展。支持 UTF-8，遇到活动 WAL／journal、UTF-16、损坏结构或不支持的 schema 时拒绝读取。开始前关闭 Soundminer；头部、大小和 sidecar 的变化检查不是操作系统文件锁，不承诺活跃库的事务快照。

元数据、解压及重采样以后台协程分批处理，取消会保留已导入条目。尚未在本机出现过的离线条目在手动扫描后仍可重定位；明确移除来源仍按原功能执行。保存失败会显示错误并保留当前会话数据，不把写入失败报告为成功。

兼容缓存转换为当前列表精度的 RWF2，以及 2048／4096 点的聚合 RWF2 和独立声道 RWF3；已有 PRS 缓存不覆盖。Soundminer 的峰值没有 PRS 频谱颜色数据，开启频谱显示时仍需按需分析源音频。重复素材的现有声道、采样率与时长也必须匹配 Soundminer 参数，才会复用缓存。

`tools/lua_soundminer_sqlite_selftest.lua` 使用 Python 标准 SQLite 生成的多页、overflow 和索引数据，检查读取、变更与损坏拒绝；`tools/lua_soundminer_import_selftest.lua` 加载生成的完整 PRS 后端，在隔离目录验证路径映射、重复与离线条目、取消、缓存转换、源变更、保存失败及索引保存后重新载入。浏览器回归通过真实控件验证导入入口、预检、路径映射校验和单次请求。安装器回归另验证稳定包首次安装、重复安装、外部 DLL 保留、回滚以及候选与错误哈希拒绝。

`tools/lua_soundminer_waveform_selftest.lua` 使用合成数据，覆盖 stored/fixed/dynamic DEFLATE、声道重排与聚合、保留瞬态的重采样、路径身份、数量与版本边界、截断和校验和错误、输出上限，以及协程穿过解码器错误捕获边界的暂停/继续。合成测试不含用户的音频、路径或元数据。

另外对 30 条实际缓存做了有界读取：均与素材参数匹配并成功解码，共 139,207 个点；覆盖单声道和多声道。一次本机 Lua 5.4.6 测量的总 CPU 时间约 0.262 秒，最长单条约 0.150 秒；这些是函数测量，不能作为整库导入速度承诺。后台导入应使用分帧回调。

其中一个实际存在的 48 kHz / 24-bit / 单声道 WAV 有 156,160 帧，缓存包含 306 组；前 305 组与源音频每 512 帧的 extrema 对照，按 127 归一化后的最大绝对误差约 0.003935，符合 8-bit 四舍五入误差；最后一组为零。该音频只在本机读取，没有复制进仓库或发布包。
