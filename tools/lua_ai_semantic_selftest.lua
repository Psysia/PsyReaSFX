local json_source_path = assert(arg[1], "expected neural JSON module")
local ai_source_path = assert(arg[2], "expected AI semantic module")
local jobs_source_path = assert(arg[3], "expected jobs/storage module")

local function read_all(path)
  local file = assert(io.open(path, "rb"))
  local value = file:read("*a")
  file:close()
  return value
end

local separator = package.config:sub(1, 1)
local virtual_files = {}
state = {
  persistence_read_only = false,
  ai_provider = "deepseek",
  ai_api_url = "https://api.deepseek.com/chat/completions",
  ai_model = "deepseek-flash",
  ai_api_key_saved = true,
  ai_request_sequence = 0,
  active_collection_id = nil,
  root_filter = nil,
  library_filter_id = nil,
  status_filter = nil,
  collection_by_id = {},
}
Host = {
  GetOS = function() return "Win64" end,
  time_precise = function() return 10 end,
  file_exists = function(path) return virtual_files[path] == true end,
  RecursiveCreateDirectory = function() return 1 end,
  ExecProcess = function() return "" end,
}
reaper = Host
AppState = {
  set = function(key, value) state[key] = value end,
  apply = function(values)
    for key, value in pairs(values) do state[key] = value end
  end,
  mark_dirty = function() end,
}
DATA_DIR = os.tmpname() .. "-psyreasfx-ai"
SEP = separator
Jobs = {
  accepting = true,
  active = {},
  generation = 0,
  history = {},
}
function trim(value) return tostring(value or ""):match("^%s*(.-)%s*$") end
function safe_lower(value) return string.lower(tostring(value or "")) end
function path_key(value) return safe_lower(value) end
function path_is_inside() return true end
function utf8_prefix(value, maximum)
  value = tostring(value or "")
  local offset = utf8.offset(value, maximum + 1)
  return offset and value:sub(1, offset - 1) or value
end
function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end
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
function commit_atomic_temporary(target_path, temporary_path, backup_path)
  os.remove(backup_path)
  local existing = io.open(target_path, "rb")
  if existing then
    existing:close()
    os.rename(target_path, backup_path)
  end
  local installed = os.rename(temporary_path, target_path)
  if installed then
    os.remove(backup_path)
    return true
  end
  os.rename(backup_path, target_path)
  return false
end
function set_status() end
function can_run_heavy_job() return true end

assert(load(read_all(json_source_path), "@" .. json_source_path, "t", _ENV))()
local jobs_source = read_all(jobs_source_path)
local jobs_boundary = assert(
  jobs_source:find("function extract_project_url_from_text", 1, true),
  "job coordinator boundary not found"
)
assert(load(jobs_source:sub(1, jobs_boundary - 1), "@" .. jobs_source_path, "t", _ENV))()
assert(load(read_all(ai_source_path), "@" .. ai_source_path, "t", _ENV))()

assert(ai_semantic_validate_endpoint("https://api.deepseek.com/chat/completions"))
assert(ai_semantic_validate_endpoint("http://127.0.0.1:11434/v1/chat/completions"))
assert(ai_semantic_validate_endpoint("http://localhost:1234/v1/chat/completions"))
assert(not ai_semantic_validate_endpoint("http://example.com/v1/chat/completions"))
assert(not ai_semantic_validate_endpoint("file:///tmp/secret"))

local url, model = ai_semantic_provider_defaults("deepseek")
assert(url == "https://api.deepseek.com/chat/completions")
assert(model == "deepseek-flash")
url, model = ai_semantic_provider_defaults("openai")
assert(url == "https://api.openai.com/v1/chat/completions")
assert(model == "gpt-4.1-mini")

local plan = assert(ai_semantic_validate_plan({
  positive_terms = { "metal", "chain", "金属", "metal" },
  negative_terms = { "music" },
  concepts = { "heavy", "industrial" },
  summary = "heavy metal chain",
}))
assert(#plan.positive_terms == 3)
assert(plan.summary == "heavy metal chain")

local relevant = {
  ready = true,
  path = [[C:\Library\Heavy_Metal_Chain_Drag.wav]],
  name = "Heavy_Metal_Chain_Drag.wav",
  description = "Slow industrial chain dragging on concrete",
  keywords = "metal heavy scrape",
  category = "METAL",
  subcategory = "CHAIN",
  catid = "MTLChain",
  duration = 6.2,
}
local irrelevant = {
  ready = true,
  path = [[C:\Library\Bird_Song.wav]],
  name = "Bird_Song.wav",
  description = "Small bird singing",
  keywords = "nature bird music",
  category = "ANIMALS",
  subcategory = "BIRDS",
  duration = 3,
}
assert(ai_semantic_asset_score(relevant, plan) > ai_semantic_asset_score(irrelevant, plan))

local session = { candidates = {} }
for index = 1, AISemantic.candidate_limit + 20 do
  ai_semantic_insert_candidate(session, {
    ready = true,
    path = string.format("C:/Library/%04d.wav", index),
    name = string.format("%04d.wav", index),
  }, index)
end
assert(#session.candidates == AISemantic.candidate_limit)
local minimum = math.huge
for _, entry in ipairs(session.candidates) do minimum = math.min(minimum, entry.score) end
assert(minimum == 21)

session.query = "金属撞击"
local chinese_name = string.rep("钟", 181)
session.candidates = {{
  asset = {
    path = "C:/Library/bell.wav",
    name = chinese_name,
    description = "金属钟声",
  },
  score = 1,
  sort_path = "c:/library/bell.wav",
}}
local candidate_payload = neural_json_decode(ai_semantic_candidate_payload(session))
assert(utf8.len(candidate_payload.candidates[1].name) == 180)
session.plan = { summary = "metal impact" }
session.job_token = {}
ai_semantic_finish(session, {}, false)
assert(state.ai_semantic_result_count == 0)
assert(next(state.ai_semantic_lookup) == nil)
assert(state.search == "金属撞击")

local decoded = assert(ai_semantic_extract_content(neural_json_encode({
  choices = {
    { message = { content = [[```json
{"positive_terms":["impact"],"negative_terms":[],"concepts":[],"summary":"impact"}
```]] } },
  },
})))
assert(decoded.positive_terms[1] == "impact")

local body = ai_semantic_chat_body("system", "user", 50)
local request = neural_json_decode(body)
assert(request.model == "deepseek-flash")
assert(request.messages[1].content == "system")
assert(request.messages[2].content == "user")
assert(request.response_format.type == "json_object")

state.ai_provider = "deepseek"
state.ai_model = "deepseek-chat"
state.config_dirty = false
assert(ai_semantic_migrate_legacy_settings())
assert(state.ai_model == "deepseek-flash")
assert(state.config_dirty)
state.ai_model = "deepseek-reasoner"
assert(ai_semantic_migrate_legacy_settings())
assert(state.ai_model == "deepseek-v4-pro")
state.ai_model = "deepseek-custom-model"
assert(not ai_semantic_migrate_legacy_settings())
assert(state.ai_model == "deepseek-custom-model")

local original_launch_bridge = ai_semantic_launch_bridge
local key_plaintext_path = os.tmpname()
local key_secret_path = os.tmpname()
os.remove(key_plaintext_path)
os.remove(key_secret_path)
state.ai_semantic_available = true
state.persistence_read_only = true
state.persistence_read_only_reason = "素材增量日志无法安全重放：field_mismatch"
state.ai_semantic_paths = {
  plaintext = key_plaintext_path,
  secret = key_secret_path,
}
ai_semantic_launch_bridge = function(request, synchronous)
  assert(synchronous)
  assert(request.operation == "protect-key")
  local encrypted = assert(io.open(request.secretPath, "wb"))
  encrypted:write("encrypted-test-value")
  encrypted:close()
  os.remove(request.plaintextPath)
  local status_path = os.tmpname()
  local status = assert(io.open(status_path, "wb"))
  status:write('{"state":"complete"}')
  status:close()
  return { request_path = "", status_path = status_path }
end
assert(ai_semantic_save_api_key("sk-test"))
assert(state.ai_api_key_saved)
assert(state.ai_api_key_input == "")
assert(state.ai_api_key_status == "API Key 已安全保存")
assert(not state.ai_api_key_status_error)
assert(state.persistence_read_only, "AI key save must not disable catalog read-only protection")
assert(not ai_semantic_save_api_key(""))
assert(state.ai_api_key_status == "保存失败：API Key 不能为空")
assert(state.ai_api_key_status_error)
ai_semantic_launch_bridge = original_launch_bridge
os.remove(key_plaintext_path)
os.remove(key_secret_path)

local original_start_api_job = ai_semantic_start_api_job
ai_semantic_start_api_job = function(kind)
  return {
    kind = kind,
    started = Host.time_precise(),
    request_path = "",
    status_path = "",
    body_path = "",
    response_path = "",
  }
end
state.assets = {
  { path = "C:/Library/one.wav", name = "one.wav", ready = true },
  { path = "C:/Library/two.wav", name = "two.wav", ready = true },
}
local catalog_job = assert(Jobs.begin("wave_precache", "catalog_exclusive", false, 20))
assert(start_ai_semantic_search("metal impact"), "catalog maintenance must not block AI search")
assert(state.ai_semantic_session.job_token.resource == "ai_semantic_api")
assert(#state.ai_semantic_session.source == 2)
state.assets[3] = { path = "C:/Library/three.wav", name = "three.wav", ready = true }
assert(#state.ai_semantic_session.source == 2, "AI search must keep a stable asset-array snapshot")
ai_semantic_cancel()
assert(not Jobs.active.ai_semantic_search, "AI cancellation must release its job token")
assert(Jobs.is_current(catalog_job), "AI cancellation must not disturb catalog maintenance")
Jobs.finish(catalog_job, true)
ai_semantic_start_api_job = original_start_api_job

local source = read_all(ai_source_path)
local payload_start = assert(source:find("function ai_semantic_candidate_payload", 1, true))
local payload_end = assert(source:find("function ai_semantic_finish", payload_start, true))
local payload_source = source:sub(payload_start, payload_end - 1)
assert(payload_source:find("name =", 1, true))
assert(not payload_source:find("path =", 1, true))
assert(source:find('"ai_semantic_api"', 1, true))
assert(source:find("source = source", 1, true))
assert(source:find("total = #source", 1, true))
assert(source:find("Audio is", 1, true))
assert(source:find("ProtectedData", 1, true))
assert(source:find("response_format", 1, true))

print("lua AI semantic search self-test passed")
