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
    assert(timeout == -2 and command:find("capabilities", 1, true))
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

print("lua neural similarity self-test passed")
