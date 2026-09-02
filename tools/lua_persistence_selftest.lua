local root = assert(arg[1], "temporary test directory is required")
local module_path = assert(arg[2], "20_jobs_storage.lua path is required")
local sep = package.config:sub(1, 1)

local function path_join(left, right)
  return left .. sep .. right
end

local function write_all(path, value)
  local file = assert(io.open(path, "wb"))
  assert(file:write(value))
  assert(file:close())
end

local function read_all(path)
  local file = io.open(path, "rb")
  if not file then return nil end
  local value = file:read("*a")
  file:close()
  return value
end

local function exists(path)
  local file = io.open(path, "rb")
  if not file then return false end
  file:close()
  return true
end

function join_path(left, right) return path_join(left, right) end
function basename(path)
  return path:match("([^/\\]+)$") or path
end
function escape_tsv(value)
  return tostring(value or "")
    :gsub("\\", "\\\\")
    :gsub("\t", "\\t")
    :gsub("\r", "\\r")
    :gsub("\n", "\\n")
end
function split_tsv(line)
  local fields = {}
  for field in (tostring(line or "") .. "\t"):gmatch("(.-)\t") do
    fields[#fields + 1] = field
  end
  return fields
end

state = { persistence_fault_injection = nil }
Jobs = { active = {}, history = {}, generation = 0, accepting = true }
reaper = {
  file_exists = exists,
  time_precise = os.clock,
}

local data_names = {
  "config.tsv", "libraries.tsv", "database.tsv", "collections.tsv",
  "project_usage.tsv", "saved_searches.tsv", "history.tsv",
  "last_played.tsv", "regions.tsv", "loudness.tsv", "failed_tasks.tsv",
  "backup_state.tsv", "migration_log.tsv", "project_url.txt",
}
CONFIG_FILE = path_join(root, data_names[1])
LIBRARIES_FILE = path_join(root, data_names[2])
DATABASE_FILE = path_join(root, data_names[3])
DATABASE_JOURNAL_FILE = path_join(root, "database.journal")
COLLECTIONS_FILE = path_join(root, data_names[4])
PROJECT_USAGE_FILE = path_join(root, data_names[5])
SAVED_SEARCHES_FILE = path_join(root, data_names[6])
HISTORY_FILE = path_join(root, data_names[7])
LAST_PLAYED_SESSION_FILE = path_join(root, data_names[8])
REGIONS_FILE = path_join(root, data_names[9])
LOUDNESS_FILE = path_join(root, data_names[10])
FAILED_TASKS_FILE = path_join(root, data_names[11])
BACKUP_STATE_FILE = path_join(root, data_names[12])
MIGRATION_LOG_FILE = path_join(root, data_names[13])
PROJECT_URL_FILE = path_join(root, data_names[14])
SCAN_CHECKPOINT_FILE = path_join(root, "scan_checkpoint.tsv")
RESTORE_TRANSACTION_COMMIT_FILE =
  path_join(root, "restore_transaction.commit")

assert(loadfile(module_path))()

local source = path_join(root, "copy-source.bin")
local target = path_join(root, "copy-target.bin")
write_all(source, "new-generation")

for _, fault in ipairs({ "write", "after_close", "after_backup" }) do
  write_all(target, "old-generation")
  state.persistence_fault_injection = fault
  assert(not copy_file_streaming(source, target), fault .. " unexpectedly succeeded")
  assert(read_all(target) == "old-generation", fault .. " damaged the prior target")
end

state.persistence_fault_injection = nil
assert(copy_file_streaming(source, target))
assert(read_all(target) == "new-generation")
assert(not exists(target .. ".bak"))

local backup = path_join(root, "backup")
local first = CONFIG_FILE
local second = LIBRARIES_FILE
write_all(first, "old-config")
write_all(second, "old-libraries")
write_all(DATABASE_JOURNAL_FILE, "post-backup-journal")
write_all(path_join(backup, basename(first)), "new-config")
write_all(path_join(backup, basename(second)), "new-libraries")

state.persistence_fault_injection = "restore_after_first"
local restored = restore_data_backup_transaction(backup)
assert(not restored, "grouped restore fault unexpectedly succeeded")
assert(read_all(first) == "old-config", "first file was not rolled back")
assert(read_all(second) == "old-libraries", "second file changed after rollback")
assert(read_all(DATABASE_JOURNAL_FILE) == "post-backup-journal")

state.persistence_fault_injection = "restore_after_journal_delete"
local journal_delete_restored = restore_data_backup_transaction(backup)
assert(not journal_delete_restored, "journal-delete fault unexpectedly succeeded")
assert(read_all(first) == "old-config")
assert(read_all(second) == "old-libraries")
assert(
  read_all(DATABASE_JOURNAL_FILE) == "post-backup-journal",
  "journal deletion was not rolled back"
)

state.persistence_fault_injection = nil
local restored_ok, restored_count = restore_data_backup_transaction(backup)
assert(restored_ok and restored_count == 3)
assert(read_all(first) == "new-config")
assert(read_all(second) == "new-libraries")
assert(not exists(DATABASE_JOURNAL_FILE), "restore retained a journal absent from the backup")

write_all(first, "old-before-marker-failure")
write_all(second, "old-libraries-before-marker-failure")
state.persistence_fault_injection = "restore_commit_marker"
assert(not restore_data_backup_transaction(backup), "commit marker fault unexpectedly succeeded")
assert(read_all(first) == "old-before-marker-failure")
assert(read_all(second) == "old-libraries-before-marker-failure")

write_all(first, "partial-config")
write_all(first .. ".restore.bak", "rollback-config")
write_all(second, "created-by-interrupted-restore")
write_all(second .. ".restore.new", "")
recover_atomic_data_files()
assert(read_all(first) == "rollback-config", "startup did not restore rollback generation")
assert(not exists(second), "startup did not remove newly created partial file")
assert(state.persistence_recovery_problem == "")

write_all(first, "committed-config")
write_all(first .. ".restore.bak", "obsolete-config")
write_all(RESTORE_TRANSACTION_COMMIT_FILE, "committed\t1\n")
recover_atomic_data_files()
assert(read_all(first) == "committed-config", "committed restore was rolled back")
assert(not exists(first .. ".restore.bak"), "committed rollback artifact remains")
assert(not exists(RESTORE_TRANSACTION_COMMIT_FILE), "commit marker remains after recovery")

BACKUP_DIR = path_join(root, "automatic-backups")
VERSION = "self-test"
local last_created_directory = nil
local removed_directory = nil
function ensure_dirs()
  os.execute('mkdir "' .. BACKUP_DIR .. '" >NUL 2>NUL')
end
function directory_exists(path)
  return os.rename(path, path) ~= nil
end
reaper.RecursiveCreateDirectory = function(path)
  last_created_directory = path
  return os.execute('mkdir "' .. path .. '" >NUL 2>NUL') and 1 or 0
end
function remove_shallow_directory(path)
  removed_directory = path
  os.execute('rmdir /s /q "' .. path .. '"')
  return true
end
function prune_data_backups() end
function set_status() end

write_all(first, "backup-config")
write_all(second, "backup-libraries")
state.persistence_fault_injection = "backup_after_first"
assert(not create_data_backup("manual", true), "partial backup was accepted")
assert(removed_directory == last_created_directory, "partial backup was not discarded")

state.persistence_fault_injection = nil
assert(create_data_backup("manual", true), "complete backup was rejected")
assert(read_all(path_join(last_created_directory, basename(first))) == "backup-config")
assert(read_all(path_join(last_created_directory, basename(second))) == "backup-libraries")

local externally_locked_target = arg[3]
local externally_locked_source = arg[4]
if externally_locked_target and externally_locked_source then
  state.persistence_fault_injection = nil
  assert(
    not copy_file_streaming(externally_locked_source, externally_locked_target),
    "externally locked target unexpectedly accepted replacement"
  )
  assert(
    read_all(externally_locked_target) == "locked-old-generation",
    "external file lock damaged the prior target"
  )
end

write_all(DATABASE_FILE, "psyreasfx_schema\tdatabase\t2\n")
assert(preflight_persistence_schemas(), "database schema 2 should remain readable")
assert(state.persistence_schema_versions[DATABASE_FILE] == 2)

local from_zero = assert(persistence_migration_path(DATABASE_FILE, 0))
assert(#from_zero == 3)
assert(from_zero[1].from == 0 and from_zero[1].to == 1)
assert(from_zero[2].from == 1 and from_zero[2].to == 2)
assert(from_zero[3].from == 2 and from_zero[3].to == 3)
local from_two = assert(persistence_migration_path(DATABASE_FILE, 2))
assert(#from_two == 1 and from_two[1].from == 2 and from_two[1].to == 3)
assert(#assert(persistence_migration_path(DATABASE_FILE, 3)) == 0)
assert(not persistence_migration_path(DATABASE_FILE, 4))

local schema_output = path_join(root, "database-schema-header.tsv")
local schema_file = assert(io.open(schema_output, "wb"))
assert(write_persistence_schema(schema_file, DATABASE_FILE))
assert(schema_file:close())
assert(
  read_all(schema_output) == "psyreasfx_schema\tdatabase\t3\n",
  "database writer did not advance to schema 3"
)
local generated_header = persistence_schema_header("database", 3, 27)
assert(
  generated_header
    == "psyreasfx_schema\tdatabase\t3\tgeneration\t27\n",
  "database generation was not embedded in the atomic snapshot"
)
assert(
  persistence_schema_generation(split_tsv(generated_header)) == 27,
  "database generation was not recovered from the snapshot"
)
assert(
  persistence_schema_generation(
    split_tsv("psyreasfx_schema\tdatabase\t3")
  ) == 0,
  "legacy schema header did not default to generation zero"
)
local invalid_generation, invalid_generation_error =
  persistence_schema_generation(
    split_tsv("psyreasfx_schema\tdatabase\t3\tgeneration\tbroken")
  )
assert(invalid_generation == nil)
assert(invalid_generation_error == "invalid_generation")

write_all(DATABASE_FILE, "psyreasfx_schema\tdatabase\t4\n")
assert(not preflight_persistence_schemas(), "future database schema was accepted")
assert(state.persistence_read_only, "future database schema did not enable read-only protection")

print("Lua persistence self-test OK")
