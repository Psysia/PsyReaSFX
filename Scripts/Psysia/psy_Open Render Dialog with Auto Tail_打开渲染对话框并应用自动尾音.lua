-- @description Open Render Dialog with Auto Tail / 打开渲染对话框并应用自动尾音
-- @version 1.0
-- @author Psysia
--
-- Use this instead of File > Render when you want the toolbar switch to apply.

local EXT_SECTION = "CodexAutoTailRender"
local ACTION_OPEN_RENDER_DIALOG = 40015

local DEFAULT_MAX_TAIL_SECONDS = 12
local DEFAULT_TRIM_THRESHOLD_DB = -60
local DEFAULT_PAD_AFTER_TRIM_MS = 80

local FLAG_TIME_SELECTION_TAIL = 4
local FLAG_ALL_MARKERS_REGIONS_TAIL = 8
local FLAG_TRIM_ENDING_SILENCE = 32768
local FLAG_SELECTED_MEDIA_ITEMS_TAIL = 16
local FLAG_SELECTED_MARKERS_REGIONS_TAIL = 32
local FLAG_PAD_END = 131072
local FLAG_DISABLE_POSTPROCESSING = 262144

local function has_flag(value, flag)
  value = math.floor(tonumber(value) or 0)
  return math.floor(value / flag) % 2 == 1
end

local function add_flag(value, flag)
  value = math.floor(tonumber(value) or 0)
  if has_flag(value, flag) then
    return value
  end
  return value + flag
end

local function remove_flag(value, flag)
  value = math.floor(tonumber(value) or 0)
  if has_flag(value, flag) then
    return value - flag
  end
  return value
end

local function read_number(value, fallback)
  local number = tonumber(value)
  if not number then
    return fallback
  end
  return number
end

local function get_ext_number(key, fallback)
  local value = reaper.GetExtState(EXT_SECTION, key)
  if value == nil or value == "" then
    return fallback
  end
  return read_number(value, fallback)
end

local function db_to_amplitude(db)
  return 10 ^ (db / 20)
end

local function get_tail_flag_for_bounds(bounds_flag)
  bounds_flag = math.floor(tonumber(bounds_flag) or 2)
  if bounds_flag == 3 or bounds_flag == 6 then
    return FLAG_ALL_MARKERS_REGIONS_TAIL
  end
  if bounds_flag == 4 then
    return FLAG_SELECTED_MEDIA_ITEMS_TAIL
  end
  if bounds_flag == 5 or bounds_flag == 7 then
    return FLAG_SELECTED_MARKERS_REGIONS_TAIL
  end
  return FLAG_TIME_SELECTION_TAIL
end

local function add_all_supported_tail_flags(tail_flags)
  tail_flags = add_flag(tail_flags, FLAG_TIME_SELECTION_TAIL)
  tail_flags = add_flag(tail_flags, FLAG_ALL_MARKERS_REGIONS_TAIL)
  tail_flags = add_flag(tail_flags, FLAG_SELECTED_MEDIA_ITEMS_TAIL)
  tail_flags = add_flag(tail_flags, FLAG_SELECTED_MARKERS_REGIONS_TAIL)
  return tail_flags
end

local function apply_auto_tail_settings()
  local max_tail_seconds = math.max(
    0,
    get_ext_number("max_tail_seconds", DEFAULT_MAX_TAIL_SECONDS)
  )
  local trim_threshold_db = math.min(
    0,
    get_ext_number("trim_threshold_db", DEFAULT_TRIM_THRESHOLD_DB)
  )
  local pad_after_trim_ms = math.max(
    0,
    get_ext_number("pad_after_trim_ms", DEFAULT_PAD_AFTER_TRIM_MS)
  )

  local current_bounds_flag = reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 0, false)
  if math.floor(current_bounds_flag) ~= 5 and math.floor(current_bounds_flag) ~= 3 then
    reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 2, true)
    current_bounds_flag = 2
  end
  reaper.GetSetProjectInfo(0, "RENDER_TAILMS", max_tail_seconds * 1000, true)
  reaper.GetSetProjectInfo(0, "RENDER_TRIMEND", db_to_amplitude(trim_threshold_db), true)
  reaper.GetSetProjectInfo(0, "RENDER_PADEND", pad_after_trim_ms / 1000, true)

  local tail_flags = reaper.GetSetProjectInfo(0, "RENDER_TAILFLAG", 0, false)
  tail_flags = add_flag(tail_flags, get_tail_flag_for_bounds(current_bounds_flag))
  tail_flags = add_all_supported_tail_flags(tail_flags)
  reaper.GetSetProjectInfo(0, "RENDER_TAILFLAG", tail_flags, true)

  local normalize_flags = reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE", 0, false)
  normalize_flags = remove_flag(normalize_flags, FLAG_DISABLE_POSTPROCESSING)
  normalize_flags = add_flag(normalize_flags, FLAG_TRIM_ENDING_SILENCE)
  if pad_after_trim_ms > 0 then
    normalize_flags = add_flag(normalize_flags, FLAG_PAD_END)
  else
    normalize_flags = remove_flag(normalize_flags, FLAG_PAD_END)
  end
  reaper.GetSetProjectInfo(0, "RENDER_NORMALIZE", normalize_flags, true)
end

if reaper.GetExtState(EXT_SECTION, "enabled") == "1" then
  apply_auto_tail_settings()
end

reaper.Main_OnCommand(ACTION_OPEN_RENDER_DIALOG, 0)
