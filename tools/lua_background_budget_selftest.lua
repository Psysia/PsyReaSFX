local function read(path) local f=assert(io.open(path,"rb")); local s=f:read("*a"); f:close(); return s end
local source=read("src/lua/50_runtime_ui.lua"):gsub("\r\n","\n")
local function region(first,last)
  local a=assert(source:find(first,1,true)); local b=assert(source:find(last,a+#first,true))
  return source:sub(a,b-1)
end
local clock, playstate, enumerated, cancelled=100,0,0,false
state={watch_enabled=true,watch_interval=60,watch_silent=true,next_watch=0,roots={"C:/audio"},
  assets={},by_path={},interaction_until=0}
assert(loadfile("src/lua/12_state_store.lua"))()
AppState=new_state_store(state)
reaper={time_precise=function() return clock end, GetPlayState=function() return playstate end,
  EnumerateFiles=function(_,i) enumerated=enumerated+1; return i<10000 and (i..".wav") or nil end,
  EnumerateSubdirectories=function() return nil end}
function ui_in_motion() return false end
function set_status() end
function directory_exists() return true end
function path_key(s) return s:lower() end
function join_path(a,b) return a.."/"..b end
function is_ignored_media_path() return false end
function is_audio_file() return true end
function cancel_auxiliary_save() end
function clear_scan_checkpoint() end
function bg_mark() end
Jobs={begin=function() return {} end,finish=function() end,cancel=function(t) t.cancel_requested=true end}
assert(load(region("WatchFolders = { unchanged = 0 }","function cleanup()")))()
assert(load(region("function start_scan(reason, roots_override, options)","----------------------------------------------------------------\n-- Search")))()
-- Existing files are never re-imported by an unchanged watch scan.
for i=0,9999 do state.by_path["c:/audio/"..i..".wav"]={ready=true} end
watch_folders(); assert(state.scan and state.scan.watch)
state.preview={}; process_scan(); assert(enumerated==0 and state.scan.paused)
state.preview=nil; playstate=1; process_scan(); assert(enumerated==0)
playstate=4; process_scan(); assert(enumerated==0)
playstate=0; state.interaction_until=110; process_scan(); assert(enumerated==0)
clock=112; process_scan(); assert(enumerated>0 and enumerated<=64)
local before=enumerated
process_scan(); assert(enumerated==before, "watch must yield between slices")
clock=112.2; process_scan(); assert(enumerated>before and #state.scan.new_assets==0)
finish_scan()
assert(state.scan.phase=="finalize_pending" and not state.scan.prune_job,
  "automatic discovery must not prune catalog/favorites on a temporary source failure")
-- Cancellation is serviced even while audio is playing.
function begin_scan_cancel() end
function process_scan_cancel() cancelled=true; state.scan=nil end
Jobs.cancel(state.scan.job_token); state.preview={}; process_scan(); assert(cancelled)
state.preview=nil
clock=1000
complete_scan_finalize({pending={},removed=0,watch=true,silent=true})
assert(state.next_watch==1120, "quiet interval starts after completion, with backoff")
clock=2000
complete_scan_finalize({pending={},removed=0,watch=true,silent=true})
assert(state.next_watch==2240)
reset_watch_schedule(true); assert(state.next_watch==2060)
state.next_watch=0; state.watch_enabled=false; watch_folders(); assert(not state.scan)
-- Cooperative total budget and fairness across ready worker queues.
local visits={0,0,0,0}
BackgroundPump={index=1,workers={}}
for i=1,4 do BackgroundPump.workers[i]={tostring(i),function() visits[i]=visits[i]+1; clock=clock+0.003 end} end
for _=1,10 do
  local started=clock; process_background_slice()
  assert(clock-started<0.0061, "more than one unit over the 4ms deadline")
end
for _,n in ipairs(visits) do assert(n==5, "background queue starved") end
print("Background scheduling passed: audio/interaction pauses, bounded slices, cancellation, completion-based backoff and queue fairness")
