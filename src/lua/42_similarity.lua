-- Audio-content similarity service.
--
-- The cache intentionally stores a double FNV signature instead of a source
-- path. At 500,000 records this keeps the on-disk index compact and avoids
-- exposing library paths in a rebuildable analysis cache. Features are
-- quantized to bytes. The disk cache stays readable hexadecimal while the
-- in-memory index uses one raw byte per feature for low-allocation ranking.

Similarity = {
  cache_magic = "PSYSFX_SIM1",
  cache_version = 1,
  feature_count = 15,
  points = 2048,
  result_limit = 200,
  frame_records = 8192,
  cache_load_records = 32768,
  clock_check_interval = 64,
  frame_budget = 0.006,
  bucket_bins = 8,
  bucket_features = { 1, 3, 5, 8, 10 },
  weights = {
    0.18, -- log duration
    0.04, -- mean envelope
    0.05, -- RMS envelope
    0.03, -- peak
    0.07, -- onset
    0.05, -- temporal centroid
    0.05, -- dynamics
    0.09, -- transient activity
    0.04, -- silence ratio
    0.10, -- spectral centroid
    0.08, -- low-band energy
    0.08, -- mid-band energy
    0.08, -- high-band energy
    0.05, -- tonality
    0.01, -- spectral availability
  },
}

function similarity_cache_path()
  return DATA_DIR .. SEP .. "similarity_features_v1.tsv"
end

function invalidate_similarity_index()
  if state and state.similarity_index then
    AppState.set("similarity_index", nil)
  end
  if state and state.similarity_warmup then
    similarity_cancel_warmup(false)
  end
  if state then AppState.set("similarity_warmup_suspended", false) end
end

function similarity_asset_signature(asset)
  if not asset then return "" end
  local size = tonumber(asset.size) or 0
  if size <= 0 then
    size = file_size(asset.path)
    asset.size = size
  end
  local identity_key = table.concat({
    path_key(asset.path),
    tostring(size),
    string.format("%.6f", tonumber(asset.duration) or 0),
  }, "|")
  if asset.similarity_signature_key == identity_key
    and tostring(asset.similarity_signature or "") ~= "" then
    return asset.similarity_signature
  end
  local identity = table.concat({
    identity_key,
    "sim-v1",
  }, "|")
  asset.similarity_signature_key = identity_key
  asset.similarity_signature =
    fnv1a(identity .. "|a") .. fnv1a("b|" .. identity)
  return asset.similarity_signature
end

function similarity_encode_features(features)
  local encoded = {}
  for index = 1, Similarity.feature_count do
    local value = clamp(tonumber(features and features[index]) or 0, 0, 1)
    encoded[index] = string.format("%02x", math.floor(value * 255 + 0.5))
  end
  return table.concat(encoded)
end

function similarity_decode_features(encoded)
  encoded = tostring(encoded or "")
  if #encoded ~= Similarity.feature_count * 2
    or encoded:find("[^0-9a-fA-F]") then
    return nil
  end
  local features = {}
  for index = 1, Similarity.feature_count do
    features[index] = (
      tonumber(encoded:sub(index * 2 - 1, index * 2), 16) or 0
    ) / 255
  end
  return features
end

function similarity_pack_features(features)
  local packed = {}
  for index = 1, Similarity.feature_count do
    local value = clamp(tonumber(features and features[index]) or 0, 0, 1)
    packed[index] = string.char(math.floor(value * 255 + 0.5))
  end
  return table.concat(packed)
end

function similarity_pack_hex(encoded)
  encoded = tostring(encoded or "")
  if #encoded ~= Similarity.feature_count * 2
    or encoded:find("[^0-9a-fA-F]") then
    return nil
  end
  local packed = {}
  for index = 1, Similarity.feature_count do
    packed[index] = string.char(
      tonumber(encoded:sub(index * 2 - 1, index * 2), 16) or 0
    )
  end
  return table.concat(packed)
end

function similarity_unpack_features(packed)
  if type(packed) ~= "string" or #packed ~= Similarity.feature_count then
    return nil
  end
  local features = {}
  for index = 1, Similarity.feature_count do
    features[index] = packed:byte(index) / 255
  end
  return features
end

function similarity_packed_hex(packed)
  if type(packed) ~= "string" or #packed ~= Similarity.feature_count then
    return nil
  end
  local encoded = {}
  for index = 1, Similarity.feature_count do
    encoded[index] = string.format("%02x", packed:byte(index))
  end
  return table.concat(encoded)
end

function similarity_encoded_feature(encoded, index)
  if type(encoded) ~= "string" then return 0 end
  if #encoded == Similarity.feature_count then
    return (encoded:byte(index) or 0) / 255
  end
  local offset = index * 2 - 1
  local high = encoded:byte(offset)
  local low = encoded:byte(offset + 1)
  if not high or not low then return 0 end
  high = high >= 97 and high - 87
    or high >= 65 and high - 55
    or high - 48
  low = low >= 97 and low - 87
    or low >= 65 and low - 55
    or low - 48
  return (high * 16 + low) / 255
end

function similarity_features_from_waveform(asset, waveform)
  if not asset or not waveform or not waveform.peaks then return nil end
  local count = math.min(tonumber(waveform.count) or 0, #waveform.peaks)
  if count <= 0 then return nil end

  local sum = 0
  local squares = 0
  local peak = 0
  local delta = 0
  local previous = tonumber(waveform.peaks[1]) or 0
  for index = 1, count do
    local value = clamp(tonumber(waveform.peaks[index]) or 0, 0, 1)
    sum = sum + value
    squares = squares + value * value
    peak = math.max(peak, value)
    if index > 1 then delta = delta + math.abs(value - previous) end
    previous = value
  end

  local mean = sum / count
  local rms = math.sqrt(squares / count)
  local variance = math.max(0, squares / count - mean * mean)
  local threshold = math.max(0.001, peak * 0.20)
  local onset = 1
  local active = 0
  local temporal_weight = 0
  local weighted_position = 0
  for index = 1, count do
    local value = clamp(tonumber(waveform.peaks[index]) or 0, 0, 1)
    if value >= threshold then
      active = active + 1
      if onset == 1 then onset = (index - 1) / math.max(1, count - 1) end
    end
    temporal_weight = temporal_weight + value
    weighted_position = weighted_position + value * ((index - 1) / math.max(1, count - 1))
  end

  local spectral_available = waveform.spectral_available == true
    and waveform.spectral_frequency
    and waveform.spectral_tonality
  local spectral_weight = 0
  local spectral_centroid = 0
  local tonality = 0
  local low = 0
  local mid = 0
  local high = 0
  if spectral_available then
    for index = 1, count do
      local amplitude = clamp(tonumber(waveform.peaks[index]) or 0, 0, 1)
      local frequency = math.max(20, tonumber(waveform.spectral_frequency[index]) or 20)
      local normalized_frequency = clamp(
        math.log(frequency / 20) / math.log(1000),
        0,
        1
      )
      spectral_weight = spectral_weight + amplitude
      spectral_centroid = spectral_centroid + normalized_frequency * amplitude
      tonality = tonality
        + clamp(tonumber(waveform.spectral_tonality[index]) or 0, 0, 1) * amplitude
      if frequency < 250 then
        low = low + amplitude
      elseif frequency < 2000 then
        mid = mid + amplitude
      else
        high = high + amplitude
      end
    end
  end
  if spectral_weight > 0 then
    spectral_centroid = spectral_centroid / spectral_weight
    tonality = tonality / spectral_weight
    low = low / spectral_weight
    mid = mid / spectral_weight
    high = high / spectral_weight
  end

  local duration = math.max(0, tonumber(asset.duration) or 0)
  return {
    clamp(math.log(1 + duration) / math.log(601), 0, 1),
    mean,
    rms,
    peak,
    onset,
    temporal_weight > 0 and weighted_position / temporal_weight or 0.5,
    clamp(math.sqrt(variance) * 2, 0, 1),
    clamp((delta / math.max(1, count - 1)) * 6, 0, 1),
    1 - active / count,
    spectral_centroid,
    low,
    mid,
    high,
    tonality,
    spectral_available and 1 or 0,
  }
end

function similarity_candidate_feature(candidate, index)
  if type(candidate) == "string" then
    return similarity_encoded_feature(candidate, index)
  end
  return tonumber(candidate and candidate[index]) or 0
end

function similarity_feature_groups(reference, candidate)
  local spectral = reference[15] >= 0.5
    and similarity_candidate_feature(candidate, 15) >= 0.5
  local labels = state and "en" == state.language
    and {
      duration = "duration",
      envelope = "envelope",
      onset = "onset",
      dynamics = "dynamics",
      spectrum = "spectrum",
      tonality = "tonality",
    }
    or {
      duration = "时长",
      envelope = "包络",
      onset = "起音",
      dynamics = "动态",
      spectrum = "频谱",
      tonality = "音调性",
    }
  return {
    { label = labels.duration, difference = math.abs(
      reference[1] - similarity_candidate_feature(candidate, 1)
    ) },
    { label = labels.envelope, difference = (
      math.abs(reference[2] - similarity_candidate_feature(candidate, 2))
      + math.abs(reference[3] - similarity_candidate_feature(candidate, 3))
      + math.abs(reference[4] - similarity_candidate_feature(candidate, 4))
      + math.abs(reference[9] - similarity_candidate_feature(candidate, 9))
    ) / 4 },
    { label = labels.onset, difference = math.abs(
      reference[5] - similarity_candidate_feature(candidate, 5)
    ) },
    { label = labels.dynamics, difference = (
      math.abs(reference[6] - similarity_candidate_feature(candidate, 6))
      + math.abs(reference[7] - similarity_candidate_feature(candidate, 7))
      + math.abs(reference[8] - similarity_candidate_feature(candidate, 8))
    ) / 3 },
    { label = labels.spectrum, difference = spectral and (
      math.abs(reference[10] - similarity_candidate_feature(candidate, 10))
      + math.abs(reference[11] - similarity_candidate_feature(candidate, 11))
      + math.abs(reference[12] - similarity_candidate_feature(candidate, 12))
      + math.abs(reference[13] - similarity_candidate_feature(candidate, 13))
    ) / 4 or 1 },
    { label = labels.tonality, difference = spectral
      and math.abs(
        reference[14] - similarity_candidate_feature(candidate, 14)
      ) or 1 },
  }
end

function similarity_compare_features(reference, candidate)
  if not reference or not candidate then return 0, "" end
  local spectral = reference[15] >= 0.5 and candidate[15] >= 0.5
  local weighted = 0
  local weight_total = 0
  for index = 1, Similarity.feature_count - 1 do
    local weight = Similarity.weights[index] or 0
    if spectral or index < 10 then
      local difference = (reference[index] or 0) - (candidate[index] or 0)
      weighted = weighted + difference * difference * weight
      weight_total = weight_total + weight
    end
  end
  local distance = weight_total > 0 and math.sqrt(weighted / weight_total) or 1
  local score = clamp((1 - distance) * 100, 0, 100)
  local groups = similarity_feature_groups(reference, candidate)
  table.sort(groups, function(left, right)
    if left.difference == right.difference then return left.label < right.label end
    return left.difference < right.difference
  end)
  local labels = {}
  for _, group in ipairs(groups) do
    if group.difference < 1 and #labels < 2 then labels[#labels + 1] = group.label end
  end
  return score, table.concat(labels, "、")
end

function similarity_compare_encoded(reference, encoded)
  if not reference or type(encoded) ~= "string"
    or (#encoded ~= Similarity.feature_count
      and #encoded ~= Similarity.feature_count * 2) then
    return 0
  end
  local spectral = reference[15] >= 0.5
    and similarity_encoded_feature(encoded, 15) >= 0.5
  local weighted = 0
  local weight_total = 0
  for index = 1, Similarity.feature_count - 1 do
    local weight = Similarity.weights[index] or 0
    if spectral or index < 10 then
      local candidate = #encoded == Similarity.feature_count
        and (encoded:byte(index) or 0) / 255
        or similarity_encoded_feature(encoded, index)
      local difference = (reference[index] or 0) - candidate
      weighted = weighted + difference * difference * weight
      weight_total = weight_total + weight
    end
  end
  local distance = weight_total > 0 and math.sqrt(weighted / weight_total) or 1
  return clamp((1 - distance) * 100, 0, 100)
end

function similarity_bucket_axis(candidate, feature_index)
  local value = clamp(
    similarity_candidate_feature(candidate, feature_index),
    0,
    1
  )
  return math.min(
    Similarity.bucket_bins - 1,
    math.floor(value * Similarity.bucket_bins)
  )
end

function similarity_bucket_key(candidate)
  local spectral = similarity_candidate_feature(candidate, 15) >= 0.5
  local parts = { string.char(spectral and 1 or 0) }
  for _, feature_index in ipairs(Similarity.bucket_features) do
    parts[#parts + 1] = string.char(
      similarity_bucket_axis(candidate, feature_index)
    )
  end
  return table.concat(parts)
end

function similarity_bucket_upper_score(reference, key)
  if not reference or type(key) ~= "string"
    or #key ~= #Similarity.bucket_features + 1 then
    return 100
  end
  local spectral = reference[15] >= 0.5 and key:byte(1) == 1
  local weighted = 0
  local weight_total = 0
  for index = 1, Similarity.feature_count - 1 do
    if spectral or index < 10 then
      weight_total = weight_total + (Similarity.weights[index] or 0)
    end
  end
  for axis, feature_index in ipairs(Similarity.bucket_features) do
    if spectral or feature_index < 10 then
      local bin = key:byte(axis + 1) or 0
      local first_byte = math.floor(bin * 256 / Similarity.bucket_bins)
      local last_byte = math.min(
        255,
        math.floor((bin + 1) * 256 / Similarity.bucket_bins) - 1
      )
      local minimum = first_byte / 255
      local maximum = last_byte / 255
      local value = tonumber(reference[feature_index]) or 0
      local difference = value < minimum and minimum - value
        or value > maximum and value - maximum
        or 0
      weighted = weighted
        + difference * difference * (Similarity.weights[feature_index] or 0)
    end
  end
  local lower_distance = weight_total > 0
    and math.sqrt(weighted / weight_total)
    or 1
  return clamp((1 - lower_distance) * 100, 0, 100)
end

function similarity_cache_begin_load(session)
  if state.similarity_cache_loaded then
    session.phase = "reference"
    return
  end
  AppState.set("similarity_cache", state.similarity_cache or {})
  local file = io.open(similarity_cache_path(), "rb")
  if not file then
    AppState.set("similarity_cache_loaded", true)
    session.phase = "reference"
    return
  end
  local header = file:read("*l") or ""
  if header ~= table.concat({
    Similarity.cache_magic,
    tostring(Similarity.cache_version),
    tostring(Similarity.feature_count),
  }, "\t") then
    file:close()
    AppState.set("similarity_cache_loaded", true)
    AppState.set("similarity_cache_reset_required", true)
    session.phase = "reference"
    return
  end
  session.cache_file = file
  session.cache_loaded_count = 0
  session.phase = "load_cache"
end

function similarity_cache_step_load(session)
  local processed = 0
  local deadline = HostApi.time_precise() + Similarity.frame_budget
  while processed < Similarity.cache_load_records
    and (processed == 0
      or processed % Similarity.clock_check_interval ~= 0
      or HostApi.time_precise() < deadline) do
    local line = session.cache_file:read("*l")
    if not line then
      session.cache_file:close()
      session.cache_file = nil
      AppState.set("similarity_cache_loaded", true)
      session.phase = "reference"
      return
    end
    local signature, encoded = line:match("^([0-9a-fA-F]+)\t([0-9a-fA-F]+)$")
    if signature and #signature == 16
      and #encoded == Similarity.feature_count * 2
      and not encoded:find("[^0-9a-fA-F]") then
      if not state.similarity_cache[signature] then
        AppState.set(
          "similarity_cache_count",
          (state.similarity_cache_count or 0) + 1
        )
      end
      state.similarity_cache[signature] = similarity_pack_hex(encoded)
      session.cache_loaded_count = session.cache_loaded_count + 1
    end
    processed = processed + 1
  end
end

function similarity_cache_open_append(session)
  if session.cache_append_file then return true end
  ensure_dirs()
  local path = similarity_cache_path()
  local reset = state.similarity_cache_reset_required
  local existed = HostApi.file_exists(path) and not reset
  local file = io.open(path, existed and "ab" or "wb")
  if not file then return false end
  if not existed then
    file:write(table.concat({
      Similarity.cache_magic,
      tostring(Similarity.cache_version),
      tostring(Similarity.feature_count),
    }, "\t"), "\n")
    AppState.set("similarity_cache_reset_required", false)
  end
  session.cache_append_file = file
  return true
end

function similarity_cache_store(session, signature, features)
  local encoded = similarity_encode_features(features)
  if not state.similarity_cache[signature] then
    AppState.set(
      "similarity_cache_count",
      (state.similarity_cache_count or 0) + 1
    )
  end
  state.similarity_cache[signature] = similarity_pack_hex(encoded)
  if session ~= state.similarity_warmup
    and not (session == state.similarity_session and session.scope == "all") then
    invalidate_similarity_index()
  end
  if not similarity_cache_open_append(session) then return false end
  session.cache_append_file:write(signature, "\t", encoded, "\n")
  session.cache_appended = (session.cache_appended or 0) + 1
  if session.cache_appended % 64 == 0 then session.cache_append_file:flush() end
  return true
end

function clear_similarity_cache()
  if state.similarity_session then
    set_status("请先完成或取消相似声音分析", true)
    return false
  end
  local path = similarity_cache_path()
  if HostApi.file_exists(path) then
    local removed, remove_error = os.remove(path)
    if not removed then
      set_status(
        "无法清空相似声音特征缓存：" .. tostring(remove_error),
        true
      )
      return false
    end
  end
  AppState.apply({
    similarity_cache = {},
    similarity_cache_count = 0,
    similarity_cache_loaded = true,
    similarity_cache_reset_required = false,
    similarity_index = nil,
    similarity_warmup_suspended = true,
    similarity_lookup = {},
    similarity_result_count = 0,
  })
  AppState.set("similarity_reference_path", nil)
  AppState.set("similarity_reference_name", nil)
  if "similar" == state.view then
    AppState.apply({
      view = "all",
      sort_mode = "name",
      sort_desc = false,
      results_dirty = true,
    })
  end
  set_status("已清空相似声音特征缓存")
  return true
end

function similarity_close_files(session)
  if not session then return end
  if session.cache_file then session.cache_file:close(); session.cache_file = nil end
  if session.cache_append_file then
    session.cache_append_file:flush()
    session.cache_append_file:close()
    session.cache_append_file = nil
  end
end

function similarity_rank_is_worse(left, right)
  if left.score ~= right.score then return left.score < right.score end
  return left.sort_path > right.sort_path
end

function similarity_rank_is_better(left, right)
  if left.score ~= right.score then return left.score > right.score end
  return left.sort_path < right.sort_path
end

function similarity_heap_sift_up(heap, index)
  while index > 1 do
    local parent = math.floor(index / 2)
    if not similarity_rank_is_worse(heap[index], heap[parent]) then break end
    heap[index], heap[parent] = heap[parent], heap[index]
    index = parent
  end
end

function similarity_heap_sift_down(heap, index)
  while true do
    local left = index * 2
    if left > #heap then return end
    local right = left + 1
    local worst = left
    if right <= #heap
      and similarity_rank_is_worse(heap[right], heap[left]) then
      worst = right
    end
    if not similarity_rank_is_worse(heap[worst], heap[index]) then return end
    heap[index], heap[worst] = heap[worst], heap[index]
    index = worst
  end
end

function similarity_insert_ranked(session, asset, score, features)
  local entry = {
    asset = asset,
    score = score,
    features = features,
    sort_path = path_key(asset.path),
  }
  if #session.ranked < Similarity.result_limit then
    session.ranked[#session.ranked + 1] = entry
    similarity_heap_sift_up(session.ranked, #session.ranked)
  elseif similarity_rank_is_better(entry, session.ranked[1]) then
    session.ranked[1] = entry
    similarity_heap_sift_down(session.ranked, 1)
  end
end

function similarity_prepare_bucket_queue(session)
  session.bucket_queue = {}
  session.cached_candidate_total = 0
  for key, assets in pairs(session.index_buckets) do
    session.cached_candidate_total = session.cached_candidate_total + #assets
    session.bucket_queue[#session.bucket_queue + 1] = {
      key = key,
      assets = assets,
      upper_score = similarity_bucket_upper_score(
        session.reference_features,
        key
      ),
    }
  end
  table.sort(session.bucket_queue, function(left, right)
    if left.upper_score == right.upper_score then
      return left.key < right.key
    end
    return left.upper_score > right.upper_score
  end)
  session.bucket_index = 1
  session.bucket_asset_index = 1
  session.ranked_cached = 0
  session.pruned_cached = 0
  session.phase = "rank_buckets"
end

function similarity_index_candidate(session, asset)
  if not asset or not asset.ready then return end
  local signature = similarity_asset_signature(asset)
  local packed = state.similarity_cache[signature]
  if packed then
    session.cached = session.cached + 1
    local key = similarity_bucket_key(packed)
    local bucket = session.index_buckets[key]
    if not bucket then
      bucket = {}
      session.index_buckets[key] = bucket
    end
    bucket[#bucket + 1] = asset
  else
    session.missing[#session.missing + 1] = asset
  end
end

function similarity_process_candidate_index(session)
  local processed = 0
  local deadline = HostApi.time_precise() + Similarity.frame_budget
  while session.source_index <= session.total
    and processed < Similarity.frame_records
    and (processed == 0
      or processed % Similarity.clock_check_interval ~= 0
      or HostApi.time_precise() < deadline) do
    similarity_index_candidate(session, session.source[session.source_index])
    session.source_index = session.source_index + 1
    session.indexed = session.indexed + 1
    processed = processed + 1
  end
  if session.source_index > session.total then
    similarity_prepare_bucket_queue(session)
  end
end

function similarity_cached_index_is_current(index)
  return index
    and index.source == state.assets
    and index.total == #state.assets
    and index.cache_count == (state.similarity_cache_count or 0)
end

function similarity_publish_index(session, missing)
  local indexed = 0
  for _, assets in pairs(session.index_buckets) do
    indexed = indexed + #assets
  end
  AppState.set("similarity_index", {
    source = state.assets,
    total = #state.assets,
    cache_count = state.similarity_cache_count or 0,
    cached = indexed,
    buckets = session.index_buckets,
    missing = missing,
  })
end

function similarity_cancel_warmup(reset_partial_cache)
  local warmup = state.similarity_warmup
  if not warmup then return end
  similarity_close_files(warmup)
  AppState.set("similarity_warmup", nil)
  if reset_partial_cache then
    AppState.apply({
      similarity_cache = {},
      similarity_cache_count = 0,
      similarity_cache_loaded = false,
    })
  end
end

function start_similarity_warmup()
  if state.similarity_session or state.similarity_warmup
    or 0 == #state.assets
    or state.similarity_warmup_suspended
    or state.scan or state.import_session or state.precache_session
    or state.root_removal_session or state.relink_plan_session
    or state.transfer_running
    or similarity_cached_index_is_current(state.similarity_index) then
    return false
  end
  if state.similarity_warmup then
    similarity_cancel_warmup(false)
  end
  if state.similarity_warmup then
    similarity_cancel_warmup(false)
  end
  local warmup = {
    source = state.assets,
    total = #state.assets,
    source_index = 1,
    indexed = 0,
    cached = 0,
    analyzed = 0,
    failed = 0,
    index_buckets = {},
    missing = {},
    failed_assets = {},
    phase = "prepare",
  }
  AppState.set("similarity_warmup", warmup)
  similarity_cache_begin_load(warmup)
  if warmup.phase == "reference" then
    warmup.phase = "index_candidates"
  end
  return true
end

function process_similarity_warmup()
  local warmup = state.similarity_warmup
  if not warmup then
    start_similarity_warmup()
    return
  end
  if state.similarity_session or state.scan or state.import_session
    or state.precache_session or state.root_removal_session
    or state.relink_plan_session or state.transfer_running
    or state.preview
    or not can_run_heavy_job() then
    return
  end
  if warmup.source ~= state.assets
    or warmup.total ~= #state.assets then
    local partial = warmup.phase == "load_cache"
    similarity_cancel_warmup(partial)
    start_similarity_warmup()
    return
  end
  if warmup.phase == "load_cache" then
    similarity_cache_step_load(warmup)
    if warmup.phase == "reference" then
      warmup.phase = "index_candidates"
    end
    return
  end
  if warmup.phase == "index_candidates" then
    local processed = 0
    local deadline = HostApi.time_precise() + Similarity.frame_budget
    while warmup.source_index <= warmup.total
      and processed < Similarity.frame_records
      and (processed == 0
        or processed % Similarity.clock_check_interval ~= 0
        or HostApi.time_precise() < deadline) do
      similarity_index_candidate(
        warmup,
        warmup.source[warmup.source_index]
      )
      warmup.source_index = warmup.source_index + 1
      warmup.indexed = warmup.indexed + 1
      processed = processed + 1
    end
    if warmup.source_index > warmup.total then
      warmup.missing_index = 1
      warmup.phase = "analyze_missing"
    end
    return
  end
  if warmup.phase == "analyze_missing" then
    local asset = warmup.missing[warmup.missing_index]
    if not asset then
      similarity_close_files(warmup)
      similarity_publish_index(warmup, warmup.failed_assets)
      AppState.set("similarity_warmup", nil)
      return
    end
    local features, _, status = similarity_features_for_asset(
      warmup,
      asset,
      true,
      false
    )
    if status == "waiting" then return end
    warmup.missing_index = warmup.missing_index + 1
    if features then
      local packed = type(features) == "string"
        and features
        or similarity_pack_features(features)
      local key = similarity_bucket_key(packed)
      local bucket = warmup.index_buckets[key]
      if not bucket then
        bucket = {}
        warmup.index_buckets[key] = bucket
      end
      bucket[#bucket + 1] = asset
    else
      warmup.failed = warmup.failed + 1
      warmup.failed_assets[#warmup.failed_assets + 1] = asset
    end
  end
end

function similarity_begin_candidate_index(session)
  local index = session.scope == "all" and state.similarity_index or nil
  if similarity_cached_index_is_current(index) then
    session.index_buckets = index.buckets
    session.missing = index.missing
    session.cached = index.cached
    session.indexed = session.total
    session.index_reused = true
    similarity_prepare_bucket_queue(session)
    return
  end
  session.phase = "index_candidates"
end

function similarity_process_ranked_buckets(session)
  local processed = 0
  local deadline = HostApi.time_precise() + Similarity.frame_budget
  while session.bucket_index <= #session.bucket_queue
    and processed < Similarity.frame_records
    and (processed == 0
      or processed % Similarity.clock_check_interval ~= 0
      or HostApi.time_precise() < deadline) do
    local descriptor = session.bucket_queue[session.bucket_index]
    if #session.ranked >= Similarity.result_limit
      and descriptor.upper_score + 0.000000001 < session.ranked[1].score then
      for index = session.bucket_index, #session.bucket_queue do
        session.pruned_cached = session.pruned_cached
          + #session.bucket_queue[index].assets
      end
      session.bucket_index = #session.bucket_queue + 1
      break
    end
    local asset = descriptor.assets[session.bucket_asset_index]
    if not asset then
      session.bucket_index = session.bucket_index + 1
      session.bucket_asset_index = 1
    else
      local packed = state.similarity_cache[similarity_asset_signature(asset)]
      if packed and path_key(asset.path) ~= path_key(session.reference.path) then
        similarity_insert_ranked(
          session,
          asset,
          similarity_compare_encoded(session.reference_features, packed),
          packed
        )
      end
      session.bucket_asset_index = session.bucket_asset_index + 1
      session.ranked_cached = session.ranked_cached + 1
      processed = processed + 1
    end
  end
  if session.bucket_index > #session.bucket_queue then
    session.bucket_queue = nil
    session.missing_index = 1
    session.phase = "analyze_missing"
  end
end

function similarity_process_missing(session)
  local processed = 0
  local deadline = HostApi.time_precise() + Similarity.frame_budget
  while session.missing_index <= #session.missing
    and processed < Similarity.frame_records
    and (processed == 0
      or processed % Similarity.clock_check_interval ~= 0
      or HostApi.time_precise() < deadline) do
    local asset = session.missing[session.missing_index]
    session.current = asset
    local features, _, status = similarity_features_for_asset(
      session,
      asset,
      true
    )
    if status == "waiting" then break end
    session.missing_index = session.missing_index + 1
    processed = processed + 1
    if features then
      local packed = type(features) == "string"
        and features
        or similarity_pack_features(features)
      local score = similarity_compare_encoded(
        session.reference_features,
        packed
      )
      if not session.reference
        or path_key(asset.path) ~= path_key(session.reference.path) then
        similarity_insert_ranked(session, asset, score, packed)
      end
      local key = similarity_bucket_key(packed)
      local bucket = session.index_buckets[key]
      if not bucket then
        bucket = {}
        session.index_buckets[key] = bucket
      end
      bucket[#bucket + 1] = asset
    else
      session.failed = session.failed + 1
      session.failed_assets[#session.failed_assets + 1] = asset
    end
  end
  if session.missing_index > #session.missing then
    finish_similarity_search(false)
  end
end

function finish_similarity_search(canceled)
  local session = state.similarity_session
  if not session then return end
  similarity_close_files(session)
  if canceled then
    Jobs.cancel(session.job_token)
    Jobs.finish(session.job_token, true, "canceled")
    AppState.set("similarity_session", nil)
    set_status("已取消相似声音分析")
    return
  end
  table.sort(session.ranked, function(left, right)
    if left.score == right.score then
      return left.sort_path < right.sort_path
    end
    return left.score > right.score
  end)

  AppState.apply({
    similarity_lookup = {},
    similarity_result_count = #session.ranked,
    similarity_reference_path = session.reference.path,
    similarity_reference_name = session.reference.name,
  })
  for _, entry in ipairs(session.ranked) do
    local groups = similarity_feature_groups(
      session.reference_features,
      entry.features
    )
    table.sort(groups, function(left, right)
      if left.difference == right.difference then
        return left.label < right.label
      end
      return left.difference < right.difference
    end)
    local labels = {}
    for _, group in ipairs(groups) do
      if group.difference < 1 and #labels < 2 then
        labels[#labels + 1] = group.label
      end
    end
    state.similarity_lookup[path_key(entry.asset.path)] = {
      score = entry.score,
      explanation = table.concat(labels, "、"),
    }
  end
  if session.scope == "all" and session.source == state.assets then
    similarity_publish_index(session, session.failed_assets)
  end
  -- The source snapshot already freezes the requested scope. Clear the old
  -- UI filters before showing that snapshot so collection/library state does
  -- not filter the completed similarity result a second time.
  AppState.apply({ search = "" })
  AppState.set("active_collection_id", nil)
  AppState.set("root_filter", nil)
  AppState.set("library_filter_id", nil)
  AppState.set("status_filter", nil)
  AppState.apply({
    view = "similar",
    sort_mode = "similarity",
    sort_desc = true,
    results_dirty = true,
    config_dirty = true,
  })
  AppState.set("similarity_session", nil)
  Jobs.finish(session.job_token, true)
  session.processed = session.total
  set_status(string.format(
    "相似声音分析完成：检查 %d，命中 %d，失败 %d",
    session.processed,
    state.similarity_result_count,
    session.failed
  ), session.failed > 0)
end

function cancel_similarity_search()
  if state.similarity_session then finish_similarity_search(true) end
end

function start_similarity_search(reference, scope)
  if not reference or not reference.ready then
    set_status("请先选择可用素材", true)
    return false
  end
  if state.similarity_session then
    set_status("相似声音分析已经在运行", true)
    return false
  end
  if state.scan or state.import_session or state.precache_session
    or state.root_removal_session or state.relink_plan_session
    or state.transfer_running then
    set_status("请等待当前后台任务完成后再分析相似声音", true)
    return false
  end
  if state.similarity_warmup then
    similarity_cancel_warmup(state.similarity_warmup.phase == "load_cache")
  end
  AppState.set("similarity_warmup_suspended", false)
  local token, reason = Jobs.begin("similarity", "catalog_exclusive", false, 45)
  if not token then
    set_status("无法启动相似声音分析：" .. tostring(reason), true)
    return false
  end
  scope = scope == "all" and "all" or "current"
  local source = scope == "all" and state.assets or state.results
  AppState.set("similarity_session", {
    reference = reference,
    reference_signature = similarity_asset_signature(reference),
    reference_features = nil,
    source = source,
    total = #source,
    source_index = 1,
    indexed = 0,
    processed = 0,
    analyzed = 0,
    cached = 0,
    failed = 0,
    ranked = {},
    index_buckets = {},
    missing = {},
    failed_assets = {},
    scope = scope,
    phase = "prepare",
    current = nil,
    job_token = token,
    started = HostApi.time_precise(),
  })
  similarity_cache_begin_load(state.similarity_session)
  set_status("正在准备相似声音分析…")
  return true
end

function similarity_features_for_asset(session, asset, keep_encoded, priority)
  local signature = similarity_asset_signature(asset)
  local encoded = state.similarity_cache[signature]
  if encoded then
    session.cached = session.cached + 1
    return keep_encoded and encoded or similarity_unpack_features(encoded),
      signature,
      "cached"
  end
  local waveform = queue_wave(
    asset,
    Similarity.points,
    priority ~= false,
    false,
    true
  )
  if not waveform then
    if asset.wave_error then return nil, signature, "failed" end
    return nil, signature, "waiting"
  end
  local features = similarity_features_from_waveform(asset, waveform)
  if not features then return nil, signature, "failed" end
  similarity_cache_store(session, signature, features)
  session.analyzed = session.analyzed + 1
  local packed = similarity_pack_features(features)
  return keep_encoded and packed or similarity_unpack_features(packed),
    signature,
    "analyzed"
end

function process_similarity_search()
  local session = state.similarity_session
  if not session then return end
  if session.job_token.cancel_requested then
    finish_similarity_search(true)
    return
  end
  if not can_run_heavy_job() then return end
  if session.phase == "load_cache" then
    similarity_cache_step_load(session)
    return
  end
  if session.phase == "reference" then
    local features, _, status = similarity_features_for_asset(session, session.reference)
    if features then
      session.reference_features = features
      similarity_begin_candidate_index(session)
    elseif status == "failed" then
      similarity_close_files(session)
      Jobs.finish(session.job_token, false, "reference_failed")
      AppState.set("similarity_session", nil)
      set_status("无法分析参考素材的音频特征", true)
    end
    return
  end
  if session.phase == "index_candidates" then
    similarity_process_candidate_index(session)
  elseif session.phase == "rank_buckets" then
    similarity_process_ranked_buckets(session)
  elseif session.phase == "analyze_missing" then
    similarity_process_missing(session)
  end
end

function similarity_result_for_asset(asset)
  return asset and state.similarity_lookup[path_key(asset.path)] or nil
end
