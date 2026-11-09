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
    match_count = 0,
    sort_index = 1,
    sort_chunk = math.max(1, math.floor(RESULT_SORT_CHUNK_SIZE)),
    stage = "filter",
    selected_index = 0,
  }
end

-- Bottom-up merge sort over the sorted chunks. All chunks live back to back in
-- one flat array and the merge ping-pongs between two flat arrays, so a round
-- allocates nothing (the second buffer is created once) and every write uses an
-- explicit index. The merge tree (pairs of neighbouring runs, an odd trailing
-- run is carried over) and the tie rule (the left run wins unless the right
-- element is strictly less) are the same as the previous pairwise
-- implementation, so the resulting order is identical.
local function begin_merge_phase(job)
  local count = job.match_count
  local width = job.sort_chunk
  if count <= width then
    job.result = job.matches
    job.matches = nil
    job.select_index = 1
    job.stage = "select"
    return
  end

  job.merge_source = job.matches
  job.merge_target = {}
  job.matches = nil
  job.merge_width = width
  job.merge_start = 1
  job.merge_left = nil
  job.stage = "merge"
end

local function step_merge(job, budget)
  local source = job.merge_source
  local target = job.merge_target
  local less = job.less
  local count = job.match_count
  local move = table.move

  while budget > 0 do
    local left = job.merge_left
    if not left then
      local width = job.merge_width
      local start = job.merge_start
      if start > count then
        -- Round complete: the target now holds runs of twice the width.
        source, target = target, source
        width = width * 2
        job.merge_source = source
        job.merge_target = target
        job.merge_width = width
        job.merge_start = 1
        if width >= count then
          job.result = source
          job.merge_source = nil
          job.merge_target = nil
          job.select_index = 1
          job.stage = "select"
          return
        end
      else
        local left_end = start + width - 1
        if left_end > count then left_end = count end
        local right_end = left_end + width
        if right_end > count then right_end = count end
        job.merge_left = start
        job.merge_left_end = left_end
        job.merge_right = left_end + 1
        job.merge_right_end = right_end
        job.merge_out = start
        job.merge_bulk = false
        job.merge_checked = false
      end
    else
      local left_end = job.merge_left_end
      local right = job.merge_right
      local right_end = job.merge_right_end
      local out = job.merge_out

      if not job.merge_checked then
        job.merge_checked = true
        if right > right_end then
          job.merge_bulk = true
        else
          -- A pair that is already in order (the left tail is not greater
          -- than the right head) is a plain concatenation.
          if not less(source[right], source[left_end]) then
            job.merge_bulk = true
          end
          budget = budget - 1
        end
      end

      if job.merge_bulk then
        local take
        if left <= left_end then
          take = left_end - left + 1
          if take > budget then take = budget end
          move(source, left, left + take - 1, out, target)
          left = left + take
        else
          take = right_end - right + 1
          if take > budget then take = budget end
          move(source, right, right + take - 1, out, target)
          right = right + take
        end
        out = out + take
        budget = budget - take
      else
        local left_value = source[left]
        local right_value = source[right]
        while true do
          if less(right_value, left_value) then
            target[out] = right_value
            out = out + 1
            right = right + 1
            if right > right_end then
              job.merge_bulk = true
              break
            end
            right_value = source[right]
          else
            target[out] = left_value
            out = out + 1
            left = left + 1
            if left > left_end then
              job.merge_bulk = true
              break
            end
            left_value = source[left]
          end
          budget = budget - 1
          if budget <= 0 then break end
        end
      end

      if left > left_end and right > right_end then
        job.merge_left = nil
        job.merge_start = job.merge_start + job.merge_width * 2
      else
        job.merge_left = left
        job.merge_right = right
        job.merge_out = out
      end
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
    local source = job.source
    local predicate = job.predicate
    local matches = job.matches
    local match_count = job.match_count
    local index = job.index
    local total = job.total
    while index <= total and processed < budget do
      local value = source[index]
      if value and predicate(value) then
        match_count = match_count + 1
        matches[match_count] = value
      end
      index = index + 1
      processed = processed + 1
    end
    job.index = index
    job.match_count = match_count

    if index > total then
      job.source = nil
      job.stage = "sort_chunks"
    end
  elseif job.stage == "sort_chunks" then
    local count = job.match_count
    local first = job.sort_index
    if first <= count then
      local last = math.min(count, first + job.sort_chunk - 1)
      -- table.sort cannot sort a sub-range, so sort a copy of the chunk and
      -- write it back to the same positions of the flat array.
      local run = table.move(job.matches, first, last, 1, {})
      table.sort(run, job.less)
      table.move(run, 1, last - first + 1, first, job.matches)
      job.sort_index = last + 1
    else
      begin_merge_phase(job)
    end
  elseif job.stage == "merge" then
    step_merge(job, budget)
  elseif job.stage == "select" then
    if not job.selected_key or not job.key_selector then
      job.stage = "complete"
    else
      local processed = 0
      local result = job.result
      local result_count = #result
      local select_index = job.select_index
      local key_selector = job.key_selector
      local selected_key = job.selected_key
      while select_index <= result_count
        and processed < budget do
        if key_selector(result[select_index]) == selected_key then
          job.selected_index = select_index
          select_index = result_count + 1
          break
        end
        select_index = select_index + 1
        processed = processed + 1
      end
      job.select_index = select_index
      if select_index > result_count then
        job.stage = "complete"
      end
    end
  end

  if job.stage == "complete" then
    return "complete", job.result or {}, job.selected_index or 0
  end

  return "pending"
end

function step_incremental_result_frame(job, budget, now, seconds)
  -- Several bounded stages can share one defer frame. The deadline is checked
  -- between stages; no unbounded synchronous catalog sort is introduced.
  local deadline = now() + (seconds or 0.008)
  local status, results, selected_index
  for _=1,64 do
    status, results, selected_index = step_incremental_result_job(job,budget)
    if status == "complete" or now() >= deadline then break end
  end
  return status, results, selected_index
end
