local template = assert(io.open(arg[1] or "src/launcher/PsyReaSFX.lua", "rb")):read("*a")
local calls, open, id, exists = {}, false, "", true
local r = {
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
print("WebView launcher first-start, restore, stale-window and missing-runtime checks passed")
