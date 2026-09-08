-- @description Reverse Selected Items in Place / 原位反转选中素材
-- @author Psysia
-- @version 1.0

function Main()
    -- 获取当前选中的素材数量
    local count = reaper.CountSelectedMediaItems(0)
    
    -- 如果没有选中任何素材，则不执行任何操作
    if count == 0 then return end

    -- 停止 UI 刷新，防止闪烁，加快执行速度
    reaper.PreventUIRefresh(1)
    
    -- 开始记录撤销历史（这样你按 Ctrl+Z 可以一步撤销）
    reaper.Undo_BeginBlock()

    -- 执行动作：Item: Reverse items to new take (生成反转的新Take)
    -- Command ID: 41051
    reaper.Main_OnCommand(41051, 0)

    -- 执行动作：Take: Crop to active take (裁剪并保留当前激活的反转Take，删除原Take)
    -- Command ID: 40131
    reaper.Main_OnCommand(40131, 0)

    -- 结束记录撤销历史
    reaper.Undo_EndBlock("一键原位反转音频", -1)
    
    -- 恢复 UI 刷新
    reaper.PreventUIRefresh(-1)
    
    -- 更新排列视图
    reaper.UpdateArrange()
end

-- 运行主函数
Main()
