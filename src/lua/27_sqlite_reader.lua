-- Read-only SQLite table reader for stable Soundminer snapshots.
-- File-format reference: https://sqlite.org/fileformat2.html
-- No SQL is executed, no database is opened for writing, and no extensions load.
-- Active WAL/journals are refused without recovery/checkpoint/locking SQL.
-- Soundminer may keep running: use a stable exported copy when it is writing.
-- unchanged() detects observed changes; it does not lock another application's DB.
SoundminerSQLite = {}

local sm_sqlite_methods = {}
local sm_sqlite_max_record = 16 * 1024 * 1024
local sm_sqlite_max_columns = 4096
local sm_sqlite_max_schema = 10000

local function sm_sqlite_require(condition, message)
  if not condition then error("Soundminer SQLite: " .. message, 0) end
end

local function sm_sqlite_uint(bytes, pos, count)
  sm_sqlite_require(pos >= 1 and pos + count - 1 <= #bytes, "truncated integer")
  local value = 0
  for index = pos, pos + count - 1 do value = (value << 8) | bytes:byte(index) end
  return value
end

local function sm_sqlite_varint(bytes, pos, limit)
  local value = 0
  limit = limit or #bytes
  for index = 1, 9 do
    sm_sqlite_require(pos <= limit, "truncated varint")
    local byte = bytes:byte(pos)
    pos = pos + 1
    if index == 9 then return (value << 8) | byte, pos end
    value = (value << 7) | (byte & 0x7f)
    if byte < 128 then return value, pos end
  end
end

local function sm_sqlite_sidecars_clear(path)
  local wal, _, wal_error = SoundminerReadOnly.open(path .. "-wal")
  if not wal and wal_error and wal_error ~= 2 then return false end
  if wal then
    local size = wal:seek("end")
    local stable = wal:unchanged()
    wal:close()
    if not stable or not size or size > 0 then return false end
  end
  local journal, _, journal_error = SoundminerReadOnly.open(path .. "-journal")
  if not journal and journal_error and journal_error ~= 2 then return false end
  if journal then
    local wanted = math.min(journal.size, 28)
    local header = journal:read(wanted)
    local stable = journal:unchanged()
    journal:close()
    -- PERSIST journals are harmless after SQLite zeros their header.
    if not stable or not header or #header ~= wanted or header:find("[^%z]") then return false end
  end
  return true
end

function sm_sqlite_methods:close()
  self.closed = true
  self.cache, self.cache_order = {}, {}
end

function sm_sqlite_methods:unchanged()
  if self.closed or not sm_sqlite_sidecars_clear(self.path) then return false end
  local fresh = SoundminerReadOnly.open(self.path)
  if not fresh then return false end
  local header = fresh:read(100)
  local size = fresh:seek("end")
  fresh:close()
  return header == self.header and size == self.size and fresh.identity == self.identity and fresh.mtime == self.mtime
end

function sm_sqlite_methods:_page(number)
  sm_sqlite_require(not self.closed, "database is closed")
  sm_sqlite_require(math.type(number) == "integer" and number >= 1 and number <= self.page_count,
    "page outside database")
  if self.cache[number] then return self.cache[number] end
  self.read_count = self.read_count + 1
  sm_sqlite_require(self:unchanged(), "database changed or has an active journal; use a stable copy")
  -- Every source open (including sidecars) uses the native shared reader. There
  -- is no CRT fallback that could deny Soundminer's rename/delete operations.
  local file, open_error = SoundminerReadOnly.open(self.path)
  sm_sqlite_require(file, open_error or "database read failed")
  local ok, bytes = pcall(function()
    sm_sqlite_require(file:seek("set", (number - 1) * self.page_size) ~= nil, "page seek failed")
    return file:read(self.page_size)
  end)
  file:close()
  sm_sqlite_require(ok, bytes)
  sm_sqlite_require(bytes and #bytes == self.page_size, "truncated page")
  sm_sqlite_require(self:unchanged(), "database changed while reading; use a stable copy")
  -- Bounded FIFO cache (at most 4 MiB at the largest SQLite page size).
  local slot = (self.cache_next % 64) + 1
  local old = self.cache_order[slot]
  if old then self.cache[old] = nil end
  self.cache_order[slot], self.cache[number], self.cache_next = number, bytes, slot
  return bytes
end

local function sm_sqlite_btree(db, number, index_tree)
  local bytes = db:_page(number)
  local start = number == 1 and 101 or 1
  local kind = bytes:byte(start)
  sm_sqlite_require(index_tree and (kind == 2 or kind == 10) or not index_tree and (kind == 5 or kind == 13),
    "unexpected b-tree page type")
  local count = sm_sqlite_uint(bytes, start + 3, 2)
  local pointer = start + ((kind == 5 or kind == 2) and 12 or 8)
  sm_sqlite_require(pointer + count * 2 - 1 <= db.usable, "invalid cell pointer array")
  return { bytes = bytes, kind = kind, count = count, pointer = pointer, start = start,
    number = number, index = 1 }
end

local function sm_sqlite_cell(db, page, index)
  sm_sqlite_require(index >= 1 and index <= page.count, "cell outside page")
  local offset = sm_sqlite_uint(page.bytes, page.pointer + (index - 1) * 2, 2) + 1
  sm_sqlite_require(offset >= page.pointer + page.count * 2 and offset <= db.usable,
    "invalid cell offset")
  return offset
end

local function sm_sqlite_record(bytes)
  local header_size, pos = sm_sqlite_varint(bytes, 1)
  sm_sqlite_require(header_size >= pos - 1 and header_size <= #bytes, "invalid record header")
  local serials = {}
  while pos <= header_size do
    local serial
    serial, pos = sm_sqlite_varint(bytes, pos, header_size)
    sm_sqlite_require(serial >= 0 and serial ~= 10 and serial ~= 11, "invalid record serial type")
    serials[#serials + 1] = serial
    sm_sqlite_require(#serials <= sm_sqlite_max_columns, "too many record columns")
  end
  local values, cursor = {}, header_size + 1
  for index, serial in ipairs(serials) do
    local length = serial < 5 and serial or serial == 5 and 6 or
      (serial == 6 or serial == 7) and 8 or serial >= 12 and ((serial - 12) // 2) or 0
    sm_sqlite_require(length >= 0 and cursor + length - 1 <= #bytes, "truncated record value")
    if serial == 0 then
      -- Preserve positions by indexing values, never by appending non-null values.
    elseif serial <= 6 then
      local value = sm_sqlite_uint(bytes, cursor, length)
      if length < 8 and bytes:byte(cursor) >= 128 then value = value - (1 << (length * 8)) end
      values[index] = value
    elseif serial == 7 then
      local value = string.unpack(">d", bytes, cursor)
      sm_sqlite_require(value == value and value ~= math.huge and value ~= -math.huge,
        "non-finite real value")
      values[index] = value
    elseif serial == 8 or serial == 9 then
      values[index] = serial - 8
    else
      values[index] = bytes:sub(cursor, cursor + length - 1)
    end
    cursor = cursor + length
  end
  sm_sqlite_require(cursor == #bytes + 1, "record has trailing bytes")
  return values, #serials, serials
end

local function sm_sqlite_payload(db, page, pos, size, index_tree)
  sm_sqlite_require(size >= 0 and size <= sm_sqlite_max_record, "record exceeds 16 MiB limit")
  local local_size = size
  local maximum = index_tree and (((db.usable - 12) * 64 // 255) - 23) or (db.usable - 35)
  if size > maximum then
    local minimum = ((db.usable - 12) * 32 // 255) - 23
    local_size = minimum + ((size - minimum) % (db.usable - 4))
    if local_size > maximum then local_size = minimum end
  end
  sm_sqlite_require(pos + local_size - 1 <= db.usable, "truncated local payload")
  local chunks = { page.bytes:sub(pos, pos + local_size - 1) }
  local remaining = size - local_size
  if remaining > 0 then
    sm_sqlite_require(pos + local_size + 3 <= db.usable, "truncated overflow pointer")
    local next_page = sm_sqlite_uint(page.bytes, pos + local_size, 4)
    local visited = { [page.number] = true }
    while remaining > 0 do
      sm_sqlite_require(not visited[next_page], "overflow page cycle")
      visited[next_page] = true
      local overflow = db:_page(next_page)
      local length = math.min(remaining, db.usable - 4)
      chunks[#chunks + 1] = overflow:sub(5, 4 + length)
      remaining = remaining - length
      next_page = sm_sqlite_uint(overflow, 1, 4)
    end
    sm_sqlite_require(next_page == 0, "overflow chain exceeds record")
  end
  return sm_sqlite_record(table.concat(chunks))
end

local function sm_sqlite_leaf_row(db, page, index)
  local pos = sm_sqlite_cell(db, page, index)
  local size, rowid
  size, pos = sm_sqlite_varint(page.bytes, pos, db.usable)
  rowid, pos = sm_sqlite_varint(page.bytes, pos, db.usable)
  local values, count = sm_sqlite_payload(db, page, pos, size, false)
  return values, rowid, count
end

local function sm_sqlite_raw_rows(db, root)
  local stack, seen = {}, {}
  local function push(number)
    sm_sqlite_require(#stack < 64, "table depth exceeds limit")
    sm_sqlite_require(not seen[number], "repeated table page")
    seen[number] = true
    stack[#stack + 1] = sm_sqlite_btree(db, number)
  end
  push(root)
  return function()
    while #stack > 0 do
      local page = stack[#stack]
      local index = page.index
      page.index = index + 1
      if page.kind == 13 then
        if index <= page.count then return sm_sqlite_leaf_row(db, page, index) end
        stack[#stack] = nil
      elseif index <= page.count then
        local offset = sm_sqlite_cell(db, page, index)
        sm_sqlite_require(offset + 3 <= db.usable, "truncated child pointer")
        push(sm_sqlite_uint(page.bytes, offset, 4))
      elseif index == page.count + 1 then
        push(sm_sqlite_uint(page.bytes, page.start + 8, 4))
      else
        stack[#stack] = nil
      end
    end
    sm_sqlite_require(db:unchanged(), "database changed or has an active journal")
  end
end

-- Tokenize CREATE TABLE without evaluating it. Quotes/comments/parentheses are
-- respected so commas in defaults and constraints cannot become fake columns.
local function sm_sqlite_tokens(sql)
  local tokens, index = {}, 1
  while index <= #sql do
    local ch, pair = sql:sub(index, index), sql:sub(index, index + 1)
    if ch:match("%s") then index = index + 1
    elseif pair == "--" then index = (sql:find("\n", index + 2, true) or #sql) + 1
    elseif pair == "/*" then
      local last = sql:find("*/", index + 2, true)
      sm_sqlite_require(last, "unterminated SQL comment")
      index = last + 2
    elseif ch == '"' or ch == "`" or ch == "'" or ch == "[" then
      local close = ch == "[" and "]" or ch
      local parts, cursor, closed = {}, index + 1, false
      while cursor <= #sql do
        local current = sql:sub(cursor, cursor)
        if current == close then
          if close ~= "]" and sql:sub(cursor + 1, cursor + 1) == close then
            parts[#parts + 1] = close; cursor = cursor + 2
          else closed = true; cursor = cursor + 1; break end
        else parts[#parts + 1] = current; cursor = cursor + 1 end
      end
      sm_sqlite_require(closed, "unterminated SQL quote")
      tokens[#tokens + 1] = { value = table.concat(parts), quoted = true, quote = ch }
      index = cursor
    elseif ch:match("[(),]") then
      tokens[#tokens + 1] = { value = ch }; index = index + 1
    else
      local cursor = index + 1
      while cursor <= #sql and not sql:sub(cursor, cursor):match("[%s(),%[%]`\"']") do cursor = cursor + 1 end
      tokens[#tokens + 1] = { value = sql:sub(index, cursor - 1) }
      index = cursor
    end
    sm_sqlite_require(#tokens <= 100000, "schema declaration exceeds token limit")
  end
  return tokens
end

local function sm_sqlite_table_schema(name, root, sql)
  local tokens = sm_sqlite_tokens(sql)
  local first
  for index, token in ipairs(tokens) do
    if not token.quoted and token.value:upper() == "VIRTUAL" then return nil end
    if token.value == "(" and not token.quoted then first = index + 1; break end
  end
  if not first then return nil end
  local definitions, definition, depth, last = {}, {}, 1, nil
  for index = first, #tokens do
    local token = tokens[index]
    if not token.quoted and token.value == "(" then depth = depth + 1 end
    if not token.quoted and token.value == ")" then depth = depth - 1 end
    if depth == 0 then definitions[#definitions + 1] = definition; last = index; break end
    if depth == 1 and not token.quoted and token.value == "," then
      definitions[#definitions + 1] = definition; definition = {}
    else definition[#definition + 1] = token end
  end
  sm_sqlite_require(last, "unclosed table declaration")
  for index = last + 1, #tokens - 1 do
    if tokens[index].value:upper() == "WITHOUT" and tokens[index + 1].value:upper() == "ROWID" then return nil end
  end
  local columns, aliases, names, defaults, collations = {}, {}, {}, {}, {}
  local table_primary
  for _, def in ipairs(definitions) do
    local token = def[1]
    sm_sqlite_require(token, "empty column declaration")
    local key = token.value:upper()
    local is_constraint = not token.quoted and (key == "CONSTRAINT" or key == "PRIMARY"
      or key == "UNIQUE" or key == "CHECK" or key == "FOREIGN")
    if is_constraint then
      local offset = key == "CONSTRAINT" and 3 or 1
      if def[offset] and def[offset].value:upper() == "PRIMARY" and def[offset + 1]
        and def[offset + 1].value:upper() == "KEY" and def[offset + 2]
        and def[offset + 2].value == "(" and def[offset + 3] and def[offset + 4]
        and def[offset + 4].value == ")" then table_primary = def[offset + 3].value end
    else
      sm_sqlite_require(not names[key], "duplicate column name")
      names[key] = true
      columns[#columns + 1] = token.value
      local column = #columns
      local datatype = def[2] and def[2].value:upper() or ""
      local boundary = def[3] and def[3].value:upper()
      local constraints = { CONSTRAINT = true, PRIMARY = true, NOT = true, UNIQUE = true,
        CHECK = true, DEFAULT = true, COLLATE = true, REFERENCES = true, GENERATED = true, AS = true }
      aliases[column] = datatype == "INTEGER" and (not boundary or constraints[boundary] == true)
      for index = 3, #def do
        local current = def[index]
        if not current.quoted then
          local word = current.value:upper()
          if word == "GENERATED" or word == "AS" then return nil end
          if word == "PRIMARY" and def[index + 1] and def[index + 1].value:upper() == "KEY"
            and aliases[column] and not (def[index + 2] and def[index + 2].value:upper() == "DESC") then
            table_primary = token.value
          end
          if word == "COLLATE" and def[index + 1] then collations[token.value] = def[index + 1].value:upper() end
          if word == "DEFAULT" and def[index + 1] then
            local value = def[index + 1]
            if value.quote == "'" or value.quote == '"' then defaults[column] = value.value
            elseif not value.quoted then defaults[column] = tonumber(value.value) end
          end
        end
      end
    end
    sm_sqlite_require(#columns <= sm_sqlite_max_columns, "too many schema columns")
  end
  local primary
  for index, column in ipairs(columns) do
    if table_primary and column:upper() == table_primary:upper() and aliases[index] then primary = index end
  end
  return { name = name, root = root, columns = columns, sql = sql, primary = primary,
    defaults = defaults, collations = collations }
end

local function sm_sqlite_index_schema(name, table_name, root, sql)
  if type(sql) ~= "string" then return nil end
  local tokens = sm_sqlite_tokens(sql)
  local on
  for index, token in ipairs(tokens) do
    if not token.quoted and token.value:upper() == "ON" then on = index; break end
  end
  if not on or not tokens[on + 1] or tokens[on + 1].value ~= table_name
    or not tokens[on + 2] or tokens[on + 2].value ~= "(" or not tokens[on + 3] then return nil end
  local column = tokens[on + 3].value
  local index = on + 4
  local binary
  while tokens[index] and tokens[index].value ~= ")" do
    local word = tokens[index].value:upper()
    if word == "ASC" then index = index + 1
    elseif word == "COLLATE" and tokens[index + 1] and tokens[index + 1].value:upper() == "BINARY" then
      binary = true
      index = index + 2
    else return nil end
  end
  if not tokens[index] or index ~= #tokens then return nil end
  return { name = name, table_name = table_name, root = root, column = column, binary = binary }
end

function sm_sqlite_methods:tables()
  if self.schema then return self.schema end
  local schema, indexes, count = {}, {}, 0
  for values in sm_sqlite_raw_rows(self, 1) do
    count = count + 1
    sm_sqlite_require(count <= sm_sqlite_max_schema, "too many schema entries")
    if values[1] == "table" and type(values[2]) == "string" and type(values[4]) == "number"
      and values[4] > 0 and type(values[5]) == "string" then
      local parsed = sm_sqlite_table_schema(values[2], values[4], values[5])
      if parsed then schema[parsed.name] = parsed end
    elseif values[1] == "index" and type(values[2]) == "string" and type(values[3]) == "string"
      and type(values[4]) == "number" and values[4] > 0 then
      local parsed = sm_sqlite_index_schema(values[2], values[3], values[4], values[5])
      if parsed then indexes[#indexes + 1] = parsed end
    end
  end
  self.schema, self.indexes = schema, {}
  for _, index in ipairs(indexes) do
    local owner = schema[index.table_name]
    if owner then
      for _, column in ipairs(owner.columns) do
        if column == index.column and (index.binary or not owner.collations[column] or owner.collations[column] == "BINARY") then
          self.indexes[index.table_name] = self.indexes[index.table_name] or {}
          self.indexes[index.table_name][column] = index
        end
      end
    end
  end
  return schema
end

local function sm_sqlite_mapped_row(schema, values, rowid, stored_count)
  sm_sqlite_require(stored_count <= #schema.columns, "record has more fields than its schema")
  local row = { _rowid = rowid }
  for index, column in ipairs(schema.columns) do
    if index == schema.primary then row[column] = values[index] or rowid
    elseif index > stored_count then row[column] = schema.defaults[index]
    else row[column] = values[index] end
  end
  return row
end

local function sm_sqlite_row_iterator(db, name)
  local schema = db:tables()[name]
  sm_sqlite_require(schema, "unsupported or missing table " .. tostring(name))
  local next_row = sm_sqlite_raw_rows(db, schema.root)
  return function()
    local values, rowid, count = next_row()
    if values then return sm_sqlite_mapped_row(schema, values, rowid, count) end
  end
end

function sm_sqlite_methods:rows(name)
  local next_row = sm_sqlite_row_iterator(self, name)
  return function()
    sm_sqlite_require(self:unchanged(), "database changed or has an active journal; use a stable copy")
    local row = next_row()
    sm_sqlite_require(self:unchanged(), "database changed while reading; use a stable copy")
    return row
  end
end

-- Inspect a small batch from one verified generation. _page also checks every
-- physical read. A mutation discards the entire batch before the caller sees it.
function sm_sqlite_methods:row_batches(name, now)
  local next_row = sm_sqlite_row_iterator(self, name)
  local finished = false
  return function()
    if finished then return end
    sm_sqlite_require(self:unchanged(), "database changed or has an active journal; use a stable copy")
    local rows, deadline = {}, now() + 0.003
    repeat
      local row = next_row()
      if not row then finished = true; break end
      rows[#rows + 1] = row
    until #rows >= 64 or now() >= deadline
    sm_sqlite_require(self:unchanged(), "database changed while reading; use a stable copy")
    if #rows > 0 then return rows end
  end
end

function sm_sqlite_methods:get(name, rowid)
  sm_sqlite_require(self:unchanged(), "database changed or has an active journal; use a stable copy")
  sm_sqlite_require(math.type(rowid) == "integer", "rowid must be an integer")
  local schema = self:tables()[name]
  sm_sqlite_require(schema, "unsupported or missing table " .. tostring(name))
  local number, visited = schema.root, {}
  for _ = 1, 64 do
    sm_sqlite_require(not visited[number], "table page cycle")
    visited[number] = true
    local page = sm_sqlite_btree(self, number)
    local low, high, match = 1, page.count, nil
    while low <= high do
      local index = (low + high) // 2
      local offset = sm_sqlite_cell(self, page, index)
      local key
      if page.kind == 5 then key = sm_sqlite_varint(page.bytes, offset + 4, self.usable)
      else
        local ignored
        ignored, offset = sm_sqlite_varint(page.bytes, offset, self.usable)
        key = sm_sqlite_varint(page.bytes, offset, self.usable)
      end
      if key >= rowid then match = index; high = index - 1 else low = index + 1 end
    end
    if page.kind == 13 then
      if not match then return nil end
      local values, key, count = sm_sqlite_leaf_row(self, page, match)
      if key == rowid then
        sm_sqlite_require(self:unchanged(), "database changed while reading; use a stable copy")
        return sm_sqlite_mapped_row(schema, values, key, count)
      end
      return nil
    end
    number = match and sm_sqlite_uint(page.bytes, sm_sqlite_cell(self, page, match), 4)
      or sm_sqlite_uint(page.bytes, page.start + 8, 4)
  end
  error("Soundminer SQLite: table depth exceeds limit", 0)
end

local function sm_sqlite_binary_compare(left, right)
  -- Lua's string ordering may use the process locale; SQLite BINARY does not.
  for index = 1, math.min(#left, #right) do
    local a, b = left:byte(index), right:byte(index)
    if a ~= b then return a < b and -1 or 1 end
  end
  return #left == #right and 0 or #left < #right and -1 or 1
end

function sm_sqlite_methods:lookup(name, column, value)
  sm_sqlite_require(self:unchanged(), "database changed or has an active journal; use a stable copy")
  sm_sqlite_require(type(value) == "string", "index lookup requires a text key")
  self:tables()
  local index = self.indexes[name] and self.indexes[name][column]
  if not index then return nil, "index_unavailable" end
  local number, visited = index.root, {}
  for _ = 1, 64 do
    sm_sqlite_require(not visited[number], "index page cycle")
    visited[number] = true
    local page = sm_sqlite_btree(self, number, true)
    local low, high, match = 1, page.count, nil
    while low <= high do
      local middle = (low + high) // 2
      local pos = sm_sqlite_cell(self, page, middle) + (page.kind == 2 and 4 or 0)
      local size
      size, pos = sm_sqlite_varint(page.bytes, pos, self.usable)
      local values, count, serials = sm_sqlite_payload(self, page, pos, size, true)
      sm_sqlite_require(count == 2 and math.type(values[2]) == "integer", "unsupported index record")
      local key, comparison = values[1], nil
      -- SQLite orders NULL and numbers before text, and blobs after text.
      sm_sqlite_require(key == nil or type(key) == "string" or type(key) == "number", "invalid index key")
      if key == nil or type(key) == "number" then comparison = -1
      elseif serials[1] % 2 == 0 then comparison = 1
      else comparison = sm_sqlite_binary_compare(key, value) end
      if comparison == 0 then return self:get(name, values[2]) end
      if comparison > 0 then match = middle; high = middle - 1 else low = middle + 1 end
    end
    if page.kind == 10 then return nil end
    number = match and sm_sqlite_uint(page.bytes, sm_sqlite_cell(self, page, match), 4)
      or sm_sqlite_uint(page.bytes, page.start + 8, 4)
  end
  error("Soundminer SQLite: index depth exceeds limit", 0)
end

function SoundminerSQLite.open(path)
  if type(path) ~= "string" or path == "" or path:find("%z") then return nil, "Invalid database path" end
  if type(SoundminerReadOnly) ~= "table" then return nil, "Shared read-only runtime is unavailable" end
  local file, open_error = SoundminerReadOnly.open(path)
  if not file then return nil, open_error end
  local ok, result = pcall(function()
    sm_sqlite_require(sm_sqlite_sidecars_clear(path), "active WAL/journal; Soundminer may keep running; use a stable exported copy")
    local header = file:read(100)
    sm_sqlite_require(header and #header == 100 and header:sub(1, 16) == "SQLite format 3\0", "not a SQLite 3 database")
    local page_size = sm_sqlite_uint(header, 17, 2)
    if page_size == 1 then page_size = 65536 end
    sm_sqlite_require(page_size >= 512 and page_size <= 65536 and (page_size & (page_size - 1)) == 0, "invalid page size")
    sm_sqlite_require(header:byte(19) >= 1 and header:byte(19) <= 2 and header:byte(20) >= 1
      and header:byte(20) <= 2, "unsupported SQLite file version")
    sm_sqlite_require(header:sub(22, 24) == string.char(64, 32, 32), "unsupported payload fractions")
    local schema_format = sm_sqlite_uint(header, 45, 4)
    sm_sqlite_require(schema_format >= 1 and schema_format <= 4, "unsupported schema format")
    sm_sqlite_require(sm_sqlite_uint(header, 57, 4) == 1, "only UTF-8 databases are supported")
    local usable, size = page_size - header:byte(21), file:seek("end")
    sm_sqlite_require(usable >= 480 and size and size >= page_size and size % page_size == 0, "invalid database size")
    local page_count = size // page_size
    local recorded = sm_sqlite_uint(header, 29, 4)
    if recorded > 0 and header:sub(25, 28) == header:sub(93, 96) then
      sm_sqlite_require(recorded == page_count, "database page count mismatch")
    end
    return setmetatable({ path = path, closed = false, header = header, page_size = page_size,
      identity = file.identity, mtime = file.mtime,
      usable = usable, size = size, page_count = page_count, cache = {}, cache_order = {},
      cache_next = 0, read_count = 0 }, { __index = sm_sqlite_methods })
  end)
  file:close()
  if not ok then return nil, tostring(result) end
  if not result:unchanged() then return nil, "Soundminer SQLite: database changed while opening; use a stable copy" end
  return result
end
