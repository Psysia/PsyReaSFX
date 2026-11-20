-- Resolve source media at the I/O boundary. The catalog keeps its original
-- paths for row identity, favorites, region edits and Soundminer waveform hashes.
SoundminerPaths = {}
do
  local P = SoundminerPaths
  local profiles, retry_at, current_scope = {}, 0, nil
  local drives, drives_at = "", 0

  local function windows_catalog()
    return SEP == "\\" and PsyReaSFXScope and PsyReaSFXScope.kind == "soundminer"
  end

  local function clean(path)
    if type(path) ~= "string" or #path > 32768 or path:find("[%z\1-\31]") then return end
    path = path:gsub("\\", "/")
    if path:sub(1, 8):lower() == "//?/unc/" then path = "//" .. path:sub(9)
    elseif path:match("^//%?/%a:/") then path = path:sub(5) end
    for part in path:gmatch("[^/]+") do
      if part == "." or part == ".." then return end
    end
    if path == "/" then return path end
    local trimmed = path:gsub("/+$", "")
    return trimmed
  end

  local function local_root(path)
    if not path or path:find('[<>"|?*]') then return end
    if path:match("^%a:$") or path:match("^%a:/") then
      if not path:sub(3):find(":", 1, true) then return path end
    elseif path:match("^//[^/]+/[^/]+") and not path:find(":", 1, true) then
      local share = path:match("^//[^/]+/([^/]+)"):lower()
      if share ~= "pipe" and share ~= "mailslot" then return path end
    end
  end

  local function xml_value(value)
    local entities = {amp="&", lt="<", gt=">", apos="'", quot='"'}
    return value:gsub("&([#%w]+);", function(entity)
      if entities[entity] then return entities[entity] end
      local hex = entity:match("^#[xX]([%da-fA-F]+)$")
      local n = hex and tonumber(hex, 16) or tonumber(entity:match("^#(%d+)$") or "")
      if n and n >= 32 and n <= 0x10ffff and (n < 0xd800 or n > 0xdfff) then return utf8.char(n) end
    end)
  end

  local function rules_from_xml(xml)
    local rules = {}
    xml = xml:gsub("<!%-%-.-%-%->", ""):gsub("<!%[CDATA%[.-%]%]>", "")
    local section = xml:match("<relinkpresets%s*>(.-)</relinkpresets%s*>") or ""
    for item in section:gmatch("<item%s+(.-)/%s*>") do
      local attr = {}
      for key, _, value in item:gmatch("([%w_]+)%s*=%s*(['\"])(.-)%2") do attr[key] = xml_value(value) end
      local source, dest = clean(attr.source), local_root(clean(attr.dest))
      if (attr.state == "1" or attr.state == "true") and source and dest
        and (source:sub(1, 1) == "/" or local_root(source)) then
        rules[#rules + 1] = {source = source, dest = dest}
      end
    end
    return rules
  end

  local function profile_rules()
    local now = HostApi.time_precise()
    if current_scope == PsyReaSFXScope and now < retry_at then return profiles.rules end
    local previous = current_scope == PsyReaSFXScope and profiles
    current_scope, retry_at, profiles = PsyReaSFXScope, now + 5, previous or {rules={}}
    local base = os.getenv("APPDATA")
    if not base or base == "" then return profiles.rules end
    local version = (PsyReaSFXScope.sourcePath or ""):gsub("\\", "/"):lower():match("/soundminerv([567])/")
    for _, v in ipairs(version and {version} or {"7", "6", "5"}) do
      local path = base .. "/SoundminerV" .. v .. "/v" .. v .. "Prefs.xml"
      local file, _, code = SoundminerReadOnly.open(path)
      if file then
        local stamp = table.concat({path, file.identity, file.mtime, tostring(file.size)}, "|")
        if previous and previous.stamp == stamp then
          profiles = previous
        elseif file.size > 0 and file.size <= 2 * 1024 * 1024 then
          local xml = file:read(file.size)
          if xml and #xml == file.size and xml:find("<PROPERTIES[%s>]") and xml:match("</PROPERTIES>%s*$") and file:unchanged() then
            profiles = {rules=rules_from_xml(xml), stamp=stamp}
          end
        end
        file:close()
        break
      end
      if code ~= 2 then break end
    end
    return profiles.rules
  end

  local function suffix(path, prefix)
    local p, root = path, prefix
    if prefix:match("^%a:") or prefix:sub(1, 2) == "//" then p, root = p:lower(), root:lower() end
    if p == root then return "" end
    if root == "/" and p:match("^/[^/]") then return path end
    if p:sub(1, #root + 1) == root .. "/" then return path:sub(#root + 1) end
  end

  local function joined(root, relative)
    local path = root .. relative
    if not local_root(path) then return end
    if path:match("^%a:$") then path = path .. "/" end
    return normalize_slashes(path)
  end

  local function readable(path, directory)
    if not path then return end
    local info = SoundminerReadOnly.stat(path)
    if info and info.directory == (directory == true) then return info end
  end

  local function unavailable(ambiguous, path)
    local label = ambiguous and "多个磁盘包含此 Soundminer 路径，请设置路径映射"
      or "无法定位 Soundminer 素材，请检查磁盘连接或设置路径映射"
    return nil, translate_ui_text(label) .. " · " .. tostring(path or "")
  end

  function P.resolve(path, directory)
    if not windows_catalog() then return path end
    local logical = clean(path)
    if not logical or logical == "" then return unavailable(false, path) end
    local volume, tail = logical:match("^/Volumes/([^/]+)(.*)$")
    local native = local_root(logical)
    if not native and not logical:match("^/[^/]") and logical ~= "/" then return unavailable(false, path) end
    local original_path = native and normalize_slashes(path)
    if not SoundminerReadOnly.available() then
      return nil, translate_ui_text("当前 ReaWebAPI 缺少共享只读接口；请更新兼容运行库后导入，已有素材库仍可浏览")
    end
    local params = PsyReaSFXScope.params or {}
    local old, new = clean(params.oldPrefix), local_root(clean(params.newPrefix))
    if old and old ~= "" and new then
      -- Beta 7 already stored explicit mappings in the catalog. Those rows
      -- retain their chosen destination even when a profile also matches it.
      if suffix(logical, new) then
        local info = readable(original_path, directory)
        if info then return original_path, nil, info end
        return unavailable(false, path)
      end
      local relative = suffix(logical, old)
      if relative then
        local selected = joined(new, relative)
        local info = readable(selected, directory)
        if info then return selected, nil, info end
        return unavailable(false, path)
      end
    end
    -- A bare /Volumes path is relative to the current Windows drive. Only
    -- drive-qualified and UNC sources can be original Windows paths.
    local original = readable(original_path, directory)
    if original then return original_path, nil, original end
    local rules = profile_rules()
    local matched
    for _, rule in ipairs(rules) do
      local relative = suffix(logical, rule.source)
      if relative then
        matched = true
        local selected = joined(rule.dest, relative)
        local info = readable(selected, directory)
        if info then return selected, nil, info end
      end
    end
    if matched or not volume then return unavailable(false, path) end
    -- With no preset, test the complete relative path on each mounted local
    -- drive. No directory traversal, filename-only guess or network search.
    local now = HostApi.time_precise()
    if now >= drives_at then
      drives_at = now + 5
      drives = reaper.PRS_SM_LocalDrives and reaper.PRS_SM_LocalDrives() or ""
    end
    local found, info
    for drive in (drives or ""):gmatch("[A-Z]") do
      local candidate = joined(drive .. ":", tail)
      local available = readable(candidate, directory)
      if available then
        if found then return unavailable(true, path) end
        found, info = candidate, available
      end
    end
    if found then return found, nil, info end
    return unavailable(false, path)
  end

  function P.stat(path, directory)
    local physical, reason, info = P.resolve(path, directory)
    if not physical then return nil, reason end
    if info then return info end
    return SoundminerReadOnly.stat(physical)
  end

  function P.open(path)
    local physical, reason, info = P.resolve(path)
    if not physical then return nil, reason, nil, true end
    return SoundminerReadOnly.open(physical, info)
  end
end
