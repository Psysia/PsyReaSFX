local function read(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  return source
end
local function section(source, first, last)
  local at = assert(source:find(first, 1, true), first)
  local stop = assert(source:find(last, at + #first, true), last)
  return source:sub(at, stop - 1)
end
local source = read(arg[1] or "src/lua/48_webview.lua")
local core = read("src/lua/10_ui_core.lua")
local definitions = { { key = "description" }, { key = "keywords" }, { key = "library" } }
local assets = {}
state = { metadata_editor = {}, workspace_tab_active = "fixture" }
SelectionIndex = { revision = 1 }
WebUI = { handlers = {}, revision = 0 }
function selected_assets() return assets end
function metadata_edit_fields() return definitions end
function writable() end
function text(value, maximum) return value:sub(1, maximum or 4096) end
function sync_metadata_editor() state.metadata_editor.values, state.metadata_editor.enabled = {}, {} end
function apply_metadata_editor(items)
  for _, item in ipairs(items) do
    for key, enabled in pairs(state.metadata_editor.enabled) do
      if enabled then item[key] = state.metadata_editor.values[key] end
    end
  end
end
local code = section(source, "local function metadata_selection()", 'WebUI.handlers["metadata.get"]')
assert(load(code))()
assets = { { path = "first", description = "shared" }, { path = "last", description = "shared" } }
local old = WebUI.handlers["metadata.selection"]({})
local current = WebUI.handlers["metadata.selection"]({})
assert(old.token ~= current.token, "editor tokens must be unique even for identical metadata")
assert(not pcall(WebUI.handlers["metadata.batch"], { token = old.token, count = 2, values = { keywords = "stale" } }),
  "an older editor must not authorize a batch save")
assets[2].description = "changed underneath"
assert(not pcall(WebUI.handlers["metadata.batch"], { token = current.token, count = 2, values = { keywords = "stale" } }),
  "full value comparisons must detect concurrent metadata updates")
current = WebUI.handlers["metadata.selection"]({})
WebUI.handlers["metadata.batch"]({ token = current.token, count = 2, values = { keywords = "committed" } })
assert(assets[1].keywords == "committed" and assets[2].keywords == "committed" and not WebUI.metadata_edit)

local count = tonumber(arg[3]) or 1000
local long = string.rep("x", 8192)
assets = {}
for index = 1, count do assets[index] = { path = "fixture/" .. index, description = long, keywords = "shared", library = "test" } end
collectgarbage("collect")
local memory = collectgarbage("count")
local started = os.clock()
current = WebUI.handlers["metadata.selection"]({})
local capture_time = os.clock() - started
local snapshot_memory = collectgarbage("count") - memory
started = os.clock()
WebUI.handlers["metadata.batch"]({ token = current.token, count = count, values = {} })
local validate_time = os.clock() - started
print(string.format("Metadata snapshot: %d assets, capture %.4fs, validation %.4fs, snapshot %.1f KiB", count, capture_time, validate_time, snapshot_memory))
if arg[2] then
  -- Optional historical benchmark: compare the production implementation
  -- before this change using the same values, runtime and asset objects.
  local baseline = read(arg[2])
  assert(load(section(core, "function fnv1a_feed(", "function fnv1a(")))()
  local capture = assert(load(section(baseline, "local function metadata_selection()", 'WebUI.handlers["metadata.selection"]') .. "\nreturn metadata_selection"))()
  started = os.clock()
  capture()
  print(string.format("Historical byte-hash capture: %.4fs", os.clock() - started))
end
print("Metadata snapshot passed: editor identity, complete conflict validation and snapshot release")
