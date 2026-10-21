-- Workspace preferences and bounded, index-only folder navigation.
-- No disk enumeration, audio work or persistent catalog edits here.

WORKSPACE_SECTION_KEYS = { "sounds", "libraries", "folders", "ucs", "collections", "saved_searches", "workflow", "activity" }

function ui_font_size(value)
  local size = tonumber(value == nil and state.ui_font_size or value) or 13
  if size ~= size then size = 13 end
  return math.floor(math.max(10, math.min(24, size)) + 0.5)
end

function ui_scale()
  -- Freeze for the whole frame. Changing settings takes effect next frame,
  -- so row clipping and mouse-to-waveform mapping use identical geometry.
  return UI_METRIC.scale or ui_font_size() / 13
end

function ui_px(value)
  return value * ui_scale()
end

function ui_flow_next(width, gap)
  gap = gap or ui_px(6)
  local right = select(1, ImGui.GetCursorScreenPos(ctx)) + select(1, ImGui.GetContentRegionAvail(ctx))
  local previous_right = select(1, ImGui.GetItemRectMax(ctx))
  if previous_right + gap + width <= right then ImGui.SameLine(ctx, 0, gap) end
end

function ui_grid_columns(width, item_width, gap, count)
  return math.max(1, math.min(count, math.floor((width + gap) / (item_width + gap))))
end

function ui_metric_flow(label, value)
  local width = select(1, ImGui.CalcTextSize(ctx, translate_ui_text(label)))
    + select(1, ImGui.CalcTextSize(ctx, tostring(value or ""))) + ui_px(20)
  ui_flow_next(width, ui_px(6))
end

function workspace_channel_layout(width, channel_count)
  local gap = ui_px(5)
  local button_width = ui_px(51)
  local all_width = math.max(ui_px(72), select(1, ImGui.CalcTextSize(ctx, translate_ui_text("全部声道"))) + ui_px(8))
  local label_width = select(1, ImGui.CalcTextSize(ctx, translate_ui_text("声道条")))
  local count_width = select(1, ImGui.CalcTextSize(ctx, tostring(channel_count) .. " / " .. tostring(channel_count)))
  local row_widths = { label_width, all_width }
  for _ = 1, channel_count do row_widths[#row_widths + 1] = button_width end
  row_widths[#row_widths + 1] = count_width
  local rows, used = 1, 0
  for _, item in ipairs(row_widths) do
    if used > 0 and used + gap + item > width then rows, used = rows + 1, 0 end
    used = used + (used > 0 and gap or 0) + item
  end
  return { rows = rows, button_width = button_width, all_width = all_width, count_width = count_width, gap = gap }
end

function workspace_load_setting(name, value)
  if name == "ui_font_size" then
    AppState.set(name, ui_font_size(value))
  elseif name == "sidebar_width" then
    local width = tonumber(value) or 240
    if width ~= width or math.abs(width) == math.huge then width = 240 end
    AppState.set(name, math.max(160, math.min(520, width)))
  elseif name == "sidebar_navigation_mode" then
    if value == "libraries" or value == "folders" or value == "both" then AppState.set(name, value) end
  elseif name == "sidebar_folder_mode" then
    if value == "tree" or value == "roots" then AppState.set(name, value) end
  elseif name:match("^sidebar_show_") then
    local key = name:sub(14)
    for _, known in ipairs(WORKSPACE_SECTION_KEYS) do
      if key == known then
        AppState.update("sidebar_modules", function(modules) modules = modules or {} modules[key] = value ~= "0" return modules end)
        return true
      end
    end
    return false
  else
    return false
  end
  return true
end

function workspace_write_settings(file)
  file:write("setting\tui_font_size\t", ui_font_size(), "\n")
  file:write("setting\tsidebar_width\t", tostring(state.sidebar_width or 240), "\n")
  file:write("setting\tsidebar_navigation_mode\t", state.sidebar_navigation_mode or "libraries", "\n")
  file:write("setting\tsidebar_folder_mode\t", state.sidebar_folder_mode or "tree", "\n")
  for _, key in ipairs(WORKSPACE_SECTION_KEYS) do
    file:write("setting\tsidebar_show_", key, "\t", state.sidebar_modules[key] ~= false and "1" or "0", "\n")
  end
end

function workspace_reset_preferences()
  AppState.apply({ ui_font_size = 13, sidebar_width = 240, sidebar_navigation_mode = "libraries",
    sidebar_folder_mode = "tree", sidebar_modules = {}, config_dirty = true })
  AppState.set("folder_sidebar_cache", nil)
end

function workspace_navigation_enabled(key)
  local mode = state.sidebar_navigation_mode or "libraries"
  return key == "folders" and mode ~= "libraries" or key == "libraries" and mode ~= "folders"
end

function folder_sidebar_invalidate()
  AppState.set("folder_sidebar_cache", nil)
end

function folder_sidebar_toggle(node)
  AppState.update("expanded_folder_nodes", function(nodes) nodes[node.key] = not (nodes[node.key] == true) return nodes end)
  AppState.mark_dirty("config_dirty")
  folder_sidebar_invalidate()
end

-- Bottom-up mergesort yields after a bounded number of copies. Even one
-- directory containing 100,000 subfolders cannot trigger an all-at-once sort.
function folder_navigation_sort_step(job, limit)
  local steps = 0
  while job.finalize_index <= #job.nodes and steps < limit do
    local node = job.nodes[job.finalize_index]
    local sort = job.sort
    if #node.children < 2 then
      job.finalize_index = job.finalize_index + 1
      steps = steps + 1
    else
      if not sort then
        sort = { source = node.children, target = {}, run = 1, base = 1, count = #node.children }
        job.sort = sort
      end
      if not sort.left then
        sort.left = sort.base
        sort.left_end = math.min(sort.count, sort.base + sort.run - 1)
        sort.right = sort.base + sort.run
        sort.right_end = math.min(sort.count, sort.base + 2 * sort.run - 1)
        sort.output = sort.base
      end
      local a, b = sort.source[sort.left], sort.source[sort.right]
      local take_left = sort.right > sort.right_end
        or (sort.left <= sort.left_end and (a.sort_name < b.sort_name
          or (a.sort_name == b.sort_name and a.key <= b.key)))
      sort.target[sort.output] = take_left and a or b
      if take_left then sort.left = sort.left + 1 else sort.right = sort.right + 1 end
      sort.output = sort.output + 1
      steps = steps + 1
      if sort.output > sort.right_end then
        sort.base = sort.base + 2 * sort.run
        sort.left = nil
        if sort.base > sort.count then
          sort.source, sort.target = sort.target, sort.source
          sort.run, sort.base = sort.run * 2, 1
          if sort.run >= sort.count then
            node.children = sort.source
            job.sort = nil
            job.finalize_index = job.finalize_index + 1
          end
        end
      end
    end
    if steps % 64 == 0 and Host.time_precise() >= job.deadline then break end
  end
  return job.finalize_index > #job.nodes
end

function folder_sidebar_rows()
  local tree_mode = state.sidebar_folder_mode ~= "roots"
  local ready = not tree_mode or state.folder_navigation_ready
  local revision = state.folder_navigation_revision or 0
  local cache = state.folder_sidebar_cache
  if not cache or cache.revision ~= revision or cache.tree_mode ~= tree_mode or cache.ready ~= ready then
    cache = { revision = revision, tree_mode = tree_mode, ready = ready, rows = {}, stack = {}, root_index = 1 }
    AppState.set("folder_sidebar_cache", cache)
  end
  local deadline = Host.time_precise() + 0.003
  local work = 0
  while not cache.complete and work < 1000 do
    local top = cache.stack[#cache.stack]
    local node, record, depth
    if top then
      node = top.node.children[top.index]
      record, depth = top.record, top.depth
      if node then top.index = top.index + 1 else cache.stack[#cache.stack] = nil end
    else
      record = state.root_records[cache.root_index]
      cache.root_index = cache.root_index + 1
      if not record then cache.complete = true break end
      if record.enabled and record.path ~= "" then
        node = tree_mode and ready and state.folder_navigation_trees[record.id]
          or { path = record.path, key = path_key(record.path), name = record.alias ~= "" and record.alias or basename(record.path), children = {} }
        depth = 0
      end
    end
    if node then
      cache.rows[#cache.rows + 1] = { node = node, record = record, depth = depth }
      if tree_mode and ready and #node.children > 0 and state.expanded_folder_nodes[node.key] then
        cache.stack[#cache.stack + 1] = { node = node, record = record, depth = depth + 1, index = 1 }
      end
    end
    work = work + 1
    if work % 32 == 0 and Host.time_precise() >= deadline then break end
  end
  return cache.rows, cache.complete
end

function draw_folder_sidebar_row(row)
  local node, record = row.node, row.record
  local has_children = #node.children > 0
  local expanded = state.expanded_folder_nodes[node.key] == true
  local selected = state.root_filter and path_key(state.root_filter) == node.key
    and (not state.library_filter_id or record.library_id == state.library_filter_id)
  local width = math.max(1, select(1, ImGui.GetContentRegionAvail(ctx)))
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local height = ui_px(24)
  local indent = math.min(ui_px(row.depth * 16), math.max(0, width - ui_px(100)))
  local arrow_width = ui_px(22)
  local label_x = x + indent + arrow_width + ui_px(20)
  ImGui.PushID(ctx, record.id .. ":" .. node.key)
  local clicked = ImGui.Selectable(ctx, "##folder_sidebar_row", selected, 0, width, height)
  local mouse_x = select(1, ImGui.GetMousePos(ctx))
  if clicked then
    if has_children and mouse_x < x + indent + arrow_width then
      folder_sidebar_toggle(node)
    else
      activate_folder_path(node.path, record.library_id, false)
      if has_children and ImGui.IsMouseDoubleClicked(ctx, 0) then folder_sidebar_toggle(node) end
    end
  end
  tooltip(node.path)
  if ImGui.BeginPopupContextItem(ctx, "folder_sidebar_context") then
    if ImGui.MenuItem(ctx, "打开目录") then open_folder(node.path) end
    if has_children and ImGui.MenuItem(ctx, expanded and "折叠此层级" or "展开此层级") then folder_sidebar_toggle(node) end
    if row.depth == 0 and ImGui.MenuItem(ctx, "扫描此来源") then start_scan("扫描 " .. node.name, { record.path }) end
    ImGui.EndPopup(ctx)
  end
  accept_folder_drop_target(record.library_id)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  if has_children then
    ImGui.DrawList_AddText(draw_list, x + indent + ui_px(4), y + ui_px(3), COLOR.dim, expanded and "▾" or "▸")
  end
  -- Code-native folder outline: no icon font or external asset dependency.
  local fx, fy = x + indent + arrow_width + ui_px(2), y + ui_px(7)
  ImGui.DrawList_AddRect(draw_list, fx, fy, fx + ui_px(13), fy + ui_px(10), COLOR.dim, ui_px(1))
  ImGui.DrawList_AddLine(draw_list, fx, fy, fx + ui_px(5), fy - ui_px(3), COLOR.dim)
  local count = node.total_count and tostring(node.total_count) or ""
  local count_width = select(1, ImGui.CalcTextSize(ctx, count))
  if label_x + ui_px(30) + count_width + ui_px(12) > x + width then count, count_width = "", 0 end
  draw_clipped_text(draw_list, label_x, y + ui_px(3), selected and COLOR.selected_text or COLOR.text,
    node.name, math.min(label_x, x + width), y, x + width - count_width - ui_px(12), y + height)
  if count ~= "" then ImGui.DrawList_AddText(draw_list, x + width - count_width - ui_px(4), y + ui_px(3), COLOR.dim, count) end
  ImGui.PopID(ctx)
end

function draw_folder_sidebar()
  if state.sidebar_folder_mode ~= "roots" then ensure_folder_navigation_build() end
  if dark_button("roots" == state.sidebar_folder_mode and "切换为文件夹层级" or "切换为根目录列表", -1) then
    AppState.set("sidebar_folder_mode", "roots" == state.sidebar_folder_mode and "tree" or "roots")
    AppState.mark_dirty("config_dirty")
    folder_sidebar_invalidate()
  end
  local ready = "roots" == state.sidebar_folder_mode or state.folder_navigation_ready
  if not ready then ImGui.TextDisabled(ctx, "正在从索引整理文件夹…") end
  local rows, complete = folder_sidebar_rows()
  if #rows == 0 and complete then ImGui.TextWrapped(ctx, "尚无导入目录；添加来源后在此浏览。") end
  local spacing = UI_METRIC.item_y or ui_px(3)
  local row_h = ui_px(24) + spacing
  local base_y = select(2, ImGui.GetCursorPos(ctx))
  local scroll = ImGui.GetScrollY(ctx)
  local window_h = select(2, ImGui.GetWindowSize(ctx))
  local first = math.max(1, math.floor((scroll - base_y) / row_h) + 1)
  local last = math.min(#rows, math.ceil((scroll + window_h - base_y) / row_h) + 1)
  if first > 1 then ImGui.Dummy(ctx, 0, math.min(#rows, first - 1) * row_h - spacing) end
  for index = first, last do draw_folder_sidebar_row(rows[index]) end
  local remaining = #rows - math.max(last, first - 1)
  if remaining > 0 then ImGui.Dummy(ctx, 0, remaining * row_h - spacing) end
  if not complete then ImGui.TextDisabled(ctx, "正在准备可见目录…") end
  if dark_button("+ 添加来源目录", -1) then add_root(state.library_filter_id) end
end

function draw_workspace_navigation_options()
  ImGui.TextWrapped(ctx, "模块隐藏不会删除数据或清除筛选；可随时从此处恢复。")
  for _, mode in ipairs({ "libraries", "folders", "both" }) do
    local label = ({ libraries = "音效库视图", folders = "文件夹视图", both = "同时显示两种导航" })[mode]
    if ImGui.RadioButton(ctx, translate_ui_text(label), mode == state.sidebar_navigation_mode) then
      AppState.set("sidebar_navigation_mode", mode)
      AppState.mark_dirty("config_dirty")
    end
  end
  ImGui.Separator(ctx)
  for _, mode in ipairs({ "tree", "roots" }) do
    if ImGui.RadioButton(ctx, translate_ui_text(mode == "tree" and "显示文件夹层级" or "仅显示导入根目录"), mode == state.sidebar_folder_mode) then
      AppState.set("sidebar_folder_mode", mode)
      AppState.mark_dirty("config_dirty")
      folder_sidebar_invalidate()
    end
  end
  ImGui.Separator(ctx)
  for _, key in ipairs(WORKSPACE_SECTION_KEYS) do
    local changed, enabled = ImGui.Checkbox(ctx, sidebar_section_label(key) .. "##show_" .. key, state.sidebar_modules[key] ~= false)
    if changed then
      AppState.update("sidebar_modules", function(modules) modules[key] = enabled return modules end)
      AppState.mark_dirty("config_dirty")
    end
  end
end

function draw_settings_workspace()
  settings_section_title("字体与布局缩放", "字体、行高、列宽和试听控件联动；更改在下一帧生效。")
  ImGui.SetNextItemWidth(ctx, math.min(ui_px(280), select(1, ImGui.GetContentRegionAvail(ctx)) * 0.6))
  local changed, size = ImGui.SliderDouble(ctx, "字体大小", ui_font_size(), 10, 24, "%.0f px")
  if changed then AppState.set("ui_font_size", ui_font_size(size)) AppState.mark_dirty("config_dirty") end
  if dark_button("恢复默认字体（13 px）", -1) then AppState.set("ui_font_size", 13) AppState.mark_dirty("config_dirty") end
  ImGui.TextWrapped(ctx, "字体预览：金属撞击 · Metal impact · 48 kHz / 24 bit")
  ImGui.TextWrapped(ctx, "波形列随字体同比缩放，手动列宽按基准尺寸保存；空间不足时保留横向滚动，不压扁波形。小窗口临时折叠侧栏，不改保存的开关。")
  settings_section_title("左侧导航", "选择音效库或文件管理器式导航；仅显示已导入索引中的目录。")
  ImGui.SetNextItemWidth(ctx, math.min(ui_px(280), select(1, ImGui.GetContentRegionAvail(ctx)) * 0.6))
  changed, size = ImGui.SliderDouble(ctx, "导航基准宽度", state.sidebar_width or 240, 160, 520, "%.0f px")
  if changed then AppState.set("sidebar_width", size) AppState.mark_dirty("config_dirty") end
  draw_workspace_navigation_options()
  ImGui.TextWrapped(ctx, "层级树复用素材索引，按需分帧建立与排序；浏览不会扫描硬盘、复制或移动音频。空目录不会显示。展开箭头仅展开，点击名称筛选，双击名称展开并筛选。")
end
