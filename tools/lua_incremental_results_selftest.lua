local module_path = assert(arg[1], "incremental results module is required")
local count = tonumber(arg[2]) or 25000
local requested_budget = tonumber(arg[3])
assert(count >= 1 and count <= 500000, "count must be between 1 and 500000")

assert(loadfile(module_path))()
local budget = requested_budget or RESULT_BUILD_DEFAULT_BUDGET

-- Regression for the main-window comparator contract. Both orders must be
-- irreflexive and asymmetric; otherwise Lua raises "invalid order function"
-- when a real catalog chunk is sorted.
assert(ordered_result_less("a", "b", 1), "ascending comparison mismatch")
assert(not ordered_result_less("b", "a", 1), "ascending comparison is not asymmetric")
assert(not ordered_result_less("a", "a", 1), "ascending comparison is not irreflexive")
assert(ordered_result_less("b", "a", -1), "descending comparison mismatch")
assert(not ordered_result_less("a", "b", -1), "descending comparison is not asymmetric")
assert(not ordered_result_less("a", "a", -1), "descending comparison is not irreflexive")

local strict_fixture = { "b", "a", "c", "a" }
table.sort(strict_fixture, function(left, right)
  return ordered_result_less(left, right, 1)
end)
assert(table.concat(strict_fixture, ",") == "a,a,b,c", "strict ascending sort mismatch")

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

local framed = begin_incremental_result_job(assets,function() return true end,less_name,
  function(asset) return asset.path end,selected_path)
local frames=0
local frame_status,frame_results,frame_selected
repeat
  frame_status,frame_results,frame_selected=step_incremental_result_frame(framed,budget,os.clock,0.008)
  frames=frames+1 assert(frames<count*2+1000)
until frame_status=="complete"
assert(#frame_results==#results and frame_selected==selected_index)
for i=1,#results do assert(frame_results[i]==results[i],"frame grouping must not change ordering") end
assert(frames<=steps,"multiple bounded stages must not add defer frames")
local advancing_clock=0
local limited=begin_incremental_result_job(assets,function() return true end,less_name)
step_incremental_result_frame(limited,1,function() advancing_clock=advancing_clock+0.01 return advancing_clock end,0.008)
assert(limited.index==2,"expired frame budget must stop after one bounded stage")
print(string.format("Result frame grouping: %d defer steps -> %d frames; exact order preserved",steps,frames))

-- Differential check of the resumable ping-pong merge against table.sort. Tiny
-- chunk sizes and starvation budgets force odd trailing runs, bulk moves and
-- resumes at every possible position; the comparator is a total order, so the
-- result must be identical to a plain sort.
do
  local saved_chunk = RESULT_SORT_CHUNK_SIZE
  local seed = 20260609
  local function random_below(limit)
    seed = (seed * 1103515245 + 12345) % 2147483648
    return seed % limit + 1
  end
  local cases = 0
  for _, chunk in ipairs({ 1, 2, 3, 5, 8, 17 }) do
    RESULT_SORT_CHUNK_SIZE = chunk
    for size = 0, 60 do
      for _, mode in ipairs({ "random", "sorted", "reverse", "dupes" }) do
        for _, step_budget in ipairs({ 1, 2, 3, 7, 1000 }) do
          local rows = {}
          for position = 1, size do
            local key
            if mode == "sorted" then key = position
            elseif mode == "reverse" then key = size - position
            elseif mode == "dupes" then key = random_below(4)
            else key = random_below(size * 2 + 1) end
            rows[position] = { key = key, id = position }
          end
          local function less_row(left, right)
            if left.key ~= right.key then return left.key < right.key end
            return left.id < right.id
          end
          local expected = table.move(rows, 1, #rows, 1, {})
          table.sort(expected, less_row)
          local merge_job = begin_incremental_result_job(
            rows, function() return true end, less_row
          )
          local merge_status, merged
          local guard = 0
          repeat
            merge_status, merged = step_incremental_result_job(merge_job, step_budget)
            guard = guard + 1
            assert(guard < 200000, "merge differential job did not converge")
          until merge_status == "complete"
          assert(#merged == size, string.format(
            "merge size mismatch chunk=%d size=%d mode=%s budget=%d", chunk, size, mode, step_budget))
          for position = 1, size do
            assert(merged[position] == expected[position], string.format(
              "merge mismatch chunk=%d size=%d mode=%s budget=%d at %d",
              chunk, size, mode, step_budget, position))
          end
          cases = cases + 1
        end
      end
    end
  end
  RESULT_SORT_CHUNK_SIZE = saved_chunk
  print(string.format("Merge differential: %d cases identical to table.sort", cases))
end

print(string.format(
  "Lua incremental results self-test OK: count=%d steps=%d elapsed=%.3fs max_step=%.4fs stage=%s memory=%.1fMiB",
  count,
  steps,
  os.clock() - started,
  maximum_step_seconds,
  maximum_step_stage,
  collectgarbage("count") / 1024
))
