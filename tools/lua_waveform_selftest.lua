local source_path = assert(arg[1], "usage: lua_waveform_selftest.lua <runtime-ui-source>")
local handle = assert(io.open(source_path, "rb"))
local source = handle:read("*a")
handle:close()

local start_at = assert(source:find("function read_waveform_from_source(", 1, true))
local end_at = assert(source:find("function memory_wave_key(", start_at, true))
local wave_source = source:sub(start_at, end_at - 1)

local peak_calls = 0
local creates = 0
local reopens = 0
local destroys = 0
local always_empty = false
local spectral_mode = false

function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

LARGE_WAVE_MAX_POINTS = 4096
WAVE_READ_RETRY_LIMIT = 6
WAVE_READ_REOPEN_ATTEMPT = 3
WAVE_READ_REOPEN_LIMIT = 1

reaper = {
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
  PCM_Source_BuildPeaks = function() return 0 end,
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

local function run(job, maximum_steps)
  for _ = 1, maximum_steps do
    local status, waveform, reason = step_wave_job(job)
    if status ~= "working" then return status, waveform, reason end
  end
  error("wave job did not terminate")
end

local status, waveform = run({
  asset = { path = "transient.wav" },
  points = 256,
}, 30)
assert(status == "done" and waveform and waveform.count == 32, "transient empty peaks must recover")
assert(creates == 1 and reopens == 1, "third empty read must reopen the media source once")
assert(peak_calls == 4 and destroys == 2, "wave source lifecycle is unbalanced after recovery")

peak_calls, creates, reopens, destroys = 0, 0, 0, 0
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
