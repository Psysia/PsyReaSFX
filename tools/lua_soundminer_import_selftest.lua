-- Integration test of generated production runtime. All writes stay in a
-- synthetic fixture, and REAPER audio/device/window APIs are mocked only.
local entry = assert(arg[1], "generated WebView runtime required")
local fixture = assert(arg[2], "fresh synthetic fixture directory required"):gsub("\\", "/"):gsub("/+$", "")
assert(fixture:match("^%a:/") or fixture:sub(1, 1) == "/", "fixture path must be absolute")
local resource = fixture .. "/runtime"
local deferred, extstate = nil, {}
local native_open, native_remove, native_rename = io.open, os.remove, os.rename
local function key(path) return tostring(path):gsub("\\", "/"):gsub("/+$", ""):lower() end
local function writable(path)
  assert(key(path):sub(1, #key(fixture) + 1) == key(fixture) .. "/", "write outside fixture: " .. tostring(path))
end
io.open = function(path, mode)
  if mode and (mode:find("[wa+]") ~= nil) then writable(path) end
  return native_open(path, mode)
end
os.remove = function(path) writable(path); return native_remove(path) end
os.rename = function(from, to)
  -- Production's same-path rename probes directories; it does not move files.
  if key(from) ~= key(to) then writable(from); writable(to) end
  return native_rename(from, to)
end
local function read(path)
  local file = assert(io.open(path, "rb"))
  local bytes = file:read("*a"); file:close(); return bytes
end
-- Accept the tracked standalone Lua file as CI input. The production launcher
-- expects its pinned runtime lock beside it, so create a complete isolated pair.
local source = read(entry)
local lock_path = arg[3] or "dependencies/reawebapi/windows-x64.lock.json"
for name, bytes in pairs({ ["PsyReaSFX_Runtime.lua"] = source, ["runtime-lock.json"] = read(lock_path) }) do
  local output = assert(io.open(resource .. "/" .. name, "wb"))
  assert(output:write(bytes)); assert(output:close())
end
entry = resource .. "/PsyReaSFX_Runtime.lua"
local inventory
reaper = {
  GetResourcePath = function() return resource end,
  GetOS = function() return "Win64" end,
  time_precise = os.clock,
  GetPlayState = function() return 0 end,
  GetPlayStateEx = function() return 0 end,
  file_exists = function(path)
    local file = io.open(path, "rb"); if not file then return false end
    file:close(); return true
  end,
  RecursiveCreateDirectory = function(path)
    writable(path)
    -- Python pre-creates runtime directories; no shell commands are necessary.
    local ok, _, code = native_rename(path .. "/", path .. "/")
    assert(ok or code == 13, "missing prepared directory: " .. path)
    return 1
  end,
  EnumerateFiles = function(path, index)
    local folder = inventory and inventory[key(path)]
    return folder and folder.files[index + 1]
  end,
  EnumerateSubdirectories = function(path, index)
    local folder = inventory and inventory[key(path)]
    return folder and folder.directories[index + 1]
  end,
  EnumProjects = function() return nil, "" end,
  GetExtState = function(section, name) return extstate[section .. name] or "" end,
  SetExtState = function(section, name, value) extstate[section .. name] = value end,
  DeleteExtState = function(section, name) extstate[section .. name] = nil end,
  ReaWeb_Open = function() return 77 end,
  ReaWeb_IsOpen = function() return true end,
  ReaWeb_IsReady = function() return true end,
  ReaWeb_Send = function() return true end,
  ReaWeb_Receive = function() return "" end,
  ReaWeb_Close = function() end,
  defer = function(callback) deferred = callback end,
  atexit = function() end,
  MB = function(message) error(message) end,
}
assert(loadfile(entry))()
inventory = neural_json_decode(read(fixture .. "/inventory.json"))
local runtime = assert(AppState.raw)
runtime.auto_backup, runtime.watch_enabled = false, false
for _ = 1, 100 do
  if not runtime.startup_session then break end
  assert(not runtime.startup_session.failure, runtime.startup_session.failure)
  process_startup()
end
assert(not runtime.startup_session and deferred, "runtime startup")
can_run_heavy_job = function() return true end

local db_path = fixture .. "/SoundminerV7/Databases/Synthetic.sqlite"
local cache_path = fixture .. "/SoundminerV7/Caches/waveforms.sqlite"
local database_before, cache_before = read(db_path), read(cache_path)
local inspected = SoundminerImport.inspect(db_path)
assert(#inspected.samples == 3 and key(inspected.cachePath) == key(cache_path))
assert(not pcall(SoundminerImport.inspect, fixture .. "/unsupported.sqlite"))
assert(not pcall(SoundminerImport.inspect, fixture .. "/wal.sqlite"))
assert(#runtime.assets == 0 and #runtime.root_records == 0, "inspection is read only")
runtime.persistence_read_only = true
assert(not pcall(SoundminerImport.start, { path = db_path, waveforms = false }))
runtime.persistence_read_only = false
local exclusive = assert(Jobs.begin("integration_lock", "catalog_exclusive", false))
assert(not pcall(SoundminerImport.start, { path = db_path, waveforms = false }))
assert(not runtime.import_session and #runtime.assets == 0, "exclusive job rejection is non-mutating")
Jobs.finish(exclusive, true)

local function drain_save()
  for _ = 1, 1000 do
    if not runtime.database_snapshot_session then return end
    process_database_snapshot()
  end
  error("save did not finish")
end
local function finish()
  for _ = 1, 10000 do
    if not runtime.import_session then drain_save(); return assert(runtime.soundminer_report) end
    process_import_session()
  end
  error("import did not finish")
end
local params = { path = db_path, oldPrefix = "/Volumes/SM-Audio", newPrefix = fixture .. "/audio" }
assert(SoundminerImport.start(params).started)
local report = finish()
assert(report.error == "", report.error)
assert(report.added == 6 and report.duplicates == 1 and report.skipped == 2 and report.offline == 1,
  neural_json_encode(report))
assert(report.waveforms == 5 and report.waveSkipped == 1, neural_json_encode(report))
assert(#runtime.libraries == 1 and #runtime.root_records == 1, "common source root across subfolders")
assert(key(runtime.root_records[1].path) == key(fixture .. "/audio"))
local function asset(relative) return assert(runtime.by_path[path_key(fixture .. "/audio/" .. relative)]) end
local first = asset("FX/impact.wav")
assert(first.description == "中文描述\nsecond line" and first.notes == "note\ncomment")
assert(first.duration == 1536 / 48000 and first.sample_rate == 48000 and first.channels == 1)
assert(first.catid == "IMPTMetl" and first.ucs_source == "soundminer")
local metadata = neural_json_decode(first.soundminer_metadata)
assert(metadata.CustomField == "keep me\t特殊" and metadata.Rating == 4 and metadata.Library == "Synthetic Library")
assert(asset("FX/offline.wav").last_seen == 0 and asset("FX/offline.wav").ready)
assert(asset("FX/fallback.wav").indexed and asset("FX/no-frames.wav").duration > 0)
local thumbnail = assert(load_wave_from_disk(first, runtime.mini_wave_points))
assert(thumbnail.count == runtime.mini_wave_points and thumbnail.peaks[1] > 0.5)
assert(load_wave_from_disk(first, 4096, true).channels == 1, "converted channel detail cache")
assert(wave_cache_file_exists(asset("FX/local.wav"), runtime.mini_wave_points), "in-database waveform link")
assert(wave_cache_file_exists(asset("FX/no-frames.wav"), runtime.mini_wave_points), "duration fallback for absent TotalFrames")

first.description = "user edit survives repeated import"
first.notes = "user note"
mark_asset_database_change(first)
assert(SoundminerImport.start(params).started)
local repeated = finish()
assert(repeated.added == 0 and repeated.duplicates == 7 and #runtime.assets == 6)
assert(first.description == "user edit survives repeated import" and first.notes == "user note")
-- A cache from an older Soundminer snapshot must not be attached to an asset
-- whose currently indexed duration/sample rate/channel metadata has changed.
local original_duration = first.duration
first.duration = original_duration + 1
assert(os.remove(wave_cache_path(first, runtime.mini_wave_points)))
assert(SoundminerImport.start(params).started)
local stale_cache = finish()
assert(stale_cache.added == 0 and stale_cache.waveSkipped >= 2)
assert(not wave_cache_file_exists(first, runtime.mini_wave_points), "mismatched overview cannot be reused")
assert(first.duration == original_duration + 1, "repeat import preserves rescanned asset metadata")
first.duration = original_duration
assert(SoundminerImport.start(params).started)
finish()
assert(wave_cache_file_exists(first, runtime.mini_wave_points), "matching cache remains reusable")
assert(read(db_path) == database_before and read(cache_path) == cache_before, "source database/cache bytes never changed")

-- Source mutation during the inspection pass must not add assets or roots.
local before_count, before_roots = #runtime.assets, #runtime.root_records
assert(SoundminerImport.start({ path = fixture .. "/changing.sqlite", waveforms = false }).started)
local changing = runtime.import_session
assert(coroutine.resume(changing.worker))
local mutation = assert(io.open(fixture .. "/changing.sqlite", "r+b"))
mutation:seek("set", 60)
local old = assert(mutation:read(4)); mutation:seek("set", 60)
mutation:write(string.char(old:byte(1) ~ 1) .. old:sub(2)); mutation:close()
local changed_report = finish()
assert(changed_report.error ~= "" and changed_report.added == 0)
assert(#runtime.assets == before_count and #runtime.root_records == before_roots)

-- Cancel before mutation, then cancel after a bounded number of inserted rows.
local cancel_params = { path = fixture .. "/cancel.sqlite", oldPrefix = "/Volumes/Cancel", newPrefix = fixture .. "/cancel", waveforms = false }
assert(SoundminerImport.start(cancel_params).started)
cancel_import_session()
assert(runtime.soundminer_report.canceled and #runtime.assets == before_count)
assert(SoundminerImport.start(cancel_params).started)
local cancel_session = runtime.import_session
for _ = 1, 1000 do
  if cancel_session.added > 0 then break end
  assert(coroutine.resume(cancel_session.worker))
end
assert(cancel_session.added > 0 and cancel_session.added < 80)
cancel_import_session(); drain_save()
assert(runtime.soundminer_report.canceled and #runtime.assets == before_count + cancel_session.added)
assert(not cancel_session.database and not Jobs.active.catalog_pipeline, "cancel closes reader and releases job")

-- Reuse existing source ownership instead of introducing overlapping roots.
local owner = create_library("Existing owner", "test-existing-owner")
assert(add_root_to_library(owner.id, fixture .. "/owned", false))
assert(SoundminerImport.start({ path = fixture .. "/owned.sqlite", waveforms = false }).started)
local owned = finish()
assert(owned.added == 1)
assert(runtime.by_path[path_key(fixture .. "/owned/new.wav")].library_id == owner.id)

-- Reject unsafe mapping, and accept a drive root mapping as a whole prefix.
assert(not pcall(SoundminerImport.start, { path = db_path, oldPrefix = "/Volumes/SM-Audio", newPrefix = "C:/target/../outside" }))
assert(SoundminerImport.resolve_path({ FilePath = "X:/FX/a.wav" }, "X:/", "Y:/") == "Y:/FX/a.wav")
assert(SoundminerImport.resolve_path({ FilePath = "x:/FX/a.wav" }, "X:/fx", "Y:/Moved") == "Y:/Moved/a.wav")
assert(SoundminerImport.resolve_path({ FilePath = "/Volumes/Audio/a.wav" }, "/Volumes/audio", "/new") == "/Volumes/Audio/a.wav",
  "POSIX prefix comparisons retain case")
assert(not SoundminerImport.resolve_path({ FilePath = "X:/FX/a.wav" }, "X:/", "Y:/../outside"))

-- Persist through the real snapshot writer and loader, including retained raw metadata.
local expected_count, expected_id = #runtime.assets, first.asset_id
drain_save()
assert(save_database_now())
assert(save_libraries())
runtime.assets, runtime.by_path, runtime.database_ordered_assets = {}, {}, nil
load_or_migrate_libraries()
load_database()
assert(not runtime.persistence_read_only and #runtime.assets == expected_count)
first = asset("FX/impact.wav")
assert(first.asset_id == expected_id and first.description == "user edit survives repeated import")
assert(neural_json_decode(first.soundminer_metadata).CustomField == "keep me\t特殊")
assert(asset("FX/offline.wav").last_seen == 0)
-- A manual scan of the available parent must retain imported never-seen files
-- alongside online files, so the user can relink the offline entries later.
start_scan("Soundminer offline retention test", { fixture .. "/audio" })
assert(runtime.scan)
for _ = 1, 10000 do
  if runtime.scan then process_scan()
  elseif runtime.import_session then process_import_session()
  else break end
end
assert(not runtime.scan and not runtime.import_session, "manual scan finishes")
drain_save()
assert(asset("FX/offline.wav").last_seen == 0 and #runtime.assets == expected_count,
  "manual source scan retains never-seen imported assets")
-- A real atomic-writer failure must keep the previous on-disk generation and
-- report failure, while retaining the newly imported assets in memory for retry.
local saved_database = resource .. "/Scripts/PsyReaSFX/index_v3.tsv"
local saved_libraries = resource .. "/Scripts/PsyReaSFX/libraries_v2.tsv"
local previous_database, previous_libraries = read(saved_database), read(saved_libraries)
runtime.persistence_fault_injection = "write"
assert(SoundminerImport.start(cancel_params).started)
local failed_save_token = runtime.import_session.job_token
local failed_save = finish()
runtime.persistence_fault_injection = nil
assert(failed_save.added > 0 and failed_save.error:find("保存失败", 1, true), neural_json_encode(failed_save))
assert(failed_save_token.state == "failed" and runtime.db_dirty, "failed save stays dirty and visible")
assert(read(saved_database) == previous_database and read(saved_libraries) == previous_libraries,
  "failed import save cannot replace the previous generation")
assert(save_libraries() and save_database_now(), "pending import can be saved after the fault clears")
assert(read(db_path) == database_before and read(cache_path) == cache_before)
io.open, os.remove, os.rename = native_open, native_remove, native_rename
print("Soundminer import integration: PASS (production runtime, metadata/waves/mapping/offline/dedup/cancel/mutation/persistence/failure)")
