function parse_ucs_filename(filename)
  local stem = strip_extension(filename)
  local tokens = {}

  for token in stem:gmatch("[^_%-%s]+") do
    tokens[#tokens + 1] = token
  end

  local result = {
    catid = "",
    category = tokens[1] or "",
    subcategory = tokens[2] or "",
  }

  if tokens[1]
    and tokens[1]:match("^[A-Z][A-Z0-9]+$") then
    result.catid = tokens[1]
  end

  return result
end

function asset_relative_path(path, root)
  path = canonical_source_path(path)
  root = canonical_source_path(root)

  if root == "" or not path_is_inside(path, root) then
    return basename(path)
  end

  if path_key(path) == path_key(root) then
    return ""
  end

  return normalize_slashes(path:sub(#root + 2))
end

function ensure_asset_identity(asset)
  if not asset then
    return
  end

  asset.relative_path = tostring(asset.relative_path or "")

  if asset.relative_path == "" then
    asset.relative_path = asset_relative_path(
      asset.path or "",
      asset.root or ""
    )
  end

  if tostring(asset.asset_id or "") == "" then
    asset.asset_id = stable_id(
      "asset",
      tostring(asset.root_id or "")
        .. "|"
        .. path_key(asset.relative_path)
    )
  end

  if reaper.file_exists(asset.path or "") then
    asset.last_seen = os.time()
  else
    asset.last_seen = tonumber(asset.last_seen) or 0
  end
end

function make_placeholder(path, known_root)
  local name = basename(path)
  local ucs = parse_ucs_filename(name)
  local root, root_record

  if known_root then
    root = known_root
    root_record = root_record_for_path(root)
  else
    root, root_record = root_for_path(path)
  end

  local library = library_for_root_record(root_record)

  local asset = {
    path = normalize_slashes(path),
    name = name,
    folder = dirname(path),
    root = root or "",
    root_id = root_record and root_record.id or "",
    library_id = library and library.id or "",
    library = library and library.name
      or library_for_path(path, root),

    duration = 0,
    channels = 0,
    sample_rate = 0,
    bit_depth = 0,
    source_type = extension(path):upper(),
    size = 0,

    description = "",
    keywords = "",
    catid = ucs.catid,
    category = ucs.category,
    subcategory = ucs.subcategory,
    artwork_path = "",
    artwork_checked = false,

    workflow_status = "none",
    marked = false,
    preview_count = 0,
    last_previewed = 0,

    indexed = false,
    ready = false,
    used_count = 0,
    last_used = 0,
    fingerprint = "",
    fingerprint_size = 0,
    fingerprint_version = "",
    fingerprint_modified = "",
    fingerprint_stat_source = "",
  }

  ensure_asset_identity(asset)
  return asset
end

function asset_path_sort_key(asset)
  local source = tostring(asset.path or "")
  if asset._sort_path_source ~= source then
    asset._sort_path_source = source
    asset._sort_path_value = path_key(source)
  end
  return asset._sort_path_value
end

function add_or_update_asset(asset)
  ensure_asset_identity(asset)
  local key = path_key(asset.path)
  local existing = state.by_path[key]

  if existing then
    local old_folder = path_key(existing.folder or "")
    local old_root_id = tostring(existing.root_id or "")
    local used_count = existing.used_count
    local last_used = existing.last_used
    local workflow_status =
      existing.workflow_status or "none"
    local marked = existing.marked == true
    local preview_count =
      existing.preview_count or 0
    local last_previewed =
      existing.last_previewed or 0
    local artwork_path =
      existing.artwork_path or ""
    local asset_id = tostring(existing.asset_id or "")

    for field, value in pairs(asset) do
      existing[field] = value
    end

    existing.used_count =
      tonumber(used_count) or 0

    existing.last_used =
      tonumber(last_used) or 0

    existing.workflow_status =
      WORKFLOW_STATUS[workflow_status]
      and workflow_status
      or "none"

    existing.marked = marked

    existing.preview_count =
      tonumber(preview_count) or 0

    existing.last_previewed =
      tonumber(last_previewed) or 0

    if (existing.artwork_path or "") == "" then
      existing.artwork_path = artwork_path
    end

    if asset_id ~= "" then
      existing.asset_id = asset_id
    end

    existing.artwork_checked =
      tostring(existing.artwork_path or "") ~= ""

    existing._search_blob = nil
    invalidate_library_counts()

    if old_folder ~= path_key(existing.folder or "")
      or old_root_id ~= tostring(existing.root_id or "") then
      invalidate_folder_navigation()
    end

    return existing
  end

  asset.workflow_status =
    WORKFLOW_STATUS[asset.workflow_status]
    and asset.workflow_status
    or "none"

  asset.marked = asset.marked == true

  asset.preview_count =
    tonumber(asset.preview_count) or 0

  asset.last_previewed =
    tonumber(asset.last_previewed) or 0

  asset.artwork_path =
    tostring(asset.artwork_path or "")

  asset.artwork_checked =
    asset.artwork_path ~= ""

  asset.used_count =
    tonumber(asset.used_count) or 0

  asset.last_used =
    tonumber(asset.last_used) or 0

  state.by_path[key] = asset
  state.assets[#state.assets + 1] = asset
  state.database_ordered_assets = nil
  invalidate_library_counts()
  invalidate_folder_navigation()
  return asset
end

function rebuild_assets()
  state.assets = {}
  state.database_ordered_assets = nil

  for _, asset in pairs(state.by_path) do
    state.assets[#state.assets + 1] = asset
  end

  state.results_dirty = true
  invalidate_library_counts()
  invalidate_folder_navigation()
end

----------------------------------------------------------------
-- Persistence
----------------------------------------------------------------

local DB_FIELDS = {
  "asset_id",
  "path",
  "relative_path",
  "name",
  "folder",
  "root",
  "library",
  "duration",
  "channels",
  "sample_rate",
  "bit_depth",
  "source_type",
  "size",
  "description",
  "keywords",
  "catid",
  "category",
  "subcategory",
  "artwork_path",
  "workflow_status",
  "marked",
  "preview_count",
  "last_previewed",
  "indexed",
  "ready",
  "used_count",
  "last_used",
  "root_id",
  "library_id",
  "fingerprint",
  "fingerprint_size",
  "fingerprint_version",
  "fingerprint_modified",
  "fingerprint_stat_source",
  "last_seen",
}

function save_libraries()
  ensure_dirs()

  local file = atomic_file_writer(LIBRARIES_FILE)

  if not file then
    set_status("无法保存音效库结构", true)
    return false
  end

  write_persistence_schema(file, LIBRARIES_FILE)
  file:write("version\t3\n")

  for _, library in ipairs(state.libraries) do
    file:write(
      "library\t",
      escape_tsv(library.id),
      "\t",
      escape_tsv(library.name),
      "\t",
      escape_tsv(library.artwork_path or ""),
      "\t",
      state.expanded_libraries[library.id] == false
        and "0" or "1",
      "\n"
    )
  end

  for _, record in ipairs(state.root_records) do
    refresh_source_identity(record)
    file:write(
      "root\t",
      escape_tsv(record.id),
      "\t",
      escape_tsv(record.library_id),
      "\t",
      escape_tsv(record.path),
      "\t",
      escape_tsv(record.alias or ""),
      "\t",
      record.enabled == false and "0" or "1",
      "\t",
      escape_tsv(record.artwork_path or ""),
      "\t",
      record.artwork_checked == true and "1" or "0",
      "\t",
      tostring(record.artwork_scan_version or 0),
      "\t",
      escape_tsv(record.canonical_path or ""),
      "\t",
      escape_tsv(record.volume_label or ""),
      "\t",
      escape_tsv(record.volume_serial or ""),
      "\t",
      tostring(record.last_seen or 0),
      "\n"
    )
  end

  if not file:close() then
    set_status("无法保存音效库结构", true)
    return false
  end
  state.libraries_dirty = false
  return true
end

function load_or_migrate_libraries()
  state.libraries = {}
  state.root_records = {}
  state.expanded_libraries = {}

  local file = io.open(LIBRARIES_FILE, "rb")

  if file then
    for line in file:lines() do
      local fields = split_tsv(line)

      if fields[1] == "library"
        and fields[2]
        and fields[3] then
        state.libraries[#state.libraries + 1] = {
          id = fields[2],
          name = fields[3],
          artwork_path = fields[4] or "",
          artwork_checked = false,
          roots = {},
        }
        state.expanded_libraries[fields[2]] =
          fields[5] ~= "0"
      elseif fields[1] == "root"
        and fields[2]
        and fields[3]
        and fields[4] then
        state.root_records[#state.root_records + 1] = {
          id = fields[2],
          library_id = fields[3],
          path = canonical_source_path(fields[4]),
          alias = fields[5] or "",
          enabled = fields[6] ~= "0",
          artwork_path = fields[7] or "",
          artwork_checked = fields[8] == "1",
          artwork_scan_version = tonumber(fields[9]) or 0,
          canonical_path = fields[10] or "",
          volume_label = fields[11] or "",
          volume_serial = fields[12] or "",
          last_seen = tonumber(fields[13]) or 0,
        }
      end
    end

    file:close()
    rebuild_library_indexes()

    -- Re-run negative automatic searches when the discovery algorithm gains
    -- new folder-layout support. Explicit manual paths and "-" opt-outs remain
    -- untouched.
    for _, record in ipairs(state.root_records) do
      if tostring(record.artwork_path or "") == ""
        and record.artwork_scan_version
          < ARTWORK_DISCOVERY_VERSION then
        record.artwork_checked = false
        state.libraries_dirty = true
      end
    end

    -- Beta 5/6 stored an automatically discovered source cover on the
    -- logical library. Migrate it only when ownership is unambiguous.
    -- Multi-source libraries intentionally drop the shared association so
    -- each source can discover or select its own artwork independently.
    for _, library in ipairs(state.libraries) do
      local legacy_artwork = tostring(library.artwork_path or "")

      if legacy_artwork ~= "" then
        if #library.roots == 1
          and tostring(library.roots[1].artwork_path or "") == "" then
          library.roots[1].artwork_path = legacy_artwork
          library.roots[1].artwork_checked = true
        end

        library.artwork_path = ""
        library.artwork_checked = false
        state.libraries_dirty = true
      end
    end

    return
  end

  -- 0.7.1 及更早版本：每个 root 自动迁移为一个逻辑库。
  for _, root in ipairs(state.legacy_roots) do
    local library = create_library(
      basename(root),
      "legacy-library:" .. path_key(root)
    )

    state.root_records[#state.root_records + 1] = {
      id = stable_id("root", path_key(root)),
      library_id = library.id,
      path = canonical_source_path(root),
      alias = "",
      enabled = true,
      artwork_path = "",
      artwork_checked = false,
      artwork_scan_version = 0,
    }
  end

  rebuild_library_indexes()

  if #state.libraries > 0 then
    save_libraries()
    set_status("已将旧音效库迁移为逻辑库与来源路径")
  end
end

function load_config()
  local file = io.open(CONFIG_FILE, "rb")

  if not file then
    return
  end

  for line in file:lines() do
    local fields = split_tsv(line)

    if fields[1] == "folder_open"
      and fields[2]
      and fields[2] ~= "" then
      state.expanded_folder_nodes[path_key(fields[2])] = true
    elseif fields[1] == "source_open"
      and fields[2]
      and fields[2] ~= "" then
      state.expanded_source_folders[fields[2]] = true
    elseif fields[1] == "root"
      and fields[2]
      and fields[2] ~= "" then
      state.legacy_roots[#state.legacy_roots + 1] =
        normalize_slashes(fields[2])
    elseif fields[1] == "favorite"
      and fields[2] then
      state.favorites[path_key(fields[2])] = true
    elseif fields[1] == "recent"
      and fields[2] then
      state.recent[#state.recent + 1] = fields[2]
    elseif fields[1] == "setting" then
      local name = fields[2]
      local value = fields[3]

      if name == "watch" then
        state.watch_enabled = value == "1"
      elseif name == "watch_interval" then
        state.watch_interval = clamp(tonumber(value) or WATCH_INTERVAL, 15, 3600)
      elseif name == "watch_silent" then
        state.watch_silent = value ~= "0"
      elseif name == "resume_scan_on_start" then
        state.resume_scan_on_start = value ~= "0"
      elseif name == "auto_backup" then
        state.auto_backup = value ~= "0"
      elseif name == "backup_keep_count" then
        state.backup_keep_count = clamp(math.floor(tonumber(value) or 7), 1, 30)
      elseif name == "auto_collect_project_usage" then
        state.auto_collect_project_usage = value ~= "0"
      elseif name == "auto_preview" then
        state.auto_preview = value == "1"
      elseif name == "insert_lowercase" then
        state.insert_lowercase = value == "1"
      elseif name == "insert_prefix" then
        state.insert_prefix = value or ""
      elseif name == "insert_suffix" then
        state.insert_suffix = value or ""
      elseif name == "transfer_dir" then
        state.transfer_dir =
          normalize_slashes(trim(value or ""))
        if state.transfer_dir == "" then
          state.transfer_dir = DEFAULT_TRANSFER_DIR
        end
      elseif name == "transfer_template" then
        state.transfer_template =
          value ~= "" and value or "{name}"
      elseif name == "transfer_format" then
        local valid_formats = {
          wav16 = true,
          wav24 = true,
          wav32 = true,
          flac = true,
        }
        state.transfer_format =
          valid_formats[value] and value or "wav24"
      elseif name == "transfer_sample_rate" then
        local valid_rates = {
          source = true,
          ["44100"] = true,
          ["48000"] = true,
          ["96000"] = true,
          ["192000"] = true,
        }
        state.transfer_sample_rate =
          valid_rates[value] and value or "source"
      elseif name == "transfer_channels" then
        state.transfer_channels =
          value == "mono" and "mono"
          or value == "stereo" and "stereo"
          or "source"
      elseif name == "transfer_scope" then
        state.transfer_scope =
          value == "full" and "full" or "selection"
      elseif name == "transfer_collision" then
        state.transfer_collision =
          value == "skip" and "skip"
          or value == "overwrite" and "overwrite"
          or "increment"
      elseif name == "transfer_fade_in_ms" then
        state.transfer_fade_in_ms =
          tonumber(value) or 5
      elseif name == "transfer_fade_out_ms" then
        state.transfer_fade_out_ms =
          tonumber(value) or 20
      elseif name == "transfer_smart_tail" then
        state.transfer_smart_tail = value == "1"
      elseif name == "transfer_tail_threshold_db" then
        state.transfer_tail_threshold_db =
          clamp(tonumber(value) or -60, -96, -18)
      elseif name == "transfer_tail_max_ms" then
        state.transfer_tail_max_ms =
          clamp(tonumber(value) or 5000, 100, 30000)
      elseif name == "transfer_tail_hold_ms" then
        state.transfer_tail_hold_ms =
          clamp(tonumber(value) or 180, 0, 2000)
      elseif name == "transfer_normalize" then
        state.transfer_normalize =
          value == "peak" and "peak"
          or value == "true_peak" and "true_peak"
          or value == "rms_i" and "rms_i"
          or value == "lufs_i" and "lufs_i"
          or "off"
      elseif name == "transfer_normalize_target" then
        state.transfer_normalize_target =
          tonumber(value) or -1
      elseif name == "transfer_insert_after" then
        state.transfer_insert_after = value == "1"
      elseif name == "transfer_open_dir_after" then
        state.transfer_open_dir_after = value == "1"
      elseif name == "transfer_lowercase" then
        state.transfer_lowercase = value == "1"
      elseif name == "transfer_dither" then
        state.transfer_dither = value ~= "0"
      elseif name == "transfer_noise_shaping" then
        state.transfer_noise_shaping = value == "1"
      elseif name == "transfer_preserve_metadata" then
        state.transfer_preserve_metadata = value ~= "0"
      elseif name == "transfer_variants_enabled" then
        state.transfer_variants_enabled = value == "1"
      elseif name == "transfer_variant_pitches" then
        state.transfer_variant_pitches = value or ""
      elseif name == "transfer_variant_rates" then
        state.transfer_variant_rates = value or ""
      elseif name == "transfer_variant_gains" then
        state.transfer_variant_gains = value or ""
      elseif name == "transfer_variant_include_reverse" then
        state.transfer_variant_include_reverse = value == "1"
      elseif name == "transfer_variant_auto_suffix" then
        state.transfer_variant_auto_suffix = value ~= "0"
      elseif name == "theme_preset" then
        local legacy_key =
          "sound" .. "ly"

        if value == legacy_key
          or value == "aether" then
          value = "dark"
        end

        if value == "dark"
          or value == "heritage"
          or value == "custom" then
          state.theme_preset = value
        else
          state.theme_preset = "dark"
        end
      elseif name == "custom_accent_hex" then
        state.custom_accent_hex = value or "#1F6FCC"
      elseif name == "custom_shell_hex" then
        state.custom_shell_hex = value or "#101114"
      elseif name == "language" then
        state.language =
          value == "en" and "en" or "zh"
      elseif name == "folder_browser_open" then
        -- 0.7.22 used a persistent inline tree. The 0.7.23 hover cascade is
        -- transient, so an old saved open state must not start background
        -- work or reserve workspace height.
        state.folder_browser_open = false
      elseif name == "active_folder_path" then
        local configured =
          canonical_source_path(value or "")
        state.root_filter =
          configured ~= "" and configured or nil
      elseif name == "mini_wave_points" then
        local points = tonumber(value) or MINI_WAVE_DEFAULT_POINTS
        state.mini_wave_points =
          points >= MINI_WAVE_MAX_POINTS
          and MINI_WAVE_MAX_POINTS
          or MINI_WAVE_DEFAULT_POINTS
      elseif name == "precache_points" then
        state.precache_points =
          tonumber(value) == 2048 and 2048 or 4096
      elseif name == "multichannel_waveform" then
        state.multichannel_waveform = value ~= "0"
      elseif name == "wave_cache_dir" then
        local configured =
          normalize_slashes(
            trim(value or "")
          )

        state.wave_cache_dir =
          configured ~= ""
            and configured
            or DEFAULT_WAVE_CACHE_DIR
      elseif name == "ui_style" then
        -- 0.6.8 及更早版本迁移。
        state.ui_density =
          value == "compact" and "compact" or "balanced"
      elseif name == "ui_density" then
        if value == "comfortable"
          or value == "balanced"
          or value == "compact" then
          state.ui_density = value
        end
      elseif name == "surface_style" then
        if value == "dark"
          or value == "heritage"
          or value == "custom" then
          state.surface_style = value
        elseif value == "flat"
          or value == "layered"
          or value == "contrast" then
          state.surface_style = "dark"
        end
      elseif name == "wave_scrub_enabled" then
        state.wave_scrub_enabled = value ~= "0"
      elseif name == "loop_selection" then
        state.loop_selection = value ~= "0"
      elseif name == "preview_control_layout" then
        if value == "studio_strip" then
          state.preview_control_layout = value
        elseif value == "full_rack"
          or value == "focus_rack"
          or value == "minimal_rack" then
          -- 0.6.17 将旧控制台统一迁移为较轻量的单行工具条。
          state.preview_control_layout = "studio_strip"
        elseif value == "pro_rack"
          or value == "right_knobs"
          or value == "classic_rack"
          or value == "inline_sliders" then
          state.preview_control_layout = "studio_strip"
        elseif value == "compact_rack"
          or value == "compact_knobs" then
          state.preview_control_layout = "studio_strip"
        end
      elseif name == "bottom_panel_height" then
        state.bottom_panel_height =
          tonumber(value) or 330
      elseif name == "preview_channel_mode" then
        if value == "left"
          or value == "right"
          or value == "mono"
          or value == "original" then
          state.preview_channel_mode = value
        end
      elseif name == "loudness_match" then
        state.loudness_match = value == "1"
      elseif name == "loudness_target_db" then
        state.loudness_target_db =
          tonumber(value) or -18
      elseif name == "transient_threshold" then
        state.transient_threshold =
          tonumber(value) or 0.24
      elseif name == "transient_min_gap_ms" then
        state.transient_min_gap_ms =
          tonumber(value) or 140
      elseif name == "transient_pre_ms" then
        state.transient_pre_ms =
          tonumber(value) or 20
      elseif name == "transient_post_ms" then
        state.transient_post_ms =
          tonumber(value) or 180
      elseif name == "transient_smoothing_ms" then
        state.transient_smoothing_ms =
          tonumber(value) or 8
      elseif name == "transient_max_regions" then
        state.transient_max_regions =
          tonumber(value) or 64
      elseif name == "transient_replace_existing" then
        state.transient_replace_existing =
          value ~= "0"
      elseif name == "show_loudness_metrics" then
        state.show_loudness_metrics =
          value ~= "0"
      elseif name == "loudness_show_i" then
        state.loudness_show_i = value ~= "0"
      elseif name == "loudness_show_m" then
        state.loudness_show_m = value ~= "0"
      elseif name == "loudness_show_s" then
        state.loudness_show_s = value == "1"
      elseif name == "loudness_show_tp" then
        state.loudness_show_tp = value ~= "0"
      elseif name == "waveform_hex" then
        state.waveform_hex = value or "#D7D8DA"
      elseif name == "waveform_selected_hex" then
        state.waveform_selected_hex = value or "#EAF3FF"
      elseif name == "waveform_played_hex" then
        state.waveform_played_hex = value or "#8FB8D8"
      elseif name == "waveform_marked_hex" then
        state.waveform_marked_hex = value or "#F0C85A"
      elseif name == "played_text_hex" then
        state.played_text_hex = value or "#F0C85A"
      elseif name == "played_text_enabled" then
        state.played_text_enabled = value ~= "0"
      elseif name == "played_waveform_enabled" then
        state.played_waveform_enabled = value == "1"
      elseif name == "restore_played_on_start" then
        state.restore_played_on_start = value == "1"
      elseif name == "artwork_enabled" then
        state.artwork_enabled = value ~= "0"
      elseif name == "inspector_artwork_pinned" then
        state.inspector_artwork_pinned = value ~= "0"
      elseif name == "selection_hex" then
        state.selection_hex = value or "#2789E9"
      elseif name == "playhead_hex" then
        state.playhead_hex = value or "#50E36D"
      elseif name == "region_hex" then
        state.region_hex = value or "#E2B764"
      elseif name:match("^sidebar_section_") then
        local key =
          name:gsub("^sidebar_section_", "")

        if state.sidebar_sections[key] ~= nil then
          state.sidebar_sections[key] = value ~= "0"
        end
      elseif name == "sidebar_visible" then
        state.sidebar_visible = value == "1"
      elseif name == "inspector_visible" then
        state.inspector_visible = value == "1"
      elseif name == "inspector_width" then
        state.inspector_width =
          tonumber(value) or INSPECTOR_DEFAULT_W
      elseif name == "active_collection_id" then
        state.active_collection_id =
          value ~= "" and value or nil
      elseif name == "status_filter" then
        state.status_filter =
          value ~= "" and value or nil
      elseif name:match("^column_visible_") then
        local key = name:gsub("^column_visible_", "")

        if state.column_visible[key] ~= nil then
          state.column_visible[key] = value == "1"
        end
      elseif name:match("^column_width_") then
        local key = name:gsub("^column_width_", "")

        if state.column_widths[key] ~= nil then
          local loaded_width =
            tonumber(value) or state.column_widths[key]

          state.column_widths[key] = key == "duration"
            and math.max(104, loaded_width)
            or loaded_width
        end
      end
    end
  end

  file:close()
end

function save_config()
  if state.root_removal_session then return false end
  ensure_dirs()

  local file = atomic_file_writer(CONFIG_FILE)

  if not file then
    set_status("无法保存配置", true)
    return
  end

  write_persistence_schema(file, CONFIG_FILE)
  file:write("version\t", VERSION, "\n")

  for path in pairs(state.favorites) do
    file:write(
      "favorite\t",
      escape_tsv(path),
      "\n"
    )
  end

  for index, path in ipairs(state.recent) do
    if index <= 100 then
      file:write(
        "recent\t",
        escape_tsv(path),
        "\n"
      )
    end
  end

  for path in pairs(state.expanded_folder_nodes) do
    file:write(
      "folder_open\t",
      escape_tsv(path),
      "\n"
    )
  end

  for root_id in pairs(state.expanded_source_folders) do
    file:write(
      "source_open\t",
      escape_tsv(root_id),
      "\n"
    )
  end

  file:write(
    "setting\twatch\t",
    state.watch_enabled and "1" or "0",
    "\n"
  )

  file:write(
    "setting\twatch_interval\t",
    tostring(state.watch_interval or WATCH_INTERVAL),
    "\n"
  )

  file:write(
    "setting\twatch_silent\t",
    state.watch_silent and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tresume_scan_on_start\t",
    state.resume_scan_on_start and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tauto_backup\t",
    state.auto_backup and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tbackup_keep_count\t",
    tostring(state.backup_keep_count or 7),
    "\n"
  )

  file:write(
    "setting\tauto_collect_project_usage\t",
    state.auto_collect_project_usage and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tauto_preview\t",
    state.auto_preview and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tinsert_lowercase\t",
    state.insert_lowercase and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tinsert_prefix\t",
    escape_tsv(state.insert_prefix),
    "\n"
  )

  file:write(
    "setting\tinsert_suffix\t",
    escape_tsv(state.insert_suffix),
    "\n"
  )

  file:write(
    "setting\ttransfer_dir\t",
    escape_tsv(state.transfer_dir or DEFAULT_TRANSFER_DIR),
    "\n"
  )

  file:write(
    "setting\ttransfer_template\t",
    escape_tsv(state.transfer_template or "{name}"),
    "\n"
  )

  file:write(
    "setting\ttransfer_format\t",
    state.transfer_format,
    "\n"
  )

  file:write(
    "setting\ttransfer_sample_rate\t",
    state.transfer_sample_rate,
    "\n"
  )

  file:write(
    "setting\ttransfer_channels\t",
    state.transfer_channels,
    "\n"
  )

  file:write(
    "setting\ttransfer_scope\t",
    state.transfer_scope,
    "\n"
  )

  file:write(
    "setting\ttransfer_collision\t",
    state.transfer_collision,
    "\n"
  )

  file:write(
    "setting\ttransfer_fade_in_ms\t",
    tostring(state.transfer_fade_in_ms),
    "\n"
  )

  file:write(
    "setting\ttransfer_fade_out_ms\t",
    tostring(state.transfer_fade_out_ms),
    "\n"
  )

  file:write(
    "setting\ttransfer_smart_tail\t",
    state.transfer_smart_tail and "1" or "0",
    "\n"
  )

  file:write(
    "setting\ttransfer_tail_threshold_db\t",
    tostring(state.transfer_tail_threshold_db),
    "\n"
  )

  file:write(
    "setting\ttransfer_tail_max_ms\t",
    tostring(state.transfer_tail_max_ms),
    "\n"
  )

  file:write(
    "setting\ttransfer_tail_hold_ms\t",
    tostring(state.transfer_tail_hold_ms),
    "\n"
  )

  file:write(
    "setting\ttransfer_normalize\t",
    state.transfer_normalize,
    "\n"
  )

  file:write(
    "setting\ttransfer_normalize_target\t",
    tostring(state.transfer_normalize_target),
    "\n"
  )

  file:write(
    "setting\ttransfer_insert_after\t",
    state.transfer_insert_after and "1" or "0",
    "\n"
  )

  file:write(
    "setting\ttransfer_open_dir_after\t",
    state.transfer_open_dir_after and "1" or "0",
    "\n"
  )

  file:write(
    "setting\ttransfer_lowercase\t",
    state.transfer_lowercase and "1" or "0",
    "\n"
  )

  file:write(
    "setting\ttransfer_dither\t",
    state.transfer_dither and "1" or "0",
    "\n"
  )

  file:write(
    "setting\ttransfer_noise_shaping\t",
    state.transfer_noise_shaping and "1" or "0",
    "\n"
  )

  file:write(
    "setting\ttransfer_preserve_metadata\t",
    state.transfer_preserve_metadata and "1" or "0",
    "\n"
  )

  file:write(
    "setting\ttransfer_variants_enabled\t",
    state.transfer_variants_enabled and "1" or "0",
    "\n"
  )

  file:write(
    "setting\ttransfer_variant_pitches\t",
    escape_tsv(state.transfer_variant_pitches or ""),
    "\n"
  )

  file:write(
    "setting\ttransfer_variant_rates\t",
    escape_tsv(state.transfer_variant_rates or ""),
    "\n"
  )

  file:write(
    "setting\ttransfer_variant_gains\t",
    escape_tsv(state.transfer_variant_gains or ""),
    "\n"
  )

  file:write(
    "setting\ttransfer_variant_include_reverse\t",
    state.transfer_variant_include_reverse and "1" or "0",
    "\n"
  )

  file:write(
    "setting\ttransfer_variant_auto_suffix\t",
    state.transfer_variant_auto_suffix and "1" or "0",
    "\n"
  )

  file:write(
    "setting\ttheme_preset\t",
    escape_tsv(state.theme_preset),
    "\n"
  )

  file:write(
    "setting\tcustom_accent_hex\t",
    escape_tsv(state.custom_accent_hex),
    "\n"
  )

  file:write(
    "setting\tcustom_shell_hex\t",
    escape_tsv(state.custom_shell_hex),
    "\n"
  )

  file:write(
    "setting\tlanguage\t",
    state.language,
    "\n"
  )

  file:write(
    "setting\tfolder_browser_open\t",
    state.folder_browser_open and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tactive_folder_path\t",
    escape_tsv(state.root_filter or ""),
    "\n"
  )

  file:write(
    "setting\tmini_wave_points\t",
    tostring(state.mini_wave_points),
    "\n"
  )

  file:write(
    "setting\tprecache_points\t",
    tostring(state.precache_points),
    "\n"
  )

  file:write(
    "setting\tmultichannel_waveform\t",
    state.multichannel_waveform and "1" or "0",
    "\n"
  )

  file:write(
    "setting\twave_cache_dir\t",
    escape_tsv(
      state.wave_cache_dir
        or DEFAULT_WAVE_CACHE_DIR
    ),
    "\n"
  )

  file:write(
    "setting\tui_density\t",
    state.ui_density,
    "\n"
  )

  file:write(
    "setting\tsurface_style\t",
    state.surface_style,
    "\n"
  )

  file:write(
    "setting\twave_scrub_enabled\t",
    state.wave_scrub_enabled and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tloop_selection\t",
    state.loop_selection and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tpreview_control_layout\t",
    state.preview_control_layout,
    "\n"
  )

  file:write(
    "setting\tbottom_panel_height\t",
    tostring(state.bottom_panel_height),
    "\n"
  )

  file:write(
    "setting\tpreview_channel_mode\t",
    state.preview_channel_mode == "custom"
      and "original"
      or state.preview_channel_mode,
    "\n"
  )

  file:write(
    "setting\tloudness_match\t",
    state.loudness_match and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tloudness_target_db\t",
    tostring(state.loudness_target_db),
    "\n"
  )

  file:write(
    "setting\ttransient_threshold\t",
    tostring(state.transient_threshold),
    "\n"
  )

  file:write(
    "setting\ttransient_min_gap_ms\t",
    tostring(state.transient_min_gap_ms),
    "\n"
  )

  file:write(
    "setting\ttransient_pre_ms\t",
    tostring(state.transient_pre_ms),
    "\n"
  )

  file:write(
    "setting\ttransient_post_ms\t",
    tostring(state.transient_post_ms),
    "\n"
  )

  file:write(
    "setting\ttransient_smoothing_ms\t",
    tostring(state.transient_smoothing_ms),
    "\n"
  )

  file:write(
    "setting\ttransient_max_regions\t",
    tostring(state.transient_max_regions),
    "\n"
  )

  file:write(
    "setting\ttransient_replace_existing\t",
    state.transient_replace_existing and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tshow_loudness_metrics\t",
    state.show_loudness_metrics and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tloudness_show_i\t",
    state.loudness_show_i and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tloudness_show_m\t",
    state.loudness_show_m and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tloudness_show_s\t",
    state.loudness_show_s and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tloudness_show_tp\t",
    state.loudness_show_tp and "1" or "0",
    "\n"
  )

  file:write(
    "setting\twaveform_hex\t",
    escape_tsv(state.waveform_hex),
    "\n"
  )

  file:write(
    "setting\twaveform_selected_hex\t",
    escape_tsv(state.waveform_selected_hex),
    "\n"
  )

  file:write(
    "setting\twaveform_played_hex\t",
    escape_tsv(state.waveform_played_hex),
    "\n"
  )

  file:write(
    "setting\twaveform_marked_hex\t",
    escape_tsv(state.waveform_marked_hex),
    "\n"
  )

  file:write(
    "setting\tplayed_text_hex\t",
    escape_tsv(state.played_text_hex),
    "\n"
  )

  file:write(
    "setting\tplayed_text_enabled\t",
    state.played_text_enabled and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tplayed_waveform_enabled\t",
    state.played_waveform_enabled and "1" or "0",
    "\n"
  )

  file:write(
    "setting\trestore_played_on_start\t",
    state.restore_played_on_start and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tartwork_enabled\t",
    state.artwork_enabled and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tinspector_artwork_pinned\t",
    state.inspector_artwork_pinned and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tselection_hex\t",
    escape_tsv(state.selection_hex),
    "\n"
  )

  file:write(
    "setting\tplayhead_hex\t",
    escape_tsv(state.playhead_hex),
    "\n"
  )

  file:write(
    "setting\tregion_hex\t",
    escape_tsv(state.region_hex),
    "\n"
  )

  file:write(
    "setting\tsidebar_visible\t",
    state.sidebar_visible and "1" or "0",
    "\n"
  )

  for _, key in ipairs({
    "sounds",
    "libraries",
    "collections",
    "saved_searches",
    "workflow",
    "activity",
  }) do
    file:write(
      "setting\tsidebar_section_",
      key,
      "\t",
      state.sidebar_sections[key] ~= false
        and "1" or "0",
      "\n"
    )
  end

  file:write(
    "setting\tinspector_visible\t",
    state.inspector_visible and "1" or "0",
    "\n"
  )

  file:write(
    "setting\tinspector_width\t",
    tostring(state.inspector_width),
    "\n"
  )

  file:write(
    "setting\tactive_collection_id\t",
    escape_tsv(state.active_collection_id or ""),
    "\n"
  )

  file:write(
    "setting\tstatus_filter\t",
    escape_tsv(state.status_filter or ""),
    "\n"
  )

  for key, visible in pairs(state.column_visible) do
    file:write(
      "setting\tcolumn_visible_",
      key,
      "\t",
      visible and "1" or "0",
      "\n"
    )
  end

  for key, width in pairs(state.column_widths) do
    file:write(
      "setting\tcolumn_width_",
      key,
      "\t",
      tostring(width),
      "\n"
    )
  end

  if not file:close() then
    set_status("无法保存配置", true)
    return false
  end
  state.config_dirty = false
  return true
end
