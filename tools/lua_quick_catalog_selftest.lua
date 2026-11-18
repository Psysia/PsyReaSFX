-- Exercise actual TSV/journal reads and catalog lifecycle in an isolated folder.
-- Native SQLite and file-sharing behavior are exercised separately by the DLL test.
local directory = assert(arg[1], "provide an empty fixture directory")
DATABASE_FILE = directory .. "/snapshot.tsv"
DATABASE_JOURNAL_FILE = directory .. "/journal.tsv"
local function write(path, data)
  local f = assert(io.open(path,"wb")); assert(f:write(data)); assert(f:close())
end
assert(not io.open(DATABASE_FILE,"rb"), "fixture must be new")
reaper = {time_precise=os.clock, ReaWeb_ReadSharedRange=dofile("tools/lua_shared_readonly_fixture.lua")}
state = {}
PsyReaSFXScope = {id="prs"}
local function data(path)
  local f = assert(io.open(path,"rb")); local source=f:read("a"); f:close(); return source
end
local core = data("src/lua/10_ui_core.lua")
local a = assert(core:find("function unescape_tsv(",1,true))
local b = assert(core:find("\nend",assert(core:find("function split_tsv(",a,true)),true))
assert(load(core:sub(a,b+3)))()
function path_key(path) return path:lower() end
function basename(path) return path:match("[^/]+$") end
function is_ignored_media_path(path) return path:match("%.reapeaks$") end
function is_persistence_schema_fields(fields) return fields[1]=="schema" end
function persistence_schema_generation(fields) return tonumber(fields[3]) end
dofile("src/lua/26_shared_readonly.lua")
dofile("src/lua/36_asset_journal.lua")
dofile("src/lua/39_quick_catalog.lua")
local committed, staged, scopes = {}, {}, {}
function reaper.PRS_Quick_Open(scope,signature,build)
  scopes[scope]=true
  if build then staged={scope=scope,signature=signature,rows={}};return 1 end
  local index=committed[scope]
  if index and index.signature==signature then return 2 end
  return 0
end
function reaper.PRS_Quick_Add(_,offset,body)
  staged.rows[#staged.rows+1]={offset=offset,body=body};return true
end
function reaper.PRS_Quick_Close(id,publish)
  if id==1 and publish then committed[staged.scope]=staged;return true end
  return false
end
function reaper.PRS_Quick_Find(_,term)
  local offsets={}
  for _,r in ipairs(committed[PsyReaSFXScope.id].rows) do
    if r.body:find(term,1,true) then offsets[#offsets+1]=r.offset end
  end
  return table.concat(offsets,",")..","
end
local fields={"path","name","duration","description"}
local first="C:/field/a.wav\train\t3\tfield recording\n"
local snapshot="schema\tassets\t7\n"..table.concat(fields,"\t").."\n"..first
for i=1,320 do snapshot=snapshot..("C:/field/%d.wav\tpad %d\t2\tfield\n"):format(i,i) end
snapshot=snapshot.."C:/field/last.wav\t火车进站\t8\ttrain\n"
write(DATABASE_FILE,snapshot)
QuickCatalog.begin()
assert(QuickCatalog.reader and not QuickCatalog.reader.id)
assert(QuickCatalog.find("rain")[1].path=="C:/field/a.wav")
assert(not QuickCatalog.asset("C:/field/last.wav"),"only visible results can be auditioned")
assert(#QuickCatalog.find("火车")==0,"first-run fallback is bounded")
QuickCatalog.finish()
for i=1,30 do QuickCatalog.step();if committed.prs then break end end
assert(committed.prs and #committed.prs.rows==322 and not QuickCatalog.builder)
write(DATABASE_JOURNAL_FILE,assert(encode_asset_journal(7,fields,{
  {op="delete",values={"C:/field/a.wav","","",""}},
  {op="upsert",values={"C:/field/1.wav","changed train","3","new"}},
})))
QuickCatalog.begin()
assert(QuickCatalog.reader.id and #QuickCatalog.find("rain")==2)
assert(not QuickCatalog.asset("C:/field/a.wav"))
local hit=assert(QuickCatalog.find("火车")[1]);assert(QuickCatalog.asset(hit.path).duration==8)
assert(#QuickCatalog.find("pad 1")>0 and not QuickCatalog.asset("C:/field/1.wav"))
write(DATABASE_JOURNAL_FILE,"broken\n")
assert(not QuickCatalog.asset(hit.path),"snapshot membership must be rechecked on click")
assert(#QuickCatalog.find("train")==0 and not QuickCatalog.reader)
QuickCatalog.begin();assert(not QuickCatalog.reader,"corrupt journal exposed base rows")
assert(os.remove(DATABASE_JOURNAL_FILE))
PsyReaSFXScope.id="sm_0123456789abcdef";QuickCatalog.begin()
assert(QuickCatalog.reader and not QuickCatalog.reader.id and scopes[PsyReaSFXScope.id])
assert(#QuickCatalog.find("火车")==0,"different catalog used the PRS index")
QuickCatalog.shutdown()
print("Quick catalog passed: bounded first start, persisted offsets, updates, deletes, stale clicks, journal validation and independent scopes")
