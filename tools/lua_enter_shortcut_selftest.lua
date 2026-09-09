local bootstrap_path = assert(
  arg[1],
  "usage: lua_enter_shortcut_selftest.lua <bootstrap> <catalog> <runtime-ui>"
)
local catalog_path = assert(arg[2], "missing catalog source")
local runtime_path = assert(arg[3], "missing runtime UI source")

local function read_all(path)
  local handle = assert(io.open(path, "rb"))
  local source = handle:read("*a")
  handle:close()
  return source
end

local bootstrap = read_all(bootstrap_path)
local catalog = read_all(catalog_path)
local runtime = read_all(runtime_path)

assert(
  bootstrap:find("enter_insert_shortcuts = false", 1, true),
  "Enter insertion shortcuts must default to disabled"
)

assert(
  runtime:find(
    "elseif%s+state%.enter_insert_shortcuts%s+and%s+ImGui%.IsKeyPressed%("
  ),
  "global Enter insertion must be guarded by the opt-in setting"
)

local toolbar_start = assert(
  runtime:find("function draw_toolbar()", 1, true),
  "missing draw_toolbar"
)
local toolbar_end = assert(
  runtime:find("function draw_sub_toolbar()", toolbar_start, true),
  "missing draw_toolbar end marker"
)
local toolbar = runtime:sub(toolbar_start, toolbar_end - 1)

assert(
  toolbar:find("ImGui.IsItemActive(ctx)", 1, true)
    and toolbar:find("ImGui.IsItemDeactivated(ctx)", 1, true)
    and toolbar:find(
      'AppState.set("keyboard_consumed", true)',
      1,
      true
    ),
  "search input must consume both active and deactivation frames"
)

local _, persisted_count = catalog:gsub(
  "enter_insert_shortcuts",
  ""
)
assert(
  persisted_count >= 2,
  "Enter shortcut preference must be loaded and saved"
)

print("Lua Enter shortcut self-test passed")
