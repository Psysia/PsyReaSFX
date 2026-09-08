-- @description Split Selected Items to New Tracks / 拆分选中素材到新轨道
-- @version 1.0
-- @author Psysia

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()

-- 获取当前选中的对象数量
local num_sel_items = reaper.CountSelectedMediaItems(0)

if num_sel_items > 0 then
    -- 1. 将选中的 items 存入数组，避免后续轨道或对象移动操作导致 API 内部索引错乱
    local items = {}
    for i = 0, num_sel_items - 1 do
        items[i+1] = reaper.GetSelectedMediaItem(0, i)
    end
    
    -- 2. 倒序遍历处理
    -- 必须倒序，这样可以保证新生成的轨道在视觉上下拉时，与时间线从左到右的顺序完美对应
    for i = #items, 1, -1 do
        local item = items[i]
        local src_track = reaper.GetMediaItem_Track(item)
        
        -- 获取当前源轨道的全局编号（1-based）
        local track_idx = reaper.GetMediaTrackInfo_Value(src_track, "IP_TRACKNUMBER")
        
        -- 在当前源轨道正下方插入新轨道（InsertTrackAtIndex 的索引是 0-based，传入 track_idx 刚好是下方）
        reaper.InsertTrackAtIndex(track_idx, true)
        local new_track = reaper.GetTrack(0, track_idx)
        
        -- 将对象移动到新轨道（此 API 会自动保持原本的时间戳位置）
        reaper.MoveMediaItemToTrack(item, new_track)
        
        -- （功能增强）获取音频的 Take 名称，并将其自动赋值给新轨道
        local take = reaper.GetActiveTake(item)
        if take then
            local retval, take_name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            if retval then
                reaper.GetSetMediaTrackInfo_String(new_track, "P_NAME", take_name, true)
            end
        end
    end
end

reaper.Undo_EndBlock("Explode selected items to new tracks (keep positions)", -1)
reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)
