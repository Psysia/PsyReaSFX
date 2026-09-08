local module_path = assert(arg[1], "UI core module is required")
local directory_path = assert(arg[2], "directory fixture is required")
local file_path = assert(arg[3], "file fixture is required")
local missing_path = assert(arg[4], "missing fixture path is required")

SEP = package.config:sub(1, 1)
state = { language = "en" }
I18N_MISSING = {}
I18N_MISSING_UNIQUE = 0
I18N_MISSING_LIMIT = 256
I18N_EN = {}
I18N_PREFIX_EN = {}
I18N_PATTERNS_EN = {}

reaper = {
  GetOS = function()
    return "Win64"
  end,
  -- Deliberately return true for every path. directory_exists() must use an
  -- unambiguous directory probe instead of trusting this as a type test.
  file_exists = function()
    return true
  end,
  EnumerateFiles = function()
    return nil
  end,
  EnumerateSubdirectories = function()
    return nil
  end,
}

assert(loadfile(module_path))()

assert(directory_exists(directory_path))
assert(directory_exists(directory_path .. SEP))
assert(not directory_exists(file_path))
assert(not directory_exists(missing_path))

local canonical = canonical_source_path(directory_path)
assert(normalize_external_path('  "' .. directory_path .. '"  ') == canonical)
assert(normalize_external_path(directory_path .. "\0\0") == canonical)
assert(normalize_external_path("C:\\声音库") == "C:\\声音库")

local real_rename = os.rename
os.rename = function()
  return nil, "fixture probe failure", 2
end
reaper.EnumerateFiles = function(path, index)
  if canonical_source_path(path) == canonical and index == 0 then
    return "fixture.wav"
  end
  return nil
end
assert(directory_exists(directory_path))
assert(not directory_exists(missing_path))
reaper.EnumerateFiles = function()
  error("fixture enumeration failure")
end
reaper.EnumerateSubdirectories = function()
  error("fixture enumeration failure")
end
assert(not directory_exists(missing_path))
os.rename = real_rename

print("Lua directory self-test OK")
