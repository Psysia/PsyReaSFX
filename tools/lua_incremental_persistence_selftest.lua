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

print(string.format(
  "Lua incremental persistence self-test OK: records=%d collection_steps=%d usage_steps=%d memory=%.1fMiB",
  item_count,
  collection_steps,
  usage_steps,
  collectgarbage("count") / 1024
))
