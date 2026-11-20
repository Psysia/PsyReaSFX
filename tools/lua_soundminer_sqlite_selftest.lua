local module = arg[1] or "src/lua/27_sqlite_reader.lua"
local fixtures = assert(arg[2], "fixture directory is required")
assert(not arg[3], "This test uses synthetic fixtures only; do not pass a user database")
reaper = { ReaWeb_ReadSharedRange = assert(loadfile("tools/lua_shared_readonly_fixture.lua"))() }
dofile(module:gsub("27_sqlite_reader.lua$", "26_shared_readonly.lua"))
assert(loadfile(module))()
local fixture_mutation_open = io.open
io.open = function(path, mode)
  assert(mode ~= "rb", "production SQLite source reader attempted a CRT fallback")
  return fixture_mutation_open(path, mode)
end

local function open(name)
  return assert(SoundminerSQLite.open(fixtures .. "/" .. name))
end

for _, name in ipairs({ "ordinary.sqlite", "large-page.sqlite" }) do
  local db = open(name)
  local schema = db:tables()
  assert(#schema.justinmetadata.columns == 11)
  assert(schema["tricky,column"].columns[1] == "a,b")
  assert(not schema.no_rowid and not schema.generated)
  local count = 0
  local previous
  for row in db:rows("justinmetadata") do
    count = count + 1
    assert(not previous or row.recid > previous, "rowid order")
    previous = row.recid
    assert(row.recid == row._rowid and row.Missing == nil)
    assert(row.Later == 42 and row.LaterText == "a,b)", "ALTER constant defaults")
    if row.recid > 0 and row.recid < 3000 then
      assert(row.Filename == "音效-" .. row.recid .. ".wav")
      assert(row.Pathname == "C:/Audio/中文")
      assert(row.Small == -row.recid and row.Score == 0.125)
      assert(row.Big == (row.recid == 101 and math.mininteger or math.maxinteger))
      assert(#row.waveformrep == (row.recid == 101 and 30720 or 256), "overflow BLOB")
      for index = 1, math.min(256, #row.waveformrep) do assert(row.waveformrep:byte(index) == index - 1) end
      if row.recid == 101 then assert(#row.Description > 19000, "overflow text") end
    end
  end
  assert(count == 2203)
  for _, id in ipairs({ math.mininteger, -1, 1, 101, 102, 2199, 2200, math.maxinteger }) do
    assert(db:get("justinmetadata", id).recid == id, "binary-search row lookup")
  end
  assert(db:get("justinmetadata", 0) == nil and db:get("justinmetadata", 2201) == nil)
  for _, id in ipairs({ 1, 7, 101, 709, 2199, 2200 }) do
    assert(db:lookup("justinmetadata", "Filename", "音效-" .. id .. ".wav").recid == id, "indexed text lookup")
  end
  assert(db:lookup("justinmetadata", "Description", "引号, comma ('nested')\n" .. string.rep("x", 19000)).recid == 101,
    "overflow index payload")
  assert(db:lookup("justinmetadata", "Filename", "absent") == nil)
  local ignored, reason = db:lookup("justinmetadata", "Pathname", "C:/Audio/中文")
  assert(not ignored and reason == "index_unavailable", "descending indexes are unsupported")
  ignored, reason = db:lookup("collated", "word", "A")
  assert(not ignored and reason == "index_unavailable", "inherited NOCASE is not BINARY")
  assert(db:lookup("typed", "word", "abc").id == 3, "text is distinct from blob")
  assert(db:lookup("typed", "word", "xyz").id == 5, "mixed SQLite type ordering")
  assert(db:get("tricky,column", 5)["quoted`name"] == "yes")
  local descending = db:get("descending", 1)
  assert(descending.id == 101 and descending._rowid == 1, "INTEGER PRIMARY KEY DESC is not alias")
  assert(db:unchanged())
  db:close()
  assert(not db:unchanged())
end

for _, name in ipairs({ "truncated.sqlite", "bad-header.sqlite", "utf16.sqlite", "wal.sqlite", "journal.sqlite" }) do
  local db, message = SoundminerSQLite.open(fixtures .. "/" .. name)
  assert(not db and type(message) == "string", "refuse " .. name)
end
for _, name in ipairs({ "cycle.sqlite", "bad-pointer.sqlite" }) do
  local db = open(name)
  local ok = pcall(function() for _ in db:rows("justinmetadata") do end end)
  assert(not ok, "reject " .. name)
  db:close()
end
local persistent = open("persist.sqlite")
assert(persistent:get("justinmetadata", 1).recid == 1)
persistent:close()
local changed = open("changing.sqlite")
local mutation = assert(io.open(fixtures .. "/changing.sqlite", "r+b"))
mutation:seek("set", 60)
local previous_bytes = assert(mutation:read(4))
mutation:seek("set", 60)
mutation:write(string.char(previous_bytes:byte(1) ~ 1) .. previous_bytes:sub(2))
mutation:close()
assert(not changed:unchanged(), "detect database change")
changed:close()
mutation = assert(io.open(fixtures .. "/changing.sqlite", "r+b"))
mutation:seek("set", 60)
mutation:write(previous_bytes)
mutation:close()

io.open = fixture_mutation_open

-- The actual native DLL's query and sharing behavior is exercised by the
-- Windows native test. Check the matching ReaScript packet decoder here.
dofile(module:gsub("27_sqlite_reader.lua$", "27_soundminer_native.lua"))
local active, generation, calls = true, true, 0
reaper.PRS_SM_Open = function() return 3 end
reaper.PRS_SM_Valid = function(handle) return handle == 3 and active and generation end
reaper.PRS_SM_Close = function(handle) assert(active and handle == 3); active = false end
reaper.PRS_SM_Read = function(handle, op, key, _, limit)
  assert(handle == 3 and active and limit <= 64); calls = calls + 1
  if not generation then return "!changed" end
  if key ~= "" then return "+" end
  if op == "paths" then return "+0i1:13s3:one" end
  assert(op == "rows")
  return "+0i1:11i1:12s3:one3x6:6100624i16:90071992547409935d16:000000000000f43f6s0:"
end
reaper.PRS_SM_Search = function(handle, text, limit)
  assert(handle == 3 and active and text == "wo" and limit == 40)
  return generation and "+1\n9007199254740993\n" or "!changed"
end
local native = open("ordinary.sqlite")
assert(native.native and native:unchanged())
local schema = native:tables().justinmetadata
local rows = native:row_batches("justinmetadata", os.clock)
local paths = native:path_batches(os.clock)
local row = assert(rows()[1])
assert(row._rowid == 1 and row[schema.columns[2]] == "one" and row[schema.columns[3]] == "a\0b")
assert(row[schema.columns[4]] == 9007199254740993 and row[schema.columns[5]] == 1.25)
assert(row[schema.columns[6]] == "" and row[schema.columns[7]] == nil)
assert(paths()[1].Filename == "one" and paths() == nil and rows() == nil)
assert(native:search_rowids("wo",100)[2] == 9007199254740993 and calls == 4)
generation = false
assert(not native:unchanged() and not pcall(function() native:get("justinmetadata",1) end))
assert(not pcall(function() native:search_rowids("wo",100) end))
native:close()
assert(not active and not native:unchanged())
print("Soundminer SQLite reader: PASS (real SQLite fixtures, overflow, rowid lookup, corruption and change detection)")
