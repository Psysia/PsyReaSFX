-- @description Toggle LUFS-M and Spectrogram / 切换 LUFS-M 与频谱图
-- @version 1.0
-- @author Psysia
--
-- 在以下两种峰值显示模式之间切换：
-- 1. Peaks: Toggle show spectral peaks and graph of momentary loudness (LUFS-M)
-- 2. Peaks: Toggle spectrogram
--
-- 无需 SWS / ReaPack。
-- 脚本会按动作名称自动查找当前 REAPER 中的 Command ID，并缓存结果。

local MAIN_SECTION_ID = 0
local CACHE_SECTION = "toggle_lufs_m_spectrogram"

local ACTION_LUFS_M =
  "Peaks: Toggle show spectral peaks and graph of momentary loudness (LUFS-M)"

local ACTION_SPECTROGRAM =
  "Peaks: Toggle spectrogram"

local function name_matches(name, target)
  if not name or name == "" then
    return false
  end

  -- 英文界面：动作名称完全一致。
  if name == target then
    return true
  end

  -- 兼容截图中的中英双语语言包：
  -- “中文说明 = Peaks: ...”
  return #name >= #target and name:sub(-#target) == target
end

local function find_action(section, target, cache_key)
  -- 优先读取缓存，并验证缓存仍然对应目标动作。
  local cached_id = tonumber(reaper.GetExtState(CACHE_SECTION, cache_key))

  if cached_id and cached_id > 0 then
    local cached_name = reaper.kbd_getTextFromCmd(cached_id, section)
    if name_matches(cached_name, target) then
      return cached_id
    end
  end

  -- 缓存无效时，遍历主动作区并按名称查找。
  local index = 0

  while true do
    local command_id, action_name =
      reaper.kbd_enumerateActions(section, index)

    if not command_id or command_id == 0 then
      break
    end

    if name_matches(action_name, target) then
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
    "未找到以下 REAPER 动作：\n\n"
    .. table.concat(missing, "\n")
    .. "\n\n请确认动作列表中仍显示这些英文名称。"
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
