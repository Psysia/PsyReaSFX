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
DB_FIELDS = { "path", "name", "ready", "indexed", "duration" }
if real_snapshot then
  local fields = region(catalog, "local DB_FIELDS = {", "function load_or_migrate_libraries()")
  fields = fields:match("local DB_FIELDS = (%b{})")
  DB_FIELDS = assert(load("return " .. fields))()
end
AppState = { set = function(key, value) state[key] = value end,
  apply = function(values) for key, value in pairs(values) do state[key] = value end end }
reaper = { time_precise = os.clock }
function path_key(path) return tostring(path or ""):lower() end
function is_ignored_media_path(path) return path:match("[\\/]%._") ~= nil end
function ensure_asset_identity() end
function fingerprint_metadata_is_compatible() return true end
function clear_asset_fingerprint() end
function invalidate_similarity_index() end
function refresh_ucs_pending_membership() end
function remove_ucs_pending_membership() end
function is_persistence_schema_fields(fields) return fields[1] == "psyreasfx_schema" end
function persistence_schema_generation(fields) return tonumber(fields[5]) or 0 end
function set_status(text) state.status = text end
function add_or_update_asset(asset)
  local key = path_key(asset.path)
  if state.by_path[key] then return end
  state.assets[#state.assets + 1] = asset
  state.by_path[key] = asset
end
function rebuild_assets()
  state.assets = {}
  for _, asset in pairs(state.by_path) do state.assets[#state.assets + 1] = asset end
end
assert(load(region(core, "function unescape_tsv(value)", "function split_words(text)")))()
assert(loadfile(journal_path))()
assert(loadfile("src/lua/37_catalog_caches.lua"))()
local database_start = runtime:find("function startup_checkpoint(phase)", 1, true)
  and "function startup_checkpoint(phase)" or "function load_database()"
assert(load(region(runtime, database_start, "function database_asset_values(asset)")))()
assert(load(region(runtime, "function replace_database_asset(asset, probe_file)", "function write_database_asset_line(file, asset)")))()
assert(load(region(runtime, "function database_asset_values(asset)", "function mark_asset_database_change(asset)")))()
function mark_database_snapshot_dirty() state.db_dirty = true end

local native_open, native_remove = io.open, os.remove
local count = 60000
if not real_snapshot then
  local rows = { table.concat(DB_FIELDS, "\t") }
  for index = 1, count do
    rows[#rows + 1] = string.format("C:/Library/%d.wav\tsound%d.wav\t1\t1\t1", index, index)
  end
  local snapshot = table.concat(rows, "\n") .. "\n"
  local journal = assert(encode_asset_journal(0, DB_FIELDS, {
    { op = "delete", values = { "C:/Library/1.wav", "", "", "", "" } },
    { op = "upsert", values = { "C:/Library/2.wav", "changed", "1", "1", "2" } },
    { op = "upsert", values = { "C:/Library/new.wav", "new", "0", "0", "0" } },
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
state = { assets = {}, by_path = {}, favorites = {}, selected_set = {},
  database_changes = new_asset_change_set() }
local yields, maximum_step = 0, 0
local phases = {}
local started = os.clock()
local thread = coroutine.create(load_database)
state.startup_session = { thread = thread, deadline = os.clock() + 0.004 }
while coroutine.status(thread) ~= "dead" do
  local step_started = os.clock()
  state.startup_session.deadline = step_started + 0.004
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
for phase, elapsed in pairs(phases) do print(string.format("  %s: %.3fs", phase, elapsed)) end
