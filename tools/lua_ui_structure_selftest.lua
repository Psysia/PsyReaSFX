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
  maintenance:find("start_ucs_reclassification_preview()", 1, true)
    and maintenance:find("start_ucs_reclassification_apply()", 1, true)
    and maintenance:find("查看 UCS 待确认素材", 1, true),
  "maintenance settings must expose UCS preview, apply and review actions"
)

local ucs_task = function_region(
  "function new_ucs_reclassification_counts()",
  "function queue_metadata("
)
assert(
  ucs_task:find("UCS_RECLASSIFY_FRAME_BUDGET", 1, true)
    and ucs_task:find("UCS_RECLASSIFY_ITEMS_PER_FRAME", 1, true),
  "existing-library UCS classification must remain frame-budgeted"
)
assert(
  ucs_task:find('phase = "preview"', 1, true)
    and ucs_task:find('phase = "apply"', 1, true)
    and ucs_task:find("ucs_assign_classification(asset, result)", 1, true),
  "existing-library UCS classification must keep preview/apply stages"
)
assert(
  ucs_task:find('reason == "manual"', 1, true)
    and ucs_task:find("session.counts.manual", 1, true),
  "UCS reclassification must preserve manual classifications"
)

local asset_view = function_region(
  "function asset_in_view(asset)",
  "local function cached_sort_text("
)
assert(
  asset_view:find('"ucs_pending" == state.view', 1, true)
    and asset_view:find('asset.ucs_status ~= "pending"', 1, true),
  "UCS review queue must filter to pending assets"
)
assert(
  asset_view:find('"ucs_category" == state.view', 1, true)
    and asset_view:find('"ucs_subcategory" == state.view', 1, true)
    and asset_view:find('"ucs_catid" == state.view', 1, true),
  "UCS virtual-directory levels must filter the catalog"
)

local ucs_sidebar = function_region(
  "function activate_ucs_filter(",
  "function activate_folder_path("
)
assert(
  ucs_sidebar:find("UcsCatalog.category_order", 1, true)
    and ucs_sidebar:find("ucs_subcategory_count_key", 1, true)
    and ucs_sidebar:find("activate_ucs_filter(", 1, true),
  "sidebar must expose Category, SubCategory and CatID UCS navigation"
)
assert(
  source:find("process_ucs_count_rebuild()", 1, true)
    and source:find("step_ucs_count_job(", 1, true),
  "UCS sidebar counts must rebuild through the incremental cache job"
)
assert(
  source:find("function confirm_ucs_candidate(", 1, true)
    and source:find("function undo_last_ucs_confirmation(", 1, true)
    and source:find("draw_ucs_candidate_actions(primary)", 1, true),
  "pending UCS candidates must support confirmation and bounded undo"
)
assert(
  source:find("function draw_ucs_search_suggestion_popup(", 1, true)
    and source:find("ucs_search_suggestions(", 1, true)
    and source:find("ucs_apply_search_suggestion(", 1, true),
  "toolbar must expose bounded UCS search suggestions"
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
