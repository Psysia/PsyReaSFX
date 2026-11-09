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
assert(
  not pcall(WebUI.handlers["selection.set"], { revision = -1, index = 1, path = asset.path }),
  "stale selections must fail"
)
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
print(
  "WebView headless startup, bounded paging, stale selection, DSP validation, read-only and metadata regressions passed"
)
