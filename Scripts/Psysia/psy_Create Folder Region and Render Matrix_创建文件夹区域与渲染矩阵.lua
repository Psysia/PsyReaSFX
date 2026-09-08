-- @description Create Folder Region and Render Matrix / 创建文件夹区域与渲染矩阵
-- @version 2.4
-- @author Psysia
--
-- v2.4 修复：
-- 单个源轨道如果位于文件夹内，使用“直接父文件夹”命名 Region，
-- 并把该父文件夹写入 Region Render Matrix。
--
-- 核心规则：
-- 1. 有已选媒体对象：区间取所有已选对象最左端 -> 最右端。
-- 2. 单个源轨道：
--    - 源轨道本身是文件夹轨道：使用它自己。
--    - 源轨道位于文件夹内：使用直接父文件夹。
--    - 没有父文件夹：使用源轨道自己。
-- 3. 多个源轨道：寻找最近公共父级（Lowest Common Ancestor）。
-- 4. 多个 Region 可以拥有完全相同的时间范围；
--    只有“范围相同 + Render Matrix 目标相同”才认为是同一逻辑 Region。
-- 5. 更新已有 Region 时刷新其 Render Matrix。
--
-- 不依赖 SWS / ReaPack。

local PROJECT = 0
local EPSILON = 0.000001

local CONFIG = {
  FORCE_LOWERCASE = true,
  REPLACE_SPACES_WITH_UNDERSCORES = true,
  SANITIZE_FOR_FILENAME = true,

  -- v2.4：单轨位于文件夹内时，使用直接父文件夹。
  SINGLE_TRACK_USE_PARENT_FOLDER = true,

  -- 同范围 + 同矩阵目标时更新原 Region。
  UPDATE_MATCHING_REGION = true,

  -- 更新已有 Region 时先清空旧 Render Matrix。
  REPLACE_EXISTING_MATRIX = true,

  -- 多轨没有共同父级时：
  -- true  = 组合源轨道名称并分别勾选源轨道；
  -- false = 停止。
  FALLBACK_TO_SOURCE_TRACKS = true,

  -- SetRegionRenderMatrix:
  -- 1 = 正常；2 = 强制单声道；4 = 强制双声道。
  MATRIX_FLAG = 1,

  SHOW_SUCCESS_MESSAGE = false,
}

local function msg(text, title)
  reaper.ShowMessageBox(
    tostring(text),
    title or "创建渲染区间",
    0
  )
end

local function trim(text)
  return (text or ""):match("^%s*(.-)%s*$")
end

local function valid_track(track)
  return track ~= nil
    and reaper.ValidatePtr2(PROJECT, track, "MediaTrack*")
end

local function track_number(track)
  if not valid_track(track) then
    return math.huge
  end

  return tonumber(
    reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
  ) or math.huge
end

local function sort_tracks(tracks)
  table.sort(
    tracks,
    function(a, b)
      return track_number(a) < track_number(b)
    end
  )
end

local function unique_tracks(tracks)
  local result = {}
  local seen = {}

  for _, track in ipairs(tracks or {}) do
    if valid_track(track) and not seen[track] then
      seen[track] = true
      result[#result + 1] = track
    end
  end

  sort_tracks(result)
  return result
end

local function is_folder_track(track)
  if not valid_track(track) then
    return false
  end

  local depth =
    tonumber(
      reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
    ) or 0

  -- 正数表示该轨道开启一个文件夹层级。
  return depth > 0
end

local function get_selected_items()
  local items = {}
  local count = reaper.CountMediaItems(PROJECT)

  for i = 0, count - 1 do
    local item = reaper.GetMediaItem(PROJECT, i)

    if item and reaper.IsMediaItemSelected(item) then
      items[#items + 1] = item
    end
  end

  return items
end

local function get_tracks_from_items(items)
  local tracks = {}

  for _, item in ipairs(items) do
    local track = reaper.GetMediaItem_Track(item)

    if valid_track(track) then
      tracks[#tracks + 1] = track
    end
  end

  return unique_tracks(tracks)
end

local function get_selected_tracks()
  local tracks = {}
  local count = reaper.CountSelectedTracks(PROJECT)

  for i = 0, count - 1 do
    local track = reaper.GetSelectedTrack(PROJECT, i)

    if valid_track(track) then
      tracks[#tracks + 1] = track
    end
  end

  return unique_tracks(tracks)
end

local function get_item_bounds(items)
  local start_pos = nil
  local end_pos = nil

  for _, item in ipairs(items) do
    local pos =
      reaper.GetMediaItemInfo_Value(item, "D_POSITION")

    local len =
      reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

    if type(pos) == "number"
      and type(len) == "number"
      and len > EPSILON then

      local item_end = pos + len

      start_pos =
        start_pos and math.min(start_pos, pos) or pos

      end_pos =
        end_pos and math.max(end_pos, item_end) or item_end
    end
  end

  if start_pos
    and end_pos
    and end_pos > start_pos + EPSILON then
    return start_pos, end_pos
  end

  return nil
end

local function resolve_sources_and_range()
  local items = get_selected_items()

  -- 已选 Item 始终优先。
  if #items > 0 then
    local tracks = get_tracks_from_items(items)
    local start_pos, end_pos = get_item_bounds(items)

    if #tracks == 0 then
      return nil, nil, nil, nil,
        "已选媒体对象没有可用的所属轨道。"
    end

    if not start_pos then
      return nil, nil, nil, nil,
        "无法从已选媒体对象取得有效长度。"
    end

    return tracks, items, start_pos, end_pos
  end

  -- 没有 Item 时使用选中轨道 + 时间选区。
  local tracks = get_selected_tracks()

  if #tracks == 0 then
    local last_touched = reaper.GetLastTouchedTrack()

    if valid_track(last_touched) then
      tracks = { last_touched }
    end
  end

  if #tracks == 0 then
    return nil, nil, nil, nil,
      "没有选中媒体对象或轨道。"
  end

  local start_pos, end_pos =
    reaper.GetSet_LoopTimeRange2(
      PROJECT,
      false,
      false,
      0,
      0,
      false
    )

  if type(start_pos) ~= "number"
    or type(end_pos) ~= "number"
    or end_pos <= start_pos + EPSILON then
    return nil, nil, nil, nil,
      "只选轨道时必须先建立有效的时间选区。"
  end

  return tracks, {}, start_pos, end_pos
end

local function get_track_name(track)
  local ok, name =
    reaper.GetSetMediaTrackInfo_String(
      track,
      "P_NAME",
      "",
      false
    )

  name = trim(ok and name or "")

  if name ~= "" then
    return name
  end

  local number = math.floor(track_number(track))

  if number == -1 then
    return "master"
  end

  return string.format(
    "track_%02d",
    math.max(number, 1)
  )
end

local RESERVED = {
  CON = true, PRN = true, AUX = true, NUL = true,
  COM1 = true, COM2 = true, COM3 = true,
  COM4 = true, COM5 = true, COM6 = true,
  COM7 = true, COM8 = true, COM9 = true,
  LPT1 = true, LPT2 = true, LPT3 = true,
  LPT4 = true, LPT5 = true, LPT6 = true,
  LPT7 = true, LPT8 = true, LPT9 = true,
}

local function normalize_name(name)
  name = trim(name)

  if CONFIG.SANITIZE_FOR_FILENAME then
    name = name:gsub("%c", "_")
    name = name:gsub('[<>:"/\\|%?%*]', "_")
  end

  if CONFIG.REPLACE_SPACES_WITH_UNDERSCORES then
    name = name:gsub("%s+", "_")
  else
    name = name:gsub("%s+", " ")
  end

  name = name:gsub("_+", "_")
  name = name:gsub("[%.%s]+$", "")
  name = name:gsub("^%s+", "")

  if CONFIG.FORCE_LOWERCASE then
    name = name:lower()
  end

  if name == "" then
    name = "unnamed_track"
  end

  local first = name:match("^([^%.]+)") or name

  if RESERVED[first:upper()] then
    name = "_" .. name
  end

  return name
end

local function ancestry_from_root(track)
  local reverse = {}
  local visited = {}
  local current = track

  while valid_track(current) do
    if visited[current] then
      return nil, "检测到异常的轨道父级循环。"
    end

    visited[current] = true
    reverse[#reverse + 1] = current

    if #reverse > 1024 then
      return nil, "文件夹层级超过安全限制。"
    end

    current = reaper.GetParentTrack(current)
  end

  local path = {}

  for i = #reverse, 1, -1 do
    path[#path + 1] = reverse[i]
  end

  return path
end

local function lowest_common_ancestor(tracks)
  if #tracks == 0 then
    return nil
  end

  local paths = {}

  for _, track in ipairs(tracks) do
    local path, err = ancestry_from_root(track)

    if not path then
      return nil, err
    end

    paths[#paths + 1] = path
  end

  local common = nil
  local depth = 1

  while true do
    local candidate = paths[1][depth]

    if not candidate then
      break
    end

    for i = 2, #paths do
      if paths[i][depth] ~= candidate then
        return common
      end
    end

    common = candidate
    depth = depth + 1
  end

  return common
end

local function combined_source_name(tracks)
  local names = {}

  for _, track in ipairs(tracks) do
    names[#names + 1] =
      normalize_name(get_track_name(track))
  end

  return table.concat(names, "__")
end

local function resolve_single_track_target(source_track)
  -- 如果 Item 本身就在一个“文件夹轨道”上，
  -- 不继续爬到更高父级，否则会误用祖父文件夹。
  if is_folder_track(source_track) then
    return source_track
  end

  if CONFIG.SINGLE_TRACK_USE_PARENT_FOLDER then
    local parent = reaper.GetParentTrack(source_track)

    if valid_track(parent) then
      -- v2.4 核心修复：
      -- 单轨只要属于某个文件夹，就使用它的直接父文件夹。
      return parent
    end
  end

  return source_track
end

local function resolve_name_and_matrix_tracks(source_tracks)
  if #source_tracks == 1 then
    local target =
      resolve_single_track_target(source_tracks[1])

    return
      normalize_name(get_track_name(target)),
      { target },
      target
  end

  local common, err =
    lowest_common_ancestor(source_tracks)

  if err then
    return nil, nil, nil, err
  end

  if valid_track(common) then
    return
      normalize_name(get_track_name(common)),
      { common },
      common
  end

  if not CONFIG.FALLBACK_TO_SOURCE_TRACKS then
    return nil, nil, nil,
      "所选轨道没有共同父文件夹。"
  end

  return
    combined_source_name(source_tracks),
    source_tracks,
    nil
end

local function enumerate_regions()
  local total =
    select(1, reaper.CountProjectMarkers(PROJECT))

  total = tonumber(total) or 0

  local regions = {}

  for i = 0, total - 1 do
    local retval,
      is_region,
      pos,
      region_end,
      name,
      id,
      color =
        reaper.EnumProjectMarkers3(PROJECT, i)

    if retval == 0 then
      break
    end

    if is_region then
      regions[#regions + 1] = {
        pos = pos,
        region_end = region_end,
        name = name or "",
        id = id,
        color = color or 0,
      }
    end
  end

  return regions
end

local function same_position(a, b)
  return math.abs(a - b) <= EPSILON
end

local function get_regions_at_range(
  regions,
  start_pos,
  end_pos
)
  local matches = {}

  for _, region in ipairs(regions) do
    if same_position(region.pos, start_pos)
      and same_position(region.region_end, end_pos) then
      matches[#matches + 1] = region
    end
  end

  return matches
end

local function get_region_matrix_tracks(region_id)
  if type(reaper.EnumRegionRenderMatrix) ~= "function" then
    return nil,
      "当前 REAPER 不支持读取 Region Render Matrix。"
  end

  local tracks = {}
  local index = 0

  while true do
    local track =
      reaper.EnumRegionRenderMatrix(
        PROJECT,
        region_id,
        index
      )

    if not track then
      break
    end

    if valid_track(track) then
      tracks[#tracks + 1] = track
    end

    index = index + 1

    if index > 16384 then
      return nil, "Region Render Matrix 条目数量异常。"
    end
  end

  return unique_tracks(tracks)
end

local function track_sets_equal(a, b)
  a = unique_tracks(a or {})
  b = unique_tracks(b or {})

  if #a ~= #b then
    return false
  end

  local set = {}

  for _, track in ipairs(a) do
    set[track] = true
  end

  for _, track in ipairs(b) do
    if not set[track] then
      return false
    end
  end

  return true
end

local function find_matching_region(
  regions,
  start_pos,
  end_pos,
  base_name,
  desired_matrix_tracks
)
  local same_range =
    get_regions_at_range(
      regions,
      start_pos,
      end_pos
    )

  if #same_range == 0 then
    return nil
  end

  local matrix_matches = {}
  local empty_matrix_name_matches = {}
  local plain_name_matches = {}

  local matrix_api_available =
    type(reaper.EnumRegionRenderMatrix) == "function"

  local base_key = trim(base_name):lower()

  for _, region in ipairs(same_range) do
    local region_name_key =
      trim(region.name):lower()

    if region_name_key == base_key then
      plain_name_matches[#plain_name_matches + 1] =
        region
    end

    if matrix_api_available then
      local existing_tracks, matrix_error =
        get_region_matrix_tracks(region.id)

      if not existing_tracks then
        return nil, matrix_error
      end

      if track_sets_equal(
        existing_tracks,
        desired_matrix_tracks
      ) then
        matrix_matches[#matrix_matches + 1] =
          region
      elseif #existing_tracks == 0
        and region_name_key == base_key then
        empty_matrix_name_matches[
          #empty_matrix_name_matches + 1
        ] = region
      end
    end
  end

  if #matrix_matches == 1 then
    return matrix_matches[1]
  end

  if #matrix_matches > 1 then
    local exact_name_matches = {}

    for _, region in ipairs(matrix_matches) do
      if trim(region.name):lower() == base_key then
        exact_name_matches[#exact_name_matches + 1] =
          region
      end
    end

    if #exact_name_matches == 1 then
      return exact_name_matches[1]
    end

    return nil,
      "同一范围内存在多个渲染矩阵目标完全相同的 Region，"
      .. "无法安全判断应更新哪一个。\n\n"
      .. "请先手动删除重复项。"
  end

  if matrix_api_available then
    if #empty_matrix_name_matches == 1 then
      return empty_matrix_name_matches[1]
    end

    if #empty_matrix_name_matches > 1 then
      return nil,
        "同一范围内存在多个同名且矩阵为空的 Region，"
        .. "无法安全判断应更新哪一个。"
    end

    -- 时间范围相同，但矩阵目标不同：
    -- 新建一个重叠 Region。
    return nil
  end

  if #plain_name_matches == 1 then
    return plain_name_matches[1]
  end

  if #plain_name_matches > 1 then
    return nil,
      "同一范围内存在多个同名 Region，"
      .. "当前 REAPER 又无法读取渲染矩阵。"
  end

  return nil
end

local function make_unique_name(
  regions,
  base_name,
  excluded_id
)
  local function exists(candidate)
    local key = candidate:lower()

    for _, region in ipairs(regions) do
      if region.id ~= excluded_id
        and trim(region.name):lower() == key then
        return true
      end
    end

    return false
  end

  if not exists(base_name) then
    return base_name
  end

  for i = 2, 9999 do
    local candidate =
      string.format("%s_%02d", base_name, i)

    if not exists(candidate) then
      return candidate
    end
  end

  return nil
end

local function verify_region(
  region_id,
  start_pos,
  end_pos
)
  local regions = enumerate_regions()

  for _, region in ipairs(regions) do
    if region.id == region_id
      and same_position(region.pos, start_pos)
      and same_position(region.region_end, end_pos) then
      return true
    end
  end

  return false
end

local function clear_matrix(region_id)
  if type(reaper.EnumRegionRenderMatrix) ~= "function" then
    return false,
      "当前 REAPER 不支持读取已有 Region Render Matrix。"
  end

  local tracks = {}
  local index = 0

  while true do
    local track =
      reaper.EnumRegionRenderMatrix(
        PROJECT,
        region_id,
        index
      )

    if not track then
      break
    end

    tracks[#tracks + 1] = track
    index = index + 1

    if index > 16384 then
      return false, "矩阵条目数量异常。"
    end
  end

  for _, track in ipairs(tracks) do
    if valid_track(track) then
      reaper.SetRegionRenderMatrix(
        PROJECT,
        region_id,
        track,
        -1
      )
    end
  end

  return true
end

local function write_matrix(region_id, tracks)
  if type(reaper.SetRegionRenderMatrix) ~= "function" then
    return false,
      "当前 REAPER 不支持 Region Render Matrix API。"
  end

  for _, track in ipairs(unique_tracks(tracks)) do
    reaper.SetRegionRenderMatrix(
      PROJECT,
      region_id,
      track,
      CONFIG.MATRIX_FLAG
    )
  end

  return true
end

local required = {
  "ValidatePtr2",
  "CountMediaItems",
  "GetMediaItem",
  "IsMediaItemSelected",
  "GetMediaItem_Track",
  "GetMediaItemInfo_Value",
  "CountSelectedTracks",
  "GetSelectedTrack",
  "GetLastTouchedTrack",
  "GetSet_LoopTimeRange2",
  "GetParentTrack",
  "GetSetMediaTrackInfo_String",
  "GetMediaTrackInfo_Value",
  "CountProjectMarkers",
  "EnumProjectMarkers3",
  "AddProjectMarker2",
  "SetProjectMarker3",
}

for _, api in ipairs(required) do
  if type(reaper[api]) ~= "function" then
    msg(
      "缺少 REAPER API：\n\n"
      .. api
      .. "\n\n请更新 REAPER。",
      "脚本无法运行"
    )
    return
  end
end

local source_tracks,
  selected_items,
  start_pos,
  end_pos,
  resolve_error =
    resolve_sources_and_range()

if not source_tracks then
  msg(resolve_error)
  return
end

local base_name,
  matrix_tracks,
  naming_track,
  naming_error =
    resolve_name_and_matrix_tracks(source_tracks)

if not base_name then
  msg(naming_error)
  return
end

local regions = enumerate_regions()

local existing_region, match_error =
  find_matching_region(
    regions,
    start_pos,
    end_pos,
    base_name,
    matrix_tracks
  )

if match_error then
  msg(match_error)
  return
end

if existing_region
  and not CONFIG.UPDATE_MATCHING_REGION then
  msg(
    "当前范围已经存在相同渲染目标的 Region。"
  )
  return
end

local final_name =
  make_unique_name(
    regions,
    base_name,
    existing_region and existing_region.id or nil
  )

if not final_name then
  msg("无法生成唯一 Region 名称。")
  return
end

reaper.Undo_BeginBlock2(PROJECT)
reaper.PreventUIRefresh(1)

local region_id = nil
local matrix_warning = nil

local ok, runtime_error =
  xpcall(
    function()
      if existing_region then
        local updated =
          reaper.SetProjectMarker3(
            PROJECT,
            existing_region.id,
            true,
            start_pos,
            end_pos,
            final_name,
            existing_region.color
          )

        if not updated then
          error("更新已有 Region 失败。")
        end

        region_id = existing_region.id
      else
        region_id =
          reaper.AddProjectMarker2(
            PROJECT,
            true,
            start_pos,
            end_pos,
            final_name,
            -1,
            0
          )

        if not region_id or region_id < 0 then
          error("REAPER 返回 Region 创建失败。")
        end
      end

      reaper.UpdateTimeline()
      reaper.UpdateArrange()

      if not verify_region(
        region_id,
        start_pos,
        end_pos
      ) then
        error(
          "REAPER 未能在预期范围内验证到新 Region。"
        )
      end

      if existing_region
        and CONFIG.REPLACE_EXISTING_MATRIX then

        local clear_ok, clear_error =
          clear_matrix(region_id)

        if not clear_ok then
          matrix_warning = clear_error
        end
      end

      local matrix_ok, matrix_error =
        write_matrix(region_id, matrix_tracks)

      if not matrix_ok then
        matrix_warning = matrix_error
      end

      -- 同步时间选区到 Region。
      reaper.GetSet_LoopTimeRange2(
        PROJECT,
        true,
        false,
        start_pos,
        end_pos,
        false
      )

      if type(reaper.MarkProjectDirty) == "function" then
        reaper.MarkProjectDirty(PROJECT)
      end
    end,
    debug.traceback
  )

reaper.PreventUIRefresh(-1)
reaper.UpdateTimeline()
reaper.UpdateArrange()

reaper.Undo_EndBlock2(
  PROJECT,
  existing_region
    and "更新父文件夹命名 Region 与渲染矩阵"
    or "创建父文件夹命名 Region 与渲染矩阵",
  -1
)

if not ok then
  msg(
    "脚本执行失败：\n\n"
    .. tostring(runtime_error)
    .. "\n\n若产生错误修改，可立即撤销。"
  )
  return
end

if matrix_warning then
  msg(
    "Region 已成功生成：\n"
    .. final_name
    .. "\n\n但渲染矩阵未完整更新：\n"
    .. matrix_warning,
    "Region 已生成"
  )
  return
end

if CONFIG.SHOW_SUCCESS_MESSAGE then
  msg(
    "Region 已生成：\n"
    .. final_name,
    "完成"
  )
end
