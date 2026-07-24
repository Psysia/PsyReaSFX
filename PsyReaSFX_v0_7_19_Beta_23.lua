-- @description PsyReaSFX - 高性能内联波形音效浏览器
-- @version 0.7.19-beta.23
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
--
--   必需：ReaImGui 0.10+
--   推荐：SWS Extension（高级试听、Pitch、Rate、Loop、定位播放）
--
--   数据目录：
--   <REAPER Resource Path>/Scripts/PsyReaSFX/

local SCRIPT_NAME = "PsyReaSFX"
local VERSION = "0.7.19 Beta 23"
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
  library_filter_id = nil,
  expanded_libraries = {},
  pending_folder_drop = nil,
  assets = {},
  by_path = {},
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

  -- 当前启动会话的已播放颜色。完整历史仍保存到 history_v1.tsv。
  session_played = {},

  -- 上次浏览会话单独保存，用户可手动或自动恢复。
  last_session_played = {},
  session_played_dirty = false,
  restore_played_on_start = false,

  status_filter = nil,

  results = {},
  search = "",
  view = "all", -- all / favorites / recent
  root_filter = nil,
  sort_mode = "name",
  sort_desc = false,
  results_dirty = true,

  selected_index = 0,
  selected_path = nil,
  selected_set = {},
  selection_anchor = 0,

  -- 导入阶段的素材保持隐藏，直到元数据与缩略波形全部准备完成。
  import_session = nil,
  import_cancel_requested = false,

  -- 从列表/大波形拖到 REAPER 编排区。
  external_drag = nil,
  external_drag_started = false,

  auto_preview = true,
  watch_enabled = true,
  next_watch = reaper.time_precise() + WATCH_INTERVAL,

  scan = nil,

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
  ["插入：Enter 插入；Ctrl+Enter 插入新轨；"] =
    "Insert: Enter inserts; Ctrl+Enter inserts on a new track;",
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

I18N_PATTERNS_EN = {
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

  return text
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
  ensure_dirs()

  local file =
    io.open(
      LAST_PLAYED_SESSION_FILE,
      "wb"
    )

  if not file then
    set_status(
      "无法保存上次浏览高亮",
      true
    )
    return false
  end

  for key in pairs(state.session_played) do
    file:write(
      "played\t",
      escape_tsv(key),
      "\n"
    )
  end

  file:close()

  state.last_session_played =
    copy_path_set(
      state.session_played
    )

  state.session_played_dirty = false
  return true
end

function restore_last_session_played_highlights(silent)
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
  state.last_session_played = {}
  os.remove(LAST_PLAYED_SESSION_FILE)

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

  if reaper.GetOS():match("Win") then
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
  path = normalize_slashes(trim(path))

  if path == "" then
    return false
  end

  -- os.rename(path, path) also succeeds for regular files on Windows.
  -- Keep file drops out of the source-folder model explicitly.
  if reaper.file_exists(path) then
    return false
  end

  local ok, _, code = os.rename(path, path)
  return ok or code == 13
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
    record.path = canonical_source_path(record.path)
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


function refresh_asset_library_binding(asset)
  local root, record = root_for_path(asset.path)
  local library = library_for_root_record(record)

  asset.root = root or ""
  asset.root_id = record and record.id or ""
  asset.library_id = library and library.id or ""
  asset.library = library and library.name
    or library_for_path(asset.path, root)
  asset._search_blob = nil
  state.library_counts_dirty = true
end

function refresh_all_asset_library_bindings()
  for _, asset in ipairs(state.assets) do
    refresh_asset_library_binding(asset)
  end

  state.results_dirty = true
  state.db_dirty = true
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
    io.open(
      PROJECT_URL_FILE,
      "wb"
    )

  if not file then
    return false
  end

  file:write(url, "\n")
  file:close()
  return true
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
      reaper.EnumerateFiles(
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

function copy_file(source_path, target_path)
  local input = io.open(source_path, "rb")

  if not input then
    return false
  end

  local content = input:read("*a")
  input:close()

  local output = io.open(target_path, "wb")

  if not output then
    return false
  end

  output:write(content or "")
  output:close()
  return true
end

function copy_file_streaming(
  source_path,
  target_path
)
  local input =
    io.open(source_path, "rb")

  if not input then
    return false
  end

  local temporary_path =
    target_path .. ".psyreasfx_tmp"

  local output =
    io.open(temporary_path, "wb")

  if not output then
    input:close()
    return false
  end

  local ok = true

  while true do
    local chunk = input:read(1024 * 1024)

    if not chunk then
      break
    end

    if not output:write(chunk) then
      ok = false
      break
    end
  end

  input:close()
  output:close()

  if not ok then
    os.remove(temporary_path)
    return false
  end

  os.remove(target_path)

  if not os.rename(
    temporary_path,
    target_path
  ) then
    os.remove(temporary_path)
    return false
  end

  return true
end

function reset_wave_cache_runtime()
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

  reaper.RecursiveCreateDirectory(
    new_directory,
    0
  )

  local filenames = {}
  local index = 0

  while true do
    local filename =
      reaper.EnumerateFiles(
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

    if reaper.file_exists(target_path) then
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
    reaper.RecursiveCreateDirectory(
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
    reaper.GetUserInputs(
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
    reaper.MB(
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
    reaper.MB(
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

  if not reaper.file_exists(CONFIG_FILE)
    and reaper.file_exists(LEGACY_CONFIG_FILE) then
    if copy_file(LEGACY_CONFIG_FILE, CONFIG_FILE) then
      set_status("已迁移旧版音效库路径与偏好设置")
    end
  end
end

----------------------------------------------------------------
-- UCS and placeholder assets
----------------------------------------------------------------

function parse_ucs_filename(filename)
  local stem = strip_extension(filename)
  local tokens = {}

  for token in stem:gmatch("[^_%-%s]+") do
    tokens[#tokens + 1] = token
  end

  local result = {
    catid = "",
    category = tokens[1] or "",
    subcategory = tokens[2] or "",
  }

  if tokens[1]
    and tokens[1]:match("^[A-Z][A-Z0-9]+$") then
    result.catid = tokens[1]
  end

  return result
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

  return {
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
  }
end

function add_or_update_asset(asset)
  local key = path_key(asset.path)
  local existing = state.by_path[key]

  if existing then
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

    existing.artwork_checked =
      tostring(existing.artwork_path or "") ~= ""

    existing._search_blob = nil
    state.library_counts_dirty = true
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
  state.library_counts_dirty = true
  return asset
end

function rebuild_assets()
  state.assets = {}

  for _, asset in pairs(state.by_path) do
    state.assets[#state.assets + 1] = asset
  end

  state.results_dirty = true
  state.library_counts_dirty = true
end

----------------------------------------------------------------
-- Persistence
----------------------------------------------------------------

local DB_FIELDS = {
  "path",
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
}

function save_libraries()
  ensure_dirs()

  local file = io.open(LIBRARIES_FILE, "wb")

  if not file then
    set_status("无法保存音效库结构", true)
    return false
  end

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
      "\n"
    )
  end

  file:close()
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

    if fields[1] == "root"
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
      elseif name == "auto_preview" then
        state.auto_preview = value == "1"
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
  ensure_dirs()

  local file = io.open(CONFIG_FILE, "wb")

  if not file then
    set_status("无法保存配置", true)
    return
  end

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

  file:write(
    "setting\twatch\t",
    state.watch_enabled and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tauto_preview\t",
    state.auto_preview and "1" or "0",
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

  file:close()
  state.config_dirty = false
end

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
  ensure_dirs()

  local file = io.open(REGIONS_FILE, "wb")

  if not file then
    set_status("无法保存 Region 数据", true)
    return
  end

  for _, regions in pairs(state.regions_by_path) do
    for _, region in ipairs(regions) do
      file:write(
        escape_tsv(region.path or ""),
        "\t",
        tostring(region.start or 0),
        "\t",
        tostring(region.finish or 0),
        "\t",
        escape_tsv(region.name or ""),
        "\t",
        escape_tsv(region.source or "manual"),
        "\t",
        tostring(region.batch_id or 0),
        "\n"
      )
    end
  end

  file:close()
  state.regions_dirty = false
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
    reaper.GetUserInputs(
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
  ensure_dirs()

  local file = io.open(LOUDNESS_FILE, "wb")

  if not file then
    set_status("无法保存响度缓存", true)
    return
  end

  for _, entry in pairs(state.loudness_cache) do
    file:write(
      escape_tsv(entry.path or ""),
      "\t",
      tostring(entry.size or 0),
      "\t",
      tostring(entry.lufs_i or ""),
      "\t",
      tostring(entry.lufs_m or ""),
      "\t",
      tostring(entry.lufs_s or ""),
      "\t",
      tostring(entry.true_peak or ""),
      "\n"
    )
  end

  file:close()
  state.loudness_dirty = false
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
    or not reaper.file_exists(asset.path)
    or type(reaper.CalculateNormalization) ~= "function" then
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

function destroy_loudness_job(job)
  if job and job.source then
    reaper.PCM_Source_Destroy(job.source)
    job.source = nil
  end
end

function process_loudness_queue()
  if not state.show_loudness_metrics
    or state.scan
    or state.import_session
    or not can_run_heavy_job() then
    return
  end

  local now = reaper.time_precise()

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
      reaper.PCM_Source_CreateFromFile(
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
      reaper.PCM_Source_Destroy(source)
      return
    end

    state.loudness_active = {
      key = queued.key,
      asset = queued.asset,
      source = source,
      entry = entry,
      metrics = pending,
      index = 1,
    }
  end

  local job = state.loudness_active
  local metric = job.metrics[job.index]

  if not metric then
    state.loudness_cache[job.key] = job.entry
    state.loudness_dirty = true
    destroy_loudness_job(job)
    state.loudness_active = nil
    return
  end

  local ok, gain =
    pcall(
      reaper.CalculateNormalization,
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
    reaper.CF_Preview_SetValue,
    preview,
    "D_PAN",
    pan
  )

  local use_centered_mono =
    state.preview_channel_mode == "left"
      or state.preview_channel_mode == "right"
      or state.preview_channel_mode == "mono"

  pcall(
    reaper.CF_Preview_SetValue,
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

  local ignored = 0

  for line in file:lines() do
    local values = split_tsv(line)
    local asset = {}

    for index, field in ipairs(headers) do
      asset[field] = values[index] or ""
    end

    if asset.path and asset.path ~= ""
      and not is_ignored_media_path(asset.path) then
      asset.duration = tonumber(asset.duration) or 0
      asset.channels = tonumber(asset.channels) or 0
      asset.sample_rate = tonumber(asset.sample_rate) or 0
      asset.bit_depth = tonumber(asset.bit_depth) or 0
      asset.size = tonumber(asset.size) or 0
      asset.workflow_status =
        WORKFLOW_STATUS[asset.workflow_status]
        and asset.workflow_status
        or "none"
      asset.marked =
        asset.marked == "1"
        or asset.marked == "true"
      asset.preview_count =
        tonumber(asset.preview_count) or 0
      asset.last_previewed =
        tonumber(asset.last_previewed) or 0
      asset.indexed =
        asset.indexed == "1"
        or asset.indexed == "true"
        or asset.duration > 0
      asset.ready =
        asset.ready == "1"
        or asset.ready == "true"
      asset.used_count = tonumber(asset.used_count) or 0
      asset.last_used = tonumber(asset.last_used) or 0

      add_or_update_asset(asset)
    elseif asset.path and asset.path ~= "" then
      ignored = ignored + 1
    end
  end

  file:close()

  if ignored > 0 then
    state.db_dirty = true
    set_status(
      string.format(
        "已从索引自动忽略 %d 个系统元数据文件",
        ignored
      )
    )
  end
end

function save_database()
  ensure_dirs()

  local file = io.open(DATABASE_FILE, "wb")

  if not file then
    set_status("无法保存索引", true)
    return
  end

  file:write(table.concat(DB_FIELDS, "\t"), "\n")

  local ordered = {}

  for _, asset in ipairs(state.assets) do
    ordered[#ordered + 1] = asset
  end

  table.sort(
    ordered,
    function(a, b)
      return path_key(a.path)
        < path_key(b.path)
    end
  )

  for _, asset in ipairs(ordered) do
    local fields = {}

    for _, field in ipairs(DB_FIELDS) do
      local value = asset[field]

      if field == "indexed" then
        value = asset.indexed and "1" or "0"
      elseif field == "ready" then
        value = asset.ready and "1" or "0"
      elseif field == "marked" then
        value = asset.marked and "1" or "0"
      end

      fields[#fields + 1] =
        escape_tsv(value)
    end

    file:write(
      table.concat(fields, "\t"),
      "\n"
    )
  end

  file:close()
  state.db_dirty = false
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
  ensure_dirs()

  local file = io.open(COLLECTIONS_FILE, "wb")

  if not file then
    set_status("无法保存播放列表", true)
    return
  end

  for _, collection in ipairs(state.collections) do
    file:write(
      "collection\t",
      escape_tsv(collection.id),
      "\t",
      escape_tsv(collection.name),
      "\t",
      escape_tsv(collection.kind or "playlist"),
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

  file:close()
  state.collections_dirty = false
end

function create_collection(kind)
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
    items = {},
    order = {},
    count = 0,
  }

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
      }
    end
  end

  file:close()
end

function save_saved_searches()
  ensure_dirs()

  local file = io.open(SAVED_SEARCHES_FILE, "wb")

  if not file then
    set_status("无法保存搜索条件", true)
    return
  end

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
      "\n"
    )
  end

  file:close()
  state.searches_dirty = false
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
  }

  state.searches_dirty = true
  set_status("已保存搜索：" .. name)
end

function activate_saved_search(saved)
  if not saved then
    return
  end

  state.search = saved.query or ""
  state.view = saved.view or "all"
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
      end
    end
  end

  file:close()
end

function save_history()
  ensure_dirs()

  local file = io.open(HISTORY_FILE, "wb")

  if not file then
    set_status("无法保存试听历史", true)
    return
  end

  for _, asset in ipairs(state.assets) do
    if (tonumber(asset.last_previewed) or 0) > 0 then
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
  end

  file:close()
  state.history_dirty = false
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
      count = count + 1
    end
  end

  if count > 0 then
    state.db_dirty = true
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
  local played_key =
    path_key(asset.path)

  if not state.session_played[played_key] then
    state.session_played[played_key] = true
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
  if not record then
    return
  end

  for _, asset in ipairs(state.assets) do
    if asset.root_id == record.id
      and tostring(asset.artwork_path or "") == "" then
      asset.artwork_checked = false
    end
  end

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
        state.db_dirty = true
      elseif current ~= "-" then
        asset.artwork_path = ""
      end

      asset.artwork_checked = true
    end
  end

  state.artwork_next_job = now + 0.025
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

  for _, asset in ipairs(state.assets) do
    if asset.artwork_path ~= "-" then
      asset.artwork_path = ""
      asset.artwork_checked = false
    end
  end

  state.db_dirty = true
  set_status("已清空 Artwork 缓存；可见素材将重新查找封面")
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
  local ucs = parse_ucs_filename(asset.name)

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

  local catid = metadata_pick(
    metadata,
    {
      "CATID",
      "CATEGORY ID",
    }
  )

  local category = metadata_pick(
    metadata,
    {
      "CATEGORY",
    }
  )

  local subcategory = metadata_pick(
    metadata,
    {
      "SUBCATEGORY",
      "SUB CATEGORY",
    }
  )

  asset.catid =
    catid ~= "" and catid or ucs.catid

  asset.category =
    category ~= "" and category or ucs.category

  asset.subcategory =
    subcategory ~= ""
      and subcategory
      or ucs.subcategory

  asset.indexed = true
  asset._search_blob = nil

  reaper.PCM_Source_Destroy(source)

  state.db_dirty = true
  state.results_dirty = true
  return true
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

function start_scan(reason, roots_override)
  local requested = roots_override or state.roots

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

  state.scan = scan

  set_status(
    string.format(
      "%s：正在扫描 %d 个目录…",
      scan.reason,
      #scan.roots
    )
  )
end

function finish_scan()
  local scan = state.scan

  if not scan then
    return
  end

  local removed = 0

  for key, asset in pairs(state.by_path) do
    local belongs =
      scan.root_keys[path_key(asset.root or "")] == true

    if belongs and not scan.seen[key] then
      state.by_path[key] = nil
      state.favorites[key] = nil
      state.selected_set[key] = nil
      removed = removed + 1
    end
  end

  if removed > 0 then
    rebuild_assets()
    state.config_dirty = true
    state.db_dirty = true
  end

  local pending = {}
  local pending_seen = {}

  for _, asset in ipairs(scan.new_assets) do
    local key = path_key(asset.path)

    if not pending_seen[key] and not asset.ready then
      pending_seen[key] = true
      asset.pending_batch = true
      pending[#pending + 1] = asset
    end
  end

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
    }

    state.import_cancel_requested = false

    set_status(
      string.format(
        "%s：扫描完成，正在分析并建立 %d 个波形…",
        scan.reason,
        #pending
      )
    )
  else
    if scan.ignored > 0 then
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

function process_scan()
  local scan = state.scan

  if not scan then
    return
  end

  local deadline =
    reaper.time_precise() + SCAN_BUDGET

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

              state.db_dirty = true
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

function rebuild_results()
  state.results = {}

  for _, asset in ipairs(state.assets) do
    if asset_in_view(asset)
      and matches_search(asset) then
      state.results[#state.results + 1] = asset
    end
  end

  local direction =
    state.sort_desc and -1 or 1

  table.sort(
    state.results,
    function(a, b)
      local av
      local bv

      if state.sort_mode == "duration" then
        av = tonumber(a.duration) or 0
        bv = tonumber(b.duration) or 0
      elseif state.sort_mode == "library" then
        av = safe_lower(a.library)
        bv = safe_lower(b.library)
      elseif state.sort_mode == "used" then
        av = tonumber(a.last_used) or 0
        bv = tonumber(b.last_used) or 0
      elseif state.sort_mode == "previewed" then
        av = tonumber(a.last_previewed) or 0
        bv = tonumber(b.last_previewed) or 0
      else
        av = safe_lower(a.name)
        bv = safe_lower(b.name)
      end

      if av == bv then
        local a_path = path_key(a.path)
        local b_path = path_key(b.path)

        if a_path == b_path then
          return false
        end

        if direction > 0 then
          return a_path < b_path
        end

        return a_path > b_path
      end

      if direction > 0 then
        return av < bv
      end

      return av > bv
    end
  )

  state.results_dirty = false

  if state.selected_path then
    state.selected_index = 0

    for index, asset in ipairs(state.results) do
      if path_key(asset.path)
        == path_key(state.selected_path) then
        state.selected_index = index
        break
      end
    end
  end
end

----------------------------------------------------------------
-- Persistent waveform cache
----------------------------------------------------------------

function wave_cache_key(asset, points, preserve_channels)
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
  )
end

function wave_cache_path(asset, points, preserve_channels)
  return join_path(
    WAVE_CACHE_DIR,
    wave_cache_key(asset, points, preserve_channels) .. ".rwf"
  )
end

function load_wave_from_disk(asset, points, preserve_channels)
  local path = wave_cache_path(asset, points, preserve_channels)
  local file = io.open(path, "rb")

  if not file then
    return nil
  end

  local header = file:read("*l") or ""
  local version, count_text, channels_text =
    header:match("^(RWF3)%s+(%d+)%s+(%d+)$")

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

  if version == "RWF3" then
    local channels = clamp(tonumber(channels_text) or 1, 1, 8)
    local bytes = file:read(count * channels * 2)
    file:close()

    if not bytes or #bytes ~= count * channels * 2 then
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

    return {
      count = count,
      channels = channels,
      peaks = peaks,
      channel_peaks = channel_peaks,
    }
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
  preserve_channels
)
  ensure_dirs()

  local file =
    io.open(
      wave_cache_path(asset, points, preserve_channels),
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

  if channel_peaks then
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
  file:close()
end

function read_waveform_from_source(
  source,
  duration,
  channels,
  points,
  preserve_channels
)
  if not source
    or not duration
    or duration <= 0 then
    return nil
  end

  channels = clamp(channels or 1, 1, 8)
  points = clamp(math.floor(points), 32, LARGE_WAVE_MAX_POINTS)

  local buffer =
    reaper.new_array(points * channels * 2)

  local retval =
    reaper.PCM_Source_GetPeaks(
      source,
      points / duration,
      0,
      channels,
      points,
      0,
      buffer
    )

  local returned = retval & 0xFFFFF

  if returned <= 0 then
    return nil
  end

  local values =
    buffer.table(
      1,
      returned * channels * 2
    )

  local peaks = {}
  local channel_peaks = preserve_channels and {} or nil
  local minimum_offset = returned * channels

  if channel_peaks then
    for channel = 1, channels do
      channel_peaks[channel] = {}
    end
  end

  for sample = 0, returned - 1 do
    local amplitude = 0

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

      if channel_peaks then
        channel_peaks[channel + 1][sample + 1] =
          clamp(math.max(maximum, minimum), 0, 1)
      end
    end

    peaks[sample + 1] =
      clamp(amplitude, 0, 1)
  end

  return {
    count = returned,
    channels = channels,
    peaks = peaks,
    channel_peaks = channel_peaks,
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

  local source =
    reaper.PCM_Source_CreateFromFile(job.asset.path)

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
  local remaining =
    reaper.PCM_Source_BuildPeaks(source, 0)

  if remaining == 0 then
    job.phase = "read"
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
    local remaining =
      reaper.PCM_Source_BuildPeaks(
        job.source,
        1
      )

    job.progress =
      clamp(1 - remaining / 100, 0, 0.99)

    if remaining ~= 0 then
      return "working"
    end

    reaper.PCM_Source_BuildPeaks(
      job.source,
      2
    )

    job.phase = "read"
    job.progress = 1
  end

  if job.phase == "read" then
    local waveform =
      read_waveform_from_source(
        job.source,
        job.duration,
        job.channels,
        job.points,
        job.preserve_channels
      )

    destroy_wave_job(job)

    if waveform then
      return "done", waveform
    end

    return "failed", nil, "峰值读取为空"
  end

  return "working"
end

function memory_wave_key(asset, points, preserve_channels)
  return wave_cache_key(asset, points, preserve_channels)
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

function queue_wave(asset, points, priority, preserve_channels)
  if asset.wave_error then
    return nil
  end

  preserve_channels = preserve_channels == true

  local key = memory_wave_key(asset, points, preserve_channels)
  local cached = state.wave_cache[key]

  state.wave_clock = state.wave_clock + 1

  if cached then
    cached.used = state.wave_clock
    return cached.waveform
  end

  if not state.wave_checked[key] then
    state.wave_checked[key] = true

    local disk_wave =
      load_wave_from_disk(asset, points, preserve_channels)

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
  end

  local job = state.wave_active
  local result, waveform, err =
    step_wave_job(job)

  if result == "done" then
    job.asset.wave_error = nil
    store_wave_memory(job.key, waveform)
    save_wave_to_disk(
      job.asset,
      job.points,
      waveform,
      job.preserve_channels
    )

    state.wave_queued[job.key] = nil
    state.wave_active = nil
  elseif result == "failed" then
    destroy_wave_job(job)
    job.asset.wave_error = tostring(err or "波形建立失败")
    state.wave_queued[job.key] = nil
    state.wave_active = nil
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

function precache_asset_list(scope)
  local assets = {}

  for _, asset in ipairs(state.assets) do
    local include =
      asset.ready
      and reaper.file_exists(asset.path)

    if include
      and scope == "current"
      and (state.root_filter or state.library_filter_id) then
      if state.root_filter then
        include = path_is_inside(asset.path, state.root_filter)
      else
        include = asset.library_id == state.library_filter_id
      end
    end

    if include then
      assets[#assets + 1] = asset
    end
  end

  return assets
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

  local assets =
    precache_asset_list(scope or "all")

  if #assets == 0 then
    set_status(
      "当前范围没有可预缓存的素材",
      true
    )
    return
  end

  state.precache_cancel_requested = false
  state.precache_session = {
    assets = assets,
    total = #assets,
    index = 1,
    generated = 0,
    cached = 0,
    failed = 0,
    points = points,
    preserve_channels = state.multichannel_waveform,
    scope = scope or "all",
    current = nil,
    started = reaper.time_precise(),
  }

  set_status(
    string.format(
      "开始预缓存 %d 个素材的 %d 点高精度波形",
      #assets,
      points
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

  if not can_run_heavy_job() then
    return
  end

  local now = reaper.time_precise()

  if now < state.next_wave_job then
    return
  end

  if not session.current then
    while session.index <= session.total do
      local asset =
        session.assets[session.index]

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
  destroy_wave_job(state.wave_active)
  state.wave_active = nil
  state.wave_cache = {}
  state.wave_cache_count = 0
  state.wave_checked = {}
  state.wave_queue = {}
  state.wave_queued = {}

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

  for _, asset in ipairs(session.assets) do
    asset.pending_batch = nil
  end

  state.import_session = nil
  state.import_cancel_requested = false
  state.results_dirty = true
  state.db_dirty = true

  save_database()

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

function cancel_import_session()
  local session = state.import_session

  if not session then
    return
  end

  if session.current and session.current.wave_job then
    destroy_wave_job(session.current.wave_job)
  end

  -- 未完成的素材保持隐藏，并从本轮数据库中移除，避免“读取中”残留。
  for _, asset in ipairs(session.assets) do
    if not asset.ready then
      state.by_path[path_key(asset.path)] = nil
    else
      asset.pending_batch = nil
    end
  end

  rebuild_assets()
  state.import_session = nil
  state.import_cancel_requested = false
  state.db_dirty = true
  save_database()
  set_status("已取消导入；已完成的素材保留")
end

function process_import_session()
  local session = state.import_session

  if not session then
    return
  end

  if state.import_cancel_requested then
    cancel_import_session()
    return
  end

  if not can_run_heavy_job() then
    return
  end

  if not session.current then
    local asset =
      session.assets[session.done + 1]

    if not asset then
      finish_import_session()
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
        asset.ready = true
        session.failed = session.failed + 1
        session.done = session.done + 1
        session.current = nil
        state.db_dirty = true
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
      session.done = session.done + 1
      session.current = nil
      state.db_dirty = true
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
      session.done = session.done + 1
      session.current = nil
      state.db_dirty = true
    elseif result == "failed" then
      destroy_wave_job(current.wave_job)
      asset.ready = true
      asset.wave_error = tostring(err or "波形建立失败")
      session.failed = session.failed + 1
      session.done = session.done + 1
      session.current = nil
      state.db_dirty = true
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
  local changed = false

  for _, asset in ipairs(assets or {}) do
    local next_value = marked == true

    if asset.marked ~= next_value then
      asset.marked = next_value
      asset._search_blob = nil
      changed = true
    end
  end

  if changed then
    state.db_dirty = true
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

function push_recent(asset)
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
  state.db_dirty = true

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
    push_recent(asset)
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

  push_recent(asset)

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

  if state.transfer_cancel_requested then
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
    push_recent(asset)
    return true
  end

  return false
end

function insert_selected_stack(
  start_percent,
  end_percent
)
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
  local os_name = reaper.GetOS()

  if os_name:match("Win") then
    reaper.ExecProcess(
      'explorer.exe "' .. path .. '"',
      0
    )
  elseif os_name:match("OSX") then
    reaper.ExecProcess(
      'open "' .. path .. '"',
      0
    )
  else
    reaper.ExecProcess(
      'xdg-open "' .. path .. '"',
      0
    )
  end
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

function remove_root(root)
  local record = type(root) == "table"
    and root
    or root_record_for_path(root)

  if not record then
    return
  end

  root = record.path
  if state.import_session then
    local touches_import = false

    for _, import_root in ipairs(
      state.import_session.roots or {}
    ) do
      if path_key(import_root) == path_key(root) then
        touches_import = true
        break
      end
    end

    if touches_import then
      if state.import_session.current
        and state.import_session.current.wave_job then
        destroy_wave_job(
          state.import_session.current.wave_job
        )
      end

      state.import_session = nil
    end
  end

  if state.scan then
    for _, scan_root in ipairs(state.scan.roots or {}) do
      if path_key(scan_root) == path_key(root) then
        state.scan = nil
        break
      end
    end
  end

  for index = #state.root_records, 1, -1 do
    if state.root_records[index].id == record.id then
      table.remove(state.root_records, index)
      break
    end
  end

  rebuild_library_indexes()

  for key, asset in pairs(state.by_path) do
    if path_is_inside(asset.path, root) then
      state.by_path[key] = nil
      state.favorites[key] = nil

      if state.regions_by_path[key] then
        state.regions_by_path[key] = nil
        state.regions_dirty = true
      end

      if state.loudness_cache[key] then
        state.loudness_cache[key] = nil
        state.loudness_dirty = true
      end
    end
  end

  if state.root_filter
    and path_key(state.root_filter)
      == path_key(root) then
    state.root_filter = nil
  end

  if state.library_filter_id == record.library_id then
    local owner = state.library_by_id[record.library_id]

    if not owner or #owner.roots == 0 then
      state.library_filter_id = nil
    end
  end

  clear_row_selection()
  rebuild_assets()
  state.libraries_dirty = true
  state.db_dirty = true
  set_status("已移除来源路径：" .. basename(root))
end

function remove_library(library_id)
  local library = state.library_by_id[library_id]

  if not library then
    return
  end

  local roots = {}

  for _, record in ipairs(library.roots or {}) do
    roots[#roots + 1] = record
  end

  for _, record in ipairs(roots) do
    remove_root(record)
  end

  for index = #state.libraries, 1, -1 do
    if state.libraries[index].id == library_id then
      table.remove(state.libraries, index)
      break
    end
  end

  if state.library_filter_id == library_id then
    state.library_filter_id = nil
  end

  rebuild_library_indexes()
  refresh_all_asset_library_bindings()
  state.libraries_dirty = true
  set_status("已移除逻辑音效库：" .. library.name)
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
  state.active_collection_id = nil
  state.status_filter = nil
  state.sort_mode = "name"
  state.sort_desc = false
  state.auto_preview = true
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
  state.transfer_job = nil
  state.transfer_cancel_requested = false
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

  if state.import_session
    and state.import_session.current
    and state.import_session.current.wave_job then
    destroy_wave_job(
      state.import_session.current.wave_job
    )
  end

  state.scan = nil
  state.import_session = nil
  state.import_cancel_requested = false
  state.assets = {}
  state.by_path = {}
  state.results = {}
  state.favorites = {}
  state.recent = {}
  state.active_collection_id = nil
  state.status_filter = nil
  clear_row_selection()
  clear_wave_cache()
  os.remove(DATABASE_FILE)
  os.remove(HISTORY_FILE)
  os.remove(LAST_PLAYED_SESSION_FILE)
  state.history_dirty = false
  state.session_played = {}
  state.last_session_played = {}
  state.session_played_dirty = false
  state.db_dirty = true
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
  state.scan = nil
  state.import_session = nil
  state.import_cancel_requested = false
  state.roots = {}
  state.libraries = {}
  state.library_by_id = {}
  state.root_records = {}
  state.root_by_id = {}
  state.root_by_path = {}
  state.library_filter_id = nil
  state.assets = {}
  state.by_path = {}
  state.results = {}
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
  os.remove(COLLECTIONS_FILE)
  os.remove(SAVED_SEARCHES_FILE)
  os.remove(HISTORY_FILE)
  os.remove(LAST_PLAYED_SESSION_FILE)
  os.remove(REGIONS_FILE)
  os.remove(LOUDNESS_FILE)
  state.config_dirty = false
  state.libraries_dirty = false
  state.db_dirty = false
  state.collections_dirty = false
  state.searches_dirty = false
  state.history_dirty = false
  state.session_played = {}
  state.last_session_played = {}
  state.session_played_dirty = false

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

      for index = range_start, range_end do
        amplitude = math.max(amplitude, peaks[index] or 0)
      end

      local px = x + pixel

      ImGui.DrawList_AddLine(
        draw_list,
        px,
        center - amplitude * half,
        px,
        center + amplitude * half,
        lane_wave_color,
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
  elseif icon == "folder" then
    ImGui.DrawList_AddRect(draw_list, left, top + size * 0.10, right, bottom, color_value, 2, 0, thickness)
    ImGui.DrawList_AddLine(draw_list, left, top + size * 0.10, center_x - size * 0.05, top + size * 0.10, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x - size * 0.05, top + size * 0.10, center_x + size * 0.03, top, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x + size * 0.03, top, right - size * 0.05, top, color_value, thickness)
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

function icon_button(id, icon, tooltip_text, active, size)
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
    local background =
      active and rgba_with_alpha(COLOR.accent, 0x32)
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
  if state.library_counts_dirty and not state.scan then
    state.library_asset_counts = {}

    for _, asset in ipairs(state.assets) do
      local id = asset.library_id or ""

      if id ~= "" then
        state.library_asset_counts[id] =
          (state.library_asset_counts[id] or 0) + 1
      end
    end

    state.library_counts_dirty = false
  end

  return state.library_asset_counts[library_id] or 0
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
    path = ok and normalize_slashes(trim(path or "")) or ""

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
        for _, asset in ipairs(state.assets) do
          if path_is_inside(asset.path, record.path) then
            asset.ready = false
            asset.indexed = false
          end
        end

        start_scan("重建 " .. basename(record.path), { record.path })
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
      save_libraries()
      save_database()
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
      save_libraries()
      save_database()
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

function draw_sidebar()
  if dark_button("隐藏导航 <", -1) then
    state.sidebar_visible = false
    state.config_dirty = true
    return
  end

  ImGui.Spacing(ctx)

  if sidebar_section_header(
    "sounds",
    "SOUNDS"
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

  end

  if sidebar_section_header(
    "libraries",
    "LIBRARIES"
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
    "collections",
    "COLLECTIONS"
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
    "SAVED SEARCHES"
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
    "WORKFLOW"
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
    "ACTIVITY"
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

  ImGui.SetNextItemWidth(ctx, -228)

  local changed
  changed, state.search =
    ImGui.InputTextWithHint(
      ctx,
      "##search",
      "输入关键词或描述声音…  category:impact  status:candidate  -exclude",
      state.search
    )

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

  if icon_button(
    "scan",
    "refresh",
    "增量扫描",
    state.scan ~= nil,
    control_size
  ) then
    start_scan("增量扫描")
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

  if state.scan then
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
  if not state.scan
    and not state.import_session
    and not state.precache_session then
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
    if state.precache_session then
      local session = state.precache_session
      local current_progress =
        session.current
        and session.current.progress
        or 0

      local completed =
        session.generated
        + session.cached
        + session.failed

      local fraction =
        session.total > 0
        and clamp(
          (completed + current_progress)
            / session.total,
          0,
          1
        )
        or 1

      local current_name =
        session.current
        and session.current.asset
        and session.current.asset.name
        or "检查现有缓存"

      ImGui.Text(
        ctx,
        string.format(
          "高精度预缓存 %d 点  %d / %d  新生成 %d  已有 %d  失败 %d",
          session.points,
          completed,
          session.total,
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
    elseif state.scan then
      local animated =
        (reaper.time_precise() * 0.28) % 1

      ImGui.Text(
        ctx,
        string.format(
          "%s：正在扫描文件…  已发现 %d 个音频 / %d 个目录",
          state.scan.reason,
          state.scan.files,
          state.scan.directories
        )
      )

      ImGui.ProgressBar(
        ctx,
        animated,
        -100,
        18,
        "扫描中"
      )
    else
      local session = state.import_session
      local current_progress =
        session.current
        and session.current.progress
        or 0

      local fraction =
        session.total > 0
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
        string.format(
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
      if state.precache_session then
        state.precache_cancel_requested = true
      elseif state.scan then
        local scan = state.scan

        for _, asset in ipairs(scan.new_assets or {}) do
          if not asset.ready then
            state.by_path[path_key(asset.path)] = nil
          end
        end

        state.scan = nil
        rebuild_assets()
        state.db_dirty = true
        set_status("已取消扫描")
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

  if ImGui.MenuItem(ctx, "插入当前轨道", "Enter") then
    insert_asset(asset, false, false)
  end

  if ImGui.MenuItem(ctx, "插入新轨道", "Ctrl+Enter") then
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
    for _, selected_item in ipairs(bulk_assets) do
      state.favorites[path_key(selected_item.path)] = true
    end

    state.config_dirty = true
    state.results_dirty = true
    set_status("已收藏所选素材")
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
      state.multichannel_waveform
    )

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
        end
      end
    end

    if asset_changed then
      asset._search_blob = nil
      changed_count = changed_count + 1
    end
  end

  if changed_count > 0 then
    state.db_dirty = true
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
    state.db_dirty = true
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
    state.db_dirty = true
  end

  if tostring(asset.artwork_path or "") ~= "" then
    if dark_button("清除封面", -1) then
      asset.artwork_path = "-"
      asset.artwork_checked = true
      state.db_dirty = true
      state.results_dirty = true
    end
  end
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
          "Enter",
          "插入当前轨道",
          "Insert on the current track",
        },
        {
          "Ctrl+Enter",
          "插入新轨道",
          "Insert on a new track",
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
      reaper.time_precise() + WATCH_INTERVAL
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
      "Current played highlights: "
        .. tostring(session_played_count()),
      "Previous-session highlights: "
        .. tostring(last_session_played_count()),
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

function transfer_choice(label, key, options)
  ImGui.TextDisabled(ctx, label)

  for index, option in ipairs(options) do
    local selected = state[key] == option.value

    if selected then
      ImGui.PushStyleColor(
        ctx,
        ImGui.Col_Button,
        rgba_with_alpha(COLOR.selected, 0x88)
      )
    end

    local clicked = dark_button(
      option.label .. "##" .. key .. "_" .. option.value,
      option.width or 128
    )

    if selected then
      ImGui.PopStyleColor(ctx)
    end

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

  if dark_button("打开输出目录", 140) then
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

      if dark_button("打开输出目录", 140) then
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
      if dark_button("打开任务报告目录", 170) then
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

  local use_two_columns =
    palette_width >= 720

  for index, definition in ipairs(WAVEFORM_PALETTE_FIELDS) do
    if use_two_columns then
      local column_width =
        (palette_width - 8) * 0.5

      if ImGui.BeginChild(
        ctx,
        "palette_cell_" .. tostring(index),
        column_width,
        60,
        0,
        ImGui.WindowFlags_NoScrollbar
          | ImGui.WindowFlags_NoScrollWithMouse
      ) then
        draw_waveform_palette_field(definition)
      end

      ImGui.EndChild(ctx)

      if index % 2 == 1 then
        ImGui.SameLine(ctx)
      end
    else
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

  if ImGui.BeginChild(
    ctx,
    "maintenance_runtime_card",
    -1,
    226,
    ImGui.ChildFlags_Borders,
    ImGui.WindowFlags_NoScrollbar
      | ImGui.WindowFlags_NoScrollWithMouse
  ) then
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
  end

  ImGui.EndChild(ctx)
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

  if ImGui.BeginChild(
    ctx,
    "cache_directory_card",
    -1,
    112,
    ImGui.ChildFlags_Borders,
    ImGui.WindowFlags_NoScrollbar
      | ImGui.WindowFlags_NoScrollWithMouse
  ) then
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
  end

  ImGui.EndChild(ctx)
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
    save_database()
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
  elseif ImGui.IsKeyPressed(
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
    and not state.import_session then
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

  state.last_save = now
end

function watch_folders()
  if not state.watch_enabled
    or state.scan
    or state.import_session
    or state.precache_session
    or state.transfer_running then
    return
  end

  local now = reaper.time_precise()

  if now >= state.next_watch then
    start_scan("Watch Folder")
    state.next_watch =
      now + WATCH_INTERVAL
  end
end

function cleanup()
  stop_preview()
  cleanup_retired_preview_sources(true)
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

  if state.import_session
    and state.import_session.current
    and state.import_session.current.wave_job then
    destroy_wave_job(
      state.import_session.current.wave_job
    )
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

  destroy_loudness_job(state.loudness_active)
end

reaper.atexit(cleanup)

ensure_dirs()
migrate_legacy_data()
load_or_migrate_project_url()
load_config()
load_or_migrate_libraries()
apply_unified_interface(false, false)
apply_wave_cache_directory(
  state.wave_cache_dir
    or DEFAULT_WAVE_CACHE_DIR
)
install_i18n_wrappers()
load_database()
refresh_all_asset_library_bindings()
load_collections()
load_saved_searches()
load_history()
load_last_played_session()

if state.restore_played_on_start then
  restore_last_session_played_highlights(true)
end

load_regions()
load_loudness_cache()
apply_surface_style()
apply_theme_palette()
apply_waveform_palette()
state.results_dirty = true

local needs_import_recovery = false

for _, asset in ipairs(state.assets) do
  if not asset.ready then
    needs_import_recovery = true
    break
  end
end

if #state.roots > 0
  and (#state.assets == 0 or needs_import_recovery) then
  start_scan(
    needs_import_recovery
      and "恢复未完成导入"
      or "首次扫描"
  )
end

function loop()
  if not state.open then
    return
  end

  if state.transfer_running then
    -- Transfer receives the background-work budget while active. Library
    -- scanning, waveform generation, Artwork and loudness analysis resume
    -- automatically after the job finishes or is stopped.
    process_transfer_job()
  else
    process_scan()
    process_import_session()
    process_metadata_queue()
    process_artwork_queue()
    process_wave_precache()
    process_wave_queue()
    process_pending_transient_detection()
    process_loudness_queue()
  end
  cleanup_retired_preview_sources(false)
  poll_preview()
  watch_folders()
  autosave()

  if state.results_dirty then
    rebuild_results()
  end

  draw_main()

  if state.open then
    reaper.defer(loop)
  end
end

loop()
