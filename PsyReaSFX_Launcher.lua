-- @description PsyReaSFX
-- @author Psysia
-- @version 0.9.4-beta5
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
-- Resolve only when setup or an error needs UI. Ready launches do not spawn a
-- process. Windows UI culture is independent of region and number formatting.
local setup_locale
local function setup_language()
  if not setup_locale then
    setup_locale = "en"
    if reaper.GetOS():match("^Win") then
      local command = 'powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -Command "[System.Globalization.CultureInfo]::CurrentUICulture.Name"'
      local ok, result = pcall(reaper.ExecProcess, command, 1500)
      local culture = ok and type(result) == "string" and result:match("^0[\r\n]+([%a][%w%-_]*)")
      if culture and (culture:lower() == "zh" or culture:lower():match("^zh[-_]")) then setup_locale = "zh" end
    end
  end
  return setup_locale
end
local function setup_text(zh, en) return setup_language() == "zh" and zh or en end
if not reaper.file_exists(runtime) then
  reaper.MB(setup_text("PsyReaSFX 运行文件缺失，请重新安装完整版本。", "PsyReaSFX files are missing. Reinstall the complete application."), "PsyReaSFX", 0)
  return
end
if type(reaper.ReaWeb_Open) ~= "function" or type(reaper.ReaWeb_ReadSharedRange) ~= "function" then
  local setup, reason = loadfile(directory .. "runtime-setup.lua")
  if not setup then
    reaper.MB(setup_text("随包组件引导缺失，请重新安装 PRS 主程序。\n", "The bundled setup helper is missing. Reinstall the PRS main package.\n") .. tostring(reason), "PsyReaSFX", 0)
    return
  end
  if not setup()(directory, setup_language()) then return end
end
local action = reaper.AddRemoveReaScript(true, 0, runtime, true)
if not action or action == 0 then
  reaper.MB(setup_text("无法注册 PsyReaSFX 后台运行入口，请检查脚本安装目录。", "Could not register the PsyReaSFX backend action. Check the script installation folder."), "PsyReaSFX", 0)
  return
end
reaper.Main_OnCommand(action, 0)
