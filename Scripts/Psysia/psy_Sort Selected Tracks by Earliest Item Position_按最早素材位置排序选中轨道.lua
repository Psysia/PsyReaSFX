-- @description Sort Tracks by Earliest Item Position / 按最早素材位置排序轨道
-- @version 1.3
-- @author Psysia
-- @changelog
--   + Selected media items now take priority over selected tracks.
--   + Sort source tracks by the earliest selected item on each track.
--   + Preserve non-contiguous destination slots and folder endings.
--   + Restore original track selection and UI state after errors.

local PROJECT = 0

local function valid_track(track)
    return track ~= nil and reaper.ValidatePtr2(PROJECT, track, "MediaTrack*")
end

local function track_number(track)
    return math.floor(
        reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") + 0.5
    )
end

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

local function save_selected_tracks()
    local tracks = {}
    local count = reaper.CountSelectedTracks(PROJECT)

    for i = 0, count - 1 do
        local track = reaper.GetSelectedTrack(PROJECT, i)
        if valid_track(track) then
            tracks[#tracks + 1] = track
        end
    end

    return tracks
end

local function restore_track_selection(tracks)
    reaper.Main_OnCommand(40297, 0) -- Track: Unselect all tracks

    for _, track in ipairs(tracks) do
        if valid_track(track) then
            reaper.SetTrackSelected(track, true)
        end
    end
end

local function build_destination_indices(entries)
    local indices = {}

    for _, entry in ipairs(entries) do
        indices[#indices + 1] = entry.original_order
    end

    table.sort(indices)
    return indices
end

local function collect_from_selected_items()
    local item_count = reaper.CountSelectedMediaItems(PROJECT)
    if item_count == 0 then
        return nil
    end

    local by_track = {}
    local entries = {}

    for i = 0, item_count - 1 do
        local item = reaper.GetSelectedMediaItem(PROJECT, i)
        local track = item and reaper.GetMediaItem_Track(item) or nil

        if valid_track(track) then
            local position = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local entry = by_track[track]

            if not entry then
                entry = {
                    track = track,
                    position = position,
                    original_order = track_number(track),
                }
                by_track[track] = entry
                entries[#entries + 1] = entry
            elseif position < entry.position then
                entry.position = position
            end
        end
    end

    return entries
end

local function collect_from_selected_tracks()
    local selected_count = reaper.CountSelectedTracks(PROJECT)
    local entries = {}

    for i = 0, selected_count - 1 do
        local track = reaper.GetSelectedTrack(PROJECT, i)

        if valid_track(track) then
            entries[#entries + 1] = {
                track = track,
                position = earliest_item_position(track),
                original_order = track_number(track),
            }
        end
    end

    return entries
end

local function sort_entries(entries)
    table.sort(entries, function(a, b)
        if a.position == b.position then
            return a.original_order < b.original_order
        end
        return a.position < b.position
    end)
end

local function main()
    local original_track_selection = save_selected_tracks()

    -- Selected media items always take priority. This avoids REAPER's incidental
    -- track-selection state changing which mode the script uses.
    local entries = collect_from_selected_items()
    local item_mode = entries ~= nil

    if not item_mode then
        entries = collect_from_selected_tracks()
    end

    if #entries < 2 then
        reaper.ShowMessageBox(
            item_mode
                and "Select media items on at least two tracks.\n\n请至少选择两个不同轨道上的素材。"
                or "Select at least two tracks.\n\n请至少选择两条轨道。",
            "Sort Tracks / 排序轨道",
            0
        )
        return
    end

    local destination_indices = build_destination_indices(entries)
    sort_entries(entries)

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    local ok, err = xpcall(function()
        for i, entry in ipairs(entries) do
            if not valid_track(entry.track) then
                error("Track pointer became invalid before move " .. i)
            end

            reaper.SetOnlyTrackSelected(entry.track)

            -- Keep the v1.1 move behavior: preserve original non-contiguous
            -- destination slots and preserve folder endings.
            if not reaper.ReorderSelectedTracks(destination_indices[i], 2) then
                error("REAPER rejected track move " .. i)
            end
        end
    end, debug.traceback)

    restore_track_selection(original_track_selection)
    reaper.PreventUIRefresh(-1)
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()

    if ok then
        reaper.Undo_EndBlock(
            item_mode
                and "Sort tracks by selected item positions / 按选中素材位置排序轨道"
                or "Sort selected tracks by earliest item position / 按最早素材位置排序选中轨道",
            -1
        )
    else
        reaper.Undo_EndBlock(
            "Sort tracks failed / 排序轨道失败",
            -1
        )

        reaper.ShowMessageBox(
            "Unable to reorder tracks.\n\n无法重新排列轨道。\n\n" .. tostring(err),
            "Sort Tracks / 排序轨道",
            0
        )
    end
end

main()
