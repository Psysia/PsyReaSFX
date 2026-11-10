-- Exercise real save scheduling with a fault-injectable atomic writer.
assert(loadfile("src/lua/38_incremental_persistence.lua"))()
assert(loadfile("src/lua/30_catalog.lua"))()
state = { favorites = {}, config_dirty = true }
AppState = { set = function(key, value) state[key] = value end }
HostApi = { time_precise = os.clock }
CONFIG_FILE, VERSION = "fixture-config", "test"
function ensure_dirs() end
function set_status(message, failed) state.status, state.error = message, failed end
function escape_tsv(value) return value end
local committed, active, close_failure, write_failure
function atomic_file_writer()
  local writer = { lines = {} }
  function writer:write(...)
    if write_failure then self.failed = true; return nil end
    self.lines[#self.lines + 1] = table.concat({...})
    return self
  end
  function writer:abort() self.aborted = true end
  function writer:close()
    assert(not self.aborted)
    if self.failed or close_failure then return false end
    committed = table.concat(self.lines)
    return true
  end
  active = writer
  return writer
end
-- The bounded settings header uses the same writer, captured at job start.
function write_config_settings(writer, favorites)
  writer:write("setting\tfixture\t", state.setting or "old", "\n")
  if favorites then
    for path in pairs(state.favorites) do writer:write("favorite\t", path, "\n") end
  end
end
for i = 1, 25000 do state.favorites["path-" .. i] = true end
assert(start_config_save())
assert(not state.config_dirty and not committed)
process_config_save()
assert(state.config_save_session, "large favorites must yield")
state.favorites["added-during-save"] = true
state.setting, state.config_dirty = "new", true
while state.config_save_session do process_config_save() end
assert(state.config_dirty, "commit cannot swallow a newer edit")
assert(not committed:find("added-during-save", 1, true))
assert(committed:find("setting\tfixture\told", 1, true))
assert(start_config_save())
while state.config_save_session do process_config_save() end
assert(not state.config_dirty and committed:find("added-during-save", 1, true))
assert(committed:find("setting\tfixture\tnew", 1, true))
local old = committed
state.config_dirty, close_failure = true, true
assert(start_config_save())
while state.config_save_session do process_config_save() end
assert(committed == old and state.config_dirty)
close_failure, write_failure = false, true
assert(not start_config_save() and active.aborted and state.config_dirty)
write_failure = false
assert(start_config_save())
local interrupted = active
assert(save_config())
assert(interrupted.aborted and not state.config_save_session)
state.config_dirty = true
assert(start_config_save())
state.root_removal_session = {}
process_config_save()
assert(active.aborted and state.config_dirty)
print("Config autosave: bounded writes, concurrent edits, faults and synchronous takeover passed")
