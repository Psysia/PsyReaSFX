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
