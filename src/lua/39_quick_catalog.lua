-- A disposable index into the committed PRS TSV, never Soundminer's database.
-- During hydration only search/preview are allowed; authoritative writes still
-- wait for the complete catalog. A verified cumulative journal shadows the
-- base snapshot, including deletions. No index is required on the first run.
QuickCatalog = {}
do
  local Q = QuickCatalog
  local function stamp(path, optional)
    if not SoundminerReadOnly then return nil end
    local s, _, code = SoundminerReadOnly.stat(path)
    if not s then return optional and code == 2 and "-" or nil end
    if s.directory then return nil end
    return table.concat({s.identity,s.mtime,s.size},"|"), s.size
  end
  local function snapshot()
    local signature = stamp(DATABASE_FILE)
    if not signature then return end
    local f = io.open(DATABASE_FILE, "rb")
    if not f then return end
    local line = f:read("*l")
    local fields = line and split_tsv(line) or {}
    local generation = 0
    if is_persistence_schema_fields(fields) then
      generation = persistence_schema_generation(fields)
      fields = split_tsv(f:read("*l") or "")
    end
    local pos = {}
    for i,k in ipairs(fields) do pos[k]=i end
    if not generation or not pos.path or not pos.name then f:close(); return end
    local start = f:seek()
    f:close()
    return {signature=signature, generation=generation, fields=pos, start=start, offset=start}
  end
  local function close(s, publish)
    if not s then return end
    if s.file then s.file:close(); s.file=nil end
    if s.id then reaper.PRS_Quick_Close(s.id,publish==true);s.id=nil end
  end
  local function body(row)
    return table.concat({row.name,row.path,row.library,row.description,row.keywords,row.category,row.subcategory,row.catid}," "):lower()
  end
  local function row(values,fields)
    local path=values[fields.path]
    if not path or path=="" or #path>32768 or path:find("[%z\1-\31]") or is_ignored_media_path(path) then return end
    local a={path=path}
    for _,k in ipairs({"name","library","description","keywords","category","subcategory","catid"}) do
      local value = values[fields[k]] or ""
      if #value > 2048 then
        local limit = 2048
        while limit > 0 and (value:byte(limit+1) & 0xc0) == 0x80 do limit=limit-1 end
        value=value:sub(1,limit)
      end
      a[k]=value
    end
    for _,k in ipairs({"duration","channels","sample_rate","size"}) do a[k]=tonumber(values[fields[k]]) or 0 end
    if a.name=="" then a.name=basename(path) end
    return a
  end
  function Q.begin()
    if state.persistence_read_only then return end
    local s=snapshot(); if not s then return end
    local js,bytes=stamp(DATABASE_JOURNAL_FILE,true)
    if not js or (bytes or 0)>1024*1024 then close(s);return end
    s.journal,s.shadow,s.updated,s.visible=js,{},{},{}
    if js~="-" then
      local j=io.open(DATABASE_JOURNAL_FILE,"rb")
      local data=j and j:read(1024*1024+1);if j then j:close() end
      local checkpoint = state.startup_session and coroutine.isyieldable() and startup_checkpoint or nil
      local entries,_,fields=decode_asset_journal(data or "",s.generation,nil,checkpoint)
      if not entries or not fields or #entries>4096 then close(s);return end
      local keys={};for i,k in ipairs(fields) do keys[k]=i end
      if not keys.path then close(s);return end
      for _,entry in ipairs(entries) do
        local a=row(entry.values,keys)
        if not a then close(s);return end
        local key=path_key(a.path)
        if s.shadow[key] then close(s);return end
        s.shadow[key]=true
        if entry.op=="upsert" then s.updated[#s.updated+1]=a end
      end
    end
    if type(reaper.PRS_Quick_Open)=="function" then
      local id=reaper.PRS_Quick_Open(PsyReaSFXScope.id,s.signature,false)
      if id>0 then s.id=id end
    end
    Q.reader=s
  end
  local function valid(s)
    return s and s.signature==stamp(DATABASE_FILE) and s.journal==stamp(DATABASE_JOURNAL_FILE,true)
  end
  function Q.find(query)
    local s=Q.reader
    if not valid(s) then close(s);Q.reader=nil;return {} end
    s.file=io.open(DATABASE_FILE,"rb")
    if not s.file then close(s);Q.reader=nil;return {} end
    local terms={}
    for t in query:lower():gmatch("%S+") do terms[#terms+1]=t end
    local results, shown={},{}
    local function take(a)
      if not a or #results>=32 then return end
      local key=path_key(a.path);if shown[key] then return end
      local b=body(a);for _,t in ipairs(terms) do if not b:find(t,1,true) then return end end
      shown[key]=a
      results[#results+1]={name=a.name,path=a.path,duration=a.duration}
    end
    for _,a in ipairs(s.updated) do take(a);if #results>=32 then break end end
    local function at_line(line)
      if line and #line<=1024*1024 then
        local a=row(split_tsv(line),s.fields)
        if a and not s.shadow[path_key(a.path)] then take(a) end
      end
    end
    if s.id then
      local offsets=reaper.PRS_Quick_Find(s.id,table.concat(terms," "))
      for offset in tostring(offsets):gmatch("(%d+),") do
        if #results>=32 then break end
        if s.file:seek("set",tonumber(offset)) then at_line(s.file:read("*l")) end
      end
    else
      -- New/changed snapshot: first rows are usable immediately without
      -- claiming an exhaustive search or scanning the whole file in the RPC.
      s.file:seek("set",s.start)
      local deadline=reaper.time_precise()+0.003
      for _=1,96 do
        local line=s.file:read("*l");if not line then break end;at_line(line)
        if #results>=32 or reaper.time_precise()>=deadline then break end
      end
    end
    s.file:close();s.file=nil
    if not valid(s) then close(s);Q.reader=nil;return {} end
    s.visible=shown;return results
  end
  function Q.asset(path)
    local s=Q.reader
    return valid(s) and s.visible[path_key(path)] or nil
  end
  function Q.finish()
    close(Q.reader);Q.reader=nil
  end
  function Q.shutdown()
    Q.finish();close(Q.builder);Q.builder=nil
  end
  function Q.step()
    if type(reaper.PRS_Quick_Open)~="function" or state.persistence_read_only or state.startup_session then return end
    local now=reaper.time_precise()
    if not Q.builder then
      if now<(Q.next_check or 0) then return end
      Q.next_check=now+10
      local s=snapshot();if not s then return end
      if s.signature==Q.checked then close(s);return end
      local id=reaper.PRS_Quick_Open(PsyReaSFXScope.id,s.signature,false)
      if id>0 then reaper.PRS_Quick_Close(id,false);Q.checked=s.signature;close(s);return end
      id=reaper.PRS_Quick_Open(PsyReaSFXScope.id,s.signature,true)
      if id<=0 then close(s);return end
      s.id=id;Q.builder=s
    end
    local s=Q.builder
    -- Release the PRS TSV between slices so snapshot replacement can proceed.
    if s.signature~=stamp(DATABASE_FILE) then close(s);Q.builder=nil;return end
    s.file=io.open(DATABASE_FILE,"rb")
    if not s.file or not s.file:seek("set",s.offset) then close(s);Q.builder=nil;return end
    for _=1,128 do
      local offset=s.file:seek()
      local line,err=s.file:read("*l")
      if not line then
        local complete=not err and s.signature==stamp(DATABASE_FILE)
        s.file:close();s.file=nil
        if reaper.PRS_Quick_Close(s.id,complete) then Q.checked=s.signature end
        Q.builder=nil;return
      end
      if #line<=1024*1024 then
        local a=row(split_tsv(line),s.fields)
        if a and not reaper.PRS_Quick_Add(s.id,tostring(offset),body(a)) then
          close(s);Q.builder=nil;return
        end
      end
      if reaper.time_precise()-now>=0.002 then break end
    end
    s.offset=s.file:seek();s.file:close();s.file=nil
  end
end
