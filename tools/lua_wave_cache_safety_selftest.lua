-- Virtual files keep these destructive-operation regressions isolated from
-- real user data. Production cache helpers and migration code run unchanged.
local root = arg[1] or "."
local function load_region(path, first, last)
  local file = assert(io.open(root .. "/" .. path, "rb"))
  local source = file:read("*a")
  file:close()
  local start = assert(source:find(first, 1, true), first)
  local finish = assert(source:find(last, start + #first, true), last)
  assert(load(source:sub(start, finish - 1), "@" .. path, "t", _ENV))()
end

SEP = "\\"
DEFAULT_WAVE_CACHE_DIR = "C:\\PRS\\data\\wave_cache_v3"
state = {}
AppState = { set = function(name, value) state[name] = value end }
reaper = {}
assert(loadfile(root .. "/src/lua/10_ui_core.lua"))()
load_region("src/lua/20_jobs_storage.lua", "function move_wave_cache_files(", "function migrate_legacy_data()")
load_region("src/lua/50_runtime_ui.lua", "function clear_wave_cache()", "function validate_wave_cache_file(path)")
load_region("src/lua/50_runtime_ui.lua", "function save_wave_to_disk(", "local DIRECT_WAVE_MAX_FRAMES_PER_POINT")
function reset_wave_cache_runtime() end
local real_open, real_remove = io.open, os.remove
local files, created, writes, removed = {}, {}, {}, {}
local fail_write, after_close = nil, nil
local function key(path) return path_key(path) end
local function put(path, content) files[key(path)] = content end
local function get(path) return files[key(path)] end
local function reset()
  files, created, writes, removed = {}, {}, {}, {}
  fail_write, after_close = nil, nil
  state = { wave_cache_dir = DEFAULT_WAVE_CACHE_DIR }
  WAVE_CACHE_DIR = DEFAULT_WAVE_CACHE_DIR
end

io.open = function(path, mode)
  local id = key(path)
  if mode == "rb" and files[id] == nil then return nil end
  if mode == "wb" then
    files[id] = ""
    writes[#writes + 1] = id
  end
  local offset = 1
  return {
    read = function(_, length)
      local content = files[id] or ""
      if offset > #content then return nil end
      local value = length == "*a" and content:sub(offset) or content:sub(offset, offset + length - 1)
      offset = offset + #value
      return value
    end,
    write = function(self, value)
      if id == fail_write then return nil, "disk full" end
      files[id] = (files[id] or "") .. value
      return self
    end,
    close = function()
      if mode == "wb" and after_close then after_close(id) end
      return true
    end,
  }
end
os.remove = function(path)
  local id = key(path)
  if files[id] == nil then return nil end
  removed[#removed + 1] = id
  files[id] = nil
  return true
end
reaper.RecursiveCreateDirectory = function(path) created[#created + 1] = key(path); return 1 end
reaper.file_exists = function(path) return files[key(path)] ~= nil end
reaper.EnumerateFiles = function(directory, index)
  local prefix, names = key(directory) .. SEP, {}
  for path in pairs(files) do
    if path:sub(1, #prefix) == prefix then
      local name = path:sub(#prefix + 1)
      if not name:find(SEP, 1, true) then names[#names + 1] = name end
    end
  end
  table.sort(names)
  return names[index + 1]
end
HostApi = reaper
function reset_wave_cache_runtime() end
function set_status(message, failed) state.status, state.status_failed = message, failed end

local parent = "D:\\Soundminer\\Caches"
local child = parent .. "\\PsyReaSFX-wave-cache"
local waveform = "RWF2 2\n\0\1\2\3"
local sqlite = "SQLite format 3\0unchanged source database"
reset()
assert(normalized_cache_directory(DEFAULT_WAVE_CACHE_DIR) == DEFAULT_WAVE_CACHE_DIR)
assert(normalized_cache_directory(parent) == child)
assert(normalized_cache_directory(child) == child, "normalization must be idempotent")
assert(normalized_cache_directory("D:/Soundminer/./Caches/../Caches") == child)
assert(normalized_cache_directory("\\\\?\\" .. parent) == child)
assert(normalized_cache_directory("\\\\?\\UNC\\server\\share\\cache")
  == "\\\\server\\share\\cache\\PsyReaSFX-wave-cache")
assert(not prs_wave_cache_directory_is_managed(parent))
assert(prs_wave_cache_directory_is_managed(child))
assert(not prs_wave_cache_directory_is_managed(child .. "\\.."))
for _, invalid in ipairs({ "relative", "C:relative", "C:\\..\\escape", "C:\\cache. ",
  "C:\\cache:stream", "C:\\NUL", "C:\\aux.txt", "\\\\.\\C:\\cache", "C:\\cache\0tail" }) do
  local value, reason = normalized_cache_directory(invalid)
  assert(value == DEFAULT_WAVE_CACHE_DIR and reason, "ambiguous cache path accepted: " .. invalid)
  assert(not switch_wave_cache_directory(invalid, true))
end
apply_wave_cache_directory(parent)
assert(WAVE_CACHE_DIR == child and created[#created] == key(child))
apply_wave_cache_directory("relative")
assert(WAVE_CACHE_DIR == DEFAULT_WAVE_CACHE_DIR and state.wave_cache_directory_warning)

-- UNIX paths keep case and also get a PRS subdirectory; root escapes fail.
SEP, DEFAULT_WAVE_CACHE_DIR = "/", "/prs/cache"
assert(normalized_cache_directory("/Volumes/Audio/../Soundminer") == "/Volumes/Soundminer/PsyReaSFX-wave-cache")
assert(not prs_wave_cache_directory_path("/../../cache"))
SEP, DEFAULT_WAVE_CACHE_DIR = "\\", "C:\\PRS\\data\\wave_cache_v3"

reset()
for _, entry in ipairs({
  { "00000001.rwf", waveform, true },
  { "00000002.rwf", "RWF3 2 2\n" .. string.rep("\0", 8), true },
  { "00000003.rwf", "RWF4 2 2\n" .. string.rep("\0", 16), true },
  { "00000004.rwf", "RWF2 2\n", true }, -- recognizable but truncated PRS cache
  { "00000005.rwf", sqlite, false },
  { "00000006.rwf", "2\n\0\0", false }, -- legacy files lack proof of ownership
  { "00000007.rwf", "RWF3 2 9\n", false },
  { "00000008.rwf", "RWF2 999999999999\n", false },
  { "00000009.rwf", "RWF2 2", false },
  { "waveforms.sqlite", sqlite, false },
  { "not-a-key.rwf", waveform, false },
  { "00000000.rwf.backup", waveform, false },
}) do
  local path = join_path(DEFAULT_WAVE_CACHE_DIR, entry[1])
  put(path, entry[2])
  assert(prs_wave_cache_file_owned(path) == entry[3], entry[1])
end
local preserved = {}
for path, content in pairs(files) do if not prs_wave_cache_file_owned(path) then preserved[path] = content end end
local moved, failed = move_wave_cache_files(DEFAULT_WAVE_CACHE_DIR, parent)
assert(moved == 4 and failed == 0)
for path, content in pairs(preserved) do assert(files[path] == content, "foreign file changed: " .. path) end
assert(get(child .. "\\00000001.rwf") == waveform)

-- The source may be an actual third-party database/cache/audio directory.
-- No cleanup may run on that directory, even if a PRS-looking file is present.
reset()
put(parent .. "\\waveforms.sqlite", sqlite)
put(parent .. "\\00000001.rwf", waveform)
moved, failed = move_wave_cache_files(parent, DEFAULT_WAVE_CACHE_DIR)
assert(moved == 0 and failed == 1 and #writes == 0 and #removed == 0)
assert(switch_wave_cache_directory(parent, false))
assert(switch_wave_cache_directory(DEFAULT_WAVE_CACHE_DIR, true))
assert(get(parent .. "\\waveforms.sqlite") == sqlite and get(parent .. "\\00000001.rwf") == waveform)

-- Collisions preserve both source and destination, including unowned files
-- and unrelated files at the generic copier's temporary-file name.
reset()
local source = DEFAULT_WAVE_CACHE_DIR .. "\\12345678.rwf"
local destination = child .. "\\12345678.rwf"
put(source, waveform)
put(destination, sqlite)
put(destination .. ".psyreasfx_tmp", "unrelated temporary file")
moved, failed = move_wave_cache_files(DEFAULT_WAVE_CACHE_DIR, parent)
assert(moved == 0 and failed == 1 and get(source) == waveform and get(destination) == sqlite)
assert(get(destination .. ".psyreasfx_tmp") == "unrelated temporary file" and #removed == 0)
put(destination, waveform)
moved, failed = move_wave_cache_files(DEFAULT_WAVE_CACHE_DIR, parent)
assert(moved == 0 and failed == 1 and get(source) == waveform, "even matching-key collisions preserve source")

reset()
put(source, waveform)
fail_write = key(destination)
moved, failed = move_wave_cache_files(DEFAULT_WAVE_CACHE_DIR, parent)
assert(moved == 0 and failed == 1 and get(source) == waveform and #removed == 0)
reset()
put(source, waveform)
after_close = function() put(source, "RWF2 2\nnew!") end
moved, failed = move_wave_cache_files(DEFAULT_WAVE_CACHE_DIR, parent)
assert(moved == 0 and failed == 1 and get(source) == "RWF2 2\nnew!", "changed source must survive migration")

reset()
assert(not switch_wave_cache_directory(DEFAULT_WAVE_CACHE_DIR .. "\\nested", true))
assert(#writes == 0 and #removed == 0 and state.wave_cache_dir == DEFAULT_WAVE_CACHE_DIR)
reset()
put(source, waveform)
put(DEFAULT_WAVE_CACHE_DIR .. "\\waveforms.sqlite", sqlite)
put(DEFAULT_WAVE_CACHE_DIR .. "\\00000002.rwf", sqlite)
clear_wave_cache()
assert(not get(source), "owned cache should be cleaned")
assert(get(DEFAULT_WAVE_CACHE_DIR .. "\\waveforms.sqlite") == sqlite)
assert(get(DEFAULT_WAVE_CACHE_DIR .. "\\00000002.rwf") == sqlite, "foreign content with a cache extension is preserved")
reset()
WAVE_CACHE_DIR = parent
put(parent .. "\\00000001.rwf", waveform)
put(parent .. "\\waveforms.sqlite", sqlite)
clear_wave_cache()
assert(#removed == 0, "unmanaged directories cannot be cleaned")
function ensure_dirs() end
function wave_cache_key() return "12345678" end
reset()
put(source, sqlite)
assert(not save_wave_to_disk({}, 1, {count=1,peaks={0.5}}))
assert(get(source) == sqlite and #writes == 0, "wave generation must not overwrite foreign content")
WAVE_CACHE_DIR = parent
assert(not save_wave_to_disk({}, 1, {count=1,peaks={0.5}}))
assert(#writes == 0, "wave generation must not write into an unmanaged directory")
io.open, os.remove = real_open, real_remove
print("Wave cache safety passed: managed directories, format ownership, collisions, failed/concurrent copies and foreign-data preservation")
