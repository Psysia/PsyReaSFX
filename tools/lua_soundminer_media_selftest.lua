-- Synthetic sources and an in-memory private filesystem: never touches user media.
local function read_source(path)
  local file = assert(io.open(path, "rb"))
  local text = file:read("*a") file:close() return text
end
local media_source = read_source("src/lua/29_soundminer_media.lua")
local runtime_source = read_source("src/lua/50_runtime_ui.lua")
local function load_region(first, last)
  local at = assert(runtime_source:find(first, 1, true), first)
  local stop = assert(runtime_source:find(last, at + #first, true), last)
  assert(load(runtime_source:sub(at, stop - 1), "@runtime-fixture", "t", _ENV))()
end
SEP, DATA_DIR, DEFAULT_TRANSFER_DIR = "\\", "C:\\PRSFixture", "C:\\PRSFixture\\Transfer"
PsyReaSFXScope = {kind = "soundminer"}
state = {}
AppState = {set = function(k,v) state[k] = v return v end,
  apply = function(values) for k,v in pairs(values) do state[k] = v end end}
function path_key(path) return tostring(path):gsub("/", "\\"):lower() end
function join_path(a,b) return a .. "\\" .. b end
function directory_exists() return true end
function set_status() end
function clamp(n,a,b) return math.max(a,math.min(b,n)) end
function extension(path) return (path:match("%.([^%.]+)$") or ""):lower() end
function trim(v) return tostring(v or ""):match("^%s*(.-)%s*$") end
function normalize_slashes(v) return tostring(v or ""):gsub("/", "\\") end
function translate_ui_text(v) return v end
local originals, private, removed = {}, {}, {}
local bytes_read, native_calls, project = 0, 0, "project"
local function is_private(path) return path:sub(1, #DATA_DIR + 1) == DATA_DIR .. "\\" end
reaper = {
  time_precise = function() return 123.456 end,
  EnumProjects = function() return project end,
  RecursiveCreateDirectory = function(path) assert(is_private(path)); return 1 end,
  file_exists = function(path) return originals[path] ~= nil or private[path] ~= nil end,
  GetOS = function() return "Win64" end,
  PCM_Source_CreateFromFile = function(path)
    native_calls = native_calls + 1
    assert(is_private(path), "native source opened original Soundminer audio")
    return {path = path}
  end,
  PCM_Source_CreateFromFileEx = function() error("protected waveform reached native source") end,
  PCM_Source_BuildPeaks = function(source) assert(is_private(source.path)); return 0 end,
  PCM_Source_GetPeaks = function() error("protected waveform reached native peak reader") end,
  PCM_Source_Destroy = function() end,
  GetMediaSourceLength = function() return 1, false end,
  GetMediaSourceNumChannels = function() return 1 end,
  GetMediaSourceSampleRate = function() return 48000 end,
  GetMediaSourceType = function() return "WAVE" end,
}
Jobs = {accepting = true, active = {}}
function Jobs.begin(kind)
  assert(not Jobs.active[kind], "queue replaced an active copy")
  local token = {kind = kind} Jobs.active[kind] = token return token
end
function Jobs.cancel(token) token.cancel_requested = true end
function Jobs.finish(token) Jobs.active[token.kind] = nil end
local readonly = {}
function readonly.open(path)
  local entry = originals[path]
  if not entry then return nil, "missing fixture" end
  local reader = {size = #entry.data, identity = entry.identity, mtime = entry.mtime, position = 0}
  function reader:unchanged()
    return originals[path] == entry and entry.identity == self.identity and entry.mtime == self.mtime
      and #entry.data == self.size and not self.closed
  end
  function reader:read(count)
    assert(type(count) == "number" and count <= 65536, "unbounded original read")
    if not self:unchanged() then return nil, "changed fixture" end
    if self.position >= self.size then return nil end
    local data = entry.data:sub(self.position + 1, self.position + count)
    self.position = self.position + #data bytes_read = bytes_read + #data
    return data
  end
  function reader:seek(whence, offset)
    whence, offset = whence or "cur", offset or 0
    self.position = (whence == "set" and 0 or whence == "end" and self.size or self.position) + offset
    return self.position
  end
  function reader:close() self.closed = true return true end
  return reader
end
SoundminerReadOnly = readonly
function source_file_exists(path)
  local reader = SoundminerReadOnly and SoundminerReadOnly.open(path)
  if reader then reader:close() return true end return false
end
local real_io_open, real_rename, real_remove = io.open, os.rename, os.remove
io.open = function(path, mode)
  assert(is_private(path), "CRT opened original Soundminer media")
  assert(mode == "wb") private[path] = ""
  return {write = function(self,data) private[path] = private[path] .. data return self end,
    close = function() return true end}
end
os.rename = function(from,to)
  assert(is_private(from) and is_private(to), "rename escaped PRS")
  assert(private[from] and not private[to]) private[to], private[from] = private[from], nil return true
end
os.remove = function(path)
  assert(is_private(path), "delete escaped PRS") removed[#removed + 1] = path private[path] = nil return true
end
assert(load(media_source, "@29_soundminer_media.lua", "t", _ENV))()
local function asset(name, data)
  local value = {path = "C:\\SoundminerFixture\\" .. name, name = name, soundminer_metadata = "fixture"}
  originals[value.path] = {data = data, identity = name, mtime = "1"} return value
end
local function drain()
  for _ = 1, 100 do
    if not SoundminerMedia.active and #SoundminerMedia.queue == 0 then return end
    local before = bytes_read SoundminerMedia.process()
    assert(bytes_read - before <= 262144, "copy did not yield within 256 KiB")
  end
  error("copy queue did not finish")
end
local large = asset("large.wav", string.rep("test", 180000))
local callbacks = 0
SoundminerMedia.prepare({large}, function(ok) assert(ok) callbacks = callbacks + 1 end)
assert(not SoundminerMedia.path(large))
drain()
local copied = assert(SoundminerMedia.path(large))
assert(is_private(copied) and private[copied] == originals[large.path].data and callbacks == 1)
local canceled = asset("cancel.wav", string.rep("C", 400000))
local canceled_ok
local cancel_session = SoundminerMedia.prepare({canceled}, function(ok) canceled_ok = ok end)
SoundminerMedia.process() SoundminerMedia.cancel(cancel_session) drain()
assert(canceled_ok == false and not SoundminerMedia.path(canceled) and #removed > 0)
local changed = asset("changed.wav", string.rep("D", 400000))
local changed_ok
SoundminerMedia.prepare({changed}, function(ok) changed_ok = ok end)
SoundminerMedia.process() originals[changed.path].mtime = "2" drain()
assert(changed_ok == false and not SoundminerMedia.path(changed))
local order = {}
SoundminerMedia.prepare({large}, function(ok) assert(ok) order[#order+1] = 1 end)
SoundminerMedia.prepare({large}, function(ok) assert(ok) order[#order+1] = 2 end)
drain() assert(table.concat(order, ",") == "1,2")
local called = false
originals[large.path].mtime = "3"
assert(SoundminerMedia.defer({large}, function() called = true end))
project = "different project" drain() assert(not called, "delayed action crossed projects")
SoundminerReadOnly = nil
assert(not SoundminerMedia.path(large), "missing native reader must fail closed")
SoundminerReadOnly = readonly

-- Unsupported or malformed WAVs must never fall back to REAPER peak builders.
LARGE_WAVE_MAX_POINTS, WAVE_READ_RETRY_LIMIT = 4096, 6
load_region("local DIRECT_WAVE_MAX_FRAMES_PER_POINT", "function memory_wave_key(")
local samples = string.rep(string.pack("<i2", 16384), 1024)
local fmt = string.pack("<I2I2I4I4I2I2", 1, 1, 48000, 96000, 2, 16)
local wav = "RIFF" .. string.pack("<I4", 36+#samples) .. "WAVEfmt " .. string.pack("<I4", #fmt)
  .. fmt .. "data" .. string.pack("<I4", #samples) .. samples
local pcm = asset("pcm.wav", wav)
local job = {asset = pcm, points = 32, preserve_channels = true}
local status, waveform
for _=1,12 do status,waveform = step_wave_job(job) if status ~= "working" then break end end
assert(status == "done" and waveform.count == 32 and waveform.peaks[1] == 0.5 and native_calls == 0)
local budget_job = {asset=pcm, points=512}
assert(step_wave_job(budget_job) == "working" and budget_job.direct_point == 65,
  "fast protected reads should use a bounded batch rather than four points per frame")
local stable_clock, simulated_time = reaper.time_precise, 200
reaper.time_precise = function() simulated_time = simulated_time + 0.004; return simulated_time end
assert(step_wave_job(budget_job) == "working" and budget_job.direct_point == 66,
  "slow shared reads must yield at the time budget after one point")
reaper.time_precise = stable_clock
destroy_wave_job(budget_job)
assert(not budget_job.direct_file and native_calls == 0, "budgeted reads must retain original-media protection")
local bad = asset("compressed.wav", "fLaC" .. string.rep("x", 100))
local compressed_job = {asset=bad,points=32}
assert(step_wave_job(compressed_job) == "working" and native_calls == 0)
drain()
assert(start_wave_job(compressed_job) and native_calls == 1, "native peaks did not use a verified private copy")
destroy_wave_job(compressed_job)
local malicious = asset("chunks.wav", "RIFF" .. string.pack("<I4", 16004) .. "WAVE" .. string.rep("JUNK\0\0\0\0", 2000))
local before = bytes_read
local malicious_job = {asset=malicious,points=32}
assert(step_wave_job(malicious_job) == "working" and bytes_read-before <= 8204)
destroy_wave_job(malicious_job) drain()
assert(not start_wave_job({asset=pcm,points=32}) and native_calls == 1)

-- Low-level native entry points also refuse an unprepared protected source.
bad = asset("unprepared.wav", "fLaC" .. string.rep("x", 100))
load_region("function create_transfer_item(", "function configure_transfer_render(")
assert(select(3,create_transfer_item(bad,false,{})), "transfer accepted an original source")
load_region("function insert_asset_at(", "function insert_assets_at(")
assert(insert_asset_at(bad,0,0,0,1) == false and native_calls == 1)
load_region("function transfer_path_key(", "function capture_transfer_context()")
state.by_path = {}
assert(not soundminer_transfer_path_allowed("C:\\SoundminerFixture\\export.wav", bad))
assert(not soundminer_transfer_path_allowed(DEFAULT_TRANSFER_DIR .. "\\..\\escape.wav", bad))
assert(soundminer_transfer_path_allowed(DEFAULT_TRANSFER_DIR .. "\\safe.wav", bad))
load_region("function unique_transfer_sidecar_path(", "function render_transfer_asset(")
assert(not unique_transfer_sidecar_path("C:\\SoundminerFixture\\export.wav", "render", 1))
assert(not commit_transfer_output(DEFAULT_TRANSFER_DIR.."\\out.tmp", bad.path, true, 1))

-- Ordinary PRS imports wait for the same source protection and then resume.
PsyReaSFXScope.kind = "prs"
local ordinary = asset("ordinary.wav", wav)
ordinary.soundminer_metadata = nil
assert(SoundminerMedia.requires(ordinary))
function metadata_map() return {} end
function parse_ucs_filename() return {} end
function metadata_pick() return "" end
function ucs_metadata_pick() return "" end
function ucs_classify_metadata() return nil end
function refresh_ucs_pending_membership() end
function mark_asset_database_change() end
function file_size(path) return #originals[path].data end
function can_run_heavy_job() return true end
function memory_wave_key(a) return a.path end
function wave_cache_file_exists() return true end
function clear_failed_task() end
function record_failed_task() error("healthy import was failed instead of waiting") end
load_region("function index_asset(", "function new_ucs_reclassification_counts()")
load_region("function process_metadata_queue()", "function start_import_recovery_audit()")
META_INTERVAL = 0.1
state.meta_queue = {{key=ordinary.path, asset=ordinary}}
state.meta_queued, state.next_meta_job = {[ordinary.path]=true}, 0
process_metadata_queue()
assert(#state.meta_queue == 1 and not ordinary.indexed, "metadata queue dropped a pending private copy")
drain() process_metadata_queue()
assert(ordinary.indexed and #state.meta_queue == 0 and native_calls == 2)
local imported = asset("folder-import.wav", wav)
imported.soundminer_metadata = nil
state.wave_cache, state.mini_wave_points = {}, 32
load_region("function step_import_session(", "function destroy_preview_source_list(")
local import = {assets={imported},done=0,failed=0,phase="metadata"}
assert(step_import_session(import) == false and import.done == 0 and not imported.indexed)
drain()
assert(step_import_session(import) == true and import.done == 1 and imported.indexed and imported.ready)
assert(native_calls == 3 and import.failed == 0)
local cover = asset("cover.png", string.rep("PNG fixture", 80))
state.artwork_images, state.artwork_image_order = {}, {}
ArtworkCreateBudget, ARTWORK_CREATES_PER_FRAME = {frame=-1,used=0}, 2
function artwork_cache_key(path) return path_key(path) end
function artwork_file_exists(path) return source_file_exists(path) end
function trim_artwork_image_cache() end
function ui_in_motion() return false end
local images = 0
ImGui = {
  ValidatePtr = function() return true end,
  Attach = function() end,
  GetFrameCount = function() return 1 end,
  CreateImage = function(path) assert(is_private(path)); images=images+1; return {path=path} end,
}
load_region("function artwork_image_from_path(", "function artwork_image_for_asset(")
assert(not artwork_image_from_path(cover.path) and images == 0)
drain()
assert(artwork_image_from_path(cover.path) and images == 1 and #state.artwork_image_order == 1)

-- A caller's cap is rechecked against the source opened for the actual copy.
local oversized = asset("oversized.png", string.rep("X", 100))
oversized.source_max_bytes = 20
local oversized_ok, before_cap = nil, bytes_read
SoundminerMedia.prepare({oversized}, function(ok) oversized_ok = ok end)
drain()
assert(oversized_ok == false and bytes_read == before_cap and not SoundminerMedia.path(oversized))

-- Delayed previews belong to both the submitting project and request.
function capture_transfer_settings() return {} end
function stop_preview()
  if SoundminerMedia.preview_session then SoundminerMedia.cancel(SoundminerMedia.preview_session) end
  SoundminerMedia.preview_session = nil
end
load_region("function play_preview(", "function update_preview_parameters()")
local actual_preview, played = play_preview, 0
play_preview = function() played = played + 1 end
state.region_start, state.region_end = 0, 1
project = "preview-project"
actual_preview(asset("preview-project.wav", wav))
project = "another-project"
drain()
assert(played == 0, "copy completion revived a preview in a different project")
actual_preview(asset("preview-obsolete.wav", wav))
local newer = {}
SoundminerMedia.preview_session = newer
drain()
assert(played == 0 and SoundminerMedia.preview_session == newer, "obsolete preview displaced a newer request")
SoundminerMedia.preview_session = nil
actual_preview(asset("preview-canceled.wav", wav))
stop_preview() drain()
assert(played == 0, "canceled preview was revived")
actual_preview(asset("preview-current.wav", wav))
drain()
assert(played == 1 and SoundminerMedia.preview_session == nil)

-- Batch/drag destinations retain track identity while source copies run.
load_region("function defer_native_media_action(", "function insert_asset(")
load_region("function insert_assets_at(", "function insert_selected_stack(")
local tracks, placements = {"a", "b", "c"}, {}
reaper.CountTracks = function() return #tracks end
reaper.GetTrack = function(_,index) return tracks[index + 1] end
reaper.ValidatePtr2 = function(_,track)
  for _,value in ipairs(tracks) do if value == track then return true end end return false
end
reaper.GetMediaTrackInfo_Value = function(track)
  for index,value in ipairs(tracks) do if value == track then return index end end error("removed track")
end
reaper.Undo_BeginBlock2, reaper.Undo_EndBlock2 = function() end, function() end
reaper.PreventUIRefresh, reaper.UpdateArrange = function() end, function() end
insert_asset_at = function(_,index) placements[#placements+1] = index return true end
insert_assets_at({asset("reordered.wav", wav)}, 1, 3, 0, 1, "fixture")
tracks = {"new", "a", "b", "c"}
drain()
assert(#placements == 1 and placements[1] == 2, "copy completion used an obsolete track number")
insert_assets_at({asset("removed-track.wav", wav)}, 2, 3, 0, 1, "fixture")
tracks = {"new", "a", "c"}
drain()
assert(#placements == 1, "removed destination track was silently replaced")
insert_assets_at({asset("append.wav", wav)}, #tracks, 3, 0, 1, "fixture")
tracks[#tracks+1] = "added during copy"
drain()
assert(placements[2] == #tracks, "append reused an obsolete track count")

-- Use the real loop: Transfer owns its exclusive branch while the independent
-- copy worker must still advance. This previously stalled the first export.
load_region("function process_transfer_job()", "function run_transfer(")
local loop_start = assert(runtime_source:find("function loop()", 1, true))
local loop_end = assert(runtime_source:find("\nloop()", loop_start, true))
assert(load(runtime_source:sub(loop_start, loop_end - 1), "@runtime-loop", "t", _ENV))()
for _,name in ipairs({"bg_mark", "process_asset_library_binding_refresh", "process_neural_similarity_probe",
  "process_ai_semantic_search", "process_import_recovery_audit", "process_library_count_rebuild",
  "process_ucs_count_rebuild", "process_config_save", "process_auxiliary_save", "cleanup_retired_preview_sources",
  "poll_preview", "poll_current_project_binding", "directory_online_pump", "watch_folders", "autosave",
  "frame_stats_record", "draw_main", "process_background_slice", "process_wave_cache_queue"}) do _G[name] = function() end end
reaper.defer = function() end
reaper.GetPlayStateEx = function() return 0 end
WEBVIEW_MODE, state.open = false, true
local exports, canceled_transfer = 0, false
function render_transfer_asset(task)
  assert(is_private(assert(SoundminerMedia.path(task.asset))))
  exports = exports + 1 return true, DEFAULT_TRANSFER_DIR .. "\\render.wav"
end
function finish_transfer_job(job, canceled)
  if job.media_session then SoundminerMedia.cancel(job.media_session) end
  state.transfer_job, state.transfer_running, state.transfer_cancel_requested = nil, false, false
  canceled_transfer = canceled
end
local pending_export = asset("transfer-pending.wav", string.rep("W", 700000))
state.transfer_running, state.transfer_last_outputs = true, {}
state.transfer_job = {project=project,tasks={{asset=pending_export,variant={}}},next_index=1,
  success_count=0,failures={},records={},total=1}
for _=1,20 do loop() if not state.transfer_running then break end end
assert(exports == 1 and not state.transfer_running, "exclusive Transfer starved its private-copy worker")
state.transfer_running, state.transfer_cancel_requested = true, true
state.transfer_job = {project=project}
reaper.GetPlayStateEx = function() error("cancellation must be checked before playback pause") end
process_transfer_job()
assert(canceled_transfer == true and not state.transfer_running)
io.open, os.rename, os.remove = real_io_open, real_rename, real_remove
print("Soundminer media safety passed: shared reads, bounded copies, cancellation/change detection, native guards and output confinement")
