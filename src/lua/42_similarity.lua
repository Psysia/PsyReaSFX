-- Audio-content similarity service.
--
-- The cache intentionally stores a double FNV signature instead of a source
-- path. At 500,000 records this keeps the on-disk index compact and avoids
-- exposing library paths in a rebuildable analysis cache. Features are
-- quantized to bytes; ranking decodes only the current candidate.

Similarity = {
  cache_magic = "PSYSFX_SIM1",
  cache_version = 1,
  feature_count = 15,
  points = 2048,
  result_limit = 200,
  frame_records = 192,
  cache_load_records = 4000,
  frame_budget = 0.003,
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

function similarity_asset_signature(asset)
  if not asset then return "" end
  local size = tonumber(asset.size) or 0
  if size <= 0 then
    size = file_size(asset.path)
    asset.size = size
  end
  local identity = table.concat({
    path_key(asset.path),
    tostring(size),
    string.format("%.6f", tonumber(asset.duration) or 0),
    "sim-v1",
  }, "|")
  return fnv1a(identity .. "|a") .. fnv1a("b|" .. identity)
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

function similarity_feature_groups(reference, candidate)
  local spectral = reference[15] >= 0.5 and candidate[15] >= 0.5
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
    { label = labels.duration, difference = math.abs(reference[1] - candidate[1]) },
    { label = labels.envelope, difference = (
      math.abs(reference[2] - candidate[2])
      + math.abs(reference[3] - candidate[3])
      + math.abs(reference[4] - candidate[4])
      + math.abs(reference[9] - candidate[9])
    ) / 4 },
    { label = labels.onset, difference = math.abs(reference[5] - candidate[5]) },
    { label = labels.dynamics, difference = (
      math.abs(reference[6] - candidate[6])
      + math.abs(reference[7] - candidate[7])
      + math.abs(reference[8] - candidate[8])
    ) / 3 },
    { label = labels.spectrum, difference = spectral and (
      math.abs(reference[10] - candidate[10])
      + math.abs(reference[11] - candidate[11])
      + math.abs(reference[12] - candidate[12])
      + math.abs(reference[13] - candidate[13])
    ) / 4 or 1 },
    { label = labels.tonality, difference = spectral
      and math.abs(reference[14] - candidate[14]) or 1 },
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
    and HostApi.time_precise() < deadline do
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
      state.similarity_cache[signature] = encoded:lower()
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
  state.similarity_cache[signature] = encoded
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

function similarity_insert_ranked(session, asset, score, explanation)
  session.ranked[#session.ranked + 1] = {
    asset = asset,
    score = score,
    explanation = explanation,
  }
  if #session.ranked >= Similarity.result_limit * 2 then
    table.sort(session.ranked, function(left, right)
      if left.score == right.score then
        return path_key(left.asset.path) < path_key(right.asset.path)
      end
      return left.score > right.score
    end)
    while #session.ranked > Similarity.result_limit do
      table.remove(session.ranked)
    end
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
      return path_key(left.asset.path) < path_key(right.asset.path)
    end
    return left.score > right.score
  end)
  while #session.ranked > Similarity.result_limit do table.remove(session.ranked) end

  AppState.apply({
    similarity_lookup = {},
    similarity_result_count = #session.ranked,
    similarity_reference_path = session.reference.path,
    similarity_reference_name = session.reference.name,
  })
  for _, entry in ipairs(session.ranked) do
    state.similarity_lookup[path_key(entry.asset.path)] = {
      score = entry.score,
      explanation = entry.explanation,
    }
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
    index = 1,
    processed = 0,
    analyzed = 0,
    cached = 0,
    failed = 0,
    ranked = {},
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

function similarity_features_for_asset(session, asset)
  local signature = similarity_asset_signature(asset)
  local encoded = state.similarity_cache[signature]
  if encoded then
    session.cached = session.cached + 1
    return similarity_decode_features(encoded), signature, "cached"
  end
  local waveform = queue_wave(asset, Similarity.points, true, false, true)
  if not waveform then
    if asset.wave_error then return nil, signature, "failed" end
    return nil, signature, "waiting"
  end
  local features = similarity_features_from_waveform(asset, waveform)
  if not features then return nil, signature, "failed" end
  similarity_cache_store(session, signature, features)
  session.analyzed = session.analyzed + 1
  return features, signature, "analyzed"
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
      session.phase = "candidates"
    elseif status == "failed" then
      similarity_close_files(session)
      Jobs.finish(session.job_token, false, "reference_failed")
      AppState.set("similarity_session", nil)
      set_status("无法分析参考素材的音频特征", true)
    end
    return
  end
  if session.phase ~= "candidates" then return end

  local processed_this_frame = 0
  local deadline = HostApi.time_precise() + Similarity.frame_budget
  while session.index <= session.total
    and processed_this_frame < Similarity.frame_records
    and HostApi.time_precise() < deadline do
    local asset = session.source[session.index]
    if not asset or not asset.ready
      or path_key(asset.path) == path_key(session.reference.path) then
      session.index = session.index + 1
      session.processed = session.processed + 1
      processed_this_frame = processed_this_frame + 1
    else
      session.current = asset
      local features, _, status = similarity_features_for_asset(session, asset)
      if status == "waiting" then break end
      session.index = session.index + 1
      session.processed = session.processed + 1
      processed_this_frame = processed_this_frame + 1
      if features then
        local score, explanation = similarity_compare_features(
          session.reference_features,
          features
        )
        similarity_insert_ranked(session, asset, score, explanation)
      else
        session.failed = session.failed + 1
      end
    end
  end
  if session.index > session.total then finish_similarity_search(false) end
end

function similarity_result_for_asset(asset)
  return asset and state.similarity_lookup[path_key(asset.path)] or nil
end
