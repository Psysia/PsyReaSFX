local module_path = assert(arg[1], "jobs/storage module is required")
local clock = 10
reaper = {
  time_precise = function()
    clock = clock + 1
    return clock
  end,
}
Jobs = {
  accepting = true,
  active = {},
  generation = 0,
  history = {},
}

local module_file = assert(io.open(module_path, "rb"))
local source = assert(module_file:read("*a"))
module_file:close()
local boundary = assert(
  source:find("function extract_project_url_from_text", 1, true),
  "job coordinator boundary not found"
)
assert(load(source:sub(1, boundary - 1), "jobs_coordinator", "t"))()

local scan = assert(Jobs.begin("scan", "catalog", false, 40))
assert(Jobs.is_current(scan))
local blocked, reason = Jobs.begin("import", "catalog", false, 50)
assert(blocked == nil and reason == "resource_busy")
local duplicate, duplicate_reason = Jobs.begin("scan", "catalog", false, 40)
assert(duplicate == nil and duplicate_reason == "already_running")

local replacement = assert(Jobs.begin("scan", "catalog", true, 60))
assert(scan.cancel_requested and scan.state == "canceling")
assert(Jobs.is_current(replacement) and not Jobs.is_current(scan))
assert(Jobs.cancel(replacement))
Jobs.finish(replacement, true, "ignored success after cancel")
assert(replacement.state == "canceled")
assert(#Jobs.history == 1 and not Jobs.active.scan)

local wave = assert(Jobs.begin("wave", "cache", false, 20))
Jobs.stop_accepting()
assert(wave.cancel_requested)
local stopped, stopped_reason = Jobs.begin("other", "other", false, 10)
assert(stopped == nil and stopped_reason == "shutting_down")

print("Lua job coordinator self-test OK")
