-- @description Cycle Selected Folders Unified Compact State / 统一轮换选中文件夹折叠状态
-- @version 1.4
-- @author Psysia
-- @changelog
--   + Keep the outer selected folders fully open during the child-folder compact stage.
--   + Make only nested child folders use I_FOLDERCOMPACT=1 in the third stage.
--   + Preserve the four distinct nested states and the flat two-state toggle.

local PROJECT = 0

local function valid_track(track)
    return track ~= nil
        and reaper.ValidatePtr2(PROJECT, track, "MediaTrack*")
end

local function is_folder_parent(track)
    return valid_track(track)
        and reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") > 0
end

local function compact_state(track)
    local state = math.floor(
        reaper.GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT") + 0.5
    )

    if state < 0 then
        return 0
    elseif state > 2 then
        return 2
    end

    return state
end

local function folder_nesting_depth(track)
    local depth = 0
    local parent = reaper.GetParentTrack(track)

    while parent do
        depth = depth + 1
        parent = reaper.GetParentTrack(parent)
    end

    return depth
end

local function has_selected_folder_ancestor(track, selected_folders)
    local parent = reaper.GetParentTrack(track)

    while parent do
        if selected_folders[parent] then
            return true
        end
        parent = reaper.GetParentTrack(parent)
    end

    return false
end

local function is_descendant_of_any(track, outermost_map)
    local parent = reaper.GetParentTrack(track)

    while parent do
        if outermost_map[parent] then
            return true
        end
        parent = reaper.GetParentTrack(parent)
    end

    return false
end

local function collect_selected_folders()
    local selected_count = reaper.CountSelectedTracks(PROJECT)
    local folders = {}
    local selected_map = {}

    for i = 0, selected_count - 1 do
        local track = reaper.GetSelectedTrack(PROJECT, i)

        if is_folder_parent(track) then
            local entry = {
                track = track,
                depth = folder_nesting_depth(track),
                track_number = math.floor(
                    reaper.GetMediaTrackInfo_Value(
                        track,
                        "IP_TRACKNUMBER"
                    ) + 0.5
                ),
            }

            folders[#folders + 1] = entry
            selected_map[track] = true
        end
    end

    return folders, selected_map
end

local function collect_outermost(folders, selected_map)
    local outermost = {}
    local outermost_map = {}

    for _, entry in ipairs(folders) do
        if not has_selected_folder_ancestor(
            entry.track,
            selected_map
        ) then
            outermost[#outermost + 1] = entry
            outermost_map[entry.track] = true
        end
    end

    table.sort(outermost, function(a, b)
        return a.track_number < b.track_number
    end)

    return outermost, outermost_map
end

local function collect_descendant_folders(outermost_map)
    local descendants = {}
    local track_count = reaper.CountTracks(PROJECT)

    for i = 0, track_count - 1 do
        local track = reaper.GetTrack(PROJECT, i)

        if is_folder_parent(track)
        and is_descendant_of_any(track, outermost_map) then
            descendants[#descendants + 1] = {
                track = track,
                depth = folder_nesting_depth(track),
                track_number = i + 1,
            }
        end
    end

    return descendants
end

local function sort_inner_to_outer(entries)
    table.sort(entries, function(a, b)
        if a.depth == b.depth then
            return a.track_number > b.track_number
        end
        return a.depth > b.depth
    end)
end

local function apply_state(entries, state)
    local ordered = {}

    for _, entry in ipairs(entries) do
        ordered[#ordered + 1] = entry
    end

    sort_inner_to_outer(ordered)

    for _, entry in ipairs(ordered) do
        if valid_track(entry.track) then
            reaper.SetMediaTrackInfo_Value(
                entry.track,
                "I_FOLDERCOMPACT",
                state
            )
        end
    end
end

local function all_in_state(entries, state)
    if #entries == 0 then
        return false
    end

    for _, entry in ipairs(entries) do
        if compact_state(entry.track) ~= state then
            return false
        end
    end

    return true
end

local function run_flat_mode(folders, outermost)
    local all_fully_collapsed =
        all_in_state(outermost, 2)

    local target =
        all_fully_collapsed and 0 or 2

    apply_state(folders, target)
end

local function run_nested_mode(
    outermost,
    descendants
)
    local outer_all_full =
        all_in_state(outermost, 2)

    local outer_all_open =
        all_in_state(outermost, 0)

    local descendants_all_collapsed =
        all_in_state(descendants, 2)

    local descendants_all_compact =
        all_in_state(descendants, 1)

    local action

    -- Four visible states:
    --
    -- 1. Deep Expanded
    --    outermost = 0, descendants = 0
    --
    -- 2. Child Folders Collapsed
    --    outermost = 0, descendants = 2
    --
    -- 3. Child Folders Compact
    --    outermost = 0, descendants = 1
    --
    -- 4. Fully Collapsed
    --    outermost = 2, descendants = 2
    --
    -- Then back to Deep Expanded.
    if outer_all_full then
        action = "deep"

    elseif outer_all_open
       and descendants_all_compact then
        action = "full"

    elseif outer_all_open
       and descendants_all_collapsed then
        action = "compact"

    else
        -- Deep Expanded or any mixed/open state is normalized
        -- to Child Folders Collapsed on the next press.
        action = "children_collapsed"
    end

    if action == "deep" then
        apply_state(descendants, 0)
        apply_state(outermost, 0)

    elseif action == "children_collapsed" then
        -- Keep the selected outer folders open, but hide the
        -- tracks inside every nested folder.
        apply_state(descendants, 2)
        apply_state(outermost, 0)

    elseif action == "compact" then
        -- Only compact the nested child folders. The selected outer
        -- folders stay fully open so unrelated outer-level tracks
        -- keep their normal height.
        apply_state(descendants, 1)
        apply_state(outermost, 0)

    else
        apply_state(descendants, 2)
        apply_state(outermost, 2)
    end
end

local function main()
    local folders, selected_map =
        collect_selected_folders()

    if #folders == 0 then
        return
    end

    local outermost, outermost_map =
        collect_outermost(
            folders,
            selected_map
        )

    local descendants =
        collect_descendant_folders(
            outermost_map
        )

    local has_nested_folders =
        #descendants > 0

    reaper.Undo_BeginBlock2(PROJECT)
    reaper.PreventUIRefresh(1)

    local ok, err = xpcall(function()
        if has_nested_folders then
            run_nested_mode(
                outermost,
                descendants
            )
        else
            run_flat_mode(
                folders,
                outermost
            )
        end
    end, debug.traceback)

    reaper.PreventUIRefresh(-1)
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()

    if ok then
        reaper.Undo_EndBlock2(
            PROJECT,
            "Cycle selected folders compact state / 轮换选中文件夹折叠状态",
            -1
        )
    else
        reaper.Undo_EndBlock2(
            PROJECT,
            "Cycle selected folders failed / 文件夹折叠状态切换失败",
            -1
        )

        reaper.ShowMessageBox(
            "Unable to change folder compact state.\n\n"
            .. "无法切换文件夹折叠状态。\n\n"
            .. tostring(err),
            "Cycle Folder Compact State / 轮换文件夹折叠状态",
            0
        )
    end
end

main()
