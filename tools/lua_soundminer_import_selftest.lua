-- Run the actual generated runtime in independent Lua environments, as separate
-- REAPER ReaScripts do. Only host/device/window APIs are mocked. All writes are
-- restricted to the generated fixture; original PRS files are byte-compared.
local entry = assert(arg[1], "generated WebView runtime required")
local fixture = assert(arg[2], "fresh synthetic fixture directory required"):gsub("\\", "/"):gsub("/+$", "")
assert(fixture:match("^%a:/") or fixture:sub(1, 1) == "/", "fixture path must be absolute")
local resource = fixture .. "/runtime"
local native_open, native_remove, native_rename = io.open, os.remove, os.rename
local shared_read_fixture = assert(loadfile("tools/lua_shared_readonly_fixture.lua"))()
local function key(path) return tostring(path):gsub("\\", "/"):gsub("/+$", ""):lower() end
local function writable(path)
  assert(key(path):sub(1, #key(fixture) + 1) == key(fixture) .. "/", "write outside fixture: " .. tostring(path))
end
io.open = function(path, mode)
  if mode and mode:find("[wa+]") then writable(path) end
  return native_open(path, mode)
end
os.remove = function(path) writable(path); return native_remove(path) end
os.rename = function(from, to)
  if key(from) ~= key(to) then writable(from); writable(to) end
  return native_rename(from, to)
end
local function read(path)
  local file = assert(io.open(path, "rb")); local bytes = file:read("*a"); file:close(); return bytes
end
local function write(path, bytes)
  local file = assert(io.open(path, "wb")); assert(file:write(bytes)); assert(file:close())
end
write(resource .. "/PsyReaSFX_Runtime.lua", read(entry))
write(resource .. "/runtime-lock.json", read(arg[3] or "dependencies/reawebapi/windows-x64.lock.json"))
entry = resource .. "/PsyReaSFX_Runtime.lua"
local inventory, extstate, windows, actions, queued = {}, {}, {}, {}, {}
local command_count, focus_count, window_id = 0, 0, 0
local function register_directory(path)
  local normalized = key(path)
  if inventory[normalized] then return end
  inventory[normalized] = { files = {}, directories = {} }
  local parent, name = normalized:match("^(.*)/([^/]+)$")
  if parent and #parent >= #key(fixture) then
    register_directory(parent)
    table.insert(inventory[parent].directories, name)
    table.sort(inventory[parent].directories)
  end
end
local function mkdir(path)
  writable(path)
  local exists, _, code = native_rename(path .. "/", path .. "/")
  if not exists and code ~= 13 then
    -- Fixture paths are controlled input. Shell is used only to mock REAPER's
    -- recursive mkdir; production writes never escape the verified fixture.
    assert(not path:find('["%%!&|<>\r\n]'), "unsafe fixture path")
    assert(os.execute('mkdir "' .. path:gsub("/", "\\") .. '" >NUL 2>NUL'))
  end
  register_directory(path)
  return 1
end
local function boot(path, context)
  local env = setmetatable({}, { __index = _G })
  env._G = env
  env.PRS_SOUNDMINER_CONTEXT = context
  env.os = setmetatable({getenv = function(name)
    if name == "APPDATA" then return fixture end
    return os.getenv(name)
  end}, {__index = os})
  env.loadfile = function(file, mode) return loadfile(file, mode or "t", env) end
  local deferred
  env.reaper = {
    ReaWeb_ReadSharedRange = function(file, offset, count)
      if inventory[key(file)] then
        if count == 0 then return '{"protocol":1,"ok":true,"dataHex":"","size":"0","mtime":"0","fileId":"1","directory":true}' end
        return '{"protocol":1,"ok":false,"code":"NOT_FILE","osError":21}'
      end
      return shared_read_fixture(file, offset, count)
    end,
    GetResourcePath = function() return resource end,
    GetOS = function() return "Win64" end,
    time_precise = os.clock,
    GetPlayState = function() return 0 end,
    GetPlayStateEx = function() return 0 end,
    file_exists = function(file)
      local handle = io.open(file, "rb"); if not handle then return false end
      handle:close(); return true
    end,
    RecursiveCreateDirectory = mkdir,
    EnumerateFiles = function(folder, index)
      local directory = inventory[key(folder)]; return directory and directory.files[index + 1]
    end,
    EnumerateSubdirectories = function(folder, index)
      local directory = inventory[key(folder)]; return directory and directory.directories[index + 1]
    end,
    EnumProjects = function() return nil, "" end,
    PCM_Source_CreateFromFile = function(path) return { path = path } end,
    PCM_Source_Destroy = function() end,
    GetMediaSourceLength = function() return 1536 / 48000, false end,
    GetMediaSourceNumChannels = function() return 1 end,
    GetMediaSourceSampleRate = function() return 48000 end,
    GetMediaSourceType = function() return "WAVE" end,
    GetMediaFileMetadata = function() return false, "" end,
    CF_GetMediaSourceBitDepth = function() return 16 end,
    GetExtState = function(section, name) return extstate[section .. name] or "" end,
    SetExtState = function(section, name, value) extstate[section .. name] = value end,
    DeleteExtState = function(section, name) extstate[section .. name] = nil end,
    ReaWeb_Open = function() window_id = window_id + 1; windows[window_id] = true; return window_id end,
    ReaWeb_IsOpen = function(id) return windows[id] == true end,
    ReaWeb_IsReady = function() return true end,
    ReaWeb_Send = function() return true end,
    ReaWeb_Receive = function() return "" end,
    ReaWeb_Close = function(id) windows[id] = nil end,
    ReaWeb_Show = function() end,
    ReaWeb_Focus = function() focus_count = focus_count + 1 end,
    AddRemoveReaScript = function(_, _, file)
      for action, registered in pairs(actions) do if registered == file then return action end end
      local id = #actions + 1; actions[id] = file; return id
    end,
    Main_OnCommand = function(action) command_count = command_count + 1; queued[#queued + 1] = assert(actions[action]) end,
    defer = function(callback) deferred = callback end,
    atexit = function() end,
    MB = function(message) error(message) end,
  }
  assert(env.loadfile(path))()
  if not next(inventory) then inventory = env.neural_json_decode(read(fixture .. "/inventory.json")) end
  env.runtime = assert(env.AppState.raw)
  env.runtime.auto_backup, env.runtime.watch_enabled = false, false
  for _ = 1, 100 do
    if not env.runtime.startup_session then break end
    assert(not env.runtime.startup_session.failure, env.runtime.startup_session.failure)
    env.process_startup()
  end
  assert(not env.runtime.startup_session and deferred, "runtime startup")
  env.can_run_heavy_job = function() return true end
  return env
end
local function launch() return boot(assert(table.remove(queued, 1), "expected registered action")) end
local function drain_save(env)
  for _ = 1, 1000 do
    if not env.runtime.database_snapshot_session then return end
    env.process_database_snapshot()
  end
  error("save did not finish")
end
local function finish(env)
  env.SoundminerCatalog.process_pending()
  for _ = 1, 10000 do
    if not env.runtime.import_session then drain_save(env); return assert(env.runtime.soundminer_report) end
    env.process_import_session()
  end
  error("import did not finish")
end
local function asset(env, relative) return assert(env.runtime.by_path[env.path_key(fixture .. "/audio/" .. relative)]) end
-- The fixture generator creates these source folders before the host starts.
-- A real shared stat can see them independently of REAPER's mkdir calls.
register_directory(fixture .. "/audio/FX")
register_directory(fixture .. "/audio/Music")
inventory[key(fixture .. "/audio/FX")].files = {"fallback.wav","impact.wav","local.wav","no-frames.wav","not-in-soundminer.wav"}
inventory[key(fixture .. "/audio/Music")].files = {"tone.wav"}
local prs = boot(entry)
assert(not pcall(boot, entry, { id = "../../original" }), "invalid wrapper context rejected before data access")
local db_path = fixture .. "/SoundminerV7/Databases/Synthetic.sqlite"
local cache_path = fixture .. "/SoundminerV7/Caches/waveforms.sqlite"
local database_before, cache_before = read(db_path), read(cache_path)
local params = { path = db_path, oldPrefix = "/Volumes/SM-Audio", newPrefix = fixture .. "/audio" }
local inspected = prs.SoundminerImport.inspect(db_path)
assert(#inspected.samples == 3 and key(inspected.cachePath) == key(cache_path))
assert(not pcall(prs.SoundminerImport.inspect, fixture .. "/unsupported.sqlite"))
assert(not pcall(prs.SoundminerImport.inspect, fixture .. "/wal.sqlite"))
assert(not pcall(prs.SoundminerImport.start, params) and not pcall(prs.SoundminerCatalog.resume), "default catalog cannot import")
assert(#prs.runtime.assets == 0 and #prs.runtime.root_records == 0, "inspection is read only")

-- Seed the original PRS catalog with the identical physical audio file, its own
-- metadata/favorite/cache, and a legacy config that isolated startup must ignore.
local owner = prs.create_library("PRS original owner", "original-prs")
assert(prs.add_root_to_library(owner.id, fixture .. "/audio", false))
local original = prs.make_placeholder(fixture .. "/audio/FX/impact.wav", fixture .. "/audio", true)
original.description, original.notes = "PRS-owned description", "PRS-owned note"
original.duration, original.sample_rate, original.channels = 9, 48000, 1
original.size, original.indexed, original.ready = prs.file_size(original.path), true, true
prs.add_or_update_asset(original, false); prs.mark_asset_database_change(original)
prs.runtime.favorites[prs.path_key(original.path)] = true
local original_wave = { count = prs.runtime.mini_wave_points, peaks = {}, mins = {}, channels = 1, duration = 9 }
for index = 1, original_wave.count do original_wave.peaks[index], original_wave.mins[index] = 0.25, -0.25 end
prs.save_wave_to_disk(original, original_wave.count, original_wave)
assert(prs.save_libraries() and prs.save_database_now() and prs.save_config())
local protected = {}
for _, path in ipairs({ resource .. "/Scripts/PsyReaSFX/index_v3.tsv", resource .. "/Scripts/PsyReaSFX/libraries_v2.tsv",
  resource .. "/Scripts/PsyReaSFX/config.tsv", prs.wave_cache_path(original, original_wave.count) }) do protected[path] = read(path) end
mkdir(resource .. "/Scripts/ReaSFX_Browser")
write(resource .. "/Scripts/ReaSFX_Browser/config.tsv", "root\t" .. fixture .. "/owned\n")

local opened = prs.SoundminerCatalog.open(params)
assert(opened.started and opened.isolated and not opened.reused and #prs.runtime.assets == 1)
local sm = launch()
assert(sm.PsyReaSFXScope.kind == "soundminer" and sm.PsyReaSFXScope.id == opened.id)
assert(#sm.runtime.assets == 0 and #sm.runtime.root_records == 0, "no original or legacy data inherited")
assert(not sm.runtime.watch_enabled and not sm.runtime.resume_scan_on_start, "isolated automatic scans disabled")
sm.runtime.persistence_read_only = true
assert(not pcall(sm.SoundminerImport.start, params)); sm.runtime.persistence_read_only = false
local exclusive = assert(sm.Jobs.begin("integration_lock", "catalog_exclusive", false))
assert(not pcall(sm.SoundminerImport.start, params)); sm.Jobs.finish(exclusive, true)
local function manifest(env)
  return env.neural_json_decode(read(env.PsyReaSFXScope.rootDirectory .. "/catalog.json"))
end
-- Reproduce a Beta 6 registration whose worker never committed an index.
local interrupted = manifest(sm)
interrupted.importState, interrupted.consumed = nil, true
write(sm.PsyReaSFXScope.rootDirectory .. "/catalog.json", sm.neural_json_encode(interrupted))
assert(os.rename(sm.PsyReaSFXScope.rootDirectory .. "/catalog.json", sm.PsyReaSFXScope.rootDirectory .. "/catalog.json.bak"))
sm.SoundminerCatalog.process_pending()
assert(sm.runtime.import_session and not manifest(sm).consumed)
assert(coroutine.resume(sm.runtime.import_session.worker))
sm.SoundminerImport.cancel(sm.runtime.import_session, true)
assert(manifest(sm).importState == "pending")
sm.webview_close()
prs.SoundminerCatalog.activate(opened.id)
sm = launch()
sm.SoundminerCatalog.process_pending()
-- The direct-search hit is a duplicate whose source row comes later. Walking
-- the source must restore the first row's metadata and retain newer edits.
local live = sm.runtime.import_session
local media_stat, media_checks = sm.SoundminerPaths.stat, 0
sm.SoundminerPaths.stat = function(path, directory)
  if path:lower():match("%.wav$") then
    assert(live.phase == "soundminer_verify_media" and #sm.runtime.assets == 6, "every metadata row precedes disk verification")
    media_checks = media_checks + 1
  end
  return media_stat(path, directory)
end
local hit = assert(live.database:get("justinmetadata", 7))
local lookups = 0
live.database.native = true
live.database.search_rowids = function(_, query, limit)
  lookups = lookups + 1
  assert(query == "impact" and limit == 32)
  return { 7 }
end
sm.runtime.view, sm.runtime.search = "all", "impact"
sm.SoundminerCatalog.process_search(live)
sm.SoundminerCatalog.process_search(live)
assert(lookups == 1, "one indexed lookup per query")
assert(not sm.SoundminerImport.prioritize_row(live, hit))
sm.runtime.search = ""
sm.SoundminerCatalog.process_search(live)
live.database.native, live.database.search_rowids = nil, nil
local searched = asset(sm, "FX/impact.wav")
assert(searched.description == "duplicate must not overwrite")
searched.keywords = "edited after direct search"
local original_size = sm.file_size
sm.file_size = function() error("first visible Soundminer row opened audio for its waveform") end
local early_points = 113
sm.queue_wave(searched, early_points, true, false, false, true)
local early_key = sm.wave_cache_key(searched, early_points)
for _ = 1, 100 do
  if sm.runtime.wave_cache[early_key] then break end
  assert(sm.process_wave_cache_queue())
end
assert(sm.runtime.wave_cache[early_key] and live.done == 0, "direct-search waveform before sequential import")
sm.file_size = original_size
while sm.runtime.import_session do sm.process_import_session() end
sm.SoundminerPaths.stat = media_stat
assert(media_checks == 6 and live.pending_count == 0, "one media check per unique source, including direct hits")
assert(sm.runtime.database_snapshot_session and not manifest(sm).consumed, "queued index is not durable")
drain_save(sm)
assert(manifest(sm).importState == "complete" and manifest(sm).consumed)
local report = sm.runtime.soundminer_report
assert(report.error == "", report.error)
assert(report.added == 6 and report.duplicates == 1 and report.skipped == 2 and report.offline == 1, sm.neural_json_encode(report))
assert(#sm.runtime.libraries == 1 and #sm.runtime.root_records == 1)
assert(key(sm.runtime.root_records[1].path) == key(fixture .. "/audio"))
local first = asset(sm, "FX/impact.wav")
assert(first.description == "中文描述\nsecond line" and first.notes == "note\ncomment")
assert(first.keywords == "edited after direct search" and not first.soundminer_metadata:find("__prs_pending_rowid", 1, true))
assert(first.duration == 1536 / 48000 and first.sample_rate == 48000 and first.channels == 1)
assert(first.catid == "IMPTMetl" and first.ucs_source == "soundminer")
local metadata = sm.neural_json_decode(first.soundminer_metadata)
assert(metadata.CustomField == "keep me\t特殊" and metadata.Rating == 4 and metadata.Library == "Synthetic Library")
assert(asset(sm, "FX/offline.wav").last_seen == 0 and asset(sm, "FX/offline.wav").ready)
assert(asset(sm, "FX/fallback.wav").indexed and asset(sm, "FX/no-frames.wav").duration > 0)
-- Metadata import does not touch waveform payloads or write offscreen caches.
local mini = sm.runtime.mini_wave_points
for _, item in ipairs(sm.runtime.assets) do
  assert(not sm.wave_cache_file_exists(item, mini) and not sm.wave_cache_file_exists(item, 4096, true))
end
local function requested_wave(item, points, preserve)
  sm.queue_wave(item, points, true, preserve, false, true)
  local wave_key = sm.wave_cache_key(item, points, preserve)
  for _ = 1, 100 do
    local ready = sm.runtime.wave_cache[wave_key]
    if ready then return ready.waveform end
    if not sm.process_wave_cache_queue() then break end
  end
end
-- A Beta 7 persisted metadata row has no underscored hash/link/duration.
metadata._FilePathHash, metadata._WaveformLink, metadata._Time = nil, nil, nil
first.soundminer_metadata = sm.neural_json_encode(metadata)
local thumbnail = assert(requested_wave(first, mini, false))
assert(thumbnail.count == sm.runtime.mini_wave_points and thumbnail.peaks[1] > 0.5)
assert(sm.wave_cache_file_exists(first, mini) and not sm.wave_cache_file_exists(first, 4096, true))
assert(requested_wave(first, 4096, true).channels == 1 and not sm.wave_cache_file_exists(first, 2048, false))
assert(requested_wave(asset(sm, "FX/local.wav"), mini, false), "local waveform by rowid")
assert(requested_wave(asset(sm, "FX/no-frames.wav"), mini, false), "duration-derived overview")
assert(requested_wave(asset(sm, "FX/offline.wav"), mini, false), "cached offline overview")
local audio_only = asset(sm, "Music/tone.wav")
assert(not requested_wave(audio_only, mini, false), "unknown overview falls back to audio")
local audio_job = assert(sm.runtime.wave_queue[1])
local result, from_audio
for _ = 1, 100 do
  result, from_audio = sm.step_wave_job(audio_job)
  if result ~= "working" then break end
  sm.SoundminerMedia.process()
end
assert(result == "done" and from_audio.count == mini, "normal protected audio fallback")
sm.runtime.wave_queued[audio_job.key] = nil
table.remove(sm.runtime.wave_queue, 1)
assert(key(sm.wave_cache_path(first, thumbnail.count)) ~= key(prs.wave_cache_path(original, original_wave.count)), "cache namespaces")
assert(original.description == "PRS-owned description" and original.duration == 9 and #prs.runtime.assets == 1)
sm.set_watch_folder_enabled(true)
assert(not sm.runtime.watch_enabled, "watch setter cannot enable directory discovery in an isolated catalog")
sm.runtime.watch_enabled, sm.runtime.next_watch = true, 0
sm.watch_folders()
assert(not sm.runtime.scan and not sm.runtime.by_path[sm.path_key(fixture .. "/audio/FX/not-in-soundminer.wav")],
  "neighboring audio absent from Soundminer never enters automatically")
sm.runtime.watch_enabled = false

local commands_before = command_count
assert(prs.SoundminerCatalog.open(params).reused)
assert(prs.SoundminerCatalog.activate(opened.id).reused and sm.SoundminerCatalog.activate("prs").reused)
assert(command_count == commands_before and focus_count >= 3, "existing windows focus without executing runtime action")
local catalog_list = sm.SoundminerCatalog.list()
assert(catalog_list.current == opened.id and #catalog_list.catalogs == 2 and catalog_list.catalogs[1].id == "prs")
assert(sm.WebUI.handlers["session.ready"]().catalogScope.id == opened.id)
assert(not pcall(sm.SoundminerImport.start, { path = fixture .. "/Second.sqlite", waveforms = false }), "source identity enforced")

-- Hash collisions must not overwrite manifests or reroute an existing catalog.
local manifest_path = sm.PsyReaSFXScope.rootDirectory .. "/catalog.json"
local manifest_before = read(manifest_path)
local original_hash = prs.fnv1a
prs.fnv1a = function(value) return value:sub(1, 8) == "catalog|" and opened.id:sub(4, 11) or opened.id:sub(12, 19) end
assert(not pcall(prs.SoundminerCatalog.open, { path = fixture .. "/cancel.sqlite", waveforms = false }))
prs.fnv1a = original_hash
assert(read(manifest_path) == manifest_before and command_count == commands_before)
-- Correcting cache options updates only non-identity manifest fields and reuses
-- the active window. Its explicit resume reads the updated options.
local corrected = { path = db_path, oldPrefix = params.oldPrefix, newPrefix = params.newPrefix, cachePath = cache_path, waveforms = false }
assert(prs.SoundminerCatalog.open(corrected).reused)
local changed_manifest = prs.neural_json_decode(read(manifest_path))
assert(changed_manifest.params.cachePath == cache_path and changed_manifest.params.waveforms == false)
assert(changed_manifest.identity == sm.PsyReaSFXScope.identity)
assert(sm.SoundminerCatalog.resume().started and sm.runtime.import_session.import_waveforms == false)
local repeat_report = finish(sm)
assert(repeat_report.added == 0 and repeat_report.duplicates == 7 and #sm.runtime.assets == 6)

local second_params = { path = fixture .. "/Second.sqlite", oldPrefix = params.oldPrefix, newPrefix = params.newPrefix, cachePath = cache_path }
local second_opened = prs.SoundminerCatalog.open(second_params)
local second = launch()
second.SoundminerCatalog.process_pending()
local snapshot_token = second.runtime.import_session.job_token
while second.runtime.import_session do second.process_import_session() end
assert(second.runtime.database_snapshot_session and not manifest(second).consumed)
second.runtime.persistence_fault_injection = "after_close"
drain_save(second)
assert(second.runtime.soundminer_report.error ~= "" and snapshot_token.state == "failed" and not manifest(second).consumed)
second.runtime.persistence_fault_injection = nil
second.webview_close(); prs.SoundminerCatalog.activate(second_opened.id); second = launch()
assert(finish(second).added == 1 and manifest(second).consumed)
local second_asset = asset(second, "FX/impact.wav")
assert(second_opened.id ~= opened.id and second_asset.description == "Second isolated library")
assert(key(second.wave_cache_path(second_asset, thumbnail.count)) ~= key(sm.wave_cache_path(first, thumbnail.count)))
assert(first.description == "中文描述\nsecond line" and original.description == "PRS-owned description")

-- Reopening a consumed scope loads only its saved index and does not re-import.
sm.runtime.watch_enabled, sm.runtime.resume_scan_on_start = true, true
assert(sm.save_config())
sm.write_scan_checkpoint({ reason = "Synthetic interrupted scan", roots = { fixture .. "/audio" } }, "scan")
sm.webview_close()
assert(not prs.SoundminerCatalog.activate(opened.id).reused)
sm = launch(); first = asset(sm, "FX/impact.wav")
sm.SoundminerCatalog.process_pending()
assert(#sm.runtime.assets == 6 and not sm.runtime.import_session and not sm.runtime.soundminer_report)
assert(not sm.runtime.watch_enabled and not sm.runtime.resume_scan_on_start and not sm.runtime.scan and not sm.runtime.import_recovery_audit,
  "reopen ignores automatic watch/recovery even if previous settings/checkpoint requested them")
assert(sm.neural_json_decode(first.soundminer_metadata).CustomField == "keep me\t特殊")
assert(asset(sm, "FX/offline.wav").last_seen == 0)
sm.start_scan("Soundminer offline retention test", { fixture .. "/audio" })
for _ = 1, 10000 do
  if sm.SoundminerMedia then sm.SoundminerMedia.process() end
  if sm.runtime.scan then sm.process_scan()
  elseif sm.runtime.import_session then sm.process_import_session()
  else break end
end
assert(not sm.runtime.scan and not sm.runtime.import_session)
drain_save(sm)
assert(asset(sm, "FX/offline.wav").last_seen == 0 and #sm.runtime.assets == 7,
  "only an explicit manual scan may add neighboring audio, retaining imported offline entries")

local cancel_params = { path = fixture .. "/cancel.sqlite", oldPrefix = "/Volumes/Cancel", newPrefix = fixture .. "/cancel", waveforms = false }
prs.SoundminerCatalog.open(cancel_params)
local cancel = launch(); cancel.SoundminerCatalog.process_pending()
cancel.cancel_import_session()
assert(cancel.runtime.soundminer_report.canceled and #cancel.runtime.assets == 0)
assert(manifest(cancel).importState == "canceled")
cancel.webview_close(); prs.SoundminerCatalog.activate(cancel.PsyReaSFXScope.id); cancel = launch()
cancel.SoundminerCatalog.process_pending()
assert(not cancel.runtime.import_session, "explicit cancellation survives reopening")
assert(cancel.SoundminerCatalog.resume().started)
local cancel_session = cancel.runtime.import_session
for _ = 1, 1000 do
  if cancel_session.added > 0 then break end
  assert(coroutine.resume(cancel_session.worker))
end
assert(cancel_session.added > 0 and cancel_session.added < 80)
assert(cancel_session.phase == "soundminer_import" and cancel_session.total == 0 and cancel.runtime.assets[1].last_seen == -1)
cancel.cancel_import_session(); drain_save(cancel)
assert(cancel.runtime.soundminer_report.canceled and #cancel.runtime.assets == cancel_session.added)
assert(cancel.runtime.soundminer_report.unchecked == cancel_session.added and cancel.runtime.soundminer_report.offline == 0)
assert(not cancel_session.database and not cancel.Jobs.active.catalog_pipeline)
local saved_database = cancel.PsyReaSFXScope.dataDirectory .. "/index_v3.tsv"
local saved_libraries = cancel.PsyReaSFXScope.dataDirectory .. "/libraries_v2.tsv"
local previous_database, previous_libraries = read(saved_database), read(saved_libraries)
cancel.webview_close(); prs.SoundminerCatalog.activate(cancel.PsyReaSFXScope.id); cancel = launch()
assert(cancel.runtime.assets[1].last_seen == -1, "unverified rows survive a close and reopen")
assert(cancel.SoundminerCatalog.resume().started)
local failed_token = cancel.runtime.import_session.job_token
cancel.runtime.persistence_fault_injection = "write"
local failed_save = finish(cancel)
cancel.runtime.persistence_fault_injection = nil
assert(failed_save.added > 0 and failed_save.error:find("保存失败", 1, true), cancel.neural_json_encode(failed_save))
assert(failed_save.offline == 80 and failed_save.unchecked == 0, "resumed media checks include previously saved rows")
assert(failed_token.state == "failed" and cancel.runtime.db_dirty)
assert(read(saved_database) == previous_database and read(saved_libraries) == previous_libraries)
assert(not manifest(cancel).consumed, "failed save remains resumable")
assert(cancel.save_libraries() and cancel.save_database_now() and #cancel.runtime.assets == 80)

local empty_opened = prs.SoundminerCatalog.open({ path = fixture .. "/empty.sqlite", waveforms = false })
local empty = launch()
assert(finish(empty).added == 0 and manifest(empty).importState == "complete")
empty.webview_close(); prs.SoundminerCatalog.activate(empty_opened.id); empty = launch()
empty.SoundminerCatalog.process_pending(); assert(not empty.runtime.import_session, "a completed empty source stays empty")

-- A reader temporarily prevents Windows from renaming the existing settings.
-- The deferred retry must retain changes made during the wait.
assert(empty.save_config())
local config = empty.PsyReaSFXScope.dataDirectory .. "/config.tsv"
local original_settings, rename = read(config), os.rename
local locked = true
os.rename = function(a, b)
  if locked and key(a) == key(config) then return nil, "locked by fixture", 13 end
  return rename(a, b)
end
empty.runtime.config_dirty = true
assert(empty.start_config_save()); empty.process_config_save()
assert(empty.runtime.config_save_retry and empty.runtime.config_dirty and read(config) == original_settings)
assert(not empty.runtime.status_error, "temporary lock must not raise a toast")
empty.runtime.favorites[key(config)] = true
locked = false
empty.runtime.config_save_retry.at = 0
empty.process_config_save(); empty.process_config_save()
assert(not empty.runtime.config_dirty and not empty.runtime.config_save_retry)
assert(read(config):find(key(config), 1, true), "retry includes recent changes")
locked = true
empty.runtime.config_dirty, empty.runtime.language = true, "en"
for _ = 1, 4 do
  if empty.runtime.config_save_retry then empty.runtime.config_save_retry.at = 0 end
  assert(empty.start_config_save()); empty.process_config_save()
end
assert(empty.runtime.config_dirty and empty.runtime.status_error and not empty.runtime.config_save_retry)
assert(empty.runtime.status:find("Unable to save configuration", 1, true) and empty.runtime.status:find("locked by fixture", 1, true))
os.rename = rename

prs.SoundminerCatalog.open({ path = fixture .. "/changing.sqlite", waveforms = false })
local changing = launch(); changing.SoundminerCatalog.process_pending()
assert(coroutine.resume(changing.runtime.import_session.worker))
if arg[4] == "concurrent-writer" then
  io.stdout:write("CONCURRENT_IMPORT_READY\n"); io.stdout:flush()
  assert(io.stdin:read("*l") == "writer-started")
else
  local mutation = assert(io.open(fixture .. "/changing.sqlite", "r+b"))
  mutation:seek("set", 60); local old = assert(mutation:read(4)); mutation:seek("set", 60)
  mutation:write(string.char(old:byte(1) ~ 1) .. old:sub(2)); mutation:close()
end
local changed_report = finish(changing)
assert(changed_report.error ~= "" and changed_report.added == 0 and #changing.runtime.root_records == 0)

assert(not pcall(prs.SoundminerCatalog.open, { path = db_path, oldPrefix = params.oldPrefix, newPrefix = "C:/target/../outside" }))
assert(sm.SoundminerImport.resolve_path({ FilePath = "X:/FX/a.wav" }, "X:/", "Y:/") == "Y:/FX/a.wav")
assert(sm.SoundminerImport.resolve_path({ FilePath = "x:/FX/a.wav" }, "X:/fx", "Y:/Moved") == "Y:/Moved/a.wav")
assert(sm.SoundminerImport.resolve_path({ FilePath = "/Volumes/Audio/a.wav" }, "/Volumes/audio", "/new") == "/Volumes/Audio/a.wav")
assert(not sm.SoundminerImport.resolve_path({ FilePath = "X:/FX/a.wav" }, "X:/", "Y:/../outside"))
assert(loadfile("tools/lua_soundminer_paths_selftest.lua"))()(prs, fixture, launch, finish, key, read, write, mkdir)
for path, bytes in pairs(protected) do assert(read(path) == bytes, "original PRS data/cache changed: " .. path) end
assert(original.description == "PRS-owned description" and prs.runtime.favorites[prs.path_key(original.path)] and #prs.runtime.assets == 1)
assert(read(db_path) == database_before and read(cache_path) == cache_before, "source SQLite/cache unchanged")
io.open, os.remove, os.rename = native_open, native_remove, native_rename
print("Soundminer integration: PASS (separate runtimes/data/cache/legacy/focus/identity/options/metadata/waves/offline/resume/mutation/persistence/failure)")
