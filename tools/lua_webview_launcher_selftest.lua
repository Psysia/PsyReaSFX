local template = assert(io.open(arg[1] or "src/launcher/PsyReaSFX.lua", "rb")):read("*a")
local calls, open, id, exists, bootstrap_exists = {}, false, "", true, true
local r = {
  ReaWeb_Open = function() end,
  ReaWeb_ReadSharedRange = function() end,
  GetOS = function() return "Win64" end,
  GetExtState = function(_, key) assert(key == "c:/fixture/psyreasfx_runtime.lua"); return id end,
  ReaWeb_IsOpen = function(value) assert(value == 17); return open end,
  ReaWeb_Show = function(value) calls[#calls+1] = "show:" .. value end,
  ReaWeb_Focus = function(value) calls[#calls+1] = "focus:" .. value end,
  file_exists = function() return exists end,
  MB = function() calls[#calls+1] = "error" end,
  AddRemoveReaScript = function(add, section, path, commit)
    assert(add and section == 0 and path == "C:/fixture/PsyReaSFX_Runtime.lua" and commit)
    calls[#calls+1] = "register"; return 42
  end,
  Main_OnCommand = function(action) assert(action == 42); calls[#calls+1] = "start" end,
}
local function run()
  calls = {}
  local env = setmetatable({ reaper = r, debug = { getinfo = function() return { source = "@C:/fixture/PsyReaSFX.lua" } end } }, { __index = _G })
  env.loadfile = function(path)
    assert(path == "C:/fixture/runtime-setup.lua")
    if not bootstrap_exists then return nil, "missing fixture" end
    return function() return function(directory)
      assert(directory == "C:/fixture/"); calls[#calls+1] = "setup"; return false
    end end
  end
  assert(load(template, "launcher", "t", env))()
  return table.concat(calls, ",")
end
assert(run() == "register,start")
id, open = "17", true
assert(run() == "show:17,focus:17", "repeat launch must only restore existing window")
open = false
assert(run() == "register,start", "closed window must allow a fresh runtime")
exists = false
assert(run() == "error")
exists, r.ReaWeb_ReadSharedRange = true, nil
assert(run() == "setup", "missing native API must prepare bundled component without starting the backend")
bootstrap_exists = false
assert(run() == "error")
open = true
assert(run() == "show:17,focus:17", "component setup must not interrupt an existing window")
print("WebView launcher first-start, restore, stale-window and missing-runtime checks passed")
