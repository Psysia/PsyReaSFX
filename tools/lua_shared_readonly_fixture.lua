-- Test-only ReaScript ABI stub for synthetic files. Production source readers
-- never use this implementation; real Win32 sharing is tested by native CI.
local fixture_open = io.open
return function(path, offset, count)
  local file, _, code = fixture_open(path, "rb")
  if not file then return '{"protocol":1,"ok":false,"code":"NOT_FOUND","osError":' .. tostring(code or 2) .. '}' end
  local size = file:seek("end")
  if not size then file:close(); return '{"protocol":1,"ok":false,"code":"STAT_FAILED","osError":5}' end
  file:seek("set", tonumber(offset))
  local bytes = count > 0 and (file:read(count) or "") or ""
  file:close()
  local hex = bytes:gsub(".", function(byte) return string.format("%02x", byte:byte()) end)
  local identity = 1
  for index = 1, #path do identity = ((identity * 31) + path:byte(index)) & 0x7fffffff end
  return string.format('{"protocol":1,"ok":true,"dataHex":"%s","size":"%d","mtime":"0","fileId":"%d","directory":false}', hex, size, identity)
end
