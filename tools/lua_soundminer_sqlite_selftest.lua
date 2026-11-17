local module = arg[1] or "src/lua/27_sqlite_reader.lua"
local fixtures = assert(arg[2], "fixture directory is required")
assert(loadfile(module))()

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

if arg[3] then
  local db = assert(SoundminerSQLite.open(arg[3]))
  local count, started = 0, os.clock()
  for row in db:rows("justinmetadata") do
    assert(row.recid and row.Filename and row.FilePath)
    count = count + 1
  end
  assert(db:unchanged())
  db:close()
  print(string.format("Read-only Soundminer sample: %d rows, %.3f CPU seconds", count, os.clock() - started))
end
print("Soundminer SQLite reader: PASS (real SQLite fixtures, overflow, rowid lookup, corruption and change detection)")
