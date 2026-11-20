-- The open instance already passed the shared reader's file-format checks.
-- Keep its schema parser and unsupported table operations available.
SoundminerNative = {}

local native_hex = {}
for i = 0,255 do native_hex[string.format("%02x",i)] = string.char(i) end

local function native_failure(code)
  local message = code == "!changed"
    and "Soundminer 数据库正在变化，本次读取已停止；可保持 Soundminer 运行，改用稳定副本重试"
    or "无法读取 Soundminer 数据，请检查所选数据库并重试"
  error(translate_ui_text and translate_ui_text(message) or message, 0)
end

local function native_rows(db, op, key, index, limit, columns)
  local wire = reaper.PRS_SM_Read(db.native_handle,op,key,index,limit)
  if type(wire) ~= "string" or wire:sub(1,1) ~= "+" then native_failure(wire) end
  local result, row, p = {}, nil, 2
  while p <= #wire do
    local first, last, column, kind, size = wire:find("^(%d+)([isdx])(%d+):",p)
    column, size = tonumber(column), tonumber(size)
    if not first or last + size > #wire then native_failure() end
    local value = wire:sub(last+1,last+size)
    if kind == "i" then value = tonumber(value)
    elseif kind == "x" or kind == "d" then
      if size % 2 ~= 0 then native_failure() end
      value = value:gsub("..", native_hex)
      if kind == "d" then value = string.unpack("<d",value) end
    end
    if column == 0 then
      if math.type(value) ~= "integer" then native_failure() end
      row = { _rowid = value }; result[#result+1] = row
    else
      local name = columns[column]
      if not row or not name then native_failure() end
      row[name] = value
    end
    p = last + size + 1
  end
  return result
end

local function native_schema(db, name)
  local schema = db:tables()[name]
  if not schema then return end
  -- Preserve both SQLite's rowid alias and the Lua row's pagination key.
  for _, column in ipairs(schema.columns) do
    if column:lower() == "_rowid_" or column == "_rowid" then return end
  end
  return schema
end

local function native_batches(db, schema, op, mask, columns)
  local key, done = "", false
  return function()
    if done then return end
    local rows = native_rows(db,op,key,mask,64,columns or schema.columns)
    if #rows == 0 then done = true; return end
    key = tostring(rows[#rows]._rowid)
    return rows
  end
end

function SoundminerNative.attach(db, path)
  if type(reaper) ~= "table" or type(reaper.PRS_SM_Open) ~= "function"
    or type(reaper.PRS_SM_Valid) ~= "function" or type(reaper.PRS_SM_Close) ~= "function"
    or type(reaper.PRS_SM_Read) ~= "function" then return db end
  local handle = reaper.PRS_SM_Open(path)
  if handle == 0 then return db end -- OS SQLite unavailable; keep the protected Lua reader
  if not handle or handle < 0 or not db:unchanged() then
    if handle and handle > 0 then reaper.PRS_SM_Close(handle) end
    local message = "Soundminer 数据库正在变化，本次读取已停止；可保持 Soundminer 运行，改用稳定副本重试"
    return nil, translate_ui_text and translate_ui_text(message) or message
  end
  local old_close, old_rows, old_batches = db.close, db.rows, db.row_batches
  local old_get, old_lookup = db.get, db.lookup
  db.native, db.native_handle = true, handle
  function db:close()
    if self.native_handle then reaper.PRS_SM_Close(self.native_handle); self.native_handle = nil end
    old_close(self)
  end
  function db:unchanged()
    return self.native_handle ~= nil and reaper.PRS_SM_Valid(self.native_handle)
  end
  function db:row_batches(name, now)
    local schema = name == "justinmetadata" and native_schema(self,name)
    if not schema then return old_batches(self,name,now) end
    return native_batches(self,schema,"rows","")
  end
  function db:path_batches(now)
    local schema = native_schema(self,"justinmetadata")
    if not schema then return old_batches(self,"justinmetadata",now) end
    local fields, bits, mask = {"FilePath","Pathname","Filename"}, { FilePath=1, Pathname=2, Filename=4 }, 0
    for _, column in ipairs(schema.columns) do mask = mask | (bits[column] or 0) end
    if mask == 0 then return old_batches(self,"justinmetadata",now) end
    return native_batches(self,schema,"paths",tostring(mask),fields)
  end
  function db:rows(name)
    local schema = name == "justinmetadata" and native_schema(self,name)
    if not schema then return old_rows(self,name) end
    local batches = native_batches(self,schema,"rows","")
    local rows, i = {}, 0
    return function()
      if not self:unchanged() then native_failure("!changed") end
      if i == #rows then rows, i = batches() or {}, 0 end
      i = i+1
      return rows[i]
    end
  end
  function db:get(name, id)
    local schema = (name == "justinmetadata" or name == "waveform") and native_schema(self,name)
    if not schema then return old_get(self,name,id) end
    assert(math.type(id) == "integer","rowid must be an integer")
    return native_rows(self,name == "waveform" and "wave_id" or "metadata_id",tostring(id),"",1,schema.columns)[1]
  end
  function db:lookup(name, column, key)
    local schema = name == "overviews" and (column == "filepathhash" or column == "filepath") and native_schema(self,name)
    if not schema then return old_lookup(self,name,column,key) end
    local index = self.indexes[name] and self.indexes[name][column]
    if not index then
      if not self:unchanged() then native_failure("!changed") end
      return nil,"index_unavailable"
    end
    assert(type(key) == "string","index lookup requires a text key")
    if key:find("%z") or #key > 32768 or #index.name > 512 then return old_lookup(self,name,column,key) end
    return native_rows(self,column == "filepathhash" and "cache_hash" or "cache_path",key,index.name,1,schema.columns)[1]
  end
  function db:search_rowids(query, limit)
    if type(reaper.PRS_SM_Search) ~= "function" or type(query) ~= "string" or query:find("%z") then return end
    limit = math.max(1, math.min(40, math.floor(tonumber(limit) or 32)))
    local wire = reaper.PRS_SM_Search(self.native_handle,query,limit)
    if wire == "!changed" then native_failure(wire) end
    if type(wire) ~= "string" or wire:sub(1,1) ~= "+" then return end
    local ids = {}
    for id in wire:gmatch("([%-]?%d+)\n") do ids[#ids+1] = tonumber(id) end
    return ids
  end
  return db
end
