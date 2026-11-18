local module = arg[1] or "src/lua/26_shared_readonly.lua"
dofile(module)
local core = assert(io.open("src/lua/10_ui_core.lua", "rb"))
local path_helper = assert(core:read("*a"):match("(function windows_extended_path%(path%).-)function open_source_binary_file"))
core:close()
assert(load(path_helper))()
local original_open = io.open
io.open = function() error("source adapter attempted CRT fallback") end
reaper = {}
local missing, reason = SoundminerReadOnly.open("C:/synthetic/source.bin")
assert(not missing and reason:find("ReaWebAPI"), "missing capability refuses source access")
local bytes, stamp, identity, calls, directory = string.rep("\0\255abcd", 30000), "1", "1:22:3", {}, false
local expected_path = "C:/synthetic/source.bin"
reaper.ReaWeb_ReadSharedRange = function(path, offset, count)
  assert(path == expected_path, path)
  assert(type(offset) == "string" and offset:match("^%d+$"))
  assert(count >= 0 and count <= 65536)
  calls[#calls + 1] = { tonumber(offset), count }
  if not bytes then return '{"protocol":1,"ok":false,"code":"NOT_FOUND","osError":2}' end
  local part = bytes:sub(tonumber(offset) + 1, tonumber(offset) + count)
  local hex = part:gsub(".", function(byte) return string.format("%02x", byte:byte()) end)
  return string.format('{"protocol":1,"ok":true,"dataHex":"%s","size":"%d","mtime":"%s","fileId":"%s","directory":%s}', hex, #bytes, stamp, identity, tostring(directory))
end
assert(not SoundminerReadOnly.open("relative.bin"))
reaper.GetOS = function() return "Win64" end
local suffix = string.rep("素材目录/", 40) .. "声音.wav"
for _, pair in ipairs({{"D:/", "\\\\?\\D:\\"}, {"//server/share/", "\\\\?\\UNC\\server\\share\\"}}) do
  local path = pair[1] .. suffix
  expected_path = pair[2] .. suffix:gsub("/", "\\")
  local reader = assert(SoundminerReadOnly.open(path))
  assert(reader.path == path and reader:read(15) == bytes:sub(1,15) and reader:unchanged())
  reader:close()
end
expected_path = "C:/synthetic/source.bin"
local source = assert(SoundminerReadOnly.open("C:/synthetic/source.bin"))
assert(source.size == #bytes and source.identity == identity and source:unchanged())
assert(source:read(131073) == bytes:sub(1, 131073))
assert(source:seek("set", 5) == 5 and source:read(9) == bytes:sub(6, 14))
assert(source:seek("end", -3) == #bytes - 3 and source:read(99) == bytes:sub(-3))
assert(source:read(1) == nil and source:read(0) == "")
assert(not source:read("*a") and not source:read(16777217))
assert(not source:seek("set", -1) and not source:seek("bad", 1))
source:seek("set", 0); stamp = "2"
assert(not source:read(1) and not source:unchanged(), "metadata change invalidates read")
source = assert(SoundminerReadOnly.open("C:/synthetic/source.bin")); identity = "1:22:4"
assert(not source:unchanged(), "same-size replacement invalidates identity")
directory = true
assert(SoundminerReadOnly.stat("C:/synthetic/source.bin").directory)
assert(not SoundminerReadOnly.open("C:/synthetic/source.bin"), "directory stat cannot become a file reader")
directory = false
source = assert(SoundminerReadOnly.open("C:/synthetic/source.bin")); bytes = nil
assert(not source:read(1), "external deletion affects only this reader")
source:close(); assert(not source:seek("set", 0))
assert(#calls >= 10)
io.open = original_open
print("Shared read-only adapter: PASS (no CRT fallback, bounded binary reads, identity/mtime/delete/closed/capability)")
