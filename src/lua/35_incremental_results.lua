-- Incremental result construction keeps large catalogs out of a single UI
-- frame. The module is intentionally independent of REAPER/ImGui so the
-- ordering contract can be exercised by the command-line Lua self-test.

RESULT_BUILD_DEFAULT_BUDGET = 10000
RESULT_SORT_CHUNK_SIZE = 4096

-- Keep the ordering relation strict in both directions. The common
-- `ascending and left < right or left > right` idiom is not equivalent to an
-- if/else in Lua: when the ascending comparison is false it evaluates the
-- descending branch as a fallback, making both a<b and b<a true.
function ordered_result_less(left, right, direction)
  if (tonumber(direction) or 1) < 0 then
    return left > right
  end
  return left < right
end

function begin_incremental_result_job(
  source,
  predicate,
  less,
  key_selector,
  selected_key
)
  return {
    source = source or {},
    predicate = predicate,
    less = less,
    key_selector = key_selector,
    selected_key = selected_key,
    index = 1,
    total = #(source or {}),
    matches = {},
    sort_index = 1,
    runs = {},
    stage = "filter",
    selected_index = 0,
  }
end

local function begin_merge_round(job)
  if #job.runs <= 1 then
    job.result = job.runs[1] or {}
    job.runs = nil
    job.select_index = 1
    job.stage = "select"
    return
  end

  job.merge_input = job.runs
  job.merge_output = {}
  job.merge_pair_index = 1
  job.merge = nil
  job.runs = nil
  job.stage = "merge"
end

local function prepare_merge_pair(job)
  local left = job.merge_input[job.merge_pair_index]
  local right = job.merge_input[job.merge_pair_index + 1]

  if not left then
    job.runs = job.merge_output
    job.merge_input = nil
    job.merge_output = nil
    begin_merge_round(job)
    return false
  end

  if not right then
    job.merge_output[#job.merge_output + 1] = left
    job.merge_pair_index = job.merge_pair_index + 2
    return false
  end

  job.merge = {
    left = left,
    right = right,
    left_index = 1,
    right_index = 1,
    output = {},
  }
  return true
end

local function append_merge_value(merge, value)
  merge.output[#merge.output + 1] = value
end

local function step_merge(job, budget)
  local processed = 0

  while processed < budget and job.stage == "merge" do
    if not job.merge then
      if not prepare_merge_pair(job) then
        if job.stage ~= "merge" then
          break
        end
      end
    end

    local merge = job.merge
    if merge then
      local left_value = merge.left[merge.left_index]
      local right_value = merge.right[merge.right_index]

      if left_value and right_value then
        if job.less(right_value, left_value) then
          append_merge_value(merge, right_value)
          merge.right_index = merge.right_index + 1
        else
          append_merge_value(merge, left_value)
          merge.left_index = merge.left_index + 1
        end
      elseif left_value then
        append_merge_value(merge, left_value)
        merge.left_index = merge.left_index + 1
      elseif right_value then
        append_merge_value(merge, right_value)
        merge.right_index = merge.right_index + 1
      else
        job.merge_output[#job.merge_output + 1] = merge.output
        job.merge_pair_index = job.merge_pair_index + 2
        job.merge = nil
      end

      processed = processed + 1
    end
  end
end

function step_incremental_result_job(job, budget)
  -- Keep collection work moving alongside allocation-heavy merge rounds.
  -- Small explicit steps avoid deferring all reclamation to one long UI frame.
  collectgarbage("step", 16)
  budget = math.max(
    1,
    math.floor(tonumber(budget) or RESULT_BUILD_DEFAULT_BUDGET)
  )

  if job.stage == "filter" then
    local processed = 0
    while job.index <= job.total and processed < budget do
      local value = job.source[job.index]
      if value and job.predicate(value) then
        job.matches[#job.matches + 1] = value
      end
      job.index = job.index + 1
      processed = processed + 1
    end

    if job.index > job.total then
      job.source = nil
      job.stage = "sort_chunks"
    end
  elseif job.stage == "sort_chunks" then
    if job.sort_index <= #job.matches then
      local run = {}
      local last = math.min(
        #job.matches,
        job.sort_index + RESULT_SORT_CHUNK_SIZE - 1
      )
      for index = job.sort_index, last do
        run[#run + 1] = job.matches[index]
      end
      table.sort(run, job.less)
      job.runs[#job.runs + 1] = run
      job.sort_index = last + 1
    else
      job.matches = nil
      begin_merge_round(job)
    end
  elseif job.stage == "merge" then
    step_merge(job, budget)
  elseif job.stage == "select" then
    if not job.selected_key or not job.key_selector then
      job.stage = "complete"
    else
      local processed = 0
      while job.select_index <= #job.result
        and processed < budget do
        if job.key_selector(job.result[job.select_index])
          == job.selected_key then
          job.selected_index = job.select_index
          job.select_index = #job.result + 1
          break
        end
        job.select_index = job.select_index + 1
        processed = processed + 1
      end
      if job.select_index > #job.result then
        job.stage = "complete"
      end
    end
  end

  if job.stage == "complete" then
    return "complete", job.result or {}, job.selected_index or 0
  end

  return "pending"
end
