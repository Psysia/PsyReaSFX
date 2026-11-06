# PsyReaSFX Desktop 1.0 重建方案（对标 Lua 0.9.0 Stable）

> 状态：方案草案（2026-11-06）。目标：从零重建独立 Windows 桌面版，功能 100% 覆盖 Lua 0.9.0，
> 并在所有被 REAPER/ReaImGui/SWS 限制的地方做真正的升级。

---

## 0. 结论先行

1. **不在现有 `desktop/`（0.7.23 Alpha 8）上继续修补，而是新建解决方案重写**。现有版本是
   2800 行 code-behind 的 `MainWindow`，全量目录驻留内存 + `ICollectionView` 过滤，FTS5 建了但从未使用，
   非 WAV 格式无时长/波形/元数据，与 0.9 的差距（UCS、相似度、神经、AI、Tabs、重复确认、日志增量……）
   比重写成本还大。
2. **保留并迁移的资产**：SQLite 迁移纪律与备份/完整性工具、`PathIdentity`（卷序列号）、TSV 编解码、
   RWF 波形缓存编解码、`TransferEngine` 的思路、`BackgroundJobCoordinator` 概念、
   **神经 Sidecar 整体（几乎原样复用）**、UCS 8.2.1 数据、品牌资产。
3. **技术栈**：.NET 10 LTS + WPF（CommunityToolkit.Mvvm + 通用 Host/DI）+ SQLite（FTS5 trigram）
   + FFmpeg（解码）+ WASAPI 常驻输出 + Signalsmith Stretch（MIT，变调/变速）+ libebur128 等价实现。
4. **REAPER 变成可选伴侣**：所有浏览/试听/整理/导出都不依赖 REAPER；插入、BWF Spot、项目使用记录
   通过重写的 Bridge 完成；拖拽改为真正的 OLE 文件拖放（REAPER 原生支持）。
5. **工期估算**：单人 + AI 辅助约 **26 周 / 8 个里程碑**，每个里程碑都可独立发布 Beta。

---

## 1. 现状诊断（为什么要重建）

| 领域 | 现有 Desktop 问题 | 影响 |
|---|---|---|
| 架构 | `MainWindow.xaml.cs` 2818 行 / 189 方法 / ~75 可变字段；68 个 Click、0 个 Command；无 DI；无单元测试项目 | 无法测试、无法并行开发 |
| 规模 | 全量资产加载为 `AudioAsset` 对象（每个 27 个 INPC）；每次按键在 UI 线程 O(N) 过滤 + 反射排序；Facet 三次全量 Distinct | 50 万文件不可用 |
| 数据 | 跨表以路径字符串引用（移动文件要改 5 张表）；无 mtime 列（重启后增量扫描只比大小）；无 UCS/指纹/相似度列；Lua 导入只做一次、忽略 `index_v3.journal` | 数据漂移、增量失效 |
| 音频 | MME `WaveOutEvent` 且每次试听重建设备；线性插值无抗混叠；SMB 相位声码器变调伪影大；倒放上限约 5 分钟；OGG/Opus/WV 不能播 | 试听质量和延迟不达标 |
| 元数据 | 仅解析 WAV RIFF 头，不读 BWF bext / iXML / INFO / ID3 / Vorbis | 搜索质量依赖 Lua 导入 |
| 响度 | K 加权近似错误、声道能量取平均（立体声偏低约 3 dB） | 数值与 REAPER 不一致 |
| Bridge | 双向轮询文件队列；遍历时删除导致批量请求隔一个丢一个；无过期；`insert_bwf` 用了 `InsertMedia(…, 4)`（=拉伸到时间选区），Lua 主程序用的是 `4096`（源 BWF 位置）→ **现有 BWF Spot 是错的** | 可靠性 |
| 发布 | `tools/` 没有 Desktop 打包脚本；无安装器/便携版/自动更新 | 无法正式发布 |

---

## 2. 功能对标清单（Lua 0.9.0 → Desktop 1.0）

每项标注：**=** 等价复刻，**↑** 复刻并升级，**⇄** 实现方式因脱离 REAPER 而改变。

### 2.1 目录与素材库
- = 逻辑库（名称/分组/封面）→ 多个物理源根；空库；拖入资源管理器文件夹建库/加根；重复/父子重叠阻止；移交归属；离线根保留；启用/别名。
- ↑ 格式：wav/wave/aif/aiff/flac/ogg/opus/mp3/wv/caf/m4a 全部**可解码、可试听、可出波形**（FFmpeg），并过滤 `._*`。
- ↑ 扫描：两阶段（占位 → 元数据 → 波形）保留，改为后台多线程管线；**mtime + size + 卷标识**判定变更。
- ↑ 监视文件夹：`FileSystemWatcher` 事件合并 + 定时兜底轮询（15–600 s，与 Lua 选项一致）；静默模式、工具栏时钟。
- = 扫描检查点续扫、失败任务带重试计数与“全部重试”。
- ↑ 元数据：自研 RIFF/BWF(bext)/iXML/INFO/CART 解析 + TagLib#（ID3/Vorbis/MP4/AIFF），字段映射完全沿用 Lua `metadata_map` 规则（DESCRIPTION/COMMENT/TITLE/INAM → description 等）；**新增 BWF TimeReference 持久化**；**新增内嵌封面提取**。
- = 封面发现规则（邻近/子目录/编号兄弟目录、角色名、评分、深度限制、正负缓存、单素材覆盖）。
- = 路径身份：永久 `source_id`/`asset_id`、相对路径、规范路径、卷标/序列号、last_seen；↑ 实测 UNC/映射盘/符号链接。
- = 重新链接：计划 → 确认 → 事务提交（快照+回滚）、合并收藏/历史/集合/区域/响度/项目使用；缺失文件审计与 Missing 视图。
- ↑ 持久化：SQLite 单库（WAL），**以 asset_id 为外键**；Lua 的 schema 头/迁移注册/未来版本只读保护理念保留。
- = 备份：每日自动快照、手动、保留数量、恢复最新（`VACUUM INTO` + 校验）。

### 2.2 搜索
- = 语法：空格 AND、引号短语、`-` 排除、大小写不敏感子串；全部字段过滤器（name/path/library/root/category/subcategory/catid/desc/keywords/ch/fav/status/marked/played/missing/duplicate/project 及别名）。
- ↑ 引擎：FTS5 `trigram` 分词（天然支持中文与子串），≤2 字符词回退 LIKE；字段过滤器编译为 SQL 谓词；全部在后台线程，可取消。
- = 视图：all/favorites/recent/previewed/ucs_*/similar/ai_semantic/missing/duplicates*/project_used，叠加集合/状态/根/库过滤；点击元数据值加过滤。
- = 排序：名称/时长/库/最近插入/最近试听，升降序，路径破平；相似/AI 视图固定顺序。
- ↑ 结果：**键集分页 + 数据虚拟化**，替代 Lua 的分帧排序合并。
- = 保存的搜索（含视图/库/根/集合/状态/UCS/排序），重命名/删除。
- = 搜索建议（UCS 最多 7 条，插入 `catid:XXX`）；↑ 同时提供字段名与最近查询建议。

### 2.3 UCS 8.2.1
- = 753 CatID / 82 Category，中英双语；分类优先级（文件名 CatID 前缀 → 元数据 → 关键词倒排（≤4 词短语）→ 待定 Top3 → 未分类；手工永不覆盖）。
- = 每素材状态/来源/版本/分类器版本/置信度/候选/证据；全库重分类“预览 → 应用”，可取消、幂等。
- = 侧栏虚拟 UCS 树带计数；检查器候选芯片一键确认；会话撤销 64 步。
- **验收方法**：用 Lua 分类器对同一批文件名/元数据跑出 golden，C# 实现逐条比对一致。

### 2.4 相似度 / 神经 / AI / 重复
- ⇄ 声学 15 特征：数学原样移植；频谱输入改由自研 FFT 计算（不再依赖 REAPER GetPeaks type 115），算法版本号升级，缓存独立；加权欧氏、缺频谱时重归一化、Top-200、范围（当前结果/全部库）、相似度列（色条 + 最近特征组）。
- = 神经：复用 `PsyReaSFX.NeuralSidecar`（EfficientAT mn04、HNSW、0.75/0.25 重排、缓存格式不变，可与 Lua 共享缓存）；↑ Desktop 端改为常驻 worker 进程（stdin/stdout JSON-RPC），避免每次查询冷启动；保留 `run-job` 文件协议供 Lua 使用；↑ 流式解码避免整文件入内存。
- ⇄ AI 语义搜索：DeepSeek/OpenAI/兼容端点、≤32 预设、DPAPI 加密密钥（`ProtectedData`，可迁移 Lua 的密钥文件）、提示词与 JSON 结构原样、空/截断重试一次、本地召回权重（文件名 8 … 路径 1，正向 +0.75，负向 −12）、Top-2400 堆 + 每页 120、连接测试、Ctrl+Shift+F。**去掉 PowerShell 桥**，直接 `HttpClient`。
- = 重复：大小分组 → FNV-1a 头/中/尾抽样指纹 → 全内容逐字节确认，区分确认/读取失败；永不自动删除。↑ 可选“移入回收站”（需二次确认）。
- = 产品导航：元数据 + 封面字节一致（≤2 MB）+ 目录名，最多上溯 6 层。

### 2.5 分析
- ↑ 波形：自研 min/max 峰值（替代稀疏采样），兼容读写 RWF2/3/4（与 Lua 共享缓存目录）；LRU、预缓存任务、校验+隔离、迁移缓存目录。
- ↑ 频谱：真正的 STFT 频谱图视图（Lua 只有频率着色），保留 20 Hz–20 kHz 对数着色模式。
- ↑ 响度：严格 ITU-R BS.1770-4 / EBU R128（LUFS-I、最大 M、最大 S、True Peak 4× 过采样、环绕声道权重），以 REAPER `CalculateNormalization` 输出做 golden 对比（误差 ≤0.1 LU）。
- = 估算响度匹配（试听增益靠拢目标）。
- = 瞬态检测（阈值/平滑/最小间隔/前后 ms/最大数/替换或追加）→ `[T]` 区域批次、撤销、清空；手工 `[M]` 区域。

### 2.6 试听
- ↑ 输出：WASAPI 共享（默认）/独占/可选 ASIO；**设备常驻**，切换素材不重建；目标首响 ≤30 ms。
- ↑ DSP：Signalsmith Stretch（保持音高变速 + 变调，质量远好于 SMB），变速（不保持音高）用高质量重采样（r8brain/WDL sinc）；范围与 Lua 一致：音高 ±24 st、速率 0.25–4×、增益 −36…+18 dB；倒放改为分块逆向读取（无时长上限）。
- = 循环（全文件/选区）、选区自动循环、20/25 ms 边界淡入淡出、预设弹窗；参数卡拖拽/滚轮/双击输入/双击标签复位。
- ↑ 声道：Stereo/L/R/Mono，且 **3–8 声道真正可单独监听**（Lua 受 SWS 限制只能视觉选择）。
- = 列表波形点击定位播放、选择即试听、Space、迷你播放头；详情波形滚轮缩放、Shift+滚轮/中键平移、双击复位、右键拖动 Scrub、左键选区；播放状态着色、历史、会话恢复；Full/Focused/Minimal 三种控制栏布局。

### 2.7 REAPER 集成（⇄ 全部经 Bridge）
- 插入当前轨 / 新轨 / BWF 位置（**修正为 4096**）/ 指定位置 / 多选堆叠到多轨；插入后设置 take 的音高/速率/保持音高/音量/命名规则/淡入；Undo 块。
- 选区插入：Bridge 直接用 `InsertMediaSection` 的 section 参数，**不再预渲染临时 WAV**。
- 拖到编排区：OLE `CF_HDROP` 拖放（原文件或带处理的临时渲染），REAPER 原生接收；Bridge 在线时附加 take 参数。
- 项目使用记录：Bridge 上报当前 `.rpp` 路径；“当前项目使用”视图；项目 Bin 自动收集。
- Transfer 后可选“插入 REAPER”。

### 2.8 整理与导出
- = 收藏 F / 标记 M / 工作流状态（候选/通过/拒绝），作用于多选；播放列表与项目 Bin；最近插入、试听历史。
- = 元数据编辑（勾选字段批量应用，编辑 UCS 设为 manual）；↑ **可选写回文件**（BWF bext/iXML/ID3，默认关闭，写前备份）。
- ⇄ Transfer：不再依赖 REAPER 渲染（action 42230），自研离线管线：解码 → 变速/变调 → 声道/采样率转换 → 增益 → 淡入淡出 → 归一化（Peak/TP/RMS-I/LUFS-I）→ 抖动+噪声整形（16-bit）→ WAV 16/24/32 / FLAC（libFLAC，无需外部 ffmpeg.exe）；保留元数据；智能尾音；命名模板全部 token；批量变体（16 值/参数、128 变体/素材、4096 任务/作业）；冲突策略（递增/跳过/覆盖+备份）；完成后插入/打开目录；“当前文件后停止”；报告。↑ 多文件并行渲染。

### 2.9 界面与工作区
- = 工具栏（品牌标 + Orbitron 字标、面板开关、搜索 + 金色 AI 按钮、层级弹窗、扫描/监视、帮助、设置）。
- = 左侧分区（Sounds/Libraries-Folders 三模式/Collections/Saved/Workflow/UCS/Activity，可折叠可隐藏）；中间虚拟化结果（固定表头、可切换/可调宽列、Similarity 列、Shift+滚轮横移）；右侧检查器；底部试听面板可拖分隔条；F9/F10/F11、窄窗口自动折叠。
- = 工作区标签页：≤24，各自查询/过滤/排序/选择/滚动/缩放；全部快捷键与右键菜单；结果缓存 LRU 12；持久化。
- = 主题 Dark/Heritage + 自定义强调色与外壳色、强调色预设、三档密度、全部波形配色、字号 10–24、导航宽 160–520。
- = 中英双语即时切换（↑ 资源化，缺失键 CI 拦截）；全部快捷键；设置 8 个分区；帮助中心；启动画面显示真实加载阶段。
- ↑ 新增：快捷键自定义、多显示器/高 DPI、命令面板（Ctrl+K）。

---

## 3. 目标架构

### 3.1 解决方案结构

```
PsyReaSFX.sln
├─ src/
│  ├─ PsyReaSFX.Core          纯领域：实体、查询语法解析、UCS 分类器、相似度数学、命名模板、重复指纹（无 IO，100% 单测）
│  ├─ PsyReaSFX.Data          SQLite：Schema/迁移、Repository、FTS 查询编译、键集分页、备份/恢复、Lua 同步
│  ├─ PsyReaSFX.Media         FFmpeg 解码、元数据读写、封面、波形峰值/RWF、频谱、响度、瞬态
│  ├─ PsyReaSFX.Audio         播放引擎（WASAPI/ASIO）、DSP 链（stretch/resample/gain/fade/channel）、离线渲染(Transfer)
│  ├─ PsyReaSFX.Jobs          作业调度：优先级、资源锁、代际令牌、取消、进度、历史
│  ├─ PsyReaSFX.Integrations  REAPER Bridge 客户端、AI Provider、Neural worker 客户端
│  ├─ PsyReaSFX.App           WPF：View + ViewModel（CommunityToolkit.Mvvm）、主题、本地化、控件（波形/列表）
│  └─ PsyReaSFX.Native        (C/C++) Signalsmith Stretch + r8brain + libFLAC 的薄封装 DLL
├─ neural/PsyReaSFX.NeuralSidecar   保留；新增 `serve` 常驻模式
├─ reaper/PsyReaSFX_Bridge.lua      重写的 Bridge 脚本（进 ReaPack index.xml）
└─ tests/
   ├─ *.Tests (xUnit)               每个库的单元测试
   ├─ PsyReaSFX.Golden              与 Lua 输出比对：UCS、搜索命中、瞬态、相似度排名、命名
   ├─ PsyReaSFX.Benchmarks          BenchmarkDotNet：50 万目录的搜索/排序/Facet/滚动
   └─ PsyReaSFX.UiTests (FlaUI)     冒烟级 UI 自动化
```

依赖方向严格单向：`App → Integrations/Jobs/Audio/Media/Data → Core`。Core 不引用任何 IO/WPF。

### 3.2 数据层设计

- 单文件 `%LOCALAPPDATA%\PsyReaSFX\catalog-v2.sqlite3`，WAL，`synchronous=NORMAL`，**不使用 shared cache**；
  单写连接（专用写线程 + Channel 批量合并事务）+ 读连接池。
- 核心表：`libraries`、`sources`、`assets`（`asset_id` INTEGER 主键 + `uuid`、路径、mtime、size、卷信息、技术字段、文本元数据、BWF time ref）、
  `asset_ucs`、`asset_flags`（收藏/标记/状态/计数）、`collections`/`collection_items`、`saved_searches`、`history`、
  `regions`、`loudness`、`project_usage`、`fingerprints`、`similarity_features`、`failed_tasks`、`scan_checkpoints`、`jobs_history`、`settings`、`tabs`。
  全部外键用 `asset_id`；路径变更只改 `assets` 一行。
- `assets_fts`（FTS5 trigram，external content）覆盖 name/description/keywords/category/subcategory/catid/library/path。
- 查询：解析器（Core）→ AST → SQL 编译器（Data）。排序列建复合索引；结果用 `(sort_key, asset_id)` 键集分页，UI 只取可见窗口 ±2 屏。
  计数与 Facet 计数异步、可取消，单独返回。
- **50 万规模门槛**（沿用 `CAPACITY_STANDARD_500K` 并收紧）：冷启动可交互 ≤2 s；普通搜索 p95 ≤150 ms；
  Facet/计数 ≤500 ms；滚动 60 fps 无掉帧；DB ≤1 GiB；全量首扫（本地 NVMe，仅元数据）≤10 分钟。

### 3.3 与 Lua 版共存（关键决策，见 §6 Q1）

推荐 **“Lua → Desktop 增量单向同步 + 缓存共享”**：
- 读取 `index_v3.tsv` 快照 + 校验并重放 `index_v3.journal`，按 Lua 的 generation 记录同步点，可重复执行；
  覆盖全部 0.9 列（UCS 7 列、指纹 5 列）与 `project_usage_v1`、`failed_tasks_v1`、`similarity_features_v1`。
- 共享且格式不变的缓存：`wave_cache_v3\*.rwf`、`neural_similarity\` 嵌入/索引缓存。
- Desktop 不写 Lua 的 TSV（避免双写冲突）；如需反向，提供“导出为 Lua 数据目录”的显式操作。

### 3.4 线程与作业模型

- UI 线程只做绑定与绘制；所有 IO/解码/查询走 `PsyReaSFX.Jobs`。
- 作业 = kind + 资源锁（`catalog_write`、`decoder_pool`、`gpu/onnx`、`network_ai`）+ 优先级 + 代际令牌（新查询自动作废旧查询）+ `CancellationToken` + `IProgress`。
- 交互优先：用户正在滚动/试听时，后台扫描与预缓存自动降速（与 Lua 的“鼠标交互时让步”一致）。
- 禁止 `async void`（事件处理除外）、禁止 `.Result`/`GetAwaiter().GetResult()`，由 Roslyn 分析器在 CI 拦截。

### 3.5 音频引擎

```
Decoder(FFmpeg, 流式, 预读环形缓冲)
 → SectionReader(offset/length/reverse 分块)
 → ChannelMatrix(Stereo/L/R/Mono/任意单声道或多选)
 → Stretch(Signalsmith：pitch + rate + preserve) | Resampler(varispeed)
 → Gain(+loudness match) → BoundaryFades(20/25 ms) → DeviceMixer(WASAPI 常驻)
```
- 播放时钟由设备位置驱动，UI 播放头用 `CompositionTarget.Rendering` 插值，波形本身不重绘。
- 起播/跳转/Scrub 时在 DSP 链上做短交叉淡化并清空 stretch 内部缓冲（继承 Alpha 5 RC5 的修复思路）。
- 同一 DSP 链离线复用于 Transfer 与“拖出选区”，保证试听即所得。

### 3.6 REAPER Bridge v2

- 传输：首选 **localhost TCP / 命名管道**——REAPER Lua 无原生 socket，因此分两步：
  1. **v2.0（随 M6）**：保留文件队列但彻底加固——请求带 `expires_at` 与序号、先快照目录再处理（修复隔一丢一）、
     `ack` + 结果文件清理、心跳带 REAPER/项目状态；动作扩展为 insert（current/new/bwf/at/stack/section）、
     `query_state`（当前项目路径、选中轨、光标、时间选区）、`apply_take_params`。目标往返 ≤60 ms。
  2. **v2.1（可选）**：C++ REAPER 扩展 `reaper_psyreasfx.dll`（命名管道 + 主线程 timer 执行），往返 ≤5 ms，
     并可读取鼠标下的编排位置，实现“拖到哪插到哪”的精确落点。
- Bridge 脚本纳入 `index.xml`，ReaPack 一键安装；Desktop 内显示版本兼容性。

### 3.7 UI 实现要点

- 结果列表：自定义虚拟化 `ListView`（固定行高），**内联波形用共享位图图集批量绘制**（每行不再是独立控件各自加载），
  波形数据按可见区域优先级从 RWF 缓存异步填充。
- 详情波形/频谱：`DrawingVisual` + 预计算多级 mipmap 峰值，缩放平移不重新解码。
- 主题：全部颜色为 `DynamicResource` 令牌，Dark/Heritage 预设 + 用户覆盖；即时切换。
- 本地化：`.resx`（zh-CN 为源、en-US），代码中不再出现 `T(zh,en)` 内联对；CI 检查缺失键。
- 每个窗口/面板一个 ViewModel；`MainViewModel` 只负责编排，目标单文件 ≤400 行。

---

## 4. 里程碑计划（约 26 周）

| 里程碑 | 周数 | 交付内容 | 退出标准 |
|---|---|---|---|
| **M0 地基** | 2 | 解决方案骨架、DI/日志/诊断、CI（build、test、分析器、许可证扫描）、Schema v1 + 迁移框架、合成 50 万库生成器 | CI 绿；空壳启动 ≤1 s |
| **M1 目录与搜索** | 4 | 库/根管理、扫描管线、FFmpeg 探测 + 元数据解析、监视、检查点/失败任务、FTS 查询编译、键集分页列表、视图/过滤/排序/保存搜索、Lua 增量同步 | 50 万合成库达到 §3.2 门槛；搜索 golden 与 Lua 一致 |
| **M2 试听与波形** | 4 | WASAPI 引擎、Signalsmith/重采样、声道模式、循环/选区/Scrub、RWF 兼容、列表与详情波形、播放状态与历史 | 首响 ≤30 ms；24h 连续切换无泄漏；RWF 与 Lua 互读 |
| **M3 界面与整理** | 4 | 完整外壳（三栏/试听面板/Focus/窄窗）、工作区标签页、收藏/标记/状态/集合/Bin、元数据编辑、检查器、封面、主题/密度/配色、i18n、设置、帮助、启动画面 | UI 验收清单逐项通过（基于 Lua 0.9 截图） |
| **M4 分析与 UCS** | 3 | 响度 BS.1770、频谱图、瞬态与区域、UCS 分类器/树/候选/重分类、重复检测与确认、产品导航、重新链接、缺失审计 | UCS/瞬态 golden 100% 一致；响度误差 ≤0.1 LU |
| **M5 相似与 AI** | 3 | 声学 15 特征、神经 worker（serve 模式）与回退、AI 预设/DPAPI/召回排序/分页、密钥迁移 | 相似 Top-20 与 Lua 重合率达标；AI 离线 mock 测试通过 |
| **M6 REAPER 与 Transfer** | 3 | Bridge v2、全部插入方式、OLE 拖放、项目使用、离线渲染管线与全部 Transfer 选项、选区拖出 | Bridge 1000 次连发 0 丢失；Transfer 输出与 Lua 版逐项对照 |
| **M7 加固与发布** | 3 | 备份/恢复、磁盘满/无权限/离线卷演练、性能回归门、Velopack 安装器 + 便携版 + 自动更新、签名、文档与官网 | 50k 真实库验收；RC → 1.0 Stable |

可并行的线：M2（音频）与 M1 后半段独立；M5 的 AI 部分与 M4 独立；Bridge v2 Lua 脚本可在 M3 期间提前做。

---

## 5. 质量保障

- **功能对标矩阵**：把 §2 每一条展开为 `PARITY_0_9_0.md` 的行，每行链接到测试或人工验收步骤；“完成”必须有证据，杜绝旧矩阵“FTS 已完成但从未使用”式的虚报。
- **Golden 测试**：从 Lua 自测工具（`tools/lua_*_selftest.lua`）导出输入/输出夹具，C# 端逐条比对：查询解析、UCS 分类、瞬态、相似度特征、命名模板、TSV/journal/RWF 编解码。
- **性能回归门**：BenchmarkDotNet 结果入 CI 工件，超过基线 15% 失败；CI 跑 50 万合成库（而不是现在的 25k）。
- **UI 冒烟**：FlaUI 覆盖启动、搜索、试听、切标签、设置切换语言/主题。
- **崩溃与诊断**：本地结构化日志 + 一键导出诊断包（不含音频、不上传）。

---

## 6. 需要你拍板的问题

1. **Lua 与 Desktop 的数据关系**：推荐“Lua → Desktop 增量单向同步 + 共享波形/神经缓存”；备选是彻底分家（只做一次性导入）或双向同步（复杂度高、易冲突，不推荐）。
2. **UI 框架**：推荐 WPF（成熟、现有经验、虚拟化与自绘可控）。若未来要 macOS 版，则改用 Avalonia 11，工期 +15–20%。
3. **变调/变速库许可**：推荐 Signalsmith Stretch（MIT，可商用无负担）。Rubber Band 音质更好但需 GPL 或购买商业授权，与“免费商用”发布方式冲突。
4. **元数据写回**：是否纳入 1.0？（推荐纳入但默认关闭。）
5. **Bridge v2.1 原生扩展**：是否投入 C++ 扩展以换取 ≤5 ms 往返和精确拖放落点？（推荐 1.0 之后。）
6. **旧 `desktop/` 目录处置**：推荐新代码放 `desktop2/`（或新分支），1.0 Stable 后删除旧目录。

---

## 7. 第三方依赖与许可

| 组件 | 用途 | 许可 | 方式 |
|---|---|---|---|
| .NET 10 / WPF | 运行时与 UI | MIT | 自包含发布 |
| CommunityToolkit.Mvvm | MVVM | MIT | NuGet |
| Microsoft.Data.Sqlite / SQLite | 数据库 | MIT / 公有领域 | NuGet |
| FFmpeg（LGPL 构建） | 解码/探测 | LGPL-2.1 | 动态链接，随附源码链接 |
| TagLib# | ID3/Vorbis/MP4 元数据 | LGPL-2.1 | NuGet 动态 |
| NAudio | WASAPI/ASIO 输出 | MIT | NuGet |
| Signalsmith Stretch | 变调/变速 | MIT | 原生封装 |
| r8brain-free-src | 重采样 | MIT | 原生封装 |
| libFLAC | FLAC 编码 | BSD-3 | 原生 |
| ONNX Runtime | 神经推理 | MIT | 已用 |
| EfficientAT mn04_as | 模型 | MIT | 已用 |
| Velopack | 安装/更新 | MIT | 打包 |
