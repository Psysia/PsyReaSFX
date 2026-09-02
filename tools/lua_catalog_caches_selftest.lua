local module_path = assert(arg[1], "catalog cache module is required")
local asset_count = math.max(1, math.floor(tonumber(arg[2]) or 25000))
assert(loadfile(module_path))()

local assets = {}
for index = 1, asset_count do
  assets[index] = {
    path = string.format("C:/Catalog/%07d.wav", index),
    library_id = "library-" .. tostring(((index - 1) % 100) + 1),
    last_previewed = index <= 100 and index or 0,
  }
end

local job = new_library_count_job()
local steps = 0
local complete, counts
repeat
  complete, counts = step_library_count_job(job, assets, 4000)
  steps = steps + 1
until complete
assert(steps == math.ceil(asset_count / 4000))
local total = 0
for _, count in pairs(counts) do total = total + count end
assert(total == asset_count)

local history = {}
local by_path = {}
local function key(path) return tostring(path):lower() end
local function sort_key(asset) return key(asset.path) end
for index = 1, math.min(100, asset_count) do
  local asset = assets[index]
  history[tostring(index)] = asset
  by_path[key(asset.path)] = asset
end
if asset_count >= 1 then
  by_path[key(assets[1].path)] = nil
end
local ordered = ordered_preview_history_assets(
  history,
  by_path,
  key,
  sort_key
)
assert(#ordered == math.min(100, asset_count) - 1)
for index = 2, #ordered do
  assert(sort_key(ordered[index - 1]) < sort_key(ordered[index]))
end

print(string.format(
  "Lua catalog cache self-test OK: assets=%d steps=%d history=%d memory=%.1fMiB",
  asset_count,
  steps,
  #ordered,
  collectgarbage("count") / 1024
))
