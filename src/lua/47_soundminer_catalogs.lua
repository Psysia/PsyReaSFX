-- Isolated catalog launchers share program files, never mutable catalog data.
SoundminerCatalog = {}

local function smc_path(value, optional)
  if value == nil and optional then value = "" end
  assert(type(value) == "string" and #value <= 32768 and not value:find("[%z\1-\31]"), "Soundminer 路径无效")
  value = value:gsub("\\", "/")
  if value == "" then assert(optional, "请选择 Soundminer 数据库"); return value end
  assert(value:match("^%a:/") or value:sub(1, 1) == "/", "路径必须是绝对路径")
  for part in value:gmatch("[^/]+") do assert(part ~= "." and part ~= "..", "路径不能包含 . 或 .. 路径段") end
  if value ~= "/" and not value:match("^%a:/+$") then value = value:gsub("/+$", "") end
  if value:match("^%a:/+$") then value = value:sub(1, 3) end
  return value
end

local function smc_parameters(params)
  assert(type(params) == "table", "Soundminer 导入参数无效")
  local normalized = { path = smc_path(params.path), oldPrefix = smc_path(params.oldPrefix, true),
    newPrefix = smc_path(params.newPrefix, true), cachePath = smc_path(params.cachePath, true),
    waveforms = params.waveforms ~= false }
  assert((normalized.oldPrefix == "") == (normalized.newPrefix == ""), "路径映射需要同时填写原路径和新路径")
  return normalized
end

local function smc_identity(params)
  local parts = {}
  for _, name in ipairs({ "path", "oldPrefix", "newPrefix" }) do
    local value = params[name]
    if value:match("^%a:/") or value:sub(1, 2) == "//" then value = value:lower() end
    parts[#parts + 1] = tostring(#value) .. ":" .. value
  end
  return table.concat(parts, "|")
end

local function smc_id(identity)
  return "sm_" .. fnv1a("catalog|" .. identity) .. fnv1a("identity|" .. identity)
end

local function smc_valid_id(id)
  return type(id) == "string" and id:match("^sm_%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

local function smc_name(value)
  -- The byte cap also applies to wrapper/bootstrap context; stop before a
  -- complete codepoint that would cross it instead of splitting UTF-8 text.
  local finish = 0
  for position in utf8.codes(value) do
    local next_position = utf8.offset(value, 2, position) or (#value + 1)
    if next_position - 1 > 256 then break end
    finish = next_position - 1
  end
  return value:sub(1, finish)
end

local function smc_root(id)
  assert(smc_valid_id(id), "无效的独立素材库标识")
  return join_path(join_path(PsyReaSFXScope.baseDirectory, "isolated_soundminer"), id)
end

local function smc_manifest_path(id) return join_path(smc_root(id), "catalog.json") end

local function smc_read_manifest(id)
  local path = smc_manifest_path(id)
  local file, open_error, open_code = io.open(path, "rb")
  -- A crash between the two Windows renames can leave the previous manifest
  -- at .bak. The same identity validation applies to both generations.
  if not file and open_code == 2 then file, open_error, open_code = io.open(path .. ".bak", "rb") end
  if not file then assert(open_code == 2, open_error); return nil end
  local bytes = file:read(262145) or ""; file:close()
  assert(#bytes <= 262144, "独立素材库清单过大")
  local decoded = neural_json_decode(bytes)
  assert(type(decoded) == "table" and decoded.schema == "PsyReaSFX-Soundminer-Catalog-v1"
    and decoded.id == id and type(decoded.name) == "string" and #decoded.name > 0 and #decoded.name <= 256
    and not decoded.name:find("[%z\1-\31]"), "独立素材库清单无效")
  decoded.params = smc_parameters(decoded.params)
  local identity = smc_identity(decoded.params)
  assert(decoded.identity == identity and id == smc_id(identity), "独立素材库身份不匹配")
  assert(type(decoded.consumed) == "boolean", "独立素材库导入标记无效")
  return decoded
end

local function smc_write(path, bytes)
  local writer, reason = atomic_file_writer(path)
  assert(writer, reason)
  local ok, err = writer:write(bytes)
  if not ok then writer:abort(); error(err or "无法写入独立素材库", 0) end
  local closed, close_error = writer:close()
  assert(closed, close_error)
end

local function smc_save_manifest(manifest)
  smc_write(smc_manifest_path(manifest.id), neural_json_encode(manifest))
end

local function smc_window_key(id)
  local key = SCRIPT_FILE:gsub("\\", "/")
  if HostApi.GetOS():match("^Win") then key = key:lower() end
  return id == "prs" and key or key .. "|catalog:" .. id
end

local function smc_focus(id)
  local window = tonumber(HostApi.GetExtState("PsyReaSFX.Web", smc_window_key(id)))
  if window and type(HostApi.ReaWeb_IsOpen) == "function" and HostApi.ReaWeb_IsOpen(window) then
    if type(HostApi.ReaWeb_Show) == "function" then HostApi.ReaWeb_Show(window) end
    if type(HostApi.ReaWeb_Focus) == "function" then HostApi.ReaWeb_Focus(window) end
    return true
  end
  return false
end

local function smc_wrapper(manifest)
  local params = manifest.params
  local script = table.concat({
    "-- @description PsyReaSFX Soundminer catalog (background runtime)\n",
    "-- Generated descriptor only; the installed shared runtime stays authoritative.\n",
    "PRS_SOUNDMINER_CONTEXT = { id = ", string.format("%q", manifest.id),
    ", name = ", string.format("%q", manifest.name), ", identity = ", string.format("%q", manifest.identity),
    ", params = { path = ", string.format("%q", params.path), ", oldPrefix = ", string.format("%q", params.oldPrefix),
    ", newPrefix = ", string.format("%q", params.newPrefix), ", cachePath = ", string.format("%q", params.cachePath),
    ", waveforms = ", tostring(params.waveforms), " } }\n",
    "assert(loadfile(", string.format("%q", SCRIPT_FILE), "))()\n",
  })
  local path = join_path(smc_root(manifest.id), "Open-Catalog.lua")
  smc_write(path, script)
  return path
end

local function smc_launch(path)
  assert(type(HostApi.AddRemoveReaScript) == "function" and type(HostApi.Main_OnCommand) == "function",
    "当前宿主无法打开独立素材库")
  local action = HostApi.AddRemoveReaScript(true, 0, path, true)
  assert(action and action ~= 0, "无法注册独立素材库入口")
  HostApi.Main_OnCommand(action, 0)
end

function SoundminerCatalog.current()
  return { id = PsyReaSFXScope.id, kind = PsyReaSFXScope.kind, name = PsyReaSFXScope.name,
    sourcePath = PsyReaSFXScope.sourcePath, dataDirectory = PsyReaSFXScope.dataDirectory }
end

function SoundminerCatalog.matches(params)
  if PsyReaSFXScope.kind ~= "soundminer" then return false end
  local ok, normalized = pcall(smc_parameters, params)
  return ok and smc_identity(normalized) == PsyReaSFXScope.identity
end

function SoundminerCatalog.list()
  local items = { { id = "prs", kind = "prs", name = "PRS", sourcePath = "",
    dataDirectory = PsyReaSFXScope.baseDirectory, active = PsyReaSFXScope.id == "prs" } }
  local parent = join_path(PsyReaSFXScope.baseDirectory, "isolated_soundminer")
  for index = 0, 4095 do
    local id = HostApi.EnumerateSubdirectories(parent, index)
    if not id then break end
    if smc_valid_id(id) then
      local ok, manifest = pcall(smc_read_manifest, id)
      if ok and manifest then
        items[#items + 1] = { id = id, kind = "soundminer", name = manifest.name,
          sourcePath = manifest.params.path, path = manifest.params.path, dataDirectory = join_path(smc_root(id), "data"),
          active = PsyReaSFXScope.id == id }
      end
    end
  end
  table.sort(items, function(a, b)
    if a.id == "prs" then return b.id ~= "prs" end
    if b.id == "prs" then return false end
    if a.name == b.name then return a.id < b.id end
    return a.name < b.name
  end)
  return { current = PsyReaSFXScope.id, catalogs = items }
end

function SoundminerCatalog.activate(id)
  assert(id == "prs" or smc_valid_id(id), "无效的独立素材库标识")
  if smc_focus(id) then return { opened = true, reused = true, id = id } end
  if id == "prs" then smc_launch(SCRIPT_FILE)
  else
    local manifest = assert(smc_read_manifest(id), "独立素材库不存在")
    smc_launch(smc_wrapper(manifest))
  end
  return { opened = true, reused = false, id = id }
end

function SoundminerCatalog.open(params)
  local normalized = smc_parameters(params)
  local identity = smc_identity(normalized)
  local id = smc_id(identity)
  local manifest = smc_read_manifest(id)
  if manifest then
    -- Never replace a colliding namespace, even if its existing index is empty.
    assert(manifest.identity == identity, "独立素材库标识冲突；未修改已有素材库")
    if manifest.params.cachePath ~= normalized.cachePath or manifest.params.waveforms ~= normalized.waveforms then
      manifest.params.cachePath, manifest.params.waveforms = normalized.cachePath, normalized.waveforms
      smc_save_manifest(manifest)
    end
  else
    local inspected = SoundminerImport.inspect(normalized.path)
    manifest = { schema = "PsyReaSFX-Soundminer-Catalog-v1", id = id, identity = identity,
      name = smc_name(inspected.name), params = normalized, importState = "pending", consumed = false }
    assert(manifest.name ~= "" and not manifest.name:find("[%z\1-\31]"), "Soundminer 数据库名称无效")
    HostApi.RecursiveCreateDirectory(smc_root(id), 0)
    smc_wrapper(manifest)
    smc_save_manifest(manifest)
  end
  local opened = SoundminerCatalog.activate(id)
  opened.started, opened.isolated, opened.name = true, true, manifest.name
  return opened
end

local function smc_current_manifest()
  assert(PsyReaSFXScope.kind == "soundminer", "请选择独立 Soundminer 素材库")
  local manifest = assert(smc_read_manifest(PsyReaSFXScope.id), "独立素材库清单缺失")
  assert(manifest.identity == PsyReaSFXScope.identity, "独立素材库来源已改变")
  return manifest
end

local function smc_import_state(manifest, phase)
  if manifest.importState == phase then return end
  manifest.importState, manifest.consumed = phase, phase ~= "pending"
  smc_save_manifest(manifest)
end

function SoundminerCatalog.set_outcome(phase)
  -- Re-read so changes to the user's cache options in another window survive.
  smc_import_state(smc_current_manifest(), phase)
end

function SoundminerCatalog.resume()
  local manifest = smc_current_manifest()
  assert(not state.import_session and not state.database_snapshot_session, "请等待当前扫描或导入完成")
  local started = SoundminerImport.start(manifest.params)
  local saved, reason = pcall(smc_import_state, manifest, "pending")
  if not saved then SoundminerImport.cancel(state.import_session, true); error(reason, 0) end
  AppState.set("soundminer_catalog_checked", true)
  return started
end

function SoundminerCatalog.process_pending()
  if PsyReaSFXScope.kind ~= "soundminer" or state.soundminer_catalog_checked or state.startup_session then return end
  if state.persistence_read_only or state.import_session or state.scan then return end
  for _, job in pairs(Jobs.active) do
    if job.resource == "catalog_exclusive" then return end
  end
  local ok, reason = pcall(function()
    local manifest = smc_current_manifest()
    -- Older versions marked the job consumed before reading its first row.
    -- A committed index (including one emptied by the user) is authoritative.
    if manifest.importState == "complete" or manifest.importState == "canceled"
      or (manifest.importState == nil and manifest.consumed and HostApi.file_exists(DATABASE_FILE)) then
      AppState.set("soundminer_catalog_checked", true); return
    end
    SoundminerCatalog.resume()
  end)
  if not ok then
    AppState.set("soundminer_catalog_checked", true)
    local message = translate_ui_text("独立 Soundminer 素材库") .. " · " .. translate_ui_text(reason)
    AppState.set("soundminer_report", { error = message })
    set_status(message, true)
  end
end
