-- @description Sort Tracks by Earliest Item Position / 按最早素材位置排序轨道
-- @version 1.4
-- @author Psysia
-- @changelog
--   + Make sorting folder-aware and preserve complete folder subtrees.
--   + Automatically sort at the nearest common hierarchy level.
--   + Treat sibling folders as indivisible units instead of moving folder parents alone.
--   + Keep unselected sibling units in their original slots.

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
    ) - 1
end

local function save_selected_tracks()
    local tracks = {}
    local count =
        reaper.CountSelectedTracks(PROJECT)

    for i = 0, count - 1 do
        local track =
            reaper.GetSelectedTrack(
                PROJECT,
                i
            )

        if valid_track(track) then
            tracks[#tracks + 1] = track
        end
    end

    return tracks
end

local function restore_track_selection(tracks)
    reaper.Main_OnCommand(40297, 0)

    for _, track in ipairs(tracks) do
        if valid_track(track) then
            reaper.SetTrackSelected(
                track,
                true
            )
        end
    end
end

local function is_descendant_of(
    track,
    ancestor
)
    if not valid_track(track)
    or not valid_track(ancestor) then
        return false
    end

    local parent =
        reaper.GetParentTrack(track)

    while parent do
        if parent == ancestor then
            return true
        end

        parent =
            reaper.GetParentTrack(parent)
    end

    return false
end

local function subtree_end_index(root)
    local start_index = track_index(root)
    local last_index = start_index
    local count = reaper.CountTracks(PROJECT)

    for i = start_index + 1, count - 1 do
        local track =
            reaper.GetTrack(PROJECT, i)

        if track
        and is_descendant_of(track, root) then
            last_index = i
        else
            break
        end
    end

    return last_index
end

local function collect_unique_target_tracks(
    item_mode
)
    local tracks = {}
    local seen = {}

    if item_mode then
        local count =
            reaper.CountSelectedMediaItems(
                PROJECT
            )

        for i = 0, count - 1 do
            local item =
                reaper.GetSelectedMediaItem(
                    PROJECT,
                    i
                )

            local track =
                item
                and reaper.GetMediaItem_Track(
                    item
                )
                or nil

            if valid_track(track)
            and not seen[track] then
                seen[track] = true
                tracks[#tracks + 1] = track
            end
        end
    else
        local count =
            reaper.CountSelectedTracks(PROJECT)

        for i = 0, count - 1 do
            local track =
                reaper.GetSelectedTrack(
                    PROJECT,
                    i
                )

            if valid_track(track)
            and not seen[track] then
                seen[track] = true
                tracks[#tracks + 1] = track
            end
        end
    end

    return tracks
end

local function prune_descendant_targets(tracks)
    local selected_map = {}

    for _, track in ipairs(tracks) do
        selected_map[track] = true
    end

    local roots = {}

    for _, track in ipairs(tracks) do
        local parent =
            reaper.GetParentTrack(track)

        local shadowed = false

        while parent do
            if selected_map[parent] then
                shadowed = true
                break
            end

            parent =
                reaper.GetParentTrack(parent)
        end

        if not shadowed then
            roots[#roots + 1] = track
        end
    end

    return roots
end

local function has_ancestor(
    track,
    ancestor
)
    if ancestor == nil then
        return true
    end

    if track == ancestor then
        return true
    end

    return is_descendant_of(
        track,
        ancestor
    )
end

local function find_nearest_common_parent(roots)
    if #roots == 0 then
        return nil
    end

    local candidate =
        reaper.GetParentTrack(roots[1])

    while true do
        local common = true

        for i = 2, #roots do
            if not has_ancestor(
                roots[i],
                candidate
            ) then
                common = false
                break
            end
        end

        if common then
            return candidate
        end

        if candidate == nil then
            return nil
        end

        candidate =
            reaper.GetParentTrack(candidate)
    end
end

local function unit_root_for_track(
    track,
    scope_parent
)
    local current = track

    while reaper.GetParentTrack(current)
        ~= scope_parent do

        current =
            reaper.GetParentTrack(current)

        if not current then
            return nil
        end
    end

    return current
end

local function collect_units(
    target_tracks,
    scope_parent
)
    local units = {}
    local seen = {}

    for _, track in ipairs(target_tracks) do
        local root =
            unit_root_for_track(
                track,
                scope_parent
            )

        if valid_track(root)
        and not seen[root] then
            seen[root] = true

            units[#units + 1] = {
                track = root,
                position = math.huge,
                original_order =
                    track_index(root),
            }
        end
    end

    return units, seen
end

local function find_unit_entry(
    units,
    root
)
    for _, entry in ipairs(units) do
        if entry.track == root then
            return entry
        end
    end

    return nil
end

local function set_item_mode_positions(
    units,
    scope_parent
)
    local count =
        reaper.CountSelectedMediaItems(
            PROJECT
        )

    for i = 0, count - 1 do
        local item =
            reaper.GetSelectedMediaItem(
                PROJECT,
                i
            )

        local track =
            item
            and reaper.GetMediaItem_Track(item)
            or nil

        if valid_track(track) then
            local root =
                unit_root_for_track(
                    track,
                    scope_parent
                )

            local entry =
                root
                and find_unit_entry(
                    units,
                    root
                )
                or nil

            if entry then
                local position =
                    reaper.GetMediaItemInfo_Value(
                        item,
                        "D_POSITION"
                    )

                if position < entry.position then
                    entry.position = position
                end
            end
        end
    end
end

local function earliest_item_in_subtree(root)
    local start_index = track_index(root)
    local end_index =
        subtree_end_index(root)

    local earliest = math.huge

    for track_i = start_index, end_index do
        local track =
            reaper.GetTrack(
                PROJECT,
                track_i
            )

        if valid_track(track) then
            local item_count =
                reaper.CountTrackMediaItems(
                    track
                )

            for item_i = 0, item_count - 1 do
                local item =
                    reaper.GetTrackMediaItem(
                        track,
                        item_i
                    )

                local position =
                    reaper.GetMediaItemInfo_Value(
                        item,
                        "D_POSITION"
                    )

                if position < earliest then
                    earliest = position
                end
            end
        end
    end

    return earliest
end

local function set_track_mode_positions(units)
    for _, entry in ipairs(units) do
        entry.position =
            earliest_item_in_subtree(
                entry.track
            )
    end
end

local function sort_units(units)
    table.sort(units, function(a, b)
        if a.position == b.position then
            return a.original_order
                < b.original_order
        end

        return a.position < b.position
    end)
end

local function collect_sibling_units(scope_parent)
    local siblings = {}
    local count =
        reaper.CountTracks(PROJECT)

    for i = 0, count - 1 do
        local track =
            reaper.GetTrack(PROJECT, i)

        if valid_track(track)
        and reaper.GetParentTrack(track)
            == scope_parent then

            siblings[#siblings + 1] =
                track
        end
    end

    return siblings
end

local function build_desired_order(
    siblings,
    selected_units,
    sorted_units
)
    local desired = {}
    local sorted_index = 1

    for _, sibling in ipairs(siblings) do
        if selected_units[sibling] then
            desired[#desired + 1] =
                sorted_units[
                    sorted_index
                ].track

            sorted_index =
                sorted_index + 1
        else
            desired[#desired + 1] =
                sibling
        end
    end

    return desired
end

local function select_complete_unit(root)
    reaper.Main_OnCommand(40297, 0)

    local start_index = track_index(root)
    local end_index =
        subtree_end_index(root)

    for i = start_index, end_index do
        local track =
            reaper.GetTrack(PROJECT, i)

        if valid_track(track) then
            reaper.SetTrackSelected(
                track,
                true
            )
        end
    end
end

local function reorder_to_desired_order(
    desired,
    scope_parent
)
    local previous = nil

    for i, root in ipairs(desired) do
        if not valid_track(root) then
            error(
                "Track pointer became invalid at unit "
                .. i
            )
        end

        local destination_index

        if previous then
            destination_index =
                subtree_end_index(previous)
                + 1
        elseif scope_parent then
            destination_index =
                track_index(scope_parent)
                + 1
        else
            destination_index = 0
        end

        local current_index =
            track_index(root)

        if current_index
            ~= destination_index then

            if current_index
                < destination_index then
                error(
                    "Unexpected unit order while rebuilding hierarchy."
                )
            end

            select_complete_unit(root)

            -- Normal move: complete subtrees are selected as one block.
            -- Because units are rebuilt from top to bottom at one sibling
            -- level, this preserves the parent/child hierarchy.
            if not reaper.ReorderSelectedTracks(
                destination_index,
                0
            ) then
                error(
                    "REAPER rejected unit move "
                    .. i
                )
            end
        end

        previous = root
    end
end

local function main()
    local original_track_selection =
        save_selected_tracks()

    local item_mode =
        reaper.CountSelectedMediaItems(
            PROJECT
        ) > 0

    local target_tracks =
        collect_unique_target_tracks(
            item_mode
        )

    if #target_tracks < 2 then
        reaper.ShowMessageBox(
            item_mode
                and "Select media items that resolve to at least two sortable tracks/folders.\n\n请选择至少两个可排序轨道或文件夹中的素材。"
                or "Select at least two sortable tracks/folders.\n\n请至少选择两个可排序的轨道或文件夹。",
            "Sort Tracks / 排序轨道",
            0
        )
        return
    end

    local root_targets =
        prune_descendant_targets(
            target_tracks
        )

    local scope_parent =
        find_nearest_common_parent(
            root_targets
        )

    local units, selected_units =
        collect_units(
            target_tracks,
            scope_parent
        )

    if #units < 2 then
        reaper.ShowMessageBox(
            "The selection resolves to only one folder-aware sorting unit.\n\n当前选择在文件夹层级中只对应一个排序单元。",
            "Sort Tracks / 排序轨道",
            0
        )
        return
    end

    if item_mode then
        set_item_mode_positions(
            units,
            scope_parent
        )
    else
        set_track_mode_positions(units)
    end

    local siblings =
        collect_sibling_units(
            scope_parent
        )

    local sorted_units = {}

    for _, entry in ipairs(units) do
        sorted_units[#sorted_units + 1] =
            entry
    end

    sort_units(sorted_units)

    local desired =
        build_desired_order(
            siblings,
            selected_units,
            sorted_units
        )

    reaper.Undo_BeginBlock2(PROJECT)
    reaper.PreventUIRefresh(1)

    local ok, err = xpcall(function()
        reorder_to_desired_order(
            desired,
            scope_parent
        )
    end, debug.traceback)

    restore_track_selection(
        original_track_selection
    )

    reaper.PreventUIRefresh(-1)
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()

    if ok then
        reaper.Undo_EndBlock2(
            PROJECT,
            item_mode
                and "Sort folder-aware units by selected item positions / 按选中素材位置排序文件夹单元"
                or "Sort folder-aware units by earliest item position / 按最早素材位置排序文件夹单元",
            -1
        )
    else
        reaper.Undo_EndBlock2(
            PROJECT,
            "Sort tracks failed / 排序轨道失败",
            -1
        )

        reaper.ShowMessageBox(
            "Unable to reorder the folder-aware track units.\n\n无法重新排列文件夹排序单元。\n\n"
            .. tostring(err),
            "Sort Tracks / 排序轨道",
            0
        )
    end
end

main()
