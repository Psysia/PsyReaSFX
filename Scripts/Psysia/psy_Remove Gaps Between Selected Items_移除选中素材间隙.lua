-- @description Remove Gaps Between Selected Items / 移除选中素材间隙
-- @version 1.0
-- @author Psysia

reaper.Undo_BeginBlock()

local count = reaper.CountSelectedMediaItems(0)
if count > 1 then
    for i = 1, count - 1 do
        local prev_item = reaper.GetSelectedMediaItem(0, i - 1)
        local curr_item = reaper.GetSelectedMediaItem(0, i)
        
        -- 获取前一个素材的位置和长度
        local prev_pos = reaper.GetMediaItemInfo_Value(prev_item, "D_POSITION")
        local prev_len = reaper.GetMediaItemInfo_Value(prev_item, "D_LENGTH")
        
        -- 将当前素材移动到前一个素材的末尾
        reaper.SetMediaItemInfo_Value(curr_item, "D_POSITION", prev_pos + prev_len)
    end
end

reaper.UpdateArrange()
reaper.Undo_EndBlock("Remove gaps between selected items", -1)
