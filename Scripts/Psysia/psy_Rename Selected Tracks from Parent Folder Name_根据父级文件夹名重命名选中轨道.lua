-- @description Rename Selected Tracks from Parent Folder Name / 根据父级文件夹名重命名选中轨道
-- @version 1.0
-- @author Psysia
-- @changelog
--   + Rename selected tracks from their immediate parent folder name.
--   + Number selected sibling tracks from top to bottom as _01, _02, _03...
--   + Handle multiple parent folders independently.
--   + Support nested folder structures by always using the nearest parent.

local PROJECT = 0

local function valid_track(track)
    return track ~= nil
        and reaper.ValidatePtr2(
            PROJECT,
            track,
            "MediaTrack*"
        )
end

local function track_index(track)
    return math.floor(
        reaper.GetMediaTrackInfo_Value(
            track,
            "IP_TRACKNUMBER"
        ) + 0.5
    )
end

local function get_track_name(track)
    local _, name =
        reaper.GetSetMediaTrackInfo_String(
            track,
            "P_NAME",
            "",
            false
        )

    return name or ""
end

local function set_track_name(track, name)
    reaper.GetSetMediaTrackInfo_String(
        track,
        "P_NAME",
        name,
        true
    )
end

local function main()
    local selected_count =
        reaper.CountSelectedTracks(PROJECT)

    if selected_count == 0 then
        return
    end

    local selected = {}

    for i = 0, selected_count - 1 do
        local track =
            reaper.GetSelectedTrack(
                PROJECT,
                i
            )

        if valid_track(track) then
            selected[#selected + 1] = track
        end
    end

    table.sort(selected, function(a, b)
        return track_index(a)
            < track_index(b)
    end)

    local groups = {}
    local group_order = {}

    local skipped_no_parent = 0
    local skipped_empty_parent_name = 0

    for _, track in ipairs(selected) do
        local parent =
            reaper.GetParentTrack(track)

        if not valid_track(parent) then
            skipped_no_parent =
                skipped_no_parent + 1
        else
            local parent_name =
                get_track_name(parent)

            if parent_name == "" then
                skipped_empty_parent_name =
                    skipped_empty_parent_name + 1
            else
                if not groups[parent] then
                    groups[parent] = {
                        parent_name = parent_name,
                        tracks = {},
                    }

                    group_order[
                        #group_order + 1
                    ] = parent
                end

                local group =
                    groups[parent]

                group.tracks[
                    #group.tracks + 1
                ] = track
            end
        end
    end

    if #group_order == 0 then
        if skipped_no_parent > 0
        or skipped_empty_parent_name > 0 then
            reaper.ShowMessageBox(
                "No selected tracks could be renamed.\n\n"
                .. "没有可重命名的选中轨道。\n\n"
                .. "Tracks must have a named immediate parent folder.\n"
                .. "轨道必须拥有已命名的直接父级文件夹。",
                "Rename Tracks / 重命名轨道",
                0
            )
        end

        return
    end

    reaper.Undo_BeginBlock2(PROJECT)
    reaper.PreventUIRefresh(1)

    local renamed_count = 0

    local ok, err = xpcall(function()
        for _, parent in ipairs(group_order) do
            local group = groups[parent]

            for i, track in ipairs(group.tracks) do
                if valid_track(track) then
                    local new_name =
                        group.parent_name
                        .. "_"
                        .. string.format(
                            "%02d",
                            i
                        )

                    set_track_name(
                        track,
                        new_name
                    )

                    renamed_count =
                        renamed_count + 1
                end
            end
        end
    end, debug.traceback)

    reaper.PreventUIRefresh(-1)
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()

    if ok then
        reaper.Undo_EndBlock2(
            PROJECT,
            "Rename selected tracks from parent folder name / 根据父级文件夹名重命名选中轨道",
            -1
        )
    else
        reaper.Undo_EndBlock2(
            PROJECT,
            "Rename selected tracks failed / 重命名选中轨道失败",
            -1
        )

        reaper.ShowMessageBox(
            "Unable to rename selected tracks.\n\n"
            .. "无法重命名选中轨道。\n\n"
            .. tostring(err),
            "Rename Tracks / 重命名轨道",
            0
        )

        return
    end

    if skipped_no_parent > 0
    or skipped_empty_parent_name > 0 then
        local message =
            "Renamed tracks: "
            .. renamed_count

        if skipped_no_parent > 0 then
            message =
                message
                .. "\nSkipped without parent folder: "
                .. skipped_no_parent
        end

        if skipped_empty_parent_name > 0 then
            message =
                message
                .. "\nSkipped because parent folder has no name: "
                .. skipped_empty_parent_name
        end

        message =
            message
            .. "\n\n已重命名轨道："
            .. renamed_count

        if skipped_no_parent > 0 then
            message =
                message
                .. "\n无父级文件夹而跳过："
                .. skipped_no_parent
        end

        if skipped_empty_parent_name > 0 then
            message =
                message
                .. "\n父级文件夹无名称而跳过："
                .. skipped_empty_parent_name
        end

        reaper.ShowMessageBox(
            message,
            "Rename Tracks / 重命名轨道",
            0
        )
    end
end

main()
