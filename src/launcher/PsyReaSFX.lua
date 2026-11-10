-- @description PsyReaSFX
-- @author Psysia
-- @version @VERSION@
-- The public action finishes immediately. The separately registered runtime
-- owns the defer loop, so invoking this action again never interrupts a job.
local source = debug.getinfo(1, "S").source:gsub("^@", "")
local directory = source:match("^(.*[\\/])") or ""
local runtime = directory .. "PsyReaSFX_Runtime.lua"
local key = runtime:gsub("\\", "/")
if reaper.GetOS():match("^Win") then key = key:lower() end
local id = tonumber(reaper.GetExtState("PsyReaSFX.Web", key))
if id and type(reaper.ReaWeb_IsOpen) == "function" and reaper.ReaWeb_IsOpen(id) then
  if type(reaper.ReaWeb_Show) == "function" then reaper.ReaWeb_Show(id) end
  if type(reaper.ReaWeb_Focus) == "function" then reaper.ReaWeb_Focus(id) end
  return
end
if not reaper.file_exists(runtime) then
  reaper.MB("PsyReaSFX 运行文件缺失，请重新安装完整版本。", "PsyReaSFX", 0)
  return
end
local action = reaper.AddRemoveReaScript(true, 0, runtime, true)
if not action or action == 0 then
  reaper.MB("无法注册 PsyReaSFX 后台运行入口，请检查脚本安装目录。", "PsyReaSFX", 0)
  return
end
reaper.Main_OnCommand(action, 0)
