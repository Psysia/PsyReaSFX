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

local earlier = new_asset_change_set()
local later = new_asset_change_set()
assert(record_asset_change(earlier, "same", "upsert", { "old" }))
assert(record_asset_change(earlier, "old-only", "delete", { "gone" }))
assert(record_asset_change(later, "same", "upsert", { "new" }))
assert(record_asset_change(later, "new-only", "upsert", { "added" }))
assert(require_asset_snapshot(later))
assert(merge_asset_changes(earlier, later))
assert(earlier.count == 3 and earlier.requires_snapshot)
local merged = earlier.by_key
assert(merged.same.values[1] == "new")
assert(merged["old-only"].op == "delete")
assert(merged["new-only"].op == "upsert")
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
local yielded = 0
local bounded_entries = {}
for index = 1, 128 do bounded_entries[index] = entries[(index - 1) % #entries + 1] end
local bounded_text = assert(encode_asset_journal(17, fields, bounded_entries))
local bounded = assert(decode_asset_journal(bounded_text, 17, fields, function()
  yielded = yielded + 1
end))
assert(#bounded == 128 and yielded > 0, "journal validation must offer bounded startup checkpoints")
local _, corrupt_error = decode_asset_journal(bounded_text:gsub("C:", "D:", 1), 17, fields)
assert(corrupt_error == "checksum_mismatch", "incremental validation must reject corrupted journals before replay")
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
local legacy_entries, legacy_error, legacy_fields =
  decode_asset_journal(encoded, 17, nil)
assert(legacy_entries and not legacy_error)
assert(asset_journal_fields_equal(legacy_fields, fields))
assert(asset_journal_fields_equal(fields, { "path", "name", "description" }))
assert(not asset_journal_fields_equal(fields, { "path", "name" }))
local remapped = assert(asset_journal_remap_values(
  { "path", "name" },
  { "C:/Library/old.wav", "old.wav" },
  { "asset_id", "path", "name", "keywords" }
))
assert(remapped[1] == "")
assert(remapped[2] == "C:/Library/old.wav")
assert(remapped[3] == "old.wav")
assert(remapped[4] == "")
local _, unknown_field_error = asset_journal_remap_values(
  { "path", "future_field" },
  { "C:/Library/future.wav", "future" },
  { "path", "name" }
)
assert(unknown_field_error == "invalid_fields")
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

-- Differential check of the optimised escape/checksum against the original
-- (byte-at-a-time Adler-32, four chained gsubs). Old journals must still
-- replay, and newly written journals must stay byte-identical.
do
  local function reference_escape(value)
    return (tostring(value or "")
      :gsub("\\", "\\\\")
      :gsub("\t", "\\t")
      :gsub("\r", "\\r")
      :gsub("\n", "\\n"))
  end
  local function reference_checksum(text)
    local first = 1
    local second = 0
    for index = 1, #text do
      first = (first + text:byte(index)) % 65521
      second = (second + first) % 65521
    end
    return string.format("%08x", second * 65536 + first)
  end

  local diff_fields = { "value" }
  local function check_value(value)
    local text = assert(encode_asset_journal(
      3, diff_fields, { { op = "upsert", values = { value } } }
    ))
    local payload = "upsert\t" .. reference_escape(value)
    local last_line = text:match("([^\n]*)\n$")
    assert(
      last_line == payload .. "\t" .. reference_checksum(payload),
      "journal line differs for value of length " .. #value
    )
    local decoded = assert(decode_asset_journal(text, 3, diff_fields))
    assert(#decoded == 1 and decoded[1].values[1] == value,
      "journal round trip differs for value of length " .. #value)
  end

  local samples = {
    "", "a", "\\", "\t", "\r", "\n", "\\\\", "\\t", "a\\b\tc\rd\ne",
    "\255\254\128\0\1", "\\\n\\\t\\\r", "plain ascii path C:/x/y.wav",
  }
  for _, sample in ipairs(samples) do check_value(sample) end

  -- Lengths around the 16-byte unroll and the 5552-byte modulus block.
  local lengths = {}
  for length = 0, 40 do lengths[#lengths + 1] = length end
  for _, base in ipairs({ 5552, 11104, 16656 }) do
    for delta = -20, 20 do lengths[#lengths + 1] = base + delta end
  end
  lengths[#lengths + 1] = 100000
  lengths[#lengths + 1] = 300001
  for _, length in ipairs(lengths) do
    check_value(string.rep("\255", length))  -- worst case for overflow
    check_value(string.rep("x", length))
  end

  -- Deterministic pseudo-random bytes biased toward the special characters.
  local seed = 987654321
  local function next_random(limit)
    seed = (seed * 1103515245 + 12345) % 2147483648
    return seed % limit
  end
  local specials = { 92, 9, 13, 10 }
  for _ = 1, 400 do
    local length = next_random(200)
    if next_random(10) == 0 then length = 5500 + next_random(200) end
    local bytes = {}
    for index = 1, length do
      if next_random(6) == 0 then
        bytes[index] = string.char(specials[next_random(4) + 1])
      else
        bytes[index] = string.char(next_random(256))
      end
    end
    -- A raw tab/newline cannot survive inside a checksum-free field, but the
    -- escape step removes them, so any byte string is valid input here.
    check_value(table.concat(bytes))
  end
end

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
