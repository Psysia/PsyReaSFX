-- @description Video Item Filename Overlay / 视频素材文件名覆盖显示
-- @version 1.0
-- @author Psysia
-- @requires js_ReaScriptAPI
-- @changelog
--   + Draw video source filenames directly inside visible Arrange View items.
--   + Hide file extensions and paths.
--   + Adapt font size to the visible item width and height.
--   + Support persistent font settings through the companion settings script.
--   + Provide toolbar toggle state and safe overlay cleanup.

local PROJECT = 0
local EXT_SECTION = "PsysiaVideoItemFilenameOverlay"

local DEFAULT_FONT_FACE = "Segoe UI"
local DEFAULT_MIN_SIZE = 10
local DEFAULT_MAX_SIZE = 30
local DEFAULT_WEIGHT = 600

local H_MARGIN = 8
local TOP_LABEL_RESERVE = 18
local REFRESH_INTERVAL = 0.033

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

local function has_required_api()
    local names = {
        "JS_Window_FindChildByID",
        "JS_Window_GetClientSize",
        "JS_LICE_CreateBitmap",
        "JS_LICE_DestroyBitmap",
        "JS_LICE_Clear",
        "JS_LICE_CreateFont",
        "JS_LICE_DestroyFont",
        "JS_LICE_SetFontFromGDI",
        "JS_LICE_SetFontColor",
        "JS_LICE_DrawText",
        "JS_GDI_CreateFont",
        "JS_GDI_DeleteObject",
        "JS_Composite",
        "JS_Composite_Unlink",
        "JS_Window_InvalidateRect",
    }

    for _, name in ipairs(names) do
        if not reaper.APIExists(name) then
            return false
        end
    end

    return true
end

if not has_required_api() then
    reaper.ShowMessageBox(
        "This script requires js_ReaScriptAPI.\n\n"
        .. "Install 'js_ReaScriptAPI: API functions for ReaScripts' through ReaPack, "
        .. "restart REAPER, then run this script again.\n\n"
        .. "此脚本需要 js_ReaScriptAPI。请通过 ReaPack 安装后重启 REAPER。",
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

if running_token ~= ""
and now - heartbeat < 1.0 then
    reaper.SetExtState(
        EXT_SECTION,
        "stop",
        running_token,
        false
    )
    return
end

reaper.DeleteExtState(
    EXT_SECTION,
    "running",
    false
)
reaper.DeleteExtState(
    EXT_SECTION,
    "stop",
    false
)

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

    reaper.DeleteExtState(
        EXT_SECTION,
        "running",
        false
    )

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

    return
end

local bitmap = nil
local bitmap_w = 0
local bitmap_h = 0
local composite_linked = false
local font_cache = {}
local last_signature = nil
local last_settings_revision = ""
local last_refresh = 0

local settings = {
    font_face = DEFAULT_FONT_FACE,
    min_size = DEFAULT_MIN_SIZE,
    max_size = DEFAULT_MAX_SIZE,
    weight = DEFAULT_WEIGHT,
}

local previous_delay = nil

if reaper.APIExists(
    "JS_Composite_Delay"
) then
    local ok, old_min, old_max, old_count =
        reaper.JS_Composite_Delay(
            arrange_hwnd,
            0.03,
            0.03,
            4
        )

    if ok then
        previous_delay = {
            min = old_min,
            max = old_max,
            count = old_count,
        }
    end
end

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    elseif value > maximum then
        return maximum
    end

    return value
end

local function destroy_fonts()
    for _, entry in pairs(font_cache) do
        if entry.lice then
            reaper.JS_LICE_DestroyFont(
                entry.lice
            )
        end

        if entry.gdi then
            reaper.JS_GDI_DeleteObject(
                entry.gdi
            )
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

    if revision == last_settings_revision
    and last_settings_revision ~= "" then
        return false
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

    last_settings_revision = revision
    destroy_fonts()
    last_signature = nil

    return true
end

local function get_font(size)
    local entry =
        font_cache[size]

    if entry then
        return entry.lice
    end

    local gdi =
        reaper.JS_GDI_CreateFont(
            size,
            settings.weight,
            0,
            false,
            false,
            false,
            settings.font_face
        )

    if not gdi then
        return nil
    end

    local lice =
        reaper.JS_LICE_CreateFont()

    if not lice then
        reaper.JS_GDI_DeleteObject(gdi)
        return nil
    end

    reaper.JS_LICE_SetFontFromGDI(
        lice,
        gdi,
        "SHADOW"
    )

    reaper.JS_LICE_SetFontColor(
        lice,
        0xFFFFFFFF
    )

    if reaper.APIExists(
        "JS_LICE_SetFontFXColor"
    ) then
        reaper.JS_LICE_SetFontFXColor(
            lice,
            0xFF000000
        )
    end

    font_cache[size] = {
        gdi = gdi,
        lice = lice,
    }

    return lice
end

local function destroy_bitmap()
    if bitmap then
        if composite_linked then
            reaper.JS_Composite_Unlink(
                arrange_hwnd,
                bitmap,
                true
            )
        end

        reaper.JS_LICE_DestroyBitmap(
            bitmap
        )
    end

    bitmap = nil
    bitmap_w = 0
    bitmap_h = 0
    composite_linked = false
end

local function ensure_bitmap(width, height)
    if bitmap
    and bitmap_w == width
    and bitmap_h == height then
        return true
    end

    destroy_bitmap()

    bitmap =
        reaper.JS_LICE_CreateBitmap(
            true,
            width,
            height
        )

    if not bitmap then
        return false
    end

    bitmap_w = width
    bitmap_h = height

    reaper.JS_Composite(
        arrange_hwnd,
        0,
        0,
        width,
        height,
        bitmap,
        0,
        0,
        width,
        height,
        true
    )

    composite_linked = true
    return true
end

local function is_video_path(path)
    local extension =
        path
        and path:match(
            "%.([^%.\\/]+)$"
        )

    if not extension then
        return false
    end

    return VIDEO_EXTENSIONS[
        extension:lower()
    ] == true
end

local function source_video_path(take)
    if not take then
        return nil
    end

    local source =
        reaper.GetMediaItemTake_Source(
            take
        )

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

        if path ~= ""
        and (
            is_video_path(path)
            or source_type:upper():find(
                "VIDEO",
                1,
                true
            )
        ) then
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

    if stem
    and stem ~= "" then
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
                units = units + 0.88
            elseif character:match(
                "[ilI1%.,':;|! ]"
            ) then
                units = units + 0.34
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
    available_width,
    available_height
)
    if available_width <= 0
    or available_height <= 0 then
        return nil
    end

    local units =
        text_units(text)

    local by_width =
        math.floor(
            available_width
            / units
        )

    local by_height =
        math.floor(
            available_height
            * 0.68
        )

    local size =
        math.min(
            settings.max_size,
            by_width,
            by_height
        )

    if size < settings.min_size then
        return nil
    end

    return size, units
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
        return {}, "empty-view"
    end

    local pixels_per_second =
        width
        / (view_end - view_start)

    local entries = {}
    local signature_parts = {
        tostring(width),
        tostring(height),
        string.format("%.9f", view_start),
        string.format("%.9f", view_end),
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

        local video_path =
            take
            and source_video_path(
                take
            )
            or nil

        if video_path then
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
                            (position - view_start)
                            * pixels_per_second
                        )

                    local x2 =
                        math.ceil(
                            (item_end - view_start)
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
                        track_y + item_y

                    local y2 =
                        y1 + item_h

                    if y2 > 0
                    and y1 < height
                    and x2 - x1 > 0 then
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

                        local visible_h =
                            visible_y2
                            - visible_y1

                        local title_reserve =
                            math.min(
                                TOP_LABEL_RESERVE,
                                math.max(
                                    0,
                                    visible_h - 4
                                )
                            )

                        local body_y1 =
                            visible_y1
                            + title_reserve

                        local body_h =
                            visible_y2
                            - body_y1

                        local body_w =
                            x2 - x1
                            - H_MARGIN * 2

                        local text =
                            filename_without_extension(
                                video_path
                            )

                        local size, units =
                            calculate_font_size(
                                text,
                                body_w,
                                body_h
                            )

                        if size then
                            local estimated_width =
                                units * size

                            local text_x =
                                math.floor(
                                    (x1 + x2)
                                    * 0.5
                                    - estimated_width
                                    * 0.5
                                )

                            local text_y =
                                math.floor(
                                    body_y1
                                    + (
                                        body_h - size
                                    ) * 0.5
                                )

                            text_x =
                                math.max(
                                    x1 + H_MARGIN,
                                    text_x
                                )

                            entries[
                                #entries + 1
                            ] = {
                                text = text,
                                size = size,
                                x1 = text_x,
                                y1 = text_y,
                                x2 = x2 - H_MARGIN,
                                y2 = visible_y2,
                            }

                            signature_parts[
                                #signature_parts + 1
                            ] =
                                table.concat(
                                    {
                                        text,
                                        size,
                                        x1,
                                        x2,
                                        visible_y1,
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

local function redraw()
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

    if not ensure_bitmap(
        width,
        height
    ) then
        return
    end

    load_settings()

    local entries, signature =
        collect_visible_entries(
            width,
            height
        )

    if signature == last_signature then
        return
    end

    last_signature = signature

    reaper.JS_LICE_Clear(
        bitmap,
        0x00000000
    )

    for _, entry in ipairs(entries) do
        local font =
            get_font(
                entry.size
            )

        if font then
            reaper.JS_LICE_DrawText(
                bitmap,
                font,
                entry.text,
                #entry.text,
                entry.x1,
                entry.y1,
                entry.x2,
                entry.y2
            )
        end
    end

    reaper.JS_Window_InvalidateRect(
        arrange_hwnd,
        0,
        0,
        width,
        height,
        false
    )
end

local function cleanup()
    destroy_bitmap()
    destroy_fonts()

    if previous_delay
    and reaper.APIExists(
        "JS_Composite_Delay"
    ) then
        reaper.JS_Composite_Delay(
            arrange_hwnd,
            previous_delay.min,
            previous_delay.max,
            previous_delay.count
        )
    end

    if reaper.ValidatePtr(
        arrange_hwnd,
        "HWND"
    ) then
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
        end
    end

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
