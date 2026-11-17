-- Soundminer V6/V7 overview cache adapter. This reads the observed protobuf /
-- zlib signed-8-bit extrema representation; unknown versions are not guessed.
-- No source cache is changed and no external decompressor is launched.
SoundminerWaveform = {}

local MAX_BLOB = 4 * 1024 * 1024
local MAX_CHANNELS = 8
local MAX_POINTS = 262144
local LENGTH_BASE = {3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258}
local LENGTH_EXTRA = {0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0}
local DISTANCE_BASE = {1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577}
local DISTANCE_EXTRA = {0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13}

local function checked(value, message)
  if not value then error(message, 0) end
  return value
end

local function varint(bytes, at)
  local value, shift = 0, 0
  for _ = 1, 5 do
    local byte = checked(bytes:byte(at), "truncated protobuf varint")
    at = at + 1
    value = value | ((byte & 127) << shift)
    if byte < 128 then return value, at end
    shift = shift + 7
  end
  error("oversized protobuf varint", 0)
end

local function fields(bytes, callback)
  local at, count = 1, 0
  while at <= #bytes do
    local tag; tag, at = varint(bytes, at)
    local field, wire = tag >> 3, tag & 7
    checked(field > 0 and count < 64, "unsupported protobuf fields")
    count = count + 1
    local value
    if wire == 0 then
      value, at = varint(bytes, at)
    elseif wire == 2 then
      local length; length, at = varint(bytes, at)
      checked(length <= #bytes - at + 1, "truncated protobuf value")
      value, at = bytes:sub(at, at + length - 1), at + length
    else
      error("unsupported protobuf wire type", 0)
    end
    callback(field, wire, value)
  end
end

local function huffman(lengths)
  local counts, next_code, levels = {}, {}, {}
  for _, length in ipairs(lengths) do
    checked(length >= 0 and length <= 15, "invalid Huffman code length")
    counts[length] = (counts[length] or 0) + 1
  end
  local left, code = 1, 0
  for bits = 1, 15 do
    left = left * 2 - (counts[bits] or 0)
    checked(left >= 0, "oversubscribed Huffman tree")
    code = (code + (bits == 1 and 0 or (counts[bits - 1] or 0))) * 2
    next_code[bits], levels[bits] = code, {}
  end
  for index, length in ipairs(lengths) do
    if length > 0 then
      code = next_code[length]
      levels[length][code] = index - 1
      next_code[length] = code + 1
    end
  end
  return levels
end

local fixed_literals, fixed_distances
do
  local literals, distances = {}, {}
  for symbol = 0, 287 do
    literals[symbol + 1] = symbol <= 143 and 8 or symbol <= 255 and 9 or symbol <= 279 and 7 or 8
  end
  for symbol = 0, 31 do distances[symbol + 1] = 5 end
  fixed_literals, fixed_distances = huffman(literals), huffman(distances)
end

-- RFC 1950/1951 decoder with output, back-reference and checksum validation.
-- Optional yield_work is called every 8192 output bytes for a coroutine job.
local function inflate(bytes, maximum, yield_work)
  checked(#bytes >= 6, "truncated zlib stream")
  local cmf, flg = bytes:byte(1, 2)
  checked(cmf & 15 == 8 and cmf >> 4 <= 7 and (cmf * 256 + flg) % 31 == 0,
    "unsupported zlib header")
  checked(flg & 32 == 0, "zlib preset dictionary is unsupported")
  local bit_at, bit_end = 16, (#bytes - 4) * 8
  local function bits(count)
    checked(bit_at + count <= bit_end, "truncated deflate stream")
    local value = 0
    for shift = 0, count - 1 do
      value = value | (((bytes:byte(bit_at // 8 + 1) >> (bit_at % 8)) & 1) << shift)
      bit_at = bit_at + 1
    end
    return value
  end
  local function symbol(tree)
    local code = 0
    for length = 1, 15 do
      code = code * 2 + bits(1)
      local value = tree[length][code]
      if value ~= nil then return value end
    end
    error("invalid Huffman symbol", 0)
  end
  local output, size, adler_a, adler_b = {}, 0, 1, 0
  local function emit(byte)
    checked(size < maximum, "waveform exceeds decoded size limit")
    size = size + 1
    output[size] = byte
    adler_a = (adler_a + byte) % 65521
    adler_b = (adler_b + adler_a) % 65521
    if yield_work and size % 8192 == 0 then yield_work() end
  end
  local final, blocks = false, 0
  repeat
    final = bits(1) == 1
    local kind = bits(2)
    blocks = blocks + 1
    checked(blocks <= 65536, "too many deflate blocks")
    if kind == 0 then
      bit_at = ((bit_at + 7) // 8) * 8
      local length, complement = bits(16), bits(16)
      checked(length ~ complement == 65535, "invalid stored-block length")
      checked(size + length <= maximum, "waveform exceeds decoded size limit")
      for _ = 1, length do emit(bits(8)) end
    else
      checked(kind ~= 3, "reserved deflate block type")
      local literals, distances = fixed_literals, fixed_distances
      if kind == 2 then
        local literal_count, distance_count, code_count = bits(5) + 257, bits(5) + 1, bits(4) + 4
        checked(literal_count <= 286, "invalid deflate literal count")
        local order = {16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15}
        local code_lengths = {}
        for index = 1, 19 do code_lengths[index] = 0 end
        for index = 1, code_count do code_lengths[order[index] + 1] = bits(3) end
        local code_tree, lengths = huffman(code_lengths), {}
        while #lengths < literal_count + distance_count do
          local value = symbol(code_tree)
          if value <= 15 then
            lengths[#lengths + 1] = value
          else
            local repeat_count, repeated
            if value == 16 then
              checked(#lengths > 0, "Huffman repeat has no preceding length")
              repeat_count, repeated = bits(2) + 3, lengths[#lengths]
            elseif value == 17 then repeat_count, repeated = bits(3) + 3, 0
            elseif value == 18 then repeat_count, repeated = bits(7) + 11, 0
            else error("invalid Huffman repeat", 0) end
            checked(#lengths + repeat_count <= literal_count + distance_count, "Huffman repeat overrun")
            for _ = 1, repeat_count do lengths[#lengths + 1] = repeated end
          end
        end
        checked(lengths[257] > 0, "deflate end marker is missing")
        local literal_lengths, distance_lengths = {}, {}
        for index = 1, literal_count do literal_lengths[index] = lengths[index] end
        for index = 1, distance_count do distance_lengths[index] = lengths[literal_count + index] end
        literals, distances = huffman(literal_lengths), huffman(distance_lengths)
      end
      while true do
        local value = symbol(literals)
        if value < 256 then emit(value)
        elseif value == 256 then break
        else
          checked(value <= 285, "reserved deflate length symbol")
          local length = LENGTH_BASE[value - 256] + bits(LENGTH_EXTRA[value - 256])
          local distance_symbol = symbol(distances)
          checked(distance_symbol < 30, "reserved deflate distance symbol")
          local distance = DISTANCE_BASE[distance_symbol + 1] + bits(DISTANCE_EXTRA[distance_symbol + 1])
          checked(distance <= size and distance <= (1 << ((cmf >> 4) + 8)), "invalid deflate back-reference")
          checked(size + length <= maximum, "waveform exceeds decoded size limit")
          for _ = 1, length do emit(output[size - distance + 1]) end
        end
      end
    end
    if yield_work then yield_work() end
  until final
  checked((bit_at + 7) // 8 == #bytes - 4, "trailing zlib bytes")
  local expected = string.unpack(">I4", bytes, #bytes - 3)
  checked((adler_b << 16) | adler_a == expected, "zlib checksum mismatch")
  return output, size
end

local function path_identity(path)
  -- Compare the original Soundminer path, before any user-selected relocation.
  -- Windows paths are case insensitive; POSIX paths deliberately are not.
  path = path:gsub("\\", "/")
  if path:match("^%a:/") or path:sub(1, 2) == "//" then path = path:lower() end
  return path
end

local function decode(blob, expected_path, channels, duration, sample_rate, total_frames, yield_work)
  checked(type(blob) == "string" and #blob > 0 and #blob <= MAX_BLOB, "invalid overview blob size")
  checked(type(expected_path) == "string" and #expected_path > 0, "original cache path is required")
  checked(type(channels) == "number" and channels % 1 == 0 and channels >= 1 and channels <= MAX_CHANNELS,
    "unsupported waveform channel count")
  local source_path, compressed, actual_channels = nil, {}, 0
  fields(blob, function(field, wire, value)
    if field == 1 and wire == 2 then
      checked(source_path == nil, "duplicate overview path")
      source_path = value
    elseif field == 2 and wire == 2 then
      local channel, payload, version
      fields(value, function(subfield, subwire, subvalue)
        if subfield == 1 and subwire == 0 and channel == nil then channel = subvalue
        elseif subfield == 2 and subwire == 2 and payload == nil then payload = subvalue
        elseif subfield == 3 and subwire == 0 and version == nil then version = subvalue
        else error("unsupported channel fields", 0) end
      end)
      checked(channel and channel < channels and payload and version == 1 and not compressed[channel + 1],
        "unsupported or duplicate waveform channel")
      compressed[channel + 1], actual_channels = payload, actual_channels + 1
    else error("unsupported overview fields", 0) end
  end)
  checked(source_path and path_identity(source_path) == path_identity(expected_path), "overview path mismatch")
  checked(actual_channels == channels, "incomplete waveform channels")
  local frame_count = tonumber(total_frames)
  if not frame_count and tonumber(duration) and tonumber(sample_rate) then
    frame_count = math.floor(duration * sample_rate + 0.5)
  end
  if frame_count then
    checked(frame_count == frame_count and frame_count > 0 and frame_count < math.huge and frame_count % 1 == 0,
      "invalid waveform duration")
  end
  local expected_points = frame_count and (frame_count // 512 + 1) or nil
  checked(not expected_points or expected_points <= MAX_POINTS, "waveform exceeds point limit")
  local wave = { channels = channels, peaks = {}, channel_peaks = {} }
  for channel = 1, channels do
    local bytes, size = inflate(compressed[channel], expected_points and expected_points * 2 or MAX_POINTS * 2, yield_work)
    checked(size > 0 and size % 2 == 0, "invalid signed-extrema payload length")
    local count = size // 2
    checked(not expected_points or count == expected_points, "overview duration mismatch")
    checked(not wave.count or count == wave.count, "unequal waveform channel lengths")
    wave.count = count
    local peaks = {}
    for index = 1, count do
      local high, low = bytes[index * 2 - 1], bytes[index * 2]
      high, low = high < 128 and high or high - 256, low < 128 and low or low - 256
      checked(high >= low, "invalid signed extrema order")
      local peak = math.min(1, math.max(math.abs(high), math.abs(low)) / 127)
      peaks[index] = peak
      wave.peaks[index] = math.max(wave.peaks[index] or 0, peak)
      if yield_work and index % 4096 == 0 then yield_work() end
    end
    wave.channel_peaks[channel] = peaks
  end
  return wave
end

function SoundminerWaveform.decode(blob, expected_path, channels, duration, sample_rate, total_frames, yield_work)
  local ok, wave = pcall(decode, blob, expected_path, channels, duration, sample_rate, total_frames, yield_work)
  if not ok then return nil, tostring(wave) end
  return wave
end

-- Conservatively includes every overlapping source bucket, preserving short
-- transients when reducing resolution. Enlarging never invents extra detail.
function SoundminerWaveform.resample(wave, points, yield_work)
  if type(wave) ~= "table" or type(wave.count) ~= "number" or wave.count < 1
    or type(points) ~= "number" or points % 1 ~= 0 or points < 1 or points > 4096 then
    return nil, "invalid waveform resample request"
  end
  local result = { count = points, channels = wave.channels, peaks = {}, channel_peaks = {} }
  local operations = 0
  for channel = 1, wave.channels do result.channel_peaks[channel] = {} end
  for index = 1, points do
    local first = math.floor((index - 1) * wave.count / points) + 1
    local last = math.min(wave.count, math.ceil(index * wave.count / points))
    local aggregate = 0
    for channel = 1, wave.channels do
      local maximum = 0
      for source_index = first, last do
        maximum = math.max(maximum, wave.channel_peaks[channel][source_index])
        operations = operations + 1
        if yield_work and operations % 4096 == 0 then yield_work() end
      end
      result.channel_peaks[channel][index] = maximum
      aggregate = math.max(aggregate, maximum)
    end
    result.peaks[index] = aggregate
  end
  return result
end
