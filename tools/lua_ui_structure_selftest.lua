local source_path = assert(arg[1], "usage: lua_ui_structure_selftest.lua <runtime-ui-source>")
local handle = assert(io.open(source_path, "rb"))
local source = handle:read("*a")
handle:close()

local function count(pattern)
  local total = 0
  for _ in source:gmatch(pattern) do total = total + 1 end
  return total
end

local function function_region(start_marker, end_marker)
  local start_at = assert(source:find(start_marker, 1, true), "missing start marker: " .. start_marker)
  local end_at = assert(source:find(end_marker, start_at + #start_marker, true), "missing end marker: " .. end_marker)
  return source:sub(start_at, end_at - 1)
end

assert(
  count("ImGui%.BeginChild%(") == count("ImGui%.EndChild%(") ,
  "BeginChild/EndChild source counts differ"
)

local appearance = function_region(
  "function draw_settings_appearance()",
  "function draw_settings_waveforms()"
)
assert(
  not appearance:find("ImGui.BeginChild(", 1, true),
  "settings appearance must not nest Child windows inside settings_content"
)

local maintenance = function_region(
  "function draw_settings_maintenance()",
  "function settings_nav_item("
)
assert(
  not maintenance:find("ImGui.BeginChild(", 1, true),
  "settings maintenance must not nest Child windows inside settings_content"
)

assert(
  source:find('"waveform_palette_table"', 1, true),
  "waveform palette must use a clipped-safe table layout"
)

print("Lua UI structure self-test passed")
