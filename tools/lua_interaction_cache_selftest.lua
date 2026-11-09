-- Interaction caches: selection index, inspector list/editor sync, directory
-- reachability cache, artwork existence cache and LRU trim, theme gating and
-- short-lived counters. These sit on the per-frame path, so each one must
-- (a) keep returning the right answer after every kind of change and
-- (b) stop doing the expensive work on repeated frames.
local runtime_path = assert(arg[1], "runtime UI module is required")
local core_path = assert(arg[2], "UI core module is required")
local catalog_path = assert(arg[3], "catalog module is required")

local function read(path)
  local handle = assert(io.open(path, "rb"))
  local text = handle:read("*a")
  handle:close()
  return text
end
local function region(source, first, following)
  local at = assert(source:find(first, 1, true), first)
  local last = assert(source:find(following, at + #first, true), following)
  return source:sub(at, last - 1)
end
local runtime, core, catalog = read(runtime_path), read(core_path), read(catalog_path)

SEP = "/"
function path_key(path) return (tostring(path or ""):gsub("\\", "/"):lower()) end
function clamp(value, minimum, maximum) return math.max(minimum, math.min(maximum, value)) end
function trim(value) return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

assert(load(region(core, "FNV1A_OFFSET = 2166136261", "function mark_interaction()")))()
assert(load(region(catalog, "function asset_path_sort_key(asset)", "function invalidate_ucs_counts()")))()
assert(load(region(runtime, "SelectionIndex = SelectionIndex or", "function select_all_results()")))()
assert(load(region(runtime, "local METADATA_EDIT_FIELDS = {", "function apply_metadata_editor(assets)")))()

-- ---------------------------------------------------------------- selection
local function make_assets(count)
  local assets, by_path = {}, {}
  for index = 1, count do
    local asset = { path = string.format("C:/Lib/File%05d.wav", index), name = "n" .. index,
      description = "d" .. index, indexed = true }
    assets[index] = asset
    by_path[path_key(asset.path)] = asset
  end
  return assets, by_path
end

local assets, by_path = make_assets(50)
state = {
  results = assets, by_path = by_path, selected_set = {}, selected_index = 0,
  selected_path = nil, selection_anchor = 0,
  metadata_editor = { signature = "", values = {}, enabled = {}, mixed = {} },
}

local function key_of(index) return path_key(assets[index].path) end

assert(#selected_assets() == 0 and selected_count() == 0)
selection_add(key_of(7)); selection_add(key_of(3)); selection_add(key_of(40))
local visible = selected_assets()
assert(#visible == 3 and visible[1] == assets[3] and visible[2] == assets[7] and visible[3] == assets[40],
  "selected assets come back in result order")
assert(selected_assets() == visible, "an unchanged selection returns the cached array")
assert(selected_count() == 3)
selection_add(key_of(7))
assert(selected_assets() == visible, "adding an already selected key changes nothing")
selection_remove(key_of(3))
assert(selected_assets() ~= visible and selected_count() == 2, "removal invalidates the cache")
selection_add("c:/not/in/results.wav")
assert(selected_count() == 2, "keys outside the results are not counted or returned")
assert(is_row_selected(assets[7]) and not is_row_selected(assets[8]))

local before_tab_switch = selected_assets()
state.selected_set = { [key_of(1)] = true }          -- a tab switch swaps the table
assert(selected_assets() ~= before_tab_switch and #selected_assets() == 1 and selected_assets()[1] == assets[1])
local replaced_results = { assets[2], assets[1] }
state.results = replaced_results
assert(#selected_assets() == 1, "a new results table invalidates the visible selection")
state.results = assets
selection_replace({ [key_of(5)] = true, [key_of(6)] = true })
assert(selected_count() == 2)
clear_row_selection()
assert(selected_count() == 0 and state.selected_index == 0 and state.selected_path == nil)

-- Inspector list: cached, sorted by key, re-validated for small selections.
selection_replace({ [key_of(9)] = true, [key_of(2)] = true, [key_of(30)] = true })
local fast = selected_assets_fast()
assert(#fast == 3 and fast[1] == assets[2] and fast[2] == assets[9] and fast[3] == assets[30])
assert(selected_assets_fast() == fast, "inspector list is cached while nothing changes")
local replacement = { path = assets[9].path, name = "replacement", indexed = true }
by_path[key_of(9)] = replacement
local refreshed = selected_assets_fast()
assert(refreshed ~= fast and refreshed[2] == replacement,
  "a replaced asset object must not be served from the cache")
by_path[key_of(9)] = assets[9]

-- Nothing selected: the focused row is the inspector's asset.
selection_replace({})
state.selected_index = 4
local focused = selected_assets_fast()
assert(#focused == 1 and focused[1] == assets[4])
state.selected_index = 5
assert(selected_assets_fast()[1] == assets[5], "moving focus must refresh the inspector list")
state.selected_index = 0

-- Large selection: not sorted, but the first entry is still the smallest key.
local big_assets, big_by_path = make_assets(3000)
state.results, state.by_path = big_assets, big_by_path
local big_set = {}
for index = 3000, 1, -1 do big_set[path_key(big_assets[index].path)] = true end
selection_replace(big_set)
local big = selected_assets_fast()
assert(#big == 3000 and big[1] == big_assets[1], "primary asset of a large selection is the smallest key")
assert(selected_assets_fast() == big)
state.results, state.by_path = assets, by_path

-- ----------------------------------------------------- metadata editor sync
SelectionIndex.meta_epoch = 0
selection_replace({ [key_of(10)] = true })
local single = selected_assets_fast()
sync_metadata_editor(single)
local editor = state.metadata_editor
assert(editor.values.description == "d10" and editor.enabled.description == true)
local identity_1, stamp_1 = metadata_selection_signature(single)
assert(select(1, metadata_selection_signature(single)) == identity_1, "signature is cached per epoch")

editor.values.description = "typed by the user"
assets[10].keywords = "fresh keywords"           -- background indexing finished underneath
assets[10].indexed = false
SelectionIndex.meta_epoch = SelectionIndex.meta_epoch + 1
sync_metadata_editor(single)
assert(editor.values.description == "typed by the user", "an edit in progress survives a refresh")
assert(editor.values.keywords == "fresh keywords", "untouched fields pick up the new value")

selection_replace({ [key_of(11)] = true })
sync_metadata_editor(selected_assets_fast())
assert(editor.values.description == "d11", "a different selection reloads every field")
selection_replace({ [key_of(11)] = true, [key_of(12)] = true })
sync_metadata_editor(selected_assets_fast())
assert(editor.enabled.description == false and editor.mixed.description == true,
  "multi-selection fields start disabled and flagged as mixed")

-- -------------------------------------------------------- count memo (core)
assert(load(region(core, "CountPathSetMemo = CountPathSetMemo or", "function copy_path_set(values)")))()
local counted = { a = true, b = true }
assert(count_path_set(counted) == 2)
counted.c = true
assert(count_path_set(counted) == 2, "a count is reused for a short moment")
assert(count_path_set(counted, true) == 3, "fresh=true always recounts")
assert(count_path_set(counted) == 3)
assert(count_path_set(nil) == 0)

-- ------------------------------------------------- directory reachability
assert(load(region(core, "DirectoryOnline = DirectoryOnline or", "function directory_exists(path)")))()
local probes = {}
local reachable = { ["C:/Lib/A"] = true, ["Z:/Offline"] = false }
function directory_exists(path) probes[#probes + 1] = path return reachable[path] == true end
assert(directory_online("C:/Lib/A") == true and directory_online("Z:/Offline") == true,
  "an unknown folder is assumed reachable until probed")
for _ = 1, 50 do directory_online("C:/Lib/A") end
assert(#probes == 0, "drawing must never touch the filesystem")
assert(directory_online_pump() == true and #probes == 1, "one probe per pump")
assert(directory_online_pump() == true and #probes == 2)
assert(directory_online_pump() == false)
assert(directory_online("C:/Lib/A") == true and directory_online("Z:/Offline") == false)
for _ = 1, 20 do directory_online("Z:/Offline") end
assert(directory_online_pump() == false and #probes == 2, "fresh answers are not probed again")
DirectoryOnline.entries["Z:/Offline"].checked = 0
reachable["Z:/Offline"] = true
directory_online("Z:/Offline")
directory_online_pump()
assert(directory_online("Z:/Offline") == true, "an expired answer is refreshed in the background")
directory_online_forget()
assert(next(DirectoryOnline.entries) == nil and #DirectoryOnline.pending == 0)

-- --------------------------------------------------- artwork existence cache
assert(load(region(runtime, "ArtworkExists = ArtworkExists or", "function root_record_for_asset(asset)")))()
local file_checks = 0
local existing = { ["C:/Art/cover.png"] = true }
reaper = { file_exists = function(path) file_checks = file_checks + 1 return existing[path] == true end }
for _ = 1, 200 do assert(valid_artwork_path("C:/Art/cover.png")) end
assert(file_checks == 1, "an existing cover is probed once, not per frame")
for _ = 1, 50 do assert(not valid_artwork_path("C:/Art/missing.png")) end
assert(file_checks == 2)
assert(not valid_artwork_path("") and not valid_artwork_path("-") and not valid_artwork_path(nil))
ArtworkExists.entries["C:/Art/missing.png"].checked = os.time() - 10
existing["C:/Art/missing.png"] = true
assert(valid_artwork_path("C:/Art/missing.png"), "a restored cover is found after the short recheck window")

-- LRU trim: the least recently used image goes first, never the busiest one.
ImGui = { ValidatePtr = function() return false end, Detach = function() end }
state.artwork_image_limit = 3
state.artwork_images = {}
state.artwork_image_order = {}
for index, name in ipairs({ "a", "b", "c", "d" }) do
  state.artwork_images[name] = { image = {}, last_used = ({ 100, 5, 90, 80 })[index] }
  state.artwork_image_order[index] = name
end
assert(load(region(runtime, "function release_artwork_image(key)", "ArtworkKeyMemo = ArtworkKeyMemo or")))()
trim_artwork_image_cache()
assert(state.artwork_images.b == nil and state.artwork_images.a ~= nil,
  "the oldest-used image is evicted even though it was inserted second")
assert(#state.artwork_image_order == 3)
assert(load(region(runtime, "ArtworkKeyMemo = ArtworkKeyMemo or", "ArtworkCreateBudget = ArtworkCreateBudget or")))()
assert(artwork_cache_key("C:\\Art\\Cover.PNG") == path_key("C:\\Art\\Cover.PNG"))

-- ------------------------------------------------------------ theme gating
local applied = { density = 0, palette = 0, surface = 0 }
function ui_font_size() return state.font_size end
function apply_ui_density_metrics() applied.density = applied.density + 1 end
function apply_theme_palette() applied.palette = applied.palette + 1 end
function apply_surface_style() applied.surface = applied.surface + 1 end
assert(load(region(runtime, "THEME_INPUT_FIELDS = {", "-- {ImGui color slot")))()
state.font_size = 13
state.ui_density, state.surface_style, state.theme_preset = "compact", "dark", "dark"
for _ = 1, 30 do apply_theme_if_changed() end
assert(applied.density == 1 and applied.palette == 1 and applied.surface == 1,
  "the theme is applied once while its inputs are unchanged")
state.theme_preset = "custom"
apply_theme_if_changed()
assert(applied.palette == 2, "a changed preset re-applies the theme")
state.font_size = 14
apply_theme_if_changed()
assert(applied.palette == 3, "a changed font size re-applies the theme")
state.waveform_hex = "#FFFFFF"
apply_theme_if_changed()
assert(applied.palette == 4, "a changed waveform colour re-applies the theme")
apply_theme_if_changed()
assert(applied.palette == 4)

-- --------------------------------------------- wave key memo (size probing)
local size_probes = 0
function file_size() size_probes = size_probes + 1 return 0 end
assert(load(region(runtime, "function wave_cache_key(", "function wave_cache_path(")))()
local missing_asset = { path = "C:/Gone/missing.wav", size = 0 }
local first_key = wave_cache_key(missing_asset, 256, false, false)
for _ = 1, 100 do assert(wave_cache_key(missing_asset, 256, false, false) == first_key) end
assert(size_probes == 1, "an unreadable file is re-probed at most every 15 s, not every frame")
local other_key = wave_cache_key(missing_asset, 512, false, false)
assert(other_key ~= first_key and wave_cache_key(missing_asset, 256, true, false) ~= first_key)
missing_asset.path = "C:/Gone/renamed.wav"
assert(wave_cache_key(missing_asset, 256, false, false) ~= first_key, "a changed path changes the key")

-- ------------------------------------------------ window motion and its LOD
do
  local clock = 100
  reaper = { time_precise = function() return clock end, file_exists = function() return true end }
  local interactions = 0
  function mark_interaction() interactions = interactions + 1 end
  local window = { x = 10, y = 20, w = 800, h = 600 }
  ImGui = {
    GetWindowPos = function() return window.x, window.y end,
    GetWindowSize = function() return window.w, window.h end,
  }
  assert(load(region(runtime, "UiMotion = UiMotion or", "function draw_main()")))()

  ui_track_window_motion()
  assert(not ui_in_motion(), "the first frame only records the geometry")
  ui_track_window_motion()
  assert(not ui_in_motion() and interactions == 0, "an unchanged window is not moving")
  window.x = 14
  ui_track_window_motion()
  assert(ui_in_motion() and interactions == 1, "a moved window enters motion mode and pauses background work")
  clock = clock + UI_MOTION_HOLD * 0.5
  assert(ui_in_motion(), "motion mode lasts a moment after the last change")
  clock = clock + UI_MOTION_HOLD
  assert(not ui_in_motion(), "and ends once the window has been still")
  window.h = 640
  ui_track_window_motion()
  assert(ui_in_motion(), "resizing counts as motion")

  -- Mini waveforms: full detail at rest, a coarse envelope that keeps every
  -- peak while the window moves.
  COLOR = { waveform_bg = 1, grid = 2 }
  local lines, rects = 0, 0
  ImGui.DrawList_AddRectFilled = function() rects = rects + 1 end
  ImGui.DrawList_AddLine = function() lines = lines + 1 end
  assert(load(region(runtime, "UI_MOTION_WAVE_COLUMNS = 48", "function reset_wave_view()")))()
  local peaks, loudest = {}, 0
  for index = 1, 256 do
    peaks[index] = ((index * 37) % 101) / 100
    if peaks[index] > loudest then loudest = peaks[index] end
  end
  local wave = { count = 256, peaks = peaks }
  clock = clock + 10                                    -- at rest
  lines = 0
  draw_waveform({}, wave, 0, 0, 300, 20, 3)
  assert(lines == 1 + 256 or lines == 1 + 255 or lines == 1 + 256, "at rest every stored point is drawn: " .. lines)
  window.x = window.x + 1
  ui_track_window_motion()                              -- motion
  lines = 0
  draw_waveform({}, wave, 0, 0, 300, 20, 3)
  assert(lines == 1 + UI_MOTION_WAVE_COLUMNS, "motion draws a coarse envelope: " .. lines)
  local coarse = wave.reduced_columns.by_columns[UI_MOTION_WAVE_COLUMNS]
  local coarse_peak = 0
  for _, value in ipairs(coarse) do if value > coarse_peak then coarse_peak = value end end
  assert(coarse_peak == loudest, "the coarse envelope keeps the loudest peak")
  lines = 0
  draw_waveform({}, wave, 0, 0, 30, 20, 3)             -- narrow column: no extra reduction needed
  assert(lines <= 1 + 30)
  clock = clock + 10
  lines = 0
  draw_waveform({}, wave, 0, 0, 300, 20, 3)
  assert(lines >= 1 + 255, "full detail returns when the window is still")

  -- The detail waveform groups three pixels per drawn column while moving.
  do
    function preview_channel_is_selected() return true end
    function rgba_with_alpha(color) return color end
    COLOR.border, COLOR.accent, COLOR.dim, COLOR.window = 5, 6, 7, 8
    function preview_channel_label() return "L" end
    state.spectral_peaks_enabled = false
    ImGui.DrawList_AddText = function() end
    assert(load(region(runtime, "function draw_waveform_window(", "function draw_wave_time_ruler(")))()
    local detail_peaks = {}
    for index = 1, 2048 do detail_peaks[index] = ((index * 53) % 97) / 100 end
    local detail = { count = 2048, peaks = detail_peaks }
    local widths, tallest = {}, {}
    ImGui.DrawList_AddLine = function(_, _, y1, _, y2, _, thickness)
      widths[#widths + 1] = thickness
      tallest[#tallest + 1] = math.abs(y2 - y1)
    end
    clock = clock + 10
    widths, tallest = {}, {}
    draw_waveform_window({}, detail, {}, 0, 0, 900, 120, 3, 0, 1)
    local at_rest = #widths
    assert(at_rest >= 900, "one column per pixel at rest: " .. at_rest)
    window.w = window.w + 7
    ui_track_window_motion()
    assert(ui_in_motion())
    widths, tallest = {}, {}
    draw_waveform_window({}, detail, {}, 0, 0, 900, 120, 3, 0, 1)
    assert(#widths < at_rest / 2 and #widths >= 300, "three pixels per column while moving: " .. #widths)
    local covered = 0
    for _, thickness in ipairs(widths) do covered = covered + thickness end
    assert(covered >= 900, "grouped columns still cover the full width")
    clock = clock + 10
  end

  -- Frame statistics feed the diagnostics text.
  assert(frame_stats_text():find("not measured", 1, true))
  frame_stats_record(1.000, 1.004, 1.020)
  frame_stats_record(1.033, 1.037, 1.053)
  local text = frame_stats_text()
  assert(text:find("fps", 1, true) and text:find("drawing", 1, true), text)
  assert(FrameStats.frames == 2)

  -- Section timing: each mark charges the time since the previous one.
  clock = 200
  frame_mark("toolbar")
  clock = clock + 0.002
  frame_mark("results")
  clock = clock + 0.010
  frame_mark(nil)
  frame_stats_record(200, 200.001, 200.013)
  local sections = frame_sections_text()
  assert(sections:find("^results 10%.0") and sections:find("toolbar 2%.0"), sections)
  assert(next(FrameStats.current) == nil and FrameStats.mark_name == nil)
  assert(frame_stats_text():find("Drawing sections", 1, true))
end

-- ----------------------------------------------------------------------------

-- Source guard: every change to the selection must go through the helpers, or
-- the cached views above would silently go stale.
do
  local direct_writes = 0
  for _, pattern in ipairs({
    "state%.selected_set%[[^%]\n]+%]%s*=[^=]",
    "state%.selected_set%s*=[^=]",
  }) do
    for _ in runtime:gmatch(pattern) do direct_writes = direct_writes + 1 end
  end
  assert(direct_writes == 1,
    "state.selected_set may only be assigned inside selection_replace(); found " .. direct_writes)
  for _, forbidden in ipairs({ "AppState.set(\"selected_set\"", "AppState.set('selected_set'" }) do
    assert(not runtime:find(forbidden, 1, true), "selected_set must not be replaced through AppState")
  end
end

print("Lua interaction cache self-test passed")
