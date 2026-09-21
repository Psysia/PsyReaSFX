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

local journal_replay = function_region(
  "function replay_database_journal(",
  "function write_database_asset_line("
)
assert(
  journal_replay:find("asset_journal_remap_values(", 1, true)
    and journal_replay:find("journal_fields,", 1, true)
    and journal_replay:find("require_asset_snapshot(state.database_changes)", 1, true),
  "legacy database journals must map fields by name and schedule a current snapshot"
)
assert(
  asset_view:find("ucs_asset_hierarchy(asset)", 1, true),
  "UCS directory filtering must resolve official hierarchy from CatID"
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
  ucs_sidebar:find('AppState.set("search", "")', 1, true),
  "activating a UCS directory must clear stale free-text search"
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
    and source:find("ucs_apply_search_suggestion(", 1, true)
    and source:find("ImGui.WindowFlags_NoFocusOnAppearing", 1, true),
  "toolbar must expose bounded UCS search suggestions"
)
local suggestion_window = function_region(
  "function draw_ucs_search_suggestion_popup(",
  "function draw_toolbar()"
)
assert(
  suggestion_window:find("ImGui.Begin(", 1, true)
    and suggestion_window:find("ImGui.End(ctx)", 1, true)
    and not suggestion_window:find("ImGui.BeginPopup(", 1, true)
    and not suggestion_window:find("ImGui.OpenPopup(", 1, true),
  "UCS search suggestions must use a non-modal window that preserves input focus"
)

local toolbar = function_region(
  "function draw_toolbar()",
  "function draw_sub_toolbar()"
)

local result_columns = function_region(
  "local COLUMN_DEFS = {",
  "function column_text(asset, key)"
)
assert(
  result_columns:find('key = "similarity"', 1, true)
    and result_columns:find('contextual = true', 1, true)
    and result_columns:find('"similar" == state.view', 1, true),
  "similarity results must expose an automatic contextual score column"
)
assert(
  source:find("function similarity_score_color(score)", 1, true)
    and source:find("function draw_similarity_score_bar(", 1, true)
    and source:find("0xE0524DFF", 1, true)
    and source:find("0xE7C447FF", 1, true)
    and source:find("0x43C96BFF", 1, true),
  "similarity scores must use a red-yellow-green bar"
)
local focus_at = assert(
  toolbar:find("if state.focus_search then", 1, true),
  "toolbar must support focusing the search input"
)
local input_at = assert(
  toolbar:find("ImGui.InputTextWithHint(", 1, true),
  "toolbar must render the search input"
)
local previous_item_at = assert(
  toolbar:find("ImGui.SetNextItemWidth(ctx, -267)", 1, true),
  "search input width marker is missing"
)
assert(
  toolbar:find('"ai_semantic"', 1, true)
    and toolbar:find("start_ai_semantic_search(state.search)", 1, true)
    and not toolbar:find("ai_semantic_popup_requested", 1, true),
  "toolbar AI button must directly search the shared query without a popup"
)
assert(
  not source:find("function draw_ai_semantic_popup()", 1, true)
    and source:find('settings_section_title(', 1, true)
    and source:find('"搜索框与 AI 按钮"', 1, true),
  "AI usage instructions must live in Settings instead of a search popup"
)
local ai_progress = function_region(
  "elseif visible_ai then",
  "elseif visible_similarity then"
)
assert(
  not ai_progress:find("ImGui.ProgressBar", 1, true),
  "AI phases should use one compact text status instead of animated progress bars"
)
assert(
  source:find("继续加载下一批 120 条", 1, true)
    and source:find("start_ai_semantic_next_page()", 1, true),
  "AI result view must expose the next 120-candidate page"
)
assert(
  source:find('definition.contextual and "similar" == state.view', 1, true)
    and not source:find('"AI 相关度"', 1, true),
  "AI results must not reuse the similar-sound relevance column"
)
assert(
  source:find("继续加载下一批完全在本地完成", 1, true)
    and not source:find('or phase == "rerank_wait"', 1, true),
  "AI paging must stay local without a remote reranking phase"
)
local ai_settings = function_region(
  "function draw_settings_ai()",
  "function color_edit_flags()"
)
assert(
  ai_settings:find('ImGui.Text(ctx, "API 地址")', 1, true)
    and ai_settings:find('"##ai_api_url"', 1, true)
    and ai_settings:find('ImGui.Text(ctx, "模型")', 1, true)
    and ai_settings:find('"##ai_model"', 1, true)
    and ai_settings:find('ImGui.Text(ctx, "新 API Key")', 1, true)
    and ai_settings:find('"##ai_api_key"', 1, true),
  "AI settings labels must render above full-width fields without right-edge clipping"
)
assert(
  ai_settings:find('"deepseek-flash"', 1, true)
    and ai_settings:find('"deepseek-v4-pro"', 1, true)
    and not ai_settings:find('"deepseek-chat"', 1, true)
    and not ai_settings:find('"deepseek-reasoner"', 1, true),
  "AI settings must expose the current DeepSeek API model IDs"
)
assert(
  ai_settings:find("state.ai_api_key_status", 1, true)
    and ai_settings:find("state.ai_api_key_status_error", 1, true),
  "API key save results must be visible inline in AI settings"
)
local search_matcher = function_region(
  "function matches_search(asset)",
  "function asset_in_view(asset)"
)
assert(
  search_matcher:find('if "ai_semantic" == state.view then return true end', 1, true),
  "AI results must retain the shared natural-language query without literal filtering"
)
assert(
  previous_item_at < focus_at and focus_at < input_at,
  "search focus must be requested immediately before the search input"
)

assert(
  source:find('"waveform_palette_table"', 1, true),
  "waveform palette must use a clipped-safe table layout"
)

local wave_job = function_region(
  "function read_waveform_from_source(",
  "function memory_wave_key("
)
local wave_queue = function_region(
  "function queue_wave(",
  "function process_wave_queue()"
)
assert(
  wave_queue:find("state.wave_queued[key] and priority", 1, true)
    and wave_queue:find("table.insert(state.wave_queue, 1, queued)", 1, true),
  "foreground waveform requests must promote an existing idle queued job"
)
assert(
  wave_job:find('job.phase = "read_wait"', 1, true)
    and wave_job:find("WAVE_READ_RETRY_LIMIT", 1, true)
    and wave_job:find("WAVE_READ_REOPEN_ATTEMPT", 1, true),
  "waveform reads must wait across frames and retry transient empty peaks"
)
assert(
  wave_job:find("spectral and 115 or 0", 1, true)
    and wave_job:find("retval & 0x1000000", 1, true),
  "spectral peaks must use REAPER's optional packed extra block"
)
assert(
  source:find('spectral and "|spectral-rwf4" or ""', 1, true)
    and source:find('"RWF4 "', 1, true)
    and source:find("state.spectral_peaks_enabled", 1, true),
  "spectral data must use an opt-in cache key and the RWF4 format"
)

assert(
  source:find('sounds = { zh = "素材", en = "SOUNDS" }', 1, true)
    and source:find('sidebar_section_label("libraries")', 1, true)
    and source:find('sidebar_section_label("activity")', 1, true),
  "sidebar section headings must switch explicitly between Chinese and English"
)
assert(
  source:find('category.name_zh .. " · " .. category.name', 1, true)
    and source:find('entry.subcategory_zh .. " · " .. entry.subcategory', 1, true),
  "Chinese UCS directory labels must remain bilingual"
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
