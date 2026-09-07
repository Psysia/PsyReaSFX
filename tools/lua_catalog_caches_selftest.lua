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

local size_groups = {}
local candidates = {}
local sample = {
  { path = "C:/Catalog/a.wav" },
  { path = "C:/Catalog/b.wav" },
  { path = "C:/Catalog/c.wav" },
  { path = "C:/Catalog/d.wav" },
}
assert(not add_duplicate_size_candidate(size_groups, candidates, 10, sample[1]))
assert(not add_duplicate_size_candidate(size_groups, candidates, 20, sample[2]))
assert(add_duplicate_size_candidate(size_groups, candidates, 10, sample[3]))
assert(add_duplicate_size_candidate(size_groups, candidates, 10, sample[4]))
assert(#candidates == 3)
assert(candidates[1] == sample[1])
assert(candidates[2] == sample[3])
assert(candidates[3] == sample[4])

local fingerprint_groups = {}
local duplicates = {}
local duplicate_lookup = {}
assert(not add_duplicate_fingerprint_asset(
  fingerprint_groups, duplicates, duplicate_lookup,
  "one", sample[1], key
))
assert(not add_duplicate_fingerprint_asset(
  fingerprint_groups, duplicates, duplicate_lookup,
  "two", sample[2], key
))
assert(add_duplicate_fingerprint_asset(
  fingerprint_groups, duplicates, duplicate_lookup,
  "one", sample[3], key
))
assert(add_duplicate_fingerprint_asset(
  fingerprint_groups, duplicates, duplicate_lookup,
  "one", sample[4], key
))
assert(#duplicates == 1)
assert(duplicates[1].count == 3)
assert(duplicate_lookup[key(sample[1].path)] == "one")
assert(duplicate_lookup[key(sample[3].path)] == "one")
assert(duplicate_lookup[key(sample[4].path)] == "one")
assert(duplicate_lookup[key(sample[2].path)] == nil)

local prune_count = math.min(asset_count, 25000)
local prune_map = {}
for index = 1, prune_count do
  prune_map[tostring(index)] = assets[index]
end
local removed_keys = {}
local prune_job = new_catalog_prune_job(prune_map)
local prune_steps = 0
local prune_complete
repeat
  prune_complete = step_catalog_prune_job(
    prune_job,
    4000,
    function(prune_key)
      return tonumber(prune_key) % 2 == 0
    end,
    function(prune_key)
      removed_keys[prune_key] = true
    end
  )
  prune_steps = prune_steps + 1
until prune_complete
assert(prune_steps == math.ceil(prune_count / 4000))
assert(prune_job.processed == prune_count)
assert(prune_job.removed == math.floor(prune_count / 2))
assert(#prune_job.kept == prune_count - prune_job.removed)
for index = 1, prune_count do
  local present = prune_map[tostring(index)] ~= nil
  assert(present == (index % 2 == 1))
  assert((removed_keys[tostring(index)] == true) == (index % 2 == 0))
end

local artwork_count = math.min(asset_count, 25000)
local artwork_assets = {}
local expected_artwork_changes = 0
for index = 1, artwork_count do
  local asset = { artwork_path = "", artwork_checked = false }
  if index % 5 == 0 then
    asset.artwork_path = "-"
    asset.artwork_checked = true
  elseif index % 3 == 0 then
    asset.artwork_path = "C:/Artwork/cover.jpg"
    asset.artwork_checked = true
    expected_artwork_changes = expected_artwork_changes + 1
  end
  artwork_assets[index] = asset
end
local artwork_job = new_artwork_reset_job(artwork_assets)
local artwork_steps = 0
repeat
  artwork_steps = artwork_steps + 1
until step_artwork_reset_job(artwork_job, 4000)
assert(artwork_steps == math.ceil(artwork_count / 4000))
assert(artwork_job.changed == expected_artwork_changes)
for index, asset in ipairs(artwork_assets) do
  if index % 5 == 0 then
    assert(asset.artwork_path == "-" and asset.artwork_checked)
  else
    assert(asset.artwork_path == "" and not asset.artwork_checked)
  end
end

local filter_job = new_catalog_filter_job(assets)
local filter_steps = 0
repeat
  filter_steps = filter_steps + 1
until step_catalog_filter_job(
  filter_job,
  4000,
  function(asset)
    return tonumber(asset.path:match("(%d+)%.wav$")) % 4 == 0
  end,
  function(asset) return key(asset.path) end
)
assert(filter_steps == math.ceil(asset_count / 4000))
assert(#filter_job.removed == math.floor(asset_count / 4))
assert(#filter_job.kept == asset_count - #filter_job.removed)
assert(filter_job.kept_by_key[key(assets[1].path)] == assets[1])
if asset_count >= 4 then
  assert(filter_job.kept_by_key[key(assets[4].path)] == nil)
end

local timed_total = math.min(asset_count, 1000)
local timed_assets = {}
for index = 1, timed_total do timed_assets[index] = assets[index] end
local timed_job = new_catalog_filter_job(timed_assets)
local timed_complete = step_catalog_filter_job(
  timed_job,
  timed_total,
  function() return false end,
  function(asset) return key(asset.path) end,
  0,
  function() return 1 end
)
if timed_total >= 64 then
  assert(not timed_complete and timed_job.index == 64)
else
  assert(timed_complete)
end

print(string.format(
  "Lua catalog cache self-test OK: assets=%d steps=%d history=%d memory=%.1fMiB",
  asset_count,
  steps,
  #ordered,
  collectgarbage("count") / 1024
))
