function Jobs.begin(
  kind,
  resource,
  replace_same_kind,
  priority
)
  if not Jobs.accepting then
    return nil, "shutting_down"
  end

  local previous = Jobs.active[kind]

  if previous then
    if not replace_same_kind then
      return nil, "already_running"
    end

    previous.cancel_requested = true
    previous.state = "canceling"
  end

  for active_kind, token in pairs(Jobs.active) do
    if active_kind ~= kind
      and token.state ~= "completed"
      and token.state ~= "failed"
      and token.resource == resource then
      return nil, "resource_busy"
    end
  end

  Jobs.generation = Jobs.generation + 1

  local token = {
    kind = kind,
    resource = resource,
    generation = Jobs.generation,
    priority = tonumber(priority) or 50,
    state = "running",
    cancel_requested = false,
    started = reaper.time_precise(),
  }

  Jobs.active[kind] = token
  return token
end

function Jobs.is_current(token)
  return token
    and Jobs.active[token.kind] == token
    and not token.cancel_requested
end

function Jobs.cancel(token_or_kind)
  local token = type(token_or_kind) == "table"
    and token_or_kind
    or Jobs.active[token_or_kind]

  if not token or token.finished then
    return false
  end

  token.cancel_requested = true
  token.state = "canceling"
  return true
end

function Jobs.finish(token, success, message)
  if not token or token.finished then
    return
  end

  token.finished = reaper.time_precise()
  token.message = tostring(message or "")
  token.state = token.cancel_requested
    and "canceled"
    or success == false and "failed"
    or "completed"

  if Jobs.active[token.kind] == token then
    Jobs.active[token.kind] = nil
  end

  Jobs.history[#Jobs.history + 1] = token

  while #Jobs.history > 64 do
    table.remove(Jobs.history, 1)
  end
end

function Jobs.active_kind(kind)
  return Jobs.active[kind] ~= nil
end

function Jobs.stop_accepting()
  Jobs.accepting = false

  for _, token in pairs(Jobs.active) do
    Jobs.cancel(token)
  end
end

function extract_project_url_from_text(content)
  content = tostring(content or "")

  local patterns = {
    'local%s+PROJECT_URL%s*=%s*"([^"]+)"',
    "local%s+PROJECT_URL%s*=%s*'([^']+)'",
    "%-%-%s*@link%s+(https?://%S+)",
    "%-%-%s*@website%s+(https?://%S+)",
  }

  for _, pattern in ipairs(patterns) do
    local value =
      content:match(pattern)

    value = trim(value or "")

    if value:match("^https?://") then
      return value
    end
  end

  return ""
end

function extract_project_url_from_script(path)
  if not path or path == "" then
    return ""
  end

  return extract_project_url_from_text(
    read_small_text_file(path)
  )
end

function find_project_url_in_sibling_scripts()
  if SCRIPT_DIR == "" then
    return ""
  end

  local current_name =
    basename(SCRIPT_FILE)

  local candidates = {}
  local index = 0

  while true do
    local filename =
      reaper.EnumerateFiles(
        SCRIPT_DIR,
        index
      )

    if not filename then
      break
    end

    if filename ~= current_name
      and filename:match(
        "^PsyReaSFX.*%.lua$"
      ) then
      candidates[#candidates + 1] =
        filename
    end

    index = index + 1
  end

  table.sort(
    candidates,
    function(a, b)
      return a > b
    end
  )

  for _, filename in ipairs(candidates) do
    local value =
      extract_project_url_from_script(
        join_path(
          SCRIPT_DIR,
          filename
        )
      )

    if value ~= "" then
      return value
    end
  end

  return ""
end

function load_or_migrate_project_url()
  local hardcoded =
    trim(PROJECT_URL or "")

  if hardcoded ~= "" then
    PROJECT_URL = hardcoded
    write_project_url_file(hardcoded)
    return
  end

  local persisted =
    trim(
      read_small_text_file(
        PROJECT_URL_FILE
      )
    )

  if persisted:match("^https?://") then
    PROJECT_URL = persisted
    return
  end

  local embedded =
    extract_project_url_from_script(
      SCRIPT_FILE
    )

  if embedded == "" then
    embedded =
      find_project_url_in_sibling_scripts()
  end

  if embedded ~= "" then
    PROJECT_URL = embedded
    write_project_url_file(embedded)
  end
end

function copy_file(source_path, target_path)
  local input = io.open(source_path, "rb")

  if not input then
    return false
  end

  local content = input:read("*a")
  input:close()

  local output = io.open(target_path, "wb")

  if not output then
    return false
  end

  output:write(content or "")
  output:close()
  return true
end

function copy_file_streaming(
  source_path,
  target_path
)
  local input =
    io.open(source_path, "rb")

  if not input then
    return false
  end

  local temporary_path =
    target_path .. ".psyreasfx_tmp"

  local output =
    io.open(temporary_path, "wb")

  if not output then
    input:close()
    return false
  end

  local ok = true

  while true do
    local chunk = input:read(1024 * 1024)

    if not chunk then
      break
    end

    if not output:write(chunk) then
      ok = false
      break
    end
  end

  input:close()
  output:close()

  if not ok then
    os.remove(temporary_path)
    return false
  end

  os.remove(target_path)

  if not os.rename(
    temporary_path,
    target_path
  ) then
    os.remove(temporary_path)
    return false
  end

  return true
end

function persistent_data_files()
  return {
    CONFIG_FILE,
    LIBRARIES_FILE,
    DATABASE_FILE,
    COLLECTIONS_FILE,
    PROJECT_USAGE_FILE,
    SAVED_SEARCHES_FILE,
    HISTORY_FILE,
    LAST_PLAYED_SESSION_FILE,
    REGIONS_FILE,
    LOUDNESS_FILE,
    FAILED_TASKS_FILE,
    BACKUP_STATE_FILE,
    MIGRATION_LOG_FILE,
    PROJECT_URL_FILE,
  }
end

local PERSISTENCE_SCHEMA_MAGIC = "psyreasfx_schema"
local PERSISTENCE_SCHEMAS = {
  [CONFIG_FILE] = {
    kind = "config",
    version = 1,
    dirty_flag = "config_dirty",
  },
  [LIBRARIES_FILE] = {
    kind = "libraries",
    version = 2,
    dirty_flag = "libraries_dirty",
  },
  [DATABASE_FILE] = {
    kind = "database",
    version = 2,
    dirty_flag = "db_dirty",
  },
  [COLLECTIONS_FILE] = {
    kind = "collections",
    version = 1,
    dirty_flag = "collections_dirty",
  },
  [PROJECT_USAGE_FILE] = {
    kind = "project_usage",
    version = 1,
    dirty_flag = "project_usage_dirty",
  },
  [SAVED_SEARCHES_FILE] = {
    kind = "saved_searches",
    version = 1,
    dirty_flag = "searches_dirty",
  },
  [HISTORY_FILE] = {
    kind = "history",
    version = 1,
    dirty_flag = "history_dirty",
  },
  [LAST_PLAYED_SESSION_FILE] = {
    kind = "last_played",
    version = 1,
  },
  [REGIONS_FILE] = {
    kind = "regions",
    version = 1,
    dirty_flag = "regions_dirty",
  },
  [LOUDNESS_FILE] = {
    kind = "loudness",
    version = 1,
    dirty_flag = "loudness_dirty",
  },
  [FAILED_TASKS_FILE] = {
    kind = "failed_tasks",
    version = 1,
    dirty_flag = "failed_tasks_dirty",
  },
  [BACKUP_STATE_FILE] = {
    kind = "backup_state",
    version = 1,
  },
  [MIGRATION_LOG_FILE] = {
    kind = "migration_log",
    version = 1,
  },
}

function persistence_schema_header(kind, version)
  return table.concat(
    {
      PERSISTENCE_SCHEMA_MAGIC,
      kind,
      tostring(version),
    },
    "\t"
  ) .. "\n"
end

function write_persistence_schema(file, target_path)
  local schema = PERSISTENCE_SCHEMAS[target_path]

  if not schema then
    return true
  end

  return file:write(
    persistence_schema_header(
      schema.kind,
      schema.version
    )
  ) ~= nil
end

function is_persistence_schema_fields(fields)
  return fields
    and fields[1] == PERSISTENCE_SCHEMA_MAGIC
end

function preflight_persistence_schemas()
  state.persistence_read_only = false
  state.persistence_read_only_reason = ""
  state.persistence_schema_versions = {}
  state.persistence_schema_legacy = {}

  local problems = {}

  for target_path, schema in pairs(PERSISTENCE_SCHEMAS) do
    local file = io.open(target_path, "rb")

    if file then
      local first_line = file:read("*l") or ""
      file:close()

      local fields = split_tsv(first_line)

      if is_persistence_schema_fields(fields) then
        local kind = fields[2] or ""
        local version = tonumber(fields[3])

        if kind ~= schema.kind then
          problems[#problems + 1] = string.format(
            "%s 的数据类型为 %s，预期为 %s",
            basename(target_path),
            kind ~= "" and kind or "未知",
            schema.kind
          )
        elseif not version
          or version < 1
          or version % 1 ~= 0 then
          problems[#problems + 1] = string.format(
            "%s 的格式版本无效",
            basename(target_path)
          )
        elseif version > schema.version then
          problems[#problems + 1] = string.format(
            "%s 使用未来格式 v%d（当前支持 v%d）",
            basename(target_path),
            version,
            schema.version
          )
        else
          state.persistence_schema_versions[target_path] =
            version
        end
      else
        -- All formats published before the hardening branch are schema 0.
        -- They remain readable and are rewritten atomically after startup.
        state.persistence_schema_versions[target_path] = 0
        state.persistence_schema_legacy[target_path] = true
      end
    end
  end

  if #problems > 0 then
    state.persistence_read_only = true
    state.persistence_read_only_reason =
      table.concat(problems, "；")
    set_status(
      "检测到不兼容的数据格式，已进入只读保护："
        .. state.persistence_read_only_reason,
      true
    )
    return false
  end

  return true
end

function schedule_legacy_schema_migrations()
  if state.persistence_read_only then
    return false
  end

  local pending = {}

  for target_path, schema in pairs(PERSISTENCE_SCHEMAS) do
    local current = state.persistence_schema_versions[target_path]

    if current ~= nil
      and current < schema.version
      and target_path ~= MIGRATION_LOG_FILE then
      pending[#pending + 1] = {
        path = target_path,
        from = current,
      }
    end
  end

  if #pending == 0 then
    return true
  end

  table.sort(pending, function(a, b)
    return a.path < b.path
  end)

  if not create_data_backup("schema_migration", true) then
    state.persistence_read_only = true
    state.persistence_read_only_reason =
      "旧数据迁移前无法创建安全快照"
    set_status(
      "无法创建迁移快照，已进入只读保护",
      true
    )
    return false
  end

  local savers = {
    [CONFIG_FILE] = save_config,
    [LIBRARIES_FILE] = save_libraries,
    [DATABASE_FILE] = save_database,
    [COLLECTIONS_FILE] = save_collections,
    [PROJECT_USAGE_FILE] = save_project_usage,
    [SAVED_SEARCHES_FILE] = save_saved_searches,
    [HISTORY_FILE] = save_history,
    [LAST_PLAYED_SESSION_FILE] =
      migrate_last_played_session_schema,
    [REGIONS_FILE] = save_regions,
    [LOUDNESS_FILE] = save_loudness_cache,
    [FAILED_TASKS_FILE] = save_failed_tasks,
    [BACKUP_STATE_FILE] = save_backup_state,
  }

  for _, migration in ipairs(pending) do
    local target_path = migration.path
    local schema = PERSISTENCE_SCHEMAS[target_path]
    local saver = savers[target_path]
    local ok = true

    if schema and schema.dirty_flag then
      state[schema.dirty_flag] = true
    end

    if saver then
      ok = saver() ~= false
    end

    local logged = append_schema_migration_log(
      schema and schema.kind or basename(target_path),
      migration.from,
      schema and schema.version or 0,
      ok and "completed" or "failed"
    )

    if not logged then
      ok = false
    end

    if not ok then
      state.persistence_read_only = true
      state.persistence_read_only_reason =
        "数据格式迁移失败：" .. basename(target_path)
      set_status(
        state.persistence_read_only_reason
          .. "；已停止后续写入",
        true
      )
      return false
    end

    state.persistence_schema_legacy[target_path] = nil
    state.persistence_schema_versions[target_path] =
      schema and schema.version or 0
  end


  return true
end

function append_schema_migration_log(
  kind,
  from_version,
  to_version,
  result
)
  if state.persistence_read_only then
    return false
  end

  local existed = reaper.file_exists(MIGRATION_LOG_FILE)
  local file = io.open(MIGRATION_LOG_FILE, "ab")

  if not file then
    return false
  end

  if not existed then
    file:write(
      persistence_schema_header("migration_log", 1)
    )
  end

  file:write(
    "migration\t",
    escape_tsv(os.date("%Y-%m-%d %H:%M:%S")),
    "\t",
    escape_tsv(kind or "unknown"),
    "\t",
    tostring(from_version or 0),
    "\t",
    tostring(to_version or 0),
    "\t",
    escape_tsv(result or "unknown"),
    "\n"
  )
  file:flush()
  file:close()
  return true
end

-- Persistent TSV/config files used to be written directly to their final
-- path. A REAPER crash or power loss during file:write() could therefore
-- replace valid data with a truncated file. Keep the previous generation as
-- a short-lived rollback and only expose a fully closed temporary file.
function atomic_file_writer(target_path)
  if state.persistence_read_only then
    return nil,
      state.persistence_read_only_reason ~= ""
        and state.persistence_read_only_reason
        or "persistence is read-only"
  end

  local temporary_path = target_path .. ".tmp"
  local backup_path = target_path .. ".bak"
  os.remove(temporary_path)

  local raw, open_error = io.open(temporary_path, "wb")
  if not raw then
    return nil, open_error
  end

  local writer = {
    raw = raw,
    target_path = target_path,
    temporary_path = temporary_path,
    backup_path = backup_path,
    failed = false,
    failure = nil,
    closed = false,
  }

  function writer:write(...)
    if self.closed or self.failed then
      return nil, self.failure or "writer is closed"
    end

    if state.persistence_fault_injection == "write" then
      self.failed = true
      self.failure = "injected write failure"
      return nil, self.failure
    end

    local ok, message = self.raw:write(...)
    if not ok then
      self.failed = true
      self.failure = message or "write failed"
      return nil, self.failure
    end
    return self
  end

  function writer:close()
    if self.closed then
      return not self.failed, self.failure
    end
    self.closed = true

    local flushed, flush_error = self.raw:flush()
    local closed, close_error = self.raw:close()
    if self.failed or not flushed or not closed then
      os.remove(self.temporary_path)
      self.failure = self.failure or flush_error or close_error
        or "could not finish temporary file"
      return false, self.failure
    end

    if state.persistence_fault_injection == "after_close" then
      os.remove(self.temporary_path)
      return false, "injected failure after temporary close"
    end

    local had_original = reaper.file_exists(self.target_path)
    os.remove(self.backup_path)
    if had_original
      and not os.rename(self.target_path, self.backup_path) then
      os.remove(self.temporary_path)
      return false, "could not preserve previous file"
    end

    if state.persistence_fault_injection == "after_backup" then
      if had_original then
        os.rename(self.backup_path, self.target_path)
      end
      os.remove(self.temporary_path)
      return false, "injected failure after backup"
    end

    if not os.rename(self.temporary_path, self.target_path) then
      if had_original then
        os.rename(self.backup_path, self.target_path)
      end
      os.remove(self.temporary_path)
      return false, "could not install completed file"
    end

    os.remove(self.backup_path)
    return true
  end

  return writer
end

function recover_atomic_data_files()
  local files = persistent_data_files()
  files[#files + 1] = SCAN_CHECKPOINT_FILE
  for _, target_path in ipairs(files) do
    local backup_path = target_path .. ".bak"
    local temporary_path = target_path .. ".tmp"

    if not reaper.file_exists(target_path)
      and reaper.file_exists(backup_path) then
      os.rename(backup_path, target_path)
    elseif reaper.file_exists(target_path) then
      os.remove(backup_path)
    end

    -- A .tmp without a rollback may have been interrupted while writing and
    -- is never trusted as user data.
    os.remove(temporary_path)
  end
end

function remove_shallow_directory(path)
  while true do
    local filename = reaper.EnumerateFiles(path, 0)

    if not filename then
      break
    end

    os.remove(join_path(path, filename))
  end

  return os.remove(path)
end

function save_backup_state()
  ensure_dirs()

  local file = atomic_file_writer(BACKUP_STATE_FILE)

  if not file then
    return false
  end

  write_persistence_schema(file, BACKUP_STATE_FILE)
  file:write("last_date\t", escape_tsv(state.backup_last_date or ""), "\n")
  return file:close()
end

function load_backup_state()
  local file = io.open(BACKUP_STATE_FILE, "rb")

  if not file then
    return
  end

  for line in file:lines() do
    local fields = split_tsv(line)

    if fields[1] == "last_date" then
      state.backup_last_date = fields[2] or ""
    end
  end

  file:close()
end

function backup_directories()
  local result = {}
  local index = 0

  while true do
    local name = reaper.EnumerateSubdirectories(BACKUP_DIR, index)

    if not name then
      break
    end

    if name:match("^%d%d%d%d%d%d%d%d_%d%d%d%d%d%d") then
      result[#result + 1] = name
    end

    index = index + 1
  end

  table.sort(result, function(a, b) return a > b end)
  return result
end

function prune_data_backups()
  local names = backup_directories()
  local keep = clamp(math.floor(state.backup_keep_count or 7), 1, 30)

  for index = keep + 1, #names do
    remove_shallow_directory(join_path(BACKUP_DIR, names[index]))
  end
end

function create_data_backup(reason, quiet)
  ensure_dirs()

  local date_key = os.date("%Y%m%d")
  local directory_name = os.date("%Y%m%d_%H%M%S")
    .. "_"
    .. (reason == "auto" and "auto" or "manual")
  local directory = join_path(BACKUP_DIR, directory_name)

  local suffix = 2
  while directory_exists(directory) do
    directory_name = os.date("%Y%m%d_%H%M%S")
      .. "_"
      .. (reason == "auto" and "auto" or "manual")
      .. "_"
      .. tostring(suffix)
    directory = join_path(BACKUP_DIR, directory_name)
    suffix = suffix + 1
  end

  if reaper.RecursiveCreateDirectory(directory, 0) <= 0 then
    if not quiet then
      set_status("无法创建数据备份目录", true)
    end
    return false
  end

  local copied = 0

  for _, source_path in ipairs(persistent_data_files()) do
    if reaper.file_exists(source_path) then
      if copy_file_streaming(
        source_path,
        join_path(directory, basename(source_path))
      ) then
        copied = copied + 1
      end
    end
  end

  local manifest = io.open(join_path(directory, "manifest.tsv"), "wb")

  if manifest then
    manifest:write("version\t", VERSION, "\n")
    manifest:write("created\t", os.date("%Y-%m-%d %H:%M:%S"), "\n")
    manifest:write("reason\t", reason or "manual", "\n")
    manifest:write("files\t", tostring(copied), "\n")
    manifest:close()
  end

  if copied <= 0 then
    remove_shallow_directory(directory)
    if not quiet then
      set_status("没有可备份的数据文件", true)
    end
    return false
  end

  state.backup_last_date = date_key
  save_backup_state()
  prune_data_backups()

  if not quiet then
    set_status("数据备份已创建：" .. directory_name)
  end

  return true
end

function restore_latest_data_backup()
  local names = backup_directories()
  local name = names[1]

  if not name then
    set_status("没有可恢复的数据备份", true)
    return
  end

  local answer = reaper.MB(
    "将恢复最近的数据备份：\n\n"
      .. name
      .. "\n\n恢复后 PsyReaSFX 会关闭，请重新运行脚本。继续吗？",
    SCRIPT_NAME,
    4
  )

  if answer ~= 6 then
    return
  end

  local directory = join_path(BACKUP_DIR, name)
  local restored = 0

  for _, target_path in ipairs(persistent_data_files()) do
    local source_path = join_path(directory, basename(target_path))

    if reaper.file_exists(source_path)
      and copy_file_streaming(source_path, target_path) then
      restored = restored + 1
    end
  end

  if restored <= 0 then
    set_status("备份中没有可恢复的数据", true)
    return
  end

  state.skip_persistence_on_cleanup = true
  state.open = false
  reaper.MB(
    "已恢复 " .. tostring(restored) .. " 个数据文件。\n\n请重新运行 PsyReaSFX。",
    SCRIPT_NAME,
    0
  )
end

function write_scan_checkpoint(scan, phase)
  if not scan then
    return
  end

  ensure_dirs()
  local file = atomic_file_writer(SCAN_CHECKPOINT_FILE)

  if not file then
    return
  end

  file:write("version\t1\n")
  file:write("phase\t", escape_tsv(phase or "scan"), "\n")
  file:write("reason\t", escape_tsv(scan.reason or "扫描"), "\n")
  file:write("files\t", tostring(scan.files or 0), "\n")
  file:write("directories\t", tostring(scan.directories or 0), "\n")

  for _, root in ipairs(scan.roots or {}) do
    file:write("root\t", escape_tsv(root), "\n")
  end

  file:close()
end

function clear_scan_checkpoint()
  os.remove(SCAN_CHECKPOINT_FILE)
end

function load_scan_checkpoint()
  local file = io.open(SCAN_CHECKPOINT_FILE, "rb")

  if not file then
    return nil
  end

  local checkpoint = { roots = {}, reason = "恢复中断扫描" }

  for line in file:lines() do
    local fields = split_tsv(line)

    if fields[1] == "root" and fields[2] and fields[2] ~= "" then
      checkpoint.roots[#checkpoint.roots + 1] = normalize_slashes(fields[2])
    elseif fields[1] == "reason" and fields[2] and fields[2] ~= "" then
      checkpoint.reason = fields[2]
    end
  end

  file:close()

  if #checkpoint.roots == 0 then
    clear_scan_checkpoint()
    return nil
  end

  return checkpoint
end

function load_failed_tasks()
  state.failed_tasks = {}
  local file = io.open(FAILED_TASKS_FILE, "rb")

  if not file then
    return
  end

  for line in file:lines() do
    local fields = split_tsv(line)
    local path = is_persistence_schema_fields(fields)
      and ""
      or fields[1] or ""

    if path ~= "" then
      state.failed_tasks[path_key(path)] = {
        path = path,
        stage = fields[2] or "unknown",
        reason = fields[3] or "",
        attempts = tonumber(fields[4]) or 1,
        updated = tonumber(fields[5]) or 0,
      }
    end
  end

  file:close()
end

function save_failed_tasks()
  ensure_dirs()
  local file = atomic_file_writer(FAILED_TASKS_FILE)

  if not file then
    set_status("无法保存失败任务", true)
    return false
  end

  write_persistence_schema(file, FAILED_TASKS_FILE)

  local tasks = {}

  for _, task in pairs(state.failed_tasks) do
    tasks[#tasks + 1] = task
  end

  table.sort(tasks, function(a, b) return path_key(a.path) < path_key(b.path) end)

  for _, task in ipairs(tasks) do
    file:write(
      escape_tsv(task.path), "\t",
      escape_tsv(task.stage), "\t",
      escape_tsv(task.reason), "\t",
      tostring(task.attempts or 1), "\t",
      tostring(task.updated or os.time()), "\n"
    )
  end

  if not file:close() then
    set_status("无法保存失败任务", true)
    return false
  end

  state.failed_tasks_dirty = false
  return true
end

function record_failed_task(asset, stage, reason)
  if not asset or not asset.path then
    return
  end

  local key = path_key(asset.path)
  local previous = state.failed_tasks[key]

  state.failed_tasks[key] = {
    path = asset.path,
    stage = stage or "unknown",
    reason = tostring(reason or "未知错误"),
    attempts = (previous and previous.attempts or 0) + 1,
    updated = os.time(),
  }
  state.failed_tasks_dirty = true
end

function clear_failed_task(asset_or_path)
  local path = type(asset_or_path) == "table"
    and asset_or_path.path
    or asset_or_path

  if path and state.failed_tasks[path_key(path)] then
    state.failed_tasks[path_key(path)] = nil
    state.failed_tasks_dirty = true
  end
end

function failed_task_count()
  local count = 0
  for _ in pairs(state.failed_tasks) do count = count + 1 end
  return count
end

function retry_failed_tasks()
  if state.scan or state.import_session or state.precache_session then
    set_status("请等待当前后台任务完成", true)
    return
  end

  local assets = {}

  for key, task in pairs(state.failed_tasks) do
    if reaper.file_exists(task.path) then
      local asset = state.by_path[key]

      if not asset then
        local root = root_for_path(task.path)
        asset = add_or_update_asset(make_placeholder(task.path, root or ""))
      end

      asset.indexed = false
      asset.ready = false
      asset.pending_batch = true
      asset.wave_error = nil
      assets[#assets + 1] = asset
    end
  end

  if #assets == 0 then
    set_status("没有可重试的失败任务", true)
    return
  end

  local job_token =
    Jobs.begin(
      "catalog_pipeline",
      "catalog_exclusive",
      false
    )

  if not job_token then
    set_status("另一个目录写任务正在运行", true)
    return
  end

  state.import_session = {
    label = "重试失败任务",
    roots = {},
    assets = assets,
    total = #assets,
    done = 0,
    failed = 0,
    current = nil,
    started = reaper.time_precise(),
    phase = "prepare",
    job_token = job_token,
  }
  state.import_cancel_requested = false
  set_status(string.format("正在重试 %d 个失败任务", #assets))
end

function reset_wave_cache_runtime()
  local precache = state.precache_session
  if state.wave_active
    and state.wave_active.job_token then
    Jobs.cancel(state.wave_active.job_token)
    Jobs.finish(
      state.wave_active.job_token,
      true,
      "cache reset"
    )
    state.wave_active.job_token = nil
  end
  destroy_wave_job(state.wave_active)
  state.wave_active = nil

  if state.precache_session
    and state.precache_session.current then
    destroy_wave_job(
      state.precache_session.current
    )
  end

  state.precache_session = nil
  state.precache_cancel_requested = false
  state.wave_cache = {}
  state.wave_cache_count = 0
  state.wave_checked = {}
  state.wave_queue = {}
  state.wave_queued = {}

  if precache and precache.job_token then
    Jobs.cancel(precache.job_token)
    Jobs.finish(
      precache.job_token,
      true,
      "cache reset"
    )
  end
end

function move_wave_cache_files(
  old_directory,
  new_directory
)
  old_directory =
    normalized_cache_directory(
      old_directory
    )

  new_directory =
    normalized_cache_directory(
      new_directory
    )

  if path_key(old_directory)
      == path_key(new_directory) then
    return 0, 0
  end

  reaper.RecursiveCreateDirectory(
    new_directory,
    0
  )

  local filenames = {}
  local index = 0

  while true do
    local filename =
      reaper.EnumerateFiles(
        old_directory,
        index
      )

    if not filename then
      break
    end

    filenames[#filenames + 1] =
      filename

    index = index + 1
  end

  local moved = 0
  local failed = 0

  for _, filename in ipairs(filenames) do
    local source_path =
      join_path(
        old_directory,
        filename
      )

    local target_path =
      join_path(
        new_directory,
        filename
      )

    if reaper.file_exists(target_path) then
      os.remove(source_path)
      moved = moved + 1
    elseif copy_file_streaming(
      source_path,
      target_path
    ) then
      os.remove(source_path)
      moved = moved + 1
    else
      failed = failed + 1
    end
  end

  return moved, failed
end

function switch_wave_cache_directory(
  new_directory,
  move_existing
)
  local old_directory =
    normalized_cache_directory(
      state.wave_cache_dir
        or WAVE_CACHE_DIR
    )

  new_directory =
    normalized_cache_directory(
      new_directory
    )

  if path_key(old_directory)
      == path_key(new_directory) then
    set_status("波形缓存目录没有变化")
    return true
  end

  if path_is_inside(
      new_directory,
      old_directory
    ) or path_is_inside(
      old_directory,
      new_directory
    ) then
    set_status(
      "新旧缓存目录不能互相嵌套",
      true
    )
    return false
  end

  reset_wave_cache_runtime()

  local moved = 0
  local failed = 0

  if move_existing then
    moved, failed =
      move_wave_cache_files(
        old_directory,
        new_directory
      )
  else
    reaper.RecursiveCreateDirectory(
      new_directory,
      0
    )
  end

  apply_wave_cache_directory(
    new_directory
  )

  state.config_dirty = true
  state.results_dirty = true

  if move_existing then
    set_status(
      string.format(
        "已切换缓存目录：移动 %d，失败 %d",
        moved,
        failed
      ),
      failed > 0
    )
  else
    set_status(
      "已切换波形缓存目录；旧缓存仍保留"
    )
  end

  return true
end

function prompt_wave_cache_directory()
  local ok, input =
    reaper.GetUserInputs(
      "更改波形缓存目录",
      1,
      "新缓存目录路径:",
      state.wave_cache_dir
        or WAVE_CACHE_DIR
    )

  if not ok then
    return
  end

  local new_directory =
    normalized_cache_directory(input)

  local answer =
    reaper.MB(
      "是否将现有波形缓存移动到新目录？\n\n"
        .. "是：移动已有缓存并切换。\n"
        .. "否：直接切换，旧目录保持不变。\n"
        .. "取消：不修改。",
      SCRIPT_NAME,
      3
    )

  if answer == 2 then
    return
  end

  switch_wave_cache_directory(
    new_directory,
    answer == 6
  )
end

function restore_default_wave_cache_directory()
  local target =
    DEFAULT_WAVE_CACHE_DIR

  if path_key(
    state.wave_cache_dir
      or WAVE_CACHE_DIR
  ) == path_key(target) then
    set_status("当前已经使用默认缓存目录")
    return
  end

  local answer =
    reaper.MB(
      "恢复默认缓存目录，并移动现有缓存？\n\n"
        .. target,
      SCRIPT_NAME,
      3
    )

  if answer == 2 then
    return
  end

  switch_wave_cache_directory(
    target,
    answer == 6
  )
end

function migrate_legacy_data()
  ensure_dirs()

  if not reaper.file_exists(CONFIG_FILE)
    and reaper.file_exists(LEGACY_CONFIG_FILE) then
    if copy_file(LEGACY_CONFIG_FILE, CONFIG_FILE) then
      set_status("已迁移旧版音效库路径与偏好设置")
    end
  end
end

----------------------------------------------------------------
-- UCS and placeholder assets
----------------------------------------------------------------
