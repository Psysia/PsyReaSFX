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

local compiled_plan = ai_semantic_compile_plan(plan)
assert(#compiled_plan.positive_terms == #plan.positive_terms)
assert(ai_semantic_asset_score(relevant, plan, compiled_plan)
  == ai_semantic_asset_score(relevant, plan))
assert(ai_semantic_asset_score(irrelevant, plan, compiled_plan) == 0)

local cached_blob_asset = { _search_blob = "cached metal impact" }
assert(ai_semantic_asset_recall_blob(cached_blob_asset) == cached_blob_asset._search_blob)

local capacity_plan = assert(ai_semantic_validate_plan({
  positive_terms = {
    "metal impact", "metal", "impact", "hit", "clang", "clank",
    "collision", "industrial", "heavy", "hard", "strike", "slam",
    "金属撞击", "金属", "撞击", "碰撞", "重击", "敲击",
  },
  negative_terms = { "music", "voice", "鸟", "音乐" },
  concepts = {},
  summary = "metal impact",
}))
local capacity_compiled = ai_semantic_compile_plan(capacity_plan)
local capacity_started = os.clock()
local capacity_matches = 0
for index = 1, 100000 do
  local hit = index % 100 == 0
  local asset = {
    ready = true,
    path = string.format("C:/Library/%s_%06d.wav", hit and "metal_impact" or "ambient", index),
    name = hit and "Heavy Metal Impact.wav" or "Quiet Forest Ambience.wav",
    description = hit and "Industrial steel collision" or "Soft wind in distant trees",
    keywords = hit and "metal hit clang" or "nature forest air",
    category = hit and "METAL" or "AMBIENCE",
    subcategory = hit and "IMPACT" or "WIND",
  }
  if ai_semantic_asset_score(asset, capacity_plan, capacity_compiled) > 0 then
    capacity_matches = capacity_matches + 1
  end
end
local capacity_elapsed = os.clock() - capacity_started
assert(capacity_matches == 1000)
assert(capacity_elapsed < 5,
  string.format("100k AI local recall exceeded capacity budget: %.3fs", capacity_elapsed))
print(string.format("AI local recall capacity: 100000 assets in %.3fs", capacity_elapsed))

local pool_started = os.clock()
local pool_session = { candidates = {} }
for index = 1, 100000 do
  ai_semantic_insert_candidate(pool_session, {
    path = string.format("C:/Library/pool-%06d.wav", index),
  }, (index % 5000) + 1)
end
local pool_elapsed = os.clock() - pool_started
assert(#pool_session.candidates == AISemantic.candidate_pool_limit)
assert(pool_elapsed < 5,
  string.format("100k AI candidate-pool maintenance exceeded budget: %.3fs", pool_elapsed))
print(string.format("AI candidate-pool capacity: 100000 inserts in %.3fs", pool_elapsed))

local session = { candidates = {} }
for index = 1, AISemantic.candidate_pool_limit + 20 do
  ai_semantic_insert_candidate(session, {
    ready = true,
    path = string.format("C:/Library/%04d.wav", index),
    name = string.format("%04d.wav", index),
  }, index)
end
assert(#session.candidates == AISemantic.candidate_pool_limit)
local minimum = math.huge
for _, entry in ipairs(session.candidates) do minimum = math.min(minimum, entry.score) end
assert(minimum == 21)

ai_semantic_sort_candidates(session.candidates)
session.candidate_pool = session.candidates
assert(ai_semantic_prepare_page(session, 1) and #session.candidates == 120)
assert(session.candidates[1].score == AISemantic.candidate_pool_limit + 20)
assert(ai_semantic_prepare_page(session, 2) and #session.candidates == 120)
assert(session.candidates[1].score == AISemantic.candidate_pool_limit - 100)
assert(ai_semantic_prepare_page(session, 20) and #session.candidates == 120)
assert(not ai_semantic_prepare_page(session, 21))

session.query = "金属撞击"
session.candidate_pool = nil
session.page_index = 1
session.page_end = 1
local chinese_name = string.rep("钟", 121)
session.candidates = {{
  asset = {
    path = "C:/Library/bell.wav",
    name = chinese_name,
    description = "金属钟声",
  },
  score = 1,
  sort_path = "c:/library/bell.wav",
}}
session.plan = { summary = "metal impact" }
session.job_token = {}
ai_semantic_finish_local(session)
assert(state.ai_semantic_result_count == 1)
assert(state.ai_semantic_lookup["c:/library/bell.wav"].local_score == 1)
assert(state.search == "金属撞击")

local first_page_assets = {}
for index = 1, 130 do
  first_page_assets[index] = {
    asset = { path = string.format("C:/Library/page-%03d.wav", index) },
    score = 200 - index,
    sort_path = string.format("c:/library/page-%03d.wav", index),
  }
end
local page_session = {
  query = "metal impact",
  plan = { summary = "metal impact" },
  compiled_plan = compiled_plan,
  candidate_pool = first_page_assets,
  candidates = {},
  page_index = 1,
  job_token = {},
}
assert(ai_semantic_prepare_page(page_session, 1))
ai_semantic_finish_local(page_session)
assert(state.ai_semantic_result_count == 120)
assert(state.ai_semantic_has_more)
assert(state.ai_semantic_loaded_candidates == 120)
assert(state.ai_semantic_total_candidates == 130)
assert(start_ai_semantic_next_page())
assert(state.ai_semantic_result_count == 130)
assert(not state.ai_semantic_has_more)
assert(state.ai_semantic_lookup["c:/library/page-001.wav"].page == 1)
assert(state.ai_semantic_lookup["c:/library/page-121.wav"].page == 2)
assert(state.ai_semantic_session == nil)

local decoded = assert(ai_semantic_extract_content(neural_json_encode({
  choices = {
    { message = { content = [[```json
{"positive_terms":["impact"],"negative_terms":[],"concepts":[],"summary":"impact"}
```]] } },
  },
})))
assert(decoded.positive_terms[1] == "impact")

decoded = assert(ai_semantic_extract_content(neural_json_encode({
  choices = {
    { message = { content = [[Here is the requested result:
```json
{"positive_terms":["door"],"negative_terms":[],"concepts":["wood"],"summary":"wood door"}
```]] } },
  },
})))
assert(decoded.positive_terms[1] == "door")

decoded = assert(ai_semantic_extract_content(neural_json_encode({
  choices = {
    { message = { content = {
      { type = "text", text = [[{"matches":[{"id":1,"score":91,"reason":"metal {impact}"}]}]] },
    } } },
  },
})))
assert(decoded.matches[1].score == 91)

local empty_content, empty_reason = ai_semantic_extract_content(neural_json_encode({
  choices = { { message = { content = "" } } },
}))
assert(empty_content == nil and ai_semantic_retryable_response_error(empty_reason))
local invalid_content, invalid_reason = ai_semantic_extract_content(neural_json_encode({
  choices = { { message = { content = "not json" } } },
}))
assert(invalid_content == nil and ai_semantic_retryable_response_error(invalid_reason))

local original_start_api_job_for_retry = ai_semantic_start_api_job
local retry_calls = 0
ai_semantic_start_api_job = function(kind, system_prompt, user_prompt, maximum_tokens)
  retry_calls = retry_calls + 1
  assert(kind == "plan-retry")
  assert(system_prompt:find("one complete JSON object", 1, true))
  assert(user_prompt == "wood door")
  assert(maximum_tokens == 600)
  return { kind = kind }
end
local retry_session = { query = "wood door" }
assert(ai_semantic_retry_api(retry_session, "plan", invalid_reason))
assert(retry_calls == 1 and retry_session.plan_retry_count == 1)
assert(not ai_semantic_retry_api(retry_session, "plan", invalid_reason))
assert(retry_calls == 1, "invalid JSON must be retried at most once")
ai_semantic_start_api_job = original_start_api_job_for_retry

local body = ai_semantic_chat_body("system", "user", 50)
local request = neural_json_decode(body)
assert(request.model == "deepseek-flash")
assert(request.messages[1].content == "system")
assert(request.messages[2].content == "user")
assert(request.response_format.type == "json_object")
assert(request.thinking.type == "disabled")

state.ai_provider = "custom"
request = neural_json_decode(ai_semantic_chat_body("system", "user", 50))
assert(request.response_format == nil)
assert(request.thinking == nil)
state.ai_provider = "deepseek"

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
assert(not source:find("ai_semantic_rerank_system_prompt", 1, true))
assert(not source:find('"rerank_wait"', 1, true))
assert(source:find("ai_semantic_finish_local", 1, true))
assert(source:find('"ai_semantic_api"', 1, true))
assert(source:find("source = source", 1, true))
assert(source:find("total = #source", 1, true))
assert(source:find("metadata and audio", 1, true))
assert(source:find("ProtectedData", 1, true))
assert(source:find("response_format", 1, true))

print("lua AI semantic search self-test passed")
