-- Bootstrap only PRS's bundled component. No download, source-library access,
-- process termination or REAPER restart is performed here.
return function(directory, language)
  if type(reaper.ReaWeb_Open) == "function" and type(reaper.ReaWeb_ReadSharedRange) == "function" then return true end
  language = language == "zh" and "zh" or "en"
  local function tr(zh, en) return language == "zh" and zh or en end
  if reaper.GetOS() ~= "Win64" then
    reaper.MB(tr("此版本需要 Windows x64。", "This version requires Windows x64."), "PsyReaSFX", 0)
    return false
  end
  local helper = directory .. "Install-BundledRuntime.ps1"
  if not reaper.file_exists(helper) or not reaper.file_exists(directory .. "bundled-runtime.json") then
    reaper.MB(tr("随包组件文件缺失，请在 ReaPack 重新安装 PRS 主程序，或重新解压完整安装包。", "Bundled component files are missing. Reinstall the PRS main package in ReaPack, or extract the complete offline package again."), "PsyReaSFX", 0)
    return false
  end
  local resource = reaper.GetResourcePath():gsub("[/\\]+$", "")
  local function quote(path)
    assert(not path:find('["\r\n%z]'), tr("无效安装路径", "Invalid installation path"))
    return '"' .. path .. '"'
  end
  local section, key = "PsyReaSFX.Setup", resource:lower()
  local request = reaper.GetExtState(section, key)
  if not request:match("^[a-f0-9]+$") or #request ~= 32 then
    request = reaper.genGuid():gsub("[^%x]", ""):lower()
    if #request ~= 32 then reaper.MB(tr("无法启动组件安装。", "Could not start component setup. Run the installer from the complete PRS package."), "PsyReaSFX", 0); return false end
    local command = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -STA -File '
      .. quote(helper) .. ' -ReaperResourcePath ' .. quote(resource) .. ' -RequestId ' .. request
      .. ' -WaitForReaperExit -Notify -Language ' .. language
    local ok, result = pcall(reaper.ExecProcess, command, -1)
    if not ok or result == nil or tostring(result):match("^%-[0-9]+") then
      reaper.MB(tr("无法启动随包安装助手，请运行完整安装包中的安装程序。", "Could not start the bundled setup helper. Run the installer from the complete PRS package."), "PsyReaSFX", 0)
      return false
    end
    reaper.SetExtState(section, key, request, false)
  end
  local status_path = resource .. "/Data/PsyReaSFX-WebView/runtime-setup-" .. request .. ".txt"
  local deadline = reaper.time_precise() + 5
  local function poll()
    local file = io.open(status_path, "rb")
    local status = file and file:read(4096)
    if file then file:close() end
    local phase, message = (status or ""):match("^(%a+)\n(.+)$")
    if phase == "ready" or phase == "waiting" or phase == "error" then
      if phase == "error" then reaper.DeleteExtState(section, key, false) end
      reaper.MB(message, tr("PsyReaSFX · 随包组件", "PsyReaSFX · Bundled component"), 0)
    elseif reaper.time_precise() < deadline then reaper.defer(poll)
    else
      reaper.DeleteExtState(section, key, false)
      reaper.MB(tr("尚未收到组件准备结果。请稍后重新运行 PRS，或使用完整安装包中的安装程序；无需另外下载运行库。", "Component setup has not returned a result yet. Run PRS again shortly, or use the installer from the complete package. No separate runtime download is needed."), "PsyReaSFX", 0)
    end
  end
  poll()
  return false
end
