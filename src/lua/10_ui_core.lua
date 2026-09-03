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
