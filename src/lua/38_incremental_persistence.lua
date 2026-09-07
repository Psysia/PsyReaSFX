-- Frame-budgeted serializers for large auxiliary catalogs. Callers own the
-- atomic writer and pass escaping/path-key functions so this module remains
-- independent from REAPER and can be capacity-tested from the command line.

function new_collections_persistence_job(collections)
  local snapshots = {}
  for _, collection in ipairs(collections or {}) do
    local order = collection.order or {}
    snapshots[#snapshots + 1] = {
      id = collection.id or "",
      name = collection.name or "",
      kind = collection.kind or "playlist",
      project_path = collection.project_path or "",
      items = collection.items or {},
      order = order,
      total = #order,
      header_written = false,
      item_index = 1,
    }
  end
  return {
    collections = snapshots,
    collection_index = 1,
    processed = 0,
  }
end

function step_collections_persistence_job(
  job,
  writer,
  batch_size,
  escape_function,
  key_function,
  deadline,
  time_function
)
  if type(job) ~= "table" or type(writer) ~= "table"
    or type(writer.write) ~= "function"
    or type(escape_function) ~= "function"
    or type(key_function) ~= "function" then
    return false, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local processed = 0
  while processed < batch_size do
    local snapshot = job.collections[job.collection_index]
    if not snapshot then return true end
    if not snapshot.header_written then
      snapshot.header_written = true
      if not writer:write(
        "collection\t", escape_function(snapshot.id), "\t",
        escape_function(snapshot.name), "\t",
        escape_function(snapshot.kind), "\t",
        escape_function(snapshot.project_path), "\n"
      ) then
        return false, "write_collection"
      end
      processed = processed + 1
      job.processed = job.processed + 1
    elseif snapshot.item_index <= snapshot.total then
      local path = snapshot.order[snapshot.item_index]
      snapshot.item_index = snapshot.item_index + 1
      if snapshot.items[key_function(path)] then
        if not writer:write(
          "item\t", escape_function(snapshot.id), "\t",
          escape_function(path), "\n"
        ) then
          return false, "write_item"
        end
      end
      processed = processed + 1
      job.processed = job.processed + 1
    else
      job.collection_index = job.collection_index + 1
    end
    if processed > 0 and processed % 64 == 0 and deadline
      and type(time_function) == "function"
      and time_function() >= deadline then
      return false
    end
  end
  local current = job.collections[job.collection_index]
  if current and current.header_written
    and current.item_index > current.total then
    job.collection_index = job.collection_index + 1
  end
  return job.collections[job.collection_index] == nil
end

function new_project_usage_persistence_job(project_usage)
  local projects = {}
  for _, bucket in pairs(project_usage or {}) do
    projects[#projects + 1] = {
      path = bucket.path or "",
      assets = bucket.assets or {},
      started = false,
      next_key = nil,
    }
  end
  return {
    projects = projects,
    project_index = 1,
    processed = 0,
  }
end

function step_project_usage_persistence_job(
  job,
  writer,
  batch_size,
  escape_function,
  deadline,
  time_function
)
  if type(job) ~= "table" or type(writer) ~= "table"
    or type(writer.write) ~= "function"
    or type(escape_function) ~= "function" then
    return false, "invalid_input"
  end
  batch_size = math.max(1, math.floor(tonumber(batch_size) or 1))
  local processed = 0
  while processed < batch_size do
    local project = job.projects[job.project_index]
    if not project then return true end
    if not project.started then
      project.started = true
      project.next_key = next(project.assets)
    elseif project.next_key == nil then
      job.project_index = job.project_index + 1
    else
      local key = project.next_key
      local entry = project.assets[key]
      project.next_key = next(project.assets, key)
      if entry and not writer:write(
        "usage\t", escape_function(project.path), "\t",
        escape_function(entry.path or ""), "\t",
        tostring(entry.count or 1), "\t",
        tostring(entry.last_used or 0), "\t",
        escape_function(entry.action or "insert"), "\n"
      ) then
        return false, "write_usage"
      end
      processed = processed + 1
      job.processed = job.processed + 1
    end
    if processed > 0 and processed % 64 == 0 and deadline
      and type(time_function) == "function"
      and time_function() >= deadline then
      return false
    end
  end
  local current = job.projects[job.project_index]
  if current and current.started and current.next_key == nil then
    job.project_index = job.project_index + 1
  end
  return job.projects[job.project_index] == nil
end
