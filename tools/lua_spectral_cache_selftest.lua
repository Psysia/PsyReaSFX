local source_path = assert(arg[1], "usage: lua_spectral_cache_selftest.lua <runtime-ui-source>")
local handle = assert(io.open(source_path, "rb"))
local source = handle:read("*a")
handle:close()

local start_at = assert(source:find("function wave_cache_key(", 1, true))
local end_at = assert(source:find("function read_waveform_from_source(", start_at, true))
local cache_source = source:sub(start_at, end_at - 1)
local verify_start = assert(source:find("function validate_wave_cache_file(", end_at, true))
local verify_end = assert(source:find("function start_wave_cache_verification(", verify_start, true))
local verify_source = source:sub(verify_start, verify_end - 1)

function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

function path_key(path) return tostring(path):lower() end
function asset_path_sort_key(asset) return path_key(asset.path) end
function file_size() return 0 end
function ensure_dirs() end
function fnv1a(value)
  return "spectral_cache_selftest_" .. (value:find("spectral%-rwf4") and "v4" or "v3")
end
function join_path(parent, child)
  return parent .. package.config:sub(1, 1) .. child
end

LARGE_WAVE_MAX_POINTS = 4096
WAVE_CACHE_DIR = os.getenv("TEMP") or os.getenv("TMP") or "."

assert(load(cache_source, "spectral-cache-runtime", "t", _ENV))()
assert(load(verify_source, "spectral-cache-verifier", "t", _ENV))()

local asset = { path = "spectral-selftest.wav", size = 123 }
local waveform = {
  count = 2,
  channels = 2,
  peaks = { 0.5, 0.75 },
  channel_peaks = {
    { 0.25, 0.5 },
    { 0.5, 0.75 },
  },
  spectral_available = true,
  spectral_frequency = { 440, 12000 },
  spectral_tonality = { 0.25, 0.75 },
}

save_wave_to_disk(asset, 2048, waveform, true, true)
local cache_path = wave_cache_path(asset, 2048, true, true)
local valid, validation_error = validate_wave_cache_file(cache_path)
assert(valid, "RWF4 cache must pass integrity verification: " .. tostring(validation_error))
local loaded = assert(load_wave_from_disk(asset, 2048, true, true))
assert(loaded.count == 2 and loaded.channels == 2, "RWF4 dimensions must round-trip")
assert(loaded.spectral_available, "RWF4 spectral flag must round-trip")
assert(loaded.spectral_frequency[1] == 440, "RWF4 frequency must round-trip")
assert(loaded.spectral_frequency[2] == 12000, "RWF4 high frequency must round-trip")
assert(math.abs(loaded.spectral_tonality[1] - 0.25) < 0.00002, "RWF4 tonality must round-trip")
assert(math.abs(loaded.channel_peaks[2][2] - 0.75) < 0.00002, "RWF4 channel peaks must round-trip")

os.remove(cache_path)
-- wave_cache_file_exists() must agree with load_wave_from_disk() for valid,
-- truncated and malformed cache files while reading only the payload length.
do
  local exists_start = assert(source:find("function wave_cache_file_exists(", 1, true))
  local exists_end = assert(source:find("function start_wave_precache(", exists_start, true))
  assert(load(source:sub(exists_start, exists_end - 1), "wave-exists", "t", _ENV))()

  local probe_asset = { path = "exists-selftest.wav", size = 456 }
  local probe_wave = {
    count = 4, channels = 2, peaks = { 0.1, 0.2, 0.3, 0.4 },
    channel_peaks = { { 0.1, 0.2, 0.3, 0.4 }, { 0.4, 0.3, 0.2, 0.1 } },
  }
  local probe_path = wave_cache_path(probe_asset, 2048, true)
  os.remove(probe_path)
  assert(wave_cache_file_exists(probe_asset, 2048, true) == false)

  save_wave_to_disk(probe_asset, 2048, probe_wave, true)
  local valid_file = assert(io.open(probe_path, "rb"))
  local valid_bytes = valid_file:read("*a")
  valid_file:close()

  local variants = {
    valid_bytes,
    valid_bytes:sub(1, #valid_bytes - 1),
    valid_bytes:sub(1, valid_bytes:find("\n", 1, true)),
    "garbage header\n" .. string.rep("x", 40),
    "RWF3 0 2\n",
    "RWF3 4 2\n" .. string.rep("\1", 16),
    "RWF3 4 2\n" .. string.rep("\1", 15),
    "RWF4 4 1\n" .. string.rep("\1", 8 + 16),
    "RWF4 4 1\n" .. string.rep("\1", 8 + 15),
    "RWF2 3\n" .. string.rep("\1", 6),
    "RWF2 3\n" .. string.rep("\1", 5),
    "3\n" .. string.rep("\1", 3),
    "3\n" .. string.rep("\1", 2),
    "9999999\n" .. string.rep("\1", 64),
    "",
  }
  for index, content in ipairs(variants) do
    local handle = assert(io.open(probe_path, "wb"))
    handle:write(content)
    handle:close()
    assert(wave_cache_file_exists(probe_asset, 2048, true)
      == (load_wave_from_disk(probe_asset, 2048, true) ~= nil),
      "existence check disagrees with the loader for variant " .. index)
  end
  os.remove(probe_path)
end

print("Lua spectral cache self-test passed")
