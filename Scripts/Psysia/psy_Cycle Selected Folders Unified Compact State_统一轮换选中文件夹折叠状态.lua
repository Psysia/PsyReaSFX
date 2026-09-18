-- @description Cycle Selected Folders Unified Compact State / 统一轮换选中文件夹折叠状态
-- @version 1.0
-- @author Psysia
-- @changelog
--   + Cycle all selected folder tracks to one unified compact state.
--   + Handle nested selected folders from inner to outer.
--   + Ignore hidden child-folder states when deciding the next state.

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

local function main()
    local selected_count = reaper.CountSelectedTracks(PROJECT)
    if selected_count == 0 then
        return
    end

    local folders = {}
    local selected_folders = {}

    for i = 0, selected_count - 1 do
        local track = reaper.GetSelectedTrack(PROJECT, i)

        if is_folder_parent(track) then
            local entry = {
                track = track,
                depth = folder_nesting_depth(track),
                track_number = math.floor(
                    reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") + 0.5
                ),
            }

            folders[#folders + 1] = entry
            selected_folders[track] = true
        end
    end

    if #folders == 0 then
        return
    end

    -- Only the outermost selected folders decide the next state.
    -- Hidden nested folders may retain an old I_FOLDERCOMPACT value, so using
    -- them here could make repeated shortcut presses appear to skip states.
    local outermost = {}

    for _, entry in ipairs(folders) do
        if not has_selected_folder_ancestor(entry.track, selected_folders) then
            outermost[#outermost + 1] = entry.track
        end
    end

    -- 0 = expanded, 1 = compact, 2 = fully collapsed.
    -- If several outermost folders are already in different states, advance
    -- from the most-collapsed one so this press also resynchronizes them.
    local reference_state = 0

    for _, track in ipairs(outermost) do
        reference_state = math.max(reference_state, compact_state(track))
    end

    local target_state = (reference_state + 1) % 3

    -- Apply nested folders first and outer folders last. This guarantees that
    -- child folders have already received the unified state before a parent
    -- hides them.
    table.sort(folders, function(a, b)
        if a.depth == b.depth then
            return a.track_number > b.track_number
        end
        return a.depth > b.depth
    end)

    reaper.Undo_BeginBlock2(PROJECT)
    reaper.PreventUIRefresh(1)

    for _, entry in ipairs(folders) do
        if valid_track(entry.track) then
            reaper.SetMediaTrackInfo_Value(
                entry.track,
                "I_FOLDERCOMPACT",
                target_state
            )
        end
    end

    reaper.PreventUIRefresh(-1)
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()

    reaper.Undo_EndBlock2(
        PROJECT,
        "Cycle selected folders unified compact state / 统一轮换选中文件夹折叠状态",
        -1
    )
end

main()
