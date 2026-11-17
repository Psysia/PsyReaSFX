-- Synthesized protobuf/zlib fixtures only; no user cache or audio is included.
dofile(arg[1] or "src/lua/28_soundminer_waveform.lua")
local function hex(value)
  return (value:gsub("..", function(pair) return string.char(tonumber(pair, 16)) end))
end
local function varint(value)
  local bytes = {}
  repeat
    local byte = value & 127
    value = value >> 7
    bytes[#bytes + 1] = string.char(byte | (value > 0 and 128 or 0))
  until value == 0
  return table.concat(bytes)
end
local function text_field(field, value) return varint(field * 8 + 2) .. varint(#value) .. value end
local function number_field(field, value) return varint(field * 8) .. varint(value) end
local source_path = "/synthetic/overview.wav"
local function channel(index, payload, version)
  return text_field(2, number_field(1, index) .. text_field(2, payload) .. number_field(3, version or 1))
end
local function blob(payload, path)
  return text_field(1, path or source_path) .. channel(0, payload)
end
local function stored(raw)
  local a, b = 1, 0
  for index = 1, #raw do a = (a + raw:byte(index)) % 65521; b = (b + a) % 65521 end
  return "\120\1\1" .. string.pack("<I2I2", #raw, 65535 - #raw) .. raw .. string.pack(">I4", (b << 16) | a)
end
local raw = string.char(64,192,127,129,0,0,2,255)
local wave = assert(SoundminerWaveform.decode(blob(stored(raw)), source_path, 1))
assert(wave.count == 4 and wave.channels == 1)
assert(wave.peaks[1] == 64 / 127 and wave.peaks[2] == 1 and wave.peaks[3] == 0)
assert(wave.peaks[4] == 2 / 127 and wave.channel_peaks[1][2] == 1)

local dynamic = hex("789cedc5410d00300804303265e76c99b339031d24eda7f9f7559d8e6ddbb66ddbb66ddbb66ddbeead0f5cce04b5")
local fixed = hex("7801733850dfc8c0c0f4df61941ea547e9517a941ea547e9517a941ea547e9517a941ea547e9517a941ea547e9517a941ea547e9517a941ea547e9517a941ea547e9ff439506005cce04b5")
for _, compressed in ipairs({ dynamic, fixed }) do
  local calls = 0
  local result = assert(SoundminerWaveform.decode(blob(compressed), source_path, 1, nil, nil, nil,
    function() calls = calls + 1 end))
  assert(result.count == 4096 and calls >= 2)
  for index = 1, result.count do assert(result.peaks[index] == wave.peaks[(index - 1) % 4 + 1]) end
end

local stereo = text_field(1, source_path) .. channel(1, stored(string.char(1,255,2,254,3,253,4,252)))
  .. channel(0, stored(raw))
local result = assert(SoundminerWaveform.decode(stereo, source_path, 2, 1536 / 48000, 48000))
assert(result.count == 4 and result.channel_peaks[2][4] == 4 / 127)
assert(result.peaks[3] == 3 / 127)
local small = assert(SoundminerWaveform.resample(result, 2))
assert(small.count == 2 and small.peaks[1] == 1 and small.peaks[2] == 4 / 127)
assert(small.channel_peaks[2][1] == 2 / 127)
local large = assert(SoundminerWaveform.resample(result, 8))
assert(large.peaks[1] == large.peaks[2] and large.peaks[3] == 1 and large.peaks[4] == 1)
local windows_path = "C:\\Synthetic\\Overview.wav"
assert(SoundminerWaveform.decode(blob(stored(raw), windows_path), "c:/synthetic/overview.wav", 1))

local function rejects(bytes, path, channels, duration, rate, frames)
  local value, reason = SoundminerWaveform.decode(bytes, path or source_path, channels or 1, duration, rate, frames)
  assert(not value and type(reason) == "string" and #reason > 0, "expected malformed cache rejection")
end
rejects(blob(stored(raw)), "/different/path.wav")
rejects(blob(stored(raw)), "/SYNTHETIC/overview.wav")
rejects(blob(stored(raw)), nil, 2)
rejects(stereo, nil, 1)
rejects(stereo .. channel(0, stored(raw)), nil, 2)
rejects(text_field(1, source_path) .. channel(0, stored(raw), 2))
rejects(blob(stored(raw)) .. text_field(3, "future"))
rejects(blob(stored(raw)), nil, nil, 1, 48000)
rejects(blob(stored(raw)), nil, nil, nil, nil, 0)
rejects(blob(stored(raw)), nil, nil, nil, nil, 512 * 262145)
rejects(blob(stored(string.char(0,1)))) -- maximum < minimum
rejects(blob(stored("\1"))) -- half an extrema pair
rejects(blob(stored(raw):sub(1, -2))) -- checksum truncated
rejects(blob(stored(raw):sub(1, -2) .. "\0")) -- incorrect checksum
rejects(blob(stored(raw) .. "\0")) -- trailing bytes
rejects(blob(dynamic:sub(1, 4)))
rejects(blob("\120\1\7\0\0\0\0")) -- reserved block type
rejects(blob("\120\1\3\2\0\0\0\0")) -- impossible distance / checksum
rejects("\10\127short")
rejects("\0\0")
rejects(text_field(1, source_path) .. channel(0, dynamic), nil, nil, nil, nil, 512) -- output cap
assert(not SoundminerWaveform.resample(result, 0))
assert(not SoundminerWaveform.resample(result, 4097))

-- Yielding through the decode pcall works on the host's Lua 5.3+ runtime.
local co = coroutine.create(function()
  return assert(SoundminerWaveform.decode(blob(dynamic), source_path, 1, nil, nil, nil, coroutine.yield))
end)
local resumes, decoded = 0, nil
repeat
  local ok, value = coroutine.resume(co)
  assert(ok, value)
  decoded, resumes = value or decoded, resumes + 1
until coroutine.status(co) == "dead"
assert(resumes >= 3 and decoded.count == 4096)
local resampling = coroutine.create(function()
  return assert(SoundminerWaveform.resample(decoded, 256, coroutine.yield))
end)
local resamples, thumbnail = 0, nil
repeat
  local ok, value = coroutine.resume(resampling)
  assert(ok, value)
  thumbnail, resamples = value or thumbnail, resamples + 1
until coroutine.status(resampling) == "dead"
assert(resamples >= 2 and thumbnail.count == 256)
for _, peak in ipairs(thumbnail.peaks) do assert(peak == 1) end
print("Soundminer waveform regression passed (stored/fixed/dynamic, channels, identity, bounds, checksum, yielding)")
