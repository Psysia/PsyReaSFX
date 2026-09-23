local source_path = assert(arg[1], "usage: lua_waveform_selftest.lua <runtime-ui-source>")
local handle = assert(io.open(source_path, "rb"))
local source = handle:read("*a")
handle:close()

local start_at = assert(source:find("local DIRECT_WAVE_MAX_FRAMES_PER_POINT", 1, true))
local end_at = assert(source:find("function memory_wave_key(", start_at, true))
local wave_source = source:sub(start_at, end_at - 1)

local peak_calls = 0
local creates = 0
local reopens = 0
local destroys = 0
local build_modes = {}
local always_empty = false
local spectral_mode = false
local direct_fixture_path = os.tmpname() .. ".wav"
local direct_alias_path = "C:\\" .. string.rep("long-folder\\", 25) .. "fixture.wav"

function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end
function extension(path)
  return ((path or ""):match("%.([^%.]+)$") or ""):lower()
end
function open_source_binary_file(path)
  if path == direct_alias_path then path = direct_fixture_path end
  local file, reason = io.open(path, "rb")
  if file then return file end
  if path:match("^%a:\\") then
    local extended, extended_reason = io.open("\\\\?\\" .. path, "rb")
    if extended then return extended end
    reason = extended_reason or reason
  end
  return nil, reason
end

LARGE_WAVE_MAX_POINTS = 4096
WAVE_READ_RETRY_LIMIT = 6
WAVE_READ_REOPEN_ATTEMPT = 3
WAVE_READ_REOPEN_LIMIT = 1

reaper = {
  GetOS = function() return "Win64" end,
  file_exists = function() return true end,
  PCM_Source_CreateFromFile = function()
    creates = creates + 1
    return { kind = "initial" }
  end,
  PCM_Source_CreateFromFileEx = function()
    reopens = reopens + 1
    return { kind = "reopened" }
  end,
  PCM_Source_Destroy = function()
    destroys = destroys + 1
  end,
  GetMediaSourceLength = function() return 1, false end,
  GetMediaSourceNumChannels = function() return 1 end,
  PCM_Source_BuildPeaks = function(_, mode)
    build_modes[#build_modes + 1] = mode
    return 0
  end,
  new_array = function(size)
    local array = { values = {} }
    array.table = function(first, count)
      local values = {}
      for index = 1, count do
        values[index] = array.values[first + index - 1] or 0
      end
      return values
    end
    for index = 1, size do array.values[index] = 0 end
    return array
  end,
  PCM_Source_GetPeaks = function(_, _, _, channels, points, extra_type, buffer)
    peak_calls = peak_calls + 1
    if always_empty or peak_calls <= 3 then return 0 end
    local returned = math.min(points, 32)
    if spectral_mode and extra_type == 115 then
      local block = returned * channels
      local packed = 440 | (8192 << 15)
      for index = 1, returned do
        buffer.values[index] = 0.5
        buffer.values[block + index] = -0.5
        buffer.values[block * 2 + index] = packed
      end
      return returned | 0x1000000
    end
    return returned
  end,
}

assert(load(wave_source, "waveform-runtime", "t", _ENV))()

do
  local frames = {}
  for index = 1, 256 do
    local left = index % 2 == 0 and 16384 or -16384
    local right = index % 4 == 0 and 8192 or -8192
    frames[#frames + 1] = string.pack("<i2i2", left, right)
  end
  local data = table.concat(frames)
  local format = string.pack("<I2I2I4I4I2I2", 1, 2, 48000, 192000, 4, 16)
  local fixture = assert(io.open(direct_fixture_path, "wb"))
  fixture:write(
    "RIFF",
    string.pack("<I4", 4 + 8 + #format + 8 + #data),
    "WAVEfmt ",
    string.pack("<I4", #format),
    format,
    "data",
    string.pack("<I4", #data),
    data
  )
  fixture:close()
end

local function run(job, maximum_steps)
  for _ = 1, maximum_steps do
    local status, waveform, reason = step_wave_job(job)
    if status ~= "working" then return status, waveform, reason end
  end
  error("wave job did not terminate")
end

local direct_job = {
  asset = { path = direct_alias_path },
  points = 128,
  preserve_channels = true,
}
local first_direct_status = step_wave_job(direct_job)
assert(first_direct_status == "working" and direct_job.progress > 0,
  "direct long-path WAV fallback must yield between bounded point batches")
local direct_status, direct_wave = run(direct_job, 2)
assert(direct_status == "done", "long-path PCM WAV must use direct waveform fallback")
assert(direct_wave.count == 128 and direct_wave.channels == 2)
assert(direct_wave.channel_peaks and #direct_wave.channel_peaks == 2)
assert(math.abs(direct_wave.peaks[1] - 0.5) < 0.0001)
assert(creates == 0 and peak_calls == 0,
  "direct long-path WAV fallback must not enter the REAPER peak API")

local real_long_wave = os.getenv("PSYREASFX_LONG_WAV_FIXTURE")
if real_long_wave and real_long_wave ~= "" then
  local real_points = tonumber(os.getenv("PSYREASFX_LONG_WAV_POINTS")) or 256
  local started = os.clock()
  local real_wave, real_reason = read_waveform_from_pcm_wave(real_long_wave, real_points, true)
  assert(real_wave, tostring(real_reason))
  assert(real_wave.count == real_points and real_wave.channels >= 1)
  print(string.format(
    "Real long-path WAV fallback: %d points, %d channels in %.3fs",
    real_wave.count,
    real_wave.channels,
    os.clock() - started
  ))
end

local status, waveform = run({
  asset = { path = "transient.wav" },
  points = 256,
}, 30)
assert(status == "done" and waveform and waveform.count == 32, "transient empty peaks must recover")
assert(creates == 1 and reopens == 1, "third empty read must reopen the media source once")
assert(peak_calls == 4 and destroys == 2, "wave source lifecycle is unbalanced after recovery")
assert(build_modes[1] == 0 and build_modes[2] == 1 and build_modes[3] == 2,
  "peak building must always execute Init, Run and Finish even when Init returns zero")

peak_calls, creates, reopens, destroys = 0, 0, 0, 0
build_modes = {}
always_empty = true
local failed, _, reason = run({
  asset = { path = "empty.wav" },
  points = 256,
}, 40)
assert(failed == "failed", "permanently empty peaks must fail after a bounded retry")
assert(reason:find("已重试 6 次", 1, true), "bounded failure must report its retry count")
assert(creates == 1 and reopens == 1 and destroys == 2, "failed retry must release both media sources")

peak_calls, creates, reopens, destroys = 3, 0, 0, 0
always_empty = false
spectral_mode = true
local spectral_status, spectral_wave = run({
  asset = { path = "spectral.wav" },
  points = 256,
  preserve_channels = true,
  spectral = true,
}, 10)
assert(spectral_status == "done", "spectral peak read must complete")
assert(spectral_wave.spectral_available, "spectral capability flag must be retained")
assert(spectral_wave.spectral_frequency[1] == 440, "packed frequency must decode")
assert(
  math.abs(spectral_wave.spectral_tonality[1] - 8192 / 16383) < 0.000001,
  "packed tonality must decode"
)
assert(spectral_wave.peaks[1] == 0.5, "spectral read must retain amplitude peaks")

print("Lua waveform self-test passed")
os.remove(direct_fixture_path)
