-- @description Sort Selected Tracks by Earliest Item Position / 按最早素材位置排序选中轨道
-- @version 1.0
-- @author Psysia

function get_earliest_item_pos(track)
    local num_items = reaper.CountTrackMediaItems(track)
    -- 如果轨道上没有内容，给一个极大的值，让它排到最后面
    if num_items == 0 then return math.huge end 
    
    local min_pos = math.huge
    for i = 0, num_items - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        if pos < min_pos then min_pos = pos end
    end
    return min_pos
end

function main()
    local num_sel_tracks = reaper.CountSelectedTracks(0)
    if num_sel_tracks < 2 then return end -- 选中不到两根轨道就不执行

    local tracks_data = {}
    local min_track_idx = math.huge

    -- 1. 收集选中轨道的数据
    for i = 0, num_sel_tracks - 1 do
        local track = reaper.GetSelectedTrack(0, i)
        -- 获取轨道当前的实际序号 (0-based)
        local track_idx = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1 
        if track_idx < min_track_idx then min_track_idx = track_idx end

        local earliest_pos = get_earliest_item_pos(track)
        table.insert(tracks_data, {
            track = track,
            pos = earliest_pos,
            orig_idx = track_idx
        })
    end

    -- 2. 根据最早的 Item 时间进行升序排序
    table.sort(tracks_data, function(a, b)
        if a.pos == b.pos then
            -- 如果时间完全一样，保留原本的上下相对顺序
            return a.orig_idx < b.orig_idx
        end
        return a.pos < b.pos
    end)

    -- 3. 开始移动轨道
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    local insert_idx = min_track_idx
    for i, data in ipairs(tracks_data) do
        -- 每次只选中一根轨道进行移动
        reaper.SetOnlyTrackSelected(data.track)
        reaper.ReorderSelectedTracks(insert_idx, 0)
        insert_idx = insert_idx + 1
    end

    -- 4. 恢复所有原本轨道的选中状态
    for i, data in ipairs(tracks_data) do
        reaper.SetTrackSelected(data.track, true)
    end

    reaper.PreventUIRefresh(-1)
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Sort selected tracks by earliest item", -1)
end

main()
