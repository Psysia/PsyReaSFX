local core_path = assert(arg[1], "usage: lua_startup_selftest.lua <ui-core> <catalog> <runtime-ui>")
local catalog_path = assert(arg[2], "missing catalog source")
local runtime_path = assert(arg[3], "missing runtime source")

local function read_all(path)
  local handle = assert(io.open(path, "rb"))
  local text = handle:read("*a")
  handle:close()
  return text
end

local function region(source, first, following)
  local start_at = assert(source:find(first, 1, true), "missing marker: " .. first)
  local end_at = assert(source:find(following, start_at + #first, true), "missing marker: " .. following)
  return source:sub(start_at, end_at - 1)
end

local core = read_all(core_path)
local catalog = read_all(catalog_path)
local runtime = read_all(runtime_path)

local path_key_source = region(core, "function path_key(path)", "function canonical_source_path(path)")
assert(path_key_source:find('SEP == "\\\\"', 1, true), "path_key must use the cached platform separator")
assert(not path_key_source:find("GetOS", 1, true), "path_key must not call the REAPER host per asset")

local identity_source = region(catalog, "function ensure_asset_identity(asset, probe_file)", "function make_placeholder(path, known_root)")
assert(identity_source:find("probe_file ~= false", 1, true), "asset identity must support trusted persisted rows")

local file_probes = 0
HostApi = {
  file_exists = function()
    file_probes = file_probes + 1
    return true
  end,
}
assert(load(identity_source, "asset-identity", "t", _ENV))()
local persisted = {
  path = "persisted.wav",
  relative_path = "persisted.wav",
  asset_id = "asset-persisted",
  last_seen = 123,
}
ensure_asset_identity(persisted, false)
assert(file_probes == 0 and persisted.last_seen == 123, "trusted database identity must perform zero file probes")
ensure_asset_identity(persisted)
assert(file_probes == 1 and persisted.last_seen >= 123, "live identity updates must retain file verification")

local database_row_source = region(runtime, "function database_asset_from_values(headers, values)", "function database_asset_values(asset)")
assert(database_row_source:find("ensure_asset_identity(asset, false)", 1, true), "database rows must not probe the filesystem at startup")

local database_load_source = region(runtime, "function load_database()", "function database_asset_from_values(headers, values)")
assert(database_load_source:find("add_or_update_asset(asset, false)", 1, true), "database loading must preserve the no-probe contract")

local history_source = region(runtime, "function load_history()", "function save_history()")
assert(history_source:find("ensure_asset_identity(asset, false)", 1, true), "history loading must not re-probe catalog files")

print("Lua startup self-test passed")
