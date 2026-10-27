local core_path = arg[1] or "src/lua/10_ui_core.lua"
local workspace_path = arg[2] or "src/lua/11_ui_workspace.lua"
local runtime_path = arg[3] or "src/lua/50_runtime_ui.lua"
local function read(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end
local function region(source, first, last)
  local a = assert(source:find(first, 1, true), first)
  local b = assert(source:find(last, a + #first, true), last)
  return source:sub(a, b - 1)
end
state = { language = "zh", ui_font_size = 13, ui_density = "compact", sidebar_modules = {},
  sidebar_sections = { folders = true }, sidebar_folder_mode = "tree", sidebar_navigation_mode = "libraries",
  root_records = {}, assets = {}, expanded_folder_nodes = {}, folder_navigation_trees = {},
  folder_navigation_revision = 0, folder_navigation_built_revision = -1 }
assert(loadfile("src/lua/12_state_store.lua"))()
UI_METRIC = {}
UI_DENSITY_PROFILES = { compact = { row_h=30, header_h=24, radius=3, radius_small=3,
  icon_button=28, icon_gap=4, panel_padding=4, parameter_h=44, parameter_min_w=88,
  parameter_max_w=126, control_panel_h=56, panel_gap=4, item_x=6, item_y=3 } }
Host = { time_precise = function() return 10 end }
SEP = "/"
function safe_lower(s) return tostring(s or ""):lower() end
function clamp(n,a,b) return math.max(a, math.min(b,n)) end
function canonical_source_path(s) return tostring(s or ""):gsub("\\", "/"):gsub("/$", "") end
function path_key(s) return safe_lower(canonical_source_path(s)) end
function basename(s) return s:match("([^/]+)$") or s end
function dirname(s) return s:match("^(.*)/[^/]+$") or "" end
function join_path(a,b) return a .. "/" .. b end
function path_is_inside(p,r) return path_key(p) == path_key(r) or path_key(p):sub(1,#r+1) == path_key(r) .. "/" end
function can_run_heavy_job() return true end
assert(loadfile(workspace_path))()
local core, runtime = read(core_path), read(runtime_path)
assert(load(region(core, "function apply_ui_density_metrics()", "function apply_surface_style()")))()
assert(load(region(core, "function invalidate_folder_navigation()", "function stable_id(")))()
assert(ui_font_size("bad") == 13 and ui_font_size(0) == 10 and ui_font_size(100) == 24)
for _, size in ipairs({10,13,18,24}) do
  state.ui_font_size = size
  apply_ui_density_metrics()
  assert(math.abs(ROW_H - 30*size/13) < 0.0001)
  assert(HEADER_H >= size and UI_METRIC.icon_button >= size)
end
state.ui_font_size = 13 apply_ui_density_metrics()
state.ui_font_size = 24
assert(ui_px(100) == 100, "settings edits must not change metrics halfway through a frame")
apply_ui_density_metrics()
assert(ui_px(100) > 180)
state.ui_font_size=13 state.config_dirty=false apply_ui_density_metrics()
for _, size in ipairs({14,18,24,20,10}) do
  assert(not workspace_edit_font_size(true,size,true))
  apply_ui_density_metrics()
  assert(state.ui_font_size==13 and state.ui_font_size_draft==size and ui_px(100)==100)
  assert(not state.config_dirty, "drag must not dirty or autosave intermediate font sizes")
end
assert(workspace_edit_font_size(false,10,false))
assert(state.ui_font_size==10 and state.ui_font_size_draft==nil and state.config_dirty)
assert(not workspace_edit_font_size(false,10,false), "release commits once")
state.config_dirty=false
assert(not workspace_commit_font_size(10) and not state.config_dirty)
state.ui_font_size=24 apply_ui_density_metrics()
local lines = {}
workspace_edit_font_size(true,18,true)
workspace_write_settings({ write = function(_,...) local t={} for i=1,select('#',...) do t[i]=tostring(select(i,...)) end lines[#lines+1]=table.concat(t) end })
assert(table.concat(lines):find("ui_font_size\t24",1,true))
assert(not table.concat(lines):find("ui_font_size_draft",1,true), "font drafts are never persisted")
AppState.set("ui_font_size_draft",nil)
assert(workspace_load_setting("sidebar_show_workflow", "0") and state.sidebar_modules.workflow == false)
assert(workspace_load_setting("sidebar_folder_mode", "roots") and state.sidebar_folder_mode == "roots")
assert(workspace_load_setting("sidebar_navigation_mode", "folders") and workspace_navigation_enabled("folders"))
assert(not workspace_navigation_enabled("libraries"))
assert(not workspace_load_setting("sidebar_show_unknown", "0"))
workspace_load_setting("sidebar_folder_mode", "bad")
assert(state.sidebar_folder_mode == "roots")

-- 100k assets/10k folders: no disk calls, bounded slices, stable alphabetical
-- children and exact root counts. Roots-only mode does not start a tree job.
state.root_records = { {id="r1",path="C:/Library",alias="Library",enabled=true,library_id="l1"},
  {id="r2",path="D:/Other",alias="Other",enabled=true,library_id="l2"},
  {id="off",path="E:/Off",alias="Disabled",enabled=false,library_id="l3"} }
for i=1,100000 do
  local folder = "C:/Library/" .. string.format("folder-%05d", 10001 - ((i-1)%10000+1))
  state.assets[i] = { root_id="r1", folder=folder, path=folder .. "/" .. i .. ".wav", ready=true }
end
local rows, complete = folder_sidebar_rows()
assert(complete and #rows == 2 and state.folder_navigation_job == nil)
state.sidebar_folder_mode = "tree"
local started = os.clock()
assert(not ensure_folder_navigation_build())
local slices = 0
while state.folder_navigation_job do process_folder_navigation_build() slices=slices+1 assert(slices<10000) end
local root = state.folder_navigation_trees.r1
assert(root.total_count == 100000 and #root.children == 10000)
assert(root.children[1].name == "folder-00001" and root.children[10000].name == "folder-10000")
assert(root.children[1].total_count == 10 and root.children[1].direct_count == 10)
assert(ensure_folder_navigation_build() and state.folder_navigation_job == nil)
rows, complete = folder_sidebar_rows()
assert(#rows == 2 and complete)
folder_sidebar_toggle(root)
local flatten_slices = 0
repeat rows, complete = folder_sidebar_rows() flatten_slices=flatten_slices+1 until complete
assert(flatten_slices > 1 and #rows == 10002 and rows[2].depth == 1)
local stable = state.folder_sidebar_cache
assert(folder_sidebar_rows() == rows and state.folder_sidebar_cache == stable)
folder_sidebar_toggle(root)
rows, complete = folder_sidebar_rows()
assert(complete and #rows == 2)
invalidate_folder_navigation()
assert(state.folder_sidebar_cache == nil and not state.folder_navigation_ready)
print(string.format("Workspace capacity: 100k assets / 10k folders, %d build slices, %.3fs CPU", slices, os.clock()-started))

-- Real column layout: widths scale once and never rewrite saved preferences.
local column_source = region(runtime, "local COLUMN_DEFS = {", "function draw_column_visibility_popup()")
assert(load(column_source))()
state.column_visible = { waveform=true, filename=true }
state.column_widths = { waveform=350, filename=220 }
for _, size in ipairs({10,13,18,24}) do
  state.ui_font_size = size apply_ui_density_metrics()
  local layout = column_layout(300)
  assert(math.abs(layout.by_key.waveform.width - 350 * size/13) < 0.0001)
  assert(layout.width + 0.0001 >= 570 * size/13 and state.column_widths.waveform == 350)
end
assert(runtime:find('ImGui.PushFont(ctx, nil, ui_font_size())',1,true))
assert(runtime:find('new_left / ui_scale()',1,true))
assert(runtime:find('draw_settings_workspace()',1,true))
assert(not read(workspace_path):find('directory_exists(',1,true))

-- Exercise real renderers with layout-aware ImGui stubs, not only markers.
ctx, COLOR = {}, { dim=1, text=2, selected_text=3, panel=4, window=5 }
local cursor_x, cursor_y, last_right, last_y, last_height, surface_width = 0,0,0,0,0,300
local drawn, clicked, mouse_x, activated = 0, false, 0, nil
ImGui = {
  GetCursorScreenPos=function() return cursor_x,cursor_y end,
  GetContentRegionAvail=function() return surface_width-cursor_x,300 end,
  GetItemRectMax=function() return last_right,last_y+last_height end,
  GetCursorPos=function() return cursor_x,cursor_y end,
  GetScrollY=function() return state.test_scroll or 0 end,
  GetWindowSize=function() return surface_width,300 end,
  SameLine=function(_,_,gap) cursor_x,cursor_y=last_right+gap,last_y end,
  Dummy=function(_,w,h) assert(w>=0 and h>=0) last_right,last_y,last_height=cursor_x+w,cursor_y,h cursor_x,cursor_y=0,cursor_y+h+(UI_METRIC.item_y or 0) end,
  Selectable=function(_,_,_,_,w,h) drawn=drawn+1 ImGui.Dummy(ctx,w,h) return clicked end,
  CalcTextSize=function(_,text) return #text*ui_font_size()*0.5,ui_font_size() end,
  GetMousePos=function() return mouse_x,0 end,
  IsMouseDoubleClicked=function() return false end,
  BeginPopupContextItem=function() return false end,
  GetWindowDrawList=function() return {} end,
  PushID=function() end, PopID=function() end,
  DrawList_AddText=function() end, DrawList_AddRect=function() end, DrawList_AddLine=function() end,
  TextDisabled=function() end, TextWrapped=function() end,
}
function tooltip() end
function accept_folder_drop_target() end
function activate_folder_path(path,library) activated={path,library} end
function draw_clipped_text() end
function dark_button() return false end
function translate_ui_text(t) return t end
state.ui_font_size=13 apply_ui_density_metrics()
state.folder_navigation_trees={ r1=root } state.folder_navigation_ready=true
state.folder_navigation_built_revision=state.folder_navigation_revision
state.expanded_folder_nodes[root.key]=true folder_sidebar_invalidate()
repeat rows,complete=folder_sidebar_rows() until complete
state.test_scroll=50000
draw_folder_sidebar()
assert(drawn>0 and drawn<20, "only visible folder rows may draw")
cursor_x,cursor_y=0,0 clicked=true mouse_x=1
draw_folder_sidebar_row({node=root,record=state.root_records[1],depth=0})
assert(not state.expanded_folder_nodes[root.key] and activated==nil, "arrow expands without filtering")
cursor_x,cursor_y=0,0 mouse_x=70
draw_folder_sidebar_row({node=root,record=state.root_records[1],depth=0})
assert(activated[1]==root.path and activated[2]=="l1", "name filters selected source")
clicked=false
assert(load(region(runtime,"function preview_control_layout_metrics(","function draw_control_deck(")))()
assert(load(region(runtime,"function draw_action_strip(","function draw_preview_controls(")))()
assert(load(region(runtime,"function draw_studio_parameters(","function preview_control_layout_metrics(")))()
assert(load(region(runtime,"function draw_control_deck(","function format_loudness_value(")))()
assert(load(region(runtime,"function draw_inline_channel_selector(","function draw_regions_popup(")))()
local child_height, font_balance, var_balance, color_balance = 0,0,0,0
local child_visible, child_ends = true,0
ImGui.PushStyleVar=function() var_balance=var_balance+1 end
ImGui.PopStyleVar=function(_,n) var_balance=var_balance-(n or 1) end
ImGui.PushStyleColor=function() color_balance=color_balance+1 end
ImGui.PopStyleColor=function(_,n) color_balance=color_balance-(n or 1) end
ImGui.PushFont=function(_,_,size) assert(size==ui_font_size()) font_balance=font_balance+1 end
ImGui.PopFont=function() font_balance=font_balance-1 end
ImGui.BeginChild=function(_,_,w,h) surface_width=w-ui_px(4) cursor_x,cursor_y=0,0 child_height=h return child_visible end
ImGui.EndChild=function() child_ends=child_ends+1 assert(last_y+last_height<=child_height, string.format("wrapped controls overflow: font=%d width=%.1f mode=%s bottom=%.1f height=%.1f",ui_font_size(),surface_width,state.preview_control_layout,last_y+last_height,child_height)) end
ImGui.Spacing=function() cursor_y=cursor_y+ui_px(8) end
ImGui.IsMouseDragging=function() return false end
ImGui.IsMouseClicked=function() return false end
ImGui.GetKeyMods=function() return 0 end
ImGui.IsItemHovered=function() return false end
ImGui.IsKeyPressed=function() return false end
ImGui.Mod_Ctrl,ImGui.Mod_Shift=1,2
ImGui.TextDisabled=function(_,t) local w,h=ImGui.CalcTextSize(ctx,t) ImGui.Dummy(ctx,w,h) end
ImGui.Button=function(_,_,w,h) assert(cursor_x+w<=surface_width+0.001) ImGui.Dummy(ctx,w,h) return false end
ImGui.WindowFlags_NoScrollbar,ImGui.WindowFlags_NoScrollWithMouse=1,2
function icon_button(_,_,_,_,size) assert(cursor_x+size<=surface_width+0.001) ImGui.Dummy(ctx,size,size) return false,false,false end
function draw_parameter_card(_,_,value,_,_,_,_,w,h) assert(cursor_x+w<=surface_width+0.001) ImGui.Dummy(ctx,w,h) return value,false end
function toolbar_separator(h) ImGui.Dummy(ctx,ui_px(7),h) end
function has_selection() return false end
function asset_regions() return {} end
function draw_more_actions_popup() end
function draw_preview_presets_popup() end
function draw_regions_popup() end
function preview_asset_channel_count(asset) return asset.channels or 2 end
function ensure_preview_channel_selection(asset) return {true,true},asset.channels end
function selected_preview_channel_count() return 2 end
function preview_channel_label(channel) return tostring(channel) end
function rgba_with_alpha(v) return v end
state.favorites={} state.preview_channel_mode="original"
for _,size in ipairs({10,13,18,24}) do
  state.ui_font_size=size apply_ui_density_metrics()
  for _,width in ipairs({220,250,275,300,350,400,450,500,550,600,650,700,800,1000,1200,1600}) do
    for _,mode in ipairs({"minimal_rack","focus_rack","studio_rack"}) do
      state.preview_control_layout=mode
      local layout=preview_control_layout_metrics(width)
      assert(layout.row_count>=1 and layout.panel_height>=layout.button_size*layout.row_count)
      if width<layout.action_width then assert(layout.row_count>1) end
      surface_width=width cursor_x,cursor_y,last_y,last_height=0,0,0,0
      draw_control_deck({path="C:/test.wav"})
      assert(var_balance==0 and color_balance==0)
      state.preview_channel_strip_expanded=true
      surface_width=width cursor_x,cursor_y,last_y,last_height=0,0,0,0
      draw_control_deck({path="C:/multi.wav",channels=8})
      assert(var_balance==0 and color_balance==0)
      state.preview_channel_strip_expanded=false
    end
  end
end
child_visible=false
local previous_ends=child_ends
surface_width=800 cursor_x,cursor_y=0,0
draw_control_deck({path="C:/clipped.wav"})
assert(child_ends==previous_ends and var_balance==0 and color_balance==0, "clipped deck must not EndChild twice")
child_visible=true
assert(load(region(runtime,"function push_theme()","function draw_inspector_splitter(")))()
function apply_theme_palette() end
function apply_surface_style() end
function rgba_with_alpha(v) return v end
local colors,vars=push_theme()
assert(font_balance==1 and var_balance==vars and color_balance==colors)
pop_theme(colors,vars)
assert(font_balance==0 and var_balance==0 and color_balance==0)

-- Real main layout: scaled side panels yield to the center without changing
-- saved visibility. Clip-only Begin returns need no explicit End in ReaImGui.
local bootstrap=read("src/lua/00_bootstrap.lua")
local constants=region(bootstrap,"local SIDEBAR_W", "local COLOR")
constants=constants:gsub("local ", "")
assert(load(constants))()
local saved_regions={}
local main_width,main_height,visible_main=1000,500,true
ImGui.SetNextWindowSize=function() end
ImGui.Begin=function() return visible_main,true end
ImGui.End=function() end
ImGui.IsWindowFocused=function() return false end
ImGui.Separator=function() end
ImGui.GetContentRegionAvail=function() return main_width,main_height end
ImGui.BeginChild=function(_,id,w,h) assert(w>0 and h>0) saved_regions[id]={w,h} return false end
ImGui.EndChild=function() error("ReaImGui already ended this clipped child") end
ImGui.SameLine=function() end
ImGui.WindowFlags_NoCollapse=4
function begin_module(id,w,h) assert(w>0 and h>0) saved_regions[id]={w,h} return false end
function end_module() end
function draw_inspector_splitter() end
for _,name in ipairs({"draw_toolbar","draw_workspace_tabs","workspace_tabs_track","draw_sub_toolbar","draw_path_condition_bar","draw_import_progress","draw_help_popup","draw_transient_detection_popup","draw_transfer_popup","draw_settings_popup","draw_folder_drop_choice_popup","keyboard","process_external_drag","draw_tooltip_overlay"}) do _G[name]=function() end end
assert(load(region(runtime,"function draw_main()","function autosave()")))()
VERSION,SCRIPT_NAME="Test","PsyReaSFX"
state.open=true state.inspector_width=320 state.sidebar_width=240
for _,size in ipairs({10,13,18,24}) do
  state.ui_font_size=size
  for _,width in ipairs({300,600,1000,1800}) do
    for _,height in ipairs({120,500,1000}) do
      main_width,main_height=width,height saved_regions={}
      state.sidebar_visible,state.inspector_visible=true,true
      draw_main()
      local center=saved_regions.center_workspace
      assert(center[1]<=width and center[2]<=height)
      assert(state.sidebar_visible and state.inspector_visible, "temporary folding must preserve preferences")
      local total=center[1]
      if saved_regions.aether_sidebar then total=total+saved_regions.aether_sidebar[1]+PANEL_GAP end
      if saved_regions.metadata_inspector then total=total+saved_regions.metadata_inspector[1]+PANEL_GAP end
      assert(total<=width+0.001)
      assert(font_balance==0 and var_balance==0 and color_balance==0)
    end
  end
end
visible_main=false draw_main()
assert(font_balance==0 and var_balance==0 and color_balance==0)
workspace_load_setting("sidebar_width", tostring(math.huge))
assert(state.sidebar_width==240)

-- Real font editor keeps its slider bounds stable through a full drag.
local editor_width, slider_x, slider_y, slider_w, next_width = 500,0,0,0,0
local slider_value, slider_active, slider_changed = 13,true,true
local preview_size, editor_fonts, applied_button = nil,0,nil
ImGui.GetContentRegionAvail=function() return editor_width-cursor_x,300 end
ImGui.GetCursorScreenPos=function() return cursor_x,cursor_y end
ImGui.SetNextItemWidth=function(_,w) next_width=w end
ImGui.Text=function() ImGui.Dummy(ctx,80,ui_px(20)) end
ImGui.TextWrapped=function() ImGui.Dummy(ctx,editor_width,ui_px(40)) end
ImGui.SliderInt=function(_,id,value,minimum,maximum,format)
  assert(id=="##workspace_font_size" and minimum==10 and maximum==24 and format=="%d px")
  slider_x,slider_y,slider_w=cursor_x,cursor_y,next_width
  ImGui.Dummy(ctx,next_width,ui_px(24))
  return slider_changed,slider_value
end
ImGui.IsItemActive=function() return slider_active end
ImGui.PushFont=function(_,_,size) preview_size=size editor_fonts=editor_fonts+1 end
ImGui.PopFont=function() editor_fonts=editor_fonts-1 end
function mark_interaction() end
function dark_button(label,w) ImGui.Dummy(ctx,w,ui_px(28)) return label==applied_button end
ImGui.SameLine=function(_,_,gap) cursor_x,cursor_y=last_right+gap,last_y end
state.ui_font_size=13 state.config_dirty=false apply_ui_density_metrics()
local geometry
for _,size in ipairs({14,18,24,10,20}) do
  slider_value=size cursor_x,cursor_y=0,0
  apply_ui_density_metrics()
  draw_workspace_font_editor()
  local current=string.format("%.2f:%.2f:%.2f",slider_x,slider_y,slider_w)
  geometry=geometry or current assert(current==geometry,"slider must not chase the mouse")
  assert(state.ui_font_size==13 and preview_size==size and editor_fonts==0 and not state.config_dirty)
end
slider_active,slider_changed=false,false cursor_x,cursor_y=0,0
draw_workspace_font_editor()
assert(state.ui_font_size==20 and state.ui_font_size_draft==nil and editor_fonts==0)
apply_ui_density_metrics()
assert(math.abs(ui_scale()-20/13)<0.0001)
applied_button="−##font_smaller" cursor_x,cursor_y=0,0
draw_workspace_font_editor() assert(state.ui_font_size==19)
applied_button="+##font_larger" cursor_x,cursor_y=0,0
draw_workspace_font_editor() assert(state.ui_font_size==20)
applied_button="恢复默认字体（13 px）" cursor_x,cursor_y=0,0
draw_workspace_font_editor() assert(state.ui_font_size==13)
print("Lua workspace settings, font scaling and folder navigation self-test passed")
