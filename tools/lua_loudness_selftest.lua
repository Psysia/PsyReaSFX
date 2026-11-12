-- Native loudness calculation must never interrupt ordinary browsing/preview.
local function read(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  return source
end
local function region(source, first, following)
  local start_at = assert(source:find(first, 1, true))
  local end_at = assert(source:find(following, start_at + #first, true))
  return source:sub(start_at, end_at - 1)
end

local source = read(arg[1] or "src/lua/40_analysis.lua")
local ui_source = read(arg[2] or "src/lua/50_runtime_ui.lua")
local clock, created, destroyed, calculations = 100, 0, 0, {}
local expected_values = { [0] = -21, [4] = -17, [5] = -19, [3] = -2 }
state = {
  show_loudness_metrics = true,
  loudness_show_i = true, loudness_show_m = true,
  loudness_show_s = true, loudness_show_tp = true,
  loudness_cache = {}, loudness_queue = {}, loudness_queued = {},
  next_loudness_job = 0,
}
function path_key(path) return path:lower() end
function file_size() return 128 end
function can_run_heavy_job() return true end
HostApi = {
  file_exists = function() return true end,
  time_precise = function() return clock end,
  PCM_Source_CreateFromFile = function(path)
    created = created + 1
    return { path = path }
  end,
  PCM_Source_Destroy = function() destroyed = destroyed + 1 end,
  CalculateNormalization = function(_, mode, target, start_time, end_time)
    assert(target == 0 and start_time == 0 and end_time == 0)
    assert(expected_values[mode], "unexpected normalization mode")
    calculations[#calculations + 1] = mode
    return 10 ^ (-expected_values[mode] / 20)
  end,
}
Jobs = { begin = function() return {} end, finish = function() end, cancel = function() end }
assert(load(region(source, "function loudness_cache_key(asset)", "function load_loudness_cache()")))()
assert(load(region(source, "function valid_loudness_entry(asset)", "function waveform_rms_proxy(asset)")))()
assert(load(region(ui_source, "function format_loudness_value(value, suffix)", "function draw_loudness_summary(asset)")))()
assert(load(region(ui_source, "function collect_loudness_summary_items(asset)", "function draw_preview_header(asset)")))()

local asset = { path = "fixture.wav", size = 128 }
-- Each UI snapshot requests metrics; uncached assets must remain quiet.
for index = 1, 100 do
  request_loudness_analysis(asset, false)
  collect_loudness_summary_items(asset)
  process_loudness_queue()
end
request_loudness_analysis(asset)
assert(created == 0 and #calculations == 0 and #state.loudness_queue == 0,
  "ordinary browsing must not open native normalization progress")

-- Explicit analysis still measures every selected metric and releases its source.
request_loudness_analysis(asset, true)
request_loudness_analysis(asset, true)
assert(#state.loudness_queue == 1, "duplicate explicit requests must be coalesced")
state.scan = {}
process_loudness_queue()
assert(created == 0, "analysis must wait while scanning")
state.scan = nil
for _ = 1, 5 do process_loudness_queue(); clock = clock + 0.1 end
assert(created == 1 and destroyed == 1 and #calculations == 4)
assert(not state.loudness_active and state.loudness_dirty)
local entry = assert(valid_loudness_entry(asset))
for field, expected in pairs({ lufs_i = -21, lufs_m = -17, lufs_s = -19, true_peak = -2 }) do
  assert(math.abs(entry[field] - expected) < 0.000001, "wrong cached " .. field)
end
local items = collect_loudness_summary_items(asset)
assert(#items == 4 and items[1].value == "-21.0", "cached metrics must remain visible")
for _ = 1, 20 do collect_loudness_summary_items(asset); process_loudness_queue() end
assert(#calculations == 4, "displaying cached metrics must not rescan audio")

-- File changes invalidate the cache without starting a modal calculation.
asset.size = 256
assert(#collect_loudness_summary_items(asset) == 0)
assert(state.loudness_cache[path_key(asset.path)] == nil and #calculations == 4)
request_loudness_analysis(asset, true)
for _ = 1, 5 do process_loudness_queue(); clock = clock + 0.1 end
assert(created == 2 and destroyed == 2 and #calculations == 8)

-- Disabled metrics and missing APIs remain harmless.
state.show_loudness_metrics = false
request_loudness_analysis(asset, true)
assert(#state.loudness_queue == 0)
state.show_loudness_metrics = true
HostApi.CalculateNormalization = nil
request_loudness_analysis(asset, true)
assert(#state.loudness_queue == 0)
print("Loudness: quiet browsing, cached display, explicit analysis and source cleanup passed")
