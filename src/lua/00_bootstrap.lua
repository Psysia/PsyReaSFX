-- @description PsyReaSFX - 高性能内联波形音效浏览器
-- @version 0.8.5
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
--
--   必需：ReaImGui 0.10+
--   推荐：SWS Extension（高级试听、Pitch、Rate、Loop、定位播放）
--
--   数据目录：
--   <REAPER Resource Path>/Scripts/PsyReaSFX/

local SCRIPT_NAME = "PsyReaSFX"
local VERSION = "0.8.5"
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

I18N_PATTERNS_EN = {
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
