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
  update = function(key, updater) state[key] = updater(state[key]) end,
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
assert(#state.ai_presets == 1 and state.ai_active_preset_id == "legacy")
assert(state.ai_api_url == deepseek_config.url and state.ai_model == deepseek_config.model)
assert(ai_semantic_preset_by_id("legacy").provider == "deepseek")
assert(ai_semantic_preset_dirty())
assert(ai_semantic_select_provider_preset("deepseek"))
assert(not ai_semantic_preset_dirty())
assert(ai_semantic_new_preset("custom"))
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
assert(ai_semantic_select_preset("legacy"))
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
assert(ai_semantic_select_preset("legacy"))
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
assert(ai_semantic_select_preset("legacy"))
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
assert(ai_semantic_select_preset("legacy"))
assert(state.ai_model == "deepseek-flash" and state.ai_semantic_paths.secret == deepseek_config.secret)

-- Exercise the real TSV configuration reader/writer with an in-memory file.
local catalog_file = assert(io.open("src/lua/30_catalog.lua", "rb"))
local catalog = catalog_file:read("*a")
catalog_file:close()
local first = assert(catalog:find("function load_config()", 1, true))
assert(loadfile("src/lua/11_ui_workspace.lua"))()
state.sidebar_modules = {}
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
state.ui_font_size = 18
state.sidebar_navigation_mode, state.sidebar_folder_mode = "both", "roots"
state.sidebar_modules.workflow = false
assert(ai_semantic_save_preset())
setmetatable(state, nil)
local saved_tsv = table.concat(saved_lines)
assert(saved_tsv:find("setting\tai_presets_json\t", 1, true))
assert(not saved_tsv:find("sk-custom-test", 1, true))
assert(not saved_tsv:find("sk-unsaved-draft", 1, true))
local ai_lines = {}
for line in saved_tsv:gmatch("[^\n]+") do
  if line:find("setting\tai_", 1, true) == 1 or line:find("setting\tui_font_size\t",1,true) == 1
    or line:find("setting\tsidebar_show_",1,true) == 1
    or line:find("setting\tsidebar_navigation_mode\t",1,true) == 1
    or line:find("setting\tsidebar_folder_mode\t",1,true) == 1 then ai_lines[#ai_lines + 1] = line end
end
io.open = function(path, mode)
  if path ~= CONFIG_FILE then return original_open(path, mode) end
  local index = 0
  return { lines = function() return function() index = index + 1 return ai_lines[index] end end,
    close = function() end }
end
state.ai_presets_json = nil
state.ui_font_size = 13
state.sidebar_navigation_mode, state.sidebar_folder_mode = "libraries", "tree"
state.sidebar_modules = {}
assert(load(catalog:sub(first, last - 1), "config-reader", "t", _ENV))()
load_config()
assert(state.ui_font_size == 18 and state.sidebar_navigation_mode == "both" and state.sidebar_folder_mode == "roots")
assert(state.sidebar_modules.workflow == false)
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

-- Explicit deletion affects only the selected group. Save failure and active
-- requests must leave both its metadata and credential untouched.
assert(ai_semantic_select_preset(custom_id))
local remove_for_delete = os.remove
os.remove = function(path) virtual_files[path] = nil return true end
state.ai_semantic_session = { phase = "test_wait" }
assert(not ai_semantic_delete_preset(custom_id))
state.ai_semantic_session = nil
save_config = function() return false end
assert(not ai_semantic_delete_preset(custom_id))
assert(state.ai_active_preset_id == custom_id and ai_semantic_preset_by_id(custom_id))
assert(virtual_files[custom_secret] == "encrypted:sk-custom-test")
save_config = real_save
assert(ai_semantic_delete_preset(custom_id))
assert(not ai_semantic_preset_by_id(custom_id) and not virtual_files[custom_secret])
assert(virtual_files[deepseek_config.secret] == "encrypted-deepseek-original")
state.ai_presets_json = persisted
assert(ai_semantic_initialize_presets())
assert(not ai_semantic_preset_by_id(custom_id))
assert(ai_semantic_delete_preset("p3"))
assert(ai_semantic_delete_preset("legacy"))
assert(#state.ai_presets == 0 and state.ai_active_preset_id == "")
assert(not state.ai_api_key_saved and state.ai_semantic_paths.secret == nil)
state.ai_presets_json = persisted
assert(ai_semantic_initialize_presets())
assert(#state.ai_presets == 0 and not ai_semantic_select_provider_preset("deepseek"))
assert(ai_semantic_new_preset("custom") and state.ai_active_preset_id == "p4")
os.remove = remove_for_delete

-- Reset removes only known credential paths, no config-stored path is trusted.
state.ai_presets_json = before
assert(ai_semantic_initialize_presets())
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
  GetContentRegionAvail = function() return 640 end,
  InputText = function(_, _, value) return false, value end,
  InputTextWithHint = function(_, _, _, value) return false, value end,
}, { __index = function() return function() return false end end })
function settings_section_title() end
function translate_ui_text(value) return value end
function ai_semantic_provider_label(value) return value end
local clicked_button = "加密保存 Key"
local button_layout = {}
function dark_button(label, width)
  button_layout[#button_layout + 1] = { label = label, width = width }
  return label == clicked_button
end
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
assert(button_layout[1].label == "新建预设" and button_layout[2].label == "切换预设"
  and button_layout[3].label == "保存预设" and button_layout[4].label == "删除预设")
assert(button_layout[1].width * 4 + 24 == 640)
state.ai_model = "saved-by-footer"
assert(ai_semantic_preset_dirty())
assert(ai_semantic_save_settings())
assert(not ai_semantic_preset_dirty())
assert(neural_json_decode(persisted).presets[1].model == "saved-by-footer")
state.ai_model = ""
assert(not ai_semantic_save_settings() and ai_semantic_preset_dirty())
state.ai_model = "saved-by-top-row"
clicked_button = "保存预设"
draw_settings_ai()
assert(not status_error and not ai_semantic_preset_dirty())
assert(neural_json_decode(persisted).presets[1].model == "saved-by-top-row")
assert(ai_semantic_new_preset("custom"))
assert(ai_semantic_select_provider_preset("openai"))
assert(state.ai_provider == "openai" and state.ai_api_url == "")
state.ai_api_url, state.ai_model = "https://ui.example/v1/chat/completions", "ui-model"
assert(ai_semantic_save_settings())
assert(ai_semantic_preset_by_id(state.ai_active_preset_id).provider == "openai")
assert(not ai_semantic_preset_dirty())

-- Model the settings modal's child/window stack: an ordinary confirmation
-- popup inside the child is not an interactive modal. Render the real helper
-- after EndChild and require a nested modal with a stable captured group ID.
local popup_open, popup_inside, parent_child = false, false, true
local captured_messages = {}
ImGui.OpenPopup = function(_, label)
  assert(not parent_child, "confirmation must open outside settings_content")
  assert(label == "删除预设##ai_preset_delete")
  popup_open = true
end
ImGui.BeginPopupModal = function(_, label)
  assert(not parent_child and label == "删除预设##ai_preset_delete")
  popup_inside = popup_open
  return popup_inside
end
ImGui.CloseCurrentPopup = function()
  assert(popup_inside, "close the confirmation, not its settings parent")
  popup_open = false
end
ImGui.EndPopup = function() assert(popup_inside) popup_inside = false end
ImGui.TextColored = function(_, _, message) captured_messages[#captured_messages + 1] = message end
local preset_before_delete = state.ai_active_preset_id
clicked_button = "删除预设"
draw_settings_ai()
assert(state.ai_preset_delete_requested and state.ai_preset_delete_id == preset_before_delete)
assert(not popup_open)
parent_child = false
clicked_button = ""
draw_ai_preset_delete_popup()
assert(popup_open and not state.ai_preset_delete_requested)
clicked_button = "取消"
draw_ai_preset_delete_popup()
assert(not popup_open and state.ai_preset_delete_id == "")
assert(ai_semantic_preset_by_id(preset_before_delete))

-- Failure is visible in the confirmation; it can be retried and then closes.
state.ai_preset_delete_id, state.ai_preset_delete_requested = preset_before_delete, true
clicked_button = ""
draw_ai_preset_delete_popup()
save_config = function() return false end
clicked_button = "确认删除"
draw_ai_preset_delete_popup()
assert(popup_open and ai_semantic_preset_by_id(preset_before_delete))
assert(captured_messages[#captured_messages] == "预设删除失败，请检查配置写入权限")
save_config = real_save
assert(ai_semantic_select_preset("legacy")) -- captured deletion identity stays fixed
draw_ai_preset_delete_popup()
assert(not popup_open and state.ai_preset_delete_id == "")
assert(not ai_semantic_preset_by_id(preset_before_delete))
assert(ai_semantic_preset_by_id("legacy"))
local persisted_after_delete = neural_json_decode(persisted)
for _, preset in ipairs(persisted_after_delete.presets) do assert(preset.id ~= preset_before_delete) end
clicked_button = ""
draw_ai_preset_delete_popup()
assert(not popup_open) -- no reopen on the following frame

-- The final group's removal also closes instead of leaving a stale dialog.
state.ai_preset_delete_id, state.ai_preset_delete_requested = "legacy", true
clicked_button = "确认删除"
local popup_remove = os.remove
os.remove = function(path) virtual_files[path] = nil return true end
draw_ai_preset_delete_popup()
os.remove = popup_remove
assert(not popup_open and #state.ai_presets == 0)
print("Lua AI presets self-test passed (migration, independent keys, drafts, reload, endpoint safety, request isolation)")
