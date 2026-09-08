local module_path = assert(arg[1], "UI core module is required")
state = { language = "en" }
I18N_MISSING = {}
I18N_MISSING_UNIQUE = 0
I18N_MISSING_LIMIT = 256
I18N_EN = { ["设置"] = "Settings" }
I18N_PREFIX_EN = { ["文件不存在："] = "File not found: " }
I18N_PATTERNS_EN = { { "^素材 (%d+)$", "Asset %1" } }

assert(loadfile(module_path))()
assert(translate_ui_text("设置") == "Settings")
assert(translate_ui_text("文件不存在：fixture.wav") == "File not found: fixture.wav")
assert(translate_ui_text("素材 12") == "Asset 12")
assert(translate_ui_label("设置##settings") == "Settings##settings")
assert(translate_ui_text("尚未翻译") == "尚未翻译")
assert(missing_translation_count() == 1)
translate_ui_text("尚未翻译")
assert(missing_translation_count() == 1 and I18N_MISSING["尚未翻译"] == 2)

local visible_session = { silent = false, current = { progress = 0.5 } }
assert(visible_progress_session(visible_session) == visible_session)
assert(visible_progress_session({ silent = true }) == nil)
assert(visible_progress_session(nil) == nil)
assert(visible_progress_session(true) == nil)

state.language = "zh"
assert(translate_ui_text("设置") == "设置")

print("Lua i18n self-test OK")
