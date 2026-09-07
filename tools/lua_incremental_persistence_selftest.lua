local module_path = assert(arg[1], "incremental persistence module is required")
local item_count = math.max(1, math.floor(tonumber(arg[2]) or 25000))
assert(loadfile(module_path))()

local function escape(value)
  return tostring(value or ""):gsub("[\t\r\n]", " ")
end
local function key(value) return tostring(value or ""):lower() end
local function new_writer(fail_after)
  return {
    lines = {},
    write = function(self, ...)
      if fail_after and #self.lines >= fail_after then return nil end
      self.lines[#self.lines + 1] = table.concat({ ... })
      return self
    end,
  }
end

local collection = {
  id = "large",
  name = "Large collection",
  kind = "playlist",
  items = {},
  order = {},
}
local usage = { project = { path = "C:/Projects/Test.rpp", assets = {} } }
for index = 1, item_count do
  local path = string.format("C:/Catalog/%07d.wav", index)
  collection.items[key(path)] = path
  collection.order[index] = path
  usage.project.assets[key(path)] = {
    path = path,
    count = index,
    last_used = index * 2,
    action = "insert",
  }
end

local writer = new_writer()
local collection_job = new_collections_persistence_job({ collection })
local collection_steps = 0
repeat
  collection_steps = collection_steps + 1
until step_collections_persistence_job(
  collection_job, writer, 4000, escape, key
)
assert(collection_steps == math.ceil((item_count + 1) / 4000))
assert(#writer.lines == item_count + 1)
assert(writer.lines[1]:match("^collection\tlarge\t"))

writer = nil
collection_job = nil
collectgarbage("collect")
writer = new_writer()
local usage_job = new_project_usage_persistence_job(usage)
local usage_steps = 0
repeat
  usage_steps = usage_steps + 1
until step_project_usage_persistence_job(
  usage_job, writer, 4000, escape
)
assert(usage_steps == math.ceil(item_count / 4000))
assert(#writer.lines == item_count)

writer = nil
usage_job = nil
collectgarbage("collect")
local failed_writer = new_writer(1)
local failed_job = new_collections_persistence_job({ collection })
local complete, failure = step_collections_persistence_job(
  failed_job, failed_writer, 4000, escape, key
)
assert(not complete and failure == "write_item")

local timed_job = new_project_usage_persistence_job(usage)
local timed_writer = new_writer()
local timed_complete = step_project_usage_persistence_job(
  timed_job,
  timed_writer,
  item_count,
  escape,
  0,
  function() return 1 end
)
if item_count >= 64 then
assert(not timed_complete and timed_job.processed == 64)
end

local history_by_id = {}
local history_by_path = {}
local played = {}
for index = 1, item_count do
  local path = string.format("C:/History/%07d.wav", index)
  local asset = {
    path = path,
    preview_count = index,
    last_previewed = index,
  }
  history_by_id[tostring(index)] = asset
  history_by_path[key(path)] = asset
  played[key(path)] = true
end
if item_count > 1 then
  history_by_path[key(history_by_id["1"].path)] = nil
end
writer = new_writer()
local history_job = new_history_persistence_job(
  history_by_id,
  history_by_path
)
local history_steps = 0
repeat
  history_steps = history_steps + 1
until step_history_persistence_job(
  history_job, writer, 4000, escape, key
)
assert(history_steps == math.ceil(item_count / 4000))
assert(#writer.lines == item_count - (item_count > 1 and 1 or 0))

writer = new_writer()
local played_job = new_path_set_persistence_job(played)
local played_steps = 0
repeat
  played_steps = played_steps + 1
until step_path_set_persistence_job(
  played_job, writer, 4000, escape
)
assert(played_steps == math.ceil(item_count / 4000))
assert(#writer.lines == item_count)
local saved_count = 0
for _ in pairs(played_job.saved) do saved_count = saved_count + 1 end
assert(saved_count == item_count)

local failed_history_writer = new_writer(0)
local failed_history_job = new_history_persistence_job(
  history_by_id,
  history_by_path
)
local history_complete, history_failure = step_history_persistence_job(
  failed_history_job,
  failed_history_writer,
  4000,
  escape,
  key
)
assert(not history_complete and history_failure == "write_history")

print(string.format(
  "Lua incremental persistence self-test OK: records=%d collection_steps=%d usage_steps=%d history_steps=%d played_steps=%d memory=%.1fMiB",
  item_count,
  collection_steps,
  usage_steps,
  history_steps,
  played_steps,
  collectgarbage("count") / 1024
))
