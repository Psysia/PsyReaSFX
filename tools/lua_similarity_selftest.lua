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

-- Differential tests: previous implementations versus the optimized ones.
do
  local seed = 987654321
  local function random(limit)
    seed = (seed * 1103515245 + 12345) & 0x7fffffff
    return seed % limit
  end
  local feature_count = Similarity.feature_count

  local function old_pack_hex(text)
    text = tostring(text or "")
    if #text ~= feature_count * 2 or text:find("[^0-9a-fA-F]") then
      return nil
    end
    local out = {}
    for index = 1, feature_count do
      out[index] = string.char(
        tonumber(text:sub(index * 2 - 1, index * 2), 16) or 0
      )
    end
    return table.concat(out)
  end
  local function old_decode(text)
    text = tostring(text or "")
    if #text ~= feature_count * 2 or text:find("[^0-9a-fA-F]") then
      return nil
    end
    local out = {}
    for index = 1, feature_count do
      out[index] = (tonumber(text:sub(index * 2 - 1, index * 2), 16) or 0) / 255
    end
    return out
  end
  local function old_bucket_key(candidate)
    local spectral = similarity_candidate_feature(candidate, 15) >= 0.5
    local parts = { string.char(spectral and 1 or 0) }
    for _, feature_index in ipairs(Similarity.bucket_features) do
      parts[#parts + 1] = string.char(similarity_bucket_axis(candidate, feature_index))
    end
    return table.concat(parts)
  end
  local alphabet = "0123456789abcdefABCDEF"
  local function random_hex(length)
    local chars = {}
    for index = 1, length do
      local pick = random(#alphabet) + 1
      chars[index] = alphabet:sub(pick, pick)
    end
    return table.concat(chars)
  end

  -- Hex decode: valid (mixed case), wrong length, one bad character anywhere.
  local invalid_chars = { "g", "G", "z", " ", "-", "+", "\n", "\0", "/", ":", "@", "`", "x" }
  for _ = 1, 4000 do
    local text = random_hex(feature_count * 2)
    assert(similarity_pack_hex(text) == old_pack_hex(text))
    local a, b = similarity_decode_features(text), old_decode(text)
    for index = 1, feature_count do assert(a[index] == b[index]) end
    local bad = text
    local position = random(#bad) + 1
    bad = bad:sub(1, position - 1) .. invalid_chars[random(#invalid_chars) + 1]
      .. bad:sub(position + 1)
    assert(similarity_pack_hex(bad) == nil and old_pack_hex(bad) == nil)
    assert(similarity_decode_features(bad) == nil)
    local short = random_hex(random(feature_count * 2 + 6))
    assert(similarity_pack_hex(short) == old_pack_hex(short))
  end
  assert(similarity_pack_hex(nil) == nil and similarity_pack_hex("") == nil)
  assert(similarity_pack_hex(string.rep("0", 29) .. "\0") == nil)
  assert(similarity_pack_hex(string.rep("fF", 15)) == string.rep("\255", 15))

  -- Bucket keys: packed bytes, hex strings and plain feature tables.
  for sample = 1, 6000 do
    local candidate
    local kind = sample % 3
    if kind == 0 then
      local bytes = {}
      for index = 1, feature_count do bytes[index] = string.char(random(256)) end
      candidate = table.concat(bytes)
    elseif kind == 1 then
      candidate = random_hex(feature_count * 2)
    else
      candidate = {}
      for index = 1, feature_count do candidate[index] = random(1001) / 1000 end
    end
    assert(similarity_bucket_key(candidate) == old_bucket_key(candidate),
      "bucket key must match the generic implementation")
  end
  for value = 0, 255 do
    local bytes = {}
    for index = 1, feature_count do bytes[index] = string.char(value) end
    local candidate = table.concat(bytes)
    assert(similarity_bucket_key(candidate) == old_bucket_key(candidate))
  end

  -- Ranking heap: identical retained entries and identical return values.
  local function old_insert(session, asset, score, features)
    local entry = {
      asset = asset, score = score, features = features,
      sort_path = path_key(asset.path),
    }
    if #session.ranked < Similarity.result_limit then
      session.ranked[#session.ranked + 1] = entry
      similarity_heap_sift_up(session.ranked, #session.ranked)
      return entry
    elseif similarity_rank_is_better(entry, session.ranked[1]) then
      session.ranked[1] = entry
      similarity_heap_sift_down(session.ranked, 1)
      return entry
    end
    return nil
  end
  local old_session, new_session = { ranked = {} }, { ranked = {} }
  for sample = 1, 6000 do
    -- Few distinct scores and paths force many ties on score and on path.
    local asset = { path = string.format("X:/Tie/%03d.WAV", random(400)) }
    local score = random(40) / 4
    local old_entry = old_insert(old_session, asset, score, "f")
    local may_enter = similarity_rank_may_enter(new_session.ranked, score)
    local new_entry = similarity_insert_ranked(new_session, asset, score, "f")
    assert((old_entry ~= nil) == (new_entry ~= nil),
      "retention decision must match at sample " .. sample)
    if old_entry then assert(may_enter) end
    if not may_enter then assert(new_entry == nil) end
    assert(#old_session.ranked == #new_session.ranked)
    if sample % 97 == 0 or sample == 6000 then
      for index = 1, #old_session.ranked do
        local left, right = old_session.ranked[index], new_session.ranked[index]
        assert(left.score == right.score and left.sort_path == right.sort_path
          and left.asset == right.asset, "heap layout must match")
      end
    end
  end
  -- A caller-supplied sort_path is used verbatim; asset path is not needed.
  local supplied = { ranked = {} }
  local entry = similarity_insert_ranked(supplied, {}, 5, "f", "supplied-key")
  assert(entry.sort_path == "supplied-key")

  -- Signature: raw-field cache validation versus rebuilt identity string.
  local function old_signature(asset)
    local size = tonumber(asset.size) or 0
    local identity_key = table.concat({
      path_key(asset.path), tostring(size),
      string.format("%.6f", tonumber(asset.duration) or 0),
    }, "|")
    local identity = identity_key .. "|sim-v1"
    return fnv1a(identity .. "|a") .. fnv1a("b|" .. identity)
  end
  for sample = 1, 3000 do
    local asset = {
      path = string.format("X:/Sig/%d/Name %d.wav", random(50), random(1000)),
      size = 1 + random(100000),
      duration = random(100000) / 100,
    }
    assert(similarity_asset_signature(asset) == old_signature(asset))
    assert(similarity_asset_signature(asset) == old_signature(asset),
      "cached signature must stay valid")
    local before = asset.similarity_signature
    asset.size = asset.size + 1
    assert(similarity_asset_signature(asset) == old_signature(asset)
      and asset.similarity_signature ~= before, "size change must invalidate")
    asset.duration = asset.duration + 0.5
    assert(similarity_asset_signature(asset) == old_signature(asset),
      "duration change must invalidate")
    asset.path = asset.path .. "x"
    assert(similarity_asset_signature(asset) == old_signature(asset),
      "path change must invalidate")
    -- same identity after path_key folding (case) keeps the same signature
    local folded = { path = asset.path:upper(), size = asset.size, duration = asset.duration }
    assert(similarity_asset_signature(folded) == similarity_asset_signature(asset))
  end

  -- Feature-cache loader: per-frame counter commit, identical content.
  if cache_directory then
    local lines = { table.concat({ Similarity.cache_magic,
      tostring(Similarity.cache_version), tostring(feature_count) }, "\t") }
    local expected, expected_count = {}, 0
    for _ = 1, 3000 do
      local signature = random_hex(16):lower()
      local hex = random_hex(feature_count * 2)
      local roll = random(10)
      if roll == 0 then
        lines[#lines + 1] = signature .. "\t" .. hex:sub(1, -2)
      elseif roll == 1 then
        lines[#lines + 1] = signature .. "\t" .. hex:sub(1, -2) .. "g"
      elseif roll == 2 then
        lines[#lines + 1] = signature:sub(1, 15) .. "\t" .. hex
      elseif roll == 3 then
        lines[#lines + 1] = "garbage line"
      else
        lines[#lines + 1] = signature .. "\t" .. hex
        if not expected[signature] then expected_count = expected_count + 1 end
        expected[signature] = old_pack_hex(hex)
        if roll == 4 then -- duplicate signature, last record wins, not recounted
          local other = random_hex(feature_count * 2)
          lines[#lines + 1] = signature .. "\t" .. other
          expected[signature] = old_pack_hex(other)
        end
      end
    end
    local file = assert(io.open(similarity_cache_path(), "wb"))
    file:write(table.concat(lines, "\n"), "\n")
    file:close()
    state.similarity_cache = {}
    state.similarity_cache_count = 0
    state.similarity_cache_loaded = false
    state.similarity_cache_reset_required = false
    local count_commits = 0
    local original_set = AppState.set
    AppState.set = function(name, value)
      if name == "similarity_cache_count" then count_commits = count_commits + 1 end
      return original_set(name, value)
    end
    local saved_records = Similarity.cache_load_records
    Similarity.cache_load_records = 500
    local load_session = { phase = "prepare" }
    similarity_cache_begin_load(load_session)
    local frames = 0
    while load_session.phase == "load_cache" do
      similarity_cache_step_load(load_session)
      frames = frames + 1
    end
    Similarity.cache_load_records = saved_records
    AppState.set = original_set
    assert(frames >= 6 and count_commits <= frames,
      "cache count must be committed at most once per frame")
    assert(state.similarity_cache_count == expected_count)
    assert(load_session.cache_loaded_count >= expected_count)
    local seen = 0
    for signature, packed in pairs(state.similarity_cache) do
      seen = seen + 1
      assert(expected[signature] == packed, "loaded record differs")
    end
    assert(seen == expected_count)
    assert(state.similarity_cache_loaded == true)
    os.remove(similarity_cache_path())
  end

  -- Reference exclusion uses the cached path key once per session, and the
  -- catalog's asset_path_sort_key is preferred when it exists.
  local key_calls = 0
  local previous_sort_key = asset_path_sort_key
  function asset_path_sort_key(asset)
    key_calls = key_calls + 1
    return path_key(asset.path)
  end
  local reference_asset_2 = { path = "X:/Ref/Same.wav", size = 10, duration = 1, ready = true }
  local twin = { path = "x:/ref/SAME.wav", size = 11, duration = 1, ready = true }
  local rank_session = {
    reference = reference_asset_2,
    reference_features = identical,
    ranked = {},
    bucket_queue = { { key = "k", assets = {}, upper_score = 100 } },
    bucket_index = 1, bucket_asset_index = 1,
    ranked_cached = 0, pruned_cached = 0,
    missing = {}, failed_assets = {}, total = 0, source = {},
  }
  local saved_cache = state.similarity_cache
  state.similarity_cache = {}
  local descriptor_assets = rank_session.bucket_queue[1].assets
  descriptor_assets[1] = twin
  for index = 1, 300 do
    descriptor_assets[index + 1] = {
      path = string.format("X:/Ref/Other%03d.wav", index),
      size = 100 + index, duration = 1, ready = true,
    }
  end
  for _, member in ipairs(descriptor_assets) do
    state.similarity_cache[similarity_asset_signature(member)] = packed
  end
  while rank_session.bucket_queue do
    similarity_process_ranked_buckets(rank_session)
  end
  for _, member in ipairs(rank_session.ranked) do
    assert(member.asset ~= twin, "case-folded twin of the reference must be excluded")
  end
  assert(#rank_session.ranked == Similarity.result_limit)
  assert(key_calls > 0, "asset_path_sort_key must be used when available")
  -- 301 candidates: one key per candidate that could enter the heap, plus the
  -- reference once; never four per candidate.
  assert(key_calls <= 301 + 1 + 1, "path keys must not be recomputed per comparison")
  asset_path_sort_key = previous_sort_key
  state.similarity_cache = saved_cache
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
