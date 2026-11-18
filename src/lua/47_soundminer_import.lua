-- Soundminer libraries are read without SQL, source writes or process control.
-- The normal catalog job owns cancellation, persistence and exclusive mutations.
SoundminerImport = {}

local function sm_text(value)
  return type(value) == "string" and value or ""
end

local function sm_number(value, maximum)
  value = tonumber(value)
  if not value or value ~= value or value < 0 or value > maximum then return 0 end
  return value
end

local function sm_path(value)
  value = sm_text(value):gsub("\\", "/")
  assert(not value:find("%z") and #value <= 32768, "Soundminer 路径无效")
  if value == "/" or value:match("^%a:/+$") then return value:sub(1, 3) end
  return value:gsub("/+$", "")
end

local function sm_absolute(value)
  return value:match("^%a:/") or value:sub(1, 1) == "/"
end

local function sm_no_dot_segments(path)
  for part in path:gmatch("[^/]+") do if part == ".." or part == "." then return false end end
  return true
end

local function sm_same_path(left, right)
  left, right = sm_path(left), sm_path(right)
  if right:match("^%a:/") or right:sub(1, 2) == "//" then return left:lower() == right:lower() end
  return left == right
end

function SoundminerImport.resolve_path(row, old_prefix, new_prefix)
  local path = sm_path(row.FilePath)
  if path == "" then
    local folder, name = sm_path(row.Pathname), sm_text(row.Filename)
    if folder ~= "" and name ~= "" and not name:find("[/\\]") then path = folder .. "/" .. name end
  end
  if path == "" or not sm_absolute(path) then return nil end
  -- Do not resolve '..' from an external library or silently guess a drive label.
  if not sm_no_dot_segments(path) then return nil end
  local prefix = old_prefix:gsub("/+$", "")
  local compare_path, compare_prefix = path, prefix
  if path:match("^%a:/") or path:sub(1, 2) == "//" then
    compare_path, compare_prefix = path:lower(), prefix:lower()
  end
  if old_prefix ~= "" and (compare_path == compare_prefix or compare_path:sub(1, #prefix + 1) == compare_prefix .. "/") then
    path = new_prefix:gsub("/+$", "") .. path:sub(#prefix + 1)
  end
  if not sm_no_dot_segments(path) or not sm_absolute(path) then return nil end
  return path
end

local function sm_group(path)
  return path:match("^(%a:)/") or path:match("^(//[^/]+/[^/]+)")
    or path:match("^(/Volumes/[^/]+)") or "/"
end

local function sm_common(first, path)
  while first ~= "" and path ~= first and path:sub(1, #first + 1) ~= first .. "/" do
    local parent = first:match("^(.*)/[^/]+$") or ""
    if parent == first then break end
    first = parent
  end
  return first
end

function SoundminerImport.discover()
  local bases, found, seen = {}, {}, {}
  local appdata = os.getenv("APPDATA")
  local home_dir = os.getenv("HOME")
  if appdata and appdata ~= "" then bases[#bases + 1] = sm_path(appdata) end
  if home_dir and home_dir ~= "" then bases[#bases + 1] = sm_path(home_dir) .. "/Library/Application Support" end
  for _, base in ipairs(bases) do
    for _, version in ipairs({ "SoundminerV7", "SoundminerV6", "SoundminerV5", "SMData" }) do
      local folder = base .. "/" .. version .. "/Databases"
      for index = 0, 1023 do
        local name = HostApi.EnumerateFiles(folder, index)
        if not name then break end
        if name:lower():match("%.sqlite$") or name:lower():match("%.db$") then
          local path = folder .. "/" .. name
          if not seen[path] then
            seen[path] = true
            found[#found + 1] = { path = path, name = name:gsub("%.[^.]+$", ""), version = version }
          end
        end
      end
    end
  end
  return found
end

function SoundminerImport.choose()
  local ok, path = HostApi.GetUserFileNameForRead("", translate_ui_text("选择 Soundminer 数据库"), "sqlite,db")
  return ok and sm_path(path) or false
end

local function sm_open(path)
  local db, err = SoundminerSQLite.open(path)
  assert(db, err)
  local ok, tables = pcall(function() return db:tables() end)
  if not ok then db:close(); error(tables, 0) end
  return db, tables
end

local function sm_schema(tables)
  local table_info = tables.justinmetadata
  assert(table_info, "不是支持的 Soundminer 素材库：缺少 justinmetadata 表")
  local columns = {}
  for _, name in ipairs(table_info.columns) do columns[name] = true end
  assert(columns.FilePath or (columns.Pathname and columns.Filename), "Soundminer 素材库缺少文件路径字段")
end

local function sm_cache_path(path)
  return dirname(dirname(path)) .. "/Caches/waveforms.sqlite"
end

function SoundminerImport.inspect(path)
  path = sm_path(path)
  local db, tables = sm_open(path)
  local ok, result = pcall(function()
    sm_schema(tables)
    local samples = {}
    local rows = db:rows("justinmetadata")
    for _ = 1, 3 do
      local row = rows()
      if not row then break end
      samples[#samples + 1] = SoundminerImport.resolve_path(row, "", "") or ""
    end
    assert(db:unchanged(), "Soundminer 数据库正在变化，本次读取已停止；可保持 Soundminer 运行，改用稳定副本重试")
    local cache = sm_cache_path(path)
    return { path = path, samples = samples,
      cachePath = SoundminerReadOnly.stat(cache) and cache or "",
      name = basename(path):gsub("%.[^.]+$", "") }
  end)
  db:close()
  if not ok then error(result, 0) end
  return result
end

local function sm_close(session)
  if session.database then session.database:close(); session.database = nil end
  if session.cache then session.cache:close(); session.cache = nil end
  session.worker = nil
end

local function sm_outcome(report, phase)
  local saved, reason = pcall(SoundminerCatalog.set_outcome, phase)
  if not saved then
    report.error = translate_ui_text("无法保存独立库导入进度") .. " · " .. tostring(reason)
  end
end

function SoundminerImport.snapshot_finished(snapshot, reason)
  local report = snapshot.soundminer_report
  if not report then return end
  report.saving = false
  if reason then
    report.error = translate_ui_text("保存失败；素材仍在当前会话，请检查数据目录和磁盘空间")
      .. " · " .. tostring(reason)
  else
    sm_outcome(report, "complete")
  end
  if report.error ~= "" then
    snapshot.soundminer_job.state, snapshot.soundminer_job.message = "failed", report.error
    set_status(report.error, true)
  end
end

function SoundminerImport.finish(session, reason)
  sm_close(session)
  if state.import_session == session then AppState.set("import_session", nil) end
  AppState.set("import_cancel_requested", false)
  Jobs.finish(session.job_token, reason == nil, reason)
  if session.added > 0 then
    rebuild_library_indexes()
    AppState.set("results_dirty", true)
    invalidate_library_counts()
    invalidate_folder_navigation()
    mark_database_snapshot_dirty()
  end
  if session.added > 0 or state.libraries_dirty or state.db_dirty then
    local libraries_ok, libraries_saved = true, true
    if state.libraries_dirty then libraries_ok, libraries_saved = pcall(save_libraries) end
    local database_ok, database_saved = false, false
    if libraries_ok and libraries_saved then database_ok, database_saved = pcall(save_database_changes) end
    if not libraries_ok or not libraries_saved or not database_ok or not database_saved then
      reason = (reason and reason .. " · " or "") .. translate_ui_text("保存失败；素材仍在当前会话，请检查数据目录和磁盘空间")
      session.job_token.state, session.job_token.message = "failed", reason
    end
  end
  reset_watch_schedule(true)
  local report = {
    added = session.added, duplicates = session.duplicates, offline = session.offline,
    skipped = session.failed, waveforms = session.waveforms, waveSkipped = session.wave_skipped,
    cacheError = session.cache_error or "", error = reason or "", canceled = session.job_token.cancel_requested == true,
  }
  if report.canceled and not session.interrupted then
    sm_outcome(report, "canceled")
  elseif not reason then
    if state.database_snapshot_session then
      report.saving = true
      state.database_snapshot_session.soundminer_report = report
      state.database_snapshot_session.soundminer_job = session.job_token
    else
      sm_outcome(report, "complete")
    end
  end
  AppState.set("soundminer_report", report)
  local message = string.format(translate_ui_text("Soundminer：新增 %d，重复 %d，离线 %d，跳过 %d，波形 %d，待重建波形 %d"),
    report.added, report.duplicates, report.offline, report.skipped, report.waveforms, report.waveSkipped)
  if report.error ~= "" then message = message .. " · " .. report.error end
  if report.cacheError ~= "" then message = message .. " · " .. report.cacheError end
  set_status(message, report.error ~= "" or report.skipped > 0)
  return report
end

function SoundminerImport.cancel(session, interrupted)
  session = session or state.import_session
  if not session or not session.soundminer then return end
  session.interrupted = interrupted
  Jobs.cancel(session.job_token)
  return SoundminerImport.finish(session, translate_ui_text("已取消；已导入素材保留"))
end

local function sm_root(session, path)
  local _, existing = root_for_path(path)
  if existing then return existing end
  local folder = sm_path(dirname(path))
  local candidate = session.roots[sm_group(path)] or folder
  if candidate == "" or candidate == "/" or candidate:match("^%a:$") then candidate = folder end
  local valid, reason, conflict = validate_new_root(candidate)
  if not valid and (reason == "covered" or reason == "exact") and conflict.enabled ~= false then return conflict end
  if not valid then
    candidate = folder
    valid, reason, conflict = validate_new_root(candidate)
    if not valid then return nil end
  end
  if not session.library then
    local id = stable_id("lib", "soundminer:" .. path_key(session.path) .. "|" .. session.old_prefix .. "|" .. session.new_prefix)
    session.library = state.library_by_id[id] or create_library(session.name,
      "soundminer:" .. path_key(session.path) .. "|" .. session.old_prefix .. "|" .. session.new_prefix)
  end
  -- Offline source paths are intentional: they remain relinkable after import.
  local record = { id = stable_id("root", path_key(candidate)), library_id = session.library.id,
    path = candidate, alias = "", enabled = true, artwork_path = "", artwork_checked = false,
    artwork_scan_version = 0 }
  state.root_records[#state.root_records + 1] = record
  state.root_by_id[record.id], state.root_by_path[path_key(candidate)] = record, record
  state.roots[#state.roots + 1] = candidate
  session.library.roots[#session.library.roots + 1] = record
  AppState.set("libraries_dirty", true)
  return record
end

local function sm_metadata(row)
  local values = {}
  for name, value in pairs(row) do
    if name:sub(1, 1) ~= "_" and name ~= "recid" and type(value) ~= "table" then
      if type(value) == "string" and not value:find("%z") then values[name] = value
      elseif type(value) == "number" and value == value and math.abs(value) < math.huge then values[name] = value end
    end
  end
  return neural_json_encode(values)
end

local function sm_wave(session, asset, row)
  if not session.import_waveforms then return end
  if wave_cache_file_exists(asset, state.mini_wave_points)
    and wave_cache_file_exists(asset, 2048, true) and wave_cache_file_exists(asset, 4096, true)
    and wave_cache_file_exists(asset, 2048, false) and wave_cache_file_exists(asset, 4096, false) then return end
  local source_rate, source_channels = sm_number(row.SampleRate, 10000000), sm_number(row.Channels, 1024)
  local source_frames = sm_number(row.TotalFrames, 9007199254740991)
  local source_duration = source_frames > 0 and source_rate > 0 and source_frames / source_rate
    or sm_number(row._Time, 31536000)
  -- A repeated import must not attach an old overview to an asset rescanned
  -- since the Soundminer snapshot (the PRS key includes the current file size).
  if source_rate <= 0 or source_duration <= 0 or source_channels ~= asset.channels
    or source_rate ~= asset.sample_rate or math.abs(source_duration - asset.duration) > 1 / source_rate then
    session.wave_skipped = session.wave_skipped + 1
    return
  end
  local original = SoundminerImport.resolve_path(row, "", "")
  if not original then return end
  local blob
  if session.cache then
    assert(session.cache:unchanged(), "Soundminer 波形缓存正在变化，本次导入已停止；请改用稳定副本")
    local found = session.cache:lookup("overviews", "filepathhash", sm_text(row._FilePathHash))
    if not found then found = session.cache:lookup("overviews", "filepath", sm_text(row.FilePath)) end
    if found and sm_same_path(found.filepath, original) then blob = found.overviews end
  end
  if not blob and session.local_wave and sm_number(row._WaveformLink, math.maxinteger) > 0 then
    local found = session.database:get("waveform", math.floor(tonumber(row._WaveformLink)))
    if found and sm_same_path(found.FilePath, original) then blob = found.waveformrep end
  end
  if not blob then session.wave_skipped = session.wave_skipped + 1; return end
  local frames = sm_number(row.TotalFrames, 9007199254740991)
  local waveform = SoundminerWaveform.decode(blob, original, asset.channels, asset.duration, asset.sample_rate,
    frames > 0 and frames or nil, coroutine.yield)
  if not waveform then session.wave_skipped = session.wave_skipped + 1; return end
  assert(session.database:unchanged() and (not session.cache or session.cache:unchanged()),
    "Soundminer 数据或波形缓存正在变化，本次导入已停止；请改用稳定副本")
  local thumbnail = SoundminerWaveform.resample(waveform, state.mini_wave_points, coroutine.yield)
  assert(session.database:unchanged() and (not session.cache or session.cache:unchanged()),
    "Soundminer 数据或波形缓存正在变化，本次导入已停止；请改用稳定副本")
  if thumbnail then
    if not wave_cache_file_exists(asset, state.mini_wave_points) then save_wave_to_disk(asset, state.mini_wave_points, thumbnail) end
    if wave_cache_file_exists(asset, state.mini_wave_points) then session.waveforms = session.waveforms + 1
    else session.wave_skipped = session.wave_skipped + 1 end
  end
  for _, points in ipairs({ 2048, 4096 }) do
    coroutine.yield()
    local detail = SoundminerWaveform.resample(waveform, points, coroutine.yield)
    assert(session.database:unchanged() and (not session.cache or session.cache:unchanged()),
      "Soundminer 数据或波形缓存正在变化，本次导入已停止；请改用稳定副本")
    for _, preserve in ipairs({ false, true }) do
      if not wave_cache_file_exists(asset, points, preserve) then save_wave_to_disk(asset, points, detail, preserve) end
    end
  end
end

local function sm_import_row(session, row)
  assert(session.database:unchanged() and (not session.cache or session.cache:unchanged()),
    "Soundminer 数据或波形缓存正在变化，本次导入已停止；请改用稳定副本")
  local path = SoundminerImport.resolve_path(row, session.old_prefix, session.new_prefix)
  if not path then session.failed = session.failed + 1; return end
  local asset = state.by_path[path_key(path)]
  if asset then
    session.duplicates = session.duplicates + 1
    -- Existing catalog metadata and user edits always win on repeat imports.
  else
    local record = sm_root(session, path)
    if not record then session.failed = session.failed + 1; return end
    asset = make_placeholder(path, record.path, true)
    asset.duration = sm_number(row._Time, 31536000)
    asset.sample_rate = sm_number(row.SampleRate, 10000000)
    local frames = sm_number(row.TotalFrames, 9007199254740991)
    if frames > 0 and asset.sample_rate > 0 then asset.duration = frames / asset.sample_rate end
    asset.channels = math.floor(sm_number(row.Channels, 1024))
    asset.bit_depth = math.floor(sm_number(row.BitDepth, 128))
    local source_info = SoundminerReadOnly.stat(path)
    asset.size = source_info and source_info.size or 0
    asset.description = sm_text(row.Description)
    if asset.description == "" then asset.description = sm_text(row.BWDescription) end
    asset.keywords = sm_text(row.Keywords)
    asset.notes = sm_text(row.Notes)
    if sm_text(row.UserComments) ~= "" then
      asset.notes = asset.notes .. (asset.notes ~= "" and "\n" or "") .. row.UserComments
    end
    asset.soundminer_metadata = sm_metadata(row)
    asset.catid, asset.category, asset.subcategory = sm_text(row.CatID), sm_text(row.Category), sm_text(row.SubCategory)
    asset.ucs_status = (asset.catid ~= "" or asset.category ~= "" or asset.subcategory ~= "") and "manual" or "unclassified"
    asset.ucs_source = "soundminer"
    asset.indexed, asset.ready = true, true
    local exists = source_info ~= nil
    asset.last_seen = exists and os.time() or 0
    if not exists then session.offline = session.offline + 1 end
    add_or_update_asset(asset, false)
    mark_asset_database_change(asset)
    session.added = session.added + 1
    local now = HostApi.time_precise()
    if not state.results_job and now >= (session.next_results_refresh or 0) then
      AppState.set("results_dirty", true)
      session.next_results_refresh = now + 2
    end
  end
  session.current = { asset = asset }
  if session.import_waveforms then
    local ok, err = pcall(sm_wave, session, asset, row)
    if not ok then
      assert(session.database:unchanged() and (not session.cache or session.cache:unchanged()),
        "Soundminer 数据或波形缓存正在变化，本次导入已停止；已导入部分保留，请改用稳定副本")
      session.wave_skipped = session.wave_skipped + 1
      session.cache_error = tostring(err)
      if session.cache then session.cache:close(); session.cache = nil end
    end
  end
end

local function sm_work(session)
  -- First pass validates records and computes compact source roots without audio I/O.
  for batch in session.database:row_batches("justinmetadata", HostApi.time_precise) do
    for _, row in ipairs(batch) do
      local path = SoundminerImport.resolve_path(row, session.old_prefix, session.new_prefix)
      if path then
        local group, folder = sm_group(path), sm_path(dirname(path))
        session.roots[group] = session.roots[group] and sm_common(session.roots[group], folder) or folder
      end
    end
    session.total = session.total + #batch
    coroutine.yield()
  end
  assert(session.database:unchanged(), "Soundminer 数据库正在变化，本次导入已停止；请改用稳定副本")
  session.phase = "soundminer_import"
  for row in session.database:rows("justinmetadata") do
    sm_import_row(session, row)
    session.done = session.done + 1
    coroutine.yield()
  end
  assert(session.database:unchanged(), "Soundminer 数据库正在变化，本次导入已停止；已完成部分保留，请改用稳定副本")
  if session.cache and not session.cache:unchanged() then session.cache_error = "Soundminer 波形缓存已变化" end
end

function SoundminerImport.start(params)
  assert(PsyReaSFXScope.kind == "soundminer" and SoundminerCatalog.matches(params),
    "请在对应的独立 Soundminer 库中导入")
  assert(not state.persistence_read_only, "素材库处于只读保护")
  assert(not state.startup_session and not state.scan and not state.import_session, "请等待当前扫描或导入完成")
  local path = sm_path(params.path)
  assert(sm_absolute(path), "请选择 Soundminer 数据库")
  local old_prefix, new_prefix = sm_path(params.oldPrefix), sm_path(params.newPrefix)
  assert((old_prefix == "") == (new_prefix == ""), "路径映射需要同时填写原路径和新路径")
  assert(old_prefix == "" or (sm_absolute(old_prefix) and sm_absolute(new_prefix)), "路径映射必须使用绝对路径")
  assert(sm_no_dot_segments(old_prefix) and sm_no_dot_segments(new_prefix), "路径映射不能包含 . 或 .. 路径段")
  local db, tables = sm_open(path)
  local ok, err = pcall(sm_schema, tables)
  if not ok then db:close(); error(err, 0) end
  local token, job_error = Jobs.begin("catalog_pipeline", "catalog_exclusive", false)
  if not token then db:close(); error(job_error == "resource_busy" and "另一个目录写任务正在运行" or "导入任务已经在运行", 0) end
  local session = { soundminer = true, database = db, path = path, roots = {},
    name = basename(path):gsub("%.[^.]+$", ""), old_prefix = old_prefix, new_prefix = new_prefix,
    local_wave = tables.waveform ~= nil, import_waveforms = params.waveforms ~= false,
    started = HostApi.time_precise(), phase = "soundminer_inspect", label = "导入 Soundminer 音效库",
    done = 0, total = 0, added = 0, duplicates = 0, offline = 0, failed = 0,
    waveforms = 0, wave_skipped = 0, assets = {}, job_token = token }
  if session.import_waveforms then
    local cache_path = sm_path(params.cachePath)
    if cache_path == "" then cache_path = sm_cache_path(path) end
    if SoundminerReadOnly.stat(cache_path) then
      local cache_ok, cache, cache_tables = pcall(sm_open, cache_path)
      if cache_ok and cache_tables.overviews then session.cache = cache
      elseif cache_ok then cache:close(); session.cache_error = "不支持的 Soundminer 波形缓存结构"
      else session.cache_error = tostring(cache) end
    end
  end
  session.worker = coroutine.create(function() sm_work(session) end)
  AppState.set("import_session", session)
  AppState.set("soundminer_report", nil)
  AppState.set("import_cancel_requested", false)
  set_status("正在读取 Soundminer 音效库…")
  return { started = true, jobId = token.generation }
end

function SoundminerImport.process(session)
  if session.job_token.cancel_requested or state.import_cancel_requested then SoundminerImport.cancel(session); return end
  if not can_run_heavy_job() then return end
  local deadline, steps = HostApi.time_precise() + 0.004, 0
  repeat
    local ok, err = coroutine.resume(session.worker)
    if not ok then SoundminerImport.finish(session, tostring(err)); return end
    if coroutine.status(session.worker) == "dead" then SoundminerImport.finish(session); return end
    steps = steps + 1
  until steps >= 32 or HostApi.time_precise() >= deadline
end
