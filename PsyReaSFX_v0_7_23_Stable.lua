-- @description PsyReaSFX - 高性能内联波形音效浏览器
-- @version 0.9.0-beta3-dev
-- @author Psysia
-- @link https://github.com/Psysia/PsyReaSFX
-- @maintenance
--   v0.5.1 将顶层辅助函数从 local function 改为脚本环境函数，
--   避免 Lua 主 chunk 超过 200 个活动局部变量的编译限制。
-- @about
--   以高密度音效资产列表与模块化工作流为核心重新设计：
--   - 深色模块化界面
--   - 波形列位于最左侧
--   - 点击列表波形任意位置，从对应时间开始试听
--   - 新库扫描后显示进度，元数据和缩略波形全部准备完成后统一展示
--   - 使用 REAPER 峰值构建流程，波形写入独立 v3 磁盘缓存
--   - Ctrl/Shift 多选、Ctrl+A 全选、批量分轨插入
--   - 从列表或下方波形拖到 REAPER 编排区
--   - 大波形点击定位、拖选区间、仅试听或拖出所选区间
--   - 左右面板一键折叠，支持专注工作区
--   - 多播放列表、项目素材箱、保存搜索、试听历史与工作流状态
--   - 设置中切换中文 / English
--   - 列表缩略波形默认提升到 256 点，可选 512 点
--   - 支持预缓存当前库或全部库的 2048 / 4096 点高精度波形
--   - Clean Cards / Compact 两套界面密度与图形化卡片风格
--   - 修复底部 Child 内图标说明被其他窗口覆盖的问题
--   - 外观设置改为真正影响全局的密度、层级和控制台模式
--   - 已播放文字按本次会话标黄，重启自动清除并支持手动刷新
--   - 单一紧凑列表布局，保持单行文字与高密度波形浏览
--   - 新增 Artwork 列、文件夹封面自动发现与元数据固定封面
--   - 设置窗口改为左侧导航 + 现代卡片式内容区
--   - Artwork 与状态颜色均采用按需缓存和可见行处理
--   - 修复设置中心左侧导航文字裁切，改为自绘双行导航卡片
--   - 所有颜色设置改为色盘选择并即时生效，保留色块与十六进制预览
--   - 新增 About 页面、运行环境、数据目录和诊断信息
--   - 修复底部控制区被裁切，动态预留波形下方控件高度
--   - 修复图标悬停说明被压成竖排文字
--   - 统一大波形标题、素材信息与响度显示为单一信息栏
--   - 移除列表与预览区之间的多重边框，只保留单一拖动把手
--   - Tooltip 增加悬停延迟，避免鼠标经过时闪出大窗口
--   - 图标帮助改为主窗口 DrawList 浮层，不再创建 ImGui Tooltip 窗口
--   - 修复图标之间快速移动时偶发的大面积空白闪烁
--   - 完成普通、选中、已播放、已标记四种列表波形状态配色
--   - 新增独立素材标记、M 快捷键与 marked:true 搜索
--   - 集中整理波形视觉状态解析与配色设置，降低行绘制分支重复
--   - 0.6 阶段：大波形缩放、平移、右键擦播、选区循环与试听预设
--   - 图形化工具栏与悬停说明；移除主工作区重复滚动条
--   - 下方面板支持垂直拖动调整高度并持久化
--   - 试听控制使用统一的专业参数卡片与响应式控制台
--   - 图标、圆角、间距、分组和悬停状态采用统一设计规范
--   - 多 Region、瞬态建议、声道监听、估算响度匹配与独立波形配色
--   - 瞬态检测详细参数、批次撤销和一键清除自动建议
--   - 选中素材按需计算 LUFS-I、LUFS-M/S max 与 True Peak
--   - 大波形选区内置拖拽胶囊，可直接拖到 REAPER 编排区
--   - 结果表不绘制横向滚动条，使用 Shift + 滚轮查看溢出字段
--   - RWF3 高精度缓存保留单声道、立体声及最多八声道独立波形
--   - 底部试听区统一为轻量 Studio Strip 小图标工具条
--   - 修复矮窗口下旧预设的预览区越界，严格按可用高度分配列表与波形
--   - 放宽 Studio Strip 参数卡间距，并压缩重复的长状态文件名
--   - 统一为单一 PsyReaSFX 布局，移除旧多预设维护分支
--   - 时间指标与参数控制去除外框，仅图标按钮保留边框
--   - 0.6 Stable：底部指标、摘要与状态统一文字基线
--   - 预览摘要与状态移入指标行，下方面板按实际内容收口
--   - 0.7 Transfer：完整文件或波形选区可渲染为新的音频文件
--   - Transfer 支持命名模板、采样率、声道、淡化与响度标准化
--   - 导出任务使用隔离临时对象，并在完成后恢复工程与渲染设置
--   - 支持递增、跳过与明确确认后的覆盖策略
--   - 可在导出后自动插入 REAPER，并记录最近传输结果
--   - 扫描时排除 macOS AppleDouble 与常见系统元数据目录
--   - 启动时自动清理旧索引中误收录的 `._*` 旁车文件
--   - 0.7.2：一个逻辑音效库可聚合多个来源文件夹
--   - 旧单路径音效库自动迁移为“一库一路径”，保留现有索引与波形缓存
--   - Windows 资源管理器文件夹可拖到逻辑库、全部音效库或中央结果区
--   - 路径重叠、重复归属和离线来源均提供明确保护与状态提示
--   - 0.7.3：允许先创建空逻辑音效库，再逐步添加来源路径
--   - 时长列统一使用 MM:SS.mmm 时间码格式
--   - 大型库扫描使用目录游标、已知根路径绑定和批量刷新，减少主线程重复遍历
--   - 0.7.4：逻辑库箭头可直接折叠或展开来源路径
--   - Artwork 增加逻辑库封面、来源根目录与常见封面子目录回退
--   - Beta 6 热修复：补齐主题强调色，避免左栏箭头中断 ImGui Child 栈
--   - 0.7.5：应用 PsyReaSFX 品牌色与 About 图标，README 使用正式品牌横幅
--   - Artwork 改为实体来源路径独立归属，不再跨逻辑库来源共享封面
--   - 实体来源右键菜单可指定、重新检测或清除自己的封面
--   - 0.7.6：黑暗模式恢复为默认，传统模式使用更深的品牌藏蓝
--   - 框架底色支持色盘自定义，并自动派生面板与交互层级
--   - 0.7.7：传统模式选中行使用深青背景与高对比白色文字
--   - 帮助窗口重构为分组快捷键手册，中英文内容完全独立
--   - Beta 10 热修复：帮助分组不再嵌套 Child，避免离屏分组破坏 ImGui Child 栈
--   - 0.7.8：移除应用内菜单条，统一为带品牌图标和双色字标的主工具栏
--   - 帮助改为永久图标入口，Watch Folder 迁移到常规设置
--   - 0.7.9：工具栏品牌标记改为矢量绘制，小尺寸与高 DPI 下保持清晰
--   - 品牌字标使用随包 Orbitron 字体；图标统一为无边框悬停高亮
--   - 左右面板开关分置工具栏两端，README 与用户手册按产品文档重写
--   - 0.7.10：右侧元数据开关回归左侧工作区控制组，减少跨窗口操作距离
--   - 工具栏搜索框与图标使用相同控制高度，统一顶部视觉基线
--   - Pitch、Rate、Gain 支持双击数值原位输入，输入时高亮且不改变布局
--   - 双击参数标签或滑轨恢复默认值，修复旧拖动状态覆盖重置的问题
--   - 设置说明精简为操作与安全提示，技术实现细节移入用户手册
--   - Beta 14 热修复：移除 InputDouble 不兼容的 EnterReturnsTrue 标志
--   - 精确参数输入改用 Enter、Esc 与失焦状态确认，不改变原位编辑布局
--   - Transfer 设置输入框使用隐藏标签，避免右侧标签被滚动条裁切
--   - 0.7.11：参数编辑与全局快捷键隔离，Enter 不再误插入素材
--   - 立体声监听使用状态图标和左键循环；右键保留完整选项
--   - 多声道选择支持 Ctrl、Shift、Ctrl+A，并实时联动独立波形声道
--   - 0.7.12：多声道选择改为主窗口内联工具条，不再创建 Popup
--   - 声道条保持全局快捷键与试听可用，支持单选、多选、范围选择与右键聚焦
--   - About 复用主工具栏矢量标志与 Orbitron 双色字标
--   - 0.7.13：修复同帧收起声道条时 SetCursorPos 越过 Child 边界的崩溃
--   - 多声道右键明确为波形聚焦，不再误称为 SWS 无法提供的源声道 Solo
--   - 0.7.14：空格停止试听使用短音量斜坡，减少连续从头试听的爆音
--   - Preview 安全淡入延长，定位在播放前写入，降低缓冲边界不连续
--   - 全部声道按钮显式区分选中、未选中与悬停状态
--   - 0.7.15：试听统一经过带源边界淡入的 Section Source
--   - 停止试听改用 SWS 音频线程淡出，移除会产生阶梯增益的 UI 帧斜坡
--   - 左右面板展开时，Gain 右侧六个试听开关仍会保留并按宽度自动换行
--   - 0.7.16：显式捕获 PsyReaSFX 聚焦窗口中的键盘输入，防止 Space
--     同时触发 REAPER 全局传输
--   - 停止试听后延迟释放媒体源，让 SWS 音频线程完成淡出，避免截断爆音
--   - 0.7.17：Artwork 自动识别支持编号封面目录与音频目录的兄弟目录
--     结构，例如 “1. Audio / 2. Artwork”，并保持实体来源之间相互隔离
--   - Transfer 新增源文件选区智能尾音，可按阈值、上限与留白延长输出
--   - 0.7.18：Artwork 候选优先选择接近 1:1 的封面，并以轻量文件头读取
--     替代完整图片解码；无封面列表单元格保持空白
--   - 左侧导航的声音、音效库、集合、保存搜索、工作流和活动分组可独立折叠
--   - 0.7.19：Transfer 补齐 WAV 16/24/32-bit、RMS-I、抖动与源元数据保留
--   - 批量变体支持自定义 Pitch、Rate、Gain 与 Normal/Reverse 笛卡尔组合
--   - 批处理改为每帧一个渲染任务，支持进度、取消、结果报告与安全覆盖提交
--   - 0.7.20：修复 Transfer 面板重复按钮 ID 与 Windows 目录打开失效
--   - 输出目录、最近输出与任务报告统一使用 SWS 优先、系统命令回退的打开流程
--   - 新增导出完成后自动打开输出目录，并随工程外配置持久化
--   - 0.7.21：Transfer 互斥选项改为明确的分段选择器状态
--   - 当前项统一使用强调色背景、边框与高对比文字，不再被通用按钮样式覆盖
--   - 0.7.22：主工作区新增索引驱动的文件夹层级浏览器与 Path 路径条件
--   - 逻辑库、来源路径和真实子目录可逐级展开；选择任意层级立即过滤结果
--   - 目录树分帧构建并持久化展开状态，不会因浏览目录重新扫描硬盘
--   - 0.7.23：目录入口改为搜索框旁的无边框文件夹图标
--   - 左键点击图标才打开第一层，避免鼠标经过工具栏时意外遮挡工作区
--   - 菜单内部以单窗口内联悬停树浏览逻辑库、来源与子目录
--   - 选中目录后只保留紧凑 Pathname 条件条，不再常驻占用结果区高度
--   - 0.8.0 Beta 1：回填桌面版的可靠性能力，增加中断扫描恢复
--   - 元数据与波形失败任务单独记录，支持稍后批量重试
--   - 新增每日/手动数据快照、保留数量管理与最近备份恢复
--   - 新增 RWF1/RWF2/RWF3 波形缓存完整性检查与损坏文件隔离
--   - Watch Folder 检查间隔可调，后台任务继续优先为鼠标交互让步
--   - 0.8.0 Beta 2：Watch Folder 默认静默检查，不再弹出常驻进度面板
--   - 后台扫描与增量波形建立统一使用工具栏动态扫描图标提示
--   - 无变化时完全静默；仅在新增、移除或失败时显示简短结果
--   - 0.8.0 Beta 3：合并原 Beta 3/4/5 计划，集中完成可靠性阶段
--   - 新增离线来源审计、整库缺失文件检查与来源根目录批量重定位
--   - 重定位同步迁移收藏、集合、Region、响度、失败任务与会话路径引用
--   - 新增同尺寸候选的分帧采样指纹检测与重复素材结果视图
--   - 指纹写入主索引并按文件大小失效，避免大型库重复读取全部文件
--   - 项目素材箱可绑定当前已保存的 RPP，插入素材时自动记录并收集
--   - 项目使用记录独立持久化，可按工程查看素材、次数和最近使用时间
--   - 0.8.0 Beta 4：完成全仓库稳定化与 50 万条目录容量治理
--   - 核心数据采用 schema、原子事务、代次快照与增量日志保护
--   - 大型目录的保存、扫描收尾、缓存、维护与关联数据均按帧预算执行
--   - 建立 AppState、Host、模块化发布源、架构审计和完整 CI 门禁
--   - 0.8.0 Beta 4.1：修复升序结果比较器不满足严格弱序导致的排序崩溃
--   - 0.8.0 Beta 4.2：修复扫描整理进度把导入会话误转为布尔值导致的崩溃
--   - 0.8.1：修复 Windows 文件夹拖放误判并结束 0.8.0 Beta 测试序列
--   - 0.8.2：修复设置维护页离屏嵌套 Child 触发的 EndChild 断言
--   - 0.8.3：Enter / Ctrl+Enter 插入 REAPER 改为默认关闭的可选快捷键
--   - 0.8.4：深层文件夹目录改为单窗口内联悬停树，避免子菜单翻向后断开
--   - 0.8.5：扫描恢复点仅用于异常中断的前台扫描，避免正常启动反复全库重扫
--   - 0.9.0 Beta 1：UCS 自动分类、虚拟目录、候选确认与搜索提示
--   - 0.9.0 Beta 2：侧栏双语、无阻塞启动快路与波形容错恢复
--   - 0.9.0 Beta 3 Dev：当前素材按需频谱峰值分析与独立 RWF4 缓存
--
--   必需：ReaImGui 0.10+
--   推荐：SWS Extension（高级试听、Pitch、Rate、Loop、定位播放）
--
--   数据目录：
--   <REAPER Resource Path>/Scripts/PsyReaSFX/

local SCRIPT_NAME = "PsyReaSFX"
local VERSION = "0.9.0 Beta 3 Dev"
local AUTHOR_NAME = "Psysia"
local COPYRIGHT_TEXT =
  "Copyright © 2026 Psysia. All rights reserved."

-- Fill this after the public repository is created, for example:
-- https://github.com/Psysia/PsyReaSFX
local PROJECT_URL = "https://github.com/Psysia/PsyReaSFX"

local PROJ = 0

----------------------------------------------------------------
-- Bootstrap
----------------------------------------------------------------

if type(reaper.ImGui_GetBuiltinPath) ~= "function" then
  reaper.MB(
    "PsyReaSFX 需要 ReaImGui。\n\n"
      .. "请在 ReaPack 中搜索并安装 ReaImGui，然后重启 REAPER。",
    SCRIPT_NAME,
    0
  )
  return
end

package.path =
  reaper.ImGui_GetBuiltinPath()
  .. "/?.lua;"
  .. package.path

local ok_imgui, ImGui = pcall(require, "imgui")

if not ok_imgui then
  reaper.MB(
    "无法加载 ReaImGui：\n\n"
      .. tostring(ImGui),
    SCRIPT_NAME,
    0
  )
  return
end

ImGui = ImGui("0.10")

local ctx =
  ImGui.CreateContext(
    SCRIPT_NAME .. "##" .. VERSION
  )

----------------------------------------------------------------
-- Paths and constants
----------------------------------------------------------------

local SEP = package.config:sub(1, 1)
local RESOURCE_PATH = reaper.GetResourcePath()

local SCRIPT_SOURCE =
  debug.getinfo(1, "S").source or ""

local SCRIPT_FILE =
  SCRIPT_SOURCE:sub(1, 1) == "@"
    and SCRIPT_SOURCE:sub(2)
    or ""

local SCRIPT_DIR =
  SCRIPT_FILE:match("^(.*[\\/])") or ""

local BRAND_ICON_PATH =
  SCRIPT_DIR
  .. "assets"
  .. SEP
  .. "brand"
  .. SEP
  .. "psyreasfx-icon.png"

local BRAND_FONT_PATH =
  SCRIPT_DIR
  .. "assets"
  .. SEP
  .. "fonts"
  .. SEP
  .. "Orbitron-VariableFont_wght.ttf"

local UCS_CATALOG_PATH =
  SCRIPT_DIR
  .. "assets"
  .. SEP
  .. "ucs"
  .. SEP
  .. "ucs-8.2.1.tsv"

local brand_font = nil

if reaper.file_exists(BRAND_FONT_PATH) then
  local font_ok, font =
    pcall(ImGui.CreateFontFromFile, BRAND_FONT_PATH)

  if font_ok and font then
    local attach_ok = pcall(ImGui.Attach, ctx, font)
    if attach_ok then
      brand_font = font
    end
  end
end

local DOCS_DIR =
  SCRIPT_DIR .. "docs"

local LEGACY_DATA_DIR =
  RESOURCE_PATH
  .. SEP
  .. "Scripts"
  .. SEP
  .. "ReaSFX_Browser"

local DATA_DIR =
  RESOURCE_PATH
  .. SEP
  .. "Scripts"
  .. SEP
  .. "PsyReaSFX"

local CONFIG_FILE =
  DATA_DIR .. SEP .. "config.tsv"

local LIBRARIES_FILE =
  DATA_DIR .. SEP .. "libraries_v2.tsv"

local PROJECT_URL_FILE =
  DATA_DIR .. SEP .. "project_url.txt"

local DATABASE_FILE =
  DATA_DIR .. SEP .. "index_v3.tsv"

local DATABASE_JOURNAL_FILE =
  DATA_DIR .. SEP .. "index_v3.journal"

local SCAN_CHECKPOINT_FILE =
  DATA_DIR .. SEP .. "scan_checkpoint_v1.tsv"

local FAILED_TASKS_FILE =
  DATA_DIR .. SEP .. "failed_tasks_v1.tsv"

local BACKUP_STATE_FILE =
  DATA_DIR .. SEP .. "backup_state_v1.tsv"

local MIGRATION_LOG_FILE =
  DATA_DIR .. SEP .. "migration_log_v1.tsv"

local BACKUP_DIR =
  DATA_DIR .. SEP .. "backups"

local RESTORE_TRANSACTION_COMMIT_FILE =
  DATA_DIR .. SEP .. "restore_transaction.commit"

local CACHE_QUARANTINE_DIR =
  DATA_DIR .. SEP .. "cache_quarantine"

local DEFAULT_WAVE_CACHE_DIR =
  DATA_DIR .. SEP .. "wave_cache_v3"

local DEFAULT_TRANSFER_DIR =
  DATA_DIR .. SEP .. "Transfer"

local TRANSFER_REPORT_FILE =
  DATA_DIR .. SEP .. "transfer_report_latest.tsv"

local WAVE_CACHE_DIR =
  DEFAULT_WAVE_CACHE_DIR

local COLLECTIONS_FILE =
  DATA_DIR .. SEP .. "collections_v1.tsv"

local PROJECT_USAGE_FILE =
  DATA_DIR .. SEP .. "project_usage_v1.tsv"

local SAVED_SEARCHES_FILE =
  DATA_DIR .. SEP .. "saved_searches_v1.tsv"

local HISTORY_FILE =
  DATA_DIR .. SEP .. "history_v1.tsv"

local LAST_PLAYED_SESSION_FILE =
  DATA_DIR .. SEP .. "last_played_session_v1.tsv"

local REGIONS_FILE =
  DATA_DIR .. SEP .. "regions_v1.tsv"

local LOUDNESS_FILE =
  DATA_DIR .. SEP .. "loudness_v1.tsv"

local LEGACY_CONFIG_FILE =
  LEGACY_DATA_DIR .. SEP .. "config.tsv"

local LEGACY_DATABASE_FILE =
  LEGACY_DATA_DIR .. SEP .. "index_v3.tsv"

local AUDIO_EXT = {
  wav = true,
  wave = true,
  aif = true,
  aiff = true,
  flac = true,
  ogg = true,
  opus = true,
  mp3 = true,
  wv = true,
  caf = true,
}

local ROW_H = 42
local HEADER_H = 28
local BOTTOM_MIN_H = 220
local BOTTOM_MAX_H = 520
local BOTTOM_SPLITTER_H = 14

-- 统一的 UI 设计规格。所有底部图标、参数卡片和面板都从这里取值。
local UI_METRIC = {
  radius = 7,
  radius_small = 5,
  icon_button = 34,
  icon_gap = 6,
  panel_padding = 7,
  parameter_h = 54,
  parameter_min_w = 104,
  parameter_max_w = 148,
  control_panel_h = 70,
}

local UI_DENSITY_PROFILES = {
  comfortable = {
    row_h = 48,
    header_h = 31,
    radius = 9,
    radius_small = 7,
    icon_button = 36,
    icon_gap = 8,
    panel_padding = 10,
    parameter_h = 60,
    parameter_min_w = 118,
    parameter_max_w = 164,
    control_panel_h = 80,
    panel_gap = 10,
    item_x = 10,
    item_y = 8,
  },
  balanced = {
    row_h = 42,
    header_h = 28,
    radius = 7,
    radius_small = 5,
    icon_button = 34,
    icon_gap = 6,
    panel_padding = 7,
    parameter_h = 54,
    parameter_min_w = 104,
    parameter_max_w = 148,
    control_panel_h = 70,
    panel_gap = 7,
    item_x = 8,
    item_y = 7,
  },
  compact = {
    row_h = 30,
    header_h = 24,
    radius = 3,
    radius_small = 3,
    icon_button = 28,
    icon_gap = 4,
    panel_padding = 4,
    parameter_h = 44,
    parameter_min_w = 88,
    parameter_max_w = 126,
    control_panel_h = 56,
    panel_gap = 4,
    item_x = 4,
    item_y = 3,
  },
}

local SURFACE_STYLES = {
  dark = {
    window = 0x101114FF,
    panel = 0x101114FF,
    panel_alt = 0x15171AFF,
    title = 0x15171AFF,
    title_active = 0x181B1FFF,
    header = 0x1B1E22FF,
    row = 0x101114FF,
    row_alt = 0x101114FF,
    row_hover = 0x1A1E23FF,
    grid = 0x24282EFF,
    border = 0x33465FFF,
    button = 0x1A1D22FF,
    button_hover = 0x252A31FF,
    waveform_bg = 0x050607FF,
    text = 0xE1E4E8FF,
    dim = 0x8D949DFF,
  },
  heritage = {
    window = 0x060A12FF,
    panel = 0x080E19FF,
    panel_alt = 0x0D1828FF,
    title = 0x0B1523FF,
    title_active = 0x102138FF,
    header = 0x11243BFF,
    row = 0x070C15FF,
    row_alt = 0x09101CFF,
    row_hover = 0x10243BFF,
    grid = 0x1B3049FF,
    border = 0x234866FF,
    button = 0x102038FF,
    button_hover = 0x183450FF,
    waveform_bg = 0x03070DFF,
    text = 0xF5FAFFFF,
    dim = 0x7A8797FF,
  },
}
local SIDEBAR_W = 188
local SIDEBAR_MIN_W = 132
local INSPECTOR_DEFAULT_W = 310
local INSPECTOR_MIN_W = 186
local CENTER_MIN_W = 300
local PANEL_GAP = 7

local SCAN_BUDGET = 0.0025
local META_INTERVAL = 0.075
local WAVE_INTERVAL = 0.012
local SAVE_INTERVAL = 8
local WATCH_INTERVAL = 60
local DATABASE_JOURNAL_COMPACT_COUNT = 10000
local DATABASE_SNAPSHOT_ASSETS_PER_FRAME = 2000
local DATABASE_SNAPSHOT_FRAME_BUDGET = 0.004
local LIBRARY_COUNT_ASSETS_PER_FRAME = 4000
local UCS_COUNT_ASSETS_PER_FRAME = 4000
local SCAN_CHECKPOINT_INTERVAL = 1.0
local IMPORT_CHECKPOINT_INTERVAL = 10.0
local CACHE_VERIFY_FILES_PER_FRAME = 12
local DUPLICATE_STAT_FILES_PER_FRAME = 64
local DUPLICATE_STAT_FRAME_BUDGET = 0.0025
local DUPLICATE_SORT_ITEMS_PER_FRAME = 4000
local PRECACHE_COLLECT_FILES_PER_FRAME = 64
local PRECACHE_CACHE_PROBES_PER_FRAME = 8
local PRECACHE_FRAME_BUDGET = 0.0025
local IMPORT_RECOVERY_ASSETS_PER_FRAME = 4000
local IMPORT_FINALIZE_ASSETS_PER_FRAME = 4000
local ARTWORK_RESET_ASSETS_PER_FRAME = 4000
local ROOT_REMOVAL_ASSETS_PER_FRAME = 4000
local ROOT_REMOVAL_FRAME_BUDGET = 0.003
local AUXILIARY_SAVE_RECORDS_PER_FRAME = 4000
local AUXILIARY_SAVE_FRAME_BUDGET = 0.003
local ASSET_BINDINGS_PER_FRAME = 4000
local ASSET_BINDING_CHANGES_PER_FRAME = 250
local SCAN_FINALIZE_ASSETS_PER_FRAME = 4000
local RELINK_PLAN_FILES_PER_FRAME = 48
local RELINK_PLAN_FRAME_BUDGET = 0.0025

local MINI_WAVE_DEFAULT_POINTS = 256
local MINI_WAVE_MAX_POINTS = 512
local LARGE_WAVE_DEFAULT_POINTS = 2048
local LARGE_WAVE_MAX_POINTS = 4096

local MAX_WAVE_MEMORY = 180
local MAX_WORK_QUEUE = 160
WAVE_READ_RETRY_LIMIT = 6
WAVE_READ_REOPEN_ATTEMPT = 3
WAVE_READ_REOPEN_LIMIT = 1

local COLOR = {
  accent = 0x1F6FCCFF,
  window = 0x101114FF,
  panel = 0x101114FF,
  panel_alt = 0x15171AFF,
  title = 0x15171AFF,
  title_active = 0x181B1FFF,
  header = 0x1B1E22FF,
  header_text = 0xE7E9EDFF,
  row = 0x0E0F12FF,
  row_alt = 0x121318FF,
  row_hover = 0x1B2027FF,
  selected = 0x1F6FCCFF,
  selected_text = 0xFFFFFFFF,
  text = 0xE1E4E8FF,
  dim = 0x8D949DFF,
  muted = 0x8D949DFF,
  grid = 0x24282EFF,
  border = 0x33465FFF,
  waveform_bg = 0x050607FF,
  waveform = 0xD7D8DAFF,
  waveform_selected = 0xEAF3FFFF,
  waveform_played = 0x8FB8D8FF,
  waveform_marked = 0xF0C85AFF,
  played_text = 0xF0C85AFF,
  playhead = 0x50E36DFF,
  selection = 0x2789E955,
  region = 0xE2B76499,
  favorite = 0xFFD533FF,
  success = 0x6ED486FF,
  warning = 0xE2B764FF,
  error = 0xE06D6DFF,
  button = 0x24272CFF,
  button_hover = 0x343A43FF,
  input = 0xF1F1F1FF,
  input_text = 0x101010FF,
}

local WORKFLOW_STATUS = {
  none = {
    label = "未标记",
    short = "—",
    color = 0x8A8D94FF,
  },
  candidate = {
    label = "候选",
    short = "候选",
    color = 0xE2B764FF,
  },
  approved = {
    label = "已采用",
    short = "采用",
    color = 0x6ED486FF,
  },
  rejected = {
    label = "已排除",
    short = "排除",
    color = 0xE06D6DFF,
  },
}

local WORKFLOW_STATUS_ORDER = {
  "none",
  "candidate",
  "approved",
  "rejected",
}

local THEME_PRESETS = {
  dark = {
    label = "黑暗模式",
    accent = 0x1F6FCCFF,
    accent_soft = 0x33465FFF,
    playhead = 0x61D982FF,
    favorite = 0xF0C85AFF,
    selected_text = 0xFFFFFFFF,
  },
  heritage = {
    label = "传统模式",
    accent = 0x19D8FFFF,
    accent_soft = 0x234866FF,
    selected = 0x0A6C86FF,
    playhead = 0x19D8FFFF,
    favorite = 0xF0C85AFF,
    selected_text = 0xFFFFFFFF,
  },
  amber = {
    label = "Warm Amber",
    accent = 0xC67B37FF,
    accent_soft = 0x5B4533FF,
    playhead = 0xF2C96DFF,
    favorite = 0xF2C96DFF,
  },
  teal = {
    label = "Deep Teal",
    accent = 0x238A86FF,
    accent_soft = 0x2E5352FF,
    playhead = 0x62D6CFFF,
    favorite = 0xE7C75BFF,
  },
  violet = {
    label = "Muted Violet",
    accent = 0x7356B8FF,
    accent_soft = 0x493E63FF,
    playhead = 0xB69CFFFF,
    favorite = 0xE2C65BFF,
  },
  neutral = {
    label = "Neutral Graphite",
    accent = 0x5E6670FF,
    accent_soft = 0x3A3E45FF,
    playhead = 0x8FD09EFF,
    favorite = 0xD8BD62FF,
  },
}

local APPEARANCE_PRESETS = {
  dark = {
    label = "黑暗模式",
    description = "原有的中性黑色工作区，作为默认外观。",
    shell_hex = "#101114",
    accent_hex = "#1F6FCC",
    waveform_hex = "#D7D8DA",
    waveform_selected_hex = "#EAF3FF",
    waveform_played_hex = "#8FB8D8",
    selection_hex = "#2789E9",
    playhead_hex = "#50E36D",
  },
  heritage = {
    label = "传统模式",
    description = "更深的藏蓝框架与 Electric Cyan 品牌强调色。",
    shell_hex = "#060A12",
    accent_hex = "#19D8FF",
    waveform_hex = "#DCE8F3",
    waveform_selected_hex = "#F5FAFF",
    waveform_played_hex = "#63CDE8",
    selection_hex = "#19D8FF",
    playhead_hex = "#19D8FF",
  },
}

----------------------------------------------------------------
-- State
----------------------------------------------------------------

local state = {
  open = true,

  -- Persistence is preflighted before any user data is loaded. Unknown or
  -- future schemas keep the application usable for browsing, but every
  -- writer is disabled so a newer catalog cannot be silently downgraded.
  persistence_read_only = false,
  persistence_read_only_reason = "",
  persistence_schema_versions = {},
  persistence_schema_legacy = {},

  roots = {},
  legacy_roots = {},
  libraries = {},
  library_by_id = {},
  root_records = {},
  root_by_id = {},
  root_by_path = {},
  libraries_dirty = false,
  library_asset_counts = {},
  library_counts_dirty = true,
  library_counts_job = nil,
  library_filter_id = nil,
  expanded_libraries = {},
  ucs_counts = {
    categories = {},
    subcategories = {},
    catids = {},
    total = 0,
  },
  ucs_counts_dirty = true,
  ucs_counts_job = nil,
  ucs_filter_category = nil,
  ucs_filter_subcategory = nil,
  ucs_filter_catid = nil,
  expanded_ucs_categories = {},
  expanded_ucs_subcategories = {},
  expanded_source_folders = {},
  expanded_folder_nodes = {},
  folder_browser_open = false,
  folder_menu_active = false,
  folder_hover_levels = {},
  folder_navigation_trees = {},
  folder_navigation_job = nil,
  folder_navigation_ready = false,
  folder_navigation_revision = 0,
  folder_navigation_built_revision = -1,
  pending_folder_drop = nil,
  assets = {},
  by_path = {},
  database_ordered_assets = nil,
  database_generation = 0,
  database_snapshot_session = nil,
  auxiliary_save_session = nil,
  root_removal_session = nil,
  clear_scan_checkpoint_after_database_save = false,
  clean_shutdown_requested = false,
  database_changes = {
    by_key = {},
    count = 0,
    requires_snapshot = false,
  },
  favorites = {},
  recent = {},

  -- 0.5：播放列表 / 项目素材箱与保存搜索使用独立轻量索引。
  collections = {},
  collection_by_id = {},
  active_collection_id = nil,
  collections_dirty = false,

  saved_searches = {},
  searches_dirty = false,

  history_dirty = false,
  preview_history_assets = {},

  -- 当前启动会话的已播放颜色。完整历史仍保存到 history_v1.tsv。
  session_played = {},

  -- 上次浏览会话单独保存，用户可手动或自动恢复。
  last_session_played = {},
  session_played_dirty = false,
  restore_played_on_start = false,

  status_filter = nil,

  results = {},
  search = "",
  view = "all", -- all / favorites / recent / previewed / missing / duplicates / project_used
  root_filter = nil,
  sort_mode = "name",
  sort_desc = false,
  results_dirty = true,
  results_job = nil,
  asset_binding_refresh = nil,

  selected_index = 0,
  selected_path = nil,
  selected_set = {},
  selection_anchor = 0,

  -- 导入阶段的素材保持隐藏，直到元数据与缩略波形全部准备完成。
  import_session = nil,
  import_cancel_requested = false,
  import_recovery_audit = nil,

  -- 从列表/大波形拖到 REAPER 编排区。
  external_drag = nil,
  external_drag_started = false,

  auto_preview = true,
  watch_enabled = true,
  watch_interval = WATCH_INTERVAL,
  watch_silent = true,
  resume_scan_on_start = true,
  next_watch = reaper.time_precise() + WATCH_INTERVAL,

  scan = nil,
  scan_checkpoint_last_at = 0,
  import_checkpoint_last_at = 0,

  -- 0.8：失败项、备份与缓存校验都独立持久化，不污染主索引。
  failed_tasks = {},
  failed_tasks_dirty = false,
  auto_backup = true,
  backup_keep_count = 7,
  backup_last_date = "",
  cache_verify_session = nil,
  skip_persistence_on_cleanup = false,

  -- 0.8 Beta 3：可靠性审计均分帧执行，结果只保留轻量索引。
  missing_audit = nil,
  missing_assets = {},
  missing_asset_count = 0,
  offline_roots = {},
  duplicate_scan = nil,
  duplicate_groups = {},
  duplicate_group_count = 0,
  duplicate_asset_count = 0,
  duplicate_lookup = {},
  duplicate_confirmation = nil,
  duplicate_confirmed_groups = {},
  duplicate_confirmed_lookup = {},
  duplicate_confirmed_asset_count = 0,
  duplicate_confirmation_failures = {},
  duplicate_confirmation_failure_count = 0,
  relink_plan_session = nil,

  -- 0.9：UCS 现有库重分类使用预览/应用双阶段任务。
  ucs_reclassification_session = nil,
  ucs_reclassification_review = nil,
  ucs_pending_lookup = {},
  ucs_pending_count = 0,
  ucs_confirmation_undo = {},
  ucs_confirmation_undo_order = {},
  ucs_search_popup_visible = false,

  -- 项目素材箱可绑定已保存的 RPP；使用记录独立保存。
  project_usage = {},
  project_usage_dirty = false,
  current_project_path = "",
  current_project_key = "",
  current_project_name = "",
  current_project_bin_id = nil,
  auto_collect_project_usage = true,
  next_project_refresh = 0,

  meta_queue = {},
  meta_queued = {},
  next_meta_job = 0,

  wave_queue = {},
  wave_queued = {},
  wave_checked = {},
  wave_active = nil,
  wave_cache = {},
  wave_cache_count = 0,
  wave_clock = 0,
  next_wave_job = 0,

  -- 高精度波形预缓存使用独立低优先级队列，不占满内存缓存。
  precache_session = nil,
  precache_cancel_requested = false,
  precache_points = 4096,

  -- 高精度大波形可保留每个源声道的独立峰值。
  multichannel_waveform = true,
  -- 频谱峰值只为当前大波形按需读取，不进入列表缩略图任务。
  spectral_peaks_enabled = false,

  -- 结果表只使用 Shift + 滚轮横向移动，不绘制常驻或浮动滚动条。
  results_scroll_x = 0,
  results_scroll_max_x = 0,
  results_scroll_request = nil,

  wave_cache_dir = DEFAULT_WAVE_CACHE_DIR,

  preview = nil,
  preview_companion = nil,
  preview_source = nil,
  preview_sources = nil,
  retired_preview_sources = {},
  preview_path = nil,
  preview_position = 0,
  preview_length = 0,
  preview_map_start = 0,
  preview_map_span = 1,
  preview_map_reverse = false,
  preview_percent = 0,
  preview_backend =
    type(reaper.CF_CreatePreview) == "function"
      and "SWS"
      or "Media Explorer",

  region_start = 0,
  region_end = 1,
  wave_drag_start = nil,

  -- 可保存的多 Region 数据单独持久化，不写入源文件。
  regions_by_path = {},
  regions_dirty = false,
  active_region_index = 0,
  pending_transient_detection = nil,
  transient_popup_requested = 0,
  transient_popup_asset_path = nil,
  transient_threshold = 0.24,
  transient_min_gap_ms = 140,
  transient_pre_ms = 20,
  transient_post_ms = 180,
  transient_smoothing_ms = 8,
  transient_max_regions = 64,
  transient_replace_existing = true,

  -- 0.6 波形编辑视图：显示范围仍使用完整文件的 0–1 百分比。
  wave_view_start = 0,
  wave_view_end = 1,
  wave_pan_last_x = nil,
  wave_scrub_last_at = 0,
  wave_scrub_enabled = true,
  loop_selection = true,

  pitch = 0,
  rate = 1,
  gain_db = 0,
  preserve_pitch = true,
  loop = false,
  reverse = false,

  preview_channel_mode = "original",
  preview_channel_asset_key = nil,
  preview_channel_count = 0,
  preview_channel_selection = {},
  preview_channel_anchor = 1,
  preview_channel_strip_expanded = false,
  loudness_match = false,
  loudness_target_db = -18,
  preview_match_offset_db = 0,

  -- 精确响度统计只分析当前请求的素材，并写入独立缓存。
  show_loudness_metrics = false,
  loudness_show_i = true,
  loudness_show_m = true,
  loudness_show_s = false,
  loudness_show_tp = false,
  loudness_cache = {},
  loudness_dirty = false,
  loudness_queue = {},
  loudness_queued = {},
  loudness_active = nil,
  next_loudness_job = 0,

  preview_control_layout = "studio_strip",
  bottom_panel_height = 330,
  bottom_split_drag = nil,
  parameter_drag = nil,
  parameter_edit = nil,
  keyboard_consumed = false,
  selection_drag_handle_pressed = false,

  enter_insert_shortcuts = false,
  insert_lowercase = true,
  insert_prefix = "",
  insert_suffix = "",
  insert_fade_ms = 5,

  -- 0.7 Transfer 使用 REAPER 原生 selected-media-item 渲染。
  -- 临时对象与工程渲染设置会在任务结束后恢复。
  transfer_dir = DEFAULT_TRANSFER_DIR,
  transfer_template = "{name}",
  transfer_format = "wav24",
  transfer_sample_rate = "source",
  transfer_channels = "source",
  transfer_scope = "selection",
  transfer_collision = "increment",
  transfer_fade_in_ms = 5,
  transfer_fade_out_ms = 20,
  transfer_smart_tail = false,
  transfer_tail_threshold_db = -60,
  transfer_tail_max_ms = 5000,
  transfer_tail_hold_ms = 180,
  transfer_normalize = "off",
  transfer_normalize_target = -1,
  transfer_insert_after = false,
  transfer_open_dir_after = false,
  transfer_lowercase = false,
  transfer_dither = true,
  transfer_noise_shaping = false,
  transfer_preserve_metadata = true,
  transfer_variants_enabled = false,
  transfer_variant_pitches = "",
  transfer_variant_rates = "",
  transfer_variant_gains = "",
  transfer_variant_include_reverse = false,
  transfer_variant_auto_suffix = true,
  transfer_popup_requested = 0,
  transfer_running = false,
  transfer_job = nil,
  transfer_cancel_requested = false,
  transfer_last_output = "",
  transfer_last_outputs = {},
  transfer_last_error = "",
  transfer_last_tail_ms = 0,
  transfer_last_summary = "",

  status = "准备就绪",
  status_error = false,

  config_dirty = false,
  db_dirty = false,
  last_save = 0,

  interaction_until = 0,
  focus_search = false,

  -- 图标说明不再使用 ImGui Tooltip 窗口。
  -- 每帧只登记一个待绘制提示，最后由主窗口 DrawList 统一绘制。
  tooltip_hover_text = nil,
  tooltip_hover_started_at = 0,
  tooltip_last_seen_at = 0,
  tooltip_delay = 0.40,
  tooltip_pending_text = nil,
  tooltip_pending_mouse_x = 0,
  tooltip_pending_mouse_y = 0,

  -- 菜单关闭后的下一帧再打开帮助窗口，避免与菜单 Popup 栈冲突。
  help_popup_requested = 0,

  theme_preset = "dark",
  custom_accent_hex = "#1F6FCC",
  custom_shell_hex = "#101114",

  language = "zh",
  mini_wave_points = MINI_WAVE_DEFAULT_POINTS,
  ui_density = "compact",
  surface_style = "dark",
  settings_tab = "general",
  settings_close_requested = false,

  waveform_hex = "#D7D8DA",
  waveform_selected_hex = "#EAF3FF",
  waveform_played_hex = "#8FB8D8",
  waveform_marked_hex = "#F0C85A",
  played_text_hex = "#F0C85A",
  played_text_enabled = true,
  played_waveform_enabled = false,
  selection_hex = "#2789E9",
  playhead_hex = "#50E36D",
  region_hex = "#E2B764",

  sidebar_visible = true,
  sidebar_sections = {
    sounds = true,
    libraries = true,
    ucs = true,
    collections = true,
    saved_searches = true,
    workflow = true,
    activity = true,
  },
  inspector_visible = true,
  inspector_width = INSPECTOR_DEFAULT_W,
  inspector_artwork_pinned = true,
  artwork_enabled = true,
  artwork_folder_cache = {},
  artwork_dimension_cache = {},
  artwork_images = {},
  artwork_image_order = {},
  artwork_image_limit = 96,
  artwork_queue = {},
  artwork_queued = {},
  artwork_reset_session = nil,
  artwork_next_job = 0,
  layout_notice = "",

  column_visible = {
    waveform = true,
    filename = true,
    status = true,
    description = true,
    artwork = false,
    duration = true,
    format = true,
    library = true,
    category = false,
    subcategory = false,
    catid = false,
    channels = false,
    sample_rate = false,
    bit_depth = false,
    path = false,
  },

  column_widths = {
    waveform = 350,
    filename = 265,
    status = 88,
    description = 320,
    artwork = 58,
    duration = 104,
    format = 118,
    library = 180,
    category = 140,
    subcategory = 150,
    catid = 90,
    channels = 80,
    sample_rate = 100,
    bit_depth = 90,
    path = 360,
  },

  column_drag = nil,

  metadata_editor = {
    signature = "",
    values = {},
    enabled = {},
    mixed = {},
  },
}

----------------------------------------------------------------
-- Localization
----------------------------------------------------------------

I18N_MISSING = {}
I18N_MISSING_UNIQUE = 0
I18N_MISSING_LIMIT = 256

I18N_EN = {
  ["音效库"] = "Libraries",
  ["传输"] = "Transfer",
  ["Transfer 导出"] = "Transfer export",
  ["Transfer 设置"] = "Transfer settings",
  ["处理、命名与导出"] = "Processing, naming and export",
  ["输出目录"] = "Output directory",
  ["输出目录:,extrawidth=420"] = "Output directory:,extrawidth=420",
  ["Transfer 使用独立目录，不修改源素材。"] = "Transfer uses an independent output directory and never modifies source media.",
  ["打开输出目录"] = "Open output directory",
  ["更改输出目录…"] = "Change output directory…",
  ["恢复默认输出目录"] = "Restore default output directory",
  ["命名模板"] = "Naming template",
  ["可用字段：{name} {category} {subcategory} {library} {index} {date} {region}"] = "Fields: {name} {category} {subcategory} {library} {index} {date} {region}",
  ["可用字段：{name} {category} {subcategory} {library} {index} {date} {region} {pitch} {rate} {gain} {direction} {variant} {variant_index}"] = "Fields: {name} {category} {subcategory} {library} {index} {date} {region} {pitch} {rate} {gain} {direction} {variant} {variant_index}",
  ["导出范围"] = "Export scope",
  ["当前选区"] = "Current selection",
  ["完整文件"] = "Full file",
  ["没有有效选区时自动使用完整文件"] = "Use the full file automatically when no valid selection exists",
  ["格式与范围"] = "Format and scope",
  ["当前素材可导出波形选区；批量导出始终使用每个完整文件。"] = "The current asset can export its waveform selection; batch export always uses each full file.",
  ["输出格式"] = "Output format",
  ["WAV · 16-bit"] = "WAV · 16-bit",
  ["WAV · 24-bit"] = "WAV · 24-bit",
  ["WAV · 32-bit PCM"] = "WAV · 32-bit PCM",
  ["WAV · 24-bit PCM"] = "WAV · 24-bit PCM",
  ["FLAC · REAPER 默认"] = "FLAC · REAPER default",
  ["采样率"] = "Sample rate",
  ["跟随源文件"] = "Source rate",
  ["声道"] = "Channels",
  ["跟随源声道"] = "Source channels",
  ["单声道"] = "Mono",
  ["立体声"] = "Stereo",
  ["尽可能保留源文件元数据"] = "Preserve source metadata when possible",
  ["启用抖动"] = "Enable dither",
  ["噪声整形"] = "Noise shaping",
  ["抖动主要用于降低到 16-bit；较高位深通常无需启用。"] = "Dither is mainly useful when reducing to 16-bit; higher bit depths usually do not need it.",
  ["当前位深保持抖动关闭；WAV 16-bit 可单独启用。"] = "Dither stays off at the current bit depth; it can be enabled separately for WAV 16-bit.",
  ["淡入"] = "Fade in",
  ["淡出"] = "Fade out",
  ["智能保留选区尾音"] = "Preserve selection tail intelligently",
  ["分析选区结束后的源音频，保留最后一个超过阈值的尾音，并受最大长度限制。"] = "Analyze source audio after the selection and keep the last tail above the threshold, limited by the maximum duration.",
  ["尾音阈值"] = "Tail threshold",
  ["最大尾音"] = "Maximum tail",
  ["尾音留白"] = "Tail hold",
  ["只延伸源文件中已有的尾音；Transfer 仍不经过工程轨道、发送或 Master FX。"] = "Only existing source-file tails are extended; Transfer still does not pass through project tracks, sends, or Master FX.",
  ["批量变体"] = "Batch variants",
  ["按 Pitch、Rate、Gain 与方向生成笛卡尔组合；每个参数最多 16 项，单素材最多 128 个变体。"] = "Generate Cartesian combinations of Pitch, Rate, Gain, and direction; up to 16 values per parameter and 128 variants per asset.",
  ["启用批量变体"] = "Enable batch variants",
  ["留空表示使用主界面当前值；可用逗号、空格或分号分隔。"] = "Leave blank to use the current main-view value; separate values with commas, spaces, or semicolons.",
  ["Pitch 列表"] = "Pitch values",
  ["Rate 列表"] = "Rate values",
  ["Gain 列表"] = "Gain values",
  ["当前参数"] = "Current values",
  ["Pitch ±3 / ±6"] = "Pitch ±3 / ±6",
  ["轻量变化"] = "Subtle variations",
  ["同时生成正向与反向"] = "Generate normal and reverse",
  ["模板未含变体字段时自动追加安全后缀"] = "Append a safe suffix when the template has no variant field",
  ["每个素材将生成"] = "Variants per asset:",
  ["变体设置无效"] = "Invalid variant settings",
  ["无效的变体数值"] = "Invalid variant value",
  ["每个变体参数最多允许 16 个数值"] = "Each variant parameter accepts at most 16 values",
  ["变体组合超过 128 个，请减少参数数量"] = "Variant combinations exceed 128; reduce the number of values",
  ["导出任务超过 4096 个，请减少素材或变体数量"] = "Export tasks exceed 4096; reduce the asset or variant count",
  ["反向变体需要安装 SWS Extension"] = "Reverse variants require SWS Extension",
  ["处理"] = "Processing",
  ["当前 Pitch、Rate、Gain、Reverse 与 Preserve Pitch 会写入导出文件。"] = "Current Pitch, Rate, Gain, Reverse, and Preserve Pitch settings are written into the exported file.",
  ["标准化"] = "Normalize",
  ["关闭标准化"] = "Off",
  ["Peak"] = "Peak",
  ["True Peak"] = "True Peak",
  ["RMS-I"] = "RMS-I",
  ["LUFS-I"] = "LUFS-I",
  ["目标值"] = "Target",
  ["重名策略"] = "Name collision",
  ["自动递增"] = "Increment",
  ["跳过已有文件"] = "Skip existing",
  ["允许覆盖"] = "Allow overwrite",
  ["完成行为"] = "Completion",
  ["自动递增是默认且最安全的重名策略。"] = "Increment is the default and safest collision policy.",
  ["文件名转为小写"] = "Lowercase filename",
  ["导出后插入 REAPER"] = "Insert into REAPER after export",
  ["导出完成后打开输出目录"] = "Open output directory after export",
  ["导出当前素材"] = "Export current asset",
  ["导出所选素材"] = "Export selected assets",
  ["打开 Transfer 面板"] = "Open Transfer panel",
  ["最近输出"] = "Latest output",
  ["尚未执行 Transfer"] = "No Transfer export yet",
  ["正在导出…"] = "Exporting…",
  ["请先选择素材"] = "Select an asset first",
  ["工程正在播放，停止后再执行 Transfer"] = "Stop project playback before running Transfer",
  ["请选择有效的输出目录"] = "Choose a valid output directory",
  ["无法创建输出目录"] = "Could not create output directory",
  ["Transfer 渲染失败"] = "Transfer render failed",
  ["已跳过已有文件："] = "Skipped existing file: ",
  ["Transfer 完成："] = "Transfer complete: ",
  ["Transfer 部分完成"] = "Transfer partially completed",
  ["正在导出"] = "Exporting",
  ["Transfer 完成"] = "Transfer complete",
  ["Transfer 已停止"] = "Transfer stopped",
  ["完成"] = "Completed",
  ["跳过"] = "Skipped",
  ["失败"] = "Failed",
  ["未知错误"] = "Unknown error",
  ["当前文件后停止"] = "Stop after current file",
  ["Transfer 已暂停：请停止工程播放"] = "Transfer paused: stop project playback to continue",
  ["打开任务报告目录"] = "Open report folder",
  ["目录不存在："] = "Folder does not exist: ",
  ["无法打开目录："] = "Could not open folder: ",
  ["未找到临时渲染文件"] = "Temporary render file was not found",
  ["无法创建临时渲染路径"] = "Could not create a temporary render path",
  ["无法创建安全覆盖备份"] = "Could not create a safe overwrite backup",
  ["无法备份原有文件"] = "Could not back up the existing file",
  ["输出提交失败，原文件保存在："] = "Output commit failed; the original file is preserved at: ",
  ["输出提交失败，原文件已恢复"] = "Output commit failed; the original file was restored",
  ["同名输出将使用安全替换：先完成临时渲染，再备份并替换原文件。是否继续？"] = "Existing outputs will use safe replacement: render a temporary file first, then back up and replace the original. Continue?",
  ["确认覆盖策略"] = "Confirm overwrite policy",
  ["覆盖现有文件？"] = "Overwrite existing file?",
  ["此操作会替换磁盘上的同名文件："] = "This will replace the existing file on disk: ",
  ["选择 Transfer 输出目录"] = "Choose Transfer output directory",
  ["输出目录没有变化"] = "Output directory was not changed",
  ["已更新 Transfer 输出目录"] = "Transfer output directory updated",
  ["Transfer 只处理源素材与当前 Pitch / Rate / Gain / Reverse / Preserve Pitch，不经过工程轨道或 Master FX。"] = "Transfer processes the source with the current Pitch, Rate, Gain, Reverse, and Preserve Pitch settings and does not pass through project tracks or Master FX.",
  ["试听"] = "Preview",
  ["视图"] = "View",
  ["集合"] = "Collections",
  ["帮助"] = "Help",
  ["未标记"] = "Unmarked",
  ["候选"] = "Candidate",
  ["已采用"] = "Approved",
  ["采用"] = "Approved",
  ["已排除"] = "Rejected",
  ["排除"] = "Rejected",
  ["准备就绪"] = "Ready",
  ["名称:"] = "Name:",
  ["根目录路径:"] = "Root folder:",
  ["新建项目素材箱"] = "New project bin",
  ["新建播放列表"] = "New playlist",
  ["当前项目"] = "Current project",
  ["新播放列表"] = "New playlist",
  ["项目素材箱"] = "Project bin",
  ["播放列表"] = "Playlist",
  ["重命名集合"] = "Rename collection",
  ["保存当前搜索"] = "Save current search",
  ["新搜索"] = "New search",
  ["重命名保存搜索"] = "Rename saved search",
  ["拖到 REAPER 编排区"] = "Drag to the REAPER arrange view",
  ["管理音效库"] = "Manage libraries",
  ["音效库根目录"] = "Library roots",
  ["尚未添加音效库"] = "No libraries added",
  ["打开"] = "Open",
  ["重建"] = "Rebuild",
  ["删除"] = "Remove",
  ["关闭"] = "Close",
  ["添加根目录…"] = "Add root folder…",
  ["增量扫描"] = "Incremental scan",
  ["静默后台检查（仅显示工具栏动态状态）"] =
    "Silent background checks (toolbar activity only)",
  ["清空波形缓存"] = "Clear waveform cache",
  ["选择后自动试听"] = "Auto-preview on selection",
  ["循环"] = "Loop",
  ["反向"] = "Reverse",
  ["左侧导航"] = "Left navigation",
  ["右侧元数据"] = "Right metadata",
  ["专注模式"] = "Focus mode",
  ["新建播放列表…"] = "New playlist…",
  ["新建项目素材箱…"] = "New project bin…",
  ["保存当前搜索…"] = "Save current search…",
  ["将所选加入当前集合"] = "Add selection to current collection",
  ["从当前集合移除所选"] = "Remove selection from current collection",
  ["使用说明与快捷键…"] = "User guide and shortcuts…",
  ["隐藏导航 <"] = "Hide navigation <",
  ["最近插入"] = "Recently inserted",
  ["试听历史"] = "Preview history",
  ["全部音效库"] = "All libraries",
  ["扫描此库"] = "Scan this library",
  ["打开目录"] = "Open folder",
  ["从 PsyReaSFX 删除"] = "Remove from PsyReaSFX",
  ["+ 添加音效库"] = "+ Add library",
  ["尚无播放列表或项目素材箱"] = "No playlists or project bins",
  ["加入当前所选素材"] = "Add current selection",
  ["从此集合移除所选素材"] = "Remove selected items",
  ["重命名"] = "Rename",
  ["+ 播放列表"] = "+ Playlist",
  ["+ 项目素材箱"] = "+ Project bin",
  ["尚无保存搜索"] = "No saved searches",
  ["空搜索"] = "Empty search",
  ["载入"] = "Load",
  ["用当前条件覆盖"] = "Overwrite with current filters",
  ["+ 保存当前搜索"] = "+ Save search",
  ["全部状态"] = "All statuses",
  ["导航"] = "Navigation",
  ["隐藏导航"] = "Hide navigation",
  ["显示导航"] = "Show navigation",
  ["元数据"] = "Metadata",
  ["隐藏元数据"] = "Hide metadata",
  ["显示元数据"] = "Show metadata",
  ["退出专注"] = "Exit focus",
  ["输入关键词或描述声音…  category:impact  status:candidate  -exclude"] =
    "Type keywords or describe a sound…  category:impact  status:candidate  -exclude",
  ["清空"] = "Clear",
  ["自动试听"] = "Auto Play",
  ["扫描"] = "Scan",
  ["设置"] = "Settings",
  ["名称"] = "Name",
  ["时长"] = "Duration",
  ["最近试听"] = "Recently previewed",
  ["← 全部素材"] = "← All sounds",
  ["加入所选"] = "Add selected",
  ["移除所选"] = "Remove selected",
  ["右键表头选择字段；拖动分隔线调整列宽；Shift+滚轮横向查看"] =
    "Right-click the header to choose fields; drag dividers to resize; Shift+wheel to pan horizontally",
  ["扫描中"] = "Scanning",
  ["准备下一项"] = "Preparing next item",
  ["检查现有缓存"] = "Checking existing cache",
  ["取消"] = "Cancel",
  ["显示字段"] = "Visible fields",
  ["重置全部列宽"] = "Reset all column widths",
  ["插入当前轨道"] = "Insert on current track",
  ["插入新轨道"] = "Insert on new track",
  ["启用 Enter / Ctrl+Enter 快速插入 REAPER"] =
    "Enable Enter / Ctrl+Enter shortcuts for inserting into REAPER",
  ["REAPER 插入快捷键"] = "REAPER insertion shortcuts",
  ["默认关闭，避免在搜索框确认文字时误插入素材。"] =
    "Off by default so confirming text in the search box cannot insert an asset accidentally.",
  ["按 BWF 时间戳插入"] = "Insert at BWF timestamp",
  ["所选素材分轨插入"] = "Insert selected items on separate tracks",
  ["工作流状态"] = "Workflow status",
  ["添加到集合"] = "Add to collection",
  ["从当前集合移除"] = "Remove from current collection",
  ["收藏全部所选"] = "Favorite all selected",
  ["取消收藏"] = "Remove favorite",
  ["收藏"] = "Favorite",
  ["重新读取元数据"] = "Reload metadata",
  ["复制完整路径"] = "Copy full path",
  ["在资源管理器中显示"] = "Show in file explorer",
  ["波形不可用"] = "Waveform unavailable",
  ["返回全部素材"] = "Back to all sounds",
  ["打开左侧导航"] = "Open left navigation",
  ["选择一个音频查看波形和试听控制。"] =
    "Select an audio file to view its waveform and preview controls.",
  ["读取中"] = "Loading",
  ["↗ 拖拽当前选区到 REAPER 编排区"] =
    "↗ Drag current selection to the REAPER arrange view",
  ["↗ 拖拽完整文件到 REAPER 编排区"] =
    "↗ Drag full file to the REAPER arrange view",
  ["大波形：单击定位试听；拖动建立选区；Alt+拖动也可拖出"] =
    "Large waveform: click to seek; drag to select; Alt-drag to transfer",
  ["■ 停止"] = "■ Stop",
  ["▶ 试听选区"] = "▶ Preview selection",
  ["▶ 播放"] = "▶ Play",
  ["插入"] = "Insert",
  ["插入新轨"] = "Insert new track",
  ["BWF 插入"] = "BWF insert",
  ["★ 已收藏"] = "★ Favorited",
  ["☆ 收藏"] = "☆ Favorite",
  ["清除选区"] = "Clear selection",
  ["定位文件"] = "Reveal file",
  ["保留音高"] = "Preserve pitch",
  ["完整文件"] = "Full file",
  ["隐藏元数据 >"] = "Hide metadata >",
  ["选择一个或多个素材后，可在这里查看并编辑 PsyReaSFX 数据库元数据。"] =
    "Select one or more files to view and edit PsyReaSFX database metadata.",
  ["应用到所选素材"] = "Apply to selected files",
  ["保存元数据"] = "Save metadata",
  ["按 Category 筛选"] = "Filter by Category",
  ["按 Library 筛选"] = "Filter by Library",
  ["复制路径"] = "Copy path",
  ["PsyReaSFX 使用说明"] = "PsyReaSFX user guide",
  ["自定义强调色 #RRGGBB"] = "Custom accent #RRGGBB",
  ["应用自定义"] = "Apply custom color",
  ["显示左侧导航"] = "Show left navigation",
  ["显示右侧元数据面板"] = "Show right metadata panel",
  ["元数据面板宽度"] = "Metadata panel width",
  ["插入命名"] = "Insert naming",
  ["前缀"] = "Prefix",
  ["后缀"] = "Suffix",
  ["Take 名称转为小写"] = "Lowercase take names",
  ["插入淡化"] = "Insert fades",
  ["重置界面设置"] = "Reset interface settings",
  ["开发阶段维护"] = "Development maintenance",
  ["重建数据库"] = "Rebuild database",
  ["恢复出厂"] = "Factory reset",
  ["保存并关闭"] = "Save and close",
  ["语言"] = "Language",
  ["中文"] = "Chinese",
  ["界面密度"] = "Interface density",
  ["舒适"] = "Comfortable",
  ["标准"] = "Balanced",
  ["紧凑"] = "Compact",
  ["层级风格"] = "Surface style",
  ["扁平"] = "Flat",
  ["分层"] = "Layered",
  ["高对比"] = "High contrast",
  ["预览控制台"] = "Preview console",
  ["轻量工具条"] = "Studio strip",
  ["独立显示各声道"] = "Show separate channel lanes",
  ["立体声显示 L / R；多声道显示 CH 1–8。仅高精度大波形使用独立声道缓存。"] =
    "Stereo uses L / R lanes; multichannel files use CH 1–8. Separate-channel caching is used only by the high-resolution preview.",
  ["完整"] = "Full",
  ["专注"] = "Focused",
  ["极简"] = "Minimal",
  ["密度会实际改变列表行高、表头、图标、参数卡片、间距和圆角。"] =
    "Density changes row height, headers, icons, parameter cards, spacing and rounding.",
  ["扁平减少卡片边界；分层保留模块层级；高对比强化表头、网格和选中状态。"] =
    "Flat reduces card separation; Layered preserves hierarchy; High Contrast strengthens headers, grids and selection.",
  ["完整显示所有试听开关；专注隐藏低频开关；极简只保留拖放、播放、插入和更多操作。"] =
    "Full shows all preview toggles; Focused hides low-frequency toggles; Minimal keeps drag, play, insert and More Actions.",
  ["波形与缓存"] = "Waveforms and cache",
  ["列表波形精度"] = "List waveform resolution",
  ["高精度预缓存"] = "High-resolution precache",
  ["预缓存全部音效库"] = "Precache all libraries",
  ["预缓存当前音效库"] = "Precache current library",
  ["停止预缓存"] = "Stop precache",
  ["瞬态检测设置"] = "Transient detection settings",
  ["阈值"] = "Threshold",
  ["平滑时间"] = "Smoothing time",
  ["最大 Region 数"] = "Maximum regions",
  ["替换已有瞬态建议"] = "Replace existing transient suggestions",
  ["开始检测"] = "Start detection",
  ["取消待检测"] = "Cancel pending detection",
  ["撤销上次检测"] = "Undo last detection",
  ["清除全部瞬态建议"] = "Clear all transient suggestions",
  ["响度显示"] = "Loudness display",
  ["显示响度统计"] = "Show loudness statistics",
  ["重新分析当前素材"] = "Reanalyze current file",
  ["拖出选区"] = "Drag selection",
  ["常规"] = "General",
  ["外观"] = "Appearance",
  ["波形"] = "Waveforms",
  ["维护"] = "Maintenance",
  ["全部"] = "All",
  ["当前库"] = "Current library",
  ["隐藏导航栏"] = "Hide navigation",
  ["显示导航栏"] = "Show navigation",
  ["隐藏元数据面板"] = "Hide metadata panel",
  ["显示元数据面板"] = "Show metadata panel",
  ["进入专注模式"] = "Enter focus mode",
  ["退出专注模式"] = "Exit focus mode",
  ["清空搜索"] = "Clear search",
  ["开启自动试听"] = "Enable auto-preview",
  ["关闭自动试听"] = "Disable auto-preview",
  ["打开设置"] = "Open settings",
  ["使用说明与快捷键"] = "User guide and shortcuts",
  ["后台与浏览"] = "Background & browsing",
  ["控制素材目录的定时增量检查。手动扫描仍可使用 Ctrl+R 或主界面刷新按钮。"] =
    "Control periodic incremental checks of source folders. Manual scans remain available with Ctrl+R or the main refresh button.",
  ["启用 Watch Folder"] = "Enable Watch Folder",
  ["检查间隔"] = "Check interval",
  ["启动时恢复中断的扫描"] = "Resume interrupted scan on startup",
  ["可靠性与恢复"] = "Reliability and recovery",
  ["失败任务、数据备份和缓存检查均不修改源音频。"] =
    "Failed-task recovery, data backups, and cache verification never modify source audio.",
  ["当前没有待处理的失败任务。"] = "There are no failed tasks to process.",
  ["重试全部失败任务"] = "Retry all failed tasks",
  ["清除失败记录"] = "Clear failure records",
  ["失败任务记录已清除"] = "Failure records cleared",
  ["每天自动备份一次数据"] = "Back up data once per day",
  ["保留备份数量"] = "Backups to keep",
  ["立即创建备份"] = "Create backup now",
  ["打开备份目录"] = "Open backup folder",
  ["恢复最近备份…"] = "Restore latest backup…",
  ["检查波形缓存完整性"] = "Verify waveform cache",
  ["损坏缓存会移入 cache_quarantine；需要时可从源音频重新生成。"] =
    "Corrupt cache files are moved to cache_quarantine and can be rebuilt from source audio.",
  ["请等待当前后台任务完成"] = "Wait for the current background task to finish",
  ["波形缓存检查已经在运行"] = "Waveform cache verification is already running",
  ["无法保存失败任务"] = "Unable to save failed tasks",
  ["Region 数据"] = "Region data",
  ["响度缓存"] = "loudness cache",
  ["失败任务"] = "failed tasks",
  ["没有可重试的失败任务"] = "There are no failed tasks that can be retried",
  ["无法创建数据备份目录"] = "Unable to create the data-backup folder",
  ["没有可备份的数据文件"] = "There are no data files to back up",
  ["无法完整创建数据备份"] = "Unable to create a complete data backup",
  ["没有可恢复的数据备份"] = "There is no data backup to restore",
  ["备份中没有可恢复的数据"] = "The backup contains no restorable data",
  ["备份恢复失败，原数据已回滚"] = "Backup restore failed; the original data was rolled back",
  ["备份恢复未能完整提交，请重启 PsyReaSFX"] = "Backup restore could not be committed completely; restart PsyReaSFX",
  ["拖拽到 REAPER 编排区"] = "Drag to the REAPER arrange view",
  ["播放或停止"] = "Play or stop",
  ["收藏或取消收藏"] = "Toggle favorite",
  ["标记或取消标记"] = "Toggle mark",
  ["标记"] = "Mark",
  ["取消标记"] = "Remove mark",
  ["标记全部所选"] = "Mark all selected",
  ["取消标记全部所选"] = "Unmark all selected",
  ["已标记所选素材"] = "Selected files marked",
  ["已取消所选素材标记"] = "Selected file marks removed",
  ["重置波形缩放"] = "Reset waveform zoom",
  ["预览参数预设"] = "Preview parameter presets",
  ["循环试听"] = "Loop preview",
  ["反向试听"] = "Reverse preview",
  ["选区完成后自动循环"] = "Loop selection automatically",
  ["右键擦播"] = "Right-button scrub",
  ["鼠标滚轮缩放；Shift+滚轮或中键拖动平移；双击重置；右键拖动擦播"] =
    "Wheel: zoom; Shift+wheel or middle-drag: pan; double-click: reset; right-drag: scrub",
  ["拖动或滚轮调整；双击数值输入；双击标签或滑轨恢复默认值"] =
    "Drag or use the wheel; double-click the value to type; double-click the label or track to reset",
  ["缩放与擦播"] = "Zoom and scrub",
  ["自动循环选区"] = "Auto-loop selection",
  ["启用右键擦播"] = "Enable right-button scrub",
  ["试听预设"] = "Preview presets",
  ["音高预设"] = "Pitch presets",
  ["速度预设"] = "Rate presets",
  ["更多操作"] = "More actions",
  ["参数控制"] = "Parameter controls",
  ["主要操作"] = "Primary actions",
  ["波形颜色"] = "Waveform color",
  ["普通波形"] = "Normal waveform",
  ["选中波形"] = "Selected waveform",
  ["已播放波形"] = "Played waveform",
  ["已标记波形"] = "Marked waveform",
  ["选区颜色"] = "Selection color",
  ["播放指针颜色"] = "Playhead color",
  ["Region 颜色"] = "Region color",
  ["应用波形配色"] = "Apply waveform colors",
  ["恢复默认波形配色"] = "Reset waveform colors",
  ["显示优先级：选中 > 已标记 > 已播放 > 普通。标记使用 M 快捷键。"] =
    "Priority: Selected > Marked > Played > Normal. Use M to mark.",
  ["其他：F 收藏；M 标记；L 循环；Ctrl+F 搜索；Ctrl+R 扫描；Ctrl+T Transfer。"] =
    "Other: F favorite; M mark; L loop; Ctrl+F search; Ctrl+R scan; Ctrl+T Transfer.",
  ["声道监听"] = "Channel audition",
  ["声道选择"] = "Channel selection",
  ["全部声道"] = "All channels",
  ["全选声道"] = "Select all channels",
  ["已选声道"] = "Selected channels",
  ["立体声"] = "Stereo",
  ["多声道"] = "Multichannel",
  ["左键切换监听模式；右键打开完整声道选项"] =
    "Left-click to cycle audition modes; right-click for all channel options",
  ["左键切换监听模式；右键恢复立体声"] =
    "Left-click to cycle audition modes; right-click restores Stereo",
  ["左键打开声道选择；右键查看说明与重置"] =
    "Left-click to choose channels; right-click for help and reset",
  ["左键展开或收起声道条；右键恢复全部声道"] =
    "Left-click to expand or collapse the channel rail; right-click restores all channels",
  ["声道条"] = "Channel rail",
  ["右键聚焦此声道波形"] = "Right-click to focus this waveform lane",
  ["已聚焦声道波形；音频仍遵循 REAPER 多声道设备路由"] =
    "Waveform lane focused; audio still follows REAPER's multichannel device routing",
  ["Ctrl+单击追加或取消；Shift+单击连续选择；Ctrl+A 全选。"] =
    "Ctrl-click toggles channels; Shift-click selects a range; Ctrl+A selects all.",
  ["当前 SWS 预览接口不能隔离任意多声道源声道；选择会实时更新波形显示，试听仍遵循 REAPER 的多声道输出路由。"] =
    "The current SWS preview API cannot isolate arbitrary multichannel source lanes. Selection updates the waveform immediately; audition still follows REAPER's multichannel output routing.",
  ["无法建立双声道监听镜像"] = "Could not create the centered audition mirror",
  ["恢复全部声道"] = "Restore all channels",
  ["原始"] = "Original",
  ["左声道"] = "Left",
  ["右声道"] = "Right",
  ["单声道"] = "Mono",
  ["估算响度匹配"] = "Estimated loudness match",
  ["目标响度"] = "Target level",
  ["保存当前选区为 Region"] = "Save selection as region",
  ["Region 列表"] = "Region list",
  ["检测瞬态"] = "Detect transients",
  ["删除 Region"] = "Delete region",
  ["没有保存的 Region"] = "No saved regions",
  ["下方面板高度"] = "Bottom panel height",
  ["Artwork"] = "Artwork",
  ["封面"] = "Artwork",
  ["选择封面"] = "Choose artwork",
  ["清除封面"] = "Clear artwork",
  ["自动查找封面"] = "Auto-detect artwork",
  ["选择音效库封面"] = "Choose library artwork",
  ["选择音效库封面…"] = "Choose library artwork…",
  ["重新自动查找封面"] = "Auto-detect library artwork again",
  ["选择来源路径封面"] = "Choose source-folder artwork",
  ["指定此来源封面…"] = "Choose artwork for this source…",
  ["重新自动查找此来源封面"] = "Auto-detect artwork for this source again",
  ["清除此来源封面"] = "Clear artwork for this source",
  ["已设置来源路径封面："] = "Source-folder artwork set: ",
  ["将重新查找来源路径封面："] = "Source-folder artwork will be rediscovered: ",
  ["已清除来源路径封面："] = "Source-folder artwork cleared: ",
  ["已播放文字"] = "Played text",
  ["已播放文字高亮"] = "Highlight played text",
  ["已播放波形高亮"] = "Highlight played waveform",
  ["清除本次已播放高亮"] = "Clear current played highlights",
  ["恢复上次浏览高亮"] = "Restore previous browsing highlights",
  ["清除已保存浏览记录"] = "Clear saved browsing highlights",
  ["启动时自动恢复上次浏览高亮"] = "Restore previous browsing highlights on startup",
  ["当前高亮"] = "Current highlights",
  ["上次记录"] = "Previous session",
  ["没有可恢复的上次浏览记录"] = "No previous browsing highlights to restore",
  ["已恢复上次浏览高亮"] = "Previous browsing highlights restored",
  ["已清除已保存浏览记录"] = "Saved browsing highlights cleared",
  ["无法保存上次浏览高亮"] = "Unable to save previous browsing highlights",
  ["当前高亮与上次浏览快照分开管理；完整试听历史不会被删除。"] =
    "Current highlights and the previous-session snapshot are managed separately; full preview history is preserved.",
  ["界面预设"] = "Interface presets",
  ["统一界面"] = "Unified interface",
  ["PsyReaSFX 现在只维护一套紧凑、扁平且自适应的正式布局。字段与左右面板仍可自由调整。"] =
    "PsyReaSFX now maintains one compact, flat, responsive interface. Columns and side panels remain customizable.",
  ["恢复统一界面"] = "Restore unified interface",
  ["重置为默认字段"] = "Reset to default fields",
  ["已恢复默认字段布局"] = "Default field layout restored",
  ["调整下方大波形与试听区域的高度。"] =
    "Adjust the height of the detailed waveform and audition area.",
  ["浏览与工作区"] = "Browsing & workspace",
  ["颜色与状态"] = "Colors & states",
  ["点击打开色盘"] = "Click to open the color picker",
  ["封面与元数据"] = "Artwork & metadata",
  ["设置中心"] = "Settings",
  ["关于"] = "About",
  ["产品、版本与运行环境"] = "Product, version and runtime",
  ["关于 PsyReaSFX"] = "About PsyReaSFX",
  ["REAPER 音效资产浏览、试听与整理工具"] = "Sound-effects browsing, audition and asset-management tool for REAPER",
  ["音效资产井然有序"] = "Sound assets organized",
  ["浏览 · 整理 · 试听"] = "Browse · Organize · Preview",
  ["版本"] = "Version",
  ["作者"] = "Author",
  ["发布阶段"] = "Release stage",
  ["0.6 稳定化"] = "0.6 stabilization",
  ["0.6 稳定候选"] = "0.6 stable candidate",
  ["更改波形缓存目录"] = "Change waveform cache directory",
  ["新缓存目录路径:"] = "New cache directory path:",
  ["波形缓存目录"] = "Waveform cache directory",
  ["当前缓存目录"] = "Current cache directory",
  ["更改缓存目录…"] = "Change cache directory…",
  ["打开缓存目录"] = "Open cache directory",
  ["恢复默认目录"] = "Restore default directory",
  ["维护操作"] = "Maintenance actions",
  ["环境、缓存与重建"] = "Environment, cache and rebuild",
  ["版本、版权与项目主页"] = "Version, copyright and project page",
  ["GitHub 项目主页 ↗"] = "GitHub project page ↗",
  ["GitHub 项目主页 · 待配置"] = "GitHub project page · not configured",
  ["运行环境"] = "Runtime environment",
  ["REAPER 版本"] = "REAPER version",
  ["操作系统"] = "Operating system",
  ["ReaImGui"] = "ReaImGui",
  ["SWS Extension"] = "SWS Extension",
  ["已检测"] = "Detected",
  ["未检测"] = "Not detected",
  ["试听后端"] = "Preview backend",
  ["数据目录"] = "Data directory",
  ["文档目录"] = "Documentation directory",
  ["打开数据目录"] = "Open data directory",
  ["打开文档目录"] = "Open documentation directory",
  ["复制诊断信息"] = "Copy diagnostics",
  ["诊断信息已复制"] = "Diagnostics copied",
  ["项目与支持"] = "Project and support",
  ["许可"] = "License",
  ["尚未指定"] = "Not specified",
  ["网站"] = "Website",
  ["尚未配置"] = "Not configured",
  ["支持联系"] = "Support contact",
  ["在 1.0 发布前建议补充许可、版权主体、官方网站与支持联系方式。"] = "Before 1.0, add the license, copyright holder, official website and support contact.",
  ["点击色块打开色盘；选择后即时生效。"] = "Click a swatch to open the color picker; changes apply immediately.",
  ["恢复"] = "Reset",
  ["强调色"] = "Accent color",
  ["颜色"] = "Color",
  ["语言、面板与插入"] = "Language, panels and insertion",
  ["预设、颜色与 Artwork"] = "Presets, colors and Artwork",
  ["精度、瞬态与响度"] = "Resolution, transients and loudness",
  ["缓存、重建与重置"] = "Cache, rebuild and reset",
  ["颜色在下方“波形配色”中通过色盘选择，并即时生效。"] = "Choose the color below under Waveform colors; changes apply immediately.",
  ["用于故障排查和兼容性确认。"] = "For troubleshooting and compatibility checks.",
  ["正式发布前需要补齐的软件身份与支持信息。"] = "Software identity and support information to complete before release.",
  ["文档目录不存在："] = "Documentation directory not found: ",
  ["版本、扩展和路径信息集中放在此处，便于故障排查。"] =
    "Version, extensions, and path information are collected here for troubleshooting.",
  ["波形缓存"] = "Waveform cache",
  ["可以迁移已有缓存，或切换到新的空目录。源音频不会被移动。"] =
    "Move the existing cache or switch to a new empty folder. Source audio is never moved.",
  ["默认："] = "Default: ",
  ["重建和重置不会删除硬盘中的源音频文件。"] =
    "Rebuild and reset actions do not delete source audio files from disk.",
  ["重建数据库会保留音效库路径并重新扫描；恢复出厂会删除 PsyReaSFX 的配置、集合、历史、索引和当前缓存，但不会删除源音频文件。"] =
    "Rebuilding keeps library paths and rescans them. Factory reset removes PsyReaSFX settings, collections, history, indexes, and the current cache, but never deletes source audio.",
  ["预设会同时调整密度、表面层级、列表字段与预览控制台。"] =
    "Presets adjust density, surface hierarchy, visible columns, and the preview console together.",
  ["单行高密度列表、Artwork、时长与扁平表面。"] =
    "Dense single-line rows with Artwork, duration, and flat surfaces.",
  ["平衡密度、分层模块与轻量预览工具条。"] =
    "Balanced density, layered modules, and a lightweight preview strip.",
  ["更大行高、高对比与完整元数据字段。"] =
    "Larger rows, stronger contrast, and the complete metadata field set.",
  ["这些选项会直接改变列表信息密度和底部控制区。"] =
    "These options directly change result density and the bottom control area.",
  ["表面层级"] = "Surface hierarchy",
  ["Artwork 只在可见行或当前选中素材中按需加载。"] =
    "Artwork loads on demand only for visible rows and the selected file.",
  ["启用 Artwork"] = "Enable Artwork",
  ["元数据封面固定在顶部"] = "Pin metadata Artwork at the top",
  ["清空 Artwork 缓存"] = "Clear Artwork cache",
  ["界面主题"] = "Interface theme",
  ["主题决定强调色；波形和已播放文字可单独配置。"] =
    "The theme controls the accent; waveform and played-text colors remain independently configurable.",
  ["外观模式"] = "Appearance mode",
  ["黑暗模式"] = "Dark mode",
  ["传统模式"] = "Heritage mode",
  ["黑暗模式为默认；传统模式使用更深的品牌藏蓝。"] =
    "Dark mode is the default; Heritage mode uses a deeper brand navy.",
  ["原有的中性黑色工作区，作为默认外观。"] =
    "The original neutral-black workspace, used as the default appearance.",
  ["更深的藏蓝框架与 Electric Cyan 品牌强调色。"] =
    "A deeper navy shell with the Electric Cyan brand accent.",
  ["当前模式："] = "Current mode: ",
  ["自定义"] = "Custom",
  ["自定义颜色"] = "Custom colors",
  ["框架底色"] = "Frame base color",
  ["选择一个底色后，面板、表头、悬停、边框与波形背景会自动生成层级。"] =
    "Choose one base color and PsyReaSFX will derive panels, headers, hover states, borders, and the waveform background.",
  ["波形配色"] = "Waveform palette",
  ["普通、选中、已播放、标记、选区、播放指针与 Region。"] =
    "Normal, selected, played, marked, selection, playhead, and Region colors.",
  ["256 点是默认值，较旧版本的 128 点至少提升一倍；512 点适合较宽的 Waveform 列。"] =
    "256 points is the default and doubles the older 128-point resolution; 512 points suits wider Waveform columns.",
  ["预缓存会逐个处理素材并写入磁盘缓存。处理会在鼠标交互时让步，不会把整库高精度波形同时保存在内存中。"] =
    "Precache processes files one at a time and writes to disk. It yields during mouse interaction and never holds an entire library of high-resolution waveforms in memory.",
  ["最小间隔"] = "Minimum gap",
  ["Region 前置"] = "Region pre-roll",
  ["Region 后置"] = "Region post-roll",
  ["使用 REAPER CalculateNormalization 按需计算；结果写入 loudness_v1.tsv。"] =
    "Calculated on demand with REAPER CalculateNormalization and cached in loudness_v1.tsv.",
  ["响度匹配仍使用快速波形估算，仅影响试听；上方显示值使用 REAPER 精确响度计算。"] =
    "Loudness matching uses a fast waveform estimate and affects preview only; displayed metrics use REAPER's precise loudness calculation.",
  ["256 点：缓存较小；512 点：细节更多。"] =
    "256 points uses less cache; 512 points shows more detail.",
  ["立体声显示 L / R；多声道显示 CH 1–8。"] =
    "Stereo uses L / R; multichannel files use CH 1–8.",
  ["频谱峰值着色"] = "Spectral peak coloring",
  ["当前素材显示频谱峰值着色"] =
    "Show spectral peak coloring for the current file",
  ["按需读取 REAPER 频谱峰值；只影响下方大波形，不扫描整个音效库。"] =
    "Read REAPER spectral peaks on demand for the detailed waveform only; the full library is not scanned.",
  ["可在首次浏览大型库前预先生成高精度波形。"] =
    "Generate high-resolution waveforms before the first large-library browse.",
  ["仅影响试听，不修改源文件，也不用于交付标准化。"] =
    "Preview only; source files and delivery normalization are unchanged.",
  ["自动检查来源文件夹变化。"] =
    "Automatically check source folders for changes.",
  ["底色控制整体框架，强调色用于选择与交互。"] =
    "The base color controls the workspace; the accent marks selection and interaction.",
  ["可以移动已有缓存，源音频不受影响。"] =
    "Existing cache files can be moved; source audio is unaffected.",
  ["启用估算响度匹配"] = "Enable estimated loudness matching",
  ["没有结果。添加音效库、扫描或修改搜索词。"] =
    "No results. Add a library, scan, or change the search query.",
  ["当前集合为空："] = "This collection is empty: ",
  ["新建集合不会删除或移动原始音效库。返回全部素材后选择声音，再使用右键菜单或“加入所选”添加到集合。"] =
    "Creating a collection does not delete or move source libraries. Return to All sounds, select files, then use the context menu or Add selected.",
  ["等待"] = "Waiting",
  ["分析中…"] = "Analyzing…",
  ["扫描完成"] = "Scan complete",
  ["首次扫描"] = "Initial scan",
  ["恢复未完成导入"] = "Resume incomplete import",
  ["添加音效库"] = "Add library",
  ["拖到 REAPER 编排区需要 SWS Extension"] =
    "Dragging to the REAPER arrange view requires SWS Extension",
  ["未安装 SWS：Media Explorer 无法由脚本精确定位到点击位置"] =
    "SWS is not installed: Media Explorer cannot seek precisely to the clicked position",
  ["重新分析当前素材响度"] = "Reanalyze current-file loudness",
  ["[项目] "] = "[Project] ",
  ["波形缓存目录没有变化"] = "Waveform cache directory was not changed",
  ["新旧缓存目录不能互相嵌套"] = "The old and new cache folders cannot contain one another",
  ["已切换波形缓存目录；旧缓存仍保留"] = "Waveform cache directory changed; the old cache was kept",
  ["当前已经使用默认缓存目录"] = "The default cache directory is already in use",
  ["请先在大波形中建立有效选区"] = "Create a valid selection in the large waveform first",
  ["Region 已保存"] = "Region saved",
  ["该 Region 已存在或选区无效"] = "This Region already exists or the selection is invalid",
  ["Region 已删除"] = "Region deleted",
  ["没有可撤销的瞬态检测结果"] = "There is no transient-detection result to undo",
  ["当前素材没有瞬态 Region 建议"] = "The current file has no transient Region suggestions",
  ["正在准备高精度波形并检测瞬态…"] = "Preparing a high-resolution waveform and detecting transients…",
  ["已取消待执行的瞬态检测"] = "Pending transient detection canceled",
  ["素材时长不可用"] = "File duration is unavailable",
  ["未检测到超过当前阈值的瞬态"] = "No transients exceeded the current threshold",
  ["没有新增瞬态 Region"] = "No new transient Regions were created",
  ["已清空 Artwork 缓存；可见素材将重新查找封面"] =
    "Artwork cache cleared; Artwork will be rediscovered for visible files",
  ["请等待当前扫描或导入完成后再预缓存"] = "Wait for the current scan or import to finish before precaching",
  ["高精度波形预缓存已经在运行"] = "High-resolution waveform precache is already running",
  ["当前范围没有可预缓存的素材"] = "There are no files to precache in the current scope",
  ["已取消拖拽：请释放到 REAPER 编排区"] = "Drag canceled: release over the REAPER arrange view",
  ["目录不存在或无法访问："] = "Folder does not exist or cannot be accessed: ",
  ["已清除本次已播放高亮"] = "Current played highlights cleared",
  ["下方大波形单击定位，拖动建立并试听选区。"] =
    "Click the large waveform to seek; drag to create and preview a selection.",
  ["表头固定置顶；右键表头选择字段；拖动分隔线调整列宽；Shift+滚轮横向查看。"] =
    "The header remains pinned. Right-click it to choose fields, drag dividers to resize, and use Shift+wheel to pan horizontally.",
  ["列表：单击单选；Ctrl+单击追加或取消；"] =
    "List: click to select; Ctrl-click to add or remove;",
  ["Shift+单击连续选择；Ctrl+A 全选当前结果。"] =
    "Shift-click selects a range; Ctrl+A selects all current results.",
  ["试听：Space 播放或停止；点击列表小波形可从对应位置试听；"] =
    "Preview: Space plays or stops; click a list waveform to preview from that position;",
  ["插入：使用按钮或右键菜单；Enter 快速插入可在设置中启用。"] =
    "Insert: use the buttons or context menu; optional Enter shortcuts can be enabled in Settings.",
  ["列表素材和下方波形选区可拖到 REAPER 编排区。"] =
    "Drag result files or the lower waveform selection into the REAPER arrange view.",
  ["工作区：顶部“导航”“元数据”“专注模式”可折叠左右面板。"] =
    "Workspace: use Navigation, Metadata, and Focus mode at the top to collapse the side panels.",
  ["F9 切换左栏，F10 切换右栏，F11 切换专注模式。"] =
    "F9 toggles the left panel, F10 the right panel, and F11 Focus mode.",
  ["集合：可创建播放列表或项目素材箱。"] =
    "Collections: create playlists or project bins.",
  ["保存搜索：保存当前关键词、库筛选、状态筛选、集合和排序条件，"] =
    "Saved searches retain the current query, library, status, collection, and sort settings,",
  ["右键素材可加入集合、设置候选/已采用/已排除状态。"] =
    "Right-click files to add them to collections or set Candidate, Approved, or Rejected status.",
  ["瞬态检测"] = "Transient detection",
  ["瞬态 Region 建议"] = "Transient Region suggestions",
  ["阈值越低越敏感；平滑可抑制细碎尖峰；手动 Region 不会被替换。"] =
    "Lower thresholds are more sensitive; smoothing suppresses small spikes; manual Regions are never replaced.",
  ["PsyReaSFX：分轨插入多个素材"] = "PsyReaSFX: insert files on separate tracks",
  ["PsyReaSFX：拖拽素材到编排区"] = "PsyReaSFX: drag files to the arrange view",
  ["从 PsyReaSFX 插入音频"] = "Insert audio from PsyReaSFX",
  ["从 PsyReaSFX 中删除该音效库？"] = "Remove this library from PsyReaSFX?",
  ["删除 PsyReaSFX 集合？"] = "Delete this PsyReaSFX collection?",
  ["不会删除磁盘音频文件。"] = "Audio files on disk will not be deleted.",
  ["不会删除磁盘中的音频文件。"] = "Audio files on disk will not be deleted.",
  ["将清空 PsyReaSFX 数据库和波形缓存，然后重新扫描现有音效库。\n\n继续吗？"] =
    "This clears the PsyReaSFX database and waveform cache, then rescans existing libraries.\n\nContinue?",
  ["这会删除全部音效库路径、收藏、播放列表、保存搜索、历史、索引、波形缓存和界面设置。\n\n继续吗？"] =
    "This removes all library paths, favorites, playlists, saved searches, history, indexes, waveform cache, and interface settings.\n\nContinue?",
  ["是否将现有波形缓存移动到新目录？\n\n是：移动已有缓存并切换。\n否：直接切换，旧目录保持不变。\n取消：不修改。"] =
    "Move the existing waveform cache to the new folder?\n\nYes: move the cache and switch.\nNo: switch directly and keep the old folder.\nCancel: make no changes.",
  ["恢复默认缓存目录，并移动现有缓存？"] = "Restore the default cache directory and move the existing cache?",
  ["无法保存 Region 数据"] = "Unable to save Region data",
  ["无法保存响度缓存"] = "Unable to save loudness cache",
  ["索引快照代次无效，已进入只读保护"] =
    "The catalog snapshot generation is invalid; read-only protection is active",
  ["素材增量日志损坏，已进入只读保护"] =
    "The asset journal is damaged; read-only protection is active",
  ["已设置 Artwork"] = "Artwork set",
  ["瞬态检测设置…"] = "Transient detection settings…",
  ["拖到编排区需要 SWS Extension"] = "Dragging to the arrange view requires SWS Extension",
  ["保存搜索：保存当前关键词、库筛选、状态筛选、集合和排序条件，之后可从左栏一键恢复。"] =
    "Saved searches retain the current query, library, status, collection, and sort settings and can be restored from the left panel.",
}

I18N_PREFIX_EN = {
  ["已设置音效库封面："] = "Library artwork set: ",
  ["将重新查找音效库封面："] =
    "Library artwork will be rediscovered: ",
  ["已设置来源路径封面："] = "Source-folder artwork set: ",
  ["将重新查找来源路径封面："] =
    "Source-folder artwork will be rediscovered: ",
  ["已清除来源路径封面："] =
    "Source-folder artwork cleared: ",
  ["文档目录不存在："] = "Documentation directory not found: ",
  ["已迁移旧版音效库路径与偏好设置"] =
    "Migrated legacy library paths and preferences",
  ["无法保存配置"] = "Unable to save configuration",
  ["无法保存索引"] = "Unable to save database index",
  ["无法保存素材增量日志："] = "Unable to save the asset journal: ",
  ["无法保存播放列表"] = "Unable to save playlists",
  ["无法保存搜索条件"] = "Unable to save saved searches",
  ["无法保存试听历史"] = "Unable to save preview history",
  ["已恢复上次浏览高亮："] =
    "Restored previous browsing highlights: ",
  ["已重命名为："] = "Renamed to: ",
  ["已删除集合："] = "Deleted collection: ",
  ["已保存搜索："] = "Saved search: ",
  ["已载入搜索："] = "Loaded search: ",
  ["已删除保存搜索："] = "Deleted saved search: ",
  ["请先添加音效库根目录"] = "Add a library root folder first",
  ["没有可访问的音效库目录"] = "No accessible library folder",
  ["文件不可用"] = "File unavailable",
  ["无法建立媒体源"] = "Unable to create media source",
  ["无有效音频长度"] = "No valid audio duration",
  ["空任务"] = "Empty task",
  ["峰值读取为空"] = "No peak data returned",
  ["波形建立失败"] = "Waveform generation failed",
  ["已清空波形缓存"] = "Waveform cache cleared",
  ["已取消导入；已完成的素材保留"] =
    "Import canceled; completed files were retained",
  ["媒体文件无法读取"] = "Unable to read media file",
  ["文件不存在："] = "File not found: ",
  ["目录不存在或无法访问："] = "Folder does not exist or cannot be accessed: ",
  ["波形建立失败："] = "Waveform generation failed: ",
  ["已切换缓存目录："] = "Cache directory changed: ",
  ["当前集合为空："] = "This collection is empty: ",
  ["默认："] = "Default: ",
  ["扫描 "] = "Scan ",
  ["重建 "] = "Rebuild ",
  ["已更新保存搜索："] = "Updated saved search: ",
  ["已清空 Artwork 缓存；"] = "Artwork cache cleared; ",
  ["由 Media Explorer 试听"] = "Previewing through Media Explorer",
  ["无法建立试听源"] = "Unable to create preview source",
  ["SWS 试听对象创建失败"] = "Unable to create SWS preview object",
  ["试听启动失败"] = "Preview failed to start",
  ["试听："] = "Preview: ",
  ["已取消收藏："] = "Removed favorite: ",
  ["已收藏："] = "Favorited: ",
  ["已插入："] = "Inserted: ",
  ["插入失败："] = "Insert failed: ",
  ["已取消拖拽："] = "Drag canceled: ",
  ["无法取得放置时间位置"] = "Unable to determine drop time",
  ["该音效库已经存在"] = "This library already exists",
  ["已移除音效库："] = "Removed library: ",
  ["已重置界面与试听设置"] = "Interface and preview settings reset",
  ["数据库已清空；请添加音效库"] =
    "Database cleared; add a library",
  ["PsyReaSFX 已恢复出厂状态"] = "PsyReaSFX factory reset completed",
  ["已取消扫描"] = "Scan canceled",
  ["至少保留一个列表字段"] = "Keep at least one list field",
  ["已收藏所选素材"] = "Selected files favorited",
  ["已复制路径"] = "Path copied",
  ["元数据没有变化"] = "No metadata changes",
  ["自定义颜色格式应为 #RRGGBB"] =
    "Custom color must use #RRGGBB",
  ["已取消所选素材收藏"] =
    "Removed selected files from favorites",
  ["窗口较窄：右侧元数据面板已临时折叠"] =
    "Narrow window: right metadata panel temporarily collapsed",
  ["窗口较窄：左右面板已临时折叠"] =
    "Narrow window: side panels temporarily collapsed",
  ["预缓存完成"] = "Precache complete",
  ["已取消高精度波形预缓存"] =
    "High-resolution waveform precache canceled",
  ["新建音效库…"] = "New library…",
  ["逻辑音效库与来源路径"] = "Logical libraries and source folders",
  ["+ 新建音效库"] = "+ New library",
  ["添加来源路径…"] = "Add source folder…",
  ["添加路径"] = "Add folder",
  ["来源路径"] = "Source folder",
  ["展开全部音效库的文件夹结构"] =
    "Browse the folder hierarchy of all libraries",
  ["清除路径条件"] = "Clear path filter",
  ["文件夹层级"] = "Folder hierarchy",
  ["箭头展开；单击名称跳转并显示该目录及其子目录"] =
    "Use arrows to expand; click a name to show that folder and its descendants",
  ["正在建立目录索引…"] = "Building folder index…",
  ["折叠此层级"] = "Collapse this level",
  ["展开此层级"] = "Expand this level",
  ["浏览文件夹层级"] = "Browse folder hierarchy",
  ["悬停展开下级目录 · 点击定位"] =
    "Hover to expand folders · click to locate",
  ["显示全部音效库"] = "Show all libraries",
  ["显示此逻辑库的全部素材"] =
    "Show all assets in this logical library",
  ["显示此来源的全部素材"] =
    "Show all assets in this source folder",
  ["显示此目录及子目录"] =
    "Show this folder and its descendants",
  ["目录索引正在后台建立…"] =
    "The folder index is being built in the background…",
  ["扫描全部来源"] = "Scan all sources",
  ["扫描此来源"] = "Scan this source",
  ["移除来源路径"] = "Remove source folder",
  ["删除库"] = "Delete library",
  ["展开或折叠来源"] = "Expand or collapse sources",
  ["重命名音效库"] = "Rename library",
  ["新建逻辑音效库"] = "New logical library",
  ["导入多个文件夹##folder_drop"] = "Import multiple folders##folder_drop",
  ["导入多个文件夹"] = "Import multiple folders",
  ["请选择它们在音效库中的组织方式。"] =
    "Choose how these folders should be organized.",
  ["每个文件夹建立一个音效库"] = "Create one library per folder",
  ["合并为一个音效库…"] = "Combine into one library…",
  ["只建立索引，不移动或修改源文件"] =
    "Only indexes folders; source files are not moved or modified",
  ["释放以新建逻辑音效库"] = "Drop to create a logical library",
  ["目标音效库不存在"] = "Target library does not exist",
  ["已经存在同名音效库"] = "A library with this name already exists",
  ["无法保存音效库结构"] = "Unable to save library structure",
  ["已将旧音效库迁移为逻辑库与来源路径"] =
    "Migrated legacy libraries to logical libraries and source folders",
  ["该来源路径已经属于音效库："] =
    "This source folder already belongs to library: ",
  ["该文件夹已包含在来源路径中："] =
    "This folder is already covered by source: ",
  ["该文件夹会覆盖已有来源路径，请先移除或重新定位："] =
    "This folder would overlap an existing source; remove or relink it first: ",
  ["已移除来源路径："] = "Removed source folder: ",
  ["已移除逻辑音效库："] = "Removed logical library: ",
  ["已重命名音效库："] = "Renamed library: ",
  ["已新建空音效库："] = "Empty logical library created: ",
  ["已移动来源路径到音效库："] = "Moved source folder to library: ",
  ["该来源路径已经在当前音效库中"] =
    "This source folder is already in the current library",
  ["请拖入文件夹；音频文件不会作为来源路径导入"] =
    "Drop folders; individual audio files are not imported as sources",
}

I18N_EN["路径与离线来源"] = "Paths and offline sources"
I18N_EN["检查缺失文件，或在素材盘符和目录变化后重新定位来源；不会移动源文件。"] =
  "Check for missing files or relink a source after a drive or folder change. Source files are never moved."
I18N_EN["检查缺失文件"] = "Check missing files"
I18N_EN["查看缺失素材"] = "Show missing assets"
I18N_EN["重新定位来源路径…"] = "Relink source folder…"
I18N_EN["重新定位…"] = "Relink…"
I18N_EN["重复候选"] = "Duplicate candidates"
I18N_EN["仅对大小相同的文件读取头部、中部和尾部采样块；结果尚未经过完整内容确认，不会修改或删除源文件。"] =
  "Equal-size files are sampled at the beginning, middle and end. Results are not yet confirmed against complete contents; source files are never changed or deleted."
I18N_EN["检查重复候选"] = "Check candidates"
I18N_EN["查看重复候选"] = "Show candidates"
I18N_EN["完整确认候选"] = "Confirm full contents"
I18N_EN["正在逐字节确认重复候选"] = "Confirming candidate contents byte by byte"
I18N_EN["当前 REAPER 工程"] = "Current REAPER project"
I18N_EN["记录插入和 Transfer 后插入的素材，并可自动收集到绑定的项目素材箱。"] =
  "Tracks inserted assets, including Transfer inserts, and can collect them in a bound project bin."
I18N_EN["工程"] = "Project"
I18N_EN["未保存工程"] = "Unsaved project"
I18N_EN["自动将插入素材加入当前工程素材箱"] =
  "Automatically add inserted assets to the current project bin"
I18N_EN["请先保存当前 REAPER 工程，再建立绑定。"] =
  "Save the current REAPER project before creating a binding."
I18N_EN["创建并绑定当前工程素材箱"] = "Create and bind project bin"
I18N_EN["查看当前工程已用素材"] = "Show assets used by current project"
I18N_EN["绑定到当前 REAPER 工程"] = "Bind to current REAPER project"
I18N_EN["缺失素材"] = "Missing assets"
I18N_EN["当前工程已用"] = "Used by current project"
I18N_EN["来源已重定位"] = "Source relinked"
I18N_EN["请先保存当前 REAPER 工程，再绑定项目素材箱"] =
  "Save the current REAPER project before binding a project bin"
I18N_EN["无法保存工程使用记录"] = "Unable to save project usage history"
I18N_EN["UCS 分类"] = "UCS classification"
I18N_EN["先分帧预览现有库，再由你确认应用；人工分类不会被覆盖。"] =
  "Preview the existing catalog in frame-budgeted steps, then confirm before applying. Manual classifications are protected."
I18N_EN["预览现有库 UCS 分类"] = "Preview UCS classification"
I18N_EN["取消 UCS 任务"] = "Cancel UCS task"
I18N_EN["确认应用分类"] = "Apply classifications"
I18N_EN["丢弃预览"] = "Discard preview"
I18N_EN["查看 UCS 待确认素材"] = "Show UCS review queue"
I18N_EN["只更新 PsyReaSFX 索引，不改名、不移动、不回写源音频。"] =
  "Updates only the PsyReaSFX index; source audio is not renamed, moved, or rewritten."
I18N_EN["停止后保留已安全应用的部分，可重新预览继续。"] =
  "Safely applied records are retained after stopping; preview again to continue."
I18N_EN["只读保护下不能重分类现有素材"] =
  "Existing assets cannot be reclassified while read-only protection is active"
I18N_EN["分类规则已变化，请重新生成预览"] =
  "Classification rules changed; generate a new preview"
I18N_EN["素材库已变化，请重新生成 UCS 分类预览"] =
  "The catalog changed; generate a new UCS classification preview"
I18N_EN["UCS 分类预览已取消"] = "UCS classification preview canceled"
I18N_EN["已丢弃 UCS 分类预览"] = "UCS classification preview discarded"
I18N_EN["未分类"] = "Unclassified"
I18N_EN["UCS 目录"] = "UCS DIRECTORY"
I18N_EN["UCS 分类索引更新中…"] = "Updating UCS classification index…"
I18N_EN["尚无已分类素材"] = "No classified assets yet"
I18N_EN["前往维护页分类现有素材"] = "Classify existing assets in Maintenance"
I18N_EN["展开或折叠 UCS 分类"] = "Expand or collapse UCS category"
I18N_EN["展开或折叠 UCS 子分类"] = "Expand or collapse UCS subcategory"
I18N_EN["UCS 候选"] = "UCS candidates"
I18N_EN["根据文件名命中："] = "Filename evidence:"
I18N_EN["撤销上次 UCS 确认"] = "Undo last UCS confirmation"
I18N_EN["撤销此素材的 UCS 确认"] = "Undo this asset's UCS confirmation"
I18N_EN["没有可确认的 UCS 候选"] = "No UCS candidate is available to confirm"
I18N_EN["无法撤销 UCS 确认"] = "Unable to undo UCS confirmation"
I18N_EN["只读保护下不能修改 UCS 分类"] =
  "UCS classification cannot be changed in read-only mode"
I18N_EN["UCS 搜索提示"] = "UCS search suggestions"

I18N_PATTERNS_EN = {
  {
    "^已确认 UCS 分类：(.+)$",
    "UCS classification confirmed: %1",
  },
  {
    "^已撤销 UCS 确认：(.+)$",
    "UCS confirmation undone: %1",
  },
  {
    "^UCS 待确认  (%d+)$",
    "UCS review queue  %1",
  },
  {
    "^UCS (.-) · 分类器 (.-) · 当前待确认 (%d+)$",
    "UCS %1 · classifier %2 · review queue %3",
  },
  {
    "^正在预览 UCS 分类 (%d+) / (%d+) · 自动 (%d+) · 待确认 (%d+) · 人工保护 (%d+)$",
    "Previewing UCS classification %1 / %2 · auto %3 · pending %4 · manual protected %5",
  },
  {
    "^正在应用 UCS 分类 (%d+) / (%d+) · 自动 (%d+) · 待确认 (%d+) · 人工保护 (%d+)$",
    "Applying UCS classification %1 / %2 · auto %3 · pending %4 · manual protected %5",
  },
  {
    "^预览完成：可更新 (%d+) · 精确 (%d+) · 自动 (%d+) · 待确认 (%d+) · 未分类 (%d+) · 人工保护 (%d+)$",
    "Preview complete: %1 updates · exact %2 · auto %3 · pending %4 · unclassified %5 · manual protected %6",
  },
  {
    "^共检查 (%d+) 条，耗时 ([%d%.]+) 秒；应用前不会修改数据库。$",
    "Checked %1 records in %2 seconds; the database remains unchanged until apply.",
  },
  {
    "^正在预览 UCS 分类：(%d+) / (%d+)$",
    "Previewing UCS classification: %1 / %2",
  },
  {
    "^正在应用 UCS 分类：(%d+) / (%d+)$",
    "Applying UCS classification: %1 / %2",
  },
  {
    "^UCS 分类预览完成：可更新 (%d+)，待确认 (%d+)，人工保护 (%d+)$",
    "UCS preview complete: %1 updates, %2 pending, %3 manual records protected",
  },
  {
    "^UCS 分类已应用：更新 (%d+)，待确认 (%d+)$",
    "UCS classification applied: %1 updated, %2 pending",
  },
  {
    "^UCS 分类已停止：已安全应用 (%d+)，可重新预览继续$",
    "UCS classification stopped: %1 safely applied; preview again to continue",
  },
  {
    "^无法后台保存Region 数据：(.+)$",
    "Unable to save Region data: %1",
  },
  {
    "^无法后台保存响度缓存：(.+)$",
    "Unable to save loudness cache: %1",
  },
  {
    "^无法后台保存失败任务：(.+)$",
    "Unable to save failed tasks: %1",
  },
  {
    "^未能回滚中断的备份恢复：(.+)$",
    "Could not roll back an interrupted backup restore: %1",
  },
  {
    "^缺失素材  (%d+)$",
    "Missing assets  %1",
  },
  {
    "^重复候选  (%d+)$",
    "Duplicate candidates  %1",
  },
  {
    "^当前工程已用  (%d+)$",
    "Used by current project  %1",
  },
  {
    "^缺失检查完成：(%d+) 个离线来源，(%d+) 个缺失素材$",
    "Missing-file check complete: %1 offline sources, %2 missing assets",
  },
  {
    "^正在检查重复候选：(%d+) 个同尺寸文件$",
    "Checking candidates: %1 equal-size files",
  },
  {
    "^候选检查完成：(%d+) 组，(%d+) 个素材$",
    "Candidate check complete: %1 groups, %2 assets",
  },
  {
    "^重复检查 (%d+) / (%d+) · 失败 (%d+)$",
    "Candidate check %1 / %2 · failed %3",
  },
  {
    "^候选组 (%d+) · 涉及素材 (%d+)$",
    "Candidate groups %1 · assets %2",
  },
  {
    "^已确认相同  (%d+)$",
    "Confirmed identical  %1",
  },
  {
    "^确认读取失败  (%d+)$",
    "Confirmation read failures  %1",
  },
  {
    "^完整确认第 (%d+) / (%d+) 组 · 当前组已处理 (%d+)$",
    "Full confirmation group %1 / %2 · processed %3 in current group",
  },
  {
    "^已确认相同 (%d+) · 读取失败 (%d+)$",
    "Confirmed identical %1 · read failures %2",
  },
  {
    "^完整确认完成：(%d+) 组，(%d+) 个素材，读取失败 (%d+)$",
    "Full confirmation complete: %1 groups, %2 assets, %3 read failures",
  },
  {
    "^来源已重定位：迁移 (%d+) 条路径，待重新扫描 (%d+) 条$",
    "Source relinked: %1 paths migrated, %2 pending rescan",
  },
  {
    "^已将项目素材箱绑定到：(.+)$",
    "Project bin bound to: %1",
  },
  {
    "^后台检查中：(%d+) 个音频 / (%d+) 个目录$",
    "Background check: %1 files / %2 folders",
  },
  {
    "^后台建立索引：(%d+) / (%d+)，失败 (%d+)$",
    "Background indexing: %1 / %2, %3 failed",
  },
  {
    "^后台更新：新增 (%d+) 个，移除 (%d+) 个，失败 (%d+) 个$",
    "Background update: %1 added, %2 removed, %3 failed",
  },
  {
    "^后台更新：移除 (%d+) 个离线素材$",
    "Background update: %1 offline files removed",
  },
  { "^失败任务：(%d+)$", "Failed tasks: %1" },
  { "^正在重试 (%d+) 个失败任务$", "Retrying %1 failed tasks" },
  { "^开始检查 (%d+) 个波形缓存$", "Verifying %1 waveform cache files" },
  {
    "^缓存检查 (%d+) / (%d+) · 有效 (%d+) · 损坏 (%d+)$",
    "Cache verification %1 / %2 · valid %3 · corrupt %4",
  },
  {
    "^缓存检查完成：有效 (%d+)，隔离损坏 (%d+)，([%d%.]+) 秒$",
    "Cache verification complete: %1 valid, %2 corrupt quarantined, %3 s",
  },
  { "^数据备份已创建：(.+)$", "Data backup created: %1" },
  { "^(%d+) 个来源路径 · (%d+) 个素材$", "%1 source folders · %2 files" },
  { "^(%d+) 个来源 · (%d+) 个素材$", "%1 sources · %2 files" },
  { "^已拖入 (%d+) 个文件夹$", "%1 folders dropped" },
  { "^释放以添加到“(.+)”$", "Drop to add to “%1”" },
  { "^全部素材%s+(%d+)$", "All sounds  %1" },
  { "^收藏%s+(%d+)$", "Favorites  %1" },
  { "^　(%d+) 个结果$", "  %1 results" },
  {
    "^结果 (%d+)\n已选 (%d+)\n试听 (.+)$",
    "Results %1\nSelected %2\nPreview %3",
  },
  { "^排序：(.+)$", "Sort: %1" },
  {
    "^扫描 (%d+) 文件 / (%d+) 目录$",
    "Scanning %1 files / %2 folders",
  },
  { "^(%d+) 个已选素材$", "%1 selected files" },
  {
    "^选区 ([%d%.]+)–([%d%.]+) 秒 / ([%d%.]+) 秒$",
    "Selection %1–%2 s / %3 s",
  },
  {
    "^从 ([%d%.]+)%% 开始试听：(.+)$",
    "Previewing from %1%%: %2",
  },
  {
    "^已分轨插入 (%d+) 个素材$",
    "Inserted %1 files on separate tracks",
  },
  {
    "^已在 ([%d%.]+) 秒放置 (%d+) 个素材$",
    "Placed %2 files at %1 s",
  },
  {
    "^已将 PsyReaSFX 元数据保存到 (%d+) 个素材$",
    "Saved PsyReaSFX metadata to %1 files",
  },
  {
    "^(%d+) 个素材批量编辑。勾选字段后才会写入。$",
    "Batch editing %1 files. Enable a field before writing it.",
  },
  {
    "^扫描完成：(%d+) 个音频，移除 (%d+) 个，([%d%.]+) 秒$",
    "Scan complete: %1 files, %2 removed, %3 s",
  },
  {
    "^扫描完成：(%d+) 个音频，移除 (%d+) 个，忽略 (%d+) 个系统文件，([%d%.]+) 秒$",
    "Scan complete: %1 files, %2 removed, %3 system files ignored, %4 s",
  },
  {
    "^已从索引自动忽略 (%d+) 个系统元数据文件$",
    "Ignored %1 system metadata files from the index",
  },
  {
    "^导入完成：(%d+) 个可用，(%d+) 个失败，([%d%.]+) 秒$",
    "Import complete: %1 available, %2 failed, %3 s",
  },
  {
    "^已选择 (%d+) 个素材$",
    "%1 files selected",
  },
  {
    "^列表波形精度已设置为 (%d+) 点；新精度将按需建立缓存$",
    "List waveform resolution set to %1 points; the new cache will be built on demand",
  },
  {
    "^预缓存完成：新生成 (%d+)，已有缓存 (%d+)，失败 (%d+)，([%d%.]+) 秒$",
    "Precache complete: %1 generated, %2 cached, %3 failed, %4 s",
  },
  {
    "^开始预缓存 (%d+) 个素材的 (%d+) 点高精度波形$",
    "Started %2-point high-resolution precache for %1 files",
  },
  {
    "^已恢复上次浏览高亮：(%d+) 项$",
    "Restored %1 previous browsing highlights",
  },
  {
    "^已撤销上次检测，移除 (%d+) 个瞬态 Region$",
    "Undid the last detection and removed %1 transient Regions",
  },
  {
    "^已清除 (%d+) 个瞬态 Region 建议$",
    "Cleared %1 transient Region suggestions",
  },
  {
    "^已生成 (%d+) 个瞬态 Region 建议；可在 Region 列表中撤销或清除$",
    "Generated %1 transient Region suggestions; undo or clear them from the Region list",
  },
  {
    "^从 ([%d%.]+)%% 开始试听：(.+)$",
    "Previewing from %1%%: %2",
  },
  {
    "^已切换缓存目录：移动 (%d+)，失败 (%d+)$",
    "Cache directory changed: %1 moved, %2 failed",
  },
  {
    "^已向“(.+)”加入 (%d+) 个素材$",
    "Added %2 files to “%1”",
  },
  {
    "^已从“(.+)”移除 (%d+) 个素材$",
    "Removed %2 files from “%1”",
  },
  {
    "^已将 (%d+) 个素材标记为“(.+)”$",
    "Marked %1 files as “%2”",
  },
  {
    "^已选择 (%d+) 个素材$",
    "%1 files selected",
  },
  {
    "^已在 ([%d%.]+) 秒放置 (%d+) 个素材$",
    "Placed %2 files at %1 s",
  },
  {
    "^高精度预缓存 (%d+) 点%s+(%d+) / (%d+)%s+新生成 (%d+)%s+已有 (%d+)%s+失败 (%d+)$",
    "%1-point precache  %2 / %3  generated %4  cached %5  failed %6",
  },
  {
    "^(.+)：正在扫描 (%d+) 个目录…$",
    "%1: scanning %2 folders…",
  },
  {
    "^(.+)：扫描完成，正在分析并建立 (%d+) 个波形…$",
    "%1: scan complete; analyzing and building %2 waveforms…",
  },
  {
    "^(.+)：分析元数据并建立波形%s+(%d+) / (%d+)%s+失败 (%d+)$",
    "%1: analyzing metadata and building waveforms  %2 / %3  failed %4",
  },
  {
    "^从 PsyReaSFX 中删除该音效库？\n\n(.+)\n\n不会删除磁盘中的音频文件。$",
    "Remove this library from PsyReaSFX?\n\n%1\n\nAudio files on disk will not be deleted.",
  },
  {
    "^删除 PsyReaSFX 集合？\n\n(.+)\n\n不会删除磁盘音频文件。$",
    "Delete this PsyReaSFX collection?\n\n%1\n\nAudio files on disk will not be deleted.",
  },
  {
    "^已新建(.+)“(.+)”，并加入 (%d+) 个当前所选素材；可在左侧点击打开$",
    "Created %1 “%2” and added %3 selected files; open it from the left panel",
  },
  {
    "^已新建(.+)“(.+)”；当前列表保持不变，可在左侧点击打开$",
    "Created %1 “%2”; the current list remains unchanged and can be opened from the left panel",
  },
}

function translate_ui_text(value)
  local text = tostring(value or "")

  if not state or state.language ~= "en" then
    return text
  end

  local exact = I18N_EN[text]

  if exact then
    return exact
  end

  for prefix, replacement in pairs(I18N_PREFIX_EN) do
    if text:sub(1, #prefix) == prefix then
      return replacement .. text:sub(#prefix + 1)
    end
  end

  for _, rule in ipairs(I18N_PATTERNS_EN) do
    local translated, count =
      text:gsub(rule[1], rule[2])

    if count > 0 then
      return translated
    end
  end

  if text:find("[\228-\233][\128-\191][\128-\191]") then
    if I18N_MISSING[text] then
      I18N_MISSING[text] = I18N_MISSING[text] + 1
    elseif (I18N_MISSING_UNIQUE or 0) < (I18N_MISSING_LIMIT or 256) then
      I18N_MISSING[text] = 1
      I18N_MISSING_UNIQUE = (I18N_MISSING_UNIQUE or 0) + 1
    end
  end

  return text
end

function missing_translation_count()
  return I18N_MISSING_UNIQUE or 0
end

-- Progress renderers need the session object itself, not the boolean result of
-- `session and not session.silent`. Keep this conversion explicit so a visible
-- import cannot become `true` and then be indexed as a table.
function visible_progress_session(session)
  if type(session) ~= "table" or session.silent then
    return nil
  end
  return session
end

function translate_ui_label(value)
  local text = tostring(value or "")
  local visible, hidden =
    text:match("^(.-)(##.*)$")

  if hidden then
    return translate_ui_text(visible) .. hidden
  end

  return translate_ui_text(text)
end

function install_i18n_wrappers()
  if I18N_WRAPPERS_INSTALLED then
    return
  end

  I18N_WRAPPERS_INSTALLED = true
  RAW_IMGUI = ImGui

  -- 使用代理表覆盖需要翻译的函数，其他常量和 API 继续从原始
  -- ReaImGui 表读取，避免修改原始绑定或产生递归调用。
  ImGui =
    setmetatable(
      {},
      {
        __index = RAW_IMGUI,
      }
    )

  RAW_REAPER_MB = reaper.MB
  RAW_REAPER_GET_USER_INPUTS =
    reaper.GetUserInputs

  ImGui.Text =
    function(context, value)
      return RAW_IMGUI.Text(
        context,
        translate_ui_text(value)
      )
    end

  ImGui.TextDisabled =
    function(context, value)
      return RAW_IMGUI.TextDisabled(
        context,
        translate_ui_text(value)
      )
    end

  ImGui.TextWrapped =
    function(context, value)
      return RAW_IMGUI.TextWrapped(
        context,
        translate_ui_text(value)
      )
    end

  ImGui.TextColored =
    function(context, color_value, value)
      return RAW_IMGUI.TextColored(
        context,
        color_value,
        translate_ui_text(value)
      )
    end

  ImGui.Button =
    function(context, label, ...)
      return RAW_IMGUI.Button(
        context,
        translate_ui_label(label),
        ...
      )
    end

  ImGui.MenuItem =
    function(context, label, shortcut, ...)
      return RAW_IMGUI.MenuItem(
        context,
        translate_ui_label(label),
        shortcut,
        ...
      )
    end

  ImGui.BeginMenu =
    function(context, label, ...)
      return RAW_IMGUI.BeginMenu(
        context,
        translate_ui_label(label),
        ...
      )
    end

  ImGui.Checkbox =
    function(context, label, ...)
      return RAW_IMGUI.Checkbox(
        context,
        translate_ui_label(label),
        ...
      )
    end

  ImGui.Selectable =
    function(context, label, ...)
      return RAW_IMGUI.Selectable(
        context,
        translate_ui_label(label),
        ...
      )
    end

  ImGui.InputText =
    function(context, label, ...)
      return RAW_IMGUI.InputText(
        context,
        translate_ui_label(label),
        ...
      )
    end

  ImGui.InputTextWithHint =
    function(context, label, hint, ...)
      return RAW_IMGUI.InputTextWithHint(
        context,
        translate_ui_label(label),
        translate_ui_text(hint),
        ...
      )
    end

  ImGui.SliderDouble =
    function(context, label, ...)
      return RAW_IMGUI.SliderDouble(
        context,
        translate_ui_label(label),
        ...
      )
    end

  ImGui.OpenPopup =
    function(context, label, ...)
      return RAW_IMGUI.OpenPopup(
        context,
        translate_ui_label(label),
        ...
      )
    end

  ImGui.BeginPopup =
    function(context, label, ...)
      return RAW_IMGUI.BeginPopup(
        context,
        translate_ui_label(label),
        ...
      )
    end

  ImGui.BeginPopupModal =
    function(context, label, ...)
      return RAW_IMGUI.BeginPopupModal(
        context,
        translate_ui_label(label),
        ...
      )
    end

  ImGui.ProgressBar =
    function(context, fraction, width, height, overlay)
      return RAW_IMGUI.ProgressBar(
        context,
        fraction,
        width,
        height,
        translate_ui_text(overlay)
      )
    end

  ImGui.CalcTextSize =
    function(context, value, ...)
      return RAW_IMGUI.CalcTextSize(
        context,
        translate_ui_text(value),
        ...
      )
    end

  ImGui.DrawList_AddText =
    function(draw_list, x, y, color_value, value, ...)
      return RAW_IMGUI.DrawList_AddText(
        draw_list,
        x,
        y,
        color_value,
        translate_ui_text(value),
        ...
      )
    end

  reaper.MB =
    function(message, title, box_type)
      return RAW_REAPER_MB(
        translate_ui_text(message),
        translate_ui_text(title),
        box_type
      )
    end

  reaper.GetUserInputs =
    function(title, count, captions, defaults, ...)
      return RAW_REAPER_GET_USER_INPUTS(
        translate_ui_text(title),
        count,
        translate_ui_text(captions),
        defaults,
        ...
      )
    end
end

----------------------------------------------------------------
-- Utility
----------------------------------------------------------------

function set_status(text, is_error)
  state.status = tostring(text or "")
  state.status_error = is_error == true
end

function clamp(value, minimum, maximum)
  if value < minimum then
    return minimum
  elseif value > maximum then
    return maximum
  end

  return value
end

function trim(value)
  return (value or ""):match("^%s*(.-)%s*$")
end

function rgba_from_hex(hex)
  hex = tostring(hex or "")
    :gsub("#", "")
    :gsub("[^%x]", "")

  if #hex ~= 6 then
    return nil
  end

  local value = tonumber(hex, 16)

  if not value then
    return nil
  end

  return (value << 8) | 0xFF
end

function rgb_from_hex(hex)
  local rgba = rgba_from_hex(hex)

  if not rgba then
    return nil
  end

  return (rgba >> 8) & 0xFFFFFF
end

function hex_from_rgb(rgb)
  return string.format(
    "#%06X",
    (tonumber(rgb) or 0) & 0xFFFFFF
  )
end

function rgba_with_alpha(color_value, alpha)
  return (color_value & 0xFFFFFF00)
    | clamp(math.floor(alpha or 255), 0, 255)
end

function rgba_mix(color_a, color_b, amount)
  amount = clamp(tonumber(amount) or 0, 0, 1)

  local function channel(color_value, shift)
    return (color_value >> shift) & 0xFF
  end

  local function mixed(shift)
    return math.floor(
      channel(color_a, shift) * (1 - amount)
        + channel(color_b, shift) * amount
        + 0.5
    )
  end

  return (mixed(24) << 24)
    | (mixed(16) << 16)
    | (mixed(8) << 8)
    | 0xFF
end

function rgba_luminance(color_value)
  local r = (color_value >> 24) & 0xFF
  local g = (color_value >> 16) & 0xFF
  local b = (color_value >> 8) & 0xFF
  return (r * 0.2126 + g * 0.7152 + b * 0.0722) / 255
end

function custom_surface_from_base()
  local base = rgba_from_hex(state.custom_shell_hex)
    or SURFACE_STYLES.dark.window
  local light = 0xFFFFFFFF
  local black = 0x000000FF
  local bright = rgba_luminance(base) > 0.52
  local layer_target = bright and black or light
  local text = bright and 0x0A1020FF or 0xF5FAFFFF

  return {
    window = base,
    panel = rgba_mix(base, layer_target, 0.025),
    panel_alt = rgba_mix(base, layer_target, 0.065),
    title = rgba_mix(base, layer_target, 0.055),
    title_active = rgba_mix(base, layer_target, 0.105),
    header = rgba_mix(base, layer_target, 0.12),
    row = rgba_mix(base, black, bright and 0.035 or 0.08),
    row_alt = rgba_mix(base, layer_target, 0.02),
    row_hover = rgba_mix(base, layer_target, 0.12),
    grid = rgba_mix(base, layer_target, 0.18),
    border = rgba_mix(base, layer_target, 0.24),
    button = rgba_mix(base, layer_target, 0.10),
    button_hover = rgba_mix(base, layer_target, 0.18),
    waveform_bg = rgba_mix(base, black, bright and 0.18 or 0.60),
    text = text,
    dim = rgba_mix(text, base, 0.48),
  }
end

function apply_ui_density_metrics()
  local profile =
    UI_DENSITY_PROFILES[state.ui_density]
    or UI_DENSITY_PROFILES.balanced

  ROW_H = profile.row_h
  HEADER_H = profile.header_h
  UI_METRIC.radius = profile.radius
  UI_METRIC.radius_small = profile.radius_small
  UI_METRIC.icon_button = profile.icon_button
  UI_METRIC.icon_gap = profile.icon_gap
  UI_METRIC.panel_padding = profile.panel_padding
  UI_METRIC.parameter_h = profile.parameter_h
  UI_METRIC.parameter_min_w = profile.parameter_min_w
  UI_METRIC.parameter_max_w = profile.parameter_max_w
  UI_METRIC.control_panel_h = profile.control_panel_h
  PANEL_GAP = profile.panel_gap
end

function apply_surface_style()
  local surface = state.surface_style == "custom"
    and custom_surface_from_base()
    or SURFACE_STYLES[state.surface_style]
    or SURFACE_STYLES.dark

  for key, value in pairs(surface) do
    COLOR[key] = value
  end

  COLOR.header_text = COLOR.text
  COLOR.muted = COLOR.dim
end

function apply_theme_palette()
  local preset = THEME_PRESETS[state.theme_preset]
    or THEME_PRESETS.dark

  local accent = preset.accent

  if state.theme_preset == "custom" then
    accent = rgba_from_hex(state.custom_accent_hex)
      or THEME_PRESETS.dark.accent
  end

  local selected = preset.selected or accent

  if state.theme_preset == "custom"
    and rgba_luminance(selected) > 0.58 then
    selected = rgba_mix(
      selected,
      0x000000FF,
      0.38
    )
  end

  COLOR.selected = selected
  COLOR.accent = accent
  COLOR.selection = rgba_with_alpha(accent, 0x55)
  if state.surface_style ~= "custom"
    and state.theme_preset ~= "custom" then
    COLOR.border = preset.accent_soft or COLOR.border
  end
  COLOR.playhead = preset.playhead or 0x61D982FF
  COLOR.favorite = preset.favorite or 0xF0C85AFF
  COLOR.selected_text =
    preset.selected_text or 0xFFFFFFFF

  if state and state.waveform_hex
    and type(apply_waveform_palette) == "function" then
    apply_waveform_palette()
  end
end

function apply_appearance_preset(key)
  local definition = APPEARANCE_PRESETS[key]

  if not definition then
    return
  end

  state.surface_style = key
  state.theme_preset = key
  state.custom_shell_hex = definition.shell_hex
  state.custom_accent_hex = definition.accent_hex
  state.waveform_hex = definition.waveform_hex
  state.waveform_selected_hex =
    definition.waveform_selected_hex
  state.waveform_played_hex =
    definition.waveform_played_hex
  state.selection_hex = definition.selection_hex
  state.playhead_hex = definition.playhead_hex
  state.config_dirty = true

  apply_surface_style()
  apply_theme_palette()

  if type(apply_waveform_palette) == "function" then
    apply_waveform_palette()
  end
end

local DEFAULT_WAVEFORM_PALETTE = {
  waveform_hex = "#D7D8DA",
  waveform_selected_hex = "#EAF3FF",
  waveform_played_hex = "#8FB8D8",
  waveform_marked_hex = "#F0C85A",
  played_text_hex = "#F0C85A",
  selection_hex = "#2789E9",
  playhead_hex = "#50E36D",
  region_hex = "#E2B764",
}

local WAVEFORM_PALETTE_FIELDS = {
  {
    key = "waveform_hex",
    label = "普通波形",
    fallback = 0xD7D8DAFF,
  },
  {
    key = "waveform_selected_hex",
    label = "选中波形",
    fallback = 0xEAF3FFFF,
  },
  {
    key = "waveform_played_hex",
    label = "已播放波形",
    fallback = 0x8FB8D8FF,
  },
  {
    key = "waveform_marked_hex",
    label = "已标记波形",
    fallback = 0xF0C85AFF,
  },
  {
    key = "played_text_hex",
    label = "已播放文字",
    fallback = 0xF0C85AFF,
  },
  {
    key = "selection_hex",
    label = "选区颜色",
    fallback = 0x2789E9FF,
  },
  {
    key = "playhead_hex",
    label = "播放指针颜色",
    fallback = 0x50E36DFF,
  },
  {
    key = "region_hex",
    label = "Region 颜色",
    fallback = 0xE2B764FF,
  },
}

function apply_waveform_palette()
  COLOR.waveform =
    rgba_from_hex(state.waveform_hex)
      or 0xDCE8F3FF

  COLOR.waveform_selected =
    rgba_from_hex(state.waveform_selected_hex)
      or 0xF5FAFFFF

  COLOR.waveform_played =
    rgba_from_hex(state.waveform_played_hex)
      or 0x63CDE8FF

  COLOR.waveform_marked =
    rgba_from_hex(state.waveform_marked_hex)
      or 0xF0C85AFF

  COLOR.played_text =
    rgba_from_hex(state.played_text_hex)
      or 0xF0C85AFF

  local selection =
    rgba_from_hex(state.selection_hex)
      or 0x19D8FFFF

  COLOR.selection =
    rgba_with_alpha(selection, 0x55)

  COLOR.playhead =
    rgba_from_hex(state.playhead_hex)
      or 0x19D8FFFF

  COLOR.region =
    rgba_with_alpha(
      rgba_from_hex(state.region_hex)
        or 0xE2B764FF,
      0x88
    )
end

function asset_is_played(asset)
  -- Persistent history, used by search and Preview History.
  return asset
    and (tonumber(asset.last_previewed) or 0) > 0
end

function asset_is_session_played(asset)
  return asset
    and state.session_played[
      path_key(asset.path)
    ] == true
end

function count_path_set(values)
  local count = 0

  for _ in pairs(values or {}) do
    count = count + 1
  end

  return count
end

function copy_path_set(values)
  local result = {}

  for key, enabled in pairs(values or {}) do
    if enabled then
      result[key] = true
    end
  end

  return result
end

function session_played_count()
  return count_path_set(state.session_played)
end

function last_session_played_count()
  return count_path_set(state.last_session_played)
end

function load_last_played_session()
  state.last_session_played = {}

  local file =
    io.open(
      LAST_PLAYED_SESSION_FILE,
      "rb"
    )

  if not file then
    return
  end

  for line in file:lines() do
    local fields = split_tsv(line)

    if fields[1] == "played"
      and fields[2]
      and fields[2] ~= "" then
      state.last_session_played[
        fields[2]
      ] = true
    end
  end

  file:close()
end

function save_last_played_session()
  if state.root_removal_session then return false end
  if state.auxiliary_save_session
    and state.auxiliary_save_session.kind == "session_played" then
    cancel_auxiliary_save("synchronous session history save")
  end
  ensure_dirs()

  local file =
    atomic_file_writer(
      LAST_PLAYED_SESSION_FILE
    )

  if not file then
    set_status(
      "无法保存上次浏览高亮",
      true
    )
    return false
  end

  write_persistence_schema(file, LAST_PLAYED_SESSION_FILE)

  for key in pairs(state.session_played) do
    file:write(
      "played\t",
      escape_tsv(key),
      "\n"
    )
  end

  if not file:close() then
    set_status("无法保存上次浏览高亮", true)
    return false
  end

  state.last_session_played =
    copy_path_set(
      state.session_played
    )

  state.session_played_dirty = false
  return true
end

function migrate_last_played_session_schema()
  ensure_dirs()

  local file = atomic_file_writer(
    LAST_PLAYED_SESSION_FILE
  )

  if not file then
    return false
  end

  write_persistence_schema(file, LAST_PLAYED_SESSION_FILE)

  for key in pairs(state.last_session_played) do
    file:write(
      "played\t",
      escape_tsv(key),
      "\n"
    )
  end

  return file:close()
end

function restore_last_session_played_highlights(silent)
  if state.auxiliary_save_session
    and state.auxiliary_save_session.kind == "session_played" then
    cancel_auxiliary_save("restore session highlights")
  end
  local count =
    last_session_played_count()

  if count == 0 then
    if not silent then
      set_status(
        "没有可恢复的上次浏览记录",
        true
      )
    end
    return false
  end

  state.session_played =
    copy_path_set(
      state.last_session_played
    )

  state.session_played_dirty = false
  state.results_dirty = true

  if not silent then
    set_status(
      string.format(
        "已恢复上次浏览高亮：%d 项",
        count
      )
    )
  end

  return true
end

function clear_session_played_highlights()
  state.session_played = {}

  -- 只清空当前界面，不覆盖上次保存快照。
  -- 误清除后仍可立即恢复。
  state.session_played_dirty = false
  state.results_dirty = true
  set_status("已清除本次已播放高亮")
end

function clear_saved_session_played_highlights()
  if state.auxiliary_save_session
    and state.auxiliary_save_session.kind == "session_played" then
    cancel_auxiliary_save("clear saved session highlights")
  end
  state.last_session_played = {}
  os.remove(LAST_PLAYED_SESSION_FILE)
  state.session_played_dirty = false

  if state.restore_played_on_start then
    state.restore_played_on_start = false
    state.config_dirty = true
  end

  set_status("已清除已保存浏览记录")
end

function asset_is_marked(asset)
  return asset and asset.marked == true
end

function waveform_visual_state(asset, selected)
  if selected then
    return "selected", COLOR.waveform_selected
  end

  if asset_is_marked(asset) then
    return "marked", COLOR.waveform_marked
  end

  if state.played_waveform_enabled
    and asset_is_session_played(asset) then
    return "played", COLOR.waveform_played
  end

  return "normal", COLOR.waveform
end

function row_text_visual_color(asset, selected)
  if selected then
    return COLOR.selected_text
  end

  if state.played_text_enabled
    and asset_is_session_played(asset) then
    return COLOR.played_text
  end

  return COLOR.text
end

function reset_waveform_palette_defaults()
  for key, value in pairs(DEFAULT_WAVEFORM_PALETTE) do
    state[key] = value
  end

  apply_waveform_palette()
  state.config_dirty = true
end

function normalize_slashes(path)
  if not path then
    return ""
  end

  if SEP == "\\" then
    return path:gsub("/", "\\")
  end

  return path:gsub("\\", "/")
end

function path_key(path)
  path = normalize_slashes(path)

  -- SEP is fixed for the life of the script. Avoid calling back into the
  -- REAPER host for every indexed path (large catalogs call this hundreds of
  -- thousands of times during startup).
  if SEP == "\\" then
    path = path:lower()
  end

  return path
end

function canonical_source_path(path)
  path = normalize_slashes(trim(path or ""))

  while #path > 3 and path:sub(-1) == SEP do
    path = path:sub(1, -2)
  end

  return path
end

function normalize_external_path(path)
  path = tostring(path or ""):gsub("%z+$", "")
  path = trim(path)

  local first = path:sub(1, 1)
  local last = path:sub(-1)
  if #path >= 2
    and ((first == '"' and last == '"')
      or (first == "'" and last == "'")) then
    path = trim(path:sub(2, -2))
  end

  return canonical_source_path(path)
end

function join_path(a, b)
  a = normalize_slashes(a or "")
  b = normalize_slashes(b or "")

  if a == "" then
    return b
  elseif b == "" then
    return a
  elseif a:sub(-1) == SEP then
    return a .. b
  end

  return a .. SEP .. b
end

function basename(path)
  path = normalize_slashes(path)
  return path:match("([^/\\]+)$") or path
end

function dirname(path)
  path = normalize_slashes(path)
  return path:match("^(.*)[/\\][^/\\]+$") or ""
end

function strip_extension(name)
  return (name or ""):gsub("%.[^%.]+$", "")
end

function extension(path)
  return ((path or ""):match("%.([^%.]+)$") or ""):lower()
end

function is_ignored_directory_name(name)
  local normalized = safe_lower(trim(name or ""))

  return normalized == "__macosx"
    or normalized == ".appledouble"
    or normalized == ".spotlight-v100"
    or normalized == ".trashes"
    or normalized == "@eadir"
end

function is_ignored_media_path(path)
  local name = basename(path or "")

  -- macOS writes AppleDouble resource-fork metadata as `._filename` on
  -- filesystems that cannot store the resource fork natively. The sidecar
  -- often keeps the original `.wav` extension but is not playable audio.
  if name:sub(1, 2) == "._" then
    return true
  end

  local normalized = safe_lower(normalize_slashes(path or ""))

  for segment in normalized:gmatch("[^/\\]+") do
    if is_ignored_directory_name(segment) then
      return true
    end
  end

  return false
end

function is_audio_file(path)
  return not is_ignored_media_path(path)
    and AUDIO_EXT[extension(path)] == true
end

function safe_lower(value)
  return tostring(value or ""):lower()
end

function file_size(path)
  local file = io.open(path, "rb")

  if not file then
    return 0
  end

  local size = file:seek("end") or 0
  file:close()
  return size
end

function directory_exists(path)
  path = normalize_external_path(path)

  if path == "" then
    return false
  end

  -- A trailing separator makes the no-op rename a directory probe instead of
  -- the ambiguous `rename(path, path)`, which also succeeds for regular files
  -- on Windows. Do not reject a path only because `reaper.file_exists()` says
  -- true: some host/filesystem combinations report readable directories too.
  local probe = path
  if probe:sub(-1) ~= SEP then
    probe = probe .. SEP
  end

  local ok, _, code = os.rename(probe, probe)
  if ok or code == 13 then
    return true
  end

  -- REAPER's enumerators use its native path layer and can still recognize a
  -- populated directory when the Lua C runtime cannot probe a long/UNC path.
  if type(reaper.EnumerateFiles) == "function" then
    local listed, entry = pcall(reaper.EnumerateFiles, path, 0)
    if listed and entry ~= nil then
      return true
    end
  end

  if type(reaper.EnumerateSubdirectories) == "function" then
    local listed, entry = pcall(
      reaper.EnumerateSubdirectories,
      path,
      0
    )
    if listed and entry ~= nil then
      return true
    end
  end

  return false
end

function path_is_inside(path, root)
  local p = path_key(path)
  local r = path_key(root)

  if p == r then
    return true
  end

  if r:sub(-1) ~= SEP then
    r = r .. SEP
  end

  return p:sub(1, #r) == r
end

function invalidate_folder_navigation()
  -- A large import can add tens of thousands of assets before the hierarchy
  -- is requested. Once the cache is already dirty, avoid allocating another
  -- empty table and advancing the revision for every discovered file.
  if not state.folder_navigation_ready
    and not state.folder_navigation_job
    and next(state.folder_navigation_trees) == nil
    and state.folder_navigation_built_revision
      ~= state.folder_navigation_revision then
    return
  end

  state.folder_navigation_revision =
    (state.folder_navigation_revision or 0) + 1
  state.folder_navigation_ready = false
  state.folder_navigation_trees = {}
  state.folder_navigation_job = nil
end

function new_folder_navigation_node(name, path, parent, root_id)
  return {
    name = name or basename(path),
    path = canonical_source_path(path),
    key = path_key(path),
    parent = parent,
    root_id = root_id,
    children = {},
    children_by_key = {},
    direct_count = 0,
    total_count = 0,
  }
end

function add_asset_to_folder_navigation(asset, trees)
  local root_id = tostring(asset.root_id or "")
  local root_node = trees[root_id]

  if not root_node then
    return
  end

  local folder = canonical_source_path(
    asset.folder ~= "" and asset.folder
      or dirname(asset.path)
  )

  if not path_is_inside(folder, root_node.path) then
    return
  end

  local node = root_node
  local relative = folder:sub(#root_node.path + 1)
  relative = relative:gsub("^[\\/]+", "")

  for segment in relative:gmatch("[^\\/]+") do
    local child_path = join_path(node.path, segment)
    local child_key = path_key(child_path)
    local child = node.children_by_key[child_key]

    if not child then
      child = new_folder_navigation_node(
        segment,
        child_path,
        node,
        root_id
      )
      node.children_by_key[child_key] = child
      node.children[#node.children + 1] = child
    end

    node = child
  end

  node.direct_count = node.direct_count + 1
end

function finalize_folder_navigation_node(node)
  table.sort(
    node.children,
    function(a, b)
      local a_name = safe_lower(a.name)
      local b_name = safe_lower(b.name)

      if a_name == b_name then
        return a.key < b.key
      end

      return a_name < b_name
    end
  )

  local total = node.direct_count

  for _, child in ipairs(node.children) do
    total = total + finalize_folder_navigation_node(child)
  end

  node.total_count = total
  return total
end

function start_folder_navigation_build()
  local trees = {}

  for _, record in ipairs(state.root_records) do
    if record.enabled and record.path ~= "" then
      trees[record.id] = new_folder_navigation_node(
        record.alias ~= "" and record.alias
          or basename(record.path),
        record.path,
        nil,
        record.id
      )
    end
  end

  state.folder_navigation_trees = trees
  state.folder_navigation_ready = false
  state.folder_navigation_job = {
    revision = state.folder_navigation_revision,
    index = 1,
    total = #state.assets,
    trees = trees,
  }
end

function ensure_folder_navigation_build()
  if state.folder_navigation_ready
    and state.folder_navigation_built_revision
      == state.folder_navigation_revision then
    return true
  end

  local job = state.folder_navigation_job

  if not job
    or job.revision ~= state.folder_navigation_revision then
    start_folder_navigation_build()
  end

  return false
end

function process_folder_navigation_build()
  local job = state.folder_navigation_job

  if not job
    or state.scan
    or state.import_session
    or state.transfer_running
    or not can_run_heavy_job() then
    return
  end

  if job.revision ~= state.folder_navigation_revision then
    start_folder_navigation_build()
    job = state.folder_navigation_job
  end

  local processed = 0
  local budget = 700

  while job.index <= job.total and processed < budget do
    local asset = state.assets[job.index]

    if asset and asset.ready and not asset.pending_batch then
      add_asset_to_folder_navigation(asset, job.trees)
    end

    job.index = job.index + 1
    processed = processed + 1
  end

  if job.index > job.total then
    for _, tree in pairs(job.trees) do
      finalize_folder_navigation_node(tree)
    end

    state.folder_navigation_trees = job.trees
    state.folder_navigation_built_revision = job.revision
    state.folder_navigation_ready = true
    state.folder_navigation_job = nil
  end
end

function stable_id(prefix, seed)
  local hash = 5381
  local value = path_key(tostring(seed or ""))

  for index = 1, #value do
    hash = (hash * 33 + value:byte(index)) % 4294967291
  end

  return tostring(prefix or "id")
    .. "_"
    .. string.format("%08x", math.floor(hash))
end

function unique_library_name(base)
  base = trim(base or "")

  if base == "" then
    base = "New library"
  end

  local used = {}

  for _, library in ipairs(state.libraries) do
    used[safe_lower(library.name)] = true
  end

  if not used[safe_lower(base)] then
    return base
  end

  local number = 2

  while used[safe_lower(base .. " " .. tostring(number))] do
    number = number + 1
  end

  return base .. " " .. tostring(number)
end

function refresh_source_identity(record)
  if not record then
    return
  end

  record.path = canonical_source_path(record.path)
  record.canonical_path = canonical_source_path(
    tostring(record.canonical_path or "") ~= ""
      and record.canonical_path
      or record.path
  )
  record.volume_label = tostring(record.volume_label or "")
  record.volume_serial = tostring(record.volume_serial or "")
  record.last_seen = tonumber(record.last_seen) or 0

  if not directory_exists(record.path) then
    return
  end

  record.canonical_path = record.path
  record.last_seen = os.time()

  if reaper.GetOS():match("Win") then
    local drive = record.path:match("^([A-Za-z]:)")

    if drive and type(reaper.ExecProcess) == "function" then
      local ok, output = pcall(
        reaper.ExecProcess,
        "cmd.exe /d /c vol " .. drive,
        1000
      )

      if ok and type(output) == "string" then
        local serial = output:match("(%x%x%x%x%-%x%x%x%x)")
        if serial then
          record.volume_serial = serial:upper()
        end
      end
    end
  end
end

function rebuild_library_indexes()
  state.library_by_id = {}
  state.root_by_id = {}
  state.root_by_path = {}
  state.roots = {}

  for _, library in ipairs(state.libraries) do
    library.artwork_path =
      tostring(library.artwork_path or "")
    library.artwork_checked =
      library.artwork_checked == true
    library.roots = {}
    state.library_by_id[library.id] = library
  end

  for _, record in ipairs(state.root_records) do
    refresh_source_identity(record)
    record.enabled = record.enabled ~= false
    record.artwork_path =
      tostring(record.artwork_path or "")
    record.artwork_checked =
      record.artwork_checked == true
    record.artwork_scan_version =
      tonumber(record.artwork_scan_version) or 0
    state.root_by_id[record.id] = record
    state.root_by_path[path_key(record.path)] = record

    local library = state.library_by_id[record.library_id]

    if library then
      library.roots[#library.roots + 1] = record
    end

    if record.enabled and record.path ~= "" then
      state.roots[#state.roots + 1] = record.path
    end
  end

  invalidate_folder_navigation()
end

function create_library(name, seed)
  local library = {
    id = stable_id(
      "lib",
      seed or (name .. tostring(reaper.time_precise()))
    ),
    name = unique_library_name(name),
    artwork_path = "",
    artwork_checked = false,
    roots = {},
  }

  while state.library_by_id[library.id] do
    library.id = stable_id(
      "lib",
      library.id .. tostring(reaper.time_precise())
    )
  end

  state.libraries[#state.libraries + 1] = library
  state.library_by_id[library.id] = library
  state.expanded_libraries[library.id] = true
  state.libraries_dirty = true
  return library
end

function root_record_for_path(path)
  return state.root_by_path[path_key(path)]
end

function library_for_root_record(record)
  return record
    and state.library_by_id[record.library_id]
    or nil
end

function root_for_path(path)
  local best = nil
  local best_path = nil

  for _, record in ipairs(state.root_records) do
    local root = record.path

    if record.enabled
      and path_is_inside(path, root)
      and (not best_path or #root > #best_path) then
      best = record
      best_path = root
    end
  end

  return best_path, best
end

function library_for_path(path, root)
  local record = nil

  if type(root) == "table" then
    record = root
    root = record.path
  elseif root then
    record = root_record_for_path(root)
  else
    root, record = root_for_path(path)
  end

  if not root then
    return basename(dirname(path))
  end

  local library = library_for_root_record(record)

  return library and library.name or basename(root)
end

function invalidate_library_counts()
  state.library_counts_dirty = true
  state.library_counts_job = nil
end

function refresh_asset_library_binding(asset)
  local previous_root = tostring(asset.root or "")
  local previous_root_id = tostring(asset.root_id or "")
  local previous_library_id = tostring(asset.library_id or "")
  local previous_library = tostring(asset.library or "")
  local root, record = root_for_path(asset.path)
  local library = library_for_root_record(record)

  asset.root = root or ""
  asset.root_id = record and record.id or ""
  asset.library_id = library and library.id or ""
  asset.library = library and library.name
    or library_for_path(asset.path, root)
  asset._search_blob = nil
  return previous_root ~= tostring(asset.root or "")
    or previous_root_id ~= tostring(asset.root_id or "")
    or previous_library_id ~= tostring(asset.library_id or "")
    or previous_library ~= tostring(asset.library or "")
end

function refresh_all_asset_library_bindings()
  local previous = state.asset_binding_refresh
  if previous and (previous.changed_count or 0) > 0 then
    -- Some objects may already have been changed by the superseded pass.
    -- A snapshot request guarantees they cannot become an untracked partial
    -- update when a second library edit restarts the job.
    mark_database_snapshot_dirty()
  end

  invalidate_folder_navigation()
  invalidate_library_counts()
  state.asset_binding_refresh = {
    assets = state.assets,
    index = 1,
    total = #state.assets,
    phase = "bindings",
    changed_assets = {},
    changed_count = 0,
    persist_index = 1,
    requires_snapshot = false,
  }
end

function finish_asset_library_binding_refresh(session)
  state.asset_binding_refresh = nil
  invalidate_folder_navigation()
  invalidate_library_counts()
  state.results_dirty = true
  if session.requires_snapshot then
    mark_database_snapshot_dirty()
  end
end

function process_asset_library_binding_refresh()
  local session = state.asset_binding_refresh
  if not session or not can_run_heavy_job() then return end

  for _, token in pairs(Jobs.active) do
    if token.resource == "catalog_exclusive"
      and not token.finished then
      return
    end
  end

  if session.assets ~= state.assets then
    if (session.changed_count or 0) > 0 then
      mark_database_snapshot_dirty()
    end
    refresh_all_asset_library_bindings()
    return
  end

  if session.phase == "bindings" then
    local last = math.min(
      session.total,
      session.index + ASSET_BINDINGS_PER_FRAME - 1
    )
    for index = session.index, last do
      local asset = session.assets[index]
      if asset and refresh_asset_library_binding(asset) then
        session.changed_count = session.changed_count + 1
        if not session.requires_snapshot
          and session.changed_count <= DATABASE_JOURNAL_COMPACT_COUNT then
          session.changed_assets[#session.changed_assets + 1] = asset
        else
          session.requires_snapshot = true
          session.changed_assets = nil
        end
      end
    end
    session.index = last + 1
    if session.index > session.total then
      if session.requires_snapshot or session.changed_count == 0 then
        finish_asset_library_binding_refresh(session)
      else
        session.phase = "persist"
      end
    end
    return
  end

  local last = math.min(
    #session.changed_assets,
    session.persist_index + ASSET_BINDING_CHANGES_PER_FRAME - 1
  )
  for index = session.persist_index, last do
    mark_asset_database_change(session.changed_assets[index])
  end
  session.persist_index = last + 1
  if session.persist_index > #session.changed_assets then
    finish_asset_library_binding_refresh(session)
  end
end

function db_to_amp(db)
  return 10 ^ ((tonumber(db) or 0) / 20)
end

function format_time(seconds)
  seconds = tonumber(seconds) or 0

  if seconds >= 60 then
    local minutes = math.floor(seconds / 60)
    return string.format(
      "%02d:%06.3f",
      minutes,
      seconds - minutes * 60
    )
  end

  return string.format("%02.3f", seconds)
end

function format_duration_clock(seconds)
  local total_ms = math.max(
    0,
    math.floor((tonumber(seconds) or 0) * 1000 + 0.5)
  )
  local minutes = math.floor(total_ms / 60000)
  local whole_seconds = math.floor((total_ms % 60000) / 1000)
  local milliseconds = total_ms % 1000

  return string.format(
    "%02d:%02d.%03d",
    minutes,
    whole_seconds,
    milliseconds
  )
end

function format_rate(sample_rate)
  sample_rate = tonumber(sample_rate) or 0

  if sample_rate <= 0 then
    return "—"
  end

  return string.format("%.1fk", sample_rate / 1000)
end

function utf8_length(text)
  text = tostring(text or "")
  return utf8.len(text)
end

function utf8_prefix(text, character_count)
  text = tostring(text or "")

  if character_count <= 0 then
    return ""
  end

  local byte_index =
    utf8.offset(
      text,
      character_count + 1
    )

  if byte_index then
    return text:sub(1, byte_index - 1)
  end

  return text
end

function compact(text, max_chars)
  text = tostring(text or "")
  max_chars =
    math.max(
      1,
      math.floor(tonumber(max_chars) or 1)
    )

  local length = utf8_length(text)

  -- 旧索引若含无效 UTF-8，不再截断，防止继续产生替换字符。
  if not length or length <= max_chars then
    return text
  end

  if max_chars <= 3 then
    return utf8_prefix(text, max_chars)
  end

  return utf8_prefix(
    text,
    max_chars - 3
  ) .. "..."
end

function fit_text_to_width(text, maximum_width)
  text = tostring(text or "")
  maximum_width = math.max(1, tonumber(maximum_width) or 1)

  local full_width =
    select(1, ImGui.CalcTextSize(ctx, text)) or 0

  if full_width <= maximum_width then
    return text
  end

  local length = utf8_length(text)

  if not length then
    return compact(text, 24)
  end

  local low, high = 1, math.max(1, length)
  local fitted = compact(text, 1)

  while low <= high do
    local middle = math.floor((low + high) / 2)
    local candidate = compact(text, middle)
    local candidate_width =
      select(1, ImGui.CalcTextSize(ctx, candidate)) or 0

    if candidate_width <= maximum_width then
      fitted = candidate
      low = middle + 1
    else
      high = middle - 1
    end
  end

  return fitted
end

function escape_tsv(value)
  return tostring(value or ""):gsub(
    "[%%\t\r\n]",
    function(char)
      return string.format(
        "%%%02X",
        string.byte(char)
      )
    end
  )
end

function unescape_tsv(value)
  return (value or ""):gsub(
    "%%(%x%x)",
    function(hex)
      return string.char(tonumber(hex, 16))
    end
  )
end

function split_tsv(line)
  local fields = {}

  for field in (line .. "\t"):gmatch("(.-)\t") do
    fields[#fields + 1] = unescape_tsv(field)
  end

  return fields
end

function split_words(text)
  local words = {}
  local current = ""
  local quoted = false
  local quote_char = nil

  for i = 1, #text do
    local char = text:sub(i, i)

    if quoted then
      if char == quote_char then
        quoted = false
      else
        current = current .. char
      end
    elseif char == '"' or char == "'" then
      quoted = true
      quote_char = char
    elseif char:match("%s") then
      if current ~= "" then
        words[#words + 1] = current
        current = ""
      end
    else
      current = current .. char
    end
  end

  if current ~= "" then
    words[#words + 1] = current
  end

  return words
end

function fnv1a(text)
  local hash = 2166136261

  for i = 1, #text do
    hash = ((hash ~ text:byte(i)) * 16777619)
      & 0xFFFFFFFF
  end

  return string.format("%08x", hash)
end

function mark_interaction()
  state.interaction_until =
    reaper.time_precise() + 0.16
end

function can_run_heavy_job()
  return reaper.time_precise()
      >= state.interaction_until
    and not ImGui.IsMouseDown(ctx, 0)
    and not ImGui.IsMouseDown(ctx, 1)
end

function normalized_cache_directory(path)
  local normalized =
    normalize_slashes(
      trim(path or "")
    )

  if normalized == "" then
    normalized = DEFAULT_WAVE_CACHE_DIR
  end

  return normalized
end

function apply_wave_cache_directory(path)
  local normalized =
    normalized_cache_directory(path)

  WAVE_CACHE_DIR = normalized
  state.wave_cache_dir = normalized

  reaper.RecursiveCreateDirectory(
    WAVE_CACHE_DIR,
    0
  )

  return WAVE_CACHE_DIR
end

function ensure_dirs()
  reaper.RecursiveCreateDirectory(DATA_DIR, 0)
  reaper.RecursiveCreateDirectory(BACKUP_DIR, 0)
  reaper.RecursiveCreateDirectory(CACHE_QUARANTINE_DIR, 0)
  apply_wave_cache_directory(
    state.wave_cache_dir
      or DEFAULT_WAVE_CACHE_DIR
  )
end


function read_small_text_file(path)
  local file = io.open(path, "rb")

  if not file then
    return ""
  end

  local content =
    file:read(8192) or ""

  file:close()
  return content
end

function write_project_url_file(url)
  url = trim(url or "")

  if url == "" then
    return false
  end

  reaper.RecursiveCreateDirectory(
    DATA_DIR,
    0
  )

  local file =
    atomic_file_writer(
      PROJECT_URL_FILE
    )

  if not file then
    return false
  end

  file:write(url, "\n")
  return file:close()
end

-- One owner for background generations and exclusive resources. Operations
-- keep their token until all per-frame work has unwound; cancellation only
-- flips the token and never releases a newer generation by mistake.
Jobs = {
  generation = 0,
  accepting = true,
  active = {},
  history = {},
}

-- Controlled mutation boundary for new modules. Legacy UI code still reads
-- the shared table directly, but new services can update it through this API
-- and tests can inject an isolated table without booting ReaImGui.

function new_state_store(initial_state)
  assert(type(initial_state) == "table", "state table is required")
  local store = { raw = initial_state }

  function store.get(name)
    return initial_state[name]
  end

  function store.set(name, value)
    assert(type(name) == "string" and name ~= "", "state key is required")
    initial_state[name] = value
    return value
  end

  function store.update(name, updater)
    assert(type(updater) == "function", "state updater is required")
    return store.set(name, updater(initial_state[name]))
  end

  function store.mark_dirty(name)
    return store.set(name, true)
  end

  function store.apply(values)
    assert(type(values) == "table", "state values are required")
    for name, value in pairs(values) do
      store.set(name, value)
    end
  end

  return store
end

AppState = new_state_store(state)

-- Injectable boundary for REAPER, SWS and ReaImGui host APIs. Runtime code
-- uses the real global table; command-line tests can supply a small stub.

function new_reaper_host_adapter(api)
  assert(type(api) == "table", "host API table is required")
  local adapter = { raw = api }
  return setmetatable(adapter, {
    __index = function(target, name)
      local value = api[name]
      if type(value) ~= "function" then
        return value
      end
      local wrapper = function(...)
        return value(...)
      end
      rawset(target, name, wrapper)
      return wrapper
    end,
  })
end

function host_api_available(api, name)
  local target = api or Host
  return type(target) == "table"
    and type(target[name]) == "function"
end

Host = new_reaper_host_adapter(reaper)

-- Background jobs, atomic storage, recovery and cache maintenance.
local HostApi = Host or reaper

function Jobs.begin(
  kind,
  resource,
  replace_same_kind,
  priority
)
  if not Jobs.accepting then
    return nil, "shutting_down"
  end

  local previous = Jobs.active[kind]

  if previous then
    if not replace_same_kind then
      return nil, "already_running"
    end

    previous.cancel_requested = true
    previous.state = "canceling"
  end

  for active_kind, token in pairs(Jobs.active) do
    if active_kind ~= kind
      and token.state ~= "completed"
      and token.state ~= "failed"
      and token.resource == resource then
      return nil, "resource_busy"
    end
  end

  Jobs.generation = Jobs.generation + 1

  local token = {
    kind = kind,
    resource = resource,
    generation = Jobs.generation,
    priority = tonumber(priority) or 50,
    state = "running",
    cancel_requested = false,
    started = HostApi.time_precise(),
  }

  Jobs.active[kind] = token
  return token
end

function Jobs.is_current(token)
  return token
    and Jobs.active[token.kind] == token
    and not token.cancel_requested
end

function Jobs.cancel(token_or_kind)
  local token = type(token_or_kind) == "table"
    and token_or_kind
    or Jobs.active[token_or_kind]

  if not token or token.finished then
    return false
  end

  token.cancel_requested = true
  token.state = "canceling"
  return true
end

function Jobs.finish(token, success, message)
  if not token or token.finished then
    return
  end

  token.finished = HostApi.time_precise()
  token.message = tostring(message or "")
  token.state = token.cancel_requested
    and "canceled"
    or success == false and "failed"
    or "completed"

  if Jobs.active[token.kind] == token then
    Jobs.active[token.kind] = nil
  end

  Jobs.history[#Jobs.history + 1] = token

  while #Jobs.history > 64 do
    table.remove(Jobs.history, 1)
  end
end

function Jobs.active_kind(kind)
  return Jobs.active[kind] ~= nil
end

function Jobs.stop_accepting()
  Jobs.accepting = false

  for _, token in pairs(Jobs.active) do
    Jobs.cancel(token)
  end
end

function extract_project_url_from_text(content)
  content = tostring(content or "")

  local patterns = {
    'local%s+PROJECT_URL%s*=%s*"([^"]+)"',
    "local%s+PROJECT_URL%s*=%s*'([^']+)'",
    "%-%-%s*@link%s+(https?://%S+)",
    "%-%-%s*@website%s+(https?://%S+)",
  }

  for _, pattern in ipairs(patterns) do
    local value =
      content:match(pattern)

    value = trim(value or "")

    if value:match("^https?://") then
      return value
    end
  end

  return ""
end

function extract_project_url_from_script(path)
  if not path or path == "" then
    return ""
  end

  return extract_project_url_from_text(
    read_small_text_file(path)
  )
end

function find_project_url_in_sibling_scripts()
  if SCRIPT_DIR == "" then
    return ""
  end

  local current_name =
    basename(SCRIPT_FILE)

  local candidates = {}
  local index = 0

  while true do
    local filename =
      HostApi.EnumerateFiles(
        SCRIPT_DIR,
        index
      )

    if not filename then
      break
    end

    if filename ~= current_name
      and filename:match(
        "^PsyReaSFX.*%.lua$"
      ) then
      candidates[#candidates + 1] =
        filename
    end

    index = index + 1
  end

  table.sort(
    candidates,
    function(a, b)
      return a > b
    end
  )

  for _, filename in ipairs(candidates) do
    local value =
      extract_project_url_from_script(
        join_path(
          SCRIPT_DIR,
          filename
        )
      )

    if value ~= "" then
      return value
    end
  end

  return ""
end

function load_or_migrate_project_url()
  local hardcoded =
    trim(PROJECT_URL or "")

  if hardcoded ~= "" then
    PROJECT_URL = hardcoded
    write_project_url_file(hardcoded)
    return
  end

  local persisted =
    trim(
      read_small_text_file(
        PROJECT_URL_FILE
      )
    )

  if persisted:match("^https?://") then
    PROJECT_URL = persisted
    return
  end

  local embedded =
    extract_project_url_from_script(
      SCRIPT_FILE
    )

  if embedded == "" then
    embedded =
      find_project_url_in_sibling_scripts()
  end

  if embedded ~= "" then
    PROJECT_URL = embedded
    write_project_url_file(embedded)
  end
end

function copy_file_streaming(
  source_path,
  target_path
)
  local temporary_path =
    target_path .. ".psyreasfx_tmp"
  os.remove(temporary_path)

  if not stream_file_to_temporary(
    source_path,
    temporary_path
  ) then
    return false
  end

  return commit_atomic_temporary(
    target_path,
    temporary_path
  )
end

function stream_file_to_temporary(
  source_path,
  temporary_path
)
  local input = io.open(source_path, "rb")

  if not input then
    return false
  end

  local output = io.open(temporary_path, "wb")

  if not output then
    input:close()
    return false
  end

  local ok = true

  while true do
    local chunk, read_error = input:read(1024 * 1024)

    if not chunk then
      if read_error then
        ok = false
      end
      break
    end

    if state.persistence_fault_injection == "write"
      or not output:write(chunk) then
      ok = false
      break
    end
  end

  input:close()
  local flushed = output:flush()
  local closed = output:close()

  if not ok or not flushed or not closed then
    os.remove(temporary_path)
    return false
  end

  if state.persistence_fault_injection == "after_close" then
    os.remove(temporary_path)
    return false
  end

  return true
end

function commit_atomic_temporary(
  target_path,
  temporary_path,
  backup_path,
  keep_backup
)
  backup_path = backup_path or (target_path .. ".bak")
  local had_original = HostApi.file_exists(target_path)
  os.remove(backup_path)

  if had_original
    and not os.rename(target_path, backup_path) then
    os.remove(temporary_path)
    return false, had_original
  end

  if state.persistence_fault_injection == "after_backup" then
    if had_original then
      os.rename(backup_path, target_path)
    end
    os.remove(temporary_path)
    return false, had_original
  end

  if not os.rename(
    temporary_path,
    target_path
  ) then
    if had_original then
      os.rename(backup_path, target_path)
    end
    os.remove(temporary_path)
    return false, had_original
  end

  if not keep_backup then
    os.remove(backup_path)
  end
  return true, had_original
end

function persistent_data_files()
  return {
    CONFIG_FILE,
    LIBRARIES_FILE,
    DATABASE_FILE,
    DATABASE_JOURNAL_FILE,
    COLLECTIONS_FILE,
    PROJECT_USAGE_FILE,
    SAVED_SEARCHES_FILE,
    HISTORY_FILE,
    LAST_PLAYED_SESSION_FILE,
    REGIONS_FILE,
    LOUDNESS_FILE,
    FAILED_TASKS_FILE,
    BACKUP_STATE_FILE,
    MIGRATION_LOG_FILE,
    PROJECT_URL_FILE,
  }
end

local PERSISTENCE_SCHEMA_MAGIC = "psyreasfx_schema"
local PERSISTENCE_SCHEMAS = {
  [CONFIG_FILE] = {
    kind = "config",
    version = 1,
    dirty_flag = "config_dirty",
  },
  [LIBRARIES_FILE] = {
    kind = "libraries",
    version = 2,
    dirty_flag = "libraries_dirty",
  },
  [DATABASE_FILE] = {
    kind = "database",
    version = 3,
    dirty_flag = "db_dirty",
  },
  [COLLECTIONS_FILE] = {
    kind = "collections",
    version = 1,
    dirty_flag = "collections_dirty",
  },
  [PROJECT_USAGE_FILE] = {
    kind = "project_usage",
    version = 1,
    dirty_flag = "project_usage_dirty",
  },
  [SAVED_SEARCHES_FILE] = {
    kind = "saved_searches",
    version = 1,
    dirty_flag = "searches_dirty",
  },
  [HISTORY_FILE] = {
    kind = "history",
    version = 1,
    dirty_flag = "history_dirty",
  },
  [LAST_PLAYED_SESSION_FILE] = {
    kind = "last_played",
    version = 1,
  },
  [REGIONS_FILE] = {
    kind = "regions",
    version = 1,
    dirty_flag = "regions_dirty",
  },
  [LOUDNESS_FILE] = {
    kind = "loudness",
    version = 1,
    dirty_flag = "loudness_dirty",
  },
  [FAILED_TASKS_FILE] = {
    kind = "failed_tasks",
    version = 1,
    dirty_flag = "failed_tasks_dirty",
  },
  [BACKUP_STATE_FILE] = {
    kind = "backup_state",
    version = 1,
  },
  [MIGRATION_LOG_FILE] = {
    kind = "migration_log",
    version = 1,
  },
}

-- Every published format advances one version at a time. Loaders normalize
-- older rows into the current in-memory model; these explicit edges are the
-- audit contract that authorizes the final atomic rewrite. A missing edge is a
-- hard stop rather than permission to jump directly to the newest schema.
local PERSISTENCE_MIGRATIONS = {
  [CONFIG_FILE] = { [0] = 1 },
  [LIBRARIES_FILE] = { [0] = 1, [1] = 2 },
  [DATABASE_FILE] = { [0] = 1, [1] = 2, [2] = 3 },
  [COLLECTIONS_FILE] = { [0] = 1 },
  [PROJECT_USAGE_FILE] = { [0] = 1 },
  [SAVED_SEARCHES_FILE] = { [0] = 1 },
  [HISTORY_FILE] = { [0] = 1 },
  [LAST_PLAYED_SESSION_FILE] = { [0] = 1 },
  [REGIONS_FILE] = { [0] = 1 },
  [LOUDNESS_FILE] = { [0] = 1 },
  [FAILED_TASKS_FILE] = { [0] = 1 },
  [BACKUP_STATE_FILE] = { [0] = 1 },
}

function persistence_migration_path(target_path, from_version)
  local schema = PERSISTENCE_SCHEMAS[target_path]
  local registered = PERSISTENCE_MIGRATIONS[target_path]
  local current = tonumber(from_version)
  if not schema or not registered or not current
    or current < 0 or current % 1 ~= 0
    or current > schema.version then
    return nil, "invalid_start"
  end

  local steps = {}
  while current < schema.version do
    local next_version = registered[current]
    if next_version ~= current + 1 then
      return nil, "missing_step_" .. tostring(current)
    end
    steps[#steps + 1] = {
      from = current,
      to = next_version,
    }
    current = next_version
  end
  return steps
end

function persistence_schema_header(kind, version, generation)
  local fields = {
    PERSISTENCE_SCHEMA_MAGIC,
    kind,
    tostring(version),
  }
  if generation ~= nil then
    fields[#fields + 1] = "generation"
    fields[#fields + 1] = tostring(generation)
  end
  return table.concat(fields, "\t") .. "\n"
end

function persistence_schema_generation(fields)
  if not is_persistence_schema_fields(fields) then return 0 end
  for index = 4, #fields - 1 do
    if fields[index] == "generation" then
      local generation = tonumber(fields[index + 1])
      if generation and generation >= 0 and generation % 1 == 0 then
        return generation
      end
      return nil, "invalid_generation"
    end
  end
  return 0
end

function write_persistence_schema(file, target_path)
  local schema = PERSISTENCE_SCHEMAS[target_path]

  if not schema then
    return true
  end

  return file:write(
    persistence_schema_header(
      schema.kind,
      schema.version
    )
  ) ~= nil
end

function is_persistence_schema_fields(fields)
  return fields
    and fields[1] == PERSISTENCE_SCHEMA_MAGIC
end

function preflight_persistence_schemas()
  state.persistence_read_only = false
  state.persistence_read_only_reason = ""
  state.persistence_schema_versions = {}
  state.persistence_schema_legacy = {}

  local problems = {}
  if state.persistence_recovery_problem
    and state.persistence_recovery_problem ~= "" then
    problems[#problems + 1] =
      state.persistence_recovery_problem
  end

  for target_path, schema in pairs(PERSISTENCE_SCHEMAS) do
    local file = io.open(target_path, "rb")

    if file then
      local first_line = file:read("*l") or ""
      file:close()

      local fields = split_tsv(first_line)

      if is_persistence_schema_fields(fields) then
        local kind = fields[2] or ""
        local version = tonumber(fields[3])

        if kind ~= schema.kind then
          problems[#problems + 1] = string.format(
            "%s 的数据类型为 %s，预期为 %s",
            basename(target_path),
            kind ~= "" and kind or "未知",
            schema.kind
          )
        elseif not version
          or version < 1
          or version % 1 ~= 0 then
          problems[#problems + 1] = string.format(
            "%s 的格式版本无效",
            basename(target_path)
          )
        elseif version > schema.version then
          problems[#problems + 1] = string.format(
            "%s 使用未来格式 v%d（当前支持 v%d）",
            basename(target_path),
            version,
            schema.version
          )
        else
          state.persistence_schema_versions[target_path] =
            version
        end
      else
        -- All formats published before the hardening branch are schema 0.
        -- They remain readable and are rewritten atomically after startup.
        state.persistence_schema_versions[target_path] = 0
        state.persistence_schema_legacy[target_path] = true
      end
    end
  end

  if #problems > 0 then
    state.persistence_read_only = true
    state.persistence_read_only_reason =
      table.concat(problems, "；")
    set_status(
      "检测到不兼容的数据格式，已进入只读保护："
        .. state.persistence_read_only_reason,
      true
    )
    return false
  end

  return true
end

function schedule_legacy_schema_migrations()
  if state.persistence_read_only then
    return false
  end

  local pending = {}

  for target_path, schema in pairs(PERSISTENCE_SCHEMAS) do
    local current = state.persistence_schema_versions[target_path]

    if current ~= nil
      and current < schema.version
      and target_path ~= MIGRATION_LOG_FILE then
      local steps, path_error =
        persistence_migration_path(target_path, current)
      if not steps then
        state.persistence_read_only = true
        state.persistence_read_only_reason = string.format(
          "缺少数据迁移步骤：%s v%d（%s）",
          basename(target_path),
          current,
          tostring(path_error or "unknown")
        )
        set_status(
          state.persistence_read_only_reason
            .. "；已停止后续写入",
          true
        )
        return false
      end
      pending[#pending + 1] = {
        path = target_path,
        from = current,
        steps = steps,
      }
    end
  end

  if #pending == 0 then
    return true
  end

  table.sort(pending, function(a, b)
    return a.path < b.path
  end)

  if not create_data_backup("schema_migration", true) then
    state.persistence_read_only = true
    state.persistence_read_only_reason =
      "旧数据迁移前无法创建安全快照"
    set_status(
      "无法创建迁移快照，已进入只读保护",
      true
    )
    return false
  end

  local savers = {
    [CONFIG_FILE] = save_config,
    [LIBRARIES_FILE] = save_libraries,
    [DATABASE_FILE] = save_database,
    [COLLECTIONS_FILE] = save_collections,
    [PROJECT_USAGE_FILE] = save_project_usage,
    [SAVED_SEARCHES_FILE] = save_saved_searches,
    [HISTORY_FILE] = save_history,
    [LAST_PLAYED_SESSION_FILE] =
      migrate_last_played_session_schema,
    [REGIONS_FILE] = save_regions,
    [LOUDNESS_FILE] = save_loudness_cache,
    [FAILED_TASKS_FILE] = save_failed_tasks,
    [BACKUP_STATE_FILE] = save_backup_state,
  }

  for _, migration in ipairs(pending) do
    local target_path = migration.path
    local schema = PERSISTENCE_SCHEMAS[target_path]
    local saver = savers[target_path]
    local ok = true

    if schema and schema.dirty_flag then
      state[schema.dirty_flag] = true
    end

    if saver then
      ok = saver() ~= false
    end

    local kind = schema and schema.kind or basename(target_path)
    if ok then
      for _, step in ipairs(migration.steps) do
        if not append_schema_migration_log(
          kind,
          step.from,
          step.to,
          "completed"
        ) then
          ok = false
          break
        end
      end
    else
      local first_step = migration.steps[1]
      append_schema_migration_log(
        kind,
        first_step and first_step.from or migration.from,
        first_step and first_step.to or (schema and schema.version or 0),
        "failed"
      )
    end

    if not ok then
      state.persistence_read_only = true
      state.persistence_read_only_reason =
        "数据格式迁移失败：" .. basename(target_path)
      set_status(
        state.persistence_read_only_reason
          .. "；已停止后续写入",
        true
      )
      return false
    end

    state.persistence_schema_legacy[target_path] = nil
    state.persistence_schema_versions[target_path] =
      schema and schema.version or 0
  end


  return true
end

function append_schema_migration_log(
  kind,
  from_version,
  to_version,
  result
)
  if state.persistence_read_only then
    return false
  end

  local existed = HostApi.file_exists(MIGRATION_LOG_FILE)
  local file = io.open(MIGRATION_LOG_FILE, "ab")

  if not file then
    return false
  end

  if not existed then
    file:write(
      persistence_schema_header("migration_log", 1)
    )
  end

  file:write(
    "migration\t",
    escape_tsv(os.date("%Y-%m-%d %H:%M:%S")),
    "\t",
    escape_tsv(kind or "unknown"),
    "\t",
    tostring(from_version or 0),
    "\t",
    tostring(to_version or 0),
    "\t",
    escape_tsv(result or "unknown"),
    "\n"
  )
  file:flush()
  file:close()
  return true
end

-- Persistent TSV/config files used to be written directly to their final
-- path. A REAPER crash or power loss during file:write() could therefore
-- replace valid data with a truncated file. Keep the previous generation as
-- a short-lived rollback and only expose a fully closed temporary file.
function atomic_file_writer(target_path)
  if state.persistence_read_only then
    return nil,
      state.persistence_read_only_reason ~= ""
        and state.persistence_read_only_reason
        or "persistence is read-only"
  end

  local temporary_path = target_path .. ".tmp"
  local backup_path = target_path .. ".bak"
  os.remove(temporary_path)

  local raw, open_error = io.open(temporary_path, "wb")
  if not raw then
    return nil, open_error
  end

  local writer = {
    raw = raw,
    target_path = target_path,
    temporary_path = temporary_path,
    backup_path = backup_path,
    failed = false,
    failure = nil,
    closed = false,
  }

  function writer:write(...)
    if self.closed or self.failed then
      return nil, self.failure or "writer is closed"
    end

    if state.persistence_fault_injection == "write" then
      self.failed = true
      self.failure = "injected write failure"
      return nil, self.failure
    end

    local ok, message = self.raw:write(...)
    if not ok then
      self.failed = true
      self.failure = message or "write failed"
      return nil, self.failure
    end
    return self
  end

  function writer:close()
    if self.closed then
      return not self.failed, self.failure
    end
    self.closed = true

    local flushed, flush_error = self.raw:flush()
    local closed, close_error = self.raw:close()
    if self.failed or not flushed or not closed then
      os.remove(self.temporary_path)
      self.failure = self.failure or flush_error or close_error
        or "could not finish temporary file"
      return false, self.failure
    end

    if state.persistence_fault_injection == "after_close" then
      os.remove(self.temporary_path)
      return false, "injected failure after temporary close"
    end

    local committed = commit_atomic_temporary(
      self.target_path,
      self.temporary_path,
      self.backup_path
    )
    if not committed then
      return false, "could not install completed file"
    end
    return true
  end

  function writer:abort()
    if self.closed then
      return false
    end
    self.closed = true
    pcall(function() self.raw:close() end)
    os.remove(self.temporary_path)
    return true
  end

  return writer
end

function recover_atomic_data_files()
  local files = persistent_data_files()
  local unresolved = {}
  local restore_committed =
    HostApi.file_exists(RESTORE_TRANSACTION_COMMIT_FILE)
  files[#files + 1] = SCAN_CHECKPOINT_FILE
  for _, target_path in ipairs(files) do
    local backup_path = target_path .. ".bak"
    local temporary_path = target_path .. ".tmp"
    local restore_backup_path = target_path .. ".restore.bak"
    local restore_temporary_path = target_path .. ".restore.tmp"
    local restore_new_path = target_path .. ".restore.new"

    -- A transaction marker is installed only after every restored file has
    -- committed. With the marker, finish cleanup and retain the new generation;
    -- without it, roll every touched file back to its previous generation.
    local restore_pending = false
    if restore_committed then
      for _, artifact_path in ipairs({
        restore_backup_path,
        restore_temporary_path,
        restore_new_path,
      }) do
        if HostApi.file_exists(artifact_path)
          and not os.remove(artifact_path) then
          restore_pending = true
        end
      end
    elseif HostApi.file_exists(restore_backup_path) then
      local removed = not HostApi.file_exists(target_path)
        or os.remove(target_path) ~= nil
      if not removed
        or not os.rename(restore_backup_path, target_path) then
        restore_pending = true
      end
    elseif HostApi.file_exists(restore_new_path) then
      if HostApi.file_exists(target_path)
        and not os.remove(target_path) then
        restore_pending = true
      end
    end
    if not restore_committed then
      os.remove(restore_temporary_path)
      if not restore_pending then
        os.remove(restore_new_path)
      end
    end
    if restore_pending then
      unresolved[#unresolved + 1] = basename(target_path)
    end

    if not restore_pending
      and not HostApi.file_exists(target_path)
      and HostApi.file_exists(backup_path) then
      os.rename(backup_path, target_path)
    elseif not restore_pending
      and HostApi.file_exists(target_path) then
      os.remove(backup_path)
    end

    -- A .tmp without a rollback may have been interrupted while writing and
    -- is never trusted as user data.
    os.remove(temporary_path)
  end
  if restore_committed and #unresolved == 0 then
    os.remove(RESTORE_TRANSACTION_COMMIT_FILE)
    if HostApi.file_exists(RESTORE_TRANSACTION_COMMIT_FILE) then
      unresolved[#unresolved + 1] =
        basename(RESTORE_TRANSACTION_COMMIT_FILE)
    end
  end
  state.persistence_recovery_problem = #unresolved > 0
    and ("未能回滚中断的备份恢复："
      .. table.concat(unresolved, ", "))
    or ""
end

function remove_shallow_directory(path)
  while true do
    local filename = HostApi.EnumerateFiles(path, 0)

    if not filename then
      break
    end

    os.remove(join_path(path, filename))
  end

  return os.remove(path)
end

function save_backup_state()
  ensure_dirs()

  local file = atomic_file_writer(BACKUP_STATE_FILE)

  if not file then
    return false
  end

  write_persistence_schema(file, BACKUP_STATE_FILE)
  file:write("last_date\t", escape_tsv(state.backup_last_date or ""), "\n")
  return file:close()
end

function load_backup_state()
  local file = io.open(BACKUP_STATE_FILE, "rb")

  if not file then
    return
  end

  for line in file:lines() do
    local fields = split_tsv(line)

    if fields[1] == "last_date" then
      state.backup_last_date = fields[2] or ""
    end
  end

  file:close()
end

function backup_directories()
  local result = {}
  local index = 0

  while true do
    local name = HostApi.EnumerateSubdirectories(BACKUP_DIR, index)

    if not name then
      break
    end

    if name:match("^%d%d%d%d%d%d%d%d_%d%d%d%d%d%d") then
      result[#result + 1] = name
    end

    index = index + 1
  end

  table.sort(result, function(a, b) return a > b end)
  return result
end

function prune_data_backups()
  local names = backup_directories()
  local keep = clamp(math.floor(state.backup_keep_count or 7), 1, 30)

  for index = keep + 1, #names do
    remove_shallow_directory(join_path(BACKUP_DIR, names[index]))
  end
end

function create_data_backup(reason, quiet)
  ensure_dirs()

  local date_key = os.date("%Y%m%d")
  local directory_name = os.date("%Y%m%d_%H%M%S")
    .. "_"
    .. (reason == "auto" and "auto" or "manual")
  local directory = join_path(BACKUP_DIR, directory_name)

  local suffix = 2
  while directory_exists(directory) do
    directory_name = os.date("%Y%m%d_%H%M%S")
      .. "_"
      .. (reason == "auto" and "auto" or "manual")
      .. "_"
      .. tostring(suffix)
    directory = join_path(BACKUP_DIR, directory_name)
    suffix = suffix + 1
  end

  if HostApi.RecursiveCreateDirectory(directory, 0) <= 0 then
    if not quiet then
      set_status("无法创建数据备份目录", true)
    end
    return false
  end

  local copied = 0
  local expected = 0
  local failed = 0

  for _, source_path in ipairs(persistent_data_files()) do
    if HostApi.file_exists(source_path) then
      expected = expected + 1
      local inject_partial =
        state.persistence_fault_injection
          == "backup_after_first"
        and copied > 0
      if not inject_partial
        and copy_file_streaming(
        source_path,
        join_path(directory, basename(source_path))
      ) then
        copied = copied + 1
      else
        failed = failed + 1
      end
    end
  end

  local manifest_path = join_path(directory, "manifest.tsv")
  local manifest = io.open(manifest_path, "wb")
  local manifest_ok = false

  if manifest then
    local wrote = manifest:write("version\t", VERSION, "\n")
      and manifest:write("created\t", os.date("%Y-%m-%d %H:%M:%S"), "\n")
      and manifest:write("reason\t", reason or "manual", "\n")
      and manifest:write("files\t", tostring(copied), "\n")
    local flushed = manifest:flush()
    local closed = manifest:close()
    manifest_ok = wrote ~= nil and flushed ~= nil and closed ~= nil
  end

  if expected <= 0 then
    remove_shallow_directory(directory)
    if not quiet then
      set_status("没有可备份的数据文件", true)
    end
    return false
  end

  if copied ~= expected or failed > 0 or not manifest_ok then
    remove_shallow_directory(directory)
    if not quiet then
      set_status("无法完整创建数据备份", true)
    end
    return false
  end

  state.backup_last_date = date_key
  save_backup_state()
  prune_data_backups()

  if not quiet then
    set_status("数据备份已创建：" .. directory_name)
  end

  return true
end

function restore_data_backup_transaction(directory)
  local plan = {}
  if HostApi.file_exists(RESTORE_TRANSACTION_COMMIT_FILE)
    and not os.remove(RESTORE_TRANSACTION_COMMIT_FILE) then
    return false, 0, "stale_commit_marker"
  end

  for _, target_path in ipairs(persistent_data_files()) do
    local source_path = join_path(directory, basename(target_path))

    if HostApi.file_exists(source_path) then
      local temporary_path = target_path .. ".restore.tmp"
      os.remove(temporary_path)
      if not stream_file_to_temporary(
        source_path,
        temporary_path
      ) then
        for _, item in ipairs(plan) do
          if item.temporary_path then
            os.remove(item.temporary_path)
          end
        end
        return false, 0, "stage"
      end
      plan[#plan + 1] = {
        target_path = target_path,
        temporary_path = temporary_path,
        backup_path = target_path .. ".restore.bak",
        new_marker_path = target_path .. ".restore.new",
        had_original = false,
      }
    elseif target_path == DATABASE_JOURNAL_FILE
      and HostApi.file_exists(target_path) then
      -- Backups created before incremental persistence have no journal.
      -- Removing the current one is part of the same rollback-safe restore,
      -- otherwise post-backup edits could reappear over the restored snapshot.
      plan[#plan + 1] = {
        target_path = target_path,
        temporary_path = nil,
        backup_path = target_path .. ".restore.bak",
        new_marker_path = target_path .. ".restore.new",
        had_original = true,
        delete_only = true,
      }
    end
  end

  if #plan == 0 then
    return false, 0, "empty"
  end

  local committed = 0
  for index, item in ipairs(plan) do
    item.had_original = HostApi.file_exists(item.target_path)
    local marker_ok = true
    if not item.had_original and not item.delete_only then
      local marker = io.open(item.new_marker_path, "wb")
      if marker then
        marker_ok = marker:close() ~= nil
      else
        marker_ok = false
      end
    end
    local ok = false
    local had_original = item.had_original
    if marker_ok and item.delete_only then
      os.remove(item.backup_path)
      ok = item.had_original
        and os.rename(item.target_path, item.backup_path) ~= nil
    elseif marker_ok then
      ok, had_original = commit_atomic_temporary(
        item.target_path,
        item.temporary_path,
        item.backup_path,
        true
      )
    end
    item.had_original = had_original == true
    if ok then
      committed = index
    end

    if ok
      and state.persistence_fault_injection
        == "restore_after_first"
      and index == 1 then
      ok = false
    end
    if ok
      and item.delete_only
      and state.persistence_fault_injection
        == "restore_after_journal_delete" then
      ok = false
    end

    if not ok then
      if item.temporary_path then os.remove(item.temporary_path) end
      os.remove(item.new_marker_path)
      for rollback = committed, 1, -1 do
        local previous = plan[rollback]
        local target_removed =
          not HostApi.file_exists(previous.target_path)
          or os.remove(previous.target_path) ~= nil
        if previous.had_original then
          os.rename(
            previous.backup_path,
            previous.target_path
          )
        else
          os.remove(previous.backup_path)
          if target_removed then
            os.remove(previous.new_marker_path)
          end
        end
      end
      for cleanup = index + 1, #plan do
        if plan[cleanup].temporary_path then
          os.remove(plan[cleanup].temporary_path)
        end
      end
      return false, 0, "commit"
    end
  end

  local commit_marker_temporary =
    RESTORE_TRANSACTION_COMMIT_FILE .. ".tmp"
  os.remove(commit_marker_temporary)
  local marker = io.open(commit_marker_temporary, "wb")
  local marker_ok = false
  if marker then
    local wrote = marker:write("committed\t1\n")
    local flushed = marker:flush()
    local closed = marker:close()
    marker_ok = wrote ~= nil and flushed ~= nil and closed ~= nil
  end
  if state.persistence_fault_injection
      == "restore_commit_marker" then
    marker_ok = false
  end
  if marker_ok then
    marker_ok = os.rename(
      commit_marker_temporary,
      RESTORE_TRANSACTION_COMMIT_FILE
    ) ~= nil
  end
  if not marker_ok then
    os.remove(commit_marker_temporary)
    for rollback = #plan, 1, -1 do
      local previous = plan[rollback]
      if HostApi.file_exists(previous.target_path) then
        os.remove(previous.target_path)
      end
      if previous.had_original then
        os.rename(previous.backup_path, previous.target_path)
      else
        os.remove(previous.backup_path)
        os.remove(previous.new_marker_path)
      end
    end
    return false, 0, "commit_marker"
  end

  for _, item in ipairs(plan) do
    os.remove(item.backup_path)
    os.remove(item.new_marker_path)
  end
  os.remove(RESTORE_TRANSACTION_COMMIT_FILE)
  return true, #plan
end

function restore_latest_data_backup()
  local names = backup_directories()
  local name = names[1]

  if not name then
    set_status("没有可恢复的数据备份", true)
    return
  end

  local answer = HostApi.MB(
    "将恢复最近的数据备份：\n\n"
      .. name
      .. "\n\n恢复后 PsyReaSFX 会关闭，请重新运行脚本。继续吗？",
    SCRIPT_NAME,
    4
  )

  if answer ~= 6 then
    return
  end

  local directory = join_path(BACKUP_DIR, name)
  local restored_ok, restored, restore_error =
    restore_data_backup_transaction(directory)

  if not restored_ok or restored <= 0 then
    if restore_error == "empty" then
      set_status("备份中没有可恢复的数据", true)
      return
    end
    state.persistence_read_only = true
    state.persistence_read_only_reason =
      "备份恢复未能完整提交，请重启 PsyReaSFX"
    set_status("备份恢复失败，原数据已回滚", true)
    return
  end

  state.skip_persistence_on_cleanup = true
  state.open = false
  HostApi.MB(
    "已恢复 " .. tostring(restored) .. " 个数据文件。\n\n请重新运行 PsyReaSFX。",
    SCRIPT_NAME,
    0
  )
end

function write_scan_checkpoint(scan, phase)
  if not scan or scan.checkpoint_enabled == false then
    return false
  end

  ensure_dirs()
  local file = atomic_file_writer(SCAN_CHECKPOINT_FILE)

  if not file then
    return false
  end

  file:write("version\t3\n")
  file:write("phase\t", escape_tsv(phase or "scan"), "\n")
  file:write("reason\t", escape_tsv(scan.reason or "扫描"), "\n")
  file:write("resume_allowed\t1\n")
  file:write("updated_at\t", tostring(os.time()), "\n")
  file:write(
    "force_rebuild\t",
    scan.force_rebuild and "1" or "0",
    "\n"
  )
  file:write("files\t", tostring(scan.files or 0), "\n")
  file:write("directories\t", tostring(scan.directories or 0), "\n")

  for _, root in ipairs(scan.roots or {}) do
    file:write("root\t", escape_tsv(root), "\n")
  end

  return file:close()
end

function clear_scan_checkpoint()
  os.remove(SCAN_CHECKPOINT_FILE)
end

function load_scan_checkpoint()
  local file = io.open(SCAN_CHECKPOINT_FILE, "rb")

  if not file then
    return nil
  end

  local checkpoint = {
    version = 0,
    roots = {},
    reason = "恢复中断扫描",
    force_rebuild = false,
    resume_allowed = false,
    updated_at = 0,
  }

  for line in file:lines() do
    local fields = split_tsv(line)

    if fields[1] == "version" then
      checkpoint.version = tonumber(fields[2]) or 0
    elseif fields[1] == "root" and fields[2] and fields[2] ~= "" then
      checkpoint.roots[#checkpoint.roots + 1] = normalize_slashes(fields[2])
    elseif fields[1] == "reason" and fields[2] and fields[2] ~= "" then
      checkpoint.reason = fields[2]
    elseif fields[1] == "force_rebuild" then
      checkpoint.force_rebuild = fields[2] == "1"
    elseif fields[1] == "resume_allowed" then
      checkpoint.resume_allowed = fields[2] == "1"
    elseif fields[1] == "updated_at" then
      checkpoint.updated_at = tonumber(fields[2]) or 0
    end
  end

  file:close()

  local checkpoint_age = os.time() - checkpoint.updated_at
  local invalid_checkpoint = checkpoint.version < 3
    or not checkpoint.resume_allowed
    or checkpoint.reason == "Watch Folder"
    or checkpoint.updated_at <= 0
    or checkpoint_age > 7 * 24 * 60 * 60

  if #checkpoint.roots == 0 or invalid_checkpoint then
    clear_scan_checkpoint()
    return nil
  end

  return checkpoint
end

function load_failed_tasks()
  state.failed_tasks = {}
  local file = io.open(FAILED_TASKS_FILE, "rb")

  if not file then
    return
  end

  for line in file:lines() do
    local fields = split_tsv(line)
    local path = is_persistence_schema_fields(fields)
      and ""
      or fields[1] or ""

    if path ~= "" then
      state.failed_tasks[path_key(path)] = {
        path = path,
        stage = fields[2] or "unknown",
        reason = fields[3] or "",
        attempts = tonumber(fields[4]) or 1,
        updated = tonumber(fields[5]) or 0,
      }
    end
  end

  file:close()
end

function save_failed_tasks()
  if state.root_removal_session then return false end
  ensure_dirs()
  local file = atomic_file_writer(FAILED_TASKS_FILE)

  if not file then
    set_status("无法保存失败任务", true)
    return false
  end

  write_persistence_schema(file, FAILED_TASKS_FILE)

  local job = new_failed_tasks_persistence_job(state.failed_tasks)
  local complete, failure
  repeat
    complete, failure = step_failed_tasks_persistence_job(
      job,
      file,
      AUXILIARY_SAVE_RECORDS_PER_FRAME,
      escape_tsv
    )
    if failure then
      file:abort()
      set_status("无法保存失败任务：" .. tostring(failure), true)
      return false
    end
  until complete

  if not file:close() then
    set_status("无法保存失败任务", true)
    return false
  end

  state.failed_tasks_dirty = false
  return true
end

function record_failed_task(asset, stage, reason)
  if not asset or not asset.path then
    return
  end

  local key = path_key(asset.path)
  local previous = state.failed_tasks[key]

  state.failed_tasks[key] = {
    path = asset.path,
    stage = stage or "unknown",
    reason = tostring(reason or "未知错误"),
    attempts = (previous and previous.attempts or 0) + 1,
    updated = os.time(),
  }
  state.failed_tasks_dirty = true
end

function clear_failed_task(asset_or_path)
  local path = type(asset_or_path) == "table"
    and asset_or_path.path
    or asset_or_path

  if path and state.failed_tasks[path_key(path)] then
    state.failed_tasks[path_key(path)] = nil
    state.failed_tasks_dirty = true
  end
end

function failed_task_count()
  local count = 0
  for _ in pairs(state.failed_tasks) do count = count + 1 end
  return count
end

function retry_failed_tasks()
  if state.scan or state.import_session or state.precache_session then
    set_status("请等待当前后台任务完成", true)
    return
  end

  local assets = {}

  for key, task in pairs(state.failed_tasks) do
    if HostApi.file_exists(task.path) then
      local asset = state.by_path[key]

      if not asset then
        local root = root_for_path(task.path)
        asset = add_or_update_asset(make_placeholder(task.path, root or ""))
      end

      asset.indexed = false
      asset.ready = false
      asset.pending_batch = true
      asset.wave_error = nil
      assets[#assets + 1] = asset
    end
  end

  if #assets == 0 then
    set_status("没有可重试的失败任务", true)
    return
  end

  local job_token =
    Jobs.begin(
      "catalog_pipeline",
      "catalog_exclusive",
      false
    )

  if not job_token then
    set_status("另一个目录写任务正在运行", true)
    return
  end

  state.import_session = {
    label = "重试失败任务",
    roots = {},
    assets = assets,
    total = #assets,
    done = 0,
    failed = 0,
    current = nil,
    started = HostApi.time_precise(),
    phase = "prepare",
    job_token = job_token,
  }
  state.import_cancel_requested = false
  set_status(string.format("正在重试 %d 个失败任务", #assets))
end

function reset_wave_cache_runtime()
  local precache = state.precache_session
  if state.wave_active
    and state.wave_active.job_token then
    Jobs.cancel(state.wave_active.job_token)
    Jobs.finish(
      state.wave_active.job_token,
      true,
      "cache reset"
    )
    state.wave_active.job_token = nil
  end
  destroy_wave_job(state.wave_active)
  state.wave_active = nil

  if state.precache_session
    and state.precache_session.current then
    destroy_wave_job(
      state.precache_session.current
    )
  end

  state.precache_session = nil
  state.precache_cancel_requested = false
  state.wave_cache = {}
  state.wave_cache_count = 0
  state.wave_checked = {}
  state.wave_queue = {}
  state.wave_queued = {}

  if precache and precache.job_token then
    Jobs.cancel(precache.job_token)
    Jobs.finish(
      precache.job_token,
      true,
      "cache reset"
    )
  end
end

function move_wave_cache_files(
  old_directory,
  new_directory
)
  old_directory =
    normalized_cache_directory(
      old_directory
    )

  new_directory =
    normalized_cache_directory(
      new_directory
    )

  if path_key(old_directory)
      == path_key(new_directory) then
    return 0, 0
  end

  HostApi.RecursiveCreateDirectory(
    new_directory,
    0
  )

  local filenames = {}
  local index = 0

  while true do
    local filename =
      HostApi.EnumerateFiles(
        old_directory,
        index
      )

    if not filename then
      break
    end

    filenames[#filenames + 1] =
      filename

    index = index + 1
  end

  local moved = 0
  local failed = 0

  for _, filename in ipairs(filenames) do
    local source_path =
      join_path(
        old_directory,
        filename
      )

    local target_path =
      join_path(
        new_directory,
        filename
      )

    if HostApi.file_exists(target_path) then
      os.remove(source_path)
      moved = moved + 1
    elseif copy_file_streaming(
      source_path,
      target_path
    ) then
      os.remove(source_path)
      moved = moved + 1
    else
      failed = failed + 1
    end
  end

  return moved, failed
end

function switch_wave_cache_directory(
  new_directory,
  move_existing
)
  local old_directory =
    normalized_cache_directory(
      state.wave_cache_dir
        or WAVE_CACHE_DIR
    )

  new_directory =
    normalized_cache_directory(
      new_directory
    )

  if path_key(old_directory)
      == path_key(new_directory) then
    set_status("波形缓存目录没有变化")
    return true
  end

  if path_is_inside(
      new_directory,
      old_directory
    ) or path_is_inside(
      old_directory,
      new_directory
    ) then
    set_status(
      "新旧缓存目录不能互相嵌套",
      true
    )
    return false
  end

  reset_wave_cache_runtime()

  local moved = 0
  local failed = 0

  if move_existing then
    moved, failed =
      move_wave_cache_files(
        old_directory,
        new_directory
      )
  else
    HostApi.RecursiveCreateDirectory(
      new_directory,
      0
    )
  end

  apply_wave_cache_directory(
    new_directory
  )

  state.config_dirty = true
  state.results_dirty = true

  if move_existing then
    set_status(
      string.format(
        "已切换缓存目录：移动 %d，失败 %d",
        moved,
        failed
      ),
      failed > 0
    )
  else
    set_status(
      "已切换波形缓存目录；旧缓存仍保留"
    )
  end

  return true
end

function prompt_wave_cache_directory()
  local ok, input =
    HostApi.GetUserInputs(
      "更改波形缓存目录",
      1,
      "新缓存目录路径:",
      state.wave_cache_dir
        or WAVE_CACHE_DIR
    )

  if not ok then
    return
  end

  local new_directory =
    normalized_cache_directory(input)

  local answer =
    HostApi.MB(
      "是否将现有波形缓存移动到新目录？\n\n"
        .. "是：移动已有缓存并切换。\n"
        .. "否：直接切换，旧目录保持不变。\n"
        .. "取消：不修改。",
      SCRIPT_NAME,
      3
    )

  if answer == 2 then
    return
  end

  switch_wave_cache_directory(
    new_directory,
    answer == 6
  )
end

function restore_default_wave_cache_directory()
  local target =
    DEFAULT_WAVE_CACHE_DIR

  if path_key(
    state.wave_cache_dir
      or WAVE_CACHE_DIR
  ) == path_key(target) then
    set_status("当前已经使用默认缓存目录")
    return
  end

  local answer =
    HostApi.MB(
      "恢复默认缓存目录，并移动现有缓存？\n\n"
        .. target,
      SCRIPT_NAME,
      3
    )

  if answer == 2 then
    return
  end

  switch_wave_cache_directory(
    target,
    answer == 6
  )
end

function migrate_legacy_data()
  ensure_dirs()

  if not HostApi.file_exists(CONFIG_FILE)
    and HostApi.file_exists(LEGACY_CONFIG_FILE) then
    if copy_file_streaming(LEGACY_CONFIG_FILE, CONFIG_FILE) then
      set_status("已迁移旧版音效库路径与偏好设置")
    end
  end
end

----------------------------------------------------------------
-- UCS and placeholder assets
----------------------------------------------------------------

-- Official UCS catalog loading and deterministic classification primitives.

UCS_CATALOG_SCHEMA = "ucs_catalog_v1"
UCS_CATALOG_VERSION = "8.2.1"
UCS_CLASSIFIER_VERSION = "filename-keywords-v1"
UCS_RECLASSIFY_ITEMS_PER_FRAME = 256
UCS_RECLASSIFY_FRAME_BUDGET = 0.004
UCS_CLASSIFICATION_FIELDS = {
  "catid",
  "category",
  "subcategory",
  "ucs_status",
  "ucs_source",
  "ucs_version",
  "ucs_classifier_version",
  "ucs_confidence",
  "ucs_candidates",
  "ucs_evidence",
}

UcsCatalog = {
  attempted = false,
  loaded = false,
  error = "",
  entries = {},
  by_catid = {},
  by_pair = {},
  categories = {},
  category_order = {},
  term_index = {},
  max_term_words = 1,
}

function ucs_reset_catalog()
  UcsCatalog.attempted = false
  UcsCatalog.loaded = false
  UcsCatalog.error = ""
  UcsCatalog.entries = {}
  UcsCatalog.by_catid = {}
  UcsCatalog.by_pair = {}
  UcsCatalog.categories = {}
  UcsCatalog.category_order = {}
  UcsCatalog.term_index = {}
  UcsCatalog.max_term_words = 1
end

function ucs_pair_key(category, subcategory)
  return string.upper(trim(category or ""))
    .. "\0"
    .. string.upper(trim(subcategory or ""))
end

function ucs_header_map(fields)
  local map = {}
  for index, field in ipairs(fields or {}) do
    map[field] = index
  end
  return map
end

function ucs_field(fields, headers, name)
  local index = headers[name]
  return index and trim(fields[index] or "") or ""
end

function load_ucs_catalog(path)
  ucs_reset_catalog()
  UcsCatalog.attempted = true

  local file = io.open(path or UCS_CATALOG_PATH, "rb")
  if not file then
    UcsCatalog.error = "missing_catalog"
    return false, UcsCatalog.error
  end

  local schema = ""
  local version = ""
  local headers = nil
  local line_number = 0
  for line in file:lines() do
    line_number = line_number + 1
    line = line:gsub("[\r\n]+$", "")
    local fields = split_tsv(line)
    if fields[1] == "#schema" then
      schema = fields[2] or ""
    elseif fields[1] == "#ucs_version" then
      version = fields[2] or ""
    elseif fields[1] == "category" then
      headers = ucs_header_map(fields)
    elseif headers and fields[1] and trim(fields[1]) ~= "" then
      local entry = {
        category = ucs_field(fields, headers, "category"),
        subcategory = ucs_field(fields, headers, "subcategory"),
        catid = ucs_field(fields, headers, "catid"),
        catshort = ucs_field(fields, headers, "catshort"),
        explanation = ucs_field(fields, headers, "explanation"),
        synonyms_en = ucs_field(fields, headers, "synonyms_en"),
        category_zh = ucs_field(fields, headers, "category_zh"),
        subcategory_zh = ucs_field(fields, headers, "subcategory_zh"),
        synonyms_zh = ucs_field(fields, headers, "synonyms_zh"),
      }

      if entry.catid == ""
        or entry.category == ""
        or entry.subcategory == ""
        or UcsCatalog.by_catid[entry.catid] then
        file:close()
        ucs_reset_catalog()
        UcsCatalog.attempted = true
        UcsCatalog.error = "invalid_catalog_row:"
          .. tostring(line_number)
          .. ":"
          .. tostring(entry.catid)
        return false, UcsCatalog.error
      end

      entry.search_catid = string.upper(entry.catid)
      entry.search_category = ucs_normalize_keyword_text(entry.category)
      entry.search_subcategory = ucs_normalize_keyword_text(
        entry.subcategory
      )
      entry.search_blob_en = ucs_normalize_keyword_text(table.concat({
        entry.explanation,
        entry.synonyms_en,
        entry.catshort,
      }, " "))
      entry.search_blob_zh = ucs_normalize_keyword_text(table.concat({
        entry.category_zh,
        entry.subcategory_zh,
        entry.synonyms_zh,
        entry.explanation,
        entry.synonyms_en,
        entry.catshort,
      }, " "))

      UcsCatalog.entries[#UcsCatalog.entries + 1] = entry
      UcsCatalog.by_catid[entry.catid] = entry
      UcsCatalog.by_pair[
        ucs_pair_key(entry.category, entry.subcategory)
      ] = entry

      local category = UcsCatalog.categories[entry.category]
      if not category then
        category = {
          name = entry.category,
          name_zh = entry.category_zh,
          entries = {},
        }
        UcsCatalog.categories[entry.category] = category
        UcsCatalog.category_order[#UcsCatalog.category_order + 1] = category
      end
      category.entries[#category.entries + 1] = entry
    end
  end
  file:close()

  if schema ~= UCS_CATALOG_SCHEMA
    or version ~= UCS_CATALOG_VERSION
    or #UcsCatalog.entries ~= 753 then
    ucs_reset_catalog()
    UcsCatalog.attempted = true
    UcsCatalog.error = "unsupported_catalog"
    return false, UcsCatalog.error
  end

  table.sort(UcsCatalog.category_order, function(left, right)
    return left.name < right.name
  end)
  for _, category in ipairs(UcsCatalog.category_order) do
    table.sort(category.entries, function(left, right)
      if left.subcategory ~= right.subcategory then
        return left.subcategory < right.subcategory
      end
      return left.catid < right.catid
    end)
  end

  ucs_build_term_index()
  UcsCatalog.loaded = true
  return true, #UcsCatalog.entries
end

function ensure_ucs_catalog()
  if UcsCatalog.loaded then return true end
  if UcsCatalog.attempted then return false end
  return load_ucs_catalog(UCS_CATALOG_PATH)
end

function ucs_classification_result(entry, status, source)
  if not entry then return nil end
  return {
    catid = entry.catid,
    category = entry.category,
    subcategory = entry.subcategory,
    ucs_status = status or "exact",
    ucs_source = source or "filename",
    ucs_version = UCS_CATALOG_VERSION,
    ucs_classifier_version = UCS_CLASSIFIER_VERSION,
    ucs_confidence = 1,
    ucs_candidates = "",
    ucs_evidence = "",
  }
end

function ucs_classify_filename_exact(filename)
  if not ensure_ucs_catalog() then return nil end
  local stem = strip_extension(basename(filename or ""))
  local token = stem:match("^([A-Za-z0-9]+)[_%-%s]")
    or stem:match("^([A-Za-z0-9]+)$")
  if not token then return nil end
  return ucs_classification_result(
    UcsCatalog.by_catid[token],
    "exact",
    "filename"
  )
end

function ucs_classify_metadata(catid, category, subcategory)
  if not ensure_ucs_catalog() then return nil end
  local entry = UcsCatalog.by_catid[trim(catid or "")]
  if not entry and trim(category or "") ~= ""
    and trim(subcategory or "") ~= "" then
    entry = UcsCatalog.by_pair[
      ucs_pair_key(category, subcategory)
    ]
  end
  return ucs_classification_result(entry, "exact", "metadata")
end

function ucs_metadata_identifier_key(identifier)
  local text = string.upper(trim(identifier or ""))
  local leaf = text:match("([^:/\\%.]+)$") or text
  return leaf:gsub("[^A-Z0-9]", "")
end

function ucs_metadata_pick(map, names)
  local ordered_keys = {}
  for key in pairs(map or {}) do
    ordered_keys[#ordered_keys + 1] = key
  end
  table.sort(ordered_keys)

  for _, name in ipairs(names or {}) do
    local wanted = ucs_metadata_identifier_key(name)
    for _, key in ipairs(ordered_keys) do
      if ucs_metadata_identifier_key(key) == wanted then
        return tostring(map[key] or "")
      end
    end
  end
  return ""
end

function ucs_normalize_keyword_text(value)
  local text = string.upper(tostring(value or ""))
  text = text:gsub("[_%-]+", " ")
  text = text:gsub("[%c%p]", " ")
  text = text:gsub("%s+", " ")
  return trim(text)
end

function ucs_keyword_word_count(value)
  local count = 0
  for _ in tostring(value or ""):gmatch("%S+") do
    count = count + 1
  end
  return count
end

function ucs_keyword_terms(value)
  local normalized = tostring(value or "")
    :gsub("，", ",")
    :gsub("；", ",")
    :gsub("、", ",")
  local terms = {}
  for term in (normalized .. ","):gmatch("(.-),") do
    term = ucs_normalize_keyword_text(term)
    if term ~= "" then terms[#terms + 1] = term end
  end
  return terms
end

function ucs_register_entry_term(entry_terms, value, kind, weight)
  local term = ucs_normalize_keyword_text(value)
  local word_count = ucs_keyword_word_count(term)
  if term == "" or word_count == 0 or word_count > 4 then return end
  if word_count == 1 and #term < 3 then return end

  local existing = entry_terms[term]
  if not existing or weight > existing.weight then
    entry_terms[term] = {
      kind = kind,
      weight = weight,
      word_count = word_count,
    }
  end
end

function ucs_build_term_index()
  UcsCatalog.term_index = {}
  UcsCatalog.max_term_words = 1

  for _, entry in ipairs(UcsCatalog.entries) do
    local entry_terms = {}
    ucs_register_entry_term(
      entry_terms,
      entry.category .. " " .. entry.subcategory,
      "pair",
      14
    )
    ucs_register_entry_term(
      entry_terms,
      entry.category_zh .. " " .. entry.subcategory_zh,
      "pair",
      14
    )
    ucs_register_entry_term(entry_terms, entry.subcategory, "subcategory", 8)
    ucs_register_entry_term(entry_terms, entry.subcategory_zh, "subcategory", 8)
    ucs_register_entry_term(entry_terms, entry.category, "category", 2)
    ucs_register_entry_term(entry_terms, entry.category_zh, "category", 2)

    for _, synonym in ipairs(ucs_keyword_terms(entry.synonyms_en)) do
      ucs_register_entry_term(entry_terms, synonym, "synonym", 4)
    end
    for _, synonym in ipairs(ucs_keyword_terms(entry.synonyms_zh)) do
      ucs_register_entry_term(entry_terms, synonym, "synonym", 4)
    end

    for term, info in pairs(entry_terms) do
      local postings = UcsCatalog.term_index[term]
      if not postings then
        postings = {}
        UcsCatalog.term_index[term] = postings
      end
      postings[#postings + 1] = {
        entry = entry,
        kind = info.kind,
        weight = info.weight,
      }
      UcsCatalog.max_term_words = math.max(
        UcsCatalog.max_term_words,
        info.word_count
      )
    end
  end
end

function ucs_term_inside(shorter, longer)
  return (" " .. longer .. " "):find(
    " " .. shorter .. " ",
    1,
    true
  ) ~= nil
end

function ucs_filename_query_terms(filename)
  local normalized = ucs_normalize_keyword_text(
    strip_extension(basename(filename or ""))
  )
  local words = {}
  for word in normalized:gmatch("%S+") do
    words[#words + 1] = word
  end

  local found = {}
  local max_words = math.min(UcsCatalog.max_term_words or 1, 4)
  for first = 1, #words do
    local phrase = ""
    for count = 1, math.min(max_words, #words - first + 1) do
      phrase = count == 1
          and words[first]
        or (phrase .. " " .. words[first + count - 1])
      if UcsCatalog.term_index[phrase] then found[phrase] = true end
    end
  end

  local ordered = {}
  for term in pairs(found) do ordered[#ordered + 1] = term end
  table.sort(ordered, function(a, b)
    local a_words = ucs_keyword_word_count(a)
    local b_words = ucs_keyword_word_count(b)
    if a_words ~= b_words then return a_words > b_words end
    if #a ~= #b then return #a > #b end
    return a < b
  end)

  local selected = {}
  for _, term in ipairs(ordered) do
    local nested = false
    for _, longer in ipairs(selected) do
      if ucs_term_inside(term, longer) then
        nested = true
        break
      end
    end
    if not nested then selected[#selected + 1] = term end
  end
  return selected
end

function ucs_format_candidates(candidates, limit)
  local values = {}
  for index = 1, math.min(limit or 3, #candidates) do
    local candidate = candidates[index]
    values[#values + 1] = candidate.entry.catid
      .. "="
      .. string.format("%.3f", candidate.score)
  end
  return table.concat(values, ";")
end

function ucs_classify_filename_keywords(filename, max_candidates)
  if not ensure_ucs_catalog() then return nil end
  local query_terms = ucs_filename_query_terms(filename)
  if #query_terms == 0 then return nil end

  local scores = {}
  for _, term in ipairs(query_terms) do
    local postings = UcsCatalog.term_index[term] or {}
    if #postings <= 64 then
      local divisor = 1 + math.log(math.max(1, #postings), 2)
      for _, posting in ipairs(postings) do
        local catid = posting.entry.catid
        local score = scores[catid]
        if not score then
          score = {
            entry = posting.entry,
            score = 0,
            evidence = {},
            evidence_seen = {},
            noncategory_count = 0,
            pair_match = false,
            subcategory_match = false,
            subcategory_postings = math.huge,
            category_match = false,
          }
          scores[catid] = score
        end

        score.score = score.score + posting.weight / divisor
        if not score.evidence_seen[term] then
          score.evidence_seen[term] = true
          score.evidence[#score.evidence + 1] = term
          if posting.kind ~= "category" then
            score.noncategory_count = score.noncategory_count + 1
          end
        end
        if posting.kind == "pair" then score.pair_match = true end
        if posting.kind == "category" then score.category_match = true end
        if posting.kind == "subcategory" then
          score.subcategory_match = true
          score.subcategory_postings = math.min(
            score.subcategory_postings,
            #postings
          )
        end
      end
    end
  end

  local candidates = {}
  for _, score in pairs(scores) do
    table.sort(score.evidence)
    candidates[#candidates + 1] = score
  end
  table.sort(candidates, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.entry.catid < b.entry.catid
  end)
  if #candidates == 0 then return nil end

  local top = candidates[1]
  local second_score = candidates[2] and candidates[2].score or 0
  local margin = top.score - second_score
  local qualifies = top.pair_match
    or (top.subcategory_match and top.subcategory_postings <= 2)
    or (top.category_match and top.noncategory_count >= 2)
    or top.noncategory_count >= 3
  local automatic = qualifies and top.score >= 6 and margin >= 2
  local confidence = automatic
      and math.min(0.96, 0.75 + math.min(0.15, top.score / 60)
        + math.min(0.06, margin / 30))
    or math.min(0.79, 0.45 + math.min(0.2, top.score / 50)
      + math.min(0.1, math.max(0, margin) / 30))

  local result = automatic
      and ucs_classification_result(
        top.entry,
        "auto",
        "filename_keywords"
      )
    or {
      catid = "",
      category = "",
      subcategory = "",
      ucs_status = "pending",
      ucs_source = "filename_keywords",
      ucs_version = UCS_CATALOG_VERSION,
      ucs_classifier_version = UCS_CLASSIFIER_VERSION,
    }
  result.ucs_confidence = confidence
  result.ucs_candidates = ucs_format_candidates(
    candidates,
    max_candidates or 3
  )
  result.ucs_evidence = table.concat(top.evidence, ",")
  return result
end

function ucs_unclassified_result(asset, source)
  local preserve_metadata = source == "metadata"
  return {
    catid = preserve_metadata and tostring(asset.catid or "") or "",
    category = preserve_metadata and tostring(asset.category or "") or "",
    subcategory = preserve_metadata
        and tostring(asset.subcategory or "")
      or "",
    ucs_status = preserve_metadata and "pending" or "unclassified",
    ucs_source = preserve_metadata and "metadata" or "",
    ucs_version = UCS_CATALOG_VERSION,
    ucs_classifier_version = UCS_CLASSIFIER_VERSION,
    ucs_confidence = 0,
    ucs_candidates = "",
    ucs_evidence = "",
  }
end

function ucs_classify_existing_asset(asset)
  if not asset then return nil, "missing" end
  if asset.ucs_status == "manual" then return nil, "manual" end

  local exact = ucs_classify_filename_exact(asset.name or asset.path or "")
  if exact then return exact, "exact" end

  local previous_source = tostring(asset.ucs_source or "")
  local generated_metadata = previous_source == "filename"
    or previous_source == "filename_keywords"
  if not generated_metadata then
    local metadata = ucs_classify_metadata(
      asset.catid,
      asset.category,
      asset.subcategory
    )
    if metadata then return metadata, "metadata" end
  end

  local keywords = ucs_classify_filename_keywords(
    asset.name or asset.path or ""
  )
  if keywords then
    if keywords.ucs_status == "pending" and not generated_metadata then
      keywords.catid = tostring(asset.catid or "")
      keywords.category = tostring(asset.category or "")
      keywords.subcategory = tostring(asset.subcategory or "")
    end
    return keywords, keywords.ucs_status
  end

  local has_metadata = not generated_metadata
    and (trim(asset.catid or "") ~= ""
      or trim(asset.category or "") ~= ""
      or trim(asset.subcategory or "") ~= "")
  return ucs_unclassified_result(
    asset,
    has_metadata and "metadata" or ""
  ), has_metadata and "pending" or "unclassified"
end

function ucs_classification_differs(asset, result)
  if not asset or not result then return false end
  for _, field in ipairs(UCS_CLASSIFICATION_FIELDS) do
    local current = asset[field]
    local proposed = result[field]
    if field == "ucs_confidence" then
      if math.abs((tonumber(current) or 0) - (tonumber(proposed) or 0))
        > 0.000001 then
        return true
      end
    elseif tostring(current or "") ~= tostring(proposed or "") then
      return true
    end
  end
  return false
end

function ucs_assign_classification(asset, result)
  if not asset or not result then return false end
  local changed = ucs_classification_differs(asset, result)
  if not changed then return false end
  for _, field in ipairs(UCS_CLASSIFICATION_FIELDS) do
    asset[field] = result[field]
  end
  return true
end

function ucs_parse_candidates(value)
  if not ensure_ucs_catalog() then return {} end
  local candidates = {}
  for token in (tostring(value or "") .. ";"):gmatch("(.-);") do
    local catid, score = token:match("^([^=]+)=([%d%.]+)$")
    local entry = catid and UcsCatalog.by_catid[trim(catid)] or nil
    if entry then
      candidates[#candidates + 1] = {
        entry = entry,
        score = tonumber(score) or 0,
      }
    end
  end
  return candidates
end

function ucs_manual_classification_result(catid)
  if not ensure_ucs_catalog() then return nil end
  local entry = UcsCatalog.by_catid[trim(catid or "")]
  return ucs_classification_result(entry, "manual", "manual")
end

function ucs_search_fragment(query)
  local token = tostring(query or ""):match("([^%s]+)$") or ""
  if token:match("^%-") then return "" end
  local field, value = token:match("^([^:]+):(.*)$")
  if field then
    field = string.lower(field)
    if field ~= "category" and field ~= "subcategory"
      and field ~= "catid" and field ~= "ucs" then
      return ""
    end
    token = value
  end
  token = token:gsub('^"+', ""):gsub('"+$', "")
  return trim(token)
end

function ucs_search_suggestions(query, language, limit)
  if not ensure_ucs_catalog() then return {} end
  local fragment = ucs_search_fragment(query)
  local needle = ucs_normalize_keyword_text(fragment)
  if #needle < 2 then return {} end

  local suggestions = {}
  for _, entry in ipairs(UcsCatalog.entries) do
    local catid = entry.search_catid
    local category = entry.search_category
    local subcategory = entry.search_subcategory
    local blob = language == "en"
        and entry.search_blob_en
      or entry.search_blob_zh
    local score = 0
    local matched = ""
    if catid == needle then
      score, matched = 120, "CatID"
    elseif catid:find(needle, 1, true) == 1 then
      score, matched = 105, "CatID"
    elseif subcategory == needle then
      score, matched = 95, "SubCategory"
    elseif subcategory:find(needle, 1, true) == 1 then
      score, matched = 85, "SubCategory"
    elseif category == needle then
      score, matched = 78, "Category"
    elseif category:find(needle, 1, true) == 1 then
      score, matched = 70, "Category"
    elseif blob:find(needle, 1, true) then
      score, matched = 50, "Synonym"
    end
    if score > 0 then
      suggestions[#suggestions + 1] = {
        entry = entry,
        score = score,
        matched = matched,
      }
    end
  end

  table.sort(suggestions, function(left, right)
    if left.score ~= right.score then return left.score > right.score end
    return left.entry.catid < right.entry.catid
  end)
  while #suggestions > (limit or 8) do
    table.remove(suggestions)
  end
  return suggestions
end

function ucs_apply_search_suggestion(query, catid)
  local prefix = tostring(query or ""):match("^(.*%s)") or ""
  return prefix .. "catid:" .. tostring(catid or "")
end

-- Catalog identity, metadata, configuration and library persistence.
local HostApi = Host or reaper

function parse_ucs_filename(filename)
  local result = ucs_classify_filename_exact(filename)
  if result then return result end
  result = ucs_classify_filename_keywords(filename)
  if result then return result end
  return {
    catid = "",
    category = "",
    subcategory = "",
    ucs_status = "unclassified",
    ucs_source = "",
    ucs_version = UCS_CATALOG_VERSION,
    ucs_classifier_version = UCS_CLASSIFIER_VERSION,
    ucs_confidence = 0,
    ucs_candidates = "",
    ucs_evidence = "",
  }
end

function asset_relative_path(path, root)
  path = canonical_source_path(path)
  root = canonical_source_path(root)

  if root == "" or not path_is_inside(path, root) then
    return basename(path)
  end

  if path_key(path) == path_key(root) then
    return ""
  end

  return normalize_slashes(path:sub(#root + 2))
end

function ensure_asset_identity(asset, probe_file)
  if not asset then
    return
  end

  asset.relative_path = tostring(asset.relative_path or "")

  if asset.relative_path == "" then
    asset.relative_path = asset_relative_path(
      asset.path or "",
      asset.root or ""
    )
  end

  if tostring(asset.asset_id or "") == "" then
    asset.asset_id = stable_id(
      "asset",
      tostring(asset.root_id or "")
        .. "|"
        .. path_key(asset.relative_path)
    )
  end

  asset.last_seen = tonumber(asset.last_seen) or 0

  -- Persisted database rows were already validated when they were scanned.
  -- Probing every file while loading the snapshot blocks REAPER's UI and can
  -- issue two synchronous filesystem calls per asset. Missing-file audits and
  -- Watch Folder jobs perform the authoritative background verification.
  if probe_file ~= false then
    if HostApi.file_exists(asset.path or "") then
      asset.last_seen = os.time()
    end
  end
end

function make_placeholder(path, known_root)
  local name = basename(path)
  local ucs = parse_ucs_filename(name)
  local root, root_record

  if known_root then
    root = known_root
    root_record = root_record_for_path(root)
  else
    root, root_record = root_for_path(path)
  end

  local library = library_for_root_record(root_record)

  local asset = {
    path = normalize_slashes(path),
    name = name,
    folder = dirname(path),
    root = root or "",
    root_id = root_record and root_record.id or "",
    library_id = library and library.id or "",
    library = library and library.name
      or library_for_path(path, root),

    duration = 0,
    channels = 0,
    sample_rate = 0,
    bit_depth = 0,
    source_type = extension(path):upper(),
    size = 0,

    description = "",
    keywords = "",
    catid = ucs.catid,
    category = ucs.category,
    subcategory = ucs.subcategory,
    ucs_status = ucs.ucs_status,
    ucs_source = ucs.ucs_source,
    ucs_version = ucs.ucs_version,
    ucs_classifier_version = ucs.ucs_classifier_version,
    ucs_confidence = ucs.ucs_confidence,
    ucs_candidates = ucs.ucs_candidates or "",
    ucs_evidence = ucs.ucs_evidence or "",
    artwork_path = "",
    artwork_checked = false,

    workflow_status = "none",
    marked = false,
    preview_count = 0,
    last_previewed = 0,

    indexed = false,
    ready = false,
    used_count = 0,
    last_used = 0,
    fingerprint = "",
    fingerprint_size = 0,
    fingerprint_version = "",
    fingerprint_modified = "",
    fingerprint_stat_source = "",
  }

  ensure_asset_identity(asset)
  return asset
end

function asset_path_sort_key(asset)
  local source = tostring(asset.path or "")
  if asset._sort_path_source ~= source then
    asset._sort_path_source = source
    asset._sort_path_value = path_key(source)
  end
  return asset._sort_path_value
end

function invalidate_ucs_counts()
  if not state.ucs_counts_dirty then
    AppState.set("ucs_counts_dirty", true)
  end
  if state.ucs_counts_job then
    AppState.set("ucs_counts_job", nil)
  end
end

function refresh_ucs_pending_membership(asset)
  if not asset or not asset.path then return end
  invalidate_ucs_counts()
  local key = path_key(asset.path)
  local was_pending = state.ucs_pending_lookup[key] ~= nil
  local is_pending = asset.ucs_status == "pending"
  if was_pending == is_pending then
    if is_pending then state.ucs_pending_lookup[key] = asset end
    return
  end
  if is_pending then
    state.ucs_pending_lookup[key] = asset
    AppState.set("ucs_pending_count", state.ucs_pending_count + 1)
  else
    state.ucs_pending_lookup[key] = nil
    AppState.set(
      "ucs_pending_count",
      math.max(0, state.ucs_pending_count - 1)
    )
  end
end

function remove_ucs_pending_membership(asset_or_path)
  local path = type(asset_or_path) == "table"
      and asset_or_path.path
    or asset_or_path
  local key = path_key(path or "")
  if key ~= "" then invalidate_ucs_counts() end
  if key ~= "" and state.ucs_pending_lookup[key] then
    state.ucs_pending_lookup[key] = nil
    AppState.set(
      "ucs_pending_count",
      math.max(0, state.ucs_pending_count - 1)
    )
  end
end

function add_or_update_asset(asset, probe_file)
  ensure_asset_identity(asset, probe_file)
  local key = path_key(asset.path)
  local existing = state.by_path[key]

  if existing then
    local old_folder = path_key(existing.folder or "")
    local old_root_id = tostring(existing.root_id or "")
    local used_count = existing.used_count
    local last_used = existing.last_used
    local workflow_status =
      existing.workflow_status or "none"
    local marked = existing.marked == true
    local preview_count =
      existing.preview_count or 0
    local last_previewed =
      existing.last_previewed or 0
    local artwork_path =
      existing.artwork_path or ""
    local asset_id = tostring(existing.asset_id or "")

    for field, value in pairs(asset) do
      existing[field] = value
    end

    existing.used_count =
      tonumber(used_count) or 0

    existing.last_used =
      tonumber(last_used) or 0

    existing.workflow_status =
      WORKFLOW_STATUS[workflow_status]
      and workflow_status
      or "none"

    existing.marked = marked

    existing.preview_count =
      tonumber(preview_count) or 0

    existing.last_previewed =
      tonumber(last_previewed) or 0

    if (existing.artwork_path or "") == "" then
      existing.artwork_path = artwork_path
    end

    if asset_id ~= "" then
      existing.asset_id = asset_id
    end

    existing.artwork_checked =
      tostring(existing.artwork_path or "") ~= ""

    existing._search_blob = nil
    invalidate_library_counts()

    if old_folder ~= path_key(existing.folder or "")
      or old_root_id ~= tostring(existing.root_id or "") then
      invalidate_folder_navigation()
    end

    refresh_ucs_pending_membership(existing)

    return existing
  end

  asset.workflow_status =
    WORKFLOW_STATUS[asset.workflow_status]
    and asset.workflow_status
    or "none"

  asset.marked = asset.marked == true

  asset.preview_count =
    tonumber(asset.preview_count) or 0

  asset.last_previewed =
    tonumber(asset.last_previewed) or 0

  asset.artwork_path =
    tostring(asset.artwork_path or "")

  asset.artwork_checked =
    asset.artwork_path ~= ""

  asset.used_count =
    tonumber(asset.used_count) or 0

  asset.last_used =
    tonumber(asset.last_used) or 0

  state.by_path[key] = asset
  state.assets[#state.assets + 1] = asset
  refresh_ucs_pending_membership(asset)
  state.database_ordered_assets = nil
  invalidate_library_counts()
  invalidate_folder_navigation()
  return asset
end

function rebuild_assets()
  state.assets = {}
  state.database_ordered_assets = nil
  AppState.set("ucs_pending_lookup", {})
  AppState.set("ucs_pending_count", 0)

  for _, asset in pairs(state.by_path) do
    state.assets[#state.assets + 1] = asset
    refresh_ucs_pending_membership(asset)
  end

  state.results_dirty = true
  invalidate_library_counts()
  invalidate_folder_navigation()
end

----------------------------------------------------------------
-- Persistence
----------------------------------------------------------------

local DB_FIELDS = {
  "asset_id",
  "path",
  "relative_path",
  "name",
  "folder",
  "root",
  "library",
  "duration",
  "channels",
  "sample_rate",
  "bit_depth",
  "source_type",
  "size",
  "description",
  "keywords",
  "catid",
  "category",
  "subcategory",
  "ucs_status",
  "ucs_source",
  "ucs_version",
  "ucs_classifier_version",
  "ucs_confidence",
  "ucs_candidates",
  "ucs_evidence",
  "artwork_path",
  "workflow_status",
  "marked",
  "preview_count",
  "last_previewed",
  "indexed",
  "ready",
  "used_count",
  "last_used",
  "root_id",
  "library_id",
  "fingerprint",
  "fingerprint_size",
  "fingerprint_version",
  "fingerprint_modified",
  "fingerprint_stat_source",
  "last_seen",
}

function save_libraries()
  ensure_dirs()

  local file = atomic_file_writer(LIBRARIES_FILE)

  if not file then
    set_status("无法保存音效库结构", true)
    return false
  end

  write_persistence_schema(file, LIBRARIES_FILE)
  file:write("version\t3\n")

  for _, library in ipairs(state.libraries) do
    file:write(
      "library\t",
      escape_tsv(library.id),
      "\t",
      escape_tsv(library.name),
      "\t",
      escape_tsv(library.artwork_path or ""),
      "\t",
      state.expanded_libraries[library.id] == false
        and "0" or "1",
      "\n"
    )
  end

  for _, record in ipairs(state.root_records) do
    refresh_source_identity(record)
    file:write(
      "root\t",
      escape_tsv(record.id),
      "\t",
      escape_tsv(record.library_id),
      "\t",
      escape_tsv(record.path),
      "\t",
      escape_tsv(record.alias or ""),
      "\t",
      record.enabled == false and "0" or "1",
      "\t",
      escape_tsv(record.artwork_path or ""),
      "\t",
      record.artwork_checked == true and "1" or "0",
      "\t",
      tostring(record.artwork_scan_version or 0),
      "\t",
      escape_tsv(record.canonical_path or ""),
      "\t",
      escape_tsv(record.volume_label or ""),
      "\t",
      escape_tsv(record.volume_serial or ""),
      "\t",
      tostring(record.last_seen or 0),
      "\n"
    )
  end

  if not file:close() then
    set_status("无法保存音效库结构", true)
    return false
  end
  state.libraries_dirty = false
  return true
end

function load_or_migrate_libraries()
  state.libraries = {}
  state.root_records = {}
  state.expanded_libraries = {}

  local file = io.open(LIBRARIES_FILE, "rb")

  if file then
    for line in file:lines() do
      local fields = split_tsv(line)

      if fields[1] == "library"
        and fields[2]
        and fields[3] then
        state.libraries[#state.libraries + 1] = {
          id = fields[2],
          name = fields[3],
          artwork_path = fields[4] or "",
          artwork_checked = false,
          roots = {},
        }
        state.expanded_libraries[fields[2]] =
          fields[5] ~= "0"
      elseif fields[1] == "root"
        and fields[2]
        and fields[3]
        and fields[4] then
        state.root_records[#state.root_records + 1] = {
          id = fields[2],
          library_id = fields[3],
          path = canonical_source_path(fields[4]),
          alias = fields[5] or "",
          enabled = fields[6] ~= "0",
          artwork_path = fields[7] or "",
          artwork_checked = fields[8] == "1",
          artwork_scan_version = tonumber(fields[9]) or 0,
          canonical_path = fields[10] or "",
          volume_label = fields[11] or "",
          volume_serial = fields[12] or "",
          last_seen = tonumber(fields[13]) or 0,
        }
      end
    end

    file:close()
    rebuild_library_indexes()

    -- Re-run negative automatic searches when the discovery algorithm gains
    -- new folder-layout support. Explicit manual paths and "-" opt-outs remain
    -- untouched.
    for _, record in ipairs(state.root_records) do
      if tostring(record.artwork_path or "") == ""
        and record.artwork_scan_version
          < ARTWORK_DISCOVERY_VERSION then
        record.artwork_checked = false
        state.libraries_dirty = true
      end
    end

    -- Beta 5/6 stored an automatically discovered source cover on the
    -- logical library. Migrate it only when ownership is unambiguous.
    -- Multi-source libraries intentionally drop the shared association so
    -- each source can discover or select its own artwork independently.
    for _, library in ipairs(state.libraries) do
      local legacy_artwork = tostring(library.artwork_path or "")

      if legacy_artwork ~= "" then
        if #library.roots == 1
          and tostring(library.roots[1].artwork_path or "") == "" then
          library.roots[1].artwork_path = legacy_artwork
          library.roots[1].artwork_checked = true
        end

        library.artwork_path = ""
        library.artwork_checked = false
        state.libraries_dirty = true
      end
    end

    return
  end

  -- 0.7.1 及更早版本：每个 root 自动迁移为一个逻辑库。
  for _, root in ipairs(state.legacy_roots) do
    local library = create_library(
      basename(root),
      "legacy-library:" .. path_key(root)
    )

    state.root_records[#state.root_records + 1] = {
      id = stable_id("root", path_key(root)),
      library_id = library.id,
      path = canonical_source_path(root),
      alias = "",
      enabled = true,
      artwork_path = "",
      artwork_checked = false,
      artwork_scan_version = 0,
    }
  end

  rebuild_library_indexes()

  if #state.libraries > 0 then
    save_libraries()
    set_status("已将旧音效库迁移为逻辑库与来源路径")
  end
end

function load_config()
  local file = io.open(CONFIG_FILE, "rb")

  if not file then
    return
  end

  for line in file:lines() do
    local fields = split_tsv(line)

    if fields[1] == "folder_open"
      and fields[2]
      and fields[2] ~= "" then
      state.expanded_folder_nodes[path_key(fields[2])] = true
    elseif fields[1] == "source_open"
      and fields[2]
      and fields[2] ~= "" then
      state.expanded_source_folders[fields[2]] = true
    elseif fields[1] == "root"
      and fields[2]
      and fields[2] ~= "" then
      state.legacy_roots[#state.legacy_roots + 1] =
        normalize_slashes(fields[2])
    elseif fields[1] == "favorite"
      and fields[2] then
      state.favorites[path_key(fields[2])] = true
    elseif fields[1] == "recent"
      and fields[2] then
      state.recent[#state.recent + 1] = fields[2]
    elseif fields[1] == "setting" then
      local name = fields[2]
      local value = fields[3]

      if name == "watch" then
        state.watch_enabled = value == "1"
      elseif name == "watch_interval" then
        state.watch_interval = clamp(tonumber(value) or WATCH_INTERVAL, 15, 3600)
      elseif name == "watch_silent" then
        state.watch_silent = value ~= "0"
      elseif name == "resume_scan_on_start" then
        state.resume_scan_on_start = value ~= "0"
      elseif name == "auto_backup" then
        state.auto_backup = value ~= "0"
      elseif name == "backup_keep_count" then
        state.backup_keep_count = clamp(math.floor(tonumber(value) or 7), 1, 30)
      elseif name == "auto_collect_project_usage" then
        state.auto_collect_project_usage = value ~= "0"
      elseif name == "auto_preview" then
        state.auto_preview = value == "1"
      elseif name == "enter_insert_shortcuts" then
        AppState.set("enter_insert_shortcuts", value == "1")
      elseif name == "insert_lowercase" then
        state.insert_lowercase = value == "1"
      elseif name == "insert_prefix" then
        state.insert_prefix = value or ""
      elseif name == "insert_suffix" then
        state.insert_suffix = value or ""
      elseif name == "transfer_dir" then
        state.transfer_dir =
          normalize_slashes(trim(value or ""))
        if state.transfer_dir == "" then
          state.transfer_dir = DEFAULT_TRANSFER_DIR
        end
      elseif name == "transfer_template" then
        state.transfer_template =
          value ~= "" and value or "{name}"
      elseif name == "transfer_format" then
        local valid_formats = {
          wav16 = true,
          wav24 = true,
          wav32 = true,
          flac = true,
        }
        state.transfer_format =
          valid_formats[value] and value or "wav24"
      elseif name == "transfer_sample_rate" then
        local valid_rates = {
          source = true,
          ["44100"] = true,
          ["48000"] = true,
          ["96000"] = true,
          ["192000"] = true,
        }
        state.transfer_sample_rate =
          valid_rates[value] and value or "source"
      elseif name == "transfer_channels" then
        state.transfer_channels =
          value == "mono" and "mono"
          or value == "stereo" and "stereo"
          or "source"
      elseif name == "transfer_scope" then
        state.transfer_scope =
          value == "full" and "full" or "selection"
      elseif name == "transfer_collision" then
        state.transfer_collision =
          value == "skip" and "skip"
          or value == "overwrite" and "overwrite"
          or "increment"
      elseif name == "transfer_fade_in_ms" then
        state.transfer_fade_in_ms =
          tonumber(value) or 5
      elseif name == "transfer_fade_out_ms" then
        state.transfer_fade_out_ms =
          tonumber(value) or 20
      elseif name == "transfer_smart_tail" then
        state.transfer_smart_tail = value == "1"
      elseif name == "transfer_tail_threshold_db" then
        state.transfer_tail_threshold_db =
          clamp(tonumber(value) or -60, -96, -18)
      elseif name == "transfer_tail_max_ms" then
        state.transfer_tail_max_ms =
          clamp(tonumber(value) or 5000, 100, 30000)
      elseif name == "transfer_tail_hold_ms" then
        state.transfer_tail_hold_ms =
          clamp(tonumber(value) or 180, 0, 2000)
      elseif name == "transfer_normalize" then
        state.transfer_normalize =
          value == "peak" and "peak"
          or value == "true_peak" and "true_peak"
          or value == "rms_i" and "rms_i"
          or value == "lufs_i" and "lufs_i"
          or "off"
      elseif name == "transfer_normalize_target" then
        state.transfer_normalize_target =
          tonumber(value) or -1
      elseif name == "transfer_insert_after" then
        state.transfer_insert_after = value == "1"
      elseif name == "transfer_open_dir_after" then
        state.transfer_open_dir_after = value == "1"
      elseif name == "transfer_lowercase" then
        state.transfer_lowercase = value == "1"
      elseif name == "transfer_dither" then
        state.transfer_dither = value ~= "0"
      elseif name == "transfer_noise_shaping" then
        state.transfer_noise_shaping = value == "1"
      elseif name == "transfer_preserve_metadata" then
        state.transfer_preserve_metadata = value ~= "0"
      elseif name == "transfer_variants_enabled" then
        state.transfer_variants_enabled = value == "1"
      elseif name == "transfer_variant_pitches" then
        state.transfer_variant_pitches = value or ""
      elseif name == "transfer_variant_rates" then
        state.transfer_variant_rates = value or ""
      elseif name == "transfer_variant_gains" then
        state.transfer_variant_gains = value or ""
      elseif name == "transfer_variant_include_reverse" then
        state.transfer_variant_include_reverse = value == "1"
      elseif name == "transfer_variant_auto_suffix" then
        state.transfer_variant_auto_suffix = value ~= "0"
      elseif name == "theme_preset" then
        local legacy_key =
          "sound" .. "ly"

        if value == legacy_key
          or value == "aether" then
          value = "dark"
        end

        if value == "dark"
          or value == "heritage"
          or value == "custom" then
          state.theme_preset = value
        else
          state.theme_preset = "dark"
        end
      elseif name == "custom_accent_hex" then
        state.custom_accent_hex = value or "#1F6FCC"
      elseif name == "custom_shell_hex" then
        state.custom_shell_hex = value or "#101114"
      elseif name == "language" then
        state.language =
          value == "en" and "en" or "zh"
      elseif name == "folder_browser_open" then
        -- 0.7.22 used a persistent inline tree. The 0.7.23 hover cascade is
        -- transient, so an old saved open state must not start background
        -- work or reserve workspace height.
        state.folder_browser_open = false
      elseif name == "active_folder_path" then
        local configured =
          canonical_source_path(value or "")
        state.root_filter =
          configured ~= "" and configured or nil
      elseif name == "mini_wave_points" then
        local points = tonumber(value) or MINI_WAVE_DEFAULT_POINTS
        state.mini_wave_points =
          points >= MINI_WAVE_MAX_POINTS
          and MINI_WAVE_MAX_POINTS
          or MINI_WAVE_DEFAULT_POINTS
      elseif name == "precache_points" then
        state.precache_points =
          tonumber(value) == 2048 and 2048 or 4096
      elseif name == "multichannel_waveform" then
        state.multichannel_waveform = value ~= "0"
      elseif name == "spectral_peaks_enabled" then
        AppState.set("spectral_peaks_enabled", value == "1")
      elseif name == "wave_cache_dir" then
        local configured =
          normalize_slashes(
            trim(value or "")
          )

        state.wave_cache_dir =
          configured ~= ""
            and configured
            or DEFAULT_WAVE_CACHE_DIR
      elseif name == "ui_style" then
        -- 0.6.8 及更早版本迁移。
        state.ui_density =
          value == "compact" and "compact" or "balanced"
      elseif name == "ui_density" then
        if value == "comfortable"
          or value == "balanced"
          or value == "compact" then
          state.ui_density = value
        end
      elseif name == "surface_style" then
        if value == "dark"
          or value == "heritage"
          or value == "custom" then
          state.surface_style = value
        elseif value == "flat"
          or value == "layered"
          or value == "contrast" then
          state.surface_style = "dark"
        end
      elseif name == "wave_scrub_enabled" then
        state.wave_scrub_enabled = value ~= "0"
      elseif name == "loop_selection" then
        state.loop_selection = value ~= "0"
      elseif name == "preview_control_layout" then
        if value == "studio_strip" then
          state.preview_control_layout = value
        elseif value == "full_rack"
          or value == "focus_rack"
          or value == "minimal_rack" then
          -- 0.6.17 将旧控制台统一迁移为较轻量的单行工具条。
          state.preview_control_layout = "studio_strip"
        elseif value == "pro_rack"
          or value == "right_knobs"
          or value == "classic_rack"
          or value == "inline_sliders" then
          state.preview_control_layout = "studio_strip"
        elseif value == "compact_rack"
          or value == "compact_knobs" then
          state.preview_control_layout = "studio_strip"
        end
      elseif name == "bottom_panel_height" then
        state.bottom_panel_height =
          tonumber(value) or 330
      elseif name == "preview_channel_mode" then
        if value == "left"
          or value == "right"
          or value == "mono"
          or value == "original" then
          state.preview_channel_mode = value
        end
      elseif name == "loudness_match" then
        state.loudness_match = value == "1"
      elseif name == "loudness_target_db" then
        state.loudness_target_db =
          tonumber(value) or -18
      elseif name == "transient_threshold" then
        state.transient_threshold =
          tonumber(value) or 0.24
      elseif name == "transient_min_gap_ms" then
        state.transient_min_gap_ms =
          tonumber(value) or 140
      elseif name == "transient_pre_ms" then
        state.transient_pre_ms =
          tonumber(value) or 20
      elseif name == "transient_post_ms" then
        state.transient_post_ms =
          tonumber(value) or 180
      elseif name == "transient_smoothing_ms" then
        state.transient_smoothing_ms =
          tonumber(value) or 8
      elseif name == "transient_max_regions" then
        state.transient_max_regions =
          tonumber(value) or 64
      elseif name == "transient_replace_existing" then
        state.transient_replace_existing =
          value ~= "0"
      elseif name == "show_loudness_metrics" then
        state.show_loudness_metrics =
          value ~= "0"
      elseif name == "loudness_show_i" then
        state.loudness_show_i = value ~= "0"
      elseif name == "loudness_show_m" then
        state.loudness_show_m = value ~= "0"
      elseif name == "loudness_show_s" then
        state.loudness_show_s = value == "1"
      elseif name == "loudness_show_tp" then
        state.loudness_show_tp = value ~= "0"
      elseif name == "waveform_hex" then
        state.waveform_hex = value or "#D7D8DA"
      elseif name == "waveform_selected_hex" then
        state.waveform_selected_hex = value or "#EAF3FF"
      elseif name == "waveform_played_hex" then
        state.waveform_played_hex = value or "#8FB8D8"
      elseif name == "waveform_marked_hex" then
        state.waveform_marked_hex = value or "#F0C85A"
      elseif name == "played_text_hex" then
        state.played_text_hex = value or "#F0C85A"
      elseif name == "played_text_enabled" then
        state.played_text_enabled = value ~= "0"
      elseif name == "played_waveform_enabled" then
        state.played_waveform_enabled = value == "1"
      elseif name == "restore_played_on_start" then
        state.restore_played_on_start = value == "1"
      elseif name == "artwork_enabled" then
        state.artwork_enabled = value ~= "0"
      elseif name == "inspector_artwork_pinned" then
        state.inspector_artwork_pinned = value ~= "0"
      elseif name == "selection_hex" then
        state.selection_hex = value or "#2789E9"
      elseif name == "playhead_hex" then
        state.playhead_hex = value or "#50E36D"
      elseif name == "region_hex" then
        state.region_hex = value or "#E2B764"
      elseif name:match("^sidebar_section_") then
        local key =
          name:gsub("^sidebar_section_", "")

        if state.sidebar_sections[key] ~= nil then
          state.sidebar_sections[key] = value ~= "0"
        end
      elseif name == "sidebar_visible" then
        state.sidebar_visible = value == "1"
      elseif name == "inspector_visible" then
        state.inspector_visible = value == "1"
      elseif name == "inspector_width" then
        state.inspector_width =
          tonumber(value) or INSPECTOR_DEFAULT_W
      elseif name == "active_collection_id" then
        state.active_collection_id =
          value ~= "" and value or nil
      elseif name == "status_filter" then
        state.status_filter =
          value ~= "" and value or nil
      elseif name:match("^column_visible_") then
        local key = name:gsub("^column_visible_", "")

        if state.column_visible[key] ~= nil then
          state.column_visible[key] = value == "1"
        end
      elseif name:match("^column_width_") then
        local key = name:gsub("^column_width_", "")

        if state.column_widths[key] ~= nil then
          local loaded_width =
            tonumber(value) or state.column_widths[key]

          state.column_widths[key] = key == "duration"
            and math.max(104, loaded_width)
            or loaded_width
        end
      end
    end
  end

  file:close()
end

function save_config()
  if state.root_removal_session then return false end
  ensure_dirs()

  local file = atomic_file_writer(CONFIG_FILE)

  if not file then
    set_status("无法保存配置", true)
    return
  end

  write_persistence_schema(file, CONFIG_FILE)
  file:write("version\t", VERSION, "\n")

  for path in pairs(state.favorites) do
    file:write(
      "favorite\t",
      escape_tsv(path),
      "\n"
    )
  end

  for index, path in ipairs(state.recent) do
    if index <= 100 then
      file:write(
        "recent\t",
        escape_tsv(path),
        "\n"
      )
    end
  end

  for path in pairs(state.expanded_folder_nodes) do
    file:write(
      "folder_open\t",
      escape_tsv(path),
      "\n"
    )
  end

  for root_id in pairs(state.expanded_source_folders) do
    file:write(
      "source_open\t",
      escape_tsv(root_id),
      "\n"
    )
  end

  file:write(
    "setting\twatch\t",
    state.watch_enabled and "1" or "0",
    "\n"
  )

  file:write(
    "setting\twatch_interval\t",
    tostring(state.watch_interval or WATCH_INTERVAL),
    "\n"
  )

  file:write(
    "setting\twatch_silent\t",
    state.watch_silent and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tresume_scan_on_start\t",
    state.resume_scan_on_start and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tauto_backup\t",
    state.auto_backup and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tbackup_keep_count\t",
    tostring(state.backup_keep_count or 7),
    "\n"
  )

  file:write(
    "setting\tauto_collect_project_usage\t",
    state.auto_collect_project_usage and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tauto_preview\t",
    state.auto_preview and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tenter_insert_shortcuts\t",
    state.enter_insert_shortcuts and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tinsert_lowercase\t",
    state.insert_lowercase and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tinsert_prefix\t",
    escape_tsv(state.insert_prefix),
    "\n"
  )

  file:write(
    "setting\tinsert_suffix\t",
    escape_tsv(state.insert_suffix),
    "\n"
  )

  file:write(
    "setting\ttransfer_dir\t",
    escape_tsv(state.transfer_dir or DEFAULT_TRANSFER_DIR),
    "\n"
  )

  file:write(
    "setting\ttransfer_template\t",
    escape_tsv(state.transfer_template or "{name}"),
    "\n"
  )

  file:write(
    "setting\ttransfer_format\t",
    state.transfer_format,
    "\n"
  )

  file:write(
    "setting\ttransfer_sample_rate\t",
    state.transfer_sample_rate,
    "\n"
  )

  file:write(
    "setting\ttransfer_channels\t",
    state.transfer_channels,
    "\n"
  )

  file:write(
    "setting\ttransfer_scope\t",
    state.transfer_scope,
    "\n"
  )

  file:write(
    "setting\ttransfer_collision\t",
    state.transfer_collision,
    "\n"
  )

  file:write(
    "setting\ttransfer_fade_in_ms\t",
    tostring(state.transfer_fade_in_ms),
    "\n"
  )

  file:write(
    "setting\ttransfer_fade_out_ms\t",
    tostring(state.transfer_fade_out_ms),
    "\n"
  )

  file:write(
    "setting\ttransfer_smart_tail\t",
    state.transfer_smart_tail and "1" or "0",
    "\n"
  )

  file:write(
    "setting\ttransfer_tail_threshold_db\t",
    tostring(state.transfer_tail_threshold_db),
    "\n"
  )

  file:write(
    "setting\ttransfer_tail_max_ms\t",
    tostring(state.transfer_tail_max_ms),
    "\n"
  )

  file:write(
    "setting\ttransfer_tail_hold_ms\t",
    tostring(state.transfer_tail_hold_ms),
    "\n"
  )

  file:write(
    "setting\ttransfer_normalize\t",
    state.transfer_normalize,
    "\n"
  )

  file:write(
    "setting\ttransfer_normalize_target\t",
    tostring(state.transfer_normalize_target),
    "\n"
  )

  file:write(
    "setting\ttransfer_insert_after\t",
    state.transfer_insert_after and "1" or "0",
    "\n"
  )

  file:write(
    "setting\ttransfer_open_dir_after\t",
    state.transfer_open_dir_after and "1" or "0",
    "\n"
  )

  file:write(
    "setting\ttransfer_lowercase\t",
    state.transfer_lowercase and "1" or "0",
    "\n"
  )

  file:write(
    "setting\ttransfer_dither\t",
    state.transfer_dither and "1" or "0",
    "\n"
  )

  file:write(
    "setting\ttransfer_noise_shaping\t",
    state.transfer_noise_shaping and "1" or "0",
    "\n"
  )

  file:write(
    "setting\ttransfer_preserve_metadata\t",
    state.transfer_preserve_metadata and "1" or "0",
    "\n"
  )

  file:write(
    "setting\ttransfer_variants_enabled\t",
    state.transfer_variants_enabled and "1" or "0",
    "\n"
  )

  file:write(
    "setting\ttransfer_variant_pitches\t",
    escape_tsv(state.transfer_variant_pitches or ""),
    "\n"
  )

  file:write(
    "setting\ttransfer_variant_rates\t",
    escape_tsv(state.transfer_variant_rates or ""),
    "\n"
  )

  file:write(
    "setting\ttransfer_variant_gains\t",
    escape_tsv(state.transfer_variant_gains or ""),
    "\n"
  )

  file:write(
    "setting\ttransfer_variant_include_reverse\t",
    state.transfer_variant_include_reverse and "1" or "0",
    "\n"
  )

  file:write(
    "setting\ttransfer_variant_auto_suffix\t",
    state.transfer_variant_auto_suffix and "1" or "0",
    "\n"
  )

  file:write(
    "setting\ttheme_preset\t",
    escape_tsv(state.theme_preset),
    "\n"
  )

  file:write(
    "setting\tcustom_accent_hex\t",
    escape_tsv(state.custom_accent_hex),
    "\n"
  )

  file:write(
    "setting\tcustom_shell_hex\t",
    escape_tsv(state.custom_shell_hex),
    "\n"
  )

  file:write(
    "setting\tlanguage\t",
    state.language,
    "\n"
  )

  file:write(
    "setting\tfolder_browser_open\t",
    state.folder_browser_open and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tactive_folder_path\t",
    escape_tsv(state.root_filter or ""),
    "\n"
  )

  file:write(
    "setting\tmini_wave_points\t",
    tostring(state.mini_wave_points),
    "\n"
  )

  file:write(
    "setting\tprecache_points\t",
    tostring(state.precache_points),
    "\n"
  )

  file:write(
    "setting\tmultichannel_waveform\t",
    state.multichannel_waveform and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tspectral_peaks_enabled\t",
    state.spectral_peaks_enabled and "1" or "0",
    "\n"
  )

  file:write(
    "setting\twave_cache_dir\t",
    escape_tsv(
      state.wave_cache_dir
        or DEFAULT_WAVE_CACHE_DIR
    ),
    "\n"
  )

  file:write(
    "setting\tui_density\t",
    state.ui_density,
    "\n"
  )

  file:write(
    "setting\tsurface_style\t",
    state.surface_style,
    "\n"
  )

  file:write(
    "setting\twave_scrub_enabled\t",
    state.wave_scrub_enabled and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tloop_selection\t",
    state.loop_selection and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tpreview_control_layout\t",
    state.preview_control_layout,
    "\n"
  )

  file:write(
    "setting\tbottom_panel_height\t",
    tostring(state.bottom_panel_height),
    "\n"
  )

  file:write(
    "setting\tpreview_channel_mode\t",
    state.preview_channel_mode == "custom"
      and "original"
      or state.preview_channel_mode,
    "\n"
  )

  file:write(
    "setting\tloudness_match\t",
    state.loudness_match and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tloudness_target_db\t",
    tostring(state.loudness_target_db),
    "\n"
  )

  file:write(
    "setting\ttransient_threshold\t",
    tostring(state.transient_threshold),
    "\n"
  )

  file:write(
    "setting\ttransient_min_gap_ms\t",
    tostring(state.transient_min_gap_ms),
    "\n"
  )

  file:write(
    "setting\ttransient_pre_ms\t",
    tostring(state.transient_pre_ms),
    "\n"
  )

  file:write(
    "setting\ttransient_post_ms\t",
    tostring(state.transient_post_ms),
    "\n"
  )

  file:write(
    "setting\ttransient_smoothing_ms\t",
    tostring(state.transient_smoothing_ms),
    "\n"
  )

  file:write(
    "setting\ttransient_max_regions\t",
    tostring(state.transient_max_regions),
    "\n"
  )

  file:write(
    "setting\ttransient_replace_existing\t",
    state.transient_replace_existing and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tshow_loudness_metrics\t",
    state.show_loudness_metrics and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tloudness_show_i\t",
    state.loudness_show_i and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tloudness_show_m\t",
    state.loudness_show_m and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tloudness_show_s\t",
    state.loudness_show_s and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tloudness_show_tp\t",
    state.loudness_show_tp and "1" or "0",
    "\n"
  )

  file:write(
    "setting\twaveform_hex\t",
    escape_tsv(state.waveform_hex),
    "\n"
  )

  file:write(
    "setting\twaveform_selected_hex\t",
    escape_tsv(state.waveform_selected_hex),
    "\n"
  )

  file:write(
    "setting\twaveform_played_hex\t",
    escape_tsv(state.waveform_played_hex),
    "\n"
  )

  file:write(
    "setting\twaveform_marked_hex\t",
    escape_tsv(state.waveform_marked_hex),
    "\n"
  )

  file:write(
    "setting\tplayed_text_hex\t",
    escape_tsv(state.played_text_hex),
    "\n"
  )

  file:write(
    "setting\tplayed_text_enabled\t",
    state.played_text_enabled and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tplayed_waveform_enabled\t",
    state.played_waveform_enabled and "1" or "0",
    "\n"
  )

  file:write(
    "setting\trestore_played_on_start\t",
    state.restore_played_on_start and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tartwork_enabled\t",
    state.artwork_enabled and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tinspector_artwork_pinned\t",
    state.inspector_artwork_pinned and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tselection_hex\t",
    escape_tsv(state.selection_hex),
    "\n"
  )

  file:write(
    "setting\tplayhead_hex\t",
    escape_tsv(state.playhead_hex),
    "\n"
  )

  file:write(
    "setting\tregion_hex\t",
    escape_tsv(state.region_hex),
    "\n"
  )

  file:write(
    "setting\tsidebar_visible\t",
    state.sidebar_visible and "1" or "0",
    "\n"
  )

  for _, key in ipairs({
    "sounds",
    "libraries",
    "ucs",
    "collections",
    "saved_searches",
    "workflow",
    "activity",
  }) do
    file:write(
      "setting\tsidebar_section_",
      key,
      "\t",
      state.sidebar_sections[key] ~= false
        and "1" or "0",
      "\n"
    )
  end

  file:write(
    "setting\tinspector_visible\t",
    state.inspector_visible and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tinspector_width\t",
    tostring(state.inspector_width),
    "\n"
  )

  file:write(
    "setting\tactive_collection_id\t",
    escape_tsv(state.active_collection_id or ""),
    "\n"
  )

  file:write(
    "setting\tstatus_filter\t",
    escape_tsv(state.status_filter or ""),
    "\n"
  )

  for key, visible in pairs(state.column_visible) do
    file:write(
      "setting\tcolumn_visible_",
      key,
      "\t",
      visible and "1" or "0",
      "\n"
    )
  end

  for key, width in pairs(state.column_widths) do
    file:write(
      "setting\tcolumn_width_",
      key,
      "\t",
      tostring(width),
      "\n"
    )
  end

  if not file:close() then
    set_status("无法保存配置", true)
    return false
  end
  state.config_dirty = false
  return true
end

-- Incremental result construction keeps large catalogs out of a single UI
-- frame. The module is intentionally independent of REAPER/ImGui so the
-- ordering contract can be exercised by the command-line Lua self-test.

RESULT_BUILD_DEFAULT_BUDGET = 10000
RESULT_SORT_CHUNK_SIZE = 4096

-- Keep the ordering relation strict in both directions. The common
-- `ascending and left < right or left > right` idiom is not equivalent to an
-- if/else in Lua: when the ascending comparison is false it evaluates the
-- descending branch as a fallback, making both a<b and b<a true.
function ordered_result_less(left, right, direction)
  if (tonumber(direction) or 1) < 0 then
    return left > right
  end
  return left < right
end

function begin_incremental_result_job(
  source,
  predicate,
  less,
  key_selector,
  selected_key
)
  return {
    source = source or {},
    predicate = predicate,
    less = less,
    key_selector = key_selector,
    selected_key = selected_key,
    index = 1,
    total = #(source or {}),
    matches = {},
    sort_index = 1,
    runs = {},
    stage = "filter",
    selected_index = 0,
  }
end

local function begin_merge_round(job)
  if #job.runs <= 1 then
    job.result = job.runs[1] or {}
    job.runs = nil
    job.select_index = 1
    job.stage = "select"
    return
  end

  job.merge_input = job.runs
  job.merge_output = {}
  job.merge_pair_index = 1
  job.merge = nil
  job.runs = nil
  job.stage = "merge"
end

local function prepare_merge_pair(job)
  local left = job.merge_input[job.merge_pair_index]
  local right = job.merge_input[job.merge_pair_index + 1]

  if not left then
    job.runs = job.merge_output
    job.merge_input = nil
    job.merge_output = nil
    begin_merge_round(job)
    return false
  end

  if not right then
    job.merge_output[#job.merge_output + 1] = left
    job.merge_pair_index = job.merge_pair_index + 2
    return false
  end

  job.merge = {
    left = left,
    right = right,
    left_index = 1,
    right_index = 1,
    output = {},
  }
  return true
end

local function append_merge_value(merge, value)
  merge.output[#merge.output + 1] = value
end

local function step_merge(job, budget)
  local processed = 0

  while processed < budget and job.stage == "merge" do
    if not job.merge then
      if not prepare_merge_pair(job) then
        if job.stage ~= "merge" then
          break
        end
      end
    end

    local merge = job.merge
    if merge then
      local left_value = merge.left[merge.left_index]
      local right_value = merge.right[merge.right_index]

      if left_value and right_value then
        if job.less(right_value, left_value) then
          append_merge_value(merge, right_value)
          merge.right_index = merge.right_index + 1
        else
          append_merge_value(merge, left_value)
          merge.left_index = merge.left_index + 1
        end
      elseif left_value then
        append_merge_value(merge, left_value)
        merge.left_index = merge.left_index + 1
      elseif right_value then
        append_merge_value(merge, right_value)
        merge.right_index = merge.right_index + 1
      else
        job.merge_output[#job.merge_output + 1] = merge.output
        job.merge_pair_index = job.merge_pair_index + 2
        job.merge = nil
      end

      processed = processed + 1
    end
  end
end

function step_incremental_result_job(job, budget)
  -- Keep collection work moving alongside allocation-heavy merge rounds.
  -- Small explicit steps avoid deferring all reclamation to one long UI frame.
  collectgarbage("step", 16)
  budget = math.max(
    1,
    math.floor(tonumber(budget) or RESULT_BUILD_DEFAULT_BUDGET)
  )

  if job.stage == "filter" then
    local processed = 0
    while job.index <= job.total and processed < budget do
      local value = job.source[job.index]
      if value and job.predicate(value) then
        job.matches[#job.matches + 1] = value
      end
      job.index = job.index + 1
      processed = processed + 1
    end

    if job.index > job.total then
      job.source = nil
      job.stage = "sort_chunks"
    end
  elseif job.stage == "sort_chunks" then
    if job.sort_index <= #job.matches then
      local run = {}
      local last = math.min(
        #job.matches,
        job.sort_index + RESULT_SORT_CHUNK_SIZE - 1
      )
      for index = job.sort_index, last do
        run[#run + 1] = job.matches[index]
      end
      table.sort(run, job.less)
      job.runs[#job.runs + 1] = run
      job.sort_index = last + 1
    else
      job.matches = nil
      begin_merge_round(job)
    end
  elseif job.stage == "merge" then
    step_merge(job, budget)
  elseif job.stage == "select" then
    if not job.selected_key or not job.key_selector then
      job.stage = "complete"
    else
      local processed = 0
      while job.select_index <= #job.result
        and processed < budget do
        if job.key_selector(job.result[job.select_index])
          == job.selected_key then
          job.selected_index = job.select_index
          job.select_index = #job.result + 1
          break
        end
        job.select_index = job.select_index + 1
        processed = processed + 1
      end
      if job.select_index > #job.result then
        job.stage = "complete"
      end
    end
  end

  if job.stage == "complete" then
    return "complete", job.result or {}, job.selected_index or 0
  end

  return "pending"
end

-- Generation-bound asset journal codec. Decoding validates the complete
-- payload before callers apply any entry, so a torn/corrupt journal cannot
-- partially mutate the in-memory catalog.

local ASSET_JOURNAL_MAGIC = "psyreasfx_asset_journal"
local ASSET_JOURNAL_VERSION = 1

function new_asset_change_set()
  return { by_key = {}, count = 0, requires_snapshot = false }
end

function record_asset_change(change_set, key, operation, values)
  if type(change_set) ~= "table" or type(change_set.by_key) ~= "table"
    or (operation ~= "upsert" and operation ~= "delete") then
    return false
  end
  key = tostring(key or "")
  if key == "" or type(values) ~= "table" then return false end
  if not change_set.by_key[key] then
    change_set.count = (change_set.count or 0) + 1
  end
  local copied_values = {}
  for index, value in ipairs(values) do
    copied_values[index] = value
  end
  change_set.by_key[key] = {
    op = operation,
    values = copied_values,
  }
  return true
end

function asset_changes_require_snapshot(
  change_set,
  snapshot_exists,
  compact_count
)
  if not snapshot_exists or type(change_set) ~= "table" then
    return true
  end
  local count = math.floor(tonumber(change_set.count) or 0)
  local threshold = math.max(
    1,
    math.floor(tonumber(compact_count) or 1)
  )
  return change_set.requires_snapshot == true
    or count <= 0
    or count >= threshold
end

function require_asset_snapshot(change_set)
  if type(change_set) ~= "table" then return false end
  change_set.requires_snapshot = true
  return true
end

function ordered_asset_changes(change_set)
  local keys = {}
  for key in pairs(change_set and change_set.by_key or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  local entries = {}
  for _, key in ipairs(keys) do
    entries[#entries + 1] = change_set.by_key[key]
  end
  return entries
end

function clear_asset_changes(change_set)
  if type(change_set) ~= "table" then return false end
  change_set.by_key = {}
  change_set.count = 0
  change_set.requires_snapshot = false
  return true
end

function merge_asset_changes(target, source)
  if type(target) ~= "table" or type(target.by_key) ~= "table"
    or type(source) ~= "table" or type(source.by_key) ~= "table" then
    return false
  end
  for key, entry in pairs(source.by_key) do
    if type(entry) == "table" then
      record_asset_change(target, key, entry.op, entry.values or {})
    end
  end
  if source.requires_snapshot == true then
    require_asset_snapshot(target)
  end
  return true
end

local function journal_escape(value)
  return tostring(value or "")
    :gsub("\\", "\\\\")
    :gsub("\t", "\\t")
    :gsub("\r", "\\r")
    :gsub("\n", "\\n")
end

local function journal_split(line)
  local fields = {}
  local current = {}
  local escaped = false
  local text = tostring(line or "")
  for index = 1, #text do
    local character = text:sub(index, index)
    if escaped then
      current[#current + 1] = character == "t" and "\t"
        or character == "r" and "\r"
        or character == "n" and "\n"
        or character
      escaped = false
    elseif character == "\\" then
      escaped = true
    elseif character == "\t" then
      fields[#fields + 1] = table.concat(current)
      current = {}
    else
      current[#current + 1] = character
    end
  end
  if escaped then current[#current + 1] = "\\" end
  fields[#fields + 1] = table.concat(current)
  return fields
end

local function journal_checksum(text)
  local first = 1
  local second = 0
  for index = 1, #text do
    first = (first + text:byte(index)) % 65521
    second = (second + first) % 65521
  end
  return string.format("%08x", second * 65536 + first)
end

local function journal_fields_equal(left, right)
  if #left ~= #right then return false end
  for index = 1, #left do
    if left[index] ~= right[index] then return false end
  end
  return true
end

function encode_asset_journal(generation, fields, entries)
  generation = tonumber(generation)
  if not generation or generation < 0 or generation % 1 ~= 0 then
    return nil, "invalid_generation"
  end
  if type(fields) ~= "table" or #fields == 0 then
    return nil, "invalid_fields"
  end

  local lines = {
    ASSET_JOURNAL_MAGIC .. "\t" .. tostring(ASSET_JOURNAL_VERSION),
    "base_generation\t" .. tostring(generation),
    "op\t" .. table.concat(fields, "\t"),
  }
  for _, entry in ipairs(entries or {}) do
    local operation = entry.op
    local values = entry.values
    if (operation ~= "upsert" and operation ~= "delete")
      or type(values) ~= "table" or #values ~= #fields then
      return nil, "invalid_entry"
    end
    local encoded = { operation }
    for index = 1, #fields do
      encoded[#encoded + 1] = journal_escape(values[index])
    end
    local payload = table.concat(encoded, "\t")
    lines[#lines + 1] = payload .. "\t" .. journal_checksum(payload)
  end
  return table.concat(lines, "\n") .. "\n"
end

function decode_asset_journal(text, expected_generation, expected_fields)
  text = tostring(text or "")
  if text == "" or text:sub(-1) ~= "\n" then
    return nil, "truncated_payload"
  end
  local lines = {}
  for line in text:gmatch("([^\n]*)\n") do
    lines[#lines + 1] = line:gsub("\r$", "")
  end
  if #lines < 3 then return nil, "truncated_header" end

  local magic = journal_split(lines[1])
  if magic[1] ~= ASSET_JOURNAL_MAGIC
    or tonumber(magic[2]) ~= ASSET_JOURNAL_VERSION then
    return nil, "unsupported_schema"
  end
  local generation = journal_split(lines[2])
  if generation[1] ~= "base_generation"
    or tonumber(generation[2]) ~= tonumber(expected_generation) then
    return nil, "generation_mismatch"
  end
  local header = journal_split(lines[3])
  if header[1] ~= "op" then return nil, "invalid_header" end
  table.remove(header, 1)
  if not journal_fields_equal(header, expected_fields or {}) then
    return nil, "field_mismatch"
  end

  local entries = {}
  for index = 4, #lines do
    local line = lines[index]
    if line ~= "" then
      local checksum_offset = line:match("^.*()\t")
      if not checksum_offset then return nil, "missing_checksum" end
      local payload = line:sub(1, checksum_offset - 1)
      local checksum = line:sub(checksum_offset + 1)
      if journal_checksum(payload) ~= checksum then
        return nil, "checksum_mismatch"
      end
      local values = journal_split(payload)
      local operation = table.remove(values, 1)
      if (operation ~= "upsert" and operation ~= "delete")
        or #values ~= #header then
        return nil, "invalid_entry"
      end
      entries[#entries + 1] = { op = operation, values = values }
    end
  end
  return entries
end

function read_asset_journal(path, expected_generation, expected_fields)
  local file, open_error = io.open(path, "rb")
  if not file then return nil, open_error or "missing" end
  local text, read_error = file:read("*a")
  local closed = file:close()
  if not text or not closed then
    return nil, read_error or "read_failed"
  end
  return decode_asset_journal(
    text,
    expected_generation,
    expected_fields
  )
end

function write_asset_journal_atomic(
  path,
  generation,
  fields,
  entries,
  writer_factory
)
  local encoded, encode_error = encode_asset_journal(
    generation,
    fields,
    entries
  )
  if not encoded then return false, encode_error end
  local file, open_error = writer_factory(path)
  if not file then return false, open_error or "open_failed" end
  if not file:write(encoded) then
    file:close()
    return false, "write_failed"
  end
  if not file:close() then return false, "commit_failed" end
  return true, #encoded
end

-- Sparse activity indexes and frame-budgeted aggregate caches for large
-- catalogs. These helpers are REAPER-independent so capacity behavior can be
-- tested without launching the UI.

function new_library_count_job()
  return { index = 1, counts = {} }
end

function step_library_count_job(job, assets, batch_size)
  if type(job) ~= "table" or type(assets) ~= "table" then
    return false, nil, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local last = math.min(#assets, job.index + batch_size - 1)
  for index = job.index, last do
    local id = tostring(assets[index].library_id or "")
    if id ~= "" then
      job.counts[id] = (job.counts[id] or 0) + 1
    end
  end
  job.index = last + 1
  return job.index > #assets, job.counts
end

function ucs_count_key(value)
  return string.upper(tostring(value or ""):match("^%s*(.-)%s*$"))
end

function ucs_subcategory_count_key(category, subcategory)
  return ucs_count_key(category) .. "\0" .. ucs_count_key(subcategory)
end

function new_ucs_count_job()
  return {
    index = 1,
    counts = {
      categories = {},
      subcategories = {},
      catids = {},
      total = 0,
    },
  }
end

function step_ucs_count_job(job, assets, batch_size)
  if type(job) ~= "table" or type(assets) ~= "table"
    or type(job.counts) ~= "table" then
    return false, nil, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local last = math.min(#assets, job.index + batch_size - 1)
  for index = job.index, last do
    local asset = assets[index]
    local catid = asset and ucs_count_key(asset.catid) or ""
    local category = asset and ucs_count_key(asset.category) or ""
    local subcategory = asset and ucs_count_key(asset.subcategory) or ""
    if asset and asset.ready and catid ~= "" then
      job.counts.catids[catid] = (job.counts.catids[catid] or 0) + 1
      if category ~= "" then
        job.counts.categories[category] =
          (job.counts.categories[category] or 0) + 1
      end
      if category ~= "" and subcategory ~= "" then
        local pair = ucs_subcategory_count_key(category, subcategory)
        job.counts.subcategories[pair] =
          (job.counts.subcategories[pair] or 0) + 1
      end
      job.counts.total = job.counts.total + 1
    end
  end
  job.index = last + 1
  return job.index > #assets, job.counts
end

function ordered_preview_history_assets(
  history_assets,
  by_path,
  path_key_function,
  sort_key_function
)
  local assets = {}
  for _, asset in pairs(history_assets or {}) do
    local key = asset and path_key_function(asset.path) or nil
    if key and by_path[key] == asset
      and (tonumber(asset.last_previewed) or 0) > 0 then
      assets[#assets + 1] = asset
    end
  end
  table.sort(assets, function(left, right)
    return sort_key_function(left) < sort_key_function(right)
  end)
  return assets
end

-- Add a file to a size bucket without retaining every singleton in a second
-- candidate array. The first item is emitted only when a second item proves
-- that the size can contain duplicates.
function add_duplicate_size_candidate(groups, candidates, size, asset)
  if type(groups) ~= "table" or type(candidates) ~= "table"
    or type(asset) ~= "table" or (tonumber(size) or 0) <= 0 then
    return false
  end
  local key = tonumber(size)
  local group = groups[key]
  if not group then
    groups[key] = { first = asset, count = 1 }
    return false
  end
  group.count = group.count + 1
  if group.count == 2 then
    candidates[#candidates + 1] = group.first
  end
  candidates[#candidates + 1] = asset
  return true
end

-- Build final fingerprint groups while fingerprints are produced. This avoids
-- a second full pass over every candidate at the end of a large scan.
function add_duplicate_fingerprint_asset(
  groups,
  duplicates,
  lookup,
  fingerprint,
  asset,
  path_key_function
)
  if type(groups) ~= "table" or type(duplicates) ~= "table"
    or type(lookup) ~= "table" or type(asset) ~= "table"
    or type(path_key_function) ~= "function" then
    return false
  end
  fingerprint = tostring(fingerprint or "")
  if fingerprint == "" then return false end

  local group = groups[fingerprint]
  if not group then
    groups[fingerprint] = {
      fingerprint = fingerprint,
      assets = { asset },
      count = 1,
    }
    return false
  end

  group.assets[#group.assets + 1] = asset
  group.count = #group.assets
  if group.count == 2 then
    duplicates[#duplicates + 1] = group
    lookup[path_key_function(group.assets[1].path)] = fingerprint
  end
  lookup[path_key_function(asset.path)] = fingerprint
  return true
end

-- Incrementally filter a path-indexed catalog while allowing the caller to
-- remove the current entry safely. The next key is captured before deletion,
-- avoiding Lua's invalid-key-to-next failure mode.
function new_catalog_prune_job(by_path)
  by_path = type(by_path) == "table" and by_path or {}
  return {
    by_path = by_path,
    next_key = next(by_path),
    kept = {},
    processed = 0,
    removed = 0,
  }
end

function step_catalog_prune_job(
  job,
  batch_size,
  should_remove,
  on_remove
)
  if type(job) ~= "table" or type(job.by_path) ~= "table"
    or type(should_remove) ~= "function" then
    return false, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local processed = 0
  while job.next_key ~= nil and processed < batch_size do
    local key = job.next_key
    local asset = job.by_path[key]
    job.next_key = next(job.by_path, key)
    if asset and should_remove(key, asset) then
      job.by_path[key] = nil
      job.removed = job.removed + 1
      if type(on_remove) == "function" then
        on_remove(key, asset)
      end
    elseif asset then
      job.kept[#job.kept + 1] = asset
    end
    job.processed = job.processed + 1
    processed = processed + 1
  end
  return job.next_key == nil
end

function new_artwork_reset_job(assets)
  assets = type(assets) == "table" and assets or {}
  return {
    assets = assets,
    index = 1,
    total = #assets,
    changed = 0,
  }
end

function step_artwork_reset_job(job, batch_size)
  if type(job) ~= "table" or type(job.assets) ~= "table" then
    return false, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local last = math.min(job.total, job.index + batch_size - 1)
  for index = job.index, last do
    local asset = job.assets[index]
    if asset and asset.artwork_path ~= "-" then
      if asset.artwork_path ~= "" or asset.artwork_checked then
        job.changed = job.changed + 1
      end
      asset.artwork_path = ""
      asset.artwork_checked = false
    end
  end
  job.index = last + 1
  return job.index > job.total
end

function new_catalog_filter_job(assets)
  assets = type(assets) == "table" and assets or {}
  return {
    assets = assets,
    index = 1,
    total = #assets,
    kept = {},
    removed = {},
    kept_by_key = {},
  }
end

function step_catalog_filter_job(
  job,
  batch_size,
  should_remove,
  key_function,
  deadline,
  time_function
)
  if type(job) ~= "table" or type(job.assets) ~= "table"
    or type(should_remove) ~= "function"
    or type(key_function) ~= "function" then
    return false, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local last = math.min(job.total, job.index + batch_size - 1)
  while job.index <= last do
    local asset = job.assets[job.index]
    if asset then
      if should_remove(asset) then
        job.removed[#job.removed + 1] = asset
      else
        job.kept[#job.kept + 1] = asset
        job.kept_by_key[key_function(asset)] = asset
      end
    end
    job.index = job.index + 1
    if deadline and type(time_function) == "function"
      and job.index % 64 == 0 and time_function() >= deadline then
      break
    end
  end
  return job.index > job.total
end

-- Rebuild an ordered path set without mutating the live collection. The
-- second map pass repairs legacy entries that were missing from `order` and
-- also guarantees that duplicate order entries collapse to one item.
function new_ordered_path_filter_job(order, items)
  order = type(order) == "table" and order or {}
  items = type(items) == "table" and items or {}
  return {
    order = order,
    items = items,
    phase = "order",
    index = 1,
    next_key = nil,
    kept_order = {},
    kept_items = {},
    rejected = {},
    processed = 0,
    removed = 0,
    repaired = 0,
  }
end

function step_ordered_path_filter_job(
  job,
  batch_size,
  should_remove,
  key_function,
  deadline,
  time_function
)
  if type(job) ~= "table" or type(job.order) ~= "table"
    or type(job.items) ~= "table"
    or type(should_remove) ~= "function"
    or type(key_function) ~= "function" then
    return false, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local processed = 0
  while processed < batch_size do
    if job.phase == "order" then
      local ordered_path = job.order[job.index]
      if ordered_path == nil then
        job.phase = "items"
        job.next_key = next(job.items)
      else
        job.index = job.index + 1
        local key = key_function(ordered_path)
        local stored_path = job.items[key]
        if stored_path ~= nil then
          if should_remove(stored_path, key) then
            if not job.rejected[key] then
              job.rejected[key] = true
              job.removed = job.removed + 1
            end
          elseif job.kept_items[key] == nil then
            job.kept_items[key] = stored_path
            job.kept_order[#job.kept_order + 1] = stored_path
          else
            job.repaired = job.repaired + 1
          end
        else
          job.repaired = job.repaired + 1
        end
        job.processed = job.processed + 1
        processed = processed + 1
      end
    elseif job.phase == "items" then
      local key = job.next_key
      if key == nil then
        job.phase = "done"
        return true
      end
      local stored_path = job.items[key]
      job.next_key = next(job.items, key)
      local canonical_key = key_function(stored_path)
      if job.kept_items[canonical_key] == nil
        and not job.rejected[canonical_key] then
        if should_remove(stored_path, canonical_key) then
          job.rejected[canonical_key] = true
          job.removed = job.removed + 1
        else
          job.kept_items[canonical_key] = stored_path
          job.kept_order[#job.kept_order + 1] = stored_path
          job.repaired = job.repaired + 1
        end
      end
      job.processed = job.processed + 1
      processed = processed + 1
    else
      return true
    end
    if deadline and type(time_function) == "function"
      and processed % 64 == 0 and time_function() >= deadline then
      break
    end
  end
  return job.phase == "done"
end

-- Filter a path-keyed map into a detached result. Values are intentionally
-- shared because the removal transaction never mutates the surviving entry.
function new_path_map_filter_job(entries)
  entries = type(entries) == "table" and entries or {}
  return {
    entries = entries,
    next_key = next(entries),
    kept = {},
    processed = 0,
    removed = 0,
  }
end

function step_path_map_filter_job(
  job,
  batch_size,
  should_remove,
  path_function,
  deadline,
  time_function
)
  if type(job) ~= "table" or type(job.entries) ~= "table"
    or type(should_remove) ~= "function"
    or type(path_function) ~= "function" then
    return false, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local processed = 0
  while job.next_key ~= nil and processed < batch_size do
    local key = job.next_key
    local entry = job.entries[key]
    job.next_key = next(job.entries, key)
    if entry ~= nil and should_remove(path_function(entry, key), key) then
      job.removed = job.removed + 1
    elseif entry ~= nil then
      job.kept[key] = entry
    end
    job.processed = job.processed + 1
    processed = processed + 1
    if deadline and type(time_function) == "function"
      and processed % 64 == 0 and time_function() >= deadline then
      break
    end
  end
  return job.next_key == nil
end

-- Remove one catalog entry in O(1) while keeping a temporary key-to-position
-- index valid. Ordering is intentionally not preserved; result views apply
-- their own deterministic sort after startup.
function remove_indexed_array_entry(
  assets,
  positions,
  key,
  key_function
)
  if type(assets) ~= "table" or type(positions) ~= "table"
    or type(key_function) ~= "function" then
    return false
  end
  local index = positions[key]
  if type(index) ~= "number" or index < 1 or index > #assets then
    positions[key] = nil
    return false
  end
  local last_index = #assets
  local last_asset = assets[last_index]
  assets[index] = last_asset
  assets[last_index] = nil
  positions[key] = nil
  if index < last_index and last_asset then
    positions[key_function(last_asset)] = index
  end
  return true
end

-- Frame-budgeted serializers for large auxiliary catalogs. Callers own the
-- atomic writer and pass escaping/path-key functions so this module remains
-- independent from REAPER and can be capacity-tested from the command line.

function new_collections_persistence_job(collections)
  local snapshots = {}
  for _, collection in ipairs(collections or {}) do
    local order = collection.order or {}
    snapshots[#snapshots + 1] = {
      id = collection.id or "",
      name = collection.name or "",
      kind = collection.kind or "playlist",
      project_path = collection.project_path or "",
      items = collection.items or {},
      order = order,
      total = #order,
      header_written = false,
      item_index = 1,
    }
  end
  return {
    collections = snapshots,
    collection_index = 1,
    processed = 0,
  }
end

function step_collections_persistence_job(
  job,
  writer,
  batch_size,
  escape_function,
  key_function,
  deadline,
  time_function
)
  if type(job) ~= "table" or type(writer) ~= "table"
    or type(writer.write) ~= "function"
    or type(escape_function) ~= "function"
    or type(key_function) ~= "function" then
    return false, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local processed = 0
  while processed < batch_size do
    local snapshot = job.collections[job.collection_index]
    if not snapshot then return true end
    if not snapshot.header_written then
      snapshot.header_written = true
      if not writer:write(
        "collection\t", escape_function(snapshot.id), "\t",
        escape_function(snapshot.name), "\t",
        escape_function(snapshot.kind), "\t",
        escape_function(snapshot.project_path), "\n"
      ) then
        return false, "write_collection"
      end
      processed = processed + 1
      job.processed = job.processed + 1
    elseif snapshot.item_index <= snapshot.total then
      local path = snapshot.order[snapshot.item_index]
      snapshot.item_index = snapshot.item_index + 1
      if snapshot.items[key_function(path)] then
        if not writer:write(
          "item\t", escape_function(snapshot.id), "\t",
          escape_function(path), "\n"
        ) then
          return false, "write_item"
        end
      end
      processed = processed + 1
      job.processed = job.processed + 1
    else
      job.collection_index = job.collection_index + 1
    end
    if processed > 0 and processed % 64 == 0 and deadline
      and type(time_function) == "function"
      and time_function() >= deadline then
      return false
    end
  end
  local current = job.collections[job.collection_index]
  if current and current.header_written
    and current.item_index > current.total then
    job.collection_index = job.collection_index + 1
  end
  return job.collections[job.collection_index] == nil
end

function new_project_usage_persistence_job(project_usage)
  local projects = {}
  for _, bucket in pairs(project_usage or {}) do
    projects[#projects + 1] = {
      path = bucket.path or "",
      assets = bucket.assets or {},
      started = false,
      next_key = nil,
    }
  end
  return {
    projects = projects,
    project_index = 1,
    processed = 0,
  }
end

function step_project_usage_persistence_job(
  job,
  writer,
  batch_size,
  escape_function,
  deadline,
  time_function
)
  if type(job) ~= "table" or type(writer) ~= "table"
    or type(writer.write) ~= "function"
    or type(escape_function) ~= "function" then
    return false, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local processed = 0
  while processed < batch_size do
    local project = job.projects[job.project_index]
    if not project then return true end
    if not project.started then
      project.started = true
      project.next_key = next(project.assets)
    elseif project.next_key == nil then
      job.project_index = job.project_index + 1
    else
      local key = project.next_key
      local entry = project.assets[key]
      project.next_key = next(project.assets, key)
      if entry and not writer:write(
        "usage\t", escape_function(project.path), "\t",
        escape_function(entry.path or ""), "\t",
        tostring(entry.count or 1), "\t",
        tostring(entry.last_used or 0), "\t",
        escape_function(entry.action or "insert"), "\n"
      ) then
        return false, "write_usage"
      end
      processed = processed + 1
      job.processed = job.processed + 1
    end
    if processed > 0 and processed % 64 == 0 and deadline
      and type(time_function) == "function"
      and time_function() >= deadline then
      return false
    end
  end
  local current = job.projects[job.project_index]
  if current and current.started and current.next_key == nil then
    job.project_index = job.project_index + 1
  end
  return job.projects[job.project_index] == nil
end

function new_history_persistence_job(history_assets, by_path)
  history_assets = type(history_assets) == "table" and history_assets or {}
  return {
    entries = history_assets,
    by_path = type(by_path) == "table" and by_path or {},
    next_key = next(history_assets),
    processed = 0,
    written = 0,
  }
end

function step_history_persistence_job(
  job,
  writer,
  batch_size,
  escape_function,
  key_function,
  deadline,
  time_function
)
  if type(job) ~= "table" or type(writer) ~= "table"
    or type(writer.write) ~= "function"
    or type(escape_function) ~= "function"
    or type(key_function) ~= "function" then
    return false, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local processed = 0
  while job.next_key ~= nil and processed < batch_size do
    local id = job.next_key
    local asset = job.entries[id]
    job.next_key = next(job.entries, id)
    if asset and job.by_path[key_function(asset.path)] == asset
      and (tonumber(asset.last_previewed) or 0) > 0 then
      if not writer:write(
        "preview\t", escape_function(asset.path), "\t",
        tostring(asset.preview_count or 0), "\t",
        tostring(asset.last_previewed or 0), "\n"
      ) then
        return false, "write_history"
      end
      job.written = job.written + 1
    end
    processed = processed + 1
    job.processed = job.processed + 1
    if processed % 64 == 0 and deadline
      and type(time_function) == "function"
      and time_function() >= deadline then
      return false
    end
  end
  return job.next_key == nil
end

function new_path_set_persistence_job(path_set)
  path_set = type(path_set) == "table" and path_set or {}
  return {
    entries = path_set,
    next_key = next(path_set),
    saved = {},
    processed = 0,
  }
end

function step_path_set_persistence_job(
  job,
  writer,
  batch_size,
  escape_function,
  deadline,
  time_function
)
  if type(job) ~= "table" or type(writer) ~= "table"
    or type(writer.write) ~= "function"
    or type(escape_function) ~= "function" then
    return false, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local processed = 0
  while job.next_key ~= nil and processed < batch_size do
    local key = job.next_key
    job.next_key = next(job.entries, key)
    if job.entries[key] then
      if not writer:write("played\t", escape_function(key), "\n") then
        return false, "write_played"
      end
      job.saved[key] = true
    end
    processed = processed + 1
    job.processed = job.processed + 1
    if processed % 64 == 0 and deadline
      and type(time_function) == "function"
      and time_function() >= deadline then
      return false
    end
  end
  return job.next_key == nil
end

-- Map-backed catalogs can change between UI frames. Lua's next() raises an
-- error when its cursor key was removed, so retain a visited set and recover
-- from a deleted cursor by finding the first unvisited live key. Normal saves
-- stay O(n); the recovery scan is only paid when a concurrent deletion occurs.
local function take_next_live_map_entry(job)
  while job.next_key ~= nil do
    local entry_key = job.next_key
    local value = job.entries[entry_key]
    if value ~= nil then
      job.visited[entry_key] = true
      job.next_key = next(job.entries, entry_key)
      return entry_key, value
    end

    local candidate = next(job.entries)
    while candidate ~= nil and job.visited[candidate] do
      candidate = next(job.entries, candidate)
    end
    job.next_key = candidate
  end
  return nil
end

local function new_live_map_job(entries)
  entries = type(entries) == "table" and entries or {}
  return {
    entries = entries,
    next_key = next(entries),
    visited = {},
    processed = 0,
    written = 0,
  }
end

local function persistence_deadline_reached(processed, deadline, time_function)
  return processed > 0 and processed % 64 == 0 and deadline
    and type(time_function) == "function"
    and time_function() >= deadline
end

function new_regions_persistence_job(regions_by_path)
  local job = new_live_map_job(regions_by_path)
  job.current_regions = nil
  job.region_index = 1
  return job
end

function step_regions_persistence_job(
  job,
  writer,
  batch_size,
  escape_function,
  deadline,
  time_function
)
  if type(job) ~= "table" or type(writer) ~= "table"
    or type(writer.write) ~= "function"
    or type(escape_function) ~= "function" then
    return false, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local processed = 0
  while processed < batch_size do
    if not job.current_regions then
      local _, regions = take_next_live_map_entry(job)
      if not regions then return true end
      job.current_regions = regions
      job.region_index = 1
      if #regions == 0 then
        job.current_regions = nil
        processed = processed + 1
        job.processed = job.processed + 1
      end
    else
      local region = job.current_regions[job.region_index]
      if not region then
        job.current_regions = nil
      else
        job.region_index = job.region_index + 1
        if not writer:write(
          escape_function(region.path or ""), "\t",
          tostring(region.start or 0), "\t",
          tostring(region.finish or 0), "\t",
          escape_function(region.name or ""), "\t",
          escape_function(region.source or "manual"), "\t",
          tostring(region.batch_id or 0), "\n"
        ) then
          return false, "write_region"
        end
        processed = processed + 1
        job.processed = job.processed + 1
        job.written = job.written + 1
        if job.current_regions[job.region_index] == nil then
          job.current_regions = nil
        end
      end
    end
    if persistence_deadline_reached(processed, deadline, time_function) then
      return false
    end
  end
  return job.current_regions == nil and job.next_key == nil
end

function new_loudness_persistence_job(loudness_cache)
  return new_live_map_job(loudness_cache)
end

function step_loudness_persistence_job(
  job,
  writer,
  batch_size,
  escape_function,
  deadline,
  time_function
)
  if type(job) ~= "table" or type(writer) ~= "table"
    or type(writer.write) ~= "function"
    or type(escape_function) ~= "function" then
    return false, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local processed = 0
  while processed < batch_size do
    local _, entry = take_next_live_map_entry(job)
    if not entry then return true end
    if not writer:write(
      escape_function(entry.path or ""), "\t",
      tostring(entry.size or 0), "\t",
      tostring(entry.lufs_i or ""), "\t",
      tostring(entry.lufs_m or ""), "\t",
      tostring(entry.lufs_s or ""), "\t",
      tostring(entry.true_peak or ""), "\n"
    ) then
      return false, "write_loudness"
    end
    processed = processed + 1
    job.processed = job.processed + 1
    job.written = job.written + 1
    if persistence_deadline_reached(processed, deadline, time_function) then
      return false
    end
  end
  return job.next_key == nil
end

function new_failed_tasks_persistence_job(failed_tasks)
  return new_live_map_job(failed_tasks)
end

function step_failed_tasks_persistence_job(
  job,
  writer,
  batch_size,
  escape_function,
  deadline,
  time_function
)
  if type(job) ~= "table" or type(writer) ~= "table"
    or type(writer.write) ~= "function"
    or type(escape_function) ~= "function" then
    return false, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local processed = 0
  while processed < batch_size do
    local _, task = take_next_live_map_entry(job)
    if not task then return true end
    if not writer:write(
      escape_function(task.path or ""), "\t",
      escape_function(task.stage or "unknown"), "\t",
      escape_function(task.reason or ""), "\t",
      tostring(task.attempts or 1), "\t",
      tostring(task.updated or 0), "\n"
    ) then
      return false, "write_failed_task"
    end
    processed = processed + 1
    job.processed = job.processed + 1
    job.written = job.written + 1
    if persistence_deadline_reached(processed, deadline, time_function) then
      return false
    end
  end
  return job.next_key == nil
end

-- Region, loudness, channel and transient analysis services.
local HostApi = Host or reaper

function asset_regions(asset)
  if not asset then
    return {}
  end

  local key = path_key(asset.path)
  local regions = state.regions_by_path[key]

  if not regions then
    regions = {}
    state.regions_by_path[key] = regions
  end

  return regions
end

function sort_regions(regions)
  table.sort(
    regions,
    function(a, b)
      if a.start == b.start then
        return a.finish < b.finish
      end

      return a.start < b.start
    end
  )
end

function load_regions()
  state.regions_by_path = {}

  local file = io.open(REGIONS_FILE, "rb")

  if not file then
    return
  end

  for line in file:lines() do
    local fields = split_tsv(line)
    local path = fields[1]

    if is_persistence_schema_fields(fields) then
      path = ""
    end
    local start_value = tonumber(fields[2])
    local finish_value = tonumber(fields[3])
    local name = fields[4] or ""
    local source = fields[5]

    if not source or source == "" then
      source =
        name:match("^Transient ")
        and "transient"
        or "manual"
    end

    local batch_id = tonumber(fields[6]) or 0

    if path and path ~= ""
      and start_value
      and finish_value
      and finish_value > start_value then

      local key = path_key(path)
      local regions =
        state.regions_by_path[key] or {}

      regions[#regions + 1] = {
        path = path,
        start = clamp(start_value, 0, 1),
        finish = clamp(finish_value, 0, 1),
        name = name ~= "" and name
          or string.format(
            "Region %02d",
            #regions + 1
          ),
        source =
          source == "transient"
          and "transient"
          or "manual",
        batch_id = batch_id,
      }

      state.regions_by_path[key] = regions
    end
  end

  file:close()

  for _, regions in pairs(state.regions_by_path) do
    sort_regions(regions)
  end
end

function save_regions()
  if state.root_removal_session then return false end
  ensure_dirs()

  local file = atomic_file_writer(REGIONS_FILE)

  if not file then
    set_status("无法保存 Region 数据", true)
    return
  end

  write_persistence_schema(file, REGIONS_FILE)

  local job = new_regions_persistence_job(state.regions_by_path)
  local complete, failure
  repeat
    complete, failure = step_regions_persistence_job(
      job,
      file,
      AUXILIARY_SAVE_RECORDS_PER_FRAME,
      escape_tsv
    )
    if failure then
      file:abort()
      set_status("无法保存 Region 数据：" .. tostring(failure), true)
      return false
    end
  until complete

  if not file:close() then
    set_status("无法保存 Region 数据", true)
    return false
  end
  state.regions_dirty = false
  return true
end

function add_saved_region(
  asset,
  start_value,
  finish_value,
  name,
  source,
  batch_id
)
  if not asset then
    return false
  end

  start_value =
    clamp(tonumber(start_value) or 0, 0, 1)

  finish_value =
    clamp(tonumber(finish_value) or 0, 0, 1)

  if finish_value - start_value <= 0.002 then
    return false
  end

  local regions = asset_regions(asset)

  for _, region in ipairs(regions) do
    if math.abs(region.start - start_value) < 0.001
      and math.abs(region.finish - finish_value) < 0.001 then
      return false
    end
  end

  regions[#regions + 1] = {
    path = asset.path,
    start = start_value,
    finish = finish_value,
    name = name ~= "" and name
      or string.format(
        "Region %02d",
        #regions + 1
      ),
    source =
      source == "transient"
      and "transient"
      or "manual",
    batch_id = tonumber(batch_id) or 0,
  }

  sort_regions(regions)

  for index, region in ipairs(regions) do
    if math.abs(region.start - start_value) < 0.000001
      and math.abs(region.finish - finish_value) < 0.000001 then
      state.active_region_index = index
      break
    end
  end

  state.regions_dirty = true
  return true
end

function save_current_selection_as_region(asset)
  if not asset or not has_selection() then
    set_status(
      "请先在大波形中建立有效选区",
      true
    )
    return
  end

  local regions = asset_regions(asset)
  local default_name =
    string.format(
      "Region %02d",
      #regions + 1
    )

  local ok, name =
    HostApi.GetUserInputs(
      "保存当前选区为 Region",
      1,
      "名称:",
      default_name
    )

  if not ok then
    return
  end

  if add_saved_region(
    asset,
    state.region_start,
    state.region_end,
    trim(name)
  ) then
    set_status("Region 已保存")
  else
    set_status("该 Region 已存在或选区无效", true)
  end
end

function activate_saved_region(asset, index, auto_play)
  local regions = asset_regions(asset)
  local region = regions[index]

  if not region then
    return
  end

  state.active_region_index = index
  state.region_start = region.start
  state.region_end = region.finish

  if auto_play ~= false then
    if state.loop_selection then
      state.loop = true
    end

    play_preview(asset, nil, true)
  end
end

function delete_saved_region(asset, index)
  local regions = asset_regions(asset)

  if not regions[index] then
    return
  end

  table.remove(regions, index)

  if #regions == 0 then
    state.regions_by_path[path_key(asset.path)] = nil
    state.active_region_index = 0
  else
    state.active_region_index =
      clamp(
        state.active_region_index,
        1,
        #regions
      )
  end

  state.regions_dirty = true
  set_status("Region 已删除")
end


function latest_transient_batch_id(asset)
  local latest = 0

  for _, region in ipairs(asset_regions(asset)) do
    if region.source == "transient" then
      latest =
        math.max(
          latest,
          tonumber(region.batch_id) or 0
        )
    end
  end

  return latest
end

function clear_transient_regions(asset, batch_id)
  if not asset then
    return 0
  end

  local regions = asset_regions(asset)
  local kept = {}
  local removed = 0

  for _, region in ipairs(regions) do
    local matches =
      region.source == "transient"
      and (
        batch_id == nil
        or (tonumber(region.batch_id) or 0)
          == tonumber(batch_id)
      )

    if matches then
      removed = removed + 1
    else
      kept[#kept + 1] = region
    end
  end

  local key = path_key(asset.path)

  if #kept > 0 then
    state.regions_by_path[key] = kept
  else
    state.regions_by_path[key] = nil
  end

  if removed > 0 then
    state.active_region_index = 0
    state.regions_dirty = true
  end

  return removed
end

function undo_last_transient_detection(asset)
  local batch_id =
    latest_transient_batch_id(asset)

  if batch_id <= 0 then
    set_status("没有可撤销的瞬态检测结果", true)
    return
  end

  local removed =
    clear_transient_regions(asset, batch_id)

  set_status(
    string.format(
      "已撤销上次检测，移除 %d 个瞬态 Region",
      removed
    )
  )
end

function clear_all_transient_suggestions(asset)
  local removed =
    clear_transient_regions(asset, nil)

  if removed > 0 then
    set_status(
      string.format(
        "已清除 %d 个瞬态 Region 建议",
        removed
      )
    )
  else
    set_status("当前素材没有瞬态 Region 建议", true)
  end
end

function loudness_cache_key(asset)
  return path_key(asset.path)
end

function load_loudness_cache()
  state.loudness_cache = {}

  local file = io.open(LOUDNESS_FILE, "rb")

  if not file then
    return
  end

  for line in file:lines() do
    local fields = split_tsv(line)
    local path = fields[1]

    if is_persistence_schema_fields(fields) then
      path = ""
    end
    local size = tonumber(fields[2]) or 0

    if path and path ~= "" then
      state.loudness_cache[path_key(path)] = {
        path = path,
        size = size,
        lufs_i = tonumber(fields[3]),
        lufs_m = tonumber(fields[4]),
        lufs_s = tonumber(fields[5]),
        true_peak = tonumber(fields[6]),
      }
    end
  end

  file:close()
end

function save_loudness_cache()
  if state.root_removal_session then return false end
  ensure_dirs()

  local file = atomic_file_writer(LOUDNESS_FILE)

  if not file then
    set_status("无法保存响度缓存", true)
    return
  end

  write_persistence_schema(file, LOUDNESS_FILE)

  local job = new_loudness_persistence_job(state.loudness_cache)
  local complete, failure
  repeat
    complete, failure = step_loudness_persistence_job(
      job,
      file,
      AUXILIARY_SAVE_RECORDS_PER_FRAME,
      escape_tsv
    )
    if failure then
      file:abort()
      set_status("无法保存响度缓存：" .. tostring(failure), true)
      return false
    end
  until complete

  if not file:close() then
    set_status("无法保存响度缓存", true)
    return false
  end
  state.loudness_dirty = false
  return true
end

function valid_loudness_entry(asset)
  if not asset then
    return nil
  end

  local entry =
    state.loudness_cache[loudness_cache_key(asset)]

  if not entry then
    return nil
  end

  local size =
    tonumber(asset.size) or file_size(asset.path)

  if tonumber(entry.size) ~= size then
    state.loudness_cache[loudness_cache_key(asset)] = nil
    state.loudness_dirty = true
    return nil
  end

  return entry
end

function loudness_required_fields()
  local fields = {}

  if state.loudness_show_i then
    fields[#fields + 1] = {
      field = "lufs_i",
      mode = 0,
    }
  end

  if state.loudness_show_m then
    fields[#fields + 1] = {
      field = "lufs_m",
      mode = 4,
    }
  end

  if state.loudness_show_s then
    fields[#fields + 1] = {
      field = "lufs_s",
      mode = 5,
    }
  end

  if state.loudness_show_tp then
    fields[#fields + 1] = {
      field = "true_peak",
      mode = 3,
    }
  end

  return fields
end

function loudness_value_from_gain(gain, target)
  gain = tonumber(gain)

  if not gain
    or gain <= 0
    or gain ~= gain
    or gain == math.huge then
    return nil
  end

  -- CalculateNormalization 返回达到目标值所需的线性增益。
  return (target or 0)
    - 20 * math.log(gain, 10)
end

function request_loudness_analysis(asset, force)
  if not state.show_loudness_metrics
    or not asset
    or not HostApi.file_exists(asset.path)
    or type(HostApi.CalculateNormalization) ~= "function" then
    return
  end

  local key = loudness_cache_key(asset)
  local entry = valid_loudness_entry(asset)
  local required = loudness_required_fields()
  local missing = force == true

  if not missing then
    for _, metric in ipairs(required) do
      if not entry or entry[metric.field] == nil then
        missing = true
        break
      end
    end
  end

  if not missing
    or state.loudness_queued[key]
    or (
      state.loudness_active
      and state.loudness_active.key == key
    ) then
    return
  end

  -- 只保留最新的待分析素材，快速浏览时不会积压整条响度队列。
  state.loudness_queue = {}
  state.loudness_queued = {}
  state.loudness_queued[key] = true
  state.loudness_queue[1] = {
    key = key,
    asset = asset,
    force = force == true,
  }
end

function destroy_loudness_job(job, completed)
  if job and job.source then
    HostApi.PCM_Source_Destroy(job.source)
    job.source = nil
  end

  if job and job.job_token then
    if not completed then
      Jobs.cancel(job.job_token)
    end
    Jobs.finish(
      job.job_token,
      true,
      completed and "" or "canceled"
    )
    job.job_token = nil
  end
end

function process_loudness_queue()
  if not state.show_loudness_metrics
    or state.scan
    or state.import_session
    or not can_run_heavy_job() then
    return
  end

  local now = HostApi.time_precise()

  if now < state.next_loudness_job then
    return
  end

  if not state.loudness_active then
    local queued =
      table.remove(state.loudness_queue, 1)

    if not queued then
      return
    end

    state.loudness_queued[queued.key] = nil

    local source =
      HostApi.PCM_Source_CreateFromFile(
        queued.asset.path
      )

    if not source then
      return
    end

    local entry =
      valid_loudness_entry(queued.asset)
      or {
        path = queued.asset.path,
        size =
          tonumber(queued.asset.size)
          or file_size(queued.asset.path),
      }

    local metrics = loudness_required_fields()
    local pending = {}

    for _, metric in ipairs(metrics) do
      if queued.force
        or entry[metric.field] == nil then
        pending[#pending + 1] = metric
      end
    end

    if #pending == 0 then
      HostApi.PCM_Source_Destroy(source)
      return
    end

    state.loudness_active = {
      key = queued.key,
      asset = queued.asset,
      source = source,
      entry = entry,
      metrics = pending,
      index = 1,
      job_token =
        Jobs.begin(
          "loudness",
          "audio_analysis",
          true
        ),
    }
  end

  local job = state.loudness_active
  local metric = job.metrics[job.index]

  if not metric then
    state.loudness_cache[job.key] = job.entry
    state.loudness_dirty = true
    destroy_loudness_job(job, true)
    state.loudness_active = nil
    return
  end

  local ok, gain =
    pcall(
      HostApi.CalculateNormalization,
      job.source,
      metric.mode,
      0,
      0,
      0
    )

  if ok then
    job.entry[metric.field] =
      loudness_value_from_gain(gain, 0)
  end

  job.index = job.index + 1
  state.next_loudness_job = now + 0.05
end

function waveform_rms_proxy(asset)
  if not asset then
    return nil
  end

  if asset._preview_rms_proxy then
    return asset._preview_rms_proxy
  end

  local waveform =
    queue_wave(
      asset,
      LARGE_WAVE_DEFAULT_POINTS,
      true
    )

  if not waveform
    or not waveform.peaks
    or waveform.count <= 0 then
    return nil
  end

  local sum = 0

  for index = 1, waveform.count do
    local value = waveform.peaks[index] or 0
    sum = sum + value * value
  end

  local rms =
    math.sqrt(
      sum / math.max(1, waveform.count)
    )

  asset._preview_rms_proxy =
    math.max(rms, 0.000001)

  return asset._preview_rms_proxy
end

function loudness_match_offset_db(asset)
  if not state.loudness_match then
    return 0
  end

  local rms = waveform_rms_proxy(asset)

  if not rms then
    return 0
  end

  local current_db =
    20 * math.log(rms, 10)

  return clamp(
    state.loudness_target_db - current_db,
    -18,
    18
  )
end

function preview_asset_channel_count(asset)
  return clamp(
    math.floor(
      tonumber(asset and asset.channels) or 1
    ),
    1,
    8
  )
end

function reset_preview_channel_selection(asset)
  local count = preview_asset_channel_count(asset)
  local selected = {}

  for channel = 1, count do
    selected[channel] = true
  end

  state.preview_channel_asset_key =
    asset and path_key(asset.path) or nil
  state.preview_channel_count = count
  state.preview_channel_selection = selected
  state.preview_channel_anchor = 1

  if count > 2
    and state.preview_channel_mode == "custom" then
    state.preview_channel_mode = "original"
  end

  return selected, count
end

function ensure_preview_channel_selection(asset)
  local count = preview_asset_channel_count(asset)
  local key = asset and path_key(asset.path) or nil

  if state.preview_channel_asset_key ~= key
    or state.preview_channel_count ~= count then
    return reset_preview_channel_selection(asset)
  end

  return state.preview_channel_selection, count
end

function selected_preview_channel_count(asset)
  local selected, count =
    ensure_preview_channel_selection(asset)
  local selected_count = 0

  for channel = 1, count do
    if selected[channel] then
      selected_count = selected_count + 1
    end
  end

  return selected_count, count
end

function preview_channel_is_selected(asset, channel)
  local selected, count =
    ensure_preview_channel_selection(asset)

  if count <= 2 then
    if state.preview_channel_mode == "left" then
      return channel == 1
    elseif state.preview_channel_mode == "right" then
      return channel == 2
    end

    return true
  end

  return selected[channel] == true
end

function select_all_preview_channels(asset)
  local selected, count =
    ensure_preview_channel_selection(asset)

  for channel = 1, count do
    selected[channel] = true
  end

  state.preview_channel_mode = "original"
  state.preview_channel_anchor = 1
end

function apply_preview_channel_selection(
  asset,
  channel,
  ctrl,
  shift,
  solo
)
  local selected, channel_count =
    ensure_preview_channel_selection(asset)

  if solo or (not ctrl and not shift) then
    for item = 1, channel_count do
      selected[item] = item == channel
    end
  elseif shift then
    local first =
      math.min(
        state.preview_channel_anchor or channel,
        channel
      )
    local last =
      math.max(
        state.preview_channel_anchor or channel,
        channel
      )

    if not ctrl then
      for item = 1, channel_count do
        selected[item] = false
      end
    end

    for item = first, last do
      selected[item] = true
    end
  else
    selected[channel] = not selected[channel]

    if selected_preview_channel_count(asset) == 0 then
      selected[channel] = true
    end
  end

  state.preview_channel_anchor = channel

  local selected_after =
    selected_preview_channel_count(asset)

  state.preview_channel_mode =
    selected_after == channel_count
      and "original"
      or "custom"
  state.config_dirty = true
end

function preview_channel_label(channel, count)
  if count == 1 then
    return "M"
  elseif count == 2 then
    return channel == 1 and "L" or "R"
  end

  return string.format("CH %d", channel)
end

function cycle_preview_channel_mode(asset)
  local count = preview_asset_channel_count(asset)

  if count > 2 then
    return false
  end

  local order =
    count == 1
      and { "original", "mono" }
      or { "original", "left", "right", "mono" }
  local current = 1

  for index, mode in ipairs(order) do
    if mode == state.preview_channel_mode then
      current = index
      break
    end
  end

  state.preview_channel_mode =
    order[current % #order + 1]
  state.config_dirty = true

  if state.preview then
    update_preview_parameters()
  end

  return true
end

function apply_preview_channel_mode(preview, mono_output_channel)
  if not preview then
    return
  end

  local pan = 0

  if state.preview_channel_mode == "left" then
    pan = -1
  elseif state.preview_channel_mode == "right" then
    pan = 1
  end

  pcall(
    HostApi.CF_Preview_SetValue,
    preview,
    "D_PAN",
    pan
  )

  local use_centered_mono =
    state.preview_channel_mode == "left"
      or state.preview_channel_mode == "right"
      or state.preview_channel_mode == "mono"

  pcall(
    HostApi.CF_Preview_SetValue,
    preview,
    "I_OUTCHAN",
    use_centered_mono
      and (
        1024
          + clamp(
            math.floor(mono_output_channel or 0),
            0,
            1
          )
      )
      or 0
  )
end

function request_transient_detection(asset)
  if not asset then
    return
  end

  state.pending_transient_detection = asset.path

  queue_wave(
    asset,
    LARGE_WAVE_MAX_POINTS,
    true
  )

  set_status("正在准备高精度波形并检测瞬态…")
end

function cancel_pending_transient_detection()
  if state.pending_transient_detection then
    state.pending_transient_detection = nil
    set_status("已取消待执行的瞬态检测")
  end
end

function open_transient_detection_popup(asset)
  if not asset then
    return
  end

  state.transient_popup_asset_path = asset.path
  state.transient_popup_requested = 2
end

function perform_transient_detection(asset, waveform)
  if not asset
    or not waveform
    or waveform.count <= 2 then
    return
  end

  local duration = tonumber(asset.duration) or 0

  if duration <= 0 then
    set_status("素材时长不可用", true)
    return
  end

  local threshold =
    clamp(
      state.transient_threshold,
      0.001,
      0.95
    )

  local min_gap_points =
    math.max(
      1,
      math.floor(
        waveform.count
          * (state.transient_min_gap_ms / 1000)
          / duration
      )
    )

  local smoothing_points =
    math.max(
      0,
      math.floor(
        waveform.count
          * (state.transient_smoothing_ms / 1000)
          / duration
      )
    )

  local envelope = {}

  for index = 1, waveform.count do
    if smoothing_points <= 0 then
      envelope[index] = waveform.peaks[index] or 0
    else
      local first =
        math.max(1, index - smoothing_points)
      local last =
        math.min(
          waveform.count,
          index + smoothing_points
        )
      local sum = 0

      for sample = first, last do
        sum = sum + (waveform.peaks[sample] or 0)
      end

      envelope[index] =
        sum / math.max(1, last - first + 1)
    end
  end

  local pre_percent =
    (state.transient_pre_ms / 1000) / duration

  local post_percent =
    (state.transient_post_ms / 1000) / duration

  local candidates = {}
  local last_index = -min_gap_points
  local maximum =
    clamp(
      math.floor(state.transient_max_regions or 64),
      1,
      256
    )

  for index = 2, waveform.count - 1 do
    local value = envelope[index] or 0

    if value >= threshold
      and value >= (envelope[index - 1] or 0)
      and value >= (envelope[index + 1] or 0)
      and index - last_index >= min_gap_points then

      candidates[#candidates + 1] = index
      last_index = index

      if #candidates >= maximum then
        break
      end
    end
  end

  if #candidates == 0 then
    set_status(
      "未检测到超过当前阈值的瞬态",
      true
    )
    return
  end

  local batch_id =
    latest_transient_batch_id(asset) + 1

  if state.transient_replace_existing then
    clear_transient_regions(asset, nil)
  end

  local added = 0

  for index, peak_index in ipairs(candidates) do
    local center =
      (peak_index - 1)
      / math.max(1, waveform.count - 1)

    local next_center =
      candidates[index + 1]
      and (
        (candidates[index + 1] - 1)
        / math.max(1, waveform.count - 1)
      )
      or 1

    local start_value =
      clamp(center - pre_percent, 0, 1)

    local finish_value =
      math.min(
        1,
        math.max(
          start_value + 0.002,
          math.min(
            center + post_percent,
            next_center - pre_percent * 0.5
          )
        )
      )

    if finish_value > start_value
      and add_saved_region(
        asset,
        start_value,
        finish_value,
        string.format(
          "Transient %02d",
          index
        ),
        "transient",
        batch_id
      ) then
      added = added + 1
    end
  end

  if added > 0 then
    local regions = asset_regions(asset)

    for index, region in ipairs(regions) do
      if region.source == "transient"
        and tonumber(region.batch_id) == batch_id then
        state.active_region_index = index
        activate_saved_region(asset, index, false)
        break
      end
    end

    set_status(
      string.format(
        "已生成 %d 个瞬态 Region 建议；可在 Region 列表中撤销或清除",
        added
      )
    )
  else
    set_status(
      "没有新增瞬态 Region",
      true
    )
  end
end

function process_pending_transient_detection()
  local path = state.pending_transient_detection

  if not path then
    return
  end

  local asset = state.by_path[path_key(path)]

  if not asset then
    state.pending_transient_detection = nil
    return
  end

  local waveform =
    queue_wave(
      asset,
      LARGE_WAVE_MAX_POINTS,
      true
    )

  if waveform then
    state.pending_transient_detection = nil
    perform_transient_detection(asset, waveform)
  end
end

local DUPLICATE_COMPARE_CHUNK_SIZE = 256 * 1024
local DUPLICATE_FINGERPRINT_VERSION = "sample-fnv1a-head-mid-tail-v1"
local function duplicate_host_api()
  return Host or reaper
end

function duplicate_file_stat(path, fallback_size)
  local result = {
    size = tonumber(fallback_size) or 0,
    modified = "",
    source = "unavailable",
  }
  local host = duplicate_host_api()
  if not host or type(host.JS_File_Stat) ~= "function" then
    return result
  end
  local values = { pcall(host.JS_File_Stat, path) }
  if not values[1] or tonumber(values[2]) ~= 0 then
    return result
  end
  result.size = tonumber(values[3]) or result.size
  result.modified = tostring(values[5] or "")
  result.source = result.modified ~= "" and "js_file_stat" or "unavailable"
  return result
end

function clear_asset_fingerprint(asset)
  asset.fingerprint = ""
  asset.fingerprint_size = 0
  asset.fingerprint_version = ""
  asset.fingerprint_modified = ""
  asset.fingerprint_stat_source = ""
end

function fingerprint_metadata_is_compatible(asset)
  return tostring(asset.fingerprint or "") ~= ""
    and tostring(asset.fingerprint_version or "")
      == DUPLICATE_FINGERPRINT_VERSION
    and (tonumber(asset.fingerprint_size) or 0) > 0
    and tostring(asset.fingerprint_stat_source or "") == "js_file_stat"
    and tostring(asset.fingerprint_modified or "") ~= ""
end

function fingerprint_metadata_is_current(asset, stat)
  return fingerprint_metadata_is_compatible(asset)
    and tonumber(asset.fingerprint_size) == tonumber(stat.size)
    and stat.source == "js_file_stat"
    and stat.modified ~= ""
    and tostring(asset.fingerprint_modified or "") == stat.modified
end

function record_asset_fingerprint(asset, fingerprint, stat)
  asset.fingerprint = tostring(fingerprint or "")
  asset.fingerprint_size = tonumber(stat.size) or 0
  asset.fingerprint_version = DUPLICATE_FINGERPRINT_VERSION
  asset.fingerprint_modified = tostring(stat.modified or "")
  asset.fingerprint_stat_source = tostring(stat.source or "unavailable")
end

function duplicate_file_stats_match(left, right)
  return left.source == "js_file_stat"
    and right.source == "js_file_stat"
    and left.size == right.size
    and left.modified == right.modified
end

function duplicate_file_changed_since(before, after)
  return before.source == "js_file_stat"
    and not duplicate_file_stats_match(before, after)
end

function close_duplicate_comparison(comparison)
  if not comparison or comparison.closed then
    return
  end
  comparison.closed = true
  if comparison.left then
    comparison.left:close()
    comparison.left = nil
  end
  if comparison.right then
    comparison.right:close()
    comparison.right = nil
  end
end

function begin_duplicate_comparison(left_path, right_path)
  local left = io.open(left_path, "rb")
  if not left then
    return nil, "left_open"
  end
  local right = io.open(right_path, "rb")
  if not right then
    left:close()
    return nil, "right_open"
  end

  local left_size = left:seek("end")
  local right_size = right:seek("end")
  if not left_size or not right_size then
    left:close()
    right:close()
    return nil, "seek"
  end
  left:seek("set", 0)
  right:seek("set", 0)

  local comparison = {
    left = left,
    right = right,
    left_path = left_path,
    right_path = right_path,
    left_stat = duplicate_file_stat(left_path, left_size),
    right_stat = duplicate_file_stat(right_path, right_size),
    bytes_compared = 0,
    total_bytes = math.max(left_size, right_size),
    closed = false,
  }
  if left_size ~= right_size then
    close_duplicate_comparison(comparison)
    comparison.result = "different"
  end
  return comparison
end

function step_duplicate_comparison(comparison, chunk_size)
  if not comparison then
    return "failed"
  end
  if comparison.result then
    return comparison.result
  end
  if comparison.closed then
    return "failed"
  end

  chunk_size = math.max(
    4096,
    math.floor(tonumber(chunk_size) or DUPLICATE_COMPARE_CHUNK_SIZE)
  )
  local left_chunk, left_error = comparison.left:read(chunk_size)
  local right_chunk, right_error = comparison.right:read(chunk_size)
  if left_error or right_error then
    comparison.error = left_error or right_error or "read"
    comparison.result = "failed"
  elseif left_chunk ~= right_chunk then
    comparison.result = "different"
  elseif not left_chunk then
    local left_changed = duplicate_file_changed_since(
      comparison.left_stat,
      duplicate_file_stat(comparison.left_path, comparison.bytes_compared)
    )
    local right_changed = duplicate_file_changed_since(
      comparison.right_stat,
      duplicate_file_stat(comparison.right_path, comparison.bytes_compared)
    )
    comparison.result = (left_changed or right_changed) and "failed" or "equal"
  else
    comparison.bytes_compared = comparison.bytes_compared + #left_chunk
    return "pending"
  end

  close_duplicate_comparison(comparison)
  return comparison.result
end

function load_database()
  local file = io.open(DATABASE_FILE, "rb")

  if not file then
    return
  end

  local header_line = file:read("*l")

  if not header_line then
    file:close()
    return
  end

  local headers = split_tsv(header_line)
  state.database_generation = 0

  if is_persistence_schema_fields(headers) then
    local generation, generation_error =
      persistence_schema_generation(headers)
    if generation == nil then
      file:close()
      state.persistence_read_only = true
      state.persistence_read_only_reason =
        "索引快照代次无效：" .. tostring(generation_error)
      set_status("索引快照代次无效，已进入只读保护", true)
      return
    end
    state.database_generation = generation
    header_line = file:read("*l")

    if not header_line then
      file:close()
      return
    end

    headers = split_tsv(header_line)
  end

  local ignored = 0
  local journal_probe = io.open(DATABASE_JOURNAL_FILE, "rb")
  local asset_positions = journal_probe and {} or nil
  if journal_probe then journal_probe:close() end

  for line in file:lines() do
    local values = split_tsv(line)
    local asset = database_asset_from_values(headers, values)
    local raw_path = ""
    for index, field in ipairs(headers) do
      if field == "path" then
        raw_path = values[index] or ""
        break
      end
    end

    if asset then
      local key = asset_positions and path_key(asset.path) or nil
      local existed = key and state.by_path[key] ~= nil
      add_or_update_asset(asset, false)
      if key and not existed then
        asset_positions[key] = #state.assets
      end
    elseif raw_path ~= "" then
      ignored = ignored + 1
    end
  end

  file:close()

  local journal_ok = replay_database_journal(asset_positions)

  if ignored > 0 then
    mark_database_snapshot_dirty()
    if journal_ok then
      set_status(
        string.format(
          "已从索引自动忽略 %d 个系统元数据文件",
          ignored
        )
      )
    end
  end
end

function database_asset_from_values(headers, values)
  local asset = {}
  for index, field in ipairs(headers or {}) do
    asset[field] = values[index] or ""
  end
  if not asset.path or asset.path == ""
    or is_ignored_media_path(asset.path) then
    return nil
  end
  asset.duration = tonumber(asset.duration) or 0
  asset.channels = tonumber(asset.channels) or 0
  asset.sample_rate = tonumber(asset.sample_rate) or 0
  asset.bit_depth = tonumber(asset.bit_depth) or 0
  asset.size = tonumber(asset.size) or 0
  asset.workflow_status = WORKFLOW_STATUS[asset.workflow_status]
    and asset.workflow_status or "none"
  asset.marked = asset.marked == "1" or asset.marked == "true"
  asset.preview_count = tonumber(asset.preview_count) or 0
  asset.last_previewed = tonumber(asset.last_previewed) or 0
  asset.indexed = asset.indexed == "1" or asset.indexed == "true"
    or asset.duration > 0
  asset.ready = asset.ready == "1" or asset.ready == "true"
  asset.used_count = tonumber(asset.used_count) or 0
  asset.last_used = tonumber(asset.last_used) or 0
  asset.fingerprint = tostring(asset.fingerprint or "")
  asset.fingerprint_size = tonumber(asset.fingerprint_size) or 0
  asset.fingerprint_version = tostring(asset.fingerprint_version or "")
  asset.fingerprint_modified = tostring(asset.fingerprint_modified or "")
  asset.fingerprint_stat_source = tostring(asset.fingerprint_stat_source or "")
  asset.ucs_status = tostring(asset.ucs_status or "unclassified")
  asset.ucs_source = tostring(asset.ucs_source or "")
  asset.ucs_version = tostring(asset.ucs_version or "")
  asset.ucs_classifier_version = tostring(asset.ucs_classifier_version or "")
  asset.ucs_confidence = tonumber(asset.ucs_confidence) or 0
  asset.ucs_candidates = tostring(asset.ucs_candidates or "")
  asset.ucs_evidence = tostring(asset.ucs_evidence or "")
  if asset.fingerprint ~= ""
    and not fingerprint_metadata_is_compatible(asset) then
    clear_asset_fingerprint(asset)
    mark_database_snapshot_dirty()
  end
  asset.last_seen = tonumber(asset.last_seen) or 0
  ensure_asset_identity(asset, false)
  return asset
end

function database_asset_values(asset)
  local values = {}
  for _, field in ipairs(DB_FIELDS) do
    local value = asset and asset[field] or ""
    if field == "indexed" then
      value = asset and asset.indexed and "1" or "0"
    elseif field == "ready" then
      value = asset and asset.ready and "1" or "0"
    elseif field == "marked" then
      value = asset and asset.marked and "1" or "0"
    end
    values[#values + 1] = value
  end
  return values
end

function mark_asset_database_change(asset)
  if not asset or not asset.path or asset.path == "" then
    return false
  end
  if state.root_removal_session then
    local pending = state.root_removal_session.concurrent_asset_changes
    if not pending then
      pending = {}
      state.root_removal_session.concurrent_asset_changes = pending
    end
    pending[path_key(asset.path)] = asset
    return true
  end
  state.db_dirty = true
  return record_asset_change(
    state.database_changes,
    path_key(asset.path),
    "upsert",
    database_asset_values(asset)
  )
end

function mark_asset_database_delete(asset_or_path)
  local path = type(asset_or_path) == "table"
    and asset_or_path.path or asset_or_path
  path = tostring(path or "")
  if path == "" then return false end
  if remove_ucs_confirmation_undo then
    remove_ucs_confirmation_undo(path_key(path))
  end
  remove_ucs_pending_membership(path)
  local values = database_asset_values(nil)
  for index, field in ipairs(DB_FIELDS) do
    if field == "path" then
      values[index] = path
      break
    end
  end
  state.db_dirty = true
  return record_asset_change(
    state.database_changes,
    path_key(path),
    "delete",
    values
  )
end

function mark_database_snapshot_dirty()
  state.db_dirty = true
  return require_asset_snapshot(state.database_changes)
end

function save_database_journal()
  ensure_dirs()
  local entries = ordered_asset_changes(state.database_changes)
  if #entries == 0 then return start_database_snapshot() end
  local written, write_error = write_asset_journal_atomic(
    DATABASE_JOURNAL_FILE,
    state.database_generation or 0,
    DB_FIELDS,
    entries,
    atomic_file_writer
  )
  if not written then
    set_status(
      "无法保存素材增量日志：" .. tostring(write_error),
      true
    )
    return false
  end
  state.db_dirty = false
  if state.clear_scan_checkpoint_after_database_save then
    clear_scan_checkpoint()
    AppState.set("clear_scan_checkpoint_after_database_save", false)
  end
  return true
end

function save_database_changes()
  local changes = state.database_changes
  if asset_changes_require_snapshot(
    changes,
    reaper.file_exists(DATABASE_FILE),
    DATABASE_JOURNAL_COMPACT_COUNT
  ) then
    return start_database_snapshot()
  end
  return save_database_journal()
end

function replace_database_asset(asset, probe_file)
  local key = path_key(asset.path)
  local existing = state.by_path[key]
  if not existing then
    add_or_update_asset(asset, probe_file)
    return
  end
  for _, field in ipairs(DB_FIELDS) do
    existing[field] = asset[field]
  end
  existing.artwork_checked = tostring(existing.artwork_path or "") ~= ""
  existing._search_blob = nil
  existing._sort_path_value = nil
  refresh_ucs_pending_membership(existing)
end

function replay_database_journal(asset_positions)
  local probe = io.open(DATABASE_JOURNAL_FILE, "rb")
  if not probe then return true end
  probe:close()

  local entries, journal_error = read_asset_journal(
    DATABASE_JOURNAL_FILE,
    state.database_generation or 0,
    DB_FIELDS
  )
  if not entries then
    if journal_error == "generation_mismatch" then
      os.remove(DATABASE_JOURNAL_FILE)
      return true
    end
    state.persistence_read_only = true
    state.persistence_read_only_reason =
      "素材增量日志无法安全重放：" .. tostring(journal_error)
    set_status("素材增量日志损坏，已进入只读保护", true)
    return false
  end

  local path_field = nil
  for index, field in ipairs(DB_FIELDS) do
    if field == "path" then path_field = index break end
  end
  if not path_field then return false end

  local actions = {}
  for _, entry in ipairs(entries) do
    local path = tostring(entry.values[path_field] or "")
    if path == "" or is_ignored_media_path(path) then
      state.persistence_read_only = true
      state.persistence_read_only_reason =
        "素材增量日志包含无效路径"
      set_status("素材增量日志损坏，已进入只读保护", true)
      return false
    end
    local action = {
      op = entry.op,
      key = path_key(path),
      values = entry.values,
    }
    if entry.op == "upsert" then
      action.asset = database_asset_from_values(DB_FIELDS, entry.values)
      if not action.asset then
        state.persistence_read_only = true
        state.persistence_read_only_reason =
          "素材增量日志包含无效素材"
        set_status("素材增量日志损坏，已进入只读保护", true)
        return false
      end
    end
    actions[#actions + 1] = action
  end

  for _, action in ipairs(actions) do
    local key = action.key
    if action.op == "delete" then
      remove_ucs_pending_membership(key)
      if asset_positions then
        remove_indexed_array_entry(
          state.assets,
          asset_positions,
          key,
          function(asset) return path_key(asset.path) end
        )
      end
      state.by_path[key] = nil
      state.favorites[key] = nil
      state.selected_set[key] = nil
    else
      local existed = state.by_path[key] ~= nil
      replace_database_asset(action.asset, false)
      if asset_positions and not existed then
        asset_positions[key] = #state.assets
      end
    end
    record_asset_change(
      state.database_changes,
      action.key,
      action.op,
      action.op == "upsert"
        and database_asset_values(action.asset)
        or action.values
    )
  end
  if #actions > 0 then
    -- `asset_positions` is built while the snapshot is already being read,
    -- so journal deletes do not require a second full catalog rebuild.
    if not asset_positions then
      rebuild_assets()
    end
    if (state.database_changes.count or 0)
      >= DATABASE_JOURNAL_COMPACT_COUNT then
      state.db_dirty = true
    end
  end
  return true
end

function write_database_asset_line(file, asset)
  local fields = database_asset_values(asset)
  for index, value in ipairs(fields) do
    fields[index] = escape_tsv(value)
  end
  return file:write(table.concat(fields, "\t"), "\n")
end

function save_database_now()
  ensure_dirs()

  local file = atomic_file_writer(DATABASE_FILE)

  if not file then
    set_status("无法保存索引", true)
    return
  end

  local next_generation =
    math.floor(tonumber(state.database_generation) or 0) + 1
  file:write(
    persistence_schema_header(
      "database",
      PERSISTENCE_SCHEMAS[DATABASE_FILE].version,
      next_generation
    )
  )
  file:write(table.concat(DB_FIELDS, "\t"), "\n")

  -- Catalog order has no persistence semantics; result views perform their
  -- own deterministic sort. Avoid a second 500k-entry array and O(n log n)
  -- sort in the rare synchronous durability fallback.
  for _, asset in ipairs(state.assets) do
    if not write_database_asset_line(file, asset) then
      file:close()
      set_status("无法保存索引", true)
      return false
    end
  end

  if not file:close() then
    set_status("无法保存索引", true)
    return false
  end
  state.database_generation = next_generation
  clear_asset_changes(state.database_changes)
  os.remove(DATABASE_JOURNAL_FILE)
  if state.clear_scan_checkpoint_after_database_save then
    clear_scan_checkpoint()
    state.clear_scan_checkpoint_after_database_save = false
  end
  state.db_dirty = false
  return true
end

function restore_database_snapshot_changes(session)
  if not session then return end
  local captured = session.captured_changes or new_asset_change_set()
  merge_asset_changes(captured, state.database_changes)
  require_asset_snapshot(captured)
  state.database_changes = captured
  state.db_dirty = true
end

function cancel_database_snapshot(reason)
  local session = state.database_snapshot_session
  if not session then return false end
  if session.writer and session.writer.abort then
    session.writer:abort()
  end
  restore_database_snapshot_changes(session)
  state.database_snapshot_session = nil
  Jobs.cancel(session.job_token)
  Jobs.finish(session.job_token, true, reason or "canceled")
  return true
end

function start_database_snapshot()
  if state.database_snapshot_session then return true end
  if state.persistence_read_only then return false end

  ensure_dirs()
  local job_token, job_error = Jobs.begin(
    "database_snapshot",
    "catalog_exclusive",
    false
  )
  if not job_token then
    if job_error ~= "resource_busy" then
      set_status("无法启动索引保存任务", true)
    end
    return false
  end

  local file, open_error = atomic_file_writer(DATABASE_FILE)
  if not file then
    Jobs.finish(job_token, false, open_error)
    set_status("无法保存索引：" .. tostring(open_error or "无法创建临时文件"), true)
    return false
  end

  local next_generation =
    math.floor(tonumber(state.database_generation) or 0) + 1
  local header_ok = file:write(
    persistence_schema_header(
      "database",
      PERSISTENCE_SCHEMAS[DATABASE_FILE].version,
      next_generation
    )
  )
  if header_ok then
    header_ok = file:write(table.concat(DB_FIELDS, "\t"), "\n")
  end
  if not header_ok then
    file:abort()
    Jobs.finish(job_token, false, "header write failed")
    set_status("无法保存索引", true)
    return false
  end

  local captured_changes = state.database_changes
  state.database_changes = new_asset_change_set()
  local assets = state.database_ordered_assets or state.assets
  state.database_snapshot_session = {
    writer = file,
    assets = assets,
    total = #assets,
    index = 1,
    next_generation = next_generation,
    captured_changes = captured_changes,
    job_token = job_token,
    started = reaper.time_precise(),
    last_status = 0,
  }
  state.db_dirty = true
  set_status(string.format("正在后台保存索引：0 / %d", #assets))
  return true
end

function fail_database_snapshot(session, message)
  if session.writer and session.writer.abort then
    session.writer:abort()
  end
  restore_database_snapshot_changes(session)
  state.database_snapshot_session = nil
  Jobs.finish(session.job_token, false, message)
  set_status("无法保存索引：" .. tostring(message or "写入失败"), true)
end

function process_database_snapshot()
  local session = state.database_snapshot_session
  if not session then return end
  if session.job_token.cancel_requested then
    cancel_database_snapshot("canceled")
    return
  end

  local deadline = reaper.time_precise()
    + DATABASE_SNAPSHOT_FRAME_BUDGET
  local last = math.min(
    session.total,
    session.index + DATABASE_SNAPSHOT_ASSETS_PER_FRAME - 1
  )
  while session.index <= last do
    local asset = session.assets[session.index]
    if asset and not write_database_asset_line(session.writer, asset) then
      fail_database_snapshot(session, "写入素材记录失败")
      return
    end
    session.index = session.index + 1
    if reaper.time_precise() >= deadline then break end
  end

  local now = reaper.time_precise()
  if now - session.last_status >= 0.5 then
    session.last_status = now
    set_status(string.format(
      "正在后台保存索引：%d / %d",
      math.min(session.index - 1, session.total),
      session.total
    ))
  end
  if session.index <= session.total then return end

  local closed, close_error = session.writer:close()
  if not closed then
    fail_database_snapshot(session, close_error or "提交临时文件失败")
    return
  end

  state.database_generation = session.next_generation
  os.remove(DATABASE_JOURNAL_FILE)
  if state.clear_scan_checkpoint_after_database_save then
    clear_scan_checkpoint()
    state.clear_scan_checkpoint_after_database_save = false
  end
  state.database_snapshot_session = nil
  state.db_dirty = (state.database_changes.count or 0) > 0
    or state.database_changes.requires_snapshot == true
  Jobs.finish(session.job_token, true)
  set_status(string.format(
    "索引已后台保存：%d 条，耗时 %.1f 秒",
    session.total,
    now - session.started
  ))
end

function save_database()
  if state.database_snapshot_session then
    cancel_database_snapshot("synchronous save requested")
  end
  local changes = state.database_changes
  if (changes.count or 0) > 0
    and not asset_changes_require_snapshot(
      changes,
      reaper.file_exists(DATABASE_FILE),
      DATABASE_JOURNAL_COMPACT_COUNT
    ) then
    return save_database_journal()
  end
  return save_database_now()
end


----------------------------------------------------------------
-- Collections, project bins and saved searches (0.5)
----------------------------------------------------------------

function new_model_id(prefix, seed)
  return prefix
    .. "_"
    .. fnv1a(
      tostring(seed or "")
        .. "|"
        .. tostring(reaper.time_precise())
        .. "|"
        .. tostring(os.time())
        .. "|"
        .. tostring(math.random())
    )
end

function rebuild_collection_index()
  state.collection_by_id = {}

  for _, collection in ipairs(state.collections) do
    collection.items = collection.items or {}
    collection.order = collection.order or {}

    if collection.count == nil then
      local count = 0

      for _ in pairs(collection.items) do
        count = count + 1
      end

      collection.count = count
    end

    state.collection_by_id[collection.id] = collection
  end

  if state.active_collection_id
    and not state.collection_by_id[
      state.active_collection_id
    ] then
    state.active_collection_id = nil
  end
end

function collection_item_count(collection)
  return collection
    and tonumber(collection.count)
    or 0
end

function current_project_identity()
  local ok, project, filename = pcall(reaper.EnumProjects, -1, "")

  if not ok then
    return PROJ, "", "", "未保存工程"
  end

  filename = normalize_slashes(trim(filename or ""))
  local key = filename ~= "" and path_key(filename) or ""
  local name = filename ~= ""
    and strip_extension(basename(filename))
    or "未保存工程"

  return project or PROJ, filename, key, name
end

function refresh_current_project_binding()
  local _, path, key, name = current_project_identity()
  state.current_project_path = path
  state.current_project_key = key
  state.current_project_name = name
  state.current_project_bin_id = nil

  if key == "" then
    return nil
  end

  for _, collection in ipairs(state.collections or {}) do
    if collection.kind == "project"
      and path_key(collection.project_path or "") == key then
      state.current_project_bin_id = collection.id
      return collection
    end
  end

  return nil
end

function poll_current_project_binding()
  local now = reaper.time_precise()

  if now < (state.next_project_refresh or 0) then
    return
  end

  state.next_project_refresh = now + 1.0
  local previous_key = state.current_project_key
  refresh_current_project_binding()

  if previous_key ~= state.current_project_key
    and state.view == "project_used" then
    state.results_dirty = true
  end
end

function project_usage_bucket(project_path, create)
  local project_key = path_key(project_path or "")

  if project_key == "" then
    return nil
  end

  local bucket = state.project_usage[project_key]

  if not bucket and create then
    bucket = {
      path = normalize_slashes(project_path),
      assets = {},
    }
    state.project_usage[project_key] = bucket
  end

  return bucket
end

function load_project_usage()
  state.project_usage = {}
  local file = io.open(PROJECT_USAGE_FILE, "rb")

  if not file then
    return
  end

  for line in file:lines() do
    local fields = split_tsv(line)

    if fields[1] == "usage"
      and fields[2] and fields[2] ~= ""
      and fields[3] and fields[3] ~= "" then
      local bucket = project_usage_bucket(fields[2], true)
      local asset_path = normalize_slashes(fields[3])
      bucket.assets[path_key(asset_path)] = {
        path = asset_path,
        count = tonumber(fields[4]) or 1,
        last_used = tonumber(fields[5]) or 0,
        action = fields[6] or "insert",
      }
    end
  end

  file:close()
  state.project_usage_dirty = false
end

function save_project_usage()
  if state.auxiliary_save_session
    and state.auxiliary_save_session.kind == "project_usage" then
    cancel_auxiliary_save("synchronous project usage save")
  end
  ensure_dirs()
  local file = atomic_file_writer(PROJECT_USAGE_FILE)

  if not file then
    set_status("无法保存工程使用记录", true)
    return false
  end

  write_persistence_schema(file, PROJECT_USAGE_FILE)

  local project_keys = {}
  for key in pairs(state.project_usage) do
    project_keys[#project_keys + 1] = key
  end
  table.sort(project_keys)

  for _, project_key in ipairs(project_keys) do
    local bucket = state.project_usage[project_key]
    local asset_keys = {}
    for key in pairs(bucket.assets or {}) do
      asset_keys[#asset_keys + 1] = key
    end
    table.sort(asset_keys)

    for _, asset_key in ipairs(asset_keys) do
      local entry = bucket.assets[asset_key]
      file:write(
        "usage\t",
        escape_tsv(bucket.path or ""), "\t",
        escape_tsv(entry.path or ""), "\t",
        tostring(entry.count or 1), "\t",
        tostring(entry.last_used or 0), "\t",
        escape_tsv(entry.action or "insert"), "\n"
      )
    end
  end

  if not file:close() then
    set_status("无法保存工程使用记录", true)
    return false
  end

  state.project_usage_dirty = false
  return true
end

function apply_project_usage_record(
  project_path,
  asset_path,
  action,
  used_at
)
  local bucket = project_usage_bucket(project_path, true)
  if not bucket then return false end
  local asset_key = path_key(asset_path)
  local entry = bucket.assets[asset_key]
  if not entry then
    entry = {
      path = asset_path,
      count = 0,
      last_used = 0,
      action = action or "insert",
    }
    bucket.assets[asset_key] = entry
  end
  entry.path = asset_path
  entry.count = (tonumber(entry.count) or 0) + 1
  entry.last_used = used_at or os.time()
  entry.action = action or "insert"
  state.project_usage_dirty = true
  return true
end

function bind_project_bin(collection, project_path)
  if state.root_removal_session then
    set_status("请等待来源移除完成后再修改项目素材箱", true)
    return false
  end
  if not collection or collection.kind ~= "project" then
    return false
  end

  project_path = normalize_slashes(trim(project_path or state.current_project_path))

  if project_path == "" then
    set_status("请先保存当前 REAPER 工程，再绑定项目素材箱", true)
    return false
  end

  collection.project_path = project_path
  state.collections_dirty = true
  refresh_current_project_binding()
  set_status("已将项目素材箱绑定到：" .. basename(project_path))
  return true
end

function ensure_current_project_bin(create_if_missing)
  local collection = refresh_current_project_binding()

  if collection or not create_if_missing then
    return collection
  end

  if state.current_project_key == "" then
    return nil
  end

  collection = {
    id = new_model_id("collection", state.current_project_path),
    name = state.current_project_name,
    kind = "project",
    project_path = state.current_project_path,
    items = {},
    order = {},
    count = 0,
  }
  state.collections[#state.collections + 1] = collection
  state.collection_by_id[collection.id] = collection
  state.current_project_bin_id = collection.id
  state.collections_dirty = true
  return collection
end

function record_project_usage(asset, action)
  if not asset or state.root_removal_session then
    return
  end

  refresh_current_project_binding()

  if state.current_project_key == "" then
    return
  end

  local asset_key = path_key(asset.path)
  local save_session = state.auxiliary_save_session
  if save_session and save_session.kind == "project_usage" then
    save_session.pending_usage[#save_session.pending_usage + 1] = {
      project_path = state.current_project_path,
      asset_path = asset.path,
      action = action or "insert",
      used_at = os.time(),
    }
  else
    apply_project_usage_record(
      state.current_project_path,
      asset.path,
      action,
      os.time()
    )
  end

  if state.auto_collect_project_usage then
    local collection = ensure_current_project_bin(true)
    if collection and not collection.items[asset_key] then
      collection.items[asset_key] = asset.path
      collection.order[#collection.order + 1] = asset.path
      collection.count = (collection.count or 0) + 1
      state.collections_dirty = true
    end
  end

  if state.view == "project_used" then
    state.results_dirty = true
  end
end


function load_collections()
  state.collections = {}
  state.collection_by_id = {}

  local file = io.open(COLLECTIONS_FILE, "rb")

  if not file then
    return
  end

  for line in file:lines() do
    local fields = split_tsv(line)
    local kind = fields[1]

    if kind == "collection"
      and fields[2]
      and fields[3] then

      local collection = {
        id = fields[2],
        name = fields[3],
        kind =
          fields[4] == "project"
          and "project"
          or "playlist",
        project_path = normalize_slashes(fields[5] or ""),
        items = {},
        order = {},
        count = 0,
      }

      state.collections[#state.collections + 1] =
        collection

      state.collection_by_id[collection.id] =
        collection
    elseif kind == "item"
      and fields[2]
      and fields[3] then

      local collection =
        state.collection_by_id[fields[2]]

      if collection then
        local path = normalize_slashes(fields[3])
        local key = path_key(path)

        if not collection.items[key] then
          collection.items[key] = path
          collection.order[#collection.order + 1] =
            path
          collection.count =
            (collection.count or 0) + 1
        end
      end
    end
  end

  file:close()
  rebuild_collection_index()
end

function save_collections()
  if state.auxiliary_save_session
    and state.auxiliary_save_session.kind == "collections" then
    cancel_auxiliary_save("synchronous collection save")
  end
  ensure_dirs()

  local file = atomic_file_writer(COLLECTIONS_FILE)

  if not file then
    set_status("无法保存播放列表", true)
    return
  end

  write_persistence_schema(file, COLLECTIONS_FILE)

  for _, collection in ipairs(state.collections) do
    file:write(
      "collection\t",
      escape_tsv(collection.id),
      "\t",
      escape_tsv(collection.name),
      "\t",
      escape_tsv(collection.kind or "playlist"),
      "\t",
      escape_tsv(collection.project_path or ""),
      "\n"
    )

    for _, path in ipairs(collection.order or {}) do
      if collection.items[path_key(path)] then
        file:write(
          "item\t",
          escape_tsv(collection.id),
          "\t",
          escape_tsv(path),
          "\n"
        )
      end
    end
  end

  if not file:close() then
    set_status("无法保存播放列表", true)
    return false
  end
  state.collections_dirty = false
  return true
end

function replay_pending_project_usage(session)
  for _, pending in ipairs(session and session.pending_usage or {}) do
    apply_project_usage_record(
      pending.project_path,
      pending.asset_path,
      pending.action,
      pending.used_at
    )
  end
  if session then session.pending_usage = {} end
end

function replay_pending_history(session)
  for id, asset in pairs(session and session.pending_history or {}) do
    state.preview_history_assets[id] = asset
  end
  if session then session.pending_history = {} end
end

function replay_pending_session_played(session)
  for key in pairs(session and session.pending_played or {}) do
    state.session_played[key] = true
  end
  if session then session.pending_played = {} end
end

function auxiliary_save_label(kind)
  if kind == "collections" then return "播放列表" end
  if kind == "project_usage" then return "工程使用记录" end
  if kind == "history" then return "试听历史" end
  if kind == "session_played" then return "本次试听高亮" end
  if kind == "regions" then return "Region 数据" end
  if kind == "loudness" then return "响度缓存" end
  if kind == "failed_tasks" then return "失败任务" end
  return "辅助数据"
end

function cancel_auxiliary_save(reason)
  local session = state.auxiliary_save_session
  if not session then return false end
  if session.writer and session.writer.abort then
    session.writer:abort()
  end
  AppState.set("auxiliary_save_session", nil)
  if session.kind == "collections" then
    state.collections_dirty = true
  elseif session.kind == "project_usage" then
    state.project_usage_dirty = true
    replay_pending_project_usage(session)
  elseif session.kind == "history" then
    state.history_dirty = true
    replay_pending_history(session)
  elseif session.kind == "session_played" then
    state.session_played_dirty = true
    replay_pending_session_played(session)
  elseif session.kind == "regions" then
    AppState.mark_dirty("regions_dirty")
  elseif session.kind == "loudness" then
    AppState.mark_dirty("loudness_dirty")
  elseif session.kind == "failed_tasks" then
    AppState.mark_dirty("failed_tasks_dirty")
  end
  return true
end

function fail_auxiliary_save(session, message)
  if state.auxiliary_save_session ~= session then return end
  cancel_auxiliary_save("write failed")
  set_status(
    "无法后台保存" .. auxiliary_save_label(session.kind)
      .. "：" .. tostring(message or "写入失败"),
    true
  )
end

function start_collections_save()
  if state.auxiliary_save_session or not state.collections_dirty then
    return false
  end
  ensure_dirs()
  local writer, open_error = atomic_file_writer(COLLECTIONS_FILE)
  if not writer then
    set_status("无法后台保存播放列表：" .. tostring(open_error or "无法创建临时文件"), true)
    return false
  end
  if not write_persistence_schema(writer, COLLECTIONS_FILE) then
    writer:abort()
    set_status("无法后台保存播放列表：无法写入文件头", true)
    return false
  end

  state.collections_dirty = false
  state.auxiliary_save_session = {
    kind = "collections",
    writer = writer,
    job = new_collections_persistence_job(state.collections),
    started = reaper.time_precise(),
  }
  return true
end

function start_project_usage_save()
  if state.auxiliary_save_session or not state.project_usage_dirty then
    return false
  end
  ensure_dirs()
  local writer, open_error = atomic_file_writer(PROJECT_USAGE_FILE)
  if not writer then
    set_status("无法后台保存工程使用记录：" .. tostring(open_error or "无法创建临时文件"), true)
    return false
  end
  if not write_persistence_schema(writer, PROJECT_USAGE_FILE) then
    writer:abort()
    set_status("无法后台保存工程使用记录：无法写入文件头", true)
    return false
  end

  state.project_usage_dirty = false
  state.auxiliary_save_session = {
    kind = "project_usage",
    writer = writer,
    job = new_project_usage_persistence_job(state.project_usage),
    pending_usage = {},
    started = reaper.time_precise(),
  }
  return true
end

function start_catalog_auxiliary_save(kind, path, dirty_flag, job)
  if state.auxiliary_save_session or not state[dirty_flag] then
    return false
  end
  ensure_dirs()
  local writer, open_error = atomic_file_writer(path)
  if not writer then
    set_status(
      "无法后台保存" .. auxiliary_save_label(kind) .. "："
        .. tostring(open_error or "无法创建临时文件"),
      true
    )
    return false
  end
  if not write_persistence_schema(writer, path) then
    writer:abort()
    set_status(
      "无法后台保存" .. auxiliary_save_label(kind) .. "：无法写入文件头",
      true
    )
    return false
  end
  AppState.set(dirty_flag, false)
  AppState.set("auxiliary_save_session", {
    kind = kind,
    writer = writer,
    job = job,
    started = reaper.time_precise(),
  })
  return true
end

function start_regions_save()
  return start_catalog_auxiliary_save(
    "regions",
    REGIONS_FILE,
    "regions_dirty",
    new_regions_persistence_job(state.regions_by_path)
  )
end

function start_loudness_save()
  return start_catalog_auxiliary_save(
    "loudness",
    LOUDNESS_FILE,
    "loudness_dirty",
    new_loudness_persistence_job(state.loudness_cache)
  )
end

function start_failed_tasks_save()
  return start_catalog_auxiliary_save(
    "failed_tasks",
    FAILED_TASKS_FILE,
    "failed_tasks_dirty",
    new_failed_tasks_persistence_job(state.failed_tasks)
  )
end

function finish_auxiliary_save(session)
  local closed, close_error = session.writer:close()
  if not closed then
    fail_auxiliary_save(session, close_error or "提交临时文件失败")
    return false
  end
  state.auxiliary_save_session = nil
  if session.kind == "project_usage" then
    replay_pending_project_usage(session)
  elseif session.kind == "history" then
    replay_pending_history(session)
  elseif session.kind == "session_played" then
    state.last_session_played = session.job.saved
    replay_pending_session_played(session)
  end
  if state.collections_dirty or state.history_dirty
    or state.session_played_dirty or state.project_usage_dirty
    or state.regions_dirty or state.loudness_dirty
    or state.failed_tasks_dirty then
    state.last_save = 0
  end
  return true
end

function process_collections_save(session, deadline)
  local complete, failure = step_collections_persistence_job(
    session.job,
    session.writer,
    AUXILIARY_SAVE_RECORDS_PER_FRAME,
    escape_tsv,
    path_key,
    deadline,
    reaper.time_precise
  )
  if failure then
    fail_auxiliary_save(session, failure)
    return false
  end
  return complete
end

function process_project_usage_save(session, deadline)
  local complete, failure = step_project_usage_persistence_job(
    session.job,
    session.writer,
    AUXILIARY_SAVE_RECORDS_PER_FRAME,
    escape_tsv,
    deadline,
    reaper.time_precise
  )
  if failure then
    fail_auxiliary_save(session, failure)
    return false
  end
  return complete
end

function process_auxiliary_save()
  local session = state.auxiliary_save_session
  if not session then return end
  local deadline = reaper.time_precise() + AUXILIARY_SAVE_FRAME_BUDGET
  local complete, failure
  if session.kind == "collections" then
    complete = process_collections_save(session, deadline)
  elseif session.kind == "project_usage" then
    complete = process_project_usage_save(session, deadline)
  elseif session.kind == "history" then
    complete, failure = step_history_persistence_job(
      session.job,
      session.writer,
      AUXILIARY_SAVE_RECORDS_PER_FRAME,
      escape_tsv,
      path_key,
      deadline,
      reaper.time_precise
    )
  elseif session.kind == "session_played" then
    complete, failure = step_path_set_persistence_job(
      session.job,
      session.writer,
      AUXILIARY_SAVE_RECORDS_PER_FRAME,
      escape_tsv,
      deadline,
      reaper.time_precise
    )
  elseif session.kind == "regions" then
    complete, failure = step_regions_persistence_job(
      session.job,
      session.writer,
      AUXILIARY_SAVE_RECORDS_PER_FRAME,
      escape_tsv,
      deadline,
      reaper.time_precise
    )
  elseif session.kind == "loudness" then
    complete, failure = step_loudness_persistence_job(
      session.job,
      session.writer,
      AUXILIARY_SAVE_RECORDS_PER_FRAME,
      escape_tsv,
      deadline,
      reaper.time_precise
    )
  elseif session.kind == "failed_tasks" then
    complete, failure = step_failed_tasks_persistence_job(
      session.job,
      session.writer,
      AUXILIARY_SAVE_RECORDS_PER_FRAME,
      escape_tsv,
      deadline,
      reaper.time_precise
    )
  else
    fail_auxiliary_save(session, "未知保存任务")
    return
  end
  if failure then
    fail_auxiliary_save(session, failure)
    return
  end
  if complete and state.auxiliary_save_session == session then
    finish_auxiliary_save(session)
  end
end

function create_collection(kind)
  if state.root_removal_session then
    set_status("请等待来源移除完成后再新建集合", true)
    return nil
  end
  kind =
    kind == "project"
    and "project"
    or "playlist"

  local title =
    kind == "project"
    and "新建项目素材箱"
    or "新建播放列表"

  local default_name =
    kind == "project"
    and "当前项目"
    or "新播放列表"

  local ok, name =
    reaper.GetUserInputs(
      title,
      1,
      "名称:",
      default_name
    )

  name = trim(name)

  if not ok or name == "" then
    return nil
  end

  local collection = {
    id = new_model_id("collection", name),
    name = name,
    kind = kind,
    project_path = "",
    items = {},
    order = {},
    count = 0,
  }

  if kind == "project" then
    local _, project_path = current_project_identity()
    collection.project_path = project_path or ""
  end

  state.collections[#state.collections + 1] =
    collection

  state.collection_by_id[collection.id] =
    collection

  -- 新建集合不再自动切换到空白集合视图。
  -- 保留当前搜索和音效库结果，避免用户误以为原始素材库消失。
  local current_selection = selected_assets()
  local added = 0

  if #current_selection > 0 then
    added = add_assets_to_collection(
      collection,
      current_selection
    )
  end

  state.collections_dirty = true
  state.config_dirty = true
  refresh_current_project_binding()

  local type_label = translate_ui_text(
    kind == "project"
      and "项目素材箱"
      or "播放列表"
  )

  if added > 0 then
    set_status(
      string.format(
        "已新建%s“%s”，并加入 %d 个当前所选素材；可在左侧点击打开",
        type_label,
        name,
        added
      )
    )
  else
    set_status(
      string.format(
        "已新建%s“%s”；当前列表保持不变，可在左侧点击打开",
        type_label,
        name
      )
    )
  end

  return collection
end

function rename_collection(collection)
  if not collection then
    return
  end

  local ok, name =
    reaper.GetUserInputs(
      "重命名集合",
      1,
      "名称:",
      collection.name
    )

  name = trim(name)

  if ok and name ~= "" then
    collection.name = name
    state.collections_dirty = true
    set_status("已重命名为：" .. name)
  end
end

function delete_collection(collection)
  if state.root_removal_session then
    set_status("请等待来源移除完成后再删除集合", true)
    return
  end
  if not collection then
    return
  end

  local answer =
    reaper.MB(
      "删除 PsyReaSFX 集合？\n\n"
        .. collection.name
        .. "\n\n不会删除磁盘音频文件。",
      SCRIPT_NAME,
      4
    )

  if answer ~= 6 then
    return
  end

  local kept = {}

  for _, current in ipairs(state.collections) do
    if current.id ~= collection.id then
      kept[#kept + 1] = current
    end
  end

  state.collections = kept
  state.collection_by_id[collection.id] = nil

  if state.active_collection_id
    == collection.id then
    state.active_collection_id = nil
    state.results_dirty = true
  end

  state.collections_dirty = true
  state.config_dirty = true
  set_status("已删除集合：" .. collection.name)
end

function add_assets_to_collection(
  collection,
  assets
)
  if state.root_removal_session then
    set_status("请等待来源移除完成后再修改集合", true)
    return 0
  end
  if not collection or not assets then
    return 0
  end

  local added = 0

  for _, asset in ipairs(assets) do
    local key = path_key(asset.path)

    if not collection.items[key] then
      collection.items[key] = asset.path
      collection.order[#collection.order + 1] =
        asset.path
      collection.count =
        (collection.count or 0) + 1
      added = added + 1
    end
  end

  if added > 0 then
    state.collections_dirty = true

    if state.active_collection_id
      == collection.id then
      state.results_dirty = true
    end

    set_status(
      string.format(
        "已向“%s”加入 %d 个素材",
        collection.name,
        added
      )
    )
  end

  return added
end

function remove_assets_from_collection(
  collection,
  assets
)
  if state.root_removal_session then
    set_status("请等待来源移除完成后再修改集合", true)
    return 0
  end
  if not collection or not assets then
    return 0
  end

  local removed = 0

  for _, asset in ipairs(assets) do
    local key = path_key(asset.path)

    if collection.items[key] then
      collection.items[key] = nil
      collection.count =
        math.max(
          0,
          (collection.count or 0) - 1
        )
      removed = removed + 1
    end
  end

  if removed > 0 then
    local order = {}

    for _, path in ipairs(collection.order) do
      if collection.items[path_key(path)] then
        order[#order + 1] = path
      end
    end

    collection.order = order
    state.collections_dirty = true
    state.results_dirty = true

    set_status(
      string.format(
        "已从“%s”移除 %d 个素材",
        collection.name,
        removed
      )
    )
  end

  return removed
end

function load_saved_searches()
  state.saved_searches = {}

  local file = io.open(SAVED_SEARCHES_FILE, "rb")

  if not file then
    return
  end

  for line in file:lines() do
    local fields = split_tsv(line)

    if fields[1] == "search"
      and fields[2]
      and fields[3] then

      state.saved_searches[
        #state.saved_searches + 1
      ] = {
        id = fields[2],
        name = fields[3],
        query = fields[4] or "",
        view = fields[5] or "all",
        root = fields[6] or "",
        sort_mode = fields[7] or "name",
        sort_desc = fields[8] == "1",
        status_filter =
          fields[9] ~= ""
          and fields[9]
          or nil,
        collection_id =
          fields[10] ~= ""
          and fields[10]
          or nil,
        library_id =
          fields[11] ~= ""
          and fields[11]
          or nil,
        ucs_category = fields[12] ~= "" and fields[12] or nil,
        ucs_subcategory = fields[13] ~= "" and fields[13] or nil,
        ucs_catid = fields[14] ~= "" and fields[14] or nil,
      }
    end
  end

  file:close()
end

function save_saved_searches()
  ensure_dirs()

  local file = atomic_file_writer(SAVED_SEARCHES_FILE)

  if not file then
    set_status("无法保存搜索条件", true)
    return
  end

  write_persistence_schema(file, SAVED_SEARCHES_FILE)

  for _, saved in ipairs(state.saved_searches) do
    file:write(
      "search\t",
      escape_tsv(saved.id),
      "\t",
      escape_tsv(saved.name),
      "\t",
      escape_tsv(saved.query or ""),
      "\t",
      escape_tsv(saved.view or "all"),
      "\t",
      escape_tsv(saved.root or ""),
      "\t",
      escape_tsv(saved.sort_mode or "name"),
      "\t",
      saved.sort_desc and "1" or "0",
      "\t",
      escape_tsv(saved.status_filter or ""),
      "\t",
      escape_tsv(saved.collection_id or ""),
      "\t",
      escape_tsv(saved.library_id or ""),
      "\t",
      escape_tsv(saved.ucs_category or ""),
      "\t",
      escape_tsv(saved.ucs_subcategory or ""),
      "\t",
      escape_tsv(saved.ucs_catid or ""),
      "\n"
    )
  end

  if not file:close() then
    set_status("无法保存搜索条件", true)
    return false
  end
  state.searches_dirty = false
  return true
end

function save_current_search()
  local ok, name =
    reaper.GetUserInputs(
      "保存当前搜索",
      1,
      "名称:",
      trim(state.search) ~= ""
        and compact(state.search, 30)
        or "新搜索"
    )

  name = trim(name)

  if not ok or name == "" then
    return
  end

  state.saved_searches[
    #state.saved_searches + 1
  ] = {
    id = new_model_id("search", name),
    name = name,
    query = state.search,
    view = state.view,
    root = state.root_filter or "",
    library_id = state.library_filter_id,
    sort_mode = state.sort_mode,
    sort_desc = state.sort_desc,
    status_filter = state.status_filter,
    collection_id = state.active_collection_id,
    ucs_category = ucs_directory_view(state.view)
        and state.ucs_filter_category or nil,
    ucs_subcategory = ucs_directory_view(state.view)
        and state.ucs_filter_subcategory or nil,
    ucs_catid = ucs_directory_view(state.view)
        and state.ucs_filter_catid or nil,
  }

  state.searches_dirty = true
  set_status("已保存搜索：" .. name)
end

function activate_saved_search(saved)
  if not saved then
    return
  end

  state.search = saved.query or ""
  local saved_view = saved.view or "all"
  if ucs_directory_view(saved_view) and not saved.ucs_category then
    saved_view = "all"
  end
  state.view = saved_view
  AppState.set("ucs_filter_category", saved.ucs_category)
  AppState.set("ucs_filter_subcategory", saved.ucs_subcategory)
  AppState.set("ucs_filter_catid", saved.ucs_catid)
  state.root_filter =
    saved.root ~= ""
    and saved.root
    or nil
  state.library_filter_id =
    saved.library_id
      and state.library_by_id[saved.library_id]
      and saved.library_id
      or nil
  state.sort_mode = saved.sort_mode or "name"
  state.sort_desc = saved.sort_desc == true
  state.status_filter = saved.status_filter

  if saved.collection_id
    and state.collection_by_id[
      saved.collection_id
    ] then
    state.active_collection_id =
      saved.collection_id
  else
    state.active_collection_id = nil
  end

  state.selected_set = {}
  state.selected_index = 0
  state.selected_path = nil
  state.selection_anchor = 0
  state.results_dirty = true
  set_status("已载入搜索：" .. saved.name)
end

function rename_saved_search(saved)
  if not saved then
    return
  end

  local ok, name =
    reaper.GetUserInputs(
      "重命名保存搜索",
      1,
      "名称:",
      saved.name
    )

  name = trim(name)

  if ok and name ~= "" then
    saved.name = name
    state.searches_dirty = true
  end
end

function delete_saved_search(saved)
  if not saved then
    return
  end

  local kept = {}

  for _, current in ipairs(state.saved_searches) do
    if current.id ~= saved.id then
      kept[#kept + 1] = current
    end
  end

  state.saved_searches = kept
  state.searches_dirty = true
  set_status("已删除保存搜索：" .. saved.name)
end

function load_history()
  local file = io.open(HISTORY_FILE, "rb")

  if not file then
    return
  end

  for line in file:lines() do
    local fields = split_tsv(line)

    if fields[1] == "preview"
      and fields[2] then

      local asset =
        state.by_path[path_key(fields[2])]

      if asset then
        asset.preview_count =
          tonumber(fields[3]) or 0
        asset.last_previewed =
          tonumber(fields[4]) or 0
        ensure_asset_identity(asset, false)
        state.preview_history_assets[asset.asset_id] = asset
      end
    end
  end

  file:close()
end

function save_history()
  if state.root_removal_session then return false end
  if state.auxiliary_save_session
    and state.auxiliary_save_session.kind == "history" then
    cancel_auxiliary_save("synchronous history save")
  end
  ensure_dirs()

  local file = atomic_file_writer(HISTORY_FILE)

  if not file then
    set_status("无法保存试听历史", true)
    return
  end

  write_persistence_schema(file, HISTORY_FILE)

  local history_assets = ordered_preview_history_assets(
    state.preview_history_assets,
    state.by_path,
    path_key,
    asset_path_sort_key
  )
  for _, asset in ipairs(history_assets) do
    file:write(
      "preview\t",
      escape_tsv(asset.path),
      "\t",
      tostring(asset.preview_count or 0),
      "\t",
      tostring(asset.last_previewed or 0),
      "\n"
    )
  end

  if not file:close() then
    set_status("无法保存试听历史", true)
    return false
  end
  state.history_dirty = false
  return true
end

function start_history_save()
  if state.auxiliary_save_session or not state.history_dirty then
    return false
  end
  ensure_dirs()
  local writer, open_error = atomic_file_writer(HISTORY_FILE)
  if not writer then
    set_status("无法后台保存试听历史：" .. tostring(open_error or "无法创建临时文件"), true)
    return false
  end
  if not write_persistence_schema(writer, HISTORY_FILE) then
    writer:abort()
    set_status("无法后台保存试听历史：无法写入文件头", true)
    return false
  end
  state.history_dirty = false
  state.auxiliary_save_session = {
    kind = "history",
    writer = writer,
    job = new_history_persistence_job(
      state.preview_history_assets,
      state.by_path
    ),
    pending_history = {},
    started = reaper.time_precise(),
  }
  return true
end

function start_session_played_save()
  if state.auxiliary_save_session or not state.session_played_dirty then
    return false
  end
  ensure_dirs()
  local writer, open_error = atomic_file_writer(LAST_PLAYED_SESSION_FILE)
  if not writer then
    set_status("无法后台保存本次试听高亮：" .. tostring(open_error or "无法创建临时文件"), true)
    return false
  end
  if not write_persistence_schema(writer, LAST_PLAYED_SESSION_FILE) then
    writer:abort()
    set_status("无法后台保存本次试听高亮：无法写入文件头", true)
    return false
  end
  state.session_played_dirty = false
  state.auxiliary_save_session = {
    kind = "session_played",
    writer = writer,
    job = new_path_set_persistence_job(state.session_played),
    pending_played = {},
    started = reaper.time_precise(),
  }
  return true
end

function schedule_auxiliary_save()
  if state.auxiliary_save_session then return false end
  if state.scan or state.import_session or state.root_removal_session
    or state.relink_plan_session then
    return false
  end
  if state.collections_dirty then return start_collections_save() end
  if state.history_dirty then return start_history_save() end
  if state.session_played_dirty then return start_session_played_save() end
  if state.project_usage_dirty then return start_project_usage_save() end
  if state.failed_tasks_dirty then return start_failed_tasks_save() end
  if state.regions_dirty then return start_regions_save() end
  if state.loudness_dirty then return start_loudness_save() end
  return false
end

function workflow_label(status)
  local definition =
    WORKFLOW_STATUS[status or "none"]
    or WORKFLOW_STATUS.none

  return definition.label
end

function set_workflow_status(
  assets,
  status
)
  status =
    WORKFLOW_STATUS[status]
    and status
    or "none"

  local count = 0

  for _, asset in ipairs(assets or {}) do
    if asset.workflow_status ~= status then
      asset.workflow_status = status
      mark_asset_database_change(asset)
      count = count + 1
    end
  end

  if count > 0 then
    state.results_dirty = true
    set_status(
      string.format(
        "已将 %d 个素材标记为“%s”",
        count,
        workflow_label(status)
      )
    )
  end
end

function record_preview_history(asset)
  if not asset then
    return
  end

  asset.preview_count =
    (tonumber(asset.preview_count) or 0) + 1
  asset.last_previewed = os.time()
  ensure_asset_identity(asset)
  local save_session = state.auxiliary_save_session
  if save_session and save_session.kind == "history"
    and not state.preview_history_assets[asset.asset_id] then
    save_session.pending_history[asset.asset_id] = asset
  else
    state.preview_history_assets[asset.asset_id] = asset
  end
  local played_key =
    path_key(asset.path)

  if not state.session_played[played_key] then
    if save_session and save_session.kind == "session_played" then
      save_session.pending_played[played_key] = true
    else
      state.session_played[played_key] = true
    end
    state.session_played_dirty = true
  end

  state.history_dirty = true

  if state.view == "previewed"
    or state.sort_mode == "previewed" then
    state.results_dirty = true
  end
end

----------------------------------------------------------------
-- Artwork discovery and image cache
----------------------------------------------------------------

local ARTWORK_NAME_PRIORITY = {
  ["artwork.jpg"] = 1,
  ["artwork.jpeg"] = 1,
  ["artwork.png"] = 1,
  ["cover.jpg"] = 2,
  ["cover.jpeg"] = 2,
  ["cover.png"] = 2,
  ["folder.jpg"] = 3,
  ["folder.jpeg"] = 3,
  ["folder.png"] = 3,
  ["front.jpg"] = 4,
  ["front.jpeg"] = 4,
  ["front.png"] = 4,
  ["album.jpg"] = 5,
  ["album.jpeg"] = 5,
  ["album.png"] = 5,
  ["thumbnail.jpg"] = 6,
  ["thumbnail.jpeg"] = 6,
  ["thumbnail.png"] = 6,
  ["library.jpg"] = 7,
  ["library.jpeg"] = 7,
  ["library.png"] = 7,
  ["product.jpg"] = 8,
  ["product.jpeg"] = 8,
  ["product.png"] = 8,
  ["preview.jpg"] = 9,
  ["preview.jpeg"] = 9,
  ["preview.png"] = 9,
}

local ARTWORK_SUBFOLDER_NAMES = {
  artwork = true,
  artworks = true,
  art = true,
  cover = true,
  covers = true,
  image = true,
  images = true,
  thumbnail = true,
  thumbnails = true,
  graphics = true,
  ["album art"] = true,
  ["product art"] = true,
  ["product artwork"] = true,
  ["product images"] = true,
  ["封面"] = true,
  ["图片"] = true,
  ["图像"] = true,
}

ARTWORK_DISCOVERY_VERSION = 3

function normalized_artwork_folder_name(name)
  local value = safe_lower(trim(name or ""))

  -- Commercial libraries commonly prefix deliverable folders with an
  -- ordering number: "1. Audio", "2. Artwork", "03_Covers", etc.
  value = value:gsub("^%d+%s*", "")
  value = value:gsub("^%p+%s*", "")
  value = value:gsub("[_%-%.]+", " ")
  value = value:gsub("%s+", " ")

  return trim(value)
end

function artwork_folder_priority(name)
  local label = normalized_artwork_folder_name(name)

  if ARTWORK_SUBFOLDER_NAMES[label] then
    return label == "artwork" and 1
      or label == "artworks" and 1
      or label == "art" and 2
      or label:find("cover", 1, true) and 3
      or label:find("image", 1, true) and 4
      or label:find("thumbnail", 1, true) and 5
      or 6
  end

  if label:find("artwork", 1, true)
    or label:find("封面", 1, true) then
    return 1
  elseif label:find("cover", 1, true) then
    return 3
  elseif label:find("product image", 1, true)
    or label:find("album art", 1, true)
    or label:find("图片", 1, true)
    or label:find("图像", 1, true) then
    return 4
  elseif label:find("thumbnail", 1, true) then
    return 5
  end

  return nil
end

function is_artwork_file(filename)
  local ext = extension(filename):lower()

  return ext == "jpg"
    or ext == "jpeg"
    or ext == "png"
    or ext == "bmp"
    or ext == "tga"
end

function image_u16_be(data, offset)
  local a, b = data:byte(offset, offset + 1)

  if not a or not b then
    return nil
  end

  return a * 256 + b
end

function image_u16_le(data, offset)
  local a, b = data:byte(offset, offset + 1)

  if not a or not b then
    return nil
  end

  return a + b * 256
end

function image_u32_be(data, offset)
  local a, b, c, d = data:byte(offset, offset + 3)

  if not a or not b or not c or not d then
    return nil
  end

  return ((a * 256 + b) * 256 + c) * 256 + d
end

function image_u32_le(data, offset)
  local a, b, c, d = data:byte(offset, offset + 3)

  if not a or not b or not c or not d then
    return nil
  end

  return a + b * 256 + c * 65536 + d * 16777216
end

function jpeg_dimensions(data)
  if data:sub(1, 2) ~= "\255\216" then
    return nil, nil
  end

  local position = 3
  local length = #data

  while position <= length - 8 do
    while position <= length
      and data:byte(position) ~= 0xFF do
      position = position + 1
    end

    while position <= length
      and data:byte(position) == 0xFF do
      position = position + 1
    end

    local marker = data:byte(position)

    if not marker then
      break
    end

    position = position + 1

    if marker == 0xD8
      or marker == 0xD9
      or marker == 0x01
      or (marker >= 0xD0 and marker <= 0xD7) then
      -- Standalone marker without a segment length.
    else
      local segment_length =
        image_u16_be(data, position)

      if not segment_length
        or segment_length < 2 then
        break
      end

      local is_size_marker =
        (marker >= 0xC0 and marker <= 0xC3)
        or (marker >= 0xC5 and marker <= 0xC7)
        or (marker >= 0xC9 and marker <= 0xCB)
        or (marker >= 0xCD and marker <= 0xCF)

      if is_size_marker then
        local height =
          image_u16_be(data, position + 3)
        local width =
          image_u16_be(data, position + 5)

        return width, height
      end

      position = position + segment_length
    end
  end

  return nil, nil
end

function artwork_image_dimensions(path)
  local key = path_key(path)
  local cached = state.artwork_dimension_cache[key]

  if cached ~= nil then
    return cached.width, cached.height
  end

  local width, height = nil, nil
  local file = io.open(path, "rb")

  if file then
    local data = file:read(262144) or ""
    file:close()

    if data:sub(1, 8) == "\137PNG\r\n\26\n" then
      width = image_u32_be(data, 17)
      height = image_u32_be(data, 21)
    elseif data:sub(1, 2) == "\255\216" then
      width, height = jpeg_dimensions(data)
    elseif data:sub(1, 2) == "BM" then
      width = image_u32_le(data, 19)
      height = image_u32_le(data, 23)
    elseif #data >= 18 then
      -- TGA stores dimensions in the fixed 18-byte header.
      width = image_u16_le(data, 13)
      height = image_u16_le(data, 15)
    end
  end

  if not width or not height
    or width <= 0 or height <= 0 then
    width, height = 0, 0
  end

  state.artwork_dimension_cache[key] = {
    width = width,
    height = height,
  }

  return width, height
end

function artwork_candidate_score(path, filename)
  local width, height =
    artwork_image_dimensions(path)
  local square_class = 3
  local square_delta = math.huge
  local area = 0

  if width > 0 and height > 0 then
    square_delta =
      math.abs(width - height)
        / math.max(width, height)
    square_class = square_delta <= 0.06 and 0
      or square_delta <= 0.18 and 1
      or 2
    area = width * height
  end

  return {
    path = path,
    filename = safe_lower(filename),
    square_class = square_class,
    square_delta = square_delta,
    name_priority =
      ARTWORK_NAME_PRIORITY[safe_lower(filename)]
        or 1000,
    area = area,
  }
end

function artwork_candidate_is_better(candidate, current)
  if not current then
    return true
  end

  if candidate.square_class ~= current.square_class then
    return candidate.square_class < current.square_class
  end

  if candidate.name_priority ~= current.name_priority then
    return candidate.name_priority < current.name_priority
  end

  if candidate.square_delta ~= current.square_delta then
    return candidate.square_delta < current.square_delta
  end

  if candidate.area ~= current.area then
    return candidate.area > current.area
  end

  return candidate.filename < current.filename
end

function find_artwork_in_folder(folder)
  local folder_key = path_key(folder)
  local cached = state.artwork_folder_cache[folder_key]

  if cached ~= nil then
    return cached == false and "" or cached
  end

  local best = nil
  local index = 0

  -- A bounded candidate set prevents a documentation folder with thousands
  -- of images from turning one low-priority Artwork job into a long stall.
  while index < 128 do
    local filename =
      reaper.EnumerateFiles(folder, index)

    if not filename then
      break
    end

    if is_artwork_file(filename) then
      local path = join_path(folder, filename)
      local candidate =
        artwork_candidate_score(path, filename)

      if artwork_candidate_is_better(candidate, best) then
        best = candidate
      end
    end

    index = index + 1
  end

  local result = best and best.path or ""

  state.artwork_folder_cache[folder_key] =
    result ~= "" and result or false

  return result
end

function find_artwork_in_tree(
  folder,
  maximum_depth,
  budget
)
  budget = budget or {
    remaining = 64,
    exhausted = false,
  }

  local cache_key =
    "tree:"
      .. tostring(maximum_depth or 0)
      .. ":"
      .. path_key(folder)
  local cached = state.artwork_folder_cache[cache_key]

  if cached ~= nil then
    return cached == false and "" or cached
  end

  local found = find_artwork_in_folder(folder)

  if found == "" and (maximum_depth or 0) > 0 then
    local index = 0
    while budget.remaining > 0 do
      local subdir =
        reaper.EnumerateSubdirectories(folder, index)

      if not subdir then
        break
      end

      index = index + 1
      budget.remaining = budget.remaining - 1
      found = find_artwork_in_tree(
        join_path(folder, subdir),
        maximum_depth - 1,
        budget
      )

      if found ~= "" then
        break
      end
    end

    if found == ""
      and budget.remaining <= 0 then
      budget.exhausted = true
    end
  end

  -- A positive result is always safe to cache. Do not turn an intentionally
  -- bounded partial walk into a permanent negative result.
  if found ~= "" or not budget.exhausted then
    state.artwork_folder_cache[cache_key] =
      found ~= "" and found or false
  end

  return found
end

function artwork_candidate_folders(parent, excluded_path)
  local candidates = {}
  local index = 0

  while index < 128 do
    local subdir =
      reaper.EnumerateSubdirectories(parent, index)

    if not subdir then
      break
    end

    index = index + 1

    local path = join_path(parent, subdir)
    local priority = artwork_folder_priority(subdir)

    if priority
      and (
        not excluded_path
        or path_key(path) ~= path_key(excluded_path)
      ) then
      candidates[#candidates + 1] = {
        path = path,
        name = subdir,
        priority = priority,
      }
    end
  end

  table.sort(candidates, function(a, b)
    if a.priority == b.priority then
      return safe_lower(a.name) < safe_lower(b.name)
    end

    return a.priority < b.priority
  end)

  return candidates
end

function find_library_artwork_in_root(root)
  if not root or root == "" then
    return ""
  end

  local found = find_artwork_in_folder(root)

  if found ~= "" then
    return found
  end

  local discovery_budget = {
    remaining = 64,
    exhausted = false,
  }

  -- First inspect recognized child folders inside the source. The normalized
  -- role matcher understands numbered layouts such as "2. Artwork".
  for _, candidate in ipairs(
    artwork_candidate_folders(root)
  ) do
    found = find_artwork_in_tree(
      candidate.path,
      2,
      discovery_budget
    )

    if found ~= "" then
      return found
    end
  end

  -- A frequent commercial-library layout keeps "1. Audio" and "2. Artwork"
  -- as siblings under the product folder. Search only artwork-like siblings
  -- of this source, never arbitrary siblings or another logical-library root.
  local parent = dirname(root)

  if parent ~= "" and parent ~= root then
    for _, candidate in ipairs(
      artwork_candidate_folders(parent, root)
    ) do
      found = find_artwork_in_tree(
        candidate.path,
        2,
        discovery_budget
      )

      if found ~= "" then
        return found
      end
    end
  end

  return ""
end

function valid_artwork_path(path)
  path = tostring(path or "")

  return path ~= ""
    and path ~= "-"
    and reaper.file_exists(path)
end

function root_record_for_asset(asset)
  if not asset then
    return nil
  end

  local record = state.root_by_id[
    tostring(asset.root_id or "")
  ]

  if not record and tostring(asset.root or "") ~= "" then
    record = root_record_for_path(asset.root)
  end

  if not record and asset.path then
    record = select(2, root_for_path(asset.path))
  end

  return record
end

function root_artwork_for_asset(asset)
  local record = root_record_for_asset(asset)

  if not record then
    return "", nil
  end

  local path = tostring(record.artwork_path or "")

  if valid_artwork_path(path) then
    return path, record
  end

  if path ~= "" and path ~= "-" then
    record.artwork_path = ""
    record.artwork_checked = false
    record.artwork_scan_version = 0
    state.libraries_dirty = true
  end

  return "", record
end

function remember_root_artwork(record, path)
  if not record or not valid_artwork_path(path) then
    return
  end

  path = normalize_slashes(path)

  if record.artwork_path ~= path then
    record.artwork_path = path
    state.libraries_dirty = true
  end

  record.artwork_checked = true
  record.artwork_scan_version =
    ARTWORK_DISCOVERY_VERSION
end

function invalidate_root_artwork_assets(record)
  if not record then return end
  -- Artwork queue eligibility also checks the source record's shared path and
  -- checked state. Changing that record therefore invalidates visible assets
  -- lazily without touching every catalog row here.
  state.results_dirty = true
end

function choose_artwork_for_root(record)
  if not record then
    return
  end

  local current = valid_artwork_path(record.artwork_path)
    and record.artwork_path
    or ""
  local ok, filename = reaper.GetUserFileNameForRead(
    current,
    translate_ui_text("选择来源路径封面"),
    "png,jpg,jpeg,bmp,tga"
  )

  if ok and filename and filename ~= "" then
    record.artwork_path = normalize_slashes(filename)
    record.artwork_checked = true
    record.artwork_scan_version =
      ARTWORK_DISCOVERY_VERSION
    state.libraries_dirty = true
    invalidate_root_artwork_assets(record)
    set_status(
      "已设置来源路径封面："
        .. (record.alias ~= "" and record.alias or basename(record.path))
    )
  end
end

function redetect_root_artwork(record)
  if not record then
    return
  end

  record.artwork_path = ""
  record.artwork_checked = false
  record.artwork_scan_version = 0
  state.artwork_folder_cache = {}
  state.artwork_dimension_cache = {}
  state.libraries_dirty = true
  invalidate_root_artwork_assets(record)
  set_status(
    "将重新查找来源路径封面："
      .. (record.alias ~= "" and record.alias or basename(record.path))
  )
end

function clear_root_artwork(record)
  if not record then
    return
  end

  record.artwork_path = "-"
  record.artwork_checked = true
  record.artwork_scan_version =
    ARTWORK_DISCOVERY_VERSION
  state.libraries_dirty = true
  invalidate_root_artwork_assets(record)
  set_status(
    "已清除来源路径封面："
      .. (record.alias ~= "" and record.alias or basename(record.path))
  )
end

function discover_artwork_path(asset)
  if not asset then
    return "", false
  end

  local shared_path, record =
    root_artwork_for_asset(asset)

  if shared_path ~= "" then
    return shared_path, true
  end

  local folder =
    asset.folder ~= ""
      and asset.folder
      or dirname(asset.path)

  local root = record and record.path
    or normalize_slashes(asset.root or "")
  local root_disabled = record
    and tostring(record.artwork_path or "") == "-"
  local depth = 0

  while folder and folder ~= "" and depth < 7 do
    local at_root = root ~= ""
      and path_key(folder) == path_key(root)
    local found = ""

    if not (at_root and root_disabled) then
      found = find_artwork_in_folder(folder)
    end

    if found ~= "" then
      if at_root then
        remember_root_artwork(record, found)
      end

      return found, at_root
    end

    if root ~= ""
      and path_key(folder) == path_key(root) then
      break
    end

    local parent = dirname(folder)

    if parent == folder or parent == "" then
      break
    end

    folder = parent
    depth = depth + 1
  end

  -- Deeply nested files may not reach their own source root within the
  -- per-file search limit. Check only that source root explicitly. Covers
  -- never cross from one source folder to another logical-library member.
  if root ~= ""
    and not root_disabled
    and (not record or not record.artwork_checked) then
    local found = find_library_artwork_in_root(root)

    if found ~= "" then
      remember_root_artwork(record, found)
      return found, true
    end
  end

  if record then
    record.artwork_checked = true
    record.artwork_scan_version =
      ARTWORK_DISCOVERY_VERSION
    state.libraries_dirty = true
  end

  return "", false
end

function queue_artwork(asset, priority)
  if not state.artwork_enabled
    or not asset then
    return
  end

  local current =
    tostring(asset.artwork_path or "")
  local shared, record =
    root_artwork_for_asset(asset)

  if current == "-"
    or valid_artwork_path(current)
    or shared ~= ""
    or (
      current == ""
      and asset.artwork_checked == true
      and (not record or record.artwork_checked)
    ) then
    return
  end

  local key = path_key(asset.path)

  if state.artwork_queued[key] then
    return
  end

  state.artwork_queued[key] = true

  local job = {
    key = key,
    asset = asset,
  }

  if priority then
    table.insert(state.artwork_queue, 1, job)
  else
    state.artwork_queue[#state.artwork_queue + 1] = job
  end
end

function process_artwork_queue()
  if #state.artwork_queue == 0
    or state.scan
    or state.import_session
    or not can_run_heavy_job() then
    return
  end

  local now = reaper.time_precise()

  if now < state.artwork_next_job then
    return
  end

  local job = table.remove(state.artwork_queue, 1)

  if not job then
    return
  end

  local job_token =
    Jobs.begin("artwork", "artwork_reader", false)

  if not job_token then
    table.insert(state.artwork_queue, 1, job)
    return
  end

  state.artwork_queued[job.key] = nil

  local asset = job.asset

  if asset and state.by_path[job.key] == asset then
    local current =
      tostring(asset.artwork_path or "")

    if current == ""
      or not reaper.file_exists(current) then
      local found, shared =
        discover_artwork_path(asset)

      if found ~= "" then
        asset.artwork_path = shared and "" or found
        mark_asset_database_change(asset)
      elseif current ~= "-" then
        asset.artwork_path = ""
      end

      asset.artwork_checked = true
    end
  end

  state.artwork_next_job = now + 0.025
  Jobs.finish(job_token, true)
end

function release_artwork_image(key)
  local entry = state.artwork_images[key]

  if not entry then
    return
  end

  if entry.image
    and ImGui.ValidatePtr(
      entry.image,
      "ImGui_Image*"
    ) then
    pcall(ImGui.Detach, ctx, entry.image)
  end

  state.artwork_images[key] = nil
end

function trim_artwork_image_cache()
  while #state.artwork_image_order
      > state.artwork_image_limit do
    local oldest =
      table.remove(
        state.artwork_image_order,
        1
      )

    release_artwork_image(oldest)
  end
end

function artwork_image_from_path(path)
  if not path
    or path == ""
    or path == "-"
    or not reaper.file_exists(path) then
    return nil
  end

  local key = path_key(path)
  local entry = state.artwork_images[key]
  local now = reaper.time_precise()

  if entry
    and entry.image
    and ImGui.ValidatePtr(
      entry.image,
      "ImGui_Image*"
    ) then
    entry.last_used = now
    return entry.image
  end

  if entry
    and entry.failed
    and now - (entry.last_used or 0) < 8 then
    return nil
  end

  local ok, image =
    pcall(ImGui.CreateImage, path)

  if not ok or not image then
    state.artwork_images[key] = {
      failed = true,
      last_used = now,
    }
    return nil
  end

  pcall(ImGui.Attach, ctx, image)

  state.artwork_images[key] = {
    image = image,
    last_used = now,
  }

  state.artwork_image_order[
    #state.artwork_image_order + 1
  ] = key

  trim_artwork_image_cache()
  return image
end

function artwork_image_for_asset(asset, priority)
  if not state.artwork_enabled
    or not asset then
    return nil
  end

  local path =
    tostring(asset.artwork_path or "")

  if path == "-" then
    return nil
  end

  if path ~= "" and not valid_artwork_path(path) then
    asset.artwork_path = ""
    asset.artwork_checked = false
    path = ""
  end

  if path == "" then
    local shared, record =
      root_artwork_for_asset(asset)
    path = shared

    if path == ""
      and (
        asset.artwork_checked ~= true
        or (record and not record.artwork_checked)
      ) then
      queue_artwork(asset, priority)
    end
  end

  if path == "" then
    return nil
  end

  return artwork_image_from_path(path)
end

function draw_artwork_placeholder(
  draw_list,
  x,
  y,
  width,
  height,
  rounding
)
  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + width,
    y + height,
    COLOR.panel_alt,
    rounding or 3
  )

  local cx = x + width * 0.5
  local cy = y + height * 0.5
  local radius =
    math.min(width, height) * 0.18

  ImGui.DrawList_AddCircle(
    draw_list,
    cx,
    cy - radius * 0.45,
    radius * 0.42,
    rgba_with_alpha(COLOR.dim, 0x99),
    16,
    1.2
  )

  ImGui.DrawList_AddTriangleFilled(
    draw_list,
    x + width * 0.20,
    y + height * 0.78,
    x + width * 0.48,
    y + height * 0.48,
    x + width * 0.64,
    y + height * 0.78,
    rgba_with_alpha(COLOR.dim, 0x88)
  )

  ImGui.DrawList_AddTriangleFilled(
    draw_list,
    x + width * 0.44,
    y + height * 0.78,
    x + width * 0.70,
    y + height * 0.56,
    x + width * 0.84,
    y + height * 0.78,
    rgba_with_alpha(COLOR.dim, 0x66)
  )
end

function draw_artwork_cover(
  draw_list,
  asset,
  x,
  y,
  width,
  height,
  crop,
  rounding,
  show_placeholder
)
  local image =
    artwork_image_for_asset(asset, true)

  if not image then
    if show_placeholder ~= false then
      draw_artwork_placeholder(
        draw_list,
        x,
        y,
        width,
        height,
        rounding
      )
    end
    return false
  end

  local image_w, image_h =
    ImGui.Image_GetSize(image)

  if not image_w or not image_h
    or image_w <= 0 or image_h <= 0 then
    if show_placeholder ~= false then
      draw_artwork_placeholder(
        draw_list,
        x,
        y,
        width,
        height,
        rounding
      )
    end
    return false
  end

  local u0, v0, u1, v1 = 0, 0, 1, 1
  local draw_x, draw_y = x, y
  local draw_w, draw_h = width, height

  if crop then
    local source_ratio = image_w / image_h
    local target_ratio = width / height

    if source_ratio > target_ratio then
      local visible = target_ratio / source_ratio
      u0 = (1 - visible) * 0.5
      u1 = 1 - u0
    elseif source_ratio < target_ratio then
      local visible = source_ratio / target_ratio
      v0 = (1 - visible) * 0.5
      v1 = 1 - v0
    end
  else
    local scale =
      math.min(
        width / image_w,
        height / image_h
      )

    draw_w = image_w * scale
    draw_h = image_h * scale
    draw_x = x + (width - draw_w) * 0.5
    draw_y = y + (height - draw_h) * 0.5

    ImGui.DrawList_AddRectFilled(
      draw_list,
      x,
      y,
      x + width,
      y + height,
      COLOR.waveform_bg,
      rounding or 4
    )
  end

  ImGui.DrawList_AddImageRounded(
    draw_list,
    image,
    draw_x,
    draw_y,
    draw_x + draw_w,
    draw_y + draw_h,
    u0,
    v0,
    u1,
    v1,
    0xFFFFFFFF,
    rounding or 4,
    0
  )

  return true
end

function clear_artwork_cache()
  if state.persistence_read_only then
    set_status("只读保护模式下不能修改 Artwork 缓存状态", true)
    return false
  end
  if state.artwork_reset_session then
    set_status("Artwork 缓存正在清理")
    return false
  end
  cancel_database_snapshot("artwork cache reset")
  local job_token, job_error = Jobs.begin(
    "artwork_reset",
    "catalog_exclusive",
    false
  )
  if not job_token then
    set_status(
      job_error == "resource_busy"
        and "请等待当前目录维护任务完成"
        or "无法启动 Artwork 缓存清理",
      true
    )
    return false
  end

  for key in pairs(state.artwork_images) do
    release_artwork_image(key)
  end

  state.artwork_images = {}
  state.artwork_image_order = {}
  state.artwork_folder_cache = {}
  state.artwork_dimension_cache = {}
  state.artwork_queue = {}
  state.artwork_queued = {}

  for _, record in ipairs(state.root_records) do
    if tostring(record.artwork_path or "") == "" then
      record.artwork_checked = false
      record.artwork_scan_version = 0
    end
  end

  mark_database_snapshot_dirty()
  state.artwork_reset_session = new_artwork_reset_job(state.assets)
  state.artwork_reset_session.job_token = job_token
  set_status(string.format(
    "正在清空 Artwork 缓存：0 / %d",
    #state.assets
  ))
  return true
end

function process_artwork_cache_reset()
  local session = state.artwork_reset_session
  if not session then return end
  if session.job_token.cancel_requested then
    state.artwork_reset_session = nil
    Jobs.finish(session.job_token, true, "canceled")
    set_status("已停止 Artwork 缓存清理；已完成部分仍会保存")
    return
  end

  local complete = step_artwork_reset_job(
    session,
    ARTWORK_RESET_ASSETS_PER_FRAME
  )
  if not complete then
    set_status(string.format(
      "正在清空 Artwork 缓存：%d / %d",
      math.min(session.index - 1, session.total),
      session.total
    ))
    return
  end

  state.artwork_reset_session = nil
  Jobs.finish(session.job_token, true)
  set_status(string.format(
    "已清空 Artwork 缓存：重置 %d 条；可见素材将重新查找封面",
    session.changed
  ))
end

----------------------------------------------------------------
-- Metadata indexing
----------------------------------------------------------------

function metadata_map(source)
  local map = {}
  local ok, identifiers =
    reaper.GetMediaFileMetadata(source, "")

  if not ok or not identifiers then
    return map
  end

  local count = 0

  for identifier in identifiers:gmatch("[^\r\n]+") do
    identifier = trim(identifier)

    if identifier ~= "" then
      local value_ok, value =
        reaper.GetMediaFileMetadata(
          source,
          identifier
        )

      if value_ok and value and value ~= "" then
        map[identifier] = value
      end

      count = count + 1

      if count >= 80 then
        break
      end
    end
  end

  return map
end

function metadata_pick(map, names)
  for key, value in pairs(map) do
    local upper = key:upper()

    for _, name in ipairs(names) do
      if upper:find(name, 1, true) then
        return value
      end
    end
  end

  return ""
end

function index_asset(asset)
  if not asset
    or not reaper.file_exists(asset.path) then
    return false
  end

  local source =
    reaper.PCM_Source_CreateFromFile(asset.path)

  if not source then
    return false
  end

  local duration, is_qn =
    reaper.GetMediaSourceLength(source)

  local metadata = metadata_map(source)
  local filename_ucs = parse_ucs_filename(asset.name)

  asset.duration =
    is_qn and 0 or (duration or 0)

  asset.channels =
    reaper.GetMediaSourceNumChannels(source) or 0

  asset.sample_rate =
    reaper.GetMediaSourceSampleRate(source) or 0

  asset.bit_depth =
    type(reaper.CF_GetMediaSourceBitDepth) == "function"
      and reaper.CF_GetMediaSourceBitDepth(source)
      or 0

  asset.source_type =
    reaper.GetMediaSourceType(source)
      or extension(asset.path):upper()

  asset.size = file_size(asset.path)

  asset.description = metadata_pick(
    metadata,
    {
      "DESCRIPTION",
      "COMMENT",
      "TITLE",
      "INAM",
    }
  )

  asset.keywords = metadata_pick(
    metadata,
    {
      "KEYWORD",
      "TAGS",
      "IKEY",
    }
  )

  local catid = ucs_metadata_pick(
    metadata,
    {
      "CATID",
      "CATEGORY ID",
    }
  )

  local category = ucs_metadata_pick(
    metadata,
    {
      "CATEGORY",
    }
  )

  local subcategory = ucs_metadata_pick(
    metadata,
    {
      "SUBCATEGORY",
      "SUB CATEGORY",
    }
  )

  local metadata_ucs = ucs_classify_metadata(
    catid,
    category,
    subcategory
  )
  local ucs = filename_ucs.ucs_status == "exact"
      and filename_ucs
    or metadata_ucs
    or (filename_ucs.ucs_status == "auto" and filename_ucs)

  if asset.ucs_status ~= "manual" then
    if ucs then
      asset.catid = ucs.catid
      asset.category = ucs.category
      asset.subcategory = ucs.subcategory
      asset.ucs_status = ucs.ucs_status
      asset.ucs_source = ucs.ucs_source
      asset.ucs_version = ucs.ucs_version
      asset.ucs_classifier_version = ucs.ucs_classifier_version
      asset.ucs_confidence = ucs.ucs_confidence
      asset.ucs_candidates = ucs.ucs_candidates or ""
      asset.ucs_evidence = ucs.ucs_evidence or ""
    else
      asset.catid = catid
      asset.category = category
      asset.subcategory = subcategory
      local filename_pending = filename_ucs.ucs_status == "pending"
      asset.ucs_status = filename_pending
          and "pending"
        or ((catid ~= "" or category ~= "" or subcategory ~= "")
          and "pending"
          or "unclassified")
      asset.ucs_source = filename_pending
          and filename_ucs.ucs_source
        or (asset.ucs_status == "pending" and "metadata" or "")
      asset.ucs_version = UCS_CATALOG_VERSION
      asset.ucs_classifier_version = UCS_CLASSIFIER_VERSION
      asset.ucs_confidence = filename_pending
          and filename_ucs.ucs_confidence
        or 0
      asset.ucs_candidates = filename_pending
          and filename_ucs.ucs_candidates
        or ""
      asset.ucs_evidence = filename_pending
          and filename_ucs.ucs_evidence
        or ""
    end
  end

  asset.indexed = true
  asset._search_blob = nil
  refresh_ucs_pending_membership(asset)

  reaper.PCM_Source_Destroy(source)

  mark_asset_database_change(asset)
  state.results_dirty = true
  return true
end

function new_ucs_reclassification_counts()
  return {
    exact = 0,
    auto = 0,
    pending = 0,
    unclassified = 0,
    manual = 0,
    changed = 0,
  }
end

function record_ucs_reclassification_result(session, asset, result, reason)
  if reason == "manual" then
    session.counts.manual = session.counts.manual + 1
    return false
  end
  local status = result and result.ucs_status or "unclassified"
  if session.counts[status] == nil then status = "unclassified" end
  session.counts[status] = session.counts[status] + 1

  local changed = result and ucs_classification_differs(asset, result)
  if not changed then return false end
  session.counts.changed = session.counts.changed + 1
  if session.phase == "preview" and #session.samples < 8 then
    session.samples[#session.samples + 1] = {
      name = tostring(asset.name or basename(asset.path or "")),
      before = tostring(asset.catid or ""),
      after = tostring(result.catid or ""),
      status = status,
      candidates = tostring(result.ucs_candidates or ""),
    }
  end
  return true
end

function start_ucs_reclassification_preview()
  if state.ucs_reclassification_session then return false end
  if state.persistence_read_only then
    set_status("只读保护下不能重分类现有素材", true)
    return false
  end

  local job_token = Jobs.begin(
    "ucs_reclassification",
    "catalog_exclusive",
    false
  )
  if not job_token then
    set_status("另一个维护任务正在运行", true)
    return false
  end

  AppState.set("ucs_reclassification_review", nil)
  AppState.set("ucs_reclassification_session", {
    phase = "preview",
    assets = state.assets,
    index = 1,
    total = #state.assets,
    counts = new_ucs_reclassification_counts(),
    samples = {},
    job_token = job_token,
    started = reaper.time_precise(),
  })
  set_status(string.format("正在预览 UCS 分类：0 / %d", #state.assets))
  return true
end

function start_ucs_reclassification_apply()
  local review = state.ucs_reclassification_review
  if not review or state.ucs_reclassification_session then return false end
  if state.persistence_read_only then
    set_status("只读保护下不能重分类现有素材", true)
    return false
  end
  if review.classifier_version ~= UCS_CLASSIFIER_VERSION then
    AppState.set("ucs_reclassification_review", nil)
    set_status("分类规则已变化，请重新生成预览", true)
    return false
  end
  if review.assets ~= state.assets or review.total ~= #state.assets then
    AppState.set("ucs_reclassification_review", nil)
    set_status("素材库已变化，请重新生成 UCS 分类预览", true)
    return false
  end

  local job_token = Jobs.begin(
    "ucs_reclassification",
    "catalog_exclusive",
    false
  )
  if not job_token then
    set_status("另一个维护任务正在运行", true)
    return false
  end

  AppState.set("ucs_reclassification_session", {
    phase = "apply",
    assets = state.assets,
    index = 1,
    total = #state.assets,
    counts = new_ucs_reclassification_counts(),
    samples = {},
    applied = 0,
    job_token = job_token,
    started = reaper.time_precise(),
  })
  set_status(string.format("正在应用 UCS 分类：0 / %d", #state.assets))
  return true
end

function cancel_ucs_reclassification()
  local session = state.ucs_reclassification_session
  if not session then return false end
  Jobs.cancel(session.job_token)
  return true
end

function finish_ucs_reclassification(session, canceled)
  AppState.set("ucs_reclassification_session", nil)
  Jobs.finish(
    session.job_token,
    true,
    canceled and "canceled" or ""
  )

  if session.phase == "preview" then
    if canceled then
      set_status("UCS 分类预览已取消")
      return
    end
    AppState.set("ucs_reclassification_review", {
      counts = session.counts,
      samples = session.samples,
      total = session.total,
      classifier_version = UCS_CLASSIFIER_VERSION,
      ucs_version = UCS_CATALOG_VERSION,
      assets = session.assets,
      elapsed = reaper.time_precise() - session.started,
    })
    set_status(string.format(
      "UCS 分类预览完成：可更新 %d，待确认 %d，人工保护 %d",
      session.counts.changed,
      session.counts.pending,
      session.counts.manual
    ))
    return
  end

  AppState.set("ucs_reclassification_review", nil)
  AppState.mark_dirty("results_dirty")
  if session.applied > 0 then save_database_changes() end
  set_status(string.format(
    canceled
        and "UCS 分类已停止：已安全应用 %d，可重新预览继续"
      or "UCS 分类已应用：更新 %d，待确认 %d",
    session.applied,
    session.counts.pending
  ))
end

function process_ucs_reclassification()
  local session = state.ucs_reclassification_session
  if not session or not can_run_heavy_job() then return end
  if session.job_token.cancel_requested then
    finish_ucs_reclassification(session, true)
    return
  end

  local deadline = reaper.time_precise() + UCS_RECLASSIFY_FRAME_BUDGET
  local processed = 0
  while session.index <= session.total
    and processed < UCS_RECLASSIFY_ITEMS_PER_FRAME
    and reaper.time_precise() < deadline do
    local asset = session.assets[session.index]
    session.index = session.index + 1
    processed = processed + 1
    if asset then
      local result, reason = ucs_classify_existing_asset(asset)
      local changed = record_ucs_reclassification_result(
        session,
        asset,
        result,
        reason
      )
      if session.phase == "apply" and changed
        and ucs_assign_classification(asset, result) then
        asset._search_blob = nil
        refresh_ucs_pending_membership(asset)
        mark_asset_database_change(asset)
        session.applied = session.applied + 1
      end
    end
  end

  if session.index > session.total then
    finish_ucs_reclassification(session, false)
  end
end

function ucs_classification_snapshot(asset)
  local snapshot = {}
  for _, field in ipairs(UCS_CLASSIFICATION_FIELDS) do
    snapshot[field] = asset[field]
  end
  return snapshot
end

function remove_ucs_confirmation_undo(key)
  key = tostring(key or "")
  state.ucs_confirmation_undo[key] = nil
  for index = #state.ucs_confirmation_undo_order, 1, -1 do
    if state.ucs_confirmation_undo_order[index] == key then
      table.remove(state.ucs_confirmation_undo_order, index)
    end
  end
end

function remember_ucs_confirmation_undo(asset)
  local key = path_key(asset.path)
  if not state.ucs_confirmation_undo[key] then
    state.ucs_confirmation_undo[key] = {
      path = asset.path,
      values = ucs_classification_snapshot(asset),
    }
  end
  for index = #state.ucs_confirmation_undo_order, 1, -1 do
    if state.ucs_confirmation_undo_order[index] == key then
      table.remove(state.ucs_confirmation_undo_order, index)
    end
  end
  state.ucs_confirmation_undo_order[
    #state.ucs_confirmation_undo_order + 1
  ] = key
  while #state.ucs_confirmation_undo_order > 64 do
    local retired = table.remove(state.ucs_confirmation_undo_order, 1)
    state.ucs_confirmation_undo[retired] = nil
  end
end

function confirm_ucs_candidate(asset, catid)
  if state.persistence_read_only then
    set_status("只读保护下不能修改 UCS 分类", true)
    return false
  end
  if not asset or "pending" ~= asset.ucs_status then
    set_status("没有可确认的 UCS 候选", true)
    return false
  end
  local allowed = false
  for _, candidate in ipairs(ucs_parse_candidates(asset.ucs_candidates)) do
    if candidate.entry.catid == catid then
      allowed = true
      break
    end
  end
  if not allowed then
    set_status("没有可确认的 UCS 候选", true)
    return false
  end
  local result = ucs_manual_classification_result(catid)
  if not result then
    set_status("没有可确认的 UCS 候选", true)
    return false
  end
  remember_ucs_confirmation_undo(asset)
  if not ucs_assign_classification(asset, result) then
    remove_ucs_confirmation_undo(path_key(asset.path))
    return false
  end
  asset._search_blob = nil
  refresh_ucs_pending_membership(asset)
  mark_asset_database_change(asset)
  AppState.mark_dirty("results_dirty")
  state.metadata_editor.signature = ""
  set_status("已确认 UCS 分类：" .. result.catid)
  return true
end

function undo_ucs_confirmation(asset_or_key)
  if state.persistence_read_only then
    set_status("只读保护下不能修改 UCS 分类", true)
    return false
  end
  local key = type(asset_or_key) == "table"
      and path_key(asset_or_key.path)
    or tostring(asset_or_key or "")
  local undo = state.ucs_confirmation_undo[key]
  local asset = undo and state.by_path[key] or nil
  if not undo or not asset then
    remove_ucs_confirmation_undo(key)
    set_status("无法撤销 UCS 确认", true)
    return false
  end
  local previous_catid = tostring(asset.catid or "")
  ucs_assign_classification(asset, undo.values)
  remove_ucs_confirmation_undo(key)
  asset._search_blob = nil
  refresh_ucs_pending_membership(asset)
  mark_asset_database_change(asset)
  AppState.mark_dirty("results_dirty")
  state.metadata_editor.signature = ""
  set_status("已撤销 UCS 确认：" .. previous_catid)
  return true
end

function undo_last_ucs_confirmation()
  while #state.ucs_confirmation_undo_order > 0 do
    local key = state.ucs_confirmation_undo_order[
      #state.ucs_confirmation_undo_order
    ]
    if state.ucs_confirmation_undo[key] and state.by_path[key] then
      return undo_ucs_confirmation(key)
    end
    remove_ucs_confirmation_undo(key)
  end
  set_status("无法撤销 UCS 确认", true)
  return false
end

function queue_metadata(asset, priority)
  if not asset or asset.indexed then
    return
  end

  local key = path_key(asset.path)

  if state.meta_queued[key] then
    return
  end

  if not priority
    and #state.meta_queue >= MAX_WORK_QUEUE then
    return
  end

  state.meta_queued[key] = true

  local job = {
    key = key,
    asset = asset,
  }

  if priority then
    table.insert(state.meta_queue, 1, job)
  else
    state.meta_queue[#state.meta_queue + 1] = job
  end
end

function process_metadata_queue()
  if state.import_session then
    return
  end

  if #state.meta_queue == 0
    or not can_run_heavy_job() then
    return
  end

  local now = reaper.time_precise()

  if now < state.next_meta_job then
    return
  end

  local job = table.remove(state.meta_queue, 1)
  state.meta_queued[job.key] = nil

  if job.asset then
    index_asset(job.asset)
  end

  state.next_meta_job = now + META_INTERVAL
end

----------------------------------------------------------------
-- Scan
----------------------------------------------------------------

function start_import_recovery_audit()
  if state.persistence_read_only or #state.roots == 0
    or #state.assets == 0 then
    state.import_recovery_audit = nil
    return
  end
  state.import_recovery_audit = {
    assets = state.assets,
    index = 1,
    total = #state.assets,
  }
end

function process_import_recovery_audit()
  local audit = state.import_recovery_audit
  if not audit or state.scan or state.import_session
    or state.transfer_running or not can_run_heavy_job() then
    return
  end

  for _, token in pairs(Jobs.active) do
    if token.resource == "catalog_exclusive"
      and not token.finished then
      return
    end
  end

  if audit.assets ~= state.assets then
    audit.assets = state.assets
    audit.index = 1
    audit.total = #state.assets
  end

  local last = math.min(
    audit.total,
    audit.index + IMPORT_RECOVERY_ASSETS_PER_FRAME - 1
  )
  for index = audit.index, last do
    local asset = audit.assets[index]
    if asset and not asset.ready then
      state.import_recovery_audit = nil
      start_scan("恢复未完成导入")
      return
    end
  end
  audit.index = last + 1
  if audit.index > audit.total then
    state.import_recovery_audit = nil
  end
end

function start_scan(reason, roots_override, options)
  local requested = roots_override or state.roots
  local silent =
    type(options) == "table"
    and options.silent == true
  local force_rebuild =
    type(options) == "table"
    and options.force_rebuild == true
  local checkpoint_enabled = not silent
    and (reason or "") ~= "Watch Folder"

  if type(options) == "table"
    and options.checkpoint_enabled ~= nil then
    checkpoint_enabled = options.checkpoint_enabled == true
  end

  if #requested == 0 then
    set_status("请先添加音效库根目录", true)
    return
  end

  local scan = {
    reason = reason or "扫描",
    roots = {},
    root_keys = {},
    dirs = {},
    dir_head = 1,
    current = nil,
    seen = {},
    files = 0,
    ignored = 0,
    directories = 0,
    new_assets = {},
    started = reaper.time_precise(),
    silent = silent,
    force_rebuild = force_rebuild,
    checkpoint_enabled = checkpoint_enabled,
  }

  for _, root in ipairs(requested) do
    if directory_exists(root) then
      scan.roots[#scan.roots + 1] = root
      scan.root_keys[path_key(root)] = true
      scan.dirs[#scan.dirs + 1] = {
        path = root,
        root = root,
        file_index = 0,
        sub_index = 0,
        stage = "files",
      }
    end
  end

  if #scan.roots == 0 then
    set_status("没有可访问的音效库目录", true)
    return
  end

  cancel_auxiliary_save("catalog scan")
  local job_token, job_error =
    Jobs.begin(
      "catalog_pipeline",
      "catalog_exclusive",
      false
    )

  if not job_token then
    set_status(
      job_error == "resource_busy"
        and "另一个目录写任务正在运行"
        or "扫描任务已经在运行",
      true
    )
    return
  end

  scan.job_token = job_token

  state.scan = scan
  state.scan_checkpoint_last_at = 0
  if scan.checkpoint_enabled then
    write_scan_checkpoint(scan, "scan")
  end

  if not scan.silent then
    set_status(
      string.format(
        "%s：正在扫描 %d 个目录…",
        scan.reason,
        #scan.roots
      )
    )
  end

end

function finish_scan()
  local scan = state.scan
  if not scan or scan.phase then return end
  scan.phase = "finalize_prune"
  scan.prune_job = new_catalog_prune_job(state.by_path)
  scan.finalize_total = #state.assets
  scan.removed = 0
  scan.finalize_removed_so_far = 0
  scan.pending = {}
  scan.pending_seen = {}
  scan.pending_index = 1
  if not scan.silent then
    set_status(scan.reason .. "：扫描完成，正在整理索引…")
  end
end

function complete_scan_finalize(scan)
  local pending = scan.pending
  local removed = scan.removed or 0
  state.scan = nil

  if #pending > 0 then
    state.import_session = {
      label = scan.reason,
      roots = scan.roots,
      assets = pending,
      total = #pending,
      done = 0,
      failed = 0,
      current = nil,
      started = scan.started,
      phase = "prepare",
      silent = scan.silent,
      removed = removed,
      job_token = scan.job_token,
    }

    state.import_cancel_requested = false

    if not scan.silent then
      set_status(
        string.format(
          "%s：扫描完成，正在分析并建立 %d 个波形…",
          scan.reason,
          #pending
        )
      )
    end
  else
    clear_scan_checkpoint()
    Jobs.finish(scan.job_token, true)
    if scan.silent then
      if removed > 0 then
        set_status(
          string.format(
            "后台更新：移除 %d 个离线素材",
            removed
          )
        )
      end
    elseif scan.ignored > 0 then
      set_status(
        string.format(
          "扫描完成：%d 个音频，移除 %d 个，忽略 %d 个系统文件，%.1f 秒",
          scan.files,
          removed,
          scan.ignored,
          reaper.time_precise() - scan.started
        )
      )
    else
      set_status(
        string.format(
          "扫描完成：%d 个音频，移除 %d 个，%.1f 秒",
          scan.files,
          removed,
          reaper.time_precise() - scan.started
        )
      )
    end
  end

  state.results_dirty = true
end

function process_scan_finalize(scan)
  if scan.phase == "finalize_prune" then
    local complete = step_catalog_prune_job(
      scan.prune_job,
      SCAN_FINALIZE_ASSETS_PER_FRAME,
      function(key, asset)
        local belongs =
          scan.root_keys[path_key(asset.root or "")] == true
        return belongs and not scan.seen[key]
      end,
      function(key, asset)
        state.favorites[key] = nil
        state.selected_set[key] = nil
        state.preview_history_assets[asset.asset_id or ""] = nil
        scan.finalize_removed_so_far =
          scan.finalize_removed_so_far + 1
      end
    )
    if complete then
      scan.removed = scan.prune_job.removed
      if scan.removed > 0 then
        state.assets = scan.prune_job.kept
        state.database_ordered_assets = nil
        state.config_dirty = true
        mark_database_snapshot_dirty()
        invalidate_library_counts()
        invalidate_folder_navigation()
      end
      scan.prune_job = nil
      scan.phase = "finalize_pending"
    end
    return
  end

  local last = math.min(
    #scan.new_assets,
    scan.pending_index + SCAN_FINALIZE_ASSETS_PER_FRAME - 1
  )
  for index = scan.pending_index, last do
    local asset = scan.new_assets[index]
    local key = asset and path_key(asset.path) or ""
    if asset and key ~= "" and not scan.pending_seen[key]
      and not asset.ready then
      scan.pending_seen[key] = true
      asset.pending_batch = true
      scan.pending[#scan.pending + 1] = asset
    end
  end
  scan.pending_index = last + 1
  if scan.pending_index > #scan.new_assets then
    scan.pending_seen = nil
    complete_scan_finalize(scan)
  end
end

function begin_scan_cancel(scan)
  if scan.phase == "cancel_collect"
    or scan.phase == "cancel_prune" then
    return
  end
  scan.phase = "cancel_collect"
  scan.cancel_index = 1
  scan.cancel_keys = {}
  scan.prune_job = nil
  set_status("正在取消扫描并清理未完成素材…")
end

function process_scan_cancel(scan)
  if scan.phase == "cancel_collect" then
    local last = math.min(
      #scan.new_assets,
      scan.cancel_index + SCAN_FINALIZE_ASSETS_PER_FRAME - 1
    )
    for index = scan.cancel_index, last do
      local asset = scan.new_assets[index]
      if asset and not asset.ready then
        scan.cancel_keys[path_key(asset.path)] = true
      end
    end
    scan.cancel_index = last + 1
    if scan.cancel_index > #scan.new_assets then
      scan.phase = "cancel_prune"
      scan.prune_job = new_catalog_prune_job(state.by_path)
      scan.cancel_total = #state.assets
    end
    return
  end

  local complete = step_catalog_prune_job(
    scan.prune_job,
    SCAN_FINALIZE_ASSETS_PER_FRAME,
    function(key)
      return scan.cancel_keys[key] == true
    end,
    function(key, asset)
      state.favorites[key] = nil
      state.selected_set[key] = nil
      state.preview_history_assets[asset.asset_id or ""] = nil
    end
  )
  if not complete then return end

  local removed = scan.prune_job.removed
  local catalog_changed = removed > 0
    or (scan.finalize_removed_so_far or 0) > 0
  if catalog_changed then
    state.assets = scan.prune_job.kept
    state.database_ordered_assets = nil
    mark_database_snapshot_dirty()
    invalidate_library_counts()
    invalidate_folder_navigation()
  end
  state.scan = nil
  clear_scan_checkpoint()
  Jobs.finish(scan.job_token, true, "user canceled")
  state.results_dirty = true
  set_status("已取消扫描")
end

function process_scan()
  local scan = state.scan

  if not scan then
    return
  end

  if scan.job_token
    and scan.job_token.cancel_requested then
    begin_scan_cancel(scan)
    process_scan_cancel(scan)
    return
  end

  if scan.phase == "finalize_prune"
    or scan.phase == "finalize_pending" then
    process_scan_finalize(scan)
    return
  end

  local deadline =
    reaper.time_precise() + SCAN_BUDGET

  local now = reaper.time_precise()

  if scan.checkpoint_enabled
    and now - (state.scan_checkpoint_last_at or 0)
      >= SCAN_CHECKPOINT_INTERVAL then
    write_scan_checkpoint(scan, "scan")
    state.scan_checkpoint_last_at = now
  end

  while reaper.time_precise() < deadline do
    local dir = scan.current

    if not dir then
      dir = scan.dirs[scan.dir_head]
      scan.dir_head = scan.dir_head + 1
      scan.current = dir

      if not dir then
        finish_scan()
        return
      end

      scan.directories =
        scan.directories + 1
    end

    if dir.stage == "files" then
      local filename =
        reaper.EnumerateFiles(
          dir.path,
          dir.file_index
        )

      if filename then
        dir.file_index = dir.file_index + 1

        local path =
          join_path(dir.path, filename)

        if is_ignored_media_path(path) then
          scan.ignored = scan.ignored + 1
        elseif is_audio_file(path) then
          local key = path_key(path)

          if not scan.seen[key] then
            scan.seen[key] = true
            scan.files = scan.files + 1

            if not state.by_path[key] then
              local asset =
                add_or_update_asset(
                  make_placeholder(path, dir.root)
                )

              scan.new_assets[#scan.new_assets + 1] =
                asset

              mark_asset_database_change(asset)
            elseif scan.force_rebuild then
              local asset = state.by_path[key]
              asset.ready = false
              asset.indexed = false
              scan.new_assets[#scan.new_assets + 1] = asset
            elseif not state.by_path[key].ready then
              scan.new_assets[#scan.new_assets + 1] =
                state.by_path[key]
            end
          end
        end
      else
        dir.stage = "subdirs"
      end
    else
      local subdir =
        reaper.EnumerateSubdirectories(
          dir.path,
          dir.sub_index
        )

      if subdir then
        dir.sub_index = dir.sub_index + 1

        if not is_ignored_directory_name(subdir) then
          scan.dirs[#scan.dirs + 1] = {
            path = join_path(dir.path, subdir),
            root = dir.root,
            file_index = 0,
            sub_index = 0,
            stage = "files",
          }
        end
      else
        scan.current = nil
      end
    end
  end
end

----------------------------------------------------------------
-- Search
----------------------------------------------------------------

function search_blob(asset)
  if not asset._search_blob then
    asset._search_blob =
      safe_lower(
        table.concat(
          {
            asset.name or "",
            asset.path or "",
            asset.library or "",
            asset.description or "",
            asset.keywords or "",
            asset.catid or "",
            asset.category or "",
            asset.subcategory or "",
            workflow_label(
              asset.workflow_status or "none"
            ),
            asset.marked and "marked" or "",
          },
          "\n"
        )
      )
  end

  return asset._search_blob
end

function field_value(asset, field)
  field = safe_lower(field)

  if field == "name" then
    return asset.name
  elseif field == "path"
    or field == "folder" then
    return asset.path
  elseif field == "library"
    or field == "lib" then
    return asset.library
  elseif field == "root"
    or field == "source" then
    local record = state.root_by_id[asset.root_id or ""]
    return record and ((record.alias or "") .. " " .. record.path)
      or asset.root
  elseif field == "category"
    or field == "cat" then
    return asset.category
  elseif field == "subcategory"
    or field == "subcat" then
    return asset.subcategory
  elseif field == "catid" then
    return asset.catid
  elseif field == "desc"
    or field == "description" then
    return asset.description
  elseif field == "keywords"
    or field == "key" then
    return asset.keywords
  elseif field == "ch"
    or field == "channels" then
    return tostring(asset.channels or 0)
  elseif field == "fav"
    or field == "favorite" then
    return state.favorites[path_key(asset.path)]
      and "true"
      or "false"
  elseif field == "status"
    or field == "workflow" then
    return asset.workflow_status or "none"
  elseif field == "marked"
    or field == "mark" then
    return asset.marked and "true" or "false"
  elseif field == "played"
    or field == "previewed" then
    return asset_is_played(asset) and "true" or "false"
  elseif field == "missing"
    or field == "offline" then
    return state.missing_assets[path_key(asset.path)]
      and "true"
      or "false"
  elseif field == "duplicate"
    or field == "dupe" then
    return state.duplicate_lookup[path_key(asset.path)]
      and "true"
      or "false"
  elseif field == "project"
    or field == "used" then
    local bucket = project_usage_bucket(
      state.current_project_path,
      false
    )
    return bucket
      and bucket.assets[path_key(asset.path)]
      and "true"
      or "false"
  end

  return ""
end

function matches_search(asset)
  local query = trim(state.search)

  if query == "" then
    return true
  end

  local blob = search_blob(asset)

  for _, raw in ipairs(split_words(query)) do
    local exclude = raw:sub(1, 1) == "-"
    local token = exclude and raw:sub(2) or raw
    token = safe_lower(token)

    if token ~= "" then
      local field, wanted =
        token:match("^([%w_]+)%:(.+)$")

      local matched

      if field then
        matched =
          safe_lower(field_value(asset, field))
            :find(wanted, 1, true)
          ~= nil
      else
        matched =
          blob:find(token, 1, true) ~= nil
      end

      if exclude and matched then
        return false
      elseif not exclude and not matched then
        return false
      end
    end
  end

  return true
end

function asset_in_view(asset)
  if not asset.ready or asset.pending_batch then
    return false
  end

  if state.view == "favorites"
    and not state.favorites[path_key(asset.path)] then
    return false
  elseif state.view == "recent"
    and (asset.last_used or 0) <= 0 then
    return false
  elseif state.view == "previewed"
    and (asset.last_previewed or 0) <= 0 then
    return false
  elseif "ucs_pending" == state.view
    and asset.ucs_status ~= "pending" then
    return false
  elseif "ucs_category" == state.view
    and tostring(asset.category or "") ~= state.ucs_filter_category then
    return false
  elseif "ucs_subcategory" == state.view
    and (tostring(asset.category or "") ~= state.ucs_filter_category
      or tostring(asset.subcategory or "")
        ~= state.ucs_filter_subcategory) then
    return false
  elseif "ucs_catid" == state.view
    and tostring(asset.catid or "") ~= state.ucs_filter_catid then
    return false
  elseif state.view == "missing"
    and not state.missing_assets[path_key(asset.path)] then
    return false
  elseif state.view == "duplicates"
    and not state.duplicate_lookup[path_key(asset.path)] then
    return false
  elseif state.view == "duplicates_confirmed"
    and not state.duplicate_confirmed_lookup[path_key(asset.path)] then
    return false
  elseif state.view == "duplicate_failures"
    and not state.duplicate_confirmation_failures[path_key(asset.path)] then
    return false
  elseif state.view == "project_used" then
    local bucket = project_usage_bucket(
      state.current_project_path,
      false
    )
    if not bucket
      or not bucket.assets[path_key(asset.path)] then
      return false
    end
  end

  if state.active_collection_id then
    local collection =
      state.collection_by_id[
        state.active_collection_id
      ]

    if not collection
      or not collection.items[path_key(asset.path)] then
      return false
    end
  end

  if state.status_filter
    and (asset.workflow_status or "none")
      ~= state.status_filter then
    return false
  end

  if state.root_filter
    and not path_is_inside(
      asset.path,
      state.root_filter
    ) then
    return false
  end

  if state.library_filter_id
    and asset.library_id ~= state.library_filter_id then
    return false
  end

  return true
end

local function cached_sort_text(asset, field, source_field, value_field)
  local source = tostring(asset[field] or "")
  if asset[source_field] ~= source then
    asset[source_field] = source
    asset[value_field] = safe_lower(source)
  end
  return asset[value_field]
end

local function cached_sort_path(asset)
  return asset_path_sort_key(asset)
end

local function result_sort_comparator()
  local direction = state.sort_desc and -1 or 1
  local view = state.view
  local sort_mode = state.sort_mode
  local duplicate_lookup = state.duplicate_lookup
  local confirmed_lookup = state.duplicate_confirmed_lookup

  return function(a, b)
    local av
    local bv

    if view == "duplicates" then
      av = duplicate_lookup[cached_sort_path(a)] or ""
      bv = duplicate_lookup[cached_sort_path(b)] or ""
    elseif view == "duplicates_confirmed" then
      av = confirmed_lookup[cached_sort_path(a)] or ""
      bv = confirmed_lookup[cached_sort_path(b)] or ""
    elseif sort_mode == "duration" then
      av = tonumber(a.duration) or 0
      bv = tonumber(b.duration) or 0
    elseif sort_mode == "library" then
      av = cached_sort_text(
        a,
        "library",
        "_sort_library_source",
        "_sort_library_value"
      )
      bv = cached_sort_text(
        b,
        "library",
        "_sort_library_source",
        "_sort_library_value"
      )
    elseif sort_mode == "used" then
      av = tonumber(a.last_used) or 0
      bv = tonumber(b.last_used) or 0
    elseif sort_mode == "previewed" then
      av = tonumber(a.last_previewed) or 0
      bv = tonumber(b.last_previewed) or 0
    else
      av = cached_sort_text(
        a,
        "name",
        "_sort_name_source",
        "_sort_name_value"
      )
      bv = cached_sort_text(
        b,
        "name",
        "_sort_name_source",
        "_sort_name_value"
      )
    end

    if av == bv then
      local a_path = cached_sort_path(a)
      local b_path = cached_sort_path(b)
      if a_path == b_path then
        return false
      end
      return ordered_result_less(a_path, b_path, direction)
    end

    return ordered_result_less(av, bv, direction)
  end
end

function start_results_rebuild()
  state.results_dirty = false
  state.results_job = begin_incremental_result_job(
    state.assets,
    function(asset)
      return asset_in_view(asset) and matches_search(asset)
    end,
    result_sort_comparator(),
    cached_sort_path,
    state.selected_path and path_key(state.selected_path) or nil
  )
end

function process_results_rebuild()
  if state.results_dirty or not state.results_job then
    start_results_rebuild()
  end

  local status, results, selected_index =
    step_incremental_result_job(
      state.results_job,
      RESULT_BUILD_DEFAULT_BUDGET
    )

  if status == "complete" then
    state.results = results
    state.selected_index = selected_index
    state.results_job = nil
  end
end

function rebuild_results()
  start_results_rebuild()
  while state.results_job do
    process_results_rebuild()
  end
end

----------------------------------------------------------------
-- Persistent waveform cache
----------------------------------------------------------------

function wave_cache_key(asset, points, preserve_channels, spectral)
  if not asset.size or asset.size <= 0 then
    asset.size = file_size(asset.path)
  end

  return fnv1a(
    path_key(asset.path)
      .. "|"
      .. tostring(asset.size)
      .. "|"
      .. tostring(points)
      .. (preserve_channels and "|channels-rwf3" or "")
      .. (spectral and "|spectral-rwf4" or "")
  )
end

function wave_cache_path(asset, points, preserve_channels, spectral)
  return join_path(
    WAVE_CACHE_DIR,
    wave_cache_key(asset, points, preserve_channels, spectral) .. ".rwf"
  )
end

function load_wave_from_disk(asset, points, preserve_channels, spectral)
  local path = wave_cache_path(asset, points, preserve_channels, spectral)
  local file = io.open(path, "rb")

  if not file then
    return nil
  end

  local header = file:read("*l") or ""
  local version, count_text, channels_text =
    header:match("^(RWF[34])%s+(%d+)%s+(%d+)$")

  if not version then
    version, count_text =
      header:match("^(RWF2)%s+(%d+)$")
  end

  local count =
    version and tonumber(count_text)
    or tonumber(header)

  if not count
    or count <= 0
    or count > LARGE_WAVE_MAX_POINTS then
    file:close()
    return nil
  end

  local peaks = {}

  if version == "RWF3" or version == "RWF4" then
    local channels = clamp(tonumber(channels_text) or 1, 1, 8)
    local amplitude_bytes = count * channels * 2
    local spectral_bytes = version == "RWF4" and count * 4 or 0
    local bytes = file:read(amplitude_bytes + spectral_bytes)
    file:close()

    if not bytes or #bytes ~= amplitude_bytes + spectral_bytes then
      return nil
    end

    local channel_peaks = {}

    for channel = 1, channels do
      channel_peaks[channel] = {}
    end

    for index = 1, count do
      local aggregate = 0

      for channel = 1, channels do
        local value_index =
          ((index - 1) * channels + channel - 1) * 2 + 1
        local low = bytes:byte(value_index) or 0
        local high = bytes:byte(value_index + 1) or 0
        local value = (low | (high << 8)) / 65535

        channel_peaks[channel][index] = value
        aggregate = math.max(aggregate, value)
      end

      peaks[index] = aggregate
    end

    local waveform = {
      count = count,
      channels = channels,
      peaks = peaks,
      channel_peaks = channel_peaks,
    }

    if version == "RWF4" then
      waveform.spectral_frequency = {}
      waveform.spectral_tonality = {}
      waveform.spectral_available = true

      for index = 1, count do
        local byte_index = amplitude_bytes + (index - 1) * 4 + 1
        local frequency =
          (bytes:byte(byte_index) or 0)
            | ((bytes:byte(byte_index + 1) or 0) << 8)
        local tonality =
          (bytes:byte(byte_index + 2) or 0)
            | ((bytes:byte(byte_index + 3) or 0) << 8)
        waveform.spectral_frequency[index] = frequency
        waveform.spectral_tonality[index] = tonality / 65535
      end
    end

    return waveform
  elseif version == "RWF2" then
    local bytes = file:read(count * 2)
    file:close()

    if not bytes or #bytes ~= count * 2 then
      return nil
    end

    for index = 1, count do
      local byte_index = (index - 1) * 2 + 1
      local low = bytes:byte(byte_index) or 0
      local high = bytes:byte(byte_index + 1) or 0
      peaks[index] = (low | (high << 8)) / 65535
    end
  else
    -- 兼容 0.5.1 及更早版本的 8-bit 峰值缓存。
    local bytes = file:read(count)
    file:close()

    if not bytes or #bytes ~= count then
      return nil
    end

    for index = 1, count do
      peaks[index] = bytes:byte(index) / 255
    end
  end

  return {
    count = count,
    peaks = peaks,
  }
end

function save_wave_to_disk(
  asset,
  points,
  waveform,
  preserve_channels,
  spectral
)
  ensure_dirs()

  local file =
    io.open(
      wave_cache_path(asset, points, preserve_channels, spectral),
      "wb"
    )

  if not file then
    return
  end

  local channel_peaks =
    preserve_channels and waveform.channel_peaks or nil
  local channels =
    channel_peaks and clamp(waveform.channels or #channel_peaks, 1, 8)
      or 1

  local has_spectral =
    spectral
    and waveform.spectral_available
    and waveform.spectral_frequency
    and waveform.spectral_tonality

  if has_spectral then
    file:write(
      "RWF4 ",
      tostring(waveform.count),
      " ",
      tostring(channels),
      "\n"
    )
  elseif channel_peaks then
    file:write(
      "RWF3 ",
      tostring(waveform.count),
      " ",
      tostring(channels),
      "\n"
    )
  else
    -- RWF2 保持列表缩略图缓存兼容；RWF3 才保存独立声道。
    file:write(
      "RWF2 ",
      tostring(waveform.count),
      "\n"
    )
  end

  local chunks = {}
  local chunk = {}

  for index = 1, waveform.count do
    for channel = 1, channels do
      local source_peaks =
        channel_peaks and channel_peaks[channel]
          or waveform.peaks
      local value =
        clamp(
          math.floor(
            ((source_peaks and source_peaks[index]) or 0)
              * 65535
              + 0.5
          ),
          0,
          65535
        )

      chunk[#chunk + 1] =
        string.char(
          value & 0xFF,
          (value >> 8) & 0xFF
        )

      if #chunk >= 256 then
        chunks[#chunks + 1] =
          table.concat(chunk)
        chunk = {}
      end
    end
  end

  if #chunk > 0 then
    chunks[#chunks + 1] =
      table.concat(chunk)
  end

  file:write(table.concat(chunks))

  if has_spectral then
    chunks = {}
    chunk = {}

    for index = 1, waveform.count do
      local frequency = clamp(
        math.floor((waveform.spectral_frequency[index] or 0) + 0.5),
        0,
        65535
      )
      local tonality = clamp(
        math.floor((waveform.spectral_tonality[index] or 0) * 65535 + 0.5),
        0,
        65535
      )

      chunk[#chunk + 1] = string.char(
        frequency & 0xFF,
        (frequency >> 8) & 0xFF,
        tonality & 0xFF,
        (tonality >> 8) & 0xFF
      )

      if #chunk >= 256 then
        chunks[#chunks + 1] = table.concat(chunk)
        chunk = {}
      end
    end

    if #chunk > 0 then
      chunks[#chunks + 1] = table.concat(chunk)
    end

    file:write(table.concat(chunks))
  end

  file:close()
end

function read_waveform_from_source(
  source,
  duration,
  channels,
  points,
  preserve_channels,
  spectral
)
  if not source
    or not duration
    or duration <= 0 then
    return nil
  end

  channels = clamp(channels or 1, 1, 8)
  points = clamp(math.floor(points), 32, LARGE_WAVE_MAX_POINTS)

  spectral = spectral == true
  local block_count = spectral and 3 or 2
  local buffer =
    reaper.new_array(points * channels * block_count)

  local call_ok, retval =
    pcall(
      reaper.PCM_Source_GetPeaks,
      source,
      points / duration,
      0,
      channels,
      points,
      spectral and 115 or 0,
      buffer
    )

  if not call_ok or type(retval) ~= "number" then
    return nil, "峰值接口调用失败", tostring(retval or "unknown")
  end

  local returned = retval & 0xFFFFF

  if returned <= 0 then
    return nil, "峰值暂未就绪", tostring(retval)
  end

  local has_spectral =
    spectral and (retval & 0x1000000) ~= 0
  local values =
    buffer.table(
      1,
      returned * channels * (has_spectral and 3 or 2)
    )

  local peaks = {}
  local channel_peaks = preserve_channels and {} or nil
  local minimum_offset = returned * channels
  local spectral_offset = returned * channels * 2
  local spectral_frequency = has_spectral and {} or nil
  local spectral_tonality = has_spectral and {} or nil

  if channel_peaks then
    for channel = 1, channels do
      channel_peaks[channel] = {}
    end
  end

  for sample = 0, returned - 1 do
    local amplitude = 0
    local dominant_channel = 0

    for channel = 0, channels - 1 do
      local maximum =
        math.abs(
          values[
            sample * channels
              + channel
              + 1
          ] or 0
        )

      local minimum =
        math.abs(
          values[
            minimum_offset
              + sample * channels
              + channel
              + 1
          ] or 0
        )

      amplitude =
        math.max(
          amplitude,
          maximum,
          minimum
        )

      if math.max(maximum, minimum) >= amplitude then
        dominant_channel = channel
      end

      if channel_peaks then
        channel_peaks[channel + 1][sample + 1] =
          clamp(math.max(maximum, minimum), 0, 1)
      end
    end

    peaks[sample + 1] =
      clamp(amplitude, 0, 1)

    if has_spectral then
      local packed = math.floor(
        values[
          spectral_offset
            + sample * channels
            + dominant_channel
            + 1
        ] or 0
      )
      spectral_frequency[sample + 1] = packed & 0x7FFF
      spectral_tonality[sample + 1] =
        ((packed >> 15) & 0x3FFF) / 0x3FFF
    end
  end

  return {
    count = returned,
    channels = channels,
    peaks = peaks,
    channel_peaks = channel_peaks,
    spectral_available = has_spectral,
    spectral_frequency = spectral_frequency,
    spectral_tonality = spectral_tonality,
  }
end

function destroy_wave_job(job)
  if job and job.source then
    reaper.PCM_Source_Destroy(job.source)
    job.source = nil
  end
end

function start_wave_job(job)
  if not job
    or not job.asset
    or not reaper.file_exists(job.asset.path) then
    return false, "文件不可用"
  end

  local source = nil
  if (job.reopen_count or 0) > 0
    and type(reaper.PCM_Source_CreateFromFileEx) == "function" then
    source = reaper.PCM_Source_CreateFromFileEx(job.asset.path, true)
  end
  if not source then
    source = reaper.PCM_Source_CreateFromFile(job.asset.path)
  end

  if not source then
    return false, "无法建立媒体源"
  end

  local duration, is_qn =
    reaper.GetMediaSourceLength(source)

  if is_qn or not duration or duration <= 0 then
    reaper.PCM_Source_Destroy(source)
    return false, "无有效音频长度"
  end

  job.source = source
  job.duration = duration
  job.channels =
    clamp(
      reaper.GetMediaSourceNumChannels(source) or 1,
      1,
      8
    )
  job.phase = "build"
  job.progress = 0

  -- GetPeaks 在峰值尚未建立时会返回 0。
  -- 按 REAPER 官方要求先 Begin，再在后续帧 Run，最后 Finish。
  local build_ok, remaining =
    pcall(reaper.PCM_Source_BuildPeaks, source, 0)

  if not build_ok or type(remaining) ~= "number" then
    reaper.PCM_Source_Destroy(source)
    job.source = nil
    return false,
      "峰值构建无法启动：" .. tostring(remaining or "未知错误")
  end

  if remaining == 0 then
    -- Some codecs and freshly built REAPER peak caches report zero samples if
    -- GetPeaks is called in the same defer cycle. Always cross a frame first.
    job.phase = "read_wait"
    job.read_wait_frames = 1
    job.progress = 1
  else
    job.progress =
      clamp(1 - remaining / 100, 0, 0.99)
  end

  return true
end

function step_wave_job(job)
  if not job then
    return "failed", nil, "空任务"
  end

  if not job.source then
    local ok, err = start_wave_job(job)

    if not ok then
      return "failed", nil, err
    end
  end

  if job.phase == "build" then
    local build_ok, remaining =
      pcall(
        reaper.PCM_Source_BuildPeaks,
        job.source,
        1
      )

    if not build_ok or type(remaining) ~= "number" then
      return "failed", nil,
        "峰值构建中断：" .. tostring(remaining or "未知错误")
    end

    job.progress =
      clamp(1 - remaining / 100, 0, 0.99)

    if remaining ~= 0 then
      return "working"
    end

    local finish_ok, finish_error =
      pcall(reaper.PCM_Source_BuildPeaks, job.source, 2)
    if not finish_ok then
      return "failed", nil,
        "峰值构建收尾失败：" .. tostring(finish_error)
    end

    job.phase = "read_wait"
    job.read_wait_frames = 1
    job.progress = 1
  end

  if job.phase == "read_wait" then
    if (job.read_wait_frames or 0) > 0 then
      job.read_wait_frames = job.read_wait_frames - 1
      return "working"
    end
    job.phase = "read"
  end

  if job.phase == "read" then
    local waveform, read_error, read_detail =
      read_waveform_from_source(
        job.source,
        job.duration,
        job.channels,
        job.points,
        job.preserve_channels,
        job.spectral
      )

    if waveform then
      destroy_wave_job(job)
      return "done", waveform
    end

    job.read_attempts = (job.read_attempts or 0) + 1
    job.last_read_error = read_error or "峰值读取为空"
    job.last_read_detail = read_detail or ""

    if job.read_attempts < WAVE_READ_RETRY_LIMIT then
      if job.read_attempts == WAVE_READ_REOPEN_ATTEMPT
        and (job.reopen_count or 0) < WAVE_READ_REOPEN_LIMIT then
        destroy_wave_job(job)
        job.reopen_count = (job.reopen_count or 0) + 1
        job.phase = nil
        job.progress = 0.5
      else
        job.phase = "read_wait"
        job.read_wait_frames = 1
      end
      return "working"
    end

    destroy_wave_job(job)
    return "failed", nil,
      string.format(
        "%s（已重试 %d 次，返回 %s）",
        job.last_read_error,
        job.read_attempts,
        job.last_read_detail ~= "" and job.last_read_detail or "未知"
      )
  end

  return "working"
end

function memory_wave_key(asset, points, preserve_channels, spectral)
  return wave_cache_key(asset, points, preserve_channels, spectral)
end

function store_wave_memory(key, waveform)
  state.wave_clock = state.wave_clock + 1

  if not state.wave_cache[key] then
    state.wave_cache_count =
      state.wave_cache_count + 1
  end

  state.wave_cache[key] = {
    waveform = waveform,
    used = state.wave_clock,
  }

  while state.wave_cache_count
    > MAX_WAVE_MEMORY do

    local oldest_key = nil
    local oldest_use = math.huge

    for candidate, entry in pairs(state.wave_cache) do
      if entry.used < oldest_use then
        oldest_key = candidate
        oldest_use = entry.used
      end
    end

    if not oldest_key then
      break
    end

    state.wave_cache[oldest_key] = nil
    state.wave_cache_count =
      state.wave_cache_count - 1
  end
end

function queue_wave(asset, points, priority, preserve_channels, spectral)
  if asset.wave_error then
    return nil
  end

  preserve_channels = preserve_channels == true
  spectral = spectral == true

  local key = memory_wave_key(asset, points, preserve_channels, spectral)
  local cached = state.wave_cache[key]

  state.wave_clock = state.wave_clock + 1

  if cached then
    cached.used = state.wave_clock
    return cached.waveform
  end

  if not state.wave_checked[key] then
    state.wave_checked[key] = true

    local disk_wave =
      load_wave_from_disk(asset, points, preserve_channels, spectral)

    if disk_wave then
      store_wave_memory(key, disk_wave)
      return disk_wave
    end
  end

  if not state.wave_queued[key] then
    if #state.wave_queue >= MAX_WORK_QUEUE
      and not priority then
      return nil
    end

    state.wave_queued[key] = true

    local job = {
      key = key,
      asset = asset,
      points = points,
      preserve_channels = preserve_channels,
      spectral = spectral,
    }

    if priority then
      table.insert(state.wave_queue, 1, job)
    else
      state.wave_queue[#state.wave_queue + 1] = job
    end
  end

  return nil
end

function process_wave_queue()
  if state.import_session
    or state.precache_session then
    return
  end

  if not can_run_heavy_job() then
    return
  end

  local now = reaper.time_precise()

  if now < state.next_wave_job then
    return
  end

  if not state.wave_active then
    local job = table.remove(state.wave_queue, 1)

    if not job then
      return
    end

    state.wave_active = job
    job.job_token =
      Jobs.begin(
        "waveform",
        "waveform_reader",
        true
      )
  end

  local job = state.wave_active
  local result, waveform, err =
    step_wave_job(job)

  if result == "done" then
    job.asset.wave_error = nil
    clear_failed_task(job.asset)
    store_wave_memory(job.key, waveform)
    save_wave_to_disk(
      job.asset,
      job.points,
      waveform,
      job.preserve_channels,
      job.spectral
    )

    state.wave_queued[job.key] = nil
    state.wave_active = nil
    Jobs.finish(job.job_token, true)
  elseif result == "failed" then
    destroy_wave_job(job)
    job.asset.wave_error = tostring(err or "波形建立失败")
    record_failed_task(job.asset, "waveform", job.asset.wave_error)
    state.wave_queued[job.key] = nil
    state.wave_active = nil
    Jobs.finish(job.job_token, false, err)
    set_status(
      "波形建立失败："
        .. basename(job.asset.path)
        .. "（"
        .. tostring(err)
        .. "）",
      true
    )
  end

  state.next_wave_job = now + WAVE_INTERVAL
end

function wave_cache_file_exists(asset, points, preserve_channels)
  return load_wave_from_disk(
    asset,
    points,
    preserve_channels
  ) ~= nil
end

function start_wave_precache(points, scope)
  if state.scan or state.import_session then
    set_status(
      "请等待当前扫描或导入完成后再预缓存",
      true
    )
    return
  end

  if state.precache_session then
    set_status(
      "高精度波形预缓存已经在运行",
      true
    )
    return
  end

  points =
    tonumber(points) == 2048 and 2048 or 4096

  local job_token =
    Jobs.begin("wave_precache", "catalog_exclusive", false)

  if not job_token then
    set_status("另一个维护任务正在运行", true)
    return
  end

  state.precache_cancel_requested = false
  scope = scope or "all"
  state.precache_session = {
    phase = "collect",
    source = state.assets,
    source_total = #state.assets,
    collect_index = 1,
    filter_root = scope == "current" and state.root_filter or nil,
    filter_library_id = scope == "current"
      and not state.root_filter and state.library_filter_id or nil,
    assets = {},
    total = 0,
    index = 1,
    generated = 0,
    cached = 0,
    failed = 0,
    points = points,
    preserve_channels = state.multichannel_waveform,
    scope = scope,
    current = nil,
    started = reaper.time_precise(),
    job_token = job_token,
  }

  set_status(
    string.format(
      "正在整理高精度波形预缓存范围：0 / %d",
      #state.assets
    )
  )
end

function finish_wave_precache()
  local session = state.precache_session

  if not session then
    return
  end

  local elapsed =
    reaper.time_precise() - session.started

  set_status(
    string.format(
      "预缓存完成：新生成 %d，已有缓存 %d，失败 %d，%.1f 秒",
      session.generated,
      session.cached,
      session.failed,
      elapsed
    ),
    session.failed > 0
  )

  state.precache_session = nil
  state.precache_cancel_requested = false
  Jobs.finish(session.job_token, true)
end

function cancel_wave_precache()
  local session = state.precache_session

  if not session then
    return
  end

  if session.current then
    destroy_wave_job(session.current)
  end

  state.precache_session = nil
  state.precache_cancel_requested = false
  Jobs.cancel(session.job_token)
  Jobs.finish(session.job_token, true, "canceled")
  set_status("已取消高精度波形预缓存")
end

function process_wave_precache()
  local session = state.precache_session

  if not session then
    return
  end

  if state.precache_cancel_requested then
    cancel_wave_precache()
    return
  end

  if session.job_token
    and session.job_token.cancel_requested then
    cancel_wave_precache()
    return
  end

  if not can_run_heavy_job() then
    return
  end

  local now = reaper.time_precise()

  if session.phase == "collect" then
    local processed = 0
    local deadline = now + PRECACHE_FRAME_BUDGET
    while session.collect_index <= session.source_total
      and processed < PRECACHE_COLLECT_FILES_PER_FRAME
      and reaper.time_precise() < deadline do
      local asset = session.source[session.collect_index]
      session.collect_index = session.collect_index + 1
      processed = processed + 1
      local include = asset and asset.ready
      if include and session.filter_root then
        include = path_is_inside(asset.path, session.filter_root)
      elseif include and session.filter_library_id then
        include = asset.library_id == session.filter_library_id
      end
      if include and reaper.file_exists(asset.path) then
        session.assets[#session.assets + 1] = asset
      end
    end
    if session.collect_index > session.source_total then
      session.source = nil
      session.phase = "precache"
      session.total = #session.assets
      if session.total == 0 then
        state.precache_session = nil
        state.precache_cancel_requested = false
        Jobs.finish(session.job_token, true)
        set_status("当前范围没有可预缓存的素材", true)
      else
        set_status(string.format(
          "开始预缓存 %d 个素材的 %d 点高精度波形",
          session.total,
          session.points
        ))
      end
    end
    return
  end

  if now < state.next_wave_job then
    return
  end

  if not session.current then
    local probed = 0
    local deadline = now + PRECACHE_FRAME_BUDGET
    while session.index <= session.total
      and probed < PRECACHE_CACHE_PROBES_PER_FRAME
      and reaper.time_precise() < deadline do
      local asset =
        session.assets[session.index]
      probed = probed + 1

      if wave_cache_file_exists(
        asset,
        session.points,
        session.preserve_channels
      ) then
        session.cached =
          session.cached + 1
        session.index =
          session.index + 1
      else
        session.current = {
          key =
            memory_wave_key(
              asset,
              session.points,
              session.preserve_channels
            ),
          asset = asset,
          points = session.points,
          preserve_channels = session.preserve_channels,
          progress = 0,
        }
        break
      end
    end

    if not session.current
      and session.index > session.total then
      finish_wave_precache()
      return
    end
    if not session.current then
      return
    end
  end

  local job = session.current
  local result, waveform =
    step_wave_job(job)

  if result == "done" then
    save_wave_to_disk(
      job.asset,
      job.points,
      waveform,
      session.preserve_channels
    )

    if state.selected_path
      and path_key(state.selected_path)
        == path_key(job.asset.path) then
      store_wave_memory(
        job.key,
        waveform
      )
    end

    session.generated =
      session.generated + 1
    session.index =
      session.index + 1
    session.current = nil
  elseif result == "failed" then
    destroy_wave_job(job)
    session.failed =
      session.failed + 1
    session.index =
      session.index + 1
    session.current = nil
  end

  state.next_wave_job =
    now + WAVE_INTERVAL
end

function clear_wave_cache()
  reset_wave_cache_runtime()

  while true do
    local file =
      reaper.EnumerateFiles(
        WAVE_CACHE_DIR,
        0
      )

    if not file then
      break
    end

    os.remove(join_path(WAVE_CACHE_DIR, file))
  end

  set_status("已清空波形缓存")
end

function validate_wave_cache_file(path)
  local file = io.open(path, "rb")

  if not file then
    return false, "无法打开"
  end

  local header = file:read("*l") or ""
  local version, count_text, channels_text =
    header:match("^(RWF[34])%s+(%d+)%s+(%d+)$")
  local expected

  if version == "RWF3" or version == "RWF4" then
    local count = tonumber(count_text) or 0
    local channels = tonumber(channels_text) or 0

    if count < 1 or count > LARGE_WAVE_MAX_POINTS
      or channels < 1 or channels > 8 then
      file:close()
      return false, version .. " 头部无效"
    end

    expected = count * channels * 2
      + (version == "RWF4" and count * 4 or 0)
  else
    version, count_text = header:match("^(RWF2)%s+(%d+)$")

    if version == "RWF2" then
      local count = tonumber(count_text) or 0

      if count < 1 or count > LARGE_WAVE_MAX_POINTS then
        file:close()
        return false, "RWF2 头部无效"
      end

      expected = count * 2
    else
      local count = tonumber(header)

      if not count or count < 1 or count > LARGE_WAVE_MAX_POINTS then
        file:close()
        return false, "未知缓存格式"
      end

      expected = count
    end
  end

  local data_start = file:seek() or 0
  local total_size = file:seek("end") or 0
  file:close()

  if total_size - data_start ~= expected then
    return false, "缓存长度不匹配"
  end

  return true
end

function start_wave_cache_verification()
  if state.cache_verify_session then
    set_status("波形缓存检查已经在运行", true)
    return
  end

  if state.scan or state.import_session or state.precache_session then
    set_status("请等待当前后台任务完成", true)
    return
  end

  local job_token =
    Jobs.begin("cache_verify", "catalog_exclusive", false)

  if not job_token then
    set_status("另一个维护任务正在运行", true)
    return
  end

  local files = {}
  local index = 0

  while true do
    local filename = reaper.EnumerateFiles(WAVE_CACHE_DIR, index)

    if not filename then
      break
    end

    if safe_lower(extension(filename)) == "rwf" then
      files[#files + 1] = filename
    end

    index = index + 1
  end

  state.cache_verify_session = {
    files = files,
    total = #files,
    index = 1,
    valid = 0,
    invalid = 0,
    started = reaper.time_precise(),
    job_token = job_token,
  }

  set_status(string.format("开始检查 %d 个波形缓存", #files))
end

function process_wave_cache_verification()
  local session = state.cache_verify_session

  if not session or not can_run_heavy_job() then
    return
  end

  if session.job_token
    and session.job_token.cancel_requested then
    state.cache_verify_session = nil
    Jobs.finish(session.job_token, true, "canceled")
    return
  end

  for _ = 1, CACHE_VERIFY_FILES_PER_FRAME do
    local filename = session.files[session.index]

    if not filename then
      local elapsed = reaper.time_precise() - session.started
      local invalid = session.invalid
      state.cache_verify_session = nil
      Jobs.finish(session.job_token, true)
      reset_wave_cache_runtime()
      set_status(
        string.format(
          "缓存检查完成：有效 %d，隔离损坏 %d，%.1f 秒",
          session.valid,
          invalid,
          elapsed
        ),
        invalid > 0
      )
      return
    end

    local path = join_path(WAVE_CACHE_DIR, filename)
    local valid = validate_wave_cache_file(path)

    if valid then
      session.valid = session.valid + 1
    else
      local quarantine = join_path(
        CACHE_QUARANTINE_DIR,
        os.date("%Y%m%d_%H%M%S_") .. filename
      )

      if copy_file_streaming(path, quarantine) then
        os.remove(path)
      end

      session.invalid = session.invalid + 1
    end

    session.index = session.index + 1
  end
end

----------------------------------------------------------------
-- Import preparation pipeline
----------------------------------------------------------------

function finish_import_session()
  local session = state.import_session

  if not session then
    return
  end

  local elapsed =
    reaper.time_precise() - session.started

  state.import_session = nil
  state.import_cancel_requested = false
  state.results_dirty = true
  mark_database_snapshot_dirty()
  state.clear_scan_checkpoint_after_database_save = true

  Jobs.finish(session.job_token, true)
  save_database_changes()
  start_failed_tasks_save()

  if session.silent then
    set_status(
      string.format(
        "后台更新：新增 %d 个，移除 %d 个，失败 %d 个",
        session.done - session.failed,
        session.removed or 0,
        session.failed
      ),
      session.failed > 0
    )
  else
    set_status(
      string.format(
        "导入完成：%d 个可用，%d 个失败，%.1f 秒",
        session.done - session.failed,
        session.failed,
        elapsed
      ),
      session.failed > 0
    )
  end
end

function cancel_import_session()
  local session = state.import_session

  if not session then
    return
  end

  if session.phase ~= "cancel_cleanup"
    and session.phase ~= "cancel_rebuild" then
    if session.current and session.current.wave_job then
      destroy_wave_job(session.current.wave_job)
    end
    session.current = nil
    session.phase = "cancel_cleanup"
    session.cleanup_index = 1
    Jobs.cancel(session.job_token)
    set_status("正在取消导入并整理索引…")
  end

  if session.phase == "cancel_cleanup" then
    local last = math.min(
      #session.assets,
      session.cleanup_index + IMPORT_FINALIZE_ASSETS_PER_FRAME - 1
    )
    for index = session.cleanup_index, last do
      local asset = session.assets[index]
      if asset then
        if not asset.ready then
          state.by_path[path_key(asset.path)] = nil
        else
          asset.pending_batch = nil
        end
      end
    end
    session.cleanup_index = last + 1
    if session.cleanup_index <= #session.assets then return end
    session.phase = "cancel_rebuild"
    session.prune_job = new_catalog_prune_job(state.by_path)
    session.cancel_rebuild_total = #state.assets
  end

  local complete = step_catalog_prune_job(
    session.prune_job,
    IMPORT_FINALIZE_ASSETS_PER_FRAME,
    function() return false end
  )
  if not complete then return end

  state.assets = session.prune_job.kept
  state.database_ordered_assets = nil
  state.results_dirty = true
  invalidate_library_counts()
  invalidate_folder_navigation()
  state.import_session = nil
  state.import_cancel_requested = false
  mark_database_snapshot_dirty()
  state.clear_scan_checkpoint_after_database_save = true
  Jobs.finish(session.job_token, true, "canceled")
  save_database_changes()
  set_status("已取消导入；已完成的素材保留")
end

function process_import_finalize(session)
  session.finalize_index = session.finalize_index or 1
  local last = math.min(
    #session.assets,
    session.finalize_index + IMPORT_FINALIZE_ASSETS_PER_FRAME - 1
  )
  for index = session.finalize_index, last do
    local asset = session.assets[index]
    if asset then asset.pending_batch = nil end
  end
  session.finalize_index = last + 1
  if session.finalize_index <= #session.assets then
    return false
  end
  finish_import_session()
  return true
end

function process_import_session()
  local session = state.import_session

  if not session then
    return
  end

  if session.job_token
    and session.job_token.cancel_requested then
    cancel_import_session()
    return
  end

  local checkpoint_now = reaper.time_precise()

  if checkpoint_now - (state.import_checkpoint_last_at or 0)
      >= IMPORT_CHECKPOINT_INTERVAL then
    save_database_changes()
    start_failed_tasks_save()
    state.import_checkpoint_last_at = checkpoint_now
  end

  if state.import_cancel_requested then
    cancel_import_session()
    return
  end

  if session.phase == "finalize" then
    process_import_finalize(session)
    return
  end

  if not can_run_heavy_job() then
    return
  end

  if not session.current then
    local asset =
      session.assets[session.done + 1]

    if not asset then
      session.phase = "finalize"
      session.finalize_index = 1
      set_status("导入分析完成，正在整理索引…")
      return
    end

    session.current = {
      asset = asset,
      phase = "metadata",
      progress = 0,
    }
  end

  local current = session.current
  local asset = current.asset

  if current.phase == "metadata" then
    current.progress = 0.08

    if not asset.indexed then
      local ok = index_asset(asset)

      if not ok then
        asset.wave_error = "媒体文件无法读取"
        record_failed_task(asset, "metadata", asset.wave_error)
        asset.ready = true
        session.failed = session.failed + 1
        session.done = session.done + 1
        session.current = nil
        mark_asset_database_change(asset)
        return
      end
    end

    local key =
      memory_wave_key(
        asset,
        state.mini_wave_points
      )

    local cached = state.wave_cache[key]
      and state.wave_cache[key].waveform
      or load_wave_from_disk(
        asset,
        state.mini_wave_points
      )

    if cached then
      store_wave_memory(key, cached)
      asset.ready = true
      asset.wave_error = nil
      clear_failed_task(asset)
      session.done = session.done + 1
      session.current = nil
      mark_asset_database_change(asset)
      return
    end

    current.wave_job = {
      key = key,
      asset = asset,
      points = state.mini_wave_points,
      progress = 0,
    }

    current.phase = "wave"
  end

  if current.phase == "wave" then
    local result, waveform, err =
      step_wave_job(current.wave_job)

    current.progress =
      0.10
      + 0.90
        * (current.wave_job.progress or 0)

    if result == "done" then
      store_wave_memory(
        current.wave_job.key,
        waveform
      )

      save_wave_to_disk(
        asset,
        state.mini_wave_points,
        waveform
      )

      asset.ready = true
      asset.wave_error = nil
      clear_failed_task(asset)
      session.done = session.done + 1
      session.current = nil
      mark_asset_database_change(asset)
    elseif result == "failed" then
      destroy_wave_job(current.wave_job)
      asset.ready = true
      asset.wave_error = tostring(err or "波形建立失败")
      record_failed_task(asset, "waveform", asset.wave_error)
      session.failed = session.failed + 1
      session.done = session.done + 1
      session.current = nil
      mark_asset_database_change(asset)
    end
  end
end


----------------------------------------------------------------
-- Preview
----------------------------------------------------------------

function destroy_preview_source_list(sources)
  if not sources then
    return
  end

  for _, source in ipairs(sources) do
    if source then
      reaper.PCM_Source_Destroy(source)
    end
  end
end

function cleanup_retired_preview_sources(force)
  local pending =
    state.retired_preview_sources or {}
  local now = reaper.time_precise()
  local keep = {}

  for _, retired in ipairs(pending) do
    if force or now >= retired.release_at then
      destroy_preview_source_list(retired.sources)
    else
      keep[#keep + 1] = retired
    end
  end

  state.retired_preview_sources = keep
end

function destroy_preview_sources(after_fade)
  local sources = state.preview_sources
  state.preview_sources = nil

  if not sources then
    return
  end

  if after_fade then
    state.retired_preview_sources =
      state.retired_preview_sources or {}

    state.retired_preview_sources[
      #state.retired_preview_sources + 1
    ] = {
      sources = sources,
      -- Keep SECTION and file sources alive beyond SWS's 25 ms fade.
      -- Destroying them in the same UI frame truncates the audio-thread
      -- fade and is audible as a click when Space is tapped repeatedly.
      release_at = reaper.time_precise() + 0.100,
    }
  else
    destroy_preview_source_list(sources)
  end
end

function stop_preview()
  local preview_job_token = state.preview_job_token
  state.preview_job_token = nil

  if state.preview_companion
    and type(reaper.CF_Preview_Stop) == "function" then
    pcall(
      reaper.CF_Preview_Stop,
      state.preview_companion
    )
  end

  if state.preview
    and type(reaper.CF_Preview_Stop) == "function" then
    pcall(reaper.CF_Preview_Stop, state.preview)
  elseif type(reaper.CF_Preview_StopAll) == "function" then
    pcall(reaper.CF_Preview_StopAll)
  end

  state.preview = nil
  state.preview_companion = nil
  state.preview_source = nil
  state.preview_path = nil
  state.preview_position = 0
  state.preview_length = 0
  state.preview_map_start = 0
  state.preview_map_span = 1
  state.preview_map_reverse = false
  state.preview_percent = 0
  destroy_preview_sources(true)

  if preview_job_token then
    Jobs.cancel(preview_job_token)
    Jobs.finish(preview_job_token, true, "stopped")
  end
end

function request_preview_stop()
  if not state.preview then
    stop_preview()
    return
  end

  -- CF_Preview_Stop performs its fade on the audio thread using
  -- D_FADEOUTLEN. A UI-frame volume ramp produces only a handful of
  -- coarse gain steps and can itself become audible when Space is tapped
  -- repeatedly, so stopping is deliberately delegated to SWS.
  pcall(
    reaper.CF_Preview_SetValue,
    state.preview,
    "B_LOOP",
    0
  )

  if state.preview_companion then
    pcall(
      reaper.CF_Preview_SetValue,
      state.preview_companion,
      "B_LOOP",
      0
    )
  end

  stop_preview()
end

function clear_row_selection()
  state.selected_set = {}
  state.selected_index = 0
  state.selected_path = nil
  state.selection_anchor = 0
end

function is_row_selected(asset)
  return asset
    and state.selected_set[path_key(asset.path)] == true
end

function selected_assets()
  local assets = {}

  for _, asset in ipairs(state.results) do
    if is_row_selected(asset) then
      assets[#assets + 1] = asset
    end
  end

  return assets
end

function selected_count()
  local count = 0

  for _ in pairs(state.selected_set) do
    count = count + 1
  end

  return count
end

function selected_asset()
  if state.selected_path then
    return state.by_path[path_key(state.selected_path)]
  end

  if state.selected_index >= 1 then
    return state.results[state.selected_index]
  end

  return nil
end

function select_all_results()
  state.selected_set = {}

  for _, asset in ipairs(state.results) do
    state.selected_set[path_key(asset.path)] = true
  end

  if #state.results > 0 then
    state.selected_index = 1
    state.selected_path = state.results[1].path
    state.selection_anchor = 1
  end

  set_status(
    string.format(
      "已选择 %d 个素材",
      #state.results
    )
  )
end

function has_selection()
  return state.region_end - state.region_start
      > 0.002
    and state.region_end - state.region_start
      < 0.998
end

function preview_uses_centered_mono(asset)
  return preview_asset_channel_count(asset) <= 2
    and (
      state.preview_channel_mode == "left"
      or state.preview_channel_mode == "right"
      or state.preview_channel_mode == "mono"
    )
end

function configure_preview_instance(
  preview,
  mono_output_channel
)
  if not preview then
    return
  end

  reaper.CF_Preview_SetValue(
    preview,
    "D_VOLUME",
    db_to_amp(
      state.gain_db
        + state.preview_match_offset_db
    )
  )

  apply_preview_channel_mode(
    preview,
    mono_output_channel
  )

  reaper.CF_Preview_SetValue(
    preview,
    "D_PITCH",
    state.pitch
  )

  reaper.CF_Preview_SetValue(
    preview,
    "D_PLAYRATE",
    state.rate
  )

  reaper.CF_Preview_SetValue(
    preview,
    "B_PPITCH",
    state.preserve_pitch and 1 or 0
  )

  reaper.CF_Preview_SetValue(
    preview,
    "B_LOOP",
    state.loop and 1 or 0
  )

  reaper.CF_Preview_SetValue(
    preview,
    "D_FADEINLEN",
    0.020
  )

  reaper.CF_Preview_SetValue(
    preview,
    "D_FADEOUTLEN",
    0.025
  )
end

function play_preview(
  asset,
  start_percent,
  use_selection
)
  if state.root_removal_session then
    set_status("请等待来源移除完成后再试听", true)
    return
  end
  asset = asset or selected_asset()

  if not asset then
    return
  end

  if not reaper.file_exists(asset.path) then
    set_status("文件不存在：" .. asset.path, true)
    return
  end

  queue_metadata(asset, true)
  stop_preview()

  if type(reaper.CF_CreatePreview) ~= "function" then
    reaper.OpenMediaExplorer(asset.path, true)
    state.preview_backend = "Media Explorer"
    record_preview_history(asset)

    if start_percent
      and start_percent > 0 then
      set_status(
        "未安装 SWS：Media Explorer 无法由脚本精确定位到点击位置",
        true
      )
    else
      set_status("由 Media Explorer 试听")
    end

    return
  end

  local source =
    reaper.PCM_Source_CreateFromFile(asset.path)

  if not source then
    set_status("无法建立试听源", true)
    return
  end

  local sources = { source }
  local preview_source = source
  local duration, is_qn =
    reaper.GetMediaSourceLength(source)

  duration =
    is_qn and 0 or (duration or asset.duration or 0)

  local selection =
    use_selection and has_selection()

  -- Always wrap audio previews in a SECTION source when SWS supports it.
  -- The section's source-boundary fade protects files whose first sample is
  -- not near zero. This is materially different from a UI volume animation:
  -- it is evaluated in the audio source path before the first audible buffer.
  if type(reaper.CF_PCM_Source_SetSectionInfo)
      == "function" then

    local section =
      reaper.PCM_Source_CreateFromType("SECTION")

    if section then
      local offset =
        selection
          and duration * state.region_start
          or 0

      local length =
        selection
          and duration
            * (state.region_end - state.region_start)
          or duration

      local call_ok, section_ok =
        pcall(
          reaper.CF_PCM_Source_SetSectionInfo,
          section,
          source,
          offset,
          length,
          state.reverse,
          0.020
        )

      -- 兼容不接受 fade 参数的旧版 SWS。
      if not call_ok then
        call_ok, section_ok =
          pcall(
            reaper.CF_PCM_Source_SetSectionInfo,
            section,
            source,
            offset,
            length,
            state.reverse
          )
      end

      if call_ok and section_ok then
        preview_source = section
        sources[#sources + 1] = section
      else
        reaper.PCM_Source_Destroy(section)
      end
    end
  end

  local preview =
    reaper.CF_CreatePreview(preview_source)

  if not preview then
    for _, item in ipairs(sources) do
      reaper.PCM_Source_Destroy(item)
    end

    set_status("SWS 试听对象创建失败", true)
    return
  end

  state.preview_match_offset_db =
    loudness_match_offset_db(asset)

  state.preview_source = preview_source
  configure_preview_instance(preview, 0)

  local companion = nil

  if preview_uses_centered_mono(asset) then
    companion =
      reaper.CF_CreatePreview(preview_source)

    if not companion then
      pcall(reaper.CF_Preview_Stop, preview)
      state.preview_source = nil

      for _, item in ipairs(sources) do
        reaper.PCM_Source_Destroy(item)
      end

      set_status(
        "无法建立双声道监听镜像",
        true
      )
      return
    end

    configure_preview_instance(companion, 1)
  end

  local seek_position = 0

  if not selection and start_percent then
    seek_position =
      clamp(start_percent, 0, 0.9999)
        * duration
  end

  if seek_position > 0 then
    reaper.CF_Preview_SetValue(
      preview,
      "D_POSITION",
      seek_position
    )

    if companion then
      reaper.CF_Preview_SetValue(
        companion,
        "D_POSITION",
        seek_position
      )
    end
  end

  local played =
    reaper.CF_Preview_Play(preview)

  local companion_played =
    not companion
      or reaper.CF_Preview_Play(companion)

  if not played or not companion_played then
    if played then
      pcall(reaper.CF_Preview_Stop, preview)
    end

    if companion then
      pcall(reaper.CF_Preview_Stop, companion)
    end

    state.preview_source = nil

    for _, item in ipairs(sources) do
      reaper.PCM_Source_Destroy(item)
    end

    set_status("试听启动失败", true)
    return
  end

  state.preview = preview
  state.preview_companion = companion
  state.preview_sources = sources
  state.preview_path = asset.path
  state.preview_job_token =
    Jobs.begin(
      "preview",
      "preview_engine",
      true,
      200
    )
  record_preview_history(asset)

  if selection then
    state.preview_map_start = state.region_start
    state.preview_map_span =
      state.region_end - state.region_start
  else
    state.preview_map_start = 0
    state.preview_map_span = 1
  end

  state.preview_map_reverse = state.reverse

  local ok_length, length =
    reaper.CF_Preview_GetValue(
      preview,
      "D_LENGTH",
      0
    )

  state.preview_length =
    selection
      and duration
        * (state.region_end - state.region_start)
      or (ok_length and length or duration)

  set_status(
    start_percent
      and string.format(
        "从 %.1f%% 开始试听：%s",
        start_percent * 100,
        asset.name
      )
      or "试听：" .. asset.name
  )
end

function update_preview_parameters()
  if not state.preview then
    return
  end

  local asset =
    state.preview_path
    and state.by_path[path_key(state.preview_path)]
    or selected_asset()

  state.preview_match_offset_db =
    loudness_match_offset_db(asset)

  local needs_companion =
    preview_uses_centered_mono(asset)

  if needs_companion
    and not state.preview_companion
    and state.preview_source then
    local companion =
      reaper.CF_CreatePreview(state.preview_source)

    if companion then
      configure_preview_instance(companion, 1)

      local ok_position, position =
        reaper.CF_Preview_GetValue(
          state.preview,
          "D_POSITION",
          0
        )

      if reaper.CF_Preview_Play(companion) then
        if ok_position and position then
          reaper.CF_Preview_SetValue(
            companion,
            "D_POSITION",
            position
          )
        end

        state.preview_companion = companion
      else
        pcall(reaper.CF_Preview_Stop, companion)
      end
    end
  elseif not needs_companion
    and state.preview_companion then
    pcall(
      reaper.CF_Preview_Stop,
      state.preview_companion
    )
    state.preview_companion = nil
  end

  configure_preview_instance(state.preview, 0)

  if state.preview_companion then
    configure_preview_instance(
      state.preview_companion,
      1
    )
  end
end

function poll_preview()
  if not state.preview then
    return
  end

  local ok, position =
    reaper.CF_Preview_GetValue(
      state.preview,
      "D_POSITION",
      0
    )

  if not ok then
    if state.preview_companion then
      pcall(
        reaper.CF_Preview_Stop,
        state.preview_companion
      )
    end

    state.preview = nil
    state.preview_companion = nil
    state.preview_source = nil
    state.preview_path = nil
    Jobs.finish(state.preview_job_token, true)
    state.preview_job_token = nil
    destroy_preview_sources()
    return
  end

  state.preview_position = position or 0

  if state.preview_length > 0 then
    local local_percent =
      clamp(
        state.preview_position
          / state.preview_length,
        0,
        1
      )

    if state.preview_map_reverse then
      local_percent = 1 - local_percent
    end

    state.preview_percent =
      clamp(
        state.preview_map_start
          + state.preview_map_span
            * local_percent,
        0,
        1
      )
  end
end

----------------------------------------------------------------
-- Selection, favorites and insertion
----------------------------------------------------------------

function focus_asset(index, auto_play)
  if #state.results == 0 then
    clear_row_selection()
    return
  end

  index = clamp(index, 1, #state.results)
  local asset = state.results[index]
  local changed =
    path_key(state.selected_path or "")
      ~= path_key(asset.path)

  state.selected_index = index
  state.selected_path = asset.path

  if changed then
    state.region_start = 0
    state.region_end = 1
    state.wave_view_start = 0
    state.wave_view_end = 1
    state.wave_pan_last_x = nil
    state.active_region_index = 0
    queue_metadata(asset, true)
    queue_wave(asset, LARGE_WAVE_DEFAULT_POINTS, true)

    if auto_play == nil then
      auto_play = state.auto_preview
    end

    if auto_play then
      play_preview(asset, 0, false)
    end
  end
end

function select_result(index, auto_play)
  clear_row_selection()

  if #state.results == 0 then
    return
  end

  index = clamp(index, 1, #state.results)
  local asset = state.results[index]
  state.selected_set[path_key(asset.path)] = true
  state.selection_anchor = index
  focus_asset(index, auto_play)
end

function select_result_with_modifiers(
  index,
  ctrl,
  shift,
  auto_play
)
  if #state.results == 0 then
    return
  end

  index = clamp(index, 1, #state.results)
  local asset = state.results[index]
  local key = path_key(asset.path)

  if shift and state.selection_anchor > 0 then
    if not ctrl then
      state.selected_set = {}
    end

    local first =
      math.min(state.selection_anchor, index)
    local last =
      math.max(state.selection_anchor, index)

    for position = first, last do
      local range_asset = state.results[position]
      state.selected_set[path_key(range_asset.path)] = true
    end

    focus_asset(index, false)
  elseif ctrl then
    if state.selected_set[key] then
      state.selected_set[key] = nil
    else
      state.selected_set[key] = true
    end

    state.selection_anchor = index
    focus_asset(index, false)
  else
    state.selected_set = { [key] = true }
    state.selection_anchor = index
    focus_asset(index, auto_play)
  end
end

function set_assets_marked(assets, marked)
  if state.root_removal_session then
    set_status("请等待来源移除完成后再修改素材", true)
    return false
  end
  local changed = false

  for _, asset in ipairs(assets or {}) do
    local next_value = marked == true

    if asset.marked ~= next_value then
      asset.marked = next_value
      asset._search_blob = nil
      mark_asset_database_change(asset)
      changed = true
    end
  end

  if changed then
    state.results_dirty = true
    set_status(
      marked
        and "已标记所选素材"
        or "已取消所选素材标记"
    )
  end
end

function toggle_mark(asset)
  if not asset then
    return
  end

  set_assets_marked(
    { asset },
    not asset.marked
  )
end

function toggle_favorite(asset)
  if state.root_removal_session then
    set_status("请等待来源移除完成后再修改收藏", true)
    return
  end
  if not asset then
    return
  end

  local key = path_key(asset.path)

  if state.favorites[key] then
    state.favorites[key] = nil
    set_status("已取消收藏：" .. asset.name)
  else
    state.favorites[key] = true
    set_status("已收藏：" .. asset.name)
  end

  state.config_dirty = true

  if state.view == "favorites" then
    state.results_dirty = true
  end
end

function push_recent(asset, project_action)
  if state.root_removal_session then
    return false
  end
  local key = path_key(asset.path)
  local updated = { asset.path }

  for _, path in ipairs(state.recent) do
    if path_key(path) ~= key
      and #updated < 100 then
      updated[#updated + 1] = path
    end
  end

  state.recent = updated
  asset.used_count =
    (tonumber(asset.used_count) or 0) + 1
  asset.last_used = os.time()

  state.config_dirty = true
  mark_asset_database_change(asset)

  if project_action then
    record_project_usage(asset, project_action)
  end

  if state.view == "recent"
    or state.sort_mode == "used" then
    state.results_dirty = true
  end
end

function take_name(asset)
  local name = strip_extension(asset.name)

  if state.insert_lowercase then
    name = name:lower()
  end

  return state.insert_prefix
    .. name
    .. state.insert_suffix
end

function apply_insert_settings(asset)
  local count =
    reaper.CountSelectedMediaItems(PROJ)

  if count <= 0 then
    return
  end

  local item =
    reaper.GetSelectedMediaItem(
      PROJ,
      count - 1
    )

  local take =
    item and reaper.GetActiveTake(item)

  if not take then
    return
  end

  reaper.SetMediaItemTakeInfo_Value(
    take,
    "D_PITCH",
    state.pitch
  )

  reaper.SetMediaItemTakeInfo_Value(
    take,
    "D_PLAYRATE",
    state.rate
  )

  reaper.SetMediaItemTakeInfo_Value(
    take,
    "B_PPITCH",
    state.preserve_pitch and 1 or 0
  )

  reaper.SetMediaItemTakeInfo_Value(
    take,
    "D_VOL",
    db_to_amp(state.gain_db)
  )

  reaper.GetSetMediaItemTakeInfo_String(
    take,
    "P_NAME",
    take_name(asset),
    true
  )

  local fade =
    math.max(
      0,
      tonumber(state.insert_fade_ms) or 0
    ) / 1000

  reaper.SetMediaItemInfo_Value(
    item,
    "D_FADEINLEN",
    fade
  )

  reaper.SetMediaItemInfo_Value(
    item,
    "D_FADEOUTLEN",
    fade
  )
end

function insert_asset(asset, new_track, bwf)
  if state.root_removal_session then
    set_status("请等待来源移除完成后再插入素材", true)
    return
  end
  asset = asset or selected_asset()

  if not asset then
    return
  end

  if not reaper.file_exists(asset.path) then
    set_status("文件不存在：" .. asset.path, true)
    return
  end

  stop_preview()

  local mode = new_track and 1 or 0

  if bwf then
    mode = mode | 4096
  end

  if state.reverse then
    mode = mode | 8192
  end

  local start_percent = 0
  local end_percent = 1

  if has_selection() then
    start_percent = state.region_start
    end_percent = state.region_end
    mode = mode | 128
  end

  reaper.Undo_BeginBlock2(PROJ)
  reaper.PreventUIRefresh(1)

  local result =
    reaper.InsertMediaSection(
      asset.path,
      mode,
      start_percent,
      end_percent,
      0
    )

  if result >= 0 then
    apply_insert_settings(asset)
    push_recent(asset, "insert")
    reaper.UpdateArrange()
    set_status("已插入：" .. asset.name)
  else
    set_status("插入失败：" .. asset.name, true)
  end

  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock2(
    PROJ,
    "从 PsyReaSFX 插入音频",
    -1
  )
end

----------------------------------------------------------------
-- 0.7 Transfer rendering
----------------------------------------------------------------

function sanitize_transfer_name(value)
  value = trim(tostring(value or ""))
  value = value:gsub("[%z\1-\31]", "_")
  value = value:gsub("[\\/:*?\"<>|]", "_")
  value = value:gsub("%s+", " ")
  value = value:gsub("[%. ]+$", "")
  value = value:gsub("^%s+", "")

  if value == "" then
    value = "untitled"
  end

  if (utf8_length(value) or #value) > 160 then
    value = utf8_prefix(value, 160)
  end

  if state.transfer_lowercase then
    value = value:lower()
  end

  return value
end

function transfer_region_name(asset)
  local regions = asset_regions(asset)
  local active = regions[state.active_region_index or 0]

  if active and trim(active.name or "") ~= "" then
    return active.name
  end

  return has_selection() and "selection" or "full"
end

function transfer_variant_number(value, decimals)
  local format_string = "%." .. tostring(decimals or 2) .. "f"
  local text = string.format(format_string, tonumber(value) or 0)
  text = text:gsub("(%..-)0+$", "%1")
  text = text:gsub("%.$", "")

  if text == "-0" then
    text = "0"
  end

  return text
end

function transfer_variant_token(value, decimals)
  local text = transfer_variant_number(value, decimals)
  text = text:gsub("%+", "")
  text = text:gsub("%-", "m")
  text = text:gsub("%.", "p")
  return text
end

function parse_transfer_variant_values(
  text,
  fallback,
  minimum,
  maximum,
  decimals,
  label
)
  local values = {}
  local seen = {}
  local had_token = false

  for token in tostring(text or ""):gmatch("[^,%s;|]+") do
    had_token = true
    local value = tonumber(token)

    if not value then
      return nil,
        string.format(
          "%s: %s",
          translate_ui_text("无效的变体数值"),
          token
        )
    end

    value = clamp(value, minimum, maximum)
    local scale = 10 ^ (decimals or 2)
    value = math.floor(value * scale + 0.5) / scale
    local key = string.format("%.6f", value)

    if not seen[key] then
      seen[key] = true
      values[#values + 1] = value
    end

    if #values > 16 then
      return nil,
        translate_ui_text("每个变体参数最多允许 16 个数值")
    end
  end

  if not had_token or #values == 0 then
    values[1] = fallback
  end

  table.sort(values)
  return values, nil
end

function build_transfer_variants()
  if not state.transfer_variants_enabled then
    return {
      {
        pitch = state.pitch,
        rate = state.rate,
        gain_db = state.gain_db,
        reverse = state.reverse,
        index = 1,
        count = 1,
        label = "current",
      },
    }, nil
  end

  local pitches, pitch_error =
    parse_transfer_variant_values(
      state.transfer_variant_pitches,
      state.pitch,
      -48,
      48,
      2,
      "Pitch"
    )

  if not pitches then
    return nil, pitch_error
  end

  local rates, rate_error =
    parse_transfer_variant_values(
      state.transfer_variant_rates,
      state.rate,
      0.1,
      4,
      3,
      "Rate"
    )

  if not rates then
    return nil, rate_error
  end

  local gains, gain_error =
    parse_transfer_variant_values(
      state.transfer_variant_gains,
      state.gain_db,
      -60,
      24,
      2,
      "Gain"
    )

  if not gains then
    return nil, gain_error
  end

  local directions =
    state.transfer_variant_include_reverse
      and { false, true }
      or { state.reverse }
  local variants = {}

  for _, pitch in ipairs(pitches) do
    for _, rate in ipairs(rates) do
      for _, gain_db in ipairs(gains) do
        for _, reverse in ipairs(directions) do
          if #variants >= 128 then
            return nil,
              translate_ui_text(
                "变体组合超过 128 个，请减少参数数量"
              )
          end

          local label =
            "p" .. transfer_variant_token(pitch, 2)
              .. "_r" .. transfer_variant_token(rate, 3)
              .. "_g" .. transfer_variant_token(gain_db, 2)
              .. (reverse and "_rev" or "_fwd")

          variants[#variants + 1] = {
            pitch = pitch,
            rate = rate,
            gain_db = gain_db,
            reverse = reverse,
            label = label,
          }
        end
      end
    end
  end

  for index, variant in ipairs(variants) do
    variant.index = index
    variant.count = #variants
  end

  return variants, nil
end

function expand_transfer_template(asset, index, variant)
  local template = state.transfer_template or "{name}"
  local value = template
  variant = variant or {
    pitch = state.pitch,
    rate = state.rate,
    gain_db = state.gain_db,
    reverse = state.reverse,
    index = 1,
    count = 1,
    label = "current",
  }
  local replacements = {
    name = strip_extension(asset.name or ""),
    category = asset.category or "",
    subcategory = asset.subcategory or "",
    library = asset.library or "",
    index = string.format("%02d", tonumber(index) or 1),
    date = os.date("%Y%m%d"),
    region = transfer_region_name(asset),
    pitch = transfer_variant_number(variant.pitch, 2),
    rate = transfer_variant_number(variant.rate, 3),
    gain = transfer_variant_number(variant.gain_db, 2),
    direction = variant.reverse and "reverse" or "normal",
    variant = variant.label or "current",
    variant_index = string.format(
      "%02d",
      tonumber(variant.index) or 1
    ),
  }

  value = value:gsub("{([%w_]+)}", function(key)
    return replacements[key] ~= nil
      and tostring(replacements[key])
      or "{" .. key .. "}"
  end)

  if state.transfer_variants_enabled
    and state.transfer_variant_auto_suffix
    and (variant.count or 1) > 1
    and not template:find("{variant}", 1, true)
    and not template:find("{variant_index}", 1, true)
    and not template:find("{pitch}", 1, true)
    and not template:find("{rate}", 1, true)
    and not template:find("{gain}", 1, true)
    and not template:find("{direction}", 1, true) then
    value = value .. "_" .. tostring(variant.label or "variant")
  end

  return sanitize_transfer_name(value)
end

function transfer_format_info()
  if state.transfer_format == "flac" then
    -- RENDER_FORMAT expects a base64-encoded sink configuration.
    -- "Y2FsZg==" decodes to REAPER's four-byte FLAC sink id, "calf".
    return "flac", "Y2FsZg=="
  end

  if state.transfer_format == "wav16" then
    return "wav", "ZXZhdxAAAQ=="
  elseif state.transfer_format == "wav32" then
    return "wav", "ZXZhdyAAAQ=="
  end

  -- Explicit WAV 24-bit PCM sink configuration.
  return "wav", "ZXZhdxgAAQ=="
end

function transfer_sample_rate(asset)
  if state.transfer_sample_rate == "source" then
    return math.max(0, math.floor(tonumber(asset.sample_rate) or 0))
  end

  return math.max(
    0,
    math.floor(tonumber(state.transfer_sample_rate) or 0)
  )
end

function transfer_channel_count(asset)
  if state.transfer_channels == "mono" then
    return 1
  elseif state.transfer_channels == "stereo" then
    return 2
  end

  return clamp(
    math.floor(tonumber(asset.channels) or 2),
    1,
    64
  )
end

function transfer_normalize_flags()
  local flags = 0

  if state.transfer_normalize == "peak" then
    flags = 1 | 4
  elseif state.transfer_normalize == "true_peak" then
    flags = 1 | 6
  elseif state.transfer_normalize == "rms_i" then
    flags = 1 | 2
  elseif state.transfer_normalize == "lufs_i" then
    flags = 1
  end

  if (tonumber(state.transfer_fade_in_ms) or 0) > 0 then
    flags = flags | 512
  end

  if (tonumber(state.transfer_fade_out_ms) or 0) > 0 then
    flags = flags | 1024
  end

  return flags
end

function resolve_transfer_output(asset, index, variant)
  local extension_name = transfer_format_info()
  local base = expand_transfer_template(asset, index, variant)
  local directory = normalize_slashes(trim(state.transfer_dir or ""))

  if directory == "" then
    directory = DEFAULT_TRANSFER_DIR
  end

  local candidate = join_path(
    directory,
    base .. "." .. extension_name
  )

  if not reaper.file_exists(candidate) then
    return candidate, "new"
  end

  if state.transfer_collision == "skip" then
    return nil, "skip", candidate
  elseif state.transfer_collision == "overwrite" then
    return candidate, "overwrite"
  end

  local suffix = 2

  while suffix < 10000 do
    local next_path = join_path(
      directory,
      string.format(
        "%s_%02d.%s",
        base,
        suffix,
        extension_name
      )
    )

    if not reaper.file_exists(next_path) then
      return next_path, "increment"
    end

    suffix = suffix + 1
  end

  return nil, "error", candidate
end

function capture_transfer_context()
  local context = {
    cursor = reaper.GetCursorPositionEx(PROJ),
    dirty = reaper.GetSetProjectInfo(PROJ, "DIRTY", 0, false),
    selected_items = {},
    selected_tracks = {},
    render_numbers = {},
    render_strings = {},
  }

  local time_start, time_end =
    reaper.GetSet_LoopTimeRange2(
      PROJ,
      false,
      false,
      0,
      0,
      false
    )

  context.time_start = time_start
  context.time_end = time_end

  for index = 0, reaper.CountSelectedMediaItems(PROJ) - 1 do
    context.selected_items[#context.selected_items + 1] =
      reaper.GetSelectedMediaItem(PROJ, index)
  end

  local master = reaper.GetMasterTrack(PROJ)

  if master
    and reaper.IsTrackSelected(master) then
    context.selected_tracks[#context.selected_tracks + 1] = master
  end

  for index = 0, reaper.CountTracks(PROJ) - 1 do
    local track = reaper.GetTrack(PROJ, index)

    if track and reaper.IsTrackSelected(track) then
      context.selected_tracks[#context.selected_tracks + 1] = track
    end
  end

  local number_keys = {
    "RENDER_SETTINGS",
    "RENDER_BOUNDSFLAG",
    "RENDER_CHANNELS",
    "RENDER_SRATE",
    "RENDER_STARTPOS",
    "RENDER_ENDPOS",
    "RENDER_TAILFLAG",
    "RENDER_TAILMS",
    "RENDER_ADDTOPROJ",
    "RENDER_DITHER",
    "RENDER_NORMALIZE",
    "RENDER_NORMALIZE_TARGET",
    "RENDER_BRICKWALL",
    "RENDER_FADEIN",
    "RENDER_FADEOUT",
    "RENDER_FADEINSHAPE",
    "RENDER_FADEOUTSHAPE",
  }

  for _, key in ipairs(number_keys) do
    context.render_numbers[key] =
      reaper.GetSetProjectInfo(PROJ, key, 0, false)
  end

  local string_keys = {
    "RENDER_FILE",
    "RENDER_PATTERN",
    "RENDER_FORMAT",
    "RENDER_FORMAT2",
  }

  for _, key in ipairs(string_keys) do
    local _, value =
      reaper.GetSetProjectInfo_String(PROJ, key, "", false)
    context.render_strings[key] = value or ""
  end

  return context
end

function restore_transfer_context(context, temporary_track)
  if temporary_track
    and reaper.ValidatePtr2(PROJ, temporary_track, "MediaTrack*") then
    reaper.DeleteTrack(temporary_track)
  end

  for key, value in pairs(context.render_numbers or {}) do
    reaper.GetSetProjectInfo(PROJ, key, value, true)
  end

  for key, value in pairs(context.render_strings or {}) do
    reaper.GetSetProjectInfo_String(PROJ, key, value, true)
  end

  reaper.SelectAllMediaItems(PROJ, false)

  local master = reaper.GetMasterTrack(PROJ)

  if master then
    reaper.SetTrackSelected(master, false)
  end

  for index = 0, reaper.CountTracks(PROJ) - 1 do
    reaper.SetTrackSelected(reaper.GetTrack(PROJ, index), false)
  end

  for _, item in ipairs(context.selected_items or {}) do
    if reaper.ValidatePtr2(PROJ, item, "MediaItem*") then
      reaper.SetMediaItemSelected(item, true)
    end
  end

  for _, track in ipairs(context.selected_tracks or {}) do
    if reaper.ValidatePtr2(PROJ, track, "MediaTrack*") then
      reaper.SetTrackSelected(track, true)
    end
  end

  reaper.SetEditCurPos2(
    PROJ,
    context.cursor or 0,
    false,
    false
  )

  reaper.GetSet_LoopTimeRange2(
    PROJ,
    true,
    false,
    context.time_start or 0,
    context.time_end or 0,
    false
  )

  reaper.GetSetProjectInfo(
    PROJ,
    "DIRTY",
    context.dirty or 0,
    true
  )

  reaper.UpdateArrange()
end

function detect_transfer_tail_end(
  asset,
  source,
  duration,
  selection_end,
  reverse
)
  if not state.transfer_smart_tail
    or reverse
    or not source
    or duration <= 0
    or selection_end >= 0.9999 then
    return selection_end, 0
  end

  local maximum_seconds =
    math.max(
      0,
      tonumber(state.transfer_tail_max_ms) or 0
    ) / 1000

  if maximum_seconds <= 0 then
    return selection_end, 0
  end

  local maximum_end =
    math.min(
      1,
      selection_end + maximum_seconds / duration
    )

  if maximum_end <= selection_end then
    return selection_end, 0
  end

  local points = 4096
  local waveform =
    load_wave_from_disk(asset, points, false)

  if not waveform then
    points =
      clamp(
        math.ceil(duration * 220),
        2048,
        8192
      )
    waveform =
      read_waveform_from_source(
        source,
        duration,
        tonumber(asset.channels) or 1,
        points,
        false
      )
  end

  if not waveform
    or not waveform.peaks
    or (waveform.count or 0) <= 0 then
    return selection_end, 0
  end

  local count = waveform.count
  local threshold =
    db_to_amp(
      clamp(
        tonumber(state.transfer_tail_threshold_db)
          or -60,
        -96,
        -18
      )
    )
  local first_index =
    clamp(
      math.floor(selection_end * count) + 1,
      1,
      count
    )
  local final_index =
    clamp(
      math.ceil(maximum_end * count),
      first_index,
      count
    )
  local last_above = nil

  -- Scan the entire allowed window rather than stopping at the first quiet
  -- gap. This preserves delayed repeats that arrive after a short silence.
  for index = first_index, final_index do
    if (waveform.peaks[index] or 0) >= threshold then
      last_above = index
    end
  end

  if not last_above then
    return selection_end, 0
  end

  local hold_seconds =
    math.max(
      0,
      tonumber(state.transfer_tail_hold_ms) or 0
    ) / 1000
  local detected_end =
    math.min(
      maximum_end,
      last_above / count
        + hold_seconds / duration
    )

  detected_end =
    clamp(detected_end, selection_end, 1)

  return detected_end,
    math.max(
      0,
      (detected_end - selection_end)
        * duration
        * 1000
    )
end

function create_transfer_item(asset, use_selection, variant)
  variant = variant or {
    pitch = state.pitch,
    rate = state.rate,
    gain_db = state.gain_db,
    reverse = state.reverse,
  }
  local track_index = reaper.CountTracks(PROJ)
  reaper.InsertTrackInProject(PROJ, track_index, 0)
  local track = reaper.GetTrack(PROJ, track_index)

  if not track then
    return nil, nil, "temporary track"
  end

  reaper.GetSetMediaTrackInfo_String(
    track,
    "P_NAME",
    "PsyReaSFX Transfer (temporary)",
    true
  )

  local source = reaper.PCM_Source_CreateFromFile(asset.path)

  if not source then
    return track, nil, "source"
  end

  local duration, is_qn = reaper.GetMediaSourceLength(source)
  duration = is_qn and 0 or (duration or asset.duration or 0)

  if duration <= 0 then
    reaper.PCM_Source_Destroy(source)
    return track, nil, "duration"
  end

  local start_percent = 0
  local end_percent = 1

  if use_selection and has_selection() then
    start_percent = clamp(state.region_start, 0, 1)
    end_percent = clamp(state.region_end, start_percent, 1)

    end_percent, state.transfer_last_tail_ms =
      detect_transfer_tail_end(
        asset,
        source,
        duration,
        end_percent,
        variant.reverse
      )
  else
    state.transfer_last_tail_ms = 0
  end

  local source_start = duration * start_percent
  local source_length = duration * (end_percent - start_percent)
  local take_source = source
  local take_start_offset = source_start

  if variant.reverse then
    if type(reaper.CF_PCM_Source_SetSectionInfo) ~= "function" then
      reaper.PCM_Source_Destroy(source)
      return track, nil, "reverse requires SWS"
    end

    local section = reaper.PCM_Source_CreateFromType("SECTION")
    local ok = section and reaper.CF_PCM_Source_SetSectionInfo(
      section,
      source,
      source_start,
      source_length,
      true
    )

    if not ok then
      if section then
        reaper.PCM_Source_Destroy(section)
      end
      reaper.PCM_Source_Destroy(source)
      return track, nil, "reverse source"
    end

    take_source = section
    take_start_offset = 0
  end

  local item = reaper.AddMediaItemToTrack(track)
  local take = item and reaper.AddTakeToMediaItem(item)

  if not take then
    if take_source ~= source then
      reaper.PCM_Source_Destroy(take_source)
    end
    reaper.PCM_Source_Destroy(source)
    return track, nil, "media item"
  end

  reaper.SetMediaItemTake_Source(take, take_source)
  reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", take_start_offset)
  reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", variant.rate)
  reaper.SetMediaItemTakeInfo_Value(take, "D_PITCH", variant.pitch)
  reaper.SetMediaItemTakeInfo_Value(
    take,
    "B_PPITCH",
    state.preserve_pitch and 1 or 0
  )
  reaper.SetMediaItemTakeInfo_Value(
    take,
    "D_VOL",
    db_to_amp(variant.gain_db)
  )

  if state.transfer_channels == "mono" then
    reaper.SetMediaItemTakeInfo_Value(take, "I_CHANMODE", 2)
  end

  local item_position = reaper.GetProjectLength(PROJ) + 10
  local item_length =
    source_length / math.max(0.01, variant.rate)
  reaper.SetMediaItemPosition(item, item_position, false)
  reaper.SetMediaItemLength(item, item_length, false)
  -- Transfer fades are applied by REAPER's render post-processing flags.
  -- Do not also apply item fades here, otherwise the requested fade would
  -- be processed twice.

  reaper.GetSetMediaItemTakeInfo_String(
    take,
    "P_NAME",
    strip_extension(asset.name),
    true
  )

  reaper.SelectAllMediaItems(PROJ, false)
  reaper.SetMediaItemSelected(item, true)
  reaper.SetOnlyTrackSelected(track)

  return track, item, nil
end

function configure_transfer_render(asset, output_path)
  local _, sink_config = transfer_format_info()
  local output_directory = dirname(output_path)
  local output_pattern = strip_extension(basename(output_path))
  local render_settings = 32
  local dither_flags = 0

  if state.transfer_preserve_metadata then
    render_settings = render_settings | 32768
  end

  if state.transfer_format == "wav16"
    and state.transfer_dither then
    dither_flags = dither_flags | 1
  end

  if state.transfer_format == "wav16"
    and state.transfer_noise_shaping then
    dither_flags = dither_flags | 2
  end

  reaper.GetSetProjectInfo(
    PROJ,
    "RENDER_SETTINGS",
    render_settings,
    true
  )
  reaper.GetSetProjectInfo(PROJ, "RENDER_BOUNDSFLAG", 4, true)
  reaper.GetSetProjectInfo(
    PROJ,
    "RENDER_CHANNELS",
    transfer_channel_count(asset),
    true
  )
  reaper.GetSetProjectInfo(
    PROJ,
    "RENDER_SRATE",
    transfer_sample_rate(asset),
    true
  )
  reaper.GetSetProjectInfo(PROJ, "RENDER_TAILFLAG", 0, true)
  reaper.GetSetProjectInfo(PROJ, "RENDER_TAILMS", 0, true)
  reaper.GetSetProjectInfo(PROJ, "RENDER_ADDTOPROJ", 0, true)
  reaper.GetSetProjectInfo(
    PROJ,
    "RENDER_DITHER",
    dither_flags,
    true
  )
  reaper.GetSetProjectInfo(
    PROJ,
    "RENDER_NORMALIZE",
    transfer_normalize_flags(),
    true
  )
  reaper.GetSetProjectInfo(
    PROJ,
    "RENDER_NORMALIZE_TARGET",
    db_to_amp(state.transfer_normalize_target),
    true
  )
  reaper.GetSetProjectInfo(
    PROJ,
    "RENDER_FADEIN",
    math.max(0, state.transfer_fade_in_ms) / 1000,
    true
  )
  reaper.GetSetProjectInfo(
    PROJ,
    "RENDER_FADEOUT",
    math.max(0, state.transfer_fade_out_ms) / 1000,
    true
  )
  reaper.GetSetProjectInfo(PROJ, "RENDER_FADEINSHAPE", 0, true)
  reaper.GetSetProjectInfo(PROJ, "RENDER_FADEOUTSHAPE", 0, true)
  reaper.GetSetProjectInfo_String(
    PROJ,
    "RENDER_FILE",
    output_directory,
    true
  )
  reaper.GetSetProjectInfo_String(
    PROJ,
    "RENDER_PATTERN",
    output_pattern,
    true
  )
  reaper.GetSetProjectInfo_String(
    PROJ,
    "RENDER_FORMAT",
    sink_config,
    true
  )
  reaper.GetSetProjectInfo_String(PROJ, "RENDER_FORMAT2", "", true)
end

function unique_transfer_sidecar_path(output_path, label, task_index)
  local directory = dirname(output_path)
  local extension_name =
    output_path:match("%.([^%.\\/]*)$") or "wav"
  local base = strip_extension(basename(output_path))
  local stamp =
    tostring(math.floor(reaper.time_precise() * 1000000))
  local attempt = 0

  while attempt < 1000 do
    local candidate = join_path(
      directory,
      string.format(
        "%s.psyreasfx_%s_%s_%04d_%03d.%s",
        base,
        label,
        stamp,
        tonumber(task_index) or 0,
        attempt,
        extension_name
      )
    )

    if not reaper.file_exists(candidate) then
      return candidate
    end

    attempt = attempt + 1
  end

  return nil
end

function commit_transfer_output(
  temporary_path,
  output_path,
  replace_existing,
  task_index
)
  if not temporary_path
    or not reaper.file_exists(temporary_path) then
    return false, translate_ui_text("未找到临时渲染文件")
  end

  if not replace_existing
    or not reaper.file_exists(output_path) then
    local ok, message = os.rename(temporary_path, output_path)
    return ok == true, message
  end

  local backup_path =
    unique_transfer_sidecar_path(
      output_path,
      "backup",
      task_index
    )

  if not backup_path then
    return false, translate_ui_text("无法创建安全覆盖备份")
  end

  local backed_up, backup_error =
    os.rename(output_path, backup_path)

  if not backed_up then
    return false,
      translate_ui_text("无法备份原有文件")
        .. (backup_error and (": " .. backup_error) or "")
  end

  local committed, commit_error =
    os.rename(temporary_path, output_path)

  if committed then
    os.remove(backup_path)
    return true, nil
  end

  local restored, restore_error =
    os.rename(backup_path, output_path)

  if not restored then
    return false,
      translate_ui_text("输出提交失败，原文件保存在：")
        .. backup_path
        .. (restore_error and (": " .. restore_error) or "")
  end

  return false,
    translate_ui_text("输出提交失败，原文件已恢复")
      .. (commit_error and (": " .. commit_error) or "")
end

function render_transfer_asset(task)
  local asset = task.asset
  local output_path, collision, existing =
    resolve_transfer_output(
      asset,
      task.asset_index,
      task.variant
    )

  if collision == "skip" then
    return false,
      nil,
      translate_ui_text("已跳过已有文件：") .. existing,
      true
  elseif not output_path then
    return false,
      nil,
      translate_ui_text("Transfer 渲染失败"),
      false
  end

  local temporary_path =
    unique_transfer_sidecar_path(
      output_path,
      "render",
      task.task_index
    )

  if not temporary_path then
    return false,
      nil,
      translate_ui_text("无法创建临时渲染路径"),
      false
  end

  local context = capture_transfer_context()
  local temporary_track = nil
  local render_ok = false
  local render_error = nil

  reaper.PreventUIRefresh(1)

  local setup_ok, setup_error = xpcall(function()
    temporary_track, _, render_error =
      create_transfer_item(
        asset,
        task.use_selection,
        task.variant
      )

    if render_error then
      error(render_error)
    end

    configure_transfer_render(asset, temporary_path)
  end, debug.traceback)

  reaper.PreventUIRefresh(-1)

  if setup_ok then
    local action_ok, action_error = pcall(function()
      reaper.Main_OnCommand(42230, 0)
    end)

    render_ok =
      action_ok and reaper.file_exists(temporary_path)
    render_error = action_error
  else
    render_error = setup_error
  end

  reaper.PreventUIRefresh(1)
  local restore_ok, restore_error =
    pcall(
      restore_transfer_context,
      context,
      temporary_track
    )
  reaper.PreventUIRefresh(-1)

  if not restore_ok then
    render_ok = false
    render_error = restore_error
  end

  if render_ok then
    local commit_ok, commit_error =
      commit_transfer_output(
        temporary_path,
        output_path,
        collision == "overwrite",
        task.task_index
      )
    render_ok = commit_ok
    render_error = commit_error
  end

  if not render_ok then
    if reaper.file_exists(temporary_path) then
      os.remove(temporary_path)
    end

    return false,
      nil,
      translate_ui_text("Transfer 渲染失败")
        .. (
          render_error
            and (": " .. tostring(render_error))
            or ""
        ),
      false
  end

  push_recent(
    asset,
    state.transfer_insert_after
      and "transfer_insert"
      or nil
  )

  if state.transfer_insert_after then
    reaper.InsertMedia(output_path, 1)
  end

  return true, output_path, nil, false
end

function write_transfer_report(job, canceled)
  local handle = io.open(TRANSFER_REPORT_FILE, "wb")

  if not handle then
    return false
  end

  handle:write(
    "status\tasset\tvariant\toutput\tmessage\tseconds\n"
  )

  for _, record in ipairs(job.records or {}) do
    handle:write(
      table.concat({
        escape_tsv(record.status or ""),
        escape_tsv(record.asset or ""),
        escape_tsv(record.variant or ""),
        escape_tsv(record.output or ""),
        escape_tsv(record.message or ""),
        escape_tsv(
          string.format("%.3f", record.seconds or 0)
        ),
      }, "\t"),
      "\n"
    )
  end

  if canceled then
    handle:write(
      table.concat({
        "canceled",
        "",
        "",
        "",
        escape_tsv("Stopped after current file"),
        "",
      }, "\t"),
      "\n"
    )
  end

  handle:close()
  return true
end

function finish_transfer_job(job, canceled)
  if not job then
    return
  end

  write_transfer_report(job, canceled)

  if canceled then
    Jobs.cancel(job.job_token)
  end
  Jobs.finish(job.job_token, true, canceled and "canceled" or "")

  state.transfer_running = false
  state.transfer_job = nil
  state.transfer_cancel_requested = false
  state.config_dirty = true

  local summary = string.format(
    "%s %d · %s %d · %s %d",
    translate_ui_text("完成"),
    job.success_count or 0,
    translate_ui_text("跳过"),
    job.skipped_count or 0,
    translate_ui_text("失败"),
    #(job.failures or {})
  )

  if canceled then
    summary =
      translate_ui_text("Transfer 已停止") .. " · " .. summary
  else
    summary =
      translate_ui_text("Transfer 完成") .. " · " .. summary
  end

  state.transfer_last_summary = summary

  if #(job.failures or {}) > 0 then
    state.transfer_last_error =
      table.concat(job.failures, "\n")
    set_status(summary, true)
  else
    state.transfer_last_error = ""
    set_status(summary)
  end

  if not canceled
    and (job.success_count or 0) > 0
    and state.transfer_open_dir_after then
    local completed_directory =
      state.transfer_last_output ~= ""
        and dirname(state.transfer_last_output)
        or (job.output_directory or state.transfer_dir)

    open_folder(completed_directory)
  end
end

function process_transfer_job()
  local job = state.transfer_job

  if not job then
    return
  end

  if (reaper.GetPlayStateEx(PROJ) & 1) == 1 then
    set_status(
      translate_ui_text(
        "Transfer 已暂停：请停止工程播放"
      ),
      true
    )
    return
  end

  if state.transfer_cancel_requested
    or (job.job_token
      and job.job_token.cancel_requested) then
    finish_transfer_job(job, true)
    return
  end

  local task = job.tasks[job.next_index]

  if not task then
    finish_transfer_job(job, false)
    return
  end

  local started_at = reaper.time_precise()
  local ok, output, message, skipped =
    render_transfer_asset(task)
  local elapsed =
    math.max(0, reaper.time_precise() - started_at)

  if ok then
    job.success_count = job.success_count + 1
    state.transfer_last_outputs[
      #state.transfer_last_outputs + 1
    ] = output
    state.transfer_last_output = output
  elseif skipped then
    job.skipped_count = job.skipped_count + 1
  else
    job.failures[#job.failures + 1] =
      (task.asset.name or "")
        .. " · "
        .. (message or translate_ui_text("未知错误"))
  end

  job.records[#job.records + 1] = {
    status = ok and "success" or (skipped and "skipped" or "failed"),
    asset = task.asset.path or task.asset.name or "",
    variant = task.variant.label or "current",
    output = output or "",
    message = message or "",
    seconds = elapsed,
  }

  job.next_index = job.next_index + 1
  job.completed = job.next_index - 1
  set_status(
    string.format(
      "%s %d / %d",
      translate_ui_text("正在导出"),
      job.completed,
      job.total
    )
  )
end

function run_transfer(assets, batch_mode)
  if state.transfer_running then
    return
  end

  assets = assets or {}

  if #assets == 0 then
    set_status("请先选择素材", true)
    return
  end

  if (reaper.GetPlayStateEx(PROJ) & 1) == 1 then
    set_status("工程正在播放，停止后再执行 Transfer", true)
    return
  end

  local directory = normalize_slashes(trim(state.transfer_dir or ""))

  if directory == "" then
    set_status("请选择有效的输出目录", true)
    return
  end

  if reaper.RecursiveCreateDirectory(directory, 0) <= 0
    and not directory_exists(directory) then
    set_status("无法创建输出目录", true)
    return
  end

  local variants, variant_error = build_transfer_variants()

  if not variants then
    set_status(variant_error, true)
    return
  end

  if type(reaper.CF_PCM_Source_SetSectionInfo) ~= "function" then
    for _, variant in ipairs(variants) do
      if variant.reverse then
        set_status(
          translate_ui_text(
            "反向变体需要安装 SWS Extension"
          ),
          true
        )
        return
      end
    end
  end

  local total = #assets * #variants

  if total > 4096 then
    set_status(
      translate_ui_text(
        "导出任务超过 4096 个，请减少素材或变体数量"
      ),
      true
    )
    return
  end

  local has_overwrite_target = false

  if state.transfer_collision == "overwrite" then
    local planned_targets = {}
    local extension_name = transfer_format_info()

    for asset_index, asset in ipairs(assets) do
      for _, variant in ipairs(variants) do
        local planned_path = join_path(
          directory,
          expand_transfer_template(
            asset,
            asset_index,
            variant
          ) .. "." .. extension_name
        )
        local planned_key = path_key(planned_path)
        local _, collision =
          resolve_transfer_output(
            asset,
            asset_index,
            variant
          )

        if collision == "overwrite"
          or planned_targets[planned_key] then
          has_overwrite_target = true
          break
        end

        planned_targets[planned_key] = true
      end

      if has_overwrite_target then
        break
      end
    end
  end

  if has_overwrite_target then
    local answer = reaper.MB(
      translate_ui_text(
        "同名输出将使用安全替换：先完成临时渲染，再备份并替换原文件。是否继续？"
      ),
      translate_ui_text("确认覆盖策略"),
      4
    )

    if answer ~= 6 then
      return
    end
  end

  local tasks = {}
  local task_index = 0

  for asset_index, asset in ipairs(assets) do
    local use_selection =
      not batch_mode
      and state.transfer_scope == "selection"
      and has_selection()

    for _, variant in ipairs(variants) do
      task_index = task_index + 1
      tasks[task_index] = {
        asset = asset,
        asset_index = asset_index,
        use_selection = use_selection,
        variant = variant,
        task_index = task_index,
      }
    end
  end

  local job_token =
    Jobs.begin("transfer", "catalog_exclusive", false)

  if not job_token then
    set_status(
      translate_ui_text(
        "请等待当前扫描或维护任务完成"
      ),
      true
    )
    return
  end

  stop_preview()
  state.transfer_running = true
  state.transfer_cancel_requested = false
  state.transfer_last_error = ""
  state.transfer_last_outputs = {}
  state.transfer_last_summary = ""
  state.transfer_job = {
    tasks = tasks,
    total = #tasks,
    next_index = 1,
    completed = 0,
    success_count = 0,
    skipped_count = 0,
    failures = {},
    records = {},
    started_at = reaper.time_precise(),
    output_directory = state.transfer_dir,
    job_token = job_token,
  }
  set_status(
    string.format(
      "%s 0 / %d",
      translate_ui_text("正在导出"),
      #tasks
    )
  )
end

----------------------------------------------------------------
-- Multi insert and drag-to-arrange
----------------------------------------------------------------

function ensure_track_index(track_index)
  track_index = math.max(0, math.floor(track_index or 0))

  while reaper.CountTracks(PROJ) <= track_index do
    reaper.InsertTrackInProject(
      PROJ,
      reaper.CountTracks(PROJ),
      1
    )
  end

  return reaper.GetTrack(PROJ, track_index)
end

function insert_asset_at(
  asset,
  track_index,
  position,
  start_percent,
  end_percent
)
  if state.root_removal_session then
    return false
  end
  if not asset or not reaper.file_exists(asset.path) then
    return false
  end

  track_index = math.max(0, math.floor(track_index or 0))
  ensure_track_index(track_index)

  reaper.SetEditCurPos(
    position or reaper.GetCursorPosition(),
    false,
    false
  )

  reaper.SelectAllMediaItems(PROJ, false)

  local mode =
    512 | (track_index << 16)

  start_percent = start_percent or 0
  end_percent = end_percent or 1

  if end_percent - start_percent < 0.999 then
    mode = mode | 128
  end

  if state.reverse then
    mode = mode | 8192
  end

  local result =
    reaper.InsertMediaSection(
      asset.path,
      mode,
      start_percent,
      end_percent,
      0
    )

  if result >= 0 then
    apply_insert_settings(asset)
    push_recent(asset, "insert")
    return true
  end

  return false
end

function insert_selected_stack(
  start_percent,
  end_percent
)
  if state.root_removal_session then
    set_status("请等待来源移除完成后再插入素材", true)
    return
  end
  local assets = selected_assets()

  if #assets == 0 then
    local asset = selected_asset()

    if asset then
      assets = { asset }
    end
  end

  if #assets == 0 then
    return
  end

  if #assets == 1 then
    insert_asset(assets[1], false, false)
    return
  end

  local selected_track =
    reaper.GetSelectedTrack(PROJ, 0)

  local base_index = selected_track
    and math.max(
      0,
      math.floor(
        reaper.GetMediaTrackInfo_Value(
          selected_track,
          "IP_TRACKNUMBER"
        )
      ) - 1
    )
    or reaper.CountTracks(PROJ)

  local position = reaper.GetCursorPosition()

  reaper.Undo_BeginBlock2(PROJ)
  reaper.PreventUIRefresh(1)

  local inserted = 0

  for index, asset in ipairs(assets) do
    if insert_asset_at(
      asset,
      base_index + index - 1,
      position,
      start_percent or 0,
      end_percent or 1
    ) then
      inserted = inserted + 1
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock2(
    PROJ,
    "PsyReaSFX：分轨插入多个素材",
    -1
  )

  set_status(
    string.format(
      "已分轨插入 %d 个素材",
      inserted
    )
  )
end

function begin_external_drag(
  asset,
  use_wave_selection
)
  local assets = selected_assets()

  if #assets == 0
    or not is_row_selected(asset) then
    assets = { asset }
  end

  local start_percent = 0
  local end_percent = 1

  if use_wave_selection and has_selection() then
    assets = { asset }
    start_percent = state.region_start
    end_percent = state.region_end
  end

  state.external_drag = {
    assets = assets,
    start_percent = start_percent,
    end_percent = end_percent,
    label = #assets == 1
      and assets[1].name
      or tostring(#assets) .. " 个素材",
  }

  state.external_drag_started = true
end

function drop_external_drag()
  local drag = state.external_drag

  state.external_drag = nil
  state.external_drag_started = false

  if not drag then
    return
  end

  if type(reaper.BR_GetMouseCursorContext)
      ~= "function"
    or type(reaper.BR_GetMouseCursorContext_Position)
      ~= "function"
    or type(reaper.BR_GetMouseCursorContext_Track)
      ~= "function" then
    set_status(
      "拖到编排区需要 SWS Extension",
      true
    )
    return
  end

  local window =
    select(1, reaper.BR_GetMouseCursorContext())

  if window ~= "arrange" then
    set_status(
      "已取消拖拽：请释放到 REAPER 编排区",
      true
    )
    return
  end

  local position =
    reaper.BR_GetMouseCursorContext_Position()

  if not position or position < 0 then
    set_status("无法取得放置时间位置", true)
    return
  end

  local track =
    reaper.BR_GetMouseCursorContext_Track()

  local base_index

  if track then
    base_index =
      math.max(
        0,
        math.floor(
          reaper.GetMediaTrackInfo_Value(
            track,
            "IP_TRACKNUMBER"
          )
        ) - 1
      )
  else
    base_index = reaper.CountTracks(PROJ)
  end

  reaper.Undo_BeginBlock2(PROJ)
  reaper.PreventUIRefresh(1)

  local inserted = 0

  for index, asset in ipairs(drag.assets) do
    if insert_asset_at(
      asset,
      base_index + index - 1,
      position,
      drag.start_percent,
      drag.end_percent
    ) then
      inserted = inserted + 1
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock2(
    PROJ,
    "PsyReaSFX：拖拽素材到编排区",
    -1
  )

  set_status(
    string.format(
      "已在 %.3f 秒放置 %d 个素材",
      position,
      inserted
    )
  )
end

function process_external_drag()
  if not state.external_drag then
    return
  end

  ImGui.BeginTooltip(ctx)

  local start_y =
    ImGui.GetCursorPosY(ctx)

  ImGui.Dummy(
    ctx,
    360,
    1
  )

  ImGui.SetCursorPosY(
    ctx,
    start_y
  )

  ImGui.Text(ctx, "拖到 REAPER 编排区")
  ImGui.TextDisabled(
    ctx,
    compact(
      state.external_drag.label,
      58
    )
  )
  ImGui.EndTooltip(ctx)

  if ImGui.IsMouseReleased(ctx, 0) then
    drop_external_drag()
  end
end

----------------------------------------------------------------
-- System shell and roots
----------------------------------------------------------------

function reveal_file(path)
  local os_name = reaper.GetOS()

  if os_name:match("Win") then
    reaper.ExecProcess(
      'explorer.exe /select,"' .. path .. '"',
      0
    )
  elseif os_name:match("OSX") then
    reaper.ExecProcess(
      'open -R "' .. path .. '"',
      0
    )
  else
    reaper.ExecProcess(
      'xdg-open "' .. dirname(path) .. '"',
      0
    )
  end
end

function open_url(url)
  url = trim(url or "")

  if url == "" then
    return false
  end

  local os_name = reaper.GetOS()

  if os_name:match("Win") then
    reaper.ExecProcess(
      'cmd.exe /C start "" "' .. url .. '"',
      0
    )
  elseif os_name:match("OSX") then
    reaper.ExecProcess(
      'open "' .. url .. '"',
      0
    )
  else
    reaper.ExecProcess(
      'xdg-open "' .. url .. '"',
      0
    )
  end

  return true
end

function open_folder(path)
  path = normalize_slashes(trim(path or ""))

  if path == "" or not directory_exists(path) then
    set_status(
      translate_ui_text("目录不存在：") .. path,
      true
    )
    return false
  end

  -- SWS delegates paths to the operating system and handles Unicode
  -- directory names more reliably than manually assembled shell commands.
  if type(reaper.CF_ShellExecute) == "function" then
    local ok, result = pcall(reaper.CF_ShellExecute, path)

    if ok and result ~= false and result ~= 0 then
      return true
    end
  end

  local os_name = reaper.GetOS()
  local command

  if os_name:match("Win") then
    command =
      'cmd.exe /D /S /C start "" "'
        .. path:gsub('"', "")
        .. '"'
  elseif os_name:match("OSX") then
    command = 'open "' .. path:gsub('"', '\\"') .. '"'
  else
    command = 'xdg-open "' .. path:gsub('"', '\\"') .. '"'
  end

  local ok = pcall(reaper.ExecProcess, command, -1)

  if not ok then
    set_status(
      translate_ui_text("无法打开目录：") .. path,
      true
    )
    return false
  end

  return true
end

function choose_folder(title, initial)
  if type(reaper.JS_Dialog_BrowseForFolder) == "function" then
    local ok, accepted, path = pcall(
      reaper.JS_Dialog_BrowseForFolder,
      translate_ui_text(title or "选择文件夹"),
      initial or ""
    )

    if ok and accepted and accepted ~= 0 then
      return normalize_slashes(trim(path or ""))
    end
  end

  local ok, input = reaper.GetUserInputs(
    title or "选择文件夹",
    1,
    "文件夹路径:,extrawidth=420",
    initial or ""
  )

  return ok and normalize_slashes(trim(input or "")) or nil
end

function validate_new_root(root)
  local key = path_key(root)
  local exact = state.root_by_path[key]

  if exact then
    return false, "exact", exact
  end

  for _, record in ipairs(state.root_records) do
    if path_is_inside(root, record.path) then
      return false, "covered", record
    elseif path_is_inside(record.path, root) then
      return false, "parent", record
    end
  end

  return true
end

function add_root_to_library(
  library_id,
  root,
  scan_now,
  defer_rebuild
)
  local library = state.library_by_id[library_id]

  if not library then
    set_status("目标音效库不存在", true)
    return false
  end

  root = canonical_source_path(root)

  if not directory_exists(root) then
    set_status(
      "目录不存在或无法访问：" .. root,
      true
    )
    return false
  end

  local valid, reason, conflict = validate_new_root(root)

  if not valid then
    local owner = library_for_root_record(conflict)

    if reason == "exact" then
      set_status(
        "该来源路径已经属于音效库："
          .. (owner and owner.name or "—"),
        true
      )
    elseif reason == "covered" then
      set_status(
        "该文件夹已包含在来源路径中："
          .. conflict.path,
        true
      )
    else
      set_status(
        "该文件夹会覆盖已有来源路径，请先移除或重新定位："
          .. conflict.path,
        true
      )
    end

    return false
  end

  local record = {
    id = stable_id("root", path_key(root)),
    library_id = library.id,
    path = root,
    alias = "",
    enabled = true,
    artwork_path = "",
    artwork_checked = false,
    artwork_scan_version = 0,
  }

  state.root_records[#state.root_records + 1] = record
  state.libraries_dirty = true

  if not defer_rebuild then
    rebuild_library_indexes()
    state.results_dirty = true
  end

  if scan_now ~= false then
    start_scan("添加来源路径", { root })
  end

  return true
end

function prompt_new_library()
  local ok, name = reaper.GetUserInputs(
    translate_ui_text("新建逻辑音效库"),
    1,
    translate_ui_text("名称:"),
    ""
  )

  name = trim(name or "")

  if not ok or name == "" then
    return false
  end

  local library = create_library(name)
  state.view = "all"
  state.active_collection_id = nil
  state.root_filter = nil
  state.library_filter_id = library.id
  state.results_dirty = true
  save_libraries()
  set_status("已新建空音效库：" .. library.name)
  return true
end

function add_root(library_id, supplied_path)
  if not library_id and not supplied_path then
    return prompt_new_library()
  end

  local root = supplied_path
    or choose_folder("添加来源路径", "")

  if not root or root == "" then
    return false
  end

  local library = library_id
    and state.library_by_id[library_id]
    or nil

  if not library then
    library = create_library(
      basename(root),
      "library:" .. path_key(root)
    )
  end

  local added = add_root_to_library(library.id, root, true)

  if not added and #library.roots == 0 then
    for index = #state.libraries, 1, -1 do
      if state.libraries[index].id == library.id then
        table.remove(state.libraries, index)
        break
      end
    end

    rebuild_library_indexes()
  end

  return added
end

function path_is_in_removed_roots(path, roots)
  for _, root in ipairs(roots or {}) do
    if path_is_inside(path, root) then return true end
  end
  return false
end

function asset_is_in_removed_roots(asset, roots)
  return asset and path_is_in_removed_roots(asset.path, roots) or false
end

function start_root_removal(records, library_id)
  if state.persistence_read_only then
    set_status("只读保护模式下不能移除来源", true)
    return false
  end
  if state.root_removal_session then
    set_status("已有来源移除任务正在运行", true)
    return false
  end
  local roots = {}
  local root_ids = {}
  for _, record in ipairs(records or {}) do
    if record and state.root_by_id[record.id] == record then
      roots[#roots + 1] = record.path
      root_ids[record.id] = true
    end
  end
  if #roots == 0 and not library_id then return false end

  cancel_auxiliary_save("catalog changed")
  cancel_database_snapshot("catalog changed")
  local job_token, job_error = Jobs.begin(
    "root_removal",
    "catalog_exclusive",
    false
  )
  if not job_token then
    set_status(
      job_error == "resource_busy"
        and "请等待当前目录维护任务完成后再移除来源"
        or "无法启动来源移除任务",
      true
    )
    return false
  end

  if state.wave_active then
    local wave_token = state.wave_active.job_token
    destroy_wave_job(state.wave_active)
    if wave_token then
      Jobs.cancel(wave_token)
      Jobs.finish(wave_token, true, "catalog changed")
    end
    state.wave_active = nil
  end
  destroy_loudness_job(state.loudness_active)
  state.loudness_active = nil
  state.meta_queue = {}
  state.meta_queued = {}
  state.wave_queue = {}
  state.wave_queued = {}
  state.artwork_queue = {}
  state.artwork_queued = {}
  state.loudness_queue = {}
  state.loudness_queued = {}

  local library = library_id and state.library_by_id[library_id] or nil
  local filter_job = new_catalog_filter_job(state.assets)
  state.root_removal_session = {
    phase = "filter",
    roots = roots,
    root_ids = root_ids,
    library_id = library_id,
    label = library and library.name or basename(roots[1] or ""),
    filter_job = filter_job,
    collections = state.collections,
    project_usage = state.project_usage,
    concurrent_asset_changes = {},
    cleanup_index = 1,
    cleanup_records = {},
    changed = {},
    job_token = job_token,
  }
  set_status(string.format(
    "正在准备移除来源：0 / %d",
    filter_job.total
  ))
  return true
end

function restore_root_removal_record(record)
  local key = record.key
  local asset_id = record.asset_id
  if record.favorite ~= nil then state.favorites[key] = record.favorite end
  if record.selected ~= nil then state.selected_set[key] = record.selected end
  if record.history ~= nil then
    state.preview_history_assets[asset_id] = record.history
  end
  if record.regions ~= nil then state.regions_by_path[key] = record.regions end
  if record.loudness ~= nil then state.loudness_cache[key] = record.loudness end
  if record.failed ~= nil then state.failed_tasks[key] = record.failed end
  if record.session_played ~= nil then
    state.session_played[key] = record.session_played
  end
  if record.last_session_played ~= nil then
    state.last_session_played[key] = record.last_session_played
  end
end

function flush_root_removal_asset_changes(session, kept_only)
  for key, asset in pairs(session.concurrent_asset_changes or {}) do
    if not kept_only
      or session.filter_job.kept_by_key[key] == asset then
      state.db_dirty = true
      record_asset_change(
        state.database_changes,
        key,
        "upsert",
        database_asset_values(asset)
      )
    end
  end
  session.concurrent_asset_changes = {}
end

function cancel_root_removal(session, reason)
  session = session or state.root_removal_session
  if not session then return false end
  if session.phase ~= "cleanup" then
    flush_root_removal_asset_changes(session, false)
    state.root_removal_session = nil
    Jobs.cancel(session.job_token)
    Jobs.finish(session.job_token, true, reason or "canceled")
    set_status("已取消来源移除")
    return true
  end
  session.phase = "rollback"
  session.rollback_index = #session.cleanup_records
  session.cancel_reason = reason or "canceled"
  set_status("正在回滚来源移除…")
  return true
end

function finish_root_removal_rollback(session)
  local first = math.max(
    1,
    session.rollback_index - ROOT_REMOVAL_ASSETS_PER_FRAME + 1
  )
  for index = session.rollback_index, first, -1 do
    restore_root_removal_record(session.cleanup_records[index])
  end
  session.rollback_index = first - 1
  if session.rollback_index > 0 then return end
  flush_root_removal_asset_changes(session, false)
  state.root_removal_session = nil
  Jobs.finish(session.job_token, true, session.cancel_reason)
  set_status("已取消来源移除并恢复原状态")
end

function capture_root_removal_record(session, asset)
  local key = path_key(asset.path)
  local asset_id = asset.asset_id or ""
  local record = {
    key = key,
    asset_id = asset_id,
    favorite = state.favorites[key],
    selected = state.selected_set[key],
    history = state.preview_history_assets[asset_id],
    regions = state.regions_by_path[key],
    loudness = state.loudness_cache[key],
    failed = state.failed_tasks[key],
    session_played = state.session_played[key],
    last_session_played = state.last_session_played[key],
  }
  local referenced = record.favorite ~= nil
    or record.selected ~= nil
    or record.history ~= nil
    or record.regions ~= nil
    or record.loudness ~= nil
    or record.failed ~= nil
    or record.session_played ~= nil
    or record.last_session_played ~= nil
  if referenced then
    session.cleanup_records[#session.cleanup_records + 1] = record
  end
  if record.favorite ~= nil then session.changed.config = true end
  if record.history ~= nil then session.changed.history = true end
  if record.regions ~= nil then session.changed.regions = true end
  if record.loudness ~= nil then session.changed.loudness = true end
  if record.failed ~= nil then session.changed.failed = true end
  if record.session_played ~= nil
    or record.last_session_played ~= nil then
    session.changed.session_played = true
  end
  state.favorites[key] = nil
  state.selected_set[key] = nil
  state.preview_history_assets[asset_id] = nil
  state.regions_by_path[key] = nil
  state.loudness_cache[key] = nil
  state.failed_tasks[key] = nil
  state.session_played[key] = nil
  state.last_session_played[key] = nil
end

function begin_root_removal_collection_filter(session)
  session.phase = "collections"
  session.collection_index = 1
  session.collection_job = nil
  session.collection_updates = {}
  session.collection_processed = 0
  session.collection_total = 0
  for _, collection in ipairs(session.collections or {}) do
    session.collection_total = session.collection_total
      + #(collection.order or {})
      + collection_item_count(collection)
  end
end

function step_root_removal_collection_filter(session, deadline)
  local frame_processed = 0
  while session.collection_index <= #(session.collections or {}) do
    local collection = session.collections[session.collection_index]
    if not session.collection_job then
      session.collection_job = new_ordered_path_filter_job(
        collection.order,
        collection.items
      )
    end
    local job = session.collection_job
    local before = job.processed
    local complete = step_ordered_path_filter_job(
      job,
      ROOT_REMOVAL_ASSETS_PER_FRAME - frame_processed,
      function(path)
        return path_is_in_removed_roots(path, session.roots)
      end,
      path_key,
      deadline,
      reaper.time_precise
    )
    local delta = job.processed - before
    frame_processed = frame_processed + delta
    session.collection_processed = session.collection_processed + delta
    if not complete then return false end

    session.collection_updates[#session.collection_updates + 1] = {
      collection = collection,
      items = job.kept_items,
      order = job.kept_order,
      count = #job.kept_order,
    }
    if job.removed > 0 or job.repaired > 0 then
      session.changed.collections = true
    end
    session.collection_job = nil
    session.collection_index = session.collection_index + 1
    if frame_processed >= ROOT_REMOVAL_ASSETS_PER_FRAME
      or reaper.time_precise() >= deadline then
      return false
    end
  end
  return true
end

function begin_root_removal_project_usage_filter(session)
  session.phase = "project_usage"
  session.project_keys = {}
  for key in pairs(session.project_usage or {}) do
    session.project_keys[#session.project_keys + 1] = key
  end
  table.sort(session.project_keys)
  session.project_index = 1
  session.project_job = nil
  session.project_usage_filtered = {}
  session.project_usage_processed = 0
end

function step_root_removal_project_usage_filter(session, deadline)
  local frame_processed = 0
  while session.project_index <= #session.project_keys do
    local project_key = session.project_keys[session.project_index]
    local bucket = session.project_usage[project_key]
    if not session.project_job then
      session.project_job = new_path_map_filter_job(
        bucket and bucket.assets or {}
      )
    end
    local job = session.project_job
    local before = job.processed
    local complete = step_path_map_filter_job(
      job,
      ROOT_REMOVAL_ASSETS_PER_FRAME - frame_processed,
      function(path)
        return path_is_in_removed_roots(path, session.roots)
      end,
      function(entry) return entry.path end,
      deadline,
      reaper.time_precise
    )
    local delta = job.processed - before
    frame_processed = frame_processed + delta
    session.project_usage_processed = session.project_usage_processed + delta
    if not complete then return false end

    local filtered_bucket = {}
    for field, value in pairs(bucket or {}) do
      if field ~= "assets" then filtered_bucket[field] = value end
    end
    filtered_bucket.assets = job.kept
    session.project_usage_filtered[project_key] = filtered_bucket
    if job.removed > 0 then session.changed.project_usage = true end
    session.project_job = nil
    session.project_index = session.project_index + 1
    if frame_processed >= ROOT_REMOVAL_ASSETS_PER_FRAME
      or reaper.time_precise() >= deadline then
      return false
    end
  end
  return true
end

function commit_root_removal(session)
  state.assets = session.filter_job.kept
  state.by_path = session.filter_job.kept_by_key
  state.database_ordered_assets = nil

  for _, update in ipairs(session.collection_updates or {}) do
    update.collection.items = update.items
    update.collection.order = update.order
    update.collection.count = update.count
  end
  if session.project_usage_filtered then
    state.project_usage = session.project_usage_filtered
  end
  if session.changed.collections then state.collections_dirty = true end
  if session.changed.project_usage then state.project_usage_dirty = true end
  rebuild_collection_index()
  refresh_current_project_binding()

  for index = #state.root_records, 1, -1 do
    if session.root_ids[state.root_records[index].id] then
      state.expanded_source_folders[state.root_records[index].id] = nil
      table.remove(state.root_records, index)
    end
  end
  if session.library_id then
    for index = #state.libraries, 1, -1 do
      if state.libraries[index].id == session.library_id then
        table.remove(state.libraries, index)
        break
      end
    end
  end
  rebuild_library_indexes()
  refresh_all_asset_library_bindings()

  for _, saved in ipairs(state.saved_searches) do
    local changed = false
    if saved.root and saved.root ~= ""
      and path_is_in_removed_roots(saved.root, session.roots) then
      saved.root = ""
      changed = true
    end
    if session.library_id and saved.library_id == session.library_id then
      saved.library_id = nil
      changed = true
    end
    if changed then state.searches_dirty = true end
  end

  local recent = {}
  for _, path in ipairs(state.recent) do
    if not path_is_in_removed_roots(path, session.roots) then
      recent[#recent + 1] = path
    end
  end
  if #recent ~= #state.recent then session.changed.config = true end
  state.recent = recent

  for _, root in ipairs(session.roots) do
    if state.root_filter and path_is_inside(state.root_filter, root) then
      state.root_filter = nil
      break
    end
  end
  if session.library_id
    and state.library_filter_id == session.library_id then
    state.library_filter_id = nil
  elseif state.library_filter_id then
    local active_library = state.library_by_id[state.library_filter_id]
    if not active_library or #active_library.roots == 0 then
      state.library_filter_id = nil
    end
  end

  clear_row_selection()
  state.duplicate_groups = {}
  state.duplicate_lookup = {}
  state.duplicate_group_count = 0
  state.duplicate_asset_count = 0
  state.duplicate_confirmed_groups = {}
  state.duplicate_confirmed_lookup = {}
  state.duplicate_confirmed_asset_count = 0
  state.duplicate_confirmation_failures = {}
  state.duplicate_confirmation_failure_count = 0
  state.missing_assets = {}
  state.missing_asset_count = 0
  state.libraries_dirty = true
  state.config_dirty = state.config_dirty or session.changed.config == true
  state.history_dirty = state.history_dirty or session.changed.history == true
  state.session_played_dirty = state.session_played_dirty
    or session.changed.session_played == true
  state.regions_dirty = state.regions_dirty or session.changed.regions == true
  state.loudness_dirty = state.loudness_dirty or session.changed.loudness == true
  state.failed_tasks_dirty = state.failed_tasks_dirty
    or session.changed.failed == true
  state.results_dirty = true
  invalidate_library_counts()
  invalidate_folder_navigation()
  mark_database_snapshot_dirty()
  flush_root_removal_asset_changes(session, true)

  state.root_removal_session = nil
  Jobs.finish(session.job_token, true)
  save_libraries()
  save_database_changes()
  set_status(string.format(
    "已移除%s：%s（%d 个素材）",
    session.library_id and "音效库" or "来源路径",
    session.label,
    #session.filter_job.removed
  ))
end

function process_root_removal()
  local session = state.root_removal_session
  if not session then return end
  if session.phase == "rollback" then
    finish_root_removal_rollback(session)
    return
  end
  if session.job_token.cancel_requested then
    cancel_root_removal(session, "canceled")
    return
  end

  if session.phase == "filter" then
    local complete = step_catalog_filter_job(
      session.filter_job,
      ROOT_REMOVAL_ASSETS_PER_FRAME,
      function(asset)
        return asset_is_in_removed_roots(asset, session.roots)
      end,
      function(asset) return path_key(asset.path) end,
      reaper.time_precise() + ROOT_REMOVAL_FRAME_BUDGET,
      reaper.time_precise
    )
    if not complete then return end
    begin_root_removal_collection_filter(session)
  end

  local deadline = reaper.time_precise() + ROOT_REMOVAL_FRAME_BUDGET
  if session.phase == "collections" then
    if not step_root_removal_collection_filter(session, deadline) then return end
    begin_root_removal_project_usage_filter(session)
  end
  if session.phase == "project_usage" then
    if not step_root_removal_project_usage_filter(session, deadline) then return end
    session.phase = "cleanup"
    session.cleanup_index = 1
  end

  local removed = session.filter_job.removed
  local last = math.min(
    #removed,
    session.cleanup_index + ROOT_REMOVAL_ASSETS_PER_FRAME - 1
  )
  for index = session.cleanup_index, last do
    capture_root_removal_record(session, removed[index])
  end
  session.cleanup_index = last + 1
  if session.cleanup_index <= #removed then return end
  commit_root_removal(session)
end

function remove_root(root)
  local record = type(root) == "table"
    and root
    or root_record_for_path(root)
  if not record then return false end
  return start_root_removal({ record }, nil)
end

function relative_path_from_root(path, root)
  local normalized_path = normalize_slashes(path or "")
  local normalized_root = canonical_source_path(root or "")

  if not path_is_inside(normalized_path, normalized_root) then
    return nil
  end

  if path_key(normalized_path) == path_key(normalized_root) then
    return ""
  end

  local offset = #normalized_root + 1
  if normalized_path:sub(offset, offset) == SEP then
    offset = offset + 1
  end
  return normalized_path:sub(offset)
end

function replace_path_in_order(order, old_key, new_path)
  local changed = 0
  local new_key = path_key(new_path)
  local seen_new = false
  local index = 1

  while index <= #(order or {}) do
    local key = path_key(order[index])
    if key == old_key then
      order[index] = new_path
      key = new_key
      changed = changed + 1
    end

    if key == new_key then
      if seen_new then
        table.remove(order, index)
        changed = changed + 1
      else
        seen_new = true
        index = index + 1
      end
    else
      index = index + 1
    end
  end

  return changed
end

function migrate_path_references(old_path, new_path)
  local old_key = path_key(old_path)
  local new_key = path_key(new_path)

  if old_key == new_key then
    return
  end

  if state.favorites[old_key] then
    state.favorites[old_key] = nil
    state.favorites[new_key] = true
    state.config_dirty = true
  end

  if state.session_played[old_key] then
    state.session_played[old_key] = nil
    state.session_played[new_key] = true
    state.session_played_dirty = true
  end

  if state.last_session_played[old_key] then
    state.last_session_played[old_key] = nil
    state.last_session_played[new_key] = true
  end

  if replace_path_in_order(state.recent, old_key, new_path) > 0 then
    state.config_dirty = true
  end

  if state.selected_path and path_key(state.selected_path) == old_key then
    state.selected_path = new_path
  end
  if state.selected_set[old_key] then
    state.selected_set[old_key] = nil
    state.selected_set[new_key] = true
  end

  for _, collection in ipairs(state.collections or {}) do
    if collection.items and collection.items[old_key] then
      local target_existed = collection.items[new_key] ~= nil
      collection.items[old_key] = nil
      collection.items[new_key] = new_path
      replace_path_in_order(collection.order, old_key, new_path)
      if target_existed then
        collection.count = math.max(0, (collection.count or 1) - 1)
      end
      state.collections_dirty = true
    end
  end

  local regions = state.regions_by_path[old_key]
  if regions then
    state.regions_by_path[old_key] = nil
    for _, region in ipairs(regions) do
      region.path = new_path
    end
    state.regions_by_path[new_key] = regions
    state.regions_dirty = true
  end

  local loudness = state.loudness_cache[old_key]
  if loudness then
    state.loudness_cache[old_key] = nil
    loudness.path = new_path
    state.loudness_cache[new_key] = loudness
    state.loudness_dirty = true
  end

  local failed = state.failed_tasks[old_key]
  if failed then
    state.failed_tasks[old_key] = nil
    failed.path = new_path
    state.failed_tasks[new_key] = failed
    state.failed_tasks_dirty = true
  end

  for _, bucket in pairs(state.project_usage or {}) do
    local entry = bucket.assets and bucket.assets[old_key]
    if entry then
      bucket.assets[old_key] = nil
      local existing = bucket.assets[new_key]
      if existing and existing ~= entry then
        local entry_last = tonumber(entry.last_used) or 0
        local existing_last = tonumber(existing.last_used) or 0
        existing.count = (tonumber(existing.count) or 0)
          + (tonumber(entry.count) or 0)
        if entry_last >= existing_last then
          existing.last_used = entry_last
          existing.action = entry.action
        end
        existing.path = new_path
      else
        entry.path = new_path
        bucket.assets[new_key] = entry
      end
      state.project_usage_dirty = true
    end
  end
end

function migrate_asset_path(asset, new_path, record)
  local old_path = asset.path
  local old_key = path_key(old_path)
  local new_key = path_key(new_path)

  if old_key == new_key then
    return false
  end

  local conflict = state.by_path[new_key]
  if conflict and conflict ~= asset then
    return false
  end

  state.by_path[old_key] = nil
  migrate_path_references(old_path, new_path)
  asset.path = normalize_slashes(new_path)
  asset.name = basename(asset.path)
  asset.folder = dirname(asset.path)
  asset.root = record.path
  asset.root_id = record.id
  asset.library_id = record.library_id
  asset.relative_path = asset_relative_path(
    asset.path,
    record.path
  )
  ensure_asset_identity(asset)
  local library = state.library_by_id[record.library_id]
  asset.library = library and library.name or asset.library
  asset.missing = not reaper.file_exists(asset.path)
  asset._search_blob = nil
  asset.artwork_checked = false
  state.database_ordered_assets = nil

  -- A relink changes the physical identity even when the target happens to
  -- have the same byte length. Never carry a sampled result across paths.
  clear_asset_fingerprint(asset)

  state.by_path[new_key] = asset
  return true
end

function validate_relinked_root(record, new_root)
  for _, other in ipairs(state.root_records) do
    if other.id ~= record.id then
      if path_key(other.path) == path_key(new_root)
        or path_is_inside(new_root, other.path)
        or path_is_inside(other.path, new_root) then
        return false, other
      end
    end
  end
  return true
end

function new_relink_plan(record, new_root, job_token)
  return {
    record = record,
    old_root = record.path,
    new_root = new_root,
    entries = {},
    targets = {},
    conflicts = {},
    missing = 0,
    external_artwork = 0,
    assets = state.assets,
    index = 1,
    total = #state.assets,
    job_token = job_token,
  }
end

function process_relink_plan_entry(plan, asset)
  if asset then
    if tostring(asset.root_id or "") == tostring(plan.record.id)
      or path_is_inside(asset.path, plan.record.path) then
      local relative = tostring(asset.relative_path or "")
      if relative == "" then
        relative = asset_relative_path(asset.path, plan.record.path)
      end
      local target = relative == ""
        and plan.new_root
        or join_path(plan.new_root, relative)
      local target_key = path_key(target)
      local conflict = state.by_path[target_key]
      local duplicate_target = plan.targets[target_key]

      if (conflict and conflict ~= asset) or duplicate_target then
        plan.conflicts[#plan.conflicts + 1] = target
      else
        plan.targets[target_key] = asset
      end

      if not reaper.file_exists(target) then
        plan.missing = plan.missing + 1
      end

      local artwork_relative = relative_path_from_root(
        asset.artwork_path or "",
        plan.record.path
      )
      if tostring(asset.artwork_path or "") ~= ""
        and not artwork_relative then
        plan.external_artwork = plan.external_artwork + 1
      end

      plan.entries[#plan.entries + 1] = {
        asset = asset,
        old_path = asset.path,
        target = target,
        old_artwork = asset.artwork_path or "",
        artwork_relative = artwork_relative,
      }
    end
  end
end

function cancel_relink_plan(session, reason)
  if not session then return end
  state.relink_plan_session = nil
  Jobs.cancel(session.job_token)
  Jobs.finish(session.job_token, true, reason or "canceled")
  set_status("已取消来源重定位计划")
end

function confirm_relink_plan(plan)
  local message = string.format(
    "来源重定位预览\n\n%s\n→ %s\n\n迁移：%d\n缺失：%d\n冲突：%d\n外部封面：%d",
    plan.old_root,
    plan.new_root,
    math.max(0, #plan.entries - plan.missing - #plan.conflicts),
    plan.missing,
    #plan.conflicts,
    plan.external_artwork
  )

  if #plan.conflicts > 0 then
    local preview = {}
    for index = 1, math.min(8, #plan.conflicts) do
      preview[#preview + 1] = plan.conflicts[index]
    end
    reaper.MB(
      message .. "\n\n冲突路径：\n" .. table.concat(preview, "\n"),
      "来源重定位冲突",
      0
    )
    return false
  end

  return reaper.MB(
    message
      .. "\n\n确认后将先创建恢复快照，再一次性迁移全部引用。是否继续？",
    "确认来源重定位",
    4
  ) == 6
end

function commit_relink_plan(plan)
  local record = plan.record
  local new_root = plan.new_root
  if not create_data_backup("source_relink", true) then
    set_status("无法创建重定位恢复快照，未修改任何路径", true)
    Jobs.finish(plan.job_token, false, "backup failed")
    return false
  end

  stop_preview()
  local old_root = record.path
  local old_root_filter = state.root_filter
  local old_record_artwork = record.artwork_path or ""
  local old_canonical_path = record.canonical_path or ""
  local old_volume_label = record.volume_label or ""
  local old_volume_serial = record.volume_serial or ""
  local old_last_seen = record.last_seen or 0
  local root_artwork_relative = relative_path_from_root(
    record.artwork_path or "",
    old_root
  )
  record.path = new_root
  if root_artwork_relative then
    record.artwork_path = root_artwork_relative == ""
      and new_root
      or join_path(new_root, root_artwork_relative)
  end
  record.artwork_checked = false
  record.artwork_scan_version = 0
  rebuild_library_indexes()

  local moved = 0
  local unresolved = 0
  local moved_entries = {}
  for _, entry in ipairs(plan.entries) do
    local asset = entry.asset
    if migrate_asset_path(asset, entry.target, record) then
        if entry.artwork_relative then
          asset.artwork_path = entry.artwork_relative == ""
            and new_root
            or join_path(new_root, entry.artwork_relative)
        end
        moved = moved + 1
        moved_entries[#moved_entries + 1] = entry
        if not reaper.file_exists(entry.target) then
          unresolved = unresolved + 1
        end
    end
  end

  if state.root_filter and path_is_inside(state.root_filter, old_root) then
    local relative = relative_path_from_root(state.root_filter, old_root) or ""
    state.root_filter = relative == "" and new_root or join_path(new_root, relative)
  end

  state.libraries_dirty = true
  mark_database_snapshot_dirty()
  state.results_dirty = true
  invalidate_library_counts()
  invalidate_folder_navigation()
  state.missing_assets = {}
  state.missing_asset_count = 0
  local libraries_saved = save_libraries()
  local database_saved = libraries_saved and save_database()

  if not libraries_saved or not database_saved then
    record.path = old_root
    record.artwork_path = old_record_artwork
    record.canonical_path = old_canonical_path
    record.volume_label = old_volume_label
    record.volume_serial = old_volume_serial
    record.last_seen = old_last_seen
    rebuild_library_indexes()
    for index = #moved_entries, 1, -1 do
      local entry = moved_entries[index]
      migrate_asset_path(entry.asset, entry.old_path, record)
      entry.asset.artwork_path = entry.old_artwork
    end
    state.root_filter = old_root_filter
    state.libraries_dirty = true
    mark_database_snapshot_dirty()
    save_libraries()
    save_database()
    set_status("来源重定位提交失败，已恢复原路径和引用", true)
    Jobs.finish(plan.job_token, false, "commit failed")
    return false
  end
  set_status(string.format("来源已重定位：迁移 %d 条路径，待重新扫描 %d 条", moved, unresolved))
  Jobs.finish(plan.job_token, true)
  start_scan("重定位后增量扫描", { new_root }, { silent = unresolved == 0 })
  return true
end

function process_relink_plan()
  local plan = state.relink_plan_session
  if not plan or not can_run_heavy_job() then return end
  if plan.job_token.cancel_requested then
    cancel_relink_plan(plan, "user canceled")
    return
  end
  if plan.assets ~= state.assets
    or state.root_by_id[plan.record.id] ~= plan.record then
    cancel_relink_plan(plan, "catalog changed")
    set_status("素材库结构已变化，请重新开始来源重定位", true)
    return
  end

  local processed = 0
  local deadline = reaper.time_precise() + RELINK_PLAN_FRAME_BUDGET
  while plan.index <= plan.total
    and processed < RELINK_PLAN_FILES_PER_FRAME
    and reaper.time_precise() < deadline do
    process_relink_plan_entry(plan, plan.assets[plan.index])
    plan.index = plan.index + 1
    processed = processed + 1
  end
  if plan.index <= plan.total then return end

  plan.assets = nil
  state.relink_plan_session = nil
  if not confirm_relink_plan(plan) then
    Jobs.finish(plan.job_token, true, "not confirmed")
    return
  end
  commit_relink_plan(plan)
end

function relink_root(record, supplied_path)
  if not record then return false end
  if state.relink_plan_session or state.scan or state.import_session
    or state.root_removal_session or state.artwork_reset_session
    or state.precache_session or state.duplicate_scan
    or state.duplicate_confirmation or state.missing_audit then
    set_status("请等待当前后台任务完成后再重新定位来源", true)
    return false
  end

  local new_root = supplied_path
    or choose_folder("重新定位来源路径", record.path)
  if not new_root or trim(new_root) == "" then return false end
  new_root = canonical_source_path(new_root)
  if not directory_exists(new_root) then
    set_status("新来源目录不存在或无法访问：" .. new_root, true)
    return false
  end
  local valid, conflict = validate_relinked_root(record, new_root)
  if not valid then
    set_status("新来源目录与现有来源重叠：" .. conflict.path, true)
    return false
  end

  cancel_auxiliary_save("source relink")

  local job_token = Jobs.begin(
    "relink_plan",
    "catalog_exclusive",
    false
  )
  if not job_token then
    set_status("另一个维护任务正在运行", true)
    return false
  end
  state.relink_plan_session = new_relink_plan(
    record,
    new_root,
    job_token
  )
  set_status(string.format(
    "正在生成来源重定位计划：0 / %d",
    #state.assets
  ))
  return true
end

function start_missing_audit()
  if state.missing_audit then
    return
  end

  if state.scan or state.import_session or state.precache_session
    or state.duplicate_scan or state.duplicate_confirmation then
    set_status("请等待当前后台任务完成", true)
    return
  end

  local job_token =
    Jobs.begin("missing_audit", "catalog_exclusive", false)

  if not job_token then
    set_status("另一个维护任务正在运行", true)
    return
  end

  local offline = {}
  state.offline_roots = {}
  for _, record in ipairs(state.root_records) do
    if record.enabled and not directory_exists(record.path) then
      offline[record.id] = true
      state.offline_roots[#state.offline_roots + 1] = record
    end
  end

  state.missing_assets = {}
  state.missing_asset_count = 0
  state.missing_audit = {
    index = 1,
    total = #state.assets,
    missing = 0,
    checked = 0,
    offline = offline,
    job_token = job_token,
  }
  set_status("正在检查缺失文件…")
end

function process_missing_audit()
  local session = state.missing_audit
  if not session or state.scan or state.import_session
    or state.precache_session or not can_run_heavy_job() then
    return
  end

  if session.job_token
    and session.job_token.cancel_requested then
    state.missing_audit = nil
    Jobs.finish(session.job_token, true, "canceled")
    return
  end

  local budget = 36
  while budget > 0 and session.index <= session.total do
    local asset = state.assets[session.index]
    session.index = session.index + 1
    session.checked = session.checked + 1
    budget = budget - 1

    local missing = session.offline[tostring(asset.root_id or "")]
      or not reaper.file_exists(asset.path)
    asset.missing = missing == true
    if asset.missing then
      local key = path_key(asset.path)
      state.missing_assets[key] = asset
      session.missing = session.missing + 1
    end
  end

  if session.index > session.total then
    state.missing_asset_count = session.missing
    state.missing_audit = nil
    Jobs.finish(session.job_token, true)
    state.results_dirty = true
    set_status(string.format("缺失检查完成：%d 个离线来源，%d 个缺失素材", #state.offline_roots, state.missing_asset_count), state.missing_asset_count > 0)
  end
end

function sampled_file_fingerprint(path, known_size)
  local file = io.open(path, "rb")
  if not file then
    return nil
  end

  local size = tonumber(known_size) or file:seek("end") or 0
  local chunk_size = 65536
  local positions = { 0, math.max(0, math.floor(size / 2 - chunk_size / 2)), math.max(0, size - chunk_size) }
  local chunks = {}

  for _, position in ipairs(positions) do
    file:seek("set", position)
    chunks[#chunks + 1] = file:read(chunk_size) or ""
  end
  file:close()

  local payload = tostring(size) .. "|" .. table.concat(chunks, "|")
  local reverse_payload = tostring(size) .. "|" .. chunks[3] .. "|" .. chunks[2] .. "|" .. chunks[1]
  return fnv1a(payload) .. fnv1a(reverse_payload)
end

function start_duplicate_scan()
  if state.duplicate_scan then
    return
  end

  if state.scan or state.import_session or state.precache_session
    or state.missing_audit or state.duplicate_confirmation then
    set_status("请等待当前后台任务完成", true)
    return
  end

  local job_token =
    Jobs.begin("duplicate_scan", "catalog_exclusive", false)

  if not job_token then
    set_status("另一个维护任务正在运行", true)
    return
  end

  state.duplicate_groups = {}
  state.duplicate_lookup = {}
  state.duplicate_group_count = 0
  state.duplicate_asset_count = 0
  state.duplicate_confirmed_groups = {}
  state.duplicate_confirmed_lookup = {}
  state.duplicate_confirmed_asset_count = 0
  state.duplicate_confirmation_failures = {}
  state.duplicate_confirmation_failure_count = 0
  state.duplicate_scan = {
    phase = "sizes",
    assets = state.assets,
    asset_index = 1,
    asset_total = #state.assets,
    size_groups = {},
    candidates = {},
    index = 1,
    total = 0,
    failed = 0,
    fingerprint_groups = {},
    duplicate_groups = {},
    duplicate_lookup = {},
    duplicate_asset_count = 0,
    job_token = job_token,
  }
  set_status(string.format("正在读取文件大小：0 / %d", #state.assets))
end

function close_duplicate_confirmation_session(session)
  if session and session.comparison then
    close_duplicate_comparison(session.comparison)
    session.comparison = nil
  end
end

function finish_duplicate_confirmation(session)
  close_duplicate_confirmation_session(session)
  state.duplicate_confirmed_groups = session.confirmed_groups
  state.duplicate_confirmed_lookup = session.confirmed_lookup
  state.duplicate_confirmed_asset_count = session.confirmed_assets
  state.duplicate_confirmation_failures = session.failures
  state.duplicate_confirmation_failure_count = session.failure_count
  state.duplicate_confirmation = nil
  Jobs.finish(session.job_token, true)
  state.results_dirty = true
  set_status(string.format(
    "完整确认完成：%d 组，%d 个素材，读取失败 %d",
    #session.confirmed_groups,
    session.confirmed_assets,
    session.failure_count
  ), session.failure_count > 0)
end

function start_duplicate_confirmation()
  if state.duplicate_confirmation or #state.duplicate_groups == 0 then
    return
  end
  local job_token = Jobs.begin(
    "duplicate_confirmation",
    "catalog_exclusive",
    false
  )
  if not job_token then
    set_status("另一个维护任务正在运行", true)
    return
  end
  state.duplicate_confirmed_groups = {}
  state.duplicate_confirmed_lookup = {}
  state.duplicate_confirmed_asset_count = 0
  state.duplicate_confirmation_failures = {}
  state.duplicate_confirmation_failure_count = 0
  state.duplicate_confirmation = {
    groups = state.duplicate_groups,
    group_index = 1,
    asset_index = 1,
    representative_index = 1,
    partitions = {},
    comparison = nil,
    confirmed_groups = {},
    confirmed_lookup = {},
    confirmed_assets = 0,
    failures = {},
    failure_count = 0,
    comparisons_finished = 0,
    total_assets = state.duplicate_asset_count,
    job_token = job_token,
  }
  set_status("正在逐字节确认重复候选")
end

function mark_duplicate_confirmation_failure(session, asset)
  local key = path_key(asset.path)
  if not session.failures[key] then
    session.failures[key] = asset
    session.failure_count = session.failure_count + 1
  end
end

function finalize_duplicate_confirmation_group(session, candidate_group)
  for partition_index, partition in ipairs(session.partitions) do
    if #partition.assets > 1 then
      local identity = tostring(candidate_group.fingerprint)
        .. ":" .. tostring(partition_index)
      local confirmed = {
        fingerprint = identity,
        assets = partition.assets,
        count = #partition.assets,
        confirmed = true,
      }
      session.confirmed_groups[#session.confirmed_groups + 1] = confirmed
      session.confirmed_assets = session.confirmed_assets + #partition.assets
      for _, asset in ipairs(partition.assets) do
        session.confirmed_lookup[path_key(asset.path)] = identity
      end
    end
  end
end

function advance_duplicate_confirmation_asset(session)
  session.asset_index = session.asset_index + 1
  session.representative_index = 1
  session.comparison = nil
end

function process_duplicate_confirmation()
  local session = state.duplicate_confirmation
  if not session or not can_run_heavy_job() then
    return
  end
  if session.job_token.cancel_requested then
    close_duplicate_confirmation_session(session)
    state.duplicate_confirmation = nil
    Jobs.finish(session.job_token, true, "canceled")
    return
  end

  local candidate_group = session.groups[session.group_index]
  if not candidate_group then
    finish_duplicate_confirmation(session)
    return
  end
  local asset = candidate_group.assets[session.asset_index]
  if not asset then
    finalize_duplicate_confirmation_group(session, candidate_group)
    session.group_index = session.group_index + 1
    session.asset_index = 1
    session.representative_index = 1
    session.partitions = {}
    return
  end
  if #session.partitions == 0 then
    session.partitions[1] = { representative = asset, assets = { asset } }
    advance_duplicate_confirmation_asset(session)
    return
  end

  local partition = session.partitions[session.representative_index]
  if not partition then
    session.partitions[#session.partitions + 1] = {
      representative = asset,
      assets = { asset },
    }
    advance_duplicate_confirmation_asset(session)
    return
  end
  if not session.comparison then
    local comparison, open_error = begin_duplicate_comparison(
      partition.representative.path,
      asset.path
    )
    if not comparison then
      if open_error == "left_open" then
        for _, previous in ipairs(partition.assets) do
          mark_duplicate_confirmation_failure(session, previous)
        end
        table.remove(session.partitions, session.representative_index)
      else
        mark_duplicate_confirmation_failure(session, asset)
        advance_duplicate_confirmation_asset(session)
      end
      return
    end
    session.comparison = comparison
  end

  local result = step_duplicate_comparison(session.comparison)
  if result == "pending" then
    return
  end
  session.comparisons_finished = session.comparisons_finished + 1
  session.comparison = nil
  if result == "equal" then
    partition.assets[#partition.assets + 1] = asset
    advance_duplicate_confirmation_asset(session)
  elseif result == "different" then
    session.representative_index = session.representative_index + 1
  else
    mark_duplicate_confirmation_failure(session, asset)
    mark_duplicate_confirmation_failure(session, partition.representative)
    advance_duplicate_confirmation_asset(session)
  end
end

function finish_duplicate_scan(session)
  local duplicates = session.sorted_groups or session.duplicate_groups or {}
  local lookup = session.duplicate_lookup or {}
  local asset_count = session.duplicate_asset_count or 0

  state.duplicate_groups = duplicates
  state.duplicate_lookup = lookup
  state.duplicate_group_count = #duplicates
  state.duplicate_asset_count = asset_count
  state.duplicate_scan = nil
  Jobs.finish(session.job_token, true)
  state.results_dirty = true
  mark_database_snapshot_dirty()
  set_status(string.format("候选检查完成：%d 组，%d 个素材", #duplicates, asset_count))
end

function process_duplicate_scan()
  local session = state.duplicate_scan
  if not session or state.scan or state.import_session
    or state.precache_session or not can_run_heavy_job() then
    return
  end

  if session.job_token
    and session.job_token.cancel_requested then
    state.duplicate_scan = nil
    Jobs.finish(session.job_token, true, "canceled")
    return
  end

  if session.phase == "sizes" then
    local processed = 0
    local deadline = reaper.time_precise()
      + DUPLICATE_STAT_FRAME_BUDGET
    while session.asset_index <= session.asset_total
      and processed < DUPLICATE_STAT_FILES_PER_FRAME
      and reaper.time_precise() < deadline do
      local asset = session.assets[session.asset_index]
      session.asset_index = session.asset_index + 1
      processed = processed + 1
      local size = asset and asset.ready and file_size(asset.path) or 0
      if asset and size > 0 then
        if size ~= (tonumber(asset.size) or 0) then
          asset.size = size
          clear_asset_fingerprint(asset)
          mark_asset_database_change(asset)
        end
        add_duplicate_size_candidate(
          session.size_groups,
          session.candidates,
          size,
          asset
        )
      end
    end
    if session.asset_index > session.asset_total then
      session.assets = nil
      session.size_groups = nil
      session.phase = "fingerprints"
      session.index = 1
      session.total = #session.candidates
      set_status(string.format(
        "正在检查重复候选：%d 个同尺寸文件",
        session.total
      ))
    end
    return
  end

  if session.phase == "sort" then
    local result, sorted = step_incremental_result_job(
      session.sort_job,
      DUPLICATE_SORT_ITEMS_PER_FRAME
    )
    if result == "complete" then
      session.sorted_groups = sorted
      session.sort_job = nil
      finish_duplicate_scan(session)
    end
    return
  end

  local asset = session.candidates[session.index]
  if not asset then
    session.candidates = nil
    session.fingerprint_groups = nil
    session.phase = "sort"
    session.sort_job = begin_incremental_result_job(
      session.duplicate_groups,
      function() return true end,
      function(left, right)
        if left.count == right.count then
          return left.fingerprint < right.fingerprint
        end
        return left.count > right.count
      end,
      nil,
      nil
    )
    return
  end

  session.index = session.index + 1
  local size = file_size(asset.path)
  if size <= 0 then
    clear_asset_fingerprint(asset)
    session.failed = session.failed + 1
    return
  end
  -- A size-only cache cannot detect an external replacement with identical
  -- length. An explicit audit therefore resamples every candidate.
  local before = duplicate_file_stat(asset.path, size)
  local fingerprint = sampled_file_fingerprint(asset.path, size)
  local after = duplicate_file_stat(asset.path, size)
  local changed_during_read = duplicate_file_changed_since(before, after)
  if fingerprint and not changed_during_read then
    record_asset_fingerprint(asset, fingerprint, after)
    local became_duplicate = add_duplicate_fingerprint_asset(
      session.fingerprint_groups,
      session.duplicate_groups,
      session.duplicate_lookup,
      fingerprint,
      asset,
      path_key
    )
    if became_duplicate then
      local group = session.fingerprint_groups[fingerprint]
      if group.count == 2 then
        session.duplicate_asset_count =
          session.duplicate_asset_count + 2
      else
        session.duplicate_asset_count =
          session.duplicate_asset_count + 1
      end
    end
  else
    clear_asset_fingerprint(asset)
    session.failed = session.failed + 1
  end

end

function remove_library(library_id)
  local library = state.library_by_id[library_id]

  if not library then
    return false
  end

  local roots = {}

  for _, record in ipairs(library.roots or {}) do
    roots[#roots + 1] = record
  end

  return start_root_removal(roots, library_id)
end

function roots_for_library(library_id)
  local result = {}
  local library = state.library_by_id[library_id]

  for _, record in ipairs(library and library.roots or {}) do
    if record.enabled then
      result[#result + 1] = record.path
    end
  end

  return result
end

function reset_interface_settings()
  stop_preview()
  clear_row_selection()
  state.search = ""
  state.view = "all"
  state.root_filter = nil
  state.library_filter_id = nil
  state.folder_browser_open = false
  state.expanded_source_folders = {}
  state.expanded_folder_nodes = {}
  invalidate_folder_navigation()
  state.active_collection_id = nil
  state.status_filter = nil
  state.sort_mode = "name"
  state.sort_desc = false
  state.auto_preview = true
  state.watch_enabled = true
  state.watch_interval = WATCH_INTERVAL
  state.watch_silent = true
  state.resume_scan_on_start = true
  state.auto_backup = true
  state.backup_keep_count = 7
  state.pitch = 0
  state.rate = 1
  state.gain_db = 0
  state.preserve_pitch = true
  state.loop = false
  state.reverse = false
  state.region_start = 0
  state.region_end = 1
  state.insert_prefix = ""
  state.insert_suffix = ""
  AppState.set("enter_insert_shortcuts", false)
  state.insert_lowercase = true
  state.insert_fade_ms = 5
  state.transfer_dir = DEFAULT_TRANSFER_DIR
  state.transfer_template = "{name}"
  state.transfer_format = "wav24"
  state.transfer_sample_rate = "source"
  state.transfer_channels = "source"
  state.transfer_scope = "selection"
  state.transfer_collision = "increment"
  state.transfer_fade_in_ms = 5
  state.transfer_fade_out_ms = 20
  state.transfer_smart_tail = false
  state.transfer_tail_threshold_db = -60
  state.transfer_tail_max_ms = 5000
  state.transfer_tail_hold_ms = 180
  state.transfer_normalize = "off"
  state.transfer_normalize_target = -1
  state.transfer_insert_after = false
  state.transfer_open_dir_after = false
  state.transfer_lowercase = false
  state.transfer_dither = true
  state.transfer_noise_shaping = false
  state.transfer_preserve_metadata = true
  state.transfer_variants_enabled = false
  state.transfer_variant_pitches = ""
  state.transfer_variant_rates = ""
  state.transfer_variant_gains = ""
  state.transfer_variant_include_reverse = false
  state.transfer_variant_auto_suffix = true
  state.transfer_last_output = ""
  state.transfer_last_outputs = {}
  state.transfer_last_error = ""
  state.transfer_last_summary = ""
  state.theme_preset = "dark"
  state.custom_accent_hex = "#1F6FCC"
  state.custom_shell_hex = "#101114"
  state.language = "zh"
  state.mini_wave_points = MINI_WAVE_DEFAULT_POINTS
  state.precache_points = 4096
  state.ui_density = "compact"
  state.surface_style = "dark"
  state.wave_scrub_enabled = true
  state.loop_selection = true
  state.preview_control_layout = "studio_strip"
  state.multichannel_waveform = true
  AppState.set("spectral_peaks_enabled", false)
  state.bottom_panel_height = 330
  state.preview_channel_mode = "original"
  state.preview_channel_asset_key = nil
  state.preview_channel_count = 0
  state.preview_channel_selection = {}
  state.preview_channel_anchor = 1
  state.preview_channel_strip_expanded = false
  state.loudness_match = false
  state.loudness_target_db = -18
  state.transient_threshold = 0.24
  state.transient_min_gap_ms = 140
  state.transient_pre_ms = 20
  state.transient_post_ms = 180
  state.transient_smoothing_ms = 8
  state.transient_max_regions = 64
  state.transient_replace_existing = true
  state.show_loudness_metrics = false
  state.loudness_show_i = true
  state.loudness_show_m = true
  state.loudness_show_s = false
  state.loudness_show_tp = false
  state.waveform_hex = "#D7D8DA"
  state.waveform_selected_hex = "#EAF3FF"
  state.waveform_played_hex = "#8FB8D8"
  state.waveform_marked_hex = "#F0C85A"
  state.played_text_hex = "#F0C85A"
  state.played_text_enabled = true
  state.played_waveform_enabled = false
  state.restore_played_on_start = false
  state.artwork_enabled = true
  state.inspector_artwork_pinned = true
  state.selection_hex = "#2789E9"
  state.playhead_hex = "#50E36D"
  state.region_hex = "#E2B764"
  apply_surface_style()
  apply_theme_palette()
  apply_waveform_palette()
  state.wave_view_start = 0
  state.wave_view_end = 1
  state.sidebar_visible = true
  state.sidebar_sections = {
    sounds = true,
    libraries = true,
    ucs = true,
    collections = true,
    saved_searches = true,
    workflow = true,
    activity = true,
  }
  state.inspector_visible = true
  state.inspector_width = INSPECTOR_DEFAULT_W
  state.column_visible = {
    waveform = true,
    filename = true,
    status = true,
    description = true,
    duration = true,
    format = true,
    library = true,
    category = false,
    subcategory = false,
    catid = false,
    channels = false,
    sample_rate = false,
    bit_depth = false,
    path = false,
  }
  state.column_widths = {
    waveform = 350,
    filename = 265,
    status = 88,
    description = 320,
    duration = 104,
    format = 118,
    library = 180,
    category = 140,
    subcategory = 150,
    catid = 90,
    channels = 80,
    sample_rate = 100,
    bit_depth = 90,
    path = 360,
  }
  state.results_dirty = true
  state.config_dirty = true
  set_status("已重置界面与试听设置")
end

function cancel_catalog_jobs(reason)
  reason = tostring(reason or "canceled")
  cancel_auxiliary_save(reason)
  cancel_database_snapshot(reason)
  if state.root_removal_session then
    local removal = state.root_removal_session
    for index = #removal.cleanup_records, 1, -1 do
      restore_root_removal_record(removal.cleanup_records[index])
    end
    flush_root_removal_asset_changes(removal, false)
    Jobs.cancel(removal.job_token)
    Jobs.finish(removal.job_token, true, reason)
    state.root_removal_session = nil
  end

  if state.transfer_job then
    finish_transfer_job(state.transfer_job, true)
  end

  if state.import_session
    and state.import_session.current
    and state.import_session.current.wave_job then
    destroy_wave_job(
      state.import_session.current.wave_job
    )
  end

  local catalog_job = state.import_session
      and state.import_session.job_token
    or state.scan
      and state.scan.job_token

  Jobs.cancel(catalog_job)
  Jobs.finish(catalog_job, true, reason)
  state.scan = nil
  state.import_session = nil
  state.import_cancel_requested = false

  local maintenance_fields = {
    "artwork_reset_session",
    "cache_verify_session",
    "missing_audit",
    "duplicate_scan",
    "duplicate_confirmation",
    "relink_plan_session",
  }

  for _, field in ipairs(maintenance_fields) do
    local session = state[field]

    if session and session.job_token then
      close_duplicate_confirmation_session(session)
      Jobs.cancel(session.job_token)
      Jobs.finish(session.job_token, true, reason)
    end

    state[field] = nil
  end
end

function reset_database_keep_roots()
  local answer = reaper.MB(
    "将清空 PsyReaSFX 数据库和波形缓存，"
      .. "然后重新扫描现有音效库。\n\n继续吗？",
    SCRIPT_NAME,
    4
  )

  if answer ~= 6 then
    return
  end

  stop_preview()
  cancel_catalog_jobs("database reset")
  state.assets = {}
  state.by_path = {}
  state.database_ordered_assets = nil
  state.database_generation = 0
  clear_asset_changes(state.database_changes)
  state.results = {}
  state.results_job = nil
  state.results_dirty = true
  state.favorites = {}
  state.recent = {}
  state.active_collection_id = nil
  state.status_filter = nil
  clear_row_selection()
  clear_wave_cache()
  os.remove(DATABASE_FILE)
  os.remove(DATABASE_JOURNAL_FILE)
  os.remove(HISTORY_FILE)
  os.remove(LAST_PLAYED_SESSION_FILE)
  os.remove(SCAN_CHECKPOINT_FILE)
  state.clear_scan_checkpoint_after_database_save = false
  os.remove(FAILED_TASKS_FILE)
  state.failed_tasks = {}
  state.failed_tasks_dirty = false
  state.missing_assets = {}
  state.missing_asset_count = 0
  state.offline_roots = {}
  state.duplicate_groups = {}
  state.duplicate_lookup = {}
  state.duplicate_group_count = 0
  state.duplicate_asset_count = 0
  state.duplicate_confirmed_groups = {}
  state.duplicate_confirmed_lookup = {}
  state.duplicate_confirmed_asset_count = 0
  state.duplicate_confirmation_failures = {}
  state.duplicate_confirmation_failure_count = 0
  state.history_dirty = false
  state.preview_history_assets = {}
  state.session_played = {}
  state.last_session_played = {}
  state.session_played_dirty = false
  mark_database_snapshot_dirty()
  state.config_dirty = true
  save_config()

  if #state.roots > 0 then
    start_scan("重建数据库")
  else
    set_status("数据库已清空；请添加音效库")
  end
end

function factory_reset()
  local answer = reaper.MB(
    "这会删除全部音效库路径、收藏、播放列表、保存搜索、"
      .. "历史、索引、波形缓存和界面设置。\n\n继续吗？",
    SCRIPT_NAME,
    4
  )

  if answer ~= 6 then
    return
  end

  stop_preview()
  cancel_catalog_jobs("factory reset")
  state.roots = {}
  state.libraries = {}
  state.library_by_id = {}
  state.root_records = {}
  state.root_by_id = {}
  state.root_by_path = {}
  state.library_filter_id = nil
  state.assets = {}
  state.by_path = {}
  state.database_ordered_assets = nil
  state.database_generation = 0
  clear_asset_changes(state.database_changes)
  state.results = {}
  state.results_job = nil
  state.results_dirty = true
  state.favorites = {}
  state.recent = {}
  state.collections = {}
  state.collection_by_id = {}
  state.active_collection_id = nil
  state.saved_searches = {}
  state.regions_by_path = {}
  state.regions_dirty = false
  state.loudness_cache = {}
  state.loudness_dirty = false
  state.status_filter = nil
  clear_row_selection()
  clear_wave_cache()
  reset_interface_settings()
  os.remove(CONFIG_FILE)
  os.remove(LIBRARIES_FILE)
  os.remove(DATABASE_FILE)
  os.remove(DATABASE_JOURNAL_FILE)
  os.remove(COLLECTIONS_FILE)
  os.remove(SAVED_SEARCHES_FILE)
  os.remove(HISTORY_FILE)
  os.remove(LAST_PLAYED_SESSION_FILE)
  os.remove(REGIONS_FILE)
  os.remove(LOUDNESS_FILE)
  os.remove(SCAN_CHECKPOINT_FILE)
  state.clear_scan_checkpoint_after_database_save = false
  os.remove(FAILED_TASKS_FILE)
  os.remove(BACKUP_STATE_FILE)
  os.remove(PROJECT_USAGE_FILE)
  state.config_dirty = false
  state.libraries_dirty = false
  state.db_dirty = false
  state.collections_dirty = false
  state.searches_dirty = false
  state.history_dirty = false
  state.preview_history_assets = {}
  state.session_played = {}
  state.last_session_played = {}
  state.session_played_dirty = false
  state.failed_tasks = {}
  state.failed_tasks_dirty = false
  state.project_usage = {}
  state.project_usage_dirty = false
  state.current_project_bin_id = nil
  state.missing_assets = {}
  state.missing_asset_count = 0
  state.offline_roots = {}
  state.duplicate_groups = {}
  state.duplicate_lookup = {}
  state.duplicate_group_count = 0
  state.duplicate_asset_count = 0
  state.duplicate_confirmed_groups = {}
  state.duplicate_confirmed_lookup = {}
  state.duplicate_confirmed_asset_count = 0
  state.duplicate_confirmation_failures = {}
  state.duplicate_confirmation_failure_count = 0

  state.wave_cache_dir =
    DEFAULT_WAVE_CACHE_DIR

  apply_wave_cache_directory(
    DEFAULT_WAVE_CACHE_DIR
  )

  set_status("PsyReaSFX 已恢复出厂状态")
end

----------------------------------------------------------------
-- Drawing helpers
----------------------------------------------------------------

function draw_waveform(
  draw_list,
  waveform,
  x,
  y,
  width,
  height,
  wave_color
)
  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + width,
    y + height,
    COLOR.waveform_bg
  )

  ImGui.DrawList_AddLine(
    draw_list,
    x,
    y + height * 0.5,
    x + width,
    y + height * 0.5,
    COLOR.grid,
    1
  )

  if not waveform or waveform.count <= 0 then
    return
  end

  local count = waveform.count
  local center = y + height * 0.5
  local half = height * 0.45
  local step = width / count

  for index = 1, count do
    local amplitude =
      waveform.peaks[index] or 0

    local px =
      x + (index - 0.5) * step

    ImGui.DrawList_AddLine(
      draw_list,
      px,
      center - amplitude * half,
      px,
      center + amplitude * half,
      wave_color,
      math.max(1, step)
    )
  end
end

function reset_wave_view()
  state.wave_view_start = 0
  state.wave_view_end = 1
  state.wave_pan_last_x = nil
end

function wave_view_span()
  return math.max(
    0.001,
    state.wave_view_end - state.wave_view_start
  )
end

function wave_source_percent(local_percent)
  return clamp(
    state.wave_view_start
      + wave_view_span()
        * clamp(local_percent, 0, 1),
    0,
    1
  )
end

function wave_view_percent(source_percent)
  return (
    source_percent - state.wave_view_start
  ) / wave_view_span()
end

function zoom_wave_view(anchor_percent, wheel_delta)
  local old_span = wave_view_span()
  local factor = 0.82 ^ wheel_delta
  local new_span = clamp(old_span * factor, 0.015, 1)
  local anchor = wave_source_percent(anchor_percent)
  local anchor_ratio = clamp(anchor_percent, 0, 1)
  local new_start = anchor - new_span * anchor_ratio

  new_start = clamp(new_start, 0, 1 - new_span)
  state.wave_view_start = new_start
  state.wave_view_end = new_start + new_span
end

function pan_wave_view(delta_percent)
  local span = wave_view_span()
  local new_start = clamp(
    state.wave_view_start + delta_percent,
    0,
    1 - span
  )

  state.wave_view_start = new_start
  state.wave_view_end = new_start + span
end

function spectral_peak_color(frequency, tonality, fallback)
  frequency = clamp(tonumber(frequency) or 0, 20, 20000)
  tonality = clamp(tonumber(tonality) or 0, 0, 1)

  local normalized =
    math.log(frequency / 20)
      / math.log(20000 / 20)
  local low = 0x5964EFFF
  local low_mid = 0x20B9D6FF
  local high_mid = 0x63D36EFF
  local high = 0xF2B45CFF
  local color

  if normalized < 0.34 then
    color = rgba_mix(low, low_mid, normalized / 0.34)
  elseif normalized < 0.68 then
    color = rgba_mix(
      low_mid,
      high_mid,
      (normalized - 0.34) / 0.34
    )
  else
    color = rgba_mix(
      high_mid,
      high,
      (normalized - 0.68) / 0.32
    )
  end

  return rgba_mix(
    fallback or COLOR.waveform,
    color,
    0.34 + tonality * 0.66
  )
end

function draw_waveform_window(
  draw_list,
  waveform,
  asset,
  x,
  y,
  width,
  height,
  wave_color,
  start_percent,
  end_percent
)
  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + width,
    y + height,
    COLOR.waveform_bg
  )

  if not waveform or waveform.count <= 0 then
    return
  end

  local count = waveform.count
  local first_index = clamp(
    math.floor(start_percent * math.max(0, count - 1)) + 1,
    1,
    count
  )
  local last_index = clamp(
    math.ceil(end_percent * math.max(0, count - 1)) + 1,
    first_index,
    count
  )

  local visible_count =
    math.max(1, last_index - first_index + 1)
  local pixels = math.max(1, math.floor(width))
  local channel_peaks = waveform.channel_peaks
  local channel_count =
    channel_peaks
      and clamp(waveform.channels or #channel_peaks, 1, 8)
      or 1
  local ruler_height = 20
  local lanes_y = y + ruler_height
  local lanes_height = math.max(18, height - ruler_height)
  local lane_height = lanes_height / channel_count

  local function draw_lane(peaks, channel, lane_y)
    local channel_selected =
      preview_channel_is_selected(asset, channel)
    local lane_wave_color =
      channel_selected
        and wave_color
        or rgba_with_alpha(wave_color, 0x32)
    local center = lane_y + lane_height * 0.5
    local half = math.max(2, lane_height * 0.38)

    ImGui.DrawList_AddLine(
      draw_list,
      x,
      center,
      x + width,
      center,
      rgba_with_alpha(COLOR.grid, 0x80),
      1
    )

    if channel > 1 then
      ImGui.DrawList_AddLine(
        draw_list,
        x,
        lane_y,
        x + width,
        lane_y,
        rgba_with_alpha(COLOR.border, 0x90),
        1
      )
    end

    for pixel = 0, pixels - 1 do
      local range_start =
        first_index
        + math.floor(pixel / pixels * visible_count)
      local range_end =
        first_index
        + math.floor((pixel + 1) / pixels * visible_count)

      range_start = clamp(range_start, first_index, last_index)
      range_end = clamp(
        math.max(range_start, range_end),
        range_start,
        last_index
      )

      local amplitude = 0
      local peak_index = range_start

      for index = range_start, range_end do
        local candidate = peaks[index] or 0
        if candidate >= amplitude then
          amplitude = candidate
          peak_index = index
        end
      end

      local px = x + pixel
      local pixel_color = lane_wave_color

      if state.spectral_peaks_enabled
        and waveform.spectral_available
        and waveform.spectral_frequency then
        pixel_color = spectral_peak_color(
          waveform.spectral_frequency[peak_index],
          waveform.spectral_tonality
            and waveform.spectral_tonality[peak_index]
            or 0,
          lane_wave_color
        )
        if not channel_selected then
          pixel_color = rgba_with_alpha(pixel_color, 0x32)
        end
      end

      ImGui.DrawList_AddLine(
        draw_list,
        px,
        center - amplitude * half,
        px,
        center + amplitude * half,
        pixel_color,
        1
      )
    end

    if lane_height >= 18 then
      local label =
        preview_channel_label(channel, channel_count)
      local label_width = channel_count > 2 and 42 or 24
      local label_x = x + width - label_width - 7
      local label_y = lane_y + 2

      ImGui.DrawList_AddRectFilled(
        draw_list,
        label_x,
        label_y,
        label_x + label_width,
        label_y + 16,
        rgba_with_alpha(COLOR.window, 0xD8),
        4
      )

      ImGui.DrawList_AddText(
        draw_list,
        label_x + 6,
        label_y + 1,
        channel_selected and COLOR.accent or COLOR.dim,
        label
      )
    end
  end

  for channel = 1, channel_count do
    draw_lane(
      channel_peaks and channel_peaks[channel] or waveform.peaks,
      channel,
      lanes_y + (channel - 1) * lane_height
    )
  end
end

function draw_wave_time_ruler(
  draw_list,
  asset,
  x,
  y,
  width,
  height
)
  if not asset or (asset.duration or 0) <= 0 then
    return
  end

  local duration = asset.duration
  local span_seconds = duration * wave_view_span()
  local divisions = width > 1100 and 8 or 5

  for index = 0, divisions do
    local local_percent = index / divisions
    local source_percent = wave_source_percent(local_percent)
    local px = x + width * local_percent
    local seconds = duration * source_percent

    ImGui.DrawList_AddLine(
      draw_list,
      px,
      y,
      px,
      y + height,
      rgba_with_alpha(COLOR.grid, (index == 0 or index == divisions) and 0x90 or 0x50),
      1
    )

    if index < divisions then
      ImGui.DrawList_AddText(
        draw_list,
        px + 4,
        y + 3,
        COLOR.dim,
        format_time(seconds)
      )
    end
  end

  ImGui.DrawList_AddText(
    draw_list,
    x + width - 82,
    y + 3,
    COLOR.dim,
    string.format("×%.1f", 1 / wave_view_span())
  )
end

function text_width(text)
  return ImGui.CalcTextSize(ctx, tostring(text))
end

function tooltip(text, max_chars)
  if not ImGui.IsItemHovered(ctx) then
    return
  end

  local now = reaper.time_precise()
  local translated =
    translate_ui_text(text)

  local hover_was_interrupted =
    now - (state.tooltip_last_seen_at or 0)
      > 0.14

  if state.tooltip_hover_text ~= translated
    or hover_was_interrupted then
    state.tooltip_hover_text = translated
    state.tooltip_hover_started_at = now
  end

  state.tooltip_last_seen_at = now

  if now - state.tooltip_hover_started_at
      < state.tooltip_delay then
    return
  end

  local mouse_x, mouse_y =
    ImGui.GetMousePos(ctx)

  -- 这里只登记提示内容，不创建 Popup 或 Tooltip 窗口。
  -- 主窗口完成布局后统一绘制，避免 Popup 自动尺寸在切换图标时闪烁。
  state.tooltip_pending_text = max_chars == false
    and translated
    or compact(translated, max_chars or 58)

  state.tooltip_pending_mouse_x =
    mouse_x

  state.tooltip_pending_mouse_y =
    mouse_y
end

function draw_tooltip_overlay()
  local text =
    state.tooltip_pending_text

  if not text or text == "" then
    return
  end

  local draw_list

  if type(ImGui.GetForegroundDrawList) == "function" then
    draw_list = ImGui.GetForegroundDrawList(ctx)
  else
    draw_list = ImGui.GetWindowDrawList(ctx)
  end

  local text_width_value, text_height =
    ImGui.CalcTextSize(
      ctx,
      text
    )

  local padding_x = 11
  local padding_y = 7
  local box_width =
    clamp(
      (text_width_value or 0)
        + padding_x * 2,
      120,
      540
    )

  local box_height =
    math.max(
      28,
      (text_height or 14)
        + padding_y * 2
    )

  local window_x, window_y =
    ImGui.GetWindowPos(ctx)

  local window_w, window_h =
    ImGui.GetWindowSize(ctx)

  local x =
    state.tooltip_pending_mouse_x + 15

  local y =
    state.tooltip_pending_mouse_y + 19

  if x + box_width
      > window_x + window_w - 8 then
    x =
      state.tooltip_pending_mouse_x
      - box_width
      - 12
  end

  if y + box_height
      > window_y + window_h - 8 then
    y =
      state.tooltip_pending_mouse_y
      - box_height
      - 12
  end

  x =
    clamp(
      x,
      window_x + 8,
      window_x + window_w
        - box_width
        - 8
    )

  y =
    clamp(
      y,
      window_y + 8,
      window_y + window_h
        - box_height
        - 8
    )

  -- 轻量阴影。
  ImGui.DrawList_AddRectFilled(
    draw_list,
    x + 3,
    y + 4,
    x + box_width + 3,
    y + box_height + 4,
    0x00000066,
    7
  )

  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + box_width,
    y + box_height,
    0x202328F5,
    7
  )

  ImGui.DrawList_AddRect(
    draw_list,
    x + 0.5,
    y + 0.5,
    x + box_width - 0.5,
    y + box_height - 0.5,
    rgba_with_alpha(
      COLOR.border,
      0xB0
    ),
    7,
    0,
    1
  )

  ImGui.DrawList_AddText(
    draw_list,
    x + padding_x,
    y + padding_y,
    COLOR.text,
    text
  )
end

function draw_icon_glyph(draw_list, icon, x, y, size, color_value)
  local left = x + size * 0.22
  local right = x + size * 0.78
  local top = y + size * 0.22
  local bottom = y + size * 0.78
  local center_x = x + size * 0.5
  local center_y = y + size * 0.5
  local thickness = math.max(1.4, size * 0.065)

  if icon == "panel_left" or icon == "panel_right" then
    ImGui.DrawList_AddRect(
      draw_list,
      left,
      top,
      right,
      bottom,
      color_value,
      2,
      0,
      thickness
    )

    local divider =
      icon == "panel_left"
      and x + size * 0.40
      or x + size * 0.60

    ImGui.DrawList_AddLine(
      draw_list,
      divider,
      top,
      divider,
      bottom,
      color_value,
      thickness
    )
  elseif icon == "focus" then
    local arm = size * 0.18
    ImGui.DrawList_AddLine(draw_list, left, top + arm, left, top, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, left, top, left + arm, top, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, right - arm, top, right, top, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, right, top, right, top + arm, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, left, bottom - arm, left, bottom, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, left, bottom, left + arm, bottom, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, right - arm, bottom, right, bottom, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, right, bottom - arm, right, bottom, color_value, thickness)
  elseif icon == "close" or icon == "clear_selection" then
    if icon == "clear_selection" then
      ImGui.DrawList_AddRect(draw_list, left, top, right, bottom, color_value, 2, 0, thickness)
    end
    ImGui.DrawList_AddLine(draw_list, left + 2, top + 2, right - 2, bottom - 2, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, right - 2, top + 2, left + 2, bottom - 2, color_value, thickness)
  elseif icon == "refresh" then
    ImGui.DrawList_AddCircle(draw_list, center_x, center_y, size * 0.22, color_value, 20, thickness)
    ImGui.DrawList_AddTriangleFilled(
      draw_list,
      right - size * 0.02,
      top + size * 0.17,
      right - size * 0.18,
      top + size * 0.16,
      right - size * 0.08,
      top + size * 0.31,
      color_value
    )
  elseif icon == "played_reset" then
    ImGui.DrawList_AddCircle(
      draw_list,
      center_x,
      center_y,
      size * 0.23,
      color_value,
      18,
      thickness
    )
    ImGui.DrawList_AddLine(
      draw_list,
      center_x,
      center_y,
      center_x,
      top + size * 0.12,
      color_value,
      thickness
    )
    ImGui.DrawList_AddLine(
      draw_list,
      center_x,
      center_y,
      right - size * 0.10,
      center_y + size * 0.05,
      color_value,
      thickness
    )
    ImGui.DrawList_AddLine(
      draw_list,
      left + size * 0.05,
      bottom - size * 0.02,
      right - size * 0.02,
      top + size * 0.05,
      COLOR.error,
      thickness
    )
  elseif icon == "settings" then
    ImGui.DrawList_AddCircle(draw_list, center_x, center_y, size * 0.12, color_value, 16, thickness)
    ImGui.DrawList_AddCircle(draw_list, center_x, center_y, size * 0.25, color_value, 20, thickness)
    for index = 0, 7 do
      local angle = index * math.pi / 4
      local x1 = center_x + math.cos(angle) * size * 0.25
      local y1 = center_y + math.sin(angle) * size * 0.25
      local x2 = center_x + math.cos(angle) * size * 0.34
      local y2 = center_y + math.sin(angle) * size * 0.34
      ImGui.DrawList_AddLine(draw_list, x1, y1, x2, y2, color_value, thickness)
    end
  elseif icon == "help" then
    ImGui.DrawList_AddCircle(
      draw_list,
      center_x,
      center_y,
      size * 0.27,
      color_value,
      20,
      thickness
    )
    ImGui.DrawList_AddText(
      draw_list,
      center_x - size * 0.095,
      center_y - size * 0.245,
      color_value,
      "?"
    )
  elseif icon == "speaker" then
    ImGui.DrawList_AddRectFilled(draw_list, left, center_y - size * 0.09, left + size * 0.12, center_y + size * 0.09, color_value)
    ImGui.DrawList_AddTriangleFilled(draw_list, left + size * 0.10, center_y - size * 0.10, center_x, top + size * 0.04, center_x, bottom - size * 0.04, color_value)
    ImGui.DrawList_AddCircle(draw_list, center_x, center_y, size * 0.20, color_value, 16, thickness)
  elseif icon == "play" then
    ImGui.DrawList_AddTriangleFilled(draw_list, left + size * 0.08, top, right, center_y, left + size * 0.08, bottom, color_value)
  elseif icon == "stop" then
    ImGui.DrawList_AddRectFilled(draw_list, left + size * 0.04, top + size * 0.04, right - size * 0.04, bottom - size * 0.04, color_value, 2)
  elseif icon == "insert" then
    ImGui.DrawList_AddLine(draw_list, left, bottom, right, bottom, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x, top, center_x, bottom - size * 0.12, color_value, thickness)
    ImGui.DrawList_AddTriangleFilled(draw_list, center_x - size * 0.12, center_y + size * 0.04, center_x + size * 0.12, center_y + size * 0.04, center_x, bottom - size * 0.04, color_value)
  elseif icon == "transfer" then
    ImGui.DrawList_AddRect(
      draw_list,
      left,
      center_y + size * 0.08,
      right,
      bottom,
      color_value,
      2,
      0,
      thickness
    )
    ImGui.DrawList_AddLine(
      draw_list,
      center_x,
      top,
      center_x,
      center_y + size * 0.10,
      color_value,
      thickness
    )
    ImGui.DrawList_AddTriangleFilled(
      draw_list,
      center_x - size * 0.14,
      center_y - size * 0.03,
      center_x + size * 0.14,
      center_y - size * 0.03,
      center_x,
      center_y + size * 0.15,
      color_value
    )
  elseif icon == "new_track" then
    ImGui.DrawList_AddLine(draw_list, left, top + size * 0.10, right - size * 0.14, top + size * 0.10, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, left, center_y, right - size * 0.14, center_y, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, left, bottom - size * 0.10, right - size * 0.14, bottom - size * 0.10, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, right - size * 0.10, center_y - size * 0.12, right - size * 0.10, center_y + size * 0.12, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, right - size * 0.22, center_y, right + size * 0.02, center_y, color_value, thickness)
  elseif icon == "clock" then
    ImGui.DrawList_AddCircle(draw_list, center_x, center_y, size * 0.25, color_value, 20, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x, center_y, center_x, top + size * 0.10, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x, center_y, right - size * 0.08, center_y + size * 0.10, color_value, thickness)
  elseif icon == "star" then
    for index = 0, 4 do
      local angle1 = -math.pi / 2 + index * 2 * math.pi / 5
      local angle2 = angle1 + 4 * math.pi / 5
      ImGui.DrawList_AddLine(
        draw_list,
        center_x + math.cos(angle1) * size * 0.27,
        center_y + math.sin(angle1) * size * 0.27,
        center_x + math.cos(angle2) * size * 0.27,
        center_y + math.sin(angle2) * size * 0.27,
        color_value,
        thickness
      )
    end
  elseif icon == "folder"
    or icon == "folder_search" then
    ImGui.DrawList_AddRect(draw_list, left, top + size * 0.10, right, bottom, color_value, 2, 0, thickness)
    ImGui.DrawList_AddLine(draw_list, left, top + size * 0.10, center_x - size * 0.05, top + size * 0.10, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x - size * 0.05, top + size * 0.10, center_x + size * 0.03, top, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x + size * 0.03, top, right - size * 0.05, top, color_value, thickness)

    if icon == "folder_search" then
      local lens_x = right - size * 0.08
      local lens_y = bottom - size * 0.08
      local lens_r = size * 0.13

      ImGui.DrawList_AddCircle(
        draw_list,
        lens_x,
        lens_y,
        lens_r,
        color_value,
        14,
        thickness
      )
      ImGui.DrawList_AddLine(
        draw_list,
        lens_x + lens_r * 0.70,
        lens_y + lens_r * 0.70,
        right + size * 0.07,
        bottom + size * 0.07,
        color_value,
        thickness
      )
    end
  elseif icon == "drag" then
    ImGui.DrawList_AddLine(draw_list, left, center_y, right, center_y, color_value, thickness)
    ImGui.DrawList_AddTriangleFilled(draw_list, right, center_y, right - size * 0.18, center_y - size * 0.13, right - size * 0.18, center_y + size * 0.13, color_value)
    ImGui.DrawList_AddLine(draw_list, left, top, left, bottom, color_value, thickness)
  elseif icon == "loop" then
    ImGui.DrawList_AddLine(draw_list, left + size * 0.06, top + size * 0.12, right - size * 0.08, top + size * 0.12, color_value, thickness)
    ImGui.DrawList_AddTriangleFilled(draw_list, right, top + size * 0.12, right - size * 0.16, top, right - size * 0.16, top + size * 0.24, color_value)
    ImGui.DrawList_AddLine(draw_list, right - size * 0.06, bottom - size * 0.12, left + size * 0.08, bottom - size * 0.12, color_value, thickness)
    ImGui.DrawList_AddTriangleFilled(draw_list, left, bottom - size * 0.12, left + size * 0.16, bottom - size * 0.24, left + size * 0.16, bottom, color_value)
  elseif icon == "reverse" then
    ImGui.DrawList_AddTriangleFilled(draw_list, left, center_y, center_x + size * 0.06, top, center_x + size * 0.06, bottom, color_value)
    ImGui.DrawList_AddLine(draw_list, center_x + size * 0.06, center_y, right, center_y, color_value, thickness)
  elseif icon == "sliders" then
    local ys = { top + size * 0.08, center_y, bottom - size * 0.08 }
    local knobs = { x + size * 0.38, x + size * 0.62, x + size * 0.46 }
    for index = 1, 3 do
      ImGui.DrawList_AddLine(draw_list, left, ys[index], right, ys[index], color_value, thickness)
      ImGui.DrawList_AddCircleFilled(draw_list, knobs[index], ys[index], size * 0.06, color_value, 12)
    end
  elseif icon == "zoom_reset" then
    ImGui.DrawList_AddCircle(draw_list, center_x - size * 0.06, center_y - size * 0.05, size * 0.18, color_value, 16, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x + size * 0.07, center_y + size * 0.08, right, bottom, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x - size * 0.14, center_y - size * 0.05, center_x + size * 0.02, center_y - size * 0.05, color_value, thickness)
  elseif icon == "region_add" then
    ImGui.DrawList_AddRect(draw_list, left, top + size * 0.08, right, bottom - size * 0.08, color_value, 2, 0, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x, top + size * 0.17, center_x, bottom - size * 0.17, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, left + size * 0.14, center_y, right - size * 0.14, center_y, color_value, thickness)
  elseif icon == "regions" then
    for index = 0, 2 do
      local yy = top + size * (0.08 + index * 0.22)
      ImGui.DrawList_AddRect(draw_list, left, yy, right, yy + size * 0.12, color_value, 1, 0, thickness)
    end
  elseif icon == "transient" then
    ImGui.DrawList_AddLine(draw_list, left, center_y, left + size * 0.15, center_y, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, left + size * 0.15, center_y, center_x - size * 0.08, top, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x - size * 0.08, top, center_x + size * 0.02, bottom, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x + size * 0.02, bottom, right - size * 0.12, center_y, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, right - size * 0.12, center_y, right, center_y, color_value, thickness)
  elseif icon == "channel"
    or icon == "channel_stereo"
    or icon == "channel_left"
    or icon == "channel_right"
    or icon == "channel_mono"
    or icon == "channel_multi" then
    local quiet =
      rgba_with_alpha(color_value, 0x58)

    if icon == "channel_left" then
      ImGui.DrawList_AddLine(draw_list, left, top, left, bottom, color_value, thickness * 1.25)
      ImGui.DrawList_AddLine(draw_list, right, top + size * 0.10, right, bottom - size * 0.10, quiet, thickness)
    elseif icon == "channel_right" then
      ImGui.DrawList_AddLine(draw_list, left, top + size * 0.10, left, bottom - size * 0.10, quiet, thickness)
      ImGui.DrawList_AddLine(draw_list, right, top, right, bottom, color_value, thickness * 1.25)
    elseif icon == "channel_mono" then
      ImGui.DrawList_AddLine(draw_list, center_x, top, center_x, bottom, color_value, thickness * 1.25)
    elseif icon == "channel_multi" then
      local xs = {
        left,
        center_x - size * 0.10,
        center_x + size * 0.10,
        right,
      }

      for index, line_x in ipairs(xs) do
        local inset = (index % 2 == 0) and size * 0.08 or 0
        ImGui.DrawList_AddLine(
          draw_list,
          line_x,
          top + inset,
          line_x,
          bottom - inset,
          color_value,
          thickness
        )
      end
    else
      ImGui.DrawList_AddLine(draw_list, left, top, left, bottom, color_value, thickness)
      ImGui.DrawList_AddLine(draw_list, right, top, right, bottom, color_value, thickness)
    end
  elseif icon == "loudness" then
    for index = 0, 3 do
      local bar_x = left + index * size * 0.15
      local bar_h = size * (0.12 + index * 0.08)
      ImGui.DrawList_AddRectFilled(draw_list, bar_x, bottom - bar_h, bar_x + size * 0.08, bottom, color_value)
    end
  elseif icon == "more" then
    for index = -1, 1 do
      ImGui.DrawList_AddCircleFilled(
        draw_list,
        center_x + index * size * 0.16,
        center_y,
        size * 0.045,
        color_value,
        12
      )
    end
  else
    ImGui.DrawList_AddCircleFilled(draw_list, center_x, center_y, size * 0.08, color_value, 12)
  end
end

function icon_button(id, icon, tooltip_text, active, size, pulse)
  size = size or UI_METRIC.icon_button

  local x, y = ImGui.GetCursorScreenPos(ctx)

  ImGui.InvisibleButton(
    ctx,
    "##icon_" .. tostring(id),
    size,
    size
  )

  local clicked = ImGui.IsItemClicked(ctx, 0)
  local hovered = ImGui.IsItemHovered(ctx)
  local item_active = ImGui.IsItemActive(ctx)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local radius = math.max(4, UI_METRIC.radius_small)

  -- Studio-style controls stay visually quiet at rest. Hover and enabled
  -- states use a soft tint instead of permanent boxes and borders.
  if active or item_active or hovered then
    local pulse_alpha =
      pulse
      and math.floor(
        0x22
        + 0x20 * (
          0.5
          + 0.5 * math.sin(reaper.time_precise() * 6.5)
        )
      )
      or 0x32
    local background =
      active and rgba_with_alpha(COLOR.accent, pulse_alpha)
      or item_active and rgba_with_alpha(COLOR.accent, 0x26)
      or rgba_with_alpha(COLOR.text, 0x14)

    ImGui.DrawList_AddRectFilled(
      draw_list,
      x,
      y,
      x + size,
      y + size,
      background,
      radius
    )
  end

  local glyph_padding = math.max(4, math.floor(size * 0.16))

  draw_icon_glyph(
    draw_list,
    icon,
    x + glyph_padding,
    y + glyph_padding,
    size - glyph_padding * 2,
    (active or hovered)
      and COLOR.accent
      or COLOR.text
  )

  if pulse then
    local phase =
      0.5
      + 0.5 * math.sin(reaper.time_precise() * 6.5)
    ImGui.DrawList_AddCircle(
      draw_list,
      x + size - math.max(5, size * 0.17),
      y + math.max(5, size * 0.17),
      math.max(2, size * (0.055 + phase * 0.025)),
      rgba_with_alpha(
        COLOR.accent,
        math.floor(0x90 + phase * 0x6F)
      ),
      16,
      1.5
    )
  end

  if tooltip_text then
    tooltip(tooltip_text)
  end

  return clicked, hovered, item_active
end

function draw_brand_symbol(draw_list, x, y, size)
  local center_x = x + size * 0.5
  local left = x + size * 0.10
  local right = x + size * 0.90
  local half_h = size * 0.235
  local layer_gap = size * 0.17

  for layer = 2, 0, -1 do
    local center_y = y + size * 0.34 + layer * layer_gap
    local top_y = center_y - half_h
    local bottom_y = center_y + half_h
    local fill =
      layer == 0
        and COLOR.panel_alt
        or rgba_with_alpha(COLOR.button, 0xC8)
    local outline =
      layer == 0
        and COLOR.accent
        or rgba_with_alpha(COLOR.header_text, 0x92)

    ImGui.DrawList_AddQuadFilled(
      draw_list,
      center_x,
      top_y,
      right,
      center_y,
      center_x,
      bottom_y,
      left,
      center_y,
      fill
    )
    ImGui.DrawList_AddQuad(
      draw_list,
      center_x,
      top_y,
      right,
      center_y,
      center_x,
      bottom_y,
      left,
      center_y,
      outline,
      1.35
    )
  end

  local bar_center_y = y + size * 0.34
  local heights = { 0.12, 0.24, 0.38, 0.56, 0.38, 0.24, 0.12 }
  local spacing = size * 0.075

  for index, height_ratio in ipairs(heights) do
    local bar_x =
      center_x + (index - 4) * spacing
    local bar_h = size * height_ratio * 0.48

    ImGui.DrawList_AddLine(
      draw_list,
      bar_x,
      bar_center_y - bar_h,
      bar_x,
      bar_center_y + bar_h,
      COLOR.accent,
      math.max(1.4, size * 0.055)
    )
  end
end

function draw_brand_wordmark(
  draw_list,
  x,
  y,
  font_size
)
  local prefix = "PsyRea"
  local font_pushed = false

  if brand_font then
    ImGui.PushFont(
      ctx,
      brand_font,
      font_size or 16
    )
    font_pushed = true
  end

  local prefix_width =
    select(
      1,
      ImGui.CalcTextSize(ctx, prefix)
    ) or 48

  ImGui.DrawList_AddText(
    draw_list,
    x,
    y,
    COLOR.header_text,
    prefix
  )
  ImGui.DrawList_AddText(
    draw_list,
    x + prefix_width,
    y,
    COLOR.accent,
    "SFX"
  )

  if font_pushed then
    ImGui.PopFont(ctx)
  end
end

function draw_brand_mark(compact)
  local draw_list =
    ImGui.GetWindowDrawList(ctx)

  local x, y =
    ImGui.GetCursorScreenPos(ctx)

  local width = compact and 38 or 166
  local height = 34

  ImGui.InvisibleButton(
    ctx,
    "psyreasfx_brand",
    width,
    height
  )

  draw_brand_symbol(draw_list, x + 1, y + 1, 32)

  if not compact then
    local word_x = x + 42
    local word_y = y + 8
    draw_brand_wordmark(
      draw_list,
      word_x,
      word_y,
      16
    )
  end

  tooltip("PsyReaSFX · Sound Assets Organized")
end

function metric_chip(label, value, accent)
  local translated_label = translate_ui_text(label)
  local value_text = tostring(value or "")
  local label_w =
    select(1, ImGui.CalcTextSize(ctx, translated_label)) or 0
  local value_w =
    select(1, ImGui.CalcTextSize(ctx, value_text)) or 0

  local width = label_w + value_w + 20
  local height = 22
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local draw_list = ImGui.GetWindowDrawList(ctx)

  ImGui.Dummy(ctx, width, height)

  ImGui.DrawList_AddText(
    draw_list,
    x + 2,
    y + 4,
    COLOR.dim,
    translated_label
  )

  ImGui.DrawList_AddText(
    draw_list,
    x + width - value_w - 2,
    y + 4,
    accent and COLOR.playhead or COLOR.text,
    value_text
  )
end

function inline_metric_text(text, color, maximum_width)
  text = translate_ui_text(tostring(text or ""))
  maximum_width = math.max(1, tonumber(maximum_width) or 1)

  local fitted = fit_text_to_width(text, maximum_width - 4)
  local text_width =
    select(1, ImGui.CalcTextSize(ctx, fitted)) or 0
  local width = math.min(maximum_width, text_width + 4)
  local height = 22
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local draw_list = ImGui.GetWindowDrawList(ctx)

  ImGui.Dummy(ctx, width, height)

  ImGui.DrawList_AddText(
    draw_list,
    x + 2,
    y + 4,
    color,
    fitted
  )
end

function draw_parameter_card(
  id,
  label,
  value,
  minimum,
  maximum,
  default_value,
  format_string,
  width,
  height
)
  width =
    clamp(
      width or 124,
      UI_METRIC.parameter_min_w,
      UI_METRIC.parameter_max_w
    )

  height = height or UI_METRIC.parameter_h

  local x, y = ImGui.GetCursorScreenPos(ctx)
  local compact_card = height <= 40
  local translated_label = translate_ui_text(label)
  local value_text = string.format(format_string, value)
  local value_w =
    select(1, ImGui.CalcTextSize(ctx, value_text)) or 0
  local value_left =
    math.max(
      x + width * 0.48,
      x + width - value_w - 18
    )
  local value_right = x + width - 6
  local value_top = y + 1
  local value_bottom =
    y + (compact_card and 22 or 30)
  local editing =
    state.parameter_edit
    and state.parameter_edit.id == id

  if editing then
    ImGui.Dummy(ctx, width, height)
  else
    ImGui.InvisibleButton(
      ctx,
      "##parameter_" .. tostring(id),
      width,
      height
    )
  end

  local after_x, after_y = ImGui.GetCursorScreenPos(ctx)
  local hovered = not editing and ImGui.IsItemHovered(ctx)
  local active = not editing and ImGui.IsItemActive(ctx)
  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local changed = false
  local double_clicked =
    hovered and ImGui.IsMouseDoubleClicked(ctx, 0)
  local value_double_clicked =
    double_clicked
    and mouse_x >= value_left
    and mouse_x <= value_right
    and mouse_y >= value_top
    and mouse_y <= value_bottom

  if value_double_clicked then
    state.parameter_drag = nil
    state.keyboard_consumed = true
    state.parameter_edit = {
      id = id,
      value = value,
      original = value,
      focus = true,
      seen_active = false,
    }
    editing = true
    active = true
  elseif double_clicked then
    state.parameter_drag = nil
    value = default_value
    changed = true
    mark_interaction()
  elseif hovered and ImGui.IsItemClicked(ctx, 0) then
    state.parameter_drag = {
      id = id,
      start_x = mouse_x,
      start_y = mouse_y,
      start_value = value,
    }
  end

  if active
    and state.parameter_drag
    and state.parameter_drag.id == id then

    local horizontal =
      (mouse_x - state.parameter_drag.start_x) / 170

    local vertical =
      (state.parameter_drag.start_y - mouse_y) / 145

    local normalized_delta =
      math.abs(horizontal) >= math.abs(vertical)
      and horizontal
      or vertical

    local new_value =
      clamp(
        state.parameter_drag.start_value
          + normalized_delta * (maximum - minimum),
        minimum,
        maximum
      )

    if math.abs(new_value - value) > 0.000001 then
      value = new_value
      changed = true
      mark_interaction()
    end
  end

  if hovered then
    local wheel = ImGui.GetMouseWheel(ctx) or 0

    if wheel ~= 0 then
      local fine =
        (maximum - minimum) / 100

      value =
        clamp(
          value + wheel * fine,
          minimum,
          maximum
        )

      changed = true
      mark_interaction()
    end
  end

  if not ImGui.IsMouseDown(ctx, 0)
    and state.parameter_drag
    and state.parameter_drag.id == id then
    state.parameter_drag = nil
  end

  local draw_list = ImGui.GetWindowDrawList(ctx)
  local text_y = compact_card and (y + 4) or (y + 8)

  ImGui.DrawList_AddText(
    draw_list,
    x + 10,
    text_y,
    COLOR.dim,
    translated_label
  )

  if not editing then
    ImGui.DrawList_AddText(
      draw_list,
      x + width - value_w - 10,
      text_y,
      active and COLOR.selected_text or COLOR.header_text,
      value_text
    )
  end

  local track_left = x + 10
  local track_right = x + width - 10
  local track_y =
    compact_card and (y + height - 4) or (y + height - 13)
  local normalized =
    clamp(
      (value - minimum)
        / math.max(0.000001, maximum - minimum),
      0,
      1
    )

  local origin =
    clamp(
      (default_value - minimum)
        / math.max(0.000001, maximum - minimum),
      0,
      1
    )

  local value_x =
    track_left
      + (track_right - track_left) * normalized

  local origin_x =
    track_left
      + (track_right - track_left) * origin

  ImGui.DrawList_AddLine(
    draw_list,
    track_left,
    track_y,
    track_right,
    track_y,
    rgba_with_alpha(COLOR.text, 0x25),
    3
  )

  ImGui.DrawList_AddLine(
    draw_list,
    math.min(origin_x, value_x),
    track_y,
    math.max(origin_x, value_x),
    track_y,
    active and COLOR.selected_text or COLOR.selected,
    3
  )

  ImGui.DrawList_AddLine(
    draw_list,
    origin_x,
    track_y - 4,
    origin_x,
    track_y + 4,
    rgba_with_alpha(COLOR.text, 0x66),
    1
  )

  ImGui.DrawList_AddCircleFilled(
    draw_list,
    value_x,
    track_y,
    compact_card
      and (active and 4 or 3)
      or (active and 5 or 4),
    active and COLOR.selected_text or COLOR.text,
    16
  )

  if editing and state.parameter_edit then
    -- The editor may deactivate on Enter before the global shortcut pass
    -- runs later in this same frame. Keep the whole editor lifetime and its
    -- closing frame isolated from application shortcuts.
    state.keyboard_consumed = true
    local editor = state.parameter_edit
    local input_width = math.max(54, value_right - value_left)
    local input_y = y + (compact_card and 0 or 3)

    ImGui.SetCursorScreenPos(ctx, value_left, input_y)
    ImGui.SetNextItemWidth(ctx, input_width)

    ImGui.PushStyleVar(
      ctx,
      ImGui.StyleVar_FramePadding,
      4,
      2
    )
    ImGui.PushStyleVar(
      ctx,
      ImGui.StyleVar_FrameRounding,
      UI_METRIC.radius_small
    )
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_FrameBg,
      rgba_with_alpha(COLOR.accent, 0x26)
    )
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_FrameBgHovered,
      rgba_with_alpha(COLOR.accent, 0x36)
    )
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_FrameBgActive,
      rgba_with_alpha(COLOR.accent, 0x46)
    )
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_Text,
      COLOR.selected_text
    )

    if editor.focus then
      ImGui.SetKeyboardFocusHere(ctx)
      editor.focus = false
    end

    local input_changed, edited_value =
      ImGui.InputDouble(
        ctx,
        "##parameter_editor_" .. tostring(id),
        editor.value,
        0,
        0,
        format_string,
        ImGui.InputTextFlags_AutoSelectAll
      )

    editor.value = edited_value

    local input_active = ImGui.IsItemActive(ctx)

    if input_active then
      editor.seen_active = true
    end

    local cancel =
      input_active
      and ImGui.IsKeyPressed(
        ctx,
        ImGui.Key_Escape,
        false
      )

    local confirm =
      input_active
      and ImGui.IsKeyPressed(
        ctx,
        ImGui.Key_Enter,
        false
      )

    local finished =
      confirm
      or (
        editor.seen_active
        and ImGui.IsItemDeactivated(ctx)
      )

    if cancel then
      if math.abs(editor.original - value) > 0.000001 then
        value = editor.original
        changed = true
      end
      state.parameter_edit = nil
    else
      local clamped_value =
        clamp(edited_value, minimum, maximum)

      if input_changed
        and math.abs(clamped_value - value) > 0.000001 then
        value = clamped_value
        changed = true
        mark_interaction()
      end

      if finished then
        state.parameter_edit = nil
      end
    end

    ImGui.PopStyleColor(ctx, 4)
    ImGui.PopStyleVar(ctx, 2)

    -- Restore the parameter card as the final layout item so neighboring
    -- controls keep their original positions while the editor is visible.
    ImGui.SetCursorScreenPos(ctx, x, y)
    ImGui.Dummy(ctx, width, height)
    ImGui.SetCursorScreenPos(ctx, after_x, after_y)
  end

  if hovered then
    local guidance =
      state.language == "en"
        and "Drag or use the wheel; double-click the value to type; double-click the label or track to reset"
        or "拖动或滚轮调整；双击数值输入；双击标签或滑轨恢复默认值"

    tooltip(
      label
        .. " · "
        .. guidance
    )
  end

  return value, changed
end

function begin_control_panel(id, width, height)
  ImGui.PushStyleVar(
    ctx,
    ImGui.StyleVar_WindowPadding,
    UI_METRIC.panel_padding,
    UI_METRIC.panel_padding
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_ChildBg,
    COLOR.panel
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Border,
    rgba_with_alpha(COLOR.border, 0xA0)
  )

  local visible =
    ImGui.BeginChild(
      ctx,
      id,
      width,
      height,
      ImGui.ChildFlags_Borders,
      ImGui.WindowFlags_NoScrollbar
        | ImGui.WindowFlags_NoScrollWithMouse
    )

  return visible
end

function end_control_panel()
  ImGui.EndChild(ctx)
  ImGui.PopStyleColor(ctx, 2)
  ImGui.PopStyleVar(ctx)
end

function toolbar_separator(height)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local draw_list = ImGui.GetWindowDrawList(ctx)

  ImGui.Dummy(ctx, 7, height)

  ImGui.DrawList_AddLine(
    draw_list,
    x + 3,
    y + 4,
    x + 3,
    y + height - 4,
    rgba_with_alpha(COLOR.border, 0x80),
    1
  )
end

function bottom_controls_reserve_height(width, asset)
  local layout = preview_control_layout_metrics(width)
  local base =
    54
      + layout.panel_height
  local channel_count =
    asset
      and preview_asset_channel_count(asset)
      or (state.preview_channel_count or 0)

  if state.preview_channel_strip_expanded
    and channel_count > 2 then
    base = base + (
      state.ui_density == "comfortable"
        and 42
        or 38
    )
  end

  return base
end

function draw_bottom_splitter(width, total_height)
  local x, y = ImGui.GetCursorScreenPos(ctx)

  ImGui.InvisibleButton(
    ctx,
    "bottom_panel_splitter",
    width,
    BOTTOM_SPLITTER_H
  )

  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)
  local _, mouse_y = ImGui.GetMousePos(ctx)

  if hovered or active then
    ImGui.SetMouseCursor(
      ctx,
      ImGui.MouseCursor_ResizeNS
    )
  end

  if ImGui.IsItemClicked(ctx, 0) then
    state.bottom_split_drag = {
      start_y = mouse_y,
      start_height = state.bottom_panel_height,
    }
  end

  if active and state.bottom_split_drag then
    local maximum_drag_height =
      math.max(
        1,
        math.min(
          BOTTOM_MAX_H,
          total_height - BOTTOM_SPLITTER_H - 24
        )
      )

    local minimum_drag_height =
      math.min(BOTTOM_MIN_H, maximum_drag_height)

    state.bottom_panel_height =
      clamp(
        state.bottom_split_drag.start_height
          - (mouse_y - state.bottom_split_drag.start_y),
        minimum_drag_height,
        maximum_drag_height
      )

    state.config_dirty = true
  end

  if not ImGui.IsMouseDown(ctx, 0) then
    state.bottom_split_drag = nil
  end

  local draw_list = ImGui.GetWindowDrawList(ctx)
  local handle_width =
    active and 54 or hovered and 50 or 44
  local handle_height =
    active and 5 or 4
  local handle_x = x + width * 0.5
  local handle_y =
    y + BOTTOM_SPLITTER_H * 0.5

  ImGui.DrawList_AddRectFilled(
    draw_list,
    handle_x - handle_width * 0.5,
    handle_y - handle_height * 0.5,
    handle_x + handle_width * 0.5,
    handle_y + handle_height * 0.5,
    active and COLOR.selected
      or hovered
        and rgba_with_alpha(COLOR.border, 0xD0)
        or rgba_with_alpha(COLOR.dim, 0x78),
    handle_height * 0.5
  )
end

function dark_button(label, width)
  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Button,
    COLOR.button
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_ButtonHovered,
    COLOR.button_hover
  )

  local clicked =
    ImGui.Button(
      ctx,
      label,
      width or 0,
      0
    )

  ImGui.PopStyleColor(ctx, 2)
  return clicked
end

function draw_clipped_text(
  draw_list,
  x,
  y,
  color_value,
  value,
  clip_min_x,
  clip_min_y,
  clip_max_x,
  clip_max_y
)
  ImGui.DrawList_PushClipRect(
    draw_list,
    clip_min_x,
    clip_min_y,
    clip_max_x,
    clip_max_y,
    true
  )

  ImGui.DrawList_AddText(
    draw_list,
    x,
    y,
    color_value,
    tostring(value or "")
  )

  ImGui.DrawList_PopClipRect(draw_list)
end

function begin_module(
  id,
  width,
  height,
  scrollable,
  borderless
)
  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_ChildBg,
    COLOR.panel
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Border,
    COLOR.grid
  )

  local window_flags = 0

  if not scrollable then
    window_flags =
      ImGui.WindowFlags_NoScrollbar
      | ImGui.WindowFlags_NoScrollWithMouse
  end

  local child_flags =
    borderless and 0
      or ImGui.ChildFlags_Borders

  local visible =
    ImGui.BeginChild(
      ctx,
      id,
      width,
      height,
      child_flags,
      window_flags
    )

  return visible
end

function end_module()
  ImGui.EndChild(ctx)
  ImGui.PopStyleColor(ctx, 2)
end

function library_asset_count(library_id)
  return state.library_asset_counts[library_id] or 0
end

function process_library_count_rebuild()
  if not state.library_counts_dirty then
    state.library_counts_job = nil
    return
  end
  if state.scan or state.import_session then
    state.library_counts_job = nil
    return
  end

  local job = state.library_counts_job
  if not job then
    job = new_library_count_job()
    state.library_counts_job = job
  end

  local complete, counts = step_library_count_job(
    job,
    state.assets,
    LIBRARY_COUNT_ASSETS_PER_FRAME
  )
  if complete then
    state.library_asset_counts = counts
    state.library_counts_dirty = false
    state.library_counts_job = nil
  end
end

function process_ucs_count_rebuild()
  if not state.ucs_counts_dirty then return end
  if state.scan or state.import_session
    or state.ucs_reclassification_session then
    if state.ucs_counts_job then
      AppState.set("ucs_counts_job", nil)
    end
    return
  end

  local job = state.ucs_counts_job
  if not job then
    job = new_ucs_count_job()
    AppState.set("ucs_counts_job", job)
  end

  local complete, counts = step_ucs_count_job(
    job,
    state.assets,
    UCS_COUNT_ASSETS_PER_FRAME
  )
  if complete then
    AppState.set("ucs_counts", counts)
    AppState.set("ucs_counts_dirty", false)
    AppState.set("ucs_counts_job", nil)
  end
end

function rename_library(library)
  local ok, name = reaper.GetUserInputs(
    "重命名音效库",
    1,
    "名称:",
    library.name
  )

  name = trim(name or "")

  if not ok or name == "" then
    return
  end

  for _, other in ipairs(state.libraries) do
    if other.id ~= library.id
      and safe_lower(other.name) == safe_lower(name) then
      set_status("已经存在同名音效库", true)
      return
    end
  end

  library.name = name
  refresh_all_asset_library_bindings()
  state.libraries_dirty = true
  set_status("已重命名音效库：" .. name)
end

function library_paths_summary(library)
  local lines = {
    library.name,
    string.format(
      "%d 个来源路径 · %d 个素材",
      #(library.roots or {}),
      library_asset_count(library.id)
    ),
  }

  for index, record in ipairs(library.roots or {}) do
    if index > 5 then
      lines[#lines + 1] = string.format(
        "… 还有 %d 个路径",
        #library.roots - 5
      )
      break
    end

    lines[#lines + 1] =
      (directory_exists(record.path) and "● " or "○ ")
      .. record.path
    lines[#lines] = compact(lines[#lines], 64)
  end

  return table.concat(lines, "\n")
end

function scan_added_roots(roots, label)
  if #roots > 0 then
    start_scan(label or "添加来源路径", roots)
    save_libraries()
  end
end

function add_folders_to_library(library_id, folders)
  local added = {}
  local bindings_changed = false

  for _, folder in ipairs(folders or {}) do
    local existing = root_record_for_path(folder)

    if existing and existing.library_id ~= library_id then
      local old_library = library_for_root_record(existing)
      local new_library = state.library_by_id[library_id]
      local answer = reaper.MB(
        "该来源路径已经属于“"
          .. (old_library and old_library.name or "—")
          .. "”。\n\n是否移动到“"
          .. (new_library and new_library.name or "—")
          .. "”？\n\n不会移动磁盘文件。",
        SCRIPT_NAME,
        4
      )

      if answer == 6 then
        existing.library_id = library_id
        state.libraries_dirty = true
        bindings_changed = true
        set_status("已移动来源路径到音效库：" .. new_library.name)
      end
    elseif existing then
      set_status("该来源路径已经在当前音效库中")
    elseif add_root_to_library(
      library_id,
      folder,
      false,
      true
    ) then
      added[#added + 1] = folder
    end
  end

  if #added > 0 or bindings_changed then
    rebuild_library_indexes()

    if bindings_changed then
      refresh_all_asset_library_bindings()
    end

    state.results_dirty = true
  end

  scan_added_roots(added, "添加来源路径")
  return #added
end

function create_libraries_from_folders(folders)
  local added = {}

  for _, folder in ipairs(folders or {}) do
    local library = create_library(
      basename(folder),
      "library:" .. path_key(folder)
    )

    if add_root_to_library(
      library.id,
      folder,
      false,
      true
    ) then
      added[#added + 1] = folder
    else
      for index = #state.libraries, 1, -1 do
        if state.libraries[index].id == library.id then
          table.remove(state.libraries, index)
          break
        end
      end
    end
  end

  if #(folders or {}) > 0 then
    rebuild_library_indexes()
    state.results_dirty = true
  end

  scan_added_roots(added, "拖入音效库")
end

function collect_folder_payload()
  local accepted, count =
    ImGui.AcceptDragDropPayloadFiles(ctx)

  if not accepted then
    return nil
  end

  local folders = {}
  local seen = {}

  for index = 0, (count or 0) - 1 do
    local ok, path = ImGui.GetDragDropPayloadFile(ctx, index)
    path = ok and normalize_external_path(path) or ""

    if path ~= ""
      and directory_exists(path)
      and not seen[path_key(path)] then
      seen[path_key(path)] = true
      folders[#folders + 1] = path
    end
  end

  return folders
end

function handle_folder_drop(folders, target_library_id)
  if not folders or #folders == 0 then
    set_status("请拖入文件夹；音频文件不会作为来源路径导入", true)
    return
  end

  if target_library_id
    and state.library_by_id[target_library_id] then
    add_folders_to_library(target_library_id, folders)
    return
  end

  if #folders == 1 then
    create_libraries_from_folders(folders)
  else
    state.pending_folder_drop = {
      folders = folders,
      requested_open = true,
    }
  end
end

function accept_folder_drop_target(target_library_id)
  if not ImGui.BeginDragDropTarget(ctx) then
    return false
  end

  local folders = collect_folder_payload()
  ImGui.EndDragDropTarget(ctx)

  if folders then
    handle_folder_drop(folders, target_library_id)
    return true
  end

  return false
end

function draw_folder_drop_choice_popup()
  local pending = state.pending_folder_drop

  if not pending then
    return
  end

  if pending.requested_open then
    ImGui.OpenPopup(ctx, "导入多个文件夹##folder_drop")
    pending.requested_open = false
  end

  if not ImGui.BeginPopupModal(
    ctx,
    "导入多个文件夹##folder_drop",
    true,
    ImGui.WindowFlags_AlwaysAutoResize
  ) then
    return
  end

  ImGui.Text(ctx, string.format(
    "已拖入 %d 个文件夹",
    #pending.folders
  ))
  ImGui.TextDisabled(ctx, "请选择它们在音效库中的组织方式。")
  ImGui.Separator(ctx)

  if dark_button("每个文件夹建立一个音效库", 220) then
    create_libraries_from_folders(pending.folders)
    state.pending_folder_drop = nil
    ImGui.CloseCurrentPopup(ctx)
  end

  if dark_button("合并为一个音效库…", 220) then
    local default_name = basename(pending.folders[1])
    local ok, name = reaper.GetUserInputs(
      "新建逻辑音效库",
      1,
      "名称:",
      default_name
    )

    name = trim(name or "")

    if ok and name ~= "" then
      local library = create_library(name)
      add_folders_to_library(library.id, pending.folders)
      state.pending_folder_drop = nil
      ImGui.CloseCurrentPopup(ctx)
    end
  end

  if dark_button("取消", 220) then
    state.pending_folder_drop = nil
    ImGui.CloseCurrentPopup(ctx)
  end

  ImGui.EndPopup(ctx)
end


function draw_library_manager_popup()
  if not ImGui.BeginPopupModal(
    ctx,
    "管理音效库##psyreasfx",
    true,
    ImGui.WindowFlags_AlwaysAutoResize
  ) then
    return
  end

  ImGui.Text(ctx, "逻辑音效库与来源路径")
  ImGui.Separator(ctx)

  if #state.libraries == 0 then
    ImGui.TextDisabled(ctx, "尚未添加音效库")
  end

  local remove_library_id = nil
  local remove_root_record = nil

  for library_index, library in ipairs(state.libraries) do
    ImGui.PushID(ctx, "manager_library_" .. library.id)
    ImGui.TextColored(ctx, COLOR.text, library.name)
    ImGui.SameLine(ctx)
    ImGui.TextDisabled(ctx, string.format(
      "%d 个来源 · %d 个素材",
      #library.roots,
      library_asset_count(library.id)
    ))

    ImGui.SameLine(ctx)

    if dark_button("添加路径", 76) then
      add_root(library.id)
    end

    ImGui.SameLine(ctx)

    if dark_button("重命名", 64) then
      rename_library(library)
    end

    ImGui.SameLine(ctx)

    if dark_button("扫描", 54) then
      start_scan("扫描 " .. library.name, roots_for_library(library.id))
    end

    ImGui.SameLine(ctx)

    if dark_button("删除库", 64) then
      remove_library_id = library.id
    end

    for root_index, record in ipairs(library.roots) do
      ImGui.PushID(ctx, root_index)
      local online = directory_exists(record.path)
      ImGui.TextColored(
        ctx,
        online and COLOR.muted or 0xE36B68FF,
        online and "  ●" or "  ○"
      )
      ImGui.SameLine(ctx)
      ImGui.Text(ctx, compact(record.path, 72))
      tooltip(record.path)
      ImGui.SameLine(ctx)

      if dark_button("打开", 54) then
        open_folder(record.path)
      end

      ImGui.SameLine(ctx)

      if dark_button("封面", 54) then
        choose_artwork_for_root(record)
      end

      ImGui.SameLine(ctx)

      if dark_button("重建", 54) then
        start_scan(
          "重建 " .. basename(record.path),
          { record.path },
          { force_rebuild = true }
        )
      end

      ImGui.SameLine(ctx)

      if dark_button("移除", 54) then
        remove_root_record = record
      end

      ImGui.PopID(ctx)
    end

    if library_index < #state.libraries then
      ImGui.Separator(ctx)
    end

    ImGui.PopID(ctx)
  end

  if remove_root_record then
    local answer = reaper.MB(
      "从逻辑音效库中移除该来源路径？\n\n"
        .. remove_root_record.path
        .. "\n\n不会删除磁盘中的音频文件。",
      SCRIPT_NAME,
      4
    )

    if answer == 6 then
      remove_root(remove_root_record)
    end
  end

  if remove_library_id then
    local library = state.library_by_id[remove_library_id]
    local answer = reaper.MB(
      "删除逻辑音效库及其所有来源路径？\n\n"
        .. (library and library.name or "")
        .. "\n\n只会清除 PsyReaSFX 索引，不会删除磁盘文件。",
      SCRIPT_NAME,
      4
    )

    if answer == 6 then
      remove_library(remove_library_id)
    end
  end

  ImGui.Separator(ctx)

  if dark_button("+ 新建音效库", 120) then
    add_root()
  end

  ImGui.SameLine(ctx)

  if dark_button("关闭", 72) then
    ImGui.CloseCurrentPopup(ctx)
  end

  ImGui.EndPopup(ctx)
end


----------------------------------------------------------------
-- UI: toolbar
----------------------------------------------------------------

function sidebar_item(
  label,
  selected,
  on_click
)
  if selected then
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_Header,
      COLOR.selected
    )

    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_HeaderHovered,
      COLOR.selected
    )
  end

  local clicked =
    ImGui.Selectable(
      ctx,
      label,
      selected
    )

  if selected then
    ImGui.PopStyleColor(ctx, 2)
  end

  if clicked then
    on_click()
  end
end

function sidebar_section_header(key, label)
  local expanded =
    state.sidebar_sections[key] ~= false

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Header,
    0x00000000
  )
  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_HeaderHovered,
    rgba_with_alpha(COLOR.button_hover, 0xB8)
  )
  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_HeaderActive,
    rgba_with_alpha(COLOR.selected, 0x88)
  )
  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Text,
    COLOR.dim
  )

  local clicked = ImGui.Selectable(
    ctx,
    (expanded and "▾  " or "▸  ")
      .. label
      .. "##sidebar_section_"
      .. key,
    false
  )

  ImGui.PopStyleColor(ctx, 4)

  if clicked then
    expanded = not expanded
    state.sidebar_sections[key] = expanded
    state.config_dirty = true
  end

  return expanded
end

SIDEBAR_SECTION_LABELS = {
  sounds = { zh = "素材", en = "SOUNDS" },
  libraries = { zh = "音效库", en = "LIBRARIES" },
  ucs = { zh = "UCS 目录", en = "UCS DIRECTORY" },
  collections = { zh = "集合", en = "COLLECTIONS" },
  saved_searches = { zh = "保存搜索", en = "SAVED SEARCHES" },
  workflow = { zh = "工作流", en = "WORKFLOW" },
  activity = { zh = "活动", en = "ACTIVITY" },
}

function sidebar_section_label(key)
  local labels = SIDEBAR_SECTION_LABELS[key]
  if not labels then return tostring(key or "") end
  return "en" == state.language and labels.en or labels.zh
end

function activate_ucs_filter(category, subcategory, catid)
  category = tostring(category or "")
  subcategory = tostring(subcategory or "")
  catid = tostring(catid or "")
  AppState.set(
    "view",
    catid ~= "" and "ucs_catid"
      or subcategory ~= "" and "ucs_subcategory"
      or "ucs_category"
  )
  AppState.set("ucs_filter_category", category ~= "" and category or nil)
  AppState.set(
    "ucs_filter_subcategory",
    subcategory ~= "" and subcategory or nil
  )
  AppState.set("ucs_filter_catid", catid ~= "" and catid or nil)
  AppState.set("active_collection_id", nil)
  AppState.set("root_filter", nil)
  AppState.set("library_filter_id", nil)
  AppState.set("status_filter", nil)
  clear_row_selection()
  AppState.mark_dirty("results_dirty")
  AppState.mark_dirty("config_dirty")
end

function ucs_directory_view(view)
  return "ucs_category" == view
    or "ucs_subcategory" == view
    or "ucs_catid" == view
end

function ucs_category_display_name(category)
  if "en" == state.language or tostring(category.name_zh or "") == "" then
    return category.name
  end
  return category.name_zh .. " · " .. category.name
end

function ucs_entry_display_name(entry)
  if "en" == state.language or tostring(entry.subcategory_zh or "") == "" then
    return entry.subcategory
  end
  return entry.subcategory_zh .. " · " .. entry.subcategory
end

function ucs_sidebar_arrow(id, expanded, tooltip_text)
  ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0x00000000)
  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_ButtonHovered,
    rgba_with_alpha(COLOR.button_hover, 0xD0)
  )
  ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, COLOR.accent)
  local clicked = ImGui.Button(
    ctx,
    (expanded and "▾" or "▸") .. "##" .. id,
    22,
    0
  )
  ImGui.PopStyleColor(ctx, 3)
  tooltip(tooltip_text)
  ImGui.SameLine(ctx, 0, 0)
  return clicked
end

function draw_ucs_sidebar_tree()
  ensure_ucs_catalog()
  local counts = state.ucs_counts or {}
  local category_counts = counts.categories or {}
  local subcategory_counts = counts.subcategories or {}
  local catid_counts = counts.catids or {}

  if #state.ucs_confirmation_undo_order > 0 then
    if dark_button("撤销上次 UCS 确认", -1) then
      undo_last_ucs_confirmation()
    end
  end

  if state.ucs_counts_dirty then
    ImGui.TextDisabled(ctx, "UCS 分类索引更新中…")
  end
  if (tonumber(counts.total) or 0) == 0 then
    if not state.ucs_counts_dirty then
      ImGui.TextDisabled(ctx, "尚无已分类素材")
    end
    if dark_button("前往维护页分类现有素材", -1) then
      AppState.set("settings_tab", "maintenance")
      ImGui.OpenPopup(ctx, "设置##reasfx")
    end
    return
  end

  for _, category in ipairs(UcsCatalog.category_order or {}) do
    local category_count = category_counts[ucs_count_key(category.name)] or 0
    if category_count > 0 then
      local expanded = state.expanded_ucs_categories[category.name] == true
      if ucs_sidebar_arrow(
        "ucs_category_arrow_" .. category.name,
        expanded,
        "展开或折叠 UCS 分类"
      ) then
        expanded = not expanded
        state.expanded_ucs_categories[category.name] = expanded
      end

      sidebar_item(
        compact(ucs_category_display_name(category), 22)
          .. "  " .. tostring(category_count)
          .. "##ucs_category_" .. category.name,
        "ucs_category" == state.view
          and category.name == state.ucs_filter_category,
        function()
          activate_ucs_filter(category.name)
        end
      )

      if expanded then
        for _, entry in ipairs(category.entries or {}) do
          local pair_key = ucs_subcategory_count_key(
            entry.category,
            entry.subcategory
          )
          local subcategory_count = subcategory_counts[pair_key] or 0
          if subcategory_count > 0 then
            local subkey = entry.category .. "\0" .. entry.subcategory
            local sub_expanded =
              state.expanded_ucs_subcategories[subkey] == true
            ImGui.Indent(ctx, 14)
            if ucs_sidebar_arrow(
              "ucs_subcategory_arrow_" .. entry.catid,
              sub_expanded,
              "展开或折叠 UCS 子分类"
            ) then
              sub_expanded = not sub_expanded
              state.expanded_ucs_subcategories[subkey] = sub_expanded
            end
            sidebar_item(
              compact(ucs_entry_display_name(entry), 20)
                .. "  " .. tostring(subcategory_count)
                .. "##ucs_subcategory_" .. entry.catid,
              "ucs_subcategory" == state.view
                and entry.category == state.ucs_filter_category
                and entry.subcategory == state.ucs_filter_subcategory,
              function()
                activate_ucs_filter(entry.category, entry.subcategory)
              end
            )
            if sub_expanded then
              local catid_count = catid_counts[ucs_count_key(entry.catid)] or 0
              sidebar_item(
                "      " .. entry.catid .. "  " .. tostring(catid_count)
                  .. "##ucs_catid_" .. entry.catid,
                "ucs_catid" == state.view
                  and entry.catid == state.ucs_filter_catid,
                function()
                  activate_ucs_filter(
                    entry.category,
                    entry.subcategory,
                    entry.catid
                  )
                end
              )
            end
            ImGui.Unindent(ctx, 14)
          end
        end
      end
    end
  end
end

function activate_folder_path(path, library_id, close_browser)
  path = canonical_source_path(path)

  state.view = "all"
  state.root_filter = path ~= "" and path or nil
  state.library_filter_id = library_id
  state.active_collection_id = nil
  state.status_filter = nil
  clear_row_selection()
  state.results_dirty = true
  state.config_dirty = true

  if close_browser ~= false then
    state.folder_browser_open = false
  end
end

function clear_folder_path(keep_library)
  local library_id = nil

  if keep_library and state.root_filter then
    local _, record = root_for_path(state.root_filter)
    library_id = record and record.library_id or nil
  end

  state.root_filter = nil
  state.library_filter_id = library_id
  state.view = "all"
  state.active_collection_id = nil
  clear_row_selection()
  state.results_dirty = true
  state.config_dirty = true
end

function folder_path_label()
  if not state.root_filter then
    if state.library_filter_id then
      local library =
        state.library_by_id[state.library_filter_id]

      if library then
        return (
          state.language == "en"
          and "Library: "
          or "音效库："
        ) .. library.name
      end
    end

    return (
      state.language == "en"
      and "Path: "
      or "路径："
    ) .. translate_ui_text("全部音效库")
  end

  local _, record = root_for_path(state.root_filter)
  local library = record
    and state.library_by_id[record.library_id]
    or nil
  local parts = {}

  if library then
    parts[#parts + 1] = library.name
  end

  if record then
    parts[#parts + 1] =
      record.alias ~= "" and record.alias
      or basename(record.path)

    local relative =
      state.root_filter:sub(#record.path + 1)
        :gsub("^[\\/]+", "")

    for segment in relative:gmatch("[^\\/]+") do
      parts[#parts + 1] = segment
    end
  else
    parts[#parts + 1] = state.root_filter
  end

  return (
    state.language == "en"
    and "Path: "
    or "路径："
  ) .. table.concat(parts, " / ")
end

function draw_path_navigation_bar()
  local available = select(1, ImGui.GetContentRegionAvail(ctx))
  local clear_width = state.root_filter and 30 or 0
  local button_width = math.max(160, available - clear_width - 6)
  local active =
    state.folder_browser_open or state.root_filter ~= nil

  if active then
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_Button,
      rgba_with_alpha(COLOR.selected, 0xA8)
    )
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_ButtonHovered,
      rgba_with_alpha(COLOR.selected, 0xD8)
    )
  end

  local path_button_clicked = ImGui.Button(
    ctx,
    (state.folder_browser_open and "▾  " or "▸  ")
      .. folder_path_label()
      .. "##folder_path_bar",
    button_width,
    0
  )

  if path_button_clicked then
    state.folder_browser_open =
      not state.folder_browser_open
    state.config_dirty = true

    if state.folder_browser_open then
      ensure_folder_navigation_build()
    end
  end

  if active then
    ImGui.PopStyleColor(ctx, 2)
  end

  tooltip(
    state.root_filter
      or translate_ui_text(
        "展开全部音效库的文件夹结构"
      )
  )

  if state.root_filter then
    ImGui.SameLine(ctx)

    if dark_button("×##clear_folder_path", 30) then
      clear_folder_path(true)
    end

    tooltip("清除路径条件")
  end
end

function draw_folder_tree_node(node, depth, library_id)
  local has_children = #node.children > 0
  local expanded =
    state.expanded_folder_nodes[node.key] == true
  local selected = state.root_filter
    and path_key(state.root_filter) == node.key

  ImGui.PushID(ctx, "folder_node_" .. node.key)
  ImGui.SetCursorPosX(ctx, 18 + depth * 18)

  if has_children then
    if dark_button(expanded and "▾" or "▸", 20) then
      state.expanded_folder_nodes[node.key] = not expanded
      state.config_dirty = true
      expanded = not expanded
    end
  else
    ImGui.TextDisabled(ctx, "·")
  end

  ImGui.SameLine(ctx, 0, 2)

  sidebar_item(
    compact(node.name, 42)
      .. "  "
      .. tostring(node.total_count)
      .. "##folder_name",
    selected,
    function()
      activate_folder_path(
        node.path,
        library_id,
        true
      )
    end
  )

  tooltip(node.path)

  if ImGui.BeginPopupContextItem(
    ctx,
    "folder_context"
  ) then
    if ImGui.MenuItem(ctx, "打开目录") then
      open_folder(node.path)
    end

    if has_children
      and ImGui.MenuItem(
        ctx,
        expanded and "折叠此层级" or "展开此层级"
      ) then
      state.expanded_folder_nodes[node.key] = not expanded
      state.config_dirty = true
      expanded = not expanded
    end

    ImGui.EndPopup(ctx)
  end

  if expanded then
    for _, child in ipairs(node.children) do
      draw_folder_tree_node(
        child,
        depth + 1,
        library_id
      )
    end
  end

  ImGui.PopID(ctx)
end

function draw_folder_browser()
  if not state.folder_browser_open then
    return
  end

  ensure_folder_navigation_build()

  local available_w, available_h =
    ImGui.GetContentRegionAvail(ctx)
  local browser_h = math.min(
    clamp(available_h * 0.34, 150, 300),
    math.max(90, available_h - 250)
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_ChildBg,
    rgba_with_alpha(COLOR.panel, 0xFC)
  )

  local visible = ImGui.BeginChild(
    ctx,
    "folder_browser_inline",
    available_w,
    browser_h,
    ImGui.ChildFlags_Borders,
    0
  )

  if visible then
    ImGui.TextColored(
      ctx,
      COLOR.text,
      translate_ui_text("文件夹层级")
    )
    ImGui.SameLine(ctx)
    ImGui.TextDisabled(
      ctx,
      translate_ui_text(
        "箭头展开；单击名称跳转并显示该目录及其子目录"
      )
    )
    ImGui.Separator(ctx)

    sidebar_item(
      translate_ui_text("全部音效库")
        .. "  "
        .. tostring(#state.assets)
        .. "##folder_browser_all",
      state.root_filter == nil
        and state.library_filter_id == nil,
      function()
        clear_folder_path(false)
        state.folder_browser_open = false
      end
    )

    for _, library in ipairs(state.libraries) do
      local expanded =
        state.expanded_libraries[library.id] == true
      local selected =
        state.library_filter_id == library.id
        and state.root_filter == nil

      ImGui.PushID(ctx, "folder_library_" .. library.id)

      if dark_button(expanded and "▾" or "▸", 20) then
        expanded = not expanded
        state.expanded_libraries[library.id] = expanded
        state.libraries_dirty = true
        state.config_dirty = true
      end

      ImGui.SameLine(ctx, 0, 2)

      sidebar_item(
        compact(library.name, 44)
          .. "  "
          .. tostring(library_asset_count(library.id))
          .. "##folder_library_name",
        selected,
        function()
          state.view = "all"
          state.library_filter_id = library.id
          state.root_filter = nil
          state.active_collection_id = nil
          clear_row_selection()
          state.results_dirty = true
          state.config_dirty = true
          state.folder_browser_open = false
        end
      )

      if expanded then
        for _, record in ipairs(library.roots) do
          ImGui.PushID(
            ctx,
            "folder_source_row_" .. record.id
          )

          local source_expanded =
            state.expanded_source_folders[record.id] == true
          local source_selected =
            state.root_filter
            and path_key(state.root_filter)
              == path_key(record.path)
          local tree =
            state.folder_navigation_trees[record.id]
          local has_children =
            tree and #tree.children > 0
          local can_expand =
            has_children
            or not state.folder_navigation_ready

          ImGui.SetCursorPosX(ctx, 18)

          if can_expand then
            if dark_button(
              source_expanded and "▾" or "▸",
              20
            ) then
              source_expanded = not source_expanded
              state.expanded_source_folders[record.id] =
                source_expanded
              state.config_dirty = true
              ensure_folder_navigation_build()
            end
          else
            ImGui.TextDisabled(ctx, "·")
          end

          ImGui.SameLine(ctx, 0, 2)

          local source_name =
            record.alias ~= "" and record.alias
            or basename(record.path)
          local source_count =
            tree and tree.total_count or 0

          sidebar_item(
            (directory_exists(record.path) and "● " or "○ ")
              .. compact(source_name, 40)
              .. (
                state.folder_navigation_ready
                and ("  " .. tostring(source_count))
                or ""
              )
              .. "##folder_source_"
              .. record.id,
            source_selected,
            function()
              activate_folder_path(
                record.path,
                library.id,
                true
              )
            end
          )

          tooltip(record.path)

          if source_expanded then
            if not state.folder_navigation_ready then
              local job = state.folder_navigation_job
              local done = job
                and math.max(0, job.index - 1)
                or 0
              local total = job and job.total or #state.assets
              ImGui.SetCursorPosX(ctx, 42)
              ImGui.TextDisabled(
                ctx,
                string.format(
                  "%s  %d / %d",
                  translate_ui_text("正在建立目录索引…"),
                  done,
                  total
                )
              )
            elseif tree then
              for _, child in ipairs(tree.children) do
                draw_folder_tree_node(
                  child,
                  2,
                  library.id
                )
              end
            end
          end

          ImGui.PopID(ctx)
        end
      end

      ImGui.PopID(ctx)
    end
  end

  ImGui.EndChild(ctx)
  ImGui.PopStyleColor(ctx)
end

function activate_library_path(library_id)
  state.view = "all"
  state.library_filter_id = library_id
  state.root_filter = nil
  state.active_collection_id = nil
  state.status_filter = nil
  clear_row_selection()
  state.results_dirty = true
  state.config_dirty = true
end

function select_path_from_hover_menu(path, library_id)
  activate_folder_path(path, library_id, false)
  ImGui.CloseCurrentPopup(ctx)
end

function folder_hover_branch_open(depth, key)
  return state.folder_hover_levels[depth] == key
end

function open_folder_hover_branch(depth, key)
  local levels = state.folder_hover_levels

  if levels[depth] == key then
    return
  end

  levels[depth] = key

  local deeper = depth + 1
  while levels[deeper] ~= nil do
    levels[deeper] = nil
    deeper = deeper + 1
  end
end

function draw_folder_hover_row(
  depth,
  key,
  name,
  count,
  has_children,
  on_click
)
  local open = has_children
    and folder_hover_branch_open(depth, key)
  local prefix = has_children
    and (open and "▾  " or "▸  ")
    or "   "
  local label = prefix
    .. compact(name, 52)
    .. "  "
    .. tostring(count or 0)
    .. "##folder_hover_row_"
    .. key

  ImGui.Indent(ctx, depth * 15)
  local clicked = ImGui.Selectable(ctx, label, false)
  local hovered = ImGui.IsItemHovered(ctx)
  ImGui.Unindent(ctx, depth * 15)

  if hovered then
    open_folder_hover_branch(depth, key)
  end

  if clicked then
    on_click()
  end

  return has_children
    and folder_hover_branch_open(depth, key)
end

function draw_folder_cascade_node(node, library_id, depth)
  depth = depth or 2
  local has_children = #node.children > 0
  local open = draw_folder_hover_row(
    depth,
    "node:" .. node.key,
    node.name,
    node.total_count,
    has_children,
    function()
      select_path_from_hover_menu(node.path, library_id)
    end
  )

  if open then
    for _, child in ipairs(node.children) do
      draw_folder_cascade_node(
        child,
        library_id,
        depth + 1
      )
    end
  end
end

function draw_source_cascade_menu(record, library, depth)
  depth = depth or 1
  local tree = state.folder_navigation_trees[record.id]
  local source_name =
    record.alias ~= "" and record.alias
    or basename(record.path)
  local count =
    state.folder_navigation_ready
      and tree
      and tree.total_count
      or nil
  local has_children = not state.folder_navigation_ready
    or (tree and #tree.children > 0)
  local open = draw_folder_hover_row(
    depth,
    "source:" .. record.id,
    (directory_exists(record.path) and "● " or "○ ")
      .. source_name,
    count or 0,
    has_children,
    function()
      select_path_from_hover_menu(record.path, library.id)
    end
  )

  if open and not state.folder_navigation_ready then
    local job = state.folder_navigation_job
    local done = job and math.max(0, job.index - 1) or 0
    local total = job and job.total or #state.assets
    ImGui.Indent(ctx, (depth + 1) * 15)
    ImGui.TextDisabled(
      ctx,
      string.format(
        "%s  %d / %d",
        translate_ui_text("目录索引正在后台建立…"),
        done,
        total
      )
    )
    ImGui.Unindent(ctx, (depth + 1) * 15)
  elseif open and tree then
    for _, child in ipairs(tree.children) do
      draw_folder_cascade_node(
        child,
        library.id,
        depth + 1
      )
    end
  end
end

function draw_library_cascade_menu(library, depth)
  depth = depth or 0
  local open = draw_folder_hover_row(
    depth,
    "library:" .. library.id,
    library.name,
    library_asset_count(library.id),
    #library.roots > 0,
    function()
      activate_library_path(library.id)
      ImGui.CloseCurrentPopup(ctx)
    end
  )

  if open then
    for _, record in ipairs(library.roots) do
      draw_source_cascade_menu(record, library, depth + 1)
    end
  end
end

function draw_folder_hover_popup()
  if not ImGui.BeginPopup(
    ctx,
    "文件夹层级##folder_hover_menu"
  ) then
    state.folder_menu_active = false
    return
  end

  state.folder_menu_active = true
  ensure_folder_navigation_build()

  ImGui.TextDisabled(
    ctx,
    "悬停展开下级目录 · 点击定位"
  )
  ImGui.Separator(ctx)

  if ImGui.MenuItem(
    ctx,
    "显示全部音效库##folder_cascade_all"
  ) then
    clear_folder_path(false)
    ImGui.CloseCurrentPopup(ctx)
  end

  if #state.libraries > 0 then
    ImGui.Separator(ctx)

    for _, library in ipairs(state.libraries) do
      draw_library_cascade_menu(library)
    end
  end

  ImGui.EndPopup(ctx)
end

function active_path_condition_label()
  if state.root_filter then
    local suffix =
      state.root_filter:sub(-1) == SEP
        and "*"
        or (SEP .. "*")

    return "Pathname: "
      .. state.root_filter
      .. suffix
  end

  local library =
    state.library_filter_id
      and state.library_by_id[
        state.library_filter_id
      ]
      or nil

  if library then
    return "Library: " .. library.name
  end

  return nil
end

function draw_path_condition_bar()
  local label = active_path_condition_label()

  if not label then
    return
  end

  local available =
    select(1, ImGui.GetContentRegionAvail(ctx))
  local text_width =
    select(1, ImGui.CalcTextSize(ctx, label))
  local clear_size = 22
  local max_button_width =
    math.max(48, available - clear_size - 7)
  local button_width = math.min(
    math.max(80, text_width + 28),
    max_button_width
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Button,
    rgba_with_alpha(COLOR.selected, 0xC0)
  )
  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_ButtonHovered,
    rgba_with_alpha(COLOR.selected, 0xE8)
  )
  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Text,
    COLOR.selected_text
  )

  if ImGui.Button(
    ctx,
    label .. "##active_path_condition",
    button_width,
    clear_size
  ) then
    AppState.set("folder_hover_levels", {})
    ensure_folder_navigation_build()
    ImGui.OpenPopup(
      ctx,
      "文件夹层级##folder_hover_menu"
    )
  end

  ImGui.PopStyleColor(ctx, 3)
  ImGui.SameLine(ctx, 0, 3)

  if icon_button(
    "clear_path_condition",
    "close",
    "清除路径条件",
    false,
    clear_size
  ) then
    clear_folder_path(false)
  end
end

function draw_sidebar()
  if dark_button("隐藏导航 <", -1) then
    state.sidebar_visible = false
    state.config_dirty = true
    return
  end

  ImGui.Spacing(ctx)

  if sidebar_section_header(
    "sounds",
    sidebar_section_label("sounds")
  ) then

  sidebar_item(
    string.format("全部素材  %d", #state.assets),
    state.view == "all"
      and not state.active_collection_id,
    function()
      state.view = "all"
      state.active_collection_id = nil
      state.root_filter = nil
      state.library_filter_id = nil
      state.results_dirty = true
      state.config_dirty = true
    end
  )

  local favorite_count = 0

  for _ in pairs(state.favorites) do
    favorite_count = favorite_count + 1
  end

  sidebar_item(
    string.format("收藏  %d", favorite_count),
    state.view == "favorites"
      and not state.active_collection_id,
    function()
      state.view = "favorites"
      state.active_collection_id = nil
      state.root_filter = nil
      state.library_filter_id = nil
      state.results_dirty = true
      state.config_dirty = true
    end
  )

  sidebar_item(
    "最近插入",
    state.view == "recent"
      and not state.active_collection_id,
    function()
      state.view = "recent"
      state.active_collection_id = nil
      state.root_filter = nil
      state.library_filter_id = nil
      state.sort_mode = "used"
      state.sort_desc = true
      state.results_dirty = true
      state.config_dirty = true
    end
  )

  sidebar_item(
    "试听历史",
    state.view == "previewed"
      and not state.active_collection_id,
    function()
      state.view = "previewed"
      state.active_collection_id = nil
      state.root_filter = nil
      state.library_filter_id = nil
      state.sort_mode = "previewed"
      state.sort_desc = true
      state.results_dirty = true
      state.config_dirty = true
    end
  )

  if state.ucs_pending_count > 0 then
    sidebar_item(
      string.format("UCS 待确认  %d", state.ucs_pending_count),
      "ucs_pending" == state.view
        and not state.active_collection_id,
      function()
        AppState.set("view", "ucs_pending")
        AppState.set("active_collection_id", nil)
        AppState.set("root_filter", nil)
        AppState.set("library_filter_id", nil)
        AppState.mark_dirty("results_dirty")
        AppState.mark_dirty("config_dirty")
      end
    )
  end

  if state.missing_asset_count > 0 then
    sidebar_item(
      string.format("缺失素材  %d", state.missing_asset_count),
      state.view == "missing"
        and not state.active_collection_id,
      function()
        state.view = "missing"
        state.active_collection_id = nil
        state.root_filter = nil
        state.library_filter_id = nil
        state.results_dirty = true
        state.config_dirty = true
      end
    )
  end

  if state.duplicate_asset_count > 0 then
    sidebar_item(
      string.format("重复候选  %d", state.duplicate_asset_count),
      state.view == "duplicates"
        and not state.active_collection_id,
      function()
        state.view = "duplicates"
        state.active_collection_id = nil
        state.root_filter = nil
        state.library_filter_id = nil
        state.results_dirty = true
        state.config_dirty = true
      end
    )
  end

  if state.duplicate_confirmed_asset_count > 0 then
    sidebar_item(
      string.format("已确认相同  %d", state.duplicate_confirmed_asset_count),
      state.view == "duplicates_confirmed",
      function()
        state.view = "duplicates_confirmed"
        state.active_collection_id = nil
        state.root_filter = nil
        state.library_filter_id = nil
        state.results_dirty = true
        state.config_dirty = true
      end
    )
  end

  if state.duplicate_confirmation_failure_count > 0 then
    sidebar_item(
      string.format("确认读取失败  %d", state.duplicate_confirmation_failure_count),
      state.view == "duplicate_failures",
      function()
        state.view = "duplicate_failures"
        state.active_collection_id = nil
        state.root_filter = nil
        state.library_filter_id = nil
        state.results_dirty = true
        state.config_dirty = true
      end
    )
  end

  local current_usage = project_usage_bucket(
    state.current_project_path,
    false
  )
  if current_usage then
    local usage_count = 0
    for _ in pairs(current_usage.assets or {}) do
      usage_count = usage_count + 1
    end
    if usage_count > 0 then
      sidebar_item(
        string.format("当前工程已用  %d", usage_count),
        state.view == "project_used"
          and not state.active_collection_id,
        function()
          state.view = "project_used"
          state.active_collection_id = nil
          state.root_filter = nil
          state.library_filter_id = nil
          state.results_dirty = true
          state.config_dirty = true
        end
      )
    end
  end

  end

  if sidebar_section_header(
    "libraries",
    sidebar_section_label("libraries")
  ) then

  sidebar_item(
    "全部音效库",
    state.root_filter == nil
      and state.library_filter_id == nil,
    function()
      state.view = "all"
      state.root_filter = nil
      state.library_filter_id = nil
      state.active_collection_id = nil
      state.results_dirty = true
    end
  )

  accept_folder_drop_target(nil)

  for index, library in ipairs(state.libraries) do
    local selected =
      state.library_filter_id == library.id
      and state.root_filter == nil
    local expanded =
      state.expanded_libraries[library.id] == true
    local has_roots = #library.roots > 0

    if has_roots then
      ImGui.PushStyleColor(
        ctx,
        ImGui.Col_Button,
        selected and COLOR.selected or 0x00000000
      )
      ImGui.PushStyleColor(
        ctx,
        ImGui.Col_ButtonHovered,
        selected
          and rgba_with_alpha(COLOR.selected, 0xE8)
          or rgba_with_alpha(COLOR.button_hover, 0xD0)
      )
      ImGui.PushStyleColor(
        ctx,
        ImGui.Col_ButtonActive,
        COLOR.accent
      )

      if ImGui.Button(
        ctx,
        (expanded and "▾" or "▸")
          .. "##library_arrow_"
          .. library.id,
        22,
        0
      ) then
        expanded = not expanded
        state.expanded_libraries[library.id] = expanded
        state.libraries_dirty = true
        state.config_dirty = true
      end

      ImGui.PopStyleColor(ctx, 3)
      tooltip("展开或折叠来源")
      ImGui.SameLine(ctx, 0, 0)
    end

    sidebar_item(
      (has_roots and "" or "  ")
        .. compact(library.name, 20)
        .. "  "
        .. tostring(library_asset_count(library.id))
        .. "##library_"
        .. tostring(index),
      selected,
      function()
        if ImGui.IsMouseDoubleClicked(ctx, 0) then
          expanded = not expanded
          state.expanded_libraries[library.id] = expanded
          state.libraries_dirty = true
        end

        state.view = "all"
        state.library_filter_id = library.id
        state.root_filter = nil
        state.active_collection_id = nil
        state.results_dirty = true
        state.config_dirty = true
      end
    )

    tooltip(library_paths_summary(library), false)
    accept_folder_drop_target(library.id)

    if ImGui.BeginPopupContextItem(
      ctx,
      "sidebar_library_context_" .. tostring(index)
    ) then
      if ImGui.MenuItem(ctx, "添加来源路径…") then
        add_root(library.id)
      end

      if ImGui.MenuItem(ctx, "扫描全部来源") then
        start_scan(
          "扫描 " .. library.name,
          roots_for_library(library.id)
        )
      end

      if ImGui.MenuItem(ctx, "重命名") then
        rename_library(library)
      end

      if ImGui.MenuItem(ctx, "展开或折叠来源") then
        state.expanded_libraries[library.id] = not expanded
        state.libraries_dirty = true
      end

      if ImGui.MenuItem(ctx, "从 PsyReaSFX 删除") then
        local answer = reaper.MB(
          "删除逻辑音效库及其所有来源路径？\n\n"
            .. library.name
            .. "\n\n不会删除磁盘中的音频文件。",
          SCRIPT_NAME,
          4
        )

        if answer == 6 then
          remove_library(library.id)
        end
      end

      ImGui.EndPopup(ctx)
    end

    if expanded then
      for root_index, record in ipairs(library.roots) do
        local root_selected = state.root_filter
          and path_key(state.root_filter) == path_key(record.path)
        local online = directory_exists(record.path)
        local root_label = record.alias ~= ""
          and record.alias
          or basename(record.path)

        sidebar_item(
          "    "
            .. (online and "● " or "○ ")
            .. compact(root_label, 18)
            .. "##root_"
            .. record.id,
          root_selected,
          function()
            state.view = "all"
            state.root_filter = record.path
            state.library_filter_id = library.id
            state.active_collection_id = nil
            state.results_dirty = true
            state.config_dirty = true
          end
        )

        tooltip(record.path)
        accept_folder_drop_target(library.id)

        if ImGui.BeginPopupContextItem(
          ctx,
          "sidebar_root_context_" .. record.id
        ) then
          if ImGui.MenuItem(ctx, "扫描此来源") then
            start_scan("扫描 " .. root_label, { record.path })
          end

          if ImGui.MenuItem(ctx, "打开目录") then
            open_folder(record.path)
          end

          ImGui.Separator(ctx)

          if ImGui.MenuItem(ctx, "指定此来源封面…") then
            choose_artwork_for_root(record)
          end

          if ImGui.MenuItem(ctx, "重新自动查找此来源封面") then
            redetect_root_artwork(record)
          end

          if ImGui.MenuItem(ctx, "清除此来源封面") then
            clear_root_artwork(record)
          end

          ImGui.Separator(ctx)

          if ImGui.MenuItem(ctx, "重新定位来源路径…") then
            relink_root(record)
          end

          ImGui.Separator(ctx)

          if ImGui.MenuItem(ctx, "移除来源路径") then
            remove_root(record)
          end

          ImGui.EndPopup(ctx)
        end
      end
    end
  end

  ImGui.Spacing(ctx)

  if dark_button("+ 新建音效库", -1) then
    add_root()
  end

  if dark_button("管理音效库", -1) then
    ImGui.OpenPopup(
      ctx,
      "管理音效库##psyreasfx"
    )
  end

  draw_library_manager_popup()

  end

  if sidebar_section_header(
    "ucs",
    sidebar_section_label("ucs")
  ) then
    draw_ucs_sidebar_tree()
  end

  if sidebar_section_header(
    "collections",
    sidebar_section_label("collections")
  ) then

  if #state.collections == 0 then
    ImGui.TextDisabled(ctx, "尚无播放列表或项目素材箱")
  end

  for index, collection in ipairs(state.collections) do
    local selected =
      state.active_collection_id
        == collection.id

    local prefix =
      collection.kind == "project"
      and translate_ui_text("[项目] ")
      or ""

    local collection_name = collection.name

    if state.language == "en" then
      if collection_name == "新播放列表" then
        collection_name = "New playlist"
      elseif collection_name == "当前项目" then
        collection_name = "Current project"
      end
    end

    sidebar_item(
      prefix
        .. compact(collection_name, 20)
        .. "  "
        .. tostring(collection_item_count(collection))
        .. "##collection_"
        .. tostring(index),
      selected,
      function()
        state.view = "all"
        state.active_collection_id =
          collection.id
        state.root_filter = nil
        state.results_dirty = true
        state.config_dirty = true
      end
    )

    if ImGui.BeginPopupContextItem(
      ctx,
      "collection_context_" .. tostring(index)
    ) then
      local assets = selected_assets()

      if #assets > 0
        and ImGui.MenuItem(
          ctx,
          "加入当前所选素材"
        ) then
        add_assets_to_collection(
          collection,
          assets
        )
      end

      if selected and #assets > 0
        and ImGui.MenuItem(
          ctx,
          "从此集合移除所选素材"
        ) then
        remove_assets_from_collection(
          collection,
          assets
        )
      end

      ImGui.Separator(ctx)

      if ImGui.MenuItem(ctx, "重命名") then
        rename_collection(collection)
      end

      if collection.kind == "project" then
        if ImGui.MenuItem(ctx, "绑定到当前 REAPER 工程") then
          bind_project_bin(collection, state.current_project_path)
        end

        if state.current_project_bin_id == collection.id
          and ImGui.MenuItem(ctx, "查看当前工程已用素材") then
          state.active_collection_id = nil
          state.view = "project_used"
          state.root_filter = nil
          state.library_filter_id = nil
          state.results_dirty = true
        end
      end

      if ImGui.MenuItem(ctx, "删除") then
        delete_collection(collection)
      end

      ImGui.EndPopup(ctx)
    end
  end

  if dark_button("+ 播放列表", -1) then
    create_collection("playlist")
  end

  if dark_button("+ 项目素材箱", -1) then
    create_collection("project")
  end

  end

  if sidebar_section_header(
    "saved_searches",
    sidebar_section_label("saved_searches")
  ) then

  if #state.saved_searches == 0 then
    ImGui.TextDisabled(ctx, "尚无保存搜索")
  end

  for index, saved in ipairs(state.saved_searches) do
    sidebar_item(
      compact(saved.name, 24)
        .. "##saved_search_"
        .. tostring(index),
      false,
      function()
        activate_saved_search(saved)
      end
    )

    tooltip(saved.query ~= "" and saved.query or "空搜索")

    if ImGui.BeginPopupContextItem(
      ctx,
      "saved_search_context_" .. tostring(index)
    ) then
      if ImGui.MenuItem(ctx, "载入") then
        activate_saved_search(saved)
      end

      if ImGui.MenuItem(ctx, "用当前条件覆盖") then
        saved.query = state.search
        saved.view = state.view
        saved.root = state.root_filter or ""
        saved.library_id = state.library_filter_id
        saved.sort_mode = state.sort_mode
        saved.sort_desc = state.sort_desc
        saved.status_filter = state.status_filter
        saved.collection_id =
          state.active_collection_id
        local save_ucs = ucs_directory_view(state.view)
        saved.ucs_category = save_ucs and state.ucs_filter_category or nil
        saved.ucs_subcategory = save_ucs
          and state.ucs_filter_subcategory or nil
        saved.ucs_catid = save_ucs and state.ucs_filter_catid or nil
        state.searches_dirty = true
        set_status("已更新保存搜索：" .. saved.name)
      end

      if ImGui.MenuItem(ctx, "重命名") then
        rename_saved_search(saved)
      end

      if ImGui.MenuItem(ctx, "删除") then
        delete_saved_search(saved)
      end

      ImGui.EndPopup(ctx)
    end
  end

  if dark_button("+ 保存当前搜索", -1) then
    save_current_search()
  end

  end

  if sidebar_section_header(
    "workflow",
    sidebar_section_label("workflow")
  ) then

  sidebar_item(
    "全部状态",
    state.status_filter == nil,
    function()
      state.status_filter = nil
      state.results_dirty = true
      state.config_dirty = true
    end
  )

  for _, status in ipairs(
    {
      "candidate",
      "approved",
      "rejected",
    }
  ) do
    local definition =
      WORKFLOW_STATUS[status]

    sidebar_item(
      definition.label
        .. "##status_filter_"
        .. status,
      state.status_filter == status,
      function()
        state.status_filter = status
        state.results_dirty = true
        state.config_dirty = true
      end
    )
  end

  end

  if sidebar_section_header(
    "activity",
    sidebar_section_label("activity")
  ) then

  ImGui.TextWrapped(
    ctx,
    string.format(
      "结果 %d\n已选 %d\n试听 %s",
      #state.results,
      selected_count(),
      state.preview_backend
    )
  )
  end
end

function draw_ucs_search_suggestion_popup(active, x, y, width)
  if not active and not state.ucs_search_popup_visible then return end
  local suggestions = ucs_search_suggestions(
    state.search,
    state.language,
    7
  )
  if active and #suggestions > 0
    and not state.ucs_search_popup_visible then
    AppState.set("ucs_search_popup_visible", true)
    ImGui.OpenPopup(ctx, "UCS 搜索提示##ucs_search_suggestions")
  end
  if not state.ucs_search_popup_visible then return end
  ImGui.SetNextWindowPos(ctx, x, y, ImGui.Cond_Always)
  ImGui.SetNextWindowSize(ctx, width, 0, ImGui.Cond_Always)
  if not ImGui.BeginPopup(
    ctx,
    "UCS 搜索提示##ucs_search_suggestions",
    ImGui.WindowFlags_NoMove
      | ImGui.WindowFlags_AlwaysAutoResize
  ) then
    AppState.set("ucs_search_popup_visible", false)
    return
  end

  if #suggestions == 0 then
    ImGui.CloseCurrentPopup(ctx)
    AppState.set("ucs_search_popup_visible", false)
  else
    ImGui.TextDisabled(ctx, "UCS 搜索提示")
    ImGui.Separator(ctx)
    local matched_labels = {
      CatID = "CatID",
      Category = "分类",
      SubCategory = "子分类",
      Synonym = "同义词",
    }
    for _, suggestion in ipairs(suggestions) do
      local entry = suggestion.entry
      local matched = "en" == state.language
          and suggestion.matched
        or (matched_labels[suggestion.matched] or suggestion.matched)
      local localized = "en" == state.language
          and entry.subcategory
        or (entry.subcategory_zh ~= ""
          and entry.subcategory_zh .. " · " .. entry.subcategory
          or entry.subcategory)
      local label = entry.catid
        .. "  ·  " .. entry.category
        .. " / " .. localized
        .. "  [" .. matched .. "]"
        .. "##ucs_search_" .. entry.catid
      if ImGui.Selectable(ctx, label, false) then
        AppState.set(
          "search",
          ucs_apply_search_suggestion(state.search, entry.catid)
        )
        AppState.mark_dirty("results_dirty")
        AppState.set("focus_search", true)
        ImGui.CloseCurrentPopup(ctx)
        AppState.set("ucs_search_popup_visible", false)
      end
      local detail = "en" == state.language
          and (entry.explanation ~= "" and entry.explanation
            or entry.synonyms_en)
        or (entry.synonyms_zh ~= "" and entry.synonyms_zh
          or entry.explanation)
      tooltip(detail)
    end
  end
  ImGui.EndPopup(ctx)
end

function draw_toolbar()
  if state.focus_search then
    ImGui.SetKeyboardFocusHere(ctx)
    state.focus_search = false
  end

  local toolbar_width =
    select(1, ImGui.GetContentRegionAvail(ctx))

  local compact_toolbar = toolbar_width < 1080
  local control_size = 32

  draw_brand_mark(compact_toolbar)
  ImGui.SameLine(ctx)

  if icon_button(
    "sidebar",
    "panel_left",
    state.sidebar_visible
      and "隐藏导航栏"
      or "显示导航栏",
    state.sidebar_visible,
    control_size
  ) then
    state.sidebar_visible =
      not state.sidebar_visible
    state.config_dirty = true
  end

  ImGui.SameLine(ctx)

  if icon_button(
    "inspector",
    "panel_right",
    state.inspector_visible
      and "隐藏元数据面板"
      or "显示元数据面板",
    state.inspector_visible,
    control_size
  ) then
    state.inspector_visible =
      not state.inspector_visible
    state.config_dirty = true
  end

  ImGui.SameLine(ctx)

  local focus_mode =
    not state.sidebar_visible
    and not state.inspector_visible

  if icon_button(
    "focus",
    "focus",
    focus_mode
      and "退出专注模式"
      or "进入专注模式",
    focus_mode,
    control_size
  ) then
    if focus_mode then
      state.sidebar_visible = true
      state.inspector_visible = true
    else
      state.sidebar_visible = false
      state.inspector_visible = false
    end

    state.config_dirty = true
  end

  ImGui.SameLine(ctx)

  local folder_clicked =
    icon_button(
      "folder_hierarchy",
      "folder_search",
      nil,
      state.folder_menu_active,
      control_size
    )

  if folder_clicked then
    state.folder_menu_active = true
    AppState.set("folder_hover_levels", {})
    ensure_folder_navigation_build()
    ImGui.OpenPopup(
      ctx,
      "文件夹层级##folder_hover_menu"
    )
  end

  draw_folder_hover_popup()
  ImGui.SameLine(ctx)

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_FrameBg,
    COLOR.input
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Text,
    COLOR.input_text
  )

  local text_height = ImGui.GetTextLineHeight(ctx)
  local input_padding_y =
    math.max(2, (control_size - text_height) * 0.5)

  ImGui.PushStyleVar(
    ctx,
    ImGui.StyleVar_FramePadding,
    8,
    input_padding_y
  )

  local search_x, search_y = ImGui.GetCursorScreenPos(ctx)
  local search_width = math.max(
    260,
    select(1, ImGui.GetContentRegionAvail(ctx)) - 228
  )
  ImGui.SetNextItemWidth(ctx, -228)

  local changed
  changed, state.search =
    ImGui.InputTextWithHint(
      ctx,
      "##search",
      "输入关键词或描述声音…  category:impact  status:candidate  -exclude",
      state.search
    )

  -- InputText may deactivate on the Enter frame before the global keyboard
  -- handler runs. Keep that frame consumed so Enter confirms text only.
  local search_active = ImGui.IsItemActive(ctx)
  local search_deactivated = ImGui.IsItemDeactivated(ctx)
  if search_active or search_deactivated then
    AppState.set("keyboard_consumed", true)
  end

  ImGui.PopStyleColor(ctx, 2)
  ImGui.PopStyleVar(ctx)

  if changed then
    state.results_dirty = true
  end

  ImGui.SameLine(ctx)

  if icon_button(
    "clear_search",
    "close",
    "清空搜索",
    state.search ~= "",
    control_size
  ) then
    state.search = ""
    state.results_dirty = true
  end

  ImGui.SameLine(ctx)

  if icon_button(
    "auto_preview",
    "speaker",
    state.auto_preview
      and "关闭自动试听"
      or "开启自动试听",
    state.auto_preview,
    control_size
  ) then
    state.auto_preview = not state.auto_preview
    state.config_dirty = true
  end

  ImGui.SameLine(ctx)

  if icon_button(
    "played_reset",
    "played_reset",
    "清除本次已播放高亮",
    session_played_count() > 0,
    control_size
  ) then
    clear_session_played_highlights()
  end

  ImGui.SameLine(ctx)

  local background_scan_active =
    (state.scan and state.scan.silent)
    or (state.import_session and state.import_session.silent)
  local scan_tooltip = "增量扫描"

  if state.scan then
    scan_tooltip = string.format(
      "后台检查中：%d 个音频 / %d 个目录",
      state.scan.files,
      state.scan.directories
    )
  elseif state.import_session and state.import_session.silent then
    scan_tooltip = string.format(
      "后台建立索引：%d / %d，失败 %d",
      state.import_session.done,
      state.import_session.total,
      state.import_session.failed
    )
  end

  if icon_button(
    "scan",
    "refresh",
    scan_tooltip,
    state.scan ~= nil or background_scan_active,
    control_size,
    background_scan_active
  ) then
    if not state.scan and not state.import_session then
      start_scan("增量扫描")
    end
  end

  ImGui.SameLine(ctx)

  if icon_button(
    "help",
    "help",
    "使用说明与快捷键",
    false,
    control_size
  ) then
    state.help_popup_requested = 1
  end

  ImGui.SameLine(ctx)

  if icon_button(
    "settings",
    "settings",
    "打开设置",
    false,
    control_size
  ) then
    ImGui.OpenPopup(
      ctx,
      "设置##reasfx"
    )
  end

  draw_ucs_search_suggestion_popup(
    search_active,
    search_x,
    search_y + control_size + 3,
    search_width
  )

end

function draw_sub_toolbar()
  local labels_zh = {
    name = "名称",
    duration = "时长",
    library = "音效库",
    used = "最近插入",
    previewed = "最近试听",
  }

  local labels_en = {
    name = "Name",
    duration = "Duration",
    library = "Library",
    used = "Recently inserted",
    previewed = "Recently previewed",
  }

  local labels =
    state.language == "en"
      and labels_en
      or labels_zh

  local sort_prefix =
    state.language == "en"
      and "Sort: "
      or "排序："

  local breadcrumb = "Home"

  if state.active_collection_id then
    local collection =
      state.collection_by_id[
        state.active_collection_id
      ]

    if collection then
      breadcrumb =
        breadcrumb
        .. "  /  "
        .. collection.name
    end
  end

  if state.root_filter then
    breadcrumb =
      breadcrumb
      .. "  /  "
      .. basename(state.root_filter)
  elseif state.library_filter_id then
    local library = state.library_by_id[state.library_filter_id]

    if library then
      breadcrumb = breadcrumb .. "  /  " .. library.name
    end
  end

  if ucs_directory_view(state.view) and state.ucs_filter_category then
    breadcrumb = breadcrumb .. "  /  UCS  /  " .. state.ucs_filter_category
    if state.ucs_filter_subcategory then
      breadcrumb = breadcrumb .. "  /  " .. state.ucs_filter_subcategory
    end
    if state.ucs_filter_catid then
      breadcrumb = breadcrumb .. "  /  " .. state.ucs_filter_catid
    end
  end

  if state.status_filter then
    breadcrumb =
      breadcrumb
      .. "  /  "
      .. workflow_label(state.status_filter)
  end

  if trim(state.search) ~= "" then
    breadcrumb =
      breadcrumb
      .. "  /  Search"
  end

  if state.active_collection_id then
    if dark_button("← 全部素材", 86) then
      state.active_collection_id = nil
      state.view = "all"
      state.results_dirty = true
      state.config_dirty = true
    end

    ImGui.SameLine(ctx)
  end

  ImGui.TextDisabled(ctx, breadcrumb)

  ImGui.SameLine(ctx)

  ImGui.TextDisabled(
    ctx,
    string.format(
      "　%d 个结果",
      #state.results
    )
  )

  ImGui.SameLine(ctx)

  if dark_button(
    sort_prefix
      .. (
        labels[state.sort_mode]
        or labels.name
      ),
    state.language == "en"
      and 154
      or 118
  ) then
    local next_mode = {
      name = "duration",
      duration = "library",
      library = "used",
      used = "previewed",
      previewed = "name",
    }

    state.sort_mode =
      next_mode[state.sort_mode] or "name"
    state.results_dirty = true
  end

  ImGui.SameLine(ctx)

  if dark_button(
    state.sort_desc and "↓" or "↑",
    30
  ) then
    state.sort_desc = not state.sort_desc
    state.results_dirty = true
  end

  local active_collection =
    state.active_collection_id
    and state.collection_by_id[
      state.active_collection_id
    ]
    or nil

  if active_collection then
    ImGui.SameLine(ctx)

    if dark_button("加入所选", 68) then
      add_assets_to_collection(
        active_collection,
        selected_assets()
      )
    end

    ImGui.SameLine(ctx)

    if dark_button("移除所选", 68) then
      remove_assets_from_collection(
        active_collection,
        selected_assets()
      )
    end
  end

  ImGui.SameLine(ctx)
  ImGui.TextDisabled(
    ctx,
    "右键表头选择字段；拖动分隔线调整列宽；Shift+滚轮横向查看"
  )

  if state.scan and not state.scan.silent then
    ImGui.SameLine(ctx)
    ImGui.TextColored(
      ctx,
      COLOR.warning,
      string.format(
        "扫描 %d 文件 / %d 目录",
        state.scan.files,
        state.scan.directories
      )
    )
  end
end

function draw_import_progress()
  local visible_scan =
    state.scan and not state.scan.silent
  local visible_import =
    visible_progress_session(state.import_session)
  local visible_relink = state.relink_plan_session
  local visible_artwork_reset = state.artwork_reset_session
  local visible_root_removal = state.root_removal_session

  if not visible_scan
    and not visible_import
    and not state.precache_session
    and not visible_relink
    and not visible_artwork_reset
    and not visible_root_removal then
    return
  end

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_ChildBg,
    0x171A20FF
  )

  if ImGui.BeginChild(
    ctx,
    "import_progress",
    -1,
    72,
    ImGui.ChildFlags_Borders
  ) then
    if visible_root_removal then
      local phase = visible_root_removal.phase
      local completed = 0
      local total = 0
      local label = "筛选目录素材"
      if phase == "filter" then
        completed = math.max(
          0,
          (visible_root_removal.filter_job.index or 1) - 1
        )
        total = visible_root_removal.filter_job.total or 0
      elseif phase == "collections" then
        label = "清理集合引用"
        completed = visible_root_removal.collection_processed or 0
        total = visible_root_removal.collection_total or 0
      elseif phase == "project_usage" then
        label = string.format(
          "清理工程使用记录（已检查 %d 条）",
          visible_root_removal.project_usage_processed or 0
        )
        completed = math.max(
          0,
          (visible_root_removal.project_index or 1) - 1
        )
        total = #(visible_root_removal.project_keys or {})
      elseif phase == "cleanup" then
        label = "清理素材引用"
        completed = math.max(0, (visible_root_removal.cleanup_index or 1) - 1)
        total = #visible_root_removal.filter_job.removed
      elseif phase == "rollback" then
        label = "回滚已清理引用"
        total = #visible_root_removal.cleanup_records
        completed = math.max(
          0,
          total - (visible_root_removal.rollback_index or 0)
        )
      else
        label = "完成事务"
        completed = 1
        total = 1
      end
      completed = math.min(completed, total)
      local fraction = total > 0 and completed / total or 1
      ImGui.Text(ctx, string.format(
        "正在%s：%s  %d / %d",
        visible_root_removal.library_id and "移除音效库" or "移除来源",
        label,
        completed,
        total
      ))
      ImGui.ProgressBar(
        ctx,
        fraction,
        -100,
        18,
        string.format("%.1f%%", fraction * 100)
      )
      ImGui.TextDisabled(ctx, compact(visible_root_removal.label, 80))
    elseif visible_artwork_reset then
      local completed = math.min(
        math.max(0, (visible_artwork_reset.index or 1) - 1),
        visible_artwork_reset.total or 0
      )
      local total = visible_artwork_reset.total or 0
      local fraction = total > 0 and completed / total or 1
      ImGui.Text(ctx, string.format(
        "正在清空 Artwork 缓存  %d / %d  已重置 %d",
        completed,
        total,
        visible_artwork_reset.changed or 0
      ))
      ImGui.ProgressBar(
        ctx,
        fraction,
        -100,
        18,
        string.format("%.1f%%", fraction * 100)
      )
      ImGui.TextDisabled(ctx, "只清理 PsyReaSFX 缓存，不会删除源图片")
    elseif visible_relink then
      local completed = math.min(
        math.max(0, (visible_relink.index or 1) - 1),
        visible_relink.total or 0
      )
      local total = visible_relink.total or 0
      local fraction = total > 0 and completed / total or 1
      ImGui.Text(ctx, string.format(
        "正在生成来源重定位计划  %d / %d  目标 %d  缺失 %d  冲突 %d",
        completed,
        total,
        #visible_relink.entries,
        visible_relink.missing,
        #visible_relink.conflicts
      ))
      ImGui.ProgressBar(
        ctx,
        fraction,
        -100,
        18,
        string.format("%.1f%%", fraction * 100)
      )
      ImGui.TextDisabled(ctx, compact(
        visible_relink.old_root .. " → " .. visible_relink.new_root,
        80
      ))
    elseif state.precache_session then
      local session = state.precache_session
      local current_progress =
        session.current
        and session.current.progress
        or 0

      local collecting = session.phase == "collect"
      local completed = collecting
        and math.max(0, (session.collect_index or 1) - 1)
        or session.generated + session.cached + session.failed
      local total = collecting
        and (session.source_total or 0) or (session.total or 0)

      local fraction =
        total > 0
        and clamp(
          (completed + current_progress)
            / total,
          0,
          1
        )
        or 0

      local current_name =
        collecting and "正在整理预缓存范围"
        or session.current
        and session.current.asset
        and session.current.asset.name
        or "检查现有缓存"

      ImGui.Text(
        ctx,
        string.format(
          "%s %d 点  %d / %d  新生成 %d  已有 %d  失败 %d",
          collecting and "整理高精度预缓存" or "高精度预缓存",
          session.points,
          completed,
          total,
          session.generated,
          session.cached,
          session.failed
        )
      )

      ImGui.ProgressBar(
        ctx,
        fraction,
        -100,
        18,
        string.format("%.1f%%", fraction * 100)
      )

      ImGui.TextDisabled(
        ctx,
        compact(current_name, 80)
      )
    elseif visible_scan then
      local scan = state.scan
      if scan.phase then
        local label = "整理扫描结果"
        local completed = 0
        local total = 0
        if scan.phase == "finalize_prune" then
          label = "整理索引"
          completed = scan.prune_job and scan.prune_job.processed or 0
          total = scan.finalize_total or 0
        elseif scan.phase == "finalize_pending" then
          label = "整理待分析素材"
          completed = math.max(0, (scan.pending_index or 1) - 1)
          total = #scan.new_assets
        elseif scan.phase == "cancel_collect" then
          label = "收集待清理素材"
          completed = math.max(0, (scan.cancel_index or 1) - 1)
          total = #scan.new_assets
        else
          label = "取消并清理扫描"
          completed = scan.prune_job and scan.prune_job.processed or 0
          total = scan.cancel_total or 0
        end
        completed = math.min(completed, total)
        local fraction = total > 0 and completed / total or 1
        ImGui.Text(ctx, string.format(
          "%s：%s  %d / %d",
          scan.reason,
          label,
          completed,
          total
        ))
        ImGui.ProgressBar(
          ctx,
          fraction,
          -100,
          18,
          string.format("%.1f%%", fraction * 100)
        )
      else
        local animated =
          (reaper.time_precise() * 0.28) % 1
        ImGui.Text(
          ctx,
          string.format(
            "%s：正在扫描文件…  已发现 %d 个音频 / %d 个目录",
            scan.reason,
            scan.files,
            scan.directories
          )
        )
        ImGui.ProgressBar(
          ctx,
          animated,
          -100,
          18,
          "扫描中"
        )
      end
    else
      local session = visible_import
      local current_progress =
        session.current
        and session.current.progress
        or 0

      local cleanup_phase = session.phase == "finalize"
        or session.phase == "cancel_cleanup"
        or session.phase == "cancel_rebuild"
      local cleanup_completed = session.phase == "finalize"
          and math.max(0, (session.finalize_index or 1) - 1)
        or session.phase == "cancel_cleanup"
          and math.max(0, (session.cleanup_index or 1) - 1)
        or session.phase == "cancel_rebuild"
          and (session.prune_job and session.prune_job.processed or 0)
        or 0
      local cleanup_total = session.phase == "cancel_rebuild"
          and (session.cancel_rebuild_total or 0)
        or #session.assets

      local fraction =
        cleanup_phase and cleanup_total > 0
          and clamp(cleanup_completed / cleanup_total, 0, 1)
        or session.total > 0
        and clamp(
          (session.done + current_progress)
            / session.total,
          0,
          1
        )
        or 1

      local current_name =
        session.current
        and session.current.asset
        and session.current.asset.name
        or "准备下一项"

      ImGui.Text(
        ctx,
        cleanup_phase
          and string.format(
            "%s：%s  %d / %d",
            session.label,
            session.phase == "finalize"
                and "整理已完成素材"
              or session.phase == "cancel_cleanup"
                and "清理未完成素材"
              or "重建可用索引",
            cleanup_completed,
            cleanup_total
          )
          or string.format(
            "%s：分析元数据并建立波形  %d / %d  失败 %d",
            session.label,
            session.done,
            session.total,
            session.failed
          )
      )

      ImGui.ProgressBar(
        ctx,
        fraction,
        -100,
        18,
        string.format("%.1f%%", fraction * 100)
      )

      ImGui.TextDisabled(
        ctx,
        compact(current_name, 80)
      )
    end

    ImGui.SameLine(ctx)

    if dark_button("取消", 72) then
      if visible_root_removal then
        if visible_root_removal.phase ~= "rollback" then
          Jobs.cancel(visible_root_removal.job_token)
        end
      elseif visible_artwork_reset then
        Jobs.cancel(visible_artwork_reset.job_token)
      elseif visible_relink then
        Jobs.cancel(visible_relink.job_token)
        set_status("正在取消来源重定位计划…")
      elseif state.precache_session then
        state.precache_cancel_requested = true
      elseif visible_scan then
        local scan = state.scan
        Jobs.cancel(scan.job_token)
        set_status("正在取消扫描…")
      else
        state.import_cancel_requested = true
      end
    end
  end

  ImGui.EndChild(ctx)
  ImGui.PopStyleColor(ctx)
end

----------------------------------------------------------------
-- UI: result list
----------------------------------------------------------------

local COLUMN_DEFS = {
  {
    key = "waveform",
    label = "Waveform",
    minimum = 180,
    default = 350,
    flexible = true,
  },
  {
    key = "filename",
    label = "Filename",
    minimum = 170,
    default = 265,
    flexible = true,
  },
  {
    key = "status",
    label = "Status",
    minimum = 76,
    default = 88,
  },
  {
    key = "description",
    label = "Keywords / Description",
    minimum = 160,
    default = 320,
    flexible = true,
  },
  {
    key = "category",
    label = "Category",
    minimum = 110,
    default = 140,
  },
  {
    key = "subcategory",
    label = "SubCategory",
    minimum = 120,
    default = 150,
  },
  {
    key = "catid",
    label = "CatID",
    minimum = 76,
    default = 90,
  },
  {
    key = "artwork",
    label = "Artwork",
    minimum = 42,
    default = 58,
  },
  {
    key = "duration",
    label = "Duration",
    minimum = 76,
    default = 92,
  },
  {
    key = "format",
    label = "Format",
    minimum = 104,
    default = 118,
  },
  {
    key = "channels",
    label = "Channels",
    minimum = 76,
    default = 80,
  },
  {
    key = "sample_rate",
    label = "Sample Rate",
    minimum = 94,
    default = 100,
  },
  {
    key = "bit_depth",
    label = "Bit Depth",
    minimum = 82,
    default = 90,
  },
  {
    key = "library",
    label = "Library",
    minimum = 120,
    default = 180,
    flexible = true,
  },
  {
    key = "path",
    label = "Path",
    minimum = 220,
    default = 360,
    flexible = true,
  },
}

local COLUMN_BY_KEY = {}

for _, definition in ipairs(COLUMN_DEFS) do
  COLUMN_BY_KEY[definition.key] = definition
end

function visible_column_definitions()
  local visible = {}

  for _, definition in ipairs(COLUMN_DEFS) do
    if state.column_visible[definition.key] then
      visible[#visible + 1] = definition
    end
  end

  if #visible == 0 then
    state.column_visible.filename = true
    visible[1] = COLUMN_BY_KEY.filename
  end

  return visible
end

function visible_column_count()
  local count = 0

  for _, definition in ipairs(COLUMN_DEFS) do
    if state.column_visible[definition.key] then
      count = count + 1
    end
  end

  return count
end

function reset_columns_default()
  for key in pairs(state.column_visible) do
    state.column_visible[key] = false
  end

  for _, key in ipairs(
    {
      "waveform",
      "filename",
      "description",
      "artwork",
      "duration",
    }
  ) do
    state.column_visible[key] = true
  end

  state.column_widths.waveform = 335
  state.column_widths.filename = 220
  state.column_widths.description = 320
  state.column_widths.artwork = 52
  state.column_widths.duration = 104

  state.ui_density = "compact"
  state.config_dirty = true
  set_status("已恢复默认字段布局")
end

function column_layout(width)
  width = math.max(width, 1)

  local definitions =
    visible_column_definitions()

  local items = {}
  local total = 0
  local minimum_total = 0
  local flexible_count = 0

  for _, definition in ipairs(definitions) do
    local preferred =
      tonumber(
        state.column_widths[definition.key]
      ) or definition.default

    local item = {
      definition = definition,
      width = math.max(
        definition.minimum,
        preferred
      ),
    }

    items[#items + 1] = item
    total = total + item.width
    minimum_total =
      minimum_total + definition.minimum

    if definition.flexible then
      flexible_count = flexible_count + 1
    end
  end

  if total < width then
    local extra = width - total
    local recipients =
      flexible_count > 0
        and flexible_count
        or #items

    for _, item in ipairs(items) do
      if flexible_count == 0
        or item.definition.flexible then
        item.width =
          item.width + extra / recipients
      end
    end
  end

  local offset = 0
  local by_key = {}

  for _, item in ipairs(items) do
    item.x0 = offset
    offset = offset + item.width
    item.x1 = offset
    by_key[item.definition.key] = item
  end

  if #items > 0 and offset < width then
    items[#items].width =
      items[#items].width + (width - offset)

    items[#items].x1 = width
    offset = width
  end

  return {
    items = items,
    by_key = by_key,
    width = math.max(width, offset),
    viewport_width = width,
  }
end

function draw_column_visibility_popup()
  if not ImGui.BeginPopup(
    ctx,
    "column_visibility_popup"
  ) then
    return
  end

  ImGui.TextDisabled(ctx, "显示字段")
  ImGui.Separator(ctx)

  local count = visible_column_count()

  for _, definition in ipairs(COLUMN_DEFS) do
    local visible =
      state.column_visible[definition.key]

    if ImGui.MenuItem(
      ctx,
      definition.label,
      nil,
      visible
    ) then
      if visible and count <= 1 then
        set_status("至少保留一个列表字段", true)
      else
        state.column_visible[definition.key] =
          not visible
        state.config_dirty = true
      end
    end
  end

  ImGui.Separator(ctx)

  if ImGui.MenuItem(ctx, "重置为默认字段") then
    reset_columns_default()
  end

  if ImGui.MenuItem(ctx, "重置全部列宽") then
    for _, definition in ipairs(COLUMN_DEFS) do
      state.column_widths[definition.key] =
        definition.default
    end

    state.config_dirty = true
  end

  ImGui.EndPopup(ctx)
end

function draw_column_splitters(
  x,
  y,
  layout
)
  local saved_x, saved_y =
    ImGui.GetCursorScreenPos(ctx)

  for index = 1, #layout.items - 1 do
    local left = layout.items[index]
    local right = layout.items[index + 1]
    local splitter_x = x + left.x1
    local hit_width = 8

    ImGui.SetCursorScreenPos(
      ctx,
      splitter_x - hit_width * 0.5,
      y
    )

    ImGui.InvisibleButton(
      ctx,
      "column_splitter_"
        .. left.definition.key
        .. "_"
        .. right.definition.key,
      hit_width,
      HEADER_H
    )

    if ImGui.IsItemHovered(ctx)
      or ImGui.IsItemActive(ctx) then
      ImGui.SetMouseCursor(
        ctx,
        ImGui.MouseCursor_ResizeEW
      )
    end

    if ImGui.IsItemActive(ctx)
      and not state.column_drag then
      state.column_drag = {
        left_key = left.definition.key,
        right_key = right.definition.key,
        start_mouse =
          select(1, ImGui.GetMousePos(ctx)),
        start_left = left.width,
        start_right = right.width,
        left_minimum = left.definition.minimum,
        right_minimum = right.definition.minimum,
      }
    end

    local drag = state.column_drag

    if ImGui.IsItemActive(ctx)
      and drag
      and drag.left_key
        == left.definition.key
      and drag.right_key
        == right.definition.key then
      mark_interaction()

      local mouse_x =
        select(1, ImGui.GetMousePos(ctx))

      local delta =
        mouse_x - drag.start_mouse

      local combined =
        drag.start_left + drag.start_right

      local new_left =
        clamp(
          drag.start_left + delta,
          drag.left_minimum,
          combined - drag.right_minimum
        )

      state.column_widths[drag.left_key] =
        new_left

      state.column_widths[drag.right_key] =
        combined - new_left

      state.config_dirty = true
    end

    if ImGui.IsItemHovered(ctx)
      and ImGui.IsMouseDoubleClicked(ctx, 0) then
      state.column_widths[left.definition.key] =
        left.definition.default
      state.column_widths[right.definition.key] =
        right.definition.default
      state.config_dirty = true
    end
  end

  if state.column_drag
    and ImGui.IsMouseReleased(ctx, 0) then
    state.column_drag = nil
  end

  ImGui.SetCursorScreenPos(
    ctx,
    saved_x,
    saved_y
  )
end

function draw_list_header(
  draw_list,
  x,
  y,
  layout,
  viewport_x0,
  viewport_x1
)
  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + layout.width,
    y + HEADER_H,
    COLOR.header
  )

  for index, item in ipairs(layout.items) do
    local column_x = x + item.x0
    local column_end = x + item.x1

    draw_clipped_text(
      draw_list,
      column_x + 7,
      y + 6,
      COLOR.header_text,
      item.definition.label,
      column_x + 2,
      y,
      column_end - 2,
      y + HEADER_H
    )

    if index > 1 then
      ImGui.DrawList_AddLine(
        draw_list,
        column_x,
        y,
        column_x,
        y + HEADER_H,
        COLOR.grid,
        1
      )
    end
  end

  draw_column_splitters(x, y, layout)

  if ImGui.IsMouseHoveringRect(
    ctx,
    viewport_x0 or x,
    y,
    viewport_x1 or (x + layout.width),
    y + HEADER_H
  ) and ImGui.IsMouseClicked(ctx, 1) then
    ImGui.OpenPopup(
      ctx,
      "column_visibility_popup"
    )
  end

  draw_column_visibility_popup()
end

function row_popup(asset)
  if not ImGui.BeginPopupContextItem(
    ctx,
    "asset_context_" .. fnv1a(path_key(asset.path))
  ) then
    return
  end

  local bulk_assets = selected_assets()
  local bulk =
    is_row_selected(asset) and #bulk_assets > 1

  if bulk then
    ImGui.TextDisabled(
      ctx,
      tostring(#bulk_assets) .. " 个已选素材"
    )
    ImGui.Separator(ctx)
  end

  if ImGui.MenuItem(ctx, "试听", "Space") then
    play_preview(asset, 0, false)
  end

  local enter_shortcut =
    state.enter_insert_shortcuts and "Enter" or nil
  local new_track_shortcut =
    state.enter_insert_shortcuts and "Ctrl+Enter" or nil

  if ImGui.MenuItem(ctx, "插入当前轨道", enter_shortcut) then
    insert_asset(asset, false, false)
  end

  if ImGui.MenuItem(ctx, "插入新轨道", new_track_shortcut) then
    insert_asset(asset, true, false)
  end

  if ImGui.MenuItem(ctx, "按 BWF 时间戳插入") then
    insert_asset(asset, false, true)
  end

  if bulk
    and ImGui.MenuItem(
      ctx,
      "所选素材分轨插入"
    ) then
    insert_selected_stack(0, 1)
  end

  local target_assets =
    bulk and bulk_assets or { asset }

  if ImGui.BeginMenu(ctx, "工作流状态") then
    for _, status in ipairs(
      WORKFLOW_STATUS_ORDER
    ) do
      local definition =
        WORKFLOW_STATUS[status]

      if ImGui.MenuItem(
        ctx,
        definition.label
      ) then
        set_workflow_status(
          target_assets,
          status
        )
      end
    end

    ImGui.EndMenu(ctx)
  end

  if #state.collections > 0
    and ImGui.BeginMenu(ctx, "添加到集合") then

    for _, collection in ipairs(state.collections) do
      local prefix =
        collection.kind == "project"
        and "[项目] "
        or ""

      if ImGui.MenuItem(
        ctx,
        prefix .. collection.name
      ) then
        add_assets_to_collection(
          collection,
          target_assets
        )
      end
    end

    ImGui.EndMenu(ctx)
  end

  local active_collection =
    state.active_collection_id
    and state.collection_by_id[
      state.active_collection_id
    ]
    or nil

  if active_collection
    and ImGui.MenuItem(
      ctx,
      "从当前集合移除"
    ) then
    remove_assets_from_collection(
      active_collection,
      target_assets
    )
  end

  ImGui.Separator(ctx)

  local all_marked = true

  for _, target in ipairs(target_assets) do
    if not target.marked then
      all_marked = false
      break
    end
  end

  local mark_label

  if bulk then
    mark_label =
      all_marked
      and "取消标记全部所选"
      or "标记全部所选"
  else
    mark_label =
      asset.marked
      and "取消标记"
      or "标记"
  end

  if ImGui.MenuItem(
    ctx,
    mark_label,
    "M"
  ) then
    set_assets_marked(
      target_assets,
      not all_marked
    )
  end

  if bulk and ImGui.MenuItem(ctx, "收藏全部所选") then
    if state.root_removal_session then
      set_status("请等待来源移除完成后再修改收藏", true)
    else
      for _, selected_item in ipairs(bulk_assets) do
        state.favorites[path_key(selected_item.path)] = true
      end

      state.config_dirty = true
      state.results_dirty = true
      set_status("已收藏所选素材")
    end
  end

  if ImGui.MenuItem(
    ctx,
    state.favorites[path_key(asset.path)]
      and "取消收藏"
      or "收藏",
    "F"
  ) then
    toggle_favorite(asset)
  end

  if ImGui.MenuItem(ctx, "重新读取元数据") then
    asset.indexed = false
    queue_metadata(asset, true)
  end

  if ImGui.MenuItem(ctx, "复制完整路径") then
    ImGui.SetClipboardText(ctx, asset.path)
    set_status("已复制路径")
  end

  if ImGui.MenuItem(ctx, "在资源管理器中显示") then
    reveal_file(asset.path)
  end

  ImGui.EndPopup(ctx)
end

function column_text(asset, key)
  if key == "status" then
    return workflow_label(
      asset.workflow_status or "none"
    )
  elseif key == "description" then
    if asset.description and asset.description ~= "" then
      return asset.description
    elseif asset.keywords and asset.keywords ~= "" then
      return asset.keywords
    end

    return asset.folder or ""
  elseif key == "category" then
    return asset.category or ""
  elseif key == "subcategory" then
    return asset.subcategory or ""
  elseif key == "catid" then
    return asset.catid or ""
  elseif key == "duration" then
    return asset.duration > 0
      and format_duration_clock(asset.duration)
      or "…"
  elseif key == "format" then
    local bit_depth =
      tonumber(asset.bit_depth) or 0

    return string.format(
      "%s  %s  %dch",
      format_rate(asset.sample_rate),
      bit_depth > 0
        and tostring(bit_depth) .. "-bit"
        or "—",
      tonumber(asset.channels) or 0
    )
  elseif key == "channels" then
    return tostring(asset.channels or 0)
  elseif key == "sample_rate" then
    return format_rate(asset.sample_rate)
  elseif key == "bit_depth" then
    local bit_depth =
      tonumber(asset.bit_depth) or 0

    return bit_depth > 0
      and tostring(bit_depth) .. "-bit"
      or "—"
  elseif key == "library" then
    return asset.library or ""
  elseif key == "path" then
    return asset.path or ""
  end

  return ""
end

function draw_result_row(
  asset,
  index,
  width,
  layout
)
  ImGui.SetCursorPosY(
    ctx,
    (index - 1) * ROW_H
  )

  local x, y =
    ImGui.GetCursorScreenPos(ctx)

  ImGui.InvisibleButton(
    ctx,
    "row_" .. tostring(index),
    width,
    ROW_H
  )

  local clicked =
    ImGui.IsItemClicked(ctx, 0)

  local hovered =
    ImGui.IsItemHovered(ctx)

  local active =
    ImGui.IsItemActive(ctx)

  local dragging =
    active
    and ImGui.IsMouseDragging(ctx, 0, 6)

  local selected =
    is_row_selected(asset)

  local asset_key = path_key(asset.path)
  local waveform_state, waveform_color =
    waveform_visual_state(asset, selected)

  local primary_text_color =
    row_text_visual_color(asset, selected)

  local secondary_text_color =
    state.played_text_enabled
      and asset_is_session_played(asset)
      and rgba_with_alpha(
        COLOR.played_text,
        selected and 0xFF or 0xB0
      )
      or selected
        and 0xD9E9FFFF
        or COLOR.dim

  local draw_list =
    ImGui.GetWindowDrawList(ctx)

  local background =
    selected
      and COLOR.selected
      or hovered
        and COLOR.row_hover
        or index % 2 == 0
          and COLOR.row_alt
          or COLOR.row

  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + width,
    y + ROW_H,
    background
  )

  queue_metadata(asset, false)

  local waveform_item =
    layout.by_key.waveform

  local compact_row =
    state.ui_density == "compact"

  local text_height =
    select(
      2,
      ImGui.CalcTextSize(ctx, "Ag")
    ) or 14

  local centered_y =
    y + math.max(
      2,
      (ROW_H - text_height) * 0.5
    )

  for column_index, item in ipairs(layout.items) do
    local key = item.definition.key
    local column_x = x + item.x0
    local column_end = x + item.x1

    if column_index > 1 then
      ImGui.DrawList_AddLine(
        draw_list,
        column_x,
        y,
        column_x,
        y + ROW_H,
        COLOR.grid,
        1
      )
    end

    if key == "waveform" then
      local waveform =
        queue_wave(
          asset,
          state.mini_wave_points,
          false
        )

      local wave_x = column_x + 2
      local wave_y = y + 2
      local wave_width =
        math.max(1, item.width - 4)
      local wave_height = ROW_H - 4

      draw_waveform(
        draw_list,
        waveform,
        wave_x,
        wave_y,
        wave_width,
        wave_height,
        waveform_color
      )

      if waveform_state == "marked" then
        local marker_x = wave_x + wave_width - 8
        local marker_y = wave_y + 7

        ImGui.DrawList_AddCircleFilled(
          draw_list,
          marker_x,
          marker_y,
          3,
          COLOR.waveform_marked,
          12
        )
      end

      if state.preview
        and state.preview_path
        and path_key(state.preview_path)
          == asset_key then
        local percent =
          clamp(
            state.preview_percent or 0,
            0,
            1
          )

        local pointer_x =
          wave_x + wave_width * percent

        ImGui.DrawList_AddLine(
          draw_list,
          pointer_x,
          wave_y,
          pointer_x,
          wave_y + wave_height,
          COLOR.playhead,
          2
        )
      end

      if not waveform and asset.wave_error then
        draw_clipped_text(
          draw_list,
          wave_x + 7,
          centered_y,
          COLOR.error,
          "波形不可用",
          column_x + 2,
          y + 2,
          column_end - 2,
          y + ROW_H - 2
        )
      end
    elseif key == "artwork" then
      local size =
        math.max(
          12,
          math.min(
            ROW_H - 4,
            item.width - 8
          )
        )

      local art_x =
        column_x
          + (item.width - size) * 0.5

      local art_y =
        y + (ROW_H - size) * 0.5

      draw_artwork_cover(
        draw_list,
        asset,
        art_x,
        art_y,
        size,
        size,
        true,
        compact_row and 1 or 3,
        false
      )
    elseif key == "filename" then
      local favorite =
        state.favorites[asset_key]

      local filename_color =
        asset_is_session_played(asset)
          and primary_text_color
          or favorite
            and COLOR.favorite
            or primary_text_color

      if compact_row then
        draw_clipped_text(
          draw_list,
          column_x + 7,
          centered_y,
          filename_color,
          (favorite and "★ " or "")
            .. asset.name,
          column_x + 2,
          y + 2,
          column_end - 2,
          y + ROW_H - 2
        )
      else
        draw_clipped_text(
          draw_list,
          column_x + 7,
          y + 5,
          filename_color,
          (favorite and "★ " or "")
            .. asset.name,
          column_x + 2,
          y + 2,
          column_end - 2,
          y + ROW_H - 2
        )

        local secondary =
          table.concat(
            {
              asset.category or "",
              asset.subcategory or "",
            },
            " · "
          ):gsub("^ · ", "")
            :gsub(" · $", "")

        draw_clipped_text(
          draw_list,
          column_x + 7,
          y + 23,
          secondary_text_color,
          secondary,
          column_x + 2,
          y + 2,
          column_end - 2,
          y + ROW_H - 2
        )
      end
    elseif key == "status" then
      local status_definition =
        WORKFLOW_STATUS[
          asset.workflow_status or "none"
        ] or WORKFLOW_STATUS.none

      draw_clipped_text(
        draw_list,
        column_x + 7,
        centered_y,
        asset_is_session_played(asset)
          and primary_text_color
          or selected
            and COLOR.selected_text
            or status_definition.color,
        status_definition.short,
        column_x + 2,
        y + 2,
        column_end - 2,
        y + ROW_H - 2
      )
    else
      draw_clipped_text(
        draw_list,
        column_x + 7,
        centered_y,
        primary_text_color,
        column_text(asset, key),
        column_x + 2,
        y + 2,
        column_end - 2,
        y + ROW_H - 2
      )
    end
  end

  ImGui.DrawList_AddLine(
    draw_list,
    x,
    y + ROW_H,
    x + width,
    y + ROW_H,
    COLOR.grid,
    1
  )

  if clicked then
    mark_interaction()

    local mods = ImGui.GetKeyMods(ctx)
    local ctrl =
      (mods & ImGui.Mod_Ctrl) ~= 0
    local shift =
      (mods & ImGui.Mod_Shift) ~= 0

    local mouse_x =
      select(1, ImGui.GetMousePos(ctx))

    if waveform_item
      and mouse_x >= x + waveform_item.x0
      and mouse_x <= x + waveform_item.x1
      and not ctrl
      and not shift then
      local percent =
        clamp(
          (mouse_x - (x + waveform_item.x0))
            / math.max(1, waveform_item.width),
          0,
          0.999
        )

      select_result_with_modifiers(
        index,
        false,
        false,
        false
      )

      play_preview(asset, percent, false)
    else
      select_result_with_modifiers(
        index,
        ctrl,
        shift,
        nil
      )
    end
  end

  if dragging and not state.external_drag then
    if not is_row_selected(asset) then
      select_result(index, false)
    end

    begin_external_drag(asset, false)
  end

  if hovered
    and ImGui.IsMouseDoubleClicked(ctx, 0) then
    local mouse_x =
      select(1, ImGui.GetMousePos(ctx))

    if not waveform_item
      or mouse_x < x + waveform_item.x0
      or mouse_x > x + waveform_item.x1 then
      insert_asset(asset, false, false)
    end
  end

  row_popup(asset)
end

function draw_results()
  local width, height =
    ImGui.GetContentRegionAvail(ctx)

  local viewport_width =
    math.max(1, width - 4)

  local layout =
    column_layout(viewport_width)

  local list_width = layout.width

  local header_x, header_y =
    ImGui.GetCursorScreenPos(ctx)

  local draw_list =
    ImGui.GetWindowDrawList(ctx)

  local cursor_y =
    ImGui.GetCursorPosY(ctx)

  ImGui.SetCursorPosY(
    ctx,
    cursor_y + HEADER_H
  )

  local child_visible = ImGui.BeginChild(
    ctx,
    "results_scroll_area",
    width,
    math.max(1, height - HEADER_H),
    0,
    0
  )

  if state.results_scroll_request then
    ImGui.SetScrollX(
      ctx,
      clamp(
        state.results_scroll_request,
        0,
        ImGui.GetScrollMaxX(ctx)
      )
    )
    state.results_scroll_request = nil
  end

  if child_visible then
    state.results_scroll_x = ImGui.GetScrollX(ctx)
    state.results_scroll_max_x = ImGui.GetScrollMaxX(ctx)

    local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
    local child_hovered =
      mouse_x >= header_x
      and mouse_x <= header_x + viewport_width
      and mouse_y >= header_y
      and mouse_y <= header_y + height
    local wheel = ImGui.GetMouseWheel(ctx) or 0
    local mods = ImGui.GetKeyMods(ctx)

    if child_hovered
      and wheel ~= 0
      and (mods & ImGui.Mod_Shift) ~= 0 then
      state.results_scroll_request = clamp(
        state.results_scroll_x - wheel * 160,
        0,
        state.results_scroll_max_x
      )
    end

    if #state.results == 0 then
      ImGui.Spacing(ctx)

      local active_collection =
        state.active_collection_id
        and state.collection_by_id[
          state.active_collection_id
        ]
        or nil

      if active_collection then
        ImGui.TextColored(
          ctx,
          COLOR.text,
          "当前集合为空：" .. active_collection.name
        )

        ImGui.TextDisabled(
          ctx,
          "新建集合不会删除或移动原始音效库。返回全部素材后选择声音，"
            .. "再使用右键菜单或“加入所选”添加到集合。"
        )

        if dark_button("返回全部素材", 112) then
          state.active_collection_id = nil
          state.view = "all"
          state.results_dirty = true
          state.config_dirty = true
        end

        ImGui.SameLine(ctx)

        if dark_button("打开左侧导航", 112) then
          state.sidebar_visible = true
          state.config_dirty = true
        end
      else
        ImGui.TextDisabled(
          ctx,
          "没有结果。添加音效库、扫描或修改搜索词。"
        )
      end
    else
      local scroll_y = ImGui.GetScrollY(ctx)
      local visible_height =
        select(2, ImGui.GetContentRegionAvail(ctx))

      local first =
        math.max(
          1,
          math.floor(scroll_y / ROW_H) + 1
        )

      local last =
        math.min(
          #state.results,
          math.ceil(
            (scroll_y + visible_height) / ROW_H
          ) + 2
        )

      ImGui.Dummy(
        ctx,
        list_width,
        #state.results * ROW_H
      )

      for index = first, last do
        draw_result_row(
          state.results[index],
          index,
          list_width,
          layout
        )
      end

      ImGui.SetCursorPosY(
        ctx,
        #state.results * ROW_H
      )

      ImGui.Dummy(ctx, 0, 0)
    end

    state.results_scroll_x = ImGui.GetScrollX(ctx)
    state.results_scroll_max_x = ImGui.GetScrollMaxX(ctx)
  end

  ImGui.EndChild(ctx)

  -- Windows/macOS 文件管理器拖入文件夹。提示层只在拖动期间出现，
  -- 不占用日常结果列表空间。
  if ImGui.BeginDragDropTarget(ctx) then
    local payload_ok, payload_type = ImGui.GetDragDropPayload(ctx)
    local target_library_id = state.library_filter_id

    if state.root_filter then
      local record = root_record_for_path(state.root_filter)
      target_library_id = record and record.library_id or target_library_id
    end

    if payload_ok and payload_type == "FILES" then
      local target_library = target_library_id
        and state.library_by_id[target_library_id]
        or nil
      local box_w = math.min(460, viewport_width - 40)
      local box_h = 116
      local box_x = header_x + (viewport_width - box_w) * 0.5
      local box_y = header_y + (height - box_h) * 0.5
      local label = target_library
        and ("释放以添加到“" .. target_library.name .. "”")
        or "释放以新建逻辑音效库"

      ImGui.DrawList_AddRectFilled(
        draw_list,
        box_x,
        box_y,
        box_x + box_w,
        box_y + box_h,
        0x151A20F2,
        10
      )
      ImGui.DrawList_AddRect(
        draw_list,
        box_x,
        box_y,
        box_x + box_w,
        box_y + box_h,
        COLOR.accent,
        10,
        0,
        2
      )
      ImGui.DrawList_AddText(
        draw_list,
        box_x + 24,
        box_y + 28,
        COLOR.text,
        "+  " .. translate_ui_text(label)
      )
      ImGui.DrawList_AddText(
        draw_list,
        box_x + 24,
        box_y + 62,
        COLOR.muted,
        translate_ui_text("只建立索引，不移动或修改源文件")
      )
    end

    local folders = collect_folder_payload()
    ImGui.EndDragDropTarget(ctx)

    if folders then
      handle_folder_drop(folders, target_library_id)
    end
  end

  draw_list_header(
    draw_list,
    header_x - (state.results_scroll_x or 0),
    header_y,
    layout,
    header_x,
    header_x + viewport_width
  )

  -- draw_column_splitters() temporarily repositions the cursor so the fixed
  -- header can remain interactive after the scrolling child is rendered.
  -- ReaImGui requires a submitted layout item after SetCursorScreenPos;
  -- without it, the parent module asserts when EndChild() is called.
  ImGui.Dummy(ctx, 0, 0)
end

----------------------------------------------------------------
-- UI: bottom module
----------------------------------------------------------------

function draw_large_wave(asset)
  local width, available_height =
    ImGui.GetContentRegionAvail(ctx)

  local minimum_wave_height =
    available_height < 126 and 28
      or available_height < 168 and 40
      or available_height < 205 and 54
      or 72

  local height =
    clamp(
      available_height
        - bottom_controls_reserve_height(width, asset),
      minimum_wave_height,
      state.multichannel_waveform
        and (asset.channels or 1) > 2
        and 360
        or 280
    )

  local view_span = wave_view_span()
  local large_points

  if view_span < 0.55 then
    large_points = LARGE_WAVE_MAX_POINTS
  elseif width <= 900 then
    large_points = 1024
  elseif width <= 1550 then
    large_points = 2048
  else
    large_points = LARGE_WAVE_MAX_POINTS
  end

  local x, y =
    ImGui.GetCursorScreenPos(ctx)

  ImGui.InvisibleButton(
    ctx,
    "large_wave",
    width,
    height
  )

  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)
  local selection_handle_hovered = false
  local draw_list =
    ImGui.GetWindowDrawList(ctx)

  local waveform =
    queue_wave(
      asset,
      large_points,
      true,
      state.multichannel_waveform,
      state.spectral_peaks_enabled
    )

  if not waveform and state.spectral_peaks_enabled then
    waveform = queue_wave(
      asset,
      large_points,
      true,
      state.multichannel_waveform,
      false
    )
  end

  draw_waveform_window(
    draw_list,
    waveform,
    asset,
    x,
    y,
    width,
    height,
    COLOR.waveform,
    state.wave_view_start,
    state.wave_view_end
  )

  draw_wave_time_ruler(
    draw_list,
    asset,
    x,
    y,
    width,
    height
  )

  local saved_regions = asset_regions(asset)

  for index, region in ipairs(saved_regions) do
    local visible_start =
      math.max(region.start, state.wave_view_start)

    local visible_end =
      math.min(region.finish, state.wave_view_end)

    if visible_end > visible_start then
      local start_x =
        x + width * wave_view_percent(visible_start)

      local end_x =
        x + width * wave_view_percent(visible_end)

      local active_region =
        index == state.active_region_index

      ImGui.DrawList_AddRectFilled(
        draw_list,
        start_x,
        y + 18,
        end_x,
        y + height,
        rgba_with_alpha(
          COLOR.region,
          active_region and 0x40 or 0x20
        )
      )

      ImGui.DrawList_AddLine(
        draw_list,
        start_x,
        y + 18,
        end_x,
        y + 18,
        COLOR.region,
        active_region and 2 or 1
      )
    end
  end

  if has_selection() then
    local visible_start = math.max(
      state.region_start,
      state.wave_view_start
    )
    local visible_end = math.min(
      state.region_end,
      state.wave_view_end
    )

    if visible_end > visible_start then
      local start_x =
        x + width * wave_view_percent(visible_start)
      local end_x =
        x + width * wave_view_percent(visible_end)

      ImGui.DrawList_AddRectFilled(
        draw_list,
        start_x,
        y,
        end_x,
        y + height,
        COLOR.selection
      )

      ImGui.DrawList_AddLine(
        draw_list,
        start_x,
        y,
        start_x,
        y + height,
        COLOR.border,
        2
      )

      ImGui.DrawList_AddLine(
        draw_list,
        end_x,
        y,
        end_x,
        y + height,
        COLOR.border,
        2
      )
    end
  end


  if has_selection() then
    local visible_start =
      math.max(
        state.region_start,
        state.wave_view_start
      )

    local visible_end =
      math.min(
        state.region_end,
        state.wave_view_end
      )

    if visible_end > visible_start then
      local start_x =
        x + width * wave_view_percent(visible_start)

      local end_x =
        x + width * wave_view_percent(visible_end)

      local handle_width =
        clamp(end_x - start_x - 12, 96, 146)

      local handle_height = 24
      local handle_x =
        clamp(
          (start_x + end_x - handle_width) * 0.5,
          x + 6,
          x + width - handle_width - 6
        )

      local handle_y = y + 22
      local mouse_x, mouse_y =
        ImGui.GetMousePos(ctx)

      selection_handle_hovered =
        mouse_x >= handle_x
        and mouse_x <= handle_x + handle_width
        and mouse_y >= handle_y
        and mouse_y <= handle_y + handle_height

      ImGui.DrawList_AddRectFilled(
        draw_list,
        handle_x,
        handle_y,
        handle_x + handle_width,
        handle_y + handle_height,
        selection_handle_hovered
          and COLOR.button_hover
          or COLOR.panel_alt,
        6
      )

      ImGui.DrawList_AddRect(
        draw_list,
        handle_x,
        handle_y,
        handle_x + handle_width,
        handle_y + handle_height,
        COLOR.border,
        6,
        0,
        selection_handle_hovered and 2 or 1
      )

      ImGui.DrawList_AddLine(
        draw_list,
        handle_x + 9,
        handle_y + 12,
        handle_x + 18,
        handle_y + 12,
        COLOR.header_text,
        2
      )

      ImGui.DrawList_AddLine(
        draw_list,
        handle_x + 14,
        handle_y + 7,
        handle_x + 19,
        handle_y + 12,
        COLOR.header_text,
        2
      )

      ImGui.DrawList_AddLine(
        draw_list,
        handle_x + 14,
        handle_y + 17,
        handle_x + 19,
        handle_y + 12,
        COLOR.header_text,
        2
      )

      ImGui.DrawList_AddText(
        draw_list,
        handle_x + 25,
        handle_y + 5,
        COLOR.header_text,
        "拖出选区"
      )

      if selection_handle_hovered
        and ImGui.IsMouseClicked(ctx, 0) then
        state.selection_drag_handle_pressed = true
        state.wave_drag_start = nil
        mark_interaction()
      end
    end
  end

  if state.selection_drag_handle_pressed
    and ImGui.IsMouseDragging(ctx, 0, 4)
    and not state.external_drag then
    begin_external_drag(asset, true)
  end

  if not ImGui.IsMouseDown(ctx, 0) then
    state.selection_drag_handle_pressed = false
  end

  if state.preview
    and state.preview_path
    and path_key(state.preview_path)
      == path_key(asset.path)
    and state.preview_length > 0
    and state.preview_percent >= state.wave_view_start
    and state.preview_percent <= state.wave_view_end then

    local view_percent =
      wave_view_percent(state.preview_percent)

    ImGui.DrawList_AddLine(
      draw_list,
      x + width * view_percent,
      y,
      x + width * view_percent,
      y + height,
      COLOR.playhead,
      2
    )
  end

  if hovered then
    local mouse_x =
      select(1, ImGui.GetMousePos(ctx))
    local local_percent =
      clamp((mouse_x - x) / width, 0, 1)
    local wheel = ImGui.GetMouseWheel(ctx)
    local mods = ImGui.GetKeyMods(ctx)
    local shift =
      (mods & ImGui.Mod_Shift) ~= 0

    if wheel ~= 0 then
      mark_interaction()

      if shift then
        pan_wave_view(
          -wheel * wave_view_span() * 0.10
        )
      else
        zoom_wave_view(local_percent, wheel)
      end
    end

    if ImGui.IsMouseDoubleClicked(ctx, 0) then
      reset_wave_view()
      state.wave_drag_start = nil
    end

    if state.wave_scrub_enabled
      and ImGui.IsMouseDown(ctx, 1) then
      local now = reaper.time_precise()

      if now - state.wave_scrub_last_at >= 0.09 then
        state.wave_scrub_last_at = now
        play_preview(
          asset,
          wave_source_percent(local_percent),
          false
        )
      end
    end
  end

  if hovered
    and ImGui.IsMouseDragging(ctx, 2) then
    local mouse_x =
      select(1, ImGui.GetMousePos(ctx))

    if state.wave_pan_last_x then
      local delta =
        -(mouse_x - state.wave_pan_last_x)
        / math.max(width, 1)
        * wave_view_span()

      pan_wave_view(delta)
    end

    state.wave_pan_last_x = mouse_x
    mark_interaction()
  elseif not ImGui.IsMouseDown(ctx, 2) then
    state.wave_pan_last_x = nil
  end

  if hovered
    and not selection_handle_hovered
    and not state.selection_drag_handle_pressed
    and ImGui.IsMouseClicked(ctx, 0)
    and not ImGui.IsMouseDoubleClicked(ctx, 0) then

    mark_interaction()

    local mods = ImGui.GetKeyMods(ctx)
    local alt =
      (mods & ImGui.Mod_Alt) ~= 0

    if alt then
      state.wave_drag_start = nil
    else
      local mouse_x =
        select(1, ImGui.GetMousePos(ctx))
      local percent = wave_source_percent(
        clamp((mouse_x - x) / width, 0, 1)
      )

      state.wave_drag_start = percent
      state.region_start = percent
      state.region_end = percent
    end
  end

  if active
    and not state.selection_drag_handle_pressed
    and ImGui.IsMouseDragging(ctx, 0) then

    mark_interaction()

    local mods = ImGui.GetKeyMods(ctx)
    local alt =
      (mods & ImGui.Mod_Alt) ~= 0

    if alt then
      if not state.external_drag then
        begin_external_drag(asset, true)
      end

      state.wave_drag_start = nil
    else
      local mouse_x =
        select(1, ImGui.GetMousePos(ctx))
      local percent = wave_source_percent(
        clamp((mouse_x - x) / width, 0, 1)
      )

      state.region_start =
        math.min(
          state.wave_drag_start or percent,
          percent
        )

      state.region_end =
        math.max(
          state.wave_drag_start or percent,
          percent
        )
    end
  end

  if state.wave_drag_start
    and not state.external_drag
    and ImGui.IsMouseReleased(ctx, 0) then

    local clicked_percent =
      state.wave_drag_start

    if state.region_end - state.region_start
      < 0.004 then

      state.region_start = 0
      state.region_end = 1
      play_preview(
        asset,
        clicked_percent,
        false
      )
    else
      if state.loop_selection then
        state.loop = true
        update_preview_parameters()
      end

      play_preview(asset, nil, true)
    end

    state.wave_drag_start = nil
  end
end

function draw_preview_presets_popup()
  if not ImGui.BeginPopup(
    ctx,
    "试听预设##preview_presets"
  ) then
    return
  end

  ImGui.Text(ctx, "音高预设")

  for index, value in ipairs(
    {
      -12,
      -6,
      -3,
      0,
      3,
      6,
      12,
    }
  ) do
    if dark_button(
      string.format("%+d", value),
      46
    ) then
      state.pitch = value
      update_preview_parameters()
    end

    if index < 7 then
      ImGui.SameLine(ctx)
    end
  end

  ImGui.Separator(ctx)
  ImGui.Text(ctx, "速度预设")

  for index, value in ipairs(
    {
      0.50,
      0.75,
      1.00,
      1.25,
      1.50,
      2.00,
    }
  ) do
    if dark_button(
      string.format("%.2fx", value),
      56
    ) then
      state.rate = value
      update_preview_parameters()
    end

    if index < 6 then
      ImGui.SameLine(ctx)
    end
  end

  ImGui.EndPopup(ctx)
end

function draw_inline_channel_selector(asset, button_size)
  local selected, channel_count =
    ensure_preview_channel_selection(asset)

  if channel_count <= 2
    or not state.preview_channel_strip_expanded then
    return
  end

  button_size = button_size or UI_METRIC.icon_button
  local available_width =
    select(1, ImGui.GetContentRegionAvail(ctx))
  local channel_button_width =
    clamp(
      (
        available_width
          - 48
          - 72
          - 58
          - (channel_count + 2) * 5
      ) / channel_count,
      34,
      51
    )

  local start_x, start_y =
    ImGui.GetCursorScreenPos(ctx)
  local mods = ImGui.GetKeyMods(ctx)
  local ctrl = (mods & ImGui.Mod_Ctrl) ~= 0
  local shift = (mods & ImGui.Mod_Shift) ~= 0
  local selected_total =
    selected_preview_channel_count(asset)

  ImGui.TextDisabled(
    ctx,
    translate_ui_text("声道条")
  )
  ImGui.SameLine(ctx, 0, 9)

  local all_selected = selected_total == channel_count

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Button,
    all_selected
      and rgba_with_alpha(COLOR.accent, 0x48)
      or rgba_with_alpha(COLOR.button, 0x74)
  )
  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_ButtonHovered,
    all_selected
      and rgba_with_alpha(COLOR.accent, 0x58)
      or rgba_with_alpha(COLOR.accent, 0x20)
  )

  if ImGui.Button(
    ctx,
    translate_ui_text("全部声道")
      .. "##inline_channel_all",
    72,
    button_size
  ) then
    select_all_preview_channels(asset)
  end

  ImGui.PopStyleColor(ctx, 2)

  for channel = 1, channel_count do
    ImGui.SameLine(ctx, 0, 5)

    local is_selected = selected[channel] == true

    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_Button,
      is_selected
        and rgba_with_alpha(COLOR.accent, 0x40)
        or rgba_with_alpha(COLOR.button, 0x74)
    )
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_ButtonHovered,
      rgba_with_alpha(COLOR.accent, 0x56)
    )

    local button_label =
      channel_button_width < 42
        and tostring(channel)
        or preview_channel_label(
          channel,
          channel_count
        )

    local clicked =
      ImGui.Button(
        ctx,
        button_label
          .. "##inline_preview_channel_"
          .. tostring(channel),
        channel_button_width,
        button_size
      )

    local hovered = ImGui.IsItemHovered(ctx)

    ImGui.PopStyleColor(ctx, 2)

    if clicked then
      apply_preview_channel_selection(
        asset,
        channel,
        ctrl,
        shift,
        false
      )
    elseif hovered
      and ImGui.IsMouseClicked(ctx, 1) then
      apply_preview_channel_selection(
        asset,
        channel,
        false,
        false,
        true
      )
      set_status(
        preview_channel_label(
          channel,
          channel_count
        )
          .. " · "
          .. translate_ui_text(
            "已聚焦声道波形；音频仍遵循 REAPER 多声道设备路由"
          )
      )
    end

    if hovered then
      tooltip(
        translate_ui_text(
          "右键聚焦此声道波形"
        )
      )
    end
  end

  ImGui.SameLine(ctx, 0, 9)
  ImGui.TextDisabled(
    ctx,
    string.format(
      "%d / %d",
      selected_preview_channel_count(asset),
      channel_count
    )
  )

  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local rail_hovered =
    mouse_x >= start_x
      and mouse_x <= start_x + available_width
      and mouse_y >= start_y
      and mouse_y <= start_y + button_size + 4

  if rail_hovered
    and ctrl
    and ImGui.IsKeyPressed(
      ctx,
      ImGui.Key_A,
      false
    ) then
    select_all_preview_channels(asset)
    state.keyboard_consumed = true
  end
end

function draw_regions_popup(asset)
  if not ImGui.BeginPopup(
    ctx,
    "Region 列表##saved_regions"
  ) then
    return
  end

  local regions = asset_regions(asset)

  if #regions == 0 then
    ImGui.TextDisabled(ctx, "没有保存的 Region")
  end

  local delete_index = nil

  for index, region in ipairs(regions) do
    ImGui.PushID(ctx, index)

    local source_label =
      region.source == "transient"
      and "[T] "
      or "[M] "

    if ImGui.Selectable(
      ctx,
      source_label
        .. region.name
        .. string.format(
          "  %.3f–%.3f s",
          region.start * (asset.duration or 0),
          region.finish * (asset.duration or 0)
        ),
      index == state.active_region_index
    ) then
      activate_saved_region(asset, index, true)
    end

    if ImGui.BeginPopupContextItem(
      ctx,
      "region_context"
    ) then
      if ImGui.MenuItem(ctx, "删除 Region") then
        delete_index = index
      end

      ImGui.EndPopup(ctx)
    end

    ImGui.PopID(ctx)
  end

  if delete_index then
    delete_saved_region(asset, delete_index)
  end

  ImGui.Separator(ctx)

  if ImGui.MenuItem(ctx, "保存当前选区为 Region") then
    save_current_selection_as_region(asset)
  end

  if ImGui.MenuItem(ctx, "瞬态检测设置…") then
    open_transient_detection_popup(asset)
  end

  if ImGui.MenuItem(ctx, "撤销上次检测") then
    undo_last_transient_detection(asset)
  end

  if ImGui.MenuItem(ctx, "清除全部瞬态建议") then
    clear_all_transient_suggestions(asset)
  end

  ImGui.EndPopup(ctx)
end


local TRANSIENT_POPUP_ID =
  "瞬态检测设置##transient_detection"

function draw_transient_detection_popup()
  if state.transient_popup_requested > 0 then
    state.transient_popup_requested =
      state.transient_popup_requested - 1

    if state.transient_popup_requested == 0 then
      ImGui.OpenPopup(ctx, TRANSIENT_POPUP_ID)
    end
  end

  ImGui.SetNextWindowSize(
    ctx,
    520,
    0,
    ImGui.Cond_Appearing
  )

  if not ImGui.BeginPopupModal(
    ctx,
    TRANSIENT_POPUP_ID,
    true,
    ImGui.WindowFlags_AlwaysAutoResize
  ) then
    return
  end

  local asset =
    state.transient_popup_asset_path
    and state.by_path[
      path_key(state.transient_popup_asset_path)
    ]
    or selected_asset()

  ImGui.TextColored(
    ctx,
    COLOR.selected_text,
    asset and asset.name or "瞬态检测"
  )

  ImGui.Separator(ctx)

  local threshold_db =
    20 * math.log(
      math.max(
        state.transient_threshold,
        0.000001
      ),
      10
    )

  ImGui.SetNextItemWidth(ctx, 300)
  local changed
  changed, threshold_db =
    ImGui.SliderDouble(
      ctx,
      "阈值",
      threshold_db,
      -60,
      -1,
      "%.1f dBFS"
    )

  if changed then
    state.transient_threshold =
      10 ^ (threshold_db / 20)
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 300)
  changed, state.transient_smoothing_ms =
    ImGui.SliderDouble(
      ctx,
      "平滑时间",
      state.transient_smoothing_ms,
      0,
      80,
      "%.0f ms"
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 300)
  changed, state.transient_min_gap_ms =
    ImGui.SliderDouble(
      ctx,
      "最小间隔",
      state.transient_min_gap_ms,
      20,
      2000,
      "%.0f ms"
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 300)
  changed, state.transient_pre_ms =
    ImGui.SliderDouble(
      ctx,
      "Region 前置",
      state.transient_pre_ms,
      0,
      1000,
      "%.0f ms"
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 300)
  changed, state.transient_post_ms =
    ImGui.SliderDouble(
      ctx,
      "Region 后置",
      state.transient_post_ms,
      20,
      5000,
      "%.0f ms"
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 300)
  changed, state.transient_max_regions =
    ImGui.SliderDouble(
      ctx,
      "最大 Region 数",
      state.transient_max_regions,
      1,
      256,
      "%.0f"
    )

  if changed then
    state.transient_max_regions =
      math.floor(state.transient_max_regions + 0.5)
    state.config_dirty = true
  end

  changed, state.transient_replace_existing =
    ImGui.Checkbox(
      ctx,
      "替换已有瞬态建议",
      state.transient_replace_existing
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.TextDisabled(
    ctx,
    "阈值越低越敏感；平滑可抑制细碎尖峰；手动 Region 不会被替换。"
  )

  ImGui.Separator(ctx)

  if dark_button("开始检测", 110) and asset then
    request_transient_detection(asset)
    ImGui.CloseCurrentPopup(ctx)
  end

  ImGui.SameLine(ctx)

  if dark_button("取消待检测", 110) then
    cancel_pending_transient_detection()
  end

  ImGui.SameLine(ctx)

  if dark_button("撤销上次检测", 120) and asset then
    undo_last_transient_detection(asset)
  end

  ImGui.SameLine(ctx)

  if dark_button("清除全部瞬态建议", 150) and asset then
    clear_all_transient_suggestions(asset)
  end

  ImGui.Spacing(ctx)

  if dark_button("关闭", 90) then
    ImGui.CloseCurrentPopup(ctx)
  end

  ImGui.EndPopup(ctx)
end

function draw_more_actions_popup(asset)
  if not ImGui.BeginPopup(
    ctx,
    "更多操作##preview_more_actions"
  ) then
    return
  end

  if ImGui.MenuItem(ctx, "按 BWF 时间戳插入") then
    insert_asset(asset, false, true)
  end

  if ImGui.MenuItem(ctx, "在资源管理器中显示") then
    reveal_file(asset.path)
  end

  if ImGui.MenuItem(ctx, "重置波形缩放") then
    reset_wave_view()
  end

  if ImGui.MenuItem(ctx, "预览参数预设") then
    ImGui.OpenPopup(ctx, "试听预设##preview_presets")
  end

  ImGui.Separator(ctx)

  if ImGui.MenuItem(
    ctx,
    "保留音高",
    nil,
    state.preserve_pitch
  ) then
    state.preserve_pitch = not state.preserve_pitch
    update_preview_parameters()
  end

  if ImGui.MenuItem(
    ctx,
    "自动循环选区",
    nil,
    state.loop_selection
  ) then
    state.loop_selection = not state.loop_selection
    state.config_dirty = true
  end

  if ImGui.MenuItem(
    ctx,
    "频谱峰值着色",
    nil,
    state.spectral_peaks_enabled
  ) then
    AppState.set(
      "spectral_peaks_enabled",
      not state.spectral_peaks_enabled
    )
    AppState.mark_dirty("config_dirty")
  end

  if ImGui.MenuItem(
    ctx,
    "估算响度匹配",
    nil,
    state.loudness_match
  ) then
    state.loudness_match = not state.loudness_match
    state.config_dirty = true
    update_preview_parameters()
  end

  if ImGui.MenuItem(
    ctx,
    "循环试听",
    nil,
    state.loop
  ) then
    state.loop = not state.loop
    update_preview_parameters()
  end

  if ImGui.MenuItem(
    ctx,
    "反向试听",
    nil,
    state.reverse
  ) then
    state.reverse = not state.reverse

    if state.preview then
      play_preview(asset, nil, has_selection())
    end
  end

  ImGui.Separator(ctx)

  if ImGui.MenuItem(ctx, "保存当前选区为 Region") then
    save_current_selection_as_region(asset)
  end

  if ImGui.MenuItem(ctx, "瞬态检测设置…") then
    open_transient_detection_popup(asset)
  end

  if ImGui.MenuItem(ctx, "撤销上次检测") then
    undo_last_transient_detection(asset)
  end

  if ImGui.MenuItem(ctx, "清除全部瞬态建议") then
    clear_all_transient_suggestions(asset)
  end

  ImGui.Separator(ctx)

  if ImGui.MenuItem(ctx, "重新分析当前素材响度") then
    request_loudness_analysis(asset, true)
  end

  ImGui.EndPopup(ctx)
end

function draw_action_strip(asset, minimal, button_size)
  button_size = button_size or UI_METRIC.icon_button
  local button_gap = math.max(3, math.floor(button_size * 0.18))

  local _, _, drag_active =
    icon_button(
      "drag_to_reaper",
      "drag",
      "拖拽到 REAPER 编排区",
      state.external_drag ~= nil,
      button_size
    )

  if drag_active
    and ImGui.IsMouseDragging(ctx, 0, 5)
    and not state.external_drag then
    begin_external_drag(asset, true)
  end

  ImGui.SameLine(ctx, 0, button_gap)

  if icon_button(
    "play_stop",
    state.preview and "stop" or "play",
    "播放或停止",
    state.preview ~= nil,
    button_size
  ) then
    if state.preview then
      request_preview_stop()
    else
      play_preview(asset, nil, true)
    end
  end

  ImGui.SameLine(ctx, 0, button_gap)

  if icon_button(
    "insert_current",
    "insert",
    "插入当前轨道",
    false,
    button_size
  ) then
    insert_asset(asset, false, false)
  end

  ImGui.SameLine(ctx, 0, button_gap)

  if icon_button(
    "transfer_export",
    "transfer",
    "打开 Transfer 面板",
    state.transfer_running,
    button_size
  ) then
    state.transfer_popup_requested = 2
  end

  if not minimal then
    ImGui.SameLine(ctx, 0, button_gap)

    if icon_button(
      "insert_new_track",
      "new_track",
      "插入新轨道",
      false,
      button_size
    ) then
      insert_asset(asset, true, false)
    end

    ImGui.SameLine(ctx, 0, button_gap)
    toolbar_separator(button_size)
    ImGui.SameLine(ctx, 0, button_gap)

    if icon_button(
      "favorite",
      "star",
      "收藏或取消收藏",
      state.favorites[path_key(asset.path)] == true,
      button_size
    ) then
      toggle_favorite(asset)
    end

    ImGui.SameLine(ctx, 0, button_gap)

    if icon_button(
      "clear_selection",
      "clear_selection",
      "清除选区",
      has_selection(),
      button_size
    ) then
      state.region_start = 0
      state.region_end = 1
      state.active_region_index = 0
    end

    ImGui.SameLine(ctx, 0, button_gap)

    if icon_button(
      "regions",
      "regions",
      "Region 列表",
      #asset_regions(asset) > 0,
      button_size
    ) then
      ImGui.OpenPopup(ctx, "Region 列表##saved_regions")
    end

  end

  ImGui.SameLine(ctx, 0, button_gap)

  if icon_button(
    "more_actions",
    "more",
    "更多操作",
    false,
    button_size
  ) then
    ImGui.OpenPopup(
      ctx,
      "更多操作##preview_more_actions"
    )
  end

  draw_more_actions_popup(asset)
  draw_preview_presets_popup()
  draw_regions_popup(asset)
end

function draw_preview_toggle_icons(asset, button_size)
  button_size = button_size or UI_METRIC.icon_button
  local button_gap = math.max(3, math.floor(button_size * 0.18))

  if icon_button(
    "preserve_pitch",
    "clock",
    "保留音高",
    state.preserve_pitch,
    button_size
  ) then
    state.preserve_pitch = not state.preserve_pitch
    update_preview_parameters()
  end

  ImGui.SameLine(ctx, 0, button_gap)

  if icon_button(
    "loop_selection",
    "loop",
    "自动循环选区",
    state.loop_selection,
    button_size
  ) then
    state.loop_selection = not state.loop_selection
    state.config_dirty = true
  end

  ImGui.SameLine(ctx, 0, button_gap)

  if icon_button(
    "loudness_match",
    "loudness",
    "估算响度匹配",
    state.loudness_match,
    button_size
  ) then
    state.loudness_match = not state.loudness_match
    state.config_dirty = true
    update_preview_parameters()
  end

  ImGui.SameLine(ctx, 0, button_gap)

  local channel_count =
    preview_asset_channel_count(asset)
  local channel_icon =
    channel_count > 2
      and "channel_multi"
      or state.preview_channel_mode == "left"
        and "channel_left"
        or state.preview_channel_mode == "right"
          and "channel_right"
          or state.preview_channel_mode == "mono"
            and "channel_mono"
            or "channel_stereo"
  local channel_tooltip =
    channel_count > 2
      and "左键展开或收起声道条；右键恢复全部声道"
      or "左键切换监听模式；右键恢复立体声"
  local channel_clicked, channel_hovered =
    icon_button(
    "channel_mode",
    channel_icon,
    channel_tooltip,
    state.preview_channel_mode ~= "original",
    button_size
  )

  if channel_clicked then
    if channel_count > 2 then
      state.preview_channel_strip_expanded =
        not state.preview_channel_strip_expanded
    else
      cycle_preview_channel_mode(asset)
    end
  end

  if channel_hovered
    and ImGui.IsMouseClicked(ctx, 1) then
    if channel_count > 2 then
      select_all_preview_channels(asset)
    else
      state.preview_channel_mode = "original"
      state.config_dirty = true

      if state.preview then
        update_preview_parameters()
      end
    end
  end

  ImGui.SameLine(ctx, 0, button_gap)

  if icon_button(
    "loop_preview",
    "loop",
    "循环试听",
    state.loop,
    button_size
  ) then
    state.loop = not state.loop
    update_preview_parameters()
  end

  ImGui.SameLine(ctx, 0, button_gap)

  if icon_button(
    "reverse_preview",
    "reverse",
    "反向试听",
    state.reverse,
    button_size
  ) then
    state.reverse = not state.reverse

    if state.preview then
      play_preview(asset, nil, has_selection())
    end
  end

end

function draw_preview_controls(asset, available_width, hide_toggles, force_compact)
  local compact = force_compact == true

  local classic = false

  local toggle_width =
    UI_METRIC.icon_button * 6
      + UI_METRIC.icon_gap * 5

  local card_gap = compact and 5 or 7
  local card_space =
    math.max(
      UI_METRIC.parameter_min_w * 3,
      available_width - toggle_width - 18
    )

  local card_width =
    clamp(
      (card_space - card_gap * 2) / 3,
      compact and 96 or UI_METRIC.parameter_min_w,
      classic and 156 or UI_METRIC.parameter_max_w
    )

  if classic then
    card_width =
      clamp(
        card_width + 12,
        120,
        160
      )
  end

  local new_pitch, pitch_changed =
    draw_parameter_card(
      "pitch",
      "Pitch",
      state.pitch,
      -24,
      24,
      0,
      "%+.1f st",
      card_width,
      UI_METRIC.parameter_h
    )

  if pitch_changed then
    state.pitch = new_pitch
    update_preview_parameters()
  end

  ImGui.SameLine(ctx, 0, card_gap)

  local new_rate, rate_changed =
    draw_parameter_card(
      "rate",
      "Rate",
      state.rate,
      0.25,
      4,
      1,
      "%.2fx",
      card_width,
      UI_METRIC.parameter_h
    )

  if rate_changed then
    state.rate = new_rate
    update_preview_parameters()
  end

  ImGui.SameLine(ctx, 0, card_gap)

  local new_gain, gain_changed =
    draw_parameter_card(
      "gain",
      "Gain",
      state.gain_db,
      -36,
      18,
      0,
      "%+.1f dB",
      card_width,
      UI_METRIC.parameter_h
    )

  if gain_changed then
    state.gain_db = new_gain
    update_preview_parameters()
  end

  local used_width =
    card_width * 3 + card_gap * 2

  if not hide_toggles then
    if available_width
        - used_width
        >= toggle_width + 12 then
      ImGui.SameLine(ctx, 0, 12)
      draw_preview_toggle_icons(asset)
    else
      ImGui.Spacing(ctx)
      draw_preview_toggle_icons(asset)
    end
  end
end

function preview_context_summary(asset)
  local selection_text = translate_ui_text("完整文件")

  if has_selection() and asset.duration > 0 then
    local start_sec = asset.duration * state.region_start
    local end_sec = asset.duration * state.region_end

    selection_text = string.format(
      "%.3f–%.3f s",
      start_sec,
      end_sec
    )
  end

  local channel_count =
    preview_asset_channel_count(asset)
  local channel_text

  if channel_count > 2
    and state.preview_channel_mode == "custom" then
    local selected =
      ensure_preview_channel_selection(asset)
    local labels = {}

    for channel = 1, channel_count do
      if selected[channel] then
        labels[#labels + 1] =
          preview_channel_label(
            channel,
            channel_count
          )
      end
    end

    channel_text = table.concat(labels, "+")
  else
    channel_text = translate_ui_text(
      state.preview_channel_mode == "left"
        and "左声道"
        or state.preview_channel_mode == "right"
          and "右声道"
          or state.preview_channel_mode == "mono"
            and "单声道"
            or channel_count > 2
              and "全部声道"
              or channel_count == 2
                and "立体声"
                or "原始"
    )
  end

  local match_text =
    state.loudness_match
      and string.format(
        "Match %+.1f dB",
        state.preview_match_offset_db
      )
      or "Match Off"

  return selection_text
    .. string.format(
      "  ·  R %d  ·  %s  ·  %s",
      #asset_regions(asset),
      channel_text,
      match_text
    )
end

function draw_time_metrics(asset)
  local current_seconds = 0

  if state.preview_path
    and path_key(state.preview_path) == path_key(asset.path) then
    current_seconds =
      (asset.duration or 0)
        * (state.preview_percent or 0)
  end

  local in_seconds =
    (asset.duration or 0) * state.region_start

  local out_seconds =
    (asset.duration or 0) * state.region_end

  metric_chip(
    "Current",
    format_time(current_seconds),
    true
  )

  ImGui.SameLine(ctx, 0, 6)
  metric_chip("In", format_time(in_seconds), false)

  ImGui.SameLine(ctx, 0, 6)
  metric_chip("Out", format_time(out_seconds), false)

  ImGui.SameLine(ctx, 0, 6)
  metric_chip(
    "Duration",
    format_time(asset.duration or 0),
    false
  )

  ImGui.SameLine(ctx, 0, 6)
  metric_chip(
    "Zoom",
    string.format("×%.1f", 1 / wave_view_span()),
    false
  )

  ImGui.SameLine(ctx, 0, 10)

  local remaining_width =
    select(1, ImGui.GetContentRegionAvail(ctx))

  local summary_drawn = false

  if remaining_width > 190 then
    local summary_width =
      math.min(
        remaining_width * 0.38,
        280
      )

    inline_metric_text(
      preview_context_summary(asset),
      COLOR.dim,
      summary_width
    )

    summary_drawn = true
  end

  local status_text = tostring(state.status or "")

  local preview_start_percent =
    status_text:match(
      "^从 ([%d%.]+)%% 开始试听[:：].+$"
    ) or status_text:match(
      "^Previewing from ([%d%.]+)%%[:：].+$"
    )

  if preview_start_percent then
    status_text =
      state.language == "en"
        and string.format(
          "Previewing from %s%%",
          preview_start_percent
        )
        or string.format(
          "从 %s%% 开始试听",
          preview_start_percent
        )
  end

  if state.layout_notice and state.layout_notice ~= "" then
    status_text =
      status_text ~= ""
        and (status_text .. "  ·  " .. state.layout_notice)
        or state.layout_notice
  end

  if status_text ~= "" then
    if summary_drawn then
      ImGui.SameLine(ctx, 0, 12)
    end

    remaining_width =
      select(1, ImGui.GetContentRegionAvail(ctx))

    if remaining_width > 90 then
      inline_metric_text(
        status_text,
        state.status_error and COLOR.error or COLOR.success,
        math.max(70, remaining_width - 8)
      )
    end
  end
end

function draw_studio_parameters(asset, card_width, card_height)
  local new_pitch, pitch_changed =
    draw_parameter_card(
      "pitch_strip",
      "Pitch",
      state.pitch,
      -24,
      24,
      0,
      "%+.1f st",
      card_width,
      card_height
    )

  if pitch_changed then
    state.pitch = new_pitch
    update_preview_parameters()
  end

  ImGui.SameLine(ctx, 0, 10)

  local new_rate, rate_changed =
    draw_parameter_card(
      "rate_strip",
      "Rate",
      state.rate,
      0.25,
      4,
      1,
      "%.2fx",
      card_width,
      card_height
    )

  if rate_changed then
    state.rate = new_rate
    update_preview_parameters()
  end

  ImGui.SameLine(ctx, 0, 10)

  local new_gain, gain_changed =
    draw_parameter_card(
      "gain_strip",
      "Gain",
      state.gain_db,
      -36,
      18,
      0,
      "%+.1f dB",
      card_width,
      card_height
    )

  if gain_changed then
    state.gain_db = new_gain
    update_preview_parameters()
  end
end

function preview_control_layout_metrics(width)
  local mode = state.preview_control_layout
  local minimal = mode == "minimal_rack"
  local focused = mode == "focus_rack"
  local button_size =
    state.ui_density == "compact" and 28
      or state.ui_density == "comfortable" and 32
      or 30
  local button_gap =
    math.max(
      3,
      math.floor(button_size * 0.18)
    )
  local action_width =
    button_size * (minimal and 5 or 9)
      + button_gap * (minimal and 4 or 10)
      + (minimal and 0 or 7)
  local toggle_width =
    button_size * 6
      + button_gap * 5
  local parameter_min_width =
    UI_METRIC.parameter_min_w * 3 + 20
  local separator_width = 27
  local all_inline_min_width =
    action_width
      + parameter_min_width
      + toggle_width
      + separator_width * 2
      + 12
  local two_rows =
    not minimal
      and width
        < action_width
          + parameter_min_width
          + separator_width
  local toggles_visible =
    not minimal and not focused
  local toggles_inline =
    toggles_visible
      and not two_rows
      and width >= all_inline_min_width
  local row_count =
    minimal and 1
      or two_rows and 2
      or 1

  if toggles_visible and not toggles_inline then
    row_count = row_count + 1
  end

  return {
    minimal = minimal,
    focused = focused,
    button_size = button_size,
    button_gap = button_gap,
    action_width = action_width,
    toggle_width = toggle_width,
    separator_width = separator_width,
    two_rows = two_rows,
    toggles_visible = toggles_visible,
    toggles_inline = toggles_inline,
    row_count = row_count,
    panel_height =
      row_count * button_size
        + math.max(0, row_count - 1) * 8
        + 4,
  }
end

function draw_control_deck(asset)
  local width = select(1, ImGui.GetContentRegionAvail(ctx))
  local layout =
    preview_control_layout_metrics(width)
  local minimal = layout.minimal
  local button_size = layout.button_size
  local two_rows = layout.two_rows
  local show_channel_rail =
    preview_asset_channel_count(asset) > 2
      and state.preview_channel_strip_expanded
  local panel_height = layout.panel_height

  if show_channel_rail then
    panel_height =
      panel_height + button_size + 10
  end

  ImGui.PushStyleVar(
    ctx,
    ImGui.StyleVar_WindowPadding,
    2,
    2
  )
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, COLOR.window)

  local strip_visible = ImGui.BeginChild(
    ctx,
    "preview_studio_strip",
    width,
    panel_height,
    0,
    ImGui.WindowFlags_NoScrollbar
      | ImGui.WindowFlags_NoScrollWithMouse
  )

  if strip_visible then
    draw_action_strip(asset, minimal, button_size)

    if not minimal then
      if two_rows then
        ImGui.Spacing(ctx)
      else
        ImGui.SameLine(ctx, 0, 10)
        toolbar_separator(button_size)
        ImGui.SameLine(ctx, 0, 10)
      end

      local card_width =
        clamp(
          (
            width
              - (
                two_rows
                  and 20
                  or layout.action_width
                    + layout.separator_width
                    + (
                      layout.toggles_inline
                        and layout.toggle_width
                          + layout.separator_width
                        or 0
                    )
              )
              - 20
          ) / 3,
          UI_METRIC.parameter_min_w,
          150
        )

      draw_studio_parameters(
        asset,
        card_width,
        button_size
      )

      if layout.toggles_inline then
        ImGui.SameLine(ctx, 0, 10)
        toolbar_separator(button_size)
        ImGui.SameLine(ctx, 0, 10)
        draw_preview_toggle_icons(asset, button_size)
      elseif layout.toggles_visible then
        ImGui.Spacing(ctx)
        draw_preview_toggle_icons(asset, button_size)
      end
    end

    if show_channel_rail
      and state.preview_channel_strip_expanded then
      ImGui.Spacing(ctx)
      draw_inline_channel_selector(
        asset,
        button_size
      )
    end
  end

  ImGui.EndChild(ctx)
  ImGui.PopStyleColor(ctx)
  ImGui.PopStyleVar(ctx)
end

function format_loudness_value(value, suffix)
  if value == nil then
    return "—"
  end

  return string.format(
    "%.1f%s",
    value,
    suffix or ""
  )
end

function draw_loudness_summary(asset)
  if not state.show_loudness_metrics then
    return
  end

  request_loudness_analysis(asset, false)

  local entry = valid_loudness_entry(asset)
  local key = loudness_cache_key(asset)
  local analyzing =
    state.loudness_queued[key]
    or (
      state.loudness_active
      and state.loudness_active.key == key
    )

  ImGui.SameLine(ctx)

  if analyzing and not entry then
    metric_chip("Loudness", "分析中…", false)
    return
  end

  if not entry then
    metric_chip("Loudness", "等待", false)
    return
  end

  local first = true

  local function add_metric(label, value, active)
    if not first then
      ImGui.SameLine(ctx, 0, 5)
    end

    metric_chip(label, value, active)
    first = false
  end

  if state.loudness_show_i then
    add_metric(
      "LUFS-I",
      format_loudness_value(entry.lufs_i, ""),
      true
    )
  end

  if state.loudness_show_m then
    add_metric(
      "M max",
      format_loudness_value(entry.lufs_m, ""),
      false
    )
  end

  if state.loudness_show_s then
    add_metric(
      "S max",
      format_loudness_value(entry.lufs_s, ""),
      false
    )
  end

  if state.loudness_show_tp then
    add_metric(
      "TP",
      format_loudness_value(entry.true_peak, " dBTP"),
      false
    )
  end
end


function collect_loudness_summary_items(asset)
  local items = {}

  if not state.show_loudness_metrics then
    return items
  end

  request_loudness_analysis(asset, false)

  local entry = valid_loudness_entry(asset)
  local key = loudness_cache_key(asset)
  local analyzing =
    state.loudness_queued[key]
    or (
      state.loudness_active
      and state.loudness_active.key == key
    )

  if analyzing and not entry then
    items[1] = {
      label = "LOUDNESS",
      value = "…",
      accent = false,
    }
    return items
  end

  if not entry then
    return items
  end

  if state.loudness_show_i then
    items[#items + 1] = {
      label = "LUFS-I",
      value = format_loudness_value(entry.lufs_i, ""),
      accent = true,
    }
  end

  if state.loudness_show_m then
    items[#items + 1] = {
      label = "M",
      value = format_loudness_value(entry.lufs_m, ""),
      accent = false,
    }
  end

  if state.loudness_show_s then
    items[#items + 1] = {
      label = "S",
      value = format_loudness_value(entry.lufs_s, ""),
      accent = false,
    }
  end

  if state.loudness_show_tp then
    items[#items + 1] = {
      label = "TP",
      value = format_loudness_value(
        entry.true_peak,
        " dBTP"
      ),
      accent = false,
    }
  end

  return items
end

function draw_preview_header(asset)
  local width =
    select(
      1,
      ImGui.GetContentRegionAvail(ctx)
    )

  local height = 32
  local x, y =
    ImGui.GetCursorScreenPos(ctx)

  ImGui.InvisibleButton(
    ctx,
    "preview_header_bar",
    width,
    height
  )

  local draw_list =
    ImGui.GetWindowDrawList(ctx)

  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + width,
    y + height,
    COLOR.title,
    UI_METRIC.radius_small
  )

  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y + 7,
    x + 3,
    y + height - 7,
    COLOR.selected,
    1.5
  )

  local items =
    collect_loudness_summary_items(asset)

  local right_x = x + width - 12

  for index = #items, 1, -1 do
    local item = items[index]
    local label =
      translate_ui_text(item.label)
    local value =
      tostring(item.value or "")

    local label_w =
      select(
        1,
        ImGui.CalcTextSize(ctx, label)
      ) or 0

    local value_w =
      select(
        1,
        ImGui.CalcTextSize(ctx, value)
      ) or 0

    local item_w =
      label_w + value_w + 12

    right_x = right_x - item_w

    ImGui.DrawList_AddText(
      draw_list,
      right_x,
      y + 9,
      COLOR.dim,
      label
    )

    ImGui.DrawList_AddText(
      draw_list,
      right_x + label_w + 6,
      y + 9,
      item.accent
        and COLOR.playhead
        or COLOR.text,
      value
    )

    right_x = right_x - 14

    if index > 1 then
      ImGui.DrawList_AddCircleFilled(
        draw_list,
        right_x + 7,
        y + height * 0.5,
        1.5,
        rgba_with_alpha(COLOR.dim, 0x88),
        10
      )
    end
  end

  local name_start = x + 12
  local name_end =
    math.min(
      x + width * 0.47,
      right_x - 14
    )

  draw_clipped_text(
    draw_list,
    name_start,
    y + 8,
    COLOR.selected_text,
    asset.name,
    name_start,
    y,
    math.max(name_start + 80, name_end),
    y + height
  )

  local name_w =
    math.min(
      select(
        1,
        ImGui.CalcTextSize(
          ctx,
          asset.name
        )
      ) or 0,
      math.max(80, name_end - name_start)
    )

  local metadata_x =
    name_start + name_w + 14

  local metadata =
    string.format(
      "%s  ·  %sch  ·  %s  ·  %s",
      asset.duration > 0
        and format_time(asset.duration)
        or "读取中",
      tostring(asset.channels or 0),
      format_rate(asset.sample_rate),
      asset.library or ""
    )

  if metadata_x < right_x - 20 then
    draw_clipped_text(
      draw_list,
      metadata_x,
      y + 8,
      COLOR.dim,
      metadata,
      metadata_x,
      y,
      right_x - 10,
      y + height
    )
  end
end

function draw_bottom(asset)
  if not asset then
    ImGui.TextDisabled(
      ctx,
      "选择一个音频查看波形和试听控制。"
    )

    if state.status and state.status ~= "" then
      ImGui.SameLine(ctx, 0, 12)
      ImGui.TextColored(
        ctx,
        state.status_error and COLOR.error or COLOR.success,
        state.status
      )
    end
    return
  end

  queue_metadata(asset, true)

  draw_preview_header(asset)
  ImGui.Spacing(ctx)
  draw_large_wave(asset)
  draw_time_metrics(asset)
  ImGui.Spacing(ctx)
  draw_control_deck(asset)
end

----------------------------------------------------------------
-- Metadata inspector (0.4: non-destructive database editing)
----------------------------------------------------------------

local METADATA_EDIT_FIELDS = {
  {
    key = "description",
    label = "Description",
  },
  {
    key = "keywords",
    label = "Keywords",
  },
  {
    key = "category",
    label = "Category",
  },
  {
    key = "subcategory",
    label = "SubCategory",
  },
  {
    key = "catid",
    label = "CatID",
  },
  {
    key = "library",
    label = "Library",
  },
  {
    key = "artwork_path",
    label = "Artwork Path",
  },
}

function selected_assets_fast()
  local assets = {}

  for key in pairs(state.selected_set) do
    local asset = state.by_path[key]

    if asset then
      assets[#assets + 1] = asset
    end
  end

  if #assets == 0 then
    local asset = selected_asset()

    if asset then
      assets[1] = asset
    end
  end

  table.sort(
    assets,
    function(a, b)
      return path_key(a.path)
        < path_key(b.path)
    end
  )

  return assets
end

function metadata_selection_signature(assets)
  local parts = {
    tostring(#assets),
  }

  for _, asset in ipairs(assets) do
    parts[#parts + 1] =
      path_key(asset.path)
      .. ":"
      .. tostring(asset.indexed)
  end

  return fnv1a(table.concat(parts, "|"))
end

function common_metadata_value(assets, field)
  if #assets == 0 then
    return "", false
  end

  local value = tostring(assets[1][field] or "")

  for index = 2, #assets do
    if tostring(assets[index][field] or "")
      ~= value then
      return "", true
    end
  end

  return value, false
end

function sync_metadata_editor(assets)
  local signature =
    metadata_selection_signature(assets)

  if state.metadata_editor.signature
    == signature then
    return
  end

  state.metadata_editor.signature = signature
  state.metadata_editor.values = {}
  state.metadata_editor.enabled = {}
  state.metadata_editor.mixed = {}

  local single = #assets == 1

  for _, field in ipairs(METADATA_EDIT_FIELDS) do
    local value, mixed =
      common_metadata_value(
        assets,
        field.key
      )

    state.metadata_editor.values[field.key] = value
    state.metadata_editor.mixed[field.key] = mixed
    state.metadata_editor.enabled[field.key] = single
  end
end

function apply_metadata_editor(assets)
  if #assets == 0 then
    return
  end

  local changed_count = 0
  local multi = #assets > 1

  for _, asset in ipairs(assets) do
    local asset_changed = false
    local ucs_changed = false

    for _, field in ipairs(METADATA_EDIT_FIELDS) do
      local should_apply =
        not multi
        or state.metadata_editor.enabled[field.key]

      if should_apply then
        local value =
          tostring(
            state.metadata_editor.values[field.key]
              or ""
          )

        if tostring(asset[field.key] or "")
          ~= value then
          asset[field.key] = value
          asset_changed = true
          if field.key == "catid"
            or field.key == "category"
            or field.key == "subcategory" then
            ucs_changed = true
          end
        end
      end
    end

    if asset_changed then
      if ucs_changed then
        remove_ucs_confirmation_undo(path_key(asset.path))
        asset.ucs_status = "manual"
        asset.ucs_source = "manual"
        asset.ucs_version = UCS_CATALOG_VERSION
        asset.ucs_classifier_version = UCS_CLASSIFIER_VERSION
        asset.ucs_confidence = 1
        asset.ucs_candidates = ""
        asset.ucs_evidence = ""
      end
      asset._search_blob = nil
      refresh_ucs_pending_membership(asset)
      mark_asset_database_change(asset)
      changed_count = changed_count + 1
    end
  end

  if changed_count > 0 then
    state.results_dirty = true
    state.metadata_editor.signature = ""

    set_status(
      string.format(
        "已将 PsyReaSFX 元数据保存到 %d 个素材",
        changed_count
      )
    )
  else
    set_status("元数据没有变化")
  end
end

function add_metadata_filter(field, value)
  value = trim(value)

  if value == "" then
    return
  end

  local token =
    field
    .. ":\""
    .. value:gsub('"', '')
    .. "\""

  if trim(state.search) == "" then
    state.search = token
  else
    state.search = state.search .. " " .. token
  end

  state.results_dirty = true
end

function choose_artwork_for_asset(asset)
  if not asset then
    return
  end

  local ok, filename =
    reaper.GetUserFileNameForRead(
      asset.artwork_path ~= "-"
        and asset.artwork_path
        or "",
      "选择封面",
      "png,jpg,jpeg"
    )

  if ok and filename and filename ~= "" then
    asset.artwork_path =
      normalize_slashes(filename)
    asset.artwork_checked = true
    mark_asset_database_change(asset)
    state.results_dirty = true
    set_status("已设置 Artwork")
  end
end

function draw_inspector_artwork_header(asset)
  local available_width =
    select(
      1,
      ImGui.GetContentRegionAvail(ctx)
    )

  local cover_size =
    clamp(
      available_width - 28,
      112,
      190
    )

  local start_x =
    ImGui.GetCursorPosX(ctx)

  ImGui.SetCursorPosX(
    ctx,
    start_x
      + math.max(
        0,
        (available_width - cover_size) * 0.5
      )
  )

  local x, y =
    ImGui.GetCursorScreenPos(ctx)

  ImGui.InvisibleButton(
    ctx,
    "inspector_artwork",
    cover_size,
    cover_size
  )

  local draw_list =
    ImGui.GetWindowDrawList(ctx)

  draw_artwork_cover(
    draw_list,
    asset,
    x,
    y,
    cover_size,
    cover_size,
    false,
    UI_METRIC.radius
  )

  ImGui.SetCursorPosX(ctx, start_x)

  ImGui.TextWrapped(ctx, asset.name)
  ImGui.TextDisabled(
    ctx,
    asset.library or ""
  )

  if dark_button("选择封面", -1) then
    choose_artwork_for_asset(asset)
  end

  if dark_button("自动查找封面", -1) then
    asset.artwork_path = ""
    asset.artwork_checked = false
    state.artwork_folder_cache = {}
    state.artwork_dimension_cache = {}
    queue_artwork(asset, true)
    mark_asset_database_change(asset)
  end

  if tostring(asset.artwork_path or "") ~= "" then
    if dark_button("清除封面", -1) then
      asset.artwork_path = "-"
      asset.artwork_checked = true
      mark_asset_database_change(asset)
      state.results_dirty = true
    end
  end
end

function draw_ucs_candidate_actions(asset)
  if not asset then return end
  local candidates = "pending" == asset.ucs_status
      and ucs_parse_candidates(asset.ucs_candidates)
    or {}
  local undo_key = path_key(asset.path)
  local has_undo = state.ucs_confirmation_undo[undo_key] ~= nil
  if #candidates == 0 and not has_undo then return end

  ImGui.TextDisabled(ctx, "UCS 候选")
  if #candidates > 0 then
    local evidence = tostring(asset.ucs_evidence or "")
    if evidence ~= "" then
      ImGui.TextWrapped(
        ctx,
        translate_ui_text("根据文件名命中：") .. evidence
      )
    end
    local score_label = "en" == state.language and "score" or "分值"
    for _, candidate in ipairs(candidates) do
      local entry = candidate.entry
      local localized = ucs_entry_display_name(entry)
      local label = string.format(
        "%s · %s · %s %.2f##confirm_ucs_%s",
        entry.catid,
        localized,
        score_label,
        candidate.score,
        entry.catid
      )
      if dark_button(label, -1) then
        confirm_ucs_candidate(asset, entry.catid)
        break
      end
    end
  end
  if has_undo and dark_button("撤销此素材的 UCS 确认", -1) then
    undo_ucs_confirmation(undo_key)
  end
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
end

function draw_metadata_inspector()
  local assets = selected_assets_fast()

  if dark_button("隐藏元数据 >", -1) then
    state.inspector_visible = false
    state.config_dirty = true
    return
  end

  ImGui.Spacing(ctx)

  ImGui.TextColored(
    ctx,
    COLOR.text,
    "METADATA"
  )

  ImGui.SameLine(ctx)
  ImGui.TextDisabled(
    ctx,
    #assets > 0
      and tostring(#assets) .. " selected"
      or "no selection"
  )

  ImGui.Separator(ctx)

  if #assets == 0 then
    ImGui.TextWrapped(
      ctx,
      "选择一个或多个素材后，可在这里查看并编辑 PsyReaSFX 数据库元数据。"
    )
    return
  end

  for _, asset in ipairs(assets) do
    if not asset.indexed then
      queue_metadata(asset, true)
    end
  end

  sync_metadata_editor(assets)

  local primary = assets[1]
  local multi = #assets > 1

  if not multi
    and state.artwork_enabled
    and state.inspector_artwork_pinned then
    draw_inspector_artwork_header(primary)
    ImGui.Separator(ctx)
  end

  if ImGui.BeginChild(
    ctx,
    "metadata_inspector_scroll",
    -1,
    -1,
    0,
    ImGui.WindowFlags_AlwaysVerticalScrollbar
  ) then
    if multi
      or not state.inspector_artwork_pinned then
      ImGui.TextWrapped(
        ctx,
        multi
          and string.format(
            "%d 个素材批量编辑。勾选字段后才会写入。",
            #assets
          )
          or primary.name
      )

      if not multi and state.artwork_enabled then
        draw_inspector_artwork_header(primary)
        ImGui.Separator(ctx)
      end
    end

    ImGui.TextDisabled(ctx, "WORKFLOW STATUS")

    for index, status in ipairs(
      WORKFLOW_STATUS_ORDER
    ) do
      local definition =
        WORKFLOW_STATUS[status]

      if dark_button(definition.label, 76) then
        set_workflow_status(
          assets,
          status
        )
      end

      if index < #WORKFLOW_STATUS_ORDER then
        ImGui.SameLine(ctx)
      end
    end

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    if not multi then
      draw_ucs_candidate_actions(primary)
    end

    for _, field in ipairs(METADATA_EDIT_FIELDS) do
      if multi then
        local enabled
        enabled, state.metadata_editor.enabled[field.key] =
          ImGui.Checkbox(
            ctx,
            "##enable_" .. field.key,
            state.metadata_editor.enabled[field.key]
          )

        ImGui.SameLine(ctx)
      end

      ImGui.TextDisabled(ctx, field.label)

      if state.metadata_editor.mixed[field.key]
        and multi
        and not state.metadata_editor.enabled[field.key] then
        ImGui.SameLine(ctx)
        ImGui.TextDisabled(ctx, "<mixed>")
      end

      ImGui.SetNextItemWidth(ctx, -1)

      local changed
      changed, state.metadata_editor.values[field.key] =
        ImGui.InputText(
          ctx,
          "##metadata_" .. field.key,
          state.metadata_editor.values[field.key]
            or ""
        )
    end

    ImGui.Spacing(ctx)

    if dark_button(
      multi
        and "应用到所选素材"
        or "保存元数据",
      -1
    ) then
      apply_metadata_editor(assets)
    end

    if not multi then
      if primary.category
        and primary.category ~= "" then
        if dark_button("按 Category 筛选", -1) then
          add_metadata_filter(
            "category",
            primary.category
          )
        end
      end

      if primary.library
        and primary.library ~= "" then
        if dark_button("按 Library 筛选", -1) then
          add_metadata_filter(
            "library",
            primary.library
          )
        end
      end
    end

    ImGui.Separator(ctx)
    ImGui.TextDisabled(ctx, "FILE INFO")

    ImGui.TextWrapped(
      ctx,
      string.format(
        "Duration  %s\nFormat  %s / %s / %dch\nType  %s",
        primary.duration > 0
          and format_time(primary.duration)
          or "—",
        format_rate(primary.sample_rate),
        (tonumber(primary.bit_depth) or 0) > 0
          and tostring(primary.bit_depth) .. "-bit"
          or "—",
        tonumber(primary.channels) or 0,
        primary.source_type or "—"
      )
    )

    ImGui.TextDisabled(ctx, "PATH")
    ImGui.TextWrapped(ctx, primary.path or "")

    if dark_button("复制路径", -1) then
      ImGui.SetClipboardText(
        ctx,
        primary.path or ""
      )
    end
  end

  ImGui.EndChild(ctx)
end

----------------------------------------------------------------
-- Help popup
----------------------------------------------------------------

local HELP_POPUP_ID =
  "PsyReaSFX 使用说明##psyreasfx_help"

function help_locale(zh_text, en_text)
  return state.language == "en"
    and en_text
    or zh_text
end

function draw_help_shortcut_row(shortcut, zh_text, en_text)
  ImGui.TextColored(
    ctx,
    COLOR.header_text,
    shortcut
  )

  ImGui.SameLine(ctx, 156)

  ImGui.TextWrapped(
    ctx,
    help_locale(zh_text, en_text)
  )
end

function draw_help_section(id, zh_title, en_title, items)
  ImGui.PushID(ctx, "help_section_" .. id)

  ImGui.TextColored(
    ctx,
    COLOR.accent,
    help_locale(zh_title, en_title)
  )

  ImGui.Separator(ctx)

  for _, item in ipairs(items) do
    draw_help_shortcut_row(
      item[1],
      item[2],
      item[3]
    )
  end

  ImGui.PopID(ctx)
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
end

function draw_help_popup()
  if state.help_popup_requested > 0 then
    state.help_popup_requested =
      state.help_popup_requested - 1

    if state.help_popup_requested == 0 then
      ImGui.OpenPopup(
        ctx,
        HELP_POPUP_ID
      )
    end
  end

  ImGui.SetNextWindowSize(
    ctx,
    820,
    650,
    ImGui.Cond_Appearing
  )

  if not ImGui.BeginPopupModal(
    ctx,
    HELP_POPUP_ID,
    true,
    ImGui.WindowFlags_NoScrollbar
  ) then
    return
  end

  ImGui.TextColored(
    ctx,
    COLOR.header_text,
    SCRIPT_NAME
  )

  ImGui.SameLine(ctx)

  ImGui.TextColored(
    ctx,
    COLOR.accent,
    "v" .. VERSION
  )

  ImGui.TextDisabled(
    ctx,
    help_locale(
      "浏览、整理、试听与传输快捷参考",
      "Quick reference for browsing, organizing, auditioning, and Transfer"
    )
  )

  ImGui.Separator(ctx)

  local width, height = ImGui.GetContentRegionAvail(ctx)

  if ImGui.BeginChild(
    ctx,
    "help_content_scroll",
    width,
    height - 50,
    0,
    ImGui.WindowFlags_AlwaysVerticalScrollbar
  ) then
    draw_help_section(
      "workspace",
      "工作区",
      "Workspace",
      {
        {
          "F9 / F10 / F11",
          "切换导航栏、元数据栏与专注模式",
          "Toggle navigation, metadata, and Focus mode",
        },
        {
          "Ctrl+F",
          "聚焦搜索框",
          "Focus the search field",
        },
        {
          "Ctrl+R",
          "扫描当前音效库范围",
          "Scan the current library scope",
        },
      }
    )

    draw_help_section(
      "results",
      "结果列表",
      "Results",
      {
        {
          "Click",
          "单选素材",
          "Select one asset",
        },
        {
          "Ctrl+Click",
          "追加或取消单个素材",
          "Add or remove one asset from the selection",
        },
        {
          "Shift+Click",
          "连续范围选择",
          "Select a continuous range",
        },
        {
          "Ctrl+A",
          "全选当前结果",
          "Select all current results",
        },
        {
          "Shift+Wheel",
          "横向查看溢出的字段",
          "Pan horizontally across overflow columns",
        },
      }
    )

    draw_help_section(
      "preview",
      "试听与波形",
      "Preview and waveform",
      {
        {
          "Space",
          "播放或停止",
          "Play or stop",
        },
        {
          "Wave click",
          "从点击位置开始试听",
          "Start preview from the clicked position",
        },
        {
          "Wave drag",
          "建立并试听波形选区",
          "Create and audition a waveform selection",
        },
        {
          "L",
          "切换循环试听",
          "Toggle loop preview",
        },
      }
    )

    draw_help_section(
      "organize",
      "整理",
      "Organize",
      {
        {
          "F",
          "收藏或取消收藏",
          "Favorite or unfavorite",
        },
        {
          "M",
          "标记或取消标记",
          "Mark or unmark",
        },
        {
          "Right-click",
          "打开素材、集合和状态操作",
          "Open asset, collection, and status actions",
        },
      }
    )

    draw_help_section(
      "output",
      "插入与 Transfer",
      "Insert and Transfer",
      {
        {
          state.enter_insert_shortcuts and "Enter" or "Button / Menu",
          state.enter_insert_shortcuts
            and "插入当前轨道"
            or "插入当前轨道（Enter 快捷键默认关闭）",
          state.enter_insert_shortcuts
            and "Insert on the current track"
            or "Insert on the current track (Enter shortcut off by default)",
        },
        {
          state.enter_insert_shortcuts and "Ctrl+Enter" or "Button / Menu",
          state.enter_insert_shortcuts
            and "插入新轨道"
            or "插入新轨道（Ctrl+Enter 快捷键默认关闭）",
          state.enter_insert_shortcuts
            and "Insert on a new track"
            or "Insert on a new track (Ctrl+Enter shortcut off by default)",
        },
        {
          "Drag",
          "将素材或波形选区拖到 REAPER 编排区",
          "Drag an asset or waveform selection into REAPER",
        },
        {
          "Ctrl+T",
          "打开 Transfer 导出",
          "Open Transfer export",
        },
      }
    )
  end

  ImGui.EndChild(ctx)

  if dark_button("关闭", 90) then
    ImGui.CloseCurrentPopup(ctx)
  end

  ImGui.EndPopup(ctx)
end

----------------------------------------------------------------
-- Settings popup
----------------------------------------------------------------

function settings_tab_button(key, label)
  local selected =
    state.settings_tab == key

  if selected then
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_Button,
      COLOR.selected
    )
  end

  local clicked =
    dark_button(label, 112)

  if selected then
    ImGui.PopStyleColor(ctx)
  end

  if clicked then
    state.settings_tab = key
  end
end

function draw_language_setting()
  ImGui.Text(ctx, "语言")
  ImGui.SameLine(ctx)

  local zh_selected =
    state.language == "zh"

  if zh_selected then
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_Button,
      COLOR.selected
    )
  end

  local zh_clicked =
    dark_button("中文", 86)

  if zh_selected then
    ImGui.PopStyleColor(ctx)
  end

  ImGui.SameLine(ctx)

  local en_selected =
    state.language == "en"

  if en_selected then
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_Button,
      COLOR.selected
    )
  end

  local en_clicked =
    dark_button("English", 86)

  if en_selected then
    ImGui.PopStyleColor(ctx)
  end

  if zh_clicked then
    state.language = "zh"
    state.config_dirty = true
  elseif en_clicked then
    state.language = "en"
    state.config_dirty = true
  end
end

function draw_settings_general()
  draw_language_setting()
  ImGui.Separator(ctx)

  settings_section_title(
    "后台与浏览",
    "自动检查来源文件夹变化。"
  )

  local watch_changed
  watch_changed, state.watch_enabled =
    ImGui.Checkbox(
      ctx,
      "启用 Watch Folder",
      state.watch_enabled
    )

  if watch_changed then
    state.next_watch =
      reaper.time_precise() + state.watch_interval
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 220)
  local interval_changed
  interval_changed, state.watch_interval =
    ImGui.SliderDouble(
      ctx,
      "检查间隔",
      state.watch_interval,
      15,
      600,
      "%.0f s"
    )

  if interval_changed then
    state.next_watch = reaper.time_precise() + state.watch_interval
    state.config_dirty = true
  end

  local silent_changed
  silent_changed, state.watch_silent =
    ImGui.Checkbox(
      ctx,
      "静默后台检查（仅显示工具栏动态状态）",
      state.watch_silent
    )

  if silent_changed then
    state.config_dirty = true
  end

  local resume_changed
  resume_changed, state.resume_scan_on_start =
    ImGui.Checkbox(
      ctx,
      "启动时恢复中断的扫描",
      state.resume_scan_on_start
    )

  if resume_changed then
    state.config_dirty = true
  end

  ImGui.Separator(ctx)

  local sidebar_changed
  sidebar_changed, state.sidebar_visible =
    ImGui.Checkbox(
      ctx,
      "显示左侧导航",
      state.sidebar_visible
    )

  if sidebar_changed then
    state.config_dirty = true
  end

  local inspector_changed
  inspector_changed, state.inspector_visible =
    ImGui.Checkbox(
      ctx,
      "显示右侧元数据面板",
      state.inspector_visible
    )

  if inspector_changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 260)

  local inspector_width_changed
  inspector_width_changed, state.inspector_width =
    ImGui.SliderDouble(
      ctx,
      "元数据面板宽度",
      state.inspector_width,
      240,
      480,
      "%.0f px"
    )

  if inspector_width_changed then
    state.config_dirty = true
  end

  ImGui.Separator(ctx)
  settings_section_title(
    "REAPER 插入快捷键",
    "默认关闭，避免在搜索框确认文字时误插入素材。"
  )

  local enter_shortcuts_changed
  local enter_shortcuts_value
  enter_shortcuts_changed, enter_shortcuts_value =
    ImGui.Checkbox(
      ctx,
      "启用 Enter / Ctrl+Enter 快速插入 REAPER",
      state.enter_insert_shortcuts
    )

  if enter_shortcuts_changed then
    AppState.set("enter_insert_shortcuts", enter_shortcuts_value)
    AppState.mark_dirty("config_dirty")
  end

  ImGui.Separator(ctx)
  ImGui.Text(ctx, "插入命名")
  ImGui.SetNextItemWidth(ctx, 300)

  local changed
  changed, state.insert_prefix =
    ImGui.InputText(
      ctx,
      "前缀",
      state.insert_prefix
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 300)

  changed, state.insert_suffix =
    ImGui.InputText(
      ctx,
      "后缀",
      state.insert_suffix
    )

  if changed then
    state.config_dirty = true
  end

  changed, state.insert_lowercase =
    ImGui.Checkbox(
      ctx,
      "Take 名称转为小写",
      state.insert_lowercase
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 220)

  changed, state.insert_fade_ms =
    ImGui.SliderDouble(
      ctx,
      "插入淡化",
      state.insert_fade_ms,
      0,
      100,
      "%.0f ms"
    )
end

function color_edit_flags()
  return ImGui.ColorEditFlags_NoAlpha
    | ImGui.ColorEditFlags_NoInputs
    | ImGui.ColorEditFlags_NoLabel
    | ImGui.ColorEditFlags_NoTooltip
    | ImGui.ColorEditFlags_PickerHueBar
    | ImGui.ColorEditFlags_InputRGB
end

function draw_color_picker_row(
  key,
  label,
  fallback_hex,
  mode
)
  local width =
    select(
      1,
      ImGui.GetContentRegionAvail(ctx)
    )

  local row_height = 44
  local x, y =
    ImGui.GetCursorScreenPos(ctx)

  -- Dummy only reserves the row. The previous InvisibleButton covered
  -- the later ColorEdit3 widget and consumed the click.
  ImGui.Dummy(
    ctx,
    width,
    row_height
  )

  local mouse_x, mouse_y =
    ImGui.GetMousePos(ctx)

  local hovered =
    mouse_x >= x
    and mouse_x <= x + width
    and mouse_y >= y
    and mouse_y <= y + row_height

  local draw_list =
    ImGui.GetWindowDrawList(ctx)

  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + width,
    y + row_height,
    hovered
      and COLOR.button_hover
      or COLOR.panel_alt,
    UI_METRIC.radius_small
  )

  ImGui.DrawList_AddRect(
    draw_list,
    x + 0.5,
    y + 0.5,
    x + width - 0.5,
    y + row_height - 0.5,
    rgba_with_alpha(COLOR.border, 0x7C),
    UI_METRIC.radius_small,
    0,
    1
  )

  ImGui.DrawList_AddText(
    draw_list,
    x + 12,
    y + 13,
    COLOR.text,
    translate_ui_text(label)
  )

  local reset_width = 54
  local hex_width = 78
  local picker_x =
    x + width - reset_width - hex_width - 54

  local saved_x, saved_y =
    ImGui.GetCursorScreenPos(ctx)

  ImGui.SetCursorScreenPos(
    ctx,
    picker_x,
    y + 7
  )

  ImGui.PushStyleVar(
    ctx,
    ImGui.StyleVar_FramePadding,
    7,
    6
  )

  local rgb =
    rgb_from_hex(state[key])
      or rgb_from_hex(fallback_hex)
      or 0

  ImGui.SetNextItemWidth(ctx, 34)

  local changed, new_rgb =
    ImGui.ColorEdit3(
      ctx,
      "##picker_" .. key,
      rgb,
      color_edit_flags()
    )

  tooltip("点击打开色盘")

  ImGui.PopStyleVar(ctx)

  if changed then
    state[key] = hex_from_rgb(new_rgb)
    state.config_dirty = true

    if mode == "theme" then
      state.theme_preset = "custom"
      apply_theme_palette()
    elseif mode == "surface" then
      state.surface_style = "custom"
      apply_surface_style()
      apply_theme_palette()
    else
      apply_waveform_palette()
    end
  end

  ImGui.SetCursorScreenPos(
    ctx,
    picker_x + 37,
    y + 13
  )

  ImGui.TextDisabled(
    ctx,
    tostring(state[key] or fallback_hex)
  )

  ImGui.SetCursorScreenPos(
    ctx,
    x + width - reset_width - 8,
    y + 7
  )

  if dark_button(
    "恢复##reset_" .. key,
    reset_width
  ) then
    state[key] = fallback_hex
    state.config_dirty = true

    if mode == "theme" then
      state.theme_preset = "custom"
      apply_theme_palette()
    elseif mode == "surface" then
      state.surface_style = "custom"
      apply_surface_style()
      apply_theme_palette()
    else
      apply_waveform_palette()
    end
  end

  ImGui.SetCursorScreenPos(
    ctx,
    saved_x,
    y + row_height
  )
end

function draw_waveform_palette_field(definition)
  local default_hex =
    DEFAULT_WAVEFORM_PALETTE[definition.key]
      or hex_from_rgb(
        (definition.fallback >> 8)
          & 0xFFFFFF
      )

  draw_color_picker_row(
    definition.key,
    definition.label,
    default_hex,
    "waveform"
  )
end

function get_reaimgui_runtime_version()
  if type(ImGui.GetVersion) ~= "function" then
    return "0.10+"
  end

  local ok, version =
    pcall(ImGui.GetVersion)

  if ok and version then
    return tostring(version)
  end

  return "0.10+"
end

function build_diagnostics_text()
  return table.concat(
    {
      SCRIPT_NAME .. " " .. VERSION,
      "Author: Psysia",
      "REAPER: " .. tostring(reaper.GetAppVersion()),
      "OS: " .. tostring(reaper.GetOS()),
      "ReaImGui: " .. get_reaimgui_runtime_version(),
      "SWS: " .. (
        type(reaper.CF_CreatePreview) == "function"
          and "Detected"
          or "Not detected"
      ),
      "Preview backend: " .. tostring(state.preview_backend),
      "Libraries: " .. tostring(#state.libraries),
      "Source folders: " .. tostring(#state.root_records),
      "Assets: " .. tostring(#state.assets),
      "Missing assets: " .. tostring(state.missing_asset_count),
      "Duplicate groups/assets: "
        .. tostring(state.duplicate_group_count)
        .. "/"
        .. tostring(state.duplicate_asset_count),
      "Current project: "
        .. tostring(state.current_project_path ~= "" and state.current_project_path or "Unsaved"),
      "Current played highlights: "
        .. tostring(session_played_count()),
      "Previous-session highlights: "
        .. tostring(last_session_played_count()),
      "Missing English translations seen: "
        .. tostring(missing_translation_count()),
      "Data directory: " .. DATA_DIR,
      "Wave cache directory: "
        .. tostring(
          state.wave_cache_dir
            or WAVE_CACHE_DIR
        ),
      "Project URL: "
        .. (
          PROJECT_URL ~= ""
            and PROJECT_URL
            or "Not configured"
        ),
      "Script file: " .. SCRIPT_FILE,
    },
    "\n"
  )
end

function about_info_row(label, value)
  local available =
    select(
      1,
      ImGui.GetContentRegionAvail(ctx)
    )

  local x, y =
    ImGui.GetCursorScreenPos(ctx)

  local label_width =
    math.min(170, available * 0.34)

  ImGui.TextDisabled(ctx, label)

  ImGui.SameLine(
    ctx,
    label_width
  )

  ImGui.TextWrapped(
    ctx,
    tostring(value or "")
  )
end

function draw_settings_about()
  local available_width =
    select(
      1,
      ImGui.GetContentRegionAvail(ctx)
    )

  local card_width =
    math.min(
      720,
      math.max(
        420,
        available_width
      )
    )

  local card_height = 220
  local x, y =
    ImGui.GetCursorScreenPos(ctx)

  ImGui.InvisibleButton(
    ctx,
    "about_minimal_card",
    card_width,
    card_height
  )

  local draw_list =
    ImGui.GetWindowDrawList(ctx)

  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + card_width,
    y + card_height,
    COLOR.panel_alt,
    math.max(10, UI_METRIC.radius)
  )

  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + card_width,
    y + 3,
    COLOR.accent,
    2
  )

  local icon_size = math.min(132, card_height - 54)
  local icon_x = x + 24
  local icon_y = y + (card_height - icon_size) * 0.5
  draw_brand_symbol(
    draw_list,
    icon_x,
    icon_y,
    icon_size
  )

  local text_x = icon_x + icon_size + 28

  draw_brand_wordmark(
    draw_list,
    text_x,
    y + 34,
    28
  )

  ImGui.DrawList_AddText(
    draw_list,
    text_x,
    y + 78,
    COLOR.header_text,
    translate_ui_text("音效资产井然有序")
  )

  ImGui.DrawList_AddText(
    draw_list,
    text_x,
    y + 105,
    COLOR.dim,
    translate_ui_text("浏览 · 整理 · 试听")
  )

  ImGui.DrawList_AddText(
    draw_list,
    text_x,
    y + 143,
    COLOR.accent,
    "v" .. VERSION .. "  ·  " .. AUTHOR_NAME
  )

  ImGui.DrawList_AddText(
    draw_list,
    text_x,
    y + 172,
    COLOR.dim,
    COPYRIGHT_TEXT
  )

  ImGui.Spacing(ctx)

  if PROJECT_URL ~= "" then
    if dark_button(
      "GitHub 项目主页 ↗",
      math.min(190, card_width)
    ) then
      open_url(PROJECT_URL)
    end
  else
    ImGui.TextDisabled(
      ctx,
      "GitHub 项目主页 · 待配置"
    )
  end
end

function apply_unified_interface(reset_columns, persist)
  state.ui_density = "compact"
  state.preview_control_layout = "studio_strip"

  if reset_columns then
    reset_columns_default()
  end

  if persist ~= false then
    state.config_dirty = true
  end
end

function settings_section_title(title, description)
  ImGui.Spacing(ctx)
  ImGui.TextColored(
    ctx,
    COLOR.header_text,
    title
  )

  if description and description ~= "" then
    ImGui.TextDisabled(ctx, description)
  end

  ImGui.Spacing(ctx)
end

function transfer_option_button(label, width, selected)
  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Button,
    selected and COLOR.selected or COLOR.button
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_ButtonHovered,
    selected and COLOR.accent or COLOR.button_hover
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_ButtonActive,
    COLOR.accent
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Text,
    selected and COLOR.selected_text or COLOR.text
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Border,
    selected
      and rgba_with_alpha(COLOR.selected_text, 0xA0)
      or rgba_with_alpha(COLOR.border, 0x70)
  )

  ImGui.PushStyleVar(
    ctx,
    ImGui.StyleVar_FrameBorderSize,
    selected and 1.5 or 1
  )

  local clicked = ImGui.Button(
    ctx,
    label,
    width or 128,
    0
  )

  ImGui.PopStyleVar(ctx)
  ImGui.PopStyleColor(ctx, 5)
  return clicked
end

function transfer_choice(label, key, options)
  ImGui.TextDisabled(ctx, label)

  for index, option in ipairs(options) do
    local selected = state[key] == option.value

    local clicked = transfer_option_button(
      option.label .. "##" .. key .. "_" .. option.value,
      option.width or 128,
      selected
    )

    if clicked then
      state[key] = option.value
      state.config_dirty = true

      if key == "transfer_normalize" then
        if option.value == "lufs_i" then
          state.transfer_normalize_target = -16
        elseif option.value == "rms_i" then
          state.transfer_normalize_target = -18
        elseif option.value ~= "off" then
          state.transfer_normalize_target = -1
        end
      end
    end

    if index < #options then
      ImGui.SameLine(ctx, 0, 6)
    end
  end
end

function prompt_transfer_directory()
  local initial = state.transfer_dir or DEFAULT_TRANSFER_DIR
  local chosen = nil

  if type(reaper.JS_Dialog_BrowseForFolder) == "function" then
    local ok, accepted, path = pcall(
      reaper.JS_Dialog_BrowseForFolder,
      translate_ui_text("选择 Transfer 输出目录"),
      initial
    )

    if ok and accepted and accepted ~= 0 then
      chosen = path
    end
  end

  if not chosen then
    local ok, input = reaper.GetUserInputs(
      "选择 Transfer 输出目录",
      1,
      "输出目录:,extrawidth=420",
      initial
    )

    if not ok then
      return
    end

    chosen = input
  end

  chosen = normalize_slashes(trim(chosen or ""))

  if chosen == "" then
    set_status("请选择有效的输出目录", true)
    return
  end

  if path_key(chosen) == path_key(initial) then
    set_status("输出目录没有变化")
    return
  end

  if reaper.RecursiveCreateDirectory(chosen, 0) <= 0
    and not directory_exists(chosen) then
    set_status("无法创建输出目录", true)
    return
  end

  state.transfer_dir = chosen
  state.config_dirty = true
  set_status("已更新 Transfer 输出目录")
end

function draw_transfer_settings_content()
  settings_section_title(
    "输出目录",
    "Transfer 使用独立目录，不修改源素材。"
  )

  ImGui.SetNextItemWidth(ctx, -1)
  local changed
  changed, state.transfer_dir = ImGui.InputText(
    ctx,
    "##transfer_dir",
    state.transfer_dir or DEFAULT_TRANSFER_DIR
  )

  if changed then
    state.transfer_dir = normalize_slashes(state.transfer_dir)
    state.config_dirty = true
  end

  if dark_button("更改输出目录…", 150) then
    prompt_transfer_directory()
  end

  ImGui.SameLine(ctx, 0, 6)

  if dark_button("打开输出目录##transfer_settings_open_dir", 140) then
    local directory = state.transfer_dir or DEFAULT_TRANSFER_DIR
    reaper.RecursiveCreateDirectory(directory, 0)
    open_folder(directory)
  end

  ImGui.SameLine(ctx, 0, 6)

  if dark_button("恢复默认输出目录", 170) then
    state.transfer_dir = DEFAULT_TRANSFER_DIR
    state.config_dirty = true
  end

  ImGui.Separator(ctx)
  settings_section_title(
    "命名模板",
    "可用字段：{name} {category} {subcategory} {library} {index} {date} {region} {pitch} {rate} {gain} {direction} {variant} {variant_index}"
  )

  ImGui.SetNextItemWidth(ctx, -1)
  changed, state.transfer_template = ImGui.InputText(
    ctx,
    "##transfer_template",
    state.transfer_template or "{name}"
  )

  if changed then
    state.config_dirty = true
  end

  changed, state.transfer_lowercase = ImGui.Checkbox(
    ctx,
    "文件名转为小写",
    state.transfer_lowercase
  )

  if changed then
    state.config_dirty = true
  end

  ImGui.Separator(ctx)
  settings_section_title(
    "格式与范围",
    "当前素材可导出波形选区；批量导出始终使用每个完整文件。"
  )

  transfer_choice("导出范围", "transfer_scope", {
    { value = "selection", label = "当前选区" },
    { value = "full", label = "完整文件" },
  })

  ImGui.TextDisabled(ctx, "没有有效选区时自动使用完整文件")

  transfer_choice("输出格式", "transfer_format", {
    { value = "wav16", label = "WAV · 16-bit", width = 126 },
    { value = "wav24", label = "WAV · 24-bit", width = 126 },
    { value = "wav32", label = "WAV · 32-bit PCM", width = 154 },
    { value = "flac", label = "FLAC · REAPER 默认", width = 190 },
  })

  transfer_choice("采样率", "transfer_sample_rate", {
    { value = "source", label = "跟随源文件", width = 120 },
    { value = "44100", label = "44.1 kHz", width = 92 },
    { value = "48000", label = "48 kHz", width = 86 },
    { value = "96000", label = "96 kHz", width = 86 },
    { value = "192000", label = "192 kHz", width = 92 },
  })

  transfer_choice("声道", "transfer_channels", {
    { value = "source", label = "跟随源声道", width = 120 },
    { value = "mono", label = "单声道", width = 92 },
    { value = "stereo", label = "立体声", width = 92 },
  })

  changed, state.transfer_preserve_metadata =
    ImGui.Checkbox(
      ctx,
      "尽可能保留源文件元数据",
      state.transfer_preserve_metadata
    )

  if changed then
    state.config_dirty = true
  end

  if state.transfer_format == "wav16" then
    changed, state.transfer_dither =
      ImGui.Checkbox(
        ctx,
        "启用抖动",
        state.transfer_dither
      )

    if changed then
      state.config_dirty = true
    end

    ImGui.SameLine(ctx, 0, 18)

    changed, state.transfer_noise_shaping =
      ImGui.Checkbox(
        ctx,
        "噪声整形",
        state.transfer_noise_shaping
      )

    if changed then
      state.config_dirty = true
    end

  elseif state.transfer_format ~= "flac" then
    ImGui.TextDisabled(
      ctx,
      "当前位深保持抖动关闭；WAV 16-bit 可单独启用。"
    )
  end

  ImGui.Separator(ctx)
  settings_section_title(
    "处理",
    "当前 Pitch、Rate、Gain、Reverse 与 Preserve Pitch 会写入导出文件。"
  )

  ImGui.SetNextItemWidth(ctx, 230)
  changed, state.transfer_fade_in_ms = ImGui.SliderDouble(
    ctx,
    "淡入",
    state.transfer_fade_in_ms,
    0,
    500,
    "%.0f ms"
  )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 230)
  changed, state.transfer_fade_out_ms = ImGui.SliderDouble(
    ctx,
    "淡出",
    state.transfer_fade_out_ms,
    0,
    2000,
    "%.0f ms"
  )

  if changed then
    state.config_dirty = true
  end

  changed, state.transfer_smart_tail = ImGui.Checkbox(
    ctx,
    "智能保留选区尾音",
    state.transfer_smart_tail
  )

  if changed then
    state.config_dirty = true
  end

  if state.transfer_smart_tail then
    ImGui.TextDisabled(
      ctx,
      "分析选区结束后的源音频，保留最后一个超过阈值的尾音，并受最大长度限制。"
    )

    ImGui.SetNextItemWidth(ctx, 230)
    changed, state.transfer_tail_threshold_db =
      ImGui.SliderDouble(
        ctx,
        "尾音阈值",
        state.transfer_tail_threshold_db,
        -96,
        -18,
        "%.1f dBFS"
      )

    if changed then
      state.config_dirty = true
    end

    ImGui.SetNextItemWidth(ctx, 230)
    changed, state.transfer_tail_max_ms =
      ImGui.SliderDouble(
        ctx,
        "最大尾音",
        state.transfer_tail_max_ms,
        100,
        30000,
        "%.0f ms"
      )

    if changed then
      state.config_dirty = true
    end

    ImGui.SetNextItemWidth(ctx, 230)
    changed, state.transfer_tail_hold_ms =
      ImGui.SliderDouble(
        ctx,
        "尾音留白",
        state.transfer_tail_hold_ms,
        0,
        2000,
        "%.0f ms"
      )

    if changed then
      state.config_dirty = true
    end

    ImGui.TextDisabled(
      ctx,
      "只延伸源文件中已有的尾音；Transfer 仍不经过工程轨道、发送或 Master FX。"
    )
  end

  ImGui.Separator(ctx)
  settings_section_title(
    "批量变体",
    "按 Pitch、Rate、Gain 与方向生成笛卡尔组合；每个参数最多 16 项，单素材最多 128 个变体。"
  )

  changed, state.transfer_variants_enabled =
    ImGui.Checkbox(
      ctx,
      "启用批量变体",
      state.transfer_variants_enabled
    )

  if changed then
    state.config_dirty = true
  end

  if state.transfer_variants_enabled then
    ImGui.TextDisabled(
      ctx,
      "留空表示使用主界面当前值；可用逗号、空格或分号分隔。"
    )

    ImGui.SetNextItemWidth(ctx, 420)
    changed, state.transfer_variant_pitches =
      ImGui.InputText(
        ctx,
        "Pitch 列表##transfer_variant_pitches",
        state.transfer_variant_pitches or ""
      )

    if changed then
      state.config_dirty = true
    end

    ImGui.SetNextItemWidth(ctx, 420)
    changed, state.transfer_variant_rates =
      ImGui.InputText(
        ctx,
        "Rate 列表##transfer_variant_rates",
        state.transfer_variant_rates or ""
      )

    if changed then
      state.config_dirty = true
    end

    ImGui.SetNextItemWidth(ctx, 420)
    changed, state.transfer_variant_gains =
      ImGui.InputText(
        ctx,
        "Gain 列表##transfer_variant_gains",
        state.transfer_variant_gains or ""
      )

    if changed then
      state.config_dirty = true
    end

    if dark_button("当前参数", 110) then
      state.transfer_variant_pitches = ""
      state.transfer_variant_rates = ""
      state.transfer_variant_gains = ""
      state.transfer_variant_include_reverse = false
      state.config_dirty = true
    end

    ImGui.SameLine(ctx, 0, 6)

    if dark_button("Pitch ±3 / ±6", 142) then
      state.transfer_variant_pitches = "-6,-3,0,3,6"
      state.transfer_variant_rates = ""
      state.transfer_variant_gains = ""
      state.config_dirty = true
    end

    ImGui.SameLine(ctx, 0, 6)

    if dark_button("轻量变化", 110) then
      state.transfer_variant_pitches = "-2,0,2"
      state.transfer_variant_rates = "0.95,1,1.05"
      state.transfer_variant_gains = "-1,0,1"
      state.config_dirty = true
    end

    changed, state.transfer_variant_include_reverse =
      ImGui.Checkbox(
        ctx,
        "同时生成正向与反向",
        state.transfer_variant_include_reverse
      )

    if changed then
      state.config_dirty = true
    end

    changed, state.transfer_variant_auto_suffix =
      ImGui.Checkbox(
        ctx,
        "模板未含变体字段时自动追加安全后缀",
        state.transfer_variant_auto_suffix
      )

    if changed then
      state.config_dirty = true
    end

    local variants, variant_error =
      build_transfer_variants()

    if variants then
      ImGui.TextColored(
        ctx,
        COLOR.success,
        string.format(
          "%s %d",
          translate_ui_text("每个素材将生成"),
          #variants
        )
      )
    else
      ImGui.TextColored(
        ctx,
        COLOR.error,
        variant_error or translate_ui_text("变体设置无效")
      )
    end
  end

  transfer_choice("标准化", "transfer_normalize", {
    { value = "off", label = "关闭标准化", width = 112 },
    { value = "peak", label = "Peak", width = 82 },
    { value = "true_peak", label = "True Peak", width = 102 },
    { value = "rms_i", label = "RMS-I", width = 88 },
    { value = "lufs_i", label = "LUFS-I", width = 90 },
  })

  if state.transfer_normalize ~= "off" then
    ImGui.SetNextItemWidth(ctx, 230)
    changed, state.transfer_normalize_target = ImGui.SliderDouble(
      ctx,
      "目标值",
      state.transfer_normalize_target,
      (
        state.transfer_normalize == "lufs_i"
          or state.transfer_normalize == "rms_i"
      ) and -36 or -12,
      0,
      state.transfer_normalize == "lufs_i"
        and "%.1f LUFS"
        or (
          state.transfer_normalize == "rms_i"
            and "%.1f dB RMS"
            or "%.1f dBFS"
        )
    )

    if changed then
      state.config_dirty = true
    end
  end

  ImGui.Separator(ctx)
  settings_section_title(
    "完成行为",
    "自动递增是默认且最安全的重名策略。"
  )

  transfer_choice("重名策略", "transfer_collision", {
    { value = "increment", label = "自动递增", width = 110 },
    { value = "skip", label = "跳过已有文件", width = 132 },
    { value = "overwrite", label = "允许覆盖", width = 108 },
  })

  changed, state.transfer_insert_after = ImGui.Checkbox(
    ctx,
    "导出后插入 REAPER",
    state.transfer_insert_after
  )

  if changed then
    state.config_dirty = true
  end

  changed, state.transfer_open_dir_after = ImGui.Checkbox(
    ctx,
    "导出完成后打开输出目录",
    state.transfer_open_dir_after
  )

  if changed then
    state.config_dirty = true
  end

  ImGui.TextDisabled(
    ctx,
    "Transfer 只处理源素材与当前 Pitch / Rate / Gain / Reverse / Preserve Pitch，不经过工程轨道或 Master FX。"
  )
end

function draw_transfer_popup()
  if state.transfer_popup_requested > 0 then
    state.transfer_popup_requested = state.transfer_popup_requested - 1

    if state.transfer_popup_requested == 0 then
      ImGui.OpenPopup(ctx, "Transfer 导出##transfer")
    end
  end

  ImGui.SetNextWindowSize(
    ctx,
    820,
    760,
    ImGui.Cond_Appearing
  )

  if not ImGui.BeginPopupModal(
    ctx,
    "Transfer 导出##transfer",
    true,
    ImGui.WindowFlags_NoScrollbar
  ) then
    return
  end

  local width, height = ImGui.GetContentRegionAvail(ctx)
  local footer_height = state.transfer_running and 106 or 72

  if ImGui.BeginChild(
    ctx,
    "transfer_settings_scroll",
    width,
    height - footer_height,
    0,
    ImGui.WindowFlags_AlwaysVerticalScrollbar
  ) then
    draw_transfer_settings_content()

    ImGui.Separator(ctx)
    settings_section_title("最近输出", "")

    if state.transfer_last_output ~= "" then
      ImGui.TextWrapped(ctx, state.transfer_last_output)

      if dark_button("打开输出目录##transfer_recent_open_dir", 140) then
        open_folder(dirname(state.transfer_last_output))
      end
    else
      ImGui.TextDisabled(ctx, "尚未执行 Transfer")
    end

    if state.transfer_last_summary ~= "" then
      ImGui.TextColored(
        ctx,
        COLOR.success,
        state.transfer_last_summary
      )
    end

    if reaper.file_exists(TRANSFER_REPORT_FILE) then
      if dark_button("打开任务报告目录##transfer_report_open_dir", 170) then
        open_folder(dirname(TRANSFER_REPORT_FILE))
      end
    end

    if state.transfer_last_error ~= "" then
      ImGui.TextColored(ctx, COLOR.error, state.transfer_last_error)
    end
  end

  ImGui.EndChild(ctx)
  ImGui.Separator(ctx)

  local asset = selected_asset()
  local selected = selected_assets()

  if state.transfer_running and state.transfer_job then
    local job = state.transfer_job
    local fraction =
      job.total > 0
        and clamp((job.completed or 0) / job.total, 0, 1)
        or 0

    ImGui.ProgressBar(
      ctx,
      fraction,
      -142,
      22,
      string.format(
        "%d / %d",
        job.completed or 0,
        job.total or 0
      )
    )

    ImGui.SameLine(ctx, 0, 8)

    if dark_button("当前文件后停止", 132) then
      state.transfer_cancel_requested = true
    end
  elseif dark_button("导出当前素材", 160) then
    run_transfer(asset and { asset } or {}, false)
  else
    ImGui.SameLine(ctx, 0, 8)

    if dark_button(
      string.format(
        "%s (%d)",
        translate_ui_text("导出所选素材"),
        #selected
      ),
      190
    ) then
      run_transfer(selected, true)
    end
  end

  ImGui.SameLine(ctx, 0, 8)

  if dark_button("关闭", 100) then
    save_config()
    ImGui.CloseCurrentPopup(ctx)
  end

  ImGui.EndPopup(ctx)
end

function draw_settings_transfer()
  draw_transfer_settings_content()
end

function draw_settings_appearance()
  settings_section_title(
    "统一界面",
    ""
  )

  if dark_button("恢复统一界面", 170) then
    apply_unified_interface(true, true)
  end

  ImGui.Separator(ctx)

  settings_section_title(
    "浏览与工作区",
    "调整下方大波形与试听区域的高度。"
  )

  ImGui.SetNextItemWidth(ctx, 280)

  local panel_height_changed
  panel_height_changed, state.bottom_panel_height =
    ImGui.SliderDouble(
      ctx,
      "下方面板高度",
      state.bottom_panel_height,
      BOTTOM_MIN_H,
      BOTTOM_MAX_H,
      "%.0f px"
    )

  if panel_height_changed then
    state.config_dirty = true
  end

  ImGui.Separator(ctx)

  settings_section_title(
    "封面与元数据",
    ""
  )

  local changed
  changed, state.artwork_enabled =
    ImGui.Checkbox(
      ctx,
      "启用 Artwork",
      state.artwork_enabled
    )

  if changed then
    state.config_dirty = true
  end

  changed, state.inspector_artwork_pinned =
    ImGui.Checkbox(
      ctx,
      "元数据封面固定在顶部",
      state.inspector_artwork_pinned
    )

  if changed then
    state.config_dirty = true
  end

  if dark_button("清空 Artwork 缓存", 160) then
    clear_artwork_cache()
  end

  ImGui.Separator(ctx)

  settings_section_title(
    "颜色与状态",
    ""
  )

  local played_changed
  played_changed, state.played_text_enabled =
    ImGui.Checkbox(
      ctx,
      "已播放文字高亮",
      state.played_text_enabled
    )

  if played_changed then
    state.config_dirty = true
  end

  ImGui.SameLine(ctx)

  played_changed, state.played_waveform_enabled =
    ImGui.Checkbox(
      ctx,
      "已播放波形高亮",
      state.played_waveform_enabled
    )

  if played_changed then
    state.config_dirty = true
  end

  local restore_changed
  restore_changed, state.restore_played_on_start =
    ImGui.Checkbox(
      ctx,
      "启动时自动恢复上次浏览高亮",
      state.restore_played_on_start
    )

  if restore_changed then
    state.config_dirty = true
  end

  ImGui.TextDisabled(
    ctx,
    string.format(
      "%s %d　·　%s %d",
      translate_ui_text("当前高亮"),
      session_played_count(),
      translate_ui_text("上次记录"),
      last_session_played_count()
    )
  )

  if dark_button("恢复上次浏览高亮", 180) then
    restore_last_session_played_highlights()
  end

  ImGui.SameLine(ctx)

  if dark_button("清除本次已播放高亮", 180) then
    clear_session_played_highlights()
  end

  ImGui.SameLine(ctx)

  if dark_button("清除已保存浏览记录", 180) then
    clear_saved_session_played_highlights()
  end

  ImGui.Separator(ctx)

  settings_section_title(
    "外观模式",
    "黑暗模式为默认；传统模式使用更深的品牌藏蓝。"
  )

  for _, key in ipairs(
    {
      "dark",
      "heritage",
    }
  ) do
    local preset = APPEARANCE_PRESETS[key]
    local was_selected =
      state.theme_preset == key
      and state.surface_style == key

    if was_selected then
      ImGui.PushStyleColor(
        ctx,
        ImGui.Col_Button,
        THEME_PRESETS[key].accent
      )
    end

    local clicked = dark_button(preset.label, 176)

    if was_selected then
      ImGui.PopStyleColor(ctx)
    end

    if clicked then
      apply_appearance_preset(key)
    end

    if key ~= "heritage" then
      ImGui.SameLine(ctx)
    end
  end

  ImGui.TextDisabled(
    ctx,
    (
      state.surface_style == "custom"
        or state.theme_preset == "custom"
    )
      and (
        translate_ui_text("当前模式：")
          .. translate_ui_text("自定义")
      )
      or (
        translate_ui_text("当前模式：")
          .. (
            APPEARANCE_PRESETS[state.surface_style]
              and translate_ui_text(
                APPEARANCE_PRESETS[state.surface_style].label
              )
              or translate_ui_text(
                APPEARANCE_PRESETS.dark.label
              )
          )
      )
  )

  ImGui.Separator(ctx)

  settings_section_title(
    "自定义颜色",
    "底色控制整体框架，强调色用于选择与交互。"
  )

  draw_color_picker_row(
    "custom_shell_hex",
    "框架底色",
    "#101114",
    "surface"
  )

  draw_color_picker_row(
    "custom_accent_hex",
    "强调色",
    "#1F6FCC",
    "theme"
  )

  ImGui.Separator(ctx)

  settings_section_title(
    "波形配色",
    "普通、选中、已播放、标记、选区、播放指针与 Region。"
  )

  local palette_width =
    select(
      1,
      ImGui.GetContentRegionAvail(ctx)
    )

  local use_two_columns = palette_width >= 720

  if use_two_columns then
    if ImGui.BeginTable(
      ctx,
      "waveform_palette_table",
      2,
      ImGui.TableFlags_SizingStretchSame
    ) then
      for _, definition in ipairs(WAVEFORM_PALETTE_FIELDS) do
        ImGui.TableNextColumn(ctx)
        draw_waveform_palette_field(definition)
      end

      ImGui.EndTable(ctx)
    end
  else
    for _, definition in ipairs(WAVEFORM_PALETTE_FIELDS) do
      draw_waveform_palette_field(definition)
    end
  end

  if dark_button("恢复默认波形配色", 168) then
    reset_waveform_palette_defaults()
  end
end

function draw_settings_waveforms()
  ImGui.Text(ctx, "列表波形精度")

  for _, points in ipairs(
    {
      MINI_WAVE_DEFAULT_POINTS,
      MINI_WAVE_MAX_POINTS,
    }
  ) do
    local selected =
      state.mini_wave_points == points

    if selected then
      ImGui.PushStyleColor(
        ctx,
        ImGui.Col_Button,
        COLOR.selected
      )
    end

    local clicked =
      dark_button(
        tostring(points) .. " points",
        112
      )

    if selected then
      ImGui.PopStyleColor(ctx)
    end

    if clicked
      and state.mini_wave_points ~= points then
      state.mini_wave_points = points
      state.wave_queue = {}
      state.wave_queued = {}
      state.wave_checked = {}
      state.config_dirty = true
      set_status(
        string.format(
          "列表波形精度已设置为 %d 点；新精度将按需建立缓存",
          points
        )
      )
    end

    if points ~= MINI_WAVE_MAX_POINTS then
      ImGui.SameLine(ctx)
    end
  end

  ImGui.TextDisabled(
    ctx,
    "256 点：缓存较小；512 点：细节更多。"
  )

  local channel_lanes_changed
  channel_lanes_changed, state.multichannel_waveform =
    ImGui.Checkbox(
      ctx,
      "独立显示各声道",
      state.multichannel_waveform
    )

  if channel_lanes_changed then
    state.wave_queue = {}
    state.wave_queued = {}
    state.wave_checked = {}
    state.config_dirty = true
  end

  ImGui.TextDisabled(
    ctx,
    "立体声显示 L / R；多声道显示 CH 1–8。"
  )

  local spectral_changed
  local spectral_value
  spectral_changed, spectral_value =
    ImGui.Checkbox(
      ctx,
      "当前素材显示频谱峰值着色",
      state.spectral_peaks_enabled
    )

  if spectral_changed then
    AppState.set("spectral_peaks_enabled", spectral_value)
    AppState.mark_dirty("config_dirty")
  end

  ImGui.TextDisabled(
    ctx,
    "按需读取 REAPER 频谱峰值；只影响下方大波形，不扫描整个音效库。"
  )

  ImGui.Separator(ctx)
  ImGui.Text(ctx, "高精度预缓存")

  for _, points in ipairs(
    {
      2048,
      4096,
    }
  ) do
    local selected =
      state.precache_points == points

    if selected then
      ImGui.PushStyleColor(
        ctx,
        ImGui.Col_Button,
        COLOR.selected
      )
    end

    local clicked =
      dark_button(
        tostring(points) .. " points",
        112
      )

    if selected then
      ImGui.PopStyleColor(ctx)
    end

    if clicked then
      state.precache_points = points
      state.config_dirty = true
    end

    if points ~= 4096 then
      ImGui.SameLine(ctx)
    end
  end

  ImGui.Spacing(ctx)

  if dark_button(
    "预缓存全部音效库",
    160
  ) then
    start_wave_precache(
      state.precache_points,
      "all"
    )
  end

  if state.root_filter or state.library_filter_id then
    ImGui.SameLine(ctx)

    if dark_button(
      "预缓存当前音效库",
      170
    ) then
      start_wave_precache(
        state.precache_points,
        "current"
      )
    end
  end

  if state.precache_session then
    ImGui.SameLine(ctx)

    if dark_button("停止预缓存", 110) then
      state.precache_cancel_requested = true
    end

    local session = state.precache_session
    local collecting = session.phase == "collect"
    local total = collecting
      and (session.source_total or 0) or (session.total or 0)
    local completed = collecting
      and math.max(0, (session.collect_index or 1) - 1)
      or math.max(0, (session.index or 1) - 1)
    completed = math.min(completed, total)
    local fraction = total > 0 and completed / total or 0
    ImGui.TextDisabled(ctx, string.format(
      "%s %d / %d",
      collecting and "正在整理范围" or "正在预缓存",
      completed,
      total
    ))
    ImGui.ProgressBar(
      ctx,
      fraction,
      -1,
      18,
      string.format("%.1f%%", fraction * 100)
    )
  end

  ImGui.Spacing(ctx)
  ImGui.TextDisabled(
    ctx,
    "可在首次浏览大型库前预先生成高精度波形。"
  )

  ImGui.Separator(ctx)
  ImGui.Text(ctx, "缩放与擦播")

  local scrub_changed
  scrub_changed, state.wave_scrub_enabled =
    ImGui.Checkbox(
      ctx,
      "启用右键擦播",
      state.wave_scrub_enabled
    )

  if scrub_changed then
    state.config_dirty = true
  end

  local loop_selection_changed
  loop_selection_changed, state.loop_selection =
    ImGui.Checkbox(
      ctx,
      "选区完成后自动循环",
      state.loop_selection
    )

  if loop_selection_changed then
    state.config_dirty = true
  end

  ImGui.TextDisabled(
    ctx,
    "鼠标滚轮缩放；Shift+滚轮或中键拖动平移；双击重置；右键拖动擦播"
  )

  ImGui.Separator(ctx)
  ImGui.Text(ctx, "瞬态 Region 建议")

  local threshold_db =
    20 * math.log(
      math.max(
        state.transient_threshold,
        0.000001
      ),
      10
    )

  ImGui.SetNextItemWidth(ctx, 240)
  local changed
  changed, threshold_db =
    ImGui.SliderDouble(
      ctx,
      "阈值",
      threshold_db,
      -60,
      -1,
      "%.1f dBFS"
    )

  if changed then
    state.transient_threshold =
      10 ^ (threshold_db / 20)
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 240)
  changed, state.transient_smoothing_ms =
    ImGui.SliderDouble(
      ctx,
      "平滑时间",
      state.transient_smoothing_ms,
      0,
      80,
      "%.0f ms"
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 240)
  changed, state.transient_min_gap_ms =
    ImGui.SliderDouble(
      ctx,
      "最小间隔",
      state.transient_min_gap_ms,
      20,
      2000,
      "%.0f ms"
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 240)
  changed, state.transient_pre_ms =
    ImGui.SliderDouble(
      ctx,
      "Region 前置",
      state.transient_pre_ms,
      0,
      1000,
      "%.0f ms"
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 240)
  changed, state.transient_post_ms =
    ImGui.SliderDouble(
      ctx,
      "Region 后置",
      state.transient_post_ms,
      20,
      5000,
      "%.0f ms"
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 240)
  changed, state.transient_max_regions =
    ImGui.SliderDouble(
      ctx,
      "最大 Region 数",
      state.transient_max_regions,
      1,
      256,
      "%.0f"
    )

  if changed then
    state.transient_max_regions =
      math.floor(state.transient_max_regions + 0.5)
    state.config_dirty = true
  end

  changed, state.transient_replace_existing =
    ImGui.Checkbox(
      ctx,
      "替换已有瞬态建议",
      state.transient_replace_existing
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.Separator(ctx)
  ImGui.Text(ctx, "响度显示")

  local loudness_changed
  loudness_changed, state.show_loudness_metrics =
    ImGui.Checkbox(
      ctx,
      "显示响度统计",
      state.show_loudness_metrics
    )

  if loudness_changed then
    state.config_dirty = true

    if state.show_loudness_metrics then
      request_loudness_analysis(selected_asset(), false)
    else
      destroy_loudness_job(state.loudness_active)
      state.loudness_active = nil
      state.loudness_queue = {}
      state.loudness_queued = {}
    end
  end

  local metric_changed
  metric_changed, state.loudness_show_i =
    ImGui.Checkbox(
      ctx,
      "LUFS-I",
      state.loudness_show_i
    )
  ImGui.SameLine(ctx)
  local changed_m
  changed_m, state.loudness_show_m =
    ImGui.Checkbox(
      ctx,
      "LUFS-M max",
      state.loudness_show_m
    )
  ImGui.SameLine(ctx)
  local changed_s
  changed_s, state.loudness_show_s =
    ImGui.Checkbox(
      ctx,
      "LUFS-S max",
      state.loudness_show_s
    )
  ImGui.SameLine(ctx)
  local changed_tp
  changed_tp, state.loudness_show_tp =
    ImGui.Checkbox(
      ctx,
      "True Peak",
      state.loudness_show_tp
    )

  if metric_changed or changed_m or changed_s or changed_tp then
    state.config_dirty = true
    request_loudness_analysis(selected_asset(), false)
  end

  if dark_button("重新分析当前素材", 160) then
    state.show_loudness_metrics = true
    state.config_dirty = true
    request_loudness_analysis(selected_asset(), true)
  end

  ImGui.Separator(ctx)
  ImGui.Text(ctx, "估算响度匹配")

  loudness_changed, state.loudness_match =
    ImGui.Checkbox(
      ctx,
      "启用估算响度匹配",
      state.loudness_match
    )

  if loudness_changed then
    state.config_dirty = true
    update_preview_parameters()
  end

  ImGui.SetNextItemWidth(ctx, 220)
  local target_changed
  target_changed, state.loudness_target_db =
    ImGui.SliderDouble(
      ctx,
      "目标响度",
      state.loudness_target_db,
      -30,
      -6,
      "%.1f dB"
    )

  if target_changed then
    state.config_dirty = true
    update_preview_parameters()
  end

  ImGui.TextDisabled(
    ctx,
    "仅影响试听，不修改源文件，也不用于交付标准化。"
  )
  ImGui.Separator(ctx)

  if dark_button("清空波形缓存", 140) then
    clear_wave_cache()
  end
end

function draw_settings_maintenance()
  settings_section_title(
    "运行环境",
    ""
  )

  ImGui.PushID(ctx, "maintenance_runtime_card")
  ImGui.Indent(ctx, 8)
  about_info_row("REAPER 版本", reaper.GetAppVersion())
  about_info_row("操作系统", reaper.GetOS())
  about_info_row("ReaImGui", get_reaimgui_runtime_version())
  about_info_row(
    "SWS Extension",
    type(reaper.CF_CreatePreview) == "function"
      and "已检测"
      or "未检测"
  )
  about_info_row("试听后端", state.preview_backend)
  about_info_row("数据目录", DATA_DIR)
  about_info_row(
    "波形缓存",
    state.wave_cache_dir
      or WAVE_CACHE_DIR
  )
  ImGui.Unindent(ctx, 8)
  ImGui.PopID(ctx)
  ImGui.Spacing(ctx)

  if dark_button("打开数据目录", 140) then
    open_folder(DATA_DIR)
  end

  ImGui.SameLine(ctx)

  if dark_button("打开文档目录", 140) then
    if directory_exists(DOCS_DIR) then
      open_folder(DOCS_DIR)
    else
      set_status(
        "文档目录不存在：" .. DOCS_DIR,
        true
      )
    end
  end

  ImGui.SameLine(ctx)

  if dark_button("复制诊断信息", 140) then
    ImGui.SetClipboardText(
      ctx,
      build_diagnostics_text()
    )
    set_status("诊断信息已复制")
  end

  ImGui.Separator(ctx)

  settings_section_title(
    "波形缓存目录",
    "可以移动已有缓存，源音频不受影响。"
  )

  ImGui.PushID(ctx, "cache_directory_card")
  ImGui.Indent(ctx, 8)
  ImGui.TextDisabled(ctx, "当前缓存目录")
  ImGui.TextWrapped(
    ctx,
    state.wave_cache_dir
      or WAVE_CACHE_DIR
  )
  ImGui.TextDisabled(
    ctx,
    "默认："
      .. DEFAULT_WAVE_CACHE_DIR
  )
  ImGui.Unindent(ctx, 8)
  ImGui.PopID(ctx)
  ImGui.Spacing(ctx)

  if dark_button("更改缓存目录…", 150) then
    prompt_wave_cache_directory()
  end

  ImGui.SameLine(ctx)

  if dark_button("打开缓存目录", 140) then
    open_folder(
      state.wave_cache_dir
        or WAVE_CACHE_DIR
    )
  end

  ImGui.SameLine(ctx)

  if dark_button("恢复默认目录", 140) then
    restore_default_wave_cache_directory()
  end

  ImGui.Separator(ctx)

  settings_section_title(
    "UCS 分类",
    "先分帧预览现有库，再由你确认应用；人工分类不会被覆盖。"
  )

  ImGui.TextDisabled(ctx, string.format(
    "UCS %s · 分类器 %s · 当前待确认 %d",
    UCS_CATALOG_VERSION,
    UCS_CLASSIFIER_VERSION,
    state.ucs_pending_count
  ))

  local ucs_session = state.ucs_reclassification_session
  local ucs_review = state.ucs_reclassification_review
  if ucs_session then
    local completed = math.min(
      math.max(0, (ucs_session.index or 1) - 1),
      ucs_session.total or 0
    )
    local fraction = (ucs_session.total or 0) > 0
        and completed / ucs_session.total
      or 1
    local label = ucs_session.phase == "apply"
        and "正在应用 UCS 分类"
      or "正在预览 UCS 分类"
    ImGui.Text(ctx, string.format(
      "%s %d / %d · 自动 %d · 待确认 %d · 人工保护 %d",
      label,
      completed,
      ucs_session.total or 0,
      ucs_session.counts.auto,
      ucs_session.counts.pending,
      ucs_session.counts.manual
    ))
    ImGui.ProgressBar(
      ctx,
      fraction,
      -1,
      18,
      string.format("%.1f%%", fraction * 100)
    )
    if dark_button("取消 UCS 任务", 150) then
      cancel_ucs_reclassification()
    end
    if ucs_session.phase == "apply" then
      ImGui.SameLine(ctx)
      ImGui.TextDisabled(ctx, "停止后保留已安全应用的部分，可重新预览继续。")
    end
  elseif ucs_review then
    local counts = ucs_review.counts
    ImGui.Text(ctx, string.format(
      "预览完成：可更新 %d · 精确 %d · 自动 %d · 待确认 %d · 未分类 %d · 人工保护 %d",
      counts.changed,
      counts.exact,
      counts.auto,
      counts.pending,
      counts.unclassified,
      counts.manual
    ))
    ImGui.TextDisabled(ctx, string.format(
      "共检查 %d 条，耗时 %.2f 秒；应用前不会修改数据库。",
      ucs_review.total,
      ucs_review.elapsed or 0
    ))
    for _, sample in ipairs(ucs_review.samples or {}) do
      local target = sample.after ~= ""
          and sample.after
        or (sample.candidates ~= "" and sample.candidates or "未分类")
      ImGui.TextDisabled(ctx, compact(
        sample.name .. "  →  " .. target .. "  [" .. sample.status .. "]",
        118
      ))
    end
    if counts.changed > 0 and dark_button("确认应用分类", 150) then
      start_ucs_reclassification_apply()
    end
    if counts.changed > 0 then ImGui.SameLine(ctx) end
    if dark_button("丢弃预览", 130) then
      AppState.set("ucs_reclassification_review", nil)
      set_status("已丢弃 UCS 分类预览")
    end
  else
    if dark_button("预览现有库 UCS 分类", 190) then
      start_ucs_reclassification_preview()
    end
    ImGui.SameLine(ctx)
    ImGui.TextDisabled(ctx, "只更新 PsyReaSFX 索引，不改名、不移动、不回写源音频。")
  end

  if state.ucs_pending_count > 0 and not ucs_session then
    if dark_button("查看 UCS 待确认素材", 190) then
      AppState.set("view", "ucs_pending")
      AppState.set("active_collection_id", nil)
      AppState.set("root_filter", nil)
      AppState.set("library_filter_id", nil)
      AppState.mark_dirty("results_dirty")
      AppState.set("settings_close_requested", true)
    end
  end

  ImGui.Separator(ctx)

  settings_section_title(
    "路径与离线来源",
    "检查缺失文件，或在素材盘符和目录变化后重新定位来源；不会移动源文件。"
  )

  if state.missing_audit then
    local session = state.missing_audit
    local completed = math.min(session.checked or 0, session.total or 0)
    local fraction = session.total > 0 and completed / session.total or 1
    ImGui.Text(
      ctx,
      string.format(
        "缺失检查 %d / %d · 已发现 %d",
        completed,
        session.total or 0,
        session.missing or 0
      )
    )
    ImGui.ProgressBar(ctx, fraction, -1, 18, string.format("%.1f%%", fraction * 100))
  else
    ImGui.TextDisabled(
      ctx,
      string.format(
        "离线来源 %d · 缺失素材 %d",
        #state.offline_roots,
        state.missing_asset_count
      )
    )

    if dark_button("检查缺失文件", 150) then
      start_missing_audit()
    end

    if state.missing_asset_count > 0 then
      ImGui.SameLine(ctx)
      if dark_button("查看缺失素材", 150) then
        state.view = "missing"
        state.active_collection_id = nil
        state.root_filter = nil
        state.library_filter_id = nil
        state.results_dirty = true
        state.settings_close_requested = true
      end
    end
  end

  for _, record in ipairs(state.offline_roots) do
    ImGui.PushID(ctx, "offline_root_" .. tostring(record.id))
    ImGui.TextDisabled(
      ctx,
      compact((record.alias ~= "" and record.alias or basename(record.path)) .. " · " .. record.path, 112)
    )
    ImGui.SameLine(ctx)
    if dark_button("重新定位…", 112) then
      relink_root(record)
    end
    ImGui.PopID(ctx)
  end

  ImGui.Separator(ctx)

  settings_section_title(
    "重复候选",
    "仅对大小相同的文件读取头部、中部和尾部采样块；结果尚未经过完整内容确认，不会修改或删除源文件。"
  )

  if state.duplicate_scan then
    local session = state.duplicate_scan
    local phase = session.phase or "fingerprints"
    local completed = 0
    local total = 0
    local label = "重复检查"
    local fraction = 0
    if phase == "sizes" then
      label = "读取文件大小"
      total = session.asset_total or 0
      completed = math.min(
        math.max(0, (session.asset_index or 1) - 1),
        total
      )
      fraction = total > 0 and completed / total or 1
    elseif phase == "fingerprints" then
      label = "采样重复候选"
      total = session.total or 0
      completed = math.min(
        math.max(0, (session.index or 1) - 1),
        total
      )
      fraction = total > 0 and completed / total or 1
    else
      label = "整理候选组"
      total = #(session.duplicate_groups or {})
      local sort_job = session.sort_job
      if sort_job and sort_job.stage == "filter" then
        completed = math.min(
          math.max(0, (sort_job.index or 1) - 1),
          sort_job.total or total
        )
        total = sort_job.total or total
        fraction = total > 0 and completed / total * 0.25 or 0.25
      elseif sort_job and sort_job.stage == "sort_chunks" then
        completed = math.min(
          math.max(0, (sort_job.sort_index or 1) - 1),
          total
        )
        fraction = 0.25
          + (total > 0 and completed / total * 0.25 or 0.25)
      elseif sort_job and sort_job.stage == "merge" then
        completed = total
        fraction = 0.75
      else
        completed = total
        fraction = 0.95
      end
    end
    ImGui.Text(
      ctx,
      string.format(
        "%s %d / %d · 失败 %d",
        label,
        completed,
        total,
        session.failed or 0
      )
    )
    ImGui.ProgressBar(ctx, fraction, -1, 18, string.format("%.1f%%", fraction * 100))
  elseif state.duplicate_confirmation then
    local session = state.duplicate_confirmation
    ImGui.Text(ctx, string.format(
      "完整确认第 %d / %d 组 · 当前组已处理 %d",
      session.group_index,
      #session.groups,
      math.max(0, session.asset_index - 1)
    ))
    local fraction = #session.groups > 0
      and math.min(1, (session.group_index - 1) / #session.groups)
      or 1
    ImGui.ProgressBar(ctx, fraction, -1, 18, string.format("%.1f%%", fraction * 100))
  else
    ImGui.TextDisabled(
      ctx,
      string.format(
        "候选组 %d · 涉及素材 %d",
        state.duplicate_group_count,
        state.duplicate_asset_count
      )
    )
    if dark_button("检查重复候选", 150) then
      start_duplicate_scan()
    end
    if state.duplicate_asset_count > 0 then
      ImGui.SameLine(ctx)
      if dark_button("查看重复候选", 150) then
        state.view = "duplicates"
        state.active_collection_id = nil
        state.root_filter = nil
        state.library_filter_id = nil
        state.results_dirty = true
        state.settings_close_requested = true
      end
      ImGui.SameLine(ctx)
      if dark_button("完整确认候选", 150) then
        start_duplicate_confirmation()
      end
    end
    ImGui.TextDisabled(ctx, string.format(
      "已确认相同 %d · 读取失败 %d",
      state.duplicate_confirmed_asset_count,
      state.duplicate_confirmation_failure_count
    ))
  end

  ImGui.Separator(ctx)

  refresh_current_project_binding()
  settings_section_title(
    "当前 REAPER 工程",
    "记录插入和 Transfer 后插入的素材，并可自动收集到绑定的项目素材箱。"
  )
  about_info_row("工程", state.current_project_name or "未保存工程")
  if state.current_project_path ~= "" then
    ImGui.TextDisabled(ctx, compact(state.current_project_path, 112))
  end

  local collect_changed
  collect_changed, state.auto_collect_project_usage =
    ImGui.Checkbox(
      ctx,
      "自动将插入素材加入当前工程素材箱",
      state.auto_collect_project_usage
    )
  if collect_changed then
    state.config_dirty = true
  end

  if state.current_project_path == "" then
    ImGui.TextDisabled(ctx, "请先保存当前 REAPER 工程，再建立绑定。")
  elseif not state.current_project_bin_id then
    if dark_button("创建并绑定当前工程素材箱", 230) then
      ensure_current_project_bin(true)
    end
  else
    local project_bin = state.collection_by_id[state.current_project_bin_id]
    ImGui.TextDisabled(
      ctx,
      "已绑定：" .. (project_bin and project_bin.name or state.current_project_name)
    )
  end

  local usage_bucket = project_usage_bucket(state.current_project_path, false)
  if usage_bucket then
    ImGui.SameLine(ctx)
    if dark_button("查看当前工程已用素材", 190) then
      state.view = "project_used"
      state.active_collection_id = nil
      state.root_filter = nil
      state.library_filter_id = nil
      state.results_dirty = true
      state.settings_close_requested = true
    end
  end

  ImGui.Separator(ctx)

  settings_section_title(
    "可靠性与恢复",
    "失败任务、数据备份和缓存检查均不修改源音频。"
  )

  local failed_count = failed_task_count()
  ImGui.Text(
    ctx,
    string.format("失败任务：%d", failed_count)
  )

  if failed_count > 0 then
    local shown = 0

    for _, task in pairs(state.failed_tasks) do
      ImGui.TextDisabled(
        ctx,
        compact(
          basename(task.path)
            .. " · "
            .. tostring(task.stage)
            .. " · "
            .. tostring(task.reason),
          100
        )
      )
      shown = shown + 1
      if shown >= 5 then break end
    end

    if dark_button("重试全部失败任务", 170) then
      retry_failed_tasks()
    end

    ImGui.SameLine(ctx)

    if dark_button("清除失败记录", 140) then
      state.failed_tasks = {}
      state.failed_tasks_dirty = true
      state.last_save = 0
      schedule_auxiliary_save()
      set_status("失败任务记录已清除")
    end
  else
    ImGui.TextDisabled(ctx, "当前没有待处理的失败任务。")
  end

  ImGui.Spacing(ctx)

  local auto_backup_changed
  auto_backup_changed, state.auto_backup =
    ImGui.Checkbox(ctx, "每天自动备份一次数据", state.auto_backup)

  if auto_backup_changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 220)
  local keep_changed
  keep_changed, state.backup_keep_count =
    ImGui.SliderDouble(
      ctx,
      "保留备份数量",
      state.backup_keep_count,
      1,
      30,
      "%.0f"
    )

  if keep_changed then
    state.backup_keep_count = math.floor(state.backup_keep_count + 0.5)
    state.config_dirty = true
  end

  if dark_button("立即创建备份", 150) then
    if state.root_removal_session then
      set_status("请等待来源移除或回滚完成后再创建备份", true)
    else
      cancel_auxiliary_save("manual backup")
      if state.config_dirty then save_config() end
      if state.libraries_dirty then save_libraries() end
      if state.db_dirty and not state.scan and not state.import_session then save_database() end
      if state.collections_dirty then save_collections() end
      if state.searches_dirty then save_saved_searches() end
      if state.history_dirty then save_history() end
      if state.regions_dirty then save_regions() end
      if state.loudness_dirty then save_loudness_cache() end
      if state.failed_tasks_dirty then save_failed_tasks() end
      if state.project_usage_dirty then save_project_usage() end
      create_data_backup("manual", false)
    end
  end

  ImGui.SameLine(ctx)

  if dark_button("打开备份目录", 140) then
    open_folder(BACKUP_DIR)
  end

  ImGui.SameLine(ctx)

  if dark_button("恢复最近备份…", 150) then
    restore_latest_data_backup()
  end

  ImGui.Spacing(ctx)

  if state.cache_verify_session then
    local session = state.cache_verify_session
    local completed = math.min(session.index - 1, session.total)
    local fraction = session.total > 0 and completed / session.total or 1
    ImGui.Text(
      ctx,
      string.format(
        "缓存检查 %d / %d · 有效 %d · 损坏 %d",
        completed,
        session.total,
        session.valid,
        session.invalid
      )
    )
    ImGui.ProgressBar(ctx, fraction, -1, 18, string.format("%.1f%%", fraction * 100))
  elseif dark_button("检查波形缓存完整性", 190) then
    start_wave_cache_verification()
  end

  ImGui.TextDisabled(
    ctx,
    "损坏缓存会移入 cache_quarantine；需要时可从源音频重新生成。"
  )

  ImGui.Separator(ctx)

  settings_section_title(
    "维护操作",
    "重建和重置不会删除硬盘中的源音频文件。"
  )

  if dark_button("清空波形缓存", 140) then
    clear_wave_cache()
  end

  ImGui.SameLine(ctx)

  if dark_button("重置界面设置", 140) then
    reset_interface_settings()
  end

  ImGui.SameLine(ctx)

  if dark_button("重建数据库", 130) then
    reset_database_keep_roots()
  end

  ImGui.SameLine(ctx)

  if dark_button("恢复出厂", 110) then
    factory_reset()
  end

  ImGui.Spacing(ctx)

  ImGui.TextWrapped(
    ctx,
    "重建数据库会保留音效库路径并重新扫描；恢复出厂会删除 PsyReaSFX "
      .. "的配置、集合、历史、索引和当前缓存，但不会删除源音频文件。"
  )
end

function settings_nav_item(key, label, description)
  local selected =
    state.settings_tab == key

  local width =
    select(
      1,
      ImGui.GetContentRegionAvail(ctx)
    )

  local height = 58
  local x, y =
    ImGui.GetCursorScreenPos(ctx)

  ImGui.InvisibleButton(
    ctx,
    "settings_nav_" .. key,
    width,
    height
  )

  local clicked =
    ImGui.IsItemClicked(ctx, 0)

  local hovered =
    ImGui.IsItemHovered(ctx)

  if clicked then
    state.settings_tab = key
  end

  local draw_list =
    ImGui.GetWindowDrawList(ctx)

  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + width,
    y + height,
    selected
      and rgba_with_alpha(COLOR.selected, 0x24)
      or hovered
        and COLOR.button_hover
        or 0x00000000,
    UI_METRIC.radius_small
  )

  if selected then
    ImGui.DrawList_AddRectFilled(
      draw_list,
      x,
      y + 8,
      x + 4,
      y + height - 8,
      COLOR.selected,
      2
    )
  end

  draw_clipped_text(
    draw_list,
    x + 14,
    y + 10,
    selected
      and COLOR.selected_text
      or COLOR.header_text,
    translate_ui_text(label),
    x + 10,
    y + 5,
    x + width - 10,
    y + 31
  )

  draw_clipped_text(
    draw_list,
    x + 14,
    y + 34,
    COLOR.dim,
    translate_ui_text(description or ""),
    x + 10,
    y + 29,
    x + width - 10,
    y + height - 6
  )
end

function draw_settings_popup()
  ImGui.SetNextWindowSize(
    ctx,
    980,
    700,
    ImGui.Cond_Appearing
  )

  if not ImGui.BeginPopupModal(
    ctx,
    "设置##reasfx",
    true,
    ImGui.WindowFlags_NoScrollbar
      | ImGui.WindowFlags_NoScrollWithMouse
  ) then
    return
  end

  local width, height =
    ImGui.GetContentRegionAvail(ctx)

  local nav_width = 226
  local footer_height = 42

  if ImGui.BeginChild(
    ctx,
    "settings_navigation",
    nav_width,
    height - footer_height,
    ImGui.ChildFlags_Borders,
    ImGui.WindowFlags_NoScrollbar
  ) then
    ImGui.TextColored(
      ctx,
      COLOR.header_text,
      "设置中心"
    )

    ImGui.TextDisabled(
      ctx,
      SCRIPT_NAME .. " " .. VERSION
    )

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    settings_nav_item("general", "常规", "语言、面板与插入")
    settings_nav_item("appearance", "外观", "预设、颜色与 Artwork")
    settings_nav_item("waveforms", "波形", "精度、瞬态与响度")
    settings_nav_item("transfer", "传输", "处理、命名与导出")
    settings_nav_item("maintenance", "维护", "环境、缓存与重建")
    settings_nav_item("about", "关于", "版本、版权与项目主页")
  end

  ImGui.EndChild(ctx)
  ImGui.SameLine(ctx)

  if ImGui.BeginChild(
    ctx,
    "settings_content",
    width - nav_width - 8,
    height - footer_height,
    ImGui.ChildFlags_Borders,
    ImGui.WindowFlags_AlwaysVerticalScrollbar
  ) then
    local page_title = {
      general = "常规",
      appearance = "外观",
      waveforms = "波形",
      transfer = "Transfer 设置",
      maintenance = "维护",
      about = "关于",
    }

    ImGui.TextColored(
      ctx,
      COLOR.header_text,
      page_title[state.settings_tab]
        or "常规"
    )

    ImGui.Separator(ctx)

    if state.settings_tab == "appearance" then
      draw_settings_appearance()
    elseif state.settings_tab == "waveforms" then
      draw_settings_waveforms()
    elseif state.settings_tab == "transfer" then
      draw_settings_transfer()
    elseif state.settings_tab == "maintenance" then
      draw_settings_maintenance()
    elseif state.settings_tab == "about" then
      draw_settings_about()
    else
      draw_settings_general()
    end
  end

  ImGui.EndChild(ctx)
  ImGui.Separator(ctx)

  local button_width = 132

  ImGui.SetCursorPosX(
    ctx,
    math.max(
      0,
      width - button_width
    )
  )

  if dark_button("保存并关闭", button_width) then
    save_config()
    if state.db_dirty then save_database_changes() end
    ImGui.CloseCurrentPopup(ctx)
  end

  if state.settings_close_requested then
    state.settings_close_requested = false
    ImGui.CloseCurrentPopup(ctx)
  end

  ImGui.EndPopup(ctx)
end

----------------------------------------------------------------
-- Keyboard
----------------------------------------------------------------

function keyboard()
  if state.keyboard_consumed
    or state.parameter_edit
    or ImGui.IsAnyItemActive(ctx) then
    return
  end
  if state.root_removal_session then
    return
  end

  local mods = ImGui.GetKeyMods(ctx)
  local ctrl =
    (mods & ImGui.Mod_Ctrl) ~= 0

  if ctrl
    and ImGui.IsKeyPressed(
      ctx,
      ImGui.Key_A,
      false
    ) then
    select_all_results()
    return
  end

  if ctrl
    and ImGui.IsKeyPressed(
      ctx,
      ImGui.Key_F,
      false
    ) then
    state.focus_search = true
    return
  end

  if ctrl
    and ImGui.IsKeyPressed(
      ctx,
      ImGui.Key_R,
      false
    ) then
    start_scan("增量扫描")
    return
  end

  if ctrl
    and ImGui.IsKeyPressed(
      ctx,
      ImGui.Key_T,
      false
    ) then
    state.transfer_popup_requested = 2
    return
  end

  if ImGui.IsKeyPressed(
    ctx,
    ImGui.Key_F9,
    false
  ) then
    state.sidebar_visible =
      not state.sidebar_visible
    state.config_dirty = true
    return
  end

  if ImGui.IsKeyPressed(
    ctx,
    ImGui.Key_F10,
    false
  ) then
    state.inspector_visible =
      not state.inspector_visible
    state.config_dirty = true
    return
  end

  if ImGui.IsKeyPressed(
    ctx,
    ImGui.Key_F11,
    false
  ) then
    local focus_mode =
      not state.sidebar_visible
      and not state.inspector_visible

    if focus_mode then
      state.sidebar_visible = true
      state.inspector_visible = true
    else
      state.sidebar_visible = false
      state.inspector_visible = false
    end

    state.config_dirty = true
    return
  end

  if ImGui.IsKeyPressed(
    ctx,
    ImGui.Key_UpArrow,
    false
  ) then
    select_result(
      math.max(
        1,
        state.selected_index - 1
      )
    )
  elseif ImGui.IsKeyPressed(
    ctx,
    ImGui.Key_DownArrow,
    false
  ) then
    select_result(
      math.min(
        #state.results,
        math.max(
          1,
          state.selected_index + 1
        )
      )
    )
  elseif ImGui.IsKeyPressed(
    ctx,
    ImGui.Key_Space,
    false
  ) then
    if state.preview then
      request_preview_stop()
    else
      play_preview(nil, nil, true)
    end
  elseif state.enter_insert_shortcuts
    and ImGui.IsKeyPressed(
    ctx,
    ImGui.Key_Enter,
    false
  ) then
    if selected_count() > 1 then
      insert_selected_stack(0, 1)
    else
      insert_asset(nil, ctrl, false)
    end
  elseif ImGui.IsKeyPressed(
    ctx,
    ImGui.Key_F,
    false
  ) then
    local assets = selected_assets()

    if #assets <= 1 then
      toggle_favorite(selected_asset())
    else
      local all_favorite = true

      for _, asset in ipairs(assets) do
        if not state.favorites[path_key(asset.path)] then
          all_favorite = false
          break
        end
      end

      for _, asset in ipairs(assets) do
        state.favorites[path_key(asset.path)] =
          all_favorite and nil or true
      end

      state.config_dirty = true
      state.results_dirty = true
      set_status(
        all_favorite
          and "已取消所选素材收藏"
          or "已收藏所选素材"
      )
    end
  elseif ImGui.IsKeyPressed(
    ctx,
    ImGui.Key_M,
    false
  ) then
    local assets = selected_assets()

    if #assets == 0 then
      return
    end

    local all_marked = true

    for _, asset in ipairs(assets) do
      if not asset.marked then
        all_marked = false
        break
      end
    end

    set_assets_marked(
      assets,
      not all_marked
    )
  elseif ImGui.IsKeyPressed(
    ctx,
    ImGui.Key_L,
    false
  ) then
    state.loop = not state.loop
    update_preview_parameters()
  end
end

----------------------------------------------------------------
-- Main window
----------------------------------------------------------------

function push_theme()
  apply_ui_density_metrics()
  apply_theme_palette()
  apply_surface_style()

  local colors = {
    { ImGui.Col_WindowBg, COLOR.window },
    { ImGui.Col_TitleBg, COLOR.title },
    { ImGui.Col_TitleBgActive, COLOR.title_active },
    { ImGui.Col_TitleBgCollapsed, COLOR.title },
    { ImGui.Col_ChildBg, COLOR.panel },
    { ImGui.Col_PopupBg, COLOR.panel_alt },
    { ImGui.Col_Border, COLOR.grid },
    { ImGui.Col_Text, COLOR.text },
    { ImGui.Col_TextDisabled, COLOR.dim },
    { ImGui.Col_FrameBg, COLOR.button },
    { ImGui.Col_FrameBgHovered, COLOR.button_hover },
    { ImGui.Col_FrameBgActive, COLOR.button_hover },
    { ImGui.Col_Header, COLOR.selected },
    { ImGui.Col_HeaderHovered, COLOR.selected },
    { ImGui.Col_HeaderActive, COLOR.selected },
    { ImGui.Col_CheckMark, COLOR.border },
    { ImGui.Col_SliderGrab, COLOR.border },
    { ImGui.Col_SliderGrabActive, COLOR.selected_text },
    { ImGui.Col_ScrollbarBg, COLOR.window },
    { ImGui.Col_ScrollbarGrab, 0x55575DFF },
    { ImGui.Col_ScrollbarGrabHovered, 0x777A82FF },
  }

  for _, item in ipairs(colors) do
    ImGui.PushStyleColor(
      ctx,
      item[1],
      item[2]
    )
  end

  local profile =
    UI_DENSITY_PROFILES[state.ui_density]
    or UI_DENSITY_PROFILES.balanced

  ImGui.PushStyleVar(
    ctx,
    ImGui.StyleVar_WindowRounding,
    profile.radius
  )

  ImGui.PushStyleVar(
    ctx,
    ImGui.StyleVar_ChildRounding,
    profile.radius
  )

  ImGui.PushStyleVar(
    ctx,
    ImGui.StyleVar_FrameRounding,
    profile.radius_small
  )

  ImGui.PushStyleVar(
    ctx,
    ImGui.StyleVar_ItemSpacing,
    profile.item_x,
    profile.item_y
  )

  return #colors, 4
end

function pop_theme(color_count, var_count)
  ImGui.PopStyleVar(ctx, var_count)
  ImGui.PopStyleColor(ctx, color_count)
end

function draw_inspector_splitter(height)
  ImGui.InvisibleButton(
    ctx,
    "inspector_width_splitter",
    PANEL_GAP,
    height
  )

  if ImGui.IsItemHovered(ctx)
    or ImGui.IsItemActive(ctx) then
    ImGui.SetMouseCursor(
      ctx,
      ImGui.MouseCursor_ResizeEW
    )
  end

  if ImGui.IsItemActive(ctx)
    and not state.inspector_resize then
    state.inspector_resize = {
      mouse_x =
        select(1, ImGui.GetMousePos(ctx)),
      width = state.inspector_width,
    }
  end

  if ImGui.IsItemActive(ctx)
    and state.inspector_resize then
    mark_interaction()

    local mouse_x =
      select(1, ImGui.GetMousePos(ctx))

    state.inspector_width =
      clamp(
        state.inspector_resize.width
          + state.inspector_resize.mouse_x
          - mouse_x,
        240,
        480
      )

    state.config_dirty = true
  end

  if state.inspector_resize
    and ImGui.IsMouseReleased(ctx, 0) then
    state.inspector_resize = nil
  end
end

function draw_main()
  -- 每帧重置，只有当前真正悬停的控件可以登记一个提示。
  state.tooltip_pending_text = nil
  state.keyboard_consumed = false

  ImGui.SetNextWindowSize(
    ctx,
    1360,
    840,
    ImGui.Cond_FirstUseEver
  )

  local color_count, var_count =
    push_theme()

  local was_open = state.open
  local visible
  visible, state.open =
    ImGui.Begin(
      ctx,
      SCRIPT_NAME
        .. " "
        .. VERSION
        .. "###PsyReaSFX",
      state.open,
      ImGui.WindowFlags_NoCollapse
        | ImGui.WindowFlags_NoScrollbar
        | ImGui.WindowFlags_NoScrollWithMouse
    )

  if was_open and not state.open then
    AppState.set("clean_shutdown_requested", true)
  end

  if visible then
    -- PsyReaSFX owns Space and the other browser shortcuts while its main
    -- window (or any child panel) is focused. Explicit capture prevents the
    -- same Space press from also reaching REAPER's global transport action.
    if ImGui.IsWindowFocused(
      ctx,
      ImGui.FocusedFlags_RootAndChildWindows
    ) then
      ImGui.SetNextFrameWantCaptureKeyboard(
        ctx,
        true
      )
    end

    draw_toolbar()
    draw_sub_toolbar()
    draw_path_condition_bar()
    draw_import_progress()
    ImGui.Separator(ctx)

    local width, height =
      ImGui.GetContentRegionAvail(ctx)

    local content_height = math.max(170, height)

    local render_sidebar = state.sidebar_visible
    local render_inspector = state.inspector_visible

    local sidebar_width =
      render_sidebar
      and clamp(
        width * 0.15,
        SIDEBAR_MIN_W,
        SIDEBAR_W
      )
      or 0

    local inspector_width =
      render_inspector
      and clamp(
        state.inspector_width,
        INSPECTOR_MIN_W,
        math.max(
          INSPECTOR_MIN_W,
          width * 0.30
        )
      )
      or 0

    local function current_gap_total()
      local gap = 0

      if render_sidebar then
        gap = gap + PANEL_GAP
      end

      if render_inspector then
        gap = gap + PANEL_GAP
      end

      return gap
    end

    -- 窗口变窄时先压缩侧栏，再临时折叠右栏和左栏。
    -- 这里只影响本帧布局，不修改用户保存的面板开关。
    local center_width =
      width
        - sidebar_width
        - inspector_width
        - current_gap_total()

    if center_width < CENTER_MIN_W
      and render_inspector then
      local deficit = CENTER_MIN_W - center_width
      local reducible =
        math.max(
          0,
          inspector_width - INSPECTOR_MIN_W
        )
      local reduction = math.min(deficit, reducible)
      inspector_width = inspector_width - reduction
      center_width = center_width + reduction
    end

    if center_width < CENTER_MIN_W
      and render_sidebar then
      local deficit = CENTER_MIN_W - center_width
      local reducible =
        math.max(
          0,
          sidebar_width - SIDEBAR_MIN_W
        )
      local reduction = math.min(deficit, reducible)
      sidebar_width = sidebar_width - reduction
      center_width = center_width + reduction
    end

    state.layout_notice = ""

    if center_width < CENTER_MIN_W
      and render_inspector then
      render_inspector = false
      inspector_width = 0
      center_width =
        width
          - sidebar_width
          - current_gap_total()
      state.layout_notice =
        "窗口较窄：右侧元数据面板已临时折叠"
    end

    if center_width < CENTER_MIN_W
      and render_sidebar then
      render_sidebar = false
      sidebar_width = 0
      center_width = width
      state.layout_notice =
        "窗口较窄：左右面板已临时折叠"
    end

    center_width =
      math.max(220, center_width)

    if render_sidebar then
      if begin_module(
        "aether_sidebar",
        sidebar_width,
        content_height,
        true
      ) then
        draw_sidebar()
      end

      end_module()
      ImGui.SameLine(ctx)
    end

    if ImGui.BeginChild(
      ctx,
      "center_workspace",
      center_width,
      content_height,
      0,
      ImGui.WindowFlags_NoScrollbar
        | ImGui.WindowFlags_NoScrollWithMouse
    ) then
      local center_available_w,
        center_available_h =
          ImGui.GetContentRegionAvail(ctx)

      -- 运行时尺寸必须严格相加等于可用高度。旧算法在矮窗口中
      -- 同时强制列表 >= 120 和预览 >= 220，曾导致底部越界裁切。
      local panel_space =
        math.max(
          2,
          center_available_h - BOTTOM_SPLITTER_H
        )

      local runtime_min_list =
        math.min(
          120,
          math.max(24, panel_space * 0.34),
          panel_space * 0.55
        )

      local maximum_bottom =
        math.max(
          1,
          math.min(
            BOTTOM_MAX_H,
            panel_space - runtime_min_list
          )
        )

      local runtime_min_bottom =
        math.min(
          BOTTOM_MIN_H,
          maximum_bottom
        )

      local bottom_height =
        clamp(
          state.bottom_panel_height,
          runtime_min_bottom,
          maximum_bottom
        )

      local list_height =
        math.max(1, panel_space - bottom_height)

      if begin_module(
        "results_module",
        center_available_w,
        list_height,
        false,
        true
      ) then
        draw_results()
      end

      end_module()

      draw_bottom_splitter(
        center_available_w,
        center_available_h
      )

      if begin_module(
        "bottom_module",
        center_available_w,
        bottom_height,
        false,
        true
      ) then
        draw_bottom(selected_asset())
      end

      end_module()
    end

    ImGui.EndChild(ctx)

    if render_inspector then
      ImGui.SameLine(ctx)
      draw_inspector_splitter(content_height)
      ImGui.SameLine(ctx)

      if begin_module(
        "metadata_inspector",
        inspector_width,
        content_height,
        false
      ) then
        draw_metadata_inspector()
      end

      end_module()
    end

    draw_help_popup()
    draw_transient_detection_popup()
    draw_transfer_popup()
    draw_settings_popup()
    draw_folder_drop_choice_popup()
    keyboard()
    process_external_drag()
    draw_tooltip_overlay()

    ImGui.End(ctx)
  end

  pop_theme(color_count, var_count)
end

----------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------

function autosave()
  if state.persistence_read_only then
    return
  end
  if state.root_removal_session then
    return
  end

  local now = reaper.time_precise()

  if now - state.last_save
    < SAVE_INTERVAL then
    return
  end

  if state.config_dirty then
    save_config()
  end

  if state.libraries_dirty then
    save_libraries()
  end

  if state.db_dirty
    and not state.scan
    and not state.import_session
    and not state.asset_binding_refresh
    and not state.artwork_reset_session
    and not state.database_snapshot_session then
    save_database_changes()
  end

  if state.searches_dirty then
    save_saved_searches()
  end

  schedule_auxiliary_save()

  state.last_save = now
end

function watch_folders()
  if state.persistence_read_only
    or not state.watch_enabled
    or state.scan
    or state.import_session
    or state.artwork_reset_session
    or state.root_removal_session
    or state.database_snapshot_session
    or state.precache_session
    or state.transfer_running then
    return
  end

  local now = reaper.time_precise()

  if now >= state.next_watch then
    start_scan(
      "Watch Folder",
      nil,
      {
        silent = state.watch_silent,
        checkpoint_enabled = false,
      }
    )
    state.next_watch =
      now + state.watch_interval
  end
end

function cleanup()
  Jobs.stop_accepting()
  cancel_auxiliary_save("shutdown")
  if state.root_removal_session then
    local removal = state.root_removal_session
    for index = #removal.cleanup_records, 1, -1 do
      restore_root_removal_record(removal.cleanup_records[index])
    end
    flush_root_removal_asset_changes(removal, false)
    state.root_removal_session = nil
    Jobs.finish(removal.job_token, true, "shutdown rollback")
  end
  cancel_database_snapshot("shutdown")
  stop_preview()
  cleanup_retired_preview_sources(true)
  if state.wave_active
    and state.wave_active.job_token then
    Jobs.cancel(state.wave_active.job_token)
    Jobs.finish(
      state.wave_active.job_token,
      true,
      "shutdown"
    )
    state.wave_active.job_token = nil
  end
  destroy_wave_job(state.wave_active)

  if state.transfer_job then
    finish_transfer_job(state.transfer_job, true)
  end

  for key in pairs(state.artwork_images) do
    release_artwork_image(key)
  end

  if state.precache_session
    and state.precache_session.current then
    destroy_wave_job(
      state.precache_session.current
    )
  end

  if state.precache_session then
    Jobs.cancel(state.precache_session.job_token)
    Jobs.finish(
      state.precache_session.job_token,
      true,
      "shutdown"
    )
  end

  if state.import_session
    and state.import_session.current
    and state.import_session.current.wave_job then
    destroy_wave_job(
      state.import_session.current.wave_job
    )
  end

  if state.import_session then
    Jobs.cancel(state.import_session.job_token)
    Jobs.finish(
      state.import_session.job_token,
      true,
      "shutdown"
    )
  elseif state.scan then
    Jobs.cancel(state.scan.job_token)
    Jobs.finish(
      state.scan.job_token,
      true,
      "shutdown"
    )
  end

  local maintenance_sessions = {
    state.artwork_reset_session,
    state.cache_verify_session,
    state.missing_audit,
    state.duplicate_scan,
    state.duplicate_confirmation,
    state.relink_plan_session,
    state.ucs_reclassification_session,
  }

  for _, session in pairs(maintenance_sessions) do
    if session and session.job_token then
      close_duplicate_confirmation_session(session)
      Jobs.cancel(session.job_token)
      Jobs.finish(
        session.job_token,
        true,
        "shutdown"
      )
    end
  end

  destroy_loudness_job(state.loudness_active)

  if state.skip_persistence_on_cleanup
    or state.persistence_read_only then
    return
  end

  if state.asset_binding_refresh
    and (state.asset_binding_refresh.changed_count or 0) > 0 then
    -- The deferred pass may have changed objects that have not reached its
    -- incremental persistence phase yet. Preserve them on an early exit.
    mark_database_snapshot_dirty()
  end

  if state.config_dirty then
    save_config()
  end

  if state.libraries_dirty then
    save_libraries()
  end

  if state.db_dirty then
    save_database()
  end

  if state.collections_dirty then
    save_collections()
  end

  if state.searches_dirty then
    save_saved_searches()
  end

  if state.history_dirty then
    save_history()
  end

  if state.session_played_dirty then
    save_last_played_session()
  end

  if state.regions_dirty then
    save_regions()
  end

  if state.loudness_dirty then
    save_loudness_cache()
  end

  if state.failed_tasks_dirty then
    save_failed_tasks()
  end

  if state.project_usage_dirty then
    save_project_usage()
  end

  -- Closing the PsyReaSFX window is a clean stop, not an interrupted scan.
  -- Keep checkpoints only when the script actually terminates unexpectedly.
  if state.clean_shutdown_requested then
    clear_scan_checkpoint()
  end

end

reaper.atexit(cleanup)

ensure_dirs()
recover_atomic_data_files()
preflight_persistence_schemas()
if not state.persistence_read_only then
  migrate_legacy_data()
end
load_or_migrate_project_url()
load_config()
state.next_watch = reaper.time_precise() + state.watch_interval
load_or_migrate_libraries()
apply_unified_interface(false, false)
apply_wave_cache_directory(
  state.wave_cache_dir
    or DEFAULT_WAVE_CACHE_DIR
)
install_i18n_wrappers()
load_database()
refresh_all_asset_library_bindings()
load_failed_tasks()
load_backup_state()

if state.root_filter then
  local _, active_root_record =
    root_for_path(state.root_filter)

  if active_root_record then
    state.library_filter_id =
      active_root_record.library_id
  else
    state.root_filter = nil
  end
end

if state.folder_browser_open then
  ensure_folder_navigation_build()
end

load_collections()
load_project_usage()
refresh_current_project_binding()
load_saved_searches()
load_history()
load_last_played_session()

if state.restore_played_on_start then
  restore_last_session_played_highlights(true)
end

load_regions()
load_loudness_cache()
schedule_legacy_schema_migrations()
apply_surface_style()
apply_theme_palette()
apply_waveform_palette()
state.results_dirty = true

if not state.persistence_read_only
  and state.auto_backup
  and state.backup_last_date ~= os.date("%Y%m%d") then
  create_data_backup("auto", true)
end

local interrupted_scan = state.resume_scan_on_start
  and load_scan_checkpoint()
  or nil

if state.persistence_read_only then
  set_status(
    "数据格式只读保护已启用；浏览可用，扫描与保存已暂停",
    true
  )
elseif interrupted_scan then
  start_scan(
    "恢复中断扫描",
    interrupted_scan.roots,
    { force_rebuild = interrupted_scan.force_rebuild }
  )
elseif #state.roots > 0 and #state.assets == 0 then
  start_scan("首次扫描")
elseif #state.roots > 0 then
  start_import_recovery_audit()
end

function loop()
  if not state.open then
    return
  end

  process_asset_library_binding_refresh()
  process_import_recovery_audit()

  if state.transfer_running then
    -- Transfer receives the background-work budget while active. Library
    -- scanning, waveform generation, Artwork and loudness analysis resume
    -- automatically after the job finishes or is stopped.
    process_transfer_job()
  elseif state.relink_plan_session then
    process_relink_plan()
  elseif state.root_removal_session then
    process_root_removal()
  elseif state.artwork_reset_session then
    process_artwork_cache_reset()
  elseif state.ucs_reclassification_session then
    process_ucs_reclassification()
  elseif state.database_snapshot_session then
    process_database_snapshot()
  else
    process_scan()
    process_import_session()
    process_metadata_queue()
    process_folder_navigation_build()
    process_artwork_queue()
    process_wave_cache_verification()
    process_missing_audit()
    process_duplicate_scan()
    process_duplicate_confirmation()
    process_wave_precache()
    process_wave_queue()
    process_pending_transient_detection()
    process_loudness_queue()
  end
  process_library_count_rebuild()
  process_ucs_count_rebuild()
  process_auxiliary_save()
  cleanup_retired_preview_sources(false)
  poll_preview()
  poll_current_project_binding()
  watch_folders()
  autosave()

  if state.results_dirty or state.results_job then
    process_results_rebuild()
  end

  draw_main()

  if state.open then
    reaper.defer(loop)
  end
end

loop()
