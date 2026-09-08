local module_path = assert(arg[1], "incremental results module is required")
local count = tonumber(arg[2]) or 25000
local requested_budget = tonumber(arg[3])
assert(count >= 1 and count <= 500000, "count must be between 1 and 500000")

assert(loadfile(module_path))()
local budget = requested_budget or RESULT_BUILD_DEFAULT_BUDGET

local assets = {}
for index = count, 1, -1 do
  assets[#assets + 1] = {
    name = string.format("ASSET_%06d", index),
    path = string.format("C:/Capacity/%02d/ASSET_%06d.wav", index % 64, index),
    category = index % 64,
  }
end

local function less_name(left, right)
  if left.name == right.name then
    return left.path < right.path
  end
  return left.name < right.name
end

local selected_number = math.max(1, math.floor(count / 2))
local selected_path = string.format(
  "C:/Capacity/%02d/ASSET_%06d.wav",
  selected_number % 64,
  selected_number
)
local job = begin_incremental_result_job(
  assets,
  function() return true end,
  less_name,
  function(asset) return asset.path end,
  selected_path
)

local started = os.clock()
local steps = 0
local maximum_step_seconds = 0
local maximum_step_stage = ""
local status, results, selected_index
repeat
  local step_stage = job.stage
  local step_started = os.clock()
  status, results, selected_index = step_incremental_result_job(job, budget)
  local step_seconds = os.clock() - step_started
  if step_seconds > maximum_step_seconds then
    maximum_step_seconds = step_seconds
    maximum_step_stage = step_stage
  end
  steps = steps + 1
  assert(steps < count * 2 + 1000, "incremental result job did not converge")
until status == "complete"

assert(#results == count, "all-result count mismatch")
assert(selected_index == selected_number, "selected row index mismatch")
for index = 2, #results do
  assert(not less_name(results[index], results[index - 1]), "result order mismatch")
end

local filtered = begin_incremental_result_job(
  assets,
  function(asset) return asset.category == 7 end,
  function(left, right) return less_name(right, left) end
)
local filtered_status, filtered_results
repeat
  filtered_status, filtered_results = step_incremental_result_job(filtered, 3333)
until filtered_status == "complete"

local expected_filtered = 0
for index = 1, count do
  if index % 64 == 7 then expected_filtered = expected_filtered + 1 end
end
assert(#filtered_results == expected_filtered, "filtered result count mismatch")
for index = 2, #filtered_results do
  assert(
    not less_name(filtered_results[index - 1], filtered_results[index]),
    "descending result order mismatch"
  )
end

local empty = begin_incremental_result_job(
  assets,
  function() return false end,
  less_name
)
local empty_status, empty_results
repeat
  empty_status, empty_results = step_incremental_result_job(empty, 7777)
until empty_status == "complete"
assert(#empty_results == 0, "empty result job returned rows")

print(string.format(
  "Lua incremental results self-test OK: count=%d steps=%d elapsed=%.3fs max_step=%.4fs stage=%s memory=%.1fMiB",
  count,
  steps,
  os.clock() - started,
  maximum_step_seconds,
  maximum_step_stage,
  collectgarbage("count") / 1024
))
