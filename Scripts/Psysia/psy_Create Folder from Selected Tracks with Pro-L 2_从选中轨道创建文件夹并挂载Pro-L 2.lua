-- @description Create Folder from Selected Tracks with Pro-L 2 / 从选中轨道创建文件夹并挂载 Pro-L 2
-- @version 1.1
-- @author Psysia
-- @changelog
--   + Wrap complete selected folder subtrees instead of relying on selected-track count.
--   + Support selecting multiple sibling folder parents and adding one new parent above them.
--   + Preserve existing nested folder structure and folder-closing depths.
--   + Reject non-contiguous or cross-parent selections instead of swallowing unrelated tracks.

local PROJECT = 0
local fx_name = "Pro-L 2"
local parent_name = "Folder Bus"

local function valid_track(track)
    return track ~= nil
        and reaper.ValidatePtr2(PROJECT, track, "MediaTrack*")
end

local function track_index(track)
    return math.floor(
        reaper.GetMediaTrackInfo_Value(
            track,
            "IP_TRACKNUMBER"
        ) + 0.5
    ) - 1
end

local function folder_depth_delta(track)
    return math.floor(
        reaper.GetMediaTrackInfo_Value(
            track,
            "I_FOLDERDEPTH"
        ) + 0.5
    )
end

local function has_selected_ancestor(track, selected_map)
    local parent = reaper.GetParentTrack(track)

    while parent do
        if selected_map[parent] then
            return true
        end
        parent = reaper.GetParentTrack(parent)
    end

    return false
end

local function subtree_end(track)
    local start_index = track_index(track)
    local opening_depth = folder_depth_delta(track)

    if opening_depth <= 0 then
        return start_index, track
    end

    local balance = opening_depth
    local track_count = reaper.CountTracks(PROJECT)

    for i = start_index + 1, track_count - 1 do
        local child = reaper.GetTrack(PROJECT, i)

        if not valid_track(child) then
            return nil, nil
        end

        balance = balance + folder_depth_delta(child)

        if balance <= 0 then
            return i, child
        end
    end

    return nil, nil
end

local function show_message(text)
    reaper.ShowMessageBox(
        text,
        "Create Folder Bus / 创建文件夹总线",
        0
    )
end

local function collect_selection()
    local selected_count =
        reaper.CountSelectedTracks(PROJECT)

    if selected_count == 0 then
        return nil
    end

    local selected = {}
    local selected_map = {}

    for i = 0, selected_count - 1 do
        local track =
            reaper.GetSelectedTrack(PROJECT, i)

        if valid_track(track) then
            selected[#selected + 1] = track
            selected_map[track] = true
        end
    end

    local roots = {}

    for _, track in ipairs(selected) do
        if not has_selected_ancestor(
            track,
            selected_map
        ) then
            roots[#roots + 1] = track
        end
    end

    table.sort(roots, function(a, b)
        return track_index(a) < track_index(b)
    end)

    return roots
end

local function validate_and_build_span(roots)
    if not roots or #roots == 0 then
        return nil
    end

    local common_parent =
        reaper.GetParentTrack(roots[1])

    for i = 2, #roots do
        if reaper.GetParentTrack(roots[i])
            ~= common_parent then

            show_message(
                "Selected tracks/folders must be siblings under the same parent.\n\n"
                .. "选中的轨道或文件夹必须位于同一个父级下。"
            )
            return nil
        end
    end

    local spans = {}

    for _, root in ipairs(roots) do
        local start_index = track_index(root)
        local end_index, end_track =
            subtree_end(root)

        if not end_index or not end_track then
            show_message(
                "Unable to resolve the complete folder subtree. "
                .. "Please check the REAPER folder structure.\n\n"
                .. "无法识别完整的文件夹子树，请检查 REAPER 文件夹层级。"
            )
            return nil
        end

        spans[#spans + 1] = {
            start_index = start_index,
            end_index = end_index,
            end_track = end_track,
        }
    end

    for i = 2, #spans do
        if spans[i].start_index
            ~= spans[i - 1].end_index + 1 then

            show_message(
                "Selection must form one continuous block. "
                .. "When selecting existing folders, selecting only their "
                .. "folder-parent tracks is enough.\n\n"
                .. "选中内容必须组成连续的一组。选择已有文件夹时，"
                .. "只需选中文件夹父轨，内部子轨会自动包含。"
            )
            return nil
        end
    end

    return {
        first_index = spans[1].start_index,
        last_track = spans[#spans].end_track,
    }
end

local function main()
    local roots = collect_selection()

    if not roots or #roots == 0 then
        return
    end

    local span =
        validate_and_build_span(roots)

    if not span then
        return
    end

    reaper.Undo_BeginBlock2(PROJECT)
    reaper.PreventUIRefresh(1)

    local fx_index = -1

    local ok, err = xpcall(function()
        reaper.InsertTrackAtIndex(
            span.first_index,
            true
        )

        local parent_track =
            reaper.GetTrack(
                PROJECT,
                span.first_index
            )

        if not valid_track(parent_track) then
            error("Unable to create parent track.")
        end

        reaper.SetMediaTrackInfo_Value(
            parent_track,
            "I_FOLDERDEPTH",
            1
        )

        local old_end_depth =
            reaper.GetMediaTrackInfo_Value(
                span.last_track,
                "I_FOLDERDEPTH"
            )

        reaper.SetMediaTrackInfo_Value(
            span.last_track,
            "I_FOLDERDEPTH",
            old_end_depth - 1
        )

        reaper.GetSetMediaTrackInfo_String(
            parent_track,
            "P_NAME",
            parent_name,
            true
        )

        fx_index = reaper.TrackFX_AddByName(
            parent_track,
            fx_name,
            false,
            -1
        )

        reaper.SetOnlyTrackSelected(
            parent_track
        )
    end, debug.traceback)

    reaper.PreventUIRefresh(-1)
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()

    if ok then
        reaper.Undo_EndBlock2(
            PROJECT,
            "Create folder from selected tracks and add Pro-L 2 / 从选中轨道创建文件夹并挂载 Pro-L 2",
            -1
        )

        if fx_index < 0 then
            show_message(
                "The folder was created, but Pro-L 2 could not be found.\n\n"
                .. "文件夹已创建，但未找到 Pro-L 2。"
            )
        end
    else
        reaper.Undo_EndBlock2(
            PROJECT,
            "Create folder failed / 创建文件夹失败",
            -1
        )

        show_message(
            "Unable to create the folder bus.\n\n"
            .. "无法创建文件夹总线。\n\n"
            .. tostring(err)
        )
    end
end

main()
