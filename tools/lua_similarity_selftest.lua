local source_path = assert(arg[1], "usage: lua_similarity_selftest.lua <similarity-source> [capacity]")
local capacity = tonumber(arg[2]) or 500000
local cache_directory = arg[3]

function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

function path_key(path) return tostring(path or ""):lower() end
function file_size() return 0 end
function fnv1a(text)
  local hash = 2166136261
  for index = 1, #text do
    hash = ((hash ~ text:byte(index)) * 16777619) & 0xFFFFFFFF
  end
  return string.format("%08x", hash)
end

state = { language = "zh" }
DATA_DIR = cache_directory or "."
SEP = package.config:sub(1, 1)
function ensure_dirs() end
HostApi = {
  time_precise = os.clock,
  file_exists = function(path)
    local file = io.open(path, "rb")
    if file then file:close(); return true end
    return false
  end,
}
AppState = {
  set = function(name, value) state[name] = value; return value end,
  apply = function(values)
    for name, value in pairs(values) do state[name] = value end
  end,
}
assert(loadfile(source_path, "t", _ENV))()

local reference_asset = {
  path = "Reference Boom.wav",
  name = "Reference Boom.wav",
  size = 1024,
  duration = 2.5,
}
local other_name_asset = {
  path = "Completely Different Filename.wav",
  name = "Completely Different Filename.wav",
  size = 2048,
  duration = 2.5,
}
local waveform = {
  count = 8,
  peaks = { 0, 0.1, 0.8, 0.4, 0.2, 0.1, 0.02, 0 },
  spectral_available = true,
  spectral_frequency = { 60, 80, 500, 800, 1600, 3000, 6000, 8000 },
  spectral_tonality = { 0.1, 0.2, 0.8, 0.7, 0.6, 0.4, 0.2, 0.1 },
}
local identical = assert(similarity_features_from_waveform(reference_asset, waveform))
local different_name = assert(similarity_features_from_waveform(other_name_asset, waveform))
local identical_score = similarity_compare_features(identical, different_name)
assert(math.abs(identical_score - 100) < 0.0001,
  "filenames must not affect audio-content similarity")

local encoded = similarity_encode_features(identical)
assert(#encoded == Similarity.feature_count * 2, "feature cache must remain fixed width")
local decoded = assert(similarity_decode_features(encoded))
for index = 1, Similarity.feature_count do
  assert(math.abs(decoded[index] - identical[index]) <= 1 / 255 + 0.000001,
    "quantized feature exceeded one-byte error bound")
end

local contrasting_waveform = {
  count = 8,
  peaks = { 0.8, 0.05, 0, 0, 0, 0, 0, 0 },
  spectral_available = true,
  spectral_frequency = { 12000, 14000, 16000, 18000, 18000, 18000, 18000, 18000 },
  spectral_tonality = { 0, 0, 0, 0, 0, 0, 0, 0 },
}
local contrasting = assert(similarity_features_from_waveform({ duration = 30 }, contrasting_waveform))
local contrasting_score = similarity_compare_features(identical, contrasting)
assert(contrasting_score < identical_score - 15,
  "duration, envelope, onset and spectrum must change ranking")

local signatures = {}
for index = 1, capacity do
  local signature = similarity_asset_signature({
    path = "X:/Synthetic/asset-" .. tostring(index) .. ".wav",
    size = 1000 + index,
    duration = (index % 6000) / 10,
  })
  assert(#signature == 16, "cache signature must use two 32-bit hashes")
  assert(not signatures[signature], "double-hash collision in capacity fixture")
  signatures[signature] = true
end

local record_bytes = 16 + 1 + Similarity.feature_count * 2 + 1
assert(record_bytes * capacity <= 25 * 1024 * 1024,
  "500k compact feature records must stay within the 25 MiB payload budget")

if cache_directory then
  state.similarity_cache = {}
  state.similarity_cache_count = 0
  state.similarity_cache_loaded = true
  state.similarity_cache_reset_required = false
  local signature = similarity_asset_signature(reference_asset)
  local write_session = {}
  assert(similarity_cache_store(write_session, signature, identical),
    "feature record must append")
  similarity_close_files(write_session)

  state.similarity_cache = {}
  state.similarity_cache_count = 0
  state.similarity_cache_loaded = false
  local read_session = { phase = "prepare" }
  similarity_cache_begin_load(read_session)
  while read_session.phase == "load_cache" do
    similarity_cache_step_load(read_session)
  end
  local restored = assert(state.similarity_cache[signature],
    "feature record must reload")
  assert(restored == similarity_encode_features(identical),
    "feature cache round-trip must be exact")
  os.remove(similarity_cache_path())
end

print(string.format(
  "Lua similarity self-test passed: %d signatures, %.2f MiB payload",
  capacity,
  record_bytes * capacity / 1024 / 1024
))
