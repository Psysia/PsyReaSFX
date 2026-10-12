-- @description Psysia: Hold W to audition track under mouse / 按住 W 临时独奏鼠标下轨道，松开恢复
-- @version 0.2.0
-- @author Psysia
-- @about
--   Single-file ReaScript; replaces the SWS/BR momentary track solo action.
--   Requires SWS and js_ReaScriptAPI (already installed on your REAPER).
--   Assign W to THIS script in the Main action section; remove W from the old SWS action.
--   Original track Solo/Mute values and playback/cursor state are restored on release.

local KEY_W = 0x57                -- Windows VK_W; Lua string index is also 87 (NOT 88)
local MAX_HOLD = 120.0            -- Fail-safe if keyboard release cannot be read
local FIRST_CHECK_GRACE = 0.12   -- First REAPER defer may run before key message dispatch
local PROJ = reaper.EnumProjects(-1)

local function msg(s) reaper.MB(s, "Psysia Mouse Solo", 0) end

if not (reaper.JS_VKeys_GetState and reaper.JS_VKeys_GetUp and reaper.JS_VKeys_Intercept) then
  msg("缺少 js_ReaScriptAPI 扩展，请通过 ReaPack 安装。")
  return
end
if not reaper.BR_PositionAtMouseCursor then
  msg("缺少 SWS 扩展，无法取得鼠标所在的播放时间。")
  return
end
if (reaper.GetPlayStateEx(PROJ) & 4) ~= 0 then return end -- Do not interfere with recording

local started_at = reaper.time_precise()
local function vkey_is_set(fun, cutoff)
  local ok, data = pcall(fun, cutoff)
  if not ok or type(data) ~= "string" or #data < KEY_W then return false end
  -- JS_VKeys_* returns 255 bytes indexed 1..255 by Windows virtual-key value.
  return (data:byte(KEY_W) or 0) ~= 0
end
local function w_down()
  return vkey_is_set(reaper.JS_VKeys_GetState, started_at - 0.3)
end
local function w_released()
  return vkey_is_set(reaper.JS_VKeys_GetUp, started_at)
end

local mx, my = reaper.GetMousePosition()
local target = reaper.GetTrackFromPoint(mx, my)
if not target and reaper.BR_GetMouseCursorContext then
  reaper.BR_GetMouseCursorContext()
  target = reaper.BR_GetMouseCursorContext_Track()
end
if not target or target == reaper.GetMasterTrack(PROJ) then return end

local mouse_pos = reaper.BR_PositionAtMouseCursor(true)
if type(mouse_pos) ~= "number" or mouse_pos < 0 then
  return -- Only trigger when mouse is on arrange timeline, like the original SWS action
end

local tracks = {}
for i = 0, reaper.CountTracks(PROJ) - 1 do
  local tr = reaper.GetTrack(PROJ, i)
  tracks[#tracks + 1] = {
    ptr = tr,
    solo = reaper.GetMediaTrackInfo_Value(tr, "I_SOLO"),
    mute = reaper.GetMediaTrackInfo_Value(tr, "B_MUTE")
  }
end

local prev_playstate = reaper.GetPlayStateEx(PROJ)
local prev_cursor = reaper.GetCursorPositionEx(PROJ)
local prev_playpos = reaper.GetPlayPositionEx(PROJ)
local intercepted, changed, finished = false, false, false

local function restore_transport()
  if (prev_playstate & 1) ~= 0 and (prev_playstate & 2) == 0 then
    -- Audition interrupted ongoing playback: restore previous play location.
    if (reaper.GetPlayStateEx(PROJ) & 1) == 0 then
      reaper.SetEditCurPos2(PROJ, prev_playpos, false, false)
      reaper.OnPlayButtonEx(PROJ)
    else
      reaper.SetEditCurPos2(PROJ, prev_playpos, false, true)
    end
    reaper.SetEditCurPos2(PROJ, prev_cursor, false, false)
  else
    reaper.OnStopButtonEx(PROJ)
    reaper.SetEditCurPos2(PROJ, prev_cursor, false, false)
    if (prev_playstate & 2) ~= 0 then reaper.OnPauseButtonEx(PROJ) end
  end
end

local function cleanup()
  if finished then return end
  finished = true
  if changed then
    pcall(restore_transport)
    for _, s in ipairs(tracks) do
      if reaper.ValidatePtr2(PROJ, s.ptr, "MediaTrack*") then
        pcall(reaper.SetMediaTrackInfo_Value, s.ptr, "I_SOLO", s.solo)
        pcall(reaper.SetMediaTrackInfo_Value, s.ptr, "B_MUTE", s.mute)
      end
    end
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()
    changed = false
  end
  if intercepted then
    pcall(reaper.JS_VKeys_Intercept, KEY_W, -1)
    intercepted = false
  end
end

reaper.atexit(cleanup) -- Also recovers if the running script is stopped from the Action List.

local function begin()
  -- Block auto-repeating W keydown from re-triggering this action.
  reaper.JS_VKeys_Intercept(KEY_W, 1)
  intercepted = true
  changed = true

  -- Save/restore ALL existing Solo states; temporary Solo is exclusive.
  for _, s in ipairs(tracks) do
    if s.solo ~= 0 then reaper.SetMediaTrackInfo_Value(s.ptr, "I_SOLO", 0) end
  end

  -- Only unmute the auditioned track and its ancestors; don't change others.
  local cur = target
  while cur do
    if reaper.GetMediaTrackInfo_Value(cur, "B_MUTE") ~= 0 then
      reaper.SetMediaTrackInfo_Value(cur, "B_MUTE", 0)
    end
    cur = reaper.GetParentTrack(cur)
  end

  local sip = true
  if reaper.SNM_GetIntConfigVar then
    local v = reaper.SNM_GetIntConfigVar("soloip", 1)
    if type(v) == "number" then sip = (v & 1) ~= 0 end
  end
  reaper.SetMediaTrackInfo_Value(target, "I_SOLO", sip and 2 or 1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()

  -- Play from the position below the mouse without permanently moving cursor.
  if (prev_playstate & 1) ~= 0 and (prev_playstate & 2) == 0 then
    reaper.SetEditCurPos2(PROJ, mouse_pos, false, true)
  else
    if (prev_playstate & 2) ~= 0 then reaper.OnStopButtonEx(PROJ) end
    reaper.SetEditCurPos2(PROJ, mouse_pos, false, false)
    reaper.OnPlayButtonEx(PROJ)
  end
end

local ok, reason = xpcall(begin, debug.traceback)
if not ok then
  cleanup()
  msg("试听启动失败：\n" .. tostring(reason))
  return
end

local function loop()
  local good, end_now = pcall(function()
    local elapsed = reaper.time_precise() - started_at
    if reaper.EnumProjects(-1) ~= PROJ then return true end
    if elapsed > MAX_HOLD then return true end
    -- GetUp detects an actual key release even if GetState has stale data.
    if w_released() then return true end
    if elapsed >= FIRST_CHECK_GRACE and not w_down() then return true end
    if elapsed >= FIRST_CHECK_GRACE and (reaper.GetPlayStateEx(PROJ) & 1) == 0 then
      return true -- User manually stopped playback.
    end
    return false
  end)
  if not good or end_now then cleanup(); return end
  reaper.defer(loop)
end

reaper.defer(loop)
