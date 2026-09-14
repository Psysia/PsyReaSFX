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
local packed = assert(similarity_pack_hex(encoded))
assert(#packed == Similarity.feature_count,
  "in-memory feature records must use one byte per feature")
assert(similarity_packed_hex(packed) == encoded,
  "packed feature conversion must preserve the disk encoding")
local unpacked = assert(similarity_unpack_features(packed))
for index = 1, Similarity.feature_count do
  assert(math.abs(decoded[index] - identical[index]) <= 1 / 255 + 0.000001,
    "quantized feature exceeded one-byte error bound")
  assert(unpacked[index] == decoded[index],
    "packed and hexadecimal decoding must agree")
end
local packed_score = similarity_compare_encoded(identical, packed)
local decoded_score = similarity_compare_features(identical, decoded)
assert(math.abs(packed_score - decoded_score) < 0.000001,
  "packed comparison must preserve the quantized score")

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

local ranking_session = { ranked = {} }
for index = 1, Similarity.result_limit + 75 do
  similarity_insert_ranked(
    ranking_session,
    { path = string.format("X:/rank/%04d.wav", index) },
    index % 211,
    packed
  )
end
assert(#ranking_session.ranked == Similarity.result_limit,
  "Top-K heap must remain bounded")
table.sort(ranking_session.ranked, similarity_rank_is_better)
for index = 2, #ranking_session.ranked do
  assert(not similarity_rank_is_better(
    ranking_session.ranked[index],
    ranking_session.ranked[index - 1]
  ), "Top-K heap must retain descending score/path order")
end

for sample = 1, 2000 do
  local candidate = {}
  for index = 1, Similarity.feature_count do
    candidate[index] = ((sample * (index * 17 + 11)) % 256) / 255
  end
  candidate[15] = sample % 3 == 0 and 0 or 1
  local candidate_packed = similarity_pack_features(candidate)
  local exact = similarity_compare_encoded(identical, candidate_packed)
  local upper = similarity_bucket_upper_score(
    identical,
    similarity_bucket_key(candidate_packed)
  )
  assert(upper + 0.000001 >= exact,
    "coarse bucket bound must never exclude an exact match")
end

local exact_session = { ranked = {} }
local indexed_session = { ranked = {} }
local buckets = {}
local candidates = {}
for sample = 1, 12000 do
  local candidate = {}
  for index = 1, Similarity.feature_count - 1 do
    candidate[index] = ((sample * (index * 29 + 7) + index * 13) % 256) / 255
  end
  candidate[15] = sample % 4 == 0 and 0 or 1
  local candidate_packed = similarity_pack_features(candidate)
  local asset = { path = string.format("X:/exact/%05d.wav", sample) }
  candidates[#candidates + 1] = { asset = asset, packed = candidate_packed }
  local key = similarity_bucket_key(candidate_packed)
  local bucket = buckets[key]
  if not bucket then bucket = {}; buckets[key] = bucket end
  bucket[#bucket + 1] = candidates[#candidates]
  similarity_insert_ranked(
    exact_session,
    asset,
    similarity_compare_encoded(identical, candidate_packed),
    candidate_packed
  )
end
local bucket_queue = {}
for key, bucket in pairs(buckets) do
  bucket_queue[#bucket_queue + 1] = {
    key = key,
    candidates = bucket,
    upper_score = similarity_bucket_upper_score(identical, key),
  }
end
table.sort(bucket_queue, function(left, right)
  if left.upper_score == right.upper_score then return left.key < right.key end
  return left.upper_score > right.upper_score
end)
local compared = 0
for _, bucket in ipairs(bucket_queue) do
  if #indexed_session.ranked >= Similarity.result_limit
    and bucket.upper_score + 0.000000001
      < indexed_session.ranked[1].score then
    break
  end
  for _, candidate in ipairs(bucket.candidates) do
    similarity_insert_ranked(
      indexed_session,
      candidate.asset,
      similarity_compare_encoded(identical, candidate.packed),
      candidate.packed
    )
    compared = compared + 1
  end
end
table.sort(exact_session.ranked, similarity_rank_is_better)
table.sort(indexed_session.ranked, similarity_rank_is_better)
assert(#indexed_session.ranked == #exact_session.ranked,
  "bucket search result count must match exhaustive ranking")
for index = 1, #exact_session.ranked do
  assert(indexed_session.ranked[index].sort_path
      == exact_session.ranked[index].sort_path,
    "bucket pruning must preserve the exact Top-K ordering")
end
assert(compared < #candidates,
  "bucket search must prune at least one exact comparison")

state.assets = {}
state.results = state.assets
state.similarity_cache = {}
state.similarity_cache_count = 0
state.similarity_cache_loaded = true
state.similarity_index = nil
state.similarity_warmup = nil
state.similarity_session = nil
local workflow_exact = { ranked = {} }
for index, candidate in ipairs(candidates) do
  local asset = {
    path = candidate.asset.path,
    name = string.format("candidate-%05d.wav", index),
    size = 1000 + index,
    duration = 1 + index / 1000,
    ready = true,
  }
  state.assets[index] = asset
  local signature = similarity_asset_signature(asset)
  state.similarity_cache[signature] = candidate.packed
  state.similarity_cache_count = state.similarity_cache_count + 1
  if index > 1 then
    similarity_insert_ranked(
      workflow_exact,
      asset,
      similarity_compare_encoded(
        similarity_unpack_features(candidates[1].packed),
        candidate.packed
      ),
      candidate.packed
    )
  end
end
state.results = state.assets
Jobs = {
  begin = function(kind)
    return { kind = kind, cancel_requested = false }
  end,
  cancel = function(token) token.cancel_requested = true end,
  finish = function() end,
}
function can_run_heavy_job() return true end
function set_status() end
function queue_wave() return nil end
assert(start_similarity_warmup(), "idle warmup must start")
while state.similarity_warmup do process_similarity_warmup() end
assert(similarity_cached_index_is_current(state.similarity_index),
  "idle warmup must publish a reusable full-library index")
assert(start_similarity_search(state.assets[1], "all"),
  "cached full-library similarity search must start")
process_similarity_search()
assert(state.similarity_session and state.similarity_session.index_reused,
  "full-library search must reuse the warm index")
while state.similarity_session do process_similarity_search() end
table.sort(workflow_exact.ranked, similarity_rank_is_better)
assert(state.similarity_result_count == Similarity.result_limit,
  "full workflow must publish the configured Top-K result count")
for _, entry in ipairs(workflow_exact.ranked) do
  assert(state.similarity_lookup[entry.sort_path],
    "indexed workflow must preserve every exhaustive Top-K result")
end

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
  assert(similarity_packed_hex(restored) == similarity_encode_features(identical),
    "feature cache round-trip must be exact")
  os.remove(similarity_cache_path())
end

print(string.format(
  "Lua similarity self-test passed: %d signatures, %.2f MiB payload",
  capacity,
  record_bytes * capacity / 1024 / 1024
))
