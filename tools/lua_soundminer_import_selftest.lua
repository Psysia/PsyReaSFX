-- Run the actual generated runtime in independent Lua environments, as separate
-- REAPER ReaScripts do. Only host/device/window APIs are mocked. All writes are
-- restricted to the generated fixture; original PRS files are byte-compared.
local entry = assert(arg[1], "generated WebView runtime required")
local fixture = assert(arg[2], "fresh synthetic fixture directory required"):gsub("\\", "/"):gsub("/+$", "")
assert(fixture:match("^%a:/") or fixture:sub(1, 1) == "/", "fixture path must be absolute")
local resource = fixture .. "/runtime"
local native_open, native_remove, native_rename = io.open, os.remove, os.rename
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
  env.loadfile = function(file, mode) return loadfile(file, mode or "t", env) end
  local deferred
  env.reaper = {
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
local report = finish(sm)
assert(report.error == "", report.error)
assert(report.added == 6 and report.duplicates == 1 and report.skipped == 2 and report.offline == 1, sm.neural_json_encode(report))
assert(report.waveforms == 5 and report.waveSkipped == 1, sm.neural_json_encode(report))
assert(#sm.runtime.libraries == 1 and #sm.runtime.root_records == 1)
assert(key(sm.runtime.root_records[1].path) == key(fixture .. "/audio"))
local first = asset(sm, "FX/impact.wav")
assert(first.description == "中文描述\nsecond line" and first.notes == "note\ncomment")
assert(first.duration == 1536 / 48000 and first.sample_rate == 48000 and first.channels == 1)
assert(first.catid == "IMPTMetl" and first.ucs_source == "soundminer")
local metadata = sm.neural_json_decode(first.soundminer_metadata)
assert(metadata.CustomField == "keep me\t特殊" and metadata.Rating == 4 and metadata.Library == "Synthetic Library")
assert(asset(sm, "FX/offline.wav").last_seen == 0 and asset(sm, "FX/offline.wav").ready)
assert(asset(sm, "FX/fallback.wav").indexed and asset(sm, "FX/no-frames.wav").duration > 0)
local thumbnail = assert(sm.load_wave_from_disk(first, sm.runtime.mini_wave_points))
assert(thumbnail.count == sm.runtime.mini_wave_points and thumbnail.peaks[1] > 0.5)
assert(sm.load_wave_from_disk(first, 4096, true).channels == 1)
assert(sm.wave_cache_file_exists(asset(sm, "FX/local.wav"), sm.runtime.mini_wave_points))
assert(sm.wave_cache_file_exists(asset(sm, "FX/no-frames.wav"), sm.runtime.mini_wave_points))
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
local second = launch(); assert(finish(second).added == 1)
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
assert(cancel.SoundminerCatalog.resume().started)
local cancel_session = cancel.runtime.import_session
for _ = 1, 1000 do
  if cancel_session.added > 0 then break end
  assert(coroutine.resume(cancel_session.worker))
end
assert(cancel_session.added > 0 and cancel_session.added < 80)
cancel.cancel_import_session(); drain_save(cancel)
assert(cancel.runtime.soundminer_report.canceled and #cancel.runtime.assets == cancel_session.added)
assert(not cancel_session.database and not cancel.Jobs.active.catalog_pipeline)
local saved_database = cancel.PsyReaSFXScope.dataDirectory .. "/index_v3.tsv"
local saved_libraries = cancel.PsyReaSFXScope.dataDirectory .. "/libraries_v2.tsv"
local previous_database, previous_libraries = read(saved_database), read(saved_libraries)
assert(cancel.SoundminerCatalog.resume().started)
local failed_token = cancel.runtime.import_session.job_token
cancel.runtime.persistence_fault_injection = "write"
local failed_save = finish(cancel)
cancel.runtime.persistence_fault_injection = nil
assert(failed_save.added > 0 and failed_save.error:find("保存失败", 1, true), cancel.neural_json_encode(failed_save))
assert(failed_token.state == "failed" and cancel.runtime.db_dirty)
assert(read(saved_database) == previous_database and read(saved_libraries) == previous_libraries)
assert(cancel.save_libraries() and cancel.save_database_now() and #cancel.runtime.assets == 80)

prs.SoundminerCatalog.open({ path = fixture .. "/changing.sqlite", waveforms = false })
local changing = launch(); changing.SoundminerCatalog.process_pending()
assert(coroutine.resume(changing.runtime.import_session.worker))
local mutation = assert(io.open(fixture .. "/changing.sqlite", "r+b"))
mutation:seek("set", 60); local old = assert(mutation:read(4)); mutation:seek("set", 60)
mutation:write(string.char(old:byte(1) ~ 1) .. old:sub(2)); mutation:close()
local changed_report = finish(changing)
assert(changed_report.error ~= "" and changed_report.added == 0 and #changing.runtime.root_records == 0)

assert(not pcall(prs.SoundminerCatalog.open, { path = db_path, oldPrefix = params.oldPrefix, newPrefix = "C:/target/../outside" }))
assert(sm.SoundminerImport.resolve_path({ FilePath = "X:/FX/a.wav" }, "X:/", "Y:/") == "Y:/FX/a.wav")
assert(sm.SoundminerImport.resolve_path({ FilePath = "x:/FX/a.wav" }, "X:/fx", "Y:/Moved") == "Y:/Moved/a.wav")
assert(sm.SoundminerImport.resolve_path({ FilePath = "/Volumes/Audio/a.wav" }, "/Volumes/audio", "/new") == "/Volumes/Audio/a.wav")
assert(not sm.SoundminerImport.resolve_path({ FilePath = "X:/FX/a.wav" }, "X:/", "Y:/../outside"))
for path, bytes in pairs(protected) do assert(read(path) == bytes, "original PRS data/cache changed: " .. path) end
assert(original.description == "PRS-owned description" and prs.runtime.favorites[prs.path_key(original.path)] and #prs.runtime.assets == 1)
assert(read(db_path) == database_before and read(cache_path) == cache_before, "source SQLite/cache unchanged")
io.open, os.remove, os.rename = native_open, native_remove, native_rename
print("Soundminer integration: PASS (separate runtimes/data/cache/legacy/focus/identity/options/metadata/waves/offline/resume/mutation/persistence/failure)")
