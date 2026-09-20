-- @description Video Item Filename Overlay / 视频素材文件名覆盖显示
-- @version 1.1
-- @author Psysia
-- @requires js_ReaScriptAPI
-- @changelog
--   + Replace LICE compositing with direct Arrange View GDI drawing for better reliability.
--   + Add source-detection fallbacks for original filename and take name.
--   + Keep labels visible at the minimum font size and use ellipsis when width is limited.
--   + Report when no video items can be detected.
--   + Preserve extension-free filenames and persistent font settings.

local PROJECT = 0
local EXT_SECTION = "PsysiaVideoItemFilenameOverlay"
local RUNNER_VERSION = "1.1"

local DEFAULT_FONT_FACE = "Segoe UI"
local DEFAULT_MIN_SIZE = 10
local DEFAULT_MAX_SIZE = 30
local DEFAULT_WEIGHT = 600

local H_MARGIN = 8
local TOP_LABEL_RESERVE = 18
local REFRESH_INTERVAL = 0.05

local VIDEO_EXTENSIONS = {
    mp4 = true,
    mov = true,
    mkv = true,
    avi = true,
    webm = true,
    m4v = true,
    mpg = true,
    mpeg = true,
    wmv = true,
    flv = true,
    ts = true,
    mts = true,
    m2ts = true,
    ogv = true,
}

local REQUIRED_APIS = {
    "JS_Window_FindChildByID",
    "JS_Window_GetClientSize",
    "JS_Window_InvalidateRect",
    "JS_Window_Update",
    "JS_GDI_GetClientDC",
    "JS_GDI_ReleaseDC",
    "JS_GDI_CreateFont",
    "JS_GDI_SelectObject",
    "JS_GDI_DeleteObject",
    "JS_GDI_SetTextColor",
    "JS_GDI_SetTextBkMode",
    "JS_GDI_DrawText",
}

local function has_required_api()
    for _, name in ipairs(REQUIRED_APIS) do
        if not reaper.APIExists(name) then
            return false, name
        end
    end

    return true
end

local api_ok, missing_api =
    has_required_api()

if not api_ok then
    reaper.ShowMessageBox(
        "This script requires js_ReaScriptAPI.\n\n"
        .. "Missing API: "
        .. tostring(missing_api)
        .. "\n\n"
        .. "Install or update 'js_ReaScriptAPI: API functions for ReaScripts' through ReaPack, "
        .. "restart REAPER, then run this script again.\n\n"
        .. "此脚本需要 js_ReaScriptAPI。请通过 ReaPack 安装或更新后重启 REAPER。",
        "Video Item Filename Overlay / 视频素材文件名覆盖显示",
        0
    )
    return
end

local _, _, SECTION_ID, COMMAND_ID =
    reaper.get_action_context()

local now = reaper.time_precise()
local running_token =
    reaper.GetExtState(
        EXT_SECTION,
        "running"
    )

local heartbeat =
    tonumber(
        reaper.GetExtState(
            EXT_SECTION,
            "heartbeat"
        )
    ) or 0

local running_version =
    reaper.GetExtState(
        EXT_SECTION,
        "runner_version"
    )

if running_token ~= ""
and now - heartbeat < 1.0 then
    if running_version == RUNNER_VERSION then
        reaper.SetExtState(
            EXT_SECTION,
            "stop",
            running_token,
            false
        )
        return
    else
        -- Stop a still-running instance from v1.0 / v1.0.1, but continue
        -- starting the new renderer immediately.
        reaper.SetExtState(
            EXT_SECTION,
            "stop",
            running_token,
            false
        )
    end
end

local token =
    string.format(
        "%.9f",
        now
    )

reaper.SetExtState(
    EXT_SECTION,
    "running",
    token,
    false
)

reaper.SetExtState(
    EXT_SECTION,
    "runner_version",
    RUNNER_VERSION,
    false
)

reaper.SetExtState(
    EXT_SECTION,
    "heartbeat",
    tostring(now),
    false
)

if COMMAND_ID and COMMAND_ID ~= 0 then
    reaper.SetToggleCommandState(
        SECTION_ID,
        COMMAND_ID,
        1
    )

    reaper.RefreshToolbar2(
        SECTION_ID,
        COMMAND_ID
    )
end

local main_hwnd =
    reaper.GetMainHwnd()

local arrange_hwnd =
    reaper.JS_Window_FindChildByID(
        main_hwnd,
        1000
    )

if not arrange_hwnd then
    reaper.ShowMessageBox(
        "Unable to locate the Arrange View.\n\n无法定位 Arrange View。",
        "Video Item Filename Overlay / 视频素材文件名覆盖显示",
        0
    )
    return
end

local settings = {
    font_face = DEFAULT_FONT_FACE,
    min_size = DEFAULT_MIN_SIZE,
    max_size = DEFAULT_MAX_SIZE,
    weight = DEFAULT_WEIGHT,
}

local font_cache = {}
local last_settings_revision = nil
local last_geometry_signature = nil
local last_refresh = 0
local warned_no_video = false

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    elseif value > maximum then
        return maximum
    end

    return value
end

local function destroy_fonts()
    for _, font in pairs(font_cache) do
        if font then
            reaper.JS_GDI_DeleteObject(font)
        end
    end

    font_cache = {}
end

local function load_settings()
    local revision =
        reaper.GetExtState(
            EXT_SECTION,
            "settings_revision"
        )

    local revision_key =
        revision ~= ""
        and revision
        or "__defaults__"

    if revision_key == last_settings_revision then
        return
    end

    local font_face =
        reaper.GetExtState(
            EXT_SECTION,
            "font_face"
        )

    local min_size =
        tonumber(
            reaper.GetExtState(
                EXT_SECTION,
                "min_size"
            )
        )

    local max_size =
        tonumber(
            reaper.GetExtState(
                EXT_SECTION,
                "max_size"
            )
        )

    local weight =
        tonumber(
            reaper.GetExtState(
                EXT_SECTION,
                "weight"
            )
        )

    settings.font_face =
        font_face ~= ""
        and font_face
        or DEFAULT_FONT_FACE

    settings.min_size =
        clamp(
            math.floor(
                min_size
                or DEFAULT_MIN_SIZE
            ),
            6,
            96
        )

    settings.max_size =
        clamp(
            math.floor(
                max_size
                or DEFAULT_MAX_SIZE
            ),
            settings.min_size,
            128
        )

    settings.weight =
        clamp(
            math.floor(
                weight
                or DEFAULT_WEIGHT
            ),
            0,
            1000
        )

    last_settings_revision =
        revision_key

    destroy_fonts()
    last_geometry_signature = nil
end

local function get_font(size)
    local font =
        font_cache[size]

    if font then
        return font
    end

    font =
        reaper.JS_GDI_CreateFont(
            size,
            settings.weight,
            0,
            false,
            false,
            false,
            settings.font_face
        )

    if font then
        font_cache[size] = font
    end

    return font
end

local function is_video_path(path)
    if not path or path == "" then
        return false
    end

    local extension =
        path:match(
            "%.([^%.\\/]+)$"
        )

    return extension ~= nil
        and VIDEO_EXTENSIONS[
            extension:lower()
        ] == true
end

local function source_video_path(take)
    if not take then
        return nil
    end

    -- If REAPER copied media on import, this can preserve the original name.
    local ok_original, original =
        reaper.GetSetMediaItemTakeInfo_String(
            take,
            "P_EXT:ORIGINAL_FILENAME",
            "",
            false
        )

    if ok_original
    and original ~= ""
    and is_video_path(original) then
        return original
    end

    local source =
        reaper.GetMediaItemTake_Source(
            take
        )

    local last_nonempty_path = nil
    local saw_video_source_type = false

    for _ = 1, 16 do
        if not source then
            break
        end

        local path =
            reaper.GetMediaSourceFileName(
                source
            ) or ""

        local source_type =
            reaper.GetMediaSourceType(
                source
            ) or ""

        if path ~= "" then
            last_nonempty_path = path
        end

        if source_type:upper():find(
            "VIDEO",
            1,
            true
        ) then
            saw_video_source_type = true
        end

        if is_video_path(path) then
            return path
        end

        local parent =
            reaper.GetMediaSourceParent(
                source
            )

        if not parent
        or parent == source then
            break
        end

        source = parent
    end

    if saw_video_source_type
    and last_nonempty_path then
        return last_nonempty_path
    end

    local take_name =
        reaper.GetTakeName(take)
        or ""

    if is_video_path(take_name) then
        return take_name
    end

    return nil
end

local function filename_without_extension(path)
    local filename =
        path:match(
            "([^\\/]+)$"
        ) or path

    local stem =
        filename:match(
            "^(.*)%.[^%.]+$"
        )

    if stem and stem ~= "" then
        return stem
    end

    return filename
end

local function text_units(text)
    local units = 0

    for _, codepoint in utf8.codes(text) do
        if codepoint < 128 then
            local character =
                string.char(codepoint)

            if character:match(
                "[MW@#%%&]"
            ) then
                units = units + 0.9
            elseif character:match(
                "[ilI1%.,':;|! ]"
            ) then
                units = units + 0.35
            else
                units = units + 0.58
            end
        else
            units = units + 1.0
        end
    end

    return math.max(
        units,
        1
    )
end

local function calculate_font_size(
    text,
    width,
    height
)
    if width < settings.min_size * 2
    or height < settings.min_size + 2 then
        return nil
    end

    local by_height =
        math.floor(
            height * 0.62
        )

    local by_width =
        math.floor(
            width
            / (
                text_units(text)
                * 0.62
            )
        )

    local candidate =
        math.min(
            settings.max_size,
            by_height,
            by_width
        )

    -- At narrow zoom levels, keep the minimum readable size and let
    -- DrawText ellipsize the filename instead of hiding it completely.
    return clamp(
        candidate,
        settings.min_size,
        settings.max_size
    )
end

local function collect_visible_entries(
    width,
    height
)
    local view_start, view_end =
        reaper.GetSet_ArrangeView2(
            PROJECT,
            false,
            0,
            0,
            0,
            0
        )

    if not view_start
    or not view_end
    or view_end <= view_start then
        return {}, "empty"
    end

    local pixels_per_second =
        width
        / (view_end - view_start)

    local entries = {}

    local signature_parts = {
        tostring(width),
        tostring(height),
        string.format(
            "%.8f",
            view_start
        ),
        string.format(
            "%.8f",
            view_end
        ),
        settings.font_face,
        tostring(settings.min_size),
        tostring(settings.max_size),
        tostring(settings.weight),
    }

    local item_count =
        reaper.CountMediaItems(PROJECT)

    for i = 0, item_count - 1 do
        local item =
            reaper.GetMediaItem(
                PROJECT,
                i
            )

        local take =
            item
            and reaper.GetActiveTake(
                item
            )
            or nil

        local path =
            take
            and source_video_path(
                take
            )
            or nil

        if path then
            local position =
                reaper.GetMediaItemInfo_Value(
                    item,
                    "D_POSITION"
                )

            local length =
                reaper.GetMediaItemInfo_Value(
                    item,
                    "D_LENGTH"
                )

            local item_end =
                position + length

            if item_end > view_start
            and position < view_end then
                local track =
                    reaper.GetMediaItem_Track(
                        item
                    )

                if track then
                    local x1 =
                        math.floor(
                            (
                                position
                                - view_start
                            )
                            * pixels_per_second
                        )

                    local x2 =
                        math.ceil(
                            (
                                item_end
                                - view_start
                            )
                            * pixels_per_second
                        )

                    x1 =
                        clamp(
                            x1,
                            0,
                            width
                        )

                    x2 =
                        clamp(
                            x2,
                            0,
                            width
                        )

                    local track_y =
                        math.floor(
                            reaper.GetMediaTrackInfo_Value(
                                track,
                                "I_TCPY"
                            )
                        )

                    local item_y =
                        math.floor(
                            reaper.GetMediaItemTakeInfo_Value(
                                take,
                                "I_LASTY"
                            )
                        )

                    local item_h =
                        math.floor(
                            reaper.GetMediaItemTakeInfo_Value(
                                take,
                                "I_LASTH"
                            )
                        )

                    if item_h <= 0 then
                        item_h =
                            math.floor(
                                reaper.GetMediaTrackInfo_Value(
                                    track,
                                    "I_TCPH"
                                )
                            )
                    end

                    local y1 =
                        track_y
                        + item_y

                    local y2 =
                        y1
                        + item_h

                    if x2 > x1
                    and y2 > 0
                    and y1 < height then
                        local visible_y1 =
                            clamp(
                                y1,
                                0,
                                height
                            )

                        local visible_y2 =
                            clamp(
                                y2,
                                0,
                                height
                            )

                        local body_y1 =
                            visible_y1
                            + math.min(
                                TOP_LABEL_RESERVE,
                                math.max(
                                    0,
                                    visible_y2
                                    - visible_y1
                                    - 4
                                )
                            )

                        local body_x1 =
                            x1 + H_MARGIN

                        local body_x2 =
                            x2 - H_MARGIN

                        local body_h =
                            visible_y2
                            - body_y1

                        local body_w =
                            body_x2
                            - body_x1

                        local text =
                            filename_without_extension(
                                path
                            )

                        local size =
                            calculate_font_size(
                                text,
                                body_w,
                                body_h
                            )

                        if size then
                            entries[
                                #entries + 1
                            ] = {
                                text = text,
                                size = size,
                                left = body_x1,
                                top = body_y1,
                                right = body_x2,
                                bottom = visible_y2,
                            }

                            signature_parts[
                                #signature_parts + 1
                            ] =
                                table.concat(
                                    {
                                        text,
                                        size,
                                        body_x1,
                                        body_y1,
                                        body_x2,
                                        visible_y2,
                                    },
                                    ":"
                                )
                        end
                    end
                end
            end
        end
    end

    return entries,
        table.concat(
            signature_parts,
            "|"
        )
end

local function count_video_items()
    local count = 0
    local item_count =
        reaper.CountMediaItems(PROJECT)

    for i = 0, item_count - 1 do
        local item =
            reaper.GetMediaItem(
                PROJECT,
                i
            )

        local take =
            item
            and reaper.GetActiveTake(
                item
            )
            or nil

        if take
        and source_video_path(take) then
            count = count + 1
        end
    end

    return count
end

local function redraw()
    load_settings()

    local ok, width, height =
        reaper.JS_Window_GetClientSize(
            arrange_hwnd
        )

    if not ok
    or not width
    or not height
    or width <= 0
    or height <= 0 then
        return
    end

    local entries, signature =
        collect_visible_entries(
            width,
            height
        )

    if signature
        ~= last_geometry_signature then

        last_geometry_signature =
            signature

        reaper.JS_Window_InvalidateRect(
            arrange_hwnd,
            0,
            0,
            width,
            height,
            false
        )

        reaper.JS_Window_Update(
            arrange_hwnd
        )
    end

    local dc =
        reaper.JS_GDI_GetClientDC(
            arrange_hwnd
        )

    if not dc then
        return
    end

    reaper.JS_GDI_SetTextBkMode(
        dc,
        1
    )

    local align =
        "HCENTER|VCENTER|SINGLELINE|NOPREFIX|ELLIPSIS"

    for _, entry in ipairs(entries) do
        local font =
            get_font(
                entry.size
            )

        if font then
            local old_font =
                reaper.JS_GDI_SelectObject(
                    dc,
                    font
                )

            -- Subtle black shadow.
            reaper.JS_GDI_SetTextColor(
                dc,
                0x000000
            )

            reaper.JS_GDI_DrawText(
                dc,
                entry.text,
                #entry.text,
                entry.left + 1,
                entry.top + 1,
                entry.right + 1,
                entry.bottom + 1,
                align
            )

            -- Main white label.
            reaper.JS_GDI_SetTextColor(
                dc,
                0xFFFFFF
            )

            reaper.JS_GDI_DrawText(
                dc,
                entry.text,
                #entry.text,
                entry.left,
                entry.top,
                entry.right,
                entry.bottom,
                align
            )

            if old_font then
                reaper.JS_GDI_SelectObject(
                    dc,
                    old_font
                )
            end
        end
    end

    reaper.JS_GDI_ReleaseDC(
        dc,
        arrange_hwnd
    )
end

local function clear_overlay()
    local ok, width, height =
        reaper.JS_Window_GetClientSize(
            arrange_hwnd
        )

    if ok then
        reaper.JS_Window_InvalidateRect(
            arrange_hwnd,
            0,
            0,
            width,
            height,
            false
        )

        reaper.JS_Window_Update(
            arrange_hwnd
        )
    end
end

local function cleanup()
    destroy_fonts()
    clear_overlay()

    if reaper.GetExtState(
        EXT_SECTION,
        "running"
    ) == token then
        reaper.DeleteExtState(
            EXT_SECTION,
            "running",
            false
        )

        reaper.DeleteExtState(
            EXT_SECTION,
            "heartbeat",
            false
        )

        reaper.DeleteExtState(
            EXT_SECTION,
            "runner_version",
            false
        )
    end

    if reaper.GetExtState(
        EXT_SECTION,
        "stop"
    ) == token then
        reaper.DeleteExtState(
            EXT_SECTION,
            "stop",
            false
        )
    end

    if COMMAND_ID and COMMAND_ID ~= 0 then
        reaper.SetToggleCommandState(
            SECTION_ID,
            COMMAND_ID,
            0
        )

        reaper.RefreshToolbar2(
            SECTION_ID,
            COMMAND_ID
        )
    end
end

reaper.atexit(cleanup)
load_settings()

if count_video_items() == 0 then
    warned_no_video = true

    reaper.ShowMessageBox(
        "The overlay started, but no video media items were detected in the current project.\n\n"
        .. "If the project does contain a video item, please tell me the file type shown in REAPER.\n\n"
        .. "覆盖显示已启动，但当前工程中没有识别到视频素材。"
        .. "如果工程里确实有视频，请告诉我 REAPER 中显示的文件类型。",
        "Video Item Filename Overlay / 视频素材文件名覆盖显示",
        0
    )
end

local function loop()
    if reaper.GetExtState(
        EXT_SECTION,
        "stop"
    ) == token then
        return
    end

    local current =
        reaper.time_precise()

    reaper.SetExtState(
        EXT_SECTION,
        "heartbeat",
        tostring(current),
        false
    )

    if current - last_refresh
        >= REFRESH_INTERVAL then

        last_refresh = current
        redraw()
    end

    reaper.defer(loop)
end

redraw()
reaper.defer(loop)
