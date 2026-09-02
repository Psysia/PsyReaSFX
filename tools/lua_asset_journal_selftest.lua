local module_path = assert(arg[1], "asset journal module is required")
assert(loadfile(module_path))()

local changes = new_asset_change_set()
assert(record_asset_change(changes, "b", "upsert", { "b1" }))
local mutable_values = { "a1" }
assert(record_asset_change(changes, "a", "upsert", mutable_values))
mutable_values[1] = "mutated-after-record"
assert(ordered_asset_changes(changes)[1].values[1] == "a1")
assert(record_asset_change(changes, "b", "upsert", { "b2" }))
assert(changes.count == 2)
assert(record_asset_change(changes, "a", "delete", { "a-deleted" }))
local ordered = ordered_asset_changes(changes)
assert(#ordered == 2)
assert(ordered[1].op == "delete" and ordered[1].values[1] == "a-deleted")
assert(ordered[2].op == "upsert" and ordered[2].values[1] == "b2")
assert(require_asset_snapshot(changes) and changes.requires_snapshot)
assert(clear_asset_changes(changes))
assert(changes.count == 0 and not changes.requires_snapshot)
assert(#ordered_asset_changes(changes) == 0)
assert(asset_changes_require_snapshot(changes, true, 10000))
assert(asset_changes_require_snapshot(changes, false, 10000))
assert(record_asset_change(changes, "one", "upsert", { "1" }))
assert(not asset_changes_require_snapshot(changes, true, 10000))
changes.count = 10000
assert(asset_changes_require_snapshot(changes, true, 10000))
changes.count = 1
assert(require_asset_snapshot(changes))
assert(asset_changes_require_snapshot(changes, true, 10000))
assert(clear_asset_changes(changes))

local fields = { "path", "name", "description" }
local entries = {
  { op = "upsert", values = { "C:\\Library\\A.wav", "A.wav", "line 1\nline\t2" } },
  { op = "delete", values = { "C:\\Library\\Old.wav", "", "" } },
  { op = "upsert", values = { "C:\\Library\\A.wav", "A.wav", "new value" } },
}
local encoded = assert(encode_asset_journal(17, fields, entries))
local decoded = assert(decode_asset_journal(encoded, 17, fields))
assert(#decoded == #entries)
assert(decoded[1].values[1] == entries[1].values[1])
assert(decoded[1].values[3] == entries[1].values[3])
assert(decoded[3].values[3] == "new value")

local replayed = {}
local function replay(target, decoded_entries)
  for _, entry in ipairs(decoded_entries) do
    local key = entry.values[1]
    if entry.op == "delete" then
      target[key] = nil
    else
      target[key] = entry.values[3]
    end
  end
end
replay(replayed, decoded)
replay(replayed, decoded)
assert(replayed["C:\\Library\\A.wav"] == "new value")
assert(replayed["C:\\Library\\Old.wav"] == nil)

local _, generation_error = decode_asset_journal(encoded, 18, fields)
assert(generation_error == "generation_mismatch")
local _, field_error = decode_asset_journal(encoded, 17, { "path", "name" })
assert(field_error == "field_mismatch")
local _, truncated_error = decode_asset_journal(encoded:sub(1, #encoded - 5), 17, fields)
assert(truncated_error == "truncated_payload")
local corrupt = encoded:gsub("new value", "bad value", 1)
local _, checksum_error = decode_asset_journal(corrupt, 17, fields)
assert(checksum_error == "checksum_mismatch")

local journal_path = os.tmpname()
local journal_file = assert(io.open(journal_path, "wb"))
assert(journal_file:write(encoded))
assert(journal_file:close())
local file_decoded = assert(read_asset_journal(journal_path, 17, fields))
assert(#file_decoded == #entries)
os.remove(journal_path)

local written_payload = nil
local write_closed = false
local write_ok = assert(write_asset_journal_atomic(
  "memory",
  17,
  fields,
  entries,
  function()
    return {
      write = function(_, value)
        written_payload = value
        return true
      end,
      close = function()
        write_closed = true
        return true
      end,
    }
  end
))
assert(write_ok and write_closed)
assert(assert(decode_asset_journal(written_payload, 17, fields)))

local failed_writer_closed = false
local failed_write, failed_write_error = write_asset_journal_atomic(
  "memory",
  17,
  fields,
  entries,
  function()
    return {
      write = function() return nil end,
      close = function()
        failed_writer_closed = true
        return false
      end,
    }
  end
)
assert(not failed_write and failed_write_error == "write_failed")
assert(failed_writer_closed)

local many = {}
for index = 1, 10000 do
  many[index] = {
    op = "upsert",
    values = {
      string.format("C:/Capacity/%05d.wav", index),
      string.format("%05d.wav", index),
      "deterministic",
    },
  }
end
local started = os.clock()
local many_encoded = assert(encode_asset_journal(99, fields, many))
local many_decoded = assert(decode_asset_journal(many_encoded, 99, fields))
assert(#many_decoded == #many)
print(string.format(
  "Lua asset journal self-test OK: entries=%d bytes=%d elapsed=%.3fs",
  #many_decoded,
  #many_encoded,
  os.clock() - started
))
