-- Run the production scheduler against deterministic disk/decoder boundaries.
local root = arg[1] or "."
local file = assert(io.open(root .. "/src/lua/50_runtime_ui.lua", "rb"))
local source = file:read("*a"); file:close()
local first = assert(source:find("function memory_wave_key(", 1, true))
local last = assert(source:find("-- True exactly when load_wave_from_disk()", first, true))
local now, disk, decoded, closed, reads = 0, {}, {}, {}, 0
local wave = { count = 2, peaks = { 0.2, 0.8 } }
MAX_WAVE_MEMORY, MAX_WORK_QUEUE, WAVE_INTERVAL = 180, 160, 0.012
reaper = { time_precise = function() return now end }
AppState = { set = function(key, value) state[key] = value end }
Jobs = { begin = function() return {} end, finish = function() end, cancel = function() end }
function wave_cache_key(asset, points) return asset.path .. ":" .. points end
function load_wave_from_disk(asset, points) reads = reads + 1; return disk[wave_cache_key(asset, points)] end
function save_wave_to_disk(asset, points, value) disk[wave_cache_key(asset, points)] = value end
function can_run_heavy_job() return not state.interacting end
function clear_failed_task() end
function record_failed_task() end
function set_status() end
function translate_ui_text(text) return text end
function basename(path) return path end
function destroy_wave_job(job) closed[job.key] = true end
function step_wave_job(job)
  decoded[job.key] = (decoded[job.key] or 0) + 1
  if job.asset.crash then error("decoder fixture failure") end
  if job.asset.slow then return "working" end
  return "done", wave
end
assert(load(source:sub(first, last - 1), "@wave-queue", "t", _ENV))()
local function reset()
  state = { wave_cache = {}, wave_cache_count = 0, wave_clock = 0, wave_checked = {},
    wave_queued = {}, wave_queue = {}, next_wave_job = 0 }
  disk, decoded, closed, reads = {}, {}, {}, 0
end
local function tick() now = now + 0.05; process_wave_queue() end
local function request(asset, priority) return queue_wave(asset, 512, priority, false, false, true) end
local function key(asset) return wave_cache_key(asset, 512) end
local cold, warm = { path = "cold", slow = true }, { path = "warm" }
reset()
request(cold); tick(); tick()
disk[key(warm)] = wave; request(warm); tick()
assert(request(warm) == wave, "cached search result must load behind a long-running decoder")
assert(not decoded[key(warm)], "cache hit must never decode the original audio")

for _, bulk in ipairs({ "import_session", "precache_session" }) do
  reset(); state[bulk] = { phase = "index" }
  request(warm); tick(); tick()
  assert(request(warm) == wave, "interactive wave must finish while " .. bulk .. " remains active")
end

reset(); request(cold); tick(); tick(); state.interacting = true
disk[key(warm)] = wave; request(warm); tick()
assert(request(warm) == wave, "safe cache reads must continue during interaction")

reset(); warm.wave_error = "old failure"; disk[key(warm)] = wave
request(warm); tick()
assert(request(warm) == wave and not warm.wave_error, "old decode failure must not hide a usable cache")
warm.wave_error = nil

reset(); request(cold); tick(); tick()
local selected = { path = "selected" }; state.selected_path = selected.path
request(selected, true); tick(); tick()
assert(request(selected, true) == wave, "selected waveform must not wait for an unrelated slow source")
assert(closed[key(cold)], "preempted decoder must release source and copy ownership")

reset(); local broken = { path = "broken", crash = true }
request(broken); tick(); tick()
assert(broken.wave_error and closed[key(broken)] and not state.wave_active,
  "decoder exception must release its slot and expose a retryable error")
request(warm); tick(); tick()
assert(request(warm) == wave, "one failed asset must not stop later results")

reset(); request(cold); tick(); tick()
retry_wave_request(cold, 512, false, false)
assert(closed[key(cold)] and not state.wave_active and not state.wave_queued[key(cold)],
  "retry must cancel pending work, not merely clear the error string")
cold.slow = false; request(cold); tick(); tick()
assert(request(cold) == wave, "canceled request must be restartable")
cold.slow = true

reset(); request(cold); tick(); tick(); request(warm); tick()
disk[key(warm)] = wave -- Simulate a bulk worker creating a previously missing cache.
cold.slow = false; tick(); tick()
assert(request(warm) == wave and not decoded[key(warm)], "late bulk cache must be reused before decoding")
cold.slow = true
print("Wave queue self-test OK: cache isolation, bulk coexistence, interaction, stale errors, selection and decoder failures")
