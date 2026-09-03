-- @description Create Folder from Selected Tracks with Pro-L 2 / 从选中轨道创建文件夹并挂载 Pro-L 2
-- @version 1.0
-- @author Psysia

-- 在这里填入你特效浏览器里 Pro-L 2 的确切名称
-- 比如 "Pro-L 2", "VST3: Pro-L 2 (FabFilter)" 等
local fx_name = "Pro-L 2" 

function main()
    -- 获取当前选中的轨道数量
    local sel_count = reaper.CountSelectedTracks(0)
    
    if sel_count == 0 then
        -- 如果没选中任何轨道，直接退出
        return 
    end

    reaper.Undo_BeginBlock()

    -- 1. 找到选中的第一个轨道和它的索引位置
    local first_track = reaper.GetSelectedTrack(0, 0)
    local first_idx = reaper.GetMediaTrackInfo_Value(first_track, "IP_TRACKNUMBER") - 1

    -- 2. 在第一个轨道上方插入一个新轨道（作为父轨道）
    reaper.InsertTrackAtIndex(first_idx, true)
    local parent_track = reaper.GetTrack(0, first_idx)

    -- 3. 将新轨道设置为文件夹的开头 (Folder Depth = 1)
    reaper.SetMediaTrackInfo_Value(parent_track, "I_FOLDERDEPTH", 1)

    -- 4. 找到刚才选中的最后一个轨道，将其设置为文件夹的结尾
    -- 因为在上方插入了一个新轨道，所以最后一个选中轨道的索引变成了 first_idx + sel_count
    local last_track = reaper.GetTrack(0, first_idx + sel_count)
    local current_depth = reaper.GetMediaTrackInfo_Value(last_track, "I_FOLDERDEPTH")
    reaper.SetMediaTrackInfo_Value(last_track, "I_FOLDERDEPTH", current_depth - 1)

    -- 5. 给新轨道命名（可以自己修改 "Folder Bus" 这个名字）
    reaper.GetSetMediaTrackInfo_String(parent_track, "P_NAME", "Folder Bus", true)

    -- 6. 在父轨道上挂载指定的 VST 插件
    -- 最后的参数 -1 表示插入到效果链的末尾（因为是新轨道所以也就是第一个）
    reaper.TrackFX_AddByName(parent_track, fx_name, false, -1)

    -- 7. 选中新建的父轨道，方便后续操作
    reaper.SetOnlyTrackSelected(parent_track)

    reaper.Undo_EndBlock("Create Folder and Add Pro-L 2", -1)
end

-- 冻结界面刷新，防止执行过程中屏幕闪烁
reaper.PreventUIRefresh(1)
main()
reaper.TrackList_AdjustWindows(false)
reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)
