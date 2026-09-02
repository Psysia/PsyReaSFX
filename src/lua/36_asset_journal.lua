-- Generation-bound asset journal codec. Decoding validates the complete
-- payload before callers apply any entry, so a torn/corrupt journal cannot
-- partially mutate the in-memory catalog.

local ASSET_JOURNAL_MAGIC = "psyreasfx_asset_journal"
local ASSET_JOURNAL_VERSION = 1

function new_asset_change_set()
  return { by_key = {}, count = 0, requires_snapshot = false }
end

function record_asset_change(change_set, key, operation, values)
  if type(change_set) ~= "table" or type(change_set.by_key) ~= "table"
    or (operation ~= "upsert" and operation ~= "delete") then
    return false
  end
  key = tostring(key or "")
  if key == "" or type(values) ~= "table" then return false end
  if not change_set.by_key[key] then
    change_set.count = (change_set.count or 0) + 1
  end
  change_set.by_key[key] = { op = operation, values = values }
  return true
end

function require_asset_snapshot(change_set)
  if type(change_set) ~= "table" then return false end
  change_set.requires_snapshot = true
  return true
end

function ordered_asset_changes(change_set)
  local keys = {}
  for key in pairs(change_set and change_set.by_key or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  local entries = {}
  for _, key in ipairs(keys) do
    entries[#entries + 1] = change_set.by_key[key]
  end
  return entries
end

function clear_asset_changes(change_set)
  if type(change_set) ~= "table" then return false end
  change_set.by_key = {}
  change_set.count = 0
  change_set.requires_snapshot = false
  return true
end

local function journal_escape(value)
  return tostring(value or "")
    :gsub("\\", "\\\\")
    :gsub("\t", "\\t")
    :gsub("\r", "\\r")
    :gsub("\n", "\\n")
end

local function journal_split(line)
  local fields = {}
  local current = {}
  local escaped = false
  local text = tostring(line or "")
  for index = 1, #text do
    local character = text:sub(index, index)
    if escaped then
      current[#current + 1] = character == "t" and "\t"
        or character == "r" and "\r"
        or character == "n" and "\n"
        or character
      escaped = false
    elseif character == "\\" then
      escaped = true
    elseif character == "\t" then
      fields[#fields + 1] = table.concat(current)
      current = {}
    else
      current[#current + 1] = character
    end
  end
  if escaped then current[#current + 1] = "\\" end
  fields[#fields + 1] = table.concat(current)
  return fields
end

local function journal_checksum(text)
  local first = 1
  local second = 0
  for index = 1, #text do
    first = (first + text:byte(index)) % 65521
    second = (second + first) % 65521
  end
  return string.format("%08x", second * 65536 + first)
end

local function journal_fields_equal(left, right)
  if #left ~= #right then return false end
  for index = 1, #left do
    if left[index] ~= right[index] then return false end
  end
  return true
end

function encode_asset_journal(generation, fields, entries)
  generation = tonumber(generation)
  if not generation or generation < 0 or generation % 1 ~= 0 then
    return nil, "invalid_generation"
  end
  if type(fields) ~= "table" or #fields == 0 then
    return nil, "invalid_fields"
  end

  local lines = {
    ASSET_JOURNAL_MAGIC .. "\t" .. tostring(ASSET_JOURNAL_VERSION),
    "base_generation\t" .. tostring(generation),
    "op\t" .. table.concat(fields, "\t"),
  }
  for _, entry in ipairs(entries or {}) do
    local operation = entry.op
    local values = entry.values
    if (operation ~= "upsert" and operation ~= "delete")
      or type(values) ~= "table" or #values ~= #fields then
      return nil, "invalid_entry"
    end
    local encoded = { operation }
    for index = 1, #fields do
      encoded[#encoded + 1] = journal_escape(values[index])
    end
    local payload = table.concat(encoded, "\t")
    lines[#lines + 1] = payload .. "\t" .. journal_checksum(payload)
  end
  return table.concat(lines, "\n") .. "\n"
end

function decode_asset_journal(text, expected_generation, expected_fields)
  text = tostring(text or "")
  if text == "" or text:sub(-1) ~= "\n" then
    return nil, "truncated_payload"
  end
  local lines = {}
  for line in text:gmatch("([^\n]*)\n") do
    lines[#lines + 1] = line:gsub("\r$", "")
  end
  if #lines < 3 then return nil, "truncated_header" end

  local magic = journal_split(lines[1])
  if magic[1] ~= ASSET_JOURNAL_MAGIC
    or tonumber(magic[2]) ~= ASSET_JOURNAL_VERSION then
    return nil, "unsupported_schema"
  end
  local generation = journal_split(lines[2])
  if generation[1] ~= "base_generation"
    or tonumber(generation[2]) ~= tonumber(expected_generation) then
    return nil, "generation_mismatch"
  end
  local header = journal_split(lines[3])
  if header[1] ~= "op" then return nil, "invalid_header" end
  table.remove(header, 1)
  if not journal_fields_equal(header, expected_fields or {}) then
    return nil, "field_mismatch"
  end

  local entries = {}
  for index = 4, #lines do
    local line = lines[index]
    if line ~= "" then
      local checksum_offset = line:match("^.*()\t")
      if not checksum_offset then return nil, "missing_checksum" end
      local payload = line:sub(1, checksum_offset - 1)
      local checksum = line:sub(checksum_offset + 1)
      if journal_checksum(payload) ~= checksum then
        return nil, "checksum_mismatch"
      end
      local values = journal_split(payload)
      local operation = table.remove(values, 1)
      if (operation ~= "upsert" and operation ~= "delete")
        or #values ~= #header then
        return nil, "invalid_entry"
      end
      entries[#entries + 1] = { op = operation, values = values }
    end
  end
  return entries
end

function read_asset_journal(path, expected_generation, expected_fields)
  local file, open_error = io.open(path, "rb")
  if not file then return nil, open_error or "missing" end
  local text, read_error = file:read("*a")
  local closed = file:close()
  if not text or not closed then
    return nil, read_error or "read_failed"
  end
  return decode_asset_journal(
    text,
    expected_generation,
    expected_fields
  )
end
