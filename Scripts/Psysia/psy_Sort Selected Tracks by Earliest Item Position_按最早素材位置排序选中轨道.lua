-- @description Sort Tracks by Earliest Item Position / 按最早素材位置排序轨道
-- @version 1.2
-- @author Psysia
--
-- 使用方式：
-- 1. 选中两条或更多轨道：
--    按每条轨道上“所有素材”的最早位置排序。
--
-- 2. 没有选中轨道，但选中了多个素材：
--    自动识别素材所在轨道，
--    按每条轨道上“被选中素材”的最早位置排序。
--
-- 3. 如果时间位置完全相同：
--    保持轨道原本的上下相对顺序。


------------------------------------------------------------
-- 获取轨道上所有素材中最早的位置
------------------------------------------------------------

local function get_earliest_item_pos_on_track(track)

    local num_items = reaper.CountTrackMediaItems(track)

    if num_items == 0 then
        return math.huge
    end

    local min_pos = math.huge

    for i = 0, num_items - 1 do

        local item = reaper.GetTrackMediaItem(track, i)

        local pos =
            reaper.GetMediaItemInfo_Value(
                item,
                "D_POSITION"
            )

        if pos < min_pos then
            min_pos = pos
        end
    end

    return min_pos
end


------------------------------------------------------------
-- 保存当前轨道选择状态
------------------------------------------------------------

local function save_selected_tracks()

    local selected = {}

    local count =
        reaper.CountSelectedTracks(0)

    for i = 0, count - 1 do

        selected[#selected + 1] =
            reaper.GetSelectedTrack(0, i)
    end

    return selected
end


------------------------------------------------------------
-- 清除全部轨道选择
------------------------------------------------------------

local function clear_track_selection()

    local track_count =
        reaper.CountTracks(0)

    for i = 0, track_count - 1 do

        local track =
            reaper.GetTrack(0, i)

        reaper.SetTrackSelected(
            track,
            false
        )
    end
end


------------------------------------------------------------
-- 恢复轨道选择状态
------------------------------------------------------------

local function restore_track_selection(selected_tracks)

    clear_track_selection()

    for _, track in ipairs(selected_tracks) do

        -- 确认轨道仍然存在
        if reaper.ValidatePtr(track, "MediaTrack*") then

            reaper.SetTrackSelected(
                track,
                true
            )
        end
    end
end


------------------------------------------------------------
-- 主程序
------------------------------------------------------------

local function main()

    --------------------------------------------------------
    -- 保存原本轨道选择
    --------------------------------------------------------

    local original_selected_tracks =
        save_selected_tracks()


    --------------------------------------------------------
    -- 模式判断
    --------------------------------------------------------

    local num_sel_tracks =
        reaper.CountSelectedTracks(0)

    local num_sel_items =
        reaper.CountSelectedMediaItems(0)


    local tracks_data = {}

    local min_track_idx =
        math.huge


    --------------------------------------------------------
    -- 模式 A：
    -- 已经选中轨道
    --------------------------------------------------------

    if num_sel_tracks >= 2 then

        for i = 0, num_sel_tracks - 1 do

            local track =
                reaper.GetSelectedTrack(0, i)

            local track_idx =
                math.floor(
                    reaper.GetMediaTrackInfo_Value(
                        track,
                        "IP_TRACKNUMBER"
                    ) - 1
                )

            local earliest_pos =
                get_earliest_item_pos_on_track(
                    track
                )

            if track_idx < min_track_idx then
                min_track_idx = track_idx
            end

            tracks_data[#tracks_data + 1] = {

                track = track,

                pos = earliest_pos,

                orig_idx = track_idx
            }
        end


    --------------------------------------------------------
    -- 模式 B：
    -- 没选轨道，但选中了素材
    --------------------------------------------------------

    elseif num_sel_tracks == 0
       and num_sel_items > 0 then


        ----------------------------------------------------
        -- 用 track 指针作为 key，
        -- 防止同一轨道被重复加入
        ----------------------------------------------------

        local track_map = {}


        for i = 0, num_sel_items - 1 do

            local item =
                reaper.GetSelectedMediaItem(
                    0,
                    i
                )

            local track =
                reaper.GetMediaItemTrack(
                    item
                )

            local pos =
                reaper.GetMediaItemInfo_Value(
                    item,
                    "D_POSITION"
                )


            ------------------------------------------------
            -- 第一次遇到这条轨道
            ------------------------------------------------

            if not track_map[track] then

                local track_idx =
                    math.floor(
                        reaper.GetMediaTrackInfo_Value(
                            track,
                            "IP_TRACKNUMBER"
                        ) - 1
                    )

                local data = {

                    track = track,

                    pos = pos,

                    orig_idx = track_idx
                }

                track_map[track] =
                    data

                tracks_data[#tracks_data + 1] =
                    data


                if track_idx < min_track_idx then
                    min_track_idx = track_idx
                end


            ------------------------------------------------
            -- 同一轨道还有其他选中素材
            -- 只保留最早位置
            ------------------------------------------------

            else

                local data =
                    track_map[track]

                if pos < data.pos then
                    data.pos = pos
                end
            end
        end


        ----------------------------------------------------
        -- 如果所有选中素材都在同一条轨道
        ----------------------------------------------------

        if #tracks_data < 2 then
            return
        end


    --------------------------------------------------------
    -- 其他情况
    --------------------------------------------------------

    else

        return
    end


    --------------------------------------------------------
    -- 时间升序排序
    --------------------------------------------------------

    table.sort(
        tracks_data,

        function(a, b)

            ------------------------------------------------
            -- 时间一样：
            -- 保持原始上下顺序
            ------------------------------------------------

            if a.pos == b.pos then
                return a.orig_idx < b.orig_idx
            end

            return a.pos < b.pos
        end
    )


    --------------------------------------------------------
    -- 开始移动轨道
    --------------------------------------------------------

    reaper.Undo_BeginBlock()

    reaper.PreventUIRefresh(1)


    local insert_idx =
        min_track_idx


    for _, data in ipairs(tracks_data) do

        ----------------------------------------------------
        -- 一次只移动一根轨道
        ----------------------------------------------------

        reaper.SetOnlyTrackSelected(
            data.track
        )


        reaper.ReorderSelectedTracks(
            insert_idx,
            0
        )


        insert_idx =
            insert_idx + 1
    end


    --------------------------------------------------------
    -- 恢复执行脚本前的轨道选择
    --------------------------------------------------------

    restore_track_selection(
        original_selected_tracks
    )


    --------------------------------------------------------
    -- 刷新
    --------------------------------------------------------

    reaper.PreventUIRefresh(-1)

    reaper.TrackList_AdjustWindows(
        false
    )

    reaper.UpdateArrange()


    reaper.Undo_EndBlock(
        "Sort tracks by earliest item position",
        -1
    )
end


main()