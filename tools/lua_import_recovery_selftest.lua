local path = assert(arg[1], "runtime source required")
local file = assert(io.open(path, "rb"))
local source = file:read("*a")
file:close()
local function region(first, following)
  local at = assert(source:find(first, 1, true))
  local last = assert(source:find(following, at + #first, true))
  return source:sub(at, last - 1)
end
IMPORT_RECOVERY_ASSETS_PER_FRAME = 2
local scan_calls, writes, starts = 0, 0, 0
function path_key(path) return path:lower() end
function can_run_heavy_job() return true end
function root_for_path(path)
  if path:find("disabled", 1, true) then return "disabled", { enabled = false } end
  return "library", { enabled = true }
end
function start_scan() scan_calls = scan_calls + 1 end
function load_scan_checkpoint() return nil end
Jobs = { active = {}, begin = function() starts = starts + 1 return {} end }
reaper = { time_precise = function() return 1 end }
AppState = { set = function(key, value) state[key] = value end }
assert(load(region("function start_import_recovery_audit()", "function start_scan(")))()
state = { roots = { "library" }, resume_scan_on_start = true, failed_tasks = {}, assets = {
  { path = "done.wav", ready = true },
  { path = "pending.wav", ready = false },
  { path = "failed.wav", ready = false },
  { path = "disabled.wav", ready = false },
  { path = "pending2.wav", ready = false },
} }
state.failed_tasks[path_key("failed.wav")] = { reason = "known failure" }
start_import_recovery_audit()
process_import_recovery_audit()
assert(state.import_recovery_audit and not state.import_session, "audit must remain incremental")
while state.import_recovery_audit do process_import_recovery_audit() end
assert(scan_calls == 0, "indexed unfinished assets must never rescan source folders")
assert(starts == 1 and state.import_session.total == 2)
assert(state.import_session.assets[1].path == "pending.wav")
assert(state.import_session.assets[2].path == "pending2.wav")
assert(state.import_session.silent and state.import_session.compact_status)
assert(not state.assets[2].pending_batch, "recovery must not hide existing assets")
state.import_session = nil
state.resume_scan_on_start = false
start_import_recovery_audit()
assert(not state.import_recovery_audit, "startup recovery switch must apply to automatic audits")

assert(load(region("function cleanup()", "reaper.atexit(cleanup)")))()
local closed = 0
state = { startup_session = { reader = { close = function() closed = closed + 1 end } } }
Jobs.stop_accepting = function() writes = writes + 1 end
function save_database() writes = writes + 1 end
cleanup()
assert(closed == 1 and writes == 0, "closing during loading must close reads without saving a partial catalog")

-- ReaImGui ends hidden windows internally; call End only for visible windows.
local ended, drawn = 0, 0
function push_theme() return 0, 0 end
function pop_theme() end
function translate_ui_text(value) return value end
ImGui = {
  SetNextWindowSize = function() end,
  Cond_FirstUseEver = 1, WindowFlags_NoCollapse = 1,
  WindowFlags_NoScrollbar = 2, WindowFlags_NoScrollWithMouse = 4,
  Begin = function() return true, true end,
  End = function() ended = ended + 1 end,
  Text = function() drawn = drawn + 1 end,
  TextDisabled = function() end,
}
SCRIPT_NAME, VERSION = "PsyReaSFX", "test"
assert(load(region("function draw_main()", "function autosave()")))()
state = { open = true, assets = {}, startup_session = { phase = "loading" } }
draw_main()
assert(ended == 1 and drawn == 1)
ImGui.Begin = function() return false, true end
draw_main()
assert(ended == 1, "ReaImGui hidden windows must not receive an extra End")
ImGui.Begin = function() return true, true end
local rows = 0
ImGui.Separator = function() end
ImGui.BeginTable = function() return true end
ImGui.EndTable = function() end
ImGui.TableSetupColumn = function() end
ImGui.TableHeadersRow = function() end
ImGui.TableNextRow = function() rows = rows + 1 end
ImGui.TableSetColumnIndex = function() end
state.startup_session.started_at = 0
for index = 1, 50 do state.assets[index] = { name = "asset", duration = 1 } end
draw_main()
assert(rows == 12 and ended == 2, "startup preview must stay bounded and balance the visible window")
assert(load(region("function process_startup()", "function loop()")))()
local now = 10
state.watch_interval = 60
reaper.time_precise = function() return now end
reaper.GetPlayState = function() return 0 end
local function loading() coroutine.yield() coroutine.yield() end
state.startup_session = { thread = coroutine.create(loading) }
process_startup()
assert(math.abs(state.startup_session.deadline - 10.024) < 0.0001)
reaper.GetPlayState = function() return 1 end
process_startup()
assert(math.abs(state.startup_session.deadline - 10.012) < 0.0001, "playing transport must retain shorter work budget")
process_startup()
assert(not state.startup_session, "finished startup must unlock normal UI")
print("Lua import recovery and loading lifecycle self-test passed")
