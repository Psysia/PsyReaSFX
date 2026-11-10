-- The browser consumes bounded snapshots. Catalogs and native resources stay in Lua.
WebUI = { protocol = 1, revision = 0, next_publish = 0, outbox = {}, handlers = {} }

local function text(value, maximum)
  value = tostring(value or "")
  maximum = maximum or 4096
  if #value <= maximum then
    return value
  end
  while maximum > 0 and ((value:byte(maximum + 1) or 0) & 0xC0) == 0x80 do
    maximum = maximum - 1
  end
  return value:sub(1, maximum)
end

local function number(value, minimum, maximum)
  value = tonumber(value)
  assert(value and value == value and value >= minimum and value <= maximum, "参数超出范围")
  return value
end

local function asset_for(path)
  local asset = state.by_path[path_key(text(path))]
  assert(asset, "素材已移除，请刷新列表")
  return asset
end

local function writable()
  assert(
    not state.persistence_read_only,
    state.persistence_read_only_reason or "素材库处于只读保护"
  )
end

local function asset_data(asset)
  if not asset then
    return nil
  end
  local output = {
    path = asset.path,
    name = asset.name,
    duration = asset.duration or 0,
    channels = asset.channels or 0,
    sampleRate = asset.sample_rate or 0,
    bitDepth = asset.bit_depth or 0,
    format = string.format(
      "%s  %s  %dch",
      format_rate(asset.sample_rate),
      (tonumber(asset.bit_depth) or 0) > 0 and tostring(asset.bit_depth) .. "-bit" or "—",
      tonumber(asset.channels) or 0
    ),
    library = asset.library or (state.library_by_id[asset.library_id] or {}).name or "",
    favorite = state.favorites[asset_path_sort_key(asset)] == true,
    marked = asset.marked == true,
    played = asset_is_session_played(asset) == true,
    waveError = not not asset.wave_error,
    previewCount = asset.preview_count or 0,
    usedCount = asset.used_count or 0,
    workflowLabel = workflow_label(asset.workflow_status or "none"),
  }
  local similarity = "similar" == state.view and similarity_result_for_asset(asset)
  output.similarity = similarity and string.format("%.0f%%", similarity.score or 0) or ""
  output.truncated = {}
  for _, field in ipairs({
    "description",
    "keywords",
    "category",
    "subcategory",
    "catid",
    "notes",
    "artwork_path",
    "workflow_status",
  }) do
    output[field] = text(asset[field])
    if output[field] ~= tostring(asset[field] or "") then
      output.truncated[field] = true
    end
  end
  return output
end

local function refresh_revision()
  if WebUI.results ~= state.results then
    WebUI.results = state.results
    WebUI.revision = WebUI.revision + 1
  end
end

local function send(message)
  local encoded = neural_json_encode(message)
  if #encoded > 900000 then
    encoded = neural_json_encode({
      protocol = WebUI.protocol,
      id = message.id,
      ok = false,
      error = "响应过大，请缩小请求范围",
    })
  end
  if reaper.ReaWeb_Send(WebUI.window, encoded) then
    return true
  end
  if #WebUI.outbox >= 64 then
    -- A page that stopped consuming messages must reconnect, not accumulate writes.
    reaper.ReaWeb_Close(WebUI.window)
    return false
  end
  WebUI.outbox[#WebUI.outbox + 1] = encoded
  return false
end

local function waveform(asset, points, channels)
  local preserve = channels and state.multichannel_waveform ~= false
  local wave = queue_wave(asset, points, channels, preserve, channels and state.spectral_peaks_enabled, true)
  if not wave then
    return nil
  end
  return {
    count = wave.count,
    peaks = wave.peaks,
    channels = wave.channel_peaks,
    channelCount = wave.channels,
    spectralFrequency = wave.spectral_frequency,
    spectralTonality = wave.spectral_tonality,
  }
end

local function runtime_owner(path)
  if
    type(reaper.ReaPack_GetOwner) ~= "function" or type(reaper.ReaPack_FreeEntry) ~= "function"
  then
    return nil
  end
  local ok, entry = pcall(reaper.ReaPack_GetOwner, path)
  if not ok or not entry then
    return nil
  end
  local owner = { entry = entry, filter = "ReaWebAPI", label = "已有 ReaPack 组件" }
  local parsed, found, repository, category, package_name, description, kind, version =
    pcall(reaper.ReaPack_GetEntryInfo, entry)
  if parsed and found and type(package_name) == "string" and package_name ~= "" then
    owner.filter = package_name:gsub("%.ext$", "")
    owner.label = text(repository, 256) .. " / " .. package_name .. " " .. text(version, 128)
  end
  return owner
end

local function prompt_runtime_install(missing_api)
  local has_reapack = type(reaper.ReaPack_BrowsePackages) == "function"
  local path = reaper.GetResourcePath() .. "/UserPlugins/reaper_reawebapi-x64.dll"
  local owner = runtime_owner(path)
  local installed = owner ~= nil or reaper.file_exists(path)
  local filter = owner and owner.filter
    or (installed and "ReaWebAPI" or "PsyReaSFX WebView Runtime")
  local instructions = installed
      and "已发现 ReaWebAPI 的安装记录或 DLL。请先重启 REAPER，使已安装的组件生效。\n" .. "版本缺少接口时，请在原组件中检查更新。\n"
    or "首次安装可选择 PsyReaSFX WebView Runtime，并在 Psysia 软件源启用预发布和同步。\n"
  if owner then
    instructions = instructions .. "当前归属 " .. owner.label .. "\n"
  end
  local title = SCRIPT_NAME .. " · WebView 运行时未就绪"
  local destination = has_reapack
      and (installed and "是否打开现有组件的 ReaPack 页面，检查安装与更新？" or "是否现在打开 ReaPack，并定位到首次安装的运行时组件？")
    or "当前未检测到 ReaPack。是否打开发布页，下载完整测试版安装包？"
  local choice = reaper.MB(
    "未检测到可用的 ReaWebAPI，或当前版本缺少所需接口。\n\n"
      .. instructions
      .. "安装或更新完成后，请重启 REAPER，再运行 PsyReaSFX。\n"
      .. "\n"
      .. destination
      .. "\n\n缺少接口 "
      .. missing_api,
    title,
    4
  )
  if choice == 6 then
    local opened = false
    if has_reapack then
      if owner and type(reaper.ReaPack_AboutInstalledPackage) == "function" then
        local ok, shown = pcall(reaper.ReaPack_AboutInstalledPackage, owner.entry)
        opened = ok and shown == true
      end
      if not opened then
        opened = pcall(reaper.ReaPack_BrowsePackages, filter)
      end
      if not opened then
        reaper.MB("无法打开 ReaPack，将打开发布页下载完整安装包。", title, 0)
      end
    end
    if not opened then
      local url = PROJECT_URL .. "/releases"
      local navigated = pcall(open_url, url)
      if not navigated then
        reaper.MB("无法自动打开浏览器，请手动访问\n\n" .. url, title, 0)
      end
    end
  end
  if owner then
    pcall(reaper.ReaPack_FreeEntry, owner.entry)
  end
end

function webview_open()
  local lock_file = io.open(SCRIPT_DIR .. "runtime-lock.json", "rb")
  local lock_text = lock_file and lock_file:read(32769) or ""
  if lock_file then
    lock_file:close()
  end
  local parsed, lock = pcall(neural_json_decode, lock_text)
  if
    #lock_text > 32768
    or not parsed
    or type(lock) ~= "table"
    or lock.schema ~= "PsyReaSFX-Dependency-Lock-v1"
    or type(lock.runtime_policy) ~= "table"
  then
    reaper.MB(
      "运行时版本清单缺失或损坏，请从完整安装包重新安装。",
      "PsyReaSFX 0.9.a",
      0
    )
    return false
  end
  WebUI.runtime_policy = lock.runtime_policy
  for _, name in ipairs({
    "ReaWeb_Open",
    "ReaWeb_IsOpen",
    "ReaWeb_IsReady",
    "ReaWeb_Send",
    "ReaWeb_Receive",
    "ReaWeb_Close",
  }) do
    if type(reaper[name]) ~= "function" then
      prompt_runtime_install(name)
      return false
    end
  end
  WebUI.key = SCRIPT_FILE:gsub("\\", "/")
  if reaper.GetOS():match("^Win") then WebUI.key = WebUI.key:lower() end
  local id = reaper.ReaWeb_Open(SCRIPT_DIR .. "web/index.html", WebUI.key)
  if not id or id == 0 then
    local failure = reaper.ReaWeb_GetLastError and reaper.ReaWeb_GetLastError()
      or "无法创建 WebView 窗口"
    reaper.MB(failure, "PsyReaSFX WebView", 0)
    return false
  end
  if reaper.GetExtState("PsyReaSFX.Web", WebUI.key) == tostring(id) then
    return false
  end
  WebUI.window = id
  if type(reaper.ReaWeb_SetShortcutRouting) == "function" then
    reaper.ReaWeb_SetShortcutRouting(id, false)
  end
  reaper.SetExtState("PsyReaSFX.Web", WebUI.key, tostring(id), false)
  return true
end

function webview_close()
  WebUI.arrange_drag = nil
  AppState.set("external_drag", nil)
  AppState.set("external_drag_started", false)
  if not WebUI.window then
    return
  end
  if reaper.GetExtState("PsyReaSFX.Web", WebUI.key) == tostring(WebUI.window) then
    reaper.DeleteExtState("PsyReaSFX.Web", WebUI.key, false)
    reaper.ReaWeb_Close(WebUI.window)
  end
end

function WebUI.update_taskbar(now)
  if WebUI.next_taskbar and now < WebUI.next_taskbar then return end
  WebUI.next_taskbar = now + 1
  if not reaper.GetOS():match("^Win") then return end
  for _, name in ipairs({ "JS_Window_Find", "JS_Window_GetClassName", "JS_Window_GetRelated",
    "JS_Window_GetLong", "JS_Window_SetLong", "JS_Window_Show", "JS_Window_IsVisible" }) do
    if type(reaper[name]) ~= "function" then WebUI.taskbar_status = "js_api_unavailable"; return end
  end
  local hwnd = reaper.JS_Window_Find("PsyReaSFX " .. VERSION, true)
  if not hwnd then WebUI.taskbar_status = "window_pending"; return end
  if reaper.JS_Window_GetClassName(hwnd) ~= "ReaWebAPI.Window" then WebUI.taskbar_status = "class_mismatch"; return end
  local style = math.floor(reaper.JS_Window_GetLong(hwnd, "STYLE"))
  local extended = math.floor(reaper.JS_Window_GetLong(hwnd, "EXSTYLE"))
  if (style & 0x40000000) ~= 0 then
    -- A docked child must never acquire a separate taskbar entry.
    if WebUI.taskbar_hwnd == hwnd and (extended & 0x40000) ~= 0 then
      reaper.JS_Window_SetLong(hwnd, "EXSTYLE", extended & ~0x40000)
    end
    WebUI.taskbar_status = "docked"
    return
  end
  -- GetParent returns NULL for owned WS_OVERLAPPED windows: ownership is not
  -- parenthood. ReaWebAPI uses WS_OVERLAPPEDWINDOW, so query GW_OWNER instead.
  if reaper.JS_Window_GetRelated(hwnd, "OWNER") ~= reaper.GetMainHwnd() then
    WebUI.taskbar_status = "owner_mismatch"; return
  end
  local desired = (extended | 0x40000) & ~0x80 -- APPWINDOW, without TOOLWINDOW
  if desired ~= extended then
    local visible = reaper.JS_Window_IsVisible(hwnd)
    if visible then reaper.JS_Window_Show(hwnd, "HIDE") end
    reaper.JS_Window_SetLong(hwnd, "EXSTYLE", desired)
    if visible then reaper.JS_Window_Show(hwnd, (style & 0x20000000) ~= 0 and "SHOWMINIMIZED" or "SHOWNA") end
  end
  WebUI.taskbar_hwnd = hwnd
  WebUI.taskbar_status = (math.floor(reaper.JS_Window_GetLong(hwnd, "EXSTYLE")) & 0x40000) ~= 0 and "enabled" or "unavailable"
end

function WebUI.task_details()
  local result = {}
  local function counter(value)
    if type(value) == "number" and value == value and math.abs(value) < math.huge then
      return math.max(0, math.floor(value))
    end
  end
  for name, session in pairs({ scan = state.scan, import = state.import_session,
    precache = state.precache_session, transfer = state.transfer_job,
    relink = state.relink_plan_session, remove = state.root_removal_session,
    ai = state.ai_semantic_session, verify = state.cache_verify_session }) do
    if type(session) == "table" then
      local current = type(session.current) == "table" and session.current or {}
      result[name] = {
        label = text(translate_ui_text(session.label or session.reason or ""), 160),
        phase = text(session.phase or "", 80),
        completed = counter(session.done) or counter(session.completed) or counter(session.processed)
          or math.max(0, (counter(session.phase == "collect" and session.collect_index or session.index) or 1) - 1),
        total = counter(session.phase == "collect" and session.source_total or session.total) or 0,
        -- Verification stores its file list under `files`; never serialize job arrays.
        files = counter(session.files), directories = counter(session.directories), failed = counter(session.failed),
        automatic = session.watch == true, paused = session.paused,
        path = text(current.path or (type(current.asset) == "table" and current.asset.path)
          or session.output_directory or session.new_root or "", 1024),
      }
    end
  end
  return result
end

WebUI.handlers["session.activity"] = function(params)
  -- Browser interaction has no ReaImGui mouse state. A throttled pulse gives
  -- background jobs the same yield hint as the legacy native UI.
  AppState.set("interaction_until", reaper.time_precise() + 0.6)
  if params.resizing == true then UiMotion.until_time = reaper.time_precise() + 0.35 end
  return true
end

WebUI.handlers["session.ready"] = function()
  WebUI.outbox = {}
  WebUI.last_snapshot = nil
  return {
    protocol = WebUI.protocol,
    product = "PsyReaSFX",
    version = VERSION,
    host = "reaper",
    author = AUTHOR_NAME,
    copyright = COPYRIGHT_TEXT,
    runtimePolicy = WebUI.runtime_policy,
    capabilities = {
      catalog = true,
      preview = true,
      metadata = true,
      transfer = true,
      insert = true,
      nativeDrag = true,
      tasks = true,
    },
  }
end

WebUI.handlers["app.link"] = function(params)
  local links = { project = PROJECT_URL, releases = PROJECT_URL .. "/releases",
    issues = PROJECT_URL .. "/issues", docs = PROJECT_URL .. "/blob/main/" .. (state.language == "en" and "README.md" or "README_zh-CN.md") }
  open_url(assert(links[params.target], "未知项目链接"))
  return true
end

WebUI.handlers["path.choose"] = function(params)
  local initial = text(params.initial or "", 4096)
  assert(not initial:find("%z"), "无效路径")
  local path
  if params.kind == "folder" then
    path = choose_folder("选择输出文件夹", initial)
  elseif params.kind == "artwork" then
    local ok, selected = reaper.GetUserFileNameForRead(initial, translate_ui_text("选择封面"), "png,jpg,jpeg,bmp,tga")
    if ok then path = selected end
  else
    error("未知路径选择类型")
  end
  return { path = path, cancelled = not path or path == "" }
end

WebUI.handlers["catalog.page"] = function(params)
  refresh_revision()
  local offset = math.floor(number(params.offset or 0, 0, 100000000))
  local limit = math.floor(number(params.limit or 60, 1, 100))
  local items = {}
  local bytes = 0
  for index = offset + 1, math.min(offset + limit, #state.results) do
    local asset = state.results[index]
    local item = asset_data(asset)
    item.index = index
    item.selected = state.selected_set[asset_path_sort_key(asset)] == true
    if params.waveforms ~= false then
      item.waveform = waveform(asset, state.mini_wave_points, false)
    end
    local size = #neural_json_encode(item)
    if bytes + size > 700000 then
      break
    end
    items[#items + 1] = item
    bytes = bytes + size
  end
  return {
    revision = WebUI.revision,
    offset = offset,
    total = #state.results,
    pending = results_pending(),
    items = items,
  }
end

WebUI.handlers["catalog.query"] = function(params)
  local views = {
    all = true,
    favorites = true,
    recent = true,
    previewed = true,
    missing = true,
    duplicates = true,
    project_used = true,
    ucs_pending = true,
  }
  if params.view then
    assert(views[params.view], "未知视图")
  end
  local filters = {
    libraryId = "library_filter_id",
    root = "root_filter",
    collectionId = "active_collection_id",
    category = "ucs_filter_category",
    subcategory = "ucs_filter_subcategory",
    catid = "ucs_filter_catid",
  }
  for parameter in pairs(filters) do
    local value = params[parameter]
    assert(value == nil or type(value) == "string", "无效筛选参数")
  end
  if params.search ~= nil then
    if state.ai_semantic_session then ai_semantic_cancel() end
    if "ai_semantic" == state.view then
      AppState.set("view", "all")
      if "ai_order" == state.sort_mode then AppState.apply({ sort_mode = "name", sort_desc = false }) end
    end
    AppState.set("search", text(params.search, 4096))
  end
  if params.view then
    AppState.set("view", params.view)
  end
  for parameter, key in pairs(filters) do
    local value = params[parameter]
    if not params.keepScope or value ~= nil then
      AppState.set(key, value ~= "" and value or nil)
    end
  end
  if params.status ~= nil then
    assert(params.status == "" or WORKFLOW_STATUS[params.status], "未知工作流筛选")
    AppState.set("status_filter", params.status ~= "" and params.status or nil)
  elseif not params.keepScope then
    AppState.set("status_filter", nil)
  end
  if state.ucs_filter_catid then
    AppState.set("view", "ucs_catid")
  elseif state.ucs_filter_category then
    AppState.set("view", "ucs_category")
  end
  AppState.apply({ results_dirty = true, config_dirty = true })
  return true
end

WebUI.handlers["catalog.sort"] = function(params)
  local sorts = {
    name = true,
    duration = true,
    library = true,
    used = true,
    previewed = true,
    similarity = true,
    ai_order = true,
  }
  assert(sorts[params.field], "未知排序字段")
  AppState.apply({
    sort_mode = params.field,
    sort_desc = params.descending == true,
    results_dirty = true,
    config_dirty = true,
  })
  return true
end

WebUI.handlers["catalog.folders"] = function(params)
  local root
  for _, item in ipairs(state.root_records) do if item.id == params.rootId then root = item; break end end
  assert(root, "来源已移除")
  local requested = canonical_source_path(text(params.path))
  assert(path_key(requested) == path_key(root.path) or path_is_inside(requested, root.path), "目录超出来源范围")
  for segment in requested:gmatch("[^\\/]+") do assert(segment ~= "." and segment ~= "..", "无效文件夹路径") end
  local offset = math.floor(number(params.offset or 0, 0, 10000000))
  ensure_folder_navigation_build()
  if not state.folder_navigation_ready then
    -- Scanning deliberately suspends the derived catalog index. Allow bounded
    -- disk navigation meanwhile; do not make the whole tree wait for a scan.
    if type(reaper.EnumerateSubdirectories) == "function" and directory_exists(requested) then
      local items = {}
      for index = offset, offset + 99 do
        local name = reaper.EnumerateSubdirectories(requested, index)
        if not name then break end
        items[#items + 1] = { name = name, path = join_path(requested, name) }
      end
      local more = reaper.EnumerateSubdirectories(requested, offset + #items) ~= nil
      return { pending = false, items = items, offset = offset,
        total = offset + #items + (more and 1 or 0), fromDisk = true }
    end
    return { pending = true, items = {} }
  end
  local node = assert(state.folder_navigation_trees[params.rootId], "来源已移除")
  assert(
    path_is_inside(requested, node.path) or path_key(requested) == node.key,
    "目录超出来源范围"
  )
  local relative = requested:sub(#node.path + 1):gsub("^[\\/]+", "")
  for segment in relative:gmatch("[^\\/]+") do
    node =
      assert(node.children_by_key[path_key(join_path(node.path, segment))], "文件夹已改变")
  end
  local items = {}
  for index = offset + 1, math.min(#node.children, offset + 100) do
    local child = node.children[index]
    items[#items + 1] = {
      name = child.name,
      path = child.path,
      count = child.total_count,
      children = #child.children > 0,
    }
  end
  return { pending = false, items = items, total = #node.children, offset = offset }
end

WebUI.handlers["catalog.ucs"] = function()
  assert(ensure_ucs_catalog(), "UCS 目录不可用")
  local categories = {}
  for _, category in ipairs(UcsCatalog.category_order) do
    local entries = {}
    for _, entry in ipairs(category.entries) do
      entries[#entries + 1] =
        { catid = entry.catid, name = entry.subcategory, label = entry.subcategory_zh,
          synonyms = text(entry.synonyms_zh) .. " " .. text(entry.explanation) }
    end
    categories[#categories + 1] =
      { name = category.name, label = category.name_zh, entries = entries }
  end
  return categories
end

WebUI.handlers["catalog.suggestions"] = function(params)
  local query = text(params.query, 4096)
  local output = {}
  for _, suggestion in ipairs(ucs_search_suggestions(query, state.language, 8)) do
    local entry = suggestion.entry
    output[#output + 1] = {
      catid = entry.catid,
      label = entry.catid
        .. " · "
        .. entry.category
        .. " / "
        .. ("en" == state.language and entry.subcategory or entry.subcategory_zh),
      detail = text("en" == state.language and entry.explanation or entry.synonyms_zh),
      query = ucs_apply_search_suggestion(query, entry.catid),
    }
  end
  return output
end

WebUI.handlers["selection.set"] = function(params)
  refresh_revision()
  local index = math.floor(number(params.index, 1, 100000000))
  -- Playback/metadata can publish a new result table without moving the row.
  -- Its identity is sufficient for a single click; ranges need a fresh page.
  if not state.results[index] or state.results[index].path ~= params.path
    or (params.shift and params.revision ~= WebUI.revision) then
    return { stale = true, revision = WebUI.revision }
  end
  select_result_with_modifiers(index, params.ctrl == true, params.shift == true, params.autoPlay)
  queue_artwork(state.results[index], true)
  return asset_data(selected_asset())
end

WebUI.handlers["selection.move"] = function(params)
  if 0 == #state.results then
    return false
  end
  local direction = number(params.direction, -1, 1)
  local index = math.max(1, math.min(#state.results, (state.selected_index or 0) + direction))
  select_result_with_modifiers(index, false, params.shift == true, state.auto_preview)
  return index
end

WebUI.handlers["selection.all"] = function()
  select_all_results()
  return true
end
WebUI.handlers["waveform.get"] = function(params)
  local asset = asset_for(params.path)
  if params.retry then
    asset.wave_error = nil
    clear_failed_task(asset)
  end
  local points = math.floor(number(params.points or 1024, 64, 4096))
  if state.multichannel_waveform ~= false then
    points = math.min(points, math.max(64, math.floor(24000 / (math.max(1, asset.channels or 1) + 3))))
  end
  return {
    path = asset.path,
    duration = asset.duration or 0,
    waveform = waveform(asset, points, true),
    error = asset.wave_error and ("波形读取失败：" .. text(asset.wave_error, 250)) or nil,
  }
end
WebUI.handlers["preview.play"] = function(params)
  if params.selection == true and params.path then
    assert(selected_asset() == asset_for(params.path), "素材已切换，请重新选择区间")
  end
  WebUI.paused_preview = nil
  play_preview(
    params.path and asset_for(params.path) or selected_asset(),
    number(params.position or state.region_start or 0, 0, 1),
    params.selection ~= false
  )
  return true
end
WebUI.handlers["preview.stop"] = function()
  WebUI.paused_preview = nil
  request_preview_stop()
  return true
end
WebUI.handlers["preview.toggle"] = function(params)
  local behavior = params.behavior or "pause"
  assert(behavior == "pause" or behavior == "stop", "无效试听切换方式")
  if state.preview then
    local bookmark
    if behavior == "pause" then
      poll_preview()
      if state.preview then
        bookmark = { path = state.preview_path, position = state.preview_position or 0,
          percent = state.preview_percent or 0, region_start = state.region_start,
          region_end = state.region_end, reverse = state.reverse,
          map_start = state.preview_map_start, map_span = state.preview_map_span }
      end
    end
    request_preview_stop()
    WebUI.paused_preview = bookmark
  else
    local bookmark, asset = WebUI.paused_preview, selected_asset()
    local resume = behavior == "pause" and bookmark and asset and bookmark.path == asset.path
      and bookmark.region_start == state.region_start and bookmark.region_end == state.region_end
      and bookmark.reverse == state.reverse
    -- A full-file click preview must resume as a full-file preview even if a
    -- Region is still selected in the UI.
    local selection = not resume or not (bookmark.map_start == 0 and bookmark.map_span == 1)
    play_preview(asset, nil, selection, resume and bookmark.position or nil)
    if state.preview or not resume then WebUI.paused_preview = nil end
  end
  return true
end
WebUI.handlers["preview.parameters"] = function(params)
  local updates = {}
  for key, bounds in pairs({ pitch = { -24, 24 }, rate = { 0.25, 4 }, gain_db = { -36, 18 } }) do
    if params[key] ~= nil then
      updates[key] = number(params[key], bounds[1], bounds[2])
    end
  end
  for _, key in ipairs({ "loop", "preserve_pitch", "reverse", "auto_preview" }) do
    if params[key] ~= nil then
      assert(type(params[key]) == "boolean")
      updates[key] = params[key]
    end
  end
  local reverse_changed = updates.reverse ~= nil and updates.reverse ~= state.reverse
  AppState.apply(updates)
  if reverse_changed and state.preview then
    play_preview(selected_asset(), state.preview_percent, false)
  else
    update_preview_parameters()
  end
  AppState.mark_dirty("config_dirty")
  return true
end
WebUI.handlers["preview.region"] = function(params)
  if params.path then
    local asset = selected_asset()
    assert(asset and path_key(asset.path) == path_key(text(params.path)), "所选素材已改变，请重新设置选区")
  end
  WebUI.paused_preview = nil
  local first = number(params.start, 0, 1)
  local last = number(params.finish, first, 1)
  AppState.apply({ region_start = first, region_end = last, active_region_index = 0 })
  if state.loop_selection and last > first then
    AppState.set("loop", true)
  end
  return true
end
WebUI.handlers["preview.clearRegion"] = function()
  WebUI.paused_preview = nil
  AppState.apply({ region_start = 0, region_end = 1, active_region_index = 0 })
  return true
end
WebUI.handlers["favorite.toggle"] = function(params)
  writable()
  toggle_favorite(asset_for(params.path))
  return true
end
local function metadata_selection()
  local assets = selected_assets()
  local values, mixed, truncated = {}, {}, {}
  local signature = 2166136261
  for _, asset in ipairs(assets) do
    signature = fnv1a_feed(signature, asset.path .. "\0")
    for _, field in ipairs(metadata_edit_fields()) do
      local value = tostring(asset[field.key] or "")
      signature = fnv1a_feed(signature, field.key .. "\0" .. value .. "\0")
      if values[field.key] == nil then
        values[field.key] = value
      elseif values[field.key] ~= value then
        mixed[field.key] = true
      end
    end
  end
  for key in pairs(mixed) do
    values[key] = ""
  end
  for key, value in pairs(values) do
    values[key] = text(value, 8192)
    if values[key] ~= value then
      truncated[key] = true
    end
  end
  return {
    count = #assets,
    token = tostring(signature),
    values = values,
    mixed = mixed,
    truncated = truncated,
    fields = metadata_edit_fields(),
  },
    assets
end

WebUI.handlers["metadata.selection"] = function()
  return (metadata_selection())
end
WebUI.handlers["metadata.batch"] = function(params)
  writable()
  assert(type(params.values) == "table", "缺少元数据字段")
  local current, assets = metadata_selection()
  assert(
    current.token == params.token and current.count == params.count,
    "选择或元数据已改变，请重新打开编辑器"
  )
  local allowed = {}
  for _, field in ipairs(metadata_edit_fields()) do
    allowed[field.key] = true
  end
  for key, value in pairs(params.values or {}) do
    assert(allowed[key] and type(value) == "string" and #value <= 8192, "无效元数据字段")
    assert(not current.truncated[key], "字段过长，不能用摘要覆盖完整内容")
  end
  state.metadata_editor.signature = ""
  sync_metadata_editor(assets)
  for _, field in ipairs(metadata_edit_fields()) do
    state.metadata_editor.enabled[field.key] = params.values[field.key] ~= nil
    if params.values[field.key] ~= nil then
      state.metadata_editor.values[field.key] = params.values[field.key]
    end
  end
  apply_metadata_editor(assets)
  WebUI.revision = WebUI.revision + 1
  return true
end

WebUI.handlers["metadata.get"] = function(params)
  local asset = asset_for(params.path)
  local result = { path = asset.path, truncated = {} }
  for _, field in ipairs(metadata_edit_fields()) do
    local value = tostring(asset[field.key] or "")
    result[field.key] = text(value, 65536)
    if result[field.key] ~= value then result.truncated[field.key] = true end
  end
  return result
end
WebUI.handlers["metadata.save"] = function(params)
  writable()
  local asset = asset_for(params.path)
  local current = WebUI.handlers["metadata.get"]({ path = asset.path })
  for key, value in pairs(params.values or {}) do
    local allowed = false
    for _, field in ipairs(metadata_edit_fields()) do
      if field.key == key then
        allowed = true
      end
    end
    assert(allowed, "不可编辑的元数据字段")
    assert(
      not current.truncated[key],
      "字段超过 64 KiB，不能用摘要覆盖完整内容"
    )
    local original = (params.original or {})[key]
    local library_fallback = key == "library" and asset.library == nil
      and original == ((state.library_by_id[asset.library_id] or {}).name or "")
    assert(
      current[key] == original or library_fallback,
      "后台已更新此字段，请重新载入后编辑"
    )
    assert(type(value) == "string" and #value <= 65536, "元数据文本过长")
  end
  state.metadata_editor.signature = ""
  sync_metadata_editor({ asset })
  for key, value in pairs(params.values or {}) do
    state.metadata_editor.values[key] = value
  end
  apply_metadata_editor({ asset })
  return asset_data(asset)
end
WebUI.handlers["library.drop"] = function(params)
  writable()
  assert(
    type(params.paths) == "table" and #params.paths > 0 and #params.paths <= 256,
    "无效来源数量"
  )
  local folders = {}
  for _, path in ipairs(params.paths) do
    assert(type(path) == "string" and directory_exists(path), "请拖入来源文件夹")
    folders[#folders + 1] = path
  end
  if params.libraryId then
    assert(state.library_by_id[params.libraryId], "目标音效库已移除")
    add_folders_to_library(params.libraryId, folders)
  elseif params.separate then
    create_libraries_from_folders(folders)
  else
    local library = create_library(basename(folders[1]))
    assert(library, "创建音效库失败")
    add_folders_to_library(library.id, folders)
  end
  return true
end

WebUI.handlers["library.add"] = function(params)
  writable()
  local library = params.libraryId and state.library_by_id[params.libraryId]
  if not library and not params.name then
    return add_root(nil, params.path and text(params.path))
  end
  if not library then
    library = create_library(text(params.name, 128))
  end
  if params.path then
    add_root_to_library(library.id, text(params.path), true, false)
  else
    add_root(library.id)
  end
  return { id = library.id, name = library.name }
end
WebUI.handlers["collection.create"] = function(params)
  writable()
  assert(params.kind == "project" or params.kind == "playlist", "未知集合类型")
  local collection = create_collection(params.kind, params.name and text(params.name, 128))
  return collection and { id = collection.id, name = collection.name } or false
end
WebUI.handlers["collection.add"] = function(params)
  writable()
  local collection = state.collection_by_id[params.id]
  assert(collection, "集合已移除")
  return add_assets_to_collection(collection, selected_assets())
end
WebUI.handlers["tab.action"] = function(params)
  if params.action == "new" then
    workspace_tab_new(params.duplicateId)
  elseif params.action == "activate" then
    workspace_tab_activate(params.id)
  elseif params.action == "close" then
    assert(
      params.mode == nil or params.mode == "others" or params.mode == "right",
      "未知关闭范围"
    )
    workspace_tab_close(params.id, params.mode)
  elseif params.action == "move" then
    workspace_tab_move(params.id, number(params.direction, -1, 1))
  elseif params.action == "rename" then
    local tab = assert(workspace_tab_by_id(params.id), "标签页已关闭")
    local ok, name = true, params.name
    if name == nil then ok, name = reaper.GetUserInputs("重命名标签页", 1, "名称:", tab.name or "") end
    if ok then
      tab.name = text(name, 128)
      AppState.mark_dirty("config_dirty")
    end
  else
    error("未知标签操作")
  end
  return true
end
WebUI.handlers["drag.begin"] = function(params)
  writable()
  assert(not state.root_removal_session and not state.transfer_running, "请等待当前任务完成后再拖入素材")
  assert(type(reaper.JS_Mouse_GetState) == "function", "拖入选区需要 js_ReaScriptAPI")
  assert(type(reaper.BR_GetMouseCursorContext) == "function"
    and type(reaper.BR_GetMouseCursorContext_Position) == "function"
    and type(reaper.BR_GetMouseCursorContext_Track) == "function", "拖到编排区需要 SWS Extension")
  local asset = params.path and asset_for(params.path) or selected_asset()
  assert(asset, "请先选择素材")
  local first, last = 0, 1
  if params.selection == true then
    local selected = selected_asset()
    assert(selected and path_key(selected.path) == path_key(asset.path), "所选素材已改变，请重新设置选区")
    first = number(params.start, 0, 1)
    last = number(params.finish, first, 1)
    assert(last > first, "请先选择有效区间")
  end
  -- Never turn an RPC that arrived after mouse-up into an insertion.
  if reaper.JS_Mouse_GetState(1) & 1 == 0 then return { started = false } end
  begin_external_drag(asset, params.selection == true)
  if params.selection == true then
    state.external_drag.assets = { asset }
    state.external_drag.start_percent, state.external_drag.end_percent = first, last
  end
  WebUI.arrange_drag = { id = text(params.id, 80), started = reaper.time_precise(),
    project = reaper.EnumProjects(-1, "") }
  set_status("拖到 REAPER 编排区后松开；Esc 取消")
  return { started = true }
end

WebUI.handlers["drag.cancel"] = function(params)
  if WebUI.arrange_drag and (not params.id or params.id == WebUI.arrange_drag.id) then
    WebUI.arrange_drag = nil
    AppState.set("external_drag", nil)
    AppState.set("external_drag_started", false)
    set_status("已取消拖拽")
  end
  return true
end

function WebUI.process_arrange_drag()
  local gesture = WebUI.arrange_drag
  if not gesture then return end
  local keys = type(reaper.JS_VKeys_GetState) == "function" and reaper.JS_VKeys_GetState(0) or ""
  if (keys:byte(27) or 0) ~= 0 or reaper.time_precise() - gesture.started > 60
    or gesture.project ~= reaper.EnumProjects(-1, "")
    or state.persistence_read_only or state.root_removal_session or state.transfer_running then
    WebUI.handlers["drag.cancel"]({ id = gesture.id })
    return
  end
  if reaper.JS_Mouse_GetState(1) & 1 ~= 0 then return end
  WebUI.arrange_drag = nil
  -- This runs every native frame, even when the WebView no longer receives
  -- pointer events. The captured range is independent of later UI snapshots.
  local ok, failure = pcall(drop_external_drag)
  AppState.set("external_drag", nil)
  AppState.set("external_drag_started", false)
  if not ok then set_status(tostring(failure), true) end
  WebUI.next_publish = 0
end

WebUI.handlers["insert"] = function(params)
  assert(not state.persistence_read_only, "当前处于只读保护")
  local assets = selected_assets()
  assert(#assets > 0, "请先选择素材")
  for _, asset in ipairs(assets) do
    insert_asset(asset, params.newTrack == true, params.bwf == true)
  end
  return true
end
WebUI.handlers["transfer.directory"] = function(params)
  if params.action == "choose" then prompt_transfer_directory()
  elseif params.action == "default" then AppState.apply({ transfer_dir = DEFAULT_TRANSFER_DIR, config_dirty = true })
  elseif params.action == "open" then
    local path = text(params.path or state.transfer_dir)
    assert(path ~= "", "请先设置输出目录")
    open_folder(path)
  elseif params.action == "recent" then
    assert(state.transfer_last_output and state.transfer_last_output ~= "", "尚未执行 Transfer")
    open_folder(dirname(state.transfer_last_output))
  elseif params.action == "report" then
    assert(reaper.file_exists(TRANSFER_REPORT_FILE), "尚无任务报告")
    open_folder(dirname(TRANSFER_REPORT_FILE))
  else error("未知输出目录操作") end
  return state.transfer_dir
end
WebUI.handlers["transfer.start"] = function(params)
  writable()
  assert(not state.transfer_running, "正在交付，请等待当前任务完成")
  assert(params.target == nil or params.target == "selected" or params.target == "current", "未知交付范围")
  local current = selected_asset()
  if params.target == "current" and params.path then
    assert(current and current.path == params.path, "选择已改变，请重新导出")
  end
  local targets = params.target == "current" and (current and { current } or {}) or selected_assets()
  assert(#targets > 0, "请先选择素材")
  local choices = {
    transfer_format = { wav16 = true, wav24 = true, wav32 = true, flac = true },
    transfer_sample_rate = {
      source = true,
      ["44100"] = true,
      ["48000"] = true,
      ["96000"] = true,
      ["192000"] = true,
    },
    transfer_channels = { source = true, mono = true, stereo = true },
    transfer_scope = { selection = true, full = true },
  }
  local updates = { config_dirty = true }
  for key, values in pairs(choices) do
    if params[key] ~= nil then
      assert(values[params[key]], "未知交付选项")
      updates[key] = params[key]
    end
  end
  if params.transfer_dir then
    updates.transfer_dir = text(params.transfer_dir)
  end
  if params.transfer_template then
    updates.transfer_template = text(params.transfer_template, 512)
  end
  if params.values then WebUI.handlers["settings.update"]({ values = params.values }) end
  AppState.apply(updates)
  run_transfer(targets, params.target ~= "current")
  return true
end
WebUI.handlers["region.action"] = function(params)
  writable()
  local asset = selected_asset()
  assert(asset, "请先选择素材")
  if params.action == "save" then
    assert(not params.path or params.path == asset.path, "选择已改变，请重新建立选区")
    if params.name ~= nil then
      assert(has_selection(), "请先在大波形中建立有效选区")
      assert(add_saved_region(asset, state.region_start, state.region_end, text(params.name, 128)), "该 Region 已存在或选区无效")
      set_status("Region 已保存")
    else
      save_current_selection_as_region(asset)
    end
  elseif params.action == "activate" then
    activate_saved_region(asset, params.index, params.play == true)
  elseif params.action == "delete" then
    delete_saved_region(asset, params.index)
  else
    error("未知区域操作")
  end
  return true
end
WebUI.handlers["search.ai"] = function(params)
  if state.ai_semantic_session then ai_semantic_cancel()
  else start_ai_semantic_search(text(params.query)) end
  return true
end
WebUI.handlers["search.more"] = function()
  start_ai_semantic_next_page()
  return true
end
local function similarity_blocker()
  for _, entry in ipairs({ {"scan", "扫描"}, {"import_session", "导入"},
    {"precache_session", "波形预生成"}, {"root_removal_session", "来源移除"},
    {"relink_plan_session", "重新链接"}, {"transfer_running", "交付"},
    {"startup_session", "素材库加载"} }) do
    if state[entry[1]] then return entry[2] end
  end
  for kind, token in pairs(Jobs.active) do
    if kind ~= "similarity" and token.resource == "catalog_exclusive"
      and token.state ~= "completed" and token.state ~= "failed" then return "目录维护" end
  end
end
local function request_similarity(asset, scope)
  assert(asset, "请先选择素材")
  if state.similarity_session then return { running = true } end
  scope = scope == "current" and "current" or "all"
  local blocker = similarity_blocker()
  if blocker then
    local context = {}
    for _, key in ipairs({ "workspace_tab_active", "search", "library_filter_id", "root_filter",
      "view", "active_collection_id", "ucs_filter_category", "ucs_filter_catid", "status_filter" }) do
      context[key] = { state[key] }
    end
    WebUI.pending_similarity = { path = asset.path, name = asset.name, scope = scope,
      blocker = blocker, context = context }
    set_status("相似声音已排队，等待" .. blocker .. "完成，可取消等待")
    return { queued = true }
  end
  WebUI.pending_similarity = nil
  if not start_similarity_search(asset, scope) then error(state.status, 0) end
  return { started = true }
end
function WebUI.process_pending_similarity()
  local pending = WebUI.pending_similarity
  if not pending or state.similarity_session then return end
  if pending.scope == "current" then
    for key, expected in pairs(pending.context) do
      local value = state[key]
      if value ~= expected[1] then
        WebUI.pending_similarity = nil
        set_status("筛选已改变，已取消等待的相似检索")
        return
      end
    end
  end
  pending.blocker = similarity_blocker()
  if pending.blocker then return end
  WebUI.pending_similarity = nil
  local asset = state.by_path[path_key(pending.path)]
  if not asset then set_status("参考素材已移除，已取消等待的相似检索"); return end
  start_similarity_search(asset, pending.scope)
end
WebUI.handlers["search.similar"] = function(params)
  return request_similarity(selected_asset(), params.scope)
end
WebUI.handlers["maintenance"] = function(params)
  writable()
  local actions = {
    scan = function()
      start_scan(
        "手动扫描",
        state.library_filter_id and roots_for_library(state.library_filter_id) or nil
      )
    end,
    missing = start_missing_audit,
    duplicates = start_duplicate_scan,
    verify = start_wave_cache_verification,
    backup = function()
      create_data_backup("manual", true)
    end,
    classify = start_ucs_reclassification_preview,
    classifyApply = start_ucs_reclassification_apply,
    classifyDiscard = function()
      AppState.set("ucs_reclassification_review", nil)
    end,
  }
  assert(actions[params.action], "未知维护操作")()
  return true
end
WebUI.handlers["tasks.cancel"] = function(params)
  local task = params and params.task
  local known = { scan=true, import=true, similar=true, ai=true, transfer=true, precache=true,
    classify=true, transients=true, relink=true, remove=true, verify=true, missing=true, duplicates=true, loudness=true }
  assert(task == nil or known[task], "未知任务")
  local function cancel(name) return task == nil or task == name end
  if cancel("scan") and state.scan then
    begin_scan_cancel(state.scan)
  end
  if cancel("import") and state.import_session then
    cancel_import_session()
  end
  if cancel("similar") and state.similarity_session then
    cancel_similarity_search()
  end
  if cancel("similar") and WebUI.pending_similarity then
    WebUI.pending_similarity = nil
    set_status("已取消等待的相似检索")
  end
  if cancel("ai") then ai_semantic_cancel() end
  if cancel("transfer") then AppState.set("transfer_cancel_requested", true) end
  if cancel("precache") then cancel_wave_precache() end
  if cancel("classify") then cancel_ucs_reclassification() end
  if cancel("transients") then cancel_pending_transient_detection() end
  if cancel("relink") and state.relink_plan_session then
    cancel_relink_plan(state.relink_plan_session, "canceled")
  end
  if cancel("remove") and state.root_removal_session then
    cancel_root_removal(state.root_removal_session, "canceled")
  end
  for _, field in ipairs({
    "cache_verify_session",
    "missing_audit",
    "duplicate_scan",
    "duplicate_confirmation",
  }) do
    local job = state[field]
    local owner = ({ cache_verify_session="verify", missing_audit="missing", duplicate_scan="duplicates", duplicate_confirmation="duplicates" })[field]
    if job and cancel(owner) then
      close_duplicate_confirmation_session(job)
      Jobs.cancel(job.job_token)
      Jobs.finish(job.job_token, true, "canceled")
      AppState.set(field, nil)
    end
  end
  if cancel("loudness") then
    destroy_loudness_job(state.loudness_active)
    AppState.set("loudness_active", nil)
    AppState.apply({ loudness_queue = {}, loudness_queued = {} })
  end
  return true
end
local settings_schema = {
  { key = "watch_enabled", label = "空闲时检查来源文件夹（播放和操作时暂停）", group = "常规", kind = "boolean" },
  { key = "transfer_dir", label = "输出目录", group = "Transfer", kind = "string" },
  { key = "transfer_template", label = "文件名模板", group = "Transfer", kind = "string" },
  { key = "transfer_format", label = "格式", group = "Transfer", kind = "choice", options = { "wav16", "wav24", "wav32", "flac" } },
  { key = "transfer_sample_rate", label = "采样率", group = "Transfer", kind = "choice", options = { "source", "44100", "48000", "96000", "192000" } },
  { key = "transfer_channels", label = "声道", group = "Transfer", kind = "choice", options = { "source", "mono", "stereo" } },
  { key = "transfer_scope", label = "范围", group = "Transfer", kind = "choice", options = { "selection", "full" } },
  {
    key = "language",
    label = "语言",
    group = "常规",
    kind = "choice",
    options = { "zh", "en" },
  },
  { key = "artwork_enabled", label = "启用封面", group = "外观", kind = "boolean" },
  {
    key = "inspector_artwork_pinned",
    label = "封面置于详细信息前",
    group = "外观",
    kind = "boolean",
  },
  { key = "selection_hex", label = "选区颜色", group = "试听颜色", kind = "color" },
  { key = "playhead_hex", label = "播放指针颜色", group = "试听颜色", kind = "color" },
  { key = "region_hex", label = "Region 颜色", group = "试听颜色", kind = "color" },
  {
    key = "mini_wave_points",
    integer = true,
    label = "列表波形采样点数",
    group = "波形与分析",
    kind = "number",
    minimum = MINI_WAVE_DEFAULT_POINTS,
    maximum = MINI_WAVE_MAX_POINTS,
  },
  {
    key = "precache_points",
    integer = true,
    label = "高精度波形采样点数",
    group = "波形与分析",
    kind = "number",
    minimum = 2048,
    maximum = 4096,
  },
  {
    key = "transient_threshold",
    label = "瞬态阈值（线性振幅）",
    group = "波形与分析",
    kind = "number",
    minimum = 0.001,
    maximum = 0.8913,
  },
  { key = "auto_backup", label = "自动备份", group = "维护", kind = "boolean" },
  {
    key = "backup_keep_count",
    integer = true,
    label = "备份保留数",
    group = "维护",
    kind = "number",
    minimum = 1,
    maximum = 100,
  },
  {
    key = "auto_collect_project_usage",
    label = "自动收集工程使用记录",
    group = "维护",
    kind = "boolean",
  },
  {
    key = "multichannel_waveform",
    label = "多声道波形",
    group = "波形与分析",
    kind = "boolean",
  },
  {
    key = "spectral_peaks_enabled",
    label = "频谱峰值着色",
    group = "波形与分析",
    kind = "boolean",
  },
  {
    key = "watch_interval",
    label = "最短空闲检查间隔（秒；无变化时自动延长）",
    group = "常规",
    kind = "number",
    minimum = 15.0,
    maximum = 600.0,
  },
  {
    key = "watch_silent",
    label = "静默后台检查（仅显示工具栏动态状态）",
    group = "常规",
    kind = "boolean",
  },
  {
    key = "resume_scan_on_start",
    label = "启动时恢复中断的扫描",
    group = "常规",
    kind = "boolean",
  },
  {
    key = "enter_insert_shortcuts",
    label = "启用 Enter / Ctrl+Enter 快速插入 REAPER",
    group = "常规",
    kind = "boolean",
  },
  { key = "insert_prefix", label = "前缀", group = "常规", kind = "string" },
  { key = "insert_suffix", label = "后缀", group = "常规", kind = "string" },
  {
    key = "insert_lowercase",
    label = "Take 名称转为小写",
    group = "常规",
    kind = "boolean",
  },
  {
    key = "insert_fade_ms",
    label = "插入淡化",
    group = "常规",
    kind = "number",
    minimum = 0.0,
    maximum = 100.0,
  },
  {
    key = "played_text_enabled",
    label = "已播放文字高亮",
    group = "试听颜色",
    kind = "boolean",
  },
  {
    key = "played_waveform_enabled",
    label = "已播放波形高亮",
    group = "试听颜色",
    kind = "boolean",
  },
  {
    key = "restore_played_on_start",
    label = "启动时自动恢复上次浏览高亮",
    group = "试听颜色",
    kind = "boolean",
  },
  {
    key = "wave_scrub_enabled",
    label = "启用右键擦播",
    group = "波形与分析",
    kind = "boolean",
  },
  {
    key = "loop_selection",
    label = "选区完成后自动循环",
    group = "波形与分析",
    kind = "boolean",
  },
  {
    key = "transient_smoothing_ms",
    label = "平滑时间",
    group = "波形与分析",
    kind = "number",
    minimum = 0.0,
    maximum = 80.0,
  },
  {
    key = "transient_min_gap_ms",
    label = "最小间隔",
    group = "波形与分析",
    kind = "number",
    minimum = 20.0,
    maximum = 2000.0,
  },
  {
    key = "transient_pre_ms",
    label = "Region 前置",
    group = "波形与分析",
    kind = "number",
    minimum = 0.0,
    maximum = 1000.0,
  },
  {
    key = "transient_post_ms",
    label = "Region 后置",
    group = "波形与分析",
    kind = "number",
    minimum = 20.0,
    maximum = 5000.0,
  },
  {
    key = "transient_max_regions",
    integer = true,
    label = "最大 Region 数",
    group = "波形与分析",
    kind = "number",
    minimum = 1.0,
    maximum = 256.0,
  },
  {
    key = "transient_replace_existing",
    label = "替换已有瞬态建议",
    group = "波形与分析",
    kind = "boolean",
  },
  {
    key = "show_loudness_metrics",
    label = "显示响度统计",
    group = "波形与分析",
    kind = "boolean",
  },
  { key = "loudness_show_i", label = "LUFS-I", group = "波形与分析", kind = "boolean" },
  { key = "loudness_show_m", label = "LUFS-M max", group = "波形与分析", kind = "boolean" },
  { key = "loudness_show_s", label = "LUFS-S max", group = "波形与分析", kind = "boolean" },
  { key = "loudness_show_tp", label = "True Peak", group = "波形与分析", kind = "boolean" },
  {
    key = "loudness_match",
    label = "启用估算响度匹配",
    group = "波形与分析",
    kind = "boolean",
  },
  {
    key = "loudness_target_db",
    label = "目标响度",
    group = "波形与分析",
    kind = "number",
    minimum = -30.0,
    maximum = -6.0,
  },
  {
    key = "transfer_lowercase",
    label = "文件名转为小写",
    group = "Transfer",
    kind = "boolean",
  },
  {
    key = "transfer_preserve_metadata",
    label = "尽可能保留源文件元数据",
    group = "Transfer",
    kind = "boolean",
  },
  { key = "transfer_dither", label = "启用抖动", group = "Transfer", kind = "boolean" },
  { key = "transfer_noise_shaping", label = "噪声整形", group = "Transfer", kind = "boolean" },
  {
    key = "transfer_fade_in_ms",
    label = "淡入",
    group = "Transfer",
    kind = "number",
    minimum = 0.0,
    maximum = 500.0,
  },
  {
    key = "transfer_fade_out_ms",
    label = "淡出",
    group = "Transfer",
    kind = "number",
    minimum = 0.0,
    maximum = 2000.0,
  },
  {
    key = "transfer_smart_tail",
    label = "智能保留选区尾音",
    group = "Transfer",
    kind = "boolean",
  },
  {
    key = "transfer_tail_threshold_db",
    label = "尾音阈值",
    group = "Transfer",
    kind = "number",
    minimum = -96.0,
    maximum = -18.0,
  },
  {
    key = "transfer_tail_max_ms",
    label = "最大尾音",
    group = "Transfer",
    kind = "number",
    minimum = 100.0,
    maximum = 30000.0,
  },
  {
    key = "transfer_tail_hold_ms",
    label = "尾音留白",
    group = "Transfer",
    kind = "number",
    minimum = 0.0,
    maximum = 2000.0,
  },
  {
    key = "transfer_variants_enabled",
    label = "启用批量变体",
    group = "Transfer",
    kind = "boolean",
  },
  { key = "transfer_variant_pitches", label = "Pitch 列表", group = "Transfer", kind = "string" },
  { key = "transfer_variant_rates", label = "Rate 列表", group = "Transfer", kind = "string" },
  { key = "transfer_variant_gains", label = "Gain 列表", group = "Transfer", kind = "string" },
  {
    key = "transfer_variant_include_reverse",
    label = "同时生成正向与反向",
    group = "Transfer",
    kind = "boolean",
  },
  {
    key = "transfer_variant_auto_suffix",
    label = "模板未含变体字段时自动追加安全后缀",
    group = "Transfer",
    kind = "boolean",
  },
  {
    key = "transfer_insert_after",
    label = "导出后插入 REAPER",
    group = "Transfer",
    kind = "boolean",
  },
  {
    key = "transfer_open_dir_after",
    label = "导出完成后打开输出目录",
    group = "Transfer",
    kind = "boolean",
  },
  {
    key = "played_text_hex",
    label = "已试听文字颜色",
    group = "试听颜色",
    kind = "color",
  },
  { key = "waveform_hex", label = "普通波形颜色", group = "试听颜色", kind = "color" },
  {
    key = "waveform_played_hex",
    label = "已试听波形颜色",
    group = "试听颜色",
    kind = "color",
  },
  {
    key = "waveform_marked_hex",
    label = "标记波形颜色",
    group = "试听颜色",
    kind = "color",
  },
  {
    key = "waveform_selected_hex",
    label = "选中波形颜色",
    group = "试听颜色",
    kind = "color",
  },
  {
    key = "transfer_normalize",
    label = "标准化",
    group = "Transfer",
    kind = "choice",
    options = { "off", "peak", "true_peak", "rms_i", "lufs_i" },
  },
  {
    key = "transfer_normalize_target",
    label = "标准化目标",
    group = "Transfer",
    kind = "number",
    minimum = -36,
    maximum = 0,
  },
  {
    key = "transfer_collision",
    label = "重名策略",
    group = "Transfer",
    kind = "choice",
    options = { "increment", "skip", "overwrite" },
  },
}
WebUI.handlers["settings.get"] = function()
  local values = {}
  for _, definition in ipairs(settings_schema) do
    values[definition.key] = state[definition.key]
  end
  local presets = {}
  for _, preset in ipairs(state.ai_presets or {}) do
    presets[#presets + 1] = { id = preset.id, name = preset.name }
  end
  return {
    transfer_dir = state.transfer_dir,
    transfer_template = state.transfer_template,
    transfer_format = state.transfer_format,
    transfer_scope = state.transfer_scope,
    transfer_sample_rate = state.transfer_sample_rate,
    transfer_channels = state.transfer_channels,
    auto_preview = state.auto_preview,
    watch_enabled = state.watch_enabled,
    ai_provider = state.ai_provider,
    ai_url = state.ai_api_url,
    ai_model = state.ai_model,
    ai_key_saved = ai_semantic_preset_key_usable(),
    ai_status = state.ai_preset_status,
    ai_presets = presets,
    loading = state.startup_session ~= nil,
    wave_cache_dir = state.wave_cache_dir,
    transfer_has_report = reaper.file_exists(TRANSFER_REPORT_FILE),
    schema = settings_schema,
    values = values,
    ai_active_preset_id = state.ai_active_preset_id,
    ai_preset_name = state.ai_preset_name,
  }
end

WebUI.handlers["settings.update"] = function(params)
  writable()
  local updates = {}
  for key, value in pairs(params.values or {}) do
    local definition
    for _, item in ipairs(settings_schema) do
      if item.key == key then
        definition = item
        break
      end
    end
    assert(definition, "未知设置")
    if definition.kind == "number" then
      value = number(value, definition.minimum, definition.maximum)
      assert(not definition.integer or value % 1 == 0, "请输入整数")
    elseif definition.kind == "boolean" then
      assert(type(value) == "boolean", "无效开关值")
    elseif definition.kind == "choice" then
      local valid = false
      for _, option in ipairs(definition.options) do
        if value == option then
          valid = true
        end
      end
      assert(valid, "未知选项")
    elseif definition.kind == "color" then
      assert(type(value) == "string" and value:match("^#%x%x%x%x%x%x$"), "无效颜色")
    else
      assert(type(value) == "string" and #value <= 4096, "设置文本过长")
    end
    updates[key] = value
  end
  local wave_changed = updates.mini_wave_points and updates.mini_wave_points ~= state.mini_wave_points
    or updates.multichannel_waveform ~= nil and updates.multichannel_waveform ~= state.multichannel_waveform
  local loudness_changed = updates.show_loudness_metrics ~= nil and updates.show_loudness_metrics ~= state.show_loudness_metrics
  local watch = updates.watch_enabled
  updates.watch_enabled = nil
  AppState.apply(updates)
  if watch ~= nil then set_watch_folder_enabled(watch) end
  if updates.watch_interval then reset_watch_schedule(true) end
  if wave_changed then
    local job = state.wave_active
    if job then
      destroy_wave_job(job)
      if job.job_token then
        Jobs.cancel(job.job_token)
        Jobs.finish(job.job_token, true, "waveform settings changed")
      end
    end
    AppState.apply({ wave_active = nil, wave_queue = {}, wave_queued = {}, wave_checked = {} })
    AppState.set("wave_active", nil)
  end
  if loudness_changed then
    if state.show_loudness_metrics then request_loudness_analysis(selected_asset(), false)
    else
      destroy_loudness_job(state.loudness_active)
      AppState.apply({ loudness_active = nil, loudness_queue = {}, loudness_queued = {} })
      AppState.set("loudness_active", nil)
    end
  end
  AppState.mark_dirty("config_dirty")
  apply_waveform_palette()
  update_preview_parameters()
  WebUI.revision = WebUI.revision + 1
  return true
end

WebUI.handlers["asset.action"] = function(params)
  local asset = params.path and asset_for(params.path) or selected_asset()
  assert(asset, "请先选择素材")
  local targets = is_row_selected(asset) and selected_assets() or { asset }
  local operations = {
    play = function()
      play_preview(asset, 0, false)
    end,
    insert = function()
      for _, target in ipairs(targets) do
        insert_asset(target, params.newTrack == true, params.bwf == true)
      end
    end,
    stack = function()
      insert_selected_stack(0, 1)
    end,
    mark = function()
      local marked = true
      for _, target in ipairs(targets) do
        if not target.marked then
          marked = false
          break
        end
      end
      set_assets_marked(targets, not marked)
    end,
    favorite = function()
      local all_favorite = true
      for _, target in ipairs(targets) do
        if not state.favorites[asset_path_sort_key(target)] then
          all_favorite = false
        end
      end
      for _, target in ipairs(targets) do
        if (state.favorites[asset_path_sort_key(target)] == true) == all_favorite then
          toggle_favorite(target)
        end
      end
    end,
    workflow = function()
      assert(WORKFLOW_STATUS[params.status], "未知工作流状态")
      set_workflow_status(targets, params.status)
    end,
    metadata = function()
      for _, target in ipairs(targets) do
        target.indexed = false
        target.meta_failed_at = nil
        queue_metadata(target, true)
      end
    end,
    removeCollection = function()
      local collection = state.collection_by_id[state.active_collection_id]
      assert(collection, "请先打开集合")
      remove_assets_from_collection(collection, targets)
    end,
    similar = function()
      request_similarity(asset, params.scope)
    end,
    loudness = function()
      request_loudness_analysis(asset, true)
    end,
    browseProduct = function()
      browse_asset_library(asset)
    end,
    artwork = function()
      choose_artwork_for_asset(asset)
    end,
    redetectArtwork = function()
      asset.artwork_path = ""
      asset.artwork_checked = false
      AppState.apply({ artwork_folder_cache = {}, artwork_dimension_cache = {} })
      queue_artwork(asset, true)
      mark_asset_database_change(asset, "display")
    end,
    clearArtwork = function()
      asset.artwork_path = "-"
      asset.artwork_checked = true
      mark_asset_database_change(asset, "display")
    end,
    filter = function()
      local fields = {
        description = true,
        keywords = true,
        category = true,
        subcategory = true,
        catid = true,
        library = true,
      }
      assert(fields[params.field], "不支持此筛选字段")
      add_metadata_filter(params.field, tostring(asset[params.field] or ""))
    end,
    confirmUcs = function()
      assert(confirm_ucs_candidate(asset, text(params.catid, 64)))
    end,
    undoUcs = function()
      undo_ucs_confirmation(asset)
    end,
    transients = function()
      request_transient_detection(asset)
    end,
    undoTransients = function()
      undo_last_transient_detection(asset)
    end,
    clearTransients = function()
      clear_all_transient_suggestions(asset)
    end,
    channelsAll = function()
      select_all_preview_channels(asset)
      update_preview_parameters()
    end,
    channelMode = function()
      local count = preview_asset_channel_count(asset)
      local mode = params.mode
      assert(
        count <= 2
          and (
            mode == "original"
            or mode == "mono"
            or (count == 2 and (mode == "left" or mode == "right"))
          ),
        "无效试听声道模式"
      )
      AppState.set("preview_channel_mode", mode)
      AppState.mark_dirty("config_dirty")
      update_preview_parameters()
    end,
    channel = function()
      assert(preview_asset_channel_count(asset) > 2, "立体声素材请使用试听声道模式")
      local channel = math.floor(number(params.channel, 1, preview_asset_channel_count(asset)))
      apply_preview_channel_selection(
        asset,
        channel,
        params.ctrl == true,
        params.shift == true,
        false
      )
      update_preview_parameters()
    end,
  }
  writable()
  assert(operations[params.action], "未知素材操作")()
  WebUI.revision = WebUI.revision + 1
  return true
end

WebUI.handlers["diagnostics.get"] = function()
  return build_diagnostics_text() .. "\nStartup: " .. neural_json_encode(state.startup_metrics or {})
    .. "\nTaskbar: " .. tostring(WebUI.taskbar_status or "pending")
end
WebUI.handlers["diagnostics.overlay"] = function(params)
  assert(type(params.enabled) == "boolean", "无效性能显示设置")
  FrameStats.overlay = params.enabled
  return FrameStats.overlay
end

WebUI.handlers["management.get"] = function()
  local groups = {
    {
      kind = "library",
      label = "音效库",
      items = {},
      actions = { "add", "rename", "scan", "remove" },
    },
    {
      kind = "root",
      label = "来源文件夹",
      items = {},
      actions = { "open", "scan", "relink", "artwork", "redetectArtwork", "clearArtwork", "remove" },
    },
    {
      kind = "collection",
      label = "集合",
      items = {},
      actions = { "addSelection", "removeSelection", "bind", "rename", "remove" },
    },
    {
      kind = "search",
      label = "保存的搜索",
      items = {},
      actions = { "activate", "overwrite", "rename", "remove" },
    },
  }
  for _, item in ipairs(state.libraries) do
    groups[1].items[#groups[1].items + 1] = { id = item.id, name = item.name }
  end
  for _, item in ipairs(state.root_records) do
    groups[2].items[#groups[2].items + 1] = { id = item.id, name = item.path }
  end
  for _, item in ipairs(state.collections) do
    groups[3].items[#groups[3].items + 1] = { id = item.id, name = item.name, kind = item.kind }
  end
  for _, item in ipairs(state.saved_searches) do
    groups[4].items[#groups[4].items + 1] = { id = item.id, name = item.name }
  end
  return groups
end

WebUI.handlers["management.action"] = function(params)
  writable()
  local lists = {
    library = state.libraries,
    root = state.root_records,
    collection = state.collections,
    search = state.saved_searches,
  }
  local list = assert(lists[params.kind], "未知管理类别")
  local target
  for _, item in ipairs(list) do
    if item.id == params.id then
      target = item
      break
    end
  end
  assert(target, "项目已移除，请刷新")
  local actions = {
    library = {
      add = function()
        add_root(target.id)
      end,
      rename = function()
        rename_library(target, params.name and text(params.name, 128))
      end,
      scan = function()
        start_scan("手动扫描", roots_for_library(target.id))
      end,
      remove = function()
        remove_library(target.id)
      end,
    },
    root = {
      open = function()
        local path = params.path and canonical_source_path(text(params.path)) or target.path
        assert(path_key(path) == path_key(target.path) or path_is_inside(path, target.path), "目录超出来源范围")
        for segment in path:gmatch("[^\\/]+") do assert(segment ~= ".." and segment ~= ".", "无效文件夹路径") end
        open_folder(path)
      end,
      scan = function()
        start_scan("手动扫描", { target.path })
      end,
      relink = function()
        relink_root(target)
      end,
      artwork = function()
        choose_artwork_for_root(target)
      end,
      redetectArtwork = function()
        redetect_root_artwork(target)
      end,
      clearArtwork = function()
        clear_root_artwork(target)
      end,
      remove = function()
        remove_root(target)
      end,
    },
    collection = {
      addSelection = function()
        add_assets_to_collection(target, selected_assets())
      end,
      removeSelection = function()
        remove_assets_from_collection(target, selected_assets())
      end,
      bind = function()
        assert(target.kind == "project", "仅项目素材箱支持工程绑定")
        refresh_current_project_binding()
        bind_project_bin(target, state.current_project_path)
      end,
      rename = function()
        rename_collection(target, params.name and text(params.name, 128))
      end,
      remove = function()
        delete_collection(target)
      end,
    },
    search = {
      overwrite = function()
        target.query, target.view = state.search, state.view
        target.root, target.library_id = state.root_filter or "", state.library_filter_id
        target.sort_mode, target.sort_desc = state.sort_mode, state.sort_desc
        target.status_filter, target.collection_id = state.status_filter, state.active_collection_id
        local ucs = ucs_directory_view(state.view)
        target.ucs_category = ucs and state.ucs_filter_category or nil
        target.ucs_subcategory = ucs and state.ucs_filter_subcategory or nil
        target.ucs_catid = ucs and state.ucs_filter_catid or nil
        AppState.mark_dirty("searches_dirty")
      end,
      activate = function()
        activate_saved_search(target)
      end,
      rename = function()
        rename_saved_search(target, params.name and text(params.name, 128))
      end,
      remove = function()
        delete_saved_search(target)
      end,
    },
  }
  assert(actions[params.kind][params.action], "未知管理操作")()
  WebUI.revision = WebUI.revision + 1
  return true
end

WebUI.handlers["records.action"] = function(params)
  writable()
  local operations = {
    restorePlayed = restore_last_session_played_highlights,
    clearPlayed = clear_session_played_highlights,
    clearSavedPlayed = clear_saved_session_played_highlights,
    saveSearch = function() save_current_search(params.name and text(params.name, 128)) end,
    clearSimilarity = clear_similarity_cache,
    clearWaveforms = clear_wave_cache,
    clearArtwork = clear_artwork_cache,
    retryFailed = retry_failed_tasks,
    clearFailed = function()
      AppState.apply({ failed_tasks = {}, failed_tasks_dirty = true, last_save = 0 })
      schedule_auxiliary_save()
      set_status("失败任务记录已清除")
    end,
    currentProject = function()
      refresh_current_project_binding()
      ensure_current_project_bin(true)
    end,
    dataFolder = function()
      open_folder(DATA_DIR)
    end,
    openCacheFolder = function()
      open_folder(state.wave_cache_dir or WAVE_CACHE_DIR)
    end,
    backupFolder = function()
      open_folder(BACKUP_DIR)
    end,
    docsFolder = function()
      assert(directory_exists(DOCS_DIR), "文档目录不存在：" .. DOCS_DIR)
      open_folder(DOCS_DIR)
    end,
    resetWaveformColors = reset_waveform_palette_defaults,
    cacheFolder = prompt_wave_cache_directory,
    cacheDefault = restore_default_wave_cache_directory,
    resetInterface = reset_interface_settings,
    resetDatabase = reset_database_keep_roots,
    factoryReset = factory_reset,
    precache = function()
      start_wave_precache(state.precache_points, "all")
    end,
    precacheCurrent = function()
      start_wave_precache(state.precache_points, "current")
    end,
    cancelPrecache = function()
      AppState.set("precache_cancel_requested", true)
    end,
    cancelClassify = cancel_ucs_reclassification,
    cancelTransients = cancel_pending_transient_detection,
    verifyDuplicates = start_duplicate_confirmation,
    restoreBackup = restore_latest_data_backup,
  }
  assert(operations[params.action], "未知记录操作")()
  WebUI.revision = WebUI.revision + 1
  return true
end

WebUI.handlers["settings.watch"] = function(params)
  assert(type(params.enabled) == "boolean", "无效监视设置")
  writable()
  set_watch_folder_enabled(params.enabled)
  return true
end

WebUI.handlers["settings.ai"] = function(params)
  writable()
  assert(not state.ai_key_save_session, "密钥正在加密保存，请稍候")
  assert(not state.ai_semantic_session, "请等待 AI 请求结束后修改设置")
  if params.action == "deleteKey" then
    assert(params.id == state.ai_active_preset_id, "预设已改变，请重新操作")
    local ok, reason = ai_semantic_delete_api_key()
    assert(ok, reason)
    return true
  end
  if params.action == "select" then
    local ok, reason = ai_semantic_select_preset(text(params.id, 80))
    assert(ok, reason)
    return true
  end
  if params.action == "new" then
    local ok, reason = ai_semantic_new_preset(params.provider)
    assert(ok, reason)
    return true
  end
  if params.action == "delete" then
    if reaper.MB("删除当前 AI 预设及其保存的密钥？", SCRIPT_NAME, 4) ~= 6 then
      return false
    end
    local ok, reason = ai_semantic_delete_preset(text(params.id, 80))
    assert(ok, reason)
    return true
  end
  assert(params.action == "save" or params.action == "test", "未知 AI 设置操作")
  assert(
    params.provider == "deepseek" or params.provider == "openai" or params.provider == "custom",
    "无效服务商"
  )
  local url, model, name = text(params.url, 4096), text(params.model, 512), text(params.name, 160)
  local valid, reason = ai_semantic_validate_endpoint(url)
  assert(valid, reason)
  assert(model ~= "" and name ~= "", "请填写模型与预设名称")
  AppState.apply({
    ai_provider = params.provider,
    ai_api_url = url,
    ai_model = model,
    ai_preset_name = name,
    ai_api_key_input = text(params.key, 8192),
  })
  if params.action == "test" then
    local ok, failure = start_ai_semantic_connection_test()
    AppState.set("ai_api_key_input", "")
    assert(ok, failure)
    return true
  end
  local ok, failure = ai_semantic_save_preset()
  AppState.set("ai_api_key_input", "")
  assert(ok, failure)
  return failure == "pending" and state.ai_key_save_session or true
end

function webview_receive()
  local deadline = reaper.time_precise() + 0.004
  for _ = 1, 4 do
    local raw = reaper.ReaWeb_Receive(WebUI.window)
    if raw == "" then
      break
    end
    local parsed, request = pcall(neural_json_decode, raw)
    if
      parsed
      and type(request) == "table"
      and type(request.id) == "string"
      and #request.id <= 80
      and request.protocol == WebUI.protocol
    then
      local handler = WebUI.handlers[request.method]
      local ok, result
      if state.startup_session and request.method ~= "session.ready" and request.method ~= "settings.get" then
        ok, result = false, "素材库正在加载，请稍后重试"
      elseif handler then
        ok, result = pcall(handler, request.params or {})
      else
        ok, result = false, "不支持的宿主操作"
      end
      local response = { id = request.id, protocol = WebUI.protocol, ok = ok }
      if ok then
        response.result = result
      else
        response.error = ai_semantic_redact(tostring(result))
      end
      if ok and state.ai_key_save_session and result == state.ai_key_save_session then
        -- Hold this response until DPAPI and the preset commit finish. Never
        -- serialize the job object: it holds the in-memory credential.
        WebUI.pending_key_response = { id = request.id, job = result }
      else
        send(response)
      end
      if request.method ~= "catalog.page" and request.method ~= "waveform.get"
        and request.method ~= "settings.get" and request.method ~= "catalog.folders"
        and request.method ~= "catalog.suggestions" and request.method ~= "session.activity" then WebUI.next_publish = 0 end
    end
    if reaper.time_precise() >= deadline then break end
  end
  WebUI.process_arrange_drag()
end

function WebUI.playback_timing()
  local length = state.preview_length or 0
  local start = state.preview_map_start or 0
  local span = state.preview_map_span or 1
  local velocity = state.preview and not state.preview_seek_target and length > 0
    and span / length * (state.rate or 1) * (state.preview_map_reverse and -1 or 1) or 0
  return {
    epoch = state.preview_job_token and state.preview_job_token.generation or 0,
    velocity = velocity, start = start, ["end"] = start + span, loop = state.loop,
  }
end

function webview_publish()
  local pending = WebUI.pending_key_response
  if pending and pending.job.complete then
    local job = pending.job
    send({ id = pending.id, protocol = WebUI.protocol, ok = job.ok,
      result = job.ok and true or nil, error = not job.ok and job.reason or nil })
    WebUI.pending_key_response = nil
  end
  if not reaper.ReaWeb_IsReady(WebUI.window) then
    return
  end
  while #WebUI.outbox > 0 do
    if not reaper.ReaWeb_Send(WebUI.window, WebUI.outbox[1]) then
      return
    end
    table.remove(WebUI.outbox, 1)
  end
  local now = reaper.time_precise()
  if now < WebUI.next_publish then
    return
  end
  WebUI.next_publish = now + 0.15
  local taskbar_ok = pcall(WebUI.update_taskbar, now)
  if not taskbar_ok then WebUI.taskbar_status = "unavailable" end
  WebUI.process_pending_similarity()
  refresh_revision()
  local libraries, collections, tabs, roots, searches = {}, {}, {}, {}, {}
  for _, saved in ipairs(state.saved_searches) do
    searches[#searches + 1] = { id = saved.id, name = text(saved.name, 160) }
  end
  for _, library in ipairs(state.libraries) do
    libraries[#libraries + 1] = { id = library.id, name = library.name }
  end
  for _, collection in ipairs(state.collections) do
    collections[#collections + 1] = {
      id = collection.id,
      name = collection.name,
      kind = collection.kind,
      count = collection_item_count(collection),
    }
  end
  for _, tab in ipairs(state.workspace_tabs or {}) do
    tabs[#tabs + 1] = { id = tab.id, name = workspace_tab_title(tab) }
  end
  for _, root in ipairs(state.root_records) do
    roots[#roots + 1] = { id = root.id, libraryId = root.library_id, path = root.path,
      name = root.alias ~= "" and root.alias or basename(root.path), enabled = root.enabled ~= false }
  end
  local asset = selected_asset()
  local paused = WebUI.paused_preview
  if paused and (state.preview or not asset or paused.path ~= asset.path
    or paused.region_start ~= state.region_start or paused.region_end ~= state.region_end
    or paused.reverse ~= state.reverse) then
    WebUI.paused_preview = nil
    paused = nil
  end
  local selected = asset_data(asset)
  if selected then
    selected.regions = asset_regions(asset)
    selected.index = state.selected_index
    selected.loudness = collect_loudness_summary_items(asset)
    selected.loudnessEnabled = state.show_loudness_metrics
    selected.channelsSelected = ensure_preview_channel_selection(asset)
    selected.channelMode = state.preview_channel_mode
    selected.ucsCandidates = {}
    if asset.ucs_status == "pending" then
      for _, candidate in ipairs(ucs_parse_candidates(asset.ucs_candidates)) do
        selected.ucsCandidates[#selected.ucsCandidates + 1] = {
          catid = candidate.entry.catid,
          label = ucs_entry_display_name(candidate.entry),
          score = candidate.score,
        }
      end
    end
  end
  local statuses = {}
  for _, id in ipairs(WORKFLOW_STATUS_ORDER) do
    statuses[#statuses + 1] = { id = id, label = WORKFLOW_STATUS[id].label }
  end
  local snapshot = {
    similarityProgress = state.similarity_session and {
      phase = state.similarity_session.neural_progress and state.similarity_session.neural_progress.phase or state.similarity_session.phase,
      completed = state.similarity_session.neural_progress and state.similarity_session.neural_progress.completed
        or state.similarity_session.processed or 0,
      total = state.similarity_session.neural_progress and state.similarity_session.neural_progress.total
        or state.similarity_session.total or 0,
      reference = text(state.similarity_session.reference and state.similarity_session.reference.name or "", 160),
      engine = state.similarity_session.neural_attempted and not state.similarity_session.neural_failure and "neural" or "acoustic",
      failure = state.similarity_session.neural_failure,
    } or (WebUI.pending_similarity and {
      phase = "waiting", completed = 0, total = 0,
      reference = text(WebUI.pending_similarity.name, 160),
      waitingFor = WebUI.pending_similarity.blocker,
    }) or nil,
    workflowStatuses = statuses,
    language = state.language,
    statusFilter = state.status_filter,
    savedSearches = searches,
    classificationReview = state.ucs_reclassification_review and {
      counts = state.ucs_reclassification_review.counts,
      total = state.ucs_reclassification_review.total,
      samples = state.ucs_reclassification_review.samples,
    } or nil,
    revision = WebUI.revision,
    count = #state.results,
    loaded = #state.assets,
    pending = results_pending(),
    startup = state.startup_session and {
      phase = state.startup_session.phase,
      failure = state.startup_session.failure,
      elapsed = now - (state.startup_session.started_at or now),
    } or nil,
    status = text(translate_ui_text(state.status)),
    error = state.status_error,
    readOnly = state.persistence_read_only,
    libraries = libraries,
    collections = collections,
    roots = roots,
    tabs = tabs,
    activeTab = state.workspace_tab_active,
    sortMode = state.sort_mode,
    sortDescending = state.sort_desc,
    search = state.search,
    view = state.view,
    libraryId = state.library_filter_id,
    collectionId = state.active_collection_id,
    selected = selected,
    selectedCount = selected_count(),
    arrangeDragging = WebUI.arrange_drag ~= nil,
    playing = state.preview ~= nil,
    playback = WebUI.playback_timing(),
    paused = paused ~= nil,
    position = paused and paused.percent or state.preview_percent or 0,
    regionStart = state.region_start,
    regionEnd = state.region_end,
    autoPreview = state.auto_preview,
    root = state.root_filter,
    category = state.ucs_filter_category,
    catid = state.ucs_filter_catid,
    selectionRevision = SelectionIndex.revision,
    aiConnectionStatus = state.ai_preset_status,
    multichannelWaveform = state.multichannel_waveform,
    detailPoints = state.precache_points,
    spectralPeaks = state.spectral_peaks_enabled,
    waveScrub = state.wave_scrub_enabled,
    aiSummary = state.ai_semantic_last_summary,
    transferProgress = state.transfer_job and {
      completed = state.transfer_job.completed or 0,
      total = state.transfer_job.total or 0,
    } or nil,
    transferSummary = state.transfer_last_summary,
    transferError = state.transfer_last_error,
    transferOutput = state.transfer_last_output,
    artworkEnabled = state.artwork_enabled,
    artworkPinned = state.inspector_artwork_pinned,
    previewPath = state.preview_path,
    enterInsertShortcuts = state.enter_insert_shortcuts,
    performance = FrameStats.overlay and {
      background = (FrameStats.background or 0) * 1000,
      update = (FrameStats.draw or 0) * 1000,
      interval = (FrameStats.interval or 0) * 1000,
    } or nil,
    playedCount = session_played_count(),
    rowAppearance = {
      textEnabled = state.played_text_enabled,
      waveformEnabled = state.played_waveform_enabled,
      text = state.played_text_hex,
      waveform = state.waveform_hex,
      played = state.waveform_played_hex,
      marked = state.waveform_marked_hex,
      selected = state.waveform_selected_hex,
      selection = state.selection_hex,
      playhead = state.playhead_hex,
      region = state.region_hex,
    },
    fx = {
      pitch = state.pitch,
      rate = state.rate,
      gain_db = state.gain_db,
      loop = state.loop,
      preserve_pitch = state.preserve_pitch,
      reverse = state.reverse,
    },
    taskDetails = WebUI.task_details(),
    tasks = {
      scan = state.scan ~= nil,
      import = state.import_session ~= nil,
      transfer = state.transfer_running,
      similar = state.similarity_session ~= nil or WebUI.pending_similarity ~= nil,
      ai = state.ai_semantic_session ~= nil,
      precache = state.precache_session ~= nil,
      classify = state.ucs_reclassification_session ~= nil,
      relink = state.relink_plan_session ~= nil,
      remove = state.root_removal_session ~= nil,
      verify = state.cache_verify_session ~= nil,
      missing = state.missing_audit ~= nil,
      duplicates = state.duplicate_scan ~= nil or state.duplicate_confirmation ~= nil,
      transients = state.pending_transient_detection ~= nil,
      loudness = state.loudness_active ~= nil,
    },
    aiHasMore = state.ai_semantic_has_more,
  }
  local encoded =
    neural_json_encode({ protocol = WebUI.protocol, event = "state", data = snapshot })
  if encoded ~= WebUI.last_snapshot and #encoded <= 900000 then
    if reaper.ReaWeb_Send(WebUI.window, encoded) then
      WebUI.last_snapshot = encoded
    end
  end
end
