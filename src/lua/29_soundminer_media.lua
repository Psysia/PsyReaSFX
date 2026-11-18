-- Give REAPER a pathless PRS decoder for audition, or a PRS-owned private
-- copy for file-based operations. Original reads share read/write/delete.
SoundminerMedia = { copies = {}, queue = {}, serial = 0 }
do
  local M = SoundminerMedia
  function M.requires(asset)
    -- This beta protects every original, including files independently added
    -- to PRS which may also be in a currently running Soundminer catalog.
    return true
  end
  local function key(asset)
    return path_key(tostring(asset and asset.path or ""))
  end
  local function signature(reader)
    return table.concat({tostring(reader.identity), tostring(reader.mtime), tostring(reader.size)}, "|")
  end
  function M.open_source(path)
    if not SoundminerReadOnly or type(SoundminerReadOnly.open) ~= "function" then
      return nil, "原音频共享只读访问需要新版 PRS 原生扩展"
    end
    return SoundminerReadOnly.open(path)
  end
  local stream_types = {wav=true, wave=true, bwf=true, rf64=true, w64=true, aif=true, aiff=true, aifc=true, flac=true, mp3=true}
  function M.stream(asset, lo, hi, reverse)
    if type(reaper.PRS_Audio_Open) ~= "function" or type(reaper.PRS_Audio_Close) ~= "function"
      or not stream_types[(tostring(asset.path):match("%.([%w]+)$") or ""):lower()] then return nil end
    local id = reaper.PRS_Audio_Open(asset.path, tonumber(asset.duration) or 0, lo or 0, hi or 1, reverse == true)
    return type(id) == "number" and id > 0 and id or nil
  end
  function M.preview_source(asset, lo, hi, reverse)
    if type(reaper.CF_CreatePreview) ~= "function" or type(reaper.PCM_Source_CreateFromType) ~= "function" then return nil end
    local token = M.stream(asset, lo, hi, reverse)
    if not token then return nil end
    local ok, src = pcall(reaper.PCM_Source_CreateFromType, "PRS_AUDITION_" .. token)
    reaper.PRS_Audio_Close(token) -- no-op if consumed; release even if the factory failed.
    return ok and src or nil
  end
  function M.step_peaks(job)
    local data = reaper.PRS_Audio_Peaks(job.stream_token, job.points, job.preserve_channels == true)
    local count, channels, first, after, hex = tostring(data):match("^(%d+):(%d+):(%d+):(%d+):([%x]*)$")
    count, channels, first, after = tonumber(count), tonumber(channels), tonumber(first), tonumber(after)
    local lanes = job.preserve_channels and channels or 1
    if not count or count < 1 or count > job.points or channels < 1 or channels > 8 or
      first ~= (job.stream_point or 0) or after < first or after > count or after-first > 64 or
      #hex ~= (after-first)*lanes*4 then return "failed", nil, "共享音频读取中断，请重试或检查原文件" end
    local wave = job.stream_wave or {count=count,channels=channels,peaks={},spectral_available=false}
    if job.preserve_channels and not wave.channel_peaks then
      wave.channel_peaks = {}
      for ch=1,lanes do wave.channel_peaks[ch]={} end
    end
    local pos=1
    for point=first+1,after do
      local maximum=0
      for ch=1,lanes do
        local v=tonumber(hex:sub(pos,pos+3),16)/65535
        if wave.channel_peaks then wave.channel_peaks[ch][point]=v end
        maximum=math.max(maximum,v);pos=pos+4
      end
      wave.peaks[point]=maximum
    end
    job.stream_wave, job.stream_point, job.progress = wave, after, after/count
    return after==count and "done" or "working", after==count and wave or nil
  end
  function M.path(asset)
    if not asset then return nil, "没有素材" end
    if not M.requires(asset) then return asset.path end
    local cached = M.copies[key(asset)]
    if not cached then return nil, "需要准备 PRS 私有音频副本" end
    local reader, reason = M.open_source(asset.path)
    if not reader then return nil, reason end
    local matches = cached.signature == signature(reader)
    reader:close()
    if not matches or not reaper.file_exists(cached.path) then
      M.copies[key(asset)] = nil
      return nil, "源音频已更新，需要重新准备副本"
    end
    return cached.path
  end
  function M.all_ready(assets)
    for _, asset in ipairs(assets or {}) do
      if not M.path(asset) then return false end
    end
    return true
  end
  function M.ensure_path(asset, owner, label)
    local path, reason = M.path(asset)
    if path then return path end
    if owner.media_finished then return nil, owner.media_error or reason end
    if not owner.media_session then
      local session, failure = M.prepare({asset}, function(ok, why)
        owner.media_session = nil
        owner.media_finished = true
        owner.media_error = not ok and (why or "私有副本准备已取消") or nil
      end, label)
      owner.media_session = session
      if not session then owner.media_finished = true owner.media_error = failure return nil, failure end
    end
    return nil, "pending"
  end
  local function publish(session)
    AppState.set("soundminer_media_session", session)
  end
  local function close_copy(session, discard)
    if session.reader then pcall(function() session.reader:close() end) session.reader = nil end
    if session.writer then pcall(function() session.writer:close() end) session.writer = nil end
    if discard and session.partial then os.remove(session.partial) end
    session.partial = nil
  end
  local function finish(session, ok, reason)
    close_copy(session, not ok)
    if session.job_token then Jobs.finish(session.job_token, ok, reason or "") end
    if M.active == session then M.active = nil publish(nil) end
    if not ok and not session.canceled then set_status(reason or "无法准备私有音频副本", true) end
    if session.callback then
      local cb_ok, cb_error = pcall(session.callback, ok, reason)
      if not cb_ok then set_status("音频准备操作失败：" .. tostring(cb_error), true) end
    end
  end
  function M.cancel(session)
    session = session or M.active
    if session then
      session.canceled = true
      if session.job_token then Jobs.cancel(session.job_token) end
    end
  end
  function M.cancel_all()
    if M.active then M.cancel(M.active) finish(M.active, false, "canceled") end
    for _, session in ipairs(M.queue) do M.cancel(session) finish(session, false, "canceled") end
    M.queue = {}
  end
  -- A callback runs only after every required copy is closed and verified.
  -- The caller decides whether a delayed action is still relevant.
  function M.prepare(assets, callback, label)
    if #M.queue >= 32 then return nil, "私有音频准备队列已满" end
    local captured = {}
    for _, asset in ipairs(assets or {}) do
      if #captured >= 4096 then return nil, "一次最多准备 4096 个素材" end
      captured[#captured + 1] = asset
    end
    if not Jobs.accepting then return nil, "程序正在关闭" end
    local session = {assets = captured, index = 1, total = #captured, copied = 0,
      callback = callback, label = label or "准备私有音频副本"}
    M.queue[#M.queue + 1] = session
    set_status(session.label .. "（可在任务中取消）")
    return session
  end
  function M.defer(assets, callback, label)
    if M.all_ready(assets) then return false end
    local project = reaper.EnumProjects and reaper.EnumProjects(-1, "")
    local session, reason = M.prepare(assets, function(ok)
      if ok and (not project or project == reaper.EnumProjects(-1, "")) then callback() end
    end, label)
    if not session then set_status(reason, true) end
    return true
  end
  local function begin_copy(session, asset)
    local reader, reason = M.open_source(asset.path)
    if not reader then return false, reason end
    if type(reader.size) ~= "number" or reader.size <= 0 then
      reader:close() return false, "源音频为空或长度无效"
    end
    if asset.source_max_bytes ~= nil then
      local maximum = tonumber(asset.source_max_bytes)
      if not maximum or maximum ~= maximum or maximum <= 0 or maximum == math.huge
        or reader.size > maximum then
        reader:close() return false, "源文件超过允许的副本大小"
      end
    end
    if not M.directory then
      local directory = join_path(DATA_DIR, "native_media")
      if reaper.RecursiveCreateDirectory(directory, 0) <= 0
        and not directory_exists(directory) then
        reader:close() return false, "无法创建 PRS 私有音频目录"
      end
      M.directory = directory
    end
    local suffix = tostring(asset.path):match("%.([%w]+)$") or "media"
    if #suffix > 12 then suffix = "media" end
    local target
    for _ = 1, 1000 do
      M.serial = M.serial + 1
      target = join_path(M.directory, string.format("sm_%s_%s_%d.%s",
        os.date("%Y%m%d_%H%M%S"), tostring(math.floor(reaper.time_precise() * 1000000)), M.serial, suffix))
      if not reaper.file_exists(target) and not reaper.file_exists(target .. ".partial") then break end
      target = nil
    end
    if not target then reader:close() return false, "无法分配独立音频副本文件名" end
    local writer, write_error = io.open(target .. ".partial", "wb")
    if not writer then reader:close() return false, write_error end
    session.reader, session.writer = reader, writer
    session.partial, session.target = target .. ".partial", target
    session.signature, session.bytes, session.size = signature(reader), 0, reader.size
    return true
  end
  function M.process()
    if not M.active then
      M.active = table.remove(M.queue, 1)
      if M.active then
        M.active.job_token = Jobs.begin("soundminer_media", "soundminer_media", false)
        if not M.active.job_token then finish(M.active, false, "无法启动私有音频准备任务") return end
      end
      publish(M.active)
    end
    local session = M.active
    if not session then return end
    if session.canceled or session.job_token.cancel_requested then
      session.canceled = true finish(session, false, "canceled") return
    end
    local asset = session.assets[session.index]
    if not asset then finish(session, true) return end
    if not session.reader then
      if M.path(asset) then session.index = session.index + 1 return end
      local ok, reason = begin_copy(session, asset)
      if not ok then finish(session, false, reason) return end
    end
    local deadline = reaper.time_precise() + 0.004
    -- At most 256 KiB per defer slice, with no unbounded whole-file allocation.
    for _ = 1, 4 do
      local count = math.min(65536, session.size - session.bytes)
      if count <= 0 then break end
      local bytes, reason = session.reader:read(count)
      if not bytes or #bytes ~= count then finish(session, false, reason or "源音频读取不完整") return end
      local wrote, write_error = session.writer:write(bytes)
      if not wrote then finish(session, false, write_error or "私有副本写入失败") return end
      session.bytes = session.bytes + #bytes
      session.progress = (session.index - 1 + session.bytes / session.size) / math.max(1, session.total)
      if reaper.time_precise() >= deadline then break end
    end
    if session.bytes < session.size then return end
    local unchanged, reason = session.reader:unchanged()
    if not unchanged then finish(session, false, reason or "复制期间源音频已变化") return end
    local closed, close_error = session.writer:close()
    session.writer = nil
    if not closed then finish(session, false, close_error or "私有副本无法完成写入") return end
    session.reader:close() session.reader = nil
    local renamed, rename_error = os.rename(session.partial, session.target)
    if not renamed then finish(session, false, rename_error or "私有副本提交失败") return end
    session.partial = nil
    M.copies[key(asset)] = {path = session.target, signature = session.signature}
    session.copied = session.copied + 1
    session.index = session.index + 1
  end
end
