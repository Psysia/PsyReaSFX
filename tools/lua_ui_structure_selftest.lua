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

local folder_browser = function_region(
  "function folder_hover_branch_open(",
  "function active_path_condition_label()"
)
assert(
  not folder_browser:find("ImGui.BeginMenu(", 1, true),
  "folder hierarchy must remain in one popup instead of directional submenus"
)
assert(
  folder_browser:find("draw_folder_hover_row(", 1, true)
    and folder_browser:find("ImGui.Selectable(", 1, true),
  "folder hierarchy must use inline hover rows"
)

local scan_start = function_region(
  "function start_scan(reason, roots_override, options)",
  "function finish_scan()"
)
assert(
  scan_start:find("checkpoint_enabled = checkpoint_enabled", 1, true),
  "catalog scans must carry an explicit checkpoint policy"
)

local watch = function_region(
  "function watch_folders()",
  "function cleanup()"
)
assert(
  watch:find("checkpoint_enabled = false", 1, true),
  "Watch Folder scans must not create startup recovery checkpoints"
)

local main_window = function_region(
  "function draw_main()",
  "refresh_current_project_binding()"
)
assert(
  main_window:find('AppState.set("clean_shutdown_requested", true)', 1, true),
  "closing the main window must be marked as a clean shutdown"
)

print("Lua UI structure self-test passed")
