local module_path = assert(arg[1], "host adapter module is required")

local calls = {}
reaper = {
  time_precise = function()
    calls[#calls + 1] = "time"
    return 12.5
  end,
  file_exists = function(path)
    calls[#calls + 1] = "exists:" .. path
    return path == "fixture.wav"
  end,
  version = "stub",
}

assert(loadfile(module_path))()
assert(Host.raw == reaper)
assert(Host.time_precise() == 12.5)
assert(Host.file_exists("fixture.wav"))
assert(not Host.file_exists("missing.wav"))
assert(Host.version == "stub")
assert(host_api_available(Host, "time_precise"))
assert(not host_api_available(Host, "missing"))

local alternate = new_reaper_host_adapter({
  time_precise = function() return 99 end,
})
assert(alternate.time_precise() == 99)
assert(#calls == 3)

print("Lua host adapter self-test OK")
