-- Sparse activity indexes and frame-budgeted aggregate caches for large
-- catalogs. These helpers are REAPER-independent so capacity behavior can be
-- tested without launching the UI.

function new_library_count_job()
  return { index = 1, counts = {} }
end

function step_library_count_job(job, assets, batch_size)
  if type(job) ~= "table" or type(assets) ~= "table" then
    return false, nil, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local last = math.min(#assets, job.index + batch_size - 1)
  for index = job.index, last do
    local id = tostring(assets[index].library_id or "")
    if id ~= "" then
      job.counts[id] = (job.counts[id] or 0) + 1
    end
  end
  job.index = last + 1
  return job.index > #assets, job.counts
end

function ordered_preview_history_assets(
  history_assets,
  by_path,
  path_key_function,
  sort_key_function
)
  local assets = {}
  for _, asset in pairs(history_assets or {}) do
    local key = asset and path_key_function(asset.path) or nil
    if key and by_path[key] == asset
      and (tonumber(asset.last_previewed) or 0) > 0 then
      assets[#assets + 1] = asset
    end
  end
  table.sort(assets, function(left, right)
    return sort_key_function(left) < sort_key_function(right)
  end)
  return assets
end

-- Add a file to a size bucket without retaining every singleton in a second
-- candidate array. The first item is emitted only when a second item proves
-- that the size can contain duplicates.
function add_duplicate_size_candidate(groups, candidates, size, asset)
  if type(groups) ~= "table" or type(candidates) ~= "table"
    or type(asset) ~= "table" or (tonumber(size) or 0) <= 0 then
    return false
  end
  local key = tonumber(size)
  local group = groups[key]
  if not group then
    groups[key] = { first = asset, count = 1 }
    return false
  end
  group.count = group.count + 1
  if group.count == 2 then
    candidates[#candidates + 1] = group.first
  end
  candidates[#candidates + 1] = asset
  return true
end

-- Build final fingerprint groups while fingerprints are produced. This avoids
-- a second full pass over every candidate at the end of a large scan.
function add_duplicate_fingerprint_asset(
  groups,
  duplicates,
  lookup,
  fingerprint,
  asset,
  path_key_function
)
  if type(groups) ~= "table" or type(duplicates) ~= "table"
    or type(lookup) ~= "table" or type(asset) ~= "table"
    or type(path_key_function) ~= "function" then
    return false
  end
  fingerprint = tostring(fingerprint or "")
  if fingerprint == "" then return false end

  local group = groups[fingerprint]
  if not group then
    groups[fingerprint] = {
      fingerprint = fingerprint,
      assets = { asset },
      count = 1,
    }
    return false
  end

  group.assets[#group.assets + 1] = asset
  group.count = #group.assets
  if group.count == 2 then
    duplicates[#duplicates + 1] = group
    lookup[path_key_function(group.assets[1].path)] = fingerprint
  end
  lookup[path_key_function(asset.path)] = fingerprint
  return true
end

-- Incrementally filter a path-indexed catalog while allowing the caller to
-- remove the current entry safely. The next key is captured before deletion,
-- avoiding Lua's invalid-key-to-next failure mode.
function new_catalog_prune_job(by_path)
  by_path = type(by_path) == "table" and by_path or {}
  return {
    by_path = by_path,
    next_key = next(by_path),
    kept = {},
    processed = 0,
    removed = 0,
  }
end

function step_catalog_prune_job(
  job,
  batch_size,
  should_remove,
  on_remove
)
  if type(job) ~= "table" or type(job.by_path) ~= "table"
    or type(should_remove) ~= "function" then
    return false, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local processed = 0
  while job.next_key ~= nil and processed < batch_size do
    local key = job.next_key
    local asset = job.by_path[key]
    job.next_key = next(job.by_path, key)
    if asset and should_remove(key, asset) then
      job.by_path[key] = nil
      job.removed = job.removed + 1
      if type(on_remove) == "function" then
        on_remove(key, asset)
      end
    elseif asset then
      job.kept[#job.kept + 1] = asset
    end
    job.processed = job.processed + 1
    processed = processed + 1
  end
  return job.next_key == nil
end

function new_artwork_reset_job(assets)
  assets = type(assets) == "table" and assets or {}
  return {
    assets = assets,
    index = 1,
    total = #assets,
    changed = 0,
  }
end

function step_artwork_reset_job(job, batch_size)
  if type(job) ~= "table" or type(job.assets) ~= "table" then
    return false, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local last = math.min(job.total, job.index + batch_size - 1)
  for index = job.index, last do
    local asset = job.assets[index]
    if asset and asset.artwork_path ~= "-" then
      if asset.artwork_path ~= "" or asset.artwork_checked then
        job.changed = job.changed + 1
      end
      asset.artwork_path = ""
      asset.artwork_checked = false
    end
  end
  job.index = last + 1
  return job.index > job.total
end
