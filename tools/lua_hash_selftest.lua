-- FNV-1a and the sampled duplicate fingerprint must stay byte-for-byte equal to
-- the original implementations: fingerprints are persisted in the catalog and
-- compared across runs, so a different digest would silently orphan them.
local core_path = assert(arg[1], "UI core module is required")
local runtime_path = assert(arg[2], "runtime UI module is required")

local function read(path)
  local handle = assert(io.open(path, "rb"))
  local text = handle:read("*a")
  handle:close()
  return text
end
local function region(source, first, following)
  local at = assert(source:find(first, 1, true), first)
  local last = assert(source:find(following, at + #first, true), following)
  return source:sub(at, last - 1)
end

local core, runtime = read(core_path), read(runtime_path)
assert(load(region(core, "FNV1A_OFFSET = 2166136261", "function mark_interaction()")))()
assert(load(region(runtime, "function sampled_file_fingerprint(", "function start_duplicate_scan()")))()

local function reference_fnv1a(text)
  local hash = 2166136261
  for index = 1, #text do
    hash = ((hash ~ text:byte(index)) * 16777619) & 0xFFFFFFFF
  end
  return string.format("%08x", hash)
end

local function reference_fingerprint(path, known_size)
  local file = io.open(path, "rb")
  if not file then return nil end
  local size = tonumber(known_size) or file:seek("end") or 0
  local chunk_size = 65536
  local positions = {
    0,
    math.max(0, math.floor(size / 2 - chunk_size / 2)),
    math.max(0, size - chunk_size),
  }
  local chunks = {}
  for _, position in ipairs(positions) do
    file:seek("set", position)
    chunks[#chunks + 1] = file:read(chunk_size) or ""
  end
  file:close()
  local payload = tostring(size) .. "|" .. table.concat(chunks, "|")
  local reverse_payload = tostring(size) .. "|" .. chunks[3] .. "|" .. chunks[2] .. "|" .. chunks[1]
  return reference_fnv1a(payload) .. reference_fnv1a(reverse_payload)
end

local seed = 20261109
local function random_byte()
  seed = (seed * 1103515245 + 12345) % 2147483648
  return (seed >> 8) % 256
end
local function random_bytes(length)
  local bytes = {}
  for index = 1, length do bytes[index] = string.char(random_byte()) end
  return table.concat(bytes)
end

-- Known vectors from the FNV reference.
assert(fnv1a("") == "811c9dc5")
assert(fnv1a("a") == "e40c292c")
assert(fnv1a("foobar") == "bf9cf968")

local checked = 0
for length = 0, 70 do
  local text = random_bytes(length)
  assert(fnv1a(text) == reference_fnv1a(text), "fnv1a mismatch at length " .. length)
  checked = checked + 1
end
for _, length in ipairs({ 255, 256, 1000, 4095, 4096, 65536, 100003 }) do
  local text = random_bytes(length)
  assert(fnv1a(text) == reference_fnv1a(text), "fnv1a mismatch at length " .. length)
  assert(fnv1a(string.rep("\255", length)) == reference_fnv1a(string.rep("\255", length)))
  checked = checked + 1
end

-- Streaming equals hashing the concatenation, for any split point.
do
  local text = random_bytes(1234)
  for split = 0, #text, 97 do
    local streamed = fnv1a_feed(FNV1A_OFFSET, text:sub(1, split))
    streamed = fnv1a_feed(streamed, text:sub(split + 1))
    assert(string.format("%08x", streamed) == reference_fnv1a(text), "streamed hash mismatch")
  end
end

-- Sampled fingerprints over files around the chunk boundaries.
local temp_dir = os.getenv("TEMP") or os.getenv("TMP") or "."
local fingerprints = 0
for _, size in ipairs({ 0, 1, 100, 65535, 65536, 65537, 98304, 131072, 131073, 200000, 300001 }) do
  local path = temp_dir .. "/psyreasfx-fingerprint-" .. size .. ".bin"
  local handle = assert(io.open(path, "wb"))
  handle:write(random_bytes(size))
  handle:close()
  for _, known_size in ipairs({ size, false }) do
    local expected = reference_fingerprint(path, known_size or nil)
    local actual = sampled_file_fingerprint(path, known_size or nil)
    assert(actual == expected, string.format(
      "fingerprint mismatch size=%d known=%s expected=%s actual=%s",
      size, tostring(known_size), tostring(expected), tostring(actual)))
    assert(#actual == 16)
    fingerprints = fingerprints + 1
  end
  os.remove(path)
end
assert(sampled_file_fingerprint(temp_dir .. "/psyreasfx-missing-fingerprint.bin", 10) == nil)

-- TSV field splitting and escaping must match the previous implementation.
do
  assert(load(region(core, "function escape_tsv(value)", "function split_words(text)")))()

  local function reference_split(line)
    local fields = {}
    for field in (line .. "\t"):gmatch("(.-)\t") do
      fields[#fields + 1] = unescape_tsv(field)
    end
    return fields
  end

  local tsv_cases = 0
  local fragments = { "", "a", "path/to/file.wav", "%", "%25", "%09", "%0A", "%0D", "%zz", "50%", "中文", " ", "x%" }
  local function random_line()
    local parts = {}
    for index = 1, random_byte() % 9 do
      parts[index] = fragments[random_byte() % #fragments + 1]
    end
    return table.concat(parts, "\t")
  end
  local special = { "", "\t", "\t\t", "a\t", "\ta", "a\t\tb", "%", "a%09b", "100%\tx%25" }
  for _, line in ipairs(special) do
    local expected, actual = reference_split(line), split_tsv(line)
    assert(#expected == #actual, "field count differs for " .. line)
    for index = 1, #expected do assert(expected[index] == actual[index]) end
    tsv_cases = tsv_cases + 1
  end
  for _ = 1, 2000 do
    local line = random_line()
    local expected, actual = reference_split(line), split_tsv(line)
    assert(#expected == #actual, "field count differs")
    for index = 1, #expected do assert(expected[index] == actual[index], "field differs") end
    tsv_cases = tsv_cases + 1
  end
  -- Escaping then splitting round-trips arbitrary field text.
  for _ = 1, 500 do
    local values = {}
    for index = 1, 1 + random_byte() % 5 do
      values[index] = random_bytes(random_byte() % 12)
    end
    local escaped = {}
    for index, value in ipairs(values) do escaped[index] = escape_tsv(value) end
    local fields = split_tsv(table.concat(escaped, "\t"))
    assert(#fields == #values, "round trip field count")
    for index = 1, #values do assert(fields[index] == values[index], "round trip value") end
    tsv_cases = tsv_cases + 1
  end
  print(string.format("Lua TSV self-test passed: %d lines identical to the previous splitter", tsv_cases))
end

print(string.format("Lua hash self-test passed: %d hashes, %d fingerprints identical", checked, fingerprints))
