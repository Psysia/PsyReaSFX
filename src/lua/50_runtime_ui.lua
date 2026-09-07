function load_database()
  local file = io.open(DATABASE_FILE, "rb")

  if not file then
    return
  end

  local header_line = file:read("*l")

  if not header_line then
    file:close()
    return
  end

  local headers = split_tsv(header_line)
  state.database_generation = 0

  if is_persistence_schema_fields(headers) then
    local generation, generation_error =
      persistence_schema_generation(headers)
    if generation == nil then
      file:close()
      state.persistence_read_only = true
      state.persistence_read_only_reason =
        "索引快照代次无效：" .. tostring(generation_error)
      set_status("索引快照代次无效，已进入只读保护", true)
      return
    end
    state.database_generation = generation
    header_line = file:read("*l")

    if not header_line then
      file:close()
      return
    end

    headers = split_tsv(header_line)
  end

  local ignored = 0

  for line in file:lines() do
    local values = split_tsv(line)
    local asset = database_asset_from_values(headers, values)
    local raw_path = ""
    for index, field in ipairs(headers) do
      if field == "path" then
        raw_path = values[index] or ""
        break
      end
    end

    if asset then
      add_or_update_asset(asset)
    elseif raw_path ~= "" then
      ignored = ignored + 1
    end
  end

  file:close()

  local journal_ok = replay_database_journal()

  if ignored > 0 then
    mark_database_snapshot_dirty()
    if journal_ok then
      set_status(
        string.format(
          "已从索引自动忽略 %d 个系统元数据文件",
          ignored
        )
      )
    end
  end
end

function database_asset_from_values(headers, values)
  local asset = {}
  for index, field in ipairs(headers or {}) do
    asset[field] = values[index] or ""
  end
  if not asset.path or asset.path == ""
    or is_ignored_media_path(asset.path) then
    return nil
  end
  asset.duration = tonumber(asset.duration) or 0
  asset.channels = tonumber(asset.channels) or 0
  asset.sample_rate = tonumber(asset.sample_rate) or 0
  asset.bit_depth = tonumber(asset.bit_depth) or 0
  asset.size = tonumber(asset.size) or 0
  asset.workflow_status = WORKFLOW_STATUS[asset.workflow_status]
    and asset.workflow_status or "none"
  asset.marked = asset.marked == "1" or asset.marked == "true"
  asset.preview_count = tonumber(asset.preview_count) or 0
  asset.last_previewed = tonumber(asset.last_previewed) or 0
  asset.indexed = asset.indexed == "1" or asset.indexed == "true"
    or asset.duration > 0
  asset.ready = asset.ready == "1" or asset.ready == "true"
  asset.used_count = tonumber(asset.used_count) or 0
  asset.last_used = tonumber(asset.last_used) or 0
  asset.fingerprint = tostring(asset.fingerprint or "")
  asset.fingerprint_size = tonumber(asset.fingerprint_size) or 0
  asset.fingerprint_version = tostring(asset.fingerprint_version or "")
  asset.fingerprint_modified = tostring(asset.fingerprint_modified or "")
  asset.fingerprint_stat_source = tostring(asset.fingerprint_stat_source or "")
  if asset.fingerprint ~= ""
    and not fingerprint_metadata_is_compatible(asset) then
    clear_asset_fingerprint(asset)
    mark_database_snapshot_dirty()
  end
  asset.last_seen = tonumber(asset.last_seen) or 0
  ensure_asset_identity(asset)
  return asset
end

function database_asset_values(asset)
  local values = {}
  for _, field in ipairs(DB_FIELDS) do
    local value = asset and asset[field] or ""
    if field == "indexed" then
      value = asset and asset.indexed and "1" or "0"
    elseif field == "ready" then
      value = asset and asset.ready and "1" or "0"
    elseif field == "marked" then
      value = asset and asset.marked and "1" or "0"
    end
    values[#values + 1] = value
  end
  return values
end

function mark_asset_database_change(asset)
  if not asset or not asset.path or asset.path == "" then
    return false
  end
  state.db_dirty = true
  return record_asset_change(
    state.database_changes,
    path_key(asset.path),
    "upsert",
    database_asset_values(asset)
  )
end

function mark_asset_database_delete(asset_or_path)
  local path = type(asset_or_path) == "table"
    and asset_or_path.path or asset_or_path
  path = tostring(path or "")
  if path == "" then return false end
  local values = database_asset_values(nil)
  for index, field in ipairs(DB_FIELDS) do
    if field == "path" then
      values[index] = path
      break
    end
  end
  state.db_dirty = true
  return record_asset_change(
    state.database_changes,
    path_key(path),
    "delete",
    values
  )
end

function mark_database_snapshot_dirty()
  state.db_dirty = true
  return require_asset_snapshot(state.database_changes)
end

function save_database_journal()
  ensure_dirs()
  local entries = ordered_asset_changes(state.database_changes)
  if #entries == 0 then return save_database() end
  local written, write_error = write_asset_journal_atomic(
    DATABASE_JOURNAL_FILE,
    state.database_generation or 0,
    DB_FIELDS,
    entries,
    atomic_file_writer
  )
  if not written then
    set_status(
      "无法保存素材增量日志：" .. tostring(write_error),
      true
    )
    return false
  end
  state.db_dirty = false
  return true
end

function save_database_changes()
  local changes = state.database_changes
  if asset_changes_require_snapshot(
    changes,
    reaper.file_exists(DATABASE_FILE),
    DATABASE_JOURNAL_COMPACT_COUNT
  ) then
    return save_database()
  end
  return save_database_journal()
end

function replace_database_asset(asset)
  local key = path_key(asset.path)
  local existing = state.by_path[key]
  if not existing then
    add_or_update_asset(asset)
    return
  end
  for _, field in ipairs(DB_FIELDS) do
    existing[field] = asset[field]
  end
  existing.artwork_checked = tostring(existing.artwork_path or "") ~= ""
  existing._search_blob = nil
  existing._sort_path_value = nil
end

function replay_database_journal()
  local probe = io.open(DATABASE_JOURNAL_FILE, "rb")
  if not probe then return true end
  probe:close()

  local entries, journal_error = read_asset_journal(
    DATABASE_JOURNAL_FILE,
    state.database_generation or 0,
    DB_FIELDS
  )
  if not entries then
    if journal_error == "generation_mismatch" then
      os.remove(DATABASE_JOURNAL_FILE)
      return true
    end
    state.persistence_read_only = true
    state.persistence_read_only_reason =
      "素材增量日志无法安全重放：" .. tostring(journal_error)
    set_status("素材增量日志损坏，已进入只读保护", true)
    return false
  end

  local path_field = nil
  for index, field in ipairs(DB_FIELDS) do
    if field == "path" then path_field = index break end
  end
  if not path_field then return false end

  local actions = {}
  for _, entry in ipairs(entries) do
    local path = tostring(entry.values[path_field] or "")
    if path == "" or is_ignored_media_path(path) then
      state.persistence_read_only = true
      state.persistence_read_only_reason =
        "素材增量日志包含无效路径"
      set_status("素材增量日志损坏，已进入只读保护", true)
      return false
    end
    local action = {
      op = entry.op,
      key = path_key(path),
      values = entry.values,
    }
    if entry.op == "upsert" then
      action.asset = database_asset_from_values(DB_FIELDS, entry.values)
      if not action.asset then
        state.persistence_read_only = true
        state.persistence_read_only_reason =
          "素材增量日志包含无效素材"
        set_status("素材增量日志损坏，已进入只读保护", true)
        return false
      end
    end
    actions[#actions + 1] = action
  end

  for _, action in ipairs(actions) do
    local key = action.key
    if action.op == "delete" then
      state.by_path[key] = nil
      state.favorites[key] = nil
      state.selected_set[key] = nil
    else
      replace_database_asset(action.asset)
    end
    record_asset_change(
      state.database_changes,
      action.key,
      action.op,
      action.op == "upsert"
        and database_asset_values(action.asset)
        or action.values
    )
  end
  if #actions > 0 then
    rebuild_assets()
    if (state.database_changes.count or 0)
      >= DATABASE_JOURNAL_COMPACT_COUNT then
      state.db_dirty = true
    end
  end
  return true
end

function save_database()
  ensure_dirs()

  local file = atomic_file_writer(DATABASE_FILE)

  if not file then
    set_status("无法保存索引", true)
    return
  end

  local next_generation =
    math.floor(tonumber(state.database_generation) or 0) + 1
  file:write(
    persistence_schema_header(
      "database",
      PERSISTENCE_SCHEMAS[DATABASE_FILE].version,
      next_generation
    )
  )
  file:write(table.concat(DB_FIELDS, "\t"), "\n")

  local ordered = state.database_ordered_assets

  if not ordered then
    ordered = {}
    for _, asset in ipairs(state.assets) do
      ordered[#ordered + 1] = asset
      asset_path_sort_key(asset)
    end
    table.sort(
      ordered,
      function(a, b)
        return asset_path_sort_key(a) < asset_path_sort_key(b)
      end
    )
    state.database_ordered_assets = ordered
  end

  for _, asset in ipairs(ordered) do
    local fields = {}

    for _, field in ipairs(DB_FIELDS) do
      local value = asset[field]

      if field == "indexed" then
        value = asset.indexed and "1" or "0"
      elseif field == "ready" then
        value = asset.ready and "1" or "0"
      elseif field == "marked" then
        value = asset.marked and "1" or "0"
      end

      fields[#fields + 1] =
        escape_tsv(value)
    end

    file:write(
      table.concat(fields, "\t"),
      "\n"
    )
  end

  if not file:close() then
    set_status("无法保存索引", true)
    return false
  end
  state.database_generation = next_generation
  clear_asset_changes(state.database_changes)
  os.remove(DATABASE_JOURNAL_FILE)
  state.db_dirty = false
  return true
end


----------------------------------------------------------------
-- Collections, project bins and saved searches (0.5)
----------------------------------------------------------------

function new_model_id(prefix, seed)
  return prefix
    .. "_"
    .. fnv1a(
      tostring(seed or "")
        .. "|"
        .. tostring(reaper.time_precise())
        .. "|"
        .. tostring(os.time())
        .. "|"
        .. tostring(math.random())
    )
end

function rebuild_collection_index()
  state.collection_by_id = {}

  for _, collection in ipairs(state.collections) do
    collection.items = collection.items or {}
    collection.order = collection.order or {}

    if collection.count == nil then
      local count = 0

      for _ in pairs(collection.items) do
        count = count + 1
      end

      collection.count = count
    end

    state.collection_by_id[collection.id] = collection
  end

  if state.active_collection_id
    and not state.collection_by_id[
      state.active_collection_id
    ] then
    state.active_collection_id = nil
  end
end

function collection_item_count(collection)
  return collection
    and tonumber(collection.count)
    or 0
end

function current_project_identity()
  local ok, project, filename = pcall(reaper.EnumProjects, -1, "")

  if not ok then
    return PROJ, "", "", "未保存工程"
  end

  filename = normalize_slashes(trim(filename or ""))
  local key = filename ~= "" and path_key(filename) or ""
  local name = filename ~= ""
    and strip_extension(basename(filename))
    or "未保存工程"

  return project or PROJ, filename, key, name
end

function refresh_current_project_binding()
  local _, path, key, name = current_project_identity()
  state.current_project_path = path
  state.current_project_key = key
  state.current_project_name = name
  state.current_project_bin_id = nil

  if key == "" then
    return nil
  end

  for _, collection in ipairs(state.collections or {}) do
    if collection.kind == "project"
      and path_key(collection.project_path or "") == key then
      state.current_project_bin_id = collection.id
      return collection
    end
  end

  return nil
end

function poll_current_project_binding()
  local now = reaper.time_precise()

  if now < (state.next_project_refresh or 0) then
    return
  end

  state.next_project_refresh = now + 1.0
  local previous_key = state.current_project_key
  refresh_current_project_binding()

  if previous_key ~= state.current_project_key
    and state.view == "project_used" then
    state.results_dirty = true
  end
end

function project_usage_bucket(project_path, create)
  local project_key = path_key(project_path or "")

  if project_key == "" then
    return nil
  end

  local bucket = state.project_usage[project_key]

  if not bucket and create then
    bucket = {
      path = normalize_slashes(project_path),
      assets = {},
    }
    state.project_usage[project_key] = bucket
  end

  return bucket
end

function load_project_usage()
  state.project_usage = {}
  local file = io.open(PROJECT_USAGE_FILE, "rb")

  if not file then
    return
  end

  for line in file:lines() do
    local fields = split_tsv(line)

    if fields[1] == "usage"
      and fields[2] and fields[2] ~= ""
      and fields[3] and fields[3] ~= "" then
      local bucket = project_usage_bucket(fields[2], true)
      local asset_path = normalize_slashes(fields[3])
      bucket.assets[path_key(asset_path)] = {
        path = asset_path,
        count = tonumber(fields[4]) or 1,
        last_used = tonumber(fields[5]) or 0,
        action = fields[6] or "insert",
      }
    end
  end

  file:close()
  state.project_usage_dirty = false
end

function save_project_usage()
  ensure_dirs()
  local file = atomic_file_writer(PROJECT_USAGE_FILE)

  if not file then
    set_status("无法保存工程使用记录", true)
    return false
  end

  write_persistence_schema(file, PROJECT_USAGE_FILE)

  local project_keys = {}
  for key in pairs(state.project_usage) do
    project_keys[#project_keys + 1] = key
  end
  table.sort(project_keys)

  for _, project_key in ipairs(project_keys) do
    local bucket = state.project_usage[project_key]
    local asset_keys = {}
    for key in pairs(bucket.assets or {}) do
      asset_keys[#asset_keys + 1] = key
    end
    table.sort(asset_keys)

    for _, asset_key in ipairs(asset_keys) do
      local entry = bucket.assets[asset_key]
      file:write(
        "usage\t",
        escape_tsv(bucket.path or ""), "\t",
        escape_tsv(entry.path or ""), "\t",
        tostring(entry.count or 1), "\t",
        tostring(entry.last_used or 0), "\t",
        escape_tsv(entry.action or "insert"), "\n"
      )
    end
  end

  if not file:close() then
    set_status("无法保存工程使用记录", true)
    return false
  end

  state.project_usage_dirty = false
  return true
end

function bind_project_bin(collection, project_path)
  if not collection or collection.kind ~= "project" then
    return false
  end

  project_path = normalize_slashes(trim(project_path or state.current_project_path))

  if project_path == "" then
    set_status("请先保存当前 REAPER 工程，再绑定项目素材箱", true)
    return false
  end

  collection.project_path = project_path
  state.collections_dirty = true
  refresh_current_project_binding()
  set_status("已将项目素材箱绑定到：" .. basename(project_path))
  return true
end

function ensure_current_project_bin(create_if_missing)
  local collection = refresh_current_project_binding()

  if collection or not create_if_missing then
    return collection
  end

  if state.current_project_key == "" then
    return nil
  end

  collection = {
    id = new_model_id("collection", state.current_project_path),
    name = state.current_project_name,
    kind = "project",
    project_path = state.current_project_path,
    items = {},
    order = {},
    count = 0,
  }
  state.collections[#state.collections + 1] = collection
  state.collection_by_id[collection.id] = collection
  state.current_project_bin_id = collection.id
  state.collections_dirty = true
  return collection
end

function record_project_usage(asset, action)
  if not asset then
    return
  end

  refresh_current_project_binding()

  if state.current_project_key == "" then
    return
  end

  local bucket = project_usage_bucket(state.current_project_path, true)
  local asset_key = path_key(asset.path)
  local entry = bucket.assets[asset_key]

  if not entry then
    entry = { path = asset.path, count = 0, last_used = 0, action = action or "insert" }
    bucket.assets[asset_key] = entry
  end

  entry.path = asset.path
  entry.count = (tonumber(entry.count) or 0) + 1
  entry.last_used = os.time()
  entry.action = action or "insert"
  state.project_usage_dirty = true

  if state.auto_collect_project_usage then
    local collection = ensure_current_project_bin(true)
    if collection and not collection.items[asset_key] then
      collection.items[asset_key] = asset.path
      collection.order[#collection.order + 1] = asset.path
      collection.count = (collection.count or 0) + 1
      state.collections_dirty = true
    end
  end

  if state.view == "project_used" then
    state.results_dirty = true
  end
end


function load_collections()
  state.collections = {}
  state.collection_by_id = {}

  local file = io.open(COLLECTIONS_FILE, "rb")

  if not file then
    return
  end

  for line in file:lines() do
    local fields = split_tsv(line)
    local kind = fields[1]

    if kind == "collection"
      and fields[2]
      and fields[3] then

      local collection = {
        id = fields[2],
        name = fields[3],
        kind =
          fields[4] == "project"
          and "project"
          or "playlist",
        project_path = normalize_slashes(fields[5] or ""),
        items = {},
        order = {},
        count = 0,
      }

      state.collections[#state.collections + 1] =
        collection

      state.collection_by_id[collection.id] =
        collection
    elseif kind == "item"
      and fields[2]
      and fields[3] then

      local collection =
        state.collection_by_id[fields[2]]

      if collection then
        local path = normalize_slashes(fields[3])
        local key = path_key(path)

        if not collection.items[key] then
          collection.items[key] = path
          collection.order[#collection.order + 1] =
            path
          collection.count =
            (collection.count or 0) + 1
        end
      end
    end
  end

  file:close()
  rebuild_collection_index()
end

function save_collections()
  ensure_dirs()

  local file = atomic_file_writer(COLLECTIONS_FILE)

  if not file then
    set_status("无法保存播放列表", true)
    return
  end

  write_persistence_schema(file, COLLECTIONS_FILE)

  for _, collection in ipairs(state.collections) do
    file:write(
      "collection\t",
      escape_tsv(collection.id),
      "\t",
      escape_tsv(collection.name),
      "\t",
      escape_tsv(collection.kind or "playlist"),
      "\t",
      escape_tsv(collection.project_path or ""),
      "\n"
    )

    for _, path in ipairs(collection.order or {}) do
      if collection.items[path_key(path)] then
        file:write(
          "item\t",
          escape_tsv(collection.id),
          "\t",
          escape_tsv(path),
          "\n"
        )
      end
    end
  end

  if not file:close() then
    set_status("无法保存播放列表", true)
    return false
  end
  state.collections_dirty = false
  return true
end

function create_collection(kind)
  kind =
    kind == "project"
    and "project"
    or "playlist"

  local title =
    kind == "project"
    and "新建项目素材箱"
    or "新建播放列表"

  local default_name =
    kind == "project"
    and "当前项目"
    or "新播放列表"

  local ok, name =
    reaper.GetUserInputs(
      title,
      1,
      "名称:",
      default_name
    )

  name = trim(name)

  if not ok or name == "" then
    return nil
  end

  local collection = {
    id = new_model_id("collection", name),
    name = name,
    kind = kind,
    project_path = "",
    items = {},
    order = {},
    count = 0,
  }

  if kind == "project" then
    local _, project_path = current_project_identity()
    collection.project_path = project_path or ""
  end

  state.collections[#state.collections + 1] =
    collection

  state.collection_by_id[collection.id] =
    collection

  -- 新建集合不再自动切换到空白集合视图。
  -- 保留当前搜索和音效库结果，避免用户误以为原始素材库消失。
  local current_selection = selected_assets()
  local added = 0

  if #current_selection > 0 then
    added = add_assets_to_collection(
      collection,
      current_selection
    )
  end

  state.collections_dirty = true
  state.config_dirty = true
  refresh_current_project_binding()

  local type_label = translate_ui_text(
    kind == "project"
      and "项目素材箱"
      or "播放列表"
  )

  if added > 0 then
    set_status(
      string.format(
        "已新建%s“%s”，并加入 %d 个当前所选素材；可在左侧点击打开",
        type_label,
        name,
        added
      )
    )
  else
    set_status(
      string.format(
        "已新建%s“%s”；当前列表保持不变，可在左侧点击打开",
        type_label,
        name
      )
    )
  end

  return collection
end

function rename_collection(collection)
  if not collection then
    return
  end

  local ok, name =
    reaper.GetUserInputs(
      "重命名集合",
      1,
      "名称:",
      collection.name
    )

  name = trim(name)

  if ok and name ~= "" then
    collection.name = name
    state.collections_dirty = true
    set_status("已重命名为：" .. name)
  end
end

function delete_collection(collection)
  if not collection then
    return
  end

  local answer =
    reaper.MB(
      "删除 PsyReaSFX 集合？\n\n"
        .. collection.name
        .. "\n\n不会删除磁盘音频文件。",
      SCRIPT_NAME,
      4
    )

  if answer ~= 6 then
    return
  end

  local kept = {}

  for _, current in ipairs(state.collections) do
    if current.id ~= collection.id then
      kept[#kept + 1] = current
    end
  end

  state.collections = kept
  state.collection_by_id[collection.id] = nil

  if state.active_collection_id
    == collection.id then
    state.active_collection_id = nil
    state.results_dirty = true
  end

  state.collections_dirty = true
  state.config_dirty = true
  set_status("已删除集合：" .. collection.name)
end

function add_assets_to_collection(
  collection,
  assets
)
  if not collection or not assets then
    return 0
  end

  local added = 0

  for _, asset in ipairs(assets) do
    local key = path_key(asset.path)

    if not collection.items[key] then
      collection.items[key] = asset.path
      collection.order[#collection.order + 1] =
        asset.path
      collection.count =
        (collection.count or 0) + 1
      added = added + 1
    end
  end

  if added > 0 then
    state.collections_dirty = true

    if state.active_collection_id
      == collection.id then
      state.results_dirty = true
    end

    set_status(
      string.format(
        "已向“%s”加入 %d 个素材",
        collection.name,
        added
      )
    )
  end

  return added
end

function remove_assets_from_collection(
  collection,
  assets
)
  if not collection or not assets then
    return 0
  end

  local removed = 0

  for _, asset in ipairs(assets) do
    local key = path_key(asset.path)

    if collection.items[key] then
      collection.items[key] = nil
      collection.count =
        math.max(
          0,
          (collection.count or 0) - 1
        )
      removed = removed + 1
    end
  end

  if removed > 0 then
    local order = {}

    for _, path in ipairs(collection.order) do
      if collection.items[path_key(path)] then
        order[#order + 1] = path
      end
    end

    collection.order = order
    state.collections_dirty = true
    state.results_dirty = true

    set_status(
      string.format(
        "已从“%s”移除 %d 个素材",
        collection.name,
        removed
      )
    )
  end

  return removed
end

function load_saved_searches()
  state.saved_searches = {}

  local file = io.open(SAVED_SEARCHES_FILE, "rb")

  if not file then
    return
  end

  for line in file:lines() do
    local fields = split_tsv(line)

    if fields[1] == "search"
      and fields[2]
      and fields[3] then

      state.saved_searches[
        #state.saved_searches + 1
      ] = {
        id = fields[2],
        name = fields[3],
        query = fields[4] or "",
        view = fields[5] or "all",
        root = fields[6] or "",
        sort_mode = fields[7] or "name",
        sort_desc = fields[8] == "1",
        status_filter =
          fields[9] ~= ""
          and fields[9]
          or nil,
        collection_id =
          fields[10] ~= ""
          and fields[10]
          or nil,
        library_id =
          fields[11] ~= ""
          and fields[11]
          or nil,
      }
    end
  end

  file:close()
end

function save_saved_searches()
  ensure_dirs()

  local file = atomic_file_writer(SAVED_SEARCHES_FILE)

  if not file then
    set_status("无法保存搜索条件", true)
    return
  end

  write_persistence_schema(file, SAVED_SEARCHES_FILE)

  for _, saved in ipairs(state.saved_searches) do
    file:write(
      "search\t",
      escape_tsv(saved.id),
      "\t",
      escape_tsv(saved.name),
      "\t",
      escape_tsv(saved.query or ""),
      "\t",
      escape_tsv(saved.view or "all"),
      "\t",
      escape_tsv(saved.root or ""),
      "\t",
      escape_tsv(saved.sort_mode or "name"),
      "\t",
      saved.sort_desc and "1" or "0",
      "\t",
      escape_tsv(saved.status_filter or ""),
      "\t",
      escape_tsv(saved.collection_id or ""),
      "\t",
      escape_tsv(saved.library_id or ""),
      "\n"
    )
  end

  if not file:close() then
    set_status("无法保存搜索条件", true)
    return false
  end
  state.searches_dirty = false
  return true
end

function save_current_search()
  local ok, name =
    reaper.GetUserInputs(
      "保存当前搜索",
      1,
      "名称:",
      trim(state.search) ~= ""
        and compact(state.search, 30)
        or "新搜索"
    )

  name = trim(name)

  if not ok or name == "" then
    return
  end

  state.saved_searches[
    #state.saved_searches + 1
  ] = {
    id = new_model_id("search", name),
    name = name,
    query = state.search,
    view = state.view,
    root = state.root_filter or "",
    library_id = state.library_filter_id,
    sort_mode = state.sort_mode,
    sort_desc = state.sort_desc,
    status_filter = state.status_filter,
    collection_id = state.active_collection_id,
  }

  state.searches_dirty = true
  set_status("已保存搜索：" .. name)
end

function activate_saved_search(saved)
  if not saved then
    return
  end

  state.search = saved.query or ""
  state.view = saved.view or "all"
  state.root_filter =
    saved.root ~= ""
    and saved.root
    or nil
  state.library_filter_id =
    saved.library_id
      and state.library_by_id[saved.library_id]
      and saved.library_id
      or nil
  state.sort_mode = saved.sort_mode or "name"
  state.sort_desc = saved.sort_desc == true
  state.status_filter = saved.status_filter

  if saved.collection_id
    and state.collection_by_id[
      saved.collection_id
    ] then
    state.active_collection_id =
      saved.collection_id
  else
    state.active_collection_id = nil
  end

  state.selected_set = {}
  state.selected_index = 0
  state.selected_path = nil
  state.selection_anchor = 0
  state.results_dirty = true
  set_status("已载入搜索：" .. saved.name)
end

function rename_saved_search(saved)
  if not saved then
    return
  end

  local ok, name =
    reaper.GetUserInputs(
      "重命名保存搜索",
      1,
      "名称:",
      saved.name
    )

  name = trim(name)

  if ok and name ~= "" then
    saved.name = name
    state.searches_dirty = true
  end
end

function delete_saved_search(saved)
  if not saved then
    return
  end

  local kept = {}

  for _, current in ipairs(state.saved_searches) do
    if current.id ~= saved.id then
      kept[#kept + 1] = current
    end
  end

  state.saved_searches = kept
  state.searches_dirty = true
  set_status("已删除保存搜索：" .. saved.name)
end

function load_history()
  local file = io.open(HISTORY_FILE, "rb")

  if not file then
    return
  end

  for line in file:lines() do
    local fields = split_tsv(line)

    if fields[1] == "preview"
      and fields[2] then

      local asset =
        state.by_path[path_key(fields[2])]

      if asset then
        asset.preview_count =
          tonumber(fields[3]) or 0
        asset.last_previewed =
          tonumber(fields[4]) or 0
        ensure_asset_identity(asset)
        state.preview_history_assets[asset.asset_id] = asset
      end
    end
  end

  file:close()
end

function save_history()
  ensure_dirs()

  local file = atomic_file_writer(HISTORY_FILE)

  if not file then
    set_status("无法保存试听历史", true)
    return
  end

  write_persistence_schema(file, HISTORY_FILE)

  local history_assets = ordered_preview_history_assets(
    state.preview_history_assets,
    state.by_path,
    path_key,
    asset_path_sort_key
  )
  for _, asset in ipairs(history_assets) do
    file:write(
      "preview\t",
      escape_tsv(asset.path),
      "\t",
      tostring(asset.preview_count or 0),
      "\t",
      tostring(asset.last_previewed or 0),
      "\n"
    )
  end

  if not file:close() then
    set_status("无法保存试听历史", true)
    return false
  end
  state.history_dirty = false
  return true
end

function workflow_label(status)
  local definition =
    WORKFLOW_STATUS[status or "none"]
    or WORKFLOW_STATUS.none

  return definition.label
end

function set_workflow_status(
  assets,
  status
)
  status =
    WORKFLOW_STATUS[status]
    and status
    or "none"

  local count = 0

  for _, asset in ipairs(assets or {}) do
    if asset.workflow_status ~= status then
      asset.workflow_status = status
      mark_asset_database_change(asset)
      count = count + 1
    end
  end

  if count > 0 then
    state.results_dirty = true
    set_status(
      string.format(
        "已将 %d 个素材标记为“%s”",
        count,
        workflow_label(status)
      )
    )
  end
end

function record_preview_history(asset)
  if not asset then
    return
  end

  asset.preview_count =
    (tonumber(asset.preview_count) or 0) + 1
  asset.last_previewed = os.time()
  ensure_asset_identity(asset)
  state.preview_history_assets[asset.asset_id] = asset
  local played_key =
    path_key(asset.path)

  if not state.session_played[played_key] then
    state.session_played[played_key] = true
    state.session_played_dirty = true
  end

  state.history_dirty = true

  if state.view == "previewed"
    or state.sort_mode == "previewed" then
    state.results_dirty = true
  end
end

----------------------------------------------------------------
-- Artwork discovery and image cache
----------------------------------------------------------------

local ARTWORK_NAME_PRIORITY = {
  ["artwork.jpg"] = 1,
  ["artwork.jpeg"] = 1,
  ["artwork.png"] = 1,
  ["cover.jpg"] = 2,
  ["cover.jpeg"] = 2,
  ["cover.png"] = 2,
  ["folder.jpg"] = 3,
  ["folder.jpeg"] = 3,
  ["folder.png"] = 3,
  ["front.jpg"] = 4,
  ["front.jpeg"] = 4,
  ["front.png"] = 4,
  ["album.jpg"] = 5,
  ["album.jpeg"] = 5,
  ["album.png"] = 5,
  ["thumbnail.jpg"] = 6,
  ["thumbnail.jpeg"] = 6,
  ["thumbnail.png"] = 6,
  ["library.jpg"] = 7,
  ["library.jpeg"] = 7,
  ["library.png"] = 7,
  ["product.jpg"] = 8,
  ["product.jpeg"] = 8,
  ["product.png"] = 8,
  ["preview.jpg"] = 9,
  ["preview.jpeg"] = 9,
  ["preview.png"] = 9,
}

local ARTWORK_SUBFOLDER_NAMES = {
  artwork = true,
  artworks = true,
  art = true,
  cover = true,
  covers = true,
  image = true,
  images = true,
  thumbnail = true,
  thumbnails = true,
  graphics = true,
  ["album art"] = true,
  ["product art"] = true,
  ["product artwork"] = true,
  ["product images"] = true,
  ["封面"] = true,
  ["图片"] = true,
  ["图像"] = true,
}

ARTWORK_DISCOVERY_VERSION = 3

function normalized_artwork_folder_name(name)
  local value = safe_lower(trim(name or ""))

  -- Commercial libraries commonly prefix deliverable folders with an
  -- ordering number: "1. Audio", "2. Artwork", "03_Covers", etc.
  value = value:gsub("^%d+%s*", "")
  value = value:gsub("^%p+%s*", "")
  value = value:gsub("[_%-%.]+", " ")
  value = value:gsub("%s+", " ")

  return trim(value)
end

function artwork_folder_priority(name)
  local label = normalized_artwork_folder_name(name)

  if ARTWORK_SUBFOLDER_NAMES[label] then
    return label == "artwork" and 1
      or label == "artworks" and 1
      or label == "art" and 2
      or label:find("cover", 1, true) and 3
      or label:find("image", 1, true) and 4
      or label:find("thumbnail", 1, true) and 5
      or 6
  end

  if label:find("artwork", 1, true)
    or label:find("封面", 1, true) then
    return 1
  elseif label:find("cover", 1, true) then
    return 3
  elseif label:find("product image", 1, true)
    or label:find("album art", 1, true)
    or label:find("图片", 1, true)
    or label:find("图像", 1, true) then
    return 4
  elseif label:find("thumbnail", 1, true) then
    return 5
  end

  return nil
end

function is_artwork_file(filename)
  local ext = extension(filename):lower()

  return ext == "jpg"
    or ext == "jpeg"
    or ext == "png"
    or ext == "bmp"
    or ext == "tga"
end

function image_u16_be(data, offset)
  local a, b = data:byte(offset, offset + 1)

  if not a or not b then
    return nil
  end

  return a * 256 + b
end

function image_u16_le(data, offset)
  local a, b = data:byte(offset, offset + 1)

  if not a or not b then
    return nil
  end

  return a + b * 256
end

function image_u32_be(data, offset)
  local a, b, c, d = data:byte(offset, offset + 3)

  if not a or not b or not c or not d then
    return nil
  end

  return ((a * 256 + b) * 256 + c) * 256 + d
end

function image_u32_le(data, offset)
  local a, b, c, d = data:byte(offset, offset + 3)

  if not a or not b or not c or not d then
    return nil
  end

  return a + b * 256 + c * 65536 + d * 16777216
end

function jpeg_dimensions(data)
  if data:sub(1, 2) ~= "\255\216" then
    return nil, nil
  end

  local position = 3
  local length = #data

  while position <= length - 8 do
    while position <= length
      and data:byte(position) ~= 0xFF do
      position = position + 1
    end

    while position <= length
      and data:byte(position) == 0xFF do
      position = position + 1
    end

    local marker = data:byte(position)

    if not marker then
      break
    end

    position = position + 1

    if marker == 0xD8
      or marker == 0xD9
      or marker == 0x01
      or (marker >= 0xD0 and marker <= 0xD7) then
      -- Standalone marker without a segment length.
    else
      local segment_length =
        image_u16_be(data, position)

      if not segment_length
        or segment_length < 2 then
        break
      end

      local is_size_marker =
        (marker >= 0xC0 and marker <= 0xC3)
        or (marker >= 0xC5 and marker <= 0xC7)
        or (marker >= 0xC9 and marker <= 0xCB)
        or (marker >= 0xCD and marker <= 0xCF)

      if is_size_marker then
        local height =
          image_u16_be(data, position + 3)
        local width =
          image_u16_be(data, position + 5)

        return width, height
      end

      position = position + segment_length
    end
  end

  return nil, nil
end

function artwork_image_dimensions(path)
  local key = path_key(path)
  local cached = state.artwork_dimension_cache[key]

  if cached ~= nil then
    return cached.width, cached.height
  end

  local width, height = nil, nil
  local file = io.open(path, "rb")

  if file then
    local data = file:read(262144) or ""
    file:close()

    if data:sub(1, 8) == "\137PNG\r\n\26\n" then
      width = image_u32_be(data, 17)
      height = image_u32_be(data, 21)
    elseif data:sub(1, 2) == "\255\216" then
      width, height = jpeg_dimensions(data)
    elseif data:sub(1, 2) == "BM" then
      width = image_u32_le(data, 19)
      height = image_u32_le(data, 23)
    elseif #data >= 18 then
      -- TGA stores dimensions in the fixed 18-byte header.
      width = image_u16_le(data, 13)
      height = image_u16_le(data, 15)
    end
  end

  if not width or not height
    or width <= 0 or height <= 0 then
    width, height = 0, 0
  end

  state.artwork_dimension_cache[key] = {
    width = width,
    height = height,
  }

  return width, height
end

function artwork_candidate_score(path, filename)
  local width, height =
    artwork_image_dimensions(path)
  local square_class = 3
  local square_delta = math.huge
  local area = 0

  if width > 0 and height > 0 then
    square_delta =
      math.abs(width - height)
        / math.max(width, height)
    square_class = square_delta <= 0.06 and 0
      or square_delta <= 0.18 and 1
      or 2
    area = width * height
  end

  return {
    path = path,
    filename = safe_lower(filename),
    square_class = square_class,
    square_delta = square_delta,
    name_priority =
      ARTWORK_NAME_PRIORITY[safe_lower(filename)]
        or 1000,
    area = area,
  }
end

function artwork_candidate_is_better(candidate, current)
  if not current then
    return true
  end

  if candidate.square_class ~= current.square_class then
    return candidate.square_class < current.square_class
  end

  if candidate.name_priority ~= current.name_priority then
    return candidate.name_priority < current.name_priority
  end

  if candidate.square_delta ~= current.square_delta then
    return candidate.square_delta < current.square_delta
  end

  if candidate.area ~= current.area then
    return candidate.area > current.area
  end

  return candidate.filename < current.filename
end

function find_artwork_in_folder(folder)
  local folder_key = path_key(folder)
  local cached = state.artwork_folder_cache[folder_key]

  if cached ~= nil then
    return cached == false and "" or cached
  end

  local best = nil
  local index = 0

  -- A bounded candidate set prevents a documentation folder with thousands
  -- of images from turning one low-priority Artwork job into a long stall.
  while index < 128 do
    local filename =
      reaper.EnumerateFiles(folder, index)

    if not filename then
      break
    end

    if is_artwork_file(filename) then
      local path = join_path(folder, filename)
      local candidate =
        artwork_candidate_score(path, filename)

      if artwork_candidate_is_better(candidate, best) then
        best = candidate
      end
    end

    index = index + 1
  end

  local result = best and best.path or ""

  state.artwork_folder_cache[folder_key] =
    result ~= "" and result or false

  return result
end

function find_artwork_in_tree(
  folder,
  maximum_depth,
  budget
)
  budget = budget or {
    remaining = 64,
    exhausted = false,
  }

  local cache_key =
    "tree:"
      .. tostring(maximum_depth or 0)
      .. ":"
      .. path_key(folder)
  local cached = state.artwork_folder_cache[cache_key]

  if cached ~= nil then
    return cached == false and "" or cached
  end

  local found = find_artwork_in_folder(folder)

  if found == "" and (maximum_depth or 0) > 0 then
    local index = 0
    while budget.remaining > 0 do
      local subdir =
        reaper.EnumerateSubdirectories(folder, index)

      if not subdir then
        break
      end

      index = index + 1
      budget.remaining = budget.remaining - 1
      found = find_artwork_in_tree(
        join_path(folder, subdir),
        maximum_depth - 1,
        budget
      )

      if found ~= "" then
        break
      end
    end

    if found == ""
      and budget.remaining <= 0 then
      budget.exhausted = true
    end
  end

  -- A positive result is always safe to cache. Do not turn an intentionally
  -- bounded partial walk into a permanent negative result.
  if found ~= "" or not budget.exhausted then
    state.artwork_folder_cache[cache_key] =
      found ~= "" and found or false
  end

  return found
end

function artwork_candidate_folders(parent, excluded_path)
  local candidates = {}
  local index = 0

  while index < 128 do
    local subdir =
      reaper.EnumerateSubdirectories(parent, index)

    if not subdir then
      break
    end

    index = index + 1

    local path = join_path(parent, subdir)
    local priority = artwork_folder_priority(subdir)

    if priority
      and (
        not excluded_path
        or path_key(path) ~= path_key(excluded_path)
      ) then
      candidates[#candidates + 1] = {
        path = path,
        name = subdir,
        priority = priority,
      }
    end
  end

  table.sort(candidates, function(a, b)
    if a.priority == b.priority then
      return safe_lower(a.name) < safe_lower(b.name)
    end

    return a.priority < b.priority
  end)

  return candidates
end

function find_library_artwork_in_root(root)
  if not root or root == "" then
    return ""
  end

  local found = find_artwork_in_folder(root)

  if found ~= "" then
    return found
  end

  local discovery_budget = {
    remaining = 64,
    exhausted = false,
  }

  -- First inspect recognized child folders inside the source. The normalized
  -- role matcher understands numbered layouts such as "2. Artwork".
  for _, candidate in ipairs(
    artwork_candidate_folders(root)
  ) do
    found = find_artwork_in_tree(
      candidate.path,
      2,
      discovery_budget
    )

    if found ~= "" then
      return found
    end
  end

  -- A frequent commercial-library layout keeps "1. Audio" and "2. Artwork"
  -- as siblings under the product folder. Search only artwork-like siblings
  -- of this source, never arbitrary siblings or another logical-library root.
  local parent = dirname(root)

  if parent ~= "" and parent ~= root then
    for _, candidate in ipairs(
      artwork_candidate_folders(parent, root)
    ) do
      found = find_artwork_in_tree(
        candidate.path,
        2,
        discovery_budget
      )

      if found ~= "" then
        return found
      end
    end
  end

  return ""
end

function valid_artwork_path(path)
  path = tostring(path or "")

  return path ~= ""
    and path ~= "-"
    and reaper.file_exists(path)
end

function root_record_for_asset(asset)
  if not asset then
    return nil
  end

  local record = state.root_by_id[
    tostring(asset.root_id or "")
  ]

  if not record and tostring(asset.root or "") ~= "" then
    record = root_record_for_path(asset.root)
  end

  if not record and asset.path then
    record = select(2, root_for_path(asset.path))
  end

  return record
end

function root_artwork_for_asset(asset)
  local record = root_record_for_asset(asset)

  if not record then
    return "", nil
  end

  local path = tostring(record.artwork_path or "")

  if valid_artwork_path(path) then
    return path, record
  end

  if path ~= "" and path ~= "-" then
    record.artwork_path = ""
    record.artwork_checked = false
    record.artwork_scan_version = 0
    state.libraries_dirty = true
  end

  return "", record
end

function remember_root_artwork(record, path)
  if not record or not valid_artwork_path(path) then
    return
  end

  path = normalize_slashes(path)

  if record.artwork_path ~= path then
    record.artwork_path = path
    state.libraries_dirty = true
  end

  record.artwork_checked = true
  record.artwork_scan_version =
    ARTWORK_DISCOVERY_VERSION
end

function invalidate_root_artwork_assets(record)
  if not record then return end
  -- Artwork queue eligibility also checks the source record's shared path and
  -- checked state. Changing that record therefore invalidates visible assets
  -- lazily without touching every catalog row here.
  state.results_dirty = true
end

function choose_artwork_for_root(record)
  if not record then
    return
  end

  local current = valid_artwork_path(record.artwork_path)
    and record.artwork_path
    or ""
  local ok, filename = reaper.GetUserFileNameForRead(
    current,
    translate_ui_text("选择来源路径封面"),
    "png,jpg,jpeg,bmp,tga"
  )

  if ok and filename and filename ~= "" then
    record.artwork_path = normalize_slashes(filename)
    record.artwork_checked = true
    record.artwork_scan_version =
      ARTWORK_DISCOVERY_VERSION
    state.libraries_dirty = true
    invalidate_root_artwork_assets(record)
    set_status(
      "已设置来源路径封面："
        .. (record.alias ~= "" and record.alias or basename(record.path))
    )
  end
end

function redetect_root_artwork(record)
  if not record then
    return
  end

  record.artwork_path = ""
  record.artwork_checked = false
  record.artwork_scan_version = 0
  state.artwork_folder_cache = {}
  state.artwork_dimension_cache = {}
  state.libraries_dirty = true
  invalidate_root_artwork_assets(record)
  set_status(
    "将重新查找来源路径封面："
      .. (record.alias ~= "" and record.alias or basename(record.path))
  )
end

function clear_root_artwork(record)
  if not record then
    return
  end

  record.artwork_path = "-"
  record.artwork_checked = true
  record.artwork_scan_version =
    ARTWORK_DISCOVERY_VERSION
  state.libraries_dirty = true
  invalidate_root_artwork_assets(record)
  set_status(
    "已清除来源路径封面："
      .. (record.alias ~= "" and record.alias or basename(record.path))
  )
end

function discover_artwork_path(asset)
  if not asset then
    return "", false
  end

  local shared_path, record =
    root_artwork_for_asset(asset)

  if shared_path ~= "" then
    return shared_path, true
  end

  local folder =
    asset.folder ~= ""
      and asset.folder
      or dirname(asset.path)

  local root = record and record.path
    or normalize_slashes(asset.root or "")
  local root_disabled = record
    and tostring(record.artwork_path or "") == "-"
  local depth = 0

  while folder and folder ~= "" and depth < 7 do
    local at_root = root ~= ""
      and path_key(folder) == path_key(root)
    local found = ""

    if not (at_root and root_disabled) then
      found = find_artwork_in_folder(folder)
    end

    if found ~= "" then
      if at_root then
        remember_root_artwork(record, found)
      end

      return found, at_root
    end

    if root ~= ""
      and path_key(folder) == path_key(root) then
      break
    end

    local parent = dirname(folder)

    if parent == folder or parent == "" then
      break
    end

    folder = parent
    depth = depth + 1
  end

  -- Deeply nested files may not reach their own source root within the
  -- per-file search limit. Check only that source root explicitly. Covers
  -- never cross from one source folder to another logical-library member.
  if root ~= ""
    and not root_disabled
    and (not record or not record.artwork_checked) then
    local found = find_library_artwork_in_root(root)

    if found ~= "" then
      remember_root_artwork(record, found)
      return found, true
    end
  end

  if record then
    record.artwork_checked = true
    record.artwork_scan_version =
      ARTWORK_DISCOVERY_VERSION
    state.libraries_dirty = true
  end

  return "", false
end

function queue_artwork(asset, priority)
  if not state.artwork_enabled
    or not asset then
    return
  end

  local current =
    tostring(asset.artwork_path or "")
  local shared, record =
    root_artwork_for_asset(asset)

  if current == "-"
    or valid_artwork_path(current)
    or shared ~= ""
    or (
      current == ""
      and asset.artwork_checked == true
      and (not record or record.artwork_checked)
    ) then
    return
  end

  local key = path_key(asset.path)

  if state.artwork_queued[key] then
    return
  end

  state.artwork_queued[key] = true

  local job = {
    key = key,
    asset = asset,
  }

  if priority then
    table.insert(state.artwork_queue, 1, job)
  else
    state.artwork_queue[#state.artwork_queue + 1] = job
  end
end

function process_artwork_queue()
  if #state.artwork_queue == 0
    or state.scan
    or state.import_session
    or not can_run_heavy_job() then
    return
  end

  local now = reaper.time_precise()

  if now < state.artwork_next_job then
    return
  end

  local job = table.remove(state.artwork_queue, 1)

  if not job then
    return
  end

  local job_token =
    Jobs.begin("artwork", "artwork_reader", false)

  if not job_token then
    table.insert(state.artwork_queue, 1, job)
    return
  end

  state.artwork_queued[job.key] = nil

  local asset = job.asset

  if asset and state.by_path[job.key] == asset then
    local current =
      tostring(asset.artwork_path or "")

    if current == ""
      or not reaper.file_exists(current) then
      local found, shared =
        discover_artwork_path(asset)

      if found ~= "" then
        asset.artwork_path = shared and "" or found
        mark_asset_database_change(asset)
      elseif current ~= "-" then
        asset.artwork_path = ""
      end

      asset.artwork_checked = true
    end
  end

  state.artwork_next_job = now + 0.025
  Jobs.finish(job_token, true)
end

function release_artwork_image(key)
  local entry = state.artwork_images[key]

  if not entry then
    return
  end

  if entry.image
    and ImGui.ValidatePtr(
      entry.image,
      "ImGui_Image*"
    ) then
    pcall(ImGui.Detach, ctx, entry.image)
  end

  state.artwork_images[key] = nil
end

function trim_artwork_image_cache()
  while #state.artwork_image_order
      > state.artwork_image_limit do
    local oldest =
      table.remove(
        state.artwork_image_order,
        1
      )

    release_artwork_image(oldest)
  end
end

function artwork_image_from_path(path)
  if not path
    or path == ""
    or path == "-"
    or not reaper.file_exists(path) then
    return nil
  end

  local key = path_key(path)
  local entry = state.artwork_images[key]
  local now = reaper.time_precise()

  if entry
    and entry.image
    and ImGui.ValidatePtr(
      entry.image,
      "ImGui_Image*"
    ) then
    entry.last_used = now
    return entry.image
  end

  if entry
    and entry.failed
    and now - (entry.last_used or 0) < 8 then
    return nil
  end

  local ok, image =
    pcall(ImGui.CreateImage, path)

  if not ok or not image then
    state.artwork_images[key] = {
      failed = true,
      last_used = now,
    }
    return nil
  end

  pcall(ImGui.Attach, ctx, image)

  state.artwork_images[key] = {
    image = image,
    last_used = now,
  }

  state.artwork_image_order[
    #state.artwork_image_order + 1
  ] = key

  trim_artwork_image_cache()
  return image
end

function artwork_image_for_asset(asset, priority)
  if not state.artwork_enabled
    or not asset then
    return nil
  end

  local path =
    tostring(asset.artwork_path or "")

  if path == "-" then
    return nil
  end

  if path ~= "" and not valid_artwork_path(path) then
    asset.artwork_path = ""
    asset.artwork_checked = false
    path = ""
  end

  if path == "" then
    local shared, record =
      root_artwork_for_asset(asset)
    path = shared

    if path == ""
      and (
        asset.artwork_checked ~= true
        or (record and not record.artwork_checked)
      ) then
      queue_artwork(asset, priority)
    end
  end

  if path == "" then
    return nil
  end

  return artwork_image_from_path(path)
end

function draw_artwork_placeholder(
  draw_list,
  x,
  y,
  width,
  height,
  rounding
)
  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + width,
    y + height,
    COLOR.panel_alt,
    rounding or 3
  )

  local cx = x + width * 0.5
  local cy = y + height * 0.5
  local radius =
    math.min(width, height) * 0.18

  ImGui.DrawList_AddCircle(
    draw_list,
    cx,
    cy - radius * 0.45,
    radius * 0.42,
    rgba_with_alpha(COLOR.dim, 0x99),
    16,
    1.2
  )

  ImGui.DrawList_AddTriangleFilled(
    draw_list,
    x + width * 0.20,
    y + height * 0.78,
    x + width * 0.48,
    y + height * 0.48,
    x + width * 0.64,
    y + height * 0.78,
    rgba_with_alpha(COLOR.dim, 0x88)
  )

  ImGui.DrawList_AddTriangleFilled(
    draw_list,
    x + width * 0.44,
    y + height * 0.78,
    x + width * 0.70,
    y + height * 0.56,
    x + width * 0.84,
    y + height * 0.78,
    rgba_with_alpha(COLOR.dim, 0x66)
  )
end

function draw_artwork_cover(
  draw_list,
  asset,
  x,
  y,
  width,
  height,
  crop,
  rounding,
  show_placeholder
)
  local image =
    artwork_image_for_asset(asset, true)

  if not image then
    if show_placeholder ~= false then
      draw_artwork_placeholder(
        draw_list,
        x,
        y,
        width,
        height,
        rounding
      )
    end
    return false
  end

  local image_w, image_h =
    ImGui.Image_GetSize(image)

  if not image_w or not image_h
    or image_w <= 0 or image_h <= 0 then
    if show_placeholder ~= false then
      draw_artwork_placeholder(
        draw_list,
        x,
        y,
        width,
        height,
        rounding
      )
    end
    return false
  end

  local u0, v0, u1, v1 = 0, 0, 1, 1
  local draw_x, draw_y = x, y
  local draw_w, draw_h = width, height

  if crop then
    local source_ratio = image_w / image_h
    local target_ratio = width / height

    if source_ratio > target_ratio then
      local visible = target_ratio / source_ratio
      u0 = (1 - visible) * 0.5
      u1 = 1 - u0
    elseif source_ratio < target_ratio then
      local visible = source_ratio / target_ratio
      v0 = (1 - visible) * 0.5
      v1 = 1 - v0
    end
  else
    local scale =
      math.min(
        width / image_w,
        height / image_h
      )

    draw_w = image_w * scale
    draw_h = image_h * scale
    draw_x = x + (width - draw_w) * 0.5
    draw_y = y + (height - draw_h) * 0.5

    ImGui.DrawList_AddRectFilled(
      draw_list,
      x,
      y,
      x + width,
      y + height,
      COLOR.waveform_bg,
      rounding or 4
    )
  end

  ImGui.DrawList_AddImageRounded(
    draw_list,
    image,
    draw_x,
    draw_y,
    draw_x + draw_w,
    draw_y + draw_h,
    u0,
    v0,
    u1,
    v1,
    0xFFFFFFFF,
    rounding or 4,
    0
  )

  return true
end

function clear_artwork_cache()
  for key in pairs(state.artwork_images) do
    release_artwork_image(key)
  end

  state.artwork_images = {}
  state.artwork_image_order = {}
  state.artwork_folder_cache = {}
  state.artwork_dimension_cache = {}
  state.artwork_queue = {}
  state.artwork_queued = {}

  for _, record in ipairs(state.root_records) do
    if tostring(record.artwork_path or "") == "" then
      record.artwork_checked = false
      record.artwork_scan_version = 0
    end
  end

  for _, asset in ipairs(state.assets) do
    if asset.artwork_path ~= "-" then
      asset.artwork_path = ""
      asset.artwork_checked = false
    end
  end

  mark_database_snapshot_dirty()
  set_status("已清空 Artwork 缓存；可见素材将重新查找封面")
end

----------------------------------------------------------------
-- Metadata indexing
----------------------------------------------------------------

function metadata_map(source)
  local map = {}
  local ok, identifiers =
    reaper.GetMediaFileMetadata(source, "")

  if not ok or not identifiers then
    return map
  end

  local count = 0

  for identifier in identifiers:gmatch("[^\r\n]+") do
    identifier = trim(identifier)

    if identifier ~= "" then
      local value_ok, value =
        reaper.GetMediaFileMetadata(
          source,
          identifier
        )

      if value_ok and value and value ~= "" then
        map[identifier] = value
      end

      count = count + 1

      if count >= 80 then
        break
      end
    end
  end

  return map
end

function metadata_pick(map, names)
  for key, value in pairs(map) do
    local upper = key:upper()

    for _, name in ipairs(names) do
      if upper:find(name, 1, true) then
        return value
      end
    end
  end

  return ""
end

function index_asset(asset)
  if not asset
    or not reaper.file_exists(asset.path) then
    return false
  end

  local source =
    reaper.PCM_Source_CreateFromFile(asset.path)

  if not source then
    return false
  end

  local duration, is_qn =
    reaper.GetMediaSourceLength(source)

  local metadata = metadata_map(source)
  local ucs = parse_ucs_filename(asset.name)

  asset.duration =
    is_qn and 0 or (duration or 0)

  asset.channels =
    reaper.GetMediaSourceNumChannels(source) or 0

  asset.sample_rate =
    reaper.GetMediaSourceSampleRate(source) or 0

  asset.bit_depth =
    type(reaper.CF_GetMediaSourceBitDepth) == "function"
      and reaper.CF_GetMediaSourceBitDepth(source)
      or 0

  asset.source_type =
    reaper.GetMediaSourceType(source)
      or extension(asset.path):upper()

  asset.size = file_size(asset.path)

  asset.description = metadata_pick(
    metadata,
    {
      "DESCRIPTION",
      "COMMENT",
      "TITLE",
      "INAM",
    }
  )

  asset.keywords = metadata_pick(
    metadata,
    {
      "KEYWORD",
      "TAGS",
      "IKEY",
    }
  )

  local catid = metadata_pick(
    metadata,
    {
      "CATID",
      "CATEGORY ID",
    }
  )

  local category = metadata_pick(
    metadata,
    {
      "CATEGORY",
    }
  )

  local subcategory = metadata_pick(
    metadata,
    {
      "SUBCATEGORY",
      "SUB CATEGORY",
    }
  )

  asset.catid =
    catid ~= "" and catid or ucs.catid

  asset.category =
    category ~= "" and category or ucs.category

  asset.subcategory =
    subcategory ~= ""
      and subcategory
      or ucs.subcategory

  asset.indexed = true
  asset._search_blob = nil

  reaper.PCM_Source_Destroy(source)

  mark_asset_database_change(asset)
  state.results_dirty = true
  return true
end

function queue_metadata(asset, priority)
  if not asset or asset.indexed then
    return
  end

  local key = path_key(asset.path)

  if state.meta_queued[key] then
    return
  end

  if not priority
    and #state.meta_queue >= MAX_WORK_QUEUE then
    return
  end

  state.meta_queued[key] = true

  local job = {
    key = key,
    asset = asset,
  }

  if priority then
    table.insert(state.meta_queue, 1, job)
  else
    state.meta_queue[#state.meta_queue + 1] = job
  end
end

function process_metadata_queue()
  if state.import_session then
    return
  end

  if #state.meta_queue == 0
    or not can_run_heavy_job() then
    return
  end

  local now = reaper.time_precise()

  if now < state.next_meta_job then
    return
  end

  local job = table.remove(state.meta_queue, 1)
  state.meta_queued[job.key] = nil

  if job.asset then
    index_asset(job.asset)
  end

  state.next_meta_job = now + META_INTERVAL
end

----------------------------------------------------------------
-- Scan
----------------------------------------------------------------

function start_import_recovery_audit()
  if state.persistence_read_only or #state.roots == 0
    or #state.assets == 0 then
    state.import_recovery_audit = nil
    return
  end
  state.import_recovery_audit = {
    assets = state.assets,
    index = 1,
    total = #state.assets,
  }
end

function process_import_recovery_audit()
  local audit = state.import_recovery_audit
  if not audit or state.scan or state.import_session
    or state.transfer_running or not can_run_heavy_job() then
    return
  end

  for _, token in pairs(Jobs.active) do
    if token.resource == "catalog_exclusive"
      and not token.finished then
      return
    end
  end

  if audit.assets ~= state.assets then
    audit.assets = state.assets
    audit.index = 1
    audit.total = #state.assets
  end

  local last = math.min(
    audit.total,
    audit.index + IMPORT_RECOVERY_ASSETS_PER_FRAME - 1
  )
  for index = audit.index, last do
    local asset = audit.assets[index]
    if asset and not asset.ready then
      state.import_recovery_audit = nil
      start_scan("恢复未完成导入")
      return
    end
  end
  audit.index = last + 1
  if audit.index > audit.total then
    state.import_recovery_audit = nil
  end
end

function start_scan(reason, roots_override, options)
  local requested = roots_override or state.roots
  local silent =
    type(options) == "table"
    and options.silent == true
  local force_rebuild =
    type(options) == "table"
    and options.force_rebuild == true

  if #requested == 0 then
    set_status("请先添加音效库根目录", true)
    return
  end

  local scan = {
    reason = reason or "扫描",
    roots = {},
    root_keys = {},
    dirs = {},
    dir_head = 1,
    current = nil,
    seen = {},
    files = 0,
    ignored = 0,
    directories = 0,
    new_assets = {},
    started = reaper.time_precise(),
    silent = silent,
    force_rebuild = force_rebuild,
  }

  for _, root in ipairs(requested) do
    if directory_exists(root) then
      scan.roots[#scan.roots + 1] = root
      scan.root_keys[path_key(root)] = true
      scan.dirs[#scan.dirs + 1] = {
        path = root,
        root = root,
        file_index = 0,
        sub_index = 0,
        stage = "files",
      }
    end
  end

  if #scan.roots == 0 then
    set_status("没有可访问的音效库目录", true)
    return
  end

  local job_token, job_error =
    Jobs.begin(
      "catalog_pipeline",
      "catalog_exclusive",
      false
    )

  if not job_token then
    set_status(
      job_error == "resource_busy"
        and "另一个目录写任务正在运行"
        or "扫描任务已经在运行",
      true
    )
    return
  end

  scan.job_token = job_token

  state.scan = scan
  state.scan_checkpoint_last_at = 0
  write_scan_checkpoint(scan, "scan")

  if not scan.silent then
    set_status(
      string.format(
        "%s：正在扫描 %d 个目录…",
        scan.reason,
        #scan.roots
      )
    )
  end

end

function finish_scan()
  local scan = state.scan
  if not scan or scan.phase then return end
  scan.phase = "finalize_prune"
  scan.prune_job = new_catalog_prune_job(state.by_path)
  scan.finalize_total = #state.assets
  scan.removed = 0
  scan.finalize_removed_so_far = 0
  scan.pending = {}
  scan.pending_seen = {}
  scan.pending_index = 1
  if not scan.silent then
    set_status(scan.reason .. "：扫描完成，正在整理索引…")
  end
end

function complete_scan_finalize(scan)
  clear_scan_checkpoint()
  local pending = scan.pending
  local removed = scan.removed or 0
  state.scan = nil

  if #pending > 0 then
    state.import_session = {
      label = scan.reason,
      roots = scan.roots,
      assets = pending,
      total = #pending,
      done = 0,
      failed = 0,
      current = nil,
      started = scan.started,
      phase = "prepare",
      silent = scan.silent,
      removed = removed,
      job_token = scan.job_token,
    }

    state.import_cancel_requested = false

    if not scan.silent then
      set_status(
        string.format(
          "%s：扫描完成，正在分析并建立 %d 个波形…",
          scan.reason,
          #pending
        )
      )
    end
  else
    Jobs.finish(scan.job_token, true)
    if scan.silent then
      if removed > 0 then
        set_status(
          string.format(
            "后台更新：移除 %d 个离线素材",
            removed
          )
        )
      end
    elseif scan.ignored > 0 then
      set_status(
        string.format(
          "扫描完成：%d 个音频，移除 %d 个，忽略 %d 个系统文件，%.1f 秒",
          scan.files,
          removed,
          scan.ignored,
          reaper.time_precise() - scan.started
        )
      )
    else
      set_status(
        string.format(
          "扫描完成：%d 个音频，移除 %d 个，%.1f 秒",
          scan.files,
          removed,
          reaper.time_precise() - scan.started
        )
      )
    end
  end

  state.results_dirty = true
end

function process_scan_finalize(scan)
  if scan.phase == "finalize_prune" then
    local complete = step_catalog_prune_job(
      scan.prune_job,
      SCAN_FINALIZE_ASSETS_PER_FRAME,
      function(key, asset)
        local belongs =
          scan.root_keys[path_key(asset.root or "")] == true
        return belongs and not scan.seen[key]
      end,
      function(key, asset)
        state.favorites[key] = nil
        state.selected_set[key] = nil
        state.preview_history_assets[asset.asset_id or ""] = nil
        scan.finalize_removed_so_far =
          scan.finalize_removed_so_far + 1
      end
    )
    if complete then
      scan.removed = scan.prune_job.removed
      if scan.removed > 0 then
        state.assets = scan.prune_job.kept
        state.database_ordered_assets = nil
        state.config_dirty = true
        mark_database_snapshot_dirty()
        invalidate_library_counts()
        invalidate_folder_navigation()
      end
      scan.prune_job = nil
      scan.phase = "finalize_pending"
    end
    return
  end

  local last = math.min(
    #scan.new_assets,
    scan.pending_index + SCAN_FINALIZE_ASSETS_PER_FRAME - 1
  )
  for index = scan.pending_index, last do
    local asset = scan.new_assets[index]
    local key = asset and path_key(asset.path) or ""
    if asset and key ~= "" and not scan.pending_seen[key]
      and not asset.ready then
      scan.pending_seen[key] = true
      asset.pending_batch = true
      scan.pending[#scan.pending + 1] = asset
    end
  end
  scan.pending_index = last + 1
  if scan.pending_index > #scan.new_assets then
    scan.pending_seen = nil
    complete_scan_finalize(scan)
  end
end

function begin_scan_cancel(scan)
  if scan.phase == "cancel_collect"
    or scan.phase == "cancel_prune" then
    return
  end
  scan.phase = "cancel_collect"
  scan.cancel_index = 1
  scan.cancel_keys = {}
  scan.prune_job = nil
  set_status("正在取消扫描并清理未完成素材…")
end

function process_scan_cancel(scan)
  if scan.phase == "cancel_collect" then
    local last = math.min(
      #scan.new_assets,
      scan.cancel_index + SCAN_FINALIZE_ASSETS_PER_FRAME - 1
    )
    for index = scan.cancel_index, last do
      local asset = scan.new_assets[index]
      if asset and not asset.ready then
        scan.cancel_keys[path_key(asset.path)] = true
      end
    end
    scan.cancel_index = last + 1
    if scan.cancel_index > #scan.new_assets then
      scan.phase = "cancel_prune"
      scan.prune_job = new_catalog_prune_job(state.by_path)
      scan.cancel_total = #state.assets
    end
    return
  end

  local complete = step_catalog_prune_job(
    scan.prune_job,
    SCAN_FINALIZE_ASSETS_PER_FRAME,
    function(key)
      return scan.cancel_keys[key] == true
    end,
    function(key, asset)
      state.favorites[key] = nil
      state.selected_set[key] = nil
      state.preview_history_assets[asset.asset_id or ""] = nil
    end
  )
  if not complete then return end

  local removed = scan.prune_job.removed
  local catalog_changed = removed > 0
    or (scan.finalize_removed_so_far or 0) > 0
  if catalog_changed then
    state.assets = scan.prune_job.kept
    state.database_ordered_assets = nil
    mark_database_snapshot_dirty()
    invalidate_library_counts()
    invalidate_folder_navigation()
  end
  state.scan = nil
  clear_scan_checkpoint()
  Jobs.finish(scan.job_token, true, "user canceled")
  state.results_dirty = true
  set_status("已取消扫描")
end

function process_scan()
  local scan = state.scan

  if not scan then
    return
  end

  if scan.job_token
    and scan.job_token.cancel_requested then
    begin_scan_cancel(scan)
    process_scan_cancel(scan)
    return
  end

  if scan.phase == "finalize_prune"
    or scan.phase == "finalize_pending" then
    process_scan_finalize(scan)
    return
  end

  local deadline =
    reaper.time_precise() + SCAN_BUDGET

  local now = reaper.time_precise()

  if now - (state.scan_checkpoint_last_at or 0)
      >= SCAN_CHECKPOINT_INTERVAL then
    write_scan_checkpoint(scan, "scan")
    state.scan_checkpoint_last_at = now
  end

  while reaper.time_precise() < deadline do
    local dir = scan.current

    if not dir then
      dir = scan.dirs[scan.dir_head]
      scan.dir_head = scan.dir_head + 1
      scan.current = dir

      if not dir then
        finish_scan()
        return
      end

      scan.directories =
        scan.directories + 1
    end

    if dir.stage == "files" then
      local filename =
        reaper.EnumerateFiles(
          dir.path,
          dir.file_index
        )

      if filename then
        dir.file_index = dir.file_index + 1

        local path =
          join_path(dir.path, filename)

        if is_ignored_media_path(path) then
          scan.ignored = scan.ignored + 1
        elseif is_audio_file(path) then
          local key = path_key(path)

          if not scan.seen[key] then
            scan.seen[key] = true
            scan.files = scan.files + 1

            if not state.by_path[key] then
              local asset =
                add_or_update_asset(
                  make_placeholder(path, dir.root)
                )

              scan.new_assets[#scan.new_assets + 1] =
                asset

              mark_asset_database_change(asset)
            elseif scan.force_rebuild then
              local asset = state.by_path[key]
              asset.ready = false
              asset.indexed = false
              scan.new_assets[#scan.new_assets + 1] = asset
            elseif not state.by_path[key].ready then
              scan.new_assets[#scan.new_assets + 1] =
                state.by_path[key]
            end
          end
        end
      else
        dir.stage = "subdirs"
      end
    else
      local subdir =
        reaper.EnumerateSubdirectories(
          dir.path,
          dir.sub_index
        )

      if subdir then
        dir.sub_index = dir.sub_index + 1

        if not is_ignored_directory_name(subdir) then
          scan.dirs[#scan.dirs + 1] = {
            path = join_path(dir.path, subdir),
            root = dir.root,
            file_index = 0,
            sub_index = 0,
            stage = "files",
          }
        end
      else
        scan.current = nil
      end
    end
  end
end

----------------------------------------------------------------
-- Search
----------------------------------------------------------------

function search_blob(asset)
  if not asset._search_blob then
    asset._search_blob =
      safe_lower(
        table.concat(
          {
            asset.name or "",
            asset.path or "",
            asset.library or "",
            asset.description or "",
            asset.keywords or "",
            asset.catid or "",
            asset.category or "",
            asset.subcategory or "",
            workflow_label(
              asset.workflow_status or "none"
            ),
            asset.marked and "marked" or "",
          },
          "\n"
        )
      )
  end

  return asset._search_blob
end

function field_value(asset, field)
  field = safe_lower(field)

  if field == "name" then
    return asset.name
  elseif field == "path"
    or field == "folder" then
    return asset.path
  elseif field == "library"
    or field == "lib" then
    return asset.library
  elseif field == "root"
    or field == "source" then
    local record = state.root_by_id[asset.root_id or ""]
    return record and ((record.alias or "") .. " " .. record.path)
      or asset.root
  elseif field == "category"
    or field == "cat" then
    return asset.category
  elseif field == "subcategory"
    or field == "subcat" then
    return asset.subcategory
  elseif field == "catid" then
    return asset.catid
  elseif field == "desc"
    or field == "description" then
    return asset.description
  elseif field == "keywords"
    or field == "key" then
    return asset.keywords
  elseif field == "ch"
    or field == "channels" then
    return tostring(asset.channels or 0)
  elseif field == "fav"
    or field == "favorite" then
    return state.favorites[path_key(asset.path)]
      and "true"
      or "false"
  elseif field == "status"
    or field == "workflow" then
    return asset.workflow_status or "none"
  elseif field == "marked"
    or field == "mark" then
    return asset.marked and "true" or "false"
  elseif field == "played"
    or field == "previewed" then
    return asset_is_played(asset) and "true" or "false"
  elseif field == "missing"
    or field == "offline" then
    return state.missing_assets[path_key(asset.path)]
      and "true"
      or "false"
  elseif field == "duplicate"
    or field == "dupe" then
    return state.duplicate_lookup[path_key(asset.path)]
      and "true"
      or "false"
  elseif field == "project"
    or field == "used" then
    local bucket = project_usage_bucket(
      state.current_project_path,
      false
    )
    return bucket
      and bucket.assets[path_key(asset.path)]
      and "true"
      or "false"
  end

  return ""
end

function matches_search(asset)
  local query = trim(state.search)

  if query == "" then
    return true
  end

  local blob = search_blob(asset)

  for _, raw in ipairs(split_words(query)) do
    local exclude = raw:sub(1, 1) == "-"
    local token = exclude and raw:sub(2) or raw
    token = safe_lower(token)

    if token ~= "" then
      local field, wanted =
        token:match("^([%w_]+)%:(.+)$")

      local matched

      if field then
        matched =
          safe_lower(field_value(asset, field))
            :find(wanted, 1, true)
          ~= nil
      else
        matched =
          blob:find(token, 1, true) ~= nil
      end

      if exclude and matched then
        return false
      elseif not exclude and not matched then
        return false
      end
    end
  end

  return true
end

function asset_in_view(asset)
  if not asset.ready or asset.pending_batch then
    return false
  end

  if state.view == "favorites"
    and not state.favorites[path_key(asset.path)] then
    return false
  elseif state.view == "recent"
    and (asset.last_used or 0) <= 0 then
    return false
  elseif state.view == "previewed"
    and (asset.last_previewed or 0) <= 0 then
    return false
  elseif state.view == "missing"
    and not state.missing_assets[path_key(asset.path)] then
    return false
  elseif state.view == "duplicates"
    and not state.duplicate_lookup[path_key(asset.path)] then
    return false
  elseif state.view == "duplicates_confirmed"
    and not state.duplicate_confirmed_lookup[path_key(asset.path)] then
    return false
  elseif state.view == "duplicate_failures"
    and not state.duplicate_confirmation_failures[path_key(asset.path)] then
    return false
  elseif state.view == "project_used" then
    local bucket = project_usage_bucket(
      state.current_project_path,
      false
    )
    if not bucket
      or not bucket.assets[path_key(asset.path)] then
      return false
    end
  end

  if state.active_collection_id then
    local collection =
      state.collection_by_id[
        state.active_collection_id
      ]

    if not collection
      or not collection.items[path_key(asset.path)] then
      return false
    end
  end

  if state.status_filter
    and (asset.workflow_status or "none")
      ~= state.status_filter then
    return false
  end

  if state.root_filter
    and not path_is_inside(
      asset.path,
      state.root_filter
    ) then
    return false
  end

  if state.library_filter_id
    and asset.library_id ~= state.library_filter_id then
    return false
  end

  return true
end

local function cached_sort_text(asset, field, source_field, value_field)
  local source = tostring(asset[field] or "")
  if asset[source_field] ~= source then
    asset[source_field] = source
    asset[value_field] = safe_lower(source)
  end
  return asset[value_field]
end

local function cached_sort_path(asset)
  return asset_path_sort_key(asset)
end

local function result_sort_comparator()
  local direction = state.sort_desc and -1 or 1
  local view = state.view
  local sort_mode = state.sort_mode
  local duplicate_lookup = state.duplicate_lookup
  local confirmed_lookup = state.duplicate_confirmed_lookup

  return function(a, b)
    local av
    local bv

    if view == "duplicates" then
      av = duplicate_lookup[cached_sort_path(a)] or ""
      bv = duplicate_lookup[cached_sort_path(b)] or ""
    elseif view == "duplicates_confirmed" then
      av = confirmed_lookup[cached_sort_path(a)] or ""
      bv = confirmed_lookup[cached_sort_path(b)] or ""
    elseif sort_mode == "duration" then
      av = tonumber(a.duration) or 0
      bv = tonumber(b.duration) or 0
    elseif sort_mode == "library" then
      av = cached_sort_text(
        a,
        "library",
        "_sort_library_source",
        "_sort_library_value"
      )
      bv = cached_sort_text(
        b,
        "library",
        "_sort_library_source",
        "_sort_library_value"
      )
    elseif sort_mode == "used" then
      av = tonumber(a.last_used) or 0
      bv = tonumber(b.last_used) or 0
    elseif sort_mode == "previewed" then
      av = tonumber(a.last_previewed) or 0
      bv = tonumber(b.last_previewed) or 0
    else
      av = cached_sort_text(
        a,
        "name",
        "_sort_name_source",
        "_sort_name_value"
      )
      bv = cached_sort_text(
        b,
        "name",
        "_sort_name_source",
        "_sort_name_value"
      )
    end

    if av == bv then
      local a_path = cached_sort_path(a)
      local b_path = cached_sort_path(b)
      if a_path == b_path then
        return false
      end
      return direction > 0 and a_path < b_path or a_path > b_path
    end

    return direction > 0 and av < bv or av > bv
  end
end

function start_results_rebuild()
  state.results_dirty = false
  state.results_job = begin_incremental_result_job(
    state.assets,
    function(asset)
      return asset_in_view(asset) and matches_search(asset)
    end,
    result_sort_comparator(),
    cached_sort_path,
    state.selected_path and path_key(state.selected_path) or nil
  )
end

function process_results_rebuild()
  if state.results_dirty or not state.results_job then
    start_results_rebuild()
  end

  local status, results, selected_index =
    step_incremental_result_job(
      state.results_job,
      RESULT_BUILD_DEFAULT_BUDGET
    )

  if status == "complete" then
    state.results = results
    state.selected_index = selected_index
    state.results_job = nil
  end
end

function rebuild_results()
  start_results_rebuild()
  while state.results_job do
    process_results_rebuild()
  end
end

----------------------------------------------------------------
-- Persistent waveform cache
----------------------------------------------------------------

function wave_cache_key(asset, points, preserve_channels)
  if not asset.size or asset.size <= 0 then
    asset.size = file_size(asset.path)
  end

  return fnv1a(
    path_key(asset.path)
      .. "|"
      .. tostring(asset.size)
      .. "|"
      .. tostring(points)
      .. (preserve_channels and "|channels-rwf3" or "")
  )
end

function wave_cache_path(asset, points, preserve_channels)
  return join_path(
    WAVE_CACHE_DIR,
    wave_cache_key(asset, points, preserve_channels) .. ".rwf"
  )
end

function load_wave_from_disk(asset, points, preserve_channels)
  local path = wave_cache_path(asset, points, preserve_channels)
  local file = io.open(path, "rb")

  if not file then
    return nil
  end

  local header = file:read("*l") or ""
  local version, count_text, channels_text =
    header:match("^(RWF3)%s+(%d+)%s+(%d+)$")

  if not version then
    version, count_text =
      header:match("^(RWF2)%s+(%d+)$")
  end

  local count =
    version and tonumber(count_text)
    or tonumber(header)

  if not count
    or count <= 0
    or count > LARGE_WAVE_MAX_POINTS then
    file:close()
    return nil
  end

  local peaks = {}

  if version == "RWF3" then
    local channels = clamp(tonumber(channels_text) or 1, 1, 8)
    local bytes = file:read(count * channels * 2)
    file:close()

    if not bytes or #bytes ~= count * channels * 2 then
      return nil
    end

    local channel_peaks = {}

    for channel = 1, channels do
      channel_peaks[channel] = {}
    end

    for index = 1, count do
      local aggregate = 0

      for channel = 1, channels do
        local value_index =
          ((index - 1) * channels + channel - 1) * 2 + 1
        local low = bytes:byte(value_index) or 0
        local high = bytes:byte(value_index + 1) or 0
        local value = (low | (high << 8)) / 65535

        channel_peaks[channel][index] = value
        aggregate = math.max(aggregate, value)
      end

      peaks[index] = aggregate
    end

    return {
      count = count,
      channels = channels,
      peaks = peaks,
      channel_peaks = channel_peaks,
    }
  elseif version == "RWF2" then
    local bytes = file:read(count * 2)
    file:close()

    if not bytes or #bytes ~= count * 2 then
      return nil
    end

    for index = 1, count do
      local byte_index = (index - 1) * 2 + 1
      local low = bytes:byte(byte_index) or 0
      local high = bytes:byte(byte_index + 1) or 0
      peaks[index] = (low | (high << 8)) / 65535
    end
  else
    -- 兼容 0.5.1 及更早版本的 8-bit 峰值缓存。
    local bytes = file:read(count)
    file:close()

    if not bytes or #bytes ~= count then
      return nil
    end

    for index = 1, count do
      peaks[index] = bytes:byte(index) / 255
    end
  end

  return {
    count = count,
    peaks = peaks,
  }
end

function save_wave_to_disk(
  asset,
  points,
  waveform,
  preserve_channels
)
  ensure_dirs()

  local file =
    io.open(
      wave_cache_path(asset, points, preserve_channels),
      "wb"
    )

  if not file then
    return
  end

  local channel_peaks =
    preserve_channels and waveform.channel_peaks or nil
  local channels =
    channel_peaks and clamp(waveform.channels or #channel_peaks, 1, 8)
      or 1

  if channel_peaks then
    file:write(
      "RWF3 ",
      tostring(waveform.count),
      " ",
      tostring(channels),
      "\n"
    )
  else
    -- RWF2 保持列表缩略图缓存兼容；RWF3 才保存独立声道。
    file:write(
      "RWF2 ",
      tostring(waveform.count),
      "\n"
    )
  end

  local chunks = {}
  local chunk = {}

  for index = 1, waveform.count do
    for channel = 1, channels do
      local source_peaks =
        channel_peaks and channel_peaks[channel]
          or waveform.peaks
      local value =
        clamp(
          math.floor(
            ((source_peaks and source_peaks[index]) or 0)
              * 65535
              + 0.5
          ),
          0,
          65535
        )

      chunk[#chunk + 1] =
        string.char(
          value & 0xFF,
          (value >> 8) & 0xFF
        )

      if #chunk >= 256 then
        chunks[#chunks + 1] =
          table.concat(chunk)
        chunk = {}
      end
    end
  end

  if #chunk > 0 then
    chunks[#chunks + 1] =
      table.concat(chunk)
  end

  file:write(table.concat(chunks))
  file:close()
end

function read_waveform_from_source(
  source,
  duration,
  channels,
  points,
  preserve_channels
)
  if not source
    or not duration
    or duration <= 0 then
    return nil
  end

  channels = clamp(channels or 1, 1, 8)
  points = clamp(math.floor(points), 32, LARGE_WAVE_MAX_POINTS)

  local buffer =
    reaper.new_array(points * channels * 2)

  local retval =
    reaper.PCM_Source_GetPeaks(
      source,
      points / duration,
      0,
      channels,
      points,
      0,
      buffer
    )

  local returned = retval & 0xFFFFF

  if returned <= 0 then
    return nil
  end

  local values =
    buffer.table(
      1,
      returned * channels * 2
    )

  local peaks = {}
  local channel_peaks = preserve_channels and {} or nil
  local minimum_offset = returned * channels

  if channel_peaks then
    for channel = 1, channels do
      channel_peaks[channel] = {}
    end
  end

  for sample = 0, returned - 1 do
    local amplitude = 0

    for channel = 0, channels - 1 do
      local maximum =
        math.abs(
          values[
            sample * channels
              + channel
              + 1
          ] or 0
        )

      local minimum =
        math.abs(
          values[
            minimum_offset
              + sample * channels
              + channel
              + 1
          ] or 0
        )

      amplitude =
        math.max(
          amplitude,
          maximum,
          minimum
        )

      if channel_peaks then
        channel_peaks[channel + 1][sample + 1] =
          clamp(math.max(maximum, minimum), 0, 1)
      end
    end

    peaks[sample + 1] =
      clamp(amplitude, 0, 1)
  end

  return {
    count = returned,
    channels = channels,
    peaks = peaks,
    channel_peaks = channel_peaks,
  }
end

function destroy_wave_job(job)
  if job and job.source then
    reaper.PCM_Source_Destroy(job.source)
    job.source = nil
  end
end

function start_wave_job(job)
  if not job
    or not job.asset
    or not reaper.file_exists(job.asset.path) then
    return false, "文件不可用"
  end

  local source =
    reaper.PCM_Source_CreateFromFile(job.asset.path)

  if not source then
    return false, "无法建立媒体源"
  end

  local duration, is_qn =
    reaper.GetMediaSourceLength(source)

  if is_qn or not duration or duration <= 0 then
    reaper.PCM_Source_Destroy(source)
    return false, "无有效音频长度"
  end

  job.source = source
  job.duration = duration
  job.channels =
    clamp(
      reaper.GetMediaSourceNumChannels(source) or 1,
      1,
      8
    )
  job.phase = "build"
  job.progress = 0

  -- GetPeaks 在峰值尚未建立时会返回 0。
  -- 按 REAPER 官方要求先 Begin，再在后续帧 Run，最后 Finish。
  local remaining =
    reaper.PCM_Source_BuildPeaks(source, 0)

  if remaining == 0 then
    job.phase = "read"
    job.progress = 1
  else
    job.progress =
      clamp(1 - remaining / 100, 0, 0.99)
  end

  return true
end

function step_wave_job(job)
  if not job then
    return "failed", nil, "空任务"
  end

  if not job.source then
    local ok, err = start_wave_job(job)

    if not ok then
      return "failed", nil, err
    end
  end

  if job.phase == "build" then
    local remaining =
      reaper.PCM_Source_BuildPeaks(
        job.source,
        1
      )

    job.progress =
      clamp(1 - remaining / 100, 0, 0.99)

    if remaining ~= 0 then
      return "working"
    end

    reaper.PCM_Source_BuildPeaks(
      job.source,
      2
    )

    job.phase = "read"
    job.progress = 1
  end

  if job.phase == "read" then
    local waveform =
      read_waveform_from_source(
        job.source,
        job.duration,
        job.channels,
        job.points,
        job.preserve_channels
      )

    destroy_wave_job(job)

    if waveform then
      return "done", waveform
    end

    return "failed", nil, "峰值读取为空"
  end

  return "working"
end

function memory_wave_key(asset, points, preserve_channels)
  return wave_cache_key(asset, points, preserve_channels)
end

function store_wave_memory(key, waveform)
  state.wave_clock = state.wave_clock + 1

  if not state.wave_cache[key] then
    state.wave_cache_count =
      state.wave_cache_count + 1
  end

  state.wave_cache[key] = {
    waveform = waveform,
    used = state.wave_clock,
  }

  while state.wave_cache_count
    > MAX_WAVE_MEMORY do

    local oldest_key = nil
    local oldest_use = math.huge

    for candidate, entry in pairs(state.wave_cache) do
      if entry.used < oldest_use then
        oldest_key = candidate
        oldest_use = entry.used
      end
    end

    if not oldest_key then
      break
    end

    state.wave_cache[oldest_key] = nil
    state.wave_cache_count =
      state.wave_cache_count - 1
  end
end

function queue_wave(asset, points, priority, preserve_channels)
  if asset.wave_error then
    return nil
  end

  preserve_channels = preserve_channels == true

  local key = memory_wave_key(asset, points, preserve_channels)
  local cached = state.wave_cache[key]

  state.wave_clock = state.wave_clock + 1

  if cached then
    cached.used = state.wave_clock
    return cached.waveform
  end

  if not state.wave_checked[key] then
    state.wave_checked[key] = true

    local disk_wave =
      load_wave_from_disk(asset, points, preserve_channels)

    if disk_wave then
      store_wave_memory(key, disk_wave)
      return disk_wave
    end
  end

  if not state.wave_queued[key] then
    if #state.wave_queue >= MAX_WORK_QUEUE
      and not priority then
      return nil
    end

    state.wave_queued[key] = true

    local job = {
      key = key,
      asset = asset,
      points = points,
      preserve_channels = preserve_channels,
    }

    if priority then
      table.insert(state.wave_queue, 1, job)
    else
      state.wave_queue[#state.wave_queue + 1] = job
    end
  end

  return nil
end

function process_wave_queue()
  if state.import_session
    or state.precache_session then
    return
  end

  if not can_run_heavy_job() then
    return
  end

  local now = reaper.time_precise()

  if now < state.next_wave_job then
    return
  end

  if not state.wave_active then
    local job = table.remove(state.wave_queue, 1)

    if not job then
      return
    end

    state.wave_active = job
    job.job_token =
      Jobs.begin(
        "waveform",
        "waveform_reader",
        true
      )
  end

  local job = state.wave_active
  local result, waveform, err =
    step_wave_job(job)

  if result == "done" then
    job.asset.wave_error = nil
    clear_failed_task(job.asset)
    store_wave_memory(job.key, waveform)
    save_wave_to_disk(
      job.asset,
      job.points,
      waveform,
      job.preserve_channels
    )

    state.wave_queued[job.key] = nil
    state.wave_active = nil
    Jobs.finish(job.job_token, true)
  elseif result == "failed" then
    destroy_wave_job(job)
    job.asset.wave_error = tostring(err or "波形建立失败")
    record_failed_task(job.asset, "waveform", job.asset.wave_error)
    state.wave_queued[job.key] = nil
    state.wave_active = nil
    Jobs.finish(job.job_token, false, err)
    set_status(
      "波形建立失败："
        .. basename(job.asset.path)
        .. "（"
        .. tostring(err)
        .. "）",
      true
    )
  end

  state.next_wave_job = now + WAVE_INTERVAL
end

function wave_cache_file_exists(asset, points, preserve_channels)
  return load_wave_from_disk(
    asset,
    points,
    preserve_channels
  ) ~= nil
end

function start_wave_precache(points, scope)
  if state.scan or state.import_session then
    set_status(
      "请等待当前扫描或导入完成后再预缓存",
      true
    )
    return
  end

  if state.precache_session then
    set_status(
      "高精度波形预缓存已经在运行",
      true
    )
    return
  end

  points =
    tonumber(points) == 2048 and 2048 or 4096

  local job_token =
    Jobs.begin("wave_precache", "catalog_exclusive", false)

  if not job_token then
    set_status("另一个维护任务正在运行", true)
    return
  end

  state.precache_cancel_requested = false
  scope = scope or "all"
  state.precache_session = {
    phase = "collect",
    source = state.assets,
    source_total = #state.assets,
    collect_index = 1,
    filter_root = scope == "current" and state.root_filter or nil,
    filter_library_id = scope == "current"
      and not state.root_filter and state.library_filter_id or nil,
    assets = {},
    total = 0,
    index = 1,
    generated = 0,
    cached = 0,
    failed = 0,
    points = points,
    preserve_channels = state.multichannel_waveform,
    scope = scope,
    current = nil,
    started = reaper.time_precise(),
    job_token = job_token,
  }

  set_status(
    string.format(
      "正在整理高精度波形预缓存范围：0 / %d",
      #state.assets
    )
  )
end

function finish_wave_precache()
  local session = state.precache_session

  if not session then
    return
  end

  local elapsed =
    reaper.time_precise() - session.started

  set_status(
    string.format(
      "预缓存完成：新生成 %d，已有缓存 %d，失败 %d，%.1f 秒",
      session.generated,
      session.cached,
      session.failed,
      elapsed
    ),
    session.failed > 0
  )

  state.precache_session = nil
  state.precache_cancel_requested = false
  Jobs.finish(session.job_token, true)
end

function cancel_wave_precache()
  local session = state.precache_session

  if not session then
    return
  end

  if session.current then
    destroy_wave_job(session.current)
  end

  state.precache_session = nil
  state.precache_cancel_requested = false
  Jobs.cancel(session.job_token)
  Jobs.finish(session.job_token, true, "canceled")
  set_status("已取消高精度波形预缓存")
end

function process_wave_precache()
  local session = state.precache_session

  if not session then
    return
  end

  if state.precache_cancel_requested then
    cancel_wave_precache()
    return
  end

  if session.job_token
    and session.job_token.cancel_requested then
    cancel_wave_precache()
    return
  end

  if not can_run_heavy_job() then
    return
  end

  local now = reaper.time_precise()

  if session.phase == "collect" then
    local processed = 0
    local deadline = now + PRECACHE_FRAME_BUDGET
    while session.collect_index <= session.source_total
      and processed < PRECACHE_COLLECT_FILES_PER_FRAME
      and reaper.time_precise() < deadline do
      local asset = session.source[session.collect_index]
      session.collect_index = session.collect_index + 1
      processed = processed + 1
      local include = asset and asset.ready
      if include and session.filter_root then
        include = path_is_inside(asset.path, session.filter_root)
      elseif include and session.filter_library_id then
        include = asset.library_id == session.filter_library_id
      end
      if include and reaper.file_exists(asset.path) then
        session.assets[#session.assets + 1] = asset
      end
    end
    if session.collect_index > session.source_total then
      session.source = nil
      session.phase = "precache"
      session.total = #session.assets
      if session.total == 0 then
        state.precache_session = nil
        state.precache_cancel_requested = false
        Jobs.finish(session.job_token, true)
        set_status("当前范围没有可预缓存的素材", true)
      else
        set_status(string.format(
          "开始预缓存 %d 个素材的 %d 点高精度波形",
          session.total,
          session.points
        ))
      end
    end
    return
  end

  if now < state.next_wave_job then
    return
  end

  if not session.current then
    local probed = 0
    local deadline = now + PRECACHE_FRAME_BUDGET
    while session.index <= session.total
      and probed < PRECACHE_CACHE_PROBES_PER_FRAME
      and reaper.time_precise() < deadline do
      local asset =
        session.assets[session.index]
      probed = probed + 1

      if wave_cache_file_exists(
        asset,
        session.points,
        session.preserve_channels
      ) then
        session.cached =
          session.cached + 1
        session.index =
          session.index + 1
      else
        session.current = {
          key =
            memory_wave_key(
              asset,
              session.points,
              session.preserve_channels
            ),
          asset = asset,
          points = session.points,
          preserve_channels = session.preserve_channels,
          progress = 0,
        }
        break
      end
    end

    if not session.current
      and session.index > session.total then
      finish_wave_precache()
      return
    end
    if not session.current then
      return
    end
  end

  local job = session.current
  local result, waveform =
    step_wave_job(job)

  if result == "done" then
    save_wave_to_disk(
      job.asset,
      job.points,
      waveform,
      session.preserve_channels
    )

    if state.selected_path
      and path_key(state.selected_path)
        == path_key(job.asset.path) then
      store_wave_memory(
        job.key,
        waveform
      )
    end

    session.generated =
      session.generated + 1
    session.index =
      session.index + 1
    session.current = nil
  elseif result == "failed" then
    destroy_wave_job(job)
    session.failed =
      session.failed + 1
    session.index =
      session.index + 1
    session.current = nil
  end

  state.next_wave_job =
    now + WAVE_INTERVAL
end

function clear_wave_cache()
  reset_wave_cache_runtime()

  while true do
    local file =
      reaper.EnumerateFiles(
        WAVE_CACHE_DIR,
        0
      )

    if not file then
      break
    end

    os.remove(join_path(WAVE_CACHE_DIR, file))
  end

  set_status("已清空波形缓存")
end

function validate_wave_cache_file(path)
  local file = io.open(path, "rb")

  if not file then
    return false, "无法打开"
  end

  local header = file:read("*l") or ""
  local version, count_text, channels_text =
    header:match("^(RWF3)%s+(%d+)%s+(%d+)$")
  local expected

  if version == "RWF3" then
    local count = tonumber(count_text) or 0
    local channels = tonumber(channels_text) or 0

    if count < 1 or count > LARGE_WAVE_MAX_POINTS
      or channels < 1 or channels > 8 then
      file:close()
      return false, "RWF3 头部无效"
    end

    expected = count * channels * 2
  else
    version, count_text = header:match("^(RWF2)%s+(%d+)$")

    if version == "RWF2" then
      local count = tonumber(count_text) or 0

      if count < 1 or count > LARGE_WAVE_MAX_POINTS then
        file:close()
        return false, "RWF2 头部无效"
      end

      expected = count * 2
    else
      local count = tonumber(header)

      if not count or count < 1 or count > LARGE_WAVE_MAX_POINTS then
        file:close()
        return false, "未知缓存格式"
      end

      expected = count
    end
  end

  local data_start = file:seek() or 0
  local total_size = file:seek("end") or 0
  file:close()

  if total_size - data_start ~= expected then
    return false, "缓存长度不匹配"
  end

  return true
end

function start_wave_cache_verification()
  if state.cache_verify_session then
    set_status("波形缓存检查已经在运行", true)
    return
  end

  if state.scan or state.import_session or state.precache_session then
    set_status("请等待当前后台任务完成", true)
    return
  end

  local job_token =
    Jobs.begin("cache_verify", "catalog_exclusive", false)

  if not job_token then
    set_status("另一个维护任务正在运行", true)
    return
  end

  local files = {}
  local index = 0

  while true do
    local filename = reaper.EnumerateFiles(WAVE_CACHE_DIR, index)

    if not filename then
      break
    end

    if safe_lower(extension(filename)) == "rwf" then
      files[#files + 1] = filename
    end

    index = index + 1
  end

  state.cache_verify_session = {
    files = files,
    total = #files,
    index = 1,
    valid = 0,
    invalid = 0,
    started = reaper.time_precise(),
    job_token = job_token,
  }

  set_status(string.format("开始检查 %d 个波形缓存", #files))
end

function process_wave_cache_verification()
  local session = state.cache_verify_session

  if not session or not can_run_heavy_job() then
    return
  end

  if session.job_token
    and session.job_token.cancel_requested then
    state.cache_verify_session = nil
    Jobs.finish(session.job_token, true, "canceled")
    return
  end

  for _ = 1, CACHE_VERIFY_FILES_PER_FRAME do
    local filename = session.files[session.index]

    if not filename then
      local elapsed = reaper.time_precise() - session.started
      local invalid = session.invalid
      state.cache_verify_session = nil
      Jobs.finish(session.job_token, true)
      reset_wave_cache_runtime()
      set_status(
        string.format(
          "缓存检查完成：有效 %d，隔离损坏 %d，%.1f 秒",
          session.valid,
          invalid,
          elapsed
        ),
        invalid > 0
      )
      return
    end

    local path = join_path(WAVE_CACHE_DIR, filename)
    local valid = validate_wave_cache_file(path)

    if valid then
      session.valid = session.valid + 1
    else
      local quarantine = join_path(
        CACHE_QUARANTINE_DIR,
        os.date("%Y%m%d_%H%M%S_") .. filename
      )

      if copy_file_streaming(path, quarantine) then
        os.remove(path)
      end

      session.invalid = session.invalid + 1
    end

    session.index = session.index + 1
  end
end

----------------------------------------------------------------
-- Import preparation pipeline
----------------------------------------------------------------

function finish_import_session()
  local session = state.import_session

  if not session then
    return
  end

  local elapsed =
    reaper.time_precise() - session.started

  for _, asset in ipairs(session.assets) do
    asset.pending_batch = nil
  end

  state.import_session = nil
  state.import_cancel_requested = false
  state.results_dirty = true
  mark_database_snapshot_dirty()

  save_database()
  save_failed_tasks()
  clear_scan_checkpoint()
  Jobs.finish(session.job_token, true)

  if session.silent then
    set_status(
      string.format(
        "后台更新：新增 %d 个，移除 %d 个，失败 %d 个",
        session.done - session.failed,
        session.removed or 0,
        session.failed
      ),
      session.failed > 0
    )
  else
    set_status(
      string.format(
        "导入完成：%d 个可用，%d 个失败，%.1f 秒",
        session.done - session.failed,
        session.failed,
        elapsed
      ),
      session.failed > 0
    )
  end
end

function cancel_import_session()
  local session = state.import_session

  if not session then
    return
  end

  if session.current and session.current.wave_job then
    destroy_wave_job(session.current.wave_job)
  end

  -- 未完成的素材保持隐藏，并从本轮数据库中移除，避免“读取中”残留。
  for _, asset in ipairs(session.assets) do
    if not asset.ready then
      state.by_path[path_key(asset.path)] = nil
    else
      asset.pending_batch = nil
    end
  end

  rebuild_assets()
  state.import_session = nil
  state.import_cancel_requested = false
  mark_database_snapshot_dirty()
  save_database()
  Jobs.cancel(session.job_token)
  Jobs.finish(session.job_token, true, "canceled")
  set_status("已取消导入；已完成的素材保留")
end

function process_import_session()
  local session = state.import_session

  if not session then
    return
  end

  if session.job_token
    and session.job_token.cancel_requested then
    cancel_import_session()
    return
  end

  local checkpoint_now = reaper.time_precise()

  if checkpoint_now - (state.import_checkpoint_last_at or 0)
      >= IMPORT_CHECKPOINT_INTERVAL then
    save_database_changes()
    save_failed_tasks()
    state.import_checkpoint_last_at = checkpoint_now
  end

  if state.import_cancel_requested then
    cancel_import_session()
    return
  end

  if not can_run_heavy_job() then
    return
  end

  if not session.current then
    local asset =
      session.assets[session.done + 1]

    if not asset then
      finish_import_session()
      return
    end

    session.current = {
      asset = asset,
      phase = "metadata",
      progress = 0,
    }
  end

  local current = session.current
  local asset = current.asset

  if current.phase == "metadata" then
    current.progress = 0.08

    if not asset.indexed then
      local ok = index_asset(asset)

      if not ok then
        asset.wave_error = "媒体文件无法读取"
        record_failed_task(asset, "metadata", asset.wave_error)
        asset.ready = true
        session.failed = session.failed + 1
        session.done = session.done + 1
        session.current = nil
        mark_asset_database_change(asset)
        return
      end
    end

    local key =
      memory_wave_key(
        asset,
        state.mini_wave_points
      )

    local cached = state.wave_cache[key]
      and state.wave_cache[key].waveform
      or load_wave_from_disk(
        asset,
        state.mini_wave_points
      )

    if cached then
      store_wave_memory(key, cached)
      asset.ready = true
      asset.wave_error = nil
      clear_failed_task(asset)
      session.done = session.done + 1
      session.current = nil
      mark_asset_database_change(asset)
      return
    end

    current.wave_job = {
      key = key,
      asset = asset,
      points = state.mini_wave_points,
      progress = 0,
    }

    current.phase = "wave"
  end

  if current.phase == "wave" then
    local result, waveform, err =
      step_wave_job(current.wave_job)

    current.progress =
      0.10
      + 0.90
        * (current.wave_job.progress or 0)

    if result == "done" then
      store_wave_memory(
        current.wave_job.key,
        waveform
      )

      save_wave_to_disk(
        asset,
        state.mini_wave_points,
        waveform
      )

      asset.ready = true
      asset.wave_error = nil
      clear_failed_task(asset)
      session.done = session.done + 1
      session.current = nil
      mark_asset_database_change(asset)
    elseif result == "failed" then
      destroy_wave_job(current.wave_job)
      asset.ready = true
      asset.wave_error = tostring(err or "波形建立失败")
      record_failed_task(asset, "waveform", asset.wave_error)
      session.failed = session.failed + 1
      session.done = session.done + 1
      session.current = nil
      mark_asset_database_change(asset)
    end
  end
end


----------------------------------------------------------------
-- Preview
----------------------------------------------------------------

function destroy_preview_source_list(sources)
  if not sources then
    return
  end

  for _, source in ipairs(sources) do
    if source then
      reaper.PCM_Source_Destroy(source)
    end
  end
end

function cleanup_retired_preview_sources(force)
  local pending =
    state.retired_preview_sources or {}
  local now = reaper.time_precise()
  local keep = {}

  for _, retired in ipairs(pending) do
    if force or now >= retired.release_at then
      destroy_preview_source_list(retired.sources)
    else
      keep[#keep + 1] = retired
    end
  end

  state.retired_preview_sources = keep
end

function destroy_preview_sources(after_fade)
  local sources = state.preview_sources
  state.preview_sources = nil

  if not sources then
    return
  end

  if after_fade then
    state.retired_preview_sources =
      state.retired_preview_sources or {}

    state.retired_preview_sources[
      #state.retired_preview_sources + 1
    ] = {
      sources = sources,
      -- Keep SECTION and file sources alive beyond SWS's 25 ms fade.
      -- Destroying them in the same UI frame truncates the audio-thread
      -- fade and is audible as a click when Space is tapped repeatedly.
      release_at = reaper.time_precise() + 0.100,
    }
  else
    destroy_preview_source_list(sources)
  end
end

function stop_preview()
  local preview_job_token = state.preview_job_token
  state.preview_job_token = nil

  if state.preview_companion
    and type(reaper.CF_Preview_Stop) == "function" then
    pcall(
      reaper.CF_Preview_Stop,
      state.preview_companion
    )
  end

  if state.preview
    and type(reaper.CF_Preview_Stop) == "function" then
    pcall(reaper.CF_Preview_Stop, state.preview)
  elseif type(reaper.CF_Preview_StopAll) == "function" then
    pcall(reaper.CF_Preview_StopAll)
  end

  state.preview = nil
  state.preview_companion = nil
  state.preview_source = nil
  state.preview_path = nil
  state.preview_position = 0
  state.preview_length = 0
  state.preview_map_start = 0
  state.preview_map_span = 1
  state.preview_map_reverse = false
  state.preview_percent = 0
  destroy_preview_sources(true)

  if preview_job_token then
    Jobs.cancel(preview_job_token)
    Jobs.finish(preview_job_token, true, "stopped")
  end
end

function request_preview_stop()
  if not state.preview then
    stop_preview()
    return
  end

  -- CF_Preview_Stop performs its fade on the audio thread using
  -- D_FADEOUTLEN. A UI-frame volume ramp produces only a handful of
  -- coarse gain steps and can itself become audible when Space is tapped
  -- repeatedly, so stopping is deliberately delegated to SWS.
  pcall(
    reaper.CF_Preview_SetValue,
    state.preview,
    "B_LOOP",
    0
  )

  if state.preview_companion then
    pcall(
      reaper.CF_Preview_SetValue,
      state.preview_companion,
      "B_LOOP",
      0
    )
  end

  stop_preview()
end

function clear_row_selection()
  state.selected_set = {}
  state.selected_index = 0
  state.selected_path = nil
  state.selection_anchor = 0
end

function is_row_selected(asset)
  return asset
    and state.selected_set[path_key(asset.path)] == true
end

function selected_assets()
  local assets = {}

  for _, asset in ipairs(state.results) do
    if is_row_selected(asset) then
      assets[#assets + 1] = asset
    end
  end

  return assets
end

function selected_count()
  local count = 0

  for _ in pairs(state.selected_set) do
    count = count + 1
  end

  return count
end

function selected_asset()
  if state.selected_path then
    return state.by_path[path_key(state.selected_path)]
  end

  if state.selected_index >= 1 then
    return state.results[state.selected_index]
  end

  return nil
end

function select_all_results()
  state.selected_set = {}

  for _, asset in ipairs(state.results) do
    state.selected_set[path_key(asset.path)] = true
  end

  if #state.results > 0 then
    state.selected_index = 1
    state.selected_path = state.results[1].path
    state.selection_anchor = 1
  end

  set_status(
    string.format(
      "已选择 %d 个素材",
      #state.results
    )
  )
end

function has_selection()
  return state.region_end - state.region_start
      > 0.002
    and state.region_end - state.region_start
      < 0.998
end

function preview_uses_centered_mono(asset)
  return preview_asset_channel_count(asset) <= 2
    and (
      state.preview_channel_mode == "left"
      or state.preview_channel_mode == "right"
      or state.preview_channel_mode == "mono"
    )
end

function configure_preview_instance(
  preview,
  mono_output_channel
)
  if not preview then
    return
  end

  reaper.CF_Preview_SetValue(
    preview,
    "D_VOLUME",
    db_to_amp(
      state.gain_db
        + state.preview_match_offset_db
    )
  )

  apply_preview_channel_mode(
    preview,
    mono_output_channel
  )

  reaper.CF_Preview_SetValue(
    preview,
    "D_PITCH",
    state.pitch
  )

  reaper.CF_Preview_SetValue(
    preview,
    "D_PLAYRATE",
    state.rate
  )

  reaper.CF_Preview_SetValue(
    preview,
    "B_PPITCH",
    state.preserve_pitch and 1 or 0
  )

  reaper.CF_Preview_SetValue(
    preview,
    "B_LOOP",
    state.loop and 1 or 0
  )

  reaper.CF_Preview_SetValue(
    preview,
    "D_FADEINLEN",
    0.020
  )

  reaper.CF_Preview_SetValue(
    preview,
    "D_FADEOUTLEN",
    0.025
  )
end

function play_preview(
  asset,
  start_percent,
  use_selection
)
  asset = asset or selected_asset()

  if not asset then
    return
  end

  if not reaper.file_exists(asset.path) then
    set_status("文件不存在：" .. asset.path, true)
    return
  end

  queue_metadata(asset, true)
  stop_preview()

  if type(reaper.CF_CreatePreview) ~= "function" then
    reaper.OpenMediaExplorer(asset.path, true)
    state.preview_backend = "Media Explorer"
    record_preview_history(asset)

    if start_percent
      and start_percent > 0 then
      set_status(
        "未安装 SWS：Media Explorer 无法由脚本精确定位到点击位置",
        true
      )
    else
      set_status("由 Media Explorer 试听")
    end

    return
  end

  local source =
    reaper.PCM_Source_CreateFromFile(asset.path)

  if not source then
    set_status("无法建立试听源", true)
    return
  end

  local sources = { source }
  local preview_source = source
  local duration, is_qn =
    reaper.GetMediaSourceLength(source)

  duration =
    is_qn and 0 or (duration or asset.duration or 0)

  local selection =
    use_selection and has_selection()

  -- Always wrap audio previews in a SECTION source when SWS supports it.
  -- The section's source-boundary fade protects files whose first sample is
  -- not near zero. This is materially different from a UI volume animation:
  -- it is evaluated in the audio source path before the first audible buffer.
  if type(reaper.CF_PCM_Source_SetSectionInfo)
      == "function" then

    local section =
      reaper.PCM_Source_CreateFromType("SECTION")

    if section then
      local offset =
        selection
          and duration * state.region_start
          or 0

      local length =
        selection
          and duration
            * (state.region_end - state.region_start)
          or duration

      local call_ok, section_ok =
        pcall(
          reaper.CF_PCM_Source_SetSectionInfo,
          section,
          source,
          offset,
          length,
          state.reverse,
          0.020
        )

      -- 兼容不接受 fade 参数的旧版 SWS。
      if not call_ok then
        call_ok, section_ok =
          pcall(
            reaper.CF_PCM_Source_SetSectionInfo,
            section,
            source,
            offset,
            length,
            state.reverse
          )
      end

      if call_ok and section_ok then
        preview_source = section
        sources[#sources + 1] = section
      else
        reaper.PCM_Source_Destroy(section)
      end
    end
  end

  local preview =
    reaper.CF_CreatePreview(preview_source)

  if not preview then
    for _, item in ipairs(sources) do
      reaper.PCM_Source_Destroy(item)
    end

    set_status("SWS 试听对象创建失败", true)
    return
  end

  state.preview_match_offset_db =
    loudness_match_offset_db(asset)

  state.preview_source = preview_source
  configure_preview_instance(preview, 0)

  local companion = nil

  if preview_uses_centered_mono(asset) then
    companion =
      reaper.CF_CreatePreview(preview_source)

    if not companion then
      pcall(reaper.CF_Preview_Stop, preview)
      state.preview_source = nil

      for _, item in ipairs(sources) do
        reaper.PCM_Source_Destroy(item)
      end

      set_status(
        "无法建立双声道监听镜像",
        true
      )
      return
    end

    configure_preview_instance(companion, 1)
  end

  local seek_position = 0

  if not selection and start_percent then
    seek_position =
      clamp(start_percent, 0, 0.9999)
        * duration
  end

  if seek_position > 0 then
    reaper.CF_Preview_SetValue(
      preview,
      "D_POSITION",
      seek_position
    )

    if companion then
      reaper.CF_Preview_SetValue(
        companion,
        "D_POSITION",
        seek_position
      )
    end
  end

  local played =
    reaper.CF_Preview_Play(preview)

  local companion_played =
    not companion
      or reaper.CF_Preview_Play(companion)

  if not played or not companion_played then
    if played then
      pcall(reaper.CF_Preview_Stop, preview)
    end

    if companion then
      pcall(reaper.CF_Preview_Stop, companion)
    end

    state.preview_source = nil

    for _, item in ipairs(sources) do
      reaper.PCM_Source_Destroy(item)
    end

    set_status("试听启动失败", true)
    return
  end

  state.preview = preview
  state.preview_companion = companion
  state.preview_sources = sources
  state.preview_path = asset.path
  state.preview_job_token =
    Jobs.begin(
      "preview",
      "preview_engine",
      true,
      200
    )
  record_preview_history(asset)

  if selection then
    state.preview_map_start = state.region_start
    state.preview_map_span =
      state.region_end - state.region_start
  else
    state.preview_map_start = 0
    state.preview_map_span = 1
  end

  state.preview_map_reverse = state.reverse

  local ok_length, length =
    reaper.CF_Preview_GetValue(
      preview,
      "D_LENGTH",
      0
    )

  state.preview_length =
    selection
      and duration
        * (state.region_end - state.region_start)
      or (ok_length and length or duration)

  set_status(
    start_percent
      and string.format(
        "从 %.1f%% 开始试听：%s",
        start_percent * 100,
        asset.name
      )
      or "试听：" .. asset.name
  )
end

function update_preview_parameters()
  if not state.preview then
    return
  end

  local asset =
    state.preview_path
    and state.by_path[path_key(state.preview_path)]
    or selected_asset()

  state.preview_match_offset_db =
    loudness_match_offset_db(asset)

  local needs_companion =
    preview_uses_centered_mono(asset)

  if needs_companion
    and not state.preview_companion
    and state.preview_source then
    local companion =
      reaper.CF_CreatePreview(state.preview_source)

    if companion then
      configure_preview_instance(companion, 1)

      local ok_position, position =
        reaper.CF_Preview_GetValue(
          state.preview,
          "D_POSITION",
          0
        )

      if reaper.CF_Preview_Play(companion) then
        if ok_position and position then
          reaper.CF_Preview_SetValue(
            companion,
            "D_POSITION",
            position
          )
        end

        state.preview_companion = companion
      else
        pcall(reaper.CF_Preview_Stop, companion)
      end
    end
  elseif not needs_companion
    and state.preview_companion then
    pcall(
      reaper.CF_Preview_Stop,
      state.preview_companion
    )
    state.preview_companion = nil
  end

  configure_preview_instance(state.preview, 0)

  if state.preview_companion then
    configure_preview_instance(
      state.preview_companion,
      1
    )
  end
end

function poll_preview()
  if not state.preview then
    return
  end

  local ok, position =
    reaper.CF_Preview_GetValue(
      state.preview,
      "D_POSITION",
      0
    )

  if not ok then
    if state.preview_companion then
      pcall(
        reaper.CF_Preview_Stop,
        state.preview_companion
      )
    end

    state.preview = nil
    state.preview_companion = nil
    state.preview_source = nil
    state.preview_path = nil
    Jobs.finish(state.preview_job_token, true)
    state.preview_job_token = nil
    destroy_preview_sources()
    return
  end

  state.preview_position = position or 0

  if state.preview_length > 0 then
    local local_percent =
      clamp(
        state.preview_position
          / state.preview_length,
        0,
        1
      )

    if state.preview_map_reverse then
      local_percent = 1 - local_percent
    end

    state.preview_percent =
      clamp(
        state.preview_map_start
          + state.preview_map_span
            * local_percent,
        0,
        1
      )
  end
end

----------------------------------------------------------------
-- Selection, favorites and insertion
----------------------------------------------------------------

function focus_asset(index, auto_play)
  if #state.results == 0 then
    clear_row_selection()
    return
  end

  index = clamp(index, 1, #state.results)
  local asset = state.results[index]
  local changed =
    path_key(state.selected_path or "")
      ~= path_key(asset.path)

  state.selected_index = index
  state.selected_path = asset.path

  if changed then
    state.region_start = 0
    state.region_end = 1
    state.wave_view_start = 0
    state.wave_view_end = 1
    state.wave_pan_last_x = nil
    state.active_region_index = 0
    queue_metadata(asset, true)
    queue_wave(asset, LARGE_WAVE_DEFAULT_POINTS, true)

    if auto_play == nil then
      auto_play = state.auto_preview
    end

    if auto_play then
      play_preview(asset, 0, false)
    end
  end
end

function select_result(index, auto_play)
  clear_row_selection()

  if #state.results == 0 then
    return
  end

  index = clamp(index, 1, #state.results)
  local asset = state.results[index]
  state.selected_set[path_key(asset.path)] = true
  state.selection_anchor = index
  focus_asset(index, auto_play)
end

function select_result_with_modifiers(
  index,
  ctrl,
  shift,
  auto_play
)
  if #state.results == 0 then
    return
  end

  index = clamp(index, 1, #state.results)
  local asset = state.results[index]
  local key = path_key(asset.path)

  if shift and state.selection_anchor > 0 then
    if not ctrl then
      state.selected_set = {}
    end

    local first =
      math.min(state.selection_anchor, index)
    local last =
      math.max(state.selection_anchor, index)

    for position = first, last do
      local range_asset = state.results[position]
      state.selected_set[path_key(range_asset.path)] = true
    end

    focus_asset(index, false)
  elseif ctrl then
    if state.selected_set[key] then
      state.selected_set[key] = nil
    else
      state.selected_set[key] = true
    end

    state.selection_anchor = index
    focus_asset(index, false)
  else
    state.selected_set = { [key] = true }
    state.selection_anchor = index
    focus_asset(index, auto_play)
  end
end

function set_assets_marked(assets, marked)
  local changed = false

  for _, asset in ipairs(assets or {}) do
    local next_value = marked == true

    if asset.marked ~= next_value then
      asset.marked = next_value
      asset._search_blob = nil
      mark_asset_database_change(asset)
      changed = true
    end
  end

  if changed then
    state.results_dirty = true
    set_status(
      marked
        and "已标记所选素材"
        or "已取消所选素材标记"
    )
  end
end

function toggle_mark(asset)
  if not asset then
    return
  end

  set_assets_marked(
    { asset },
    not asset.marked
  )
end

function toggle_favorite(asset)
  if not asset then
    return
  end

  local key = path_key(asset.path)

  if state.favorites[key] then
    state.favorites[key] = nil
    set_status("已取消收藏：" .. asset.name)
  else
    state.favorites[key] = true
    set_status("已收藏：" .. asset.name)
  end

  state.config_dirty = true

  if state.view == "favorites" then
    state.results_dirty = true
  end
end

function push_recent(asset, project_action)
  local key = path_key(asset.path)
  local updated = { asset.path }

  for _, path in ipairs(state.recent) do
    if path_key(path) ~= key
      and #updated < 100 then
      updated[#updated + 1] = path
    end
  end

  state.recent = updated
  asset.used_count =
    (tonumber(asset.used_count) or 0) + 1
  asset.last_used = os.time()

  state.config_dirty = true
  mark_asset_database_change(asset)

  if project_action then
    record_project_usage(asset, project_action)
  end

  if state.view == "recent"
    or state.sort_mode == "used" then
    state.results_dirty = true
  end
end

function take_name(asset)
  local name = strip_extension(asset.name)

  if state.insert_lowercase then
    name = name:lower()
  end

  return state.insert_prefix
    .. name
    .. state.insert_suffix
end

function apply_insert_settings(asset)
  local count =
    reaper.CountSelectedMediaItems(PROJ)

  if count <= 0 then
    return
  end

  local item =
    reaper.GetSelectedMediaItem(
      PROJ,
      count - 1
    )

  local take =
    item and reaper.GetActiveTake(item)

  if not take then
    return
  end

  reaper.SetMediaItemTakeInfo_Value(
    take,
    "D_PITCH",
    state.pitch
  )

  reaper.SetMediaItemTakeInfo_Value(
    take,
    "D_PLAYRATE",
    state.rate
  )

  reaper.SetMediaItemTakeInfo_Value(
    take,
    "B_PPITCH",
    state.preserve_pitch and 1 or 0
  )

  reaper.SetMediaItemTakeInfo_Value(
    take,
    "D_VOL",
    db_to_amp(state.gain_db)
  )

  reaper.GetSetMediaItemTakeInfo_String(
    take,
    "P_NAME",
    take_name(asset),
    true
  )

  local fade =
    math.max(
      0,
      tonumber(state.insert_fade_ms) or 0
    ) / 1000

  reaper.SetMediaItemInfo_Value(
    item,
    "D_FADEINLEN",
    fade
  )

  reaper.SetMediaItemInfo_Value(
    item,
    "D_FADEOUTLEN",
    fade
  )
end

function insert_asset(asset, new_track, bwf)
  asset = asset or selected_asset()

  if not asset then
    return
  end

  if not reaper.file_exists(asset.path) then
    set_status("文件不存在：" .. asset.path, true)
    return
  end

  stop_preview()

  local mode = new_track and 1 or 0

  if bwf then
    mode = mode | 4096
  end

  if state.reverse then
    mode = mode | 8192
  end

  local start_percent = 0
  local end_percent = 1

  if has_selection() then
    start_percent = state.region_start
    end_percent = state.region_end
    mode = mode | 128
  end

  reaper.Undo_BeginBlock2(PROJ)
  reaper.PreventUIRefresh(1)

  local result =
    reaper.InsertMediaSection(
      asset.path,
      mode,
      start_percent,
      end_percent,
      0
    )

  if result >= 0 then
    apply_insert_settings(asset)
    push_recent(asset, "insert")
    reaper.UpdateArrange()
    set_status("已插入：" .. asset.name)
  else
    set_status("插入失败：" .. asset.name, true)
  end

  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock2(
    PROJ,
    "从 PsyReaSFX 插入音频",
    -1
  )
end

----------------------------------------------------------------
-- 0.7 Transfer rendering
----------------------------------------------------------------

function sanitize_transfer_name(value)
  value = trim(tostring(value or ""))
  value = value:gsub("[%z\1-\31]", "_")
  value = value:gsub("[\\/:*?\"<>|]", "_")
  value = value:gsub("%s+", " ")
  value = value:gsub("[%. ]+$", "")
  value = value:gsub("^%s+", "")

  if value == "" then
    value = "untitled"
  end

  if (utf8_length(value) or #value) > 160 then
    value = utf8_prefix(value, 160)
  end

  if state.transfer_lowercase then
    value = value:lower()
  end

  return value
end

function transfer_region_name(asset)
  local regions = asset_regions(asset)
  local active = regions[state.active_region_index or 0]

  if active and trim(active.name or "") ~= "" then
    return active.name
  end

  return has_selection() and "selection" or "full"
end

function transfer_variant_number(value, decimals)
  local format_string = "%." .. tostring(decimals or 2) .. "f"
  local text = string.format(format_string, tonumber(value) or 0)
  text = text:gsub("(%..-)0+$", "%1")
  text = text:gsub("%.$", "")

  if text == "-0" then
    text = "0"
  end

  return text
end

function transfer_variant_token(value, decimals)
  local text = transfer_variant_number(value, decimals)
  text = text:gsub("%+", "")
  text = text:gsub("%-", "m")
  text = text:gsub("%.", "p")
  return text
end

function parse_transfer_variant_values(
  text,
  fallback,
  minimum,
  maximum,
  decimals,
  label
)
  local values = {}
  local seen = {}
  local had_token = false

  for token in tostring(text or ""):gmatch("[^,%s;|]+") do
    had_token = true
    local value = tonumber(token)

    if not value then
      return nil,
        string.format(
          "%s: %s",
          translate_ui_text("无效的变体数值"),
          token
        )
    end

    value = clamp(value, minimum, maximum)
    local scale = 10 ^ (decimals or 2)
    value = math.floor(value * scale + 0.5) / scale
    local key = string.format("%.6f", value)

    if not seen[key] then
      seen[key] = true
      values[#values + 1] = value
    end

    if #values > 16 then
      return nil,
        translate_ui_text("每个变体参数最多允许 16 个数值")
    end
  end

  if not had_token or #values == 0 then
    values[1] = fallback
  end

  table.sort(values)
  return values, nil
end

function build_transfer_variants()
  if not state.transfer_variants_enabled then
    return {
      {
        pitch = state.pitch,
        rate = state.rate,
        gain_db = state.gain_db,
        reverse = state.reverse,
        index = 1,
        count = 1,
        label = "current",
      },
    }, nil
  end

  local pitches, pitch_error =
    parse_transfer_variant_values(
      state.transfer_variant_pitches,
      state.pitch,
      -48,
      48,
      2,
      "Pitch"
    )

  if not pitches then
    return nil, pitch_error
  end

  local rates, rate_error =
    parse_transfer_variant_values(
      state.transfer_variant_rates,
      state.rate,
      0.1,
      4,
      3,
      "Rate"
    )

  if not rates then
    return nil, rate_error
  end

  local gains, gain_error =
    parse_transfer_variant_values(
      state.transfer_variant_gains,
      state.gain_db,
      -60,
      24,
      2,
      "Gain"
    )

  if not gains then
    return nil, gain_error
  end

  local directions =
    state.transfer_variant_include_reverse
      and { false, true }
      or { state.reverse }
  local variants = {}

  for _, pitch in ipairs(pitches) do
    for _, rate in ipairs(rates) do
      for _, gain_db in ipairs(gains) do
        for _, reverse in ipairs(directions) do
          if #variants >= 128 then
            return nil,
              translate_ui_text(
                "变体组合超过 128 个，请减少参数数量"
              )
          end

          local label =
            "p" .. transfer_variant_token(pitch, 2)
              .. "_r" .. transfer_variant_token(rate, 3)
              .. "_g" .. transfer_variant_token(gain_db, 2)
              .. (reverse and "_rev" or "_fwd")

          variants[#variants + 1] = {
            pitch = pitch,
            rate = rate,
            gain_db = gain_db,
            reverse = reverse,
            label = label,
          }
        end
      end
    end
  end

  for index, variant in ipairs(variants) do
    variant.index = index
    variant.count = #variants
  end

  return variants, nil
end

function expand_transfer_template(asset, index, variant)
  local template = state.transfer_template or "{name}"
  local value = template
  variant = variant or {
    pitch = state.pitch,
    rate = state.rate,
    gain_db = state.gain_db,
    reverse = state.reverse,
    index = 1,
    count = 1,
    label = "current",
  }
  local replacements = {
    name = strip_extension(asset.name or ""),
    category = asset.category or "",
    subcategory = asset.subcategory or "",
    library = asset.library or "",
    index = string.format("%02d", tonumber(index) or 1),
    date = os.date("%Y%m%d"),
    region = transfer_region_name(asset),
    pitch = transfer_variant_number(variant.pitch, 2),
    rate = transfer_variant_number(variant.rate, 3),
    gain = transfer_variant_number(variant.gain_db, 2),
    direction = variant.reverse and "reverse" or "normal",
    variant = variant.label or "current",
    variant_index = string.format(
      "%02d",
      tonumber(variant.index) or 1
    ),
  }

  value = value:gsub("{([%w_]+)}", function(key)
    return replacements[key] ~= nil
      and tostring(replacements[key])
      or "{" .. key .. "}"
  end)

  if state.transfer_variants_enabled
    and state.transfer_variant_auto_suffix
    and (variant.count or 1) > 1
    and not template:find("{variant}", 1, true)
    and not template:find("{variant_index}", 1, true)
    and not template:find("{pitch}", 1, true)
    and not template:find("{rate}", 1, true)
    and not template:find("{gain}", 1, true)
    and not template:find("{direction}", 1, true) then
    value = value .. "_" .. tostring(variant.label or "variant")
  end

  return sanitize_transfer_name(value)
end

function transfer_format_info()
  if state.transfer_format == "flac" then
    -- RENDER_FORMAT expects a base64-encoded sink configuration.
    -- "Y2FsZg==" decodes to REAPER's four-byte FLAC sink id, "calf".
    return "flac", "Y2FsZg=="
  end

  if state.transfer_format == "wav16" then
    return "wav", "ZXZhdxAAAQ=="
  elseif state.transfer_format == "wav32" then
    return "wav", "ZXZhdyAAAQ=="
  end

  -- Explicit WAV 24-bit PCM sink configuration.
  return "wav", "ZXZhdxgAAQ=="
end

function transfer_sample_rate(asset)
  if state.transfer_sample_rate == "source" then
    return math.max(0, math.floor(tonumber(asset.sample_rate) or 0))
  end

  return math.max(
    0,
    math.floor(tonumber(state.transfer_sample_rate) or 0)
  )
end

function transfer_channel_count(asset)
  if state.transfer_channels == "mono" then
    return 1
  elseif state.transfer_channels == "stereo" then
    return 2
  end

  return clamp(
    math.floor(tonumber(asset.channels) or 2),
    1,
    64
  )
end

function transfer_normalize_flags()
  local flags = 0

  if state.transfer_normalize == "peak" then
    flags = 1 | 4
  elseif state.transfer_normalize == "true_peak" then
    flags = 1 | 6
  elseif state.transfer_normalize == "rms_i" then
    flags = 1 | 2
  elseif state.transfer_normalize == "lufs_i" then
    flags = 1
  end

  if (tonumber(state.transfer_fade_in_ms) or 0) > 0 then
    flags = flags | 512
  end

  if (tonumber(state.transfer_fade_out_ms) or 0) > 0 then
    flags = flags | 1024
  end

  return flags
end

function resolve_transfer_output(asset, index, variant)
  local extension_name = transfer_format_info()
  local base = expand_transfer_template(asset, index, variant)
  local directory = normalize_slashes(trim(state.transfer_dir or ""))

  if directory == "" then
    directory = DEFAULT_TRANSFER_DIR
  end

  local candidate = join_path(
    directory,
    base .. "." .. extension_name
  )

  if not reaper.file_exists(candidate) then
    return candidate, "new"
  end

  if state.transfer_collision == "skip" then
    return nil, "skip", candidate
  elseif state.transfer_collision == "overwrite" then
    return candidate, "overwrite"
  end

  local suffix = 2

  while suffix < 10000 do
    local next_path = join_path(
      directory,
      string.format(
        "%s_%02d.%s",
        base,
        suffix,
        extension_name
      )
    )

    if not reaper.file_exists(next_path) then
      return next_path, "increment"
    end

    suffix = suffix + 1
  end

  return nil, "error", candidate
end

function capture_transfer_context()
  local context = {
    cursor = reaper.GetCursorPositionEx(PROJ),
    dirty = reaper.GetSetProjectInfo(PROJ, "DIRTY", 0, false),
    selected_items = {},
    selected_tracks = {},
    render_numbers = {},
    render_strings = {},
  }

  local time_start, time_end =
    reaper.GetSet_LoopTimeRange2(
      PROJ,
      false,
      false,
      0,
      0,
      false
    )

  context.time_start = time_start
  context.time_end = time_end

  for index = 0, reaper.CountSelectedMediaItems(PROJ) - 1 do
    context.selected_items[#context.selected_items + 1] =
      reaper.GetSelectedMediaItem(PROJ, index)
  end

  local master = reaper.GetMasterTrack(PROJ)

  if master
    and reaper.IsTrackSelected(master) then
    context.selected_tracks[#context.selected_tracks + 1] = master
  end

  for index = 0, reaper.CountTracks(PROJ) - 1 do
    local track = reaper.GetTrack(PROJ, index)

    if track and reaper.IsTrackSelected(track) then
      context.selected_tracks[#context.selected_tracks + 1] = track
    end
  end

  local number_keys = {
    "RENDER_SETTINGS",
    "RENDER_BOUNDSFLAG",
    "RENDER_CHANNELS",
    "RENDER_SRATE",
    "RENDER_STARTPOS",
    "RENDER_ENDPOS",
    "RENDER_TAILFLAG",
    "RENDER_TAILMS",
    "RENDER_ADDTOPROJ",
    "RENDER_DITHER",
    "RENDER_NORMALIZE",
    "RENDER_NORMALIZE_TARGET",
    "RENDER_BRICKWALL",
    "RENDER_FADEIN",
    "RENDER_FADEOUT",
    "RENDER_FADEINSHAPE",
    "RENDER_FADEOUTSHAPE",
  }

  for _, key in ipairs(number_keys) do
    context.render_numbers[key] =
      reaper.GetSetProjectInfo(PROJ, key, 0, false)
  end

  local string_keys = {
    "RENDER_FILE",
    "RENDER_PATTERN",
    "RENDER_FORMAT",
    "RENDER_FORMAT2",
  }

  for _, key in ipairs(string_keys) do
    local _, value =
      reaper.GetSetProjectInfo_String(PROJ, key, "", false)
    context.render_strings[key] = value or ""
  end

  return context
end

function restore_transfer_context(context, temporary_track)
  if temporary_track
    and reaper.ValidatePtr2(PROJ, temporary_track, "MediaTrack*") then
    reaper.DeleteTrack(temporary_track)
  end

  for key, value in pairs(context.render_numbers or {}) do
    reaper.GetSetProjectInfo(PROJ, key, value, true)
  end

  for key, value in pairs(context.render_strings or {}) do
    reaper.GetSetProjectInfo_String(PROJ, key, value, true)
  end

  reaper.SelectAllMediaItems(PROJ, false)

  local master = reaper.GetMasterTrack(PROJ)

  if master then
    reaper.SetTrackSelected(master, false)
  end

  for index = 0, reaper.CountTracks(PROJ) - 1 do
    reaper.SetTrackSelected(reaper.GetTrack(PROJ, index), false)
  end

  for _, item in ipairs(context.selected_items or {}) do
    if reaper.ValidatePtr2(PROJ, item, "MediaItem*") then
      reaper.SetMediaItemSelected(item, true)
    end
  end

  for _, track in ipairs(context.selected_tracks or {}) do
    if reaper.ValidatePtr2(PROJ, track, "MediaTrack*") then
      reaper.SetTrackSelected(track, true)
    end
  end

  reaper.SetEditCurPos2(
    PROJ,
    context.cursor or 0,
    false,
    false
  )

  reaper.GetSet_LoopTimeRange2(
    PROJ,
    true,
    false,
    context.time_start or 0,
    context.time_end or 0,
    false
  )

  reaper.GetSetProjectInfo(
    PROJ,
    "DIRTY",
    context.dirty or 0,
    true
  )

  reaper.UpdateArrange()
end

function detect_transfer_tail_end(
  asset,
  source,
  duration,
  selection_end,
  reverse
)
  if not state.transfer_smart_tail
    or reverse
    or not source
    or duration <= 0
    or selection_end >= 0.9999 then
    return selection_end, 0
  end

  local maximum_seconds =
    math.max(
      0,
      tonumber(state.transfer_tail_max_ms) or 0
    ) / 1000

  if maximum_seconds <= 0 then
    return selection_end, 0
  end

  local maximum_end =
    math.min(
      1,
      selection_end + maximum_seconds / duration
    )

  if maximum_end <= selection_end then
    return selection_end, 0
  end

  local points = 4096
  local waveform =
    load_wave_from_disk(asset, points, false)

  if not waveform then
    points =
      clamp(
        math.ceil(duration * 220),
        2048,
        8192
      )
    waveform =
      read_waveform_from_source(
        source,
        duration,
        tonumber(asset.channels) or 1,
        points,
        false
      )
  end

  if not waveform
    or not waveform.peaks
    or (waveform.count or 0) <= 0 then
    return selection_end, 0
  end

  local count = waveform.count
  local threshold =
    db_to_amp(
      clamp(
        tonumber(state.transfer_tail_threshold_db)
          or -60,
        -96,
        -18
      )
    )
  local first_index =
    clamp(
      math.floor(selection_end * count) + 1,
      1,
      count
    )
  local final_index =
    clamp(
      math.ceil(maximum_end * count),
      first_index,
      count
    )
  local last_above = nil

  -- Scan the entire allowed window rather than stopping at the first quiet
  -- gap. This preserves delayed repeats that arrive after a short silence.
  for index = first_index, final_index do
    if (waveform.peaks[index] or 0) >= threshold then
      last_above = index
    end
  end

  if not last_above then
    return selection_end, 0
  end

  local hold_seconds =
    math.max(
      0,
      tonumber(state.transfer_tail_hold_ms) or 0
    ) / 1000
  local detected_end =
    math.min(
      maximum_end,
      last_above / count
        + hold_seconds / duration
    )

  detected_end =
    clamp(detected_end, selection_end, 1)

  return detected_end,
    math.max(
      0,
      (detected_end - selection_end)
        * duration
        * 1000
    )
end

function create_transfer_item(asset, use_selection, variant)
  variant = variant or {
    pitch = state.pitch,
    rate = state.rate,
    gain_db = state.gain_db,
    reverse = state.reverse,
  }
  local track_index = reaper.CountTracks(PROJ)
  reaper.InsertTrackInProject(PROJ, track_index, 0)
  local track = reaper.GetTrack(PROJ, track_index)

  if not track then
    return nil, nil, "temporary track"
  end

  reaper.GetSetMediaTrackInfo_String(
    track,
    "P_NAME",
    "PsyReaSFX Transfer (temporary)",
    true
  )

  local source = reaper.PCM_Source_CreateFromFile(asset.path)

  if not source then
    return track, nil, "source"
  end

  local duration, is_qn = reaper.GetMediaSourceLength(source)
  duration = is_qn and 0 or (duration or asset.duration or 0)

  if duration <= 0 then
    reaper.PCM_Source_Destroy(source)
    return track, nil, "duration"
  end

  local start_percent = 0
  local end_percent = 1

  if use_selection and has_selection() then
    start_percent = clamp(state.region_start, 0, 1)
    end_percent = clamp(state.region_end, start_percent, 1)

    end_percent, state.transfer_last_tail_ms =
      detect_transfer_tail_end(
        asset,
        source,
        duration,
        end_percent,
        variant.reverse
      )
  else
    state.transfer_last_tail_ms = 0
  end

  local source_start = duration * start_percent
  local source_length = duration * (end_percent - start_percent)
  local take_source = source
  local take_start_offset = source_start

  if variant.reverse then
    if type(reaper.CF_PCM_Source_SetSectionInfo) ~= "function" then
      reaper.PCM_Source_Destroy(source)
      return track, nil, "reverse requires SWS"
    end

    local section = reaper.PCM_Source_CreateFromType("SECTION")
    local ok = section and reaper.CF_PCM_Source_SetSectionInfo(
      section,
      source,
      source_start,
      source_length,
      true
    )

    if not ok then
      if section then
        reaper.PCM_Source_Destroy(section)
      end
      reaper.PCM_Source_Destroy(source)
      return track, nil, "reverse source"
    end

    take_source = section
    take_start_offset = 0
  end

  local item = reaper.AddMediaItemToTrack(track)
  local take = item and reaper.AddTakeToMediaItem(item)

  if not take then
    if take_source ~= source then
      reaper.PCM_Source_Destroy(take_source)
    end
    reaper.PCM_Source_Destroy(source)
    return track, nil, "media item"
  end

  reaper.SetMediaItemTake_Source(take, take_source)
  reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", take_start_offset)
  reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", variant.rate)
  reaper.SetMediaItemTakeInfo_Value(take, "D_PITCH", variant.pitch)
  reaper.SetMediaItemTakeInfo_Value(
    take,
    "B_PPITCH",
    state.preserve_pitch and 1 or 0
  )
  reaper.SetMediaItemTakeInfo_Value(
    take,
    "D_VOL",
    db_to_amp(variant.gain_db)
  )

  if state.transfer_channels == "mono" then
    reaper.SetMediaItemTakeInfo_Value(take, "I_CHANMODE", 2)
  end

  local item_position = reaper.GetProjectLength(PROJ) + 10
  local item_length =
    source_length / math.max(0.01, variant.rate)
  reaper.SetMediaItemPosition(item, item_position, false)
  reaper.SetMediaItemLength(item, item_length, false)
  -- Transfer fades are applied by REAPER's render post-processing flags.
  -- Do not also apply item fades here, otherwise the requested fade would
  -- be processed twice.

  reaper.GetSetMediaItemTakeInfo_String(
    take,
    "P_NAME",
    strip_extension(asset.name),
    true
  )

  reaper.SelectAllMediaItems(PROJ, false)
  reaper.SetMediaItemSelected(item, true)
  reaper.SetOnlyTrackSelected(track)

  return track, item, nil
end

function configure_transfer_render(asset, output_path)
  local _, sink_config = transfer_format_info()
  local output_directory = dirname(output_path)
  local output_pattern = strip_extension(basename(output_path))
  local render_settings = 32
  local dither_flags = 0

  if state.transfer_preserve_metadata then
    render_settings = render_settings | 32768
  end

  if state.transfer_format == "wav16"
    and state.transfer_dither then
    dither_flags = dither_flags | 1
  end

  if state.transfer_format == "wav16"
    and state.transfer_noise_shaping then
    dither_flags = dither_flags | 2
  end

  reaper.GetSetProjectInfo(
    PROJ,
    "RENDER_SETTINGS",
    render_settings,
    true
  )
  reaper.GetSetProjectInfo(PROJ, "RENDER_BOUNDSFLAG", 4, true)
  reaper.GetSetProjectInfo(
    PROJ,
    "RENDER_CHANNELS",
    transfer_channel_count(asset),
    true
  )
  reaper.GetSetProjectInfo(
    PROJ,
    "RENDER_SRATE",
    transfer_sample_rate(asset),
    true
  )
  reaper.GetSetProjectInfo(PROJ, "RENDER_TAILFLAG", 0, true)
  reaper.GetSetProjectInfo(PROJ, "RENDER_TAILMS", 0, true)
  reaper.GetSetProjectInfo(PROJ, "RENDER_ADDTOPROJ", 0, true)
  reaper.GetSetProjectInfo(
    PROJ,
    "RENDER_DITHER",
    dither_flags,
    true
  )
  reaper.GetSetProjectInfo(
    PROJ,
    "RENDER_NORMALIZE",
    transfer_normalize_flags(),
    true
  )
  reaper.GetSetProjectInfo(
    PROJ,
    "RENDER_NORMALIZE_TARGET",
    db_to_amp(state.transfer_normalize_target),
    true
  )
  reaper.GetSetProjectInfo(
    PROJ,
    "RENDER_FADEIN",
    math.max(0, state.transfer_fade_in_ms) / 1000,
    true
  )
  reaper.GetSetProjectInfo(
    PROJ,
    "RENDER_FADEOUT",
    math.max(0, state.transfer_fade_out_ms) / 1000,
    true
  )
  reaper.GetSetProjectInfo(PROJ, "RENDER_FADEINSHAPE", 0, true)
  reaper.GetSetProjectInfo(PROJ, "RENDER_FADEOUTSHAPE", 0, true)
  reaper.GetSetProjectInfo_String(
    PROJ,
    "RENDER_FILE",
    output_directory,
    true
  )
  reaper.GetSetProjectInfo_String(
    PROJ,
    "RENDER_PATTERN",
    output_pattern,
    true
  )
  reaper.GetSetProjectInfo_String(
    PROJ,
    "RENDER_FORMAT",
    sink_config,
    true
  )
  reaper.GetSetProjectInfo_String(PROJ, "RENDER_FORMAT2", "", true)
end

function unique_transfer_sidecar_path(output_path, label, task_index)
  local directory = dirname(output_path)
  local extension_name =
    output_path:match("%.([^%.\\/]*)$") or "wav"
  local base = strip_extension(basename(output_path))
  local stamp =
    tostring(math.floor(reaper.time_precise() * 1000000))
  local attempt = 0

  while attempt < 1000 do
    local candidate = join_path(
      directory,
      string.format(
        "%s.psyreasfx_%s_%s_%04d_%03d.%s",
        base,
        label,
        stamp,
        tonumber(task_index) or 0,
        attempt,
        extension_name
      )
    )

    if not reaper.file_exists(candidate) then
      return candidate
    end

    attempt = attempt + 1
  end

  return nil
end

function commit_transfer_output(
  temporary_path,
  output_path,
  replace_existing,
  task_index
)
  if not temporary_path
    or not reaper.file_exists(temporary_path) then
    return false, translate_ui_text("未找到临时渲染文件")
  end

  if not replace_existing
    or not reaper.file_exists(output_path) then
    local ok, message = os.rename(temporary_path, output_path)
    return ok == true, message
  end

  local backup_path =
    unique_transfer_sidecar_path(
      output_path,
      "backup",
      task_index
    )

  if not backup_path then
    return false, translate_ui_text("无法创建安全覆盖备份")
  end

  local backed_up, backup_error =
    os.rename(output_path, backup_path)

  if not backed_up then
    return false,
      translate_ui_text("无法备份原有文件")
        .. (backup_error and (": " .. backup_error) or "")
  end

  local committed, commit_error =
    os.rename(temporary_path, output_path)

  if committed then
    os.remove(backup_path)
    return true, nil
  end

  local restored, restore_error =
    os.rename(backup_path, output_path)

  if not restored then
    return false,
      translate_ui_text("输出提交失败，原文件保存在：")
        .. backup_path
        .. (restore_error and (": " .. restore_error) or "")
  end

  return false,
    translate_ui_text("输出提交失败，原文件已恢复")
      .. (commit_error and (": " .. commit_error) or "")
end

function render_transfer_asset(task)
  local asset = task.asset
  local output_path, collision, existing =
    resolve_transfer_output(
      asset,
      task.asset_index,
      task.variant
    )

  if collision == "skip" then
    return false,
      nil,
      translate_ui_text("已跳过已有文件：") .. existing,
      true
  elseif not output_path then
    return false,
      nil,
      translate_ui_text("Transfer 渲染失败"),
      false
  end

  local temporary_path =
    unique_transfer_sidecar_path(
      output_path,
      "render",
      task.task_index
    )

  if not temporary_path then
    return false,
      nil,
      translate_ui_text("无法创建临时渲染路径"),
      false
  end

  local context = capture_transfer_context()
  local temporary_track = nil
  local render_ok = false
  local render_error = nil

  reaper.PreventUIRefresh(1)

  local setup_ok, setup_error = xpcall(function()
    temporary_track, _, render_error =
      create_transfer_item(
        asset,
        task.use_selection,
        task.variant
      )

    if render_error then
      error(render_error)
    end

    configure_transfer_render(asset, temporary_path)
  end, debug.traceback)

  reaper.PreventUIRefresh(-1)

  if setup_ok then
    local action_ok, action_error = pcall(function()
      reaper.Main_OnCommand(42230, 0)
    end)

    render_ok =
      action_ok and reaper.file_exists(temporary_path)
    render_error = action_error
  else
    render_error = setup_error
  end

  reaper.PreventUIRefresh(1)
  local restore_ok, restore_error =
    pcall(
      restore_transfer_context,
      context,
      temporary_track
    )
  reaper.PreventUIRefresh(-1)

  if not restore_ok then
    render_ok = false
    render_error = restore_error
  end

  if render_ok then
    local commit_ok, commit_error =
      commit_transfer_output(
        temporary_path,
        output_path,
        collision == "overwrite",
        task.task_index
      )
    render_ok = commit_ok
    render_error = commit_error
  end

  if not render_ok then
    if reaper.file_exists(temporary_path) then
      os.remove(temporary_path)
    end

    return false,
      nil,
      translate_ui_text("Transfer 渲染失败")
        .. (
          render_error
            and (": " .. tostring(render_error))
            or ""
        ),
      false
  end

  push_recent(
    asset,
    state.transfer_insert_after
      and "transfer_insert"
      or nil
  )

  if state.transfer_insert_after then
    reaper.InsertMedia(output_path, 1)
  end

  return true, output_path, nil, false
end

function write_transfer_report(job, canceled)
  local handle = io.open(TRANSFER_REPORT_FILE, "wb")

  if not handle then
    return false
  end

  handle:write(
    "status\tasset\tvariant\toutput\tmessage\tseconds\n"
  )

  for _, record in ipairs(job.records or {}) do
    handle:write(
      table.concat({
        escape_tsv(record.status or ""),
        escape_tsv(record.asset or ""),
        escape_tsv(record.variant or ""),
        escape_tsv(record.output or ""),
        escape_tsv(record.message or ""),
        escape_tsv(
          string.format("%.3f", record.seconds or 0)
        ),
      }, "\t"),
      "\n"
    )
  end

  if canceled then
    handle:write(
      table.concat({
        "canceled",
        "",
        "",
        "",
        escape_tsv("Stopped after current file"),
        "",
      }, "\t"),
      "\n"
    )
  end

  handle:close()
  return true
end

function finish_transfer_job(job, canceled)
  if not job then
    return
  end

  write_transfer_report(job, canceled)

  if canceled then
    Jobs.cancel(job.job_token)
  end
  Jobs.finish(job.job_token, true, canceled and "canceled" or "")

  state.transfer_running = false
  state.transfer_job = nil
  state.transfer_cancel_requested = false
  state.config_dirty = true

  local summary = string.format(
    "%s %d · %s %d · %s %d",
    translate_ui_text("完成"),
    job.success_count or 0,
    translate_ui_text("跳过"),
    job.skipped_count or 0,
    translate_ui_text("失败"),
    #(job.failures or {})
  )

  if canceled then
    summary =
      translate_ui_text("Transfer 已停止") .. " · " .. summary
  else
    summary =
      translate_ui_text("Transfer 完成") .. " · " .. summary
  end

  state.transfer_last_summary = summary

  if #(job.failures or {}) > 0 then
    state.transfer_last_error =
      table.concat(job.failures, "\n")
    set_status(summary, true)
  else
    state.transfer_last_error = ""
    set_status(summary)
  end

  if not canceled
    and (job.success_count or 0) > 0
    and state.transfer_open_dir_after then
    local completed_directory =
      state.transfer_last_output ~= ""
        and dirname(state.transfer_last_output)
        or (job.output_directory or state.transfer_dir)

    open_folder(completed_directory)
  end
end

function process_transfer_job()
  local job = state.transfer_job

  if not job then
    return
  end

  if (reaper.GetPlayStateEx(PROJ) & 1) == 1 then
    set_status(
      translate_ui_text(
        "Transfer 已暂停：请停止工程播放"
      ),
      true
    )
    return
  end

  if state.transfer_cancel_requested
    or (job.job_token
      and job.job_token.cancel_requested) then
    finish_transfer_job(job, true)
    return
  end

  local task = job.tasks[job.next_index]

  if not task then
    finish_transfer_job(job, false)
    return
  end

  local started_at = reaper.time_precise()
  local ok, output, message, skipped =
    render_transfer_asset(task)
  local elapsed =
    math.max(0, reaper.time_precise() - started_at)

  if ok then
    job.success_count = job.success_count + 1
    state.transfer_last_outputs[
      #state.transfer_last_outputs + 1
    ] = output
    state.transfer_last_output = output
  elseif skipped then
    job.skipped_count = job.skipped_count + 1
  else
    job.failures[#job.failures + 1] =
      (task.asset.name or "")
        .. " · "
        .. (message or translate_ui_text("未知错误"))
  end

  job.records[#job.records + 1] = {
    status = ok and "success" or (skipped and "skipped" or "failed"),
    asset = task.asset.path or task.asset.name or "",
    variant = task.variant.label or "current",
    output = output or "",
    message = message or "",
    seconds = elapsed,
  }

  job.next_index = job.next_index + 1
  job.completed = job.next_index - 1
  set_status(
    string.format(
      "%s %d / %d",
      translate_ui_text("正在导出"),
      job.completed,
      job.total
    )
  )
end

function run_transfer(assets, batch_mode)
  if state.transfer_running then
    return
  end

  assets = assets or {}

  if #assets == 0 then
    set_status("请先选择素材", true)
    return
  end

  if (reaper.GetPlayStateEx(PROJ) & 1) == 1 then
    set_status("工程正在播放，停止后再执行 Transfer", true)
    return
  end

  local directory = normalize_slashes(trim(state.transfer_dir or ""))

  if directory == "" then
    set_status("请选择有效的输出目录", true)
    return
  end

  if reaper.RecursiveCreateDirectory(directory, 0) <= 0
    and not directory_exists(directory) then
    set_status("无法创建输出目录", true)
    return
  end

  local variants, variant_error = build_transfer_variants()

  if not variants then
    set_status(variant_error, true)
    return
  end

  if type(reaper.CF_PCM_Source_SetSectionInfo) ~= "function" then
    for _, variant in ipairs(variants) do
      if variant.reverse then
        set_status(
          translate_ui_text(
            "反向变体需要安装 SWS Extension"
          ),
          true
        )
        return
      end
    end
  end

  local total = #assets * #variants

  if total > 4096 then
    set_status(
      translate_ui_text(
        "导出任务超过 4096 个，请减少素材或变体数量"
      ),
      true
    )
    return
  end

  local has_overwrite_target = false

  if state.transfer_collision == "overwrite" then
    local planned_targets = {}
    local extension_name = transfer_format_info()

    for asset_index, asset in ipairs(assets) do
      for _, variant in ipairs(variants) do
        local planned_path = join_path(
          directory,
          expand_transfer_template(
            asset,
            asset_index,
            variant
          ) .. "." .. extension_name
        )
        local planned_key = path_key(planned_path)
        local _, collision =
          resolve_transfer_output(
            asset,
            asset_index,
            variant
          )

        if collision == "overwrite"
          or planned_targets[planned_key] then
          has_overwrite_target = true
          break
        end

        planned_targets[planned_key] = true
      end

      if has_overwrite_target then
        break
      end
    end
  end

  if has_overwrite_target then
    local answer = reaper.MB(
      translate_ui_text(
        "同名输出将使用安全替换：先完成临时渲染，再备份并替换原文件。是否继续？"
      ),
      translate_ui_text("确认覆盖策略"),
      4
    )

    if answer ~= 6 then
      return
    end
  end

  local tasks = {}
  local task_index = 0

  for asset_index, asset in ipairs(assets) do
    local use_selection =
      not batch_mode
      and state.transfer_scope == "selection"
      and has_selection()

    for _, variant in ipairs(variants) do
      task_index = task_index + 1
      tasks[task_index] = {
        asset = asset,
        asset_index = asset_index,
        use_selection = use_selection,
        variant = variant,
        task_index = task_index,
      }
    end
  end

  local job_token =
    Jobs.begin("transfer", "catalog_exclusive", false)

  if not job_token then
    set_status(
      translate_ui_text(
        "请等待当前扫描或维护任务完成"
      ),
      true
    )
    return
  end

  stop_preview()
  state.transfer_running = true
  state.transfer_cancel_requested = false
  state.transfer_last_error = ""
  state.transfer_last_outputs = {}
  state.transfer_last_summary = ""
  state.transfer_job = {
    tasks = tasks,
    total = #tasks,
    next_index = 1,
    completed = 0,
    success_count = 0,
    skipped_count = 0,
    failures = {},
    records = {},
    started_at = reaper.time_precise(),
    output_directory = state.transfer_dir,
    job_token = job_token,
  }
  set_status(
    string.format(
      "%s 0 / %d",
      translate_ui_text("正在导出"),
      #tasks
    )
  )
end

----------------------------------------------------------------
-- Multi insert and drag-to-arrange
----------------------------------------------------------------

function ensure_track_index(track_index)
  track_index = math.max(0, math.floor(track_index or 0))

  while reaper.CountTracks(PROJ) <= track_index do
    reaper.InsertTrackInProject(
      PROJ,
      reaper.CountTracks(PROJ),
      1
    )
  end

  return reaper.GetTrack(PROJ, track_index)
end

function insert_asset_at(
  asset,
  track_index,
  position,
  start_percent,
  end_percent
)
  if not asset or not reaper.file_exists(asset.path) then
    return false
  end

  track_index = math.max(0, math.floor(track_index or 0))
  ensure_track_index(track_index)

  reaper.SetEditCurPos(
    position or reaper.GetCursorPosition(),
    false,
    false
  )

  reaper.SelectAllMediaItems(PROJ, false)

  local mode =
    512 | (track_index << 16)

  start_percent = start_percent or 0
  end_percent = end_percent or 1

  if end_percent - start_percent < 0.999 then
    mode = mode | 128
  end

  if state.reverse then
    mode = mode | 8192
  end

  local result =
    reaper.InsertMediaSection(
      asset.path,
      mode,
      start_percent,
      end_percent,
      0
    )

  if result >= 0 then
    apply_insert_settings(asset)
    push_recent(asset, "insert")
    return true
  end

  return false
end

function insert_selected_stack(
  start_percent,
  end_percent
)
  local assets = selected_assets()

  if #assets == 0 then
    local asset = selected_asset()

    if asset then
      assets = { asset }
    end
  end

  if #assets == 0 then
    return
  end

  if #assets == 1 then
    insert_asset(assets[1], false, false)
    return
  end

  local selected_track =
    reaper.GetSelectedTrack(PROJ, 0)

  local base_index = selected_track
    and math.max(
      0,
      math.floor(
        reaper.GetMediaTrackInfo_Value(
          selected_track,
          "IP_TRACKNUMBER"
        )
      ) - 1
    )
    or reaper.CountTracks(PROJ)

  local position = reaper.GetCursorPosition()

  reaper.Undo_BeginBlock2(PROJ)
  reaper.PreventUIRefresh(1)

  local inserted = 0

  for index, asset in ipairs(assets) do
    if insert_asset_at(
      asset,
      base_index + index - 1,
      position,
      start_percent or 0,
      end_percent or 1
    ) then
      inserted = inserted + 1
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock2(
    PROJ,
    "PsyReaSFX：分轨插入多个素材",
    -1
  )

  set_status(
    string.format(
      "已分轨插入 %d 个素材",
      inserted
    )
  )
end

function begin_external_drag(
  asset,
  use_wave_selection
)
  local assets = selected_assets()

  if #assets == 0
    or not is_row_selected(asset) then
    assets = { asset }
  end

  local start_percent = 0
  local end_percent = 1

  if use_wave_selection and has_selection() then
    assets = { asset }
    start_percent = state.region_start
    end_percent = state.region_end
  end

  state.external_drag = {
    assets = assets,
    start_percent = start_percent,
    end_percent = end_percent,
    label = #assets == 1
      and assets[1].name
      or tostring(#assets) .. " 个素材",
  }

  state.external_drag_started = true
end

function drop_external_drag()
  local drag = state.external_drag

  state.external_drag = nil
  state.external_drag_started = false

  if not drag then
    return
  end

  if type(reaper.BR_GetMouseCursorContext)
      ~= "function"
    or type(reaper.BR_GetMouseCursorContext_Position)
      ~= "function"
    or type(reaper.BR_GetMouseCursorContext_Track)
      ~= "function" then
    set_status(
      "拖到编排区需要 SWS Extension",
      true
    )
    return
  end

  local window =
    select(1, reaper.BR_GetMouseCursorContext())

  if window ~= "arrange" then
    set_status(
      "已取消拖拽：请释放到 REAPER 编排区",
      true
    )
    return
  end

  local position =
    reaper.BR_GetMouseCursorContext_Position()

  if not position or position < 0 then
    set_status("无法取得放置时间位置", true)
    return
  end

  local track =
    reaper.BR_GetMouseCursorContext_Track()

  local base_index

  if track then
    base_index =
      math.max(
        0,
        math.floor(
          reaper.GetMediaTrackInfo_Value(
            track,
            "IP_TRACKNUMBER"
          )
        ) - 1
      )
  else
    base_index = reaper.CountTracks(PROJ)
  end

  reaper.Undo_BeginBlock2(PROJ)
  reaper.PreventUIRefresh(1)

  local inserted = 0

  for index, asset in ipairs(drag.assets) do
    if insert_asset_at(
      asset,
      base_index + index - 1,
      position,
      drag.start_percent,
      drag.end_percent
    ) then
      inserted = inserted + 1
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock2(
    PROJ,
    "PsyReaSFX：拖拽素材到编排区",
    -1
  )

  set_status(
    string.format(
      "已在 %.3f 秒放置 %d 个素材",
      position,
      inserted
    )
  )
end

function process_external_drag()
  if not state.external_drag then
    return
  end

  ImGui.BeginTooltip(ctx)

  local start_y =
    ImGui.GetCursorPosY(ctx)

  ImGui.Dummy(
    ctx,
    360,
    1
  )

  ImGui.SetCursorPosY(
    ctx,
    start_y
  )

  ImGui.Text(ctx, "拖到 REAPER 编排区")
  ImGui.TextDisabled(
    ctx,
    compact(
      state.external_drag.label,
      58
    )
  )
  ImGui.EndTooltip(ctx)

  if ImGui.IsMouseReleased(ctx, 0) then
    drop_external_drag()
  end
end

----------------------------------------------------------------
-- System shell and roots
----------------------------------------------------------------

function reveal_file(path)
  local os_name = reaper.GetOS()

  if os_name:match("Win") then
    reaper.ExecProcess(
      'explorer.exe /select,"' .. path .. '"',
      0
    )
  elseif os_name:match("OSX") then
    reaper.ExecProcess(
      'open -R "' .. path .. '"',
      0
    )
  else
    reaper.ExecProcess(
      'xdg-open "' .. dirname(path) .. '"',
      0
    )
  end
end

function open_url(url)
  url = trim(url or "")

  if url == "" then
    return false
  end

  local os_name = reaper.GetOS()

  if os_name:match("Win") then
    reaper.ExecProcess(
      'cmd.exe /C start "" "' .. url .. '"',
      0
    )
  elseif os_name:match("OSX") then
    reaper.ExecProcess(
      'open "' .. url .. '"',
      0
    )
  else
    reaper.ExecProcess(
      'xdg-open "' .. url .. '"',
      0
    )
  end

  return true
end

function open_folder(path)
  path = normalize_slashes(trim(path or ""))

  if path == "" or not directory_exists(path) then
    set_status(
      translate_ui_text("目录不存在：") .. path,
      true
    )
    return false
  end

  -- SWS delegates paths to the operating system and handles Unicode
  -- directory names more reliably than manually assembled shell commands.
  if type(reaper.CF_ShellExecute) == "function" then
    local ok, result = pcall(reaper.CF_ShellExecute, path)

    if ok and result ~= false and result ~= 0 then
      return true
    end
  end

  local os_name = reaper.GetOS()
  local command

  if os_name:match("Win") then
    command =
      'cmd.exe /D /S /C start "" "'
        .. path:gsub('"', "")
        .. '"'
  elseif os_name:match("OSX") then
    command = 'open "' .. path:gsub('"', '\\"') .. '"'
  else
    command = 'xdg-open "' .. path:gsub('"', '\\"') .. '"'
  end

  local ok = pcall(reaper.ExecProcess, command, -1)

  if not ok then
    set_status(
      translate_ui_text("无法打开目录：") .. path,
      true
    )
    return false
  end

  return true
end

function choose_folder(title, initial)
  if type(reaper.JS_Dialog_BrowseForFolder) == "function" then
    local ok, accepted, path = pcall(
      reaper.JS_Dialog_BrowseForFolder,
      translate_ui_text(title or "选择文件夹"),
      initial or ""
    )

    if ok and accepted and accepted ~= 0 then
      return normalize_slashes(trim(path or ""))
    end
  end

  local ok, input = reaper.GetUserInputs(
    title or "选择文件夹",
    1,
    "文件夹路径:,extrawidth=420",
    initial or ""
  )

  return ok and normalize_slashes(trim(input or "")) or nil
end

function validate_new_root(root)
  local key = path_key(root)
  local exact = state.root_by_path[key]

  if exact then
    return false, "exact", exact
  end

  for _, record in ipairs(state.root_records) do
    if path_is_inside(root, record.path) then
      return false, "covered", record
    elseif path_is_inside(record.path, root) then
      return false, "parent", record
    end
  end

  return true
end

function add_root_to_library(
  library_id,
  root,
  scan_now,
  defer_rebuild
)
  local library = state.library_by_id[library_id]

  if not library then
    set_status("目标音效库不存在", true)
    return false
  end

  root = canonical_source_path(root)

  if not directory_exists(root) then
    set_status(
      "目录不存在或无法访问：" .. root,
      true
    )
    return false
  end

  local valid, reason, conflict = validate_new_root(root)

  if not valid then
    local owner = library_for_root_record(conflict)

    if reason == "exact" then
      set_status(
        "该来源路径已经属于音效库："
          .. (owner and owner.name or "—"),
        true
      )
    elseif reason == "covered" then
      set_status(
        "该文件夹已包含在来源路径中："
          .. conflict.path,
        true
      )
    else
      set_status(
        "该文件夹会覆盖已有来源路径，请先移除或重新定位："
          .. conflict.path,
        true
      )
    end

    return false
  end

  local record = {
    id = stable_id("root", path_key(root)),
    library_id = library.id,
    path = root,
    alias = "",
    enabled = true,
    artwork_path = "",
    artwork_checked = false,
    artwork_scan_version = 0,
  }

  state.root_records[#state.root_records + 1] = record
  state.libraries_dirty = true

  if not defer_rebuild then
    rebuild_library_indexes()
    state.results_dirty = true
  end

  if scan_now ~= false then
    start_scan("添加来源路径", { root })
  end

  return true
end

function prompt_new_library()
  local ok, name = reaper.GetUserInputs(
    translate_ui_text("新建逻辑音效库"),
    1,
    translate_ui_text("名称:"),
    ""
  )

  name = trim(name or "")

  if not ok or name == "" then
    return false
  end

  local library = create_library(name)
  state.view = "all"
  state.active_collection_id = nil
  state.root_filter = nil
  state.library_filter_id = library.id
  state.results_dirty = true
  save_libraries()
  set_status("已新建空音效库：" .. library.name)
  return true
end

function add_root(library_id, supplied_path)
  if not library_id and not supplied_path then
    return prompt_new_library()
  end

  local root = supplied_path
    or choose_folder("添加来源路径", "")

  if not root or root == "" then
    return false
  end

  local library = library_id
    and state.library_by_id[library_id]
    or nil

  if not library then
    library = create_library(
      basename(root),
      "library:" .. path_key(root)
    )
  end

  local added = add_root_to_library(library.id, root, true)

  if not added and #library.roots == 0 then
    for index = #state.libraries, 1, -1 do
      if state.libraries[index].id == library.id then
        table.remove(state.libraries, index)
        break
      end
    end

    rebuild_library_indexes()
  end

  return added
end

function remove_root(root)
  local record = type(root) == "table"
    and root
    or root_record_for_path(root)

  if not record then
    return
  end

  root = record.path
  if state.import_session then
    local touches_import = false

    for _, import_root in ipairs(
      state.import_session.roots or {}
    ) do
      if path_key(import_root) == path_key(root) then
        touches_import = true
        break
      end
    end

    if touches_import then
      if state.import_session.current
        and state.import_session.current.wave_job then
        destroy_wave_job(
          state.import_session.current.wave_job
        )
      end

      Jobs.cancel(state.import_session.job_token)
      Jobs.finish(
        state.import_session.job_token,
        true,
        "source removed"
      )
      state.import_session = nil
    end
  end

  if state.scan then
    for _, scan_root in ipairs(state.scan.roots or {}) do
      if path_key(scan_root) == path_key(root) then
        Jobs.cancel(state.scan.job_token)
        Jobs.finish(
          state.scan.job_token,
          true,
          "source removed"
        )
        state.scan = nil
        break
      end
    end
  end

  for index = #state.root_records, 1, -1 do
    if state.root_records[index].id == record.id then
      table.remove(state.root_records, index)
      break
    end
  end

  rebuild_library_indexes()

  for key, asset in pairs(state.by_path) do
    if path_is_inside(asset.path, root) then
      state.by_path[key] = nil
      state.favorites[key] = nil
      state.preview_history_assets[asset.asset_id or ""] = nil

      if state.regions_by_path[key] then
        state.regions_by_path[key] = nil
        state.regions_dirty = true
      end

      if state.loudness_cache[key] then
        state.loudness_cache[key] = nil
        state.loudness_dirty = true
      end
    end
  end

  if state.root_filter
    and path_is_inside(state.root_filter, root) then
    state.root_filter = nil
  end

  if state.library_filter_id == record.library_id then
    local owner = state.library_by_id[record.library_id]

    if not owner or #owner.roots == 0 then
      state.library_filter_id = nil
    end
  end

  clear_row_selection()
  rebuild_assets()
  state.libraries_dirty = true
  mark_database_snapshot_dirty()
  set_status("已移除来源路径：" .. basename(root))
end

function relative_path_from_root(path, root)
  local normalized_path = normalize_slashes(path or "")
  local normalized_root = canonical_source_path(root or "")

  if not path_is_inside(normalized_path, normalized_root) then
    return nil
  end

  if path_key(normalized_path) == path_key(normalized_root) then
    return ""
  end

  local offset = #normalized_root + 1
  if normalized_path:sub(offset, offset) == SEP then
    offset = offset + 1
  end
  return normalized_path:sub(offset)
end

function replace_path_in_order(order, old_key, new_path)
  local changed = 0
  local new_key = path_key(new_path)
  local seen_new = false
  local index = 1

  while index <= #(order or {}) do
    local key = path_key(order[index])
    if key == old_key then
      order[index] = new_path
      key = new_key
      changed = changed + 1
    end

    if key == new_key then
      if seen_new then
        table.remove(order, index)
        changed = changed + 1
      else
        seen_new = true
        index = index + 1
      end
    else
      index = index + 1
    end
  end

  return changed
end

function migrate_path_references(old_path, new_path)
  local old_key = path_key(old_path)
  local new_key = path_key(new_path)

  if old_key == new_key then
    return
  end

  if state.favorites[old_key] then
    state.favorites[old_key] = nil
    state.favorites[new_key] = true
    state.config_dirty = true
  end

  if state.session_played[old_key] then
    state.session_played[old_key] = nil
    state.session_played[new_key] = true
    state.session_played_dirty = true
  end

  if state.last_session_played[old_key] then
    state.last_session_played[old_key] = nil
    state.last_session_played[new_key] = true
  end

  if replace_path_in_order(state.recent, old_key, new_path) > 0 then
    state.config_dirty = true
  end

  if state.selected_path and path_key(state.selected_path) == old_key then
    state.selected_path = new_path
  end
  if state.selected_set[old_key] then
    state.selected_set[old_key] = nil
    state.selected_set[new_key] = true
  end

  for _, collection in ipairs(state.collections or {}) do
    if collection.items and collection.items[old_key] then
      local target_existed = collection.items[new_key] ~= nil
      collection.items[old_key] = nil
      collection.items[new_key] = new_path
      replace_path_in_order(collection.order, old_key, new_path)
      if target_existed then
        collection.count = math.max(0, (collection.count or 1) - 1)
      end
      state.collections_dirty = true
    end
  end

  local regions = state.regions_by_path[old_key]
  if regions then
    state.regions_by_path[old_key] = nil
    for _, region in ipairs(regions) do
      region.path = new_path
    end
    state.regions_by_path[new_key] = regions
    state.regions_dirty = true
  end

  local loudness = state.loudness_cache[old_key]
  if loudness then
    state.loudness_cache[old_key] = nil
    loudness.path = new_path
    state.loudness_cache[new_key] = loudness
    state.loudness_dirty = true
  end

  local failed = state.failed_tasks[old_key]
  if failed then
    state.failed_tasks[old_key] = nil
    failed.path = new_path
    state.failed_tasks[new_key] = failed
    state.failed_tasks_dirty = true
  end

  for _, bucket in pairs(state.project_usage or {}) do
    local entry = bucket.assets and bucket.assets[old_key]
    if entry then
      bucket.assets[old_key] = nil
      local existing = bucket.assets[new_key]
      if existing and existing ~= entry then
        local entry_last = tonumber(entry.last_used) or 0
        local existing_last = tonumber(existing.last_used) or 0
        existing.count = (tonumber(existing.count) or 0)
          + (tonumber(entry.count) or 0)
        if entry_last >= existing_last then
          existing.last_used = entry_last
          existing.action = entry.action
        end
        existing.path = new_path
      else
        entry.path = new_path
        bucket.assets[new_key] = entry
      end
      state.project_usage_dirty = true
    end
  end
end

function migrate_asset_path(asset, new_path, record)
  local old_path = asset.path
  local old_key = path_key(old_path)
  local new_key = path_key(new_path)

  if old_key == new_key then
    return false
  end

  local conflict = state.by_path[new_key]
  if conflict and conflict ~= asset then
    return false
  end

  state.by_path[old_key] = nil
  migrate_path_references(old_path, new_path)
  asset.path = normalize_slashes(new_path)
  asset.name = basename(asset.path)
  asset.folder = dirname(asset.path)
  asset.root = record.path
  asset.root_id = record.id
  asset.library_id = record.library_id
  asset.relative_path = asset_relative_path(
    asset.path,
    record.path
  )
  ensure_asset_identity(asset)
  local library = state.library_by_id[record.library_id]
  asset.library = library and library.name or asset.library
  asset.missing = not reaper.file_exists(asset.path)
  asset._search_blob = nil
  asset.artwork_checked = false
  state.database_ordered_assets = nil

  -- A relink changes the physical identity even when the target happens to
  -- have the same byte length. Never carry a sampled result across paths.
  clear_asset_fingerprint(asset)

  state.by_path[new_key] = asset
  return true
end

function validate_relinked_root(record, new_root)
  for _, other in ipairs(state.root_records) do
    if other.id ~= record.id then
      if path_key(other.path) == path_key(new_root)
        or path_is_inside(new_root, other.path)
        or path_is_inside(other.path, new_root) then
        return false, other
      end
    end
  end
  return true
end

function new_relink_plan(record, new_root, job_token)
  return {
    record = record,
    old_root = record.path,
    new_root = new_root,
    entries = {},
    targets = {},
    conflicts = {},
    missing = 0,
    external_artwork = 0,
    assets = state.assets,
    index = 1,
    total = #state.assets,
    job_token = job_token,
  }
end

function process_relink_plan_entry(plan, asset)
  if asset then
    if tostring(asset.root_id or "") == tostring(plan.record.id)
      or path_is_inside(asset.path, plan.record.path) then
      local relative = tostring(asset.relative_path or "")
      if relative == "" then
        relative = asset_relative_path(asset.path, plan.record.path)
      end
      local target = relative == ""
        and plan.new_root
        or join_path(plan.new_root, relative)
      local target_key = path_key(target)
      local conflict = state.by_path[target_key]
      local duplicate_target = plan.targets[target_key]

      if (conflict and conflict ~= asset) or duplicate_target then
        plan.conflicts[#plan.conflicts + 1] = target
      else
        plan.targets[target_key] = asset
      end

      if not reaper.file_exists(target) then
        plan.missing = plan.missing + 1
      end

      local artwork_relative = relative_path_from_root(
        asset.artwork_path or "",
        plan.record.path
      )
      if tostring(asset.artwork_path or "") ~= ""
        and not artwork_relative then
        plan.external_artwork = plan.external_artwork + 1
      end

      plan.entries[#plan.entries + 1] = {
        asset = asset,
        old_path = asset.path,
        target = target,
        old_artwork = asset.artwork_path or "",
        artwork_relative = artwork_relative,
      }
    end
  end
end

function cancel_relink_plan(session, reason)
  if not session then return end
  state.relink_plan_session = nil
  Jobs.cancel(session.job_token)
  Jobs.finish(session.job_token, true, reason or "canceled")
  set_status("已取消来源重定位计划")
end

function confirm_relink_plan(plan)
  local message = string.format(
    "来源重定位预览\n\n%s\n→ %s\n\n迁移：%d\n缺失：%d\n冲突：%d\n外部封面：%d",
    plan.old_root,
    plan.new_root,
    math.max(0, #plan.entries - plan.missing - #plan.conflicts),
    plan.missing,
    #plan.conflicts,
    plan.external_artwork
  )

  if #plan.conflicts > 0 then
    local preview = {}
    for index = 1, math.min(8, #plan.conflicts) do
      preview[#preview + 1] = plan.conflicts[index]
    end
    reaper.MB(
      message .. "\n\n冲突路径：\n" .. table.concat(preview, "\n"),
      "来源重定位冲突",
      0
    )
    return false
  end

  return reaper.MB(
    message
      .. "\n\n确认后将先创建恢复快照，再一次性迁移全部引用。是否继续？",
    "确认来源重定位",
    4
  ) == 6
end

function commit_relink_plan(plan)
  local record = plan.record
  local new_root = plan.new_root
  if not create_data_backup("source_relink", true) then
    set_status("无法创建重定位恢复快照，未修改任何路径", true)
    Jobs.finish(plan.job_token, false, "backup failed")
    return false
  end

  stop_preview()
  local old_root = record.path
  local old_root_filter = state.root_filter
  local old_record_artwork = record.artwork_path or ""
  local old_canonical_path = record.canonical_path or ""
  local old_volume_label = record.volume_label or ""
  local old_volume_serial = record.volume_serial or ""
  local old_last_seen = record.last_seen or 0
  local root_artwork_relative = relative_path_from_root(
    record.artwork_path or "",
    old_root
  )
  record.path = new_root
  if root_artwork_relative then
    record.artwork_path = root_artwork_relative == ""
      and new_root
      or join_path(new_root, root_artwork_relative)
  end
  record.artwork_checked = false
  record.artwork_scan_version = 0
  rebuild_library_indexes()

  local moved = 0
  local unresolved = 0
  local moved_entries = {}
  for _, entry in ipairs(plan.entries) do
    local asset = entry.asset
    if migrate_asset_path(asset, entry.target, record) then
        if entry.artwork_relative then
          asset.artwork_path = entry.artwork_relative == ""
            and new_root
            or join_path(new_root, entry.artwork_relative)
        end
        moved = moved + 1
        moved_entries[#moved_entries + 1] = entry
        if not reaper.file_exists(entry.target) then
          unresolved = unresolved + 1
        end
    end
  end

  if state.root_filter and path_is_inside(state.root_filter, old_root) then
    local relative = relative_path_from_root(state.root_filter, old_root) or ""
    state.root_filter = relative == "" and new_root or join_path(new_root, relative)
  end

  state.libraries_dirty = true
  mark_database_snapshot_dirty()
  state.results_dirty = true
  invalidate_library_counts()
  invalidate_folder_navigation()
  state.missing_assets = {}
  state.missing_asset_count = 0
  local libraries_saved = save_libraries()
  local database_saved = libraries_saved and save_database()

  if not libraries_saved or not database_saved then
    record.path = old_root
    record.artwork_path = old_record_artwork
    record.canonical_path = old_canonical_path
    record.volume_label = old_volume_label
    record.volume_serial = old_volume_serial
    record.last_seen = old_last_seen
    rebuild_library_indexes()
    for index = #moved_entries, 1, -1 do
      local entry = moved_entries[index]
      migrate_asset_path(entry.asset, entry.old_path, record)
      entry.asset.artwork_path = entry.old_artwork
    end
    state.root_filter = old_root_filter
    state.libraries_dirty = true
    mark_database_snapshot_dirty()
    save_libraries()
    save_database()
    set_status("来源重定位提交失败，已恢复原路径和引用", true)
    Jobs.finish(plan.job_token, false, "commit failed")
    return false
  end
  set_status(string.format("来源已重定位：迁移 %d 条路径，待重新扫描 %d 条", moved, unresolved))
  Jobs.finish(plan.job_token, true)
  start_scan("重定位后增量扫描", { new_root }, { silent = unresolved == 0 })
  return true
end

function process_relink_plan()
  local plan = state.relink_plan_session
  if not plan or not can_run_heavy_job() then return end
  if plan.job_token.cancel_requested then
    cancel_relink_plan(plan, "user canceled")
    return
  end
  if plan.assets ~= state.assets
    or state.root_by_id[plan.record.id] ~= plan.record then
    cancel_relink_plan(plan, "catalog changed")
    set_status("素材库结构已变化，请重新开始来源重定位", true)
    return
  end

  local processed = 0
  local deadline = reaper.time_precise() + RELINK_PLAN_FRAME_BUDGET
  while plan.index <= plan.total
    and processed < RELINK_PLAN_FILES_PER_FRAME
    and reaper.time_precise() < deadline do
    process_relink_plan_entry(plan, plan.assets[plan.index])
    plan.index = plan.index + 1
    processed = processed + 1
  end
  if plan.index <= plan.total then return end

  plan.assets = nil
  state.relink_plan_session = nil
  if not confirm_relink_plan(plan) then
    Jobs.finish(plan.job_token, true, "not confirmed")
    return
  end
  commit_relink_plan(plan)
end

function relink_root(record, supplied_path)
  if not record then return false end
  if state.relink_plan_session or state.scan or state.import_session
    or state.precache_session or state.duplicate_scan
    or state.duplicate_confirmation or state.missing_audit then
    set_status("请等待当前后台任务完成后再重新定位来源", true)
    return false
  end

  local new_root = supplied_path
    or choose_folder("重新定位来源路径", record.path)
  if not new_root or trim(new_root) == "" then return false end
  new_root = canonical_source_path(new_root)
  if not directory_exists(new_root) then
    set_status("新来源目录不存在或无法访问：" .. new_root, true)
    return false
  end
  local valid, conflict = validate_relinked_root(record, new_root)
  if not valid then
    set_status("新来源目录与现有来源重叠：" .. conflict.path, true)
    return false
  end

  local job_token = Jobs.begin(
    "relink_plan",
    "catalog_exclusive",
    false
  )
  if not job_token then
    set_status("另一个维护任务正在运行", true)
    return false
  end
  state.relink_plan_session = new_relink_plan(
    record,
    new_root,
    job_token
  )
  set_status(string.format(
    "正在生成来源重定位计划：0 / %d",
    #state.assets
  ))
  return true
end

function start_missing_audit()
  if state.missing_audit then
    return
  end

  if state.scan or state.import_session or state.precache_session
    or state.duplicate_scan or state.duplicate_confirmation then
    set_status("请等待当前后台任务完成", true)
    return
  end

  local job_token =
    Jobs.begin("missing_audit", "catalog_exclusive", false)

  if not job_token then
    set_status("另一个维护任务正在运行", true)
    return
  end

  local offline = {}
  state.offline_roots = {}
  for _, record in ipairs(state.root_records) do
    if record.enabled and not directory_exists(record.path) then
      offline[record.id] = true
      state.offline_roots[#state.offline_roots + 1] = record
    end
  end

  state.missing_assets = {}
  state.missing_asset_count = 0
  state.missing_audit = {
    index = 1,
    total = #state.assets,
    missing = 0,
    checked = 0,
    offline = offline,
    job_token = job_token,
  }
  set_status("正在检查缺失文件…")
end

function process_missing_audit()
  local session = state.missing_audit
  if not session or state.scan or state.import_session
    or state.precache_session or not can_run_heavy_job() then
    return
  end

  if session.job_token
    and session.job_token.cancel_requested then
    state.missing_audit = nil
    Jobs.finish(session.job_token, true, "canceled")
    return
  end

  local budget = 36
  while budget > 0 and session.index <= session.total do
    local asset = state.assets[session.index]
    session.index = session.index + 1
    session.checked = session.checked + 1
    budget = budget - 1

    local missing = session.offline[tostring(asset.root_id or "")]
      or not reaper.file_exists(asset.path)
    asset.missing = missing == true
    if asset.missing then
      local key = path_key(asset.path)
      state.missing_assets[key] = asset
      session.missing = session.missing + 1
    end
  end

  if session.index > session.total then
    state.missing_asset_count = session.missing
    state.missing_audit = nil
    Jobs.finish(session.job_token, true)
    state.results_dirty = true
    set_status(string.format("缺失检查完成：%d 个离线来源，%d 个缺失素材", #state.offline_roots, state.missing_asset_count), state.missing_asset_count > 0)
  end
end

function sampled_file_fingerprint(path, known_size)
  local file = io.open(path, "rb")
  if not file then
    return nil
  end

  local size = tonumber(known_size) or file:seek("end") or 0
  local chunk_size = 65536
  local positions = { 0, math.max(0, math.floor(size / 2 - chunk_size / 2)), math.max(0, size - chunk_size) }
  local chunks = {}

  for _, position in ipairs(positions) do
    file:seek("set", position)
    chunks[#chunks + 1] = file:read(chunk_size) or ""
  end
  file:close()

  local payload = tostring(size) .. "|" .. table.concat(chunks, "|")
  local reverse_payload = tostring(size) .. "|" .. chunks[3] .. "|" .. chunks[2] .. "|" .. chunks[1]
  return fnv1a(payload) .. fnv1a(reverse_payload)
end

function start_duplicate_scan()
  if state.duplicate_scan then
    return
  end

  if state.scan or state.import_session or state.precache_session
    or state.missing_audit or state.duplicate_confirmation then
    set_status("请等待当前后台任务完成", true)
    return
  end

  local job_token =
    Jobs.begin("duplicate_scan", "catalog_exclusive", false)

  if not job_token then
    set_status("另一个维护任务正在运行", true)
    return
  end

  state.duplicate_groups = {}
  state.duplicate_lookup = {}
  state.duplicate_group_count = 0
  state.duplicate_asset_count = 0
  state.duplicate_confirmed_groups = {}
  state.duplicate_confirmed_lookup = {}
  state.duplicate_confirmed_asset_count = 0
  state.duplicate_confirmation_failures = {}
  state.duplicate_confirmation_failure_count = 0
  state.duplicate_scan = {
    phase = "sizes",
    assets = state.assets,
    asset_index = 1,
    asset_total = #state.assets,
    size_groups = {},
    candidates = {},
    index = 1,
    total = 0,
    failed = 0,
    fingerprint_groups = {},
    duplicate_groups = {},
    duplicate_lookup = {},
    duplicate_asset_count = 0,
    job_token = job_token,
  }
  set_status(string.format("正在读取文件大小：0 / %d", #state.assets))
end

function close_duplicate_confirmation_session(session)
  if session and session.comparison then
    close_duplicate_comparison(session.comparison)
    session.comparison = nil
  end
end

function finish_duplicate_confirmation(session)
  close_duplicate_confirmation_session(session)
  state.duplicate_confirmed_groups = session.confirmed_groups
  state.duplicate_confirmed_lookup = session.confirmed_lookup
  state.duplicate_confirmed_asset_count = session.confirmed_assets
  state.duplicate_confirmation_failures = session.failures
  state.duplicate_confirmation_failure_count = session.failure_count
  state.duplicate_confirmation = nil
  Jobs.finish(session.job_token, true)
  state.results_dirty = true
  set_status(string.format(
    "完整确认完成：%d 组，%d 个素材，读取失败 %d",
    #session.confirmed_groups,
    session.confirmed_assets,
    session.failure_count
  ), session.failure_count > 0)
end

function start_duplicate_confirmation()
  if state.duplicate_confirmation or #state.duplicate_groups == 0 then
    return
  end
  local job_token = Jobs.begin(
    "duplicate_confirmation",
    "catalog_exclusive",
    false
  )
  if not job_token then
    set_status("另一个维护任务正在运行", true)
    return
  end
  state.duplicate_confirmed_groups = {}
  state.duplicate_confirmed_lookup = {}
  state.duplicate_confirmed_asset_count = 0
  state.duplicate_confirmation_failures = {}
  state.duplicate_confirmation_failure_count = 0
  state.duplicate_confirmation = {
    groups = state.duplicate_groups,
    group_index = 1,
    asset_index = 1,
    representative_index = 1,
    partitions = {},
    comparison = nil,
    confirmed_groups = {},
    confirmed_lookup = {},
    confirmed_assets = 0,
    failures = {},
    failure_count = 0,
    comparisons_finished = 0,
    total_assets = state.duplicate_asset_count,
    job_token = job_token,
  }
  set_status("正在逐字节确认重复候选")
end

function mark_duplicate_confirmation_failure(session, asset)
  local key = path_key(asset.path)
  if not session.failures[key] then
    session.failures[key] = asset
    session.failure_count = session.failure_count + 1
  end
end

function finalize_duplicate_confirmation_group(session, candidate_group)
  for partition_index, partition in ipairs(session.partitions) do
    if #partition.assets > 1 then
      local identity = tostring(candidate_group.fingerprint)
        .. ":" .. tostring(partition_index)
      local confirmed = {
        fingerprint = identity,
        assets = partition.assets,
        count = #partition.assets,
        confirmed = true,
      }
      session.confirmed_groups[#session.confirmed_groups + 1] = confirmed
      session.confirmed_assets = session.confirmed_assets + #partition.assets
      for _, asset in ipairs(partition.assets) do
        session.confirmed_lookup[path_key(asset.path)] = identity
      end
    end
  end
end

function advance_duplicate_confirmation_asset(session)
  session.asset_index = session.asset_index + 1
  session.representative_index = 1
  session.comparison = nil
end

function process_duplicate_confirmation()
  local session = state.duplicate_confirmation
  if not session or not can_run_heavy_job() then
    return
  end
  if session.job_token.cancel_requested then
    close_duplicate_confirmation_session(session)
    state.duplicate_confirmation = nil
    Jobs.finish(session.job_token, true, "canceled")
    return
  end

  local candidate_group = session.groups[session.group_index]
  if not candidate_group then
    finish_duplicate_confirmation(session)
    return
  end
  local asset = candidate_group.assets[session.asset_index]
  if not asset then
    finalize_duplicate_confirmation_group(session, candidate_group)
    session.group_index = session.group_index + 1
    session.asset_index = 1
    session.representative_index = 1
    session.partitions = {}
    return
  end
  if #session.partitions == 0 then
    session.partitions[1] = { representative = asset, assets = { asset } }
    advance_duplicate_confirmation_asset(session)
    return
  end

  local partition = session.partitions[session.representative_index]
  if not partition then
    session.partitions[#session.partitions + 1] = {
      representative = asset,
      assets = { asset },
    }
    advance_duplicate_confirmation_asset(session)
    return
  end
  if not session.comparison then
    local comparison, open_error = begin_duplicate_comparison(
      partition.representative.path,
      asset.path
    )
    if not comparison then
      if open_error == "left_open" then
        for _, previous in ipairs(partition.assets) do
          mark_duplicate_confirmation_failure(session, previous)
        end
        table.remove(session.partitions, session.representative_index)
      else
        mark_duplicate_confirmation_failure(session, asset)
        advance_duplicate_confirmation_asset(session)
      end
      return
    end
    session.comparison = comparison
  end

  local result = step_duplicate_comparison(session.comparison)
  if result == "pending" then
    return
  end
  session.comparisons_finished = session.comparisons_finished + 1
  session.comparison = nil
  if result == "equal" then
    partition.assets[#partition.assets + 1] = asset
    advance_duplicate_confirmation_asset(session)
  elseif result == "different" then
    session.representative_index = session.representative_index + 1
  else
    mark_duplicate_confirmation_failure(session, asset)
    mark_duplicate_confirmation_failure(session, partition.representative)
    advance_duplicate_confirmation_asset(session)
  end
end

function finish_duplicate_scan(session)
  local duplicates = session.sorted_groups or session.duplicate_groups or {}
  local lookup = session.duplicate_lookup or {}
  local asset_count = session.duplicate_asset_count or 0

  state.duplicate_groups = duplicates
  state.duplicate_lookup = lookup
  state.duplicate_group_count = #duplicates
  state.duplicate_asset_count = asset_count
  state.duplicate_scan = nil
  Jobs.finish(session.job_token, true)
  state.results_dirty = true
  mark_database_snapshot_dirty()
  set_status(string.format("候选检查完成：%d 组，%d 个素材", #duplicates, asset_count))
end

function process_duplicate_scan()
  local session = state.duplicate_scan
  if not session or state.scan or state.import_session
    or state.precache_session or not can_run_heavy_job() then
    return
  end

  if session.job_token
    and session.job_token.cancel_requested then
    state.duplicate_scan = nil
    Jobs.finish(session.job_token, true, "canceled")
    return
  end

  if session.phase == "sizes" then
    local processed = 0
    local deadline = reaper.time_precise()
      + DUPLICATE_STAT_FRAME_BUDGET
    while session.asset_index <= session.asset_total
      and processed < DUPLICATE_STAT_FILES_PER_FRAME
      and reaper.time_precise() < deadline do
      local asset = session.assets[session.asset_index]
      session.asset_index = session.asset_index + 1
      processed = processed + 1
      local size = asset and asset.ready and file_size(asset.path) or 0
      if asset and size > 0 then
        if size ~= (tonumber(asset.size) or 0) then
          asset.size = size
          clear_asset_fingerprint(asset)
          mark_asset_database_change(asset)
        end
        add_duplicate_size_candidate(
          session.size_groups,
          session.candidates,
          size,
          asset
        )
      end
    end
    if session.asset_index > session.asset_total then
      session.assets = nil
      session.size_groups = nil
      session.phase = "fingerprints"
      session.index = 1
      session.total = #session.candidates
      set_status(string.format(
        "正在检查重复候选：%d 个同尺寸文件",
        session.total
      ))
    end
    return
  end

  if session.phase == "sort" then
    local result, sorted = step_incremental_result_job(
      session.sort_job,
      DUPLICATE_SORT_ITEMS_PER_FRAME
    )
    if result == "complete" then
      session.sorted_groups = sorted
      session.sort_job = nil
      finish_duplicate_scan(session)
    end
    return
  end

  local asset = session.candidates[session.index]
  if not asset then
    session.candidates = nil
    session.fingerprint_groups = nil
    session.phase = "sort"
    session.sort_job = begin_incremental_result_job(
      session.duplicate_groups,
      function() return true end,
      function(left, right)
        if left.count == right.count then
          return left.fingerprint < right.fingerprint
        end
        return left.count > right.count
      end,
      nil,
      nil
    )
    return
  end

  session.index = session.index + 1
  local size = file_size(asset.path)
  if size <= 0 then
    clear_asset_fingerprint(asset)
    session.failed = session.failed + 1
    return
  end
  -- A size-only cache cannot detect an external replacement with identical
  -- length. An explicit audit therefore resamples every candidate.
  local before = duplicate_file_stat(asset.path, size)
  local fingerprint = sampled_file_fingerprint(asset.path, size)
  local after = duplicate_file_stat(asset.path, size)
  local changed_during_read = duplicate_file_changed_since(before, after)
  if fingerprint and not changed_during_read then
    record_asset_fingerprint(asset, fingerprint, after)
    local became_duplicate = add_duplicate_fingerprint_asset(
      session.fingerprint_groups,
      session.duplicate_groups,
      session.duplicate_lookup,
      fingerprint,
      asset,
      path_key
    )
    if became_duplicate then
      local group = session.fingerprint_groups[fingerprint]
      if group.count == 2 then
        session.duplicate_asset_count =
          session.duplicate_asset_count + 2
      else
        session.duplicate_asset_count =
          session.duplicate_asset_count + 1
      end
    end
  else
    clear_asset_fingerprint(asset)
    session.failed = session.failed + 1
  end

end

function remove_library(library_id)
  local library = state.library_by_id[library_id]

  if not library then
    return
  end

  local roots = {}

  for _, record in ipairs(library.roots or {}) do
    roots[#roots + 1] = record
  end

  for _, record in ipairs(roots) do
    remove_root(record)
  end

  for index = #state.libraries, 1, -1 do
    if state.libraries[index].id == library_id then
      table.remove(state.libraries, index)
      break
    end
  end

  if state.library_filter_id == library_id then
    state.library_filter_id = nil
  end

  rebuild_library_indexes()
  refresh_all_asset_library_bindings()
  state.libraries_dirty = true
  set_status("已移除逻辑音效库：" .. library.name)
end

function roots_for_library(library_id)
  local result = {}
  local library = state.library_by_id[library_id]

  for _, record in ipairs(library and library.roots or {}) do
    if record.enabled then
      result[#result + 1] = record.path
    end
  end

  return result
end

function reset_interface_settings()
  stop_preview()
  clear_row_selection()
  state.search = ""
  state.view = "all"
  state.root_filter = nil
  state.library_filter_id = nil
  state.folder_browser_open = false
  state.expanded_source_folders = {}
  state.expanded_folder_nodes = {}
  invalidate_folder_navigation()
  state.active_collection_id = nil
  state.status_filter = nil
  state.sort_mode = "name"
  state.sort_desc = false
  state.auto_preview = true
  state.watch_enabled = true
  state.watch_interval = WATCH_INTERVAL
  state.watch_silent = true
  state.resume_scan_on_start = true
  state.auto_backup = true
  state.backup_keep_count = 7
  state.pitch = 0
  state.rate = 1
  state.gain_db = 0
  state.preserve_pitch = true
  state.loop = false
  state.reverse = false
  state.region_start = 0
  state.region_end = 1
  state.insert_prefix = ""
  state.insert_suffix = ""
  state.insert_lowercase = true
  state.insert_fade_ms = 5
  state.transfer_dir = DEFAULT_TRANSFER_DIR
  state.transfer_template = "{name}"
  state.transfer_format = "wav24"
  state.transfer_sample_rate = "source"
  state.transfer_channels = "source"
  state.transfer_scope = "selection"
  state.transfer_collision = "increment"
  state.transfer_fade_in_ms = 5
  state.transfer_fade_out_ms = 20
  state.transfer_smart_tail = false
  state.transfer_tail_threshold_db = -60
  state.transfer_tail_max_ms = 5000
  state.transfer_tail_hold_ms = 180
  state.transfer_normalize = "off"
  state.transfer_normalize_target = -1
  state.transfer_insert_after = false
  state.transfer_open_dir_after = false
  state.transfer_lowercase = false
  state.transfer_dither = true
  state.transfer_noise_shaping = false
  state.transfer_preserve_metadata = true
  state.transfer_variants_enabled = false
  state.transfer_variant_pitches = ""
  state.transfer_variant_rates = ""
  state.transfer_variant_gains = ""
  state.transfer_variant_include_reverse = false
  state.transfer_variant_auto_suffix = true
  state.transfer_last_output = ""
  state.transfer_last_outputs = {}
  state.transfer_last_error = ""
  state.transfer_last_summary = ""
  state.theme_preset = "dark"
  state.custom_accent_hex = "#1F6FCC"
  state.custom_shell_hex = "#101114"
  state.language = "zh"
  state.mini_wave_points = MINI_WAVE_DEFAULT_POINTS
  state.precache_points = 4096
  state.ui_density = "compact"
  state.surface_style = "dark"
  state.wave_scrub_enabled = true
  state.loop_selection = true
  state.preview_control_layout = "studio_strip"
  state.multichannel_waveform = true
  state.bottom_panel_height = 330
  state.preview_channel_mode = "original"
  state.preview_channel_asset_key = nil
  state.preview_channel_count = 0
  state.preview_channel_selection = {}
  state.preview_channel_anchor = 1
  state.preview_channel_strip_expanded = false
  state.loudness_match = false
  state.loudness_target_db = -18
  state.transient_threshold = 0.24
  state.transient_min_gap_ms = 140
  state.transient_pre_ms = 20
  state.transient_post_ms = 180
  state.transient_smoothing_ms = 8
  state.transient_max_regions = 64
  state.transient_replace_existing = true
  state.show_loudness_metrics = false
  state.loudness_show_i = true
  state.loudness_show_m = true
  state.loudness_show_s = false
  state.loudness_show_tp = false
  state.waveform_hex = "#D7D8DA"
  state.waveform_selected_hex = "#EAF3FF"
  state.waveform_played_hex = "#8FB8D8"
  state.waveform_marked_hex = "#F0C85A"
  state.played_text_hex = "#F0C85A"
  state.played_text_enabled = true
  state.played_waveform_enabled = false
  state.restore_played_on_start = false
  state.artwork_enabled = true
  state.inspector_artwork_pinned = true
  state.selection_hex = "#2789E9"
  state.playhead_hex = "#50E36D"
  state.region_hex = "#E2B764"
  apply_surface_style()
  apply_theme_palette()
  apply_waveform_palette()
  state.wave_view_start = 0
  state.wave_view_end = 1
  state.sidebar_visible = true
  state.sidebar_sections = {
    sounds = true,
    libraries = true,
    collections = true,
    saved_searches = true,
    workflow = true,
    activity = true,
  }
  state.inspector_visible = true
  state.inspector_width = INSPECTOR_DEFAULT_W
  state.column_visible = {
    waveform = true,
    filename = true,
    status = true,
    description = true,
    duration = true,
    format = true,
    library = true,
    category = false,
    subcategory = false,
    catid = false,
    channels = false,
    sample_rate = false,
    bit_depth = false,
    path = false,
  }
  state.column_widths = {
    waveform = 350,
    filename = 265,
    status = 88,
    description = 320,
    duration = 104,
    format = 118,
    library = 180,
    category = 140,
    subcategory = 150,
    catid = 90,
    channels = 80,
    sample_rate = 100,
    bit_depth = 90,
    path = 360,
  }
  state.results_dirty = true
  state.config_dirty = true
  set_status("已重置界面与试听设置")
end

function cancel_catalog_jobs(reason)
  reason = tostring(reason or "canceled")

  if state.transfer_job then
    finish_transfer_job(state.transfer_job, true)
  end

  if state.import_session
    and state.import_session.current
    and state.import_session.current.wave_job then
    destroy_wave_job(
      state.import_session.current.wave_job
    )
  end

  local catalog_job = state.import_session
      and state.import_session.job_token
    or state.scan
      and state.scan.job_token

  Jobs.cancel(catalog_job)
  Jobs.finish(catalog_job, true, reason)
  state.scan = nil
  state.import_session = nil
  state.import_cancel_requested = false

  local maintenance_fields = {
    "cache_verify_session",
    "missing_audit",
    "duplicate_scan",
    "duplicate_confirmation",
    "relink_plan_session",
  }

  for _, field in ipairs(maintenance_fields) do
    local session = state[field]

    if session and session.job_token then
      close_duplicate_confirmation_session(session)
      Jobs.cancel(session.job_token)
      Jobs.finish(session.job_token, true, reason)
    end

    state[field] = nil
  end
end

function reset_database_keep_roots()
  local answer = reaper.MB(
    "将清空 PsyReaSFX 数据库和波形缓存，"
      .. "然后重新扫描现有音效库。\n\n继续吗？",
    SCRIPT_NAME,
    4
  )

  if answer ~= 6 then
    return
  end

  stop_preview()
  cancel_catalog_jobs("database reset")
  state.assets = {}
  state.by_path = {}
  state.database_ordered_assets = nil
  state.database_generation = 0
  clear_asset_changes(state.database_changes)
  state.results = {}
  state.results_job = nil
  state.results_dirty = true
  state.favorites = {}
  state.recent = {}
  state.active_collection_id = nil
  state.status_filter = nil
  clear_row_selection()
  clear_wave_cache()
  os.remove(DATABASE_FILE)
  os.remove(DATABASE_JOURNAL_FILE)
  os.remove(HISTORY_FILE)
  os.remove(LAST_PLAYED_SESSION_FILE)
  os.remove(SCAN_CHECKPOINT_FILE)
  os.remove(FAILED_TASKS_FILE)
  state.failed_tasks = {}
  state.failed_tasks_dirty = false
  state.missing_assets = {}
  state.missing_asset_count = 0
  state.offline_roots = {}
  state.duplicate_groups = {}
  state.duplicate_lookup = {}
  state.duplicate_group_count = 0
  state.duplicate_asset_count = 0
  state.duplicate_confirmed_groups = {}
  state.duplicate_confirmed_lookup = {}
  state.duplicate_confirmed_asset_count = 0
  state.duplicate_confirmation_failures = {}
  state.duplicate_confirmation_failure_count = 0
  state.history_dirty = false
  state.preview_history_assets = {}
  state.session_played = {}
  state.last_session_played = {}
  state.session_played_dirty = false
  mark_database_snapshot_dirty()
  state.config_dirty = true
  save_config()

  if #state.roots > 0 then
    start_scan("重建数据库")
  else
    set_status("数据库已清空；请添加音效库")
  end
end

function factory_reset()
  local answer = reaper.MB(
    "这会删除全部音效库路径、收藏、播放列表、保存搜索、"
      .. "历史、索引、波形缓存和界面设置。\n\n继续吗？",
    SCRIPT_NAME,
    4
  )

  if answer ~= 6 then
    return
  end

  stop_preview()
  cancel_catalog_jobs("factory reset")
  state.roots = {}
  state.libraries = {}
  state.library_by_id = {}
  state.root_records = {}
  state.root_by_id = {}
  state.root_by_path = {}
  state.library_filter_id = nil
  state.assets = {}
  state.by_path = {}
  state.database_ordered_assets = nil
  state.database_generation = 0
  clear_asset_changes(state.database_changes)
  state.results = {}
  state.results_job = nil
  state.results_dirty = true
  state.favorites = {}
  state.recent = {}
  state.collections = {}
  state.collection_by_id = {}
  state.active_collection_id = nil
  state.saved_searches = {}
  state.regions_by_path = {}
  state.regions_dirty = false
  state.loudness_cache = {}
  state.loudness_dirty = false
  state.status_filter = nil
  clear_row_selection()
  clear_wave_cache()
  reset_interface_settings()
  os.remove(CONFIG_FILE)
  os.remove(LIBRARIES_FILE)
  os.remove(DATABASE_FILE)
  os.remove(DATABASE_JOURNAL_FILE)
  os.remove(COLLECTIONS_FILE)
  os.remove(SAVED_SEARCHES_FILE)
  os.remove(HISTORY_FILE)
  os.remove(LAST_PLAYED_SESSION_FILE)
  os.remove(REGIONS_FILE)
  os.remove(LOUDNESS_FILE)
  os.remove(SCAN_CHECKPOINT_FILE)
  os.remove(FAILED_TASKS_FILE)
  os.remove(BACKUP_STATE_FILE)
  os.remove(PROJECT_USAGE_FILE)
  state.config_dirty = false
  state.libraries_dirty = false
  state.db_dirty = false
  state.collections_dirty = false
  state.searches_dirty = false
  state.history_dirty = false
  state.preview_history_assets = {}
  state.session_played = {}
  state.last_session_played = {}
  state.session_played_dirty = false
  state.failed_tasks = {}
  state.failed_tasks_dirty = false
  state.project_usage = {}
  state.project_usage_dirty = false
  state.current_project_bin_id = nil
  state.missing_assets = {}
  state.missing_asset_count = 0
  state.offline_roots = {}
  state.duplicate_groups = {}
  state.duplicate_lookup = {}
  state.duplicate_group_count = 0
  state.duplicate_asset_count = 0
  state.duplicate_confirmed_groups = {}
  state.duplicate_confirmed_lookup = {}
  state.duplicate_confirmed_asset_count = 0
  state.duplicate_confirmation_failures = {}
  state.duplicate_confirmation_failure_count = 0

  state.wave_cache_dir =
    DEFAULT_WAVE_CACHE_DIR

  apply_wave_cache_directory(
    DEFAULT_WAVE_CACHE_DIR
  )

  set_status("PsyReaSFX 已恢复出厂状态")
end

----------------------------------------------------------------
-- Drawing helpers
----------------------------------------------------------------

function draw_waveform(
  draw_list,
  waveform,
  x,
  y,
  width,
  height,
  wave_color
)
  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + width,
    y + height,
    COLOR.waveform_bg
  )

  ImGui.DrawList_AddLine(
    draw_list,
    x,
    y + height * 0.5,
    x + width,
    y + height * 0.5,
    COLOR.grid,
    1
  )

  if not waveform or waveform.count <= 0 then
    return
  end

  local count = waveform.count
  local center = y + height * 0.5
  local half = height * 0.45
  local step = width / count

  for index = 1, count do
    local amplitude =
      waveform.peaks[index] or 0

    local px =
      x + (index - 0.5) * step

    ImGui.DrawList_AddLine(
      draw_list,
      px,
      center - amplitude * half,
      px,
      center + amplitude * half,
      wave_color,
      math.max(1, step)
    )
  end
end

function reset_wave_view()
  state.wave_view_start = 0
  state.wave_view_end = 1
  state.wave_pan_last_x = nil
end

function wave_view_span()
  return math.max(
    0.001,
    state.wave_view_end - state.wave_view_start
  )
end

function wave_source_percent(local_percent)
  return clamp(
    state.wave_view_start
      + wave_view_span()
        * clamp(local_percent, 0, 1),
    0,
    1
  )
end

function wave_view_percent(source_percent)
  return (
    source_percent - state.wave_view_start
  ) / wave_view_span()
end

function zoom_wave_view(anchor_percent, wheel_delta)
  local old_span = wave_view_span()
  local factor = 0.82 ^ wheel_delta
  local new_span = clamp(old_span * factor, 0.015, 1)
  local anchor = wave_source_percent(anchor_percent)
  local anchor_ratio = clamp(anchor_percent, 0, 1)
  local new_start = anchor - new_span * anchor_ratio

  new_start = clamp(new_start, 0, 1 - new_span)
  state.wave_view_start = new_start
  state.wave_view_end = new_start + new_span
end

function pan_wave_view(delta_percent)
  local span = wave_view_span()
  local new_start = clamp(
    state.wave_view_start + delta_percent,
    0,
    1 - span
  )

  state.wave_view_start = new_start
  state.wave_view_end = new_start + span
end

function draw_waveform_window(
  draw_list,
  waveform,
  asset,
  x,
  y,
  width,
  height,
  wave_color,
  start_percent,
  end_percent
)
  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + width,
    y + height,
    COLOR.waveform_bg
  )

  if not waveform or waveform.count <= 0 then
    return
  end

  local count = waveform.count
  local first_index = clamp(
    math.floor(start_percent * math.max(0, count - 1)) + 1,
    1,
    count
  )
  local last_index = clamp(
    math.ceil(end_percent * math.max(0, count - 1)) + 1,
    first_index,
    count
  )

  local visible_count =
    math.max(1, last_index - first_index + 1)
  local pixels = math.max(1, math.floor(width))
  local channel_peaks = waveform.channel_peaks
  local channel_count =
    channel_peaks
      and clamp(waveform.channels or #channel_peaks, 1, 8)
      or 1
  local ruler_height = 20
  local lanes_y = y + ruler_height
  local lanes_height = math.max(18, height - ruler_height)
  local lane_height = lanes_height / channel_count

  local function draw_lane(peaks, channel, lane_y)
    local channel_selected =
      preview_channel_is_selected(asset, channel)
    local lane_wave_color =
      channel_selected
        and wave_color
        or rgba_with_alpha(wave_color, 0x32)
    local center = lane_y + lane_height * 0.5
    local half = math.max(2, lane_height * 0.38)

    ImGui.DrawList_AddLine(
      draw_list,
      x,
      center,
      x + width,
      center,
      rgba_with_alpha(COLOR.grid, 0x80),
      1
    )

    if channel > 1 then
      ImGui.DrawList_AddLine(
        draw_list,
        x,
        lane_y,
        x + width,
        lane_y,
        rgba_with_alpha(COLOR.border, 0x90),
        1
      )
    end

    for pixel = 0, pixels - 1 do
      local range_start =
        first_index
        + math.floor(pixel / pixels * visible_count)
      local range_end =
        first_index
        + math.floor((pixel + 1) / pixels * visible_count)

      range_start = clamp(range_start, first_index, last_index)
      range_end = clamp(
        math.max(range_start, range_end),
        range_start,
        last_index
      )

      local amplitude = 0

      for index = range_start, range_end do
        amplitude = math.max(amplitude, peaks[index] or 0)
      end

      local px = x + pixel

      ImGui.DrawList_AddLine(
        draw_list,
        px,
        center - amplitude * half,
        px,
        center + amplitude * half,
        lane_wave_color,
        1
      )
    end

    if lane_height >= 18 then
      local label =
        preview_channel_label(channel, channel_count)
      local label_width = channel_count > 2 and 42 or 24
      local label_x = x + width - label_width - 7
      local label_y = lane_y + 2

      ImGui.DrawList_AddRectFilled(
        draw_list,
        label_x,
        label_y,
        label_x + label_width,
        label_y + 16,
        rgba_with_alpha(COLOR.window, 0xD8),
        4
      )

      ImGui.DrawList_AddText(
        draw_list,
        label_x + 6,
        label_y + 1,
        channel_selected and COLOR.accent or COLOR.dim,
        label
      )
    end
  end

  for channel = 1, channel_count do
    draw_lane(
      channel_peaks and channel_peaks[channel] or waveform.peaks,
      channel,
      lanes_y + (channel - 1) * lane_height
    )
  end
end

function draw_wave_time_ruler(
  draw_list,
  asset,
  x,
  y,
  width,
  height
)
  if not asset or (asset.duration or 0) <= 0 then
    return
  end

  local duration = asset.duration
  local span_seconds = duration * wave_view_span()
  local divisions = width > 1100 and 8 or 5

  for index = 0, divisions do
    local local_percent = index / divisions
    local source_percent = wave_source_percent(local_percent)
    local px = x + width * local_percent
    local seconds = duration * source_percent

    ImGui.DrawList_AddLine(
      draw_list,
      px,
      y,
      px,
      y + height,
      rgba_with_alpha(COLOR.grid, (index == 0 or index == divisions) and 0x90 or 0x50),
      1
    )

    if index < divisions then
      ImGui.DrawList_AddText(
        draw_list,
        px + 4,
        y + 3,
        COLOR.dim,
        format_time(seconds)
      )
    end
  end

  ImGui.DrawList_AddText(
    draw_list,
    x + width - 82,
    y + 3,
    COLOR.dim,
    string.format("×%.1f", 1 / wave_view_span())
  )
end

function text_width(text)
  return ImGui.CalcTextSize(ctx, tostring(text))
end

function tooltip(text, max_chars)
  if not ImGui.IsItemHovered(ctx) then
    return
  end

  local now = reaper.time_precise()
  local translated =
    translate_ui_text(text)

  local hover_was_interrupted =
    now - (state.tooltip_last_seen_at or 0)
      > 0.14

  if state.tooltip_hover_text ~= translated
    or hover_was_interrupted then
    state.tooltip_hover_text = translated
    state.tooltip_hover_started_at = now
  end

  state.tooltip_last_seen_at = now

  if now - state.tooltip_hover_started_at
      < state.tooltip_delay then
    return
  end

  local mouse_x, mouse_y =
    ImGui.GetMousePos(ctx)

  -- 这里只登记提示内容，不创建 Popup 或 Tooltip 窗口。
  -- 主窗口完成布局后统一绘制，避免 Popup 自动尺寸在切换图标时闪烁。
  state.tooltip_pending_text = max_chars == false
    and translated
    or compact(translated, max_chars or 58)

  state.tooltip_pending_mouse_x =
    mouse_x

  state.tooltip_pending_mouse_y =
    mouse_y
end

function draw_tooltip_overlay()
  local text =
    state.tooltip_pending_text

  if not text or text == "" then
    return
  end

  local draw_list

  if type(ImGui.GetForegroundDrawList) == "function" then
    draw_list = ImGui.GetForegroundDrawList(ctx)
  else
    draw_list = ImGui.GetWindowDrawList(ctx)
  end

  local text_width_value, text_height =
    ImGui.CalcTextSize(
      ctx,
      text
    )

  local padding_x = 11
  local padding_y = 7
  local box_width =
    clamp(
      (text_width_value or 0)
        + padding_x * 2,
      120,
      540
    )

  local box_height =
    math.max(
      28,
      (text_height or 14)
        + padding_y * 2
    )

  local window_x, window_y =
    ImGui.GetWindowPos(ctx)

  local window_w, window_h =
    ImGui.GetWindowSize(ctx)

  local x =
    state.tooltip_pending_mouse_x + 15

  local y =
    state.tooltip_pending_mouse_y + 19

  if x + box_width
      > window_x + window_w - 8 then
    x =
      state.tooltip_pending_mouse_x
      - box_width
      - 12
  end

  if y + box_height
      > window_y + window_h - 8 then
    y =
      state.tooltip_pending_mouse_y
      - box_height
      - 12
  end

  x =
    clamp(
      x,
      window_x + 8,
      window_x + window_w
        - box_width
        - 8
    )

  y =
    clamp(
      y,
      window_y + 8,
      window_y + window_h
        - box_height
        - 8
    )

  -- 轻量阴影。
  ImGui.DrawList_AddRectFilled(
    draw_list,
    x + 3,
    y + 4,
    x + box_width + 3,
    y + box_height + 4,
    0x00000066,
    7
  )

  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + box_width,
    y + box_height,
    0x202328F5,
    7
  )

  ImGui.DrawList_AddRect(
    draw_list,
    x + 0.5,
    y + 0.5,
    x + box_width - 0.5,
    y + box_height - 0.5,
    rgba_with_alpha(
      COLOR.border,
      0xB0
    ),
    7,
    0,
    1
  )

  ImGui.DrawList_AddText(
    draw_list,
    x + padding_x,
    y + padding_y,
    COLOR.text,
    text
  )
end

function draw_icon_glyph(draw_list, icon, x, y, size, color_value)
  local left = x + size * 0.22
  local right = x + size * 0.78
  local top = y + size * 0.22
  local bottom = y + size * 0.78
  local center_x = x + size * 0.5
  local center_y = y + size * 0.5
  local thickness = math.max(1.4, size * 0.065)

  if icon == "panel_left" or icon == "panel_right" then
    ImGui.DrawList_AddRect(
      draw_list,
      left,
      top,
      right,
      bottom,
      color_value,
      2,
      0,
      thickness
    )

    local divider =
      icon == "panel_left"
      and x + size * 0.40
      or x + size * 0.60

    ImGui.DrawList_AddLine(
      draw_list,
      divider,
      top,
      divider,
      bottom,
      color_value,
      thickness
    )
  elseif icon == "focus" then
    local arm = size * 0.18
    ImGui.DrawList_AddLine(draw_list, left, top + arm, left, top, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, left, top, left + arm, top, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, right - arm, top, right, top, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, right, top, right, top + arm, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, left, bottom - arm, left, bottom, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, left, bottom, left + arm, bottom, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, right - arm, bottom, right, bottom, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, right, bottom - arm, right, bottom, color_value, thickness)
  elseif icon == "close" or icon == "clear_selection" then
    if icon == "clear_selection" then
      ImGui.DrawList_AddRect(draw_list, left, top, right, bottom, color_value, 2, 0, thickness)
    end
    ImGui.DrawList_AddLine(draw_list, left + 2, top + 2, right - 2, bottom - 2, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, right - 2, top + 2, left + 2, bottom - 2, color_value, thickness)
  elseif icon == "refresh" then
    ImGui.DrawList_AddCircle(draw_list, center_x, center_y, size * 0.22, color_value, 20, thickness)
    ImGui.DrawList_AddTriangleFilled(
      draw_list,
      right - size * 0.02,
      top + size * 0.17,
      right - size * 0.18,
      top + size * 0.16,
      right - size * 0.08,
      top + size * 0.31,
      color_value
    )
  elseif icon == "played_reset" then
    ImGui.DrawList_AddCircle(
      draw_list,
      center_x,
      center_y,
      size * 0.23,
      color_value,
      18,
      thickness
    )
    ImGui.DrawList_AddLine(
      draw_list,
      center_x,
      center_y,
      center_x,
      top + size * 0.12,
      color_value,
      thickness
    )
    ImGui.DrawList_AddLine(
      draw_list,
      center_x,
      center_y,
      right - size * 0.10,
      center_y + size * 0.05,
      color_value,
      thickness
    )
    ImGui.DrawList_AddLine(
      draw_list,
      left + size * 0.05,
      bottom - size * 0.02,
      right - size * 0.02,
      top + size * 0.05,
      COLOR.error,
      thickness
    )
  elseif icon == "settings" then
    ImGui.DrawList_AddCircle(draw_list, center_x, center_y, size * 0.12, color_value, 16, thickness)
    ImGui.DrawList_AddCircle(draw_list, center_x, center_y, size * 0.25, color_value, 20, thickness)
    for index = 0, 7 do
      local angle = index * math.pi / 4
      local x1 = center_x + math.cos(angle) * size * 0.25
      local y1 = center_y + math.sin(angle) * size * 0.25
      local x2 = center_x + math.cos(angle) * size * 0.34
      local y2 = center_y + math.sin(angle) * size * 0.34
      ImGui.DrawList_AddLine(draw_list, x1, y1, x2, y2, color_value, thickness)
    end
  elseif icon == "help" then
    ImGui.DrawList_AddCircle(
      draw_list,
      center_x,
      center_y,
      size * 0.27,
      color_value,
      20,
      thickness
    )
    ImGui.DrawList_AddText(
      draw_list,
      center_x - size * 0.095,
      center_y - size * 0.245,
      color_value,
      "?"
    )
  elseif icon == "speaker" then
    ImGui.DrawList_AddRectFilled(draw_list, left, center_y - size * 0.09, left + size * 0.12, center_y + size * 0.09, color_value)
    ImGui.DrawList_AddTriangleFilled(draw_list, left + size * 0.10, center_y - size * 0.10, center_x, top + size * 0.04, center_x, bottom - size * 0.04, color_value)
    ImGui.DrawList_AddCircle(draw_list, center_x, center_y, size * 0.20, color_value, 16, thickness)
  elseif icon == "play" then
    ImGui.DrawList_AddTriangleFilled(draw_list, left + size * 0.08, top, right, center_y, left + size * 0.08, bottom, color_value)
  elseif icon == "stop" then
    ImGui.DrawList_AddRectFilled(draw_list, left + size * 0.04, top + size * 0.04, right - size * 0.04, bottom - size * 0.04, color_value, 2)
  elseif icon == "insert" then
    ImGui.DrawList_AddLine(draw_list, left, bottom, right, bottom, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x, top, center_x, bottom - size * 0.12, color_value, thickness)
    ImGui.DrawList_AddTriangleFilled(draw_list, center_x - size * 0.12, center_y + size * 0.04, center_x + size * 0.12, center_y + size * 0.04, center_x, bottom - size * 0.04, color_value)
  elseif icon == "transfer" then
    ImGui.DrawList_AddRect(
      draw_list,
      left,
      center_y + size * 0.08,
      right,
      bottom,
      color_value,
      2,
      0,
      thickness
    )
    ImGui.DrawList_AddLine(
      draw_list,
      center_x,
      top,
      center_x,
      center_y + size * 0.10,
      color_value,
      thickness
    )
    ImGui.DrawList_AddTriangleFilled(
      draw_list,
      center_x - size * 0.14,
      center_y - size * 0.03,
      center_x + size * 0.14,
      center_y - size * 0.03,
      center_x,
      center_y + size * 0.15,
      color_value
    )
  elseif icon == "new_track" then
    ImGui.DrawList_AddLine(draw_list, left, top + size * 0.10, right - size * 0.14, top + size * 0.10, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, left, center_y, right - size * 0.14, center_y, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, left, bottom - size * 0.10, right - size * 0.14, bottom - size * 0.10, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, right - size * 0.10, center_y - size * 0.12, right - size * 0.10, center_y + size * 0.12, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, right - size * 0.22, center_y, right + size * 0.02, center_y, color_value, thickness)
  elseif icon == "clock" then
    ImGui.DrawList_AddCircle(draw_list, center_x, center_y, size * 0.25, color_value, 20, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x, center_y, center_x, top + size * 0.10, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x, center_y, right - size * 0.08, center_y + size * 0.10, color_value, thickness)
  elseif icon == "star" then
    for index = 0, 4 do
      local angle1 = -math.pi / 2 + index * 2 * math.pi / 5
      local angle2 = angle1 + 4 * math.pi / 5
      ImGui.DrawList_AddLine(
        draw_list,
        center_x + math.cos(angle1) * size * 0.27,
        center_y + math.sin(angle1) * size * 0.27,
        center_x + math.cos(angle2) * size * 0.27,
        center_y + math.sin(angle2) * size * 0.27,
        color_value,
        thickness
      )
    end
  elseif icon == "folder"
    or icon == "folder_search" then
    ImGui.DrawList_AddRect(draw_list, left, top + size * 0.10, right, bottom, color_value, 2, 0, thickness)
    ImGui.DrawList_AddLine(draw_list, left, top + size * 0.10, center_x - size * 0.05, top + size * 0.10, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x - size * 0.05, top + size * 0.10, center_x + size * 0.03, top, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x + size * 0.03, top, right - size * 0.05, top, color_value, thickness)

    if icon == "folder_search" then
      local lens_x = right - size * 0.08
      local lens_y = bottom - size * 0.08
      local lens_r = size * 0.13

      ImGui.DrawList_AddCircle(
        draw_list,
        lens_x,
        lens_y,
        lens_r,
        color_value,
        14,
        thickness
      )
      ImGui.DrawList_AddLine(
        draw_list,
        lens_x + lens_r * 0.70,
        lens_y + lens_r * 0.70,
        right + size * 0.07,
        bottom + size * 0.07,
        color_value,
        thickness
      )
    end
  elseif icon == "drag" then
    ImGui.DrawList_AddLine(draw_list, left, center_y, right, center_y, color_value, thickness)
    ImGui.DrawList_AddTriangleFilled(draw_list, right, center_y, right - size * 0.18, center_y - size * 0.13, right - size * 0.18, center_y + size * 0.13, color_value)
    ImGui.DrawList_AddLine(draw_list, left, top, left, bottom, color_value, thickness)
  elseif icon == "loop" then
    ImGui.DrawList_AddLine(draw_list, left + size * 0.06, top + size * 0.12, right - size * 0.08, top + size * 0.12, color_value, thickness)
    ImGui.DrawList_AddTriangleFilled(draw_list, right, top + size * 0.12, right - size * 0.16, top, right - size * 0.16, top + size * 0.24, color_value)
    ImGui.DrawList_AddLine(draw_list, right - size * 0.06, bottom - size * 0.12, left + size * 0.08, bottom - size * 0.12, color_value, thickness)
    ImGui.DrawList_AddTriangleFilled(draw_list, left, bottom - size * 0.12, left + size * 0.16, bottom - size * 0.24, left + size * 0.16, bottom, color_value)
  elseif icon == "reverse" then
    ImGui.DrawList_AddTriangleFilled(draw_list, left, center_y, center_x + size * 0.06, top, center_x + size * 0.06, bottom, color_value)
    ImGui.DrawList_AddLine(draw_list, center_x + size * 0.06, center_y, right, center_y, color_value, thickness)
  elseif icon == "sliders" then
    local ys = { top + size * 0.08, center_y, bottom - size * 0.08 }
    local knobs = { x + size * 0.38, x + size * 0.62, x + size * 0.46 }
    for index = 1, 3 do
      ImGui.DrawList_AddLine(draw_list, left, ys[index], right, ys[index], color_value, thickness)
      ImGui.DrawList_AddCircleFilled(draw_list, knobs[index], ys[index], size * 0.06, color_value, 12)
    end
  elseif icon == "zoom_reset" then
    ImGui.DrawList_AddCircle(draw_list, center_x - size * 0.06, center_y - size * 0.05, size * 0.18, color_value, 16, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x + size * 0.07, center_y + size * 0.08, right, bottom, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x - size * 0.14, center_y - size * 0.05, center_x + size * 0.02, center_y - size * 0.05, color_value, thickness)
  elseif icon == "region_add" then
    ImGui.DrawList_AddRect(draw_list, left, top + size * 0.08, right, bottom - size * 0.08, color_value, 2, 0, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x, top + size * 0.17, center_x, bottom - size * 0.17, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, left + size * 0.14, center_y, right - size * 0.14, center_y, color_value, thickness)
  elseif icon == "regions" then
    for index = 0, 2 do
      local yy = top + size * (0.08 + index * 0.22)
      ImGui.DrawList_AddRect(draw_list, left, yy, right, yy + size * 0.12, color_value, 1, 0, thickness)
    end
  elseif icon == "transient" then
    ImGui.DrawList_AddLine(draw_list, left, center_y, left + size * 0.15, center_y, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, left + size * 0.15, center_y, center_x - size * 0.08, top, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x - size * 0.08, top, center_x + size * 0.02, bottom, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, center_x + size * 0.02, bottom, right - size * 0.12, center_y, color_value, thickness)
    ImGui.DrawList_AddLine(draw_list, right - size * 0.12, center_y, right, center_y, color_value, thickness)
  elseif icon == "channel"
    or icon == "channel_stereo"
    or icon == "channel_left"
    or icon == "channel_right"
    or icon == "channel_mono"
    or icon == "channel_multi" then
    local quiet =
      rgba_with_alpha(color_value, 0x58)

    if icon == "channel_left" then
      ImGui.DrawList_AddLine(draw_list, left, top, left, bottom, color_value, thickness * 1.25)
      ImGui.DrawList_AddLine(draw_list, right, top + size * 0.10, right, bottom - size * 0.10, quiet, thickness)
    elseif icon == "channel_right" then
      ImGui.DrawList_AddLine(draw_list, left, top + size * 0.10, left, bottom - size * 0.10, quiet, thickness)
      ImGui.DrawList_AddLine(draw_list, right, top, right, bottom, color_value, thickness * 1.25)
    elseif icon == "channel_mono" then
      ImGui.DrawList_AddLine(draw_list, center_x, top, center_x, bottom, color_value, thickness * 1.25)
    elseif icon == "channel_multi" then
      local xs = {
        left,
        center_x - size * 0.10,
        center_x + size * 0.10,
        right,
      }

      for index, line_x in ipairs(xs) do
        local inset = (index % 2 == 0) and size * 0.08 or 0
        ImGui.DrawList_AddLine(
          draw_list,
          line_x,
          top + inset,
          line_x,
          bottom - inset,
          color_value,
          thickness
        )
      end
    else
      ImGui.DrawList_AddLine(draw_list, left, top, left, bottom, color_value, thickness)
      ImGui.DrawList_AddLine(draw_list, right, top, right, bottom, color_value, thickness)
    end
  elseif icon == "loudness" then
    for index = 0, 3 do
      local bar_x = left + index * size * 0.15
      local bar_h = size * (0.12 + index * 0.08)
      ImGui.DrawList_AddRectFilled(draw_list, bar_x, bottom - bar_h, bar_x + size * 0.08, bottom, color_value)
    end
  elseif icon == "more" then
    for index = -1, 1 do
      ImGui.DrawList_AddCircleFilled(
        draw_list,
        center_x + index * size * 0.16,
        center_y,
        size * 0.045,
        color_value,
        12
      )
    end
  else
    ImGui.DrawList_AddCircleFilled(draw_list, center_x, center_y, size * 0.08, color_value, 12)
  end
end

function icon_button(id, icon, tooltip_text, active, size, pulse)
  size = size or UI_METRIC.icon_button

  local x, y = ImGui.GetCursorScreenPos(ctx)

  ImGui.InvisibleButton(
    ctx,
    "##icon_" .. tostring(id),
    size,
    size
  )

  local clicked = ImGui.IsItemClicked(ctx, 0)
  local hovered = ImGui.IsItemHovered(ctx)
  local item_active = ImGui.IsItemActive(ctx)
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local radius = math.max(4, UI_METRIC.radius_small)

  -- Studio-style controls stay visually quiet at rest. Hover and enabled
  -- states use a soft tint instead of permanent boxes and borders.
  if active or item_active or hovered then
    local pulse_alpha =
      pulse
      and math.floor(
        0x22
        + 0x20 * (
          0.5
          + 0.5 * math.sin(reaper.time_precise() * 6.5)
        )
      )
      or 0x32
    local background =
      active and rgba_with_alpha(COLOR.accent, pulse_alpha)
      or item_active and rgba_with_alpha(COLOR.accent, 0x26)
      or rgba_with_alpha(COLOR.text, 0x14)

    ImGui.DrawList_AddRectFilled(
      draw_list,
      x,
      y,
      x + size,
      y + size,
      background,
      radius
    )
  end

  local glyph_padding = math.max(4, math.floor(size * 0.16))

  draw_icon_glyph(
    draw_list,
    icon,
    x + glyph_padding,
    y + glyph_padding,
    size - glyph_padding * 2,
    (active or hovered)
      and COLOR.accent
      or COLOR.text
  )

  if pulse then
    local phase =
      0.5
      + 0.5 * math.sin(reaper.time_precise() * 6.5)
    ImGui.DrawList_AddCircle(
      draw_list,
      x + size - math.max(5, size * 0.17),
      y + math.max(5, size * 0.17),
      math.max(2, size * (0.055 + phase * 0.025)),
      rgba_with_alpha(
        COLOR.accent,
        math.floor(0x90 + phase * 0x6F)
      ),
      16,
      1.5
    )
  end

  if tooltip_text then
    tooltip(tooltip_text)
  end

  return clicked, hovered, item_active
end

function draw_brand_symbol(draw_list, x, y, size)
  local center_x = x + size * 0.5
  local left = x + size * 0.10
  local right = x + size * 0.90
  local half_h = size * 0.235
  local layer_gap = size * 0.17

  for layer = 2, 0, -1 do
    local center_y = y + size * 0.34 + layer * layer_gap
    local top_y = center_y - half_h
    local bottom_y = center_y + half_h
    local fill =
      layer == 0
        and COLOR.panel_alt
        or rgba_with_alpha(COLOR.button, 0xC8)
    local outline =
      layer == 0
        and COLOR.accent
        or rgba_with_alpha(COLOR.header_text, 0x92)

    ImGui.DrawList_AddQuadFilled(
      draw_list,
      center_x,
      top_y,
      right,
      center_y,
      center_x,
      bottom_y,
      left,
      center_y,
      fill
    )
    ImGui.DrawList_AddQuad(
      draw_list,
      center_x,
      top_y,
      right,
      center_y,
      center_x,
      bottom_y,
      left,
      center_y,
      outline,
      1.35
    )
  end

  local bar_center_y = y + size * 0.34
  local heights = { 0.12, 0.24, 0.38, 0.56, 0.38, 0.24, 0.12 }
  local spacing = size * 0.075

  for index, height_ratio in ipairs(heights) do
    local bar_x =
      center_x + (index - 4) * spacing
    local bar_h = size * height_ratio * 0.48

    ImGui.DrawList_AddLine(
      draw_list,
      bar_x,
      bar_center_y - bar_h,
      bar_x,
      bar_center_y + bar_h,
      COLOR.accent,
      math.max(1.4, size * 0.055)
    )
  end
end

function draw_brand_wordmark(
  draw_list,
  x,
  y,
  font_size
)
  local prefix = "PsyRea"
  local font_pushed = false

  if brand_font then
    ImGui.PushFont(
      ctx,
      brand_font,
      font_size or 16
    )
    font_pushed = true
  end

  local prefix_width =
    select(
      1,
      ImGui.CalcTextSize(ctx, prefix)
    ) or 48

  ImGui.DrawList_AddText(
    draw_list,
    x,
    y,
    COLOR.header_text,
    prefix
  )
  ImGui.DrawList_AddText(
    draw_list,
    x + prefix_width,
    y,
    COLOR.accent,
    "SFX"
  )

  if font_pushed then
    ImGui.PopFont(ctx)
  end
end

function draw_brand_mark(compact)
  local draw_list =
    ImGui.GetWindowDrawList(ctx)

  local x, y =
    ImGui.GetCursorScreenPos(ctx)

  local width = compact and 38 or 166
  local height = 34

  ImGui.InvisibleButton(
    ctx,
    "psyreasfx_brand",
    width,
    height
  )

  draw_brand_symbol(draw_list, x + 1, y + 1, 32)

  if not compact then
    local word_x = x + 42
    local word_y = y + 8
    draw_brand_wordmark(
      draw_list,
      word_x,
      word_y,
      16
    )
  end

  tooltip("PsyReaSFX · Sound Assets Organized")
end

function metric_chip(label, value, accent)
  local translated_label = translate_ui_text(label)
  local value_text = tostring(value or "")
  local label_w =
    select(1, ImGui.CalcTextSize(ctx, translated_label)) or 0
  local value_w =
    select(1, ImGui.CalcTextSize(ctx, value_text)) or 0

  local width = label_w + value_w + 20
  local height = 22
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local draw_list = ImGui.GetWindowDrawList(ctx)

  ImGui.Dummy(ctx, width, height)

  ImGui.DrawList_AddText(
    draw_list,
    x + 2,
    y + 4,
    COLOR.dim,
    translated_label
  )

  ImGui.DrawList_AddText(
    draw_list,
    x + width - value_w - 2,
    y + 4,
    accent and COLOR.playhead or COLOR.text,
    value_text
  )
end

function inline_metric_text(text, color, maximum_width)
  text = translate_ui_text(tostring(text or ""))
  maximum_width = math.max(1, tonumber(maximum_width) or 1)

  local fitted = fit_text_to_width(text, maximum_width - 4)
  local text_width =
    select(1, ImGui.CalcTextSize(ctx, fitted)) or 0
  local width = math.min(maximum_width, text_width + 4)
  local height = 22
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local draw_list = ImGui.GetWindowDrawList(ctx)

  ImGui.Dummy(ctx, width, height)

  ImGui.DrawList_AddText(
    draw_list,
    x + 2,
    y + 4,
    color,
    fitted
  )
end

function draw_parameter_card(
  id,
  label,
  value,
  minimum,
  maximum,
  default_value,
  format_string,
  width,
  height
)
  width =
    clamp(
      width or 124,
      UI_METRIC.parameter_min_w,
      UI_METRIC.parameter_max_w
    )

  height = height or UI_METRIC.parameter_h

  local x, y = ImGui.GetCursorScreenPos(ctx)
  local compact_card = height <= 40
  local translated_label = translate_ui_text(label)
  local value_text = string.format(format_string, value)
  local value_w =
    select(1, ImGui.CalcTextSize(ctx, value_text)) or 0
  local value_left =
    math.max(
      x + width * 0.48,
      x + width - value_w - 18
    )
  local value_right = x + width - 6
  local value_top = y + 1
  local value_bottom =
    y + (compact_card and 22 or 30)
  local editing =
    state.parameter_edit
    and state.parameter_edit.id == id

  if editing then
    ImGui.Dummy(ctx, width, height)
  else
    ImGui.InvisibleButton(
      ctx,
      "##parameter_" .. tostring(id),
      width,
      height
    )
  end

  local after_x, after_y = ImGui.GetCursorScreenPos(ctx)
  local hovered = not editing and ImGui.IsItemHovered(ctx)
  local active = not editing and ImGui.IsItemActive(ctx)
  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local changed = false
  local double_clicked =
    hovered and ImGui.IsMouseDoubleClicked(ctx, 0)
  local value_double_clicked =
    double_clicked
    and mouse_x >= value_left
    and mouse_x <= value_right
    and mouse_y >= value_top
    and mouse_y <= value_bottom

  if value_double_clicked then
    state.parameter_drag = nil
    state.keyboard_consumed = true
    state.parameter_edit = {
      id = id,
      value = value,
      original = value,
      focus = true,
      seen_active = false,
    }
    editing = true
    active = true
  elseif double_clicked then
    state.parameter_drag = nil
    value = default_value
    changed = true
    mark_interaction()
  elseif hovered and ImGui.IsItemClicked(ctx, 0) then
    state.parameter_drag = {
      id = id,
      start_x = mouse_x,
      start_y = mouse_y,
      start_value = value,
    }
  end

  if active
    and state.parameter_drag
    and state.parameter_drag.id == id then

    local horizontal =
      (mouse_x - state.parameter_drag.start_x) / 170

    local vertical =
      (state.parameter_drag.start_y - mouse_y) / 145

    local normalized_delta =
      math.abs(horizontal) >= math.abs(vertical)
      and horizontal
      or vertical

    local new_value =
      clamp(
        state.parameter_drag.start_value
          + normalized_delta * (maximum - minimum),
        minimum,
        maximum
      )

    if math.abs(new_value - value) > 0.000001 then
      value = new_value
      changed = true
      mark_interaction()
    end
  end

  if hovered then
    local wheel = ImGui.GetMouseWheel(ctx) or 0

    if wheel ~= 0 then
      local fine =
        (maximum - minimum) / 100

      value =
        clamp(
          value + wheel * fine,
          minimum,
          maximum
        )

      changed = true
      mark_interaction()
    end
  end

  if not ImGui.IsMouseDown(ctx, 0)
    and state.parameter_drag
    and state.parameter_drag.id == id then
    state.parameter_drag = nil
  end

  local draw_list = ImGui.GetWindowDrawList(ctx)
  local text_y = compact_card and (y + 4) or (y + 8)

  ImGui.DrawList_AddText(
    draw_list,
    x + 10,
    text_y,
    COLOR.dim,
    translated_label
  )

  if not editing then
    ImGui.DrawList_AddText(
      draw_list,
      x + width - value_w - 10,
      text_y,
      active and COLOR.selected_text or COLOR.header_text,
      value_text
    )
  end

  local track_left = x + 10
  local track_right = x + width - 10
  local track_y =
    compact_card and (y + height - 4) or (y + height - 13)
  local normalized =
    clamp(
      (value - minimum)
        / math.max(0.000001, maximum - minimum),
      0,
      1
    )

  local origin =
    clamp(
      (default_value - minimum)
        / math.max(0.000001, maximum - minimum),
      0,
      1
    )

  local value_x =
    track_left
      + (track_right - track_left) * normalized

  local origin_x =
    track_left
      + (track_right - track_left) * origin

  ImGui.DrawList_AddLine(
    draw_list,
    track_left,
    track_y,
    track_right,
    track_y,
    rgba_with_alpha(COLOR.text, 0x25),
    3
  )

  ImGui.DrawList_AddLine(
    draw_list,
    math.min(origin_x, value_x),
    track_y,
    math.max(origin_x, value_x),
    track_y,
    active and COLOR.selected_text or COLOR.selected,
    3
  )

  ImGui.DrawList_AddLine(
    draw_list,
    origin_x,
    track_y - 4,
    origin_x,
    track_y + 4,
    rgba_with_alpha(COLOR.text, 0x66),
    1
  )

  ImGui.DrawList_AddCircleFilled(
    draw_list,
    value_x,
    track_y,
    compact_card
      and (active and 4 or 3)
      or (active and 5 or 4),
    active and COLOR.selected_text or COLOR.text,
    16
  )

  if editing and state.parameter_edit then
    -- The editor may deactivate on Enter before the global shortcut pass
    -- runs later in this same frame. Keep the whole editor lifetime and its
    -- closing frame isolated from application shortcuts.
    state.keyboard_consumed = true
    local editor = state.parameter_edit
    local input_width = math.max(54, value_right - value_left)
    local input_y = y + (compact_card and 0 or 3)

    ImGui.SetCursorScreenPos(ctx, value_left, input_y)
    ImGui.SetNextItemWidth(ctx, input_width)

    ImGui.PushStyleVar(
      ctx,
      ImGui.StyleVar_FramePadding,
      4,
      2
    )
    ImGui.PushStyleVar(
      ctx,
      ImGui.StyleVar_FrameRounding,
      UI_METRIC.radius_small
    )
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_FrameBg,
      rgba_with_alpha(COLOR.accent, 0x26)
    )
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_FrameBgHovered,
      rgba_with_alpha(COLOR.accent, 0x36)
    )
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_FrameBgActive,
      rgba_with_alpha(COLOR.accent, 0x46)
    )
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_Text,
      COLOR.selected_text
    )

    if editor.focus then
      ImGui.SetKeyboardFocusHere(ctx)
      editor.focus = false
    end

    local input_changed, edited_value =
      ImGui.InputDouble(
        ctx,
        "##parameter_editor_" .. tostring(id),
        editor.value,
        0,
        0,
        format_string,
        ImGui.InputTextFlags_AutoSelectAll
      )

    editor.value = edited_value

    local input_active = ImGui.IsItemActive(ctx)

    if input_active then
      editor.seen_active = true
    end

    local cancel =
      input_active
      and ImGui.IsKeyPressed(
        ctx,
        ImGui.Key_Escape,
        false
      )

    local confirm =
      input_active
      and ImGui.IsKeyPressed(
        ctx,
        ImGui.Key_Enter,
        false
      )

    local finished =
      confirm
      or (
        editor.seen_active
        and ImGui.IsItemDeactivated(ctx)
      )

    if cancel then
      if math.abs(editor.original - value) > 0.000001 then
        value = editor.original
        changed = true
      end
      state.parameter_edit = nil
    else
      local clamped_value =
        clamp(edited_value, minimum, maximum)

      if input_changed
        and math.abs(clamped_value - value) > 0.000001 then
        value = clamped_value
        changed = true
        mark_interaction()
      end

      if finished then
        state.parameter_edit = nil
      end
    end

    ImGui.PopStyleColor(ctx, 4)
    ImGui.PopStyleVar(ctx, 2)

    -- Restore the parameter card as the final layout item so neighboring
    -- controls keep their original positions while the editor is visible.
    ImGui.SetCursorScreenPos(ctx, x, y)
    ImGui.Dummy(ctx, width, height)
    ImGui.SetCursorScreenPos(ctx, after_x, after_y)
  end

  if hovered then
    local guidance =
      state.language == "en"
        and "Drag or use the wheel; double-click the value to type; double-click the label or track to reset"
        or "拖动或滚轮调整；双击数值输入；双击标签或滑轨恢复默认值"

    tooltip(
      label
        .. " · "
        .. guidance
    )
  end

  return value, changed
end

function begin_control_panel(id, width, height)
  ImGui.PushStyleVar(
    ctx,
    ImGui.StyleVar_WindowPadding,
    UI_METRIC.panel_padding,
    UI_METRIC.panel_padding
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_ChildBg,
    COLOR.panel
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Border,
    rgba_with_alpha(COLOR.border, 0xA0)
  )

  local visible =
    ImGui.BeginChild(
      ctx,
      id,
      width,
      height,
      ImGui.ChildFlags_Borders,
      ImGui.WindowFlags_NoScrollbar
        | ImGui.WindowFlags_NoScrollWithMouse
    )

  return visible
end

function end_control_panel()
  ImGui.EndChild(ctx)
  ImGui.PopStyleColor(ctx, 2)
  ImGui.PopStyleVar(ctx)
end

function toolbar_separator(height)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local draw_list = ImGui.GetWindowDrawList(ctx)

  ImGui.Dummy(ctx, 7, height)

  ImGui.DrawList_AddLine(
    draw_list,
    x + 3,
    y + 4,
    x + 3,
    y + height - 4,
    rgba_with_alpha(COLOR.border, 0x80),
    1
  )
end

function bottom_controls_reserve_height(width, asset)
  local layout = preview_control_layout_metrics(width)
  local base =
    54
      + layout.panel_height
  local channel_count =
    asset
      and preview_asset_channel_count(asset)
      or (state.preview_channel_count or 0)

  if state.preview_channel_strip_expanded
    and channel_count > 2 then
    base = base + (
      state.ui_density == "comfortable"
        and 42
        or 38
    )
  end

  return base
end

function draw_bottom_splitter(width, total_height)
  local x, y = ImGui.GetCursorScreenPos(ctx)

  ImGui.InvisibleButton(
    ctx,
    "bottom_panel_splitter",
    width,
    BOTTOM_SPLITTER_H
  )

  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)
  local _, mouse_y = ImGui.GetMousePos(ctx)

  if hovered or active then
    ImGui.SetMouseCursor(
      ctx,
      ImGui.MouseCursor_ResizeNS
    )
  end

  if ImGui.IsItemClicked(ctx, 0) then
    state.bottom_split_drag = {
      start_y = mouse_y,
      start_height = state.bottom_panel_height,
    }
  end

  if active and state.bottom_split_drag then
    local maximum_drag_height =
      math.max(
        1,
        math.min(
          BOTTOM_MAX_H,
          total_height - BOTTOM_SPLITTER_H - 24
        )
      )

    local minimum_drag_height =
      math.min(BOTTOM_MIN_H, maximum_drag_height)

    state.bottom_panel_height =
      clamp(
        state.bottom_split_drag.start_height
          - (mouse_y - state.bottom_split_drag.start_y),
        minimum_drag_height,
        maximum_drag_height
      )

    state.config_dirty = true
  end

  if not ImGui.IsMouseDown(ctx, 0) then
    state.bottom_split_drag = nil
  end

  local draw_list = ImGui.GetWindowDrawList(ctx)
  local handle_width =
    active and 54 or hovered and 50 or 44
  local handle_height =
    active and 5 or 4
  local handle_x = x + width * 0.5
  local handle_y =
    y + BOTTOM_SPLITTER_H * 0.5

  ImGui.DrawList_AddRectFilled(
    draw_list,
    handle_x - handle_width * 0.5,
    handle_y - handle_height * 0.5,
    handle_x + handle_width * 0.5,
    handle_y + handle_height * 0.5,
    active and COLOR.selected
      or hovered
        and rgba_with_alpha(COLOR.border, 0xD0)
        or rgba_with_alpha(COLOR.dim, 0x78),
    handle_height * 0.5
  )
end

function dark_button(label, width)
  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Button,
    COLOR.button
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_ButtonHovered,
    COLOR.button_hover
  )

  local clicked =
    ImGui.Button(
      ctx,
      label,
      width or 0,
      0
    )

  ImGui.PopStyleColor(ctx, 2)
  return clicked
end

function draw_clipped_text(
  draw_list,
  x,
  y,
  color_value,
  value,
  clip_min_x,
  clip_min_y,
  clip_max_x,
  clip_max_y
)
  ImGui.DrawList_PushClipRect(
    draw_list,
    clip_min_x,
    clip_min_y,
    clip_max_x,
    clip_max_y,
    true
  )

  ImGui.DrawList_AddText(
    draw_list,
    x,
    y,
    color_value,
    tostring(value or "")
  )

  ImGui.DrawList_PopClipRect(draw_list)
end

function begin_module(
  id,
  width,
  height,
  scrollable,
  borderless
)
  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_ChildBg,
    COLOR.panel
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Border,
    COLOR.grid
  )

  local window_flags = 0

  if not scrollable then
    window_flags =
      ImGui.WindowFlags_NoScrollbar
      | ImGui.WindowFlags_NoScrollWithMouse
  end

  local child_flags =
    borderless and 0
      or ImGui.ChildFlags_Borders

  local visible =
    ImGui.BeginChild(
      ctx,
      id,
      width,
      height,
      child_flags,
      window_flags
    )

  return visible
end

function end_module()
  ImGui.EndChild(ctx)
  ImGui.PopStyleColor(ctx, 2)
end

function library_asset_count(library_id)
  return state.library_asset_counts[library_id] or 0
end

function process_library_count_rebuild()
  if not state.library_counts_dirty then
    state.library_counts_job = nil
    return
  end
  if state.scan or state.import_session then
    state.library_counts_job = nil
    return
  end

  local job = state.library_counts_job
  if not job then
    job = new_library_count_job()
    state.library_counts_job = job
  end

  local complete, counts = step_library_count_job(
    job,
    state.assets,
    LIBRARY_COUNT_ASSETS_PER_FRAME
  )
  if complete then
    state.library_asset_counts = counts
    state.library_counts_dirty = false
    state.library_counts_job = nil
  end
end

function rename_library(library)
  local ok, name = reaper.GetUserInputs(
    "重命名音效库",
    1,
    "名称:",
    library.name
  )

  name = trim(name or "")

  if not ok or name == "" then
    return
  end

  for _, other in ipairs(state.libraries) do
    if other.id ~= library.id
      and safe_lower(other.name) == safe_lower(name) then
      set_status("已经存在同名音效库", true)
      return
    end
  end

  library.name = name
  refresh_all_asset_library_bindings()
  state.libraries_dirty = true
  set_status("已重命名音效库：" .. name)
end

function library_paths_summary(library)
  local lines = {
    library.name,
    string.format(
      "%d 个来源路径 · %d 个素材",
      #(library.roots or {}),
      library_asset_count(library.id)
    ),
  }

  for index, record in ipairs(library.roots or {}) do
    if index > 5 then
      lines[#lines + 1] = string.format(
        "… 还有 %d 个路径",
        #library.roots - 5
      )
      break
    end

    lines[#lines + 1] =
      (directory_exists(record.path) and "● " or "○ ")
      .. record.path
    lines[#lines] = compact(lines[#lines], 64)
  end

  return table.concat(lines, "\n")
end

function scan_added_roots(roots, label)
  if #roots > 0 then
    start_scan(label or "添加来源路径", roots)
    save_libraries()
  end
end

function add_folders_to_library(library_id, folders)
  local added = {}
  local bindings_changed = false

  for _, folder in ipairs(folders or {}) do
    local existing = root_record_for_path(folder)

    if existing and existing.library_id ~= library_id then
      local old_library = library_for_root_record(existing)
      local new_library = state.library_by_id[library_id]
      local answer = reaper.MB(
        "该来源路径已经属于“"
          .. (old_library and old_library.name or "—")
          .. "”。\n\n是否移动到“"
          .. (new_library and new_library.name or "—")
          .. "”？\n\n不会移动磁盘文件。",
        SCRIPT_NAME,
        4
      )

      if answer == 6 then
        existing.library_id = library_id
        state.libraries_dirty = true
        bindings_changed = true
        set_status("已移动来源路径到音效库：" .. new_library.name)
      end
    elseif existing then
      set_status("该来源路径已经在当前音效库中")
    elseif add_root_to_library(
      library_id,
      folder,
      false,
      true
    ) then
      added[#added + 1] = folder
    end
  end

  if #added > 0 or bindings_changed then
    rebuild_library_indexes()

    if bindings_changed then
      refresh_all_asset_library_bindings()
    end

    state.results_dirty = true
  end

  scan_added_roots(added, "添加来源路径")
  return #added
end

function create_libraries_from_folders(folders)
  local added = {}

  for _, folder in ipairs(folders or {}) do
    local library = create_library(
      basename(folder),
      "library:" .. path_key(folder)
    )

    if add_root_to_library(
      library.id,
      folder,
      false,
      true
    ) then
      added[#added + 1] = folder
    else
      for index = #state.libraries, 1, -1 do
        if state.libraries[index].id == library.id then
          table.remove(state.libraries, index)
          break
        end
      end
    end
  end

  if #(folders or {}) > 0 then
    rebuild_library_indexes()
    state.results_dirty = true
  end

  scan_added_roots(added, "拖入音效库")
end

function collect_folder_payload()
  local accepted, count =
    ImGui.AcceptDragDropPayloadFiles(ctx)

  if not accepted then
    return nil
  end

  local folders = {}
  local seen = {}

  for index = 0, (count or 0) - 1 do
    local ok, path = ImGui.GetDragDropPayloadFile(ctx, index)
    path = ok and normalize_slashes(trim(path or "")) or ""

    if path ~= ""
      and directory_exists(path)
      and not seen[path_key(path)] then
      seen[path_key(path)] = true
      folders[#folders + 1] = path
    end
  end

  return folders
end

function handle_folder_drop(folders, target_library_id)
  if not folders or #folders == 0 then
    set_status("请拖入文件夹；音频文件不会作为来源路径导入", true)
    return
  end

  if target_library_id
    and state.library_by_id[target_library_id] then
    add_folders_to_library(target_library_id, folders)
    return
  end

  if #folders == 1 then
    create_libraries_from_folders(folders)
  else
    state.pending_folder_drop = {
      folders = folders,
      requested_open = true,
    }
  end
end

function accept_folder_drop_target(target_library_id)
  if not ImGui.BeginDragDropTarget(ctx) then
    return false
  end

  local folders = collect_folder_payload()
  ImGui.EndDragDropTarget(ctx)

  if folders then
    handle_folder_drop(folders, target_library_id)
    return true
  end

  return false
end

function draw_folder_drop_choice_popup()
  local pending = state.pending_folder_drop

  if not pending then
    return
  end

  if pending.requested_open then
    ImGui.OpenPopup(ctx, "导入多个文件夹##folder_drop")
    pending.requested_open = false
  end

  if not ImGui.BeginPopupModal(
    ctx,
    "导入多个文件夹##folder_drop",
    true,
    ImGui.WindowFlags_AlwaysAutoResize
  ) then
    return
  end

  ImGui.Text(ctx, string.format(
    "已拖入 %d 个文件夹",
    #pending.folders
  ))
  ImGui.TextDisabled(ctx, "请选择它们在音效库中的组织方式。")
  ImGui.Separator(ctx)

  if dark_button("每个文件夹建立一个音效库", 220) then
    create_libraries_from_folders(pending.folders)
    state.pending_folder_drop = nil
    ImGui.CloseCurrentPopup(ctx)
  end

  if dark_button("合并为一个音效库…", 220) then
    local default_name = basename(pending.folders[1])
    local ok, name = reaper.GetUserInputs(
      "新建逻辑音效库",
      1,
      "名称:",
      default_name
    )

    name = trim(name or "")

    if ok and name ~= "" then
      local library = create_library(name)
      add_folders_to_library(library.id, pending.folders)
      state.pending_folder_drop = nil
      ImGui.CloseCurrentPopup(ctx)
    end
  end

  if dark_button("取消", 220) then
    state.pending_folder_drop = nil
    ImGui.CloseCurrentPopup(ctx)
  end

  ImGui.EndPopup(ctx)
end


function draw_library_manager_popup()
  if not ImGui.BeginPopupModal(
    ctx,
    "管理音效库##psyreasfx",
    true,
    ImGui.WindowFlags_AlwaysAutoResize
  ) then
    return
  end

  ImGui.Text(ctx, "逻辑音效库与来源路径")
  ImGui.Separator(ctx)

  if #state.libraries == 0 then
    ImGui.TextDisabled(ctx, "尚未添加音效库")
  end

  local remove_library_id = nil
  local remove_root_record = nil

  for library_index, library in ipairs(state.libraries) do
    ImGui.PushID(ctx, "manager_library_" .. library.id)
    ImGui.TextColored(ctx, COLOR.text, library.name)
    ImGui.SameLine(ctx)
    ImGui.TextDisabled(ctx, string.format(
      "%d 个来源 · %d 个素材",
      #library.roots,
      library_asset_count(library.id)
    ))

    ImGui.SameLine(ctx)

    if dark_button("添加路径", 76) then
      add_root(library.id)
    end

    ImGui.SameLine(ctx)

    if dark_button("重命名", 64) then
      rename_library(library)
    end

    ImGui.SameLine(ctx)

    if dark_button("扫描", 54) then
      start_scan("扫描 " .. library.name, roots_for_library(library.id))
    end

    ImGui.SameLine(ctx)

    if dark_button("删除库", 64) then
      remove_library_id = library.id
    end

    for root_index, record in ipairs(library.roots) do
      ImGui.PushID(ctx, root_index)
      local online = directory_exists(record.path)
      ImGui.TextColored(
        ctx,
        online and COLOR.muted or 0xE36B68FF,
        online and "  ●" or "  ○"
      )
      ImGui.SameLine(ctx)
      ImGui.Text(ctx, compact(record.path, 72))
      tooltip(record.path)
      ImGui.SameLine(ctx)

      if dark_button("打开", 54) then
        open_folder(record.path)
      end

      ImGui.SameLine(ctx)

      if dark_button("封面", 54) then
        choose_artwork_for_root(record)
      end

      ImGui.SameLine(ctx)

      if dark_button("重建", 54) then
        start_scan(
          "重建 " .. basename(record.path),
          { record.path },
          { force_rebuild = true }
        )
      end

      ImGui.SameLine(ctx)

      if dark_button("移除", 54) then
        remove_root_record = record
      end

      ImGui.PopID(ctx)
    end

    if library_index < #state.libraries then
      ImGui.Separator(ctx)
    end

    ImGui.PopID(ctx)
  end

  if remove_root_record then
    local answer = reaper.MB(
      "从逻辑音效库中移除该来源路径？\n\n"
        .. remove_root_record.path
        .. "\n\n不会删除磁盘中的音频文件。",
      SCRIPT_NAME,
      4
    )

    if answer == 6 then
      remove_root(remove_root_record)
      save_libraries()
      save_database()
    end
  end

  if remove_library_id then
    local library = state.library_by_id[remove_library_id]
    local answer = reaper.MB(
      "删除逻辑音效库及其所有来源路径？\n\n"
        .. (library and library.name or "")
        .. "\n\n只会清除 PsyReaSFX 索引，不会删除磁盘文件。",
      SCRIPT_NAME,
      4
    )

    if answer == 6 then
      remove_library(remove_library_id)
      save_libraries()
      save_database()
    end
  end

  ImGui.Separator(ctx)

  if dark_button("+ 新建音效库", 120) then
    add_root()
  end

  ImGui.SameLine(ctx)

  if dark_button("关闭", 72) then
    ImGui.CloseCurrentPopup(ctx)
  end

  ImGui.EndPopup(ctx)
end


----------------------------------------------------------------
-- UI: toolbar
----------------------------------------------------------------

function sidebar_item(
  label,
  selected,
  on_click
)
  if selected then
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_Header,
      COLOR.selected
    )

    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_HeaderHovered,
      COLOR.selected
    )
  end

  local clicked =
    ImGui.Selectable(
      ctx,
      label,
      selected
    )

  if selected then
    ImGui.PopStyleColor(ctx, 2)
  end

  if clicked then
    on_click()
  end
end

function sidebar_section_header(key, label)
  local expanded =
    state.sidebar_sections[key] ~= false

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Header,
    0x00000000
  )
  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_HeaderHovered,
    rgba_with_alpha(COLOR.button_hover, 0xB8)
  )
  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_HeaderActive,
    rgba_with_alpha(COLOR.selected, 0x88)
  )
  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Text,
    COLOR.dim
  )

  local clicked = ImGui.Selectable(
    ctx,
    (expanded and "▾  " or "▸  ")
      .. label
      .. "##sidebar_section_"
      .. key,
    false
  )

  ImGui.PopStyleColor(ctx, 4)

  if clicked then
    expanded = not expanded
    state.sidebar_sections[key] = expanded
    state.config_dirty = true
  end

  return expanded
end

function activate_folder_path(path, library_id, close_browser)
  path = canonical_source_path(path)

  state.view = "all"
  state.root_filter = path ~= "" and path or nil
  state.library_filter_id = library_id
  state.active_collection_id = nil
  state.status_filter = nil
  clear_row_selection()
  state.results_dirty = true
  state.config_dirty = true

  if close_browser ~= false then
    state.folder_browser_open = false
  end
end

function clear_folder_path(keep_library)
  local library_id = nil

  if keep_library and state.root_filter then
    local _, record = root_for_path(state.root_filter)
    library_id = record and record.library_id or nil
  end

  state.root_filter = nil
  state.library_filter_id = library_id
  state.view = "all"
  state.active_collection_id = nil
  clear_row_selection()
  state.results_dirty = true
  state.config_dirty = true
end

function folder_path_label()
  if not state.root_filter then
    if state.library_filter_id then
      local library =
        state.library_by_id[state.library_filter_id]

      if library then
        return (
          state.language == "en"
          and "Library: "
          or "音效库："
        ) .. library.name
      end
    end

    return (
      state.language == "en"
      and "Path: "
      or "路径："
    ) .. translate_ui_text("全部音效库")
  end

  local _, record = root_for_path(state.root_filter)
  local library = record
    and state.library_by_id[record.library_id]
    or nil
  local parts = {}

  if library then
    parts[#parts + 1] = library.name
  end

  if record then
    parts[#parts + 1] =
      record.alias ~= "" and record.alias
      or basename(record.path)

    local relative =
      state.root_filter:sub(#record.path + 1)
        :gsub("^[\\/]+", "")

    for segment in relative:gmatch("[^\\/]+") do
      parts[#parts + 1] = segment
    end
  else
    parts[#parts + 1] = state.root_filter
  end

  return (
    state.language == "en"
    and "Path: "
    or "路径："
  ) .. table.concat(parts, " / ")
end

function draw_path_navigation_bar()
  local available = select(1, ImGui.GetContentRegionAvail(ctx))
  local clear_width = state.root_filter and 30 or 0
  local button_width = math.max(160, available - clear_width - 6)
  local active =
    state.folder_browser_open or state.root_filter ~= nil

  if active then
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_Button,
      rgba_with_alpha(COLOR.selected, 0xA8)
    )
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_ButtonHovered,
      rgba_with_alpha(COLOR.selected, 0xD8)
    )
  end

  local path_button_clicked = ImGui.Button(
    ctx,
    (state.folder_browser_open and "▾  " or "▸  ")
      .. folder_path_label()
      .. "##folder_path_bar",
    button_width,
    0
  )

  if path_button_clicked then
    state.folder_browser_open =
      not state.folder_browser_open
    state.config_dirty = true

    if state.folder_browser_open then
      ensure_folder_navigation_build()
    end
  end

  if active then
    ImGui.PopStyleColor(ctx, 2)
  end

  tooltip(
    state.root_filter
      or translate_ui_text(
        "展开全部音效库的文件夹结构"
      )
  )

  if state.root_filter then
    ImGui.SameLine(ctx)

    if dark_button("×##clear_folder_path", 30) then
      clear_folder_path(true)
    end

    tooltip("清除路径条件")
  end
end

function draw_folder_tree_node(node, depth, library_id)
  local has_children = #node.children > 0
  local expanded =
    state.expanded_folder_nodes[node.key] == true
  local selected = state.root_filter
    and path_key(state.root_filter) == node.key

  ImGui.PushID(ctx, "folder_node_" .. node.key)
  ImGui.SetCursorPosX(ctx, 18 + depth * 18)

  if has_children then
    if dark_button(expanded and "▾" or "▸", 20) then
      state.expanded_folder_nodes[node.key] = not expanded
      state.config_dirty = true
      expanded = not expanded
    end
  else
    ImGui.TextDisabled(ctx, "·")
  end

  ImGui.SameLine(ctx, 0, 2)

  sidebar_item(
    compact(node.name, 42)
      .. "  "
      .. tostring(node.total_count)
      .. "##folder_name",
    selected,
    function()
      activate_folder_path(
        node.path,
        library_id,
        true
      )
    end
  )

  tooltip(node.path)

  if ImGui.BeginPopupContextItem(
    ctx,
    "folder_context"
  ) then
    if ImGui.MenuItem(ctx, "打开目录") then
      open_folder(node.path)
    end

    if has_children
      and ImGui.MenuItem(
        ctx,
        expanded and "折叠此层级" or "展开此层级"
      ) then
      state.expanded_folder_nodes[node.key] = not expanded
      state.config_dirty = true
      expanded = not expanded
    end

    ImGui.EndPopup(ctx)
  end

  if expanded then
    for _, child in ipairs(node.children) do
      draw_folder_tree_node(
        child,
        depth + 1,
        library_id
      )
    end
  end

  ImGui.PopID(ctx)
end

function draw_folder_browser()
  if not state.folder_browser_open then
    return
  end

  ensure_folder_navigation_build()

  local available_w, available_h =
    ImGui.GetContentRegionAvail(ctx)
  local browser_h = math.min(
    clamp(available_h * 0.34, 150, 300),
    math.max(90, available_h - 250)
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_ChildBg,
    rgba_with_alpha(COLOR.panel, 0xFC)
  )

  local visible = ImGui.BeginChild(
    ctx,
    "folder_browser_inline",
    available_w,
    browser_h,
    ImGui.ChildFlags_Borders,
    0
  )

  if visible then
    ImGui.TextColored(
      ctx,
      COLOR.text,
      translate_ui_text("文件夹层级")
    )
    ImGui.SameLine(ctx)
    ImGui.TextDisabled(
      ctx,
      translate_ui_text(
        "箭头展开；单击名称跳转并显示该目录及其子目录"
      )
    )
    ImGui.Separator(ctx)

    sidebar_item(
      translate_ui_text("全部音效库")
        .. "  "
        .. tostring(#state.assets)
        .. "##folder_browser_all",
      state.root_filter == nil
        and state.library_filter_id == nil,
      function()
        clear_folder_path(false)
        state.folder_browser_open = false
      end
    )

    for _, library in ipairs(state.libraries) do
      local expanded =
        state.expanded_libraries[library.id] == true
      local selected =
        state.library_filter_id == library.id
        and state.root_filter == nil

      ImGui.PushID(ctx, "folder_library_" .. library.id)

      if dark_button(expanded and "▾" or "▸", 20) then
        expanded = not expanded
        state.expanded_libraries[library.id] = expanded
        state.libraries_dirty = true
        state.config_dirty = true
      end

      ImGui.SameLine(ctx, 0, 2)

      sidebar_item(
        compact(library.name, 44)
          .. "  "
          .. tostring(library_asset_count(library.id))
          .. "##folder_library_name",
        selected,
        function()
          state.view = "all"
          state.library_filter_id = library.id
          state.root_filter = nil
          state.active_collection_id = nil
          clear_row_selection()
          state.results_dirty = true
          state.config_dirty = true
          state.folder_browser_open = false
        end
      )

      if expanded then
        for _, record in ipairs(library.roots) do
          ImGui.PushID(
            ctx,
            "folder_source_row_" .. record.id
          )

          local source_expanded =
            state.expanded_source_folders[record.id] == true
          local source_selected =
            state.root_filter
            and path_key(state.root_filter)
              == path_key(record.path)
          local tree =
            state.folder_navigation_trees[record.id]
          local has_children =
            tree and #tree.children > 0
          local can_expand =
            has_children
            or not state.folder_navigation_ready

          ImGui.SetCursorPosX(ctx, 18)

          if can_expand then
            if dark_button(
              source_expanded and "▾" or "▸",
              20
            ) then
              source_expanded = not source_expanded
              state.expanded_source_folders[record.id] =
                source_expanded
              state.config_dirty = true
              ensure_folder_navigation_build()
            end
          else
            ImGui.TextDisabled(ctx, "·")
          end

          ImGui.SameLine(ctx, 0, 2)

          local source_name =
            record.alias ~= "" and record.alias
            or basename(record.path)
          local source_count =
            tree and tree.total_count or 0

          sidebar_item(
            (directory_exists(record.path) and "● " or "○ ")
              .. compact(source_name, 40)
              .. (
                state.folder_navigation_ready
                and ("  " .. tostring(source_count))
                or ""
              )
              .. "##folder_source_"
              .. record.id,
            source_selected,
            function()
              activate_folder_path(
                record.path,
                library.id,
                true
              )
            end
          )

          tooltip(record.path)

          if source_expanded then
            if not state.folder_navigation_ready then
              local job = state.folder_navigation_job
              local done = job
                and math.max(0, job.index - 1)
                or 0
              local total = job and job.total or #state.assets
              ImGui.SetCursorPosX(ctx, 42)
              ImGui.TextDisabled(
                ctx,
                string.format(
                  "%s  %d / %d",
                  translate_ui_text("正在建立目录索引…"),
                  done,
                  total
                )
              )
            elseif tree then
              for _, child in ipairs(tree.children) do
                draw_folder_tree_node(
                  child,
                  2,
                  library.id
                )
              end
            end
          end

          ImGui.PopID(ctx)
        end
      end

      ImGui.PopID(ctx)
    end
  end

  ImGui.EndChild(ctx)
  ImGui.PopStyleColor(ctx)
end

function activate_library_path(library_id)
  state.view = "all"
  state.library_filter_id = library_id
  state.root_filter = nil
  state.active_collection_id = nil
  state.status_filter = nil
  clear_row_selection()
  state.results_dirty = true
  state.config_dirty = true
end

function select_path_from_hover_menu(path, library_id)
  activate_folder_path(path, library_id, false)
  ImGui.CloseCurrentPopup(ctx)
end

function draw_folder_cascade_node(node, library_id)
  local has_children = #node.children > 0
  local label =
    compact(node.name, 44)
      .. "  "
      .. tostring(node.total_count)
      .. "##folder_cascade_"
      .. node.key

  if has_children then
    if ImGui.BeginMenu(ctx, label) then
      if ImGui.MenuItem(
        ctx,
        "显示此目录及子目录##folder_cascade_select"
      ) then
        select_path_from_hover_menu(
          node.path,
          library_id
        )
      end

      ImGui.Separator(ctx)

      for _, child in ipairs(node.children) do
        draw_folder_cascade_node(child, library_id)
      end

      ImGui.EndMenu(ctx)
    end
  elseif ImGui.MenuItem(ctx, label) then
    select_path_from_hover_menu(
      node.path,
      library_id
    )
  end
end

function draw_source_cascade_menu(record, library)
  local tree = state.folder_navigation_trees[record.id]
  local source_name =
    record.alias ~= "" and record.alias
    or basename(record.path)
  local count =
    state.folder_navigation_ready
      and tree
      and tree.total_count
      or nil
  local label =
    (directory_exists(record.path) and "● " or "○ ")
      .. compact(source_name, 42)
      .. (count and ("  " .. tostring(count)) or "")
      .. "##folder_cascade_source_"
      .. record.id

  if ImGui.BeginMenu(ctx, label) then
    if ImGui.MenuItem(
      ctx,
      "显示此来源的全部素材##source_cascade_select"
    ) then
      select_path_from_hover_menu(
        record.path,
        library.id
      )
    end

    if not state.folder_navigation_ready then
      ImGui.Separator(ctx)

      local job = state.folder_navigation_job
      local done =
        job and math.max(0, job.index - 1) or 0
      local total = job and job.total or #state.assets

      ImGui.TextDisabled(
        ctx,
        string.format(
          "%s  %d / %d",
          translate_ui_text(
            "目录索引正在后台建立…"
          ),
          done,
          total
        )
      )
    elseif tree and #tree.children > 0 then
      ImGui.Separator(ctx)

      for _, child in ipairs(tree.children) do
        draw_folder_cascade_node(
          child,
          library.id
        )
      end
    end

    ImGui.EndMenu(ctx)
  end
end

function draw_library_cascade_menu(library)
  local label =
    compact(library.name, 40)
      .. "  "
      .. tostring(library_asset_count(library.id))
      .. "##folder_cascade_library_"
      .. library.id

  if ImGui.BeginMenu(ctx, label) then
    if ImGui.MenuItem(
      ctx,
      "显示此逻辑库的全部素材##library_cascade_select"
    ) then
      activate_library_path(library.id)
      ImGui.CloseCurrentPopup(ctx)
    end

    if #library.roots > 0 then
      ImGui.Separator(ctx)

      for _, record in ipairs(library.roots) do
        draw_source_cascade_menu(record, library)
      end
    end

    ImGui.EndMenu(ctx)
  end
end

function draw_folder_hover_popup()
  if not ImGui.BeginPopup(
    ctx,
    "文件夹层级##folder_hover_menu"
  ) then
    state.folder_menu_active = false
    return
  end

  state.folder_menu_active = true
  ensure_folder_navigation_build()

  if ImGui.MenuItem(
    ctx,
    "显示全部音效库##folder_cascade_all"
  ) then
    clear_folder_path(false)
    ImGui.CloseCurrentPopup(ctx)
  end

  if #state.libraries > 0 then
    ImGui.Separator(ctx)

    for _, library in ipairs(state.libraries) do
      draw_library_cascade_menu(library)
    end
  end

  ImGui.EndPopup(ctx)
end

function active_path_condition_label()
  if state.root_filter then
    local suffix =
      state.root_filter:sub(-1) == SEP
        and "*"
        or (SEP .. "*")

    return "Pathname: "
      .. state.root_filter
      .. suffix
  end

  local library =
    state.library_filter_id
      and state.library_by_id[
        state.library_filter_id
      ]
      or nil

  if library then
    return "Library: " .. library.name
  end

  return nil
end

function draw_path_condition_bar()
  local label = active_path_condition_label()

  if not label then
    return
  end

  local available =
    select(1, ImGui.GetContentRegionAvail(ctx))
  local text_width =
    select(1, ImGui.CalcTextSize(ctx, label))
  local clear_size = 22
  local max_button_width =
    math.max(48, available - clear_size - 7)
  local button_width = math.min(
    math.max(80, text_width + 28),
    max_button_width
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Button,
    rgba_with_alpha(COLOR.selected, 0xC0)
  )
  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_ButtonHovered,
    rgba_with_alpha(COLOR.selected, 0xE8)
  )
  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Text,
    COLOR.selected_text
  )

  if ImGui.Button(
    ctx,
    label .. "##active_path_condition",
    button_width,
    clear_size
  ) then
    ensure_folder_navigation_build()
    ImGui.OpenPopup(
      ctx,
      "文件夹层级##folder_hover_menu"
    )
  end

  ImGui.PopStyleColor(ctx, 3)
  ImGui.SameLine(ctx, 0, 3)

  if icon_button(
    "clear_path_condition",
    "close",
    "清除路径条件",
    false,
    clear_size
  ) then
    clear_folder_path(false)
  end
end

function draw_sidebar()
  if dark_button("隐藏导航 <", -1) then
    state.sidebar_visible = false
    state.config_dirty = true
    return
  end

  ImGui.Spacing(ctx)

  if sidebar_section_header(
    "sounds",
    "SOUNDS"
  ) then

  sidebar_item(
    string.format("全部素材  %d", #state.assets),
    state.view == "all"
      and not state.active_collection_id,
    function()
      state.view = "all"
      state.active_collection_id = nil
      state.root_filter = nil
      state.library_filter_id = nil
      state.results_dirty = true
      state.config_dirty = true
    end
  )

  local favorite_count = 0

  for _ in pairs(state.favorites) do
    favorite_count = favorite_count + 1
  end

  sidebar_item(
    string.format("收藏  %d", favorite_count),
    state.view == "favorites"
      and not state.active_collection_id,
    function()
      state.view = "favorites"
      state.active_collection_id = nil
      state.root_filter = nil
      state.library_filter_id = nil
      state.results_dirty = true
      state.config_dirty = true
    end
  )

  sidebar_item(
    "最近插入",
    state.view == "recent"
      and not state.active_collection_id,
    function()
      state.view = "recent"
      state.active_collection_id = nil
      state.root_filter = nil
      state.library_filter_id = nil
      state.sort_mode = "used"
      state.sort_desc = true
      state.results_dirty = true
      state.config_dirty = true
    end
  )

  sidebar_item(
    "试听历史",
    state.view == "previewed"
      and not state.active_collection_id,
    function()
      state.view = "previewed"
      state.active_collection_id = nil
      state.root_filter = nil
      state.library_filter_id = nil
      state.sort_mode = "previewed"
      state.sort_desc = true
      state.results_dirty = true
      state.config_dirty = true
    end
  )

  if state.missing_asset_count > 0 then
    sidebar_item(
      string.format("缺失素材  %d", state.missing_asset_count),
      state.view == "missing"
        and not state.active_collection_id,
      function()
        state.view = "missing"
        state.active_collection_id = nil
        state.root_filter = nil
        state.library_filter_id = nil
        state.results_dirty = true
        state.config_dirty = true
      end
    )
  end

  if state.duplicate_asset_count > 0 then
    sidebar_item(
      string.format("重复候选  %d", state.duplicate_asset_count),
      state.view == "duplicates"
        and not state.active_collection_id,
      function()
        state.view = "duplicates"
        state.active_collection_id = nil
        state.root_filter = nil
        state.library_filter_id = nil
        state.results_dirty = true
        state.config_dirty = true
      end
    )
  end

  if state.duplicate_confirmed_asset_count > 0 then
    sidebar_item(
      string.format("已确认相同  %d", state.duplicate_confirmed_asset_count),
      state.view == "duplicates_confirmed",
      function()
        state.view = "duplicates_confirmed"
        state.active_collection_id = nil
        state.root_filter = nil
        state.library_filter_id = nil
        state.results_dirty = true
        state.config_dirty = true
      end
    )
  end

  if state.duplicate_confirmation_failure_count > 0 then
    sidebar_item(
      string.format("确认读取失败  %d", state.duplicate_confirmation_failure_count),
      state.view == "duplicate_failures",
      function()
        state.view = "duplicate_failures"
        state.active_collection_id = nil
        state.root_filter = nil
        state.library_filter_id = nil
        state.results_dirty = true
        state.config_dirty = true
      end
    )
  end

  local current_usage = project_usage_bucket(
    state.current_project_path,
    false
  )
  if current_usage then
    local usage_count = 0
    for _ in pairs(current_usage.assets or {}) do
      usage_count = usage_count + 1
    end
    if usage_count > 0 then
      sidebar_item(
        string.format("当前工程已用  %d", usage_count),
        state.view == "project_used"
          and not state.active_collection_id,
        function()
          state.view = "project_used"
          state.active_collection_id = nil
          state.root_filter = nil
          state.library_filter_id = nil
          state.results_dirty = true
          state.config_dirty = true
        end
      )
    end
  end

  end

  if sidebar_section_header(
    "libraries",
    "LIBRARIES"
  ) then

  sidebar_item(
    "全部音效库",
    state.root_filter == nil
      and state.library_filter_id == nil,
    function()
      state.view = "all"
      state.root_filter = nil
      state.library_filter_id = nil
      state.active_collection_id = nil
      state.results_dirty = true
    end
  )

  accept_folder_drop_target(nil)

  for index, library in ipairs(state.libraries) do
    local selected =
      state.library_filter_id == library.id
      and state.root_filter == nil
    local expanded =
      state.expanded_libraries[library.id] == true
    local has_roots = #library.roots > 0

    if has_roots then
      ImGui.PushStyleColor(
        ctx,
        ImGui.Col_Button,
        selected and COLOR.selected or 0x00000000
      )
      ImGui.PushStyleColor(
        ctx,
        ImGui.Col_ButtonHovered,
        selected
          and rgba_with_alpha(COLOR.selected, 0xE8)
          or rgba_with_alpha(COLOR.button_hover, 0xD0)
      )
      ImGui.PushStyleColor(
        ctx,
        ImGui.Col_ButtonActive,
        COLOR.accent
      )

      if ImGui.Button(
        ctx,
        (expanded and "▾" or "▸")
          .. "##library_arrow_"
          .. library.id,
        22,
        0
      ) then
        expanded = not expanded
        state.expanded_libraries[library.id] = expanded
        state.libraries_dirty = true
        state.config_dirty = true
      end

      ImGui.PopStyleColor(ctx, 3)
      tooltip("展开或折叠来源")
      ImGui.SameLine(ctx, 0, 0)
    end

    sidebar_item(
      (has_roots and "" or "  ")
        .. compact(library.name, 20)
        .. "  "
        .. tostring(library_asset_count(library.id))
        .. "##library_"
        .. tostring(index),
      selected,
      function()
        if ImGui.IsMouseDoubleClicked(ctx, 0) then
          expanded = not expanded
          state.expanded_libraries[library.id] = expanded
          state.libraries_dirty = true
        end

        state.view = "all"
        state.library_filter_id = library.id
        state.root_filter = nil
        state.active_collection_id = nil
        state.results_dirty = true
        state.config_dirty = true
      end
    )

    tooltip(library_paths_summary(library), false)
    accept_folder_drop_target(library.id)

    if ImGui.BeginPopupContextItem(
      ctx,
      "sidebar_library_context_" .. tostring(index)
    ) then
      if ImGui.MenuItem(ctx, "添加来源路径…") then
        add_root(library.id)
      end

      if ImGui.MenuItem(ctx, "扫描全部来源") then
        start_scan(
          "扫描 " .. library.name,
          roots_for_library(library.id)
        )
      end

      if ImGui.MenuItem(ctx, "重命名") then
        rename_library(library)
      end

      if ImGui.MenuItem(ctx, "展开或折叠来源") then
        state.expanded_libraries[library.id] = not expanded
        state.libraries_dirty = true
      end

      if ImGui.MenuItem(ctx, "从 PsyReaSFX 删除") then
        local answer = reaper.MB(
          "删除逻辑音效库及其所有来源路径？\n\n"
            .. library.name
            .. "\n\n不会删除磁盘中的音频文件。",
          SCRIPT_NAME,
          4
        )

        if answer == 6 then
          remove_library(library.id)
        end
      end

      ImGui.EndPopup(ctx)
    end

    if expanded then
      for root_index, record in ipairs(library.roots) do
        local root_selected = state.root_filter
          and path_key(state.root_filter) == path_key(record.path)
        local online = directory_exists(record.path)
        local root_label = record.alias ~= ""
          and record.alias
          or basename(record.path)

        sidebar_item(
          "    "
            .. (online and "● " or "○ ")
            .. compact(root_label, 18)
            .. "##root_"
            .. record.id,
          root_selected,
          function()
            state.view = "all"
            state.root_filter = record.path
            state.library_filter_id = library.id
            state.active_collection_id = nil
            state.results_dirty = true
            state.config_dirty = true
          end
        )

        tooltip(record.path)
        accept_folder_drop_target(library.id)

        if ImGui.BeginPopupContextItem(
          ctx,
          "sidebar_root_context_" .. record.id
        ) then
          if ImGui.MenuItem(ctx, "扫描此来源") then
            start_scan("扫描 " .. root_label, { record.path })
          end

          if ImGui.MenuItem(ctx, "打开目录") then
            open_folder(record.path)
          end

          ImGui.Separator(ctx)

          if ImGui.MenuItem(ctx, "指定此来源封面…") then
            choose_artwork_for_root(record)
          end

          if ImGui.MenuItem(ctx, "重新自动查找此来源封面") then
            redetect_root_artwork(record)
          end

          if ImGui.MenuItem(ctx, "清除此来源封面") then
            clear_root_artwork(record)
          end

          ImGui.Separator(ctx)

          if ImGui.MenuItem(ctx, "重新定位来源路径…") then
            relink_root(record)
          end

          ImGui.Separator(ctx)

          if ImGui.MenuItem(ctx, "移除来源路径") then
            remove_root(record)
          end

          ImGui.EndPopup(ctx)
        end
      end
    end
  end

  ImGui.Spacing(ctx)

  if dark_button("+ 新建音效库", -1) then
    add_root()
  end

  if dark_button("管理音效库", -1) then
    ImGui.OpenPopup(
      ctx,
      "管理音效库##psyreasfx"
    )
  end

  draw_library_manager_popup()

  end

  if sidebar_section_header(
    "collections",
    "COLLECTIONS"
  ) then

  if #state.collections == 0 then
    ImGui.TextDisabled(ctx, "尚无播放列表或项目素材箱")
  end

  for index, collection in ipairs(state.collections) do
    local selected =
      state.active_collection_id
        == collection.id

    local prefix =
      collection.kind == "project"
      and translate_ui_text("[项目] ")
      or ""

    local collection_name = collection.name

    if state.language == "en" then
      if collection_name == "新播放列表" then
        collection_name = "New playlist"
      elseif collection_name == "当前项目" then
        collection_name = "Current project"
      end
    end

    sidebar_item(
      prefix
        .. compact(collection_name, 20)
        .. "  "
        .. tostring(collection_item_count(collection))
        .. "##collection_"
        .. tostring(index),
      selected,
      function()
        state.view = "all"
        state.active_collection_id =
          collection.id
        state.root_filter = nil
        state.results_dirty = true
        state.config_dirty = true
      end
    )

    if ImGui.BeginPopupContextItem(
      ctx,
      "collection_context_" .. tostring(index)
    ) then
      local assets = selected_assets()

      if #assets > 0
        and ImGui.MenuItem(
          ctx,
          "加入当前所选素材"
        ) then
        add_assets_to_collection(
          collection,
          assets
        )
      end

      if selected and #assets > 0
        and ImGui.MenuItem(
          ctx,
          "从此集合移除所选素材"
        ) then
        remove_assets_from_collection(
          collection,
          assets
        )
      end

      ImGui.Separator(ctx)

      if ImGui.MenuItem(ctx, "重命名") then
        rename_collection(collection)
      end

      if collection.kind == "project" then
        if ImGui.MenuItem(ctx, "绑定到当前 REAPER 工程") then
          bind_project_bin(collection, state.current_project_path)
        end

        if state.current_project_bin_id == collection.id
          and ImGui.MenuItem(ctx, "查看当前工程已用素材") then
          state.active_collection_id = nil
          state.view = "project_used"
          state.root_filter = nil
          state.library_filter_id = nil
          state.results_dirty = true
        end
      end

      if ImGui.MenuItem(ctx, "删除") then
        delete_collection(collection)
      end

      ImGui.EndPopup(ctx)
    end
  end

  if dark_button("+ 播放列表", -1) then
    create_collection("playlist")
  end

  if dark_button("+ 项目素材箱", -1) then
    create_collection("project")
  end

  end

  if sidebar_section_header(
    "saved_searches",
    "SAVED SEARCHES"
  ) then

  if #state.saved_searches == 0 then
    ImGui.TextDisabled(ctx, "尚无保存搜索")
  end

  for index, saved in ipairs(state.saved_searches) do
    sidebar_item(
      compact(saved.name, 24)
        .. "##saved_search_"
        .. tostring(index),
      false,
      function()
        activate_saved_search(saved)
      end
    )

    tooltip(saved.query ~= "" and saved.query or "空搜索")

    if ImGui.BeginPopupContextItem(
      ctx,
      "saved_search_context_" .. tostring(index)
    ) then
      if ImGui.MenuItem(ctx, "载入") then
        activate_saved_search(saved)
      end

      if ImGui.MenuItem(ctx, "用当前条件覆盖") then
        saved.query = state.search
        saved.view = state.view
        saved.root = state.root_filter or ""
        saved.library_id = state.library_filter_id
        saved.sort_mode = state.sort_mode
        saved.sort_desc = state.sort_desc
        saved.status_filter = state.status_filter
        saved.collection_id =
          state.active_collection_id
        state.searches_dirty = true
        set_status("已更新保存搜索：" .. saved.name)
      end

      if ImGui.MenuItem(ctx, "重命名") then
        rename_saved_search(saved)
      end

      if ImGui.MenuItem(ctx, "删除") then
        delete_saved_search(saved)
      end

      ImGui.EndPopup(ctx)
    end
  end

  if dark_button("+ 保存当前搜索", -1) then
    save_current_search()
  end

  end

  if sidebar_section_header(
    "workflow",
    "WORKFLOW"
  ) then

  sidebar_item(
    "全部状态",
    state.status_filter == nil,
    function()
      state.status_filter = nil
      state.results_dirty = true
      state.config_dirty = true
    end
  )

  for _, status in ipairs(
    {
      "candidate",
      "approved",
      "rejected",
    }
  ) do
    local definition =
      WORKFLOW_STATUS[status]

    sidebar_item(
      definition.label
        .. "##status_filter_"
        .. status,
      state.status_filter == status,
      function()
        state.status_filter = status
        state.results_dirty = true
        state.config_dirty = true
      end
    )
  end

  end

  if sidebar_section_header(
    "activity",
    "ACTIVITY"
  ) then

  ImGui.TextWrapped(
    ctx,
    string.format(
      "结果 %d\n已选 %d\n试听 %s",
      #state.results,
      selected_count(),
      state.preview_backend
    )
  )
  end
end


function draw_toolbar()
  if state.focus_search then
    ImGui.SetKeyboardFocusHere(ctx)
    state.focus_search = false
  end

  local toolbar_width =
    select(1, ImGui.GetContentRegionAvail(ctx))

  local compact_toolbar = toolbar_width < 1080
  local control_size = 32

  draw_brand_mark(compact_toolbar)
  ImGui.SameLine(ctx)

  if icon_button(
    "sidebar",
    "panel_left",
    state.sidebar_visible
      and "隐藏导航栏"
      or "显示导航栏",
    state.sidebar_visible,
    control_size
  ) then
    state.sidebar_visible =
      not state.sidebar_visible
    state.config_dirty = true
  end

  ImGui.SameLine(ctx)

  if icon_button(
    "inspector",
    "panel_right",
    state.inspector_visible
      and "隐藏元数据面板"
      or "显示元数据面板",
    state.inspector_visible,
    control_size
  ) then
    state.inspector_visible =
      not state.inspector_visible
    state.config_dirty = true
  end

  ImGui.SameLine(ctx)

  local focus_mode =
    not state.sidebar_visible
    and not state.inspector_visible

  if icon_button(
    "focus",
    "focus",
    focus_mode
      and "退出专注模式"
      or "进入专注模式",
    focus_mode,
    control_size
  ) then
    if focus_mode then
      state.sidebar_visible = true
      state.inspector_visible = true
    else
      state.sidebar_visible = false
      state.inspector_visible = false
    end

    state.config_dirty = true
  end

  ImGui.SameLine(ctx)

  local folder_clicked =
    icon_button(
      "folder_hierarchy",
      "folder_search",
      nil,
      state.folder_menu_active,
      control_size
    )

  if folder_clicked then
    state.folder_menu_active = true
    ensure_folder_navigation_build()
    ImGui.OpenPopup(
      ctx,
      "文件夹层级##folder_hover_menu"
    )
  end

  draw_folder_hover_popup()
  ImGui.SameLine(ctx)

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_FrameBg,
    COLOR.input
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Text,
    COLOR.input_text
  )

  local text_height = ImGui.GetTextLineHeight(ctx)
  local input_padding_y =
    math.max(2, (control_size - text_height) * 0.5)

  ImGui.PushStyleVar(
    ctx,
    ImGui.StyleVar_FramePadding,
    8,
    input_padding_y
  )

  ImGui.SetNextItemWidth(ctx, -228)

  local changed
  changed, state.search =
    ImGui.InputTextWithHint(
      ctx,
      "##search",
      "输入关键词或描述声音…  category:impact  status:candidate  -exclude",
      state.search
    )

  ImGui.PopStyleColor(ctx, 2)
  ImGui.PopStyleVar(ctx)

  if changed then
    state.results_dirty = true
  end

  ImGui.SameLine(ctx)

  if icon_button(
    "clear_search",
    "close",
    "清空搜索",
    state.search ~= "",
    control_size
  ) then
    state.search = ""
    state.results_dirty = true
  end

  ImGui.SameLine(ctx)

  if icon_button(
    "auto_preview",
    "speaker",
    state.auto_preview
      and "关闭自动试听"
      or "开启自动试听",
    state.auto_preview,
    control_size
  ) then
    state.auto_preview = not state.auto_preview
    state.config_dirty = true
  end

  ImGui.SameLine(ctx)

  if icon_button(
    "played_reset",
    "played_reset",
    "清除本次已播放高亮",
    session_played_count() > 0,
    control_size
  ) then
    clear_session_played_highlights()
  end

  ImGui.SameLine(ctx)

  local background_scan_active =
    (state.scan and state.scan.silent)
    or (state.import_session and state.import_session.silent)
  local scan_tooltip = "增量扫描"

  if state.scan then
    scan_tooltip = string.format(
      "后台检查中：%d 个音频 / %d 个目录",
      state.scan.files,
      state.scan.directories
    )
  elseif state.import_session and state.import_session.silent then
    scan_tooltip = string.format(
      "后台建立索引：%d / %d，失败 %d",
      state.import_session.done,
      state.import_session.total,
      state.import_session.failed
    )
  end

  if icon_button(
    "scan",
    "refresh",
    scan_tooltip,
    state.scan ~= nil or background_scan_active,
    control_size,
    background_scan_active
  ) then
    if not state.scan and not state.import_session then
      start_scan("增量扫描")
    end
  end

  ImGui.SameLine(ctx)

  if icon_button(
    "help",
    "help",
    "使用说明与快捷键",
    false,
    control_size
  ) then
    state.help_popup_requested = 1
  end

  ImGui.SameLine(ctx)

  if icon_button(
    "settings",
    "settings",
    "打开设置",
    false,
    control_size
  ) then
    ImGui.OpenPopup(
      ctx,
      "设置##reasfx"
    )
  end

end

function draw_sub_toolbar()
  local labels_zh = {
    name = "名称",
    duration = "时长",
    library = "音效库",
    used = "最近插入",
    previewed = "最近试听",
  }

  local labels_en = {
    name = "Name",
    duration = "Duration",
    library = "Library",
    used = "Recently inserted",
    previewed = "Recently previewed",
  }

  local labels =
    state.language == "en"
      and labels_en
      or labels_zh

  local sort_prefix =
    state.language == "en"
      and "Sort: "
      or "排序："

  local breadcrumb = "Home"

  if state.active_collection_id then
    local collection =
      state.collection_by_id[
        state.active_collection_id
      ]

    if collection then
      breadcrumb =
        breadcrumb
        .. "  /  "
        .. collection.name
    end
  end

  if state.root_filter then
    breadcrumb =
      breadcrumb
      .. "  /  "
      .. basename(state.root_filter)
  elseif state.library_filter_id then
    local library = state.library_by_id[state.library_filter_id]

    if library then
      breadcrumb = breadcrumb .. "  /  " .. library.name
    end
  end

  if state.status_filter then
    breadcrumb =
      breadcrumb
      .. "  /  "
      .. workflow_label(state.status_filter)
  end

  if trim(state.search) ~= "" then
    breadcrumb =
      breadcrumb
      .. "  /  Search"
  end

  if state.active_collection_id then
    if dark_button("← 全部素材", 86) then
      state.active_collection_id = nil
      state.view = "all"
      state.results_dirty = true
      state.config_dirty = true
    end

    ImGui.SameLine(ctx)
  end

  ImGui.TextDisabled(ctx, breadcrumb)

  ImGui.SameLine(ctx)

  ImGui.TextDisabled(
    ctx,
    string.format(
      "　%d 个结果",
      #state.results
    )
  )

  ImGui.SameLine(ctx)

  if dark_button(
    sort_prefix
      .. (
        labels[state.sort_mode]
        or labels.name
      ),
    state.language == "en"
      and 154
      or 118
  ) then
    local next_mode = {
      name = "duration",
      duration = "library",
      library = "used",
      used = "previewed",
      previewed = "name",
    }

    state.sort_mode =
      next_mode[state.sort_mode] or "name"
    state.results_dirty = true
  end

  ImGui.SameLine(ctx)

  if dark_button(
    state.sort_desc and "↓" or "↑",
    30
  ) then
    state.sort_desc = not state.sort_desc
    state.results_dirty = true
  end

  local active_collection =
    state.active_collection_id
    and state.collection_by_id[
      state.active_collection_id
    ]
    or nil

  if active_collection then
    ImGui.SameLine(ctx)

    if dark_button("加入所选", 68) then
      add_assets_to_collection(
        active_collection,
        selected_assets()
      )
    end

    ImGui.SameLine(ctx)

    if dark_button("移除所选", 68) then
      remove_assets_from_collection(
        active_collection,
        selected_assets()
      )
    end
  end

  ImGui.SameLine(ctx)
  ImGui.TextDisabled(
    ctx,
    "右键表头选择字段；拖动分隔线调整列宽；Shift+滚轮横向查看"
  )

  if state.scan and not state.scan.silent then
    ImGui.SameLine(ctx)
    ImGui.TextColored(
      ctx,
      COLOR.warning,
      string.format(
        "扫描 %d 文件 / %d 目录",
        state.scan.files,
        state.scan.directories
      )
    )
  end
end

function draw_import_progress()
  local visible_scan =
    state.scan and not state.scan.silent
  local visible_import =
    state.import_session
    and not state.import_session.silent
  local visible_relink = state.relink_plan_session

  if not visible_scan
    and not visible_import
    and not state.precache_session
    and not visible_relink then
    return
  end

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_ChildBg,
    0x171A20FF
  )

  if ImGui.BeginChild(
    ctx,
    "import_progress",
    -1,
    72,
    ImGui.ChildFlags_Borders
  ) then
    if visible_relink then
      local completed = math.min(
        math.max(0, (visible_relink.index or 1) - 1),
        visible_relink.total or 0
      )
      local total = visible_relink.total or 0
      local fraction = total > 0 and completed / total or 1
      ImGui.Text(ctx, string.format(
        "正在生成来源重定位计划  %d / %d  目标 %d  缺失 %d  冲突 %d",
        completed,
        total,
        #visible_relink.entries,
        visible_relink.missing,
        #visible_relink.conflicts
      ))
      ImGui.ProgressBar(
        ctx,
        fraction,
        -100,
        18,
        string.format("%.1f%%", fraction * 100)
      )
      ImGui.TextDisabled(ctx, compact(
        visible_relink.old_root .. " → " .. visible_relink.new_root,
        80
      ))
    elseif state.precache_session then
      local session = state.precache_session
      local current_progress =
        session.current
        and session.current.progress
        or 0

      local collecting = session.phase == "collect"
      local completed = collecting
        and math.max(0, (session.collect_index or 1) - 1)
        or session.generated + session.cached + session.failed
      local total = collecting
        and (session.source_total or 0) or (session.total or 0)

      local fraction =
        total > 0
        and clamp(
          (completed + current_progress)
            / total,
          0,
          1
        )
        or 0

      local current_name =
        collecting and "正在整理预缓存范围"
        or session.current
        and session.current.asset
        and session.current.asset.name
        or "检查现有缓存"

      ImGui.Text(
        ctx,
        string.format(
          "%s %d 点  %d / %d  新生成 %d  已有 %d  失败 %d",
          collecting and "整理高精度预缓存" or "高精度预缓存",
          session.points,
          completed,
          total,
          session.generated,
          session.cached,
          session.failed
        )
      )

      ImGui.ProgressBar(
        ctx,
        fraction,
        -100,
        18,
        string.format("%.1f%%", fraction * 100)
      )

      ImGui.TextDisabled(
        ctx,
        compact(current_name, 80)
      )
    elseif visible_scan then
      local scan = state.scan
      if scan.phase then
        local label = "整理扫描结果"
        local completed = 0
        local total = 0
        if scan.phase == "finalize_prune" then
          label = "整理索引"
          completed = scan.prune_job and scan.prune_job.processed or 0
          total = scan.finalize_total or 0
        elseif scan.phase == "finalize_pending" then
          label = "整理待分析素材"
          completed = math.max(0, (scan.pending_index or 1) - 1)
          total = #scan.new_assets
        elseif scan.phase == "cancel_collect" then
          label = "收集待清理素材"
          completed = math.max(0, (scan.cancel_index or 1) - 1)
          total = #scan.new_assets
        else
          label = "取消并清理扫描"
          completed = scan.prune_job and scan.prune_job.processed or 0
          total = scan.cancel_total or 0
        end
        completed = math.min(completed, total)
        local fraction = total > 0 and completed / total or 1
        ImGui.Text(ctx, string.format(
          "%s：%s  %d / %d",
          scan.reason,
          label,
          completed,
          total
        ))
        ImGui.ProgressBar(
          ctx,
          fraction,
          -100,
          18,
          string.format("%.1f%%", fraction * 100)
        )
      else
        local animated =
          (reaper.time_precise() * 0.28) % 1
        ImGui.Text(
          ctx,
          string.format(
            "%s：正在扫描文件…  已发现 %d 个音频 / %d 个目录",
            scan.reason,
            scan.files,
            scan.directories
          )
        )
        ImGui.ProgressBar(
          ctx,
          animated,
          -100,
          18,
          "扫描中"
        )
      end
    else
      local session = visible_import
      local current_progress =
        session.current
        and session.current.progress
        or 0

      local fraction =
        session.total > 0
        and clamp(
          (session.done + current_progress)
            / session.total,
          0,
          1
        )
        or 1

      local current_name =
        session.current
        and session.current.asset
        and session.current.asset.name
        or "准备下一项"

      ImGui.Text(
        ctx,
        string.format(
          "%s：分析元数据并建立波形  %d / %d  失败 %d",
          session.label,
          session.done,
          session.total,
          session.failed
        )
      )

      ImGui.ProgressBar(
        ctx,
        fraction,
        -100,
        18,
        string.format("%.1f%%", fraction * 100)
      )

      ImGui.TextDisabled(
        ctx,
        compact(current_name, 80)
      )
    end

    ImGui.SameLine(ctx)

    if dark_button("取消", 72) then
      if visible_relink then
        Jobs.cancel(visible_relink.job_token)
        set_status("正在取消来源重定位计划…")
      elseif state.precache_session then
        state.precache_cancel_requested = true
      elseif visible_scan then
        local scan = state.scan
        Jobs.cancel(scan.job_token)
        set_status("正在取消扫描…")
      else
        state.import_cancel_requested = true
      end
    end
  end

  ImGui.EndChild(ctx)
  ImGui.PopStyleColor(ctx)
end

----------------------------------------------------------------
-- UI: result list
----------------------------------------------------------------

local COLUMN_DEFS = {
  {
    key = "waveform",
    label = "Waveform",
    minimum = 180,
    default = 350,
    flexible = true,
  },
  {
    key = "filename",
    label = "Filename",
    minimum = 170,
    default = 265,
    flexible = true,
  },
  {
    key = "status",
    label = "Status",
    minimum = 76,
    default = 88,
  },
  {
    key = "description",
    label = "Keywords / Description",
    minimum = 160,
    default = 320,
    flexible = true,
  },
  {
    key = "category",
    label = "Category",
    minimum = 110,
    default = 140,
  },
  {
    key = "subcategory",
    label = "SubCategory",
    minimum = 120,
    default = 150,
  },
  {
    key = "catid",
    label = "CatID",
    minimum = 76,
    default = 90,
  },
  {
    key = "artwork",
    label = "Artwork",
    minimum = 42,
    default = 58,
  },
  {
    key = "duration",
    label = "Duration",
    minimum = 76,
    default = 92,
  },
  {
    key = "format",
    label = "Format",
    minimum = 104,
    default = 118,
  },
  {
    key = "channels",
    label = "Channels",
    minimum = 76,
    default = 80,
  },
  {
    key = "sample_rate",
    label = "Sample Rate",
    minimum = 94,
    default = 100,
  },
  {
    key = "bit_depth",
    label = "Bit Depth",
    minimum = 82,
    default = 90,
  },
  {
    key = "library",
    label = "Library",
    minimum = 120,
    default = 180,
    flexible = true,
  },
  {
    key = "path",
    label = "Path",
    minimum = 220,
    default = 360,
    flexible = true,
  },
}

local COLUMN_BY_KEY = {}

for _, definition in ipairs(COLUMN_DEFS) do
  COLUMN_BY_KEY[definition.key] = definition
end

function visible_column_definitions()
  local visible = {}

  for _, definition in ipairs(COLUMN_DEFS) do
    if state.column_visible[definition.key] then
      visible[#visible + 1] = definition
    end
  end

  if #visible == 0 then
    state.column_visible.filename = true
    visible[1] = COLUMN_BY_KEY.filename
  end

  return visible
end

function visible_column_count()
  local count = 0

  for _, definition in ipairs(COLUMN_DEFS) do
    if state.column_visible[definition.key] then
      count = count + 1
    end
  end

  return count
end

function reset_columns_default()
  for key in pairs(state.column_visible) do
    state.column_visible[key] = false
  end

  for _, key in ipairs(
    {
      "waveform",
      "filename",
      "description",
      "artwork",
      "duration",
    }
  ) do
    state.column_visible[key] = true
  end

  state.column_widths.waveform = 335
  state.column_widths.filename = 220
  state.column_widths.description = 320
  state.column_widths.artwork = 52
  state.column_widths.duration = 104

  state.ui_density = "compact"
  state.config_dirty = true
  set_status("已恢复默认字段布局")
end

function column_layout(width)
  width = math.max(width, 1)

  local definitions =
    visible_column_definitions()

  local items = {}
  local total = 0
  local minimum_total = 0
  local flexible_count = 0

  for _, definition in ipairs(definitions) do
    local preferred =
      tonumber(
        state.column_widths[definition.key]
      ) or definition.default

    local item = {
      definition = definition,
      width = math.max(
        definition.minimum,
        preferred
      ),
    }

    items[#items + 1] = item
    total = total + item.width
    minimum_total =
      minimum_total + definition.minimum

    if definition.flexible then
      flexible_count = flexible_count + 1
    end
  end

  if total < width then
    local extra = width - total
    local recipients =
      flexible_count > 0
        and flexible_count
        or #items

    for _, item in ipairs(items) do
      if flexible_count == 0
        or item.definition.flexible then
        item.width =
          item.width + extra / recipients
      end
    end
  end

  local offset = 0
  local by_key = {}

  for _, item in ipairs(items) do
    item.x0 = offset
    offset = offset + item.width
    item.x1 = offset
    by_key[item.definition.key] = item
  end

  if #items > 0 and offset < width then
    items[#items].width =
      items[#items].width + (width - offset)

    items[#items].x1 = width
    offset = width
  end

  return {
    items = items,
    by_key = by_key,
    width = math.max(width, offset),
    viewport_width = width,
  }
end

function draw_column_visibility_popup()
  if not ImGui.BeginPopup(
    ctx,
    "column_visibility_popup"
  ) then
    return
  end

  ImGui.TextDisabled(ctx, "显示字段")
  ImGui.Separator(ctx)

  local count = visible_column_count()

  for _, definition in ipairs(COLUMN_DEFS) do
    local visible =
      state.column_visible[definition.key]

    if ImGui.MenuItem(
      ctx,
      definition.label,
      nil,
      visible
    ) then
      if visible and count <= 1 then
        set_status("至少保留一个列表字段", true)
      else
        state.column_visible[definition.key] =
          not visible
        state.config_dirty = true
      end
    end
  end

  ImGui.Separator(ctx)

  if ImGui.MenuItem(ctx, "重置为默认字段") then
    reset_columns_default()
  end

  if ImGui.MenuItem(ctx, "重置全部列宽") then
    for _, definition in ipairs(COLUMN_DEFS) do
      state.column_widths[definition.key] =
        definition.default
    end

    state.config_dirty = true
  end

  ImGui.EndPopup(ctx)
end

function draw_column_splitters(
  x,
  y,
  layout
)
  local saved_x, saved_y =
    ImGui.GetCursorScreenPos(ctx)

  for index = 1, #layout.items - 1 do
    local left = layout.items[index]
    local right = layout.items[index + 1]
    local splitter_x = x + left.x1
    local hit_width = 8

    ImGui.SetCursorScreenPos(
      ctx,
      splitter_x - hit_width * 0.5,
      y
    )

    ImGui.InvisibleButton(
      ctx,
      "column_splitter_"
        .. left.definition.key
        .. "_"
        .. right.definition.key,
      hit_width,
      HEADER_H
    )

    if ImGui.IsItemHovered(ctx)
      or ImGui.IsItemActive(ctx) then
      ImGui.SetMouseCursor(
        ctx,
        ImGui.MouseCursor_ResizeEW
      )
    end

    if ImGui.IsItemActive(ctx)
      and not state.column_drag then
      state.column_drag = {
        left_key = left.definition.key,
        right_key = right.definition.key,
        start_mouse =
          select(1, ImGui.GetMousePos(ctx)),
        start_left = left.width,
        start_right = right.width,
        left_minimum = left.definition.minimum,
        right_minimum = right.definition.minimum,
      }
    end

    local drag = state.column_drag

    if ImGui.IsItemActive(ctx)
      and drag
      and drag.left_key
        == left.definition.key
      and drag.right_key
        == right.definition.key then
      mark_interaction()

      local mouse_x =
        select(1, ImGui.GetMousePos(ctx))

      local delta =
        mouse_x - drag.start_mouse

      local combined =
        drag.start_left + drag.start_right

      local new_left =
        clamp(
          drag.start_left + delta,
          drag.left_minimum,
          combined - drag.right_minimum
        )

      state.column_widths[drag.left_key] =
        new_left

      state.column_widths[drag.right_key] =
        combined - new_left

      state.config_dirty = true
    end

    if ImGui.IsItemHovered(ctx)
      and ImGui.IsMouseDoubleClicked(ctx, 0) then
      state.column_widths[left.definition.key] =
        left.definition.default
      state.column_widths[right.definition.key] =
        right.definition.default
      state.config_dirty = true
    end
  end

  if state.column_drag
    and ImGui.IsMouseReleased(ctx, 0) then
    state.column_drag = nil
  end

  ImGui.SetCursorScreenPos(
    ctx,
    saved_x,
    saved_y
  )
end

function draw_list_header(
  draw_list,
  x,
  y,
  layout,
  viewport_x0,
  viewport_x1
)
  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + layout.width,
    y + HEADER_H,
    COLOR.header
  )

  for index, item in ipairs(layout.items) do
    local column_x = x + item.x0
    local column_end = x + item.x1

    draw_clipped_text(
      draw_list,
      column_x + 7,
      y + 6,
      COLOR.header_text,
      item.definition.label,
      column_x + 2,
      y,
      column_end - 2,
      y + HEADER_H
    )

    if index > 1 then
      ImGui.DrawList_AddLine(
        draw_list,
        column_x,
        y,
        column_x,
        y + HEADER_H,
        COLOR.grid,
        1
      )
    end
  end

  draw_column_splitters(x, y, layout)

  if ImGui.IsMouseHoveringRect(
    ctx,
    viewport_x0 or x,
    y,
    viewport_x1 or (x + layout.width),
    y + HEADER_H
  ) and ImGui.IsMouseClicked(ctx, 1) then
    ImGui.OpenPopup(
      ctx,
      "column_visibility_popup"
    )
  end

  draw_column_visibility_popup()
end

function row_popup(asset)
  if not ImGui.BeginPopupContextItem(
    ctx,
    "asset_context_" .. fnv1a(path_key(asset.path))
  ) then
    return
  end

  local bulk_assets = selected_assets()
  local bulk =
    is_row_selected(asset) and #bulk_assets > 1

  if bulk then
    ImGui.TextDisabled(
      ctx,
      tostring(#bulk_assets) .. " 个已选素材"
    )
    ImGui.Separator(ctx)
  end

  if ImGui.MenuItem(ctx, "试听", "Space") then
    play_preview(asset, 0, false)
  end

  if ImGui.MenuItem(ctx, "插入当前轨道", "Enter") then
    insert_asset(asset, false, false)
  end

  if ImGui.MenuItem(ctx, "插入新轨道", "Ctrl+Enter") then
    insert_asset(asset, true, false)
  end

  if ImGui.MenuItem(ctx, "按 BWF 时间戳插入") then
    insert_asset(asset, false, true)
  end

  if bulk
    and ImGui.MenuItem(
      ctx,
      "所选素材分轨插入"
    ) then
    insert_selected_stack(0, 1)
  end

  local target_assets =
    bulk and bulk_assets or { asset }

  if ImGui.BeginMenu(ctx, "工作流状态") then
    for _, status in ipairs(
      WORKFLOW_STATUS_ORDER
    ) do
      local definition =
        WORKFLOW_STATUS[status]

      if ImGui.MenuItem(
        ctx,
        definition.label
      ) then
        set_workflow_status(
          target_assets,
          status
        )
      end
    end

    ImGui.EndMenu(ctx)
  end

  if #state.collections > 0
    and ImGui.BeginMenu(ctx, "添加到集合") then

    for _, collection in ipairs(state.collections) do
      local prefix =
        collection.kind == "project"
        and "[项目] "
        or ""

      if ImGui.MenuItem(
        ctx,
        prefix .. collection.name
      ) then
        add_assets_to_collection(
          collection,
          target_assets
        )
      end
    end

    ImGui.EndMenu(ctx)
  end

  local active_collection =
    state.active_collection_id
    and state.collection_by_id[
      state.active_collection_id
    ]
    or nil

  if active_collection
    and ImGui.MenuItem(
      ctx,
      "从当前集合移除"
    ) then
    remove_assets_from_collection(
      active_collection,
      target_assets
    )
  end

  ImGui.Separator(ctx)

  local all_marked = true

  for _, target in ipairs(target_assets) do
    if not target.marked then
      all_marked = false
      break
    end
  end

  local mark_label

  if bulk then
    mark_label =
      all_marked
      and "取消标记全部所选"
      or "标记全部所选"
  else
    mark_label =
      asset.marked
      and "取消标记"
      or "标记"
  end

  if ImGui.MenuItem(
    ctx,
    mark_label,
    "M"
  ) then
    set_assets_marked(
      target_assets,
      not all_marked
    )
  end

  if bulk and ImGui.MenuItem(ctx, "收藏全部所选") then
    for _, selected_item in ipairs(bulk_assets) do
      state.favorites[path_key(selected_item.path)] = true
    end

    state.config_dirty = true
    state.results_dirty = true
    set_status("已收藏所选素材")
  end

  if ImGui.MenuItem(
    ctx,
    state.favorites[path_key(asset.path)]
      and "取消收藏"
      or "收藏",
    "F"
  ) then
    toggle_favorite(asset)
  end

  if ImGui.MenuItem(ctx, "重新读取元数据") then
    asset.indexed = false
    queue_metadata(asset, true)
  end

  if ImGui.MenuItem(ctx, "复制完整路径") then
    ImGui.SetClipboardText(ctx, asset.path)
    set_status("已复制路径")
  end

  if ImGui.MenuItem(ctx, "在资源管理器中显示") then
    reveal_file(asset.path)
  end

  ImGui.EndPopup(ctx)
end

function column_text(asset, key)
  if key == "status" then
    return workflow_label(
      asset.workflow_status or "none"
    )
  elseif key == "description" then
    if asset.description and asset.description ~= "" then
      return asset.description
    elseif asset.keywords and asset.keywords ~= "" then
      return asset.keywords
    end

    return asset.folder or ""
  elseif key == "category" then
    return asset.category or ""
  elseif key == "subcategory" then
    return asset.subcategory or ""
  elseif key == "catid" then
    return asset.catid or ""
  elseif key == "duration" then
    return asset.duration > 0
      and format_duration_clock(asset.duration)
      or "…"
  elseif key == "format" then
    local bit_depth =
      tonumber(asset.bit_depth) or 0

    return string.format(
      "%s  %s  %dch",
      format_rate(asset.sample_rate),
      bit_depth > 0
        and tostring(bit_depth) .. "-bit"
        or "—",
      tonumber(asset.channels) or 0
    )
  elseif key == "channels" then
    return tostring(asset.channels or 0)
  elseif key == "sample_rate" then
    return format_rate(asset.sample_rate)
  elseif key == "bit_depth" then
    local bit_depth =
      tonumber(asset.bit_depth) or 0

    return bit_depth > 0
      and tostring(bit_depth) .. "-bit"
      or "—"
  elseif key == "library" then
    return asset.library or ""
  elseif key == "path" then
    return asset.path or ""
  end

  return ""
end

function draw_result_row(
  asset,
  index,
  width,
  layout
)
  ImGui.SetCursorPosY(
    ctx,
    (index - 1) * ROW_H
  )

  local x, y =
    ImGui.GetCursorScreenPos(ctx)

  ImGui.InvisibleButton(
    ctx,
    "row_" .. tostring(index),
    width,
    ROW_H
  )

  local clicked =
    ImGui.IsItemClicked(ctx, 0)

  local hovered =
    ImGui.IsItemHovered(ctx)

  local active =
    ImGui.IsItemActive(ctx)

  local dragging =
    active
    and ImGui.IsMouseDragging(ctx, 0, 6)

  local selected =
    is_row_selected(asset)

  local asset_key = path_key(asset.path)
  local waveform_state, waveform_color =
    waveform_visual_state(asset, selected)

  local primary_text_color =
    row_text_visual_color(asset, selected)

  local secondary_text_color =
    state.played_text_enabled
      and asset_is_session_played(asset)
      and rgba_with_alpha(
        COLOR.played_text,
        selected and 0xFF or 0xB0
      )
      or selected
        and 0xD9E9FFFF
        or COLOR.dim

  local draw_list =
    ImGui.GetWindowDrawList(ctx)

  local background =
    selected
      and COLOR.selected
      or hovered
        and COLOR.row_hover
        or index % 2 == 0
          and COLOR.row_alt
          or COLOR.row

  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + width,
    y + ROW_H,
    background
  )

  queue_metadata(asset, false)

  local waveform_item =
    layout.by_key.waveform

  local compact_row =
    state.ui_density == "compact"

  local text_height =
    select(
      2,
      ImGui.CalcTextSize(ctx, "Ag")
    ) or 14

  local centered_y =
    y + math.max(
      2,
      (ROW_H - text_height) * 0.5
    )

  for column_index, item in ipairs(layout.items) do
    local key = item.definition.key
    local column_x = x + item.x0
    local column_end = x + item.x1

    if column_index > 1 then
      ImGui.DrawList_AddLine(
        draw_list,
        column_x,
        y,
        column_x,
        y + ROW_H,
        COLOR.grid,
        1
      )
    end

    if key == "waveform" then
      local waveform =
        queue_wave(
          asset,
          state.mini_wave_points,
          false
        )

      local wave_x = column_x + 2
      local wave_y = y + 2
      local wave_width =
        math.max(1, item.width - 4)
      local wave_height = ROW_H - 4

      draw_waveform(
        draw_list,
        waveform,
        wave_x,
        wave_y,
        wave_width,
        wave_height,
        waveform_color
      )

      if waveform_state == "marked" then
        local marker_x = wave_x + wave_width - 8
        local marker_y = wave_y + 7

        ImGui.DrawList_AddCircleFilled(
          draw_list,
          marker_x,
          marker_y,
          3,
          COLOR.waveform_marked,
          12
        )
      end

      if state.preview
        and state.preview_path
        and path_key(state.preview_path)
          == asset_key then
        local percent =
          clamp(
            state.preview_percent or 0,
            0,
            1
          )

        local pointer_x =
          wave_x + wave_width * percent

        ImGui.DrawList_AddLine(
          draw_list,
          pointer_x,
          wave_y,
          pointer_x,
          wave_y + wave_height,
          COLOR.playhead,
          2
        )
      end

      if not waveform and asset.wave_error then
        draw_clipped_text(
          draw_list,
          wave_x + 7,
          centered_y,
          COLOR.error,
          "波形不可用",
          column_x + 2,
          y + 2,
          column_end - 2,
          y + ROW_H - 2
        )
      end
    elseif key == "artwork" then
      local size =
        math.max(
          12,
          math.min(
            ROW_H - 4,
            item.width - 8
          )
        )

      local art_x =
        column_x
          + (item.width - size) * 0.5

      local art_y =
        y + (ROW_H - size) * 0.5

      draw_artwork_cover(
        draw_list,
        asset,
        art_x,
        art_y,
        size,
        size,
        true,
        compact_row and 1 or 3,
        false
      )
    elseif key == "filename" then
      local favorite =
        state.favorites[asset_key]

      local filename_color =
        asset_is_session_played(asset)
          and primary_text_color
          or favorite
            and COLOR.favorite
            or primary_text_color

      if compact_row then
        draw_clipped_text(
          draw_list,
          column_x + 7,
          centered_y,
          filename_color,
          (favorite and "★ " or "")
            .. asset.name,
          column_x + 2,
          y + 2,
          column_end - 2,
          y + ROW_H - 2
        )
      else
        draw_clipped_text(
          draw_list,
          column_x + 7,
          y + 5,
          filename_color,
          (favorite and "★ " or "")
            .. asset.name,
          column_x + 2,
          y + 2,
          column_end - 2,
          y + ROW_H - 2
        )

        local secondary =
          table.concat(
            {
              asset.category or "",
              asset.subcategory or "",
            },
            " · "
          ):gsub("^ · ", "")
            :gsub(" · $", "")

        draw_clipped_text(
          draw_list,
          column_x + 7,
          y + 23,
          secondary_text_color,
          secondary,
          column_x + 2,
          y + 2,
          column_end - 2,
          y + ROW_H - 2
        )
      end
    elseif key == "status" then
      local status_definition =
        WORKFLOW_STATUS[
          asset.workflow_status or "none"
        ] or WORKFLOW_STATUS.none

      draw_clipped_text(
        draw_list,
        column_x + 7,
        centered_y,
        asset_is_session_played(asset)
          and primary_text_color
          or selected
            and COLOR.selected_text
            or status_definition.color,
        status_definition.short,
        column_x + 2,
        y + 2,
        column_end - 2,
        y + ROW_H - 2
      )
    else
      draw_clipped_text(
        draw_list,
        column_x + 7,
        centered_y,
        primary_text_color,
        column_text(asset, key),
        column_x + 2,
        y + 2,
        column_end - 2,
        y + ROW_H - 2
      )
    end
  end

  ImGui.DrawList_AddLine(
    draw_list,
    x,
    y + ROW_H,
    x + width,
    y + ROW_H,
    COLOR.grid,
    1
  )

  if clicked then
    mark_interaction()

    local mods = ImGui.GetKeyMods(ctx)
    local ctrl =
      (mods & ImGui.Mod_Ctrl) ~= 0
    local shift =
      (mods & ImGui.Mod_Shift) ~= 0

    local mouse_x =
      select(1, ImGui.GetMousePos(ctx))

    if waveform_item
      and mouse_x >= x + waveform_item.x0
      and mouse_x <= x + waveform_item.x1
      and not ctrl
      and not shift then
      local percent =
        clamp(
          (mouse_x - (x + waveform_item.x0))
            / math.max(1, waveform_item.width),
          0,
          0.999
        )

      select_result_with_modifiers(
        index,
        false,
        false,
        false
      )

      play_preview(asset, percent, false)
    else
      select_result_with_modifiers(
        index,
        ctrl,
        shift,
        nil
      )
    end
  end

  if dragging and not state.external_drag then
    if not is_row_selected(asset) then
      select_result(index, false)
    end

    begin_external_drag(asset, false)
  end

  if hovered
    and ImGui.IsMouseDoubleClicked(ctx, 0) then
    local mouse_x =
      select(1, ImGui.GetMousePos(ctx))

    if not waveform_item
      or mouse_x < x + waveform_item.x0
      or mouse_x > x + waveform_item.x1 then
      insert_asset(asset, false, false)
    end
  end

  row_popup(asset)
end

function draw_results()
  local width, height =
    ImGui.GetContentRegionAvail(ctx)

  local viewport_width =
    math.max(1, width - 4)

  local layout =
    column_layout(viewport_width)

  local list_width = layout.width

  local header_x, header_y =
    ImGui.GetCursorScreenPos(ctx)

  local draw_list =
    ImGui.GetWindowDrawList(ctx)

  local cursor_y =
    ImGui.GetCursorPosY(ctx)

  ImGui.SetCursorPosY(
    ctx,
    cursor_y + HEADER_H
  )

  local child_visible = ImGui.BeginChild(
    ctx,
    "results_scroll_area",
    width,
    math.max(1, height - HEADER_H),
    0,
    0
  )

  if state.results_scroll_request then
    ImGui.SetScrollX(
      ctx,
      clamp(
        state.results_scroll_request,
        0,
        ImGui.GetScrollMaxX(ctx)
      )
    )
    state.results_scroll_request = nil
  end

  if child_visible then
    state.results_scroll_x = ImGui.GetScrollX(ctx)
    state.results_scroll_max_x = ImGui.GetScrollMaxX(ctx)

    local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
    local child_hovered =
      mouse_x >= header_x
      and mouse_x <= header_x + viewport_width
      and mouse_y >= header_y
      and mouse_y <= header_y + height
    local wheel = ImGui.GetMouseWheel(ctx) or 0
    local mods = ImGui.GetKeyMods(ctx)

    if child_hovered
      and wheel ~= 0
      and (mods & ImGui.Mod_Shift) ~= 0 then
      state.results_scroll_request = clamp(
        state.results_scroll_x - wheel * 160,
        0,
        state.results_scroll_max_x
      )
    end

    if #state.results == 0 then
      ImGui.Spacing(ctx)

      local active_collection =
        state.active_collection_id
        and state.collection_by_id[
          state.active_collection_id
        ]
        or nil

      if active_collection then
        ImGui.TextColored(
          ctx,
          COLOR.text,
          "当前集合为空：" .. active_collection.name
        )

        ImGui.TextDisabled(
          ctx,
          "新建集合不会删除或移动原始音效库。返回全部素材后选择声音，"
            .. "再使用右键菜单或“加入所选”添加到集合。"
        )

        if dark_button("返回全部素材", 112) then
          state.active_collection_id = nil
          state.view = "all"
          state.results_dirty = true
          state.config_dirty = true
        end

        ImGui.SameLine(ctx)

        if dark_button("打开左侧导航", 112) then
          state.sidebar_visible = true
          state.config_dirty = true
        end
      else
        ImGui.TextDisabled(
          ctx,
          "没有结果。添加音效库、扫描或修改搜索词。"
        )
      end
    else
      local scroll_y = ImGui.GetScrollY(ctx)
      local visible_height =
        select(2, ImGui.GetContentRegionAvail(ctx))

      local first =
        math.max(
          1,
          math.floor(scroll_y / ROW_H) + 1
        )

      local last =
        math.min(
          #state.results,
          math.ceil(
            (scroll_y + visible_height) / ROW_H
          ) + 2
        )

      ImGui.Dummy(
        ctx,
        list_width,
        #state.results * ROW_H
      )

      for index = first, last do
        draw_result_row(
          state.results[index],
          index,
          list_width,
          layout
        )
      end

      ImGui.SetCursorPosY(
        ctx,
        #state.results * ROW_H
      )

      ImGui.Dummy(ctx, 0, 0)
    end

    state.results_scroll_x = ImGui.GetScrollX(ctx)
    state.results_scroll_max_x = ImGui.GetScrollMaxX(ctx)
  end

  ImGui.EndChild(ctx)

  -- Windows/macOS 文件管理器拖入文件夹。提示层只在拖动期间出现，
  -- 不占用日常结果列表空间。
  if ImGui.BeginDragDropTarget(ctx) then
    local payload_ok, payload_type = ImGui.GetDragDropPayload(ctx)
    local target_library_id = state.library_filter_id

    if state.root_filter then
      local record = root_record_for_path(state.root_filter)
      target_library_id = record and record.library_id or target_library_id
    end

    if payload_ok and payload_type == "FILES" then
      local target_library = target_library_id
        and state.library_by_id[target_library_id]
        or nil
      local box_w = math.min(460, viewport_width - 40)
      local box_h = 116
      local box_x = header_x + (viewport_width - box_w) * 0.5
      local box_y = header_y + (height - box_h) * 0.5
      local label = target_library
        and ("释放以添加到“" .. target_library.name .. "”")
        or "释放以新建逻辑音效库"

      ImGui.DrawList_AddRectFilled(
        draw_list,
        box_x,
        box_y,
        box_x + box_w,
        box_y + box_h,
        0x151A20F2,
        10
      )
      ImGui.DrawList_AddRect(
        draw_list,
        box_x,
        box_y,
        box_x + box_w,
        box_y + box_h,
        COLOR.accent,
        10,
        0,
        2
      )
      ImGui.DrawList_AddText(
        draw_list,
        box_x + 24,
        box_y + 28,
        COLOR.text,
        "+  " .. translate_ui_text(label)
      )
      ImGui.DrawList_AddText(
        draw_list,
        box_x + 24,
        box_y + 62,
        COLOR.muted,
        translate_ui_text("只建立索引，不移动或修改源文件")
      )
    end

    local folders = collect_folder_payload()
    ImGui.EndDragDropTarget(ctx)

    if folders then
      handle_folder_drop(folders, target_library_id)
    end
  end

  draw_list_header(
    draw_list,
    header_x - (state.results_scroll_x or 0),
    header_y,
    layout,
    header_x,
    header_x + viewport_width
  )

  -- draw_column_splitters() temporarily repositions the cursor so the fixed
  -- header can remain interactive after the scrolling child is rendered.
  -- ReaImGui requires a submitted layout item after SetCursorScreenPos;
  -- without it, the parent module asserts when EndChild() is called.
  ImGui.Dummy(ctx, 0, 0)
end

----------------------------------------------------------------
-- UI: bottom module
----------------------------------------------------------------

function draw_large_wave(asset)
  local width, available_height =
    ImGui.GetContentRegionAvail(ctx)

  local minimum_wave_height =
    available_height < 126 and 28
      or available_height < 168 and 40
      or available_height < 205 and 54
      or 72

  local height =
    clamp(
      available_height
        - bottom_controls_reserve_height(width, asset),
      minimum_wave_height,
      state.multichannel_waveform
        and (asset.channels or 1) > 2
        and 360
        or 280
    )

  local view_span = wave_view_span()
  local large_points

  if view_span < 0.55 then
    large_points = LARGE_WAVE_MAX_POINTS
  elseif width <= 900 then
    large_points = 1024
  elseif width <= 1550 then
    large_points = 2048
  else
    large_points = LARGE_WAVE_MAX_POINTS
  end

  local x, y =
    ImGui.GetCursorScreenPos(ctx)

  ImGui.InvisibleButton(
    ctx,
    "large_wave",
    width,
    height
  )

  local hovered = ImGui.IsItemHovered(ctx)
  local active = ImGui.IsItemActive(ctx)
  local selection_handle_hovered = false
  local draw_list =
    ImGui.GetWindowDrawList(ctx)

  local waveform =
    queue_wave(
      asset,
      large_points,
      true,
      state.multichannel_waveform
    )

  draw_waveform_window(
    draw_list,
    waveform,
    asset,
    x,
    y,
    width,
    height,
    COLOR.waveform,
    state.wave_view_start,
    state.wave_view_end
  )

  draw_wave_time_ruler(
    draw_list,
    asset,
    x,
    y,
    width,
    height
  )

  local saved_regions = asset_regions(asset)

  for index, region in ipairs(saved_regions) do
    local visible_start =
      math.max(region.start, state.wave_view_start)

    local visible_end =
      math.min(region.finish, state.wave_view_end)

    if visible_end > visible_start then
      local start_x =
        x + width * wave_view_percent(visible_start)

      local end_x =
        x + width * wave_view_percent(visible_end)

      local active_region =
        index == state.active_region_index

      ImGui.DrawList_AddRectFilled(
        draw_list,
        start_x,
        y + 18,
        end_x,
        y + height,
        rgba_with_alpha(
          COLOR.region,
          active_region and 0x40 or 0x20
        )
      )

      ImGui.DrawList_AddLine(
        draw_list,
        start_x,
        y + 18,
        end_x,
        y + 18,
        COLOR.region,
        active_region and 2 or 1
      )
    end
  end

  if has_selection() then
    local visible_start = math.max(
      state.region_start,
      state.wave_view_start
    )
    local visible_end = math.min(
      state.region_end,
      state.wave_view_end
    )

    if visible_end > visible_start then
      local start_x =
        x + width * wave_view_percent(visible_start)
      local end_x =
        x + width * wave_view_percent(visible_end)

      ImGui.DrawList_AddRectFilled(
        draw_list,
        start_x,
        y,
        end_x,
        y + height,
        COLOR.selection
      )

      ImGui.DrawList_AddLine(
        draw_list,
        start_x,
        y,
        start_x,
        y + height,
        COLOR.border,
        2
      )

      ImGui.DrawList_AddLine(
        draw_list,
        end_x,
        y,
        end_x,
        y + height,
        COLOR.border,
        2
      )
    end
  end


  if has_selection() then
    local visible_start =
      math.max(
        state.region_start,
        state.wave_view_start
      )

    local visible_end =
      math.min(
        state.region_end,
        state.wave_view_end
      )

    if visible_end > visible_start then
      local start_x =
        x + width * wave_view_percent(visible_start)

      local end_x =
        x + width * wave_view_percent(visible_end)

      local handle_width =
        clamp(end_x - start_x - 12, 96, 146)

      local handle_height = 24
      local handle_x =
        clamp(
          (start_x + end_x - handle_width) * 0.5,
          x + 6,
          x + width - handle_width - 6
        )

      local handle_y = y + 22
      local mouse_x, mouse_y =
        ImGui.GetMousePos(ctx)

      selection_handle_hovered =
        mouse_x >= handle_x
        and mouse_x <= handle_x + handle_width
        and mouse_y >= handle_y
        and mouse_y <= handle_y + handle_height

      ImGui.DrawList_AddRectFilled(
        draw_list,
        handle_x,
        handle_y,
        handle_x + handle_width,
        handle_y + handle_height,
        selection_handle_hovered
          and COLOR.button_hover
          or COLOR.panel_alt,
        6
      )

      ImGui.DrawList_AddRect(
        draw_list,
        handle_x,
        handle_y,
        handle_x + handle_width,
        handle_y + handle_height,
        COLOR.border,
        6,
        0,
        selection_handle_hovered and 2 or 1
      )

      ImGui.DrawList_AddLine(
        draw_list,
        handle_x + 9,
        handle_y + 12,
        handle_x + 18,
        handle_y + 12,
        COLOR.header_text,
        2
      )

      ImGui.DrawList_AddLine(
        draw_list,
        handle_x + 14,
        handle_y + 7,
        handle_x + 19,
        handle_y + 12,
        COLOR.header_text,
        2
      )

      ImGui.DrawList_AddLine(
        draw_list,
        handle_x + 14,
        handle_y + 17,
        handle_x + 19,
        handle_y + 12,
        COLOR.header_text,
        2
      )

      ImGui.DrawList_AddText(
        draw_list,
        handle_x + 25,
        handle_y + 5,
        COLOR.header_text,
        "拖出选区"
      )

      if selection_handle_hovered
        and ImGui.IsMouseClicked(ctx, 0) then
        state.selection_drag_handle_pressed = true
        state.wave_drag_start = nil
        mark_interaction()
      end
    end
  end

  if state.selection_drag_handle_pressed
    and ImGui.IsMouseDragging(ctx, 0, 4)
    and not state.external_drag then
    begin_external_drag(asset, true)
  end

  if not ImGui.IsMouseDown(ctx, 0) then
    state.selection_drag_handle_pressed = false
  end

  if state.preview
    and state.preview_path
    and path_key(state.preview_path)
      == path_key(asset.path)
    and state.preview_length > 0
    and state.preview_percent >= state.wave_view_start
    and state.preview_percent <= state.wave_view_end then

    local view_percent =
      wave_view_percent(state.preview_percent)

    ImGui.DrawList_AddLine(
      draw_list,
      x + width * view_percent,
      y,
      x + width * view_percent,
      y + height,
      COLOR.playhead,
      2
    )
  end

  if hovered then
    local mouse_x =
      select(1, ImGui.GetMousePos(ctx))
    local local_percent =
      clamp((mouse_x - x) / width, 0, 1)
    local wheel = ImGui.GetMouseWheel(ctx)
    local mods = ImGui.GetKeyMods(ctx)
    local shift =
      (mods & ImGui.Mod_Shift) ~= 0

    if wheel ~= 0 then
      mark_interaction()

      if shift then
        pan_wave_view(
          -wheel * wave_view_span() * 0.10
        )
      else
        zoom_wave_view(local_percent, wheel)
      end
    end

    if ImGui.IsMouseDoubleClicked(ctx, 0) then
      reset_wave_view()
      state.wave_drag_start = nil
    end

    if state.wave_scrub_enabled
      and ImGui.IsMouseDown(ctx, 1) then
      local now = reaper.time_precise()

      if now - state.wave_scrub_last_at >= 0.09 then
        state.wave_scrub_last_at = now
        play_preview(
          asset,
          wave_source_percent(local_percent),
          false
        )
      end
    end
  end

  if hovered
    and ImGui.IsMouseDragging(ctx, 2) then
    local mouse_x =
      select(1, ImGui.GetMousePos(ctx))

    if state.wave_pan_last_x then
      local delta =
        -(mouse_x - state.wave_pan_last_x)
        / math.max(width, 1)
        * wave_view_span()

      pan_wave_view(delta)
    end

    state.wave_pan_last_x = mouse_x
    mark_interaction()
  elseif not ImGui.IsMouseDown(ctx, 2) then
    state.wave_pan_last_x = nil
  end

  if hovered
    and not selection_handle_hovered
    and not state.selection_drag_handle_pressed
    and ImGui.IsMouseClicked(ctx, 0)
    and not ImGui.IsMouseDoubleClicked(ctx, 0) then

    mark_interaction()

    local mods = ImGui.GetKeyMods(ctx)
    local alt =
      (mods & ImGui.Mod_Alt) ~= 0

    if alt then
      state.wave_drag_start = nil
    else
      local mouse_x =
        select(1, ImGui.GetMousePos(ctx))
      local percent = wave_source_percent(
        clamp((mouse_x - x) / width, 0, 1)
      )

      state.wave_drag_start = percent
      state.region_start = percent
      state.region_end = percent
    end
  end

  if active
    and not state.selection_drag_handle_pressed
    and ImGui.IsMouseDragging(ctx, 0) then

    mark_interaction()

    local mods = ImGui.GetKeyMods(ctx)
    local alt =
      (mods & ImGui.Mod_Alt) ~= 0

    if alt then
      if not state.external_drag then
        begin_external_drag(asset, true)
      end

      state.wave_drag_start = nil
    else
      local mouse_x =
        select(1, ImGui.GetMousePos(ctx))
      local percent = wave_source_percent(
        clamp((mouse_x - x) / width, 0, 1)
      )

      state.region_start =
        math.min(
          state.wave_drag_start or percent,
          percent
        )

      state.region_end =
        math.max(
          state.wave_drag_start or percent,
          percent
        )
    end
  end

  if state.wave_drag_start
    and not state.external_drag
    and ImGui.IsMouseReleased(ctx, 0) then

    local clicked_percent =
      state.wave_drag_start

    if state.region_end - state.region_start
      < 0.004 then

      state.region_start = 0
      state.region_end = 1
      play_preview(
        asset,
        clicked_percent,
        false
      )
    else
      if state.loop_selection then
        state.loop = true
        update_preview_parameters()
      end

      play_preview(asset, nil, true)
    end

    state.wave_drag_start = nil
  end
end

function draw_preview_presets_popup()
  if not ImGui.BeginPopup(
    ctx,
    "试听预设##preview_presets"
  ) then
    return
  end

  ImGui.Text(ctx, "音高预设")

  for index, value in ipairs(
    {
      -12,
      -6,
      -3,
      0,
      3,
      6,
      12,
    }
  ) do
    if dark_button(
      string.format("%+d", value),
      46
    ) then
      state.pitch = value
      update_preview_parameters()
    end

    if index < 7 then
      ImGui.SameLine(ctx)
    end
  end

  ImGui.Separator(ctx)
  ImGui.Text(ctx, "速度预设")

  for index, value in ipairs(
    {
      0.50,
      0.75,
      1.00,
      1.25,
      1.50,
      2.00,
    }
  ) do
    if dark_button(
      string.format("%.2fx", value),
      56
    ) then
      state.rate = value
      update_preview_parameters()
    end

    if index < 6 then
      ImGui.SameLine(ctx)
    end
  end

  ImGui.EndPopup(ctx)
end

function draw_inline_channel_selector(asset, button_size)
  local selected, channel_count =
    ensure_preview_channel_selection(asset)

  if channel_count <= 2
    or not state.preview_channel_strip_expanded then
    return
  end

  button_size = button_size or UI_METRIC.icon_button
  local available_width =
    select(1, ImGui.GetContentRegionAvail(ctx))
  local channel_button_width =
    clamp(
      (
        available_width
          - 48
          - 72
          - 58
          - (channel_count + 2) * 5
      ) / channel_count,
      34,
      51
    )

  local start_x, start_y =
    ImGui.GetCursorScreenPos(ctx)
  local mods = ImGui.GetKeyMods(ctx)
  local ctrl = (mods & ImGui.Mod_Ctrl) ~= 0
  local shift = (mods & ImGui.Mod_Shift) ~= 0
  local selected_total =
    selected_preview_channel_count(asset)

  ImGui.TextDisabled(
    ctx,
    translate_ui_text("声道条")
  )
  ImGui.SameLine(ctx, 0, 9)

  local all_selected = selected_total == channel_count

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Button,
    all_selected
      and rgba_with_alpha(COLOR.accent, 0x48)
      or rgba_with_alpha(COLOR.button, 0x74)
  )
  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_ButtonHovered,
    all_selected
      and rgba_with_alpha(COLOR.accent, 0x58)
      or rgba_with_alpha(COLOR.accent, 0x20)
  )

  if ImGui.Button(
    ctx,
    translate_ui_text("全部声道")
      .. "##inline_channel_all",
    72,
    button_size
  ) then
    select_all_preview_channels(asset)
  end

  ImGui.PopStyleColor(ctx, 2)

  for channel = 1, channel_count do
    ImGui.SameLine(ctx, 0, 5)

    local is_selected = selected[channel] == true

    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_Button,
      is_selected
        and rgba_with_alpha(COLOR.accent, 0x40)
        or rgba_with_alpha(COLOR.button, 0x74)
    )
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_ButtonHovered,
      rgba_with_alpha(COLOR.accent, 0x56)
    )

    local button_label =
      channel_button_width < 42
        and tostring(channel)
        or preview_channel_label(
          channel,
          channel_count
        )

    local clicked =
      ImGui.Button(
        ctx,
        button_label
          .. "##inline_preview_channel_"
          .. tostring(channel),
        channel_button_width,
        button_size
      )

    local hovered = ImGui.IsItemHovered(ctx)

    ImGui.PopStyleColor(ctx, 2)

    if clicked then
      apply_preview_channel_selection(
        asset,
        channel,
        ctrl,
        shift,
        false
      )
    elseif hovered
      and ImGui.IsMouseClicked(ctx, 1) then
      apply_preview_channel_selection(
        asset,
        channel,
        false,
        false,
        true
      )
      set_status(
        preview_channel_label(
          channel,
          channel_count
        )
          .. " · "
          .. translate_ui_text(
            "已聚焦声道波形；音频仍遵循 REAPER 多声道设备路由"
          )
      )
    end

    if hovered then
      tooltip(
        translate_ui_text(
          "右键聚焦此声道波形"
        )
      )
    end
  end

  ImGui.SameLine(ctx, 0, 9)
  ImGui.TextDisabled(
    ctx,
    string.format(
      "%d / %d",
      selected_preview_channel_count(asset),
      channel_count
    )
  )

  local mouse_x, mouse_y = ImGui.GetMousePos(ctx)
  local rail_hovered =
    mouse_x >= start_x
      and mouse_x <= start_x + available_width
      and mouse_y >= start_y
      and mouse_y <= start_y + button_size + 4

  if rail_hovered
    and ctrl
    and ImGui.IsKeyPressed(
      ctx,
      ImGui.Key_A,
      false
    ) then
    select_all_preview_channels(asset)
    state.keyboard_consumed = true
  end
end

function draw_regions_popup(asset)
  if not ImGui.BeginPopup(
    ctx,
    "Region 列表##saved_regions"
  ) then
    return
  end

  local regions = asset_regions(asset)

  if #regions == 0 then
    ImGui.TextDisabled(ctx, "没有保存的 Region")
  end

  local delete_index = nil

  for index, region in ipairs(regions) do
    ImGui.PushID(ctx, index)

    local source_label =
      region.source == "transient"
      and "[T] "
      or "[M] "

    if ImGui.Selectable(
      ctx,
      source_label
        .. region.name
        .. string.format(
          "  %.3f–%.3f s",
          region.start * (asset.duration or 0),
          region.finish * (asset.duration or 0)
        ),
      index == state.active_region_index
    ) then
      activate_saved_region(asset, index, true)
    end

    if ImGui.BeginPopupContextItem(
      ctx,
      "region_context"
    ) then
      if ImGui.MenuItem(ctx, "删除 Region") then
        delete_index = index
      end

      ImGui.EndPopup(ctx)
    end

    ImGui.PopID(ctx)
  end

  if delete_index then
    delete_saved_region(asset, delete_index)
  end

  ImGui.Separator(ctx)

  if ImGui.MenuItem(ctx, "保存当前选区为 Region") then
    save_current_selection_as_region(asset)
  end

  if ImGui.MenuItem(ctx, "瞬态检测设置…") then
    open_transient_detection_popup(asset)
  end

  if ImGui.MenuItem(ctx, "撤销上次检测") then
    undo_last_transient_detection(asset)
  end

  if ImGui.MenuItem(ctx, "清除全部瞬态建议") then
    clear_all_transient_suggestions(asset)
  end

  ImGui.EndPopup(ctx)
end


local TRANSIENT_POPUP_ID =
  "瞬态检测设置##transient_detection"

function draw_transient_detection_popup()
  if state.transient_popup_requested > 0 then
    state.transient_popup_requested =
      state.transient_popup_requested - 1

    if state.transient_popup_requested == 0 then
      ImGui.OpenPopup(ctx, TRANSIENT_POPUP_ID)
    end
  end

  ImGui.SetNextWindowSize(
    ctx,
    520,
    0,
    ImGui.Cond_Appearing
  )

  if not ImGui.BeginPopupModal(
    ctx,
    TRANSIENT_POPUP_ID,
    true,
    ImGui.WindowFlags_AlwaysAutoResize
  ) then
    return
  end

  local asset =
    state.transient_popup_asset_path
    and state.by_path[
      path_key(state.transient_popup_asset_path)
    ]
    or selected_asset()

  ImGui.TextColored(
    ctx,
    COLOR.selected_text,
    asset and asset.name or "瞬态检测"
  )

  ImGui.Separator(ctx)

  local threshold_db =
    20 * math.log(
      math.max(
        state.transient_threshold,
        0.000001
      ),
      10
    )

  ImGui.SetNextItemWidth(ctx, 300)
  local changed
  changed, threshold_db =
    ImGui.SliderDouble(
      ctx,
      "阈值",
      threshold_db,
      -60,
      -1,
      "%.1f dBFS"
    )

  if changed then
    state.transient_threshold =
      10 ^ (threshold_db / 20)
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 300)
  changed, state.transient_smoothing_ms =
    ImGui.SliderDouble(
      ctx,
      "平滑时间",
      state.transient_smoothing_ms,
      0,
      80,
      "%.0f ms"
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 300)
  changed, state.transient_min_gap_ms =
    ImGui.SliderDouble(
      ctx,
      "最小间隔",
      state.transient_min_gap_ms,
      20,
      2000,
      "%.0f ms"
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 300)
  changed, state.transient_pre_ms =
    ImGui.SliderDouble(
      ctx,
      "Region 前置",
      state.transient_pre_ms,
      0,
      1000,
      "%.0f ms"
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 300)
  changed, state.transient_post_ms =
    ImGui.SliderDouble(
      ctx,
      "Region 后置",
      state.transient_post_ms,
      20,
      5000,
      "%.0f ms"
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 300)
  changed, state.transient_max_regions =
    ImGui.SliderDouble(
      ctx,
      "最大 Region 数",
      state.transient_max_regions,
      1,
      256,
      "%.0f"
    )

  if changed then
    state.transient_max_regions =
      math.floor(state.transient_max_regions + 0.5)
    state.config_dirty = true
  end

  changed, state.transient_replace_existing =
    ImGui.Checkbox(
      ctx,
      "替换已有瞬态建议",
      state.transient_replace_existing
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.TextDisabled(
    ctx,
    "阈值越低越敏感；平滑可抑制细碎尖峰；手动 Region 不会被替换。"
  )

  ImGui.Separator(ctx)

  if dark_button("开始检测", 110) and asset then
    request_transient_detection(asset)
    ImGui.CloseCurrentPopup(ctx)
  end

  ImGui.SameLine(ctx)

  if dark_button("取消待检测", 110) then
    cancel_pending_transient_detection()
  end

  ImGui.SameLine(ctx)

  if dark_button("撤销上次检测", 120) and asset then
    undo_last_transient_detection(asset)
  end

  ImGui.SameLine(ctx)

  if dark_button("清除全部瞬态建议", 150) and asset then
    clear_all_transient_suggestions(asset)
  end

  ImGui.Spacing(ctx)

  if dark_button("关闭", 90) then
    ImGui.CloseCurrentPopup(ctx)
  end

  ImGui.EndPopup(ctx)
end

function draw_more_actions_popup(asset)
  if not ImGui.BeginPopup(
    ctx,
    "更多操作##preview_more_actions"
  ) then
    return
  end

  if ImGui.MenuItem(ctx, "按 BWF 时间戳插入") then
    insert_asset(asset, false, true)
  end

  if ImGui.MenuItem(ctx, "在资源管理器中显示") then
    reveal_file(asset.path)
  end

  if ImGui.MenuItem(ctx, "重置波形缩放") then
    reset_wave_view()
  end

  if ImGui.MenuItem(ctx, "预览参数预设") then
    ImGui.OpenPopup(ctx, "试听预设##preview_presets")
  end

  ImGui.Separator(ctx)

  if ImGui.MenuItem(
    ctx,
    "保留音高",
    nil,
    state.preserve_pitch
  ) then
    state.preserve_pitch = not state.preserve_pitch
    update_preview_parameters()
  end

  if ImGui.MenuItem(
    ctx,
    "自动循环选区",
    nil,
    state.loop_selection
  ) then
    state.loop_selection = not state.loop_selection
    state.config_dirty = true
  end

  if ImGui.MenuItem(
    ctx,
    "估算响度匹配",
    nil,
    state.loudness_match
  ) then
    state.loudness_match = not state.loudness_match
    state.config_dirty = true
    update_preview_parameters()
  end

  if ImGui.MenuItem(
    ctx,
    "循环试听",
    nil,
    state.loop
  ) then
    state.loop = not state.loop
    update_preview_parameters()
  end

  if ImGui.MenuItem(
    ctx,
    "反向试听",
    nil,
    state.reverse
  ) then
    state.reverse = not state.reverse

    if state.preview then
      play_preview(asset, nil, has_selection())
    end
  end

  ImGui.Separator(ctx)

  if ImGui.MenuItem(ctx, "保存当前选区为 Region") then
    save_current_selection_as_region(asset)
  end

  if ImGui.MenuItem(ctx, "瞬态检测设置…") then
    open_transient_detection_popup(asset)
  end

  if ImGui.MenuItem(ctx, "撤销上次检测") then
    undo_last_transient_detection(asset)
  end

  if ImGui.MenuItem(ctx, "清除全部瞬态建议") then
    clear_all_transient_suggestions(asset)
  end

  ImGui.Separator(ctx)

  if ImGui.MenuItem(ctx, "重新分析当前素材响度") then
    request_loudness_analysis(asset, true)
  end

  ImGui.EndPopup(ctx)
end

function draw_action_strip(asset, minimal, button_size)
  button_size = button_size or UI_METRIC.icon_button
  local button_gap = math.max(3, math.floor(button_size * 0.18))

  local _, _, drag_active =
    icon_button(
      "drag_to_reaper",
      "drag",
      "拖拽到 REAPER 编排区",
      state.external_drag ~= nil,
      button_size
    )

  if drag_active
    and ImGui.IsMouseDragging(ctx, 0, 5)
    and not state.external_drag then
    begin_external_drag(asset, true)
  end

  ImGui.SameLine(ctx, 0, button_gap)

  if icon_button(
    "play_stop",
    state.preview and "stop" or "play",
    "播放或停止",
    state.preview ~= nil,
    button_size
  ) then
    if state.preview then
      request_preview_stop()
    else
      play_preview(asset, nil, true)
    end
  end

  ImGui.SameLine(ctx, 0, button_gap)

  if icon_button(
    "insert_current",
    "insert",
    "插入当前轨道",
    false,
    button_size
  ) then
    insert_asset(asset, false, false)
  end

  ImGui.SameLine(ctx, 0, button_gap)

  if icon_button(
    "transfer_export",
    "transfer",
    "打开 Transfer 面板",
    state.transfer_running,
    button_size
  ) then
    state.transfer_popup_requested = 2
  end

  if not minimal then
    ImGui.SameLine(ctx, 0, button_gap)

    if icon_button(
      "insert_new_track",
      "new_track",
      "插入新轨道",
      false,
      button_size
    ) then
      insert_asset(asset, true, false)
    end

    ImGui.SameLine(ctx, 0, button_gap)
    toolbar_separator(button_size)
    ImGui.SameLine(ctx, 0, button_gap)

    if icon_button(
      "favorite",
      "star",
      "收藏或取消收藏",
      state.favorites[path_key(asset.path)] == true,
      button_size
    ) then
      toggle_favorite(asset)
    end

    ImGui.SameLine(ctx, 0, button_gap)

    if icon_button(
      "clear_selection",
      "clear_selection",
      "清除选区",
      has_selection(),
      button_size
    ) then
      state.region_start = 0
      state.region_end = 1
      state.active_region_index = 0
    end

    ImGui.SameLine(ctx, 0, button_gap)

    if icon_button(
      "regions",
      "regions",
      "Region 列表",
      #asset_regions(asset) > 0,
      button_size
    ) then
      ImGui.OpenPopup(ctx, "Region 列表##saved_regions")
    end

  end

  ImGui.SameLine(ctx, 0, button_gap)

  if icon_button(
    "more_actions",
    "more",
    "更多操作",
    false,
    button_size
  ) then
    ImGui.OpenPopup(
      ctx,
      "更多操作##preview_more_actions"
    )
  end

  draw_more_actions_popup(asset)
  draw_preview_presets_popup()
  draw_regions_popup(asset)
end

function draw_preview_toggle_icons(asset, button_size)
  button_size = button_size or UI_METRIC.icon_button
  local button_gap = math.max(3, math.floor(button_size * 0.18))

  if icon_button(
    "preserve_pitch",
    "clock",
    "保留音高",
    state.preserve_pitch,
    button_size
  ) then
    state.preserve_pitch = not state.preserve_pitch
    update_preview_parameters()
  end

  ImGui.SameLine(ctx, 0, button_gap)

  if icon_button(
    "loop_selection",
    "loop",
    "自动循环选区",
    state.loop_selection,
    button_size
  ) then
    state.loop_selection = not state.loop_selection
    state.config_dirty = true
  end

  ImGui.SameLine(ctx, 0, button_gap)

  if icon_button(
    "loudness_match",
    "loudness",
    "估算响度匹配",
    state.loudness_match,
    button_size
  ) then
    state.loudness_match = not state.loudness_match
    state.config_dirty = true
    update_preview_parameters()
  end

  ImGui.SameLine(ctx, 0, button_gap)

  local channel_count =
    preview_asset_channel_count(asset)
  local channel_icon =
    channel_count > 2
      and "channel_multi"
      or state.preview_channel_mode == "left"
        and "channel_left"
        or state.preview_channel_mode == "right"
          and "channel_right"
          or state.preview_channel_mode == "mono"
            and "channel_mono"
            or "channel_stereo"
  local channel_tooltip =
    channel_count > 2
      and "左键展开或收起声道条；右键恢复全部声道"
      or "左键切换监听模式；右键恢复立体声"
  local channel_clicked, channel_hovered =
    icon_button(
    "channel_mode",
    channel_icon,
    channel_tooltip,
    state.preview_channel_mode ~= "original",
    button_size
  )

  if channel_clicked then
    if channel_count > 2 then
      state.preview_channel_strip_expanded =
        not state.preview_channel_strip_expanded
    else
      cycle_preview_channel_mode(asset)
    end
  end

  if channel_hovered
    and ImGui.IsMouseClicked(ctx, 1) then
    if channel_count > 2 then
      select_all_preview_channels(asset)
    else
      state.preview_channel_mode = "original"
      state.config_dirty = true

      if state.preview then
        update_preview_parameters()
      end
    end
  end

  ImGui.SameLine(ctx, 0, button_gap)

  if icon_button(
    "loop_preview",
    "loop",
    "循环试听",
    state.loop,
    button_size
  ) then
    state.loop = not state.loop
    update_preview_parameters()
  end

  ImGui.SameLine(ctx, 0, button_gap)

  if icon_button(
    "reverse_preview",
    "reverse",
    "反向试听",
    state.reverse,
    button_size
  ) then
    state.reverse = not state.reverse

    if state.preview then
      play_preview(asset, nil, has_selection())
    end
  end

end

function draw_preview_controls(asset, available_width, hide_toggles, force_compact)
  local compact = force_compact == true

  local classic = false

  local toggle_width =
    UI_METRIC.icon_button * 6
      + UI_METRIC.icon_gap * 5

  local card_gap = compact and 5 or 7
  local card_space =
    math.max(
      UI_METRIC.parameter_min_w * 3,
      available_width - toggle_width - 18
    )

  local card_width =
    clamp(
      (card_space - card_gap * 2) / 3,
      compact and 96 or UI_METRIC.parameter_min_w,
      classic and 156 or UI_METRIC.parameter_max_w
    )

  if classic then
    card_width =
      clamp(
        card_width + 12,
        120,
        160
      )
  end

  local new_pitch, pitch_changed =
    draw_parameter_card(
      "pitch",
      "Pitch",
      state.pitch,
      -24,
      24,
      0,
      "%+.1f st",
      card_width,
      UI_METRIC.parameter_h
    )

  if pitch_changed then
    state.pitch = new_pitch
    update_preview_parameters()
  end

  ImGui.SameLine(ctx, 0, card_gap)

  local new_rate, rate_changed =
    draw_parameter_card(
      "rate",
      "Rate",
      state.rate,
      0.25,
      4,
      1,
      "%.2fx",
      card_width,
      UI_METRIC.parameter_h
    )

  if rate_changed then
    state.rate = new_rate
    update_preview_parameters()
  end

  ImGui.SameLine(ctx, 0, card_gap)

  local new_gain, gain_changed =
    draw_parameter_card(
      "gain",
      "Gain",
      state.gain_db,
      -36,
      18,
      0,
      "%+.1f dB",
      card_width,
      UI_METRIC.parameter_h
    )

  if gain_changed then
    state.gain_db = new_gain
    update_preview_parameters()
  end

  local used_width =
    card_width * 3 + card_gap * 2

  if not hide_toggles then
    if available_width
        - used_width
        >= toggle_width + 12 then
      ImGui.SameLine(ctx, 0, 12)
      draw_preview_toggle_icons(asset)
    else
      ImGui.Spacing(ctx)
      draw_preview_toggle_icons(asset)
    end
  end
end

function preview_context_summary(asset)
  local selection_text = translate_ui_text("完整文件")

  if has_selection() and asset.duration > 0 then
    local start_sec = asset.duration * state.region_start
    local end_sec = asset.duration * state.region_end

    selection_text = string.format(
      "%.3f–%.3f s",
      start_sec,
      end_sec
    )
  end

  local channel_count =
    preview_asset_channel_count(asset)
  local channel_text

  if channel_count > 2
    and state.preview_channel_mode == "custom" then
    local selected =
      ensure_preview_channel_selection(asset)
    local labels = {}

    for channel = 1, channel_count do
      if selected[channel] then
        labels[#labels + 1] =
          preview_channel_label(
            channel,
            channel_count
          )
      end
    end

    channel_text = table.concat(labels, "+")
  else
    channel_text = translate_ui_text(
      state.preview_channel_mode == "left"
        and "左声道"
        or state.preview_channel_mode == "right"
          and "右声道"
          or state.preview_channel_mode == "mono"
            and "单声道"
            or channel_count > 2
              and "全部声道"
              or channel_count == 2
                and "立体声"
                or "原始"
    )
  end

  local match_text =
    state.loudness_match
      and string.format(
        "Match %+.1f dB",
        state.preview_match_offset_db
      )
      or "Match Off"

  return selection_text
    .. string.format(
      "  ·  R %d  ·  %s  ·  %s",
      #asset_regions(asset),
      channel_text,
      match_text
    )
end

function draw_time_metrics(asset)
  local current_seconds = 0

  if state.preview_path
    and path_key(state.preview_path) == path_key(asset.path) then
    current_seconds =
      (asset.duration or 0)
        * (state.preview_percent or 0)
  end

  local in_seconds =
    (asset.duration or 0) * state.region_start

  local out_seconds =
    (asset.duration or 0) * state.region_end

  metric_chip(
    "Current",
    format_time(current_seconds),
    true
  )

  ImGui.SameLine(ctx, 0, 6)
  metric_chip("In", format_time(in_seconds), false)

  ImGui.SameLine(ctx, 0, 6)
  metric_chip("Out", format_time(out_seconds), false)

  ImGui.SameLine(ctx, 0, 6)
  metric_chip(
    "Duration",
    format_time(asset.duration or 0),
    false
  )

  ImGui.SameLine(ctx, 0, 6)
  metric_chip(
    "Zoom",
    string.format("×%.1f", 1 / wave_view_span()),
    false
  )

  ImGui.SameLine(ctx, 0, 10)

  local remaining_width =
    select(1, ImGui.GetContentRegionAvail(ctx))

  local summary_drawn = false

  if remaining_width > 190 then
    local summary_width =
      math.min(
        remaining_width * 0.38,
        280
      )

    inline_metric_text(
      preview_context_summary(asset),
      COLOR.dim,
      summary_width
    )

    summary_drawn = true
  end

  local status_text = tostring(state.status or "")

  local preview_start_percent =
    status_text:match(
      "^从 ([%d%.]+)%% 开始试听[:：].+$"
    ) or status_text:match(
      "^Previewing from ([%d%.]+)%%[:：].+$"
    )

  if preview_start_percent then
    status_text =
      state.language == "en"
        and string.format(
          "Previewing from %s%%",
          preview_start_percent
        )
        or string.format(
          "从 %s%% 开始试听",
          preview_start_percent
        )
  end

  if state.layout_notice and state.layout_notice ~= "" then
    status_text =
      status_text ~= ""
        and (status_text .. "  ·  " .. state.layout_notice)
        or state.layout_notice
  end

  if status_text ~= "" then
    if summary_drawn then
      ImGui.SameLine(ctx, 0, 12)
    end

    remaining_width =
      select(1, ImGui.GetContentRegionAvail(ctx))

    if remaining_width > 90 then
      inline_metric_text(
        status_text,
        state.status_error and COLOR.error or COLOR.success,
        math.max(70, remaining_width - 8)
      )
    end
  end
end

function draw_studio_parameters(asset, card_width, card_height)
  local new_pitch, pitch_changed =
    draw_parameter_card(
      "pitch_strip",
      "Pitch",
      state.pitch,
      -24,
      24,
      0,
      "%+.1f st",
      card_width,
      card_height
    )

  if pitch_changed then
    state.pitch = new_pitch
    update_preview_parameters()
  end

  ImGui.SameLine(ctx, 0, 10)

  local new_rate, rate_changed =
    draw_parameter_card(
      "rate_strip",
      "Rate",
      state.rate,
      0.25,
      4,
      1,
      "%.2fx",
      card_width,
      card_height
    )

  if rate_changed then
    state.rate = new_rate
    update_preview_parameters()
  end

  ImGui.SameLine(ctx, 0, 10)

  local new_gain, gain_changed =
    draw_parameter_card(
      "gain_strip",
      "Gain",
      state.gain_db,
      -36,
      18,
      0,
      "%+.1f dB",
      card_width,
      card_height
    )

  if gain_changed then
    state.gain_db = new_gain
    update_preview_parameters()
  end
end

function preview_control_layout_metrics(width)
  local mode = state.preview_control_layout
  local minimal = mode == "minimal_rack"
  local focused = mode == "focus_rack"
  local button_size =
    state.ui_density == "compact" and 28
      or state.ui_density == "comfortable" and 32
      or 30
  local button_gap =
    math.max(
      3,
      math.floor(button_size * 0.18)
    )
  local action_width =
    button_size * (minimal and 5 or 9)
      + button_gap * (minimal and 4 or 10)
      + (minimal and 0 or 7)
  local toggle_width =
    button_size * 6
      + button_gap * 5
  local parameter_min_width =
    UI_METRIC.parameter_min_w * 3 + 20
  local separator_width = 27
  local all_inline_min_width =
    action_width
      + parameter_min_width
      + toggle_width
      + separator_width * 2
      + 12
  local two_rows =
    not minimal
      and width
        < action_width
          + parameter_min_width
          + separator_width
  local toggles_visible =
    not minimal and not focused
  local toggles_inline =
    toggles_visible
      and not two_rows
      and width >= all_inline_min_width
  local row_count =
    minimal and 1
      or two_rows and 2
      or 1

  if toggles_visible and not toggles_inline then
    row_count = row_count + 1
  end

  return {
    minimal = minimal,
    focused = focused,
    button_size = button_size,
    button_gap = button_gap,
    action_width = action_width,
    toggle_width = toggle_width,
    separator_width = separator_width,
    two_rows = two_rows,
    toggles_visible = toggles_visible,
    toggles_inline = toggles_inline,
    row_count = row_count,
    panel_height =
      row_count * button_size
        + math.max(0, row_count - 1) * 8
        + 4,
  }
end

function draw_control_deck(asset)
  local width = select(1, ImGui.GetContentRegionAvail(ctx))
  local layout =
    preview_control_layout_metrics(width)
  local minimal = layout.minimal
  local button_size = layout.button_size
  local two_rows = layout.two_rows
  local show_channel_rail =
    preview_asset_channel_count(asset) > 2
      and state.preview_channel_strip_expanded
  local panel_height = layout.panel_height

  if show_channel_rail then
    panel_height =
      panel_height + button_size + 10
  end

  ImGui.PushStyleVar(
    ctx,
    ImGui.StyleVar_WindowPadding,
    2,
    2
  )
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, COLOR.window)

  local strip_visible = ImGui.BeginChild(
    ctx,
    "preview_studio_strip",
    width,
    panel_height,
    0,
    ImGui.WindowFlags_NoScrollbar
      | ImGui.WindowFlags_NoScrollWithMouse
  )

  if strip_visible then
    draw_action_strip(asset, minimal, button_size)

    if not minimal then
      if two_rows then
        ImGui.Spacing(ctx)
      else
        ImGui.SameLine(ctx, 0, 10)
        toolbar_separator(button_size)
        ImGui.SameLine(ctx, 0, 10)
      end

      local card_width =
        clamp(
          (
            width
              - (
                two_rows
                  and 20
                  or layout.action_width
                    + layout.separator_width
                    + (
                      layout.toggles_inline
                        and layout.toggle_width
                          + layout.separator_width
                        or 0
                    )
              )
              - 20
          ) / 3,
          UI_METRIC.parameter_min_w,
          150
        )

      draw_studio_parameters(
        asset,
        card_width,
        button_size
      )

      if layout.toggles_inline then
        ImGui.SameLine(ctx, 0, 10)
        toolbar_separator(button_size)
        ImGui.SameLine(ctx, 0, 10)
        draw_preview_toggle_icons(asset, button_size)
      elseif layout.toggles_visible then
        ImGui.Spacing(ctx)
        draw_preview_toggle_icons(asset, button_size)
      end
    end

    if show_channel_rail
      and state.preview_channel_strip_expanded then
      ImGui.Spacing(ctx)
      draw_inline_channel_selector(
        asset,
        button_size
      )
    end
  end

  ImGui.EndChild(ctx)
  ImGui.PopStyleColor(ctx)
  ImGui.PopStyleVar(ctx)
end

function format_loudness_value(value, suffix)
  if value == nil then
    return "—"
  end

  return string.format(
    "%.1f%s",
    value,
    suffix or ""
  )
end

function draw_loudness_summary(asset)
  if not state.show_loudness_metrics then
    return
  end

  request_loudness_analysis(asset, false)

  local entry = valid_loudness_entry(asset)
  local key = loudness_cache_key(asset)
  local analyzing =
    state.loudness_queued[key]
    or (
      state.loudness_active
      and state.loudness_active.key == key
    )

  ImGui.SameLine(ctx)

  if analyzing and not entry then
    metric_chip("Loudness", "分析中…", false)
    return
  end

  if not entry then
    metric_chip("Loudness", "等待", false)
    return
  end

  local first = true

  local function add_metric(label, value, active)
    if not first then
      ImGui.SameLine(ctx, 0, 5)
    end

    metric_chip(label, value, active)
    first = false
  end

  if state.loudness_show_i then
    add_metric(
      "LUFS-I",
      format_loudness_value(entry.lufs_i, ""),
      true
    )
  end

  if state.loudness_show_m then
    add_metric(
      "M max",
      format_loudness_value(entry.lufs_m, ""),
      false
    )
  end

  if state.loudness_show_s then
    add_metric(
      "S max",
      format_loudness_value(entry.lufs_s, ""),
      false
    )
  end

  if state.loudness_show_tp then
    add_metric(
      "TP",
      format_loudness_value(entry.true_peak, " dBTP"),
      false
    )
  end
end


function collect_loudness_summary_items(asset)
  local items = {}

  if not state.show_loudness_metrics then
    return items
  end

  request_loudness_analysis(asset, false)

  local entry = valid_loudness_entry(asset)
  local key = loudness_cache_key(asset)
  local analyzing =
    state.loudness_queued[key]
    or (
      state.loudness_active
      and state.loudness_active.key == key
    )

  if analyzing and not entry then
    items[1] = {
      label = "LOUDNESS",
      value = "…",
      accent = false,
    }
    return items
  end

  if not entry then
    return items
  end

  if state.loudness_show_i then
    items[#items + 1] = {
      label = "LUFS-I",
      value = format_loudness_value(entry.lufs_i, ""),
      accent = true,
    }
  end

  if state.loudness_show_m then
    items[#items + 1] = {
      label = "M",
      value = format_loudness_value(entry.lufs_m, ""),
      accent = false,
    }
  end

  if state.loudness_show_s then
    items[#items + 1] = {
      label = "S",
      value = format_loudness_value(entry.lufs_s, ""),
      accent = false,
    }
  end

  if state.loudness_show_tp then
    items[#items + 1] = {
      label = "TP",
      value = format_loudness_value(
        entry.true_peak,
        " dBTP"
      ),
      accent = false,
    }
  end

  return items
end

function draw_preview_header(asset)
  local width =
    select(
      1,
      ImGui.GetContentRegionAvail(ctx)
    )

  local height = 32
  local x, y =
    ImGui.GetCursorScreenPos(ctx)

  ImGui.InvisibleButton(
    ctx,
    "preview_header_bar",
    width,
    height
  )

  local draw_list =
    ImGui.GetWindowDrawList(ctx)

  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + width,
    y + height,
    COLOR.title,
    UI_METRIC.radius_small
  )

  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y + 7,
    x + 3,
    y + height - 7,
    COLOR.selected,
    1.5
  )

  local items =
    collect_loudness_summary_items(asset)

  local right_x = x + width - 12

  for index = #items, 1, -1 do
    local item = items[index]
    local label =
      translate_ui_text(item.label)
    local value =
      tostring(item.value or "")

    local label_w =
      select(
        1,
        ImGui.CalcTextSize(ctx, label)
      ) or 0

    local value_w =
      select(
        1,
        ImGui.CalcTextSize(ctx, value)
      ) or 0

    local item_w =
      label_w + value_w + 12

    right_x = right_x - item_w

    ImGui.DrawList_AddText(
      draw_list,
      right_x,
      y + 9,
      COLOR.dim,
      label
    )

    ImGui.DrawList_AddText(
      draw_list,
      right_x + label_w + 6,
      y + 9,
      item.accent
        and COLOR.playhead
        or COLOR.text,
      value
    )

    right_x = right_x - 14

    if index > 1 then
      ImGui.DrawList_AddCircleFilled(
        draw_list,
        right_x + 7,
        y + height * 0.5,
        1.5,
        rgba_with_alpha(COLOR.dim, 0x88),
        10
      )
    end
  end

  local name_start = x + 12
  local name_end =
    math.min(
      x + width * 0.47,
      right_x - 14
    )

  draw_clipped_text(
    draw_list,
    name_start,
    y + 8,
    COLOR.selected_text,
    asset.name,
    name_start,
    y,
    math.max(name_start + 80, name_end),
    y + height
  )

  local name_w =
    math.min(
      select(
        1,
        ImGui.CalcTextSize(
          ctx,
          asset.name
        )
      ) or 0,
      math.max(80, name_end - name_start)
    )

  local metadata_x =
    name_start + name_w + 14

  local metadata =
    string.format(
      "%s  ·  %sch  ·  %s  ·  %s",
      asset.duration > 0
        and format_time(asset.duration)
        or "读取中",
      tostring(asset.channels or 0),
      format_rate(asset.sample_rate),
      asset.library or ""
    )

  if metadata_x < right_x - 20 then
    draw_clipped_text(
      draw_list,
      metadata_x,
      y + 8,
      COLOR.dim,
      metadata,
      metadata_x,
      y,
      right_x - 10,
      y + height
    )
  end
end

function draw_bottom(asset)
  if not asset then
    ImGui.TextDisabled(
      ctx,
      "选择一个音频查看波形和试听控制。"
    )

    if state.status and state.status ~= "" then
      ImGui.SameLine(ctx, 0, 12)
      ImGui.TextColored(
        ctx,
        state.status_error and COLOR.error or COLOR.success,
        state.status
      )
    end
    return
  end

  queue_metadata(asset, true)

  draw_preview_header(asset)
  ImGui.Spacing(ctx)
  draw_large_wave(asset)
  draw_time_metrics(asset)
  ImGui.Spacing(ctx)
  draw_control_deck(asset)
end

----------------------------------------------------------------
-- Metadata inspector (0.4: non-destructive database editing)
----------------------------------------------------------------

local METADATA_EDIT_FIELDS = {
  {
    key = "description",
    label = "Description",
  },
  {
    key = "keywords",
    label = "Keywords",
  },
  {
    key = "category",
    label = "Category",
  },
  {
    key = "subcategory",
    label = "SubCategory",
  },
  {
    key = "catid",
    label = "CatID",
  },
  {
    key = "library",
    label = "Library",
  },
  {
    key = "artwork_path",
    label = "Artwork Path",
  },
}

function selected_assets_fast()
  local assets = {}

  for key in pairs(state.selected_set) do
    local asset = state.by_path[key]

    if asset then
      assets[#assets + 1] = asset
    end
  end

  if #assets == 0 then
    local asset = selected_asset()

    if asset then
      assets[1] = asset
    end
  end

  table.sort(
    assets,
    function(a, b)
      return path_key(a.path)
        < path_key(b.path)
    end
  )

  return assets
end

function metadata_selection_signature(assets)
  local parts = {
    tostring(#assets),
  }

  for _, asset in ipairs(assets) do
    parts[#parts + 1] =
      path_key(asset.path)
      .. ":"
      .. tostring(asset.indexed)
  end

  return fnv1a(table.concat(parts, "|"))
end

function common_metadata_value(assets, field)
  if #assets == 0 then
    return "", false
  end

  local value = tostring(assets[1][field] or "")

  for index = 2, #assets do
    if tostring(assets[index][field] or "")
      ~= value then
      return "", true
    end
  end

  return value, false
end

function sync_metadata_editor(assets)
  local signature =
    metadata_selection_signature(assets)

  if state.metadata_editor.signature
    == signature then
    return
  end

  state.metadata_editor.signature = signature
  state.metadata_editor.values = {}
  state.metadata_editor.enabled = {}
  state.metadata_editor.mixed = {}

  local single = #assets == 1

  for _, field in ipairs(METADATA_EDIT_FIELDS) do
    local value, mixed =
      common_metadata_value(
        assets,
        field.key
      )

    state.metadata_editor.values[field.key] = value
    state.metadata_editor.mixed[field.key] = mixed
    state.metadata_editor.enabled[field.key] = single
  end
end

function apply_metadata_editor(assets)
  if #assets == 0 then
    return
  end

  local changed_count = 0
  local multi = #assets > 1

  for _, asset in ipairs(assets) do
    local asset_changed = false

    for _, field in ipairs(METADATA_EDIT_FIELDS) do
      local should_apply =
        not multi
        or state.metadata_editor.enabled[field.key]

      if should_apply then
        local value =
          tostring(
            state.metadata_editor.values[field.key]
              or ""
          )

        if tostring(asset[field.key] or "")
          ~= value then
          asset[field.key] = value
          asset_changed = true
        end
      end
    end

    if asset_changed then
      asset._search_blob = nil
      mark_asset_database_change(asset)
      changed_count = changed_count + 1
    end
  end

  if changed_count > 0 then
    state.results_dirty = true
    state.metadata_editor.signature = ""

    set_status(
      string.format(
        "已将 PsyReaSFX 元数据保存到 %d 个素材",
        changed_count
      )
    )
  else
    set_status("元数据没有变化")
  end
end

function add_metadata_filter(field, value)
  value = trim(value)

  if value == "" then
    return
  end

  local token =
    field
    .. ":\""
    .. value:gsub('"', '')
    .. "\""

  if trim(state.search) == "" then
    state.search = token
  else
    state.search = state.search .. " " .. token
  end

  state.results_dirty = true
end

function choose_artwork_for_asset(asset)
  if not asset then
    return
  end

  local ok, filename =
    reaper.GetUserFileNameForRead(
      asset.artwork_path ~= "-"
        and asset.artwork_path
        or "",
      "选择封面",
      "png,jpg,jpeg"
    )

  if ok and filename and filename ~= "" then
    asset.artwork_path =
      normalize_slashes(filename)
    asset.artwork_checked = true
    mark_asset_database_change(asset)
    state.results_dirty = true
    set_status("已设置 Artwork")
  end
end

function draw_inspector_artwork_header(asset)
  local available_width =
    select(
      1,
      ImGui.GetContentRegionAvail(ctx)
    )

  local cover_size =
    clamp(
      available_width - 28,
      112,
      190
    )

  local start_x =
    ImGui.GetCursorPosX(ctx)

  ImGui.SetCursorPosX(
    ctx,
    start_x
      + math.max(
        0,
        (available_width - cover_size) * 0.5
      )
  )

  local x, y =
    ImGui.GetCursorScreenPos(ctx)

  ImGui.InvisibleButton(
    ctx,
    "inspector_artwork",
    cover_size,
    cover_size
  )

  local draw_list =
    ImGui.GetWindowDrawList(ctx)

  draw_artwork_cover(
    draw_list,
    asset,
    x,
    y,
    cover_size,
    cover_size,
    false,
    UI_METRIC.radius
  )

  ImGui.SetCursorPosX(ctx, start_x)

  ImGui.TextWrapped(ctx, asset.name)
  ImGui.TextDisabled(
    ctx,
    asset.library or ""
  )

  if dark_button("选择封面", -1) then
    choose_artwork_for_asset(asset)
  end

  if dark_button("自动查找封面", -1) then
    asset.artwork_path = ""
    asset.artwork_checked = false
    state.artwork_folder_cache = {}
    state.artwork_dimension_cache = {}
    queue_artwork(asset, true)
    mark_asset_database_change(asset)
  end

  if tostring(asset.artwork_path or "") ~= "" then
    if dark_button("清除封面", -1) then
      asset.artwork_path = "-"
      asset.artwork_checked = true
      mark_asset_database_change(asset)
      state.results_dirty = true
    end
  end
end

function draw_metadata_inspector()
  local assets = selected_assets_fast()

  if dark_button("隐藏元数据 >", -1) then
    state.inspector_visible = false
    state.config_dirty = true
    return
  end

  ImGui.Spacing(ctx)

  ImGui.TextColored(
    ctx,
    COLOR.text,
    "METADATA"
  )

  ImGui.SameLine(ctx)
  ImGui.TextDisabled(
    ctx,
    #assets > 0
      and tostring(#assets) .. " selected"
      or "no selection"
  )

  ImGui.Separator(ctx)

  if #assets == 0 then
    ImGui.TextWrapped(
      ctx,
      "选择一个或多个素材后，可在这里查看并编辑 PsyReaSFX 数据库元数据。"
    )
    return
  end

  for _, asset in ipairs(assets) do
    if not asset.indexed then
      queue_metadata(asset, true)
    end
  end

  sync_metadata_editor(assets)

  local primary = assets[1]
  local multi = #assets > 1

  if not multi
    and state.artwork_enabled
    and state.inspector_artwork_pinned then
    draw_inspector_artwork_header(primary)
    ImGui.Separator(ctx)
  end

  if ImGui.BeginChild(
    ctx,
    "metadata_inspector_scroll",
    -1,
    -1,
    0,
    ImGui.WindowFlags_AlwaysVerticalScrollbar
  ) then
    if multi
      or not state.inspector_artwork_pinned then
      ImGui.TextWrapped(
        ctx,
        multi
          and string.format(
            "%d 个素材批量编辑。勾选字段后才会写入。",
            #assets
          )
          or primary.name
      )

      if not multi and state.artwork_enabled then
        draw_inspector_artwork_header(primary)
        ImGui.Separator(ctx)
      end
    end

    ImGui.TextDisabled(ctx, "WORKFLOW STATUS")

    for index, status in ipairs(
      WORKFLOW_STATUS_ORDER
    ) do
      local definition =
        WORKFLOW_STATUS[status]

      if dark_button(definition.label, 76) then
        set_workflow_status(
          assets,
          status
        )
      end

      if index < #WORKFLOW_STATUS_ORDER then
        ImGui.SameLine(ctx)
      end
    end

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    for _, field in ipairs(METADATA_EDIT_FIELDS) do
      if multi then
        local enabled
        enabled, state.metadata_editor.enabled[field.key] =
          ImGui.Checkbox(
            ctx,
            "##enable_" .. field.key,
            state.metadata_editor.enabled[field.key]
          )

        ImGui.SameLine(ctx)
      end

      ImGui.TextDisabled(ctx, field.label)

      if state.metadata_editor.mixed[field.key]
        and multi
        and not state.metadata_editor.enabled[field.key] then
        ImGui.SameLine(ctx)
        ImGui.TextDisabled(ctx, "<mixed>")
      end

      ImGui.SetNextItemWidth(ctx, -1)

      local changed
      changed, state.metadata_editor.values[field.key] =
        ImGui.InputText(
          ctx,
          "##metadata_" .. field.key,
          state.metadata_editor.values[field.key]
            or ""
        )
    end

    ImGui.Spacing(ctx)

    if dark_button(
      multi
        and "应用到所选素材"
        or "保存元数据",
      -1
    ) then
      apply_metadata_editor(assets)
    end

    if not multi then
      if primary.category
        and primary.category ~= "" then
        if dark_button("按 Category 筛选", -1) then
          add_metadata_filter(
            "category",
            primary.category
          )
        end
      end

      if primary.library
        and primary.library ~= "" then
        if dark_button("按 Library 筛选", -1) then
          add_metadata_filter(
            "library",
            primary.library
          )
        end
      end
    end

    ImGui.Separator(ctx)
    ImGui.TextDisabled(ctx, "FILE INFO")

    ImGui.TextWrapped(
      ctx,
      string.format(
        "Duration  %s\nFormat  %s / %s / %dch\nType  %s",
        primary.duration > 0
          and format_time(primary.duration)
          or "—",
        format_rate(primary.sample_rate),
        (tonumber(primary.bit_depth) or 0) > 0
          and tostring(primary.bit_depth) .. "-bit"
          or "—",
        tonumber(primary.channels) or 0,
        primary.source_type or "—"
      )
    )

    ImGui.TextDisabled(ctx, "PATH")
    ImGui.TextWrapped(ctx, primary.path or "")

    if dark_button("复制路径", -1) then
      ImGui.SetClipboardText(
        ctx,
        primary.path or ""
      )
    end
  end

  ImGui.EndChild(ctx)
end

----------------------------------------------------------------
-- Help popup
----------------------------------------------------------------

local HELP_POPUP_ID =
  "PsyReaSFX 使用说明##psyreasfx_help"

function help_locale(zh_text, en_text)
  return state.language == "en"
    and en_text
    or zh_text
end

function draw_help_shortcut_row(shortcut, zh_text, en_text)
  ImGui.TextColored(
    ctx,
    COLOR.header_text,
    shortcut
  )

  ImGui.SameLine(ctx, 156)

  ImGui.TextWrapped(
    ctx,
    help_locale(zh_text, en_text)
  )
end

function draw_help_section(id, zh_title, en_title, items)
  ImGui.PushID(ctx, "help_section_" .. id)

  ImGui.TextColored(
    ctx,
    COLOR.accent,
    help_locale(zh_title, en_title)
  )

  ImGui.Separator(ctx)

  for _, item in ipairs(items) do
    draw_help_shortcut_row(
      item[1],
      item[2],
      item[3]
    )
  end

  ImGui.PopID(ctx)
  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)
end

function draw_help_popup()
  if state.help_popup_requested > 0 then
    state.help_popup_requested =
      state.help_popup_requested - 1

    if state.help_popup_requested == 0 then
      ImGui.OpenPopup(
        ctx,
        HELP_POPUP_ID
      )
    end
  end

  ImGui.SetNextWindowSize(
    ctx,
    820,
    650,
    ImGui.Cond_Appearing
  )

  if not ImGui.BeginPopupModal(
    ctx,
    HELP_POPUP_ID,
    true,
    ImGui.WindowFlags_NoScrollbar
  ) then
    return
  end

  ImGui.TextColored(
    ctx,
    COLOR.header_text,
    SCRIPT_NAME
  )

  ImGui.SameLine(ctx)

  ImGui.TextColored(
    ctx,
    COLOR.accent,
    "v" .. VERSION
  )

  ImGui.TextDisabled(
    ctx,
    help_locale(
      "浏览、整理、试听与传输快捷参考",
      "Quick reference for browsing, organizing, auditioning, and Transfer"
    )
  )

  ImGui.Separator(ctx)

  local width, height = ImGui.GetContentRegionAvail(ctx)

  if ImGui.BeginChild(
    ctx,
    "help_content_scroll",
    width,
    height - 50,
    0,
    ImGui.WindowFlags_AlwaysVerticalScrollbar
  ) then
    draw_help_section(
      "workspace",
      "工作区",
      "Workspace",
      {
        {
          "F9 / F10 / F11",
          "切换导航栏、元数据栏与专注模式",
          "Toggle navigation, metadata, and Focus mode",
        },
        {
          "Ctrl+F",
          "聚焦搜索框",
          "Focus the search field",
        },
        {
          "Ctrl+R",
          "扫描当前音效库范围",
          "Scan the current library scope",
        },
      }
    )

    draw_help_section(
      "results",
      "结果列表",
      "Results",
      {
        {
          "Click",
          "单选素材",
          "Select one asset",
        },
        {
          "Ctrl+Click",
          "追加或取消单个素材",
          "Add or remove one asset from the selection",
        },
        {
          "Shift+Click",
          "连续范围选择",
          "Select a continuous range",
        },
        {
          "Ctrl+A",
          "全选当前结果",
          "Select all current results",
        },
        {
          "Shift+Wheel",
          "横向查看溢出的字段",
          "Pan horizontally across overflow columns",
        },
      }
    )

    draw_help_section(
      "preview",
      "试听与波形",
      "Preview and waveform",
      {
        {
          "Space",
          "播放或停止",
          "Play or stop",
        },
        {
          "Wave click",
          "从点击位置开始试听",
          "Start preview from the clicked position",
        },
        {
          "Wave drag",
          "建立并试听波形选区",
          "Create and audition a waveform selection",
        },
        {
          "L",
          "切换循环试听",
          "Toggle loop preview",
        },
      }
    )

    draw_help_section(
      "organize",
      "整理",
      "Organize",
      {
        {
          "F",
          "收藏或取消收藏",
          "Favorite or unfavorite",
        },
        {
          "M",
          "标记或取消标记",
          "Mark or unmark",
        },
        {
          "Right-click",
          "打开素材、集合和状态操作",
          "Open asset, collection, and status actions",
        },
      }
    )

    draw_help_section(
      "output",
      "插入与 Transfer",
      "Insert and Transfer",
      {
        {
          "Enter",
          "插入当前轨道",
          "Insert on the current track",
        },
        {
          "Ctrl+Enter",
          "插入新轨道",
          "Insert on a new track",
        },
        {
          "Drag",
          "将素材或波形选区拖到 REAPER 编排区",
          "Drag an asset or waveform selection into REAPER",
        },
        {
          "Ctrl+T",
          "打开 Transfer 导出",
          "Open Transfer export",
        },
      }
    )
  end

  ImGui.EndChild(ctx)

  if dark_button("关闭", 90) then
    ImGui.CloseCurrentPopup(ctx)
  end

  ImGui.EndPopup(ctx)
end

----------------------------------------------------------------
-- Settings popup
----------------------------------------------------------------

function settings_tab_button(key, label)
  local selected =
    state.settings_tab == key

  if selected then
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_Button,
      COLOR.selected
    )
  end

  local clicked =
    dark_button(label, 112)

  if selected then
    ImGui.PopStyleColor(ctx)
  end

  if clicked then
    state.settings_tab = key
  end
end

function draw_language_setting()
  ImGui.Text(ctx, "语言")
  ImGui.SameLine(ctx)

  local zh_selected =
    state.language == "zh"

  if zh_selected then
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_Button,
      COLOR.selected
    )
  end

  local zh_clicked =
    dark_button("中文", 86)

  if zh_selected then
    ImGui.PopStyleColor(ctx)
  end

  ImGui.SameLine(ctx)

  local en_selected =
    state.language == "en"

  if en_selected then
    ImGui.PushStyleColor(
      ctx,
      ImGui.Col_Button,
      COLOR.selected
    )
  end

  local en_clicked =
    dark_button("English", 86)

  if en_selected then
    ImGui.PopStyleColor(ctx)
  end

  if zh_clicked then
    state.language = "zh"
    state.config_dirty = true
  elseif en_clicked then
    state.language = "en"
    state.config_dirty = true
  end
end

function draw_settings_general()
  draw_language_setting()
  ImGui.Separator(ctx)

  settings_section_title(
    "后台与浏览",
    "自动检查来源文件夹变化。"
  )

  local watch_changed
  watch_changed, state.watch_enabled =
    ImGui.Checkbox(
      ctx,
      "启用 Watch Folder",
      state.watch_enabled
    )

  if watch_changed then
    state.next_watch =
      reaper.time_precise() + state.watch_interval
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 220)
  local interval_changed
  interval_changed, state.watch_interval =
    ImGui.SliderDouble(
      ctx,
      "检查间隔",
      state.watch_interval,
      15,
      600,
      "%.0f s"
    )

  if interval_changed then
    state.next_watch = reaper.time_precise() + state.watch_interval
    state.config_dirty = true
  end

  local silent_changed
  silent_changed, state.watch_silent =
    ImGui.Checkbox(
      ctx,
      "静默后台检查（仅显示工具栏动态状态）",
      state.watch_silent
    )

  if silent_changed then
    state.config_dirty = true
  end

  local resume_changed
  resume_changed, state.resume_scan_on_start =
    ImGui.Checkbox(
      ctx,
      "启动时恢复中断的扫描",
      state.resume_scan_on_start
    )

  if resume_changed then
    state.config_dirty = true
  end

  ImGui.Separator(ctx)

  local sidebar_changed
  sidebar_changed, state.sidebar_visible =
    ImGui.Checkbox(
      ctx,
      "显示左侧导航",
      state.sidebar_visible
    )

  if sidebar_changed then
    state.config_dirty = true
  end

  local inspector_changed
  inspector_changed, state.inspector_visible =
    ImGui.Checkbox(
      ctx,
      "显示右侧元数据面板",
      state.inspector_visible
    )

  if inspector_changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 260)

  local inspector_width_changed
  inspector_width_changed, state.inspector_width =
    ImGui.SliderDouble(
      ctx,
      "元数据面板宽度",
      state.inspector_width,
      240,
      480,
      "%.0f px"
    )

  if inspector_width_changed then
    state.config_dirty = true
  end

  ImGui.Separator(ctx)
  ImGui.Text(ctx, "插入命名")
  ImGui.SetNextItemWidth(ctx, 300)

  local changed
  changed, state.insert_prefix =
    ImGui.InputText(
      ctx,
      "前缀",
      state.insert_prefix
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 300)

  changed, state.insert_suffix =
    ImGui.InputText(
      ctx,
      "后缀",
      state.insert_suffix
    )

  if changed then
    state.config_dirty = true
  end

  changed, state.insert_lowercase =
    ImGui.Checkbox(
      ctx,
      "Take 名称转为小写",
      state.insert_lowercase
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 220)

  changed, state.insert_fade_ms =
    ImGui.SliderDouble(
      ctx,
      "插入淡化",
      state.insert_fade_ms,
      0,
      100,
      "%.0f ms"
    )
end

function color_edit_flags()
  return ImGui.ColorEditFlags_NoAlpha
    | ImGui.ColorEditFlags_NoInputs
    | ImGui.ColorEditFlags_NoLabel
    | ImGui.ColorEditFlags_NoTooltip
    | ImGui.ColorEditFlags_PickerHueBar
    | ImGui.ColorEditFlags_InputRGB
end

function draw_color_picker_row(
  key,
  label,
  fallback_hex,
  mode
)
  local width =
    select(
      1,
      ImGui.GetContentRegionAvail(ctx)
    )

  local row_height = 44
  local x, y =
    ImGui.GetCursorScreenPos(ctx)

  -- Dummy only reserves the row. The previous InvisibleButton covered
  -- the later ColorEdit3 widget and consumed the click.
  ImGui.Dummy(
    ctx,
    width,
    row_height
  )

  local mouse_x, mouse_y =
    ImGui.GetMousePos(ctx)

  local hovered =
    mouse_x >= x
    and mouse_x <= x + width
    and mouse_y >= y
    and mouse_y <= y + row_height

  local draw_list =
    ImGui.GetWindowDrawList(ctx)

  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + width,
    y + row_height,
    hovered
      and COLOR.button_hover
      or COLOR.panel_alt,
    UI_METRIC.radius_small
  )

  ImGui.DrawList_AddRect(
    draw_list,
    x + 0.5,
    y + 0.5,
    x + width - 0.5,
    y + row_height - 0.5,
    rgba_with_alpha(COLOR.border, 0x7C),
    UI_METRIC.radius_small,
    0,
    1
  )

  ImGui.DrawList_AddText(
    draw_list,
    x + 12,
    y + 13,
    COLOR.text,
    translate_ui_text(label)
  )

  local reset_width = 54
  local hex_width = 78
  local picker_x =
    x + width - reset_width - hex_width - 54

  local saved_x, saved_y =
    ImGui.GetCursorScreenPos(ctx)

  ImGui.SetCursorScreenPos(
    ctx,
    picker_x,
    y + 7
  )

  ImGui.PushStyleVar(
    ctx,
    ImGui.StyleVar_FramePadding,
    7,
    6
  )

  local rgb =
    rgb_from_hex(state[key])
      or rgb_from_hex(fallback_hex)
      or 0

  ImGui.SetNextItemWidth(ctx, 34)

  local changed, new_rgb =
    ImGui.ColorEdit3(
      ctx,
      "##picker_" .. key,
      rgb,
      color_edit_flags()
    )

  tooltip("点击打开色盘")

  ImGui.PopStyleVar(ctx)

  if changed then
    state[key] = hex_from_rgb(new_rgb)
    state.config_dirty = true

    if mode == "theme" then
      state.theme_preset = "custom"
      apply_theme_palette()
    elseif mode == "surface" then
      state.surface_style = "custom"
      apply_surface_style()
      apply_theme_palette()
    else
      apply_waveform_palette()
    end
  end

  ImGui.SetCursorScreenPos(
    ctx,
    picker_x + 37,
    y + 13
  )

  ImGui.TextDisabled(
    ctx,
    tostring(state[key] or fallback_hex)
  )

  ImGui.SetCursorScreenPos(
    ctx,
    x + width - reset_width - 8,
    y + 7
  )

  if dark_button(
    "恢复##reset_" .. key,
    reset_width
  ) then
    state[key] = fallback_hex
    state.config_dirty = true

    if mode == "theme" then
      state.theme_preset = "custom"
      apply_theme_palette()
    elseif mode == "surface" then
      state.surface_style = "custom"
      apply_surface_style()
      apply_theme_palette()
    else
      apply_waveform_palette()
    end
  end

  ImGui.SetCursorScreenPos(
    ctx,
    saved_x,
    y + row_height
  )
end

function draw_waveform_palette_field(definition)
  local default_hex =
    DEFAULT_WAVEFORM_PALETTE[definition.key]
      or hex_from_rgb(
        (definition.fallback >> 8)
          & 0xFFFFFF
      )

  draw_color_picker_row(
    definition.key,
    definition.label,
    default_hex,
    "waveform"
  )
end

function get_reaimgui_runtime_version()
  if type(ImGui.GetVersion) ~= "function" then
    return "0.10+"
  end

  local ok, version =
    pcall(ImGui.GetVersion)

  if ok and version then
    return tostring(version)
  end

  return "0.10+"
end

function build_diagnostics_text()
  return table.concat(
    {
      SCRIPT_NAME .. " " .. VERSION,
      "Author: Psysia",
      "REAPER: " .. tostring(reaper.GetAppVersion()),
      "OS: " .. tostring(reaper.GetOS()),
      "ReaImGui: " .. get_reaimgui_runtime_version(),
      "SWS: " .. (
        type(reaper.CF_CreatePreview) == "function"
          and "Detected"
          or "Not detected"
      ),
      "Preview backend: " .. tostring(state.preview_backend),
      "Libraries: " .. tostring(#state.libraries),
      "Source folders: " .. tostring(#state.root_records),
      "Assets: " .. tostring(#state.assets),
      "Missing assets: " .. tostring(state.missing_asset_count),
      "Duplicate groups/assets: "
        .. tostring(state.duplicate_group_count)
        .. "/"
        .. tostring(state.duplicate_asset_count),
      "Current project: "
        .. tostring(state.current_project_path ~= "" and state.current_project_path or "Unsaved"),
      "Current played highlights: "
        .. tostring(session_played_count()),
      "Previous-session highlights: "
        .. tostring(last_session_played_count()),
      "Data directory: " .. DATA_DIR,
      "Wave cache directory: "
        .. tostring(
          state.wave_cache_dir
            or WAVE_CACHE_DIR
        ),
      "Project URL: "
        .. (
          PROJECT_URL ~= ""
            and PROJECT_URL
            or "Not configured"
        ),
      "Script file: " .. SCRIPT_FILE,
    },
    "\n"
  )
end

function about_info_row(label, value)
  local available =
    select(
      1,
      ImGui.GetContentRegionAvail(ctx)
    )

  local x, y =
    ImGui.GetCursorScreenPos(ctx)

  local label_width =
    math.min(170, available * 0.34)

  ImGui.TextDisabled(ctx, label)

  ImGui.SameLine(
    ctx,
    label_width
  )

  ImGui.TextWrapped(
    ctx,
    tostring(value or "")
  )
end

function draw_settings_about()
  local available_width =
    select(
      1,
      ImGui.GetContentRegionAvail(ctx)
    )

  local card_width =
    math.min(
      720,
      math.max(
        420,
        available_width
      )
    )

  local card_height = 220
  local x, y =
    ImGui.GetCursorScreenPos(ctx)

  ImGui.InvisibleButton(
    ctx,
    "about_minimal_card",
    card_width,
    card_height
  )

  local draw_list =
    ImGui.GetWindowDrawList(ctx)

  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + card_width,
    y + card_height,
    COLOR.panel_alt,
    math.max(10, UI_METRIC.radius)
  )

  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + card_width,
    y + 3,
    COLOR.accent,
    2
  )

  local icon_size = math.min(132, card_height - 54)
  local icon_x = x + 24
  local icon_y = y + (card_height - icon_size) * 0.5
  draw_brand_symbol(
    draw_list,
    icon_x,
    icon_y,
    icon_size
  )

  local text_x = icon_x + icon_size + 28

  draw_brand_wordmark(
    draw_list,
    text_x,
    y + 34,
    28
  )

  ImGui.DrawList_AddText(
    draw_list,
    text_x,
    y + 78,
    COLOR.header_text,
    translate_ui_text("音效资产井然有序")
  )

  ImGui.DrawList_AddText(
    draw_list,
    text_x,
    y + 105,
    COLOR.dim,
    translate_ui_text("浏览 · 整理 · 试听")
  )

  ImGui.DrawList_AddText(
    draw_list,
    text_x,
    y + 143,
    COLOR.accent,
    "v" .. VERSION .. "  ·  " .. AUTHOR_NAME
  )

  ImGui.DrawList_AddText(
    draw_list,
    text_x,
    y + 172,
    COLOR.dim,
    COPYRIGHT_TEXT
  )

  ImGui.Spacing(ctx)

  if PROJECT_URL ~= "" then
    if dark_button(
      "GitHub 项目主页 ↗",
      math.min(190, card_width)
    ) then
      open_url(PROJECT_URL)
    end
  else
    ImGui.TextDisabled(
      ctx,
      "GitHub 项目主页 · 待配置"
    )
  end
end

function apply_unified_interface(reset_columns, persist)
  state.ui_density = "compact"
  state.preview_control_layout = "studio_strip"

  if reset_columns then
    reset_columns_default()
  end

  if persist ~= false then
    state.config_dirty = true
  end
end

function settings_section_title(title, description)
  ImGui.Spacing(ctx)
  ImGui.TextColored(
    ctx,
    COLOR.header_text,
    title
  )

  if description and description ~= "" then
    ImGui.TextDisabled(ctx, description)
  end

  ImGui.Spacing(ctx)
end

function transfer_option_button(label, width, selected)
  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Button,
    selected and COLOR.selected or COLOR.button
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_ButtonHovered,
    selected and COLOR.accent or COLOR.button_hover
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_ButtonActive,
    COLOR.accent
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Text,
    selected and COLOR.selected_text or COLOR.text
  )

  ImGui.PushStyleColor(
    ctx,
    ImGui.Col_Border,
    selected
      and rgba_with_alpha(COLOR.selected_text, 0xA0)
      or rgba_with_alpha(COLOR.border, 0x70)
  )

  ImGui.PushStyleVar(
    ctx,
    ImGui.StyleVar_FrameBorderSize,
    selected and 1.5 or 1
  )

  local clicked = ImGui.Button(
    ctx,
    label,
    width or 128,
    0
  )

  ImGui.PopStyleVar(ctx)
  ImGui.PopStyleColor(ctx, 5)
  return clicked
end

function transfer_choice(label, key, options)
  ImGui.TextDisabled(ctx, label)

  for index, option in ipairs(options) do
    local selected = state[key] == option.value

    local clicked = transfer_option_button(
      option.label .. "##" .. key .. "_" .. option.value,
      option.width or 128,
      selected
    )

    if clicked then
      state[key] = option.value
      state.config_dirty = true

      if key == "transfer_normalize" then
        if option.value == "lufs_i" then
          state.transfer_normalize_target = -16
        elseif option.value == "rms_i" then
          state.transfer_normalize_target = -18
        elseif option.value ~= "off" then
          state.transfer_normalize_target = -1
        end
      end
    end

    if index < #options then
      ImGui.SameLine(ctx, 0, 6)
    end
  end
end

function prompt_transfer_directory()
  local initial = state.transfer_dir or DEFAULT_TRANSFER_DIR
  local chosen = nil

  if type(reaper.JS_Dialog_BrowseForFolder) == "function" then
    local ok, accepted, path = pcall(
      reaper.JS_Dialog_BrowseForFolder,
      translate_ui_text("选择 Transfer 输出目录"),
      initial
    )

    if ok and accepted and accepted ~= 0 then
      chosen = path
    end
  end

  if not chosen then
    local ok, input = reaper.GetUserInputs(
      "选择 Transfer 输出目录",
      1,
      "输出目录:,extrawidth=420",
      initial
    )

    if not ok then
      return
    end

    chosen = input
  end

  chosen = normalize_slashes(trim(chosen or ""))

  if chosen == "" then
    set_status("请选择有效的输出目录", true)
    return
  end

  if path_key(chosen) == path_key(initial) then
    set_status("输出目录没有变化")
    return
  end

  if reaper.RecursiveCreateDirectory(chosen, 0) <= 0
    and not directory_exists(chosen) then
    set_status("无法创建输出目录", true)
    return
  end

  state.transfer_dir = chosen
  state.config_dirty = true
  set_status("已更新 Transfer 输出目录")
end

function draw_transfer_settings_content()
  settings_section_title(
    "输出目录",
    "Transfer 使用独立目录，不修改源素材。"
  )

  ImGui.SetNextItemWidth(ctx, -1)
  local changed
  changed, state.transfer_dir = ImGui.InputText(
    ctx,
    "##transfer_dir",
    state.transfer_dir or DEFAULT_TRANSFER_DIR
  )

  if changed then
    state.transfer_dir = normalize_slashes(state.transfer_dir)
    state.config_dirty = true
  end

  if dark_button("更改输出目录…", 150) then
    prompt_transfer_directory()
  end

  ImGui.SameLine(ctx, 0, 6)

  if dark_button("打开输出目录##transfer_settings_open_dir", 140) then
    local directory = state.transfer_dir or DEFAULT_TRANSFER_DIR
    reaper.RecursiveCreateDirectory(directory, 0)
    open_folder(directory)
  end

  ImGui.SameLine(ctx, 0, 6)

  if dark_button("恢复默认输出目录", 170) then
    state.transfer_dir = DEFAULT_TRANSFER_DIR
    state.config_dirty = true
  end

  ImGui.Separator(ctx)
  settings_section_title(
    "命名模板",
    "可用字段：{name} {category} {subcategory} {library} {index} {date} {region} {pitch} {rate} {gain} {direction} {variant} {variant_index}"
  )

  ImGui.SetNextItemWidth(ctx, -1)
  changed, state.transfer_template = ImGui.InputText(
    ctx,
    "##transfer_template",
    state.transfer_template or "{name}"
  )

  if changed then
    state.config_dirty = true
  end

  changed, state.transfer_lowercase = ImGui.Checkbox(
    ctx,
    "文件名转为小写",
    state.transfer_lowercase
  )

  if changed then
    state.config_dirty = true
  end

  ImGui.Separator(ctx)
  settings_section_title(
    "格式与范围",
    "当前素材可导出波形选区；批量导出始终使用每个完整文件。"
  )

  transfer_choice("导出范围", "transfer_scope", {
    { value = "selection", label = "当前选区" },
    { value = "full", label = "完整文件" },
  })

  ImGui.TextDisabled(ctx, "没有有效选区时自动使用完整文件")

  transfer_choice("输出格式", "transfer_format", {
    { value = "wav16", label = "WAV · 16-bit", width = 126 },
    { value = "wav24", label = "WAV · 24-bit", width = 126 },
    { value = "wav32", label = "WAV · 32-bit PCM", width = 154 },
    { value = "flac", label = "FLAC · REAPER 默认", width = 190 },
  })

  transfer_choice("采样率", "transfer_sample_rate", {
    { value = "source", label = "跟随源文件", width = 120 },
    { value = "44100", label = "44.1 kHz", width = 92 },
    { value = "48000", label = "48 kHz", width = 86 },
    { value = "96000", label = "96 kHz", width = 86 },
    { value = "192000", label = "192 kHz", width = 92 },
  })

  transfer_choice("声道", "transfer_channels", {
    { value = "source", label = "跟随源声道", width = 120 },
    { value = "mono", label = "单声道", width = 92 },
    { value = "stereo", label = "立体声", width = 92 },
  })

  changed, state.transfer_preserve_metadata =
    ImGui.Checkbox(
      ctx,
      "尽可能保留源文件元数据",
      state.transfer_preserve_metadata
    )

  if changed then
    state.config_dirty = true
  end

  if state.transfer_format == "wav16" then
    changed, state.transfer_dither =
      ImGui.Checkbox(
        ctx,
        "启用抖动",
        state.transfer_dither
      )

    if changed then
      state.config_dirty = true
    end

    ImGui.SameLine(ctx, 0, 18)

    changed, state.transfer_noise_shaping =
      ImGui.Checkbox(
        ctx,
        "噪声整形",
        state.transfer_noise_shaping
      )

    if changed then
      state.config_dirty = true
    end

  elseif state.transfer_format ~= "flac" then
    ImGui.TextDisabled(
      ctx,
      "当前位深保持抖动关闭；WAV 16-bit 可单独启用。"
    )
  end

  ImGui.Separator(ctx)
  settings_section_title(
    "处理",
    "当前 Pitch、Rate、Gain、Reverse 与 Preserve Pitch 会写入导出文件。"
  )

  ImGui.SetNextItemWidth(ctx, 230)
  changed, state.transfer_fade_in_ms = ImGui.SliderDouble(
    ctx,
    "淡入",
    state.transfer_fade_in_ms,
    0,
    500,
    "%.0f ms"
  )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 230)
  changed, state.transfer_fade_out_ms = ImGui.SliderDouble(
    ctx,
    "淡出",
    state.transfer_fade_out_ms,
    0,
    2000,
    "%.0f ms"
  )

  if changed then
    state.config_dirty = true
  end

  changed, state.transfer_smart_tail = ImGui.Checkbox(
    ctx,
    "智能保留选区尾音",
    state.transfer_smart_tail
  )

  if changed then
    state.config_dirty = true
  end

  if state.transfer_smart_tail then
    ImGui.TextDisabled(
      ctx,
      "分析选区结束后的源音频，保留最后一个超过阈值的尾音，并受最大长度限制。"
    )

    ImGui.SetNextItemWidth(ctx, 230)
    changed, state.transfer_tail_threshold_db =
      ImGui.SliderDouble(
        ctx,
        "尾音阈值",
        state.transfer_tail_threshold_db,
        -96,
        -18,
        "%.1f dBFS"
      )

    if changed then
      state.config_dirty = true
    end

    ImGui.SetNextItemWidth(ctx, 230)
    changed, state.transfer_tail_max_ms =
      ImGui.SliderDouble(
        ctx,
        "最大尾音",
        state.transfer_tail_max_ms,
        100,
        30000,
        "%.0f ms"
      )

    if changed then
      state.config_dirty = true
    end

    ImGui.SetNextItemWidth(ctx, 230)
    changed, state.transfer_tail_hold_ms =
      ImGui.SliderDouble(
        ctx,
        "尾音留白",
        state.transfer_tail_hold_ms,
        0,
        2000,
        "%.0f ms"
      )

    if changed then
      state.config_dirty = true
    end

    ImGui.TextDisabled(
      ctx,
      "只延伸源文件中已有的尾音；Transfer 仍不经过工程轨道、发送或 Master FX。"
    )
  end

  ImGui.Separator(ctx)
  settings_section_title(
    "批量变体",
    "按 Pitch、Rate、Gain 与方向生成笛卡尔组合；每个参数最多 16 项，单素材最多 128 个变体。"
  )

  changed, state.transfer_variants_enabled =
    ImGui.Checkbox(
      ctx,
      "启用批量变体",
      state.transfer_variants_enabled
    )

  if changed then
    state.config_dirty = true
  end

  if state.transfer_variants_enabled then
    ImGui.TextDisabled(
      ctx,
      "留空表示使用主界面当前值；可用逗号、空格或分号分隔。"
    )

    ImGui.SetNextItemWidth(ctx, 420)
    changed, state.transfer_variant_pitches =
      ImGui.InputText(
        ctx,
        "Pitch 列表##transfer_variant_pitches",
        state.transfer_variant_pitches or ""
      )

    if changed then
      state.config_dirty = true
    end

    ImGui.SetNextItemWidth(ctx, 420)
    changed, state.transfer_variant_rates =
      ImGui.InputText(
        ctx,
        "Rate 列表##transfer_variant_rates",
        state.transfer_variant_rates or ""
      )

    if changed then
      state.config_dirty = true
    end

    ImGui.SetNextItemWidth(ctx, 420)
    changed, state.transfer_variant_gains =
      ImGui.InputText(
        ctx,
        "Gain 列表##transfer_variant_gains",
        state.transfer_variant_gains or ""
      )

    if changed then
      state.config_dirty = true
    end

    if dark_button("当前参数", 110) then
      state.transfer_variant_pitches = ""
      state.transfer_variant_rates = ""
      state.transfer_variant_gains = ""
      state.transfer_variant_include_reverse = false
      state.config_dirty = true
    end

    ImGui.SameLine(ctx, 0, 6)

    if dark_button("Pitch ±3 / ±6", 142) then
      state.transfer_variant_pitches = "-6,-3,0,3,6"
      state.transfer_variant_rates = ""
      state.transfer_variant_gains = ""
      state.config_dirty = true
    end

    ImGui.SameLine(ctx, 0, 6)

    if dark_button("轻量变化", 110) then
      state.transfer_variant_pitches = "-2,0,2"
      state.transfer_variant_rates = "0.95,1,1.05"
      state.transfer_variant_gains = "-1,0,1"
      state.config_dirty = true
    end

    changed, state.transfer_variant_include_reverse =
      ImGui.Checkbox(
        ctx,
        "同时生成正向与反向",
        state.transfer_variant_include_reverse
      )

    if changed then
      state.config_dirty = true
    end

    changed, state.transfer_variant_auto_suffix =
      ImGui.Checkbox(
        ctx,
        "模板未含变体字段时自动追加安全后缀",
        state.transfer_variant_auto_suffix
      )

    if changed then
      state.config_dirty = true
    end

    local variants, variant_error =
      build_transfer_variants()

    if variants then
      ImGui.TextColored(
        ctx,
        COLOR.success,
        string.format(
          "%s %d",
          translate_ui_text("每个素材将生成"),
          #variants
        )
      )
    else
      ImGui.TextColored(
        ctx,
        COLOR.error,
        variant_error or translate_ui_text("变体设置无效")
      )
    end
  end

  transfer_choice("标准化", "transfer_normalize", {
    { value = "off", label = "关闭标准化", width = 112 },
    { value = "peak", label = "Peak", width = 82 },
    { value = "true_peak", label = "True Peak", width = 102 },
    { value = "rms_i", label = "RMS-I", width = 88 },
    { value = "lufs_i", label = "LUFS-I", width = 90 },
  })

  if state.transfer_normalize ~= "off" then
    ImGui.SetNextItemWidth(ctx, 230)
    changed, state.transfer_normalize_target = ImGui.SliderDouble(
      ctx,
      "目标值",
      state.transfer_normalize_target,
      (
        state.transfer_normalize == "lufs_i"
          or state.transfer_normalize == "rms_i"
      ) and -36 or -12,
      0,
      state.transfer_normalize == "lufs_i"
        and "%.1f LUFS"
        or (
          state.transfer_normalize == "rms_i"
            and "%.1f dB RMS"
            or "%.1f dBFS"
        )
    )

    if changed then
      state.config_dirty = true
    end
  end

  ImGui.Separator(ctx)
  settings_section_title(
    "完成行为",
    "自动递增是默认且最安全的重名策略。"
  )

  transfer_choice("重名策略", "transfer_collision", {
    { value = "increment", label = "自动递增", width = 110 },
    { value = "skip", label = "跳过已有文件", width = 132 },
    { value = "overwrite", label = "允许覆盖", width = 108 },
  })

  changed, state.transfer_insert_after = ImGui.Checkbox(
    ctx,
    "导出后插入 REAPER",
    state.transfer_insert_after
  )

  if changed then
    state.config_dirty = true
  end

  changed, state.transfer_open_dir_after = ImGui.Checkbox(
    ctx,
    "导出完成后打开输出目录",
    state.transfer_open_dir_after
  )

  if changed then
    state.config_dirty = true
  end

  ImGui.TextDisabled(
    ctx,
    "Transfer 只处理源素材与当前 Pitch / Rate / Gain / Reverse / Preserve Pitch，不经过工程轨道或 Master FX。"
  )
end

function draw_transfer_popup()
  if state.transfer_popup_requested > 0 then
    state.transfer_popup_requested = state.transfer_popup_requested - 1

    if state.transfer_popup_requested == 0 then
      ImGui.OpenPopup(ctx, "Transfer 导出##transfer")
    end
  end

  ImGui.SetNextWindowSize(
    ctx,
    820,
    760,
    ImGui.Cond_Appearing
  )

  if not ImGui.BeginPopupModal(
    ctx,
    "Transfer 导出##transfer",
    true,
    ImGui.WindowFlags_NoScrollbar
  ) then
    return
  end

  local width, height = ImGui.GetContentRegionAvail(ctx)
  local footer_height = state.transfer_running and 106 or 72

  if ImGui.BeginChild(
    ctx,
    "transfer_settings_scroll",
    width,
    height - footer_height,
    0,
    ImGui.WindowFlags_AlwaysVerticalScrollbar
  ) then
    draw_transfer_settings_content()

    ImGui.Separator(ctx)
    settings_section_title("最近输出", "")

    if state.transfer_last_output ~= "" then
      ImGui.TextWrapped(ctx, state.transfer_last_output)

      if dark_button("打开输出目录##transfer_recent_open_dir", 140) then
        open_folder(dirname(state.transfer_last_output))
      end
    else
      ImGui.TextDisabled(ctx, "尚未执行 Transfer")
    end

    if state.transfer_last_summary ~= "" then
      ImGui.TextColored(
        ctx,
        COLOR.success,
        state.transfer_last_summary
      )
    end

    if reaper.file_exists(TRANSFER_REPORT_FILE) then
      if dark_button("打开任务报告目录##transfer_report_open_dir", 170) then
        open_folder(dirname(TRANSFER_REPORT_FILE))
      end
    end

    if state.transfer_last_error ~= "" then
      ImGui.TextColored(ctx, COLOR.error, state.transfer_last_error)
    end
  end

  ImGui.EndChild(ctx)
  ImGui.Separator(ctx)

  local asset = selected_asset()
  local selected = selected_assets()

  if state.transfer_running and state.transfer_job then
    local job = state.transfer_job
    local fraction =
      job.total > 0
        and clamp((job.completed or 0) / job.total, 0, 1)
        or 0

    ImGui.ProgressBar(
      ctx,
      fraction,
      -142,
      22,
      string.format(
        "%d / %d",
        job.completed or 0,
        job.total or 0
      )
    )

    ImGui.SameLine(ctx, 0, 8)

    if dark_button("当前文件后停止", 132) then
      state.transfer_cancel_requested = true
    end
  elseif dark_button("导出当前素材", 160) then
    run_transfer(asset and { asset } or {}, false)
  else
    ImGui.SameLine(ctx, 0, 8)

    if dark_button(
      string.format(
        "%s (%d)",
        translate_ui_text("导出所选素材"),
        #selected
      ),
      190
    ) then
      run_transfer(selected, true)
    end
  end

  ImGui.SameLine(ctx, 0, 8)

  if dark_button("关闭", 100) then
    save_config()
    ImGui.CloseCurrentPopup(ctx)
  end

  ImGui.EndPopup(ctx)
end

function draw_settings_transfer()
  draw_transfer_settings_content()
end

function draw_settings_appearance()
  settings_section_title(
    "统一界面",
    ""
  )

  if dark_button("恢复统一界面", 170) then
    apply_unified_interface(true, true)
  end

  ImGui.Separator(ctx)

  settings_section_title(
    "浏览与工作区",
    "调整下方大波形与试听区域的高度。"
  )

  ImGui.SetNextItemWidth(ctx, 280)

  local panel_height_changed
  panel_height_changed, state.bottom_panel_height =
    ImGui.SliderDouble(
      ctx,
      "下方面板高度",
      state.bottom_panel_height,
      BOTTOM_MIN_H,
      BOTTOM_MAX_H,
      "%.0f px"
    )

  if panel_height_changed then
    state.config_dirty = true
  end

  ImGui.Separator(ctx)

  settings_section_title(
    "封面与元数据",
    ""
  )

  local changed
  changed, state.artwork_enabled =
    ImGui.Checkbox(
      ctx,
      "启用 Artwork",
      state.artwork_enabled
    )

  if changed then
    state.config_dirty = true
  end

  changed, state.inspector_artwork_pinned =
    ImGui.Checkbox(
      ctx,
      "元数据封面固定在顶部",
      state.inspector_artwork_pinned
    )

  if changed then
    state.config_dirty = true
  end

  if dark_button("清空 Artwork 缓存", 160) then
    clear_artwork_cache()
  end

  ImGui.Separator(ctx)

  settings_section_title(
    "颜色与状态",
    ""
  )

  local played_changed
  played_changed, state.played_text_enabled =
    ImGui.Checkbox(
      ctx,
      "已播放文字高亮",
      state.played_text_enabled
    )

  if played_changed then
    state.config_dirty = true
  end

  ImGui.SameLine(ctx)

  played_changed, state.played_waveform_enabled =
    ImGui.Checkbox(
      ctx,
      "已播放波形高亮",
      state.played_waveform_enabled
    )

  if played_changed then
    state.config_dirty = true
  end

  local restore_changed
  restore_changed, state.restore_played_on_start =
    ImGui.Checkbox(
      ctx,
      "启动时自动恢复上次浏览高亮",
      state.restore_played_on_start
    )

  if restore_changed then
    state.config_dirty = true
  end

  ImGui.TextDisabled(
    ctx,
    string.format(
      "%s %d　·　%s %d",
      translate_ui_text("当前高亮"),
      session_played_count(),
      translate_ui_text("上次记录"),
      last_session_played_count()
    )
  )

  if dark_button("恢复上次浏览高亮", 180) then
    restore_last_session_played_highlights()
  end

  ImGui.SameLine(ctx)

  if dark_button("清除本次已播放高亮", 180) then
    clear_session_played_highlights()
  end

  ImGui.SameLine(ctx)

  if dark_button("清除已保存浏览记录", 180) then
    clear_saved_session_played_highlights()
  end

  ImGui.Separator(ctx)

  settings_section_title(
    "外观模式",
    "黑暗模式为默认；传统模式使用更深的品牌藏蓝。"
  )

  for _, key in ipairs(
    {
      "dark",
      "heritage",
    }
  ) do
    local preset = APPEARANCE_PRESETS[key]
    local was_selected =
      state.theme_preset == key
      and state.surface_style == key

    if was_selected then
      ImGui.PushStyleColor(
        ctx,
        ImGui.Col_Button,
        THEME_PRESETS[key].accent
      )
    end

    local clicked = dark_button(preset.label, 176)

    if was_selected then
      ImGui.PopStyleColor(ctx)
    end

    if clicked then
      apply_appearance_preset(key)
    end

    if key ~= "heritage" then
      ImGui.SameLine(ctx)
    end
  end

  ImGui.TextDisabled(
    ctx,
    (
      state.surface_style == "custom"
        or state.theme_preset == "custom"
    )
      and (
        translate_ui_text("当前模式：")
          .. translate_ui_text("自定义")
      )
      or (
        translate_ui_text("当前模式：")
          .. (
            APPEARANCE_PRESETS[state.surface_style]
              and translate_ui_text(
                APPEARANCE_PRESETS[state.surface_style].label
              )
              or translate_ui_text(
                APPEARANCE_PRESETS.dark.label
              )
          )
      )
  )

  ImGui.Separator(ctx)

  settings_section_title(
    "自定义颜色",
    "底色控制整体框架，强调色用于选择与交互。"
  )

  draw_color_picker_row(
    "custom_shell_hex",
    "框架底色",
    "#101114",
    "surface"
  )

  draw_color_picker_row(
    "custom_accent_hex",
    "强调色",
    "#1F6FCC",
    "theme"
  )

  ImGui.Separator(ctx)

  settings_section_title(
    "波形配色",
    "普通、选中、已播放、标记、选区、播放指针与 Region。"
  )

  local palette_width =
    select(
      1,
      ImGui.GetContentRegionAvail(ctx)
    )

  local use_two_columns =
    palette_width >= 720

  for index, definition in ipairs(WAVEFORM_PALETTE_FIELDS) do
    if use_two_columns then
      local column_width =
        (palette_width - 8) * 0.5

      if ImGui.BeginChild(
        ctx,
        "palette_cell_" .. tostring(index),
        column_width,
        60,
        0,
        ImGui.WindowFlags_NoScrollbar
          | ImGui.WindowFlags_NoScrollWithMouse
      ) then
        draw_waveform_palette_field(definition)
      end

      ImGui.EndChild(ctx)

      if index % 2 == 1 then
        ImGui.SameLine(ctx)
      end
    else
      draw_waveform_palette_field(definition)
    end
  end

  if dark_button("恢复默认波形配色", 168) then
    reset_waveform_palette_defaults()
  end
end

function draw_settings_waveforms()
  ImGui.Text(ctx, "列表波形精度")

  for _, points in ipairs(
    {
      MINI_WAVE_DEFAULT_POINTS,
      MINI_WAVE_MAX_POINTS,
    }
  ) do
    local selected =
      state.mini_wave_points == points

    if selected then
      ImGui.PushStyleColor(
        ctx,
        ImGui.Col_Button,
        COLOR.selected
      )
    end

    local clicked =
      dark_button(
        tostring(points) .. " points",
        112
      )

    if selected then
      ImGui.PopStyleColor(ctx)
    end

    if clicked
      and state.mini_wave_points ~= points then
      state.mini_wave_points = points
      state.wave_queue = {}
      state.wave_queued = {}
      state.wave_checked = {}
      state.config_dirty = true
      set_status(
        string.format(
          "列表波形精度已设置为 %d 点；新精度将按需建立缓存",
          points
        )
      )
    end

    if points ~= MINI_WAVE_MAX_POINTS then
      ImGui.SameLine(ctx)
    end
  end

  ImGui.TextDisabled(
    ctx,
    "256 点：缓存较小；512 点：细节更多。"
  )

  local channel_lanes_changed
  channel_lanes_changed, state.multichannel_waveform =
    ImGui.Checkbox(
      ctx,
      "独立显示各声道",
      state.multichannel_waveform
    )

  if channel_lanes_changed then
    state.wave_queue = {}
    state.wave_queued = {}
    state.wave_checked = {}
    state.config_dirty = true
  end

  ImGui.TextDisabled(
    ctx,
    "立体声显示 L / R；多声道显示 CH 1–8。"
  )

  ImGui.Separator(ctx)
  ImGui.Text(ctx, "高精度预缓存")

  for _, points in ipairs(
    {
      2048,
      4096,
    }
  ) do
    local selected =
      state.precache_points == points

    if selected then
      ImGui.PushStyleColor(
        ctx,
        ImGui.Col_Button,
        COLOR.selected
      )
    end

    local clicked =
      dark_button(
        tostring(points) .. " points",
        112
      )

    if selected then
      ImGui.PopStyleColor(ctx)
    end

    if clicked then
      state.precache_points = points
      state.config_dirty = true
    end

    if points ~= 4096 then
      ImGui.SameLine(ctx)
    end
  end

  ImGui.Spacing(ctx)

  if dark_button(
    "预缓存全部音效库",
    160
  ) then
    start_wave_precache(
      state.precache_points,
      "all"
    )
  end

  if state.root_filter or state.library_filter_id then
    ImGui.SameLine(ctx)

    if dark_button(
      "预缓存当前音效库",
      170
    ) then
      start_wave_precache(
        state.precache_points,
        "current"
      )
    end
  end

  if state.precache_session then
    ImGui.SameLine(ctx)

    if dark_button("停止预缓存", 110) then
      state.precache_cancel_requested = true
    end

    local session = state.precache_session
    local collecting = session.phase == "collect"
    local total = collecting
      and (session.source_total or 0) or (session.total or 0)
    local completed = collecting
      and math.max(0, (session.collect_index or 1) - 1)
      or math.max(0, (session.index or 1) - 1)
    completed = math.min(completed, total)
    local fraction = total > 0 and completed / total or 0
    ImGui.TextDisabled(ctx, string.format(
      "%s %d / %d",
      collecting and "正在整理范围" or "正在预缓存",
      completed,
      total
    ))
    ImGui.ProgressBar(
      ctx,
      fraction,
      -1,
      18,
      string.format("%.1f%%", fraction * 100)
    )
  end

  ImGui.Spacing(ctx)
  ImGui.TextDisabled(
    ctx,
    "可在首次浏览大型库前预先生成高精度波形。"
  )

  ImGui.Separator(ctx)
  ImGui.Text(ctx, "缩放与擦播")

  local scrub_changed
  scrub_changed, state.wave_scrub_enabled =
    ImGui.Checkbox(
      ctx,
      "启用右键擦播",
      state.wave_scrub_enabled
    )

  if scrub_changed then
    state.config_dirty = true
  end

  local loop_selection_changed
  loop_selection_changed, state.loop_selection =
    ImGui.Checkbox(
      ctx,
      "选区完成后自动循环",
      state.loop_selection
    )

  if loop_selection_changed then
    state.config_dirty = true
  end

  ImGui.TextDisabled(
    ctx,
    "鼠标滚轮缩放；Shift+滚轮或中键拖动平移；双击重置；右键拖动擦播"
  )

  ImGui.Separator(ctx)
  ImGui.Text(ctx, "瞬态 Region 建议")

  local threshold_db =
    20 * math.log(
      math.max(
        state.transient_threshold,
        0.000001
      ),
      10
    )

  ImGui.SetNextItemWidth(ctx, 240)
  local changed
  changed, threshold_db =
    ImGui.SliderDouble(
      ctx,
      "阈值",
      threshold_db,
      -60,
      -1,
      "%.1f dBFS"
    )

  if changed then
    state.transient_threshold =
      10 ^ (threshold_db / 20)
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 240)
  changed, state.transient_smoothing_ms =
    ImGui.SliderDouble(
      ctx,
      "平滑时间",
      state.transient_smoothing_ms,
      0,
      80,
      "%.0f ms"
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 240)
  changed, state.transient_min_gap_ms =
    ImGui.SliderDouble(
      ctx,
      "最小间隔",
      state.transient_min_gap_ms,
      20,
      2000,
      "%.0f ms"
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 240)
  changed, state.transient_pre_ms =
    ImGui.SliderDouble(
      ctx,
      "Region 前置",
      state.transient_pre_ms,
      0,
      1000,
      "%.0f ms"
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 240)
  changed, state.transient_post_ms =
    ImGui.SliderDouble(
      ctx,
      "Region 后置",
      state.transient_post_ms,
      20,
      5000,
      "%.0f ms"
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 240)
  changed, state.transient_max_regions =
    ImGui.SliderDouble(
      ctx,
      "最大 Region 数",
      state.transient_max_regions,
      1,
      256,
      "%.0f"
    )

  if changed then
    state.transient_max_regions =
      math.floor(state.transient_max_regions + 0.5)
    state.config_dirty = true
  end

  changed, state.transient_replace_existing =
    ImGui.Checkbox(
      ctx,
      "替换已有瞬态建议",
      state.transient_replace_existing
    )

  if changed then
    state.config_dirty = true
  end

  ImGui.Separator(ctx)
  ImGui.Text(ctx, "响度显示")

  local loudness_changed
  loudness_changed, state.show_loudness_metrics =
    ImGui.Checkbox(
      ctx,
      "显示响度统计",
      state.show_loudness_metrics
    )

  if loudness_changed then
    state.config_dirty = true

    if state.show_loudness_metrics then
      request_loudness_analysis(selected_asset(), false)
    else
      destroy_loudness_job(state.loudness_active)
      state.loudness_active = nil
      state.loudness_queue = {}
      state.loudness_queued = {}
    end
  end

  local metric_changed
  metric_changed, state.loudness_show_i =
    ImGui.Checkbox(
      ctx,
      "LUFS-I",
      state.loudness_show_i
    )
  ImGui.SameLine(ctx)
  local changed_m
  changed_m, state.loudness_show_m =
    ImGui.Checkbox(
      ctx,
      "LUFS-M max",
      state.loudness_show_m
    )
  ImGui.SameLine(ctx)
  local changed_s
  changed_s, state.loudness_show_s =
    ImGui.Checkbox(
      ctx,
      "LUFS-S max",
      state.loudness_show_s
    )
  ImGui.SameLine(ctx)
  local changed_tp
  changed_tp, state.loudness_show_tp =
    ImGui.Checkbox(
      ctx,
      "True Peak",
      state.loudness_show_tp
    )

  if metric_changed or changed_m or changed_s or changed_tp then
    state.config_dirty = true
    request_loudness_analysis(selected_asset(), false)
  end

  if dark_button("重新分析当前素材", 160) then
    state.show_loudness_metrics = true
    state.config_dirty = true
    request_loudness_analysis(selected_asset(), true)
  end

  ImGui.Separator(ctx)
  ImGui.Text(ctx, "估算响度匹配")

  loudness_changed, state.loudness_match =
    ImGui.Checkbox(
      ctx,
      "启用估算响度匹配",
      state.loudness_match
    )

  if loudness_changed then
    state.config_dirty = true
    update_preview_parameters()
  end

  ImGui.SetNextItemWidth(ctx, 220)
  local target_changed
  target_changed, state.loudness_target_db =
    ImGui.SliderDouble(
      ctx,
      "目标响度",
      state.loudness_target_db,
      -30,
      -6,
      "%.1f dB"
    )

  if target_changed then
    state.config_dirty = true
    update_preview_parameters()
  end

  ImGui.TextDisabled(
    ctx,
    "仅影响试听，不修改源文件，也不用于交付标准化。"
  )
  ImGui.Separator(ctx)

  if dark_button("清空波形缓存", 140) then
    clear_wave_cache()
  end
end

function draw_settings_maintenance()
  settings_section_title(
    "运行环境",
    ""
  )

  if ImGui.BeginChild(
    ctx,
    "maintenance_runtime_card",
    -1,
    226,
    ImGui.ChildFlags_Borders,
    ImGui.WindowFlags_NoScrollbar
      | ImGui.WindowFlags_NoScrollWithMouse
  ) then
    about_info_row("REAPER 版本", reaper.GetAppVersion())
    about_info_row("操作系统", reaper.GetOS())
    about_info_row("ReaImGui", get_reaimgui_runtime_version())
    about_info_row(
      "SWS Extension",
      type(reaper.CF_CreatePreview) == "function"
        and "已检测"
        or "未检测"
    )
    about_info_row("试听后端", state.preview_backend)
    about_info_row("数据目录", DATA_DIR)
    about_info_row(
      "波形缓存",
      state.wave_cache_dir
        or WAVE_CACHE_DIR
    )
  end

  ImGui.EndChild(ctx)
  ImGui.Spacing(ctx)

  if dark_button("打开数据目录", 140) then
    open_folder(DATA_DIR)
  end

  ImGui.SameLine(ctx)

  if dark_button("打开文档目录", 140) then
    if directory_exists(DOCS_DIR) then
      open_folder(DOCS_DIR)
    else
      set_status(
        "文档目录不存在：" .. DOCS_DIR,
        true
      )
    end
  end

  ImGui.SameLine(ctx)

  if dark_button("复制诊断信息", 140) then
    ImGui.SetClipboardText(
      ctx,
      build_diagnostics_text()
    )
    set_status("诊断信息已复制")
  end

  ImGui.Separator(ctx)

  settings_section_title(
    "波形缓存目录",
    "可以移动已有缓存，源音频不受影响。"
  )

  if ImGui.BeginChild(
    ctx,
    "cache_directory_card",
    -1,
    112,
    ImGui.ChildFlags_Borders,
    ImGui.WindowFlags_NoScrollbar
      | ImGui.WindowFlags_NoScrollWithMouse
  ) then
    ImGui.TextDisabled(ctx, "当前缓存目录")
    ImGui.TextWrapped(
      ctx,
      state.wave_cache_dir
        or WAVE_CACHE_DIR
    )
    ImGui.TextDisabled(
      ctx,
      "默认："
        .. DEFAULT_WAVE_CACHE_DIR
    )
  end

  ImGui.EndChild(ctx)
  ImGui.Spacing(ctx)

  if dark_button("更改缓存目录…", 150) then
    prompt_wave_cache_directory()
  end

  ImGui.SameLine(ctx)

  if dark_button("打开缓存目录", 140) then
    open_folder(
      state.wave_cache_dir
        or WAVE_CACHE_DIR
    )
  end

  ImGui.SameLine(ctx)

  if dark_button("恢复默认目录", 140) then
    restore_default_wave_cache_directory()
  end

  ImGui.Separator(ctx)

  settings_section_title(
    "路径与离线来源",
    "检查缺失文件，或在素材盘符和目录变化后重新定位来源；不会移动源文件。"
  )

  if state.missing_audit then
    local session = state.missing_audit
    local completed = math.min(session.checked or 0, session.total or 0)
    local fraction = session.total > 0 and completed / session.total or 1
    ImGui.Text(
      ctx,
      string.format(
        "缺失检查 %d / %d · 已发现 %d",
        completed,
        session.total or 0,
        session.missing or 0
      )
    )
    ImGui.ProgressBar(ctx, fraction, -1, 18, string.format("%.1f%%", fraction * 100))
  else
    ImGui.TextDisabled(
      ctx,
      string.format(
        "离线来源 %d · 缺失素材 %d",
        #state.offline_roots,
        state.missing_asset_count
      )
    )

    if dark_button("检查缺失文件", 150) then
      start_missing_audit()
    end

    if state.missing_asset_count > 0 then
      ImGui.SameLine(ctx)
      if dark_button("查看缺失素材", 150) then
        state.view = "missing"
        state.active_collection_id = nil
        state.root_filter = nil
        state.library_filter_id = nil
        state.results_dirty = true
        state.settings_close_requested = true
      end
    end
  end

  for _, record in ipairs(state.offline_roots) do
    ImGui.PushID(ctx, "offline_root_" .. tostring(record.id))
    ImGui.TextDisabled(
      ctx,
      compact((record.alias ~= "" and record.alias or basename(record.path)) .. " · " .. record.path, 112)
    )
    ImGui.SameLine(ctx)
    if dark_button("重新定位…", 112) then
      relink_root(record)
    end
    ImGui.PopID(ctx)
  end

  ImGui.Separator(ctx)

  settings_section_title(
    "重复候选",
    "仅对大小相同的文件读取头部、中部和尾部采样块；结果尚未经过完整内容确认，不会修改或删除源文件。"
  )

  if state.duplicate_scan then
    local session = state.duplicate_scan
    local phase = session.phase or "fingerprints"
    local completed = 0
    local total = 0
    local label = "重复检查"
    local fraction = 0
    if phase == "sizes" then
      label = "读取文件大小"
      total = session.asset_total or 0
      completed = math.min(
        math.max(0, (session.asset_index or 1) - 1),
        total
      )
      fraction = total > 0 and completed / total or 1
    elseif phase == "fingerprints" then
      label = "采样重复候选"
      total = session.total or 0
      completed = math.min(
        math.max(0, (session.index or 1) - 1),
        total
      )
      fraction = total > 0 and completed / total or 1
    else
      label = "整理候选组"
      total = #(session.duplicate_groups or {})
      local sort_job = session.sort_job
      if sort_job and sort_job.stage == "filter" then
        completed = math.min(
          math.max(0, (sort_job.index or 1) - 1),
          sort_job.total or total
        )
        total = sort_job.total or total
        fraction = total > 0 and completed / total * 0.25 or 0.25
      elseif sort_job and sort_job.stage == "sort_chunks" then
        completed = math.min(
          math.max(0, (sort_job.sort_index or 1) - 1),
          total
        )
        fraction = 0.25
          + (total > 0 and completed / total * 0.25 or 0.25)
      elseif sort_job and sort_job.stage == "merge" then
        completed = total
        fraction = 0.75
      else
        completed = total
        fraction = 0.95
      end
    end
    ImGui.Text(
      ctx,
      string.format(
        "%s %d / %d · 失败 %d",
        label,
        completed,
        total,
        session.failed or 0
      )
    )
    ImGui.ProgressBar(ctx, fraction, -1, 18, string.format("%.1f%%", fraction * 100))
  elseif state.duplicate_confirmation then
    local session = state.duplicate_confirmation
    ImGui.Text(ctx, string.format(
      "完整确认第 %d / %d 组 · 当前组已处理 %d",
      session.group_index,
      #session.groups,
      math.max(0, session.asset_index - 1)
    ))
    local fraction = #session.groups > 0
      and math.min(1, (session.group_index - 1) / #session.groups)
      or 1
    ImGui.ProgressBar(ctx, fraction, -1, 18, string.format("%.1f%%", fraction * 100))
  else
    ImGui.TextDisabled(
      ctx,
      string.format(
        "候选组 %d · 涉及素材 %d",
        state.duplicate_group_count,
        state.duplicate_asset_count
      )
    )
    if dark_button("检查重复候选", 150) then
      start_duplicate_scan()
    end
    if state.duplicate_asset_count > 0 then
      ImGui.SameLine(ctx)
      if dark_button("查看重复候选", 150) then
        state.view = "duplicates"
        state.active_collection_id = nil
        state.root_filter = nil
        state.library_filter_id = nil
        state.results_dirty = true
        state.settings_close_requested = true
      end
      ImGui.SameLine(ctx)
      if dark_button("完整确认候选", 150) then
        start_duplicate_confirmation()
      end
    end
    ImGui.TextDisabled(ctx, string.format(
      "已确认相同 %d · 读取失败 %d",
      state.duplicate_confirmed_asset_count,
      state.duplicate_confirmation_failure_count
    ))
  end

  ImGui.Separator(ctx)

  refresh_current_project_binding()
  settings_section_title(
    "当前 REAPER 工程",
    "记录插入和 Transfer 后插入的素材，并可自动收集到绑定的项目素材箱。"
  )
  about_info_row("工程", state.current_project_name or "未保存工程")
  if state.current_project_path ~= "" then
    ImGui.TextDisabled(ctx, compact(state.current_project_path, 112))
  end

  local collect_changed
  collect_changed, state.auto_collect_project_usage =
    ImGui.Checkbox(
      ctx,
      "自动将插入素材加入当前工程素材箱",
      state.auto_collect_project_usage
    )
  if collect_changed then
    state.config_dirty = true
  end

  if state.current_project_path == "" then
    ImGui.TextDisabled(ctx, "请先保存当前 REAPER 工程，再建立绑定。")
  elseif not state.current_project_bin_id then
    if dark_button("创建并绑定当前工程素材箱", 230) then
      ensure_current_project_bin(true)
    end
  else
    local project_bin = state.collection_by_id[state.current_project_bin_id]
    ImGui.TextDisabled(
      ctx,
      "已绑定：" .. (project_bin and project_bin.name or state.current_project_name)
    )
  end

  local usage_bucket = project_usage_bucket(state.current_project_path, false)
  if usage_bucket then
    ImGui.SameLine(ctx)
    if dark_button("查看当前工程已用素材", 190) then
      state.view = "project_used"
      state.active_collection_id = nil
      state.root_filter = nil
      state.library_filter_id = nil
      state.results_dirty = true
      state.settings_close_requested = true
    end
  end

  ImGui.Separator(ctx)

  settings_section_title(
    "可靠性与恢复",
    "失败任务、数据备份和缓存检查均不修改源音频。"
  )

  local failed_count = failed_task_count()
  ImGui.Text(
    ctx,
    string.format("失败任务：%d", failed_count)
  )

  if failed_count > 0 then
    local shown = 0

    for _, task in pairs(state.failed_tasks) do
      ImGui.TextDisabled(
        ctx,
        compact(
          basename(task.path)
            .. " · "
            .. tostring(task.stage)
            .. " · "
            .. tostring(task.reason),
          100
        )
      )
      shown = shown + 1
      if shown >= 5 then break end
    end

    if dark_button("重试全部失败任务", 170) then
      retry_failed_tasks()
    end

    ImGui.SameLine(ctx)

    if dark_button("清除失败记录", 140) then
      state.failed_tasks = {}
      state.failed_tasks_dirty = true
      save_failed_tasks()
      set_status("失败任务记录已清除")
    end
  else
    ImGui.TextDisabled(ctx, "当前没有待处理的失败任务。")
  end

  ImGui.Spacing(ctx)

  local auto_backup_changed
  auto_backup_changed, state.auto_backup =
    ImGui.Checkbox(ctx, "每天自动备份一次数据", state.auto_backup)

  if auto_backup_changed then
    state.config_dirty = true
  end

  ImGui.SetNextItemWidth(ctx, 220)
  local keep_changed
  keep_changed, state.backup_keep_count =
    ImGui.SliderDouble(
      ctx,
      "保留备份数量",
      state.backup_keep_count,
      1,
      30,
      "%.0f"
    )

  if keep_changed then
    state.backup_keep_count = math.floor(state.backup_keep_count + 0.5)
    state.config_dirty = true
  end

  if dark_button("立即创建备份", 150) then
    if state.config_dirty then save_config() end
    if state.libraries_dirty then save_libraries() end
    if state.db_dirty and not state.scan and not state.import_session then save_database_changes() end
    if state.collections_dirty then save_collections() end
    if state.searches_dirty then save_saved_searches() end
    if state.history_dirty then save_history() end
    if state.regions_dirty then save_regions() end
    if state.loudness_dirty then save_loudness_cache() end
    if state.failed_tasks_dirty then save_failed_tasks() end
    if state.project_usage_dirty then save_project_usage() end
    create_data_backup("manual", false)
  end

  ImGui.SameLine(ctx)

  if dark_button("打开备份目录", 140) then
    open_folder(BACKUP_DIR)
  end

  ImGui.SameLine(ctx)

  if dark_button("恢复最近备份…", 150) then
    restore_latest_data_backup()
  end

  ImGui.Spacing(ctx)

  if state.cache_verify_session then
    local session = state.cache_verify_session
    local completed = math.min(session.index - 1, session.total)
    local fraction = session.total > 0 and completed / session.total or 1
    ImGui.Text(
      ctx,
      string.format(
        "缓存检查 %d / %d · 有效 %d · 损坏 %d",
        completed,
        session.total,
        session.valid,
        session.invalid
      )
    )
    ImGui.ProgressBar(ctx, fraction, -1, 18, string.format("%.1f%%", fraction * 100))
  elseif dark_button("检查波形缓存完整性", 190) then
    start_wave_cache_verification()
  end

  ImGui.TextDisabled(
    ctx,
    "损坏缓存会移入 cache_quarantine；需要时可从源音频重新生成。"
  )

  ImGui.Separator(ctx)

  settings_section_title(
    "维护操作",
    "重建和重置不会删除硬盘中的源音频文件。"
  )

  if dark_button("清空波形缓存", 140) then
    clear_wave_cache()
  end

  ImGui.SameLine(ctx)

  if dark_button("重置界面设置", 140) then
    reset_interface_settings()
  end

  ImGui.SameLine(ctx)

  if dark_button("重建数据库", 130) then
    reset_database_keep_roots()
  end

  ImGui.SameLine(ctx)

  if dark_button("恢复出厂", 110) then
    factory_reset()
  end

  ImGui.Spacing(ctx)

  ImGui.TextWrapped(
    ctx,
    "重建数据库会保留音效库路径并重新扫描；恢复出厂会删除 PsyReaSFX "
      .. "的配置、集合、历史、索引和当前缓存，但不会删除源音频文件。"
  )
end

function settings_nav_item(key, label, description)
  local selected =
    state.settings_tab == key

  local width =
    select(
      1,
      ImGui.GetContentRegionAvail(ctx)
    )

  local height = 58
  local x, y =
    ImGui.GetCursorScreenPos(ctx)

  ImGui.InvisibleButton(
    ctx,
    "settings_nav_" .. key,
    width,
    height
  )

  local clicked =
    ImGui.IsItemClicked(ctx, 0)

  local hovered =
    ImGui.IsItemHovered(ctx)

  if clicked then
    state.settings_tab = key
  end

  local draw_list =
    ImGui.GetWindowDrawList(ctx)

  ImGui.DrawList_AddRectFilled(
    draw_list,
    x,
    y,
    x + width,
    y + height,
    selected
      and rgba_with_alpha(COLOR.selected, 0x24)
      or hovered
        and COLOR.button_hover
        or 0x00000000,
    UI_METRIC.radius_small
  )

  if selected then
    ImGui.DrawList_AddRectFilled(
      draw_list,
      x,
      y + 8,
      x + 4,
      y + height - 8,
      COLOR.selected,
      2
    )
  end

  draw_clipped_text(
    draw_list,
    x + 14,
    y + 10,
    selected
      and COLOR.selected_text
      or COLOR.header_text,
    translate_ui_text(label),
    x + 10,
    y + 5,
    x + width - 10,
    y + 31
  )

  draw_clipped_text(
    draw_list,
    x + 14,
    y + 34,
    COLOR.dim,
    translate_ui_text(description or ""),
    x + 10,
    y + 29,
    x + width - 10,
    y + height - 6
  )
end

function draw_settings_popup()
  ImGui.SetNextWindowSize(
    ctx,
    980,
    700,
    ImGui.Cond_Appearing
  )

  if not ImGui.BeginPopupModal(
    ctx,
    "设置##reasfx",
    true,
    ImGui.WindowFlags_NoScrollbar
      | ImGui.WindowFlags_NoScrollWithMouse
  ) then
    return
  end

  local width, height =
    ImGui.GetContentRegionAvail(ctx)

  local nav_width = 226
  local footer_height = 42

  if ImGui.BeginChild(
    ctx,
    "settings_navigation",
    nav_width,
    height - footer_height,
    ImGui.ChildFlags_Borders,
    ImGui.WindowFlags_NoScrollbar
  ) then
    ImGui.TextColored(
      ctx,
      COLOR.header_text,
      "设置中心"
    )

    ImGui.TextDisabled(
      ctx,
      SCRIPT_NAME .. " " .. VERSION
    )

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    settings_nav_item("general", "常规", "语言、面板与插入")
    settings_nav_item("appearance", "外观", "预设、颜色与 Artwork")
    settings_nav_item("waveforms", "波形", "精度、瞬态与响度")
    settings_nav_item("transfer", "传输", "处理、命名与导出")
    settings_nav_item("maintenance", "维护", "环境、缓存与重建")
    settings_nav_item("about", "关于", "版本、版权与项目主页")
  end

  ImGui.EndChild(ctx)
  ImGui.SameLine(ctx)

  if ImGui.BeginChild(
    ctx,
    "settings_content",
    width - nav_width - 8,
    height - footer_height,
    ImGui.ChildFlags_Borders,
    ImGui.WindowFlags_AlwaysVerticalScrollbar
  ) then
    local page_title = {
      general = "常规",
      appearance = "外观",
      waveforms = "波形",
      transfer = "Transfer 设置",
      maintenance = "维护",
      about = "关于",
    }

    ImGui.TextColored(
      ctx,
      COLOR.header_text,
      page_title[state.settings_tab]
        or "常规"
    )

    ImGui.Separator(ctx)

    if state.settings_tab == "appearance" then
      draw_settings_appearance()
    elseif state.settings_tab == "waveforms" then
      draw_settings_waveforms()
    elseif state.settings_tab == "transfer" then
      draw_settings_transfer()
    elseif state.settings_tab == "maintenance" then
      draw_settings_maintenance()
    elseif state.settings_tab == "about" then
      draw_settings_about()
    else
      draw_settings_general()
    end
  end

  ImGui.EndChild(ctx)
  ImGui.Separator(ctx)

  local button_width = 132

  ImGui.SetCursorPosX(
    ctx,
    math.max(
      0,
      width - button_width
    )
  )

  if dark_button("保存并关闭", button_width) then
    save_config()
    if state.db_dirty then save_database_changes() end
    ImGui.CloseCurrentPopup(ctx)
  end

  if state.settings_close_requested then
    state.settings_close_requested = false
    ImGui.CloseCurrentPopup(ctx)
  end

  ImGui.EndPopup(ctx)
end

----------------------------------------------------------------
-- Keyboard
----------------------------------------------------------------

function keyboard()
  if state.keyboard_consumed
    or state.parameter_edit
    or ImGui.IsAnyItemActive(ctx) then
    return
  end

  local mods = ImGui.GetKeyMods(ctx)
  local ctrl =
    (mods & ImGui.Mod_Ctrl) ~= 0

  if ctrl
    and ImGui.IsKeyPressed(
      ctx,
      ImGui.Key_A,
      false
    ) then
    select_all_results()
    return
  end

  if ctrl
    and ImGui.IsKeyPressed(
      ctx,
      ImGui.Key_F,
      false
    ) then
    state.focus_search = true
    return
  end

  if ctrl
    and ImGui.IsKeyPressed(
      ctx,
      ImGui.Key_R,
      false
    ) then
    start_scan("增量扫描")
    return
  end

  if ctrl
    and ImGui.IsKeyPressed(
      ctx,
      ImGui.Key_T,
      false
    ) then
    state.transfer_popup_requested = 2
    return
  end

  if ImGui.IsKeyPressed(
    ctx,
    ImGui.Key_F9,
    false
  ) then
    state.sidebar_visible =
      not state.sidebar_visible
    state.config_dirty = true
    return
  end

  if ImGui.IsKeyPressed(
    ctx,
    ImGui.Key_F10,
    false
  ) then
    state.inspector_visible =
      not state.inspector_visible
    state.config_dirty = true
    return
  end

  if ImGui.IsKeyPressed(
    ctx,
    ImGui.Key_F11,
    false
  ) then
    local focus_mode =
      not state.sidebar_visible
      and not state.inspector_visible

    if focus_mode then
      state.sidebar_visible = true
      state.inspector_visible = true
    else
      state.sidebar_visible = false
      state.inspector_visible = false
    end

    state.config_dirty = true
    return
  end

  if ImGui.IsKeyPressed(
    ctx,
    ImGui.Key_UpArrow,
    false
  ) then
    select_result(
      math.max(
        1,
        state.selected_index - 1
      )
    )
  elseif ImGui.IsKeyPressed(
    ctx,
    ImGui.Key_DownArrow,
    false
  ) then
    select_result(
      math.min(
        #state.results,
        math.max(
          1,
          state.selected_index + 1
        )
      )
    )
  elseif ImGui.IsKeyPressed(
    ctx,
    ImGui.Key_Space,
    false
  ) then
    if state.preview then
      request_preview_stop()
    else
      play_preview(nil, nil, true)
    end
  elseif ImGui.IsKeyPressed(
    ctx,
    ImGui.Key_Enter,
    false
  ) then
    if selected_count() > 1 then
      insert_selected_stack(0, 1)
    else
      insert_asset(nil, ctrl, false)
    end
  elseif ImGui.IsKeyPressed(
    ctx,
    ImGui.Key_F,
    false
  ) then
    local assets = selected_assets()

    if #assets <= 1 then
      toggle_favorite(selected_asset())
    else
      local all_favorite = true

      for _, asset in ipairs(assets) do
        if not state.favorites[path_key(asset.path)] then
          all_favorite = false
          break
        end
      end

      for _, asset in ipairs(assets) do
        state.favorites[path_key(asset.path)] =
          all_favorite and nil or true
      end

      state.config_dirty = true
      state.results_dirty = true
      set_status(
        all_favorite
          and "已取消所选素材收藏"
          or "已收藏所选素材"
      )
    end
  elseif ImGui.IsKeyPressed(
    ctx,
    ImGui.Key_M,
    false
  ) then
    local assets = selected_assets()

    if #assets == 0 then
      return
    end

    local all_marked = true

    for _, asset in ipairs(assets) do
      if not asset.marked then
        all_marked = false
        break
      end
    end

    set_assets_marked(
      assets,
      not all_marked
    )
  elseif ImGui.IsKeyPressed(
    ctx,
    ImGui.Key_L,
    false
  ) then
    state.loop = not state.loop
    update_preview_parameters()
  end
end

----------------------------------------------------------------
-- Main window
----------------------------------------------------------------

function push_theme()
  apply_ui_density_metrics()
  apply_theme_palette()
  apply_surface_style()

  local colors = {
    { ImGui.Col_WindowBg, COLOR.window },
    { ImGui.Col_TitleBg, COLOR.title },
    { ImGui.Col_TitleBgActive, COLOR.title_active },
    { ImGui.Col_TitleBgCollapsed, COLOR.title },
    { ImGui.Col_ChildBg, COLOR.panel },
    { ImGui.Col_PopupBg, COLOR.panel_alt },
    { ImGui.Col_Border, COLOR.grid },
    { ImGui.Col_Text, COLOR.text },
    { ImGui.Col_TextDisabled, COLOR.dim },
    { ImGui.Col_FrameBg, COLOR.button },
    { ImGui.Col_FrameBgHovered, COLOR.button_hover },
    { ImGui.Col_FrameBgActive, COLOR.button_hover },
    { ImGui.Col_Header, COLOR.selected },
    { ImGui.Col_HeaderHovered, COLOR.selected },
    { ImGui.Col_HeaderActive, COLOR.selected },
    { ImGui.Col_CheckMark, COLOR.border },
    { ImGui.Col_SliderGrab, COLOR.border },
    { ImGui.Col_SliderGrabActive, COLOR.selected_text },
    { ImGui.Col_ScrollbarBg, COLOR.window },
    { ImGui.Col_ScrollbarGrab, 0x55575DFF },
    { ImGui.Col_ScrollbarGrabHovered, 0x777A82FF },
  }

  for _, item in ipairs(colors) do
    ImGui.PushStyleColor(
      ctx,
      item[1],
      item[2]
    )
  end

  local profile =
    UI_DENSITY_PROFILES[state.ui_density]
    or UI_DENSITY_PROFILES.balanced

  ImGui.PushStyleVar(
    ctx,
    ImGui.StyleVar_WindowRounding,
    profile.radius
  )

  ImGui.PushStyleVar(
    ctx,
    ImGui.StyleVar_ChildRounding,
    profile.radius
  )

  ImGui.PushStyleVar(
    ctx,
    ImGui.StyleVar_FrameRounding,
    profile.radius_small
  )

  ImGui.PushStyleVar(
    ctx,
    ImGui.StyleVar_ItemSpacing,
    profile.item_x,
    profile.item_y
  )

  return #colors, 4
end

function pop_theme(color_count, var_count)
  ImGui.PopStyleVar(ctx, var_count)
  ImGui.PopStyleColor(ctx, color_count)
end

function draw_inspector_splitter(height)
  ImGui.InvisibleButton(
    ctx,
    "inspector_width_splitter",
    PANEL_GAP,
    height
  )

  if ImGui.IsItemHovered(ctx)
    or ImGui.IsItemActive(ctx) then
    ImGui.SetMouseCursor(
      ctx,
      ImGui.MouseCursor_ResizeEW
    )
  end

  if ImGui.IsItemActive(ctx)
    and not state.inspector_resize then
    state.inspector_resize = {
      mouse_x =
        select(1, ImGui.GetMousePos(ctx)),
      width = state.inspector_width,
    }
  end

  if ImGui.IsItemActive(ctx)
    and state.inspector_resize then
    mark_interaction()

    local mouse_x =
      select(1, ImGui.GetMousePos(ctx))

    state.inspector_width =
      clamp(
        state.inspector_resize.width
          + state.inspector_resize.mouse_x
          - mouse_x,
        240,
        480
      )

    state.config_dirty = true
  end

  if state.inspector_resize
    and ImGui.IsMouseReleased(ctx, 0) then
    state.inspector_resize = nil
  end
end

function draw_main()
  -- 每帧重置，只有当前真正悬停的控件可以登记一个提示。
  state.tooltip_pending_text = nil
  state.keyboard_consumed = false

  ImGui.SetNextWindowSize(
    ctx,
    1360,
    840,
    ImGui.Cond_FirstUseEver
  )

  local color_count, var_count =
    push_theme()

  local visible
  visible, state.open =
    ImGui.Begin(
      ctx,
      SCRIPT_NAME
        .. " "
        .. VERSION
        .. "###PsyReaSFX",
      state.open,
      ImGui.WindowFlags_NoCollapse
        | ImGui.WindowFlags_NoScrollbar
        | ImGui.WindowFlags_NoScrollWithMouse
    )

  if visible then
    -- PsyReaSFX owns Space and the other browser shortcuts while its main
    -- window (or any child panel) is focused. Explicit capture prevents the
    -- same Space press from also reaching REAPER's global transport action.
    if ImGui.IsWindowFocused(
      ctx,
      ImGui.FocusedFlags_RootAndChildWindows
    ) then
      ImGui.SetNextFrameWantCaptureKeyboard(
        ctx,
        true
      )
    end

    draw_toolbar()
    draw_sub_toolbar()
    draw_path_condition_bar()
    draw_import_progress()
    ImGui.Separator(ctx)

    local width, height =
      ImGui.GetContentRegionAvail(ctx)

    local content_height = math.max(170, height)

    local render_sidebar = state.sidebar_visible
    local render_inspector = state.inspector_visible

    local sidebar_width =
      render_sidebar
      and clamp(
        width * 0.15,
        SIDEBAR_MIN_W,
        SIDEBAR_W
      )
      or 0

    local inspector_width =
      render_inspector
      and clamp(
        state.inspector_width,
        INSPECTOR_MIN_W,
        math.max(
          INSPECTOR_MIN_W,
          width * 0.30
        )
      )
      or 0

    local function current_gap_total()
      local gap = 0

      if render_sidebar then
        gap = gap + PANEL_GAP
      end

      if render_inspector then
        gap = gap + PANEL_GAP
      end

      return gap
    end

    -- 窗口变窄时先压缩侧栏，再临时折叠右栏和左栏。
    -- 这里只影响本帧布局，不修改用户保存的面板开关。
    local center_width =
      width
        - sidebar_width
        - inspector_width
        - current_gap_total()

    if center_width < CENTER_MIN_W
      and render_inspector then
      local deficit = CENTER_MIN_W - center_width
      local reducible =
        math.max(
          0,
          inspector_width - INSPECTOR_MIN_W
        )
      local reduction = math.min(deficit, reducible)
      inspector_width = inspector_width - reduction
      center_width = center_width + reduction
    end

    if center_width < CENTER_MIN_W
      and render_sidebar then
      local deficit = CENTER_MIN_W - center_width
      local reducible =
        math.max(
          0,
          sidebar_width - SIDEBAR_MIN_W
        )
      local reduction = math.min(deficit, reducible)
      sidebar_width = sidebar_width - reduction
      center_width = center_width + reduction
    end

    state.layout_notice = ""

    if center_width < CENTER_MIN_W
      and render_inspector then
      render_inspector = false
      inspector_width = 0
      center_width =
        width
          - sidebar_width
          - current_gap_total()
      state.layout_notice =
        "窗口较窄：右侧元数据面板已临时折叠"
    end

    if center_width < CENTER_MIN_W
      and render_sidebar then
      render_sidebar = false
      sidebar_width = 0
      center_width = width
      state.layout_notice =
        "窗口较窄：左右面板已临时折叠"
    end

    center_width =
      math.max(220, center_width)

    if render_sidebar then
      if begin_module(
        "aether_sidebar",
        sidebar_width,
        content_height,
        true
      ) then
        draw_sidebar()
      end

      end_module()
      ImGui.SameLine(ctx)
    end

    if ImGui.BeginChild(
      ctx,
      "center_workspace",
      center_width,
      content_height,
      0,
      ImGui.WindowFlags_NoScrollbar
        | ImGui.WindowFlags_NoScrollWithMouse
    ) then
      local center_available_w,
        center_available_h =
          ImGui.GetContentRegionAvail(ctx)

      -- 运行时尺寸必须严格相加等于可用高度。旧算法在矮窗口中
      -- 同时强制列表 >= 120 和预览 >= 220，曾导致底部越界裁切。
      local panel_space =
        math.max(
          2,
          center_available_h - BOTTOM_SPLITTER_H
        )

      local runtime_min_list =
        math.min(
          120,
          math.max(24, panel_space * 0.34),
          panel_space * 0.55
        )

      local maximum_bottom =
        math.max(
          1,
          math.min(
            BOTTOM_MAX_H,
            panel_space - runtime_min_list
          )
        )

      local runtime_min_bottom =
        math.min(
          BOTTOM_MIN_H,
          maximum_bottom
        )

      local bottom_height =
        clamp(
          state.bottom_panel_height,
          runtime_min_bottom,
          maximum_bottom
        )

      local list_height =
        math.max(1, panel_space - bottom_height)

      if begin_module(
        "results_module",
        center_available_w,
        list_height,
        false,
        true
      ) then
        draw_results()
      end

      end_module()

      draw_bottom_splitter(
        center_available_w,
        center_available_h
      )

      if begin_module(
        "bottom_module",
        center_available_w,
        bottom_height,
        false,
        true
      ) then
        draw_bottom(selected_asset())
      end

      end_module()
    end

    ImGui.EndChild(ctx)

    if render_inspector then
      ImGui.SameLine(ctx)
      draw_inspector_splitter(content_height)
      ImGui.SameLine(ctx)

      if begin_module(
        "metadata_inspector",
        inspector_width,
        content_height,
        false
      ) then
        draw_metadata_inspector()
      end

      end_module()
    end

    draw_help_popup()
    draw_transient_detection_popup()
    draw_transfer_popup()
    draw_settings_popup()
    draw_folder_drop_choice_popup()
    keyboard()
    process_external_drag()
    draw_tooltip_overlay()

    ImGui.End(ctx)
  end

  pop_theme(color_count, var_count)
end

----------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------

function autosave()
  if state.persistence_read_only then
    return
  end

  local now = reaper.time_precise()

  if now - state.last_save
    < SAVE_INTERVAL then
    return
  end

  if state.config_dirty then
    save_config()
  end

  if state.libraries_dirty then
    save_libraries()
  end

  if state.db_dirty
    and not state.scan
    and not state.import_session
    and not state.asset_binding_refresh then
    save_database_changes()
  end

  if state.collections_dirty then
    save_collections()
  end

  if state.searches_dirty then
    save_saved_searches()
  end

  if state.history_dirty then
    save_history()
  end

  if state.session_played_dirty then
    save_last_played_session()
  end

  if state.regions_dirty then
    save_regions()
  end

  if state.loudness_dirty then
    save_loudness_cache()
  end

  if state.failed_tasks_dirty then
    save_failed_tasks()
  end

  if state.project_usage_dirty then
    save_project_usage()
  end

  state.last_save = now
end

function watch_folders()
  if state.persistence_read_only
    or not state.watch_enabled
    or state.scan
    or state.import_session
    or state.precache_session
    or state.transfer_running then
    return
  end

  local now = reaper.time_precise()

  if now >= state.next_watch then
    start_scan(
      "Watch Folder",
      nil,
      { silent = state.watch_silent }
    )
    state.next_watch =
      now + state.watch_interval
  end
end

function cleanup()
  Jobs.stop_accepting()
  stop_preview()
  cleanup_retired_preview_sources(true)
  if state.wave_active
    and state.wave_active.job_token then
    Jobs.cancel(state.wave_active.job_token)
    Jobs.finish(
      state.wave_active.job_token,
      true,
      "shutdown"
    )
    state.wave_active.job_token = nil
  end
  destroy_wave_job(state.wave_active)

  if state.transfer_job then
    finish_transfer_job(state.transfer_job, true)
  end

  for key in pairs(state.artwork_images) do
    release_artwork_image(key)
  end

  if state.precache_session
    and state.precache_session.current then
    destroy_wave_job(
      state.precache_session.current
    )
  end

  if state.precache_session then
    Jobs.cancel(state.precache_session.job_token)
    Jobs.finish(
      state.precache_session.job_token,
      true,
      "shutdown"
    )
  end

  if state.import_session
    and state.import_session.current
    and state.import_session.current.wave_job then
    destroy_wave_job(
      state.import_session.current.wave_job
    )
  end

  if state.import_session then
    Jobs.cancel(state.import_session.job_token)
    Jobs.finish(
      state.import_session.job_token,
      true,
      "shutdown"
    )
  elseif state.scan then
    Jobs.cancel(state.scan.job_token)
    Jobs.finish(
      state.scan.job_token,
      true,
      "shutdown"
    )
  end

  local maintenance_sessions = {
    state.cache_verify_session,
    state.missing_audit,
    state.duplicate_scan,
    state.duplicate_confirmation,
    state.relink_plan_session,
  }

  for _, session in pairs(maintenance_sessions) do
    if session and session.job_token then
      close_duplicate_confirmation_session(session)
      Jobs.cancel(session.job_token)
      Jobs.finish(
        session.job_token,
        true,
        "shutdown"
      )
    end
  end

  destroy_loudness_job(state.loudness_active)

  if state.skip_persistence_on_cleanup
    or state.persistence_read_only then
    return
  end

  if state.asset_binding_refresh
    and (state.asset_binding_refresh.changed_count or 0) > 0 then
    -- The deferred pass may have changed objects that have not reached its
    -- incremental persistence phase yet. Preserve them on an early exit.
    mark_database_snapshot_dirty()
  end

  if state.config_dirty then
    save_config()
  end

  if state.libraries_dirty then
    save_libraries()
  end

  if state.db_dirty then
    save_database_changes()
  end

  if state.collections_dirty then
    save_collections()
  end

  if state.searches_dirty then
    save_saved_searches()
  end

  if state.history_dirty then
    save_history()
  end

  if state.session_played_dirty then
    save_last_played_session()
  end

  if state.regions_dirty then
    save_regions()
  end

  if state.loudness_dirty then
    save_loudness_cache()
  end

  if state.failed_tasks_dirty then
    save_failed_tasks()
  end

  if state.project_usage_dirty then
    save_project_usage()
  end

end

reaper.atexit(cleanup)

ensure_dirs()
recover_atomic_data_files()
preflight_persistence_schemas()
if not state.persistence_read_only then
  migrate_legacy_data()
end
load_or_migrate_project_url()
load_config()
state.next_watch = reaper.time_precise() + state.watch_interval
load_or_migrate_libraries()
apply_unified_interface(false, false)
apply_wave_cache_directory(
  state.wave_cache_dir
    or DEFAULT_WAVE_CACHE_DIR
)
install_i18n_wrappers()
load_database()
refresh_all_asset_library_bindings()
load_failed_tasks()
load_backup_state()

if state.root_filter then
  local _, active_root_record =
    root_for_path(state.root_filter)

  if active_root_record then
    state.library_filter_id =
      active_root_record.library_id
  else
    state.root_filter = nil
  end
end

if state.folder_browser_open then
  ensure_folder_navigation_build()
end

load_collections()
load_project_usage()
refresh_current_project_binding()
load_saved_searches()
load_history()
load_last_played_session()

if state.restore_played_on_start then
  restore_last_session_played_highlights(true)
end

load_regions()
load_loudness_cache()
schedule_legacy_schema_migrations()
apply_surface_style()
apply_theme_palette()
apply_waveform_palette()
state.results_dirty = true

if not state.persistence_read_only
  and state.auto_backup
  and state.backup_last_date ~= os.date("%Y%m%d") then
  create_data_backup("auto", true)
end

local interrupted_scan = state.resume_scan_on_start
  and load_scan_checkpoint()
  or nil

if state.persistence_read_only then
  set_status(
    "数据格式只读保护已启用；浏览可用，扫描与保存已暂停",
    true
  )
elseif interrupted_scan then
  start_scan(
    "恢复中断扫描",
    interrupted_scan.roots,
    { force_rebuild = interrupted_scan.force_rebuild }
  )
elseif #state.roots > 0 and #state.assets == 0 then
  start_scan("首次扫描")
elseif #state.roots > 0 then
  start_import_recovery_audit()
end

function loop()
  if not state.open then
    return
  end

  process_asset_library_binding_refresh()
  process_import_recovery_audit()

  if state.transfer_running then
    -- Transfer receives the background-work budget while active. Library
    -- scanning, waveform generation, Artwork and loudness analysis resume
    -- automatically after the job finishes or is stopped.
    process_transfer_job()
  elseif state.relink_plan_session then
    process_relink_plan()
  else
    process_scan()
    process_import_session()
    process_metadata_queue()
    process_folder_navigation_build()
    process_artwork_queue()
    process_wave_cache_verification()
    process_missing_audit()
    process_duplicate_scan()
    process_duplicate_confirmation()
    process_wave_precache()
    process_wave_queue()
    process_pending_transient_detection()
    process_loudness_queue()
  end
  process_library_count_rebuild()
  cleanup_retired_preview_sources(false)
  poll_preview()
  poll_current_project_binding()
  watch_folders()
  autosave()

  if state.results_dirty or state.results_job then
    process_results_rebuild()
  end

  draw_main()

  if state.open then
    reaper.defer(loop)
  end
end

loop()
