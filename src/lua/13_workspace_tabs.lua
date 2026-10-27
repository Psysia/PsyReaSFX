-- Lightweight browser tabs. Assets, waveforms, API presets and maintenance
-- jobs remain shared; only browsing context and completed result references
-- belong to a tab. No disk scanning, audio copies or API calls on switching.
WorkspaceTabs = { limit = 24, cache_tabs = 12, cache_rows = 1000000, refresh_interval = 1 }
local context_keys = { "search", "view", "root_filter", "library_filter_id", "active_collection_id",
  "status_filter", "ucs_filter_category", "ucs_filter_subcategory", "ucs_filter_catid", "sort_mode", "sort_desc" }
local runtime_keys = { "results", "selected_index", "selected_path", "selected_set", "selection_anchor",
  "results_scroll_x", "results_scroll_y", "region_start", "region_end", "wave_view_start", "wave_view_end",
  "active_region_index", "similarity_lookup", "similarity_result_count", "similarity_reference_path",
  "similarity_reference_name", "ai_semantic_lookup", "ai_semantic_result_count", "ai_semantic_last_query",
  "ai_semantic_last_summary", "ai_semantic_paging", "ai_semantic_has_more", "ai_semantic_loaded_candidates",
  "ai_semantic_total_candidates" }
local allowed_views = { all=true, favorites=true, recent=true, previewed=true, similar=true, ai_semantic=true,
  missing=true, duplicates=true, duplicates_confirmed=true, duplicate_failures=true, project_used=true,
  ucs_pending=true, ucs_category=true, ucs_subcategory=true, ucs_catid=true }
local allowed_sorts = { name=true, duration=true, library=true, used=true, previewed=true, similarity=true, ai_order=true }

local function copy_fields(source, keys)
  local output = {}
  for _, key in ipairs(keys) do output[key] = source[key] end
  return output
end

local function copy_map(source)
  local output = {}
  for key, value in pairs(source or {}) do output[key] = value end
  return output
end

local function default_context()
  return { search="", view="all", sort_mode="name", sort_desc=false }
end

local function assign_tab_numbers(tabs)
  local used = {}
  for _, tab in ipairs(tabs) do
    local number = tab.number
    if type(number) == "number" and number == math.floor(number)
      and number >= 1 and number <= WorkspaceTabs.limit and not used[number] then
      used[number] = true
    else tab.number = nil end
  end
  for _, tab in ipairs(tabs) do
    if not tab.number then
      local number = 1
      while used[number] do number = number + 1 end
      tab.number, used[number] = number, true
    end
  end
end

local function next_tab_number()
  local used = {}
  for _, tab in ipairs(state.workspace_tabs) do used[tab.number] = true end
  local number = 1
  while used[number] do number = number + 1 end
  return number
end

function workspace_tab_by_id(id)
  for index, tab in ipairs(state.workspace_tabs or {}) do
    if tab.id == id then return tab, index end
  end
end

local function context_depends_on(context, change, asset)
  local query = (context.search or ""):lower()
  local function field(names)
    for _, name in ipairs(names) do if query:find(name..":",1,true) then return true end end
    return false
  end
  if change == "display" then return false end
  if change == true then
    return context.view == "previewed" or context.sort_mode == "previewed" or field({"played","previewed"})
  elseif change == "missing" then
    return context.view == "missing" or field({"missing","offline"})
  elseif change == "duplicates" then
    return context.view == "duplicates" or context.view == "duplicates_confirmed"
      or context.view == "duplicate_failures" or field({"duplicate","dupe"})
  elseif change == "project" then
    return context.view == "project_used" or field({"project","used"})
  elseif change == "favorites" then
    return context.view == "favorites" or field({"fav","favorite"})
  elseif change == "usage" then
    return context.view == "recent" or context.sort_mode == "used"
  elseif change == "collection" then
    return context.active_collection_id == asset
  elseif change == "background" and asset then
    if context.library_filter_id and context.library_filter_id ~= asset.library_id then return false end
    if context.root_filter and type(path_is_inside) == "function"
      and not path_is_inside(asset.path,context.root_filter) then return false end
    if context.active_collection_id then
      local collection = (state.collection_by_id or {})[context.active_collection_id]
      if not collection or not (collection.items or {})[path_key(asset.path)] then return false end
    end
  end
  return true
end

function workspace_tabs_invalidate(change, asset)
  local structural = change == nil
  if structural then AppState.set("workspace_tabs_revision", (state.workspace_tabs_revision or 0) + 1) end
  local active = workspace_tab_by_id(state.workspace_tab_active)
  for _, tab in ipairs(state.workspace_tabs or {}) do
    local context = tab == active and state or tab.context
    if context_depends_on(context, change, asset) then
      if structural then
        -- Removed/replaced catalog objects must not survive in a snapshot.
        if tab.runtime then tab.runtime.results = nil end
        tab.runtime_valid = false
      end
      tab.refresh_pending = true
    end
  end
  if context_depends_on(state, change, asset) then
    if change == "background" then
      -- Coalesce background metadata/wave completion. Never restart an
      -- in-flight build per asset; retain each page's last completed rows.
      if not state.workspace_results_refresh_at then
        AppState.set("workspace_results_refresh_at", workspace_tabs_now() + WorkspaceTabs.refresh_interval)
      end
    else AppState.mark_dirty("results_dirty") end
  end
end

function workspace_tabs_now()
  return HostApi and HostApi.time_precise and HostApi.time_precise() or os.clock()
end

function workspace_tabs_process_refresh()
  local tab = workspace_tab_by_id(state.workspace_tab_active)
  if not tab or not tab.refresh_pending or state.results_dirty or state.results_job then return end
  local now = workspace_tabs_now()
  local due = state.workspace_results_refresh_at
  if not due then
    AppState.set("workspace_results_refresh_at", now + WorkspaceTabs.refresh_interval)
  elseif now >= due then
    AppState.mark_dirty("results_dirty")
  end
end

function workspace_tabs_results_started()
  workspace_tabs_track()
  local tab = workspace_tab_by_id(state.workspace_tab_active)
  if tab then tab.refresh_pending = false end
  AppState.set("workspace_results_refresh_at", workspace_tabs_now() + WorkspaceTabs.refresh_interval)
end

function workspace_tabs_results_completed()
  -- Save at completion, not just when leaving the tab. A later background
  -- update must not erase the last usable snapshot before a switch.
  workspace_tab_capture()
end

function workspace_tabs_ensure()
  if state.workspace_tabs and #state.workspace_tabs > 0 then
    assign_tab_numbers(state.workspace_tabs)
    return
  end
  AppState.set("workspace_tabs", { { id=1, number=1, context=copy_fields(state, context_keys) } })
  AppState.set("workspace_tab_active", 1)
  AppState.set("workspace_tab_sequence", 1)
  AppState.set("workspace_tab_select", 1)
end

function workspace_tabs_busy()
  return state.startup_session or state.root_removal_session or state.external_drag
    or state.similarity_session or state.ai_semantic_session
end

local function permit_switch()
  if workspace_tabs_busy() then
    set_status("请等待或取消当前 AI / 相似声音任务后再切换标签页", true)
    return false
  end
  return true
end

local function context_equal(left, right)
  for _, key in ipairs(context_keys) do if left[key] ~= right[key] then return false end end
  return true
end

function workspace_tabs_track()
  workspace_tabs_ensure()
  local tab = workspace_tab_by_id(state.workspace_tab_active)
  if not context_equal(tab.context, state) then
    tab.context = copy_fields(state, context_keys)
    tab.runtime = nil
    tab.refresh_pending = false
    AppState.mark_dirty("config_dirty")
  end
  -- These global lookups are replaced by background jobs, without necessarily
  -- dirtying an inactive view. Detect the replacement in constant time.
  local watched = { state.assets, state.by_path, state.duplicate_lookup, state.duplicate_confirmed_lookup,
    state.duplicate_confirmation_failures, state.missing_assets, state.current_project_path }
  local prior = state.workspace_tabs_catalog_watch
  if prior then
    for index=1,7 do
      if prior[index] ~= watched[index] then
        if index <= 2 then workspace_tabs_invalidate()
        else workspace_tabs_invalidate(index <= 5 and "duplicates" or index == 6 and "missing" or "project") end
      end
    end
  end
  AppState.set("workspace_tabs_catalog_watch", watched)
end

function workspace_tabs_trim_cache()
  local cached, rows, arrays = {}, 0, {}
  for _, tab in ipairs(state.workspace_tabs or {}) do
    if tab.runtime and tab.runtime.results then
      local results = tab.runtime.results
      if not arrays[results] then rows = rows + #results end
      arrays[results] = (arrays[results] or 0) + 1
      cached[#cached+1] = tab
    end
  end
  table.sort(cached, function(a,b) return (a.used or 0) < (b.used or 0) end)
  local count = #cached
  for _, tab in ipairs(cached) do
    if count <= WorkspaceTabs.cache_tabs and rows <= WorkspaceTabs.cache_rows then break end
    if tab.id ~= state.workspace_tab_active then
      local results = tab.runtime.results
      arrays[results] = arrays[results] - 1
      if arrays[results] == 0 then rows = rows - #results end
      tab.runtime.results = nil
      tab.runtime_valid = false
      count = count - 1
    end
  end
end

function workspace_tab_capture()
  workspace_tabs_track()
  local tab = workspace_tab_by_id(state.workspace_tab_active)
  tab.context = copy_fields(state, context_keys)
  local runtime = copy_fields(state, runtime_keys)
  -- Move ownership on ordinary switches; duplication alone needs a copy.
  -- Ctrl+A on a huge library must not clone its selection on every switch.
  runtime.selected_set = state.selected_set or {}
  local complete = not state.results_dirty and not state.results_job
  local previous = tab.runtime
  if not complete and tab.runtime_valid and previous and previous.results
    and tab.revision == (state.workspace_tabs_revision or 0) then
    runtime.results = previous.results
    tab.refresh_pending = true
  else tab.runtime_valid = complete end
  tab.runtime = runtime
  tab.revision = state.workspace_tabs_revision or 0
  AppState.set("workspace_tab_clock", (state.workspace_tab_clock or 0) + 1)
  tab.used = state.workspace_tab_clock
  workspace_tabs_trim_cache()
  return tab
end

local function reset_runtime()
  for _, key in ipairs(runtime_keys) do AppState.set(key, nil) end
  AppState.apply({ results={}, selected_index=0, selected_set={}, selection_anchor=0,
    results_scroll_x=0, results_scroll_y=0, region_start=0, region_end=1, wave_view_start=0, wave_view_end=1,
    active_region_index=0, similarity_lookup={}, similarity_result_count=0, ai_semantic_lookup={},
    ai_semantic_result_count=0, ai_semantic_last_query="", ai_semantic_last_summary="", ai_semantic_has_more=false,
    ai_semantic_loaded_candidates=0, ai_semantic_total_candidates=0 })
end

local function restore_tab(tab)
  if type(stop_preview) == "function" then stop_preview() end
  -- Incomplete result jobs use active global predicates: never resume them in
  -- a different tab. Only the active tab performs an incremental rebuild.
  AppState.set("results_job", nil)
  AppState.set("results_scroll_request", nil)
  AppState.set("results_scroll_y_request", nil)
  AppState.set("wave_drag_start", nil)
  AppState.set("wave_pan_last_x", nil)
  AppState.set("ucs_search_popup_visible", false)
  for _, key in ipairs(context_keys) do AppState.set(key, tab.context[key]) end
  if state.library_filter_id and not (state.library_by_id or {})[state.library_filter_id] then
    AppState.set("library_filter_id", nil)
  end
  if state.active_collection_id and not (state.collection_by_id or {})[state.active_collection_id] then
    AppState.set("active_collection_id", nil)
  end
  if state.root_filter and type(root_for_path) == "function" then
    local _, record = root_for_path(state.root_filter)
    if not record then AppState.set("root_filter", nil) end
  end
  local runtime = tab.runtime
  reset_runtime()
  if runtime then
    for _, key in ipairs(runtime_keys) do
      if runtime[key] ~= nil then AppState.set(key, runtime[key]) end
    end
    AppState.set("selected_set", runtime.selected_set or {})
  end
  local valid = runtime and runtime.results and tab.runtime_valid
    and tab.revision == (state.workspace_tabs_revision or 0) and context_equal(tab.context, state)
  if not valid then AppState.set("results", {}) end
  AppState.set("results_dirty", not valid)
  if valid and tab.refresh_pending then
    AppState.set("workspace_results_refresh_at", workspace_tabs_now() + WorkspaceTabs.refresh_interval)
  end
  AppState.set("workspace_tab_scroll_restore", {x=state.results_scroll_x or 0,y=state.results_scroll_y or 0,frames=2})
  AppState.set("workspace_tab_active", tab.id)
  AppState.set("workspace_tab_select", tab.id)
  AppState.mark_dirty("config_dirty")
  if tab.restore_notice then
    set_status("标签页已恢复；AI / 相似声音结果仅在本次会话保留，需要时重新搜索。")
    tab.restore_notice = nil
  end
  if state.selected_path and not (state.by_path or {})[path_key(state.selected_path)] then
    AppState.set("selected_path", nil)
    AppState.apply({selected_set={}, selected_index=0, selection_anchor=0})
  elseif state.selected_path then
    local asset = state.by_path[path_key(state.selected_path)]
    if type(queue_metadata) == "function" then queue_metadata(asset, true) end
    if type(queue_wave) == "function" then queue_wave(asset, LARGE_WAVE_DEFAULT_POINTS, true) end
  end
end

function workspace_tab_activate(id)
  workspace_tabs_ensure()
  local tab = workspace_tab_by_id(id)
  if not tab or id == state.workspace_tab_active then return false end
  if not permit_switch() then return false end
  workspace_tab_capture()
  restore_tab(tab)
  return true
end

function workspace_tab_new(duplicate_id)
  workspace_tabs_ensure()
  if #state.workspace_tabs >= WorkspaceTabs.limit then
    set_status("最多打开 24 个标签页，请先关闭不需要的标签页", true) return false
  end
  if not permit_switch() then return false end
  local current = workspace_tab_capture()
  local source = duplicate_id and workspace_tab_by_id(duplicate_id)
  local id = (state.workspace_tab_sequence or 0) + 1
  -- Display numbers reuse free slots; internal IDs remain unique for ImGui,
  -- caches and pending selection requests, including immediately after close.
  local tab = { id=id, number=next_tab_number(),
    context=source and copy_fields(source.context, context_keys) or default_context() }
  if not source then
    for _, cached in ipairs(state.workspace_tabs) do
      if cached.runtime_valid and cached.revision == (state.workspace_tabs_revision or 0)
        and cached.runtime and cached.runtime.results and context_equal(cached.context, tab.context) then
        tab.runtime = {results=cached.runtime.results}
        tab.runtime_valid, tab.revision = true, cached.revision
        tab.refresh_pending = cached.refresh_pending
        break
      end
    end
  end
  if source then
    tab.name = source.name
    tab.runtime = source.runtime and copy_fields(source.runtime, runtime_keys)
    if tab.runtime then
      tab.runtime.selected_set = copy_map(source.runtime.selected_set)
      -- AI page descriptors are immutable; next-page loading replaces them.
      -- Result arrays/lookups reference the shared assets and are not cloned.
    end
    tab.runtime_valid, tab.revision = source.runtime_valid, source.revision
    tab.refresh_pending = source.refresh_pending
  end
  table.insert(state.workspace_tabs, select(2, workspace_tab_by_id(current.id)) + 1, tab)
  AppState.set("workspace_tab_sequence", id)
  restore_tab(tab)
  workspace_tabs_trim_cache()
  AppState.set("focus_search", not duplicate_id)
  return id
end

function workspace_tab_close(id, mode)
  workspace_tabs_ensure()
  local tab, position = workspace_tab_by_id(id)
  if not tab then return false end
  local removed, kept = {}, {}
  for index, item in ipairs(state.workspace_tabs) do
    local remove = (mode == "others" and item.id ~= id)
      or (mode == "right" and index > position) or (not mode and item.id == id)
    if remove then removed[item.id] = true else kept[#kept+1] = item end
  end
  if not next(removed) then return false end
  if removed[state.workspace_tab_active] then
    if not permit_switch() then return false end
    if #kept == 0 then
      -- Closing the final tab resets it to a fresh browser, never exits REAPER.
      local next_id = (state.workspace_tab_sequence or 0) + 1
      kept[1] = { id=next_id, number=1, context=default_context() }
      AppState.set("workspace_tab_sequence", next_id)
    end
    local target = mode == "others" and tab or kept[math.min(position, #kept)]
    restore_tab(target)
  end
  AppState.set("workspace_tabs", kept)
  AppState.mark_dirty("config_dirty")
  return true
end

function workspace_tab_move(id, direction)
  local tab, index = workspace_tab_by_id(id)
  if not tab then return false end
  local target = math.max(1, math.min(#state.workspace_tabs, index + direction))
  if target == index then return false end
  table.remove(state.workspace_tabs, index)
  table.insert(state.workspace_tabs, target, tab)
  AppState.mark_dirty("config_dirty")
  return true
end

function workspace_tab_title(tab)
  if tab.name then return tab.name end
  local context = tab.id == state.workspace_tab_active and state or tab.context
  local query = trim(context.search or "")
  if query ~= "" then return compact(query, 24) end
  local library = (state.library_by_id or {})[context.library_filter_id]
  if context.root_filter then return basename(context.root_filter) end
  if library then return library.name end
  local collection = (state.collection_by_id or {})[context.active_collection_id]
  if collection then return collection.name end
  local titles = {favorites="收藏",recent="最近插入",previewed="试听历史",project_used="工程已用"}
  if titles[context.view] then return translate_ui_text(titles[context.view]) end
  return translate_ui_text("标签页") .. " " .. tab.number
end

function workspace_tab_label(tab)
  local context = tab.id == state.workspace_tab_active and state or tab.context
  local prefix = context.view == "ai_semantic" and "AI · " or context.view == "similar"
    and (translate_ui_text("相似声音") .. " · ") or ""
  -- User-provided ### must not change the stable ImGui identity.
  return prefix .. compact(workspace_tab_title(tab),28):gsub("#", "＃") .. "###workspace_tab_" .. tab.id
end

function workspace_tabs_apply_scroll()
  local pending = state.workspace_tab_scroll_restore
  if not pending or state.results_dirty or state.results_job then return end
  -- ImGui computes the new content extent at EndChild. Repeating over two
  -- frames avoids clamping a new tab against the previous frame's extent.
  ImGui.SetScrollX(ctx, math.max(0,pending.x))
  ImGui.SetScrollY(ctx, math.max(0,pending.y))
  pending.frames = pending.frames - 1
  if pending.frames <= 0 then AppState.set("workspace_tab_scroll_restore", nil) end
end

function workspace_tabs_write_settings(file)
  workspace_tabs_track()
  local tabs = {}
  for _, tab in ipairs(state.workspace_tabs) do
    tabs[#tabs+1] = { id=tab.id, number=tab.number, name=tab.name, context=copy_fields(tab.context, context_keys) }
  end
  file:write("setting\tworkspace_tabs_json\t", escape_tsv(neural_json_encode({schema=1,
    active=state.workspace_tab_active, sequence=state.workspace_tab_sequence, tabs=tabs})), "\n")
end

function workspace_tabs_reset()
  AppState.set("workspace_tabs", nil)
  AppState.set("workspace_tabs_catalog_watch", nil)
  AppState.set("workspace_tab_scroll_restore", nil)
  AppState.set("workspace_tab_rename_open", nil)
  AppState.set("workspace_results_refresh_at", nil)
  workspace_tabs_ensure()
end

function workspace_tabs_load_setting(name, value)
  if name ~= "workspace_tabs_json" then return false end
  if type(value) ~= "string" or #value > 2097152 then return true end
  local ok, data = pcall(neural_json_decode, value)
  if not ok or type(data) ~= "table" or data.schema ~= 1 or type(data.tabs) ~= "table" then return true end
  local tabs, ids, sequence = {}, {}, 0
  for index, input in ipairs(data.tabs) do
    if index > WorkspaceTabs.limit then break end
    local id = type(input) == "table" and tonumber(input.id)
    if id and id == math.floor(id) and id > 0 and id < 1000000000 and not ids[id]
      and type(input.context) == "table" then
      local context = default_context()
      for _, key in ipairs(context_keys) do
        local v = input.context[key]
        if key ~= "sort_desc" and type(v) == "string" and v ~= "" then
          context[key] = type(utf8_prefix) == "function" and utf8_prefix(v,8192) or v:sub(1,8192)
        end
      end
      context.view = allowed_views[context.view] and context.view or "all"
      context.sort_mode = allowed_sorts[context.sort_mode] and context.sort_mode or "name"
      context.sort_desc = input.context.sort_desc == true
      local name = type(input.name) == "string" and compact(trim(input.name),64) or ""
      tabs[#tabs+1] = {id=id, number=input.number, name=name ~= "" and name or nil, context=context}
      ids[id], sequence = true, math.max(sequence,id)
    end
  end
  if #tabs > 0 then
    -- Older settings have only monotonically increasing IDs. Migrate their
    -- visible numbers without changing IDs, names, ordering or search scopes.
    assign_tab_numbers(tabs)
    AppState.set("workspace_tabs", tabs)
    AppState.set("workspace_tab_sequence", sequence)
    AppState.set("workspace_tab_active", ids[data.active] and data.active or tabs[1].id)
    AppState.set("workspace_tabs_loaded", true)
  end
  return true
end

function workspace_tabs_initialize()
  workspace_tabs_ensure()
  if state.workspace_tabs_loaded then
    -- Ranked payloads are memory-only: no automatic network/audio analysis
    -- or hundreds of thousands of persisted rows during startup.
    for _, tab in ipairs(state.workspace_tabs) do
      if tab.context.view == "ai_semantic" or tab.context.view == "similar" then
        tab.context.view, tab.context.sort_mode, tab.context.sort_desc = "all", "name", false
        tab.restore_notice = true
      end
    end
    restore_tab(workspace_tab_by_id(state.workspace_tab_active))
    AppState.set("workspace_tabs_loaded", nil)
  end
end

function workspace_tabs_keyboard(ctrl, shift)
  if not ctrl then return false end
  if ImGui.IsKeyPressed(ctx, ImGui.Key_N, false) then
    workspace_tab_new(shift and state.workspace_tab_active or nil) return true
  elseif ImGui.IsKeyPressed(ctx, ImGui.Key_W, false) then
    workspace_tab_close(state.workspace_tab_active) return true
  elseif ImGui.IsKeyPressed(ctx, ImGui.Key_Tab, false) then
    workspace_tabs_ensure()
    local _, index = workspace_tab_by_id(state.workspace_tab_active)
    local target = (index - 1 + (shift and -1 or 1)) % #state.workspace_tabs + 1
    workspace_tab_activate(state.workspace_tabs[target].id) return true
  end
  return false
end

function draw_workspace_tab_rename_popup()
  if state.workspace_tab_rename_open then
    ImGui.OpenPopup(ctx, "重命名标签页##workspace_tab_rename")
    AppState.set("workspace_tab_rename_open", nil)
    AppState.set("workspace_tab_rename_focus", true)
  end
  if ImGui.BeginPopupModal(ctx, "重命名标签页##workspace_tab_rename", true, ImGui.WindowFlags_AlwaysAutoResize) then
    if state.workspace_tab_rename_focus then
      ImGui.SetKeyboardFocusHere(ctx)
      AppState.set("workspace_tab_rename_focus", nil)
    end
    ImGui.SetNextItemWidth(ctx, ui_px(260))
    local _, value = ImGui.InputText(ctx, "名称##workspace_tab_name", state.workspace_tab_rename_text or "")
    AppState.set("workspace_tab_rename_text", value)
    local confirm = ImGui.IsItemActive(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_Enter, false)
    if confirm then AppState.set("keyboard_consumed", true) end
    if dark_button("保存##workspace_tab_name_save", ui_px(90)) or confirm then
      local tab = workspace_tab_by_id(state.workspace_tab_rename_id)
      local name = compact(trim(value),64)
      if tab then tab.name = name ~= "" and name or nil AppState.mark_dirty("config_dirty") end
      ImGui.CloseCurrentPopup(ctx)
    end
    ImGui.SameLine(ctx)
    if dark_button("取消##workspace_tab_name_cancel", ui_px(90)) then ImGui.CloseCurrentPopup(ctx) end
    ImGui.TextDisabled(ctx, "留空恢复自动名称")
    ImGui.EndPopup(ctx)
  end
end

function draw_workspace_tabs()
  workspace_tabs_track()
  local action, id, confirmed_selection
  local requested_selection = state.workspace_tab_select
  if ImGui.BeginTabBar(ctx, "##workspace_tabs", ImGui.TabBarFlags_FittingPolicyScroll | ImGui.TabBarFlags_TabListPopupButton) then
    if ImGui.TabItemButton(ctx, "+##workspace_new_tab", ImGui.TabItemFlags_Trailing) then action="new" end
    tooltip("新建标签页（Ctrl+N）；复制当前页 Ctrl+Shift+N；关闭 Ctrl+W；切换 Ctrl+Tab")
    for _, tab in ipairs(state.workspace_tabs) do
      local flags = ImGui.TabItemFlags_NoReorder | ImGui.TabItemFlags_NoAssumedClosure
      if tab.id == state.workspace_tab_select then flags = flags | ImGui.TabItemFlags_SetSelected end
      local selected, open = ImGui.BeginTabItem(ctx, workspace_tab_label(tab), true, flags)
      if selected then
        if tab.id == requested_selection then confirmed_selection = true end
        if not action and not requested_selection and tab.id ~= state.workspace_tab_active then
          action, id="activate",tab.id
        end
        ImGui.EndTabItem(ctx)
      end
      if open == false then action, id="close",tab.id end
      if ImGui.IsItemHovered(ctx) then
        tooltip((tab.context.search or "") .. "\n" .. (tab.context.root_filter or "")
          .. "\n" .. translate_ui_text("切换标签不重新调用 API；进行中的任务需先结束或取消。"))
      end
      if ImGui.BeginPopupContextItem(ctx, "workspace_tab_menu_" .. tab.id) then
        if ImGui.MenuItem(ctx, "新建标签页") then action="new" end
        if ImGui.MenuItem(ctx, "复制标签页") then action,id="duplicate",tab.id end
        if ImGui.MenuItem(ctx, "重命名标签页") then action,id="rename",tab.id end
        ImGui.Separator(ctx)
        if ImGui.MenuItem(ctx, "关闭标签页") then action,id="close",tab.id end
        if ImGui.MenuItem(ctx, "关闭其他标签页") then action,id="others",tab.id end
        if ImGui.MenuItem(ctx, "关闭右侧标签页") then action,id="right",tab.id end
        ImGui.Separator(ctx)
        if ImGui.MenuItem(ctx, "向左移动标签页") then action,id="left",tab.id end
        if ImGui.MenuItem(ctx, "向右移动标签页") then action,id="move_right",tab.id end
        ImGui.EndPopup(ctx)
      end
    end
    ImGui.EndTabBar(ctx)
    -- Dear ImGui queues SetSelected for the following frame. An old visible
    -- tab is not a user selection until the requested target is confirmed.
    if confirmed_selection then AppState.set("workspace_tab_select", nil) end
  end
  -- Mutate only after all tab items/popups have been balanced.
  if action == "new" then workspace_tab_new()
  elseif action == "duplicate" then workspace_tab_new(id)
  elseif action == "activate" then
    if workspace_tab_activate(id) then
      -- Native selection is already visible; do not send a redundant request.
      AppState.set("workspace_tab_select", nil)
    else AppState.set("workspace_tab_select", state.workspace_tab_active) end
  elseif action == "close" or action == "others" or action == "right" then
    if not workspace_tab_close(id, action ~= "close" and action or nil) then
      AppState.set("workspace_tab_select", state.workspace_tab_active)
    end
  elseif action == "left" or action == "move_right" then workspace_tab_move(id, action == "left" and -1 or 1)
  elseif action == "rename" then
    local tab = workspace_tab_by_id(id)
    AppState.apply({workspace_tab_rename_id=id, workspace_tab_rename_text=tab.name or workspace_tab_title(tab),
      workspace_tab_rename_open=true})
  end
  draw_workspace_tab_rename_popup()
end
