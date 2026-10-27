local file=assert(io.open("src/lua/50_runtime_ui.lua","rb")) local source=file:read("*a") file:close()
local function region(first,last)
  local start=assert(source:find(first,1,true)) local finish=assert(source:find(last,start+#first,true))
  return source:sub(start,finish-1)
end
state={watch_interval=60,watch_enabled=true,search="impact",view="ucs_category",active_collection_id="bin",
  root_filter="C:/other",library_filter_id="other",status_filter="candidate",ucs_filter_category="GAMES",
  ucs_filter_catid="GAMEArc",sort_mode="duration",sort_desc=true,library_by_id={lib={id="lib",name="Library"}},
  results_scroll_x=10,results_job={}}
assert(loadfile("src/lua/12_state_store.lua"))()
reaper={time_precise=function() return 100 end}
local stopped,tracked=0,0
local busy=false
function workspace_tabs_busy() return busy end
function stop_preview() stopped=stopped+1 end
function workspace_tabs_track() tracked=tracked+1 end
function path_key(value) return value:lower() end
function dirname(path) return path:match("^(.*)/[^/]+$") end
function root_for_path() return "C:/audio",{library_id="lib"} end
function set_status(message) last_status=message end
function clamp(n,lo,hi) return math.max(lo,math.min(n,hi)) end
function translate_ui_text(value) return value end
assert(load(region("function set_watch_folder_enabled(enabled)","function watch_folders()")))()
state.import_session={done=5}
set_watch_folder_enabled(false)
assert(not state.watch_enabled and state.config_dirty and state.next_watch==160 and state.import_session.done==5)
set_watch_folder_enabled(true) assert(state.watch_enabled and state.next_watch==160)
state.import_session=nil
assert(load(region("function browse_asset_library(asset)","function draw_metadata_inspector()")))()
local asset={path="C:/audio/sub/effect.wav",folder="C:/audio/sub",library_id="lib"}
busy=true assert(not browse_asset_library(asset) and state.search=="impact") busy=false
assert(browse_asset_library(asset))
assert(state.search=="" and state.view=="all" and state.library_filter_id=="lib")
assert(not state.root_filter and not state.active_collection_id and not state.status_filter and not state.ucs_filter_category)
assert(not state.results_job and state.results_dirty and state.sort_mode=="name" and not state.sort_desc)
assert(state.selected_path==asset.path and state.selected_set[path_key(asset.path)] and state.selected_index==0)
assert(state.workspace_tab_scroll_restore.y==0 and stopped==1 and tracked==1)
-- A right click navigates directly from the parent or its scrolling child,
-- without popup APIs or a focused metadata field blocking the action.
local hovered, clicked = true, true
ImGui={HoveredFlags_ChildWindows=1,IsWindowHovered=function(_,flags) return hovered and flags==1 end,
  IsMouseClicked=function(_,button) return clicked and button==1 end,
  IsAnyItemActive=function() return true end,
  OpenPopup=function() error("Inspector navigation must not open a popup") end,
  BeginPopup=function() error("Inspector navigation must not draw a popup") end}
state.search="category:arcade" state.root_filter="C:/other" state.view="ucs_category"
local draft={values={description="unsaved edit"}} state.metadata_editor=draft
assert(handle_inspector_library_navigation(asset))
assert(state.search=="" and state.view=="all" and not state.root_filter and state.library_filter_id=="lib")
assert(state.metadata_editor==draft and draft.values.description=="unsaved edit" and tracked==2)
hovered=false assert(not handle_inspector_library_navigation(asset) and tracked==2)
hovered=true clicked=false assert(not handle_inspector_library_navigation(asset) and tracked==2)
clicked=true assert(not handle_inspector_library_navigation(nil) and tracked==2)
busy=true assert(not handle_inspector_library_navigation(asset) and tracked==2) busy=false
assert(not source:find("inspector_navigation",1,true))
assert(load(region("function neural_progress_display(session)","function draw_import_progress()")))()
local label,fraction=neural_progress_display({phase="neural_wait",total=76530,neural_asset_count=76530,
  neural_job={operation="build-cache"},neural_progress={phase="embedding",completed=0,total=76530,
    windowCompleted=5,windowTotal=34}})
assert(label:find("正在分析音频窗口",1,true) and label:find("5 / 34",1,true) and fraction>0)
label,fraction=neural_progress_display({phase="neural_wait",neural_job={operation="build-index"},
  neural_progress={phase="building-index",completed=30,total=100}})
assert(label:find("神经近邻索引",1,true) and fraction==0.3)
label,fraction=neural_progress_display({phase="neural_prepare",total=100,neural_prepare_index=31})
assert(label:find("准备神经",1,true) and fraction==0.3)
label,fraction=neural_progress_display({phase="neural_rerank",neural_match_index=3,neural_matches={1,2,3,4}})
assert(fraction==0.5 and label:find("重排神经",1,true))
assert(source:find('icon_button("watch_folder", "clock"',1,true))
print("Lua browser actions self-test passed: Watch toggle, inspector scopes, cleared filters, neural stages and window progress")
