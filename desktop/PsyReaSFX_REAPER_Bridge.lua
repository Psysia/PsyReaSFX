-- @description PsyReaSFX Desktop - REAPER Bridge
-- @author Psysia
-- @version 0.7.23-a8
-- @about
--   Keep this ReaScript running to receive optional insert/spot requests from
--   PsyReaSFX Desktop. It only reads requests from the current user's
--   LocalAppData/PsyReaSFX/bridge directory.

local section_id, command_id = select(3, reaper.get_action_context())
local local_appdata = os.getenv("LOCALAPPDATA") or reaper.GetResourcePath()
local sep = package.config:sub(1, 1)
local root = local_appdata .. sep .. "PsyReaSFX" .. sep .. "bridge"
local requests = root .. sep .. "requests"
local responses = root .. sep .. "responses"
local heartbeat = root .. sep .. "heartbeat.tsv"
local last_heartbeat = 0

reaper.RecursiveCreateDirectory(requests, 0)
reaper.RecursiveCreateDirectory(responses, 0)

local function decode(value)
  value = (value or ""):gsub("+", " ")
  return (value:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end

local function encode(value)
  return tostring(value or ""):gsub("([^%w%-_%.~])", function(char)
    return string.format("%%%02X", string.byte(char))
  end)
end

local function read_values(path)
  local file = io.open(path, "rb")
  if not file then return nil end
  local values = {}
  for line in file:lines() do
    local key, value = line:match("^([^=]+)=(.*)$")
    if key then values[key] = decode(value) end
  end
  file:close()
  return values
end

local function write_values(path, values)
  local temp = path .. ".tmp"
  local file = io.open(temp, "wb")
  if not file then return false end
  local order = { "id", "success", "message", "action", "asset", "inserted", "project_path", "project_name", "track_name", "track_index", "position", "created_utc" }
  for _, key in ipairs(order) do
    file:write(key, "=", encode(values[key] or ""), "\n")
  end
  file:close()
  os.remove(path)
  return os.rename(temp, path) ~= nil
end

local function basename(path)
  return (path or ""):match("([^/\\]+)$") or "Untitled"
end

local function get_project_info()
  local _, path = reaper.EnumProjects(-1, "")
  return path or "", path and path ~= "" and basename(path):gsub("%.rpp$", "") or "Untitled"
end

local function capture_selected_tracks()
  local selected = {}
  for index = 0, reaper.CountSelectedTracks(0) - 1 do selected[#selected + 1] = reaper.GetSelectedTrack(0, index) end
  return selected
end

local function restore_selected_tracks(selected)
  reaper.Main_OnCommand(40297, 0) -- Track: Unselect all tracks
  for _, track in ipairs(selected) do
    if reaper.ValidatePtr2(0, track, "MediaTrack*") then reaper.SetTrackSelected(track, true) end
  end
end

local function select_only(track)
  reaper.Main_OnCommand(40297, 0)
  reaper.SetTrackSelected(track, true)
end

local function target_track()
  return reaper.GetSelectedTrack(0, 0) or reaper.GetLastTouchedTrack()
end

local function process_request(values)
  local action = values.action or ""
  local asset = values.asset or ""
  local media = values.media or ""
  local response = {
    id = values.id or "", success = "0", message = "Unknown bridge action", action = action,
    asset = asset, inserted = media, track_index = "-1", position = "0", created_utc = tostring(os.time())
  }
  response.project_path, response.project_name = get_project_info()

  if action == "ping" then
    response.success = "1"
    response.message = "PsyReaSFX REAPER Bridge is online"
    return response
  end
  if media == "" or not reaper.file_exists(media) then
    response.message = "Media file does not exist"
    return response
  end

  local track = target_track()
  if action == "insert_new_track" then
    local index = reaper.CountTracks(0)
    reaper.InsertTrackAtIndex(index, true)
    track = reaper.GetTrack(0, index)
  elseif not track then
    response.message = "Select or touch a target track in REAPER first"
    return response
  end

  local selected_tracks = capture_selected_tracks()
  local cursor = reaper.GetCursorPosition()
  reaper.Undo_BeginBlock2(0)
  reaper.PreventUIRefresh(1)
  select_only(track)
  local before = reaper.CountMediaItems(0)
  local mode = action == "insert_bwf" and 4 or 0
  local ok, result = pcall(reaper.InsertMedia, media, mode)
  local after = reaper.CountMediaItems(0)
  reaper.PreventUIRefresh(-1)

  if action ~= "insert_new_track" then restore_selected_tracks(selected_tracks) end
  if action == "insert_bwf" then reaper.SetEditCurPos(cursor, false, false) end
  reaper.UpdateArrange()
  reaper.Undo_EndBlock2(0, "PsyReaSFX: " .. (values.display or basename(media)), -1)

  if not ok or after <= before then
    response.message = ok and "REAPER did not create a media item" or tostring(result)
    return response
  end

  local _, track_name = reaper.GetTrackName(track)
  local inserted_item = reaper.GetSelectedMediaItem(0, 0) or reaper.GetMediaItem(0, after - 1)
  response.success = "1"
  response.message = "Inserted into REAPER"
  response.track_name = track_name or ""
  response.track_index = tostring(math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") or 0))
  response.position = tostring(inserted_item and reaper.GetMediaItemInfo_Value(inserted_item, "D_POSITION") or cursor)
  return response
end

local function write_heartbeat(now)
  local file = io.open(heartbeat, "wb")
  if file then
    file:write("online=1\nupdated_utc=", tostring(os.time()), "\nversion=0.7.23-a8\n")
    file:close()
  end
  last_heartbeat = now
end

local function poll_requests()
  local index = 0
  while true do
    local name = reaper.EnumerateFiles(requests, index)
    if not name then break end
    index = index + 1
    if name:match("%.request$") then
      local path = requests .. sep .. name
      local values = read_values(path)
      if values and values.id and values.id ~= "" then
        local ok, response = xpcall(function() return process_request(values) end, debug.traceback)
        if not ok then
          response = { id = values.id, success = "0", message = tostring(response), action = values.action or "", asset = values.asset or "", inserted = values.media or "", created_utc = tostring(os.time()) }
        end
        write_values(responses .. sep .. values.id .. ".response", response)
      end
      os.remove(path)
    end
  end
end

local function loop()
  local now = reaper.time_precise()
  if now - last_heartbeat >= 1 then write_heartbeat(now) end
  poll_requests()
  reaper.defer(loop)
end

local function shutdown()
  os.remove(heartbeat)
  if section_id and command_id and command_id > 0 then
    reaper.SetToggleCommandState(section_id, command_id, 0)
    reaper.RefreshToolbar2(section_id, command_id)
  end
end

if section_id and command_id and command_id > 0 then
  reaper.SetToggleCommandState(section_id, command_id, 1)
  reaper.RefreshToolbar2(section_id, command_id)
end
reaper.atexit(shutdown)
write_heartbeat(reaper.time_precise())
loop()
