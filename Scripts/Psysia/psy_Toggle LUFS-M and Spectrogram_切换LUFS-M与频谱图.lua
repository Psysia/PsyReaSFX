-- @description Toggle LUFS-M and Spectrogram / 切换 LUFS-M 与频谱图
-- @version 1.1
-- @author Psysia
--
-- 在以下两种峰值显示模式之间切换：
-- 1. Peaks: Toggle show spectral peaks and graph of momentary loudness (LUFS-M)
-- 2. Peaks: Toggle spectrogram
--
-- 无需 SWS / ReaPack。
-- 自动兼容 REAPER 当前语言包，并缓存已解析的 Command ID。

local MAIN_SECTION_ID = 0
local CACHE_SECTION = "toggle_lufs_m_spectrogram"

local ACTION_LUFS_M =
  "Peaks: Toggle show spectral peaks and graph of momentary loudness (LUFS-M)"

local ACTION_SPECTROGRAM =
  "Peaks: Toggle spectrogram"

local function add_candidate(candidates, seen, value)
  if not value or value == "" or seen[value] then
    return
  end

  seen[value] = true
  candidates[#candidates + 1] = value
end

local function get_action_name_candidates(target)
  local candidates = {}
  local seen = {}

  -- 永远保留 REAPER 原始英文动作名作为兼容后备。
  add_candidate(candidates, seen, target)

  -- REAPER 语言包中的动作名称位于 actions 区段。
  -- 使用当前语言包动态取得显示名称，避免硬编码中文翻译。
  if reaper.LocalizeString then
    local ok, localized = pcall(
      reaper.LocalizeString,
      target,
      "actions",
      0
    )

    if ok then
      add_candidate(candidates, seen, localized)
    end
  end

  return candidates
end

local function name_matches(name, candidates)
  if not name or name == "" then
    return false
  end

  for _, candidate in ipairs(candidates) do
    -- 精确匹配：英文或纯本地化语言包。
    if name == candidate then
      return true
    end

    -- 子串匹配：兼容“中文说明 = English action”之类的双语语言包。
    if name:find(candidate, 1, true) then
      return true
    end
  end

  return false
end

local function find_action(section, target, cache_key)
  local candidates = get_action_name_candidates(target)

  -- 优先读取缓存，但每次都按当前语言包重新验证。
  -- 因此重新导入配置或切换语言后，旧缓存不会造成错误绑定。
  local cached_id = tonumber(reaper.GetExtState(CACHE_SECTION, cache_key))

  if cached_id and cached_id > 0 then
    local cached_name = reaper.kbd_getTextFromCmd(cached_id, section)
    if name_matches(cached_name, candidates) then
      return cached_id
    end
  end

  -- 缓存不存在或失效时，遍历主动作区重新定位。
  local index = 0

  while true do
    local command_id, action_name =
      reaper.kbd_enumerateActions(section, index)

    if not command_id or command_id == 0 then
      break
    end

    if name_matches(action_name, candidates) then
      reaper.SetExtState(
        CACHE_SECTION,
        cache_key,
        tostring(command_id),
        true
      )
      return command_id
    end

    index = index + 1
  end

  return nil
end

local function show_error(message)
  reaper.ShowMessageBox(
    message,
    "切换 LUFS-M / 频谱图",
    0
  )
end

if not reaper.SectionFromUniqueID
or not reaper.kbd_enumerateActions
or not reaper.kbd_getTextFromCmd then
  show_error(
    "当前 REAPER 版本不支持脚本所需的动作枚举 API。\n"
    .. "请更新 REAPER 后再试。"
  )
  return
end

local main_section = reaper.SectionFromUniqueID(MAIN_SECTION_ID)

if not main_section then
  show_error("无法读取 REAPER 主动作区。")
  return
end

local command_lufs_m =
  find_action(main_section, ACTION_LUFS_M, "command_lufs_m")

local command_spectrogram =
  find_action(main_section, ACTION_SPECTROGRAM, "command_spectrogram")

if not command_lufs_m or not command_spectrogram then
  local missing = {}

  if not command_lufs_m then
    missing[#missing + 1] = ACTION_LUFS_M
  end

  if not command_spectrogram then
    missing[#missing + 1] = ACTION_SPECTROGRAM
  end

  show_error(
    "未找到所需的 REAPER 峰值显示动作：\n\n"
    .. table.concat(missing, "\n")
    .. "\n\n请确认当前 REAPER 版本包含这些峰值显示功能。"
  )
  return
end

local lufs_m_is_on =
  reaper.GetToggleCommandStateEx(
    MAIN_SECTION_ID,
    command_lufs_m
  ) == 1

local spectrogram_is_on =
  reaper.GetToggleCommandStateEx(
    MAIN_SECTION_ID,
    command_spectrogram
  ) == 1

reaper.PreventUIRefresh(1)

if lufs_m_is_on then
  -- LUFS-M 模式 -> 纯频谱图模式
  reaper.Main_OnCommand(command_lufs_m, 0)

  -- 如果频谱图已经开启，不重复执行，避免反向关闭。
  if not spectrogram_is_on then
    reaper.Main_OnCommand(command_spectrogram, 0)
  end
else
  -- 纯频谱图模式或其他模式 -> LUFS-M 模式
  if spectrogram_is_on then
    reaper.Main_OnCommand(command_spectrogram, 0)
  end

  reaper.Main_OnCommand(command_lufs_m, 0)
end

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.UpdateTimeline()
