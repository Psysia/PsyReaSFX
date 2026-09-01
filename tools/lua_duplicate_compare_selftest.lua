local root = assert(arg[1], "temporary test directory is required")
local module_path = assert(arg[2], "duplicate comparison module is required")
local sep = package.config:sub(1, 1)

local function path(name) return root .. sep .. name end
local function write(path_value, value)
  local file = assert(io.open(path_value, "wb"))
  assert(file:write(value))
  assert(file:close())
end
local function finish(comparison)
  local result = "pending"
  local steps = 0
  while result == "pending" do
    result = step_duplicate_comparison(comparison, 4096)
    steps = steps + 1
    assert(steps < 100, "comparison did not converge")
  end
  return result, steps
end

assert(loadfile(module_path))()

reaper = {
  JS_File_Stat = function()
    return 0, 9004, "2026.09.01 10:00:00", "2026.09.01 09:00:00", "", 1, 0, 1, 0, 1, 0, 0
  end,
}
local metadata_asset = {}
local metadata_stat = duplicate_file_stat("metadata.bin", 0)
record_asset_fingerprint(metadata_asset, "fingerprint", metadata_stat)
assert(metadata_asset.fingerprint_version == "sample-fnv1a-head-mid-tail-v1")
assert(metadata_asset.fingerprint_modified == "2026.09.01 09:00:00")
assert(metadata_asset.fingerprint_stat_source == "js_file_stat")
assert(fingerprint_metadata_is_compatible(metadata_asset))
assert(fingerprint_metadata_is_current(metadata_asset, metadata_stat))
local changed_size = { size = 9005, modified = metadata_stat.modified, source = "js_file_stat" }
local changed_time = { size = 9004, modified = "2026.09.01 09:00:01", source = "js_file_stat" }
assert(not fingerprint_metadata_is_current(metadata_asset, changed_size))
assert(not fingerprint_metadata_is_current(metadata_asset, changed_time))
assert(duplicate_file_stats_match(metadata_stat, metadata_stat))
assert(not duplicate_file_stats_match(metadata_stat, changed_time))
assert(duplicate_file_changed_since(metadata_stat, changed_time))
assert(not duplicate_file_changed_since(
  { size = 9004, modified = "", source = "unavailable" },
  changed_time
))
metadata_asset.fingerprint_version = "legacy"
assert(not fingerprint_metadata_is_compatible(metadata_asset))
assert(not fingerprint_metadata_is_current(metadata_asset, metadata_stat))
metadata_asset.fingerprint_version = "sample-fnv1a-head-mid-tail-v1"
reaper.JS_File_Stat = nil
assert(not fingerprint_metadata_is_current(metadata_asset, duplicate_file_stat("metadata.bin", 9004)))
clear_asset_fingerprint(metadata_asset)
assert(metadata_asset.fingerprint == "" and metadata_asset.fingerprint_size == 0)
assert(metadata_asset.fingerprint_version == "" and metadata_asset.fingerprint_modified == "")
assert(metadata_asset.fingerprint_stat_source == "")

local prefix = string.rep("A", 9000)
local left = path("left.bin")
local equal = path("equal.bin")
local different = path("different.bin")
local shorter = path("shorter.bin")
write(left, prefix .. "tail")
write(equal, prefix .. "tail")
write(different, string.rep("A", 5000) .. "B" .. string.rep("A", 3999) .. "tail")
write(shorter, prefix)

local equal_comparison = assert(begin_duplicate_comparison(left, equal))
local equal_result, equal_steps = finish(equal_comparison)
assert(equal_result == "equal" and equal_steps > 1)
assert(equal_comparison.bytes_compared == #prefix + 4)

local stat_calls = {}
reaper.JS_File_Stat = function(stat_path)
  stat_calls[stat_path] = (stat_calls[stat_path] or 0) + 1
  local modified = stat_calls[stat_path] == 1
    and "2026.09.01 09:00:00"
    or "2026.09.01 09:00:01"
  return 0, #prefix + 4, "", modified, "", 1, 0, 1, 0, 1, 0, 0
end
assert(finish(assert(begin_duplicate_comparison(left, equal))) == "failed")
reaper.JS_File_Stat = nil

assert(finish(assert(begin_duplicate_comparison(left, different))) == "different")
assert(finish(assert(begin_duplicate_comparison(left, shorter))) == "different")
local missing, missing_error = begin_duplicate_comparison(left, path("missing.bin"))
assert(not missing and missing_error == "right_open")

print("Lua duplicate comparison self-test OK")
