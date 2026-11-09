-- Relink migration: the bulk context used by the commit (which skips scanning
-- the recent list for assets that are not in it) must produce exactly the same
-- catalog state as the plain per-asset migration, with far fewer path keys.
local runtime_path = assert(arg[1], "runtime UI module is required")

local function read(path)
  local handle = assert(io.open(path, "rb"))
  local text = handle:read("*a")
  handle:close()
  return text
end
local function region(source, first, following)
  local at = assert(source:find(first, 1, true), first)
  local last = assert(source:find(following, at + #first, true), following)
  return source:sub(at, last - 1)
end

local path_key_calls = 0
function normalize_slashes(path) return (tostring(path or ""):gsub("\\", "/")) end
function path_key(path)
  path_key_calls = path_key_calls + 1
  return normalize_slashes(path):lower()
end
function asset_path_sort_key(asset) return path_key(asset.path) end
function basename(path) return tostring(path):match("([^/]+)$") or "" end
function dirname(path) return tostring(path):match("^(.*)/[^/]*$") or "" end
function asset_relative_path(path, root)
  path, root = normalize_slashes(path), normalize_slashes(root)
  if path:lower():sub(1, #root) == root:lower() then return (path:sub(#root + 2)) end
  return path
end
function invalidate_similarity_index() end
function clear_asset_fingerprint(asset) asset.fingerprint = "" end
function ensure_asset_identity(asset, probe)
  asset.relative_path = asset_relative_path(asset.path, asset.root or "")
  asset.identity_probed = probe ~= false
end
function selection_add(key) state.selected_set[key] = true end
function selection_remove(key) state.selected_set[key] = nil end
reaper = { file_exists = function(path) return not tostring(path):find("gone", 1, true) end }

assert(load(region(read(runtime_path), "function replace_path_in_order(", "function validate_relinked_root(")))()

local function dump(value, seen)
  local kind = type(value)
  if kind ~= "table" then return kind == "string" and string.format("%q", value) or tostring(value) end
  seen = seen or {}
  if seen[value] then return "<cycle>" end
  seen[value] = true
  local keys = {}
  for key in pairs(value) do
    if key ~= "last_seen" then keys[#keys + 1] = key end
  end
  table.sort(keys, function(left, right) return tostring(left) < tostring(right) end)
  local parts = {}
  for _, key in ipairs(keys) do
    parts[#parts + 1] = tostring(key) .. "=" .. dump(value[key], seen)
  end
  seen[value] = nil
  return "{" .. table.concat(parts, ",") .. "}"
end

local function build()
  local assets, by_path = {}, {}
  local state_local = {
    favorites = {}, session_played = {}, last_session_played = {},
    recent = {}, collections = {}, regions_by_path = {}, loudness_cache = {},
    failed_tasks = {}, project_usage = { p1 = { assets = {} }, p2 = { assets = {} } },
    selected_set = {}, library_by_id = { lib = { name = "Lib" } }, by_path = by_path,
  }
  for index = 1, 400 do
    local path = string.format("C:/Old/dir%d/File%03d%s.wav", index % 7, index, index % 41 == 0 and "gone" or "")
    local asset = { path = path, name = basename(path), root = "C:/Old", root_id = "r1", library = "Old" }
    assets[index] = asset
    by_path[path_key(path)] = asset
    local key = path_key(path)
    if index % 3 == 0 then state_local.favorites[key] = true end
    if index % 5 == 0 then state_local.session_played[key] = true end
    if index % 11 == 0 then state_local.loudness_cache[key] = { path = path, size = index } end
    if index % 13 == 0 then state_local.failed_tasks[key] = { path = path } end
    if index % 17 == 0 then state_local.regions_by_path[key] = { { path = path, start = 0, finish = 1 } } end
    if index % 19 == 0 then state_local.project_usage.p1.assets[key] = { path = path, count = 2, last_used = index } end
  end
  -- Recent list: some migrated assets (some twice), some unrelated, and an
  -- entry that already equals a migration target (exercises de-duplication).
  for index = 1, 100 do
    if index % 4 == 0 then
      state_local.recent[index] = assets[(index * 3) % 400 + 1].path
    elseif index % 9 == 0 then
      state_local.recent[index] = "D:/New/dir1/File002.wav"
    else
      state_local.recent[index] = "E:/Elsewhere/Other" .. index .. ".wav"
    end
  end
  local items, order = {}, {}
  for index = 1, 400, 4 do
    local key = path_key(assets[index].path)
    items[key] = assets[index].path
    order[#order + 1] = assets[index].path
  end
  state_local.collections[1] = { items = items, order = order, count = #order }
  return state_local, assets
end

local function run(use_bulk)
  state, assets = nil, nil
  local built, built_assets = build()
  state = built
  local record = { path = "D:/New", id = "r2", library_id = "lib" }
  path_key_calls = 0
  if use_bulk then RelinkBulk = new_relink_bulk_context() end
  local moved = 0
  for index, asset in ipairs(built_assets) do
    if index % 10 ~= 0 then
      local target = "D:/New/dir" .. (index % 7) .. "/File" .. string.format("%03d", index) .. (index % 41 == 0 and "gone" or "") .. ".wav"
      if migrate_asset_path(asset, target, record) then moved = moved + 1 end
    end
  end
  RelinkBulk = nil
  return dump(state), moved, path_key_calls
end

local plain_dump, plain_moved, plain_calls = run(false)
local bulk_dump, bulk_moved, bulk_calls = run(true)
assert(plain_moved == bulk_moved and plain_moved > 300, "same assets must migrate")
assert(plain_dump == bulk_dump, "bulk relink must produce the same catalog state as the plain migration")
assert(bulk_calls * 3 < plain_calls,
  string.format("bulk context should avoid most recent-list path keys (%d vs %d)", bulk_calls, plain_calls))

-- One existence probe per asset: migration answers `missing` and last_seen
-- together instead of probing three times.
do
  local probes = 0
  reaper.file_exists = function(path) probes = probes + 1 return not tostring(path):find("gone", 1, true) end
  local single_state, single_assets = build()
  state = single_state
  local asset = single_assets[1]
  assert(migrate_asset_path(asset, "D:/New/dir1/File001.wav", { path = "D:/New", id = "r2", library_id = "lib" }))
  assert(probes == 1, "one file_exists per migrated asset, got " .. probes)
  assert(asset.identity_probed == false and asset.missing == false)
  local gone = single_assets[41]
  assert(migrate_asset_path(gone, "D:/New/dir6/File041gone.wav", { path = "D:/New", id = "r2", library_id = "lib" }))
  assert(gone.missing == true)
end

print(string.format("Lua relink self-test passed: %d assets, path keys %d -> %d", plain_moved, plain_calls, bulk_calls))
