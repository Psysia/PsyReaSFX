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

function copy_file_streaming(
  source_path,
  target_path
)
  local temporary_path =
    target_path .. ".psyreasfx_tmp"
  os.remove(temporary_path)

  if not stream_file_to_temporary(
    source_path,
    temporary_path
  ) then
    return false
  end

  return commit_atomic_temporary(
    target_path,
    temporary_path
  )
end

function stream_file_to_temporary(
  source_path,
  temporary_path
)
  local input = io.open(source_path, "rb")

  if not input then
    return false
  end

  local output = io.open(temporary_path, "wb")

  if not output then
    input:close()
    return false
  end

  local ok = true

  while true do
    local chunk, read_error = input:read(1024 * 1024)

    if not chunk then
      if read_error then
        ok = false
      end
      break
    end

    if state.persistence_fault_injection == "write"
      or not output:write(chunk) then
      ok = false
      break
    end
  end

  input:close()
  local flushed = output:flush()
  local closed = output:close()

  if not ok or not flushed or not closed then
    os.remove(temporary_path)
    return false
  end

  if state.persistence_fault_injection == "after_close" then
    os.remove(temporary_path)
    return false
  end

  return true
end

function commit_atomic_temporary(
  target_path,
  temporary_path,
  backup_path,
  keep_backup
)
  backup_path = backup_path or (target_path .. ".bak")
  local had_original = reaper.file_exists(target_path)
  os.remove(backup_path)

  if had_original
    and not os.rename(target_path, backup_path) then
    os.remove(temporary_path)
    return false, had_original
  end

  if state.persistence_fault_injection == "after_backup" then
    if had_original then
      os.rename(backup_path, target_path)
    end
    os.remove(temporary_path)
    return false, had_original
  end

  if not os.rename(
    temporary_path,
    target_path
  ) then
    if had_original then
      os.rename(backup_path, target_path)
    end
    os.remove(temporary_path)
    return false, had_original
  end

  if not keep_backup then
    os.remove(backup_path)
  end
  return true, had_original
end

function persistent_data_files()
  return {
    CONFIG_FILE,
    LIBRARIES_FILE,
    DATABASE_FILE,
    DATABASE_JOURNAL_FILE,
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
    version = 3,
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

-- Every published format advances one version at a time. Loaders normalize
-- older rows into the current in-memory model; these explicit edges are the
-- audit contract that authorizes the final atomic rewrite. A missing edge is a
-- hard stop rather than permission to jump directly to the newest schema.
local PERSISTENCE_MIGRATIONS = {
  [CONFIG_FILE] = { [0] = 1 },
  [LIBRARIES_FILE] = { [0] = 1, [1] = 2 },
  [DATABASE_FILE] = { [0] = 1, [1] = 2, [2] = 3 },
  [COLLECTIONS_FILE] = { [0] = 1 },
  [PROJECT_USAGE_FILE] = { [0] = 1 },
  [SAVED_SEARCHES_FILE] = { [0] = 1 },
  [HISTORY_FILE] = { [0] = 1 },
  [LAST_PLAYED_SESSION_FILE] = { [0] = 1 },
  [REGIONS_FILE] = { [0] = 1 },
  [LOUDNESS_FILE] = { [0] = 1 },
  [FAILED_TASKS_FILE] = { [0] = 1 },
  [BACKUP_STATE_FILE] = { [0] = 1 },
}

function persistence_migration_path(target_path, from_version)
  local schema = PERSISTENCE_SCHEMAS[target_path]
  local registered = PERSISTENCE_MIGRATIONS[target_path]
  local current = tonumber(from_version)
  if not schema or not registered or not current
    or current < 0 or current % 1 ~= 0
    or current > schema.version then
    return nil, "invalid_start"
  end

  local steps = {}
  while current < schema.version do
    local next_version = registered[current]
    if next_version ~= current + 1 then
      return nil, "missing_step_" .. tostring(current)
    end
    steps[#steps + 1] = {
      from = current,
      to = next_version,
    }
    current = next_version
  end
  return steps
end

function persistence_schema_header(kind, version, generation)
  local fields = {
    PERSISTENCE_SCHEMA_MAGIC,
    kind,
    tostring(version),
  }
  if generation ~= nil then
    fields[#fields + 1] = "generation"
    fields[#fields + 1] = tostring(generation)
  end
  return table.concat(fields, "\t") .. "\n"
end

function persistence_schema_generation(fields)
  if not is_persistence_schema_fields(fields) then return 0 end
  for index = 4, #fields - 1 do
    if fields[index] == "generation" then
      local generation = tonumber(fields[index + 1])
      if generation and generation >= 0 and generation % 1 == 0 then
        return generation
      end
      return nil, "invalid_generation"
    end
  end
  return 0
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
  if state.persistence_recovery_problem
    and state.persistence_recovery_problem ~= "" then
    problems[#problems + 1] =
      state.persistence_recovery_problem
  end

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
      local steps, path_error =
        persistence_migration_path(target_path, current)
      if not steps then
        state.persistence_read_only = true
        state.persistence_read_only_reason = string.format(
          "缺少数据迁移步骤：%s v%d（%s）",
          basename(target_path),
          current,
          tostring(path_error or "unknown")
        )
        set_status(
          state.persistence_read_only_reason
            .. "；已停止后续写入",
          true
        )
        return false
      end
      pending[#pending + 1] = {
        path = target_path,
        from = current,
        steps = steps,
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

    local kind = schema and schema.kind or basename(target_path)
    if ok then
      for _, step in ipairs(migration.steps) do
        if not append_schema_migration_log(
          kind,
          step.from,
          step.to,
          "completed"
        ) then
          ok = false
          break
        end
      end
    else
      local first_step = migration.steps[1]
      append_schema_migration_log(
        kind,
        first_step and first_step.from or migration.from,
        first_step and first_step.to or (schema and schema.version or 0),
        "failed"
      )
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

    local committed = commit_atomic_temporary(
      self.target_path,
      self.temporary_path,
      self.backup_path
    )
    if not committed then
      return false, "could not install completed file"
    end
    return true
  end

  function writer:abort()
    if self.closed then
      return false
    end
    self.closed = true
    pcall(function() self.raw:close() end)
    os.remove(self.temporary_path)
    return true
  end

  return writer
end

function recover_atomic_data_files()
  local files = persistent_data_files()
  local unresolved = {}
  local restore_committed =
    reaper.file_exists(RESTORE_TRANSACTION_COMMIT_FILE)
  files[#files + 1] = SCAN_CHECKPOINT_FILE
  for _, target_path in ipairs(files) do
    local backup_path = target_path .. ".bak"
    local temporary_path = target_path .. ".tmp"
    local restore_backup_path = target_path .. ".restore.bak"
    local restore_temporary_path = target_path .. ".restore.tmp"
    local restore_new_path = target_path .. ".restore.new"

    -- A transaction marker is installed only after every restored file has
    -- committed. With the marker, finish cleanup and retain the new generation;
    -- without it, roll every touched file back to its previous generation.
    local restore_pending = false
    if restore_committed then
      for _, artifact_path in ipairs({
        restore_backup_path,
        restore_temporary_path,
        restore_new_path,
      }) do
        if reaper.file_exists(artifact_path)
          and not os.remove(artifact_path) then
          restore_pending = true
        end
      end
    elseif reaper.file_exists(restore_backup_path) then
      local removed = not reaper.file_exists(target_path)
        or os.remove(target_path) ~= nil
      if not removed
        or not os.rename(restore_backup_path, target_path) then
        restore_pending = true
      end
    elseif reaper.file_exists(restore_new_path) then
      if reaper.file_exists(target_path)
        and not os.remove(target_path) then
        restore_pending = true
      end
    end
    if not restore_committed then
      os.remove(restore_temporary_path)
      if not restore_pending then
        os.remove(restore_new_path)
      end
    end
    if restore_pending then
      unresolved[#unresolved + 1] = basename(target_path)
    end

    if not restore_pending
      and not reaper.file_exists(target_path)
      and reaper.file_exists(backup_path) then
      os.rename(backup_path, target_path)
    elseif not restore_pending
      and reaper.file_exists(target_path) then
      os.remove(backup_path)
    end

    -- A .tmp without a rollback may have been interrupted while writing and
    -- is never trusted as user data.
    os.remove(temporary_path)
  end
  if restore_committed and #unresolved == 0 then
    os.remove(RESTORE_TRANSACTION_COMMIT_FILE)
    if reaper.file_exists(RESTORE_TRANSACTION_COMMIT_FILE) then
      unresolved[#unresolved + 1] =
        basename(RESTORE_TRANSACTION_COMMIT_FILE)
    end
  end
  state.persistence_recovery_problem = #unresolved > 0
    and ("未能回滚中断的备份恢复："
      .. table.concat(unresolved, ", "))
    or ""
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
  local expected = 0
  local failed = 0

  for _, source_path in ipairs(persistent_data_files()) do
    if reaper.file_exists(source_path) then
      expected = expected + 1
      local inject_partial =
        state.persistence_fault_injection
          == "backup_after_first"
        and copied > 0
      if not inject_partial
        and copy_file_streaming(
        source_path,
        join_path(directory, basename(source_path))
      ) then
        copied = copied + 1
      else
        failed = failed + 1
      end
    end
  end

  local manifest_path = join_path(directory, "manifest.tsv")
  local manifest = io.open(manifest_path, "wb")
  local manifest_ok = false

  if manifest then
    local wrote = manifest:write("version\t", VERSION, "\n")
      and manifest:write("created\t", os.date("%Y-%m-%d %H:%M:%S"), "\n")
      and manifest:write("reason\t", reason or "manual", "\n")
      and manifest:write("files\t", tostring(copied), "\n")
    local flushed = manifest:flush()
    local closed = manifest:close()
    manifest_ok = wrote ~= nil and flushed ~= nil and closed ~= nil
  end

  if expected <= 0 then
    remove_shallow_directory(directory)
    if not quiet then
      set_status("没有可备份的数据文件", true)
    end
    return false
  end

  if copied ~= expected or failed > 0 or not manifest_ok then
    remove_shallow_directory(directory)
    if not quiet then
      set_status("无法完整创建数据备份", true)
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

function restore_data_backup_transaction(directory)
  local plan = {}
  if reaper.file_exists(RESTORE_TRANSACTION_COMMIT_FILE)
    and not os.remove(RESTORE_TRANSACTION_COMMIT_FILE) then
    return false, 0, "stale_commit_marker"
  end

  for _, target_path in ipairs(persistent_data_files()) do
    local source_path = join_path(directory, basename(target_path))

    if reaper.file_exists(source_path) then
      local temporary_path = target_path .. ".restore.tmp"
      os.remove(temporary_path)
      if not stream_file_to_temporary(
        source_path,
        temporary_path
      ) then
        for _, item in ipairs(plan) do
          if item.temporary_path then
            os.remove(item.temporary_path)
          end
        end
        return false, 0, "stage"
      end
      plan[#plan + 1] = {
        target_path = target_path,
        temporary_path = temporary_path,
        backup_path = target_path .. ".restore.bak",
        new_marker_path = target_path .. ".restore.new",
        had_original = false,
      }
    elseif target_path == DATABASE_JOURNAL_FILE
      and reaper.file_exists(target_path) then
      -- Backups created before incremental persistence have no journal.
      -- Removing the current one is part of the same rollback-safe restore,
      -- otherwise post-backup edits could reappear over the restored snapshot.
      plan[#plan + 1] = {
        target_path = target_path,
        temporary_path = nil,
        backup_path = target_path .. ".restore.bak",
        new_marker_path = target_path .. ".restore.new",
        had_original = true,
        delete_only = true,
      }
    end
  end

  if #plan == 0 then
    return false, 0, "empty"
  end

  local committed = 0
  for index, item in ipairs(plan) do
    item.had_original = reaper.file_exists(item.target_path)
    local marker_ok = true
    if not item.had_original and not item.delete_only then
      local marker = io.open(item.new_marker_path, "wb")
      if marker then
        marker_ok = marker:close() ~= nil
      else
        marker_ok = false
      end
    end
    local ok = false
    local had_original = item.had_original
    if marker_ok and item.delete_only then
      os.remove(item.backup_path)
      ok = item.had_original
        and os.rename(item.target_path, item.backup_path) ~= nil
    elseif marker_ok then
      ok, had_original = commit_atomic_temporary(
        item.target_path,
        item.temporary_path,
        item.backup_path,
        true
      )
    end
    item.had_original = had_original == true
    if ok then
      committed = index
    end

    if ok
      and state.persistence_fault_injection
        == "restore_after_first"
      and index == 1 then
      ok = false
    end
    if ok
      and item.delete_only
      and state.persistence_fault_injection
        == "restore_after_journal_delete" then
      ok = false
    end

    if not ok then
      if item.temporary_path then os.remove(item.temporary_path) end
      os.remove(item.new_marker_path)
      for rollback = committed, 1, -1 do
        local previous = plan[rollback]
        local target_removed =
          not reaper.file_exists(previous.target_path)
          or os.remove(previous.target_path) ~= nil
        if previous.had_original then
          os.rename(
            previous.backup_path,
            previous.target_path
          )
        else
          os.remove(previous.backup_path)
          if target_removed then
            os.remove(previous.new_marker_path)
          end
        end
      end
      for cleanup = index + 1, #plan do
        if plan[cleanup].temporary_path then
          os.remove(plan[cleanup].temporary_path)
        end
      end
      return false, 0, "commit"
    end
  end

  local commit_marker_temporary =
    RESTORE_TRANSACTION_COMMIT_FILE .. ".tmp"
  os.remove(commit_marker_temporary)
  local marker = io.open(commit_marker_temporary, "wb")
  local marker_ok = false
  if marker then
    local wrote = marker:write("committed\t1\n")
    local flushed = marker:flush()
    local closed = marker:close()
    marker_ok = wrote ~= nil and flushed ~= nil and closed ~= nil
  end
  if state.persistence_fault_injection
      == "restore_commit_marker" then
    marker_ok = false
  end
  if marker_ok then
    marker_ok = os.rename(
      commit_marker_temporary,
      RESTORE_TRANSACTION_COMMIT_FILE
    ) ~= nil
  end
  if not marker_ok then
    os.remove(commit_marker_temporary)
    for rollback = #plan, 1, -1 do
      local previous = plan[rollback]
      if reaper.file_exists(previous.target_path) then
        os.remove(previous.target_path)
      end
      if previous.had_original then
        os.rename(previous.backup_path, previous.target_path)
      else
        os.remove(previous.backup_path)
        os.remove(previous.new_marker_path)
      end
    end
    return false, 0, "commit_marker"
  end

  for _, item in ipairs(plan) do
    os.remove(item.backup_path)
    os.remove(item.new_marker_path)
  end
  os.remove(RESTORE_TRANSACTION_COMMIT_FILE)
  return true, #plan
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
  local restored_ok, restored, restore_error =
    restore_data_backup_transaction(directory)

  if not restored_ok or restored <= 0 then
    if restore_error == "empty" then
      set_status("备份中没有可恢复的数据", true)
      return
    end
    state.persistence_read_only = true
    state.persistence_read_only_reason =
      "备份恢复未能完整提交，请重启 PsyReaSFX"
    set_status("备份恢复失败，原数据已回滚", true)
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

  file:write("version\t2\n")
  file:write("phase\t", escape_tsv(phase or "scan"), "\n")
  file:write("reason\t", escape_tsv(scan.reason or "扫描"), "\n")
  file:write(
    "force_rebuild\t",
    scan.force_rebuild and "1" or "0",
    "\n"
  )
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

  local checkpoint = {
    roots = {},
    reason = "恢复中断扫描",
    force_rebuild = false,
  }

  for line in file:lines() do
    local fields = split_tsv(line)

    if fields[1] == "root" and fields[2] and fields[2] ~= "" then
      checkpoint.roots[#checkpoint.roots + 1] = normalize_slashes(fields[2])
    elseif fields[1] == "reason" and fields[2] and fields[2] ~= "" then
      checkpoint.reason = fields[2]
    elseif fields[1] == "force_rebuild" then
      checkpoint.force_rebuild = fields[2] == "1"
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
  if state.root_removal_session then return false end
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
    if copy_file_streaming(LEGACY_CONFIG_FILE, CONFIG_FILE) then
      set_status("已迁移旧版音效库路径与偏好设置")
    end
  end
end

----------------------------------------------------------------
-- UCS and placeholder assets
----------------------------------------------------------------
