local module_path = assert(arg[1], "asset journal module is required")
assert(loadfile(module_path))()

local changes = new_asset_change_set()
assert(record_asset_change(changes, "b", "upsert", { "b1" }))
assert(record_asset_change(changes, "a", "upsert", { "a1" }))
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

local _, generation_error = decode_asset_journal(encoded, 18, fields)
assert(generation_error == "generation_mismatch")
local _, field_error = decode_asset_journal(encoded, 17, { "path", "name" })
assert(field_error == "field_mismatch")
local _, truncated_error = decode_asset_journal(encoded:sub(1, #encoded - 5), 17, fields)
assert(truncated_error == "truncated_payload")
local corrupt = encoded:gsub("new value", "bad value", 1)
local _, checksum_error = decode_asset_journal(corrupt, 17, fields)
assert(checksum_error == "checksum_mismatch")

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
