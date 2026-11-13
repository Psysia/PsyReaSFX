local source_path = assert(arg[1], "expected neural similarity module")
local source_file = assert(io.open(source_path, "rb"))
local source = source_file:read("*a")
source_file:close()

local separator = package.config:sub(1, 1)
local virtual_files = {}
state = { persistence_read_only = false, neural_similarity_state = "available" }
Host = {
  GetOS = function() return "Win64" end,
  time_precise = function() return 123.25 end,
  file_exists = function(path)
    if virtual_files[path] then return true end
    local file = io.open(path, "rb")
    if file then file:close() return true end
    return false
  end,
  RecursiveCreateDirectory = function() return 1 end,
  ExecProcess = function(command, timeout)
    assert(timeout == -2 and command:match("^powershell%.exe .*%-WindowStyle Hidden %-EncodedCommand [A-Za-z0-9+/=]+$"))
    return ""
  end,
}
reaper = Host
AppState = {
  set = function(key, value) state[key] = value end,
  apply = function(values)
    for key, value in pairs(values) do state[key] = value end
  end,
}
DATA_DIR = os.tmpname() .. "-psyreasfx-neural"
RESOURCE_PATH = DATA_DIR .. "-resource"
SCRIPT_DIR = DATA_DIR .. separator
SEP = separator
Similarity = { frame_budget = 0.006, frame_records = 8192 }
function file_size() return 123 end
function similarity_asset_signature(asset) return asset.signature end
function atomic_file_writer(path)
  local raw = assert(io.open(path .. ".tmp", "wb"))
  return {
    write = function(self, ...)
      local ok, reason = raw:write(...)
      return ok and self or nil, reason
    end,
    close = function()
      assert(raw:close())
      os.remove(path)
      assert(os.rename(path .. ".tmp", path))
      return true
    end,
    abort = function()
      raw:close()
      os.remove(path .. ".tmp")
    end,
  }
end
function set_status() end
function can_run_heavy_job() return true end

assert(load(source, "@" .. source_path, "t", _ENV))()

local cache_root = DATA_DIR .. separator .. "neural_similarity"
local component_root = RESOURCE_PATH .. separator .. "Data" .. separator
  .. "PsyReaSFX" .. separator .. "neural_similarity"
local component_executable = component_root .. separator
  .. "PsyReaSFX.NeuralSidecar.exe"
local component_model = component_root .. separator .. "models" .. separator
  .. NeuralSimilarity.profile
local legacy_executable = cache_root .. separator
  .. "PsyReaSFX.NeuralSidecar.exe"
local legacy_model = cache_root .. separator .. "models" .. separator
  .. NeuralSimilarity.profile
virtual_files[component_executable] = true
virtual_files[component_model .. separator .. "manifest-v1.json"] = true
virtual_files[legacy_executable] = true
virtual_files[legacy_model .. separator .. "manifest-v1.json"] = true
local paths = neural_similarity_paths()
assert(paths.root == cache_root)
assert(paths.component_root == component_root)
assert(paths.executable == component_executable)
assert(paths.model_directory == component_model)
virtual_files[component_executable] = nil
virtual_files[component_model .. separator .. "manifest-v1.json"] = nil
paths = neural_similarity_paths()
assert(paths.executable == legacy_executable)
assert(paths.model_directory == legacy_model)

local encoded = neural_json_encode({
  schema = "x",
  path = [[C:\Sound Library\tab\"quote".wav]],
  values = { true, false, 1.25 },
})
local decoded = neural_json_decode(encoded)
assert(decoded.schema == "x")
assert(decoded.path == [[C:\Sound Library\tab\"quote".wav]])
assert(decoded.values[1] == true and decoded.values[2] == false)
assert(math.abs(decoded.values[3] - 1.25) < 0.000001)
assert(neural_json_decode([["\ud83c\udfa7"]]) == "🎧")
for _, invalid in ipairs({
  "01", "-01", "1.", "1e", "1e+", "1e999", "-1e999", "+1",
  [[{"x":1,"x":2}]], [[{"x":null,"x":2}]], [["\u+123"]],
  string.rep("[", 65) .. "0" .. string.rep("]", 65),
}) do
  assert(not pcall(neural_json_decode, invalid), "invalid/unbounded JSON was accepted: " .. invalid:sub(1, 80))
end
for _, valid in ipairs({ "0", "-0", "1.0", "-0.5e-2", "1E+3", "2e20" }) do
  assert(neural_json_decode(valid) == tonumber(valid), "valid JSON number was rejected")
end

assert(neural_windows_quote_argument("plain") == "plain")
assert(neural_windows_quote_argument([[C:\Program Files\PsyReaSFX\]])
  == [["C:\Program Files\PsyReaSFX\\"]])
assert(neural_windows_quote_argument([[a"b]]) == [["a\"b"]])

local valid, reason = neural_validate_capabilities({
  schema = "PsyReaSFX-Neural-Capabilities-v1",
  protocolVersion = 1,
  operations = { "capabilities", "run-job" },
  jobOperations = { "build-cache", "build-index", "query" },
  profiles = {
    {
      profile = "mn04_as_scene_320_v1", dimensions = 320, sampleRate = 32000,
      decoderVersion = 1,
      supportedExtensions = { "wav", "wave", "aif", "aiff", "flac", "mp3", "ogg", "opus", "wv", "caf", "m4a" },
    },
  },
})
assert(valid and reason == nil)
state.neural_similarity_capabilities = {
  profiles = {
    {
      profile = "mn04_as_scene_320_v1", dimensions = 320, sampleRate = 32000,
      decoderVersion = 1,
      supportedExtensions = { "wav", "wave", "aif", "aiff", "flac", "mp3", "ogg", "opus", "wv", "caf", "m4a" },
    },
  },
}

valid, reason = neural_validate_capabilities({
  schema = "PsyReaSFX-Neural-Capabilities-v1",
  protocolVersion = 2,
  operations = { "run-job" },
  jobOperations = { "build-cache", "build-index", "query" },
  profiles = {},
})
assert(not valid and reason == "protocol_mismatch")

assert(neural_similarity_asset_supported({
  ready = true, path = "effect.wav", source_type = "WAVE",
  sample_rate = 48000, bit_depth = 24,
}))
assert(neural_similarity_asset_supported({
  ready = true, path = "effect.flac", source_type = "FLAC",
  sample_rate = 96000, bit_depth = 24,
}))
assert(neural_similarity_asset_supported({
  ready = true, path = "effect.opus", source_type = "OPUS",
  sample_rate = 48000, bit_depth = 0,
}))
assert(not neural_similarity_asset_supported({
  ready = true, path = "effect.unknown", source_type = "UNKNOWN",
  sample_rate = 48000, bit_depth = 24,
}))

local request_value = neural_json_decode(neural_json_encode({
  schema = "PsyReaSFX-Neural-Job-v1",
  operation = "query",
  cachePath = [[C:\cache.bin]],
  statusPath = [[C:\job.status]],
  resultPath = [[C:\job.result]],
  cancelPath = [[C:\job.cancel]],
  referenceSignature = "0123456789abcdef",
  topK = 1000,
  searchMode = "auto",
}))
assert(request_value.schema == "PsyReaSFX-Neural-Job-v1")
assert(request_value.referenceSignature == "0123456789abcdef")
assert(request_value.topK == 1000 and request_value.searchMode == "auto")

local result = neural_json_decode([[
{"schema":"PsyReaSFX-Neural-Job-Result-v1","requestId":"lua-1-query",
"operation":"query","profile":"mn04_as_scene_320_v1","dimensions":320,
"cancelled":false,"matches":[{"signature":"fedcba9876543210","score":0.875}]}
]])
assert(result.matches[1].signature == "fedcba9876543210")
assert(math.abs(result.matches[1].score - 0.875) < 0.000001)

assert(source:find('session.neural_attempted = true', 1, true))
assert(source:find('session.phase = "reference"', 1, true))
assert(source:find('state.neural_similarity_state ~= "available"', 1, true))
assert(source:find('tonumber(profile.decoderVersion or 0) >= 1', 1, true))
assert(source:find('profile.supportedExtensions or {}', 1, true))
assert(source:find('written < 1 or written > session.neural_asset_count', 1, true))
assert(source:find('session.neural_decode_failed = math.max', 1, true))

Similarity.frame_records = 2
local reference = {
  ready = true, path = "reference.wav", source_type = "WAVE",
  sample_rate = 32000, bit_depth = 16, signature = "0000000000000001",
}
local session = {
  reference = reference,
  source = {
    reference,
    { ready = true, path = "second.wav", source_type = "WAVE",
      sample_rate = 32000, bit_depth = 16, signature = "0000000000000002" },
    { ready = true, path = "third.wav", source_type = "WAVE",
      sample_rate = 32000, bit_depth = 16, signature = "0000000000000003" },
  },
  total = 3,
  scope = "all",
}
assert(neural_similarity_try_start(session) and session.phase == "neural_prepare")
assert(process_neural_similarity_search(session))
assert(session.phase == "neural_prepare" and session.neural_prepare_index == 3)
session.source[3].source_type = "UNKNOWN"
session.source[3].path = "third.unknown"
assert(process_neural_similarity_search(session))
assert(session.phase == "reference" and session.neural_failure == "candidate_format")

local ordered_path = os.tmpname() .. "-candidates.txt"
assert(neural_write_lines_atomic(ordered_path, { "a\n", "b\n" }))
local ordered_file = assert(io.open(ordered_path, "rb"))
assert(ordered_file:read("*a") == "a\nb\n")
ordered_file:close()
os.remove(ordered_path)

-- Real status files feed the UI progress and heartbeat. A launch that never
-- produces a status exits to fallback promptly instead of waiting 10 minutes.
local status_path=os.tmpname()
local result_path=os.tmpname() os.remove(result_path)
local cancel_path=os.tmpname() os.remove(cancel_path)
local test_paths={status=status_path,result=result_path,cancel=cancel_path,
  request=status_path..".request",assets=status_path..".assets",candidates=status_path..".candidates"}
local job_clock=200
local original_clock=Host.time_precise
Host.time_precise=function() return job_clock end
local waiting={phase="neural_wait",neural_job={operation="build-cache",request_id="test-cache",
  started=200,last_change=200,last_status="",paths=test_paths}}
local status_file=assert(io.open(status_path,"wb"))
status_file:write(neural_json_encode({schema="PsyReaSFX-Neural-Job-Status-v1",requestId="test-cache",
  operation="build-cache",state="running",phase="embedding",completed=0,total=76530,
  windowCompleted=2,windowTotal=34,updatedUtc="2026-10-27T10:00:00Z"})) status_file:close()
process_neural_similarity_search(waiting)
assert(waiting.phase=="neural_wait" and waiting.neural_progress.windowCompleted==2 and waiting.neural_job.status_seen)
job_clock=201 status_file=assert(io.open(status_path,"wb"))
status_file:write(neural_json_encode({schema="PsyReaSFX-Neural-Job-Status-v1",requestId="test-cache",
  operation="build-cache",state="running",phase="embedding",completed=0,total=76530,
  windowCompleted=3,windowTotal=34,updatedUtc="2026-10-27T10:00:01Z"})) status_file:close()
process_neural_similarity_search(waiting)
assert(waiting.neural_progress.windowCompleted==3 and waiting.neural_job.last_change==201)
os.remove(status_path)
job_clock=240
local never_started={phase="neural_wait",neural_job={operation="query",request_id="test-query",started=200,
  last_change=200,paths=test_paths}}
process_neural_similarity_search(never_started)
assert(never_started.phase=="reference" and never_started.neural_failure=="job_start_timeout")
os.remove(cancel_path)
Host.time_precise=original_clock

-- B10: a status read that lands in the sidecar's rename window (missing file,
-- partial JSON) is retried; only consecutive failures fall back, and a
-- successful read resets the counter.
do
  local retry_status = os.tmpname()
  local retry_paths = { status = retry_status, result = retry_status .. ".r",
    cancel = retry_status .. ".c", request = retry_status .. ".q",
    assets = retry_status .. ".a", candidates = retry_status .. ".d" }
  local clock = 1000
  Host.time_precise = function() return clock end
  local function new_job()
    return { phase = "neural_wait", neural_job = { operation = "build-cache",
      request_id = "retry-cache", started = clock, last_change = clock,
      last_status = "", paths = retry_paths } }
  end
  local function write_status(content)
    local file = assert(io.open(retry_status, "wb"))
    file:write(content)
    file:close()
  end
  local function valid_status(window)
    return neural_json_encode({ schema = "PsyReaSFX-Neural-Job-Status-v1",
      requestId = "retry-cache", operation = "build-cache", state = "running",
      phase = "building-cache", completed = window, total = 100 })
  end
  local function poll(session)
    clock = clock + 1
    process_neural_similarity_search(session)
  end
  assert(NeuralSimilarity.status_failure_limit == 5)

  -- partial JSON for limit-1 polls, then a valid file: keeps waiting
  local session = new_job()
  write_status(valid_status(1))
  poll(session)
  assert(session.phase == "neural_wait" and session.neural_job.status_seen)
  write_status('{"schema":"PsyReaSFX-Neu')
  for _ = 1, NeuralSimilarity.status_failure_limit - 1 do
    poll(session)
    assert(session.phase == "neural_wait", "transient partial status must not fall back")
  end
  assert(session.neural_job.status_failures == NeuralSimilarity.status_failure_limit - 1)
  write_status(valid_status(2))
  poll(session)
  assert(session.phase == "neural_wait" and session.neural_job.status_failures == 0
    and session.neural_progress.completed == 2, "successful read must clear the counter")

  -- limit consecutive failures: fall back with the read error
  write_status('{"broken":')
  for _ = 1, NeuralSimilarity.status_failure_limit - 1 do poll(session) end
  assert(session.phase == "neural_wait")
  poll(session)
  assert(session.phase == "reference" and session.neural_failure == "invalid_json")

  -- status path present but unreadable (virtual): read_failed after the limit
  os.remove(retry_status)
  virtual_files[retry_status] = true
  local unreadable = new_job()
  unreadable.neural_job.status_seen = true
  for _ = 1, NeuralSimilarity.status_failure_limit - 1 do
    poll(unreadable)
    assert(unreadable.phase == "neural_wait")
  end
  poll(unreadable)
  assert(unreadable.phase == "reference" and unreadable.neural_failure == "read_failed")
  virtual_files[retry_status] = nil

  -- oversize status is never retried
  write_status(string.rep(" ", 64 * 1024 + 8))
  local oversize = new_job()
  poll(oversize)
  assert(oversize.phase == "reference" and oversize.neural_failure == "too_large")

  -- transient failures never extend past the stall timeout
  write_status('{"partial"')
  local stalled = new_job()
  stalled.neural_job.status_seen = true
  clock = clock + NeuralSimilarity.job_stall_timeout + 5
  poll(stalled)
  assert(stalled.phase == "reference" and stalled.neural_failure == "invalid_json")

  -- the start timeout still applies while the status keeps failing
  local unstarted = new_job()
  clock = clock + 1
  unstarted.neural_job.started = clock - NeuralSimilarity.job_start_timeout - 1
  unstarted.neural_job.last_change = clock
  virtual_files[retry_status] = true
  os.remove(retry_status)
  poll(unstarted)
  assert(unstarted.phase == "reference" and unstarted.neural_failure == "job_start_timeout")
  virtual_files[retry_status] = nil
  os.remove(retry_status)
  Host.time_precise = original_clock
end

-- T13: the optimized JSON decoder against the previous character-by-character
-- implementation, on valid, escaped, truncated and randomly corrupted input.
do
  local function reference_decode(text)
    text = tostring(text or "")
    local position = 1
    local length = #text
    local function skip_space()
      local _, last = text:find("^[ \t\r\n]*", position)
      position = (last or position - 1) + 1
    end
    local parse_value
    local function parse_string()
      if text:sub(position, position) ~= '"' then error("expected JSON string") end
      position = position + 1
      local output = {}
      while position <= length do
        local character = text:sub(position, position)
        if character == '"' then
          position = position + 1
          return table.concat(output)
        end
        if character == "\\" then
          local escape = text:sub(position + 1, position + 1)
          local mapped = ({ ['"'] = '"', ['\\'] = '\\', ['/'] = '/',
            b = '\b', f = '\f', n = '\n', r = '\r', t = '\t' })[escape]
          if mapped then
            output[#output + 1] = mapped
            position = position + 2
          elseif escape == "u" then
            local hex = text:sub(position + 2, position + 5)
            local code = tonumber(hex, 16)
            if not code or #hex ~= 4 then error("invalid JSON unicode escape") end
            position = position + 6
            if code >= 0xd800 and code <= 0xdbff then
              if text:sub(position, position + 1) ~= "\\u" then
                error("incomplete JSON surrogate pair")
              end
              local low = tonumber(text:sub(position + 2, position + 5), 16)
              if not low or low < 0xdc00 or low > 0xdfff then
                error("invalid JSON surrogate pair")
              end
              code = 0x10000 + (code - 0xd800) * 0x400 + (low - 0xdc00)
              position = position + 6
            elseif code >= 0xdc00 and code <= 0xdfff then
              error("invalid JSON low surrogate")
            end
            output[#output + 1] = utf8.char(code)
          else
            error("invalid JSON escape")
          end
        else
          if string.byte(character) < 32 then error("invalid JSON string character") end
          output[#output + 1] = character
          position = position + 1
        end
      end
      error("unterminated JSON string")
    end
    local function parse_array()
      position = position + 1
      local output = {}
      skip_space()
      if text:sub(position, position) == "]" then position = position + 1 return output end
      while true do
        output[#output + 1] = parse_value()
        skip_space()
        local character = text:sub(position, position)
        if character == "]" then position = position + 1 return output end
        if character ~= "," then error("expected JSON array separator") end
        position = position + 1
      end
    end
    local function parse_object()
      position = position + 1
      local output = {}
      skip_space()
      if text:sub(position, position) == "}" then position = position + 1 return output end
      while true do
        skip_space()
        local key = parse_string()
        skip_space()
        if text:sub(position, position) ~= ":" then error("expected JSON property separator") end
        position = position + 1
        output[key] = parse_value()
        skip_space()
        local character = text:sub(position, position)
        if character == "}" then position = position + 1 return output end
        if character ~= "," then error("expected JSON object separator") end
        position = position + 1
      end
    end
    function parse_value()
      skip_space()
      local character = text:sub(position, position)
      if character == '"' then return parse_string() end
      if character == "[" then return parse_array() end
      if character == "{" then return parse_object() end
      local literals = { ["true"] = true, ["false"] = false }
      for literal, value in pairs(literals) do
        if text:sub(position, position + #literal - 1) == literal then
          position = position + #literal
          return value
        end
      end
      if text:sub(position, position + 3) == "null" then
        position = position + 4
        return nil
      end
      local first, last = text:find("^-?%d+%.?%d*[eE]?[+-]?%d*", position)
      if not first then error("invalid JSON value") end
      local number = tonumber(text:sub(first, last))
      if not number then error("invalid JSON number") end
      position = last + 1
      return number
    end
    local value = parse_value()
    skip_space()
    if position <= length then error("trailing JSON data") end
    return value
  end

  local function same_value(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then
      return left == right or (left ~= left and right ~= right)
    end
    for key, value in pairs(left) do
      if not same_value(value, right[key]) then return false end
    end
    for key in pairs(right) do
      if left[key] == nil then return false end
    end
    return true
  end
  local function compare(text)
    local old_ok, old_value = pcall(reference_decode, text)
    local new_ok, new_value = pcall(neural_json_decode, text)
    -- The previous parser accepted malformed numbers and duplicate properties.
    -- Valid encoder output still has to match; corruptions may be rejected
    -- earlier, but must never become newly accepted.
    assert(old_ok or not new_ok, "decoder newly accepted corrupt JSON: " .. string.format("%q", text))
    if old_ok and new_ok then
      assert(same_value(old_value, new_value), "decoded value differs: " .. string.format("%q", text))
    end
    return new_ok
  end

  local seed = 20260611
  local function random(limit)
    seed = (seed * 1103515245 + 12345) & 0x7fffffff
    return seed % limit
  end
  local alphabet = { "a", "b", "Z", " ", "/", "é", "中", "🎧", "\\", '"', "\n", "\t",
    "\r", "\0", "\1", "\31", "\127", "\u{7ff}", "{", "}", "[", "]", ",", ":" }
  local function random_string()
    local pieces = {}
    for index = 1, random(14) do pieces[index] = alphabet[random(#alphabet) + 1] end
    return table.concat(pieces)
  end
  local function random_value(depth)
    local kind = random(depth > 3 and 5 or 8)
    if kind == 0 then return random_string() end
    if kind == 1 then return random(100000) / 8 - 5000 end
    if kind == 2 then return random(2) == 0 end
    if kind == 3 then return random(50000) - 25000 end
    if kind == 4 then return random_string() .. random_string() end
    if kind <= 5 then
      local array = {}
      for index = 1, random(5) do array[index] = random_value(depth + 1) end
      return array
    end
    local object = {}
    for _ = 1, random(5) do object[random_string()] = random_value(depth + 1) end
    return object
  end

  local checked = 0
  local rejected = 0
  for _ = 1, 3000 do
    local encoded = neural_json_encode(random_value(0))
    assert(compare(encoded), "valid encoder output must decode")
    local spaced = encoded:gsub("([,:%[%]{}])", function(c)
      return random(3) == 0 and (" " .. c .. "\t\r\n ") or c
    end)
    compare(spaced)
    -- truncations and byte mutations of valid documents
    for _ = 1, 4 do
      local cut = random(#encoded + 1)
      if not compare(encoded:sub(1, cut)) then rejected = rejected + 1 end
      local mutated = encoded
      for _ = 1, 1 + random(3) do
        if #mutated > 0 then
          local at = random(#mutated) + 1
          local replacement = string.char(random(256))
          if random(2) == 0 then
            replacement = ({ '"', "\\", "u", "d", "8", "\0", "\31", "\127", "e", "-", ",", ":" })[random(12) + 1]
          end
          mutated = mutated:sub(1, at - 1) .. replacement .. mutated:sub(at + 1)
        end
      end
      if not compare(mutated) then rejected = rejected + 1 end
    end
    checked = checked + 1
  end
  assert(rejected > 1000, "fuzz must exercise the error paths")

  -- Hand-picked edge cases around escapes, surrogates and delimiters.
  for _, text in ipairs({
    '""', '"a"', '"\\', '"\\u"', '"\\u12"', '"\\u12G4"', '"\\ud83c"', '"\\ud83c\\u0041"',
    '"\\udc00"', '"\\ud83c\\udfa7x"', '"\\ud83c\\udfa7\\ud83c\\udfa7"', '"\\u 123"',
    '"\\u-001"', '"a\\/b\\b\\f\\n\\r\\t\\"\\\\"', '"\\x"', '"abc', '"abc\\', '"ab\0c"',
    '"ab\31c"', '"ab\127c"', '"é中🎧"', '[]', '[ ]', '[1,]', '[,1]', '[null]', '[null,1,null]',
    '[1 2]', '{}', '{ }', '{"a":null}', '{"a":1,"a":null}', '{"a":1,"a":2}', '{"a"}', '{"a":}',
    '{1:2}', '{"a":1,}', '{"a":1 "b":2}', 'true', 'false', 'null', 'tru', 'nul', 'truefalse',
    ' true ', '1', '-1', '1.5e3', '1e', '-', '--1', '01', '1.', '.5', '', '   ', 'true x',
    '[true,false,null,"x",1.5,{"k":[1,2,{"z":"\\n"}]}]',
    '{"signature":"fedcba9876543210","score":0.875}',
  }) do
    compare(text)
  end
  -- deep nesting and a long plain string exercise the bulk-copy path
  compare(string.rep("[", 150) .. string.rep("]", 150))
  compare('"' .. string.rep("abcdefghij", 5000) .. '"')
  compare('"' .. string.rep("abcdefghij\\n", 5000) .. '"')
  compare(neural_json_encode({ list = (function()
    local items = {}
    for index = 1, 2000 do items[index] = { signature = string.format("%016x", index), score = index / 2000 } end
    return items
  end)() }))
end

print("lua neural similarity self-test passed")
