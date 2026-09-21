-- @description Video Item Track Name Overlay Settings / 视频素材轨道名覆盖显示设置
-- @version 1.2
-- @author Psysia
-- @changelog
--   + Add a dropdown containing installed Windows font families.
--   + Default to Microsoft YaHei UI with CJK-capable fallbacks.
--   + Keep minimum size, maximum size, and weight settings.
--   + Preserve the existing ExtState keys for compatibility.

local EXT_SECTION =
    "PsysiaVideoItemFilenameOverlay"

local DEFAULT_FONT_FACE =
    "Microsoft YaHei UI"

local DEFAULT_MIN_SIZE = 10
local DEFAULT_MAX_SIZE = 30
local DEFAULT_WEIGHT = 600

local CJK_FALLBACKS = {
    "Microsoft YaHei UI",
    "Microsoft YaHei",
    "SimHei",
    "SimSun",
    "Noto Sans CJK SC",
    "Noto Sans SC",
    "Source Han Sans SC",
    "PingFang SC",
    "Arial Unicode MS",
    "Segoe UI",
}

local function trim(text)
    return (
        text
        and text:match(
            "^%s*(.-)%s*$"
        )
        or ""
    )
end

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

local function parse_process_output(result)
    if not result or result == "" then
        return nil
    end

    local newline =
        result:find(
            "\n",
            1,
            true
        )

    if not newline then
        return nil
    end

    local code =
        trim(
            result:sub(
                1,
                newline - 1
            ):gsub(
                "\r",
                ""
            )
        )

    if tonumber(code) ~= 0 then
        return nil
    end

    return result:sub(
        newline + 1
    )
end

local function add_unique_font(
    fonts,
    seen,
    name
)
    name = trim(name)

    if name == "" then
        return
    end

    -- gfx.showmenu uses | as a field delimiter.
    if name:find(
        "|",
        1,
        true
    ) then
        return
    end

    local key =
        name:lower()

    if not seen[key] then
        seen[key] = true
        fonts[#fonts + 1] = name
    end
end

local function enumerate_windows_fonts()
    local command = [[powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; Add-Type -AssemblyName System.Drawing; $c=New-Object System.Drawing.Text.InstalledFontCollection; $c.Families | ForEach-Object { $_.Name } | Sort-Object -Unique"]]

    local result =
        reaper.ExecProcess(
            command,
            0
        )

    local output =
        parse_process_output(
            result
        )

    if not output then
        return {}
    end

    -- Remove UTF-8 BOM if PowerShell emitted one.
    output =
        output:gsub(
            "^\239\187\191",
            ""
        )

    local fonts = {}
    local seen = {}

    for line in output:gmatch(
        "[^\r\n]+"
    ) do
        add_unique_font(
            fonts,
            seen,
            line
        )
    end

    table.sort(
        fonts,
        function(a, b)
            return a:lower()
                < b:lower()
        end
    )

    return fonts
end

local function fallback_fonts()
    local fonts = {}
    local seen = {}

    for _, name in ipairs(
        CJK_FALLBACKS
    ) do
        add_unique_font(
            fonts,
            seen,
            name
        )
    end

    return fonts
end

local function enumerate_fonts()
    local os_name =
        reaper.GetOS()
        or ""

    if os_name:match(
        "^Win"
    ) then
        local fonts =
            enumerate_windows_fonts()

        if #fonts > 0 then
            return fonts, true
        end
    end

    return fallback_fonts(), false
end

local function contains_font(
    fonts,
    name
)
    local wanted =
        (name or ""):lower()

    for _, font in ipairs(fonts) do
        if font:lower()
            == wanted then
            return true
        end
    end

    return false
end

local function recommended_font(fonts)
    for _, candidate in ipairs(
        CJK_FALLBACKS
    ) do
        if contains_font(
            fonts,
            candidate
        ) then
            return candidate
        end
    end

    return fonts[1]
        or DEFAULT_FONT_FACE
end

local function menu_label(
    name,
    checked
)
    local label =
        name:gsub(
            "[\r\n]",
            " "
        )

    -- Avoid accidental gfx.showmenu control prefixes.
    if label:match(
        "^[#><]"
    ) then
        label = " " .. label
    end

    if checked then
        return "!" .. label
    end

    return label
end

local fonts, full_list =
    enumerate_fonts()

local saved_font =
    reaper.GetExtState(
        EXT_SECTION,
        "font_face"
    )

local current_font =
    saved_font ~= ""
    and saved_font
    or recommended_font(fonts)

-- Put the current font first, the recommended CJK font second,
-- then all other installed fonts alphabetically.
local ordered = {}
local seen = {}

local function push_font(name)
    if not name or name == "" then
        return
    end

    local key =
        name:lower()

    if not seen[key] then
        seen[key] = true
        ordered[#ordered + 1] = name
    end
end

push_font(current_font)

local recommended =
    recommended_font(fonts)

push_font(recommended)

for _, name in ipairs(fonts) do
    push_font(name)
end

if #ordered == 0 then
    reaper.ShowMessageBox(
        "No usable fonts were found.\n\n"
        .. "未找到可用字体。",
        "Video Track Name Overlay Settings / 视频轨道名覆盖设置",
        0
    )
    return
end

local menu_parts = {}

for i, name in ipairs(ordered) do
    menu_parts[i] =
        menu_label(
            name,
            name:lower()
                == current_font:lower()
        )
end

local mouse_x, mouse_y =
    reaper.GetMousePosition()

gfx.init(
    "Video Track Name Overlay Font",
    1,
    1,
    0,
    mouse_x,
    mouse_y
)

gfx.x = 0
gfx.y = 0

local choice =
    gfx.showmenu(
        table.concat(
            menu_parts,
            "|"
        )
    )

gfx.quit()

if choice <= 0
or not ordered[choice] then
    return
end

local selected_font =
    ordered[choice]

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
        3,
        "Minimum px / 最小字号,Maximum px / 最大字号,Weight 0-1000 / 字重,extrawidth=160",
        table.concat(
            {
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

local new_min,
      new_max,
      new_weight =
    values:match(
        "^([^,]*),([^,]*),([^,]*)$"
    )

new_min =
    tonumber(new_min)

new_max =
    tonumber(new_max)

new_weight =
    tonumber(new_weight)

if not new_min
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
    selected_font,
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

if not full_list then
    reaper.ShowMessageBox(
        "The full installed-font list could not be enumerated on this system, "
        .. "so a CJK-capable fallback list was used.\n\n"
        .. "当前系统无法枚举完整字体列表，已使用支持中文的备用字体列表。",
        "Video Track Name Overlay Settings / 视频轨道名覆盖设置",
        0
    )
end
