local function read(path)
  local f=assert(io.open(path,"rb")) local s=f:read("*a") f:close() return s
end
local function region(source,first,last)
  local a=assert(source:find(first,1,true),first)
  local b=assert(source:find(last,a+#first,true),last)
  return source:sub(a,b-1)
end
function trim(s) return tostring(s or ""):match("^%s*(.-)%s*$") end
function compact(s,n) return #s>n and s:sub(1,n).."…" or s end
function path_key(s) return tostring(s or ""):lower() end
function basename(s) return s:match("([^/]+)$") or s end
function translate_ui_text(s) return s end
function set_status(s,error) last_status=s end
function ui_px(n) return n end
function tooltip() end
state={search="metal",view="all",sort_mode="name",sort_desc=false,results={},selected_set={},
  assets={},by_path={},library_by_id={lib={name="Library"}},collection_by_id={bin={name="Bin"}},
  similarity_lookup={},ai_semantic_lookup={}}
assert(loadfile("src/lua/12_state_store.lua"))()
assert(loadfile("src/lua/13_workspace_tabs.lua"))()
local neural=read("src/lua/43_neural_similarity.lua")
assert(load(neural:sub(1,assert(neural:find("function neural_similarity_paths()",1,true))-1)))()
local core=read("src/lua/10_ui_core.lua")
assert(load(region(core,"function utf8_length(","function fit_text_to_width(")))()
assert(load(region(core,"function escape_tsv(","function split_words(")))()
local stops=0
function stop_preview() stops=stops+1 end
function root_for_path(p) if p=="C:/Library" then return p,{} end end
workspace_tabs_ensure()
assert(#state.workspace_tabs==1 and state.workspace_tab_active==1)
local asset={path="a.wav",ready=true,name="Metal"}
state.assets={asset} state.by_path={['a.wav']=asset}
state.results={asset} state.results_dirty=false
state.selected_path=asset.path state.selected_index=1 state.selected_set={['a.wav']=true}
state.selection_anchor=1 state.results_scroll_x=123 state.results_scroll_y=432
state.region_start=0.2 state.region_end=0.7 state.wave_view_start=0.1 state.wave_view_end=0.8
state.library_filter_id="lib" state.active_collection_id="bin" state.root_filter="C:/Library"
state.status_filter="candidate" state.ucs_filter_category="Metal"
workspace_tabs_track()
local first=state.workspace_tab_active
local results=state.results
local second=workspace_tab_new()
assert(second and second~=first and stops==1)
assert(state.search=="" and state.view=="all" and state.library_filter_id==nil and state.root_filter==nil)
assert(state.active_collection_id==nil and state.status_filter==nil and state.selected_path==nil)
assert(state.ai_semantic_paging==nil and #state.results==0 and state.results_dirty)
state.search="steps" state.results={} state.results_dirty=false
assert(workspace_tab_activate(first))
assert(state.search=="metal" and state.results==results and not state.results_dirty)
assert(state.selected_set['a.wav'] and state.selected_path=='a.wav' and state.workspace_tab_scroll_restore.y==432)
assert(state.workspace_tab_scroll_restore.x==123 and state.region_start==0.2 and state.wave_view_end==0.8)
assert(state.library_filter_id=="lib" and state.root_filter=="C:/Library" and state.ucs_filter_category=="Metal")

local duplicate=workspace_tab_new(first)
assert(state.results==results and state.selected_set~=workspace_tab_by_id(first).runtime.selected_set)
state.selected_set['a.wav']=nil
assert(workspace_tab_activate(first) and state.selected_set['a.wav'])
assert(workspace_tab_activate(duplicate) and not state.selected_set['a.wav'])

-- Incomplete result jobs are never resumed with another tab's predicates.
state.results_job={stage="filter"} state.results_dirty=false
assert(workspace_tab_activate(first))
assert(workspace_tab_activate(duplicate) and state.results_job==nil and state.results_dirty and #state.results==0)
state.results={asset} state.results_dirty=false

-- Shared catalog edits invalidate cached rows, not AI paging or selections.
state.view="ai_semantic" state.search="metal scene" state.sort_mode="ai_order"
local pool={{asset=asset,score=10},{asset=asset,score=9}}
state.ai_semantic_lookup={['a.wav']={page=1,page_rank=1}}
state.ai_semantic_paging={candidate_pool=pool,next_offset=2,page_index=1,query=state.search}
state.ai_semantic_has_more=true state.ai_semantic_result_count=1
workspace_tabs_track() state.results_dirty=false
assert(workspace_tab_activate(second))
state.results={} state.results_dirty=false
assert(workspace_tab_activate(duplicate) and state.ai_semantic_paging.candidate_pool==pool)
assert(state.ai_semantic_has_more and state.ai_semantic_lookup['a.wav'])
local copied=workspace_tab_new(duplicate)
state.ai_semantic_paging={candidate_pool=pool,next_offset=3,page_index=2}
state.ai_semantic_lookup={['a.wav']={page=2,page_rank=1}}
assert(workspace_tab_activate(duplicate) and state.ai_semantic_paging.next_offset==2)
assert(state.ai_semantic_lookup['a.wav'].page==1)
workspace_tabs_invalidate()
assert(workspace_tab_activate(copied) and state.results_dirty and #state.results==0)
assert(state.ai_semantic_paging.next_offset==3)

-- Missing libraries/collections/selected files never leak stale UI state.
state.library_filter_id="lib" state.active_collection_id="bin" state.root_filter="C:/Library"
state.selected_path="gone.wav" state.selected_set={['gone.wav']=true}
state.results={asset} state.results_dirty=false
workspace_tabs_track()
assert(workspace_tab_activate(first))
state.library_by_id.lib=nil state.collection_by_id.bin=nil
assert(workspace_tab_activate(copied) and state.library_filter_id==nil and state.active_collection_id==nil)
assert(state.selected_path==nil and next(state.selected_set)==nil and state.results_dirty)
state.library_by_id.lib={name="Library"} state.collection_by_id.bin={name="Bin"}

-- Requests cannot complete in a different page. Closing inactive tabs is safe.
state.ai_semantic_session={phase="plan_wait"}
assert(not workspace_tab_activate(first) and not workspace_tab_new() and not workspace_tab_close(copied))
assert(workspace_tab_close(second))
state.ai_semantic_session=nil
state.similarity_session={}
assert(not workspace_tab_activate(first)) state.similarity_session=nil
assert(workspace_tab_move(copied,-1))
assert(workspace_tab_close(copied,"others") and #state.workspace_tabs==1 and state.workspace_tab_active==copied)
assert(workspace_tab_close(copied) and #state.workspace_tabs==1 and state.workspace_tab_active~=copied)
assert(state.view=="all" and state.search=="" and state.ai_semantic_paging==nil)

-- Reuse display slots without reusing widget IDs or renumbering open tabs.
local numbered_first=state.workspace_tab_active
assert(workspace_tab_title(workspace_tab_by_id(numbered_first))=="标签页 1")
local numbered_second=workspace_tab_new()
assert(workspace_tab_title(workspace_tab_by_id(numbered_second))=="标签页 2")
local numbered_third=workspace_tab_new()
assert(workspace_tab_title(workspace_tab_by_id(numbered_third))=="标签页 3")
assert(workspace_tab_close(numbered_second))
local reused=workspace_tab_new()
assert(reused>numbered_third and workspace_tab_title(workspace_tab_by_id(reused))=="标签页 2")
assert(workspace_tab_title(workspace_tab_by_id(numbered_third))=="标签页 3")
for _=1,20 do
  assert(workspace_tab_close(reused))
  local old_id=reused reused=workspace_tab_new()
  assert(reused>old_id and workspace_tab_title(workspace_tab_by_id(reused))=="标签页 2")
end
assert(workspace_tab_move(reused,-1) and workspace_tab_by_id(reused).number==2)
workspace_tab_by_id(reused).name="Custom"
assert(workspace_tab_title(workspace_tab_by_id(reused))=="Custom")
workspace_tab_by_id(reused).name=nil
assert(workspace_tab_title(workspace_tab_by_id(reused))=="标签页 2")
assert(workspace_tab_close(reused,"others"))
assert(workspace_tab_close(reused) and workspace_tab_by_id(state.workspace_tab_active).number==1)

-- Same-context new pages share completed rows, but no selection or filters.
local unfiltered_rows={asset}
state.results=unfiltered_rows state.results_dirty=false state.results_job=nil
state.selected_set={['a.wav']=true} state.selected_path='a.wav' state.selected_index=1
local cached_first=state.workspace_tab_active
local fresh=workspace_tab_new()
assert(state.results==unfiltered_rows and not state.results_dirty)
assert(state.selected_path==nil and state.selected_index==0 and next(state.selected_set)==nil)
assert(state.region_start==0 and state.region_end==1 and state.results_scroll_y==0)
assert(workspace_tab_activate(cached_first) and state.selected_path=='a.wav')
workspace_tabs_invalidate()
local stale_fresh=workspace_tab_new()
assert(state.results~=unfiltered_rows and #state.results==0 and state.results_dirty)
assert(workspace_tab_close(stale_fresh,"others"))

-- Bound result-reference memory; no large array copies on switching.
local original_limit, original_rows=WorkspaceTabs.cache_tabs,WorkspaceTabs.cache_rows
WorkspaceTabs.cache_tabs=2 WorkspaceTabs.cache_rows=4
state.results={asset,asset} state.results_dirty=false
local a=state.workspace_tab_active
local b=workspace_tab_new(a) state.results_dirty=false
local c=workspace_tab_new(b) state.results_dirty=false
local cached=0
for _,tab in ipairs(state.workspace_tabs) do if tab.runtime and tab.runtime.results then cached=cached+1 end end
assert(cached<=2)
WorkspaceTabs.cache_tabs,WorkspaceTabs.cache_rows=original_limit,original_rows

-- Persist only small context descriptors; no result rows, filenames or keys.
state.search="hello\tworld\n100%" state.view="ai_semantic" state.sort_mode="ai_order"
workspace_tab_by_id(c).name="My ### tab"
state.ai_api_key_input="DO NOT SAVE ME"
local lines={}
workspace_tabs_write_settings({write=function(_,...) local pieces={...} for i,v in ipairs(pieces) do pieces[i]=tostring(v) end lines[#lines+1]=table.concat(pieces) end})
local serialized=table.concat(lines)
assert(not serialized:find('DO NOT SAVE ME',1,true) and not serialized:find('a.wav',1,true))
assert(not serialized:find('candidate_pool',1,true) and not serialized:find('selected_set',1,true))
assert(#serialized<2000,"tab persistence must remain small")
local fields=split_tsv(serialized:gsub("\n$",""))
AppState.set("workspace_tabs",nil)
assert(workspace_tabs_load_setting(fields[2],fields[3]))
workspace_tabs_initialize()
assert(state.search=="hello\tworld\n100%" and state.view=="all" and state.results_dirty)
assert(workspace_tab_by_id(state.workspace_tab_active).name=="My ### tab")
assert(workspace_tab_label(workspace_tab_by_id(state.workspace_tab_active)):match("###workspace_tab_%d+$"))
assert(workspace_tabs_load_setting("workspace_tabs_json","{broken") and #state.workspace_tabs==3)
assert(not workspace_tabs_load_setting("unrelated",""))
workspace_tab_by_id(state.workspace_tab_active).name=string.rep("音效标签",30)
local unicode_label=workspace_tab_label(workspace_tab_by_id(state.workspace_tab_active))
assert(utf8.len(unicode_label) and unicode_label:match("###workspace_tab_%d+$"))
local before=#state.workspace_tabs
workspace_tabs_load_setting("workspace_tabs_json",neural_json_encode({schema=1,active=1,tabs={
  {id=1,context={view="bad",sort_mode="bad",sort_desc="true",root_filter="",search={}}},
  {id=1,context={}}, {id=-1,context={}}, {id=1.5,context={}}, {id=2,context="bad"}}}))
assert(#state.workspace_tabs==1 and state.workspace_tabs[1].context.view=="all")
assert(state.workspace_tabs[1].context.sort_mode=="name" and state.workspace_tabs[1].context.sort_desc==false)
assert(state.workspace_tabs[1].context.root_filter==nil)
-- Legacy descriptors migrate display IDs; malformed or duplicate numbers are
-- repaired while valid numbers, custom names and stable IDs are preserved.
workspace_tabs_load_setting("workspace_tabs_json",neural_json_encode({schema=1,active=87,tabs={
  {id=87,context={}}, {id=203,name="Named",context={}}, {id=900,context={}}}}))
assert(state.workspace_tabs[1].id==87 and state.workspace_tabs[1].number==1)
assert(state.workspace_tabs[2].name=="Named" and state.workspace_tabs[2].number==2)
workspace_tabs_load_setting("workspace_tabs_json",neural_json_encode({schema=1,active=87,tabs={
  {id=87,number=3,context={}}, {id=203,number=3,context={}},
  {id=900,number="bad",context={}}, {id=901,number=1.5,context={}}}}))
assert(state.workspace_tabs[1].number==3 and state.workspace_tabs[2].number==1)
assert(state.workspace_tabs[3].number==2 and state.workspace_tabs[4].number==4)
workspace_tabs_load_setting(fields[2],fields[3]) workspace_tabs_initialize()
assert(workspace_tab_by_id(state.workspace_tab_active).number==neural_json_decode(fields[3]).tabs[3].number)

-- 100k references switch without cloning asset arrays or rebuilding results.
local large={}
local selection={}
for i=1,100000 do large[i]=asset selection[tostring(i)]=true end
state.results=large state.results_dirty=false state.view="all" state.search=""
state.selected_set=selection
local original_tab=state.workspace_tab_active
local large_duplicate=workspace_tab_new(original_tab)
local started=os.clock()
for i=1,100 do
  assert(workspace_tab_activate(original_tab) and state.results==large and not state.results_dirty and state.selected_set==selection)
  assert(workspace_tab_activate(large_duplicate) and state.results==large and not state.results_dirty)
end
print(string.format("Workspace tabs: 100k shared rows, 200 switches in %.3fs CPU",os.clock()-started))
assert(workspace_tab_close(large_duplicate))
workspace_tabs_invalidate(true)
assert(workspace_tab_activate(original_tab)==false)
local rt=workspace_tab_capture() assert(rt.runtime.results==large,"history should not invalidate ordinary views")

-- Close-right and close-others keep the requested page and at least one tab.
local right1=workspace_tab_new() local right2=workspace_tab_new()
assert(workspace_tab_close(right1,"right") and not workspace_tab_by_id(right2))
assert(workspace_tab_close(original_tab,"others") and #state.workspace_tabs==1)
workspace_tab_new() workspace_tab_new()
local limit_before=WorkspaceTabs.limit WorkspaceTabs.limit=#state.workspace_tabs
assert(not workspace_tab_new()) WorkspaceTabs.limit=limit_before

-- Run the actual UI bar with balanced stack mocks, including blocked switch,
-- modal rename, native close and a clipped/not-visible bar.
ImGui={TabBarFlags_FittingPolicyScroll=1,TabBarFlags_TabListPopupButton=2,
  TabItemFlags_Trailing=4,TabItemFlags_NoReorder=8,TabItemFlags_NoAssumedClosure=16,TabItemFlags_SetSelected=32,
  WindowFlags_AlwaysAutoResize=64,Key_N=10,Key_W=11,Key_Tab=12,Key_Enter=13}
local bar_balance,item_balance,popup_balance=0,0,0
local visible=true local click_id,close_id,menu_action,plus,modal=nil,nil,nil,false,false
local deferred_selection, queued_selection = false, nil
local ui_selected=state.workspace_tab_active
ImGui.BeginTabBar=function()
  if not visible then return false end
  if queued_selection then ui_selected=queued_selection queued_selection=nil end
  bar_balance=bar_balance+1 return true
end
ImGui.EndTabBar=function() bar_balance=bar_balance-1 end
ImGui.TabItemButton=function() return plus end
ImGui.BeginTabItem=function(_,label,open,flags)
  local id=tonumber(label:match("workspace_tab_(%d+)$"))
  if (flags & 32)~=0 then
    if deferred_selection then queued_selection=id else ui_selected=id end
  elseif click_id==id then ui_selected=id end
  local selected=ui_selected==id if selected then item_balance=item_balance+1 end
  return selected,close_id~=id
end
ImGui.EndTabItem=function() item_balance=item_balance-1 end
ImGui.IsItemHovered=function() return false end
ImGui.BeginPopupContextItem=function(_,label)
  if menu_action and label:match("_"..state.workspace_tab_active.."$") then popup_balance=popup_balance+1 return true end
  return false
end
ImGui.MenuItem=function(_,label) return label==menu_action end
ImGui.Separator=function() end
ImGui.EndPopup=function() popup_balance=popup_balance-1 end
ImGui.OpenPopup=function() modal=true end
ImGui.BeginPopupModal=function() if modal then popup_balance=popup_balance+1 return true end return false end
ImGui.SetKeyboardFocusHere=function() end
ImGui.SetNextItemWidth=function() end
ImGui.InputText=function() return true,"Renamed" end
ImGui.IsItemActive=function() return false end
ImGui.IsKeyPressed=function() return false end
ImGui.CloseCurrentPopup=function() modal=false end
ImGui.SameLine=function() end
ImGui.TextDisabled=function() end
local button
function dark_button(label) return label==button end
draw_workspace_tabs()
assert(bar_balance==0 and item_balance==0 and popup_balance==0)
state.workspace_tab_select=nil
local other=state.workspace_tabs[1].id click_id=other
state.ai_semantic_session={}
draw_workspace_tabs() assert(state.workspace_tab_active~=other and state.workspace_tab_select==state.workspace_tab_active)
state.ai_semantic_session=nil click_id=nil
draw_workspace_tabs() assert(ui_selected==state.workspace_tab_active)
click_id=other draw_workspace_tabs() assert(state.workspace_tab_active==other) click_id=nil
menu_action="重命名标签页" draw_workspace_tabs() menu_action=nil
button="保存##workspace_tab_name_save" draw_workspace_tabs() button=nil
assert(workspace_tab_by_id(other).name=="Renamed" and not modal)
plus=true draw_workspace_tabs() plus=false
assert(state.workspace_tab_active~=other)
draw_workspace_tabs() close_id=state.workspace_tab_active draw_workspace_tabs() close_id=nil
assert(bar_balance==0 and item_balance==0 and popup_balance==0)
-- Model real Dear ImGui's one-frame SetSelected delay (not the instantaneous
-- mock used previously). New/close/keyboard selection must never bounce back.
deferred_selection=true
local prior_tab=state.workspace_tab_active
plus=true draw_workspace_tabs() plus=false
local delayed_new=state.workspace_tab_active
assert(delayed_new~=prior_tab and state.workspace_tab_select==delayed_new)
draw_workspace_tabs()
assert(state.workspace_tab_active==delayed_new and state.workspace_tab_select==delayed_new,
  "old visible tab must not cancel the queued new-tab request")
draw_workspace_tabs()
assert(ui_selected==delayed_new and state.workspace_tab_active==delayed_new and not state.workspace_tab_select)
close_id=delayed_new draw_workspace_tabs() close_id=nil
local after_close=state.workspace_tab_active
draw_workspace_tabs() draw_workspace_tabs()
assert(ui_selected==after_close and state.workspace_tab_active==after_close and not state.workspace_tab_select)
for _=1,10 do
  plus=true draw_workspace_tabs() plus=false
  local requested=state.workspace_tab_active
  visible=false draw_workspace_tabs() visible=true
  assert(state.workspace_tab_select==requested,"clipping must preserve selection requests")
  draw_workspace_tabs() draw_workspace_tabs()
  assert(state.workspace_tab_active==requested and ui_selected==requested)
  close_id=requested draw_workspace_tabs() close_id=nil
  draw_workspace_tabs() draw_workspace_tabs()
  assert(ui_selected==state.workspace_tab_active)
end
deferred_selection=false
visible=false draw_workspace_tabs() assert(bar_balance==0 and item_balance==0)

-- Run the real clipped results widget. ReaImGui ends a false BeginChild;
-- it must not receive another EndChild or scroll calls on the parent.
local runtime=read("src/lua/50_runtime_ui.lua")
assert(runtime:find('draw_workspace_tabs()',1,true) and runtime:find('workspace_tabs_initialize()',1,true))
assert(load(region(runtime,"function draw_results()","function draw_large_wave(")))()
local child_balance=0
ImGui.GetContentRegionAvail=function() return 400,300 end
function column_layout() return {width=1000} end
HEADER_H=24 ROW_H=30
ImGui.GetCursorScreenPos=function() return 0,0 end
ImGui.GetWindowDrawList=function() return {} end
ImGui.GetCursorPosY=function() return 0 end
ImGui.SetCursorPosY=function() end
ImGui.BeginChild=function(_,id) assert(id:find("tab_",1,true)) return false end
ImGui.EndChild=function() child_balance=child_balance-1 end
ImGui.BeginDragDropTarget=function() return false end
function draw_table_header() end
function draw_column_headers() end
function draw_list_header() end
ImGui.Dummy=function() end
state.results_scroll_request=10
draw_results()
assert(child_balance==0 and state.results_scroll_request==10)
local scrolls=0
ImGui.SetScrollX=function(_,n) assert(n>=0) scrolls=scrolls+1 end
ImGui.SetScrollY=function(_,n) assert(n>=0) scrolls=scrolls+1 end
-- Every empty view uses the same pending state, rather than claiming an empty
-- library/collection/AI batch while a result job is still working.
assert(load(region(runtime,"function results_pending()","function rebuild_results()")))()
ImGui.BeginChild=function() child_balance=child_balance+1 return true end
ImGui.GetScrollX=function() return 0 end ImGui.GetScrollMaxX=function() return 0 end
ImGui.GetScrollY=function() return 0 end ImGui.GetMousePos=function() return -1,-1 end
ImGui.GetMouseWheel=function() return 0 end ImGui.GetKeyMods=function() return 0 end
ImGui.Spacing=function() end
local messages={}
ImGui.TextDisabled=function(_,text) messages[#messages+1]=text end
function draw_column_splitters() end
function clamp(n,lo,hi) return math.max(lo,math.min(n,hi)) end
state.results={} state.results_scroll_request=nil state.workspace_tab_scroll_restore=nil
for _,view in ipairs({"all","similar","ai_semantic"}) do
  state.view=view state.results_dirty=true state.results_job=nil messages={}
  draw_results()
  assert(#messages==1 and messages[1]=="正在更新结果…" and child_balance==0)
  state.results_dirty=false state.results_job={stage="filter"} messages={}
  draw_results()
  assert(#messages==1 and messages[1]=="正在更新结果…" and child_balance==0)
end
state.view="all" state.results_job=nil state.results_dirty=false messages={}
draw_results()
assert(#messages==1 and messages[1]:find("没有结果",1,true))
state.results_dirty=true state.workspace_tab_scroll_restore={x=123,y=456,frames=2}
workspace_tabs_apply_scroll() assert(scrolls==0)
state.results_dirty=false workspace_tabs_apply_scroll() assert(scrolls==2 and state.workspace_tab_scroll_restore)
workspace_tabs_apply_scroll() assert(scrolls==4 and state.workspace_tab_scroll_restore==nil)
local pressed
ImGui.IsKeyPressed=function(_,key) return key==pressed end
pressed=ImGui.Key_Tab local old=state.workspace_tab_active
assert(workspace_tabs_keyboard(true,false) and state.workspace_tab_active~=old)
assert(workspace_tabs_keyboard(true,true) and state.workspace_tab_active==old)
pressed=ImGui.Key_N assert(workspace_tabs_keyboard(true,false))
pressed=ImGui.Key_W assert(workspace_tabs_keyboard(true,false))
deferred_selection=true visible=true
draw_workspace_tabs() draw_workspace_tabs()
pressed=ImGui.Key_Tab assert(workspace_tabs_keyboard(true,false))
local keyboard_target=state.workspace_tab_active
draw_workspace_tabs() draw_workspace_tabs()
assert(ui_selected==keyboard_target and state.workspace_tab_active==keyboard_target)
pressed=ImGui.Key_N assert(workspace_tabs_keyboard(true,true))
local keyboard_copy=state.workspace_tab_active
draw_workspace_tabs() draw_workspace_tabs()
assert(ui_selected==keyboard_copy and state.workspace_tab_active==keyboard_copy)
pressed=ImGui.Key_W assert(workspace_tabs_keyboard(true,false))
local keyboard_closed=state.workspace_tab_active
draw_workspace_tabs() draw_workspace_tabs()
assert(ui_selected==keyboard_closed and state.workspace_tab_active==keyboard_closed)
pressed=nil assert(not workspace_tabs_keyboard(true,false) and not workspace_tabs_keyboard(false,false))

print("Lua workspace tabs self-test passed: isolated context, bounded shared results, paging, persistence and UI stacks")
