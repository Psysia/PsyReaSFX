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
    library = (state.library_by_id[asset.library_id] or {}).name or "",
    favorite = state.favorites[asset_path_sort_key(asset)] == true,
    marked = asset.marked == true,
  }
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
  local wave = queue_wave(asset, points, channels, channels)
  if not wave then
    return nil
  end
  return {
    count = wave.count,
    peaks = wave.peaks,
    channels = wave.channel_peaks,
    channelCount = wave.channels,
  }
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
      reaper.MB(
        "请在 ReaPack 启用预发布，安装同仓库的 PsyReaSFX WebView Runtime，再重启 REAPER。"
          .. "\n已有 ReaWebAPI 时请先检查其接口兼容性。缺少接口："
          .. name,
        "PsyReaSFX 0.9.a",
        0
      )
      return false
    end
  end
  WebUI.key = SCRIPT_FILE
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
  reaper.SetExtState("PsyReaSFX.Web", WebUI.key, tostring(id), false)
  return true
end

function webview_close()
  if not WebUI.window then
    return
  end
  if reaper.GetExtState("PsyReaSFX.Web", WebUI.key) == tostring(WebUI.window) then
    reaper.DeleteExtState("PsyReaSFX.Web", WebUI.key, false)
    reaper.ReaWeb_Close(WebUI.window)
  end
end

WebUI.handlers["session.ready"] = function()
  WebUI.outbox = {}
  WebUI.last_snapshot = nil
  return {
    protocol = WebUI.protocol,
    product = "PsyReaSFX",
    version = VERSION,
    host = "reaper",
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
      item.waveform = waveform(asset, MINI_WAVE_DEFAULT_POINTS, false)
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
    AppState.set("search", text(params.search, 4096))
  end
  if params.view then
    AppState.set("view", params.view)
  end
  for parameter, key in pairs(filters) do
    local value = params[parameter]
    AppState.set(key, value ~= "" and value or nil)
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
  local sorts = { name = true, duration = true, library = true, used = true, previewed = true }
  assert(sorts[params.field], "未知排序字段")
  AppState.apply({
    sort_mode = params.field,
    sort_desc = params.descending == true,
    results_dirty = true,
    config_dirty = true,
  })
  return true
end

WebUI.handlers["catalog.ucs"] = function()
  assert(ensure_ucs_catalog(), "UCS 目录不可用")
  local categories = {}
  for _, category in ipairs(UcsCatalog.category_order) do
    local entries = {}
    for _, entry in ipairs(category.entries) do
      entries[#entries + 1] =
        { catid = entry.catid, name = entry.subcategory, label = entry.subcategory_zh }
    end
    categories[#categories + 1] =
      { name = category.name, label = category.name_zh, entries = entries }
  end
  return categories
end

WebUI.handlers["selection.set"] = function(params)
  refresh_revision()
  assert(params.revision == WebUI.revision, "结果已更新，请重试选择")
  local index = math.floor(number(params.index, 1, #state.results))
  assert(state.results[index].path == params.path, "结果位置已改变")
  select_result_with_modifiers(index, params.ctrl == true, params.shift == true, params.autoPlay)
  queue_artwork(state.results[index], true)
  return asset_data(selected_asset())
end

WebUI.handlers["selection.all"] = function()
  select_all_results()
  return true
end
WebUI.handlers["waveform.get"] = function(params)
  local asset = asset_for(params.path)
  return {
    path = asset.path,
    duration = asset.duration or 0,
    waveform = waveform(asset, math.floor(number(params.points or 1024, 64, 2048)), true),
  }
end
WebUI.handlers["preview.play"] = function(params)
  play_preview(
    params.path and asset_for(params.path) or selected_asset(),
    number(params.position or state.region_start or 0, 0, 1),
    params.selection ~= false
  )
  return true
end
WebUI.handlers["preview.stop"] = function()
  stop_preview()
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
  local first = number(params.start, 0, 1)
  local last = number(params.finish, first, 1)
  AppState.apply({ region_start = first, region_end = last })
  return true
end
WebUI.handlers["favorite.toggle"] = function(params)
  writable()
  toggle_favorite(asset_for(params.path))
  return true
end
WebUI.handlers["metadata.save"] = function(params)
  writable()
  local asset = asset_for(params.path)
  local current = asset_data(asset)
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
      "字段超出当前编辑长度，请使用原元数据编辑器处理完整内容"
    )
    assert(
      current[key] == (params.original or {})[key],
      "后台已更新此字段，请重新载入后编辑"
    )
    assert(type(value) == "string" and #value <= 8192, "元数据文本过长")
  end
  sync_metadata_editor({ asset })
  for key, value in pairs(params.values or {}) do
    state.metadata_editor.values[key] = value
  end
  apply_metadata_editor({ asset })
  return asset_data(asset)
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
  local collection = create_collection(params.kind)
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
    workspace_tab_close(params.id)
  else
    error("未知标签操作")
  end
  return true
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
WebUI.handlers["transfer.start"] = function(params)
  writable()
  local choices = {
    transfer_format = { wav16 = true, wav24 = true, wav32 = true, flac = true },
    transfer_sample_rate = { source = true, ["44100"] = true, ["48000"] = true, ["96000"] = true },
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
  AppState.apply(updates)
  run_transfer(selected_assets(), #selected_assets() > 1)
  return true
end
WebUI.handlers["region.action"] = function(params)
  writable()
  local asset = selected_asset()
  assert(asset, "请先选择素材")
  if params.action == "save" then
    save_current_selection_as_region(asset)
  elseif params.action == "activate" then
    activate_saved_region(asset, params.index, false)
  elseif params.action == "delete" then
    delete_saved_region(asset, params.index)
  else
    error("未知区域操作")
  end
  return true
end
WebUI.handlers["search.ai"] = function(params)
  start_ai_semantic_search(text(params.query))
  return true
end
WebUI.handlers["search.more"] = function()
  start_ai_semantic_next_page()
  return true
end
WebUI.handlers["search.similar"] = function(params)
  assert(selected_asset(), "请先选择素材")
  start_similarity_search(selected_asset(), params.scope == "results" and "results" or "all")
  return true
end
WebUI.handlers["maintenance"] = function(params)
  writable()
  local actions = {
    scan = function()
      start_scan("手动扫描")
    end,
    missing = start_missing_audit,
    duplicates = start_duplicate_scan,
    verify = start_wave_cache_verification,
    backup = function()
      create_data_backup("manual", true)
    end,
    classify = start_ucs_reclassification_preview,
    classifyApply = start_ucs_reclassification_apply,
  }
  assert(actions[params.action], "未知维护操作")()
  return true
end
WebUI.handlers["tasks.cancel"] = function()
  if state.scan then
    begin_scan_cancel(state.scan)
  end
  if state.import_session then
    cancel_import_session()
  end
  if state.similarity_session then
    cancel_similarity_search()
  end
  ai_semantic_cancel()
  AppState.set("transfer_cancel_requested", true)
  return true
end
WebUI.handlers["settings.get"] = function()
  local presets = {}
  for _, preset in ipairs(state.ai_presets) do
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
    ai_presets = presets,
    ai_active_preset_id = state.ai_active_preset_id,
    ai_preset_name = state.ai_preset_name,
  }
end

WebUI.handlers["settings.watch"] = function(params)
  assert(type(params.enabled) == "boolean", "无效监视设置")
  writable()
  set_watch_folder_enabled(params.enabled)
  return true
end

WebUI.handlers["settings.ai"] = function(params)
  writable()
  assert(not state.ai_semantic_session, "请等待 AI 请求结束后修改设置")
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
  if params.action == "test" then
    start_ai_semantic_connection_test()
    return true
  end
  assert(params.action == "save", "未知 AI 设置操作")
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
  local ok, failure = ai_semantic_save_preset()
  AppState.set("ai_api_key_input", "")
  assert(ok, failure)
  return true
end

function webview_receive()
  for _ = 1, 8 do
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
      if state.startup_session and request.method ~= "session.ready" then
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
      send(response)
      WebUI.next_publish = 0
    end
  end
end

function webview_publish()
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
  refresh_revision()
  local libraries, collections, tabs, roots = {}, {}, {}, {}
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
    roots[#roots + 1] = { id = root.id, libraryId = root.library_id, path = root.path }
  end
  local asset = selected_asset()
  local selected = asset_data(asset)
  if selected then
    selected.regions = asset_regions(asset)
    selected.index = state.selected_index
  end
  local snapshot = {
    revision = WebUI.revision,
    count = #state.results,
    loaded = #state.assets,
    pending = results_pending(),
    startup = state.startup_session and {
      phase = state.startup_session.phase,
      failure = state.startup_session.failure,
    } or nil,
    status = text(state.status),
    error = state.status_error,
    readOnly = state.persistence_read_only,
    libraries = libraries,
    collections = collections,
    roots = roots,
    tabs = tabs,
    activeTab = state.workspace_tab_active,
    search = state.search,
    view = state.view,
    libraryId = state.library_filter_id,
    collectionId = state.active_collection_id,
    selected = selected,
    selectedCount = selected_count(),
    playing = state.preview ~= nil,
    position = state.preview_percent or 0,
    regionStart = state.region_start,
    regionEnd = state.region_end,
    autoPreview = state.auto_preview,
    fx = {
      pitch = state.pitch,
      rate = state.rate,
      gain_db = state.gain_db,
      loop = state.loop,
      preserve_pitch = state.preserve_pitch,
      reverse = state.reverse,
    },
    tasks = {
      scan = state.scan ~= nil,
      import = state.import_session ~= nil,
      transfer = state.transfer_running,
      similar = state.similarity_session ~= nil,
      ai = state.ai_semantic_session ~= nil,
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
