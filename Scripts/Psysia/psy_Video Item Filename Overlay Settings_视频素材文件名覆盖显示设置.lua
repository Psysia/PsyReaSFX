-- @description Video Item Track Name Overlay Settings / 视频素材轨道名覆盖显示设置
-- @version 1.1
-- @author Psysia
-- @changelog
--   + Rename the settings Action for the track-name overlay.
--   + Preserve the same ExtState keys so existing font settings remain compatible.
--   + Configure font face, minimum size, maximum size, and weight.

local EXT_SECTION =
    "PsysiaVideoItemFilenameOverlay"

local DEFAULT_FONT_FACE = "Segoe UI"
local DEFAULT_MIN_SIZE = 10
local DEFAULT_MAX_SIZE = 30
local DEFAULT_WEIGHT = 600

local function get_value(
    key,
    fallback
)
    local value =
        reaper.GetExtState(
            EXT_SECTION,
            key
        )

    if value == "" then
        return tostring(fallback)
    end

    return value
end

local font_face =
    get_value(
        "font_face",
        DEFAULT_FONT_FACE
    )

local min_size =
    get_value(
        "min_size",
        DEFAULT_MIN_SIZE
    )

local max_size =
    get_value(
        "max_size",
        DEFAULT_MAX_SIZE
    )

local weight =
    get_value(
        "weight",
        DEFAULT_WEIGHT
    )

local ok, values =
    reaper.GetUserInputs(
        "Video Track Name Overlay Settings / 视频轨道名覆盖设置",
        4,
        "Font / 字体,Minimum px / 最小字号,Maximum px / 最大字号,Weight 0-1000 / 字重,extrawidth=160",
        table.concat(
            {
                font_face,
                min_size,
                max_size,
                weight,
            },
            ","
        )
    )

if not ok then
    return
end

local new_font,
      new_min,
      new_max,
      new_weight =
    values:match(
        "^([^,]*),([^,]*),([^,]*),([^,]*)$"
    )

new_font =
    new_font
    and new_font:match(
        "^%s*(.-)%s*$"
    )
    or ""

new_min =
    tonumber(new_min)

new_max =
    tonumber(new_max)

new_weight =
    tonumber(new_weight)

if new_font == ""
or not new_min
or not new_max
or not new_weight
or new_min < 6
or new_min > 96
or new_max < new_min
or new_max > 128
or new_weight < 0
or new_weight > 1000 then
    reaper.ShowMessageBox(
        "Invalid settings.\n\n"
        .. "Minimum: 6-96 px\n"
        .. "Maximum: minimum-128 px\n"
        .. "Weight: 0-1000\n\n"
        .. "设置无效，请检查字号和字重范围。",
        "Video Track Name Overlay Settings / 视频轨道名覆盖设置",
        0
    )
    return
end

reaper.SetExtState(
    EXT_SECTION,
    "font_face",
    new_font,
    true
)

reaper.SetExtState(
    EXT_SECTION,
    "min_size",
    tostring(
        math.floor(new_min)
    ),
    true
)

reaper.SetExtState(
    EXT_SECTION,
    "max_size",
    tostring(
        math.floor(new_max)
    ),
    true
)

reaper.SetExtState(
    EXT_SECTION,
    "weight",
    tostring(
        math.floor(new_weight)
    ),
    true
)

reaper.SetExtState(
    EXT_SECTION,
    "settings_revision",
    tostring(
        reaper.time_precise()
    ),
    true
)
