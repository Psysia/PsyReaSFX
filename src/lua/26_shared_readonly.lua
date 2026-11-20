-- Shared, bounded source reads. Never fall back to CRT io.open: its Windows
-- sharing flags can deny another application's rename/delete operations.
SoundminerReadOnly = {}
local sm_read_methods = {}
local sm_read_cap = 16 * 1024 * 1024
local sm_hex_bytes = {}
for byte = 0, 255 do
  local pair = string.format("%02x", byte)
  sm_hex_bytes[pair], sm_hex_bytes[pair:upper()] = string.char(byte), string.char(byte)
  local high, low = pair:sub(1,1), pair:sub(2)
  sm_hex_bytes[high:upper() .. low], sm_hex_bytes[high .. low:upper()] = string.char(byte), string.char(byte)
end

local function sm_read_request(path, offset, count)
  local api = type(reaper) == "table" and reaper.ReaWeb_ReadSharedRange
  if type(api) ~= "function" then
    return nil, "当前 ReaWebAPI 缺少共享只读接口；请更新兼容运行库后导入，已有素材库仍可浏览", 38
  end
  local called, response = pcall(api, path, string.format("%.0f", offset), count)
  if not called then return nil, "Shared source read failed: " .. tostring(response), 5 end
  if type(response) ~= "string" or #response > 132000 then return nil, "Invalid shared read response", 5 end
  -- This intentionally accepts only the flat, ASCII, versioned native wire
  -- format. Binary payloads never cross ReaScript's NUL-terminated ABI directly.
  local hex, size, mtime, identity, directory = response:match(
    '^%{"protocol":1,"ok":true,"dataHex":"(%x*)","size":"(%d+)","mtime":"([%d:%-]+)","fileId":"([%d:]+)","directory":(%a+)%}$')
  if not hex then
    local code, os_error = response:match('^%{"protocol":1,"ok":false,"code":"([A-Z_]+)","osError":(%d+)%}$')
    local errno = code == "NOT_FOUND" and 2 or tonumber(os_error) or 5
    return nil, "Shared source read: " .. tostring(code or "INVALID_RESPONSE"), errno
  end
  size = tonumber(size)
  if not size or size > 9007199254740991 or #hex % 2 ~= 0 or #hex > count * 2
    or (directory ~= "true" and directory ~= "false") then
    return nil, "Invalid shared read bounds", 5
  end
  local bytes = hex:gsub("..", sm_hex_bytes)
  return { bytes = bytes, size = size, mtime = mtime, identity = identity, directory = directory == "true" }
end

local function sm_read_path(path)
  return type(path) == "string" and #path > 0 and #path <= 32768 and not path:find("[%z\1-\31]")
    and (path:match("^%a:[/\\]") or path:sub(1, 1) == "/" or path:sub(1, 2) == "\\\\")
end

local function sm_read_same(first, second)
  return first.size == second.size and first.mtime == second.mtime and first.identity == second.identity
    and first.directory == second.directory
end

function SoundminerReadOnly.available()
  return type(reaper) == "table" and type(reaper.ReaWeb_ReadSharedRange) == "function"
end

function SoundminerReadOnly.stat(path)
  if not sm_read_path(path) then return nil, "Invalid absolute source path", 22 end
  local native_path = windows_extended_path and windows_extended_path(path) or path
  local info, reason, code = sm_read_request(native_path, 0, 0)
  if info then info.native_path = native_path end
  return info, reason, code
end

function SoundminerReadOnly.open(path, info)
  local reason, code
  if not info then info, reason, code = SoundminerReadOnly.stat(path) end
  if not info then return nil, reason, code end
  if info.directory then return nil, "Source path is a directory", 21 end
  info.path, info.position, info.closed = path, 0, false
  return setmetatable(info, { __index = sm_read_methods })
end

function sm_read_methods:close()
  self.closed = true
  return true
end

function sm_read_methods:unchanged()
  if self.closed or self.failed then return false end
  local current = sm_read_request(self.native_path, 0, 0)
  if not current or not sm_read_same(self, current) then self.failed = true; return false end
  return true
end

function sm_read_methods:seek(whence, offset)
  if self.closed or self.failed then return nil, "Shared source reader is closed or changed" end
  whence, offset = whence or "cur", offset or 0
  local base = whence == "set" and 0 or whence == "cur" and self.position or whence == "end" and self.size
  if not base or type(offset) ~= "number" or offset % 1 ~= 0 or math.abs(offset) > 9007199254740991 then
    return nil, "Invalid shared source seek"
  end
  local position = base + offset
  if position < 0 or position > 9007199254740991 then return nil, "Shared source seek outside bounds" end
  self.position = position
  return position
end

function sm_read_methods:read(count)
  if self.closed or self.failed then return nil, "Shared source reader is closed or changed" end
  if type(count) ~= "number" or count % 1 ~= 0 or count < 0 or count > sm_read_cap then
    return nil, "Shared source read requires a bounded byte count (at most 16 MiB)"
  end
  if count == 0 then return "" end
  if self.position >= self.size then return nil end
  local remaining = math.min(count, self.size - self.position)
  local parts = {}
  while remaining > 0 do
    local wanted = math.min(remaining, 65536)
    local result, reason = sm_read_request(self.native_path, self.position, wanted)
    if not result or not sm_read_same(self, result) or #result.bytes ~= wanted then
      self.failed = true
      return nil, reason or "Shared source changed during read"
    end
    parts[#parts + 1] = result.bytes
    self.position, remaining = self.position + wanted, remaining - wanted
  end
  return table.concat(parts)
end
