-- Region, loudness, channel and transient analysis services.
local HostApi = Host or reaper

function asset_regions(asset)
  if not asset then
    return {}
  end

  local key = path_key(asset.path)
  local regions = state.regions_by_path[key]

  if not regions then
    regions = {}
    state.regions_by_path[key] = regions
  end

  return regions
end

function sort_regions(regions)
  table.sort(
    regions,
    function(a, b)
      if a.start == b.start then
        return a.finish < b.finish
      end

      return a.start < b.start
    end
  )
end

function load_regions()
  state.regions_by_path = {}

  local file = io.open(REGIONS_FILE, "rb")

  if not file then
    return
  end

  for line in file:lines() do
    local fields = split_tsv(line)
    local path = fields[1]

    if is_persistence_schema_fields(fields) then
      path = ""
    end
    local start_value = tonumber(fields[2])
    local finish_value = tonumber(fields[3])
    local name = fields[4] or ""
    local source = fields[5]

    if not source or source == "" then
      source =
        name:match("^Transient ")
        and "transient"
        or "manual"
    end

    local batch_id = tonumber(fields[6]) or 0

    if path and path ~= ""
      and start_value
      and finish_value
      and finish_value > start_value then

      local key = path_key(path)
      local regions =
        state.regions_by_path[key] or {}

      regions[#regions + 1] = {
        path = path,
        start = clamp(start_value, 0, 1),
        finish = clamp(finish_value, 0, 1),
        name = name ~= "" and name
          or string.format(
            "Region %02d",
            #regions + 1
          ),
        source =
          source == "transient"
          and "transient"
          or "manual",
        batch_id = batch_id,
      }

      state.regions_by_path[key] = regions
    end
  end

  file:close()

  for _, regions in pairs(state.regions_by_path) do
    sort_regions(regions)
  end
end

function save_regions()
  if state.root_removal_session then return false end
  ensure_dirs()

  local file = atomic_file_writer(REGIONS_FILE)

  if not file then
    set_status("无法保存 Region 数据", true)
    return
  end

  write_persistence_schema(file, REGIONS_FILE)

  local job = new_regions_persistence_job(state.regions_by_path)
  local complete, failure
  repeat
    complete, failure = step_regions_persistence_job(
      job,
      file,
      AUXILIARY_SAVE_RECORDS_PER_FRAME,
      escape_tsv
    )
    if failure then
      file:abort()
      set_status("无法保存 Region 数据：" .. tostring(failure), true)
      return false
    end
  until complete

  if not file:close() then
    set_status("无法保存 Region 数据", true)
    return false
  end
  state.regions_dirty = false
  return true
end

function add_saved_region(
  asset,
  start_value,
  finish_value,
  name,
  source,
  batch_id
)
  if not asset then
    return false
  end

  start_value =
    clamp(tonumber(start_value) or 0, 0, 1)

  finish_value =
    clamp(tonumber(finish_value) or 0, 0, 1)

  if finish_value - start_value <= 0.002 then
    return false
  end

  local regions = asset_regions(asset)

  for _, region in ipairs(regions) do
    if math.abs(region.start - start_value) < 0.001
      and math.abs(region.finish - finish_value) < 0.001 then
      return false
    end
  end

  regions[#regions + 1] = {
    path = asset.path,
    start = start_value,
    finish = finish_value,
    name = name ~= "" and name
      or string.format(
        "Region %02d",
        #regions + 1
      ),
    source =
      source == "transient"
      and "transient"
      or "manual",
    batch_id = tonumber(batch_id) or 0,
  }

  sort_regions(regions)

  for index, region in ipairs(regions) do
    if math.abs(region.start - start_value) < 0.000001
      and math.abs(region.finish - finish_value) < 0.000001 then
      state.active_region_index = index
      break
    end
  end

  state.regions_dirty = true
  return true
end

function save_current_selection_as_region(asset)
  if not asset or not has_selection() then
    set_status(
      "请先在大波形中建立有效选区",
      true
    )
    return
  end

  local regions = asset_regions(asset)
  local default_name =
    string.format(
      "Region %02d",
      #regions + 1
    )

  local ok, name =
    HostApi.GetUserInputs(
      "保存当前选区为 Region",
      1,
      "名称:",
      default_name
    )

  if not ok then
    return
  end

  if add_saved_region(
    asset,
    state.region_start,
    state.region_end,
    trim(name)
  ) then
    set_status("Region 已保存")
  else
    set_status("该 Region 已存在或选区无效", true)
  end
end

function activate_saved_region(asset, index, auto_play)
  local regions = asset_regions(asset)
  local region = regions[index]

  if not region then
    return
  end

  state.active_region_index = index
  state.region_start = region.start
  state.region_end = region.finish

  if auto_play ~= false then
    if state.loop_selection then
      state.loop = true
    end

    play_preview(asset, nil, true)
  end
end

function delete_saved_region(asset, index)
  local regions = asset_regions(asset)

  if not regions[index] then
    return
  end

  table.remove(regions, index)

  if #regions == 0 then
    state.regions_by_path[path_key(asset.path)] = nil
    state.active_region_index = 0
  else
    state.active_region_index =
      clamp(
        state.active_region_index,
        1,
        #regions
      )
  end

  state.regions_dirty = true
  set_status("Region 已删除")
end


function latest_transient_batch_id(asset)
  local latest = 0

  for _, region in ipairs(asset_regions(asset)) do
    if region.source == "transient" then
      latest =
        math.max(
          latest,
          tonumber(region.batch_id) or 0
        )
    end
  end

  return latest
end

function clear_transient_regions(asset, batch_id)
  if not asset then
    return 0
  end

  local regions = asset_regions(asset)
  local kept = {}
  local removed = 0

  for _, region in ipairs(regions) do
    local matches =
      region.source == "transient"
      and (
        batch_id == nil
        or (tonumber(region.batch_id) or 0)
          == tonumber(batch_id)
      )

    if matches then
      removed = removed + 1
    else
      kept[#kept + 1] = region
    end
  end

  local key = path_key(asset.path)

  if #kept > 0 then
    state.regions_by_path[key] = kept
  else
    state.regions_by_path[key] = nil
  end

  if removed > 0 then
    state.active_region_index = 0
    state.regions_dirty = true
  end

  return removed
end

function undo_last_transient_detection(asset)
  local batch_id =
    latest_transient_batch_id(asset)

  if batch_id <= 0 then
    set_status("没有可撤销的瞬态检测结果", true)
    return
  end

  local removed =
    clear_transient_regions(asset, batch_id)

  set_status(
    string.format(
      "已撤销上次检测，移除 %d 个瞬态 Region",
      removed
    )
  )
end

function clear_all_transient_suggestions(asset)
  local removed =
    clear_transient_regions(asset, nil)

  if removed > 0 then
    set_status(
      string.format(
        "已清除 %d 个瞬态 Region 建议",
        removed
      )
    )
  else
    set_status("当前素材没有瞬态 Region 建议", true)
  end
end

function loudness_cache_key(asset)
  return path_key(asset.path)
end

function load_loudness_cache()
  state.loudness_cache = {}

  local file = io.open(LOUDNESS_FILE, "rb")

  if not file then
    return
  end

  for line in file:lines() do
    local fields = split_tsv(line)
    local path = fields[1]

    if is_persistence_schema_fields(fields) then
      path = ""
    end
    local size = tonumber(fields[2]) or 0

    if path and path ~= "" then
      state.loudness_cache[path_key(path)] = {
        path = path,
        size = size,
        lufs_i = tonumber(fields[3]),
        lufs_m = tonumber(fields[4]),
        lufs_s = tonumber(fields[5]),
        true_peak = tonumber(fields[6]),
      }
    end
  end

  file:close()
end

function save_loudness_cache()
  if state.root_removal_session then return false end
  ensure_dirs()

  local file = atomic_file_writer(LOUDNESS_FILE)

  if not file then
    set_status("无法保存响度缓存", true)
    return
  end

  write_persistence_schema(file, LOUDNESS_FILE)

  local job = new_loudness_persistence_job(state.loudness_cache)
  local complete, failure
  repeat
    complete, failure = step_loudness_persistence_job(
      job,
      file,
      AUXILIARY_SAVE_RECORDS_PER_FRAME,
      escape_tsv
    )
    if failure then
      file:abort()
      set_status("无法保存响度缓存：" .. tostring(failure), true)
      return false
    end
  until complete

  if not file:close() then
    set_status("无法保存响度缓存", true)
    return false
  end
  state.loudness_dirty = false
  return true
end

function valid_loudness_entry(asset)
  if not asset then
    return nil
  end

  local entry =
    state.loudness_cache[loudness_cache_key(asset)]

  if not entry then
    return nil
  end

  local size =
    tonumber(asset.size) or file_size(asset.path)

  if tonumber(entry.size) ~= size then
    state.loudness_cache[loudness_cache_key(asset)] = nil
    state.loudness_dirty = true
    return nil
  end

  return entry
end

function loudness_required_fields()
  local fields = {}

  if state.loudness_show_i then
    fields[#fields + 1] = {
      field = "lufs_i",
      mode = 0,
    }
  end

  if state.loudness_show_m then
    fields[#fields + 1] = {
      field = "lufs_m",
      mode = 4,
    }
  end

  if state.loudness_show_s then
    fields[#fields + 1] = {
      field = "lufs_s",
      mode = 5,
    }
  end

  if state.loudness_show_tp then
    fields[#fields + 1] = {
      field = "true_peak",
      mode = 3,
    }
  end

  return fields
end

function loudness_value_from_gain(gain, target)
  gain = tonumber(gain)

  if not gain
    or gain <= 0
    or gain ~= gain
    or gain == math.huge then
    return nil
  end

  -- CalculateNormalization 返回达到目标值所需的线性增益。
  return (target or 0)
    - 20 * math.log(gain, 10)
end

function request_loudness_analysis(asset, force)
  if not state.show_loudness_metrics
    or not asset
    or not HostApi.file_exists(asset.path)
    or type(HostApi.CalculateNormalization) ~= "function" then
    return
  end

  local key = loudness_cache_key(asset)
  local entry = valid_loudness_entry(asset)
  local required = loudness_required_fields()
  local missing = force == true

  if not missing then
    for _, metric in ipairs(required) do
      if not entry or entry[metric.field] == nil then
        missing = true
        break
      end
    end
  end

  if not missing
    or state.loudness_queued[key]
    or (
      state.loudness_active
      and state.loudness_active.key == key
    ) then
    return
  end

  -- 只保留最新的待分析素材，快速浏览时不会积压整条响度队列。
  state.loudness_queue = {}
  state.loudness_queued = {}
  state.loudness_queued[key] = true
  state.loudness_queue[1] = {
    key = key,
    asset = asset,
    force = force == true,
  }
end

function destroy_loudness_job(job, completed)
  if job and job.source then
    HostApi.PCM_Source_Destroy(job.source)
    job.source = nil
  end

  if job and job.job_token then
    if not completed then
      Jobs.cancel(job.job_token)
    end
    Jobs.finish(
      job.job_token,
      true,
      completed and "" or "canceled"
    )
    job.job_token = nil
  end
end

function process_loudness_queue()
  if not state.show_loudness_metrics
    or state.scan
    or state.import_session
    or not can_run_heavy_job() then
    return
  end

  local now = HostApi.time_precise()

  if now < state.next_loudness_job then
    return
  end

  if not state.loudness_active then
    local queued =
      table.remove(state.loudness_queue, 1)

    if not queued then
      return
    end

    state.loudness_queued[queued.key] = nil

    local source =
      HostApi.PCM_Source_CreateFromFile(
        queued.asset.path
      )

    if not source then
      return
    end

    local entry =
      valid_loudness_entry(queued.asset)
      or {
        path = queued.asset.path,
        size =
          tonumber(queued.asset.size)
          or file_size(queued.asset.path),
      }

    local metrics = loudness_required_fields()
    local pending = {}

    for _, metric in ipairs(metrics) do
      if queued.force
        or entry[metric.field] == nil then
        pending[#pending + 1] = metric
      end
    end

    if #pending == 0 then
      HostApi.PCM_Source_Destroy(source)
      return
    end

    state.loudness_active = {
      key = queued.key,
      asset = queued.asset,
      source = source,
      entry = entry,
      metrics = pending,
      index = 1,
      job_token =
        Jobs.begin(
          "loudness",
          "audio_analysis",
          true
        ),
    }
  end

  local job = state.loudness_active
  local metric = job.metrics[job.index]

  if not metric then
    state.loudness_cache[job.key] = job.entry
    state.loudness_dirty = true
    destroy_loudness_job(job, true)
    state.loudness_active = nil
    return
  end

  local ok, gain =
    pcall(
      HostApi.CalculateNormalization,
      job.source,
      metric.mode,
      0,
      0,
      0
    )

  if ok then
    job.entry[metric.field] =
      loudness_value_from_gain(gain, 0)
  end

  job.index = job.index + 1
  state.next_loudness_job = now + 0.05
end

function waveform_rms_proxy(asset)
  if not asset then
    return nil
  end

  if asset._preview_rms_proxy then
    return asset._preview_rms_proxy
  end

  local waveform =
    queue_wave(
      asset,
      LARGE_WAVE_DEFAULT_POINTS,
      true
    )

  if not waveform
    or not waveform.peaks
    or waveform.count <= 0 then
    return nil
  end

  local sum = 0

  for index = 1, waveform.count do
    local value = waveform.peaks[index] or 0
    sum = sum + value * value
  end

  local rms =
    math.sqrt(
      sum / math.max(1, waveform.count)
    )

  asset._preview_rms_proxy =
    math.max(rms, 0.000001)

  return asset._preview_rms_proxy
end

function loudness_match_offset_db(asset)
  if not state.loudness_match then
    return 0
  end

  local rms = waveform_rms_proxy(asset)

  if not rms then
    return 0
  end

  local current_db =
    20 * math.log(rms, 10)

  return clamp(
    state.loudness_target_db - current_db,
    -18,
    18
  )
end

function preview_asset_channel_count(asset)
  return clamp(
    math.floor(
      tonumber(asset and asset.channels) or 1
    ),
    1,
    8
  )
end

function reset_preview_channel_selection(asset)
  local count = preview_asset_channel_count(asset)
  local selected = {}

  for channel = 1, count do
    selected[channel] = true
  end

  state.preview_channel_asset_key =
    asset and path_key(asset.path) or nil
  state.preview_channel_count = count
  state.preview_channel_selection = selected
  state.preview_channel_anchor = 1

  if count > 2
    and state.preview_channel_mode == "custom" then
    state.preview_channel_mode = "original"
  end

  return selected, count
end

function ensure_preview_channel_selection(asset)
  local count = preview_asset_channel_count(asset)
  local key = asset and path_key(asset.path) or nil

  if state.preview_channel_asset_key ~= key
    or state.preview_channel_count ~= count then
    return reset_preview_channel_selection(asset)
  end

  return state.preview_channel_selection, count
end

function selected_preview_channel_count(asset)
  local selected, count =
    ensure_preview_channel_selection(asset)
  local selected_count = 0

  for channel = 1, count do
    if selected[channel] then
      selected_count = selected_count + 1
    end
  end

  return selected_count, count
end

function preview_channel_is_selected(asset, channel)
  local selected, count =
    ensure_preview_channel_selection(asset)

  if count <= 2 then
    if state.preview_channel_mode == "left" then
      return channel == 1
    elseif state.preview_channel_mode == "right" then
      return channel == 2
    end

    return true
  end

  return selected[channel] == true
end

function select_all_preview_channels(asset)
  local selected, count =
    ensure_preview_channel_selection(asset)

  for channel = 1, count do
    selected[channel] = true
  end

  state.preview_channel_mode = "original"
  state.preview_channel_anchor = 1
end

function apply_preview_channel_selection(
  asset,
  channel,
  ctrl,
  shift,
  solo
)
  local selected, channel_count =
    ensure_preview_channel_selection(asset)

  if solo or (not ctrl and not shift) then
    for item = 1, channel_count do
      selected[item] = item == channel
    end
  elseif shift then
    local first =
      math.min(
        state.preview_channel_anchor or channel,
        channel
      )
    local last =
      math.max(
        state.preview_channel_anchor or channel,
        channel
      )

    if not ctrl then
      for item = 1, channel_count do
        selected[item] = false
      end
    end

    for item = first, last do
      selected[item] = true
    end
  else
    selected[channel] = not selected[channel]

    if selected_preview_channel_count(asset) == 0 then
      selected[channel] = true
    end
  end

  state.preview_channel_anchor = channel

  local selected_after =
    selected_preview_channel_count(asset)

  state.preview_channel_mode =
    selected_after == channel_count
      and "original"
      or "custom"
  state.config_dirty = true
end

function preview_channel_label(channel, count)
  if count == 1 then
    return "M"
  elseif count == 2 then
    return channel == 1 and "L" or "R"
  end

  return string.format("CH %d", channel)
end

function cycle_preview_channel_mode(asset)
  local count = preview_asset_channel_count(asset)

  if count > 2 then
    return false
  end

  local order =
    count == 1
      and { "original", "mono" }
      or { "original", "left", "right", "mono" }
  local current = 1

  for index, mode in ipairs(order) do
    if mode == state.preview_channel_mode then
      current = index
      break
    end
  end

  state.preview_channel_mode =
    order[current % #order + 1]
  state.config_dirty = true

  if state.preview then
    update_preview_parameters()
  end

  return true
end

function apply_preview_channel_mode(preview, mono_output_channel)
  if not preview then
    return
  end

  local pan = 0

  if state.preview_channel_mode == "left" then
    pan = -1
  elseif state.preview_channel_mode == "right" then
    pan = 1
  end

  pcall(
    HostApi.CF_Preview_SetValue,
    preview,
    "D_PAN",
    pan
  )

  local use_centered_mono =
    state.preview_channel_mode == "left"
      or state.preview_channel_mode == "right"
      or state.preview_channel_mode == "mono"

  pcall(
    HostApi.CF_Preview_SetValue,
    preview,
    "I_OUTCHAN",
    use_centered_mono
      and (
        1024
          + clamp(
            math.floor(mono_output_channel or 0),
            0,
            1
          )
      )
      or 0
  )
end

function request_transient_detection(asset)
  if not asset then
    return
  end

  state.pending_transient_detection = asset.path

  queue_wave(
    asset,
    LARGE_WAVE_MAX_POINTS,
    true
  )

  set_status("正在准备高精度波形并检测瞬态…")
end

function cancel_pending_transient_detection()
  if state.pending_transient_detection then
    state.pending_transient_detection = nil
    set_status("已取消待执行的瞬态检测")
  end
end

function open_transient_detection_popup(asset)
  if not asset then
    return
  end

  state.transient_popup_asset_path = asset.path
  state.transient_popup_requested = 2
end

function perform_transient_detection(asset, waveform)
  if not asset
    or not waveform
    or waveform.count <= 2 then
    return
  end

  local duration = tonumber(asset.duration) or 0

  if duration <= 0 then
    set_status("素材时长不可用", true)
    return
  end

  local threshold =
    clamp(
      state.transient_threshold,
      0.001,
      0.95
    )

  local min_gap_points =
    math.max(
      1,
      math.floor(
        waveform.count
          * (state.transient_min_gap_ms / 1000)
          / duration
      )
    )

  local smoothing_points =
    math.max(
      0,
      math.floor(
        waveform.count
          * (state.transient_smoothing_ms / 1000)
          / duration
      )
    )

  local envelope = {}

  for index = 1, waveform.count do
    if smoothing_points <= 0 then
      envelope[index] = waveform.peaks[index] or 0
    else
      local first =
        math.max(1, index - smoothing_points)
      local last =
        math.min(
          waveform.count,
          index + smoothing_points
        )
      local sum = 0

      for sample = first, last do
        sum = sum + (waveform.peaks[sample] or 0)
      end

      envelope[index] =
        sum / math.max(1, last - first + 1)
    end
  end

  local pre_percent =
    (state.transient_pre_ms / 1000) / duration

  local post_percent =
    (state.transient_post_ms / 1000) / duration

  local candidates = {}
  local last_index = -min_gap_points
  local maximum =
    clamp(
      math.floor(state.transient_max_regions or 64),
      1,
      256
    )

  for index = 2, waveform.count - 1 do
    local value = envelope[index] or 0

    if value >= threshold
      and value >= (envelope[index - 1] or 0)
      and value >= (envelope[index + 1] or 0)
      and index - last_index >= min_gap_points then

      candidates[#candidates + 1] = index
      last_index = index

      if #candidates >= maximum then
        break
      end
    end
  end

  if #candidates == 0 then
    set_status(
      "未检测到超过当前阈值的瞬态",
      true
    )
    return
  end

  local batch_id =
    latest_transient_batch_id(asset) + 1

  if state.transient_replace_existing then
    clear_transient_regions(asset, nil)
  end

  local added = 0

  for index, peak_index in ipairs(candidates) do
    local center =
      (peak_index - 1)
      / math.max(1, waveform.count - 1)

    local next_center =
      candidates[index + 1]
      and (
        (candidates[index + 1] - 1)
        / math.max(1, waveform.count - 1)
      )
      or 1

    local start_value =
      clamp(center - pre_percent, 0, 1)

    local finish_value =
      math.min(
        1,
        math.max(
          start_value + 0.002,
          math.min(
            center + post_percent,
            next_center - pre_percent * 0.5
          )
        )
      )

    if finish_value > start_value
      and add_saved_region(
        asset,
        start_value,
        finish_value,
        string.format(
          "Transient %02d",
          index
        ),
        "transient",
        batch_id
      ) then
      added = added + 1
    end
  end

  if added > 0 then
    local regions = asset_regions(asset)

    for index, region in ipairs(regions) do
      if region.source == "transient"
        and tonumber(region.batch_id) == batch_id then
        state.active_region_index = index
        activate_saved_region(asset, index, false)
        break
      end
    end

    set_status(
      string.format(
        "已生成 %d 个瞬态 Region 建议；可在 Region 列表中撤销或清除",
        added
      )
    )
  else
    set_status(
      "没有新增瞬态 Region",
      true
    )
  end
end

function process_pending_transient_detection()
  local path = state.pending_transient_detection

  if not path then
    return
  end

  local asset = state.by_path[path_key(path)]

  if not asset then
    state.pending_transient_detection = nil
    return
  end

  local waveform =
    queue_wave(
      asset,
      LARGE_WAVE_MAX_POINTS,
      true
    )

  if waveform then
    state.pending_transient_detection = nil
    perform_transient_detection(asset, waveform)
  end
end
