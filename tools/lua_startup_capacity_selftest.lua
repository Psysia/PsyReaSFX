-- Read-only startup benchmark. Optional real-data paths are never written.
local core_path = assert(arg[1], "ui-core source required")
local catalog_path = assert(arg[2], "catalog source required")
local runtime_path = assert(arg[3], "runtime source required")
local journal_path = assert(arg[4], "journal module required")
local function read(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  return source
end
local function region(source, first, following)
  local at = assert(source:find(first, 1, true), first)
  local last = assert(source:find(following, at + #first, true), following)
  return source:sub(at, last - 1)
end
local core, catalog, runtime = read(core_path), read(catalog_path), read(runtime_path)
local real_snapshot, real_journal = arg[5], arg[6]
DATABASE_FILE = real_snapshot or "memory-snapshot"
DATABASE_JOURNAL_FILE = real_journal or "memory-journal"
DATABASE_JOURNAL_COMPACT_COUNT = 10000
WORKFLOW_STATUS = { none = true }
local fields = region(catalog, "local DB_FIELDS = {", "function load_or_migrate_libraries()")
fields = fields:match("local DB_FIELDS = (%b{})")
DB_FIELDS = assert(load("return " .. fields))()
AppState = { set = function(key, value) state[key] = value end,
  apply = function(values) for key, value in pairs(values) do state[key] = value end end }
reaper = { time_precise = os.clock, file_exists = function() error("catalog load must not probe audio files") end }
SEP = "\\"
HostApi = reaper
assert(load(region(core, "function normalize_slashes(path)", "function is_audio_file(path)")))()
assert(load(region(core, "function trim(value)", "function rgba_from_hex(hex)")))()
assert(load(region(core, "function safe_lower(value)", "function windows_extended_path(path)")))()
assert(load(region(core, "function stable_id(prefix, seed)", "function unique_library_name(base)")))()
assert(load(region(core, "function invalidate_folder_navigation()", "function new_folder_navigation_node(")))()
assert(load(region(core, "function invalidate_library_counts()", "function refresh_asset_library_binding(asset)")))()
assert(load(region(catalog, "function asset_relative_path(path, root)", "function make_placeholder(path, known_root)")))()
assert(load(region(catalog, "function asset_path_sort_key(asset)", "-- Persistence")))()
assert(loadfile("src/lua/45_duplicate_confirmation.lua"))()
function invalidate_similarity_index() end
function is_persistence_schema_fields(fields) return fields[1] == "psyreasfx_schema" end
function persistence_schema_generation(fields) return tonumber(fields[5]) or 0 end
function set_status(text) state.status = text end
assert(load(region(core, "function unescape_tsv(value)", "function split_words(text)")))()
assert(loadfile(journal_path))()
assert(loadfile("src/lua/37_catalog_caches.lua"))()
local database_start = runtime:find("function startup_checkpoint(phase)", 1, true)
  and "function startup_checkpoint(phase)" or "function load_database()"
assert(load(region(runtime, database_start, "function database_asset_values(asset)")))()
assert(load(region(runtime, "function replace_database_asset(asset, probe_file)", "function write_database_asset_line(file, asset)")))()
assert(load(region(runtime, "function database_asset_values(asset)", "function mark_asset_database_change(asset)")))()
function mark_database_snapshot_dirty() state.db_dirty = true end

-- Match the legacy values decoder byte-for-byte, including old headers,
-- percent escapes, empty/truncated fields, ignored paths and artwork state.
state = {}
for _, headers in ipairs({ DB_FIELDS, { "path", "name", "marked", "duration", "artwork_path" } }) do
  for _, line in ipairs({
    "C:/fixture.wav\tname%09tab%0Aline%25literal\t1\t2.5\tcover.png",
    "C:/fixture.wav\t\ttrue\t\t",
    "C:/fixture.wav", "", "C:/._metadata.wav\tignored",
  }) do
    local expected = database_asset_from_values(headers, split_tsv(line))
    local actual = database_asset_from_line(headers, line)
    assert((expected == nil) == (actual == nil))
    if expected then
      for key, value in pairs(expected) do assert(actual[key] == value, key) end
      for key, value in pairs(actual) do assert(expected[key] == value, key) end
    end
  end
end
for _, path in ipairs({ "C:/__MACOSX/file.wav", "C:/.AppleDouble/file.wav", "C:/ .Trashes /file.wav", "C:/@eaDir/file.wav", "C:/._file.wav" }) do
  assert(is_ignored_media_path(path), "system metadata filtering must remain intact")
end
assert(not is_ignored_media_path("C:/library/normal.wav"))

local function fresh_state()
  return { assets = {}, by_path = {}, favorites = {}, selected_set = {},
    ucs_pending_lookup = {}, ucs_pending_count = 0,
    folder_navigation_trees = {}, folder_navigation_revision = 0,
    folder_navigation_built_revision = -1, database_changes = new_asset_change_set() }
end
local function duplicate_rows(insert)
  state = fresh_state()
  for _, line in ipairs({
    "C:/same.wav\tfirst\t1\t1\t3\tpending\t2\tcover.png",
    "C:/same.wav\tupdated\t0\t0\t8\tunclassified\t9\t",
  }) do
    local asset = database_asset_from_line({ "path", "name", "marked", "ready", "used_count", "ucs_status", "preview_count", "artwork_path" }, line)
    insert(asset, path_key(asset.path))
  end
  return state
end
local legacy = duplicate_rows(function(asset) add_or_update_asset(asset, false) end)
local bulk = duplicate_rows(add_loaded_database_asset)
assert(#bulk.assets == 1 and bulk.ucs_pending_count == legacy.ucs_pending_count)
for key, value in pairs(legacy.assets[1]) do assert(bulk.assets[1][key] == value, key) end

local native_open, native_remove = io.open, os.remove
local count = 60000
if not real_snapshot then
  local rows = { table.concat(DB_FIELDS, "\t") }
  for index = 1, count do
    local path = string.format("C:/Library/%d.wav", index)
    rows[#rows + 1] = table.concat(database_asset_values({
      path = path, asset_id = "asset" .. index, relative_path = index .. ".wav",
      name = "sound" .. index .. ".wav", folder = "C:/Library", root = "C:/Library",
      library = "Library", library_id = "library", root_id = "root",
      ready = true, indexed = true, duration = 1, channels = 2,
      sample_rate = 48000, bit_depth = 24, source_type = "WAV", size = 288044,
      description = "Synthetic library fixture with a full current-schema row",
      keywords = "impact metal transient sound", workflow_status = "none",
    }), "\t")
  end
  local snapshot = table.concat(rows, "\n") .. "\n"
  local journal = assert(encode_asset_journal(0, DB_FIELDS, {
    { op = "delete", values = database_asset_values({ path = "C:/Library/1.wav" }) },
    { op = "upsert", values = database_asset_values({ path = "C:/Library/2.wav", name = "changed", ready = true, indexed = true, duration = 2 }) },
    { op = "upsert", values = database_asset_values({ path = "C:/Library/new.wav", name = "new" }) },
  }))
  io.open = function(path, mode)
    local content = path == DATABASE_FILE and snapshot or path == DATABASE_JOURNAL_FILE and journal
    if not content then return native_open(path, mode) end
    assert(mode == "rb", "benchmark may only read")
    local position = 1
    local file = {}
    function file:read(kind)
      if kind == "*a" then return content end
      local last = content:find("\n", position, true)
      if not last then return nil end
      local line = content:sub(position, last - 1)
      position = last + 1
      return line
    end
    function file:lines() return function() return self:read("*l") end end
    function file:close() return true end
    return file
  end
end
os.remove = function() error("read-only benchmark attempted a removal") end
state = fresh_state()
local yields, maximum_step = 0, 0
local phases = {}
local budget = tonumber(arg[7]) or 0.024
local started = os.clock()
local thread = coroutine.create(load_database)
state.startup_session = { thread = thread, deadline = os.clock() + budget }
while coroutine.status(thread) ~= "dead" do
  local step_started = os.clock()
  state.startup_session.deadline = step_started + budget
  local ok, reason = coroutine.resume(thread)
  assert(ok, reason)
  maximum_step = math.max(maximum_step, os.clock() - step_started)
  local phase = state.startup_session.phase or "snapshot"
  phases[phase] = (phases[phase] or 0) + os.clock() - step_started
  yields = yields + 1
end
assert(not state.persistence_read_only, state.persistence_read_only_reason)
if not real_snapshot then
  assert(#state.assets == count)
  assert(not state.by_path[path_key("C:/Library/1.wav")])
  assert(state.by_path[path_key("C:/Library/2.wav")].name == "changed")
  assert(state.by_path[path_key("C:/Library/new.wav")].ready == false)
  if startup_checkpoint then assert(yields > 1, "startup must yield across catalog batches") end
end
io.open, os.remove = native_open, native_remove
print(string.format("Startup catalog: %d assets, %.3fs total CPU, %d frames, %.4fs maximum frame",
  #state.assets, os.clock() - started, yields, maximum_step))
print(string.format("  Estimated catalog wall time at 30ms defer gaps: %.3fs (excludes UI, other startup work and disk latency)",
  os.clock() - started + math.max(0, yields - 1) * 0.030))
for phase, elapsed in pairs(phases) do print(string.format("  %s: %.3fs", phase, elapsed)) end
