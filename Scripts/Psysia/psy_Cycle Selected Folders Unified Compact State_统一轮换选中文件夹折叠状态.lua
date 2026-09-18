-- @description Cycle Selected Folders Unified Compact State / 统一轮换选中文件夹折叠状态
-- @version 1.1
-- @author Psysia
-- @changelog
--   + Add a fourth Deep Expanded state that opens every nested folder.
--   + Restore unselected nested folders when returning to Normal Expanded.
--   + Keep selected nested folder parents synchronized as one group.
--   + Preserve the existing Compact and Fully Collapsed states.

local PROJECT = 0
local EXT_SECTION = "PsysiaCycleSelectedFoldersUnifiedCompactState"

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

local function track_guid(track)
    if reaper.GetTrackGUID then
        return reaper.GetTrackGUID(track)
    end

    local _, guid = reaper.GetSetMediaTrackInfo_String(
        track,
        "GUID",
        "",
        false
    )
    return guid or ""
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

local function get_project_state(key)
    local retval, value = reaper.GetProjExtState(
        PROJECT,
        EXT_SECTION,
        key
    )

    if retval == 1 then
        return value or ""
    end

    return ""
end

local function set_project_state(key, value)
    reaper.SetProjExtState(
        PROJECT,
        EXT_SECTION,
        key,
        value or ""
    )
end

local function encode_snapshot(entries)
    local lines = {}

    for _, entry in ipairs(entries) do
        if entry.guid ~= "" then
            lines[#lines + 1] =
                entry.guid .. "\t" .. tostring(entry.state)
        end
    end

    return table.concat(lines, "\n")
end

local function decode_snapshot(text)
    local result = {}

    for line in string.gmatch(text or "", "[^\r\n]+") do
        local guid, state =
            string.match(line, "^(.-)\t([012])$")

        if guid and state then
            result[guid] = tonumber(state)
        end
    end

    return result
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
                guid = track_guid(track),
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

local function selection_signature(outermost)
    local parts = {}

    for _, entry in ipairs(outermost) do
        parts[#parts + 1] = entry.guid
    end

    return table.concat(parts, "|")
end

local function collect_descendant_folder_snapshot(
    outermost_map
)
    local snapshot = {}
    local track_count = reaper.CountTracks(PROJECT)

    for i = 0, track_count - 1 do
        local track = reaper.GetTrack(PROJECT, i)

        if is_folder_parent(track)
        and is_descendant_of_any(
            track,
            outermost_map
        ) then
            snapshot[#snapshot + 1] = {
                track = track,
                guid = track_guid(track),
                state = compact_state(track),
                depth = folder_nesting_depth(track),
                track_number = i + 1,
            }
        end
    end

    return snapshot
end

local function build_guid_map()
    local map = {}
    local track_count = reaper.CountTracks(PROJECT)

    for i = 0, track_count - 1 do
        local track = reaper.GetTrack(PROJECT, i)

        if is_folder_parent(track) then
            local guid = track_guid(track)
            if guid ~= "" then
                map[guid] = track
            end
        end
    end

    return map
end

local function sort_inner_to_outer(entries)
    table.sort(entries, function(a, b)
        if a.depth == b.depth then
            return a.track_number > b.track_number
        end
        return a.depth > b.depth
    end)
end

local function apply_selected_state(folders, state)
    local ordered = {}

    for _, entry in ipairs(folders) do
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

local function enter_deep_expanded(
    folders,
    outermost_map,
    signature
)
    local descendants =
        collect_descendant_folder_snapshot(
            outermost_map
        )

    set_project_state(
        "snapshot",
        encode_snapshot(descendants)
    )
    set_project_state(
        "selection_signature",
        signature
    )
    set_project_state(
        "stage",
        "deep"
    )

    -- Open descendant folders first, then the selected folder parents.
    sort_inner_to_outer(descendants)

    for _, entry in ipairs(descendants) do
        if valid_track(entry.track) then
            reaper.SetMediaTrackInfo_Value(
                entry.track,
                "I_FOLDERCOMPACT",
                0
            )
        end
    end

    apply_selected_state(folders, 0)
end

local function enter_normal_expanded(
    folders,
    selected_map,
    outermost_map,
    signature
)
    local saved =
        decode_snapshot(
            get_project_state("snapshot")
        )

    local guid_map = build_guid_map()

    -- Selected folder parents stay expanded. Unselected nested folders
    -- return to the state they had before Deep Expanded.
    for guid, state in pairs(saved) do
        local track = guid_map[guid]

        if valid_track(track)
        and not selected_map[track]
        and is_descendant_of_any(
            track,
            outermost_map
        ) then
            reaper.SetMediaTrackInfo_Value(
                track,
                "I_FOLDERCOMPACT",
                state
            )
        end
    end

    apply_selected_state(folders, 0)

    set_project_state(
        "selection_signature",
        signature
    )
    set_project_state(
        "stage",
        "normal"
    )
    set_project_state("snapshot", "")
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

    local signature =
        selection_signature(outermost)

    local stored_signature =
        get_project_state(
            "selection_signature"
        )

    local stored_stage =
        get_project_state("stage")

    local reference_state = 0

    for _, entry in ipairs(outermost) do
        reference_state =
            math.max(
                reference_state,
                compact_state(entry.track)
            )
    end

    local same_selection =
        signature ~= ""
        and signature == stored_signature

    local action

    -- Four-state cycle:
    -- Normal Expanded -> Compact -> Fully Collapsed
    -- -> Deep Expanded -> Normal Expanded
    if reference_state >= 2 then
        action = "deep"
    elseif reference_state == 1 then
        action = "full"
    elseif same_selection
       and stored_stage == "deep" then
        action = "normal"
    else
        action = "compact"
    end

    reaper.Undo_BeginBlock2(PROJECT)
    reaper.PreventUIRefresh(1)

    local ok, err = xpcall(function()
        if action == "deep" then
            enter_deep_expanded(
                folders,
                outermost_map,
                signature
            )

        elseif action == "normal" then
            enter_normal_expanded(
                folders,
                selected_map,
                outermost_map,
                signature
            )

        elseif action == "compact" then
            apply_selected_state(folders, 1)
            set_project_state(
                "selection_signature",
                signature
            )
            set_project_state(
                "stage",
                "compact"
            )
            set_project_state("snapshot", "")

        else
            apply_selected_state(folders, 2)
            set_project_state(
                "selection_signature",
                signature
            )
            set_project_state(
                "stage",
                "full"
            )
            set_project_state("snapshot", "")
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
