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
- 无需 Python、SQLite 或 zlib DLL；共享读取需要随 Beta 1 提供的 ReaWebAPI `0.3.9.30-prs.3`。Lua 解压器可通过回调在输出 8,192 字节、转换 4,096 点或完成压缩块时暂停，重采样每处理 4,096 个源点也可暂停，供后台协程分帧执行。
- 路径哈希不等于音频内容哈希。路径、声道及帧数校验不能识别同一路径下等长音频被替换的情况；需要时使用 PRS 原有缓存重建功能。

## 验证证据

### PRS 导入行为

入口为 **文件／音效库 → 导入 Soundminer 音效库**，也可从设置中的音效库页打开。自动发现本机 Soundminer 数据目录，或选择独立 `.sqlite` 文件；可指定缓存路径和音频路径前缀映射。每个数据库与路径映射组合创建独立目录 `PsyReaSFX/isolated_soundminer/<id>/data` 和独立运行窗口，索引、设置、播放列表、历史与波形缓存均分开保存。原有 PRS 库继续使用原目录。不同库即使引用同一音频，也各自保存元数据，不合并、不互相覆盖；源数据库和音频不移动。

窗口右上角显示当前库名称；点击它或菜单中的 **选择独立库** 可打开对应窗口，已打开的库直接切到前台。重新选择同一个数据库与路径映射会打开已保存的独立库；首次导入在该窗口后台开始。取消或失败后可从当前库的 **继续导入** 补全，保留已经导入的素材。程序更新共用安装的运行脚本，独立库不复制旧版程序。

再次选择同一库可修正缓存路径和波形开关，这两项不改变库身份，之后通过 **继续导入** 补全。独立 Soundminer 库禁用自动文件夹监视、自动首次扫描和中断目录扫描恢复，避免把数据库未收录的同目录素材自动加进来；手动操作仍限于当前独立库。

描述、关键词、分类、音频参数和备注进入所选独立库的索引，其他非内部的文本／数字字段保存在 `soundminer_metadata` JSON 列中；它们不会自动变成搜索字段。同一独立库内再次导入相同路径保留已导入的元数据和编辑。

数据库读取器只遍历普通 SQLite rowid 表及已确认的单列 BINARY 升序索引，不执行库中的 SQL、视图、触发器或扩展。支持 UTF-8，遇到活动 WAL／journal、UTF-16、损坏结构或不支持的 schema 时拒绝读取。Soundminer 可以同时运行；每次有界读取都以 `GENERIC_READ`、`OPEN_EXISTING` 和 `FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE` 打开并及时关闭句柄，不持有 SQLite 锁、不创建或删除源库 sidecar。文件身份、时间、大小、头部或日志发生变化时停止 PRS 的本次读取。该检测不构成事务快照；持续写入的库应使用 Soundminer 提供的一致数据库副本导入，不要求结束 Soundminer 进程。

元数据、解压及重采样以后台协程分批处理，取消会保留已导入条目。尚未在本机出现过的离线条目在手动扫描后仍可重定位；明确移除来源仍按原功能执行。保存失败会显示错误并保留当前会话数据，不把写入失败报告为成功。

兼容缓存转换为当前独立库的列表精度 RWF2，以及 2048／4096 点的聚合 RWF2 和独立声道 RWF3，不使用或覆盖原有 PRS 库的缓存。Soundminer 的峰值没有 PRS 频谱颜色数据，开启频谱显示时仍需按需分析源音频。同一独立库内重复素材的现有声道、采样率与时长也必须匹配 Soundminer 参数，才会补全缓存。

`tools/lua_soundminer_sqlite_selftest.lua` 使用 Python 标准 SQLite 生成的多页、overflow 和索引数据，检查读取、变更与损坏拒绝；`tools/lua_soundminer_import_selftest.lua` 加载生成的完整 PRS 后端，在多个隔离实例中验证同路径 PRS／Soundminer 数据与缓存独立、旧配置不迁移、重复打开仅聚焦、清单身份碰撞拒绝、目录外来素材不会自动进入，以及路径映射、离线条目、取消后继续、缓存转换、源变更、写盘失败和重新载入。检查原 PRS 文件与源数据库字节不变。浏览器回归通过真实控件验证导入、库选择、预检、路径映射、继续导入、标题和浏览器偏好隔离。安装器回归另验证首次安装、重复安装、外部 DLL 保留、回滚以及候选与错误哈希拒绝。

`tools/lua_soundminer_waveform_selftest.lua` 使用合成数据，覆盖 stored/fixed/dynamic DEFLATE、声道重排与聚合、保留瞬态的重采样、路径身份、数量与版本边界、截断和校验和错误、输出上限，以及协程穿过解码器错误捕获边界的暂停/继续。合成测试不含用户的音频、路径或元数据。

### 所有素材的源文件保护

保护覆盖原有 PRS 库和 Soundminer 导入库。目录探测、源音频、封面、数据库和波形缓存均通过共享只读接口；没有该接口时拒绝源读取，已有索引仍可浏览。元数据编辑只写当前 PRS 索引。

REAPER 原生媒体接口可能生成峰值旁车或持有文件句柄，因此试听、分析、插入工程、原生拖放、媒体浏览器、Transfer 和神经分析收到的是当前库 `data/native_media` 中的私有副本。复制在后台分段进行，可取消；源变化时丢弃未完成副本。完成的副本保留，避免破坏已经引用它们的 REAPER 工程。副本复用限于本次 PRS 会话，重新打开后可能再次复制，请预留磁盘空间，不要在工程仍引用时手动删除。

Transfer 在本测试版限定为 PRS 专属导出目录，已有文件不会被覆盖。旧的自定义目录设置保留，用户须在设置中选择“使用 PRS 导出目录”后导出。波形缓存选择外部父目录时使用 `PsyReaSFX-wave-cache` 子目录，迁移、清理和覆盖仅处理具备 PRS 格式标记的缓存文件。

`tools/lua_shared_readonly_selftest.lua` 验证接口缺失、读取限额、文件身份变化和目录拒绝；`tools/lua_soundminer_media_selftest.lua` 验证全素材副本、取消和原生调用路径。`tools/test_soundminer_source_concurrency.py` 使用合成 SQLite 库和独立写进程，验证导入及时停止且写进程可继续提交；原生依赖的 Windows 测试另验证共享句柄存在期间写入、重命名和删除。Lua 的测试替身不被当作 Win32 句柄行为证据。

这些检查验证文件访问边界，不保证同时运行时没有 CPU、磁盘或音频设备争用；没有对用户实际运行中的 Soundminer 执行注入、关闭或写入测试。手工建立指向其他程序目录的 junction／符号链接不属于已验收场景，REAPER 与 Soundminer 同机交互和音频设备表现仍需实机验收。

另外对 30 条实际缓存做了有界读取：均与素材参数匹配并成功解码，共 139,207 个点；覆盖单声道和多声道。一次本机 Lua 5.4.6 测量的总 CPU 时间约 0.262 秒，最长单条约 0.150 秒；这些是函数测量，不能作为整库导入速度承诺。后台导入应使用分帧回调。

其中一个实际存在的 48 kHz / 24-bit / 单声道 WAV 有 156,160 帧，缓存包含 306 组；前 305 组与源音频每 512 帧的 extrema 对照，按 127 归一化后的最大绝对误差约 0.003935，符合 8-bit 四舍五入误差；最后一组为零。该音频只在本机读取，没有复制进仓库或发布包。
