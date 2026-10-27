local function read(path)
  local file=assert(io.open(path,"rb")) local value=file:read("*a") file:close() return value
end
local function region(source, first, following)
  local start=assert(source:find(first,1,true),first)
  local finish=assert(source:find(following,start+#first,true),following)
  return source:sub(start,finish-1)
end
local clock=0
HostApi={time_precise=function() clock=clock+0.01 return clock end}
function path_key(value) return value:lower() end
function safe_lower(value) return tostring(value or ""):lower() end
function path_is_inside(path,root) return path:sub(1,#root)==root end
function asset_path_sort_key(asset) return path_key(asset.path) end
function stop_preview() end
function set_status() end
function asset_in_view(asset)
  return asset.ready and not asset.pending_batch
    and (not state.library_filter_id or asset.library_id==state.library_filter_id)
end
function matches_search(asset) return state.search=="" or asset.name:find(state.search,1,true)~=nil end
state={assets={},by_path={},search="",view="all",sort_mode="name",sort_desc=false,
  results={},results_dirty=true,selected_set={},library_by_id={a={},b={}},collection_by_id={}}
assert(loadfile("src/lua/12_state_store.lua"))()
assert(loadfile("src/lua/13_workspace_tabs.lua"))()
assert(loadfile("src/lua/35_incremental_results.lua"))()
local runtime=read("src/lua/50_runtime_ui.lua")
assert(load(region(runtime,"local function cached_sort_text(","function rebuild_results()")))()
for i=1,30000 do
  local asset={path="C:/a/"..i..".wav",name=string.format("sound%06d",i),ready=true,library_id="a"}
  state.assets[i]=asset state.by_path[path_key(asset.path)]=asset
end
workspace_tabs_ensure()
local first=state.workspace_tab_active
local function finish()
  local steps=0
  repeat process_results_rebuild() steps=steps+1 assert(steps<1000) until not state.results_job
end
finish()
local original=state.results
assert(workspace_tab_by_id(first).runtime.results==original,"completion must capture immediately")
local second=workspace_tab_new()
assert(state.results==original and not state.results_dirty)
state.library_filter_id="b" state.results_dirty=true finish()
local empty=state.results
assert(#empty==0 and workspace_tab_by_id(second).runtime_valid)
assert(workspace_tab_activate(first) and state.results==original and not state.results_dirty)
local revision=state.workspace_tabs_revision
for _=1,1000 do workspace_tabs_invalidate("display",state.assets[1]) end
assert(not state.results_dirty and not workspace_tab_by_id(first).refresh_pending)
assert(state.workspace_tabs_revision==revision,"display updates must not invalidate revisions")
-- A normal background metadata/ready change preserves rows. Repeated updates
-- neither restart a build nor invalidate a disjoint library's snapshot.
workspace_tabs_invalidate("background",state.assets[1])
assert(not state.results_dirty and workspace_tab_by_id(first).refresh_pending)
assert(not workspace_tab_by_id(second).refresh_pending)
clock=clock+2 workspace_tabs_process_refresh()
assert(state.results_dirty) process_results_rebuild()
local job=state.results_job assert(job)
for _=1,100 do workspace_tabs_invalidate("background",state.assets[2]) end
assert(not state.results_dirty and state.results_job==job,"background events must not restart the active job")
local offset=job.index or 0
process_results_rebuild()
assert(state.results_job==job and (job.index or 0)>=offset)
assert(workspace_tab_activate(second) and state.results==empty and not state.results_dirty)
assert(workspace_tab_activate(first) and state.results==original and not state.results_dirty)
assert(state.results_job==nil,"cross-tab global predicates must never resume")
clock=clock+2 workspace_tabs_process_refresh() finish()
assert(#state.results==30000 and not state.results_dirty)
-- Events arriving during a build are serviced once again after the interval.
workspace_tabs_invalidate("background",state.assets[1])
clock=clock+2 workspace_tabs_process_refresh() process_results_rebuild()
job=state.results_job workspace_tabs_invalidate("background",state.assets[2]) finish()
assert(workspace_tab_by_id(first).refresh_pending)
clock=clock+2 workspace_tabs_process_refresh() finish()
assert(not workspace_tab_by_id(first).refresh_pending)
local fresh=state.results
local cache_rows=WorkspaceTabs.cache_rows
WorkspaceTabs.cache_rows=#fresh
local shared=workspace_tab_new(first)
workspace_tabs_trim_cache()
assert(workspace_tab_by_id(first).runtime.results==fresh and state.results==fresh,
  "shared arrays must count once against the cache row budget")
assert(workspace_tab_close(shared))
WorkspaceTabs.cache_rows=cache_rows
if state.workspace_tab_active~=first then assert(workspace_tab_activate(first)) end
for _=1,100 do
  assert(workspace_tab_activate(second) and state.results==empty and not state.results_dirty)
  assert(workspace_tab_activate(first) and state.results==fresh and not state.results_dirty)
end
-- Independent maintenance lookup replacement dirties only dependent pages.
state.duplicate_lookup={} state.missing_assets={} state.current_project_path="new.rpp"
workspace_tabs_track()
assert(not state.results_dirty and state.results==fresh)
workspace_tabs_invalidate("favorites")
assert(not state.results_dirty and not workspace_tab_by_id(first).refresh_pending)
state.search="FAV:true" workspace_tabs_track() state.results_dirty=false
workspace_tabs_invalidate("favorites") assert(state.results_dirty)
state.search="" workspace_tabs_track() state.results_dirty=false
-- A structural replacement must release old rows, unlike metadata refresh.
workspace_tab_capture() state.assets={} state.by_path={} workspace_tabs_track()
assert(state.results_dirty and not workspace_tab_by_id(first).runtime_valid)
assert(workspace_tab_by_id(first).runtime.results==nil)
assert(workspace_tab_by_id(second).runtime.results==nil)
-- Quiet periodic scans with no changes do not rebuild an unchanged catalog.
local previous_state=state
state={}
AppState=new_state_store(state)
local finished_scans, imports=0,0
Jobs={finish=function() finished_scans=finished_scans+1 end}
reaper={time_precise=function() return clock end}
function clear_scan_checkpoint() end
assert(load(region(runtime,"function complete_scan_finalize(scan)","function process_scan_finalize(scan)")))()
complete_scan_finalize({pending={},removed=0,silent=true,job_token={}})
assert(not state.results_dirty and finished_scans==1)
complete_scan_finalize({pending={},removed=1,silent=true,job_token={}})
assert(state.results_dirty and finished_scans==2)
state.results_dirty=false
complete_scan_finalize({pending={{path="new.wav"}},removed=0,silent=true,reason="Watch Folder",job_token={}})
assert(state.results_dirty and state.import_session.total==1)
-- Watch Folder periodically polls recursively via the existing scan pipeline;
-- tab restoration has no entry point that starts a scan or recovery audit.
state={watch_enabled=true,next_watch=10,watch_interval=60,watch_silent=true}
AppState=new_state_store(state)
local scan_count=0
function start_scan(reason,roots,options)
  assert(reason=="Watch Folder" and roots==nil and options.silent and not options.checkpoint_enabled)
  scan_count=scan_count+1
end
assert(load(region(runtime,"function watch_folders()","function cleanup()")))()
clock=9 watch_folders() assert(scan_count==0)
clock=10 watch_folders() assert(scan_count==1 and state.next_watch==70)
watch_folders() assert(scan_count==1)
state.import_session={} clock=100 watch_folders() assert(scan_count==1)
state.import_session=nil watch_folders() assert(scan_count==2)
state.watch_enabled=false clock=200 watch_folders() assert(scan_count==2)
state=previous_state
AppState=new_state_store(state)
print("Lua workspace refresh self-test passed: completed snapshots, scoped invalidation, bounded refresh, no background restart")
