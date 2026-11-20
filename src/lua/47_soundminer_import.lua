-- Soundminer libraries are read through shared, read-only database handles.
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
    unchecked = session.pending_count,
    skipped = session.failed, error = reason or "", canceled = session.job_token.cancel_requested == true,
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
  local message = string.format(translate_ui_text("Soundminer：新增 %d，重复 %d，离线 %d，跳过 %d"),
    report.added, report.duplicates, report.offline, report.skipped)
  if report.unchecked > 0 then
    message = message .. " · " .. string.format(translate_ui_text("待检查的音频文件 %d"), report.unchecked)
  end
  if report.error ~= "" then message = message .. " · " .. report.error end
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

-- Explicit mappings and volume/share names give us a root from the first row.
-- For a mapped drive root, keep its top-level source folders distinct.
local function sm_anchor(session, path)
  local prefix = session.new_prefix:gsub("/+$", "")
  if session.new_prefix ~= "" and sm_same_path(path:sub(1, #prefix), prefix)
    and path:sub(#prefix + 1, #prefix + 1) == "/" then
    if session.new_prefix == "/" then return path:match("^(/[^/]+)/") or "/" end
    if session.new_prefix:match("^%a:/$") then return path:match("^(%a:/[^/]+)/") or session.new_prefix end
    return session.new_prefix
  end
  return path:match("^(/Volumes/[^/]+)/") or path:match("^(//[^/]+/[^/]+)/")
end

local function sm_root(session, path)
  local _, existing = root_for_path(path)
  if existing then return existing end
  local folder = sm_path(dirname(path))
  local candidate = sm_anchor(session, path) or session.roots[sm_group(path)] or folder
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

local function sm_metadata(row, ahead_rowid)
  local values = {}
  for name, value in pairs(row) do
    if ((name:sub(1, 1) ~= "_" and name ~= "recid")
      or name == "_FilePathHash" or name == "_WaveformLink" or name == "_Time") and type(value) ~= "table" then
      if type(value) == "string" and not value:find("%z") then values[name] = value
      elseif type(value) == "number" and value == value and math.abs(value) < math.huge then values[name] = value end
    end
  end
  values.__prs_pending_rowid = ahead_rowid
  return neural_json_encode(values)
end

-- Pre-Beta 8 rows retain their original FilePath but omit Soundminer's hidden
-- filepathhash. Look it up by the same lowercase SHA-1 used in waveform caches.
local function sm_path_sha1(path)
  local bits = #path * 8
  path = path .. "\128" .. string.rep("\0", (55 - #path) % 64) .. string.pack(">I8", bits)
  local h0, h1, h2, h3, h4 = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0
  local function rot(value, count)
    value = value & 0xffffffff
    return ((value << count) | (value >> (32 - count))) & 0xffffffff
  end
  local words = {}
  for offset = 1, #path, 64 do
    for i = 0, 15 do words[i] = string.unpack(">I4", path, offset + i * 4) end
    for i = 16, 79 do words[i] = rot(words[i - 3] ~ words[i - 8] ~ words[i - 14] ~ words[i - 16], 1) end
    local a, b, c, d, e = h0, h1, h2, h3, h4
    for i = 0, 79 do
      local f, k
      if i < 20 then f, k = (b & c) | (~b & d), 0x5a827999
      elseif i < 40 then f, k = b ~ c ~ d, 0x6ed9eba1
      elseif i < 60 then f, k = (b & c) | (b & d) | (c & d), 0x8f1bbcdc
      else f, k = b ~ c ~ d, 0xca62c1d6 end
      local next_a = (rot(a, 5) + f + e + k + words[i]) & 0xffffffff
      a, b, c, d, e = next_a, a, rot(b, 30), c, d
    end
    h0, h1, h2 = (h0 + a) & 0xffffffff, (h1 + b) & 0xffffffff, (h2 + c) & 0xffffffff
    h3, h4 = (h3 + d) & 0xffffffff, (h4 + e) & 0xffffffff
  end
  return string.format("%08x%08x%08x%08x%08x", h0, h1, h2, h3, h4)
end

local wave_sources = {}
function SoundminerImport.close_wave_sources()
  for key, source in pairs(wave_sources) do
    if source.db then source.db:close() end
    wave_sources[key] = nil
  end
end

local function sm_wave_source(key, path, required_table)
  local source = wave_sources[key]
  local now = HostApi.time_precise()
  if source and source.path == path then
    if source.db and source.db:unchanged() then return source.db end
    if not source.db and now < source.retry_at then return end
  end
  if source and source.db then source.db:close() end
  source = {path = path, retry_at = now + 2}
  wave_sources[key] = source
  local ok, db, tables = pcall(sm_open, path)
  if ok then
    if tables[required_table] then source.db = db else db:close() end
  end
  return source.db
end

local function sm_overview(params, metadata, original)
  local cache_path = sm_path(params.cachePath)
  if cache_path == "" then cache_path = sm_cache_path(params.path) end
  local hash = sm_text(metadata._FilePathHash)
  local raw_path = sm_text(metadata.FilePath)
  if raw_path == "" then raw_path = original end
  if hash == "" then hash = sm_path_sha1(raw_path) end
  local cache = sm_wave_source("overviews", cache_path, "overviews")
  if cache then
    local row = cache:lookup("overviews", "filepathhash", hash) or cache:lookup("overviews", "filepath", raw_path)
    if row and sm_same_path(row.filepath, original) and type(row.overviews) == "string" then
      return row.overviews, cache
    end
  end
  local database = sm_wave_source("source", params.path, "waveform")
  if not database then return end
  local link = sm_number(metadata._WaveformLink, math.maxinteger)
  if link == 0 and metadata._WaveformLink == nil then
    -- Legacy rows can still resolve a local waveform through the source index.
    local source = database:lookup("justinmetadata", "_FilePathHash", hash)
      or database:lookup("justinmetadata", "FilePath", raw_path)
    if source and sm_same_path(SoundminerImport.resolve_path(source, "", ""), original) then
      link = sm_number(source._WaveformLink, math.maxinteger)
    end
  end
  local row = link > 0 and database:get("waveform", math.floor(link)) or database:lookup("waveform", "FilePath", raw_path)
  if row and sm_same_path(row.FilePath, original) then return row.waveformrep, database end
end

local function sm_read_wave(job, params)
  local asset = job.asset
  local metadata = neural_json_decode(asset.soundminer_metadata)
  if type(metadata) ~= "table" then return end
  local original = SoundminerImport.resolve_path(metadata, "", "")
  if not original then return end
  local rate = sm_number(metadata.SampleRate, 10000000)
  local channels = sm_number(metadata.Channels, 1024)
  local frames = sm_number(metadata.TotalFrames, 9007199254740991)
  local duration = frames > 0 and rate > 0 and frames / rate or tonumber(metadata._Time) or asset.duration
  if rate <= 0 or channels ~= asset.channels or rate ~= asset.sample_rate or duration <= 0
    or math.abs(duration - asset.duration) > 1 / rate then return end
  local blob, source = sm_overview(params, metadata, original)
  if not blob then return end
  local function yield_work()
    if HostApi.time_precise() >= job.soundminer_deadline then coroutine.yield() end
  end
  local decoded = SoundminerWaveform.decode(blob, original, channels, duration, rate,
    frames > 0 and frames or nil, yield_work)
  if not decoded then return end
  local wave = SoundminerWaveform.resample(decoded, job.points, yield_work)
  if wave and source:unchanged() then return wave end
end

function SoundminerImport.step_wave(job)
  if job.soundminer_checked then return end
  local params = SoundminerImport.wave_params or PsyReaSFXScope.params
  if not job.soundminer_worker then
    if PsyReaSFXScope.kind ~= "soundminer" or not params or params.waveforms == false or job.spectral
      or (job.asset.soundminer_metadata or "") == "" then return end
    job.soundminer_worker = coroutine.create(function() return sm_read_wave(job, params) end)
  end
  job.soundminer_deadline = HostApi.time_precise() + 0.002
  local ok, wave = coroutine.resume(job.soundminer_worker)
  if ok and coroutine.status(job.soundminer_worker) ~= "dead" then return "working" end
  job.soundminer_checked, job.soundminer_worker = true, nil
  if ok and wave then return "done", wave end
  -- Unsupported, missing or changing overviews fall through to protected audio.
end

local function sm_asset_fields(row, ahead_rowid)
  local data = {
    description = sm_text(row.Description), keywords = sm_text(row.Keywords), notes = sm_text(row.Notes),
    catid = sm_text(row.CatID), category = sm_text(row.Category), subcategory = sm_text(row.SubCategory),
    duration = sm_number(row._Time, 31536000), sample_rate = sm_number(row.SampleRate, 10000000),
    channels = math.floor(sm_number(row.Channels, 1024)), bit_depth = math.floor(sm_number(row.BitDepth, 128)),
    soundminer_metadata = sm_metadata(row, ahead_rowid), ucs_source = "soundminer",
  }
  if data.description == "" then data.description = sm_text(row.BWDescription) end
  local comment = sm_text(row.UserComments)
  if comment ~= "" then data.notes = data.notes .. (data.notes ~= "" and "\n" or "") .. comment end
  local frames = sm_number(row.TotalFrames, 9007199254740991)
  if frames > 0 and data.sample_rate > 0 then data.duration = frames / data.sample_rate end
  data.ucs_status = (data.catid ~= "" or data.category ~= "" or data.subcategory ~= "") and "manual" or "unclassified"
  return data
end

local function sm_import_row(session, row, ahead)
  local path = SoundminerImport.resolve_path(row, session.old_prefix, session.new_prefix)
  if not path then session.failed = session.failed + 1; return end
  local key, id = path_key(path), row._rowid
  local asset = state.by_path[key]
  if asset then
    session.duplicates = session.duplicates + 1
    -- A direct search may expose a later duplicate before sequential import
    -- reaches the first row for that path. Prefer source order, keeping edits.
    local raw = asset.soundminer_metadata or ""
    if raw:find('"__prs_pending_rowid":', 1, true) then
      local prior = neural_json_decode(raw)
      if type(prior) == "table" and type(prior.__prs_pending_rowid) == "number" and id <= prior.__prs_pending_rowid then
        local previous = sm_asset_fields(prior, prior.__prs_pending_rowid)
        previous.soundminer_metadata = raw
        for field, value in pairs(sm_asset_fields(row, ahead and id)) do
          if asset[field] == previous[field] then asset[field] = value end
        end
        asset._search_blob = nil
        refresh_ucs_pending_membership(asset)
        mark_asset_database_change(asset)
        AppState.set("results_dirty", true)
      end
    end
  else
    local record = sm_root(session, path)
    if not record then session.failed = session.failed + 1; return end
    asset = make_placeholder(path, record.path, true)
    for field, value in pairs(sm_asset_fields(row, ahead and id)) do asset[field] = value end
    -- Negative means metadata arrived before local media verification. The
    -- saved marker lets a canceled/interrupted import resume exactly once.
    asset.size, asset.last_seen = 0, -1
    asset.indexed, asset.ready = true, true
    add_or_update_asset(asset, false)
    -- The catalog-exclusive import commits a full snapshot on completion or
    -- cancel. Avoid a second journal copy of every new metadata row.
    mark_database_snapshot_dirty()
    session.added = session.added + 1
    local now = HostApi.time_precise()
    if not state.results_job and now >= (session.next_results_refresh or 0) then
      AppState.set("results_dirty", true)
      session.next_results_refresh = now + 1
    end
  end
  if asset.last_seen == -1 and not session.pending_media[asset] then
    session.pending_media[asset] = true
    session.pending_count = session.pending_count + 1
  end
  session.current = { asset = asset }
  return asset
end

function SoundminerImport.prioritize_row(session, row)
  if session ~= state.import_session or session.phase ~= "soundminer_import" then return false end
  local id = type(row) == "table" and row._rowid
  if math.type(id) ~= "integer" or (session.last_read_rowid and id <= session.last_read_rowid)
    or session.ahead[id] or session.ahead_count >= 256 then return false end
  local path = SoundminerImport.resolve_path(row, session.old_prefix, session.new_prefix)
  if not path or not (sm_anchor(session, path) or session.roots_planned or root_for_path(path)) then return false end
  assert(session.database:unchanged(), "Soundminer 数据库正在变化，本次导入已停止；请改用稳定副本")
  local asset = sm_import_row(session, row, true)
  session.ahead[id], session.ahead_count = asset or true, session.ahead_count + 1
  return asset ~= nil
end

local function sm_plan_roots(session)
  -- An unanchored local path could be below a user's home or drive root.
  -- Derive the common source folders rather than registering such a broad root.
  -- The native projection reads just path fields for this uncommon pass.
  session.phase = "soundminer_inspect"
  local database = session.database
  local batches = database.path_batches and database:path_batches(HostApi.time_precise)
    or database:row_batches("justinmetadata", HostApi.time_precise)
  for batch in batches do
    for _, row in ipairs(batch) do
      local path = SoundminerImport.resolve_path(row, session.old_prefix, session.new_prefix)
      if path and not sm_anchor(session, path) then
        local group, folder = sm_group(path), sm_path(dirname(path))
        session.roots[group] = session.roots[group] and sm_common(session.roots[group], folder) or folder
      end
    end
    session.total = session.total + #batch
    coroutine.yield()
  end
  assert(database:unchanged(), "Soundminer 数据库正在变化，本次导入已停止；请改用稳定副本")
  session.roots_planned, session.phase = true, "soundminer_import"
end

local function sm_work(session)
  local database = session.database
  for batch in database:row_batches("justinmetadata", HostApi.time_precise) do
    coroutine.yield()
    assert(database:unchanged(), "Soundminer 数据库正在变化，本次导入已停止；请改用稳定副本")
    for _, row in ipairs(batch) do
      local path = SoundminerImport.resolve_path(row, session.old_prefix, session.new_prefix)
      if path and not session.roots_planned and not sm_anchor(session, path) and not root_for_path(path) then
        sm_plan_roots(session)
      end
      local id = row._rowid
      local ahead = session.ahead[id]
      if ahead then
        session.ahead[id], session.ahead_count = nil, session.ahead_count - 1
        if type(ahead) == "table" then
          local raw = ahead.soundminer_metadata or ""
          if raw:find('"__prs_pending_rowid":', 1, true) then
            local fields = neural_json_decode(raw)
            if fields.__prs_pending_rowid == id then
              fields.__prs_pending_rowid = nil
              ahead.soundminer_metadata = neural_json_encode(fields)
              mark_asset_database_change(ahead)
            end
          end
        end
      else
        sm_import_row(session, row)
      end
      session.last_read_rowid, session.done = id, session.done + 1
      if HostApi.time_precise() >= (session.deadline or 0) then
        coroutine.yield()
        assert(database:unchanged(), "Soundminer 数据库正在变化，本次导入已停止；已完成部分保留，请改用稳定副本")
      end
    end
  end
  assert(database:unchanged(), "Soundminer 数据库正在变化，本次导入已停止；已完成部分保留，请改用稳定副本")
  session.total = session.done
  database:close()
  session.database = nil
  if session.pending_count == 0 then return end

  -- All rows can now be searched and selected, even if checking an external
  -- drive is slow. Only the unique asset references are pending, no row copy.
  session.phase, session.done, session.total = "soundminer_verify_media", 0, session.pending_count
  AppState.set("results_dirty", true)
  coroutine.yield()
  for asset in pairs(session.pending_media) do
    local info = SoundminerPaths.stat(asset.path)
    local now = os.time()
    asset.size, asset.last_seen = info and info.size or 0, info and now or 0
    asset._size_retry_at = not info and now + 15 or nil
    if not info then session.offline = session.offline + 1 end
    session.pending_media[asset] = nil
    session.pending_count, session.done = session.pending_count - 1, session.done + 1
    mark_database_snapshot_dirty()
    if HostApi.time_precise() >= (session.deadline or 0) then coroutine.yield() end
  end
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
    import_waveforms = params.waveforms ~= false, ahead = {}, ahead_count = 0,
    pending_media = {}, pending_count = 0,
    started = HostApi.time_precise(), phase = "soundminer_import", label = "导入 Soundminer 音效库",
    done = 0, total = 0, added = 0, duplicates = 0, offline = 0, failed = 0,
    job_token = token }
  SoundminerImport.close_wave_sources()
  SoundminerImport.wave_params = params
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
  session.deadline = HostApi.time_precise() + 0.004
  local steps = 0
  repeat
    local ok, err = coroutine.resume(session.worker)
    if not ok then SoundminerImport.finish(session, tostring(err)); return end
    if coroutine.status(session.worker) == "dead" then SoundminerImport.finish(session); return end
    steps = steps + 1
  until steps >= 32 or HostApi.time_precise() >= session.deadline
end
