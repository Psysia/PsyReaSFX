-- @description Smart Tail Render Panel / 智能尾音渲染面板
-- @version 1.1
-- @author Psysia
--
-- 原理：先用 REAPER 原生 Render Tail 多渲染一段最大尾音，
-- 再用 Trim ending silence 按 dBFS 阈值裁掉尾部静音，
-- 最后追加少量安全留白。适用于 Region Render Matrix、时间选区等。
--
-- 本脚本解决“时间范围截断”，不会改变轨道路由。
-- 外部混响/Delay Return 必须回到被渲染的总线，或包含在所选渲染源中。
-- 不依赖 SWS、ReaPack 或 ReaImGui。

local PROJ = 0
local TITLE = "智能尾音渲染"

-- 默认窗口扩大，并预留独立的提示、状态和按钮区域。
local DEFAULT_W, DEFAULT_H = 700, 620
local MIN_W, MIN_H = 640, 570

local BIT_TRIM_END     = 32768
local BIT_PAD_END      = 2 << 16
local BIT_DISABLE_POST = 4 << 16
local ALL_TAIL_FLAGS   = 1 | 2 | 4 | 8 | 16 | 32

local state = {
  threshold_db = -60,
  max_tail_sec = 10,
  safety_ms = 200,
  trim = true,
  pad = true,

  -- 1 当前渲染范围
  -- 2 全部/已选 Region
  -- 3 所有渲染范围
  scope = 2,

  status = "",
  status_at = 0,
  running = true,
}

local original = {}
local mouse_last = 0
local active_slider = nil

local bounds_name = {
  [0] = "自定义时间范围",
  [1] = "整个工程",
  [2] = "时间选区",
  [3] = "全部 Region",
  [4] = "已选媒体对象",
  [5] = "已选 Region",
  [6] = "全部 Marker",
  [7] = "已选 Marker",
}

local function clamp(value, minimum, maximum)
  if value < minimum then
    return minimum
  end

  if value > maximum then
    return maximum
  end

  return value
end

local function round_to_step(value, step)
  return math.floor(value / step + 0.5) * step
end

local function db_to_amp(db)
  return 10 ^ (db / 20)
end

local function amp_to_db(amp)
  if not amp or amp <= 0 then
    return -150
  end

  return 20 * math.log(amp) / math.log(10)
end

local function get_num(key)
  return reaper.GetSetProjectInfo(
    PROJ,
    key,
    0,
    false
  )
end

local function get_int(key)
  return math.floor(get_num(key) + 0.5)
end

local function set_num(key, value)
  reaper.GetSetProjectInfo(
    PROJ,
    key,
    value,
    true
  )
end

local function set_status(text)
  state.status = text
  state.status_at = reaper.time_precise()
end

local function capture_original()
  original.tailflag = get_int("RENDER_TAILFLAG")
  original.tailms = get_num("RENDER_TAILMS")
  original.normalize = get_int("RENDER_NORMALIZE")
  original.trimend = get_num("RENDER_TRIMEND")
  original.padend = get_num("RENDER_PADEND")
end

local function load_current()
  local normalize = get_int("RENDER_NORMALIZE")
  local threshold = get_num("RENDER_TRIMEND")
  local tail_ms = get_num("RENDER_TAILMS")
  local pad_end = get_num("RENDER_PADEND")

  state.trim = (normalize & BIT_TRIM_END) ~= 0
  state.pad = (normalize & BIT_PAD_END) ~= 0

  if threshold > 0 then
    state.threshold_db =
      clamp(amp_to_db(threshold), -120, -20)
  end

  if tail_ms > 0 then
    state.max_tail_sec =
      clamp(tail_ms / 1000, 0.5, 60)
  end

  if pad_end >= 0 then
    state.safety_ms =
      clamp(pad_end * 1000, 0, 2000)
  end
end

local function current_bounds()
  return math.floor(
    get_num("RENDER_BOUNDSFLAG") + 0.5
  )
end

local function tail_bit_for_bounds(bounds)
  if bounds == 0 then
    return 1
  elseif bounds == 1 then
    return 2
  elseif bounds == 2 then
    return 4
  elseif bounds == 3 or bounds == 6 then
    return 8
  elseif bounds == 4 then
    return 16
  elseif bounds == 5 or bounds == 7 then
    return 32
  end

  return 0
end

local function apply_settings()
  local tail_flag = get_int("RENDER_TAILFLAG")
  local normalize = get_int("RENDER_NORMALIZE")

  if state.scope == 1 then
    tail_flag =
      tail_flag | tail_bit_for_bounds(current_bounds())
  elseif state.scope == 2 then
    tail_flag = tail_flag | 8 | 32
  else
    tail_flag = tail_flag | ALL_TAIL_FLAGS
  end

  -- 裁尾和留白属于渲染后处理，因此清除“禁用全部后处理”位。
  normalize = normalize & (~BIT_DISABLE_POST)

  if state.trim then
    normalize = normalize | BIT_TRIM_END
  else
    normalize = normalize & (~BIT_TRIM_END)
  end

  if state.pad and state.safety_ms > 0 then
    normalize = normalize | BIT_PAD_END
  else
    normalize = normalize & (~BIT_PAD_END)
  end

  reaper.Undo_BeginBlock2(PROJ)

  set_num("RENDER_TAILFLAG", tail_flag)
  set_num("RENDER_TAILMS", state.max_tail_sec * 1000)
  set_num("RENDER_NORMALIZE", normalize)
  set_num("RENDER_TRIMEND", db_to_amp(state.threshold_db))
  set_num(
    "RENDER_PADEND",
    state.pad and state.safety_ms / 1000 or 0
  )

  if reaper.MarkProjectDirty then
    reaper.MarkProjectDirty(PROJ)
  end

  reaper.Undo_EndBlock2(
    PROJ,
    "设置智能尾音渲染参数",
    -1
  )

  set_status(
    string.format(
      "已应用：%.0f dBFS / %.1f 秒 / %.0f ms",
      state.threshold_db,
      state.max_tail_sec,
      state.pad and state.safety_ms or 0
    )
  )
end

local function restore_original()
  reaper.Undo_BeginBlock2(PROJ)

  set_num("RENDER_TAILFLAG", original.tailflag)
  set_num("RENDER_TAILMS", original.tailms)
  set_num("RENDER_NORMALIZE", original.normalize)
  set_num("RENDER_TRIMEND", original.trimend)
  set_num("RENDER_PADEND", original.padend)

  if reaper.MarkProjectDirty then
    reaper.MarkProjectDirty(PROJ)
  end

  reaper.Undo_EndBlock2(
    PROJ,
    "恢复尾音面板打开前的渲染设置",
    -1
  )

  load_current()
  set_status("已恢复面板打开前的渲染设置")
end

local function color(r, g, b, a)
  gfx.set(
    r / 255,
    g / 255,
    b / 255,
    a or 1
  )
end

local function fill(x, y, w, h, r, g, b, a)
  color(r, g, b, a)
  gfx.rect(x, y, w, h, 1)
end

local function stroke(x, y, w, h, r, g, b, a)
  color(r, g, b, a)
  gfx.rect(x, y, w, h, 0)
end

local function text(value, x, y, r, g, b)
  color(r or 230, g or 230, b or 230, 1)
  gfx.x = x
  gfx.y = y
  gfx.drawstr(tostring(value))
end

local function text_width(value)
  return gfx.measurestr(tostring(value))
end

local function inside(x, y, w, h)
  return gfx.mouse_x >= x
    and gfx.mouse_x <= x + w
    and gfx.mouse_y >= y
    and gfx.mouse_y <= y + h
end

local function pressed()
  return (gfx.mouse_cap & 1) ~= 0
    and (mouse_last & 1) == 0
end

local function released()
  return (gfx.mouse_cap & 1) == 0
    and (mouse_last & 1) ~= 0
end

local function button(label, x, y, w, h)
  local hover = inside(x, y, w, h)

  fill(
    x,
    y,
    w,
    h,
    hover and 68 or 52,
    hover and 84 or 63,
    hover and 108 or 79,
    1
  )

  stroke(x, y, w, h, 104, 119, 143, 1)

  text(
    label,
    x + (w - text_width(label)) / 2,
    y + math.floor((h - 16) / 2),
    238,
    241,
    246
  )

  return hover and pressed()
end

local function checkbox(label, value, x, y)
  local size = 18
  local hover =
    inside(x, y, size + 10 + text_width(label), size)

  fill(
    x,
    y,
    size,
    size,
    hover and 70 or 48,
    hover and 82 or 57,
    hover and 100 or 68,
    1
  )

  stroke(x, y, size, size, 118, 128, 145, 1)

  if value then
    color(224, 235, 248, 1)
    gfx.line(x + 4, y + 9, x + 8, y + 14)
    gfx.line(x + 8, y + 14, x + 15, y + 4)
  end

  text(label, x + 27, y + 1)

  if hover and pressed() then
    return not value
  end

  return value
end

local function prompt_number(
  title,
  caption,
  value,
  minimum,
  maximum
)
  local ok, output =
    reaper.GetUserInputs(
      title,
      1,
      caption,
      tostring(value)
    )

  if not ok then
    return nil
  end

  local number = tonumber(output)

  if not number then
    reaper.ShowMessageBox(
      "请输入有效数字。",
      TITLE,
      0
    )
    return nil
  end

  return clamp(number, minimum, maximum)
end

local function slider(
  id,
  label,
  value,
  minimum,
  maximum,
  step,
  y,
  format_value,
  prompt_caption
)
  local x = 38
  local total = gfx.w - 76
  local label_width = 140
  local button_width = 28
  local value_width = 102

  local slider_x =
    x + label_width + button_width + 8

  local slider_width =
    total
    - label_width
    - button_width
    - button_width
    - value_width
    - 32

  text(label, x, y + 8)

  if button(
    "-",
    x + label_width,
    y,
    button_width,
    32
  ) then
    value =
      clamp(
        round_to_step(value - step, step),
        minimum,
        maximum
      )
  end

  fill(
    slider_x,
    y + 13,
    slider_width,
    6,
    57,
    62,
    72,
    1
  )

  local ratio =
    clamp(
      (value - minimum) / (maximum - minimum),
      0,
      1
    )

  fill(
    slider_x,
    y + 13,
    slider_width * ratio,
    6,
    110,
    142,
    184,
    1
  )

  local knob_x =
    slider_x + slider_width * ratio

  fill(
    knob_x - 5,
    y + 7,
    10,
    18,
    205,
    216,
    232,
    1
  )

  if inside(
    slider_x - 7,
    y,
    slider_width + 14,
    32
  ) and pressed() then
    active_slider = id
  end

  if active_slider == id
    and (gfx.mouse_cap & 1) ~= 0 then

    local new_ratio =
      clamp(
        (gfx.mouse_x - slider_x) / slider_width,
        0,
        1
      )

    value =
      minimum + new_ratio * (maximum - minimum)

    value =
      clamp(
        round_to_step(value, step),
        minimum,
        maximum
      )
  end

  if active_slider == id and released() then
    active_slider = nil
  end

  local plus_x =
    slider_x + slider_width + 8

  if button(
    "+",
    plus_x,
    y,
    button_width,
    32
  ) then
    value =
      clamp(
        round_to_step(value + step, step),
        minimum,
        maximum
      )
  end

  local value_x =
    plus_x + button_width + 8

  if button(
    format_value(value),
    value_x,
    y,
    value_width,
    32
  ) then
    local number =
      prompt_number(
        label,
        prompt_caption,
        value,
        minimum,
        maximum
      )

    if number then
      value =
        clamp(
          round_to_step(number, step),
          minimum,
          maximum
        )
    end
  end

  return value
end

local function scope_label()
  if state.scope == 1 then
    return "当前渲染范围"
  elseif state.scope == 2 then
    return "全部/已选 Region"
  end

  return "所有渲染范围"
end

local function draw_too_small()
  fill(0, 0, gfx.w, gfx.h, 29, 33, 40, 1)

  gfx.setfont(1, "Arial", 18)
  text(
    "窗口尺寸过小",
    24,
    22,
    238,
    241,
    246
  )

  gfx.setfont(1, "Arial", 14)
  text(
    string.format(
      "请将窗口拉大至至少 %d × %d。",
      MIN_W,
      MIN_H
    ),
    24,
    62,
    198,
    203,
    213
  )

  if button(
    "关闭",
    24,
    104,
    90,
    36
  ) then
    state.running = false
  end
end

local function draw()
  if gfx.w < MIN_W or gfx.h < MIN_H then
    draw_too_small()
    return
  end

  fill(0, 0, gfx.w, gfx.h, 29, 33, 40, 1)

  -- 顶栏
  fill(0, 0, gfx.w, 62, 35, 40, 48, 1)

  gfx.setfont(1, "Arial", 22)
  text(TITLE, 24, 16, 238, 241, 246)

  gfx.setfont(1, "Arial", 14)
  text(
    "最大尾音窗口 + dBFS 阈值裁尾 + 安全留白",
    244,
    22,
    166,
    177,
    194
  )

  -- 当前范围说明
  fill(
    22,
    78,
    gfx.w - 44,
    74,
    42,
    47,
    56,
    1
  )

  stroke(
    22,
    78,
    gfx.w - 44,
    74,
    73,
    81,
    95,
    1
  )

  local bounds = current_bounds()

  text(
    "当前原生渲染范围：",
    38,
    92,
    170,
    180,
    194
  )

  text(
    bounds_name[bounds] or tostring(bounds),
    182,
    92,
    236,
    239,
    244
  )

  text(
    "先额外渲染最大尾音，再从文件末尾裁到最后一个高于阈值的位置。",
    38,
    120,
    183,
    191,
    204
  )

  -- 应用范围
  text("尾音应用范围", 38, 174)

  if button(
    scope_label(),
    190,
    164,
    228,
    32
  ) then
    state.scope = state.scope % 3 + 1
  end

  text(
    "点击切换",
    432,
    174,
    135,
    144,
    158
  )

  -- 参数区
  state.threshold_db =
    slider(
      "threshold",
      "裁尾阈值",
      state.threshold_db,
      -120,
      -20,
      1,
      218,
      function(value)
        return string.format("%.0f dBFS", value)
      end,
      "阈值 dBFS:"
    )

  state.max_tail_sec =
    slider(
      "tail",
      "最大尾音",
      state.max_tail_sec,
      0.5,
      60,
      0.5,
      266,
      function(value)
        return string.format("%.1f 秒", value)
      end,
      "最大尾音秒数:"
    )

  state.safety_ms =
    slider(
      "pad",
      "安全留白",
      state.safety_ms,
      0,
      2000,
      10,
      314,
      function(value)
        return string.format("%.0f ms", value)
      end,
      "安全留白毫秒:"
    )

  state.trim =
    checkbox(
      "启用阈值裁尾",
      state.trim,
      38,
      366
    )

  state.pad =
    checkbox(
      "裁切点后添加安全留白",
      state.pad,
      248,
      366
    )

  -- 预设区
  text("阈值预设", 38, 414)

  if button(
    "-48 dB",
    112,
    404,
    82,
    30
  ) then
    state.threshold_db = -48
  end

  if button(
    "-60 dB",
    204,
    404,
    82,
    30
  ) then
    state.threshold_db = -60
  end

  if button(
    "-72 dB",
    296,
    404,
    82,
    30
  ) then
    state.threshold_db = -72
  end

  text(
    "建议起点：-60 dBFS / 10 秒 / 200 ms",
    398,
    412,
    145,
    154,
    168
  )

  -- 独立路由提示框，避免与预设和状态文字重叠。
  fill(
    22,
    452,
    gfx.w - 44,
    58,
    45,
    42,
    39,
    1
  )

  stroke(
    22,
    452,
    gfx.w - 44,
    58,
    102,
    83,
    62,
    1
  )

  text(
    "路由注意：外部 Reverb / Delay Return 必须回到被渲染的总线，",
    38,
    464,
    210,
    180,
    137
  )

  text(
    "否则即使延长尾音，也不会进入当前渲染文件。",
    38,
    486,
    198,
    167,
    126
  )

  -- 独立状态栏
  local status_text = "尚未应用本次修改"

  if state.status ~= ""
    and reaper.time_precise() - state.status_at < 5 then
    status_text = state.status
  end

  text(
    status_text,
    24,
    525,
    171,
    202,
    170
  )

  -- 固定底部按钮栏
  fill(
    0,
    gfx.h - 72,
    gfx.w,
    72,
    35,
    40,
    48,
    1
  )

  local button_y = gfx.h - 54

  if button(
    "仅应用",
    22,
    button_y,
    100,
    36
  ) then
    apply_settings()
  end

  if button(
    "应用并打开渲染面板",
    132,
    button_y,
    205,
    36
  ) then
    apply_settings()
    reaper.Main_OnCommand(40015, 0)
  end

  if button(
    "恢复原设置",
    347,
    button_y,
    120,
    36
  ) then
    restore_original()
  end

  if button(
    "关闭",
    477,
    button_y,
    82,
    36
  ) then
    state.running = false
  end
end

local required = {
  "GetSetProjectInfo",
  "Undo_BeginBlock2",
  "Undo_EndBlock2",
  "Main_OnCommand",
  "GetUserInputs",
  "time_precise",
}

for _, name in ipairs(required) do
  if type(reaper[name]) ~= "function" then
    reaper.ShowMessageBox(
      "当前 REAPER 缺少脚本所需 API：\n\n"
      .. name
      .. "\n\n请更新 REAPER。",
      TITLE,
      0
    )
    return
  end
end

capture_original()
load_current()

gfx.init(
  TITLE,
  DEFAULT_W,
  DEFAULT_H,
  0
)

local function loop()
  if not state.running then
    gfx.quit()
    return
  end

  local char = gfx.getchar()

  if char < 0 or char == 27 then
    gfx.quit()
    return
  end

  draw()

  mouse_last = gfx.mouse_cap

  gfx.update()
  reaper.defer(loop)
end

loop()
