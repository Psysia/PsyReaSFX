# PsyReaSFX Lua 0.9.0 优化审查（2026-11-06）

范围：`src/lua/*.lua` 全部模块（约 42k 行）。只读审查，未修改代码。
标记：✅ = 已人工核对源码确认；其余为审查代理读码得出（高/中置信），未做实测，耗时均为估算。
🔧 = 已在 0.9.1 热修中修复（工作区未提交，Lua CI 全部自测通过）。

---

## P0 正确性 Bug（建议立即修）

| # | 位置 | 问题 | 修法 |
|---|---|---|---|
| B1 ✅ 🔧 | `50_runtime_ui.lua:5609` `store_wave_memory` / `:5663` `queue_wave` | 内存 LRU（仅 180 条）淘汰时不清 `wave_checked[key]`，回滚到已淘汰的行时跳过 `.rwf` 磁盘缓存，**重新从音频解码并重写缓存**；预缓存写盘也不清该标记 | 淘汰时 `state.wave_checked[oldest_key] = nil`；`save_wave_to_disk` 后清对应 key；`MAX_WAVE_MEMORY` 提到 1000+ |
| B2 ✅ 🔧 | `50_runtime_ui.lua:2039` `set_workflow_status` | 改状态不清 `asset._search_blob`，而 blob 含状态标签 → 按状态文字搜索结果过期 | 循环内加 `asset._search_blob = nil`（`set_assets_marked` 已这样做） |
| B3 ✅ 🔧 | `50_runtime_ui.lua:3342` `metadata_pick` | 外层 `pairs(map)`，哪个元数据键先命中取决于哈希顺序；Lua 5.4 哈希种子随机 → TITLE 可能盖过 DESCRIPTION，且每次会话结果可能不同 | 外层循环 `names`（按优先级），内层循环键 |
| B4 ✅ 🔧 | `20_jobs_storage.lua:14-32` `Jobs.begin` | 先把旧任务标记 canceling，再检查 `resource_busy`；检查失败时旧任务已被取消且无替代 | 先做资源检查，再取消旧任务 |
| B5 ✅（降级） | `38_incremental_persistence.lua:262`、`37_catalog_caches.lua:176/394` | 跨帧用 `next()` 遍历 map，期间若插入新键，Lua 语义未定义，本次写出的文件可能漏掉旧条目。**复核后降级**：保存开始时清除脏标记，新插入会重新置脏，下一轮保存会完整重写，退出时还会同步保存；只有在两次保存之间崩溃才会丢失 | 移到 0.9.2：任务创建时分帧快照键数组，或维护变更代数 |
| B6 ✅ 🔧 | `50_runtime_ui.lua:14039` | 侧栏"前往维护页分类现有素材"在子窗口里 `OpenPopup("设置##reasfx")`，ID 栈与主窗口的 Modal 不一致 → 按钮无效 | 改用 `AppState.set("settings_popup_requested", 1)` |
| B7 | `50_runtime_ui.lua:20431-20509` 检查器 | 编辑器签名只含 path+indexed；"自动查找/清除封面"后签名不变，之后"保存元数据"把旧 `artwork_path` 写回；后台索引完成会冲掉正在编辑的内容 | 每素材修订号（`mark_asset_database_change` 自增）入签名；签名变化只重置未编辑字段 |
| B8 | `50_runtime_ui.lua:6650-6670` | `selected_set` 保留已不在结果里的键：计数与实际选中不一致，`selected_count()>1` 让 Enter 误走堆叠插入 | 结果重建完成时裁剪 `selected_set`，或两者同源 |
| B9 | `50_runtime_ui.lua:3356` `index_asset` | 元数据读取失败不记失败标记，可见行每 75 ms 重试一次（stat + 同步 `PCM_Source_CreateFromFile`） | 记 `meta_failed_at`，重扫前跳过 |
| B10 | `43_neural_similarity.lua:780` | 状态文件在 sidecar 重命名窗口读到一次失败/半截 JSON 就立刻回退声学搜索 | 连续 N 次失败或超时后才回退 |
| B11 | `50_runtime_ui.lua:2950-3015` 封面图缓存 | 实为 FIFO（`last_used` 未用于淘汰）；图像失效重建时 key 重复入队，淘汰旧副本会释放正在用的图像 | 入队前去重，按 `last_used` 淘汰 |

---

## P1 每帧卡顿（规模越大越明显，用户最能感知）

| # | 位置 | 问题 | 估算 | 修法 |
|---|---|---|---|---|
| F1 ✅ 🔧 | `10_ui_core.lua:243` 包装的 `DrawList_AddText` | **英文界面下每个表格单元格（文件名/描述/路径）每帧都走完整翻译管线**：~200 前缀 `sub` + ~20 `gsub` + CJK 检测，中文文件名还写进 `I18N_MISSING` | 30 行×6 列 ≈ 3.6 万次子串分配/帧 | 用户数据用 `RAW_IMGUI.DrawList_AddText`；`translate_ui_text` 无 CJK 字节直接返回；加有界记忆缓存 |
| F2 | `50_runtime_ui.lua:20826` 检查器 | 每帧对整个选择集建数组、`table.sort`（比较器内两次 `path_key`）、拼接全部路径再 `fnv1a` | Ctrl+A 50 万时 REAPER 基本冻结 | `selection_version` 计数器，按版本缓存排序结果与签名 |
| F3 | `50_runtime_ui.lua:15177/15225/14664/13756` 侧栏 | 每帧对每个库/根调用 `directory_exists`（`os.rename` 探测 + `EnumerateFiles`），tooltip 参数不悬停也构建 | 离线 SMB 根每帧阻塞网络超时 | 仅悬停时构建；在线状态由后台每 0.5–2 s 轮询一个根 |
| F4 | `50_runtime_ui.lua:3017/3125` 封面列 | 每可见行每帧 2–3 次 `file_exists`，命中图像缓存前就查盘；`CreateImage` 同步解码无每帧上限 | ~60+ stat/帧 | 有有效缓存图像直接返回；带 TTL 的存在性缓存；每帧最多创建 1–2 张 |
| F5 | `50_runtime_ui.lua:4773/17426-17831` 结果行 | 每行每帧：`wave_cache_key`（`path_key`+拼接+纯 Lua `fnv1a`）、popup ID 再算一次 `fnv1a(path_key)`、另外 8–10 次 `path_key`；`size<=0` 时每帧 `file_size`（缺失文件每帧 fopen） | ~600+ 字符串分配/帧 | `asset._key`、`asset._wave_key[points]` 缓存；负尺寸标记；`BeginPopupContextItem` 不传 ID |
| F6 | `50_runtime_ui.lua:11583` 迷你波形 | 每个存储峰值画一条线（256–512），而列宽只有 150–335 px | 1–2 万次 ImGui 调用/帧 | 按像素列取最大值，按宽度缓存 |
| F7 | `50_runtime_ui.lua:6650` `selected_assets()` | 右键菜单打开期间每帧扫描全部结果并 `path_key` | 50 万结果时每帧数百 ms | 按选择/结果版本缓存；小选择集反查 `by_path` |
| F8 ✅ 🔧 | `50_runtime_ui.lua:15559` | UCS 搜索建议在检查弹窗可见性**之前**计算，只要末词 ≥2 字符就每帧扫 ~750 条并排序 | 持续空耗 | 先判断可见性，按 `(search, language)` 记忆 |
| F9 | `50_runtime_ui.lua:14881/15065/15551/15857` | 收藏数、项目使用数、`selected_count()`、`session_played_count()` 每帧全量遍历 | Ctrl+A 后每帧 50 万次 | 变更时增量维护计数 |
| F10 | `50_runtime_ui.lua:24826` `push_theme` | 每帧重新应用密度、调色板（解析 ~8 个 hex）、外壳样式，分配 22 个小表 | 低-中 | 主题/密度版本变化时才重算 |
| F11 | `50_runtime_ui.lua:25329` `autosave` | `save_config` 在 UI 帧同步原子写入，包含全部收藏；大多数 UI 操作都会置脏 | 每 8 s 一次卡顿，随收藏数增长 | 收藏拆到独立文件，走辅助保存任务 |

---

## P2 批量操作 / 启动 / 保存吞吐

| # | 位置 | 问题 | 修法 |
|---|---|---|---|
| T1 ✅ 🔧 | `10_ui_core.lua:1720` `escape_tsv` | 每次调用新建闭包 + 无快速路径；50 万×35 字段 ≈ 1700 万次 | 常量映射表 + `find("[%%\t\r\n]")` 快速返回 + `(s:gsub(pat, MAP))` |
| T2 ✅ | `10_ui_core.lua:1743` `split_tsv` | 复制整行 + 惰性 `gmatch` + 每字段 `unescape_tsv`；响度/区域/失败任务/会话加载在启动时**同步执行**，50 万响度条目约 1–2 s 冻结 | 改用 `database_asset_from_line` 的 plain find 循环；响度/区域加载移入预算任务 |
| T3 | `50_runtime_ui.lua:4479` `matches_search` | **每个素材都重新解析一次查询**（`trim`+`split_words` 逐字符拼接+`lower`） | 重建开始时解析一次成 token 列表传入过滤闭包 |
| T4 | `50_runtime_ui.lua:4524` `asset_in_view` | 多个视图每素材 1–2 次 `path_key`；根过滤 `path_is_inside` 每素材 2 次 `path_key`+拼接 | 统一用缓存键；根键/桶/集合表每次重建预计算一次 |
| T5 | `50_runtime_ui.lua:6361` 导入 | **每帧最多处理一个素材，缓存命中也一样** → 50 万导入至少 2.3–4.6 小时；导入波形塞进内存 LRU 挤掉可见行 | 廉价步骤在 deadline 内循环；导入波形不进内存缓存 |
| T6 | `50_runtime_ui.lua:10452` 重新链接提交 | 单帧内对每个素材遍历所有集合/项目桶/最近列表 + 2–3 次 stat + 同步全库重写（失败路径再写一次） | 先建 old→new 映射单遍迁移；预算分步；走后台快照 |
| T7 | `50_runtime_ui.lua:10709` 重复指纹 | 每文件读 3×64 KB、拼两份 ~196 KB 再纯 Lua 逐字节 FNV（~39 万次迭代），约 20–40 ms/帧 | `string.unpack("<I4")` 4 字节一组；不拼接；单遍双种子；按 deadline 分帧 |
| T8 | `50_runtime_ui.lua:5780` `wave_cache_file_exists` | 为判断存在而完整解码缓存文件 | 只读头或 `file_exists` |
| T9 | `50_runtime_ui.lua:10681` 缺失审计 | 固定每帧 36 次 stat，无时间预算（网络盘超帧，本地盘又太慢：50 万约 8 分钟） | 改 deadline 驱动 |
| T10 | `42_similarity.lua:57-80/623/896` | 每候选约 4 次 `path_key`；参考路径每次重算；未超过堆最小值也先分配条目 | 参考键算一次；先比分数再分配；用缓存键。`44:1145` AI 同理 |
| T11 | `42_similarity.lua:116/466` | 特征缓存逐字节十六进制解码 + 冗余校验 + 每条 `AppState.set` | 256 项 `HEX2CHAR` 表 + `gsub("%x%x", map)`；局部计数每帧提交一次 |
| T12 | `44_ai_semantic_search.lua:1057` | 无 blob 素材每个建 8 元素表+concat+lower（50 万约 150 MB 垃圾）；每次迭代 `time_precise` | 复用搜索 blob；命中后才建字段表；每 64 条看一次时钟 |
| T13 | `43_neural_similarity.lua:89-140` JSON 解码 | 逐字符 `sub`，单帧无预算解析最大 2 MB（神经）/8 MB（AI）结果 → 0.3–1 s 卡顿 | `find('["\\%c]')` 批量复制普通片段；表常量上提 |
| T14 | `20_jobs_storage.lua:789` | 写文件用 CRT 默认缓冲（MSVC 约 4 KB，未在 REAPER 构建上确认），150–250 MB 快照数万次 WriteFile | `setvbuf("full", 1<<20)`；按 256 行 concat 一次写 |
| T15 | `36_asset_journal.lua:94/118` | 每字段 4 次链式 gsub；Adler-32 每字节 `byte()`+两次取模 | 快速路径 + 单次 gsub；分块读取、每 5552 字节取模（约 3–5×） |
| T16 | `35_incremental_results.lua:87` | 归并每轮新建 50 万数组，`#t+1` 追加；4096 元素 `table.sort` 本身可能超 8 ms | 显式写索引、双缓冲乒乓、多路归并；预计算排序键 |
| T17 | `30_catalog.lua:136→65` | 扫描新文件时 `ensure_asset_identity` 又 `file_exists` 一次（刚枚举过） | 传 `false`，直接写 `last_seen` |

---

## P3 安全与结构

- **AI 密钥**（`44_ai_semantic_search.lua:31/677/591`）：未发现命令注入（参数引用规则正确，pid 为整数）。但密钥以**明文**写到 `DATA_DIR/ai_semantic/api-key-plaintext.tmp`（原子写还会产生 `.tmp`/`.bak`，删除但未擦除）；若数据目录在 OneDrive/文档同步下可能被上传；保护调用同步阻塞 REAPER 最长 15 s。建议让 PowerShell 桥自己弹 `Get-Credential` 收密钥（密钥不经 Lua、不落盘），并异步启动。错误脱敏再加 `sk-[A-Za-z0-9_-]{8,}`。
- **全局函数查找开销**：`Build-LuaRelease.ps1` 直接拼接模块，受 200 局部变量上限所限，helper 都是全局，热循环里每次调用都是 `_ENV` 哈希查找。构建时把每个模块包进 `do … end`，热模块缓存 `local find, sub, byte = string.find, string.sub, string.byte` 等 upvalue。
- **HostApi 包装**（`15_host_adapter.lua:9-18`）：每次调用多一层 vararg 包装，直接 `rawset` 真实函数。
- **统一素材键**：`path_key(asset.path)` 在 `50_runtime_ui.lua` 前半就出现 43 次。引入 `asset_key(asset)`（基于已有的 `asset_path_sort_key` 缓存，重新链接时失效），一次改动可消掉 F5/F7/T3/T4/T10 的大部分分配。
- **死代码**：`draw_folder_browser`(14349)、`draw_folder_tree_node`(14274)、`draw_path_navigation_bar`(14213)、`folder_path_label`(14158) 约 400 行未被调用，建议删除。
- 文件夹悬停级联（14637/14689）不裁剪，子文件夹多时每帧上千个 `Selectable`，改用 `ListClipper`。

---

## 0.9.1 热修附带修复

- `escape_tsv` 旧实现返回 gsub 的两个值；在 Transfer 报告（`50_runtime_ui.lua` 写 `transfer_report_latest.tsv` 处）作为表构造器最后一项时，替换次数被当作第 7 列写入。新实现只返回一个值，报告恢复为 6 列。
- 回归测试：`tools/lua_jobs_selftest.lua` 新增"被拒绝的替换不得取消原任务"（旧代码失败、新代码通过）；`tools/lua_i18n_selftest.lua` 新增翻译记忆缓存的计数与容量上限断言。

## 建议推进顺序

1. **0.9.1 热修**（1–2 天）：B1–B6、F1、F8、T1。改动小、收益直接：波形不再反复重解码、英文界面明显变流畅、修掉静默丢数据和无效按钮。
2. **0.9.2 卡顿专项**（约 1 周）：引入 `asset_key` 缓存与选择/计数版本号（F2、F5、F7、F9、T3、T4），侧栏与封面的文件系统探测改后台（F3、F4），B7–B11。
3. **0.9.3 吞吐专项**（约 1 周）：T2、T5–T17，构建脚本加模块 `do…end` 作用域。附带补自测：`lua_*_selftest.lua` 增加对应回归用例。

---

## 0.9.2 实施记录（2026-11-09）

本批把原计划的"卡顿专项"和"吞吐专项"合并实施。下表只记录**已实测**的数字；没有实测的不写预估。代码在 `beta/0.9.x`，**尚未在真实 REAPER 中验证**，也尚未发布（`@version` 仍为 0.9.1）。

### 已完成

| 编号 | 做了什么 | 实测 / 验证 |
|---|---|---|
| B5 | 跨帧保存改为"创建时快照键数组"，中途新增的键不再让旧条目被漏写 | 新回归测试：遍历中途新增 5000 个键，原有 500 条必须各写一次；旧实现该测试失败 |
| B7 | 检查器签名拆为"选择身份 + 元数据戳"，同一选择下素材变化只刷新用户未编辑的字段 | 交互缓存自测覆盖 |
| B8 | `selected_count()` 改为可见选中数，与 `selected_assets()` 同源 | 交互缓存自测覆盖 |
| B9 | 元数据读取失败的素材 30 秒内不再重试 | 代码审阅 |
| B11 | 封面缓存按最近使用淘汰；重建图像不再重复入队 | LRU 单测 |
| F2 / F7 | 选择集所有修改走统一函数，选中列表、检查器列表、签名按修订号缓存；大选择不再每帧排序 | 源码守卫测试：`state.selected_set` 只允许在 `selection_replace` 里赋值 |
| F3 | 侧栏、库管理器改读 `directory_online()` 缓存，主循环每帧最多探测 1 个目录 | 单测：绘制期 0 次文件系统访问 |
| F4 | 封面存在性 5 秒缓存；已加载图像不再查盘；每帧最多新建 2 张 | 单测：200 次调用只探测 1 次 |
| F5 | 波形缓存键、行弹窗 ID、分类标签、文字高度、预览路径键均改为备忘 | 单测：未读取文件的素材 15 秒内不重复 `file_size` |
| F6 | 迷你波形按像素列绘制（每列取峰值） | 代码审阅（视觉与旧实现一致：重叠线条取最大值） |
| F9 | 收藏数、试听数等计数 0.25 秒缓存（需精确值处传 `fresh`） | 单测 |
| F10 | 主题仅在输入变化时重算 | 单测：30 帧只应用 1 次 |
| T2 | `split_tsv` 改为 plain find/sub，无 `%` 时跳过反转义；响度、区域加载每 2048 行让出一帧 | 2509 行与旧拆分器逐字段一致 |
| T3 / T4 | 查询只解析一次；视图/过滤条件每次重建只解析一次 | 1,498,500 次比较与旧实现完全一致；200k 素材 3 词查询 880 → 300 ms（2.9×） |
| T5 | 导入每帧在 6 ms 内处理多个"已索引且波形已缓存"的素材；导入不再把波形塞进内存 LRU | 导入恢复自测通过 |
| T6（部分） | 重新链接提交：最近列表批量上下文 + 每素材仅 1 次存在性探测 | 360 个素材：path_key 调用 47,900 → 14,165；状态与逐个迁移完全一致 |
| T7 | FNV-1a 每次取 8 字节并延迟掩码；重复检测指纹改为流式哈希，不再拼接两份约 196 KB 字符串 | 200 KB：5.00 → 1.20 ms（4.2×）；22 个文件的指纹与旧实现逐位相同 |
| T8 | `wave_cache_file_exists` 只读取并校验载荷长度，不再解码 | 与 `load_wave_from_disk` 在 15 种有效/截断/损坏文件上结论一致 |
| T9 | 缺失审计改为 4 ms 时间预算（每 8 个文件看一次时钟，上限 400/帧） | 代码审阅 |
| T10 / T11 / T13 / B10 | 相似度排名先比分数再算键；特征缓存加载用 256 项映射表；神经 JSON 解码按段复制；状态文件瞬时读失败最多容忍 5 次 | 各模块自测内含新旧实现对拍 |
| T12（部分） | AI 候选池满且分数不够时跳过路径键；时钟每 32 条检查一次；错误信息脱敏 `sk-…` | AI 自测 + PowerShell 桥自测 |
| T14 | 原子写入器 1 MiB 全缓冲（句柄不支持时自动忽略） | 写出字节与旧实现一致；覆盖 setvbuf 缺失/抛错 |
| T15 | 日志转义一次 find + 一次 gsub；Adler-32 每 16 字节展开、每 5552 字节取模 | 10000 条记录：编码 61 → 37 ms，解码 76 → 63 ms（**远低于预估的 3–5×**）；与旧实现逐位一致，覆盖 5552 边界 |
| T16 | 增量排序改为扁平数组乒乓归并 | 7320 个用例（含 chunk=1、预算=1、奇数尾段）与 `table.sort` 一致；30 万行总耗时 1.04 → 0.95 s（**仅小幅提升**，主要收益是不再每轮分配 30 万元素数组） |
| T17 | 扫描新发现的文件不再重复 `file_exists` | 启动自测通过 |
| 结构 | 删除约 390 行未被调用的旧目录浏览代码 | 结构自测、架构审计通过 |
| 结构 | 构建脚本把除 bootstrap 外的每个模块包进 `do … end`；5 个跨模块共享的 `local` 改为全局；新增 `tools/check_lua_module_scopes.cjs` 静态检查 + CI 里 `luac -p` 编译检查 | 构建产物 `luac -p`、luaparse 通过；检查器确认 79 个被包裹的顶层 local 无人跨模块引用 |

### 未做 / 只做了一部分

- **F11 收藏随配置每次全量写入**：未做。拆成独立文件需要新的 schema 与迁移，风险高于收益；写入器的 1 MiB 缓冲已降低了该开销。
- **T6 的后半**：重新链接提交仍在单帧内完成并同步重写数据库，只是去掉了 path_key 与重复探测的开销。
- **T12 的召回 blob**：没有的素材每次仍要拼接并转小写（为避免给 50 万素材常驻 blob 的内存而刻意保留）。
- **UCS 侧栏计数键、`column_layout` 缓存、悬停级联 `ListClipper`**：评估后收益很小（每帧一次或仅展开时），未改。
- **AI 密钥明文临时文件**：属于安全设计变更（让桥自己弹窗收密钥），未在本批处理。
- **所有"每帧耗时"类改动**：只有单元级验证，没有在真实 REAPER/ReaImGui 里测过帧时间。
