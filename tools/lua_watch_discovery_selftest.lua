local function read(path)
  local f=assert(io.open(path,"rb")); local s=f:read("*a"); f:close(); return s:gsub("\r\n","\n")
end
local source=read("src/lua/50_runtime_ui.lua")
local function region(s,first,last)
  local a=assert(s:find(first,1,true)); local b=assert(s:find(last,a+#first,true)); return s:sub(a,b-1)
end
local clock, reads, stats, made = 100, {}, 0, 0
local disk={
  ["c:/audio"]={files={},children={"nested","quiet"},stamp="2020.01.01 00:00:00"},
  ["c:/audio/nested"]={files={"old.wav","unfinished.wav"},children={},stamp="2020.01.01 00:00:00"},
  ["c:/audio/quiet"]={files={"quiet.wav"},children={},stamp="2020.01.01 00:00:00"},
}
state={roots={"c:/audio"},assets={},by_path={},favorites={},preview_history_assets={},
  watch_enabled=true,watch_silent=true,watch_interval=60,next_watch=0,interaction_until=0}
function path_key(s) return s:lower() end
function join_path(a,b) return a.."/"..b end
function dirname(s) return s:match("^(.*)/[^/]+$") end
function asset_path_sort_key(a) return path_key(a.path) end
function directory_exists(p) return disk[p]~=nil end
function is_audio_file(p) return p:match("%.wav$")~=nil end
function is_ignored_media_path() return false end
function is_ignored_directory_name() return false end
function ui_in_motion() return false end
function set_status(s) state.status=s end
function cancel_auxiliary_save() end
function clear_scan_checkpoint() end
function mark_asset_database_change() end
function mark_database_snapshot_dirty() end
function invalidate_similarity_index() end
function invalidate_library_counts() end
function invalidate_folder_navigation() end
function selection_remove() end
function make_placeholder(p,r) made=made+1; return {path=p,root=r,folder=dirname(p),ready=false} end
function add_or_update_asset(a) state.by_path[path_key(a.path)]=a; state.assets[#state.assets+1]=a; return a end
local enumeration_cache={}
local function enumerate(p,i,field)
  reads[p]=(reads[p] or 0)+1
  local key=p..":"..field
  if i==-1 or not enumeration_cache[key] then
    enumeration_cache[key]={table.unpack(disk[p] and disk[p][field] or {})}
  end
  if i>=0 then return enumeration_cache[key][i+1] end
end
reaper={time_precise=function() return clock end, GetPlayState=function() return 0 end,
  EnumerateFiles=function(p,i) return enumerate(p,i,"files") end,
  EnumerateSubdirectories=function(p,i) return enumerate(p,i,"children") end,
  JS_File_Stat=function(p)
    stats=stats+1; local d=disk[p]; if not d then return -1 end
    return 0,0,"",d.stamp,"2020.01.01 00:00:00",1,0,0,0x4000
  end}
HostApi=reaper
SCAN_FINALIZE_ASSETS_PER_FRAME=32
SCAN_BUDGET=0.01
SCAN_CHECKPOINT_INTERVAL=60
Jobs={active={},history={},generation=0,accepting=true}
assert(load(region(read("src/lua/20_jobs_storage.lua"),"function Jobs.begin(","function Jobs.active_kind(")))()
assert(loadfile("src/lua/12_state_store.lua"))(); AppState=new_state_store(state)
assert(load(region(read("src/lua/37_catalog_caches.lua"),"function new_catalog_prune_job(","function new_artwork_reset_job(")))()
assert(load(region(source,"WatchFolders = { unchanged = 0 }","function cleanup()")))()
assert(load(region(source,"function start_scan(reason, roots_override, options)","----------------------------------------------------------------\n-- Search")))()
for i=1,1000 do disk["c:/audio"].files[i]=i..".wav" end
for p,d in pairs(disk) do for _,name in ipairs(d.files) do add_or_update_asset({path=join_path(p,name),root="c:/audio",ready=name~="unfinished.wav"}) end end
local unfinished=state.by_path["c:/audio/nested/unfinished.wav"]
state.favorites[unfinished.path]=true
local function pump()
  for _=1,2000 do
    if not state.scan then return end
    clock=clock+0.11; process_scan()
  end
  error("scan did not terminate")
end
local function scan(reason)
  reads={}; start_scan(reason or "Watch Folder",nil,{silent=true}); local job=assert(state.scan); pump(); return job
end
local function finish_import()
  local session=assert(state.import_session)
  for _,a in ipairs(session.assets) do a.ready=true; a.pending_batch=nil end
  Jobs.finish(session.job_token,true); state.import_session=nil
end
local first=scan()
assert(first.files==1003 and first.added==0 and not state.import_session and made==0)
assert(state.by_path[unfinished.path]==unfinished and not unfinished.ready,
  "automatic discovery must not re-analyze old unfinished entries")
local second=scan()
assert(next(reads)==nil and second.skipped_directories==3 and stats>0,
  "unchanged directories must avoid file and subdirectory enumeration")
disk["c:/audio/nested"].files[3]="new.wav"
disk["c:/audio/nested"].stamp="2020.01.01 00:01:00"
local changed=scan()
assert(not reads["c:/audio"] and not reads["c:/audio/quiet"] and reads["c:/audio/nested"])
assert(changed.added==1 and #state.import_session.assets==1 and state.import_session.assets[1].path:match("/new.wav$"))
finish_import()
disk["c:/audio/nested"].children={"new folder"}
disk["c:/audio/nested"].stamp="2020.01.01 00:02:00"
disk["c:/audio/nested/new folder"]={files={"child.wav"},children={},stamp="2020.01.01 00:00:00"}
assert(scan().added==1); finish_import()
-- Deliberately unchanged timestamps are eventually reconciled by the fallback.
disk["c:/audio/quiet"].files[2]="preserved-time.wav"
assert(scan().added==0); clock=clock+1801
assert(scan().added==1); finish_import()
-- Second-resolution directory times cannot be trusted in the current second.
disk["c:/audio/quiet"].stamp=os.date("%Y.%m.%d %H:%M:%S")
assert(scan().added==0)
disk["c:/audio/quiet"].files[3]="same-second.wav"
assert(scan().added==1); finish_import()
-- Missing stat support remains correct through incremental filename checking.
local stat=reaper.JS_File_Stat; reaper.JS_File_Stat=nil
disk["c:/audio/quiet"].files[4]="fallback.wav"
assert(scan().added==1 and reads["c:/audio"]); finish_import(); reaper.JS_File_Stat=stat
-- Cancel without additions: no enumeration, no full-catalog prune, no restart.
local prune=new_catalog_prune_job
new_catalog_prune_job=function() error("empty cancellation walked the catalog") end
start_scan("Watch Folder",nil,{silent=true}); reads={}; local token=state.scan.job_token
state.preview={}; state.interaction_until=clock+100
begin_scan_cancel(state.scan); begin_scan_cancel(state.scan); process_scan()
assert(not state.scan and not Jobs.active.catalog_pipeline and token.state=="canceled" and next(reads)==nil)
watch_folders(); assert(not state.scan and state.next_watch>clock)
new_catalog_prune_job=prune; state.preview=nil; state.interaction_until=0
-- Manual scan sees old unfinished entries too; cancellation may remove only
-- placeholders created by this scan, preserving existing assets/favorites.
disk["c:/audio/nested"].files[4]="cancel-new.wav"
disk["c:/audio/nested"].stamp="2020.01.01 00:03:00"
start_scan("manual",nil,{silent=true}); local pending=state.scan
while state.scan and not state.by_path["c:/audio/nested/cancel-new.wav"] do clock=clock+0.11; process_scan() end
assert(state.scan==pending)
begin_scan_cancel(pending); state.preview={}; state.interaction_until=clock+100; pump()
assert(not state.by_path["c:/audio/nested/cancel-new.wav"])
assert(state.by_path[unfinished.path]==unfinished and state.favorites[unfinished.path] and not unfinished.pending_batch)
assert(not Jobs.active.catalog_pipeline)
state.preview=nil; state.interaction_until=0
assert(scan().added==1, "cancelled new entries must be discoverable again despite the directory cache")
-- The following metadata phase must forget removed placeholders too, or its
-- directory cache would hide those files until the periodic full check.
IMPORT_FINALIZE_ASSETS_PER_FRAME=32
function save_database_changes() end
assert(load(region(source,"function cancel_import_session()","function process_import_finalize(")))()
clock=clock+100
for _=1,2000 do if not state.import_session then break end; cancel_import_session() end
assert(not state.import_session and not state.by_path["c:/audio/nested/cancel-new.wav"])
assert(state.next_watch>clock and not Jobs.active.catalog_pipeline)
assert(scan().added==1); finish_import()
-- Cancelling after explicit pruning began must rebuild the asset array from
-- the surviving map even when there are no new placeholders to remove.
local removed=state.by_path["c:/audio/1.wav"]; state.by_path[removed.path]=nil
state.scan={new_assets={},created_keys={},finalize_removed_so_far=1,
  job_token=assert(Jobs.begin("catalog_pipeline","catalog_exclusive",false))}
begin_scan_cancel(state.scan); pump()
for _,a in ipairs(state.assets) do assert(a~=removed) end
assert(not Jobs.active.catalog_pipeline)
print("Watch discovery passed: cached descendants, changed/new folders, fallback/recent timestamps, new-only imports, paused cancellation and existing-asset preservation")
