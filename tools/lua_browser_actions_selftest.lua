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
assert(load(region("function browse_asset_location(asset, folder)","function draw_metadata_inspector()")))()
local asset={path="C:/audio/sub/effect.wav",folder="C:/audio/sub",library_id="lib"}
busy=true assert(not browse_asset_location(asset,false) and state.search=="impact") busy=false
assert(browse_asset_location(asset,false))
assert(state.search=="" and state.view=="all" and state.library_filter_id=="lib")
assert(not state.root_filter and not state.active_collection_id and not state.status_filter and not state.ucs_filter_category)
assert(not state.results_job and state.results_dirty and state.sort_mode=="name" and not state.sort_desc)
assert(state.selected_path==asset.path and state.selected_set[path_key(asset.path)] and state.selected_index==0)
assert(state.workspace_tab_scroll_restore.y==0 and stopped==1 and tracked==1)
assert(browse_asset_location(asset,true) and state.root_filter==asset.folder)
-- Menu draws in its root context, including when the scrolling child is hovered.
local opened,ended=0,0
ImGui={HoveredFlags_ChildWindows=1,IsWindowHovered=function(_,flags) return flags==1 end,
  IsMouseClicked=function(_,button) return button==1 end,IsAnyItemActive=function() return false end,
  OpenPopup=function(_,id) assert(id=="素材来源##inspector_navigation") opened=opened+1 end,
  BeginPopup=function() return true end,MenuItem=function(_,label) return label=="浏览此素材所在音效库的全部声音" end,
  Separator=function() end,EndPopup=function() ended=ended+1 end}
open_inspector_navigation_menu() draw_inspector_navigation_menu(asset)
assert(opened==1 and ended==1 and not state.root_filter)
ImGui.IsAnyItemActive=function() return true end open_inspector_navigation_menu() assert(opened==1)
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
