local json_path = arg[1] or "src/lua/43_neural_similarity.lua"
local ai_path = arg[2] or "src/lua/44_ai_semantic_search.lua"
local virtual_files, persisted, requests = {}, nil, {}
state = {
  ai_provider = "deepseek", ai_api_url = "https://api.deepseek.com/chat/completions",
  ai_model = "deepseek-flash", ai_api_key_saved = true,
  ai_semantic_available = true, ai_active_preset_id = "", ai_request_sequence = 0,
  ai_semantic_paths = { root = "test-ai", secret = "test-ai/api-key.dpapi", plaintext = "test-ai/plaintext.tmp", jobs = "test-ai/jobs" },
}
SEP = "/"
Host = { file_exists = function(path) return virtual_files[path] ~= nil end,
  time_precise = function() return 10 end }
AppState = { set = function(key, value) state[key] = value end,
  apply = function(values) for key, value in pairs(values) do state[key] = value end end }
function trim(value) return tostring(value or ""):match("^%s*(.-)%s*$") end
function safe_lower(value) return string.lower(tostring(value or "")) end
function save_config()
  persisted = ai_semantic_presets_config_json()
  state.config_dirty = false
  return true
end
assert(loadfile(json_path))()
assert(loadfile(ai_path))()
virtual_files["test-ai/api-key.dpapi"] = "encrypted-deepseek-original"
ai_semantic_write_atomic = function(path, content) virtual_files[path] = content return true end
ai_semantic_read_file = function(path) return virtual_files[path] end
ai_semantic_launch_bridge = function(request)
  requests[#requests + 1] = request
  if request.operation == "protect-key" then
    virtual_files[request.secretPath] = "encrypted:" .. virtual_files[request.plaintextPath]
  end
  return { status_path = "mock-status", kind = request.operation }
end
ai_semantic_read_status = function() return { state = "complete" } end
ai_semantic_cleanup_job = function() end

assert(ai_semantic_initialize_presets())
assert(state.ai_active_preset_id == "legacy")
assert(state.ai_preset_name == "DeepSeek" and state.ai_api_key_saved)
assert(ai_semantic_preset_secret_path("../../secret") == nil)
assert(ai_semantic_preset_secret_path("p1/evil") == nil)
assert(not ai_semantic_preset_dirty())
assert(ai_semantic_save_preset())
assert(not persisted:find("encrypted", 1, true))

local deepseek_config = ai_semantic_current_api_config()
assert(ai_semantic_select_provider_preset("custom"))
local custom_id, custom_secret = state.ai_active_preset_id, state.ai_semantic_paths.secret
assert(custom_id == "p1" and not state.ai_api_key_saved)
assert(custom_secret ~= deepseek_config.secret)
state.ai_preset_name = "My compatible endpoint"
state.ai_api_url = "https://compatible.example/v1/chat/completions"
state.ai_model = "compatible-model"
state.ai_api_key_input = "sk-custom-test"
local started, reason = ai_semantic_start_api_job("test", "JSON", "test", 20)
assert(not started and reason == "请先保存输入的新密钥，再测试或搜索")
assert(ai_semantic_save_preset())
assert(virtual_files[deepseek_config.secret] == "encrypted-deepseek-original")
assert(virtual_files[custom_secret] == "encrypted:sk-custom-test")
assert(state.ai_api_key_input == "" and ai_semantic_preset_key_usable())
assert(not persisted:find("sk-custom-test", 1, true))
assert(not persisted:find("key_input", 1, true))

local custom_config = ai_semantic_current_api_config()
assert(ai_semantic_start_api_job("test", "JSON", "test", 20))
assert(requests[#requests].secretPath == custom_secret)
assert(ai_semantic_select_provider_preset("deepseek"))
assert(state.ai_active_preset_id == "legacy")
assert(state.ai_api_url == deepseek_config.url and state.ai_model == "deepseek-flash")
assert(ai_semantic_preset_key_usable())
assert(ai_semantic_start_api_job("test", "JSON", "test", 20))
assert(requests[#requests].secretPath == deepseek_config.secret)

-- Drafts survive switching, but never enter the persisted whitelist.
assert(ai_semantic_select_preset(custom_id))
state.ai_model = "draft-model"
state.ai_preset_name = "Draft name"
state.ai_api_key_input = "sk-unsaved-draft"
assert(ai_semantic_preset_dirty())
assert(ai_semantic_select_provider_preset("deepseek"))
assert(not ai_semantic_presets_config_json():find("sk-unsaved-draft", 1, true))
assert(ai_semantic_select_preset(custom_id))
assert(state.ai_model == "draft-model" and state.ai_preset_name == "Draft name")
assert(state.ai_api_key_input == "sk-unsaved-draft")
state.ai_api_key_input = ""

-- Existing credentials are never forwarded to a changed endpoint.
state.ai_api_url = "https://different.example/v1/chat/completions"
assert(not ai_semantic_preset_key_usable())
started, reason = ai_semantic_start_api_job("test", "JSON", "test", 20)
assert(not started and reason == "地址已更改，请新建预设保存其他接口的密钥")
assert(not ai_semantic_save_api_key("sk-replacement"))
assert(virtual_files[custom_secret] == "encrypted:sk-custom-test")
state.ai_api_url = custom_config.url

-- A failed durable save retains the old preset and editable draft.
local real_save = save_config
save_config = function() return false end
assert(not ai_semantic_save_preset())
assert(ai_semantic_preset_by_id(custom_id).model == "compatible-model")
assert(state.ai_model == "draft-model")
save_config = real_save

-- A request and its format retry retain the original preset after switching.
state.ai_semantic_session = { phase = "test_wait", api_config = custom_config }
assert(ai_semantic_select_provider_preset("deepseek"))
assert(not ai_semantic_save_api_key("sk-active-test"))
assert(not ai_semantic_delete_api_key())
assert(not ai_semantic_save_preset())
ai_semantic_record_test(state.ai_semantic_session, true, "连接成功")
assert(state.ai_preset_tests[custom_id].ok)
assert(state.ai_preset_tests.legacy == nil)
assert(ai_semantic_start_api_job("retry", "JSON", "test", 600, custom_config))
assert(requests[#requests].url == custom_config.url)
assert(requests[#requests].secretPath == custom_secret)
state.ai_semantic_session = nil

-- Reload restores saved values, not another preset's flattened draft fields.
state.ai_presets_json = persisted
state.ai_provider, state.ai_api_url, state.ai_model = "deepseek", "wrong", "wrong"
assert(ai_semantic_initialize_presets())
assert(state.ai_active_preset_id == custom_id)
assert(state.ai_model == "compatible-model" and state.ai_preset_name == "My compatible endpoint")
assert(state.ai_api_key_saved and state.ai_api_key_input == "")
assert(ai_semantic_select_provider_preset("deepseek"))
assert(state.ai_model == "deepseek-flash" and state.ai_semantic_paths.secret == deepseek_config.secret)

-- Exercise the real TSV configuration reader/writer with an in-memory file.
local catalog_file = assert(io.open("src/lua/30_catalog.lua", "rb"))
local catalog = catalog_file:read("*a")
catalog_file:close()
local first = assert(catalog:find("function load_config()", 1, true))
local last = assert(catalog:find("function save_config()", first + 1, true))
local save_last = catalog:find("\nfunction ", last + 1, true) or (#catalog + 1)
local original_open, original_save = io.open, save_config
local saved_lines = {}
local function escape_tsv_value(value)
  return tostring(value or ""):gsub("\\", "\\\\"):gsub("\t", "\\t"):gsub("\n", "\\n"):gsub("\r", "\\r")
end
escape_tsv = escape_tsv_value
function split_tsv(line)
  local fields = {}
  for value in (line .. "\t"):gmatch("(.-)\t") do
    fields[#fields + 1] = value:gsub("\\(.)", { ["\\"] = "\\", t = "\t", n = "\n", r = "\r" })
  end
  return fields
end
CONFIG_FILE, VERSION = "virtual-config", "test"
function ensure_dirs() end
function set_status() end
function write_persistence_schema() end
function atomic_file_writer()
  return { write = function(_, ...) for index = 1, select("#", ...) do
    saved_lines[#saved_lines + 1] = tostring(select(index, ...)) end return true end,
    close = function() return true end }
end
assert(load(catalog:sub(last, save_last - 1), "config-writer", "t", _ENV))()
-- A proxy supplies neutral values for the unrelated legacy config fields.
local table_fields = { favorites = true, recent = true, expanded_folder_nodes = true,
  expanded_source_folders = true, sidebar_sections = true, column_visible = true, column_widths = true }
setmetatable(state, { __index = function(_, key)
  if table_fields[key] then return {} end
  if key == "ai_semantic_session" or key == "root_removal_session" then return nil end
  return ""
end })
state.ai_preset_name = "Saved name"
assert(ai_semantic_save_preset())
setmetatable(state, nil)
local saved_tsv = table.concat(saved_lines)
assert(saved_tsv:find("setting\tai_presets_json\t", 1, true))
assert(not saved_tsv:find("sk-custom-test", 1, true))
assert(not saved_tsv:find("sk-unsaved-draft", 1, true))
local ai_lines = {}
for line in saved_tsv:gmatch("[^\n]+") do
  if line:find("setting\tai_", 1, true) == 1 then ai_lines[#ai_lines + 1] = line end
end
io.open = function(path, mode)
  if path ~= CONFIG_FILE then return original_open(path, mode) end
  local index = 0
  return { lines = function() return function() index = index + 1 return ai_lines[index] end end,
    close = function() end }
end
state.ai_presets_json = nil
assert(load(catalog:sub(first, last - 1), "config-reader", "t", _ENV))()
load_config()
io.open, save_config = original_open, original_save
assert(ai_semantic_initialize_presets())
assert(state.ai_preset_name == "Saved name" and state.ai_active_preset_id == "legacy")
assert(ai_semantic_select_preset(custom_id) and state.ai_model == "compatible-model")

-- Multiple presets of one provider do not share credentials; orphan IDs skipped.
virtual_files["test-ai/api-key-p2.dpapi"] = "orphan-key"
assert(ai_semantic_new_preset("custom"))
assert(state.ai_active_preset_id == "p3" and not state.ai_api_key_saved)
assert(#state.ai_presets == 3)
local before = ai_semantic_presets_config_json()
state.ai_presets_json = '{"version":999,"presets":[]}'
assert(not ai_semantic_initialize_presets())
assert(ai_semantic_presets_config_json() == state.ai_presets_json)
assert(not ai_semantic_start_api_job("test", "JSON", "test", 20))
state.ai_presets_json = before
assert(ai_semantic_initialize_presets())

-- Reset removes only known credential paths, no config-stored path is trusted.
local original_remove = os.remove
local removed = {}
os.remove = function(path) removed[path] = true return true end
ai_semantic_reset_presets()
os.remove = original_remove
assert(removed[deepseek_config.secret] and removed[custom_secret])
assert(not state.ai_presets_loaded and state.ai_presets_json == nil)

-- Execute the settings renderer with a mock ImGui host. The legacy Key button
-- must save the entire preset, but must not claim a blank Key was saved.
state.ai_provider, state.ai_api_url, state.ai_model = "deepseek", deepseek_config.url, "deepseek-flash"
assert(ai_semantic_initialize_presets())
local ui_file = assert(io.open("src/lua/50_runtime_ui.lua", "rb"))
local ui = ui_file:read("*a")
ui_file:close()
local ui_start = assert(ui:find("function draw_settings_ai()", 1, true))
local ui_end = assert(ui:find("function color_edit_flags()", ui_start, true))
ctx, COLOR = {}, { error = 1, success = 2, warning = 3 }
ImGui = setmetatable({
  InputTextFlags_Password = 1,
  InputTextFlags_AutoSelectAll = 2,
  InputText = function(_, _, value) return false, value end,
  InputTextWithHint = function(_, _, _, value) return false, value end,
}, { __index = function() return function() return false end end })
function settings_section_title() end
function translate_ui_text(value) return value end
function ai_semantic_provider_label(value) return value end
function dark_button(label) return label == "加密保存 Key" end
local status_message, status_error
function set_status(message, is_error) status_message, status_error = message, is_error end
assert(load(ui:sub(ui_start, ui_end - 1), "ai-settings-renderer", "t", _ENV))()
draw_settings_ai()
assert(status_error and status_message:find("API Key 不能为空", 1, true))
state.ai_preset_name, state.ai_api_key_input = "Key button saved group", "sk-ui-test"
draw_settings_ai()
assert(not status_error and state.ai_api_key_input == "")
assert(neural_json_decode(persisted).presets[1].name == "Key button saved group")
assert(not persisted:find("sk-ui-test", 1, true))
print("Lua AI presets self-test passed (migration, independent keys, drafts, reload, endpoint safety, request isolation)")
