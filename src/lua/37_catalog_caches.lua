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

function ucs_count_key(value)
  return string.upper(tostring(value or ""):match("^%s*(.-)%s*$"))
end

function ucs_subcategory_count_key(category, subcategory)
  return ucs_count_key(category) .. "\0" .. ucs_count_key(subcategory)
end

function new_ucs_count_job()
  return {
    index = 1,
    counts = {
      categories = {},
      subcategories = {},
      catids = {},
      total = 0,
    },
  }
end

function step_ucs_count_job(job, assets, batch_size)
  if type(job) ~= "table" or type(assets) ~= "table"
    or type(job.counts) ~= "table" then
    return false, nil, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local last = math.min(#assets, job.index + batch_size - 1)
  for index = job.index, last do
    local asset = assets[index]
    local catid = asset and ucs_count_key(asset.catid) or ""
    local category = asset and ucs_count_key(asset.category) or ""
    local subcategory = asset and ucs_count_key(asset.subcategory) or ""
    if asset and asset.ready and catid ~= "" then
      job.counts.catids[catid] = (job.counts.catids[catid] or 0) + 1
      if category ~= "" then
        job.counts.categories[category] =
          (job.counts.categories[category] or 0) + 1
      end
      if category ~= "" and subcategory ~= "" then
        local pair = ucs_subcategory_count_key(category, subcategory)
        job.counts.subcategories[pair] =
          (job.counts.subcategories[pair] or 0) + 1
      end
      job.counts.total = job.counts.total + 1
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

function new_catalog_filter_job(assets)
  assets = type(assets) == "table" and assets or {}
  return {
    assets = assets,
    index = 1,
    total = #assets,
    kept = {},
    removed = {},
    kept_by_key = {},
  }
end

function step_catalog_filter_job(
  job,
  batch_size,
  should_remove,
  key_function,
  deadline,
  time_function
)
  if type(job) ~= "table" or type(job.assets) ~= "table"
    or type(should_remove) ~= "function"
    or type(key_function) ~= "function" then
    return false, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local last = math.min(job.total, job.index + batch_size - 1)
  while job.index <= last do
    local asset = job.assets[job.index]
    if asset then
      if should_remove(asset) then
        job.removed[#job.removed + 1] = asset
      else
        job.kept[#job.kept + 1] = asset
        job.kept_by_key[key_function(asset)] = asset
      end
    end
    job.index = job.index + 1
    if deadline and type(time_function) == "function"
      and job.index % 64 == 0 and time_function() >= deadline then
      break
    end
  end
  return job.index > job.total
end

-- Rebuild an ordered path set without mutating the live collection. The
-- second map pass repairs legacy entries that were missing from `order` and
-- also guarantees that duplicate order entries collapse to one item.
function new_ordered_path_filter_job(order, items)
  order = type(order) == "table" and order or {}
  items = type(items) == "table" and items or {}
  return {
    order = order,
    items = items,
    phase = "order",
    index = 1,
    next_key = nil,
    kept_order = {},
    kept_items = {},
    rejected = {},
    processed = 0,
    removed = 0,
    repaired = 0,
  }
end

function step_ordered_path_filter_job(
  job,
  batch_size,
  should_remove,
  key_function,
  deadline,
  time_function
)
  if type(job) ~= "table" or type(job.order) ~= "table"
    or type(job.items) ~= "table"
    or type(should_remove) ~= "function"
    or type(key_function) ~= "function" then
    return false, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local processed = 0
  while processed < batch_size do
    if job.phase == "order" then
      local ordered_path = job.order[job.index]
      if ordered_path == nil then
        job.phase = "items"
        job.next_key = next(job.items)
      else
        job.index = job.index + 1
        local key = key_function(ordered_path)
        local stored_path = job.items[key]
        if stored_path ~= nil then
          if should_remove(stored_path, key) then
            if not job.rejected[key] then
              job.rejected[key] = true
              job.removed = job.removed + 1
            end
          elseif job.kept_items[key] == nil then
            job.kept_items[key] = stored_path
            job.kept_order[#job.kept_order + 1] = stored_path
          else
            job.repaired = job.repaired + 1
          end
        else
          job.repaired = job.repaired + 1
        end
        job.processed = job.processed + 1
        processed = processed + 1
      end
    elseif job.phase == "items" then
      local key = job.next_key
      if key == nil then
        job.phase = "done"
        return true
      end
      local stored_path = job.items[key]
      job.next_key = next(job.items, key)
      local canonical_key = key_function(stored_path)
      if job.kept_items[canonical_key] == nil
        and not job.rejected[canonical_key] then
        if should_remove(stored_path, canonical_key) then
          job.rejected[canonical_key] = true
          job.removed = job.removed + 1
        else
          job.kept_items[canonical_key] = stored_path
          job.kept_order[#job.kept_order + 1] = stored_path
          job.repaired = job.repaired + 1
        end
      end
      job.processed = job.processed + 1
      processed = processed + 1
    else
      return true
    end
    if deadline and type(time_function) == "function"
      and processed % 64 == 0 and time_function() >= deadline then
      break
    end
  end
  return job.phase == "done"
end

-- Filter a path-keyed map into a detached result. Values are intentionally
-- shared because the removal transaction never mutates the surviving entry.
function new_path_map_filter_job(entries)
  entries = type(entries) == "table" and entries or {}
  return {
    entries = entries,
    next_key = next(entries),
    kept = {},
    processed = 0,
    removed = 0,
  }
end

function step_path_map_filter_job(
  job,
  batch_size,
  should_remove,
  path_function,
  deadline,
  time_function
)
  if type(job) ~= "table" or type(job.entries) ~= "table"
    or type(should_remove) ~= "function"
    or type(path_function) ~= "function" then
    return false, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local processed = 0
  while job.next_key ~= nil and processed < batch_size do
    local key = job.next_key
    local entry = job.entries[key]
    job.next_key = next(job.entries, key)
    if entry ~= nil and should_remove(path_function(entry, key), key) then
      job.removed = job.removed + 1
    elseif entry ~= nil then
      job.kept[key] = entry
    end
    job.processed = job.processed + 1
    processed = processed + 1
    if deadline and type(time_function) == "function"
      and processed % 64 == 0 and time_function() >= deadline then
      break
    end
  end
  return job.next_key == nil
end

-- Remove one catalog entry in O(1) while keeping a temporary key-to-position
-- index valid. Ordering is intentionally not preserved; result views apply
-- their own deterministic sort after startup.
function remove_indexed_array_entry(
  assets,
  positions,
  key,
  key_function
)
  if type(assets) ~= "table" or type(positions) ~= "table"
    or type(key_function) ~= "function" then
    return false
  end
  local index = positions[key]
  if type(index) ~= "number" or index < 1 or index > #assets then
    positions[key] = nil
    return false
  end
  local last_index = #assets
  local last_asset = assets[last_index]
  assets[index] = last_asset
  assets[last_index] = nil
  positions[key] = nil
  if index < last_index and last_asset then
    positions[key_function(last_asset)] = index
  end
  return true
end
