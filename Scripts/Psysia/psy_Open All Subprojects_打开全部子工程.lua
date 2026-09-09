-- @description Open All Subprojects / 打开全部子工程
-- @version 1.0
-- @author Psysia

local NEW_PROJECT_TAB = 40859
local IS_WINDOWS = reaper.GetOS():match("Win") ~= nil

local function path_key(path)
    if not path or path == "" then return nil end
    local key = path:gsub("\\", "/"):gsub("/+$", "")
    if IS_WINDOWS then key = key:lower() end
    return key
end

local function dirname(path)
    if not path or path == "" then return "" end
    return path:match("^(.*[\\/])") or ""
end

local function is_absolute_path(path)
    if not path or path == "" then return false end
    if path:match("^%a:[\\/]") then return true end
    if path:match("^[\\/][\\/]") then return true end
    if path:sub(1, 1) == "/" or path:sub(1, 1) == "\\" then return true end
    return false
end

local function make_absolute(path, base_dir)
    if not path or path == "" then return nil end
    if is_absolute_path(path) or not base_dir or base_dir == "" then return path end
    return base_dir .. path
end

local function get_sws_rpp_path(source)
    if not reaper.APIExists("CF_GetMediaSourceRPP") then return nil end

    -- Newer SWS builds allow the output buffer arguments to be omitted in Lua.
    local ok, retval, filename = pcall(reaper.CF_GetMediaSourceRPP, source)
    if ok and retval and type(filename) == "string" and filename ~= "" then
        return filename
    end

    -- Compatibility fallback for older SWS Lua bindings.
    ok, retval, filename = pcall(reaper.CF_GetMediaSourceRPP, source, "")
    if ok and retval and type(filename) == "string" and filename ~= "" then
        return filename
    end

    return nil
end

local function get_subproject_path_from_source(source, base_dir)
    local src = source

    -- Walk through SECTION/REVERSE wrappers until the underlying source is reached.
    for _ = 1, 16 do
        if not src then break end

        local source_type = reaper.GetMediaSourceType(src, "") or ""
        local filename = reaper.GetMediaSourceFileName(src) or ""
        local lower = filename:lower()
        local is_rpp_project = source_type == "RPP_PROJECT"
        local is_rpp_proxy = lower:match("%.rpp%-prox$") ~= nil
        local is_rpp_file = lower:match("%.rpp$") ~= nil

        if is_rpp_project or is_rpp_proxy or is_rpp_file then
            -- SWS can return the exact associated .RPP path, but is completely optional.
            local sws_path = get_sws_rpp_path(src)
            if sws_path then
                return make_absolute(sws_path, base_dir)
            end

            if is_rpp_proxy then
                -- REAPER renders Subproject.RPP as Subproject.RPP-PROX.
                filename = filename:sub(1, -6)
            end

            if filename:lower():match("%.rpp$") then
                return make_absolute(filename, base_dir)
            end
        end

        local parent = reaper.GetMediaSourceParent(src)
        if not parent or parent == src then break end
        src = parent
    end

    return nil
end

local function collect_subprojects(project, base_dir)
    local result = {}
    local seen = {}
    local item_count = reaper.CountMediaItems(project)

    for i = 0, item_count - 1 do
        local item = reaper.GetMediaItem(project, i)
        local take = item and reaper.GetActiveTake(item) or nil

        if take then
            local source = reaper.GetMediaItemTake_Source(take)
            local path = source and get_subproject_path_from_source(source, base_dir) or nil
            local key = path_key(path)

            if key and not seen[key] then
                seen[key] = true
                result[#result + 1] = path
            end
        end
    end

    return result
end

local function enum_open_projects()
    local by_path = {}
    local i = 0

    while true do
        local project, filename = reaper.EnumProjects(i)
        if not project then break end

        local key = path_key(filename)
        if key then by_path[key] = project end
        i = i + 1
    end

    return by_path
end

local original_project, original_filename = reaper.EnumProjects(-1)
if not original_project then return end

local open_projects = enum_open_projects()
local scanned = {}
local queued = {}
local queue = {}
local missing = {}
local opened_count = 0
local already_open_count = 0

local original_key = path_key(original_filename)
if original_key then scanned[original_key] = true end

local function enqueue(path)
    local key = path_key(path)
    if not key or scanned[key] or queued[key] then return end

    queued[key] = true
    queue[#queue + 1] = path
end

local root_base = dirname(original_filename)
for _, path in ipairs(collect_subprojects(original_project, root_base)) do
    enqueue(path)
end

if #queue == 0 then
    reaper.MB(
        "No subprojects were found in the current project.\n\n当前工程中未找到子工程。",
        "Open All Subprojects / 打开全部子工程",
        0
    )
    return
end

local index = 1
while index <= #queue do
    local path = queue[index]
    index = index + 1

    local key = path_key(path)
    queued[key] = nil

    if key and not scanned[key] then
        scanned[key] = true

        local project = open_projects[key]

        if project then
            already_open_count = already_open_count + 1
        elseif reaper.file_exists(path) then
            reaper.Main_OnCommand(NEW_PROJECT_TAB, 0)
            reaper.Main_openProject("noprompt:" .. path)

            local current_project, current_filename = reaper.EnumProjects(-1)
            if current_project then
                local current_key = path_key(current_filename)
                if current_key then open_projects[current_key] = current_project end

                -- REAPER may normalize path separators/case while opening.
                if current_key == key then
                    project = current_project
                    open_projects[key] = current_project
                    opened_count = opened_count + 1
                end
            end
        else
            missing[#missing + 1] = path
        end

        -- Recursively discover nested subprojects from every successfully resolved child project.
        if project then
            local child_base = dirname(path)
            for _, child_path in ipairs(collect_subprojects(project, child_base)) do
                enqueue(child_path)
            end
        end
    end
end

-- Return focus to the project from which the script was launched.
reaper.SelectProjectInstance(original_project)

if #missing > 0 then
    local lines = {
        string.format("Opened: %d", opened_count),
        string.format("Already open: %d", already_open_count),
        string.format("Missing: %d", #missing),
        "",
        "Missing subproject files / 缺失的子工程文件："
    }

    local max_list = math.min(#missing, 10)
    for i = 1, max_list do
        lines[#lines + 1] = missing[i]
    end
    if #missing > max_list then
        lines[#lines + 1] = string.format("... +%d", #missing - max_list)
    end

    reaper.MB(
        table.concat(lines, "\n"),
        "Open All Subprojects / 打开全部子工程",
        0
    )
end
