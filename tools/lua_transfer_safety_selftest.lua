local source_path = arg[1] or "src/lua/50_runtime_ui.lua"
local file = assert(io.open(source_path, "rb"))
local source = file:read("*a")
file:close()
local function load_region(first, last)
  local at = assert(source:find(first, 1, true), first)
  local stop = assert(source:find(last, at + #first, true), last)
  assert(load(source:sub(at, stop - 1), "@" .. source_path, "t", _ENV))()
end
SEP = "\\"
function trim(value) return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
function normalize_slashes(value) return (tostring(value or ""):gsub("/", "\\")) end
function path_key(value) return normalize_slashes(value):lower() end
function join_path(first, last) return first:gsub("[\\/]+$", "") .. "\\" .. last end
function transfer_format_info() return "wav" end
function clamp(value, first, last) return math.max(first, math.min(last, value)) end
function translate_ui_text(value) return value end
function expand_transfer_template(asset) return asset.name end
local exists = {}
reaper = { file_exists = function(path) return exists[path_key(path)] == true end }
state = { transfer_dir = "C:\\Library", transfer_collision = "overwrite", by_path = {} }
load_region("function transfer_path_key(", "function capture_transfer_context()")
local asset = { path = "C:\\Library\\source.wav", name = "source" }
state.by_path[path_key(asset.path)] = asset
exists[path_key(asset.path)] = true
local output, collision = resolve_transfer_output(asset, 1, {})
assert(not output and collision == "source", "overwrite export must not replace its source")
state.transfer_dir = "C:\\Library\\sub\\.."
output, collision = resolve_transfer_output(asset, 1, {})
assert(not output and collision == "source", "dot segments must not bypass source protection")
state.transfer_dir = "\\\\?\\C:\\Library"
output, collision = resolve_transfer_output(asset, 1, {})
assert(not output and collision == "source", "extended path prefixes must not bypass source protection")
local other = { path = "C:\\Library\\other.wav", name = "other" }
state.by_path[path_key(other.path)] = other
state.transfer_dir = "C:\\Library"
asset.name = "other"
output, collision = resolve_transfer_output(asset, 1, {})
assert(not output and collision == "source", "another catalog source must also be protected, even offline")
asset.name = "export"
output, collision = resolve_transfer_output(asset, 1, {})
assert(output == "C:\\Library\\export.wav" and collision == "new")
load_region("function parse_transfer_variant_values(", "function build_transfer_variants()")
for _, invalid in ipairs({ "1e999", "-1e999", "NaN", "Infinity" }) do
  assert(not parse_transfer_variant_values(invalid, 0, -48, 48, 2, "Pitch"),
    "non-finite variation values must not be clamped into a valid export")
end

-- A running batch owns its settings. UI edits between files must not change
-- the next file's output, sample rate, fades or audition/selection parameters.
function capture_transfer_settings()
  return { transfer_dir = "C:\\New", pitch = 9, region_start = 0.7 }
end
AppState = { apply = function(values) for key, value in pairs(values) do state[key] = value end end }
local rendered = {}
function render_transfer_asset(task)
  rendered[#rendered + 1] = { state.transfer_dir, state.pitch, state.region_start }
  return true, state.transfer_dir .. "\\out.wav", "OK", false
end
function set_status() end
function translate_ui_text(value) return value end
reaper.time_precise = os.clock
reaper.GetPlayStateEx = function() return 0 end
load_region("function process_transfer_job()", "function run_transfer(")
state.transfer_dir, state.pitch, state.region_start = "C:\\New", 9, 0.7
local task = { asset = { name = "fixture" }, variant = {} }
state.transfer_job = { tasks = { task, task }, next_index = 1, completed = 0, total = 2,
  success_count = 0, failures = {}, records = {}, settings = { transfer_dir = "C:\\Captured", pitch = 2, region_start = 0.2 } }
state.transfer_last_outputs = {}
process_transfer_job()
assert(rendered[1][1] == "C:\\Captured" and rendered[1][2] == 2 and rendered[1][3] == 0.2,
  "batch rendering must use the parameters captured at submission")
assert(state.transfer_dir == "C:\\New" and state.pitch == 9 and state.region_start == 0.7,
  "captured rendering must restore the user's later settings")
render_transfer_asset = function() error("fixture failure") end
process_transfer_job()
assert(state.transfer_dir == "C:\\New" and state.pitch == 9 and state.region_start == 0.7,
  "a failed batch render must also restore the user's later settings")
print("Transfer safety passed: source protection, path aliases and immutable batch parameters")
