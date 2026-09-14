local source_path = assert(
  arg[1],
  "usage: lua_preview_seek_selftest.lua <runtime-ui-source>"
)
local handle = assert(io.open(source_path, "rb"))
local source = handle:read("*a")
handle:close()

local function region(first, following)
  local start_at = assert(source:find(first, 1, true), "missing marker: " .. first)
  local end_at = assert(
    source:find(following, start_at + #first, true),
    "missing marker: " .. following
  )
  return source:sub(start_at, end_at - 1)
end

function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

assert(load(region(
  "function preview_percent_from_position(",
  "function play_preview("
), "preview-mapping", "t", _ENV))()

local forward = preview_position_from_percent(0.625, 8, 0, 1, false)
assert(math.abs(forward - 5) < 0.000001, "forward seek mapping is incorrect")
assert(
  math.abs(preview_percent_from_position(forward, 8, 0, 1, false) - 0.625)
    < 0.000001,
  "forward playhead mapping must round-trip"
)

local reverse = preview_position_from_percent(0.625, 8, 0, 1, true)
assert(math.abs(reverse - 3) < 0.000001, "reverse seek mapping is incorrect")
assert(
  math.abs(preview_percent_from_position(reverse, 8, 0, 1, true) - 0.625)
    < 0.000001,
  "reverse playhead mapping must round-trip"
)

local play_preview_source = region(
  "function play_preview(",
  "function update_preview_parameters()"
)
assert(
  play_preview_source:find("and start_percent > 0", 1, true),
  "zero-percent full preview must not seek to the end of a reversed source"
)

assert(
  math.abs(preview_percent_from_position(0, 4, 0.25, 0.5, false) - 0.25)
    < 0.000001,
  "forward selection must start at its left boundary"
)
assert(
  math.abs(preview_percent_from_position(0, 4, 0.25, 0.5, true) - 0.75)
    < 0.000001,
  "reverse selection must start at its right boundary"
)

local positions = { 0, 5.02 }
local clock = 10
state = {
  preview = {},
  preview_length = 8,
  preview_position = 5,
  preview_percent = 0.625,
  preview_map_start = 0,
  preview_map_span = 1,
  preview_map_reverse = false,
  preview_seek_target = 5,
  preview_seek_started_at = clock,
}
reaper = {
  CF_Preview_GetValue = function()
    return true, table.remove(positions, 1)
  end,
  time_precise = function() return clock end,
}
Jobs = {}
AppState = {
  set = function(name, value)
    state[name] = value
    return value
  end,
}

assert(load(region(
  "function poll_preview()",
  "-- Selection, favorites and insertion"
), "preview-poll", "t", _ENV))()

poll_preview()
assert(
  state.preview_position == 5 and state.preview_percent == 0.625,
  "the transient zero position must not flash the playhead at the start"
)
assert(state.preview_seek_target == 5, "seek must remain pending until confirmed")

poll_preview()
assert(
  state.preview_seek_target == nil and state.preview_position == 5.02,
  "confirmed seek position must resume normal preview polling"
)

print("Lua preview seek self-test passed")
