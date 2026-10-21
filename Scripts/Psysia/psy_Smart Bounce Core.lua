-- @noindex
-- Psysia Smart Bounce shared engine
-- Copyright (c) 2026 Psysia. All rights reserved.
--
-- The render is performed through REAPER's native master-mix renderer,
-- after temporarily isolating source media and routing ancestors.
-- Changes are restored before the bounced item is inserted.
local M = {}
local PROJECT = 0
local SECTION = "PsysiaSmartBounce"
local MAX_TAIL_SECONDS = 5.0
local RENDER_COMMAND = 42230 -- render using recent settings; auto-close
local NUM_RENDER = {
  "RENDER_SETTINGS", "RENDER_BOUNDSFLAG", "RENDER_STARTPOS",
  "RENDER_ENDPOS", "RENDER_TAILFLAG", "RENDER_TAILMS",
  "RENDER_CHANNELS", "RENDER_SRATE", "RENDER_NORMALIZE",
  "RENDER_ADDTOPROJ", "RENDER_DITHER"
}
local STR_RENDER = {
  "RENDER_FILE", "RENDER_PATTERN", "RENDER_FORMAT", "RENDER_FORMAT2"
}
local function err(s) error(s, 0) end
local function value(tr, key) return reaper.GetMediaTrackInfo_Value(tr, key) end
local function item_value(it, key) return reaper.GetMediaItemInfo_Value(it, key) end
local function parent(tr) return reaper.GetParentTrack(tr) end
local function get_name(tr)
  local _, s = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
  return s ~= "" and s or "track"
end
local function basename(s)
  s = (s or ""):gsub("[^%w_%-]+","_"):gsub("_+","_")
  s = s:sub(1, 60):gsub("_+$", "")
  return s ~= "" and s or "selection"
end
local function read_options()
  local function num(key, default, min, max)
    local v = tonumber(reaper.GetExtState(SECTION,key)) or default
    return math.max(min, math.min(max, v))
  end
  local mode = reaper.GetExtState(SECTION, "tail_mode")
  if mode ~= "fixed" and mode ~= "none" then mode="auto" end
  return {
    threshold_db=num("threshold_db",-60,-100,-12),
    silence_hold=num("silence_hold",1,0.1,5),
    safety_pad=num("safety_pad",0.2,0,2),
    mode=mode
  }
end
local function is_descendant(tr, ancestor)
  local node=tr
  for _=1,1024 do
    if not node then return false end
    if node==ancestor then return true end
    node=parent(node)
  end
  return false
end
local function top_root(tr)
  local p=parent(tr)
  local hops=0
  while p and hops<1024 do tr=p; p=parent(tr); hops=hops+1 end
  return tr
end
local function add_source(tr, set)
  if tr then set[tr]=true end
end
local function collect_selection()
  local selected_items={}
  for i=0,reaper.CountSelectedMediaItems(PROJECT)-1 do
    selected_items[#selected_items+1]=reaper.GetSelectedMediaItem(PROJECT,i)
  end
  local is_item_mode=#selected_items>0
  local source_set,keep_items={},{}
  local roots={}
  if is_item_mode then
    for _,it in ipairs(selected_items) do
      local tr=reaper.GetMediaItem_Track(it)
      add_source(tr,source_set)
      keep_items[it]=true
      roots[tr]=true
    end
  else
    for i=0,reaper.CountSelectedTracks(PROJECT)-1 do
      local tr=reaper.GetSelectedTrack(PROJECT,i)
      roots[tr]=true
    end
    if next(roots)==nil then
      err("请先选择至少一条轨道，或选择一个或多个 Item。")
    end
    for i=0,reaper.CountTracks(PROJECT)-1 do
      local tr=reaper.GetTrack(PROJECT,i)
      for root in pairs(roots) do
        if is_descendant(tr,root) then
          add_source(tr,source_set)
          break
        end
      end
    end
  end
  local start_pos,end_pos=nil,nil
  for i=0,reaper.CountMediaItems(PROJECT)-1 do
    local it=reaper.GetMediaItem(PROJECT,i)
    local tr=reaper.GetMediaItem_Track(it)
    if source_set[tr] and (not is_item_mode or keep_items[it]) then
      keep_items[it]=true
      local pos=item_value(it,"D_POSITION")
      local length=item_value(it,"D_LENGTH")
      if length>0 then
        start_pos=math.min(start_pos or pos,pos)
        end_pos=math.max(end_pos or pos+length,pos+length)
      end
    end
  end
  if not start_pos or not end_pos or end_pos<=start_pos then
    err("所选范围内没有有效 Item。轨道模式需要至少一个具有非零长度的 Item。")
  end
  local allowed={}
  for tr in pairs(source_set) do
    local node=tr
    local depth=0
    while node and depth<1024 do
      allowed[node]=true
      node=parent(node)
      depth=depth+1
    end
  end
  return {
    start_pos=start_pos, end_pos=end_pos,
    source_set=source_set, allowed=allowed,
    keep_items=keep_items, roots=roots,
    item_mode=is_item_mode
  }
end
local function output_insert_index(sel)
  local greatest=-1
  for tr in pairs(sel.source_set) do
    local root=top_root(tr)
    for i=0,reaper.CountTracks(PROJECT)-1 do
      local candidate=reaper.GetTrack(PROJECT,i)
      if is_descendant(candidate,root) then
        if i>greatest then greatest=i end
      end
    end
  end
  return greatest+1
end
local function snapshot()
  local snap={tracks={},items={},fx={},numbers={},strings={},restored=false}
  for i=0,reaper.CountTracks(PROJECT)-1 do
    local tr=reaper.GetTrack(PROJECT,i)
    snap.tracks[#snap.tracks+1]={
      track=tr, mute=value(tr,"B_MUTE"), solo=value(tr,"I_SOLO")
    }
  end
  for i=0,reaper.CountMediaItems(PROJECT)-1 do
    local it=reaper.GetMediaItem(PROJECT,i)
    snap.items[#snap.items+1]={
      item=it,
      mute=item_value(it,"B_MUTE")
    }
  end
  for _,key in ipairs(NUM_RENDER) do
    snap.numbers[key]=reaper.GetSetProjectInfo(PROJECT,key,0,false)
  end
  for _,key in ipairs(STR_RENDER) do
    local _,str=reaper.GetSetProjectInfo_String(PROJECT,key,"",false)
    snap.strings[key]=str
  end
  return snap
end
local function disable_fx(snap,tr)
  for i=0,reaper.TrackFX_GetCount(tr)-1 do
    local on=reaper.TrackFX_GetEnabled(tr,i)
    if on then
      snap.fx[#snap.fx+1]={track=tr,fx=i,enabled=on}
      reaper.TrackFX_SetEnabled(tr,i,false)
    end
  end
end
local function apply_isolation(snap,sel,with_parent)
  -- Mute other media items even on an unmuted ancestor bus.
  for _,state in ipairs(snap.items) do
    -- Never touch momentary SWS/BR solo / item-solo overrides.
    -- Those belong to the key-down/key-up action, not to this renderer.
    reaper.SetMediaItemInfo_Value(
      state.item,"B_MUTE",sel.keep_items[state.item] and 0 or 1)
  end
  for _,state in ipairs(snap.tracks) do
    local tr=state.track
    -- Do not set I_SOLO or SetTrackUISolo here: doing so interferes
    -- with SWS/BR "perform until shortcut released" preview actions.
    reaper.SetMediaTrackInfo_Value(
      tr,"B_MUTE",sel.allowed[tr] and 0 or 1)
    if not with_parent and sel.allowed[tr] and not sel.source_set[tr] then
      disable_fx(snap,tr)
    end
  end
  -- Never print master FX: the bounced item will pass through the
  -- master again during playback, otherwise master processing doubles.
  disable_fx(snap,reaper.GetMasterTrack(PROJECT))
end
local function restore(snap)
  if not snap or snap.restored then return end
  snap.restored=true
  -- Try every restoration independently if one pointer has gone invalid.
  for _,v in ipairs(snap.fx) do
    pcall(reaper.TrackFX_SetEnabled,v.track,v.fx,v.enabled)
  end
  for _,v in ipairs(snap.items) do
    if reaper.ValidatePtr2(PROJECT,v.item,"MediaItem*") then
      pcall(reaper.SetMediaItemInfo_Value,v.item,"B_MUTE",v.mute)
    end
  end
  for _,v in ipairs(snap.tracks) do
    if reaper.ValidatePtr2(PROJECT,v.track,"MediaTrack*") then
      pcall(reaper.SetMediaTrackInfo_Value,v.track,"B_MUTE",v.mute)
      -- Solo is never changed, so never "restore" a potentially stale
      -- momentary solo snapshot after SWS has handled key release.
    end
  end
  for key,v in pairs(snap.numbers) do
    pcall(reaper.GetSetProjectInfo,PROJECT,key,v,true)
  end
  for key,v in pairs(snap.strings) do
    pcall(reaper.GetSetProjectInfo_String,PROJECT,key,v,true)
  end
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
end
-- Prefer the project's dedicated output subfolder, but never fail
-- simply because a nested folder cannot be created. Windows projects with
-- Chinese characters in the project path may hit filesystem API limitations.
local function choose_output_folder()
  local base=reaper.GetProjectPathEx(PROJECT)
  if not base or base=="" then base=reaper.GetResourcePath() end
  local sub=base.."/PsysiaSmartBounce"
  local ok=reaper.RecursiveCreateDirectory(sub,0)
  if ok and ok>0 then
    return sub,false
  end
  -- The project recording/media directory is already maintained by REAPER.
  -- No additional mkdir is required for this fallback.
  return base,true
end

local function file_size(path)
  local f=io.open(path,"rb")
  if f then
    local size=f:seek("end")
    f:close()
    return size
  end
  -- Windows Lua io.open can fail with non-ASCII paths even if REAPER's
  -- native Unicode-aware media handling successfully wrote the WAV.
  if reaper.file_exists(path) then
    local src=reaper.PCM_Source_CreateFromFile(path)
    if src then
      local duration=reaper.GetMediaSourceLength(src)
      reaper.PCM_Source_Destroy(src)
      if duration and duration>0 then return duration*48000+100 end
    end
  end
  return nil
end
local function render_setup(sel,opts,folder,stem)
  local setnum=reaper.GetSetProjectInfo
  local setstr=reaper.GetSetProjectInfo_String
  setnum(PROJECT,"RENDER_SETTINGS",0,true) -- one master-mix file
  setnum(PROJECT,"RENDER_BOUNDSFLAG",0,true) -- custom bounds
  setnum(PROJECT,"RENDER_STARTPOS",sel.start_pos,true)
  setnum(PROJECT,"RENDER_ENDPOS",
    sel.end_pos+(opts.mode=="none" and 0 or MAX_TAIL_SECONDS),true)
  setnum(PROJECT,"RENDER_TAILFLAG",0,true)
  setnum(PROJECT,"RENDER_TAILMS",0,true)
  setnum(PROJECT,"RENDER_CHANNELS",2,true)
  setnum(PROJECT,"RENDER_SRATE",0,true)
  setnum(PROJECT,"RENDER_ADDTOPROJ",0,true)
  setnum(PROJECT,"RENDER_NORMALIZE",4<<16,true)
  setnum(PROJECT,"RENDER_DITHER",16,true)
  setstr(PROJECT,"RENDER_FILE",folder,true)
  setstr(PROJECT,"RENDER_PATTERN",stem,true)
  setstr(PROJECT,"RENDER_FORMAT","evaw",true)
  setstr(PROJECT,"RENDER_FORMAT2","",true)
  local _,targets=setstr(PROJECT,"RENDER_TARGETS","",false)
  local path=(targets or ""):match("^([^;]+)")
  path=path and path:gsub('^"',""):gsub('"$',"")
  if not path or path=="" then path=folder.."/"..stem..".wav" end
  return path
end
local function read_tail_end(take,sel,opts,full_length)
  if opts.mode=="none" then return sel.end_pos,false end
  if opts.mode=="fixed" then
    return math.min(sel.end_pos+MAX_TAIL_SECONDS,sel.start_pos+full_length),false
  end
  local src=reaper.GetMediaItemTake_Source(take)
  local sr=reaper.GetMediaSourceSampleRate(src)
  if not sr or sr<8000 then sr=48000 end
  local nc=math.max(1,math.min(reaper.GetMediaSourceNumChannels(src) or 2,2))
  local acc=reaper.CreateTakeAudioAccessor(take)
  if not acc then err("无法创建渲染音频分析器。") end
  local ok,last,at_limit=pcall(function()
    local window=math.max(16,math.floor(sr*0.01))
    local buf=reaper.new_array(window*nc)
    local threshold=10^(opts.threshold_db/20)
    local latest=nil
    local tail_duration=math.min(MAX_TAIL_SECONDS,
      math.max(0,sel.start_pos+full_length-sel.end_pos))
    local cursor=0
    while cursor<tail_duration-0.000001 do
      local n=math.min(window,math.floor((tail_duration-cursor)*sr+0.5))
      if n<=0 then break end
      buf.clear()
      local ret=reaper.GetAudioAccessorSamples(
        acc,sr,nc,sel.end_pos+cursor,n,buf)
      if ret==-1 then err("尾音读取失败。") end
      local sum=0
      for j=1,n*nc do
        local x=buf[j]
        sum=sum+x*x
      end
      local rms=math.sqrt(sum/(n*nc))
      if rms>=threshold then latest=cursor+n/sr end
      cursor=cursor+n/sr
    end
    if not latest then return sel.end_pos,false end
    local end_at=sel.end_pos+math.min(
      tail_duration,latest+opts.safety_pad)
    local incomplete=(tail_duration-latest)<opts.silence_hold
    return end_at,incomplete
  end)
  reaper.DestroyAudioAccessor(acc)
  if not ok then err(last) end
  return last,at_limit
end
local build_new_item_peaks
local function insert_result(sel,path,opts,with_parent)
  local src=reaper.PCM_Source_CreateFromFile(path)
  if not src then err("无法打开渲染后的 WAV："..path) end
  local length=reaper.GetMediaSourceLength(src)
  if not length or length<=0 then
    reaper.PCM_Source_Destroy(src)
    err("渲染文件长度为 0，无法插入。")
  end
  local index=output_insert_index(sel)
  local new_track=nil
  reaper.Undo_BeginBlock2(PROJECT)
  local ok,failed_or_incomplete,result_length=xpcall(function()
    reaper.InsertTrackAtIndex(index,true)
    new_track=reaper.GetTrack(PROJECT,index)
    if not new_track then err("无法创建输出轨道。") end
    local prefix=with_parent and "bounce_parent_fx_" or "bounce_track_fx_"
    local name=prefix..os.date("%H%M%S")
    reaper.GetSetMediaTrackInfo_String(new_track,"P_NAME",name,true)
    local item=reaper.AddMediaItemToTrack(new_track)
    if not item then err("无法创建输出 Item。") end
    local take=reaper.AddTakeToMediaItem(item)
    if not take then err("无法创建输出 Take。") end
    reaper.SetMediaItemTake_Source(take,src)
    reaper.SetMediaItemInfo_Value(item,"D_POSITION",sel.start_pos)
    reaper.SetMediaItemInfo_Value(item,"D_LENGTH",length)
    local end_at,incomplete=read_tail_end(take,sel,opts,length)
    local wanted=math.max(0.01,math.min(length,end_at-sel.start_pos))
    reaper.SetMediaItemInfo_Value(item,"D_LENGTH",wanted)
    reaper.SetMediaItemSelected(item,true)
    reaper.UpdateItemInProject(item)
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()
    -- Start waveform generation only after the Source has been attached.
    -- The deferred steps will refresh the Item once the peak file is ready.
    build_new_item_peaks(item)
    return incomplete,wanted
  end,debug.traceback)
  if not ok then
    if new_track and reaper.ValidatePtr2(PROJECT,new_track,"MediaTrack*") then
      reaper.DeleteTrack(new_track)
    end
    reaper.Undo_EndBlock2(PROJECT,"Smart Bounce failed: rolled back",-1)
    err(failed_or_incomplete)
  end
  reaper.Undo_EndBlock2(PROJECT,"Smart Bounce: create merged WAV below selection",-1)
  return failed_or_incomplete,result_length
end

local function find_preexisting_solo()
  -- Refuse to render through a momentary or manually soloed signal
  -- because we intentionally do not override Solo states.
  for i=0,reaper.CountTracks(PROJECT)-1 do
    local tr=reaper.GetTrack(PROJECT,i)
    local solo=value(tr,"I_SOLO")
    if solo~=0 then return tr end
  end
  return nil
end

-- Generate the waveform without requiring a focus change. The file
-- source is already owned by the newly inserted Item's active Take.
build_new_item_peaks = function(item)
  if not item or not reaper.ValidatePtr2(PROJECT,item,"MediaItem*") then return end
  local take=reaper.GetActiveTake(item)
  if not take then return end
  local src=reaper.GetMediaItemTake_Source(take)
  if not src then return end
  local started=false
  local ok,begin=pcall(reaper.PCM_Source_BuildPeaks,src,0)
  if ok and begin and begin>0 then started=true end
  local attempts=0
  local function step()
    if not reaper.ValidatePtr2(PROJECT,item,"MediaItem*") then
      if started then pcall(reaper.PCM_Source_BuildPeaks,src,2) end
      return
    end
    if started then
      attempts=attempts+1
      local good,remaining=pcall(reaper.PCM_Source_BuildPeaks,src,1)
      if not good then return end
      if remaining~=0 and attempts<20000 then
        reaper.defer(step)
        return
      end
      if remaining==0 then
        pcall(reaper.PCM_Source_BuildPeaks,src,2)
      end
    end
    reaper.UpdateItemInProject(item)
    reaper.MarkTrackItemsDirty(reaper.GetMediaItem_Track(item),item)
    reaper.UpdateArrange()
  end
  reaper.defer(step)
end

function M.run(with_parent)
  if reaper.GetPlayStateEx(PROJECT)&5~=0 then
    reaper.MB("请先停止播放和录音，再执行智能合并渲染。","Psysia Smart Bounce",0)
    return
  end
  if reaper.EnumProjects(0x40000000) then
    reaper.MB("REAPER 正在渲染另一项任务，请稍后重试。","Psysia Smart Bounce",0)
    return
  end
  local solo_track=find_preexisting_solo()
  if solo_track then
    reaper.MB(
      "检测到当前存在 Solo 轨道："..get_name(solo_track)
      .."\n\n请先松开鼠标试听快捷键，或解除现有 Solo 后再执行。"
      .."\n为保护 SWS/BR 按键松开恢复机制，Smart Bounce 不会修改轨道 Solo。",
      "Psysia Smart Bounce / Solo 冲突保护",0)
    return
  end
  local saved=nil
  local restored=false
  local active=true
  local function cleanup()
    if active then restore(saved); active=false end
  end
  reaper.atexit(cleanup)
  local state={}
  local function start()
    state.project=reaper.EnumProjects(-1)
    state.sel=collect_selection()
    state.opts=read_options()
    local folder,used_fallback=choose_output_folder()
    state.used_fallback=used_fallback
    local unique=string.format("%s_%d_%d",with_parent and
      "parentfx" or "trackfx",os.time(),
      math.floor(reaper.time_precise()*100000)%100000)
    state.folder=folder
    saved=snapshot()
    apply_isolation(saved,state.sel,with_parent)
    state.path=render_setup(state.sel,state.opts,folder,unique)
    if file_size(state.path) then err("输出文件名发生冲突："..state.path) end
    state.started=reaper.time_precise()
    reaper.Main_OnCommand(RENDER_COMMAND,0)
  end
  local ok,msg=xpcall(start,debug.traceback)
  if not ok then
    cleanup()
    reaper.MB("无法开始渲染：\n\n"..tostring(msg),
      "Psysia Smart Bounce",0)
    return
  end
  local last_size,stable_since=nil,nil
  local function poll()
    local good,reason=xpcall(function()
      if reaper.EnumProjects(-1)~=state.project then
        err("渲染期间切换了工程，已终止自动插入。")
      end
      local rendering=reaper.EnumProjects(0x40000000)~=nil
      local size=file_size(state.path)
      local now=reaper.time_precise()
      if now-state.started>600 then err("渲染超时（10 分钟）。") end
      if size and size>44 then
        if size~=last_size then
          last_size=size
          stable_since=now
        end
        if not rendering and stable_since and now-stable_since>0.45 then
          cleanup()
          local incomplete,trimmed=insert_result(
            state.sel,state.path,state.opts,with_parent)
          if state.used_fallback then
            reaper.ShowConsoleMsg(
              "[Smart Bounce] 专用子目录不可用；已改在工程媒体目录输出：\n"
              ..state.path.."\n")
          end
          if incomplete then
            reaper.MB("尾音在 5 秒上限内仍有信号。\n"
              .."已保留到最大检测边界，可能需要手动检查尾音。",
              "Psysia Smart Bounce",0)
          end
          return "done"
        end
      else
        if now-state.started>20 and not rendering then
          err("渲染未生成可读取的 WAV 文件。\n"
             .."请检查 REAPER 渲染设置或渲染提示窗口。")
        end
      end
      return "wait"
    end,debug.traceback)
    if not good then
      cleanup()
      reaper.MB("智能渲染失败：\n\n"..tostring(reason)
        .."\n\n原始工程状态已尝试恢复。",
        "Psysia Smart Bounce",0)
      return
    end
    if reason=="wait" then reaper.defer(poll) end
  end
  reaper.defer(poll)
end
return M
