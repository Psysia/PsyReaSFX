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
function fit_text_to_width(value) return value end
function rgba_with_alpha(color, alpha) return (color & 0xffffff00) | alpha end
COLOR = { panel = 1, panel_alt = 2, button = 3, border = 4,
  header_text = 5, accent = 0x66ddffff, dim = 7, text = 8, error = 9 }
local viewport_w, viewport_h = 1360, 800
local bars, coordinates, labels = 0, {}, {}
ImGui = {
  SetNextWindowSize = function() end,
  Cond_FirstUseEver = 1, WindowFlags_NoCollapse = 1,
  WindowFlags_NoScrollbar = 2, WindowFlags_NoScrollWithMouse = 4,
  Begin = function() return true, true end,
  End = function() ended = ended + 1 end,
  Text = function() drawn = drawn + 1 end,
  TextDisabled = function() end,
  TextWrapped = function(value, text) labels[#labels + 1] = text end,
  GetContentRegionAvail = function() return viewport_w, viewport_h end,
  GetCursorScreenPos = function() return 0, 0 end,
  GetWindowDrawList = function() return {} end,
  Dummy = function() end,
  CalcTextSize = function(_, value) return #value * 8, 18 end,
  DrawList_AddText = function(_, x, y, _, value) labels[#labels + 1] = value end,
  DrawList_AddRectFilled = function() end,
  DrawList_AddRect = function() end,
  DrawList_AddQuadFilled = function() end,
  DrawList_AddQuad = function() end,
  DrawList_AddLine = function(_, x1, y1, x2, y2)
    bars = bars + 1
    coordinates[#coordinates + 1] = { x1, y1, x2, y2 }
    assert(x1 >= 0 and x2 <= viewport_w and y1 >= 0 and y2 <= viewport_h, "splash must fit viewport")
  end,
}
SCRIPT_NAME, VERSION = "PsyReaSFX", "test"
assert(load(region("function draw_brand_symbol(", "function draw_brand_mark(")))()
assert(load(region("function draw_startup_splash(session)", "function draw_main()")))()
assert(load(region("function draw_main()", "function autosave()")))()
state = { open = true, assets = {}, startup_session = { phase = "loading" } }
draw_main()
assert(ended == 1 and bars == 55, "splash must use a fixed 48 waveform bars and 7 logo bars")
ImGui.Begin = function() return false, true end
draw_main()
assert(ended == 1, "ReaImGui hidden windows must not receive an extra End")
ImGui.Begin = function() return true, true end
state.startup_session.started_at = 0
for index = 1, 50 do state.assets[index] = { name = "asset", duration = 1 } end
local earlier_y = coordinates[20][2]
bars, coordinates, labels = 0, {}, {}
draw_main()
assert(bars == 55 and ended == 2, "splash cost must not grow with catalog size")
assert(coordinates[20][2] ~= earlier_y, "waveform must move with elapsed time")
assert(table.concat(labels, "|"):find("已读取 50 条素材", 1, true), "real counts must remain visible")
viewport_w, viewport_h = 300, 300
bars = 0
draw_main()
assert(bars == 55, "minimum splash layout must fit")
viewport_w = 220
bars = 0
draw_main()
assert(bars == 0 and drawn == 1, "tiny windows must use readable text fallback")
viewport_w, viewport_h = 1360, 800
state.startup_session.failure = "fixture loading error"
bars, labels = 0, {}
draw_main()
assert(bars == 0 and labels[1] == "fixture loading error", "failed startup must stop motion and show diagnostics")
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
