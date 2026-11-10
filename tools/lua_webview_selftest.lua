local entry = assert(arg[1], "generated WebView Lua entry is required")
local fixture = assert(arg[2], "isolated fixture directory is required")
local messages, deferred, exits, extstate = {}, nil, {}, {}
reaper = {
  GetResourcePath = function()
    return fixture
  end,
  GetOS = function()
    return "Win64"
  end,
  time_precise = os.clock,
  GetPlayState = function()
    return 0
  end,
  GetPlayStateEx = function()
    return 0
  end,
  file_exists = function(path)
    local file = io.open(path, "rb")
    if not file then
      return false
    end
    file:close()
    return true
  end,
  RecursiveCreateDirectory = function(path)
    assert(not path:find('["&|<>]'), "invalid fixture directory")
    os.execute('mkdir "' .. path .. '" >NUL 2>NUL')
    return 1
  end,
  EnumerateFiles = function()
    return nil
  end,
  EnumerateSubdirectories = function()
    return nil
  end,
  EnumProjects = function()
    return nil, ""
  end,
  GetExtState = function(section, key)
    return extstate[section .. key] or ""
  end,
  SetExtState = function(section, key, value)
    extstate[section .. key] = value
  end,
  DeleteExtState = function(section, key)
    extstate[section .. key] = nil
  end,
  ReaWeb_Open = function()
    return 77
  end,
  ReaWeb_IsOpen = function()
    return true
  end,
  ReaWeb_IsReady = function()
    return true
  end,
  ReaWeb_Send = function(_, message)
    messages[#messages + 1] = message
    return true
  end,
  ReaWeb_Receive = function()
    return ""
  end,
  ReaWeb_Close = function() end,
  defer = function(callback)
    deferred = callback
  end,
  atexit = function(callback)
    exits[#exits + 1] = callback
  end,
  MB = function(message)
    error(message)
  end,
}
assert(loadfile(entry))()
assert(WebUI and deferred, "WebView entry must register its native loop")
local original_open, original_message_box = io.open, reaper.MB
for _, broken_lock in ipairs({ "", "{bad", string.rep("x", 32769) }) do
  local reported = false
  io.open = function(path, mode)
    if path:match("runtime%-lock%.json$") then
      return {
        read = function()
          return broken_lock
        end,
        close = function() end,
      }
    end
    return original_open(path, mode)
  end
  reaper.MB = function()
    reported = true
  end
  assert(
    webview_open() == false and reported,
    "invalid runtime locks must fail with a repair message"
  )
end
io.open, reaper.MB = original_open, original_message_box
local original_native_open = reaper.ReaWeb_Open
local original_browse, original_open_url = reaper.ReaPack_BrowsePackages, open_url
local choice, questions, notices, searches, links = 6, {}, {}, {}, {}
reaper.MB = function(message, title, kind)
  if kind == 4 then
    questions[#questions + 1] = message
    return choice
  end
  notices[#notices + 1] = message
  return 1
end
open_url = function(url)
  links[#links + 1] = url
end
reaper.ReaPack_BrowsePackages = function(filter)
  searches[#searches + 1] = filter
end
reaper.ReaWeb_Open = nil
assert(webview_open() == false)
assert(#questions == 1 and searches[1] == "PsyReaSFX WebView Runtime" and #links == 0)
assert(questions[1]:find("重启 REAPER", 1, true), "dependency prompt must explain restart")
choice = 7
assert(webview_open() == false)
assert(#searches == 1 and #links == 0, "declining must not navigate")
choice = 6
reaper.ReaPack_BrowsePackages = nil
assert(webview_open() == false)
assert(
  links[1] == "https://github.com/Psysia/PsyReaSFX/releases",
  "missing ReaPack must offer downloads"
)
reaper.ReaPack_BrowsePackages = function()
  error("ReaPack unavailable")
end
assert(webview_open() == false)
assert(#links == 2 and #notices == 1, "ReaPack errors must fall back to downloads")
open_url = function()
  error("browser unavailable")
end
assert(webview_open() == false)
assert(notices[#notices]:find("https://github.com/Psysia/PsyReaSFX/releases", 1, true))
local ownership_apis = {
  "ReaPack_GetOwner",
  "ReaPack_GetEntryInfo",
  "ReaPack_FreeEntry",
  "ReaPack_AboutInstalledPackage",
}
local original_ownership = {}
for _, name in ipairs(ownership_apis) do
  original_ownership[name] = reaper[name]
end
local allocations, releases, about_calls = 0, 0, 0
local info_error, show_about = false, true
reaper.ReaPack_GetOwner = function(path)
  assert(path == fixture .. "/UserPlugins/reaper_reawebapi-x64.dll")
  allocations = allocations + 1
  return { released = false }
end
reaper.ReaPack_GetEntryInfo = function(entry)
  assert(not entry.released)
  if info_error then
    error("metadata unavailable")
  end
  return true, "zaibuyidao Scripts", "ReaWebAPI", "ReaWebAPI.ext", "ReaWebAPI", 2, "0.3.9.29"
end
reaper.ReaPack_FreeEntry = function(entry)
  releases = releases + 1
  assert(not entry.released, "owner entries must be released once")
  entry.released = true
end
reaper.ReaPack_AboutInstalledPackage = function(entry)
  assert(not entry.released, "owner entry must remain valid while opening its page")
  about_calls = about_calls + 1
  return show_about
end
reaper.ReaPack_BrowsePackages = function(filter)
  searches[#searches + 1] = filter
end
open_url = function(url)
  links[#links + 1] = url
end
local previous_searches = #searches
assert(webview_open() == false)
assert(about_calls == 1 and releases == allocations and #searches == previous_searches)
assert(
  questions[#questions]:find("zaibuyidao Scripts", 1, true)
    and questions[#questions]:find("0.3.9.29", 1, true)
)
assert(
  not questions[#questions]:find("首次安装可选择", 1, true),
  "existing ownership must not recommend a duplicate"
)
choice = 7
assert(webview_open() == false)
assert(
  about_calls == 1 and releases == allocations,
  "cancel must release the owner without navigating"
)
choice, show_about = 6, false
assert(webview_open() == false)
assert(
  searches[#searches] == "ReaWebAPI" and releases == allocations,
  "owner page failure must search the original package"
)
info_error, show_about = true, true
assert(webview_open() == false)
assert(
  about_calls == 3 and releases == allocations,
  "missing metadata must preserve ownership and release its handle"
)
for _, name in ipairs(ownership_apis) do
  reaper[name] = original_ownership[name]
end
local original_exists = reaper.file_exists
reaper.file_exists = function(path)
  return path == fixture .. "/UserPlugins/reaper_reawebapi-x64.dll" or original_exists(path)
end
assert(webview_open() == false)
assert(
  searches[#searches] == "ReaWebAPI",
  "unmanaged existing DLLs must receive restart/update guidance"
)
reaper.file_exists = original_exists
reaper.ReaWeb_Open = original_native_open
local original_send = reaper.ReaWeb_Send
reaper.ReaWeb_Send = nil
choice = 7
assert(webview_open() == false)
assert(
  questions[#questions]:find("ReaWeb_Send", 1, true),
  "partial API installations must prompt too"
)
reaper.ReaWeb_Send = original_send
local previous_questions = #questions
webview_open()
assert(
  #questions == previous_questions,
  "available dependencies must not trigger installation prompts"
)
reaper.ReaPack_BrowsePackages, open_url, reaper.MB =
  original_browse, original_open_url, original_message_box
local session = WebUI.handlers["session.ready"]()
assert(
  session.runtimePolicy.protocol == 1,
  "runtime policy must come from the packaged dependency lock"
)
assert(session.runtimePolicy.baseline_versions[1], "handshake must expose the pinned baseline")
for _ = 1, 50 do
  deferred()
  local message = neural_json_decode(messages[#messages])
  if message.event == "state" and message.data.startup == nil then
    break
  end
end
local latest = neural_json_decode(messages[#messages])
assert(latest.event == "state", "WebView must publish state")
assert(
  not (latest.data.startup and latest.data.startup.failure),
  latest.data.startup and latest.data.startup.failure
)

local runtime
for index = 1, 30 do
  local name, value = debug.getupvalue(webview_publish, index)
  if name == "state" then
    runtime = value
    break
  end
end
assert(runtime, "test must access the actual runtime state")
assert(runtime.startup_session == nil, "headless startup must complete without ReaImGui")
local settings = WebUI.handlers["settings.get"]()
assert(type(settings.ai_presets) == "table", "settings must load after headless startup")
assert(type(neural_json_encode(settings)) == "string")

local asset = {
  path = fixture .. "\\test.wav",
  name = "测试声音.wav",
  duration = 8,
  channels = 2,
  sample_rate = 96000,
  bit_depth = 24,
  description = "original",
  keywords = "metal",
}
runtime.assets, runtime.results = { asset }, { asset }
runtime.by_path[path_key(asset.path)] = asset
local cached_key = asset_path_sort_key(asset)
replace_database_asset(asset, false)
assert(
  asset_path_sort_key(asset) == cached_key,
  "journal replacement must rebuild invalidated path cache"
)
assert(type(wave_cache_key(asset, 128, false, false)) == "string")
asset.ready = true
runtime.root_filter = fixture
assert(results_filter_predicate()(asset), "root filtering must survive journal replacement")
runtime.root_filter = nil

record_preview_history(asset)
local played_page = WebUI.handlers["catalog.page"]({ offset = 0, limit = 20, waveforms = false })
assert(played_page.items[1].played == true, "successful preview must expose session highlighting")
WebUI.handlers["records.action"]({ action = "clearPlayed" })
assert(not WebUI.handlers["catalog.page"]({ waveforms = false }).items[1].played)
assert(asset.last_previewed > 0, "clearing session highlights must retain history")
WebUI.handlers["asset.action"]({ action = "mark", path = asset.path })
assert(asset.marked == true)
WebUI.handlers["asset.action"]({ action = "mark", path = asset.path })
assert(asset.marked == false)
WebUI.handlers["asset.action"]({ action = "workflow", path = asset.path, status = "approved" })
assert(asset.workflow_status == "approved")
WebUI.handlers["asset.action"]({ action = "channelMode", path = asset.path, mode = "left" })
assert(runtime.preview_channel_mode == "left")
assert(
  not pcall(
    WebUI.handlers["asset.action"],
    { action = "channelMode", path = asset.path, mode = "custom" }
  )
)
assert(
  not pcall(WebUI.handlers["asset.action"], { action = "channel", path = asset.path, channel = 1 })
)
WebUI.handlers["asset.action"]({ action = "channelMode", path = asset.path, mode = "original" })
WebUI.handlers["settings.update"]({
  values = { played_text_enabled = false, transfer_fade_in_ms = 12 },
})
assert(runtime.played_text_enabled == false and runtime.transfer_fade_in_ms == 12)
assert(
  not pcall(
    WebUI.handlers["settings.update"],
    { values = { played_text_enabled = true, transfer_fade_in_ms = -1 } }
  )
)
assert(runtime.played_text_enabled == false, "invalid settings batches must not partially apply")
assert(not pcall(WebUI.handlers["settings.update"], { values = { persistence_read_only = false } }))
WebUI.handlers["settings.update"]({ values = { played_text_enabled = true } })
assert(#WebUI.handlers["management.get"]() == 4)
local second = {
  path = fixture .. "\\second.wav",
  name = "second.wav",
  description = "second description",
  keywords = "second",
  ready = true,
}
runtime.assets, runtime.results = { asset, second }, { asset, second }
runtime.by_path[path_key(second.path)] = second
WebUI.handlers["selection.all"]({})
local batch = WebUI.handlers["metadata.selection"]({})
assert(batch.count == 2 and batch.mixed.description)
runtime.favorites[path_key(asset.path)] = true
WebUI.handlers["asset.action"]({ action = "favorite", path = asset.path })
assert(
  runtime.favorites[path_key(asset.path)] and runtime.favorites[path_key(second.path)],
  "mixed selection must favorite all"
)
WebUI.handlers["asset.action"]({ action = "favorite", path = asset.path })
assert(
  not runtime.favorites[path_key(asset.path)] and not runtime.favorites[path_key(second.path)],
  "all-favorite selection must clear all"
)
WebUI.handlers["metadata.batch"]({
  count = batch.count,
  token = batch.token,
  values = { keywords = "shared" },
})
assert(asset.keywords == "shared" and second.keywords == "shared")
assert(asset.description == "original" and second.description == "second description")
local stale_batch = WebUI.handlers["metadata.selection"]({})
second.description = "background edit"
assert(
  not pcall(
    WebUI.handlers["metadata.batch"],
    { count = stale_batch.count, token = stale_batch.token, values = { keywords = "overwrite" } }
  )
)
assert(asset.keywords == "shared" and second.keywords == "shared")
runtime.assets, runtime.results = { asset }, { asset }
asset.keywords = "metal"
WebUI.handlers["selection.all"]({})
local first = WebUI.handlers["catalog.page"]({ offset = 0, limit = 20, waveforms = false })
assert(#first.items == 1 and first.items[1].name == asset.name)
assert(first.items[1].waveform == nil, "hidden waveform column must not queue audio work")
asset.description = string.rep("测试", 900)
local clipped = WebUI.handlers["catalog.page"]({ offset = 0, limit = 1, waveforms = false })
assert(utf8.len(clipped.items[1].description), "bounded fields must keep valid UTF-8")
assert(clipped.items[1].truncated.description, "oversized fields must declare truncation")
assert(not pcall(WebUI.handlers["metadata.save"], {
  path = asset.path,
  original = { description = clipped.items[1].description },
  values = { description = "new" },
}), "truncated fields must not be silently overwritten")
asset.description = "original"
assert(not pcall(WebUI.handlers["catalog.page"], { limit = 100000 }), "page size must be bounded")
assert(WebUI.handlers["selection.set"]({ revision = -1, index = 1, path = asset.path, autoPlay = false }).path == asset.path,
  "a harmless revision change must not block an identity-matched click")
assert(WebUI.handlers["selection.set"]({ revision = -1, index = 1, path = asset.path, shift = true }).stale,
  "range selection must request a fresh page after reordering")
assert(WebUI.handlers["selection.set"]({ revision = WebUI.revision, index = 1, path = "different.wav" }).stale,
  "a stale row must never select a different asset")
assert(
  not pcall(WebUI.handlers["preview.parameters"], { pitch = 100 }),
  "invalid DSP range must fail"
)
WebUI.handlers["preview.parameters"]({ pitch = 2, rate = 0.8, gain_db = -3 })
assert(runtime.pitch == 2 and runtime.rate == 0.8 and runtime.gain_db == -3)
assert(not pcall(WebUI.handlers["preview.parameters"], { pitch = 10, rate = 100 }))
assert(
  runtime.pitch == 2 and runtime.rate == 0.8,
  "invalid parameter batch must not partially apply"
)
WebUI.handlers["preview.region"]({ start = 0.25, finish = 0.75 })
assert(runtime.region_start == 0.25 and runtime.region_end == 0.75)
assert(not pcall(WebUI.handlers["preview.region"], { start = 0.8, finish = 0.2 }))
runtime.persistence_read_only = true
assert(
  not pcall(WebUI.handlers["favorite.toggle"], { path = asset.path }),
  "read-only catalogs must reject writes"
)
runtime.persistence_read_only = false
WebUI.handlers["favorite.toggle"]({ path = asset.path })
assert(runtime.favorites[path_key(asset.path)])
assert(
  not pcall(
    WebUI.handlers["metadata.save"],
    { path = asset.path, original = { description = "stale" }, values = { description = "new" } }
  ),
  "metadata conflicts must fail"
)
WebUI.handlers["metadata.save"]({
  path = asset.path,
  original = { description = "original" },
  values = { description = "new" },
})
assert(
  asset.description == "new" and asset.keywords == "metal",
  "partial metadata edit must preserve other fields"
)
WebUI.handlers["catalog.query"]({ search = "metal", libraryId = "", view = "all" })
assert(runtime.search == "metal" and runtime.results_dirty)
runtime.root_filter = fixture
runtime.library_filter_id = "scoped-library"
WebUI.handlers["catalog.query"]({ search = "gear", keepScope = true, status = "approved" })
assert(runtime.root_filter == fixture and runtime.library_filter_id == "scoped-library")
assert(runtime.status_filter == "approved")
WebUI.handlers["catalog.query"]({ search = "", view = "all" })
assert(runtime.root_filter == nil and runtime.status_filter == nil)
local input = {
  neural_json_encode({ protocol = 1, id = "invalid-method", method = "unknown", params = {} }),
  "{bad",
}
reaper.ReaWeb_Receive = function()
  return table.remove(input, 1) or ""
end
webview_receive()
local response = neural_json_decode(messages[#messages])
assert(
  response.id == "invalid-method" and response.ok == false,
  "unsupported RPC must return a correlated error"
)
local settings = WebUI.handlers["settings.get"]()
assert(
  settings.ai_key == nil and settings.secret == nil,
  "settings snapshots must not expose credentials"
)
WebUI.handlers["settings.update"]({ values = { language = "en" } })
assert(runtime.language == "en")
local suggestions = WebUI.handlers["catalog.suggestions"]({ query = "burst" })
assert(#suggestions > 0 and #suggestions <= 8 and suggestions[1].catid == "AIRBrst")
assert(suggestions[1].query == "catid:AIRBrst")
assert(#WebUI.handlers["catalog.suggestions"]({ query = "a" }) == 0)
assert(not pcall(WebUI.handlers["settings.update"], { values = { language = "invalid" } }))
WebUI.handlers["settings.update"]({ values = { language = "zh" } })
-- Web names must not open a second, hidden native input dialog.
local playlist = WebUI.handlers["collection.create"]({ kind = "playlist", name = "Web playlist" })
assert(playlist and runtime.collection_by_id[playlist.id].kind == "playlist")
WebUI.handlers["management.action"]({ kind = "collection", id = playlist.id, action = "rename", name = "Renamed playlist" })
assert(runtime.collection_by_id[playlist.id].name == "Renamed playlist")
WebUI.handlers["records.action"]({ action = "saveSearch", name = "Web search" })
assert(runtime.saved_searches[#runtime.saved_searches].name == "Web search")
local active_tab = runtime.workspace_tab_active
WebUI.handlers["tab.action"]({ action = "rename", id = active_tab, name = "Web tab" })
assert(workspace_tab_by_id(active_tab).name == "Web tab")

asset.description = string.rep("完整元数据", 900)
local full_metadata = WebUI.handlers["metadata.get"]({ path = asset.path })
assert(not full_metadata.truncated.description and full_metadata.description == asset.description)
WebUI.handlers["metadata.save"]({ path = asset.path, original = full_metadata, values = { description = "Long field edited safely" } })
assert(asset.description == "Long field edited safely")
asset.description = string.rep("x", 70000)
local oversized = WebUI.handlers["metadata.get"]({ path = asset.path })
assert(oversized.truncated.description and #oversized.description == 65536)
assert(not pcall(WebUI.handlers["metadata.save"], { path = asset.path, original = oversized, values = { description = "truncated" } }))
asset.description = "Long field edited safely"
local previous_library, previous_library_id = asset.library, asset.library_id
asset.library, asset.library_id = nil, "webview-fallback"
runtime.library_by_id[asset.library_id] = { name = "Displayed library" }
WebUI.handlers["metadata.save"]({ path = asset.path, original = { library = "Displayed library" }, values = { library = "Edited library" } })
assert(asset.library == "Edited library", "the displayed library fallback must remain editable")
runtime.library_by_id["webview-fallback"] = nil
asset.library, asset.library_id = previous_library, previous_library_id
asset.wave_error = "unreadable"
assert(WebUI.handlers["catalog.page"]({ offset = 0, limit = 1, waveforms = false }).items[1].waveError)
asset.wave_error = nil
runtime.view, runtime.sort_mode = "ai_semantic", "ai_order"
WebUI.handlers["catalog.query"]({ search = "ordinary search", keepScope = true })
assert(runtime.view == "all" and runtime.sort_mode == "name", "ordinary search must leave stale AI ordering")

WebUI.handlers["settings.update"]({ values = { watch_enabled = false, watch_interval = 60, transfer_format = "wav24" } })
assert(runtime.watch_enabled == false and runtime.watch_interval == 60 and runtime.next_watch > reaper.time_precise())
local old_channels = runtime.multichannel_waveform
runtime.wave_queued = { pending = true }
WebUI.handlers["settings.update"]({ values = { multichannel_waveform = not old_channels } })
assert(next(runtime.wave_queued) == nil, "waveform settings must invalidate queued jobs")
runtime.transfer_cancel_requested = false
WebUI.handlers["tasks.cancel"]({ task = "ai" })
assert(runtime.transfer_cancel_requested == false, "canceling AI must not cancel Transfer")
WebUI.handlers["tasks.cancel"]({ task = "transfer" })
assert(runtime.transfer_cancel_requested == true)
assert(not pcall(WebUI.handlers["tasks.cancel"], { task = "unknown" }))

-- Loading is a readable UI state, not an unresponsive settings button.
do
  local saved = {}
  for _, key in ipairs({ "results", "assets", "wave_cache", "wave_cache_count", "wave_clock", "wave_checked", "wave_queued", "wave_queue", "wave_active", "next_wave_job", "precache_session", "import_session", "scan", "transfer_running", "root_records", "folder_navigation_trees", "folder_navigation_ready", "folder_navigation_job", "folder_navigation_revision", "folder_navigation_built_revision" }) do saved[key] = { runtime[key] } end
  local disk_loader, decoder, heavy, clock = load_wave_from_disk, step_wave_job, can_run_heavy_job, reaper.time_precise
  local reads, ticks = 0, 100
  reaper.time_precise = function() ticks = ticks + 0.004; return ticks end
  can_run_heavy_job = function() return true end
  load_wave_from_disk = function() reads = reads + 1; return { count = 2, peaks = { 0.2, 0.8 } } end
  step_wave_job = function() error("warm cache must not decode source audio") end
  runtime.wave_cache, runtime.wave_checked, runtime.wave_queued, runtime.wave_queue = {}, {}, {}, {}
  runtime.wave_cache_count, runtime.wave_clock, runtime.next_wave_job = 0, 0, 0
  runtime.wave_active, runtime.precache_session, runtime.import_session, runtime.scan, runtime.transfer_running = nil, nil, nil, nil, false
  runtime.results = {}
  for index = 1, 32 do
    runtime.results[index] = { path = fixture .. "\\cached-" .. index .. ".wav", name = "cached", ready = true, channels = 2 }
  end
  WebUI.handlers["catalog.page"]({ offset = 0, limit = 32 })
  assert(reads == 0 and #runtime.wave_queue == 32, "all visible waves must enqueue without blocking RPC on disk reads")
  runtime.import_session = { phase = "index" }
  process_wave_queue()
  runtime.import_session, runtime.precache_session = nil, { phase = "collect" }
  process_wave_queue()
  assert(reads == 2 and #runtime.wave_queue == 30, "existing disk waves must remain readable during import and precache")
  runtime.precache_session = nil
  for _ = 1, 30 do process_wave_queue() end
  local cached_page = WebUI.handlers["catalog.page"]({ offset = 0, limit = 32 })
  assert(reads == 32 and #runtime.wave_queue == 0)
  for _, row in ipairs(cached_page.items) do assert(row.waveform and row.waveform.peaks[2] == 0.8, "later rows must not starve") end
  local channels, multichannel = asset.channels, runtime.multichannel_waveform
  asset.channels = 128
  runtime.multichannel_waveform = true
  WebUI.handlers["waveform.get"]({ path = asset.path, points = 4096 })
  assert(runtime.wave_queue[1].points <= 183, "high-channel waveforms must fit a bounded native response")
  asset.channels = channels
  runtime.multichannel_waveform = multichannel
  runtime.root_records = { { id = "web-folders", library_id = "lib", alias = "", path = "D:\\Fixture", enabled = true } }
  runtime.assets = { { path = "D:\\Fixture\\Child\\Nested\\a.wav", folder = "D:\\Fixture\\Child\\Nested", root_id = "web-folders", ready = true } }
  runtime.folder_navigation_trees, runtime.folder_navigation_ready, runtime.folder_navigation_job = {}, false, nil
  runtime.folder_navigation_revision = 100
  assert(WebUI.handlers["catalog.folders"]({ rootId = "web-folders", path = "D:\\Fixture" }).pending)
  for _ = 1, 30 do process_folder_navigation_build() end
  local folders = WebUI.handlers["catalog.folders"]({ rootId = "web-folders", path = "D:\\Fixture" })
  assert(not folders.pending and folders.items[1].name == "Child" and folders.items[1].count == 1)
  local children = WebUI.handlers["catalog.folders"]({ rootId = "web-folders", path = "D:\\Fixture\\Child" })
  assert(children.items[1].name == "Nested" and not children.items[1].children, "nested folder browsing must resolve actual index nodes")
  assert(not pcall(WebUI.handlers["catalog.folders"], { rootId = "web-folders", path = "D:\\Outside" }), "folder traversal must remain within its source")
  for key, value in pairs(saved) do runtime[key] = value[1] end
  load_wave_from_disk, step_wave_job, can_run_heavy_job, reaper.time_precise = disk_loader, decoder, heavy, clock
end

runtime.startup_session = { phase = "fixture loading" }
input = { neural_json_encode({ protocol = 1, id = "loading-settings", method = "settings.get", params = {} }) }
webview_receive()
local loading_response = neural_json_decode(messages[#messages])
assert(loading_response.ok and loading_response.result.loading)
input = { neural_json_encode({ protocol = 1, id = "loading-write", method = "settings.update", params = { values = { language = "en" } } }) }
webview_receive()
assert(not neural_json_decode(messages[#messages]).ok and runtime.language == "zh")
runtime.startup_session = nil
-- Beta 9: source-equivalent actions, independent of stale browser snapshots.
do
  local play, stop, folder, transfer, queue, mark = play_preview, request_preview_stop, open_folder, run_transfer, queue_artwork, mark_asset_database_change
  local saved_preview = runtime.preview
  local toggles = {}
  play_preview = function(item, position, selection)
    assert(item == nil and position == nil and selection == true)
    runtime.preview = "fixture-preview"
    toggles[#toggles + 1] = "play"
  end
  request_preview_stop = function()
    runtime.preview = nil
    toggles[#toggles + 1] = "stop"
  end
  runtime.preview = nil
  WebUI.handlers["preview.toggle"]({})
  WebUI.handlers["preview.toggle"]({})
  assert(table.concat(toggles, ",") == "play,stop", "toggle must read live host playback state")
  WebUI.handlers["preview.region"]({ start = 0.2, finish = 0.6 })
  runtime.active_region_index = 7
  WebUI.handlers["preview.clearRegion"]({})
  assert(runtime.region_start == 0 and runtime.region_end == 1 and runtime.active_region_index == 0)
  runtime.preview = saved_preview
  play_preview, request_preview_stop = play, stop

  local opened = {}
  open_folder = function(path) opened[#opened + 1] = path end
  local roots = runtime.root_records
  runtime.root_records = { { id = "open-fixture", path = "D:\\Library" } }
  WebUI.handlers["management.action"]({ kind = "root", id = "open-fixture", action = "open", path = "D:\\Library\\Child" })
  assert(opened[1] == "D:\\Library\\Child")
  assert(not pcall(WebUI.handlers["management.action"], { kind = "root", id = "open-fixture", action = "open", path = "D:\\Outside" }))
  assert(not pcall(WebUI.handlers["management.action"], { kind = "root", id = "open-fixture", action = "open", path = "D:\\Library\\..\\Outside" }))
  WebUI.handlers["records.action"]({ action = "openCacheFolder" })
  WebUI.handlers["records.action"]({ action = "backupFolder" })
  assert(#opened == 3)
  runtime.root_records = roots
  open_folder = folder

  local dirty = {}
  mark_asset_database_change = function(item, mode) dirty[#dirty + 1] = { item, mode } end
  queue_artwork = function(item, priority) assert(item == asset and priority) end
  asset.artwork_path, asset.artwork_checked = "old.png", true
  WebUI.handlers["asset.action"]({ path = asset.path, action = "clearArtwork" })
  assert(asset.artwork_path == "-" and asset.artwork_checked)
  WebUI.handlers["asset.action"]({ path = asset.path, action = "redetectArtwork" })
  assert(asset.artwork_path == "" and not asset.artwork_checked and #dirty == 2)
  queue_artwork, mark_asset_database_change = queue, mark
  runtime.failed_tasks = { fixture = { path = asset.path, stage = "wave", reason = "fixture" } }
  WebUI.handlers["records.action"]({ action = "clearFailed" })
  assert(next(runtime.failed_tasks) == nil and runtime.failed_tasks_dirty)

  runtime.results, runtime.selected_index, runtime.selected_path = { asset }, 1, asset.path
  select_all_results()
  local exports = {}
  run_transfer = function(targets, batch) exports[#exports + 1] = { targets, batch } end
  runtime.transfer_running = false
  WebUI.handlers["transfer.start"]({ target = "current", path = asset.path })
  WebUI.handlers["transfer.start"]({ target = "selected" })
  assert(exports[1][1][1] == asset and exports[1][2] == false)
  assert(exports[2][1][1] == asset and exports[2][2] == true)
  assert(not pcall(WebUI.handlers["transfer.start"], { target = "current", path = "changed.wav" }))
  run_transfer = transfer
  assert(WebUI.handlers["diagnostics.overlay"]({ enabled = true }) and FrameStats.overlay)
  assert(not WebUI.handlers["diagnostics.overlay"]({ enabled = false }))
  assert(not pcall(WebUI.handlers["settings.ai"], { action = "deleteKey", id = "another-preset" }))
  local catalog = WebUI.handlers["catalog.ucs"]({})
  assert(#catalog > 50 and type(catalog[1].entries[1].synonyms) == "string")
  assert(#neural_json_encode(catalog) < 900000, "searchable taxonomy must fit the native message budget")
end
if arg[3] then
  local file = assert(io.open(arg[3], "wb"))
  file:write(neural_json_encode(WebUI.handlers["settings.get"]().schema))
  file:close()
end
print(
  "WebView headless startup, bounded paging, stale selection, DSP validation, read-only and metadata regressions passed"
)
