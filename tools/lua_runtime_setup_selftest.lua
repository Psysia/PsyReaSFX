local handle = assert(io.open("packaging/webview/runtime-setup.lua", "rb"))
local source = handle:read("*a"); handle:close()
local states, calls, files, deferred, clock = {}, {}, {}, nil, 0
local directory = "C:/PRS & 音频/"
local resource = "C:/REAPER $literal`name"
local token = "1234567890abcdef1234567890abcdef"
local r = {
  GetOS = function() return "Win64" end,
  GetResourcePath = function() return resource end,
  file_exists = function() return true end,
  GetExtState = function(_, key) return states[key] or "" end,
  SetExtState = function(_, key, value, persist) assert(not persist); states[key] = value end,
  DeleteExtState = function(_, key) states[key] = nil end,
  genGuid = function() return "{" .. token .. "}" end,
  ExecProcess = function(command, timeout)
    assert(timeout == -1 and command:find('-WindowStyle Hidden', 1, true))
    assert(command:find('"' .. directory .. 'Install-BundledRuntime.ps1"', 1, true))
    assert(command:find('"' .. resource .. '"', 1, true))
    assert(not command:lower():find("stop-process", 1, true))
    calls[#calls+1] = "spawn"; return "0"
  end,
  time_precise = function() return clock end,
  defer = function(callback) deferred = callback end,
  MB = function(message) calls[#calls+1] = message end,
}
local testio = { open = function(path, mode)
  assert(mode == "rb" and path == resource .. "/Data/PsyReaSFX-WebView/runtime-setup-" .. token .. ".txt")
  local value = files[path]
  if value then return {read=function(_, count) assert(count==4096); return value end,close=function() end} end
end }
local env = setmetatable({reaper=r,io=testio}, {__index=_G})
local setup = assert(load(source, "setup", "t", env))()
r.GetOS=function() return "Win32" end
setup(directory); assert(calls[#calls]:find("Windows x64")); calls={}
r.GetOS=function() return "Win64" end
assert(not setup(directory) and #calls==1 and calls[1]=="spawn" and deferred)
clock=6; deferred(); assert(states[resource:lower()]==nil, "silent helper failure must allow retry")
clock=0; calls={}; setup(directory)
files[resource .. "/Data/PsyReaSFX-WebView/runtime-setup-" .. token .. ".txt"] = "waiting\nWait for REAPER"
deferred(); assert(calls[#calls]=="Wait for REAPER")
assert(not setup(directory)); assert(calls[#calls]=="Wait for REAPER")
local spawned=0; for _,call in ipairs(calls) do if call=="spawn" then spawned=spawned+1 end end
assert(spawned==1, "repeated actions must reuse the waiting installer")
files[resource .. "/Data/PsyReaSFX-WebView/runtime-setup-" .. token .. ".txt"] = "error\nPreserved external runtime"
setup(directory); assert(states[resource:lower()]==nil)
r.ReaWeb_Open, r.ReaWeb_ReadSharedRange = function() end, function() end
local before=#calls; assert(setup(directory) and #calls==before, "ready API must not reinstall or interrupt playback")
r.ReaWeb_ReadSharedRange=nil; r.file_exists=function() return false end
setup(directory); assert(calls[#calls]:find("文件缺失"))
r.file_exists=function() return true end
r.ExecProcess=function() return "-1" end
setup(directory); assert(states[resource:lower()]==nil and calls[#calls]:find("无法启动"))
print("Bundled runtime bootstrap passed: ready fast path, quoted hidden launch, one helper, deferred status and preserved-external retry")
