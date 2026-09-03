-- @description Sort Selected Tracks by Earliest Item Position / 按最早素材位置排序选中轨道
-- @version 1.1
-- @author Psysia
-- @changelog
--   + Preserve the original slots of non-contiguous selected tracks.
--   + Preserve folder endings while reordering tracks.
--   + Restore selection and UI refresh state after an error.

local function earliest_item_position(track)
    local item_count = reaper.CountTrackMediaItems(track)
    if item_count == 0 then
        return math.huge
    end

    local earliest = math.huge
    for i = 0, item_count - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        if position < earliest then
            earliest = position
        end
    end
    return earliest
end

local function restore_track_selection(tracks)
    reaper.Main_OnCommand(40297, 0) -- Track: Unselect all tracks
    for _, track in ipairs(tracks) do
        if reaper.ValidatePtr2(0, track, "MediaTrack*") then
            reaper.SetTrackSelected(track, true)
        end
    end
end

local function main()
    local selected_count = reaper.CountSelectedTracks(0)
    if selected_count < 2 then
        reaper.ShowMessageBox(
            "Select at least two tracks.\n\n请至少选择两条轨道。",
            "Sort Selected Tracks / 排序选中轨道",
            0
        )
        return
    end

    local original_selection = {}
    local sorted_tracks = {}
    local destination_indices = {}

    for i = 0, selected_count - 1 do
        local track = reaper.GetSelectedTrack(0, i)
        local track_number = math.floor(
            reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") + 0.5
        )

        original_selection[#original_selection + 1] = track
        destination_indices[#destination_indices + 1] = track_number
        sorted_tracks[#sorted_tracks + 1] = {
            track = track,
            position = earliest_item_position(track),
            original_order = i,
        }
    end

    table.sort(sorted_tracks, function(a, b)
        if a.position == b.position then
            return a.original_order < b.original_order
        end
        return a.position < b.position
    end)

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    local ok, err = xpcall(function()
        for i, entry in ipairs(sorted_tracks) do
            reaper.SetOnlyTrackSelected(entry.track)
            if not reaper.ReorderSelectedTracks(destination_indices[i], 2) then
                error("REAPER rejected track move " .. i)
            end
        end
    end, debug.traceback)

    restore_track_selection(original_selection)
    reaper.PreventUIRefresh(-1)
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()

    if ok then
        reaper.Undo_EndBlock(
            "Sort selected tracks by earliest item position / 按最早素材位置排序选中轨道",
            -1
        )
    else
        reaper.Undo_EndBlock(
            "Sort selected tracks failed / 排序选中轨道失败",
            -1
        )
        reaper.ShowMessageBox(
            "Unable to reorder the selected tracks.\n\n无法重新排列选中的轨道。\n\n" .. tostring(err),
            "Sort Selected Tracks / 排序选中轨道",
            0
        )
    end
end

main()
