local DUPLICATE_COMPARE_CHUNK_SIZE = 256 * 1024

function close_duplicate_comparison(comparison)
  if not comparison or comparison.closed then
    return
  end
  comparison.closed = true
  if comparison.left then
    comparison.left:close()
    comparison.left = nil
  end
  if comparison.right then
    comparison.right:close()
    comparison.right = nil
  end
end

function begin_duplicate_comparison(left_path, right_path)
  local left = io.open(left_path, "rb")
  if not left then
    return nil, "left_open"
  end
  local right = io.open(right_path, "rb")
  if not right then
    left:close()
    return nil, "right_open"
  end

  local left_size = left:seek("end")
  local right_size = right:seek("end")
  if not left_size or not right_size then
    left:close()
    right:close()
    return nil, "seek"
  end
  left:seek("set", 0)
  right:seek("set", 0)

  local comparison = {
    left = left,
    right = right,
    left_path = left_path,
    right_path = right_path,
    bytes_compared = 0,
    total_bytes = math.max(left_size, right_size),
    closed = false,
  }
  if left_size ~= right_size then
    close_duplicate_comparison(comparison)
    comparison.result = "different"
  end
  return comparison
end

function step_duplicate_comparison(comparison, chunk_size)
  if not comparison then
    return "failed"
  end
  if comparison.result then
    return comparison.result
  end
  if comparison.closed then
    return "failed"
  end

  chunk_size = math.max(
    4096,
    math.floor(tonumber(chunk_size) or DUPLICATE_COMPARE_CHUNK_SIZE)
  )
  local left_chunk, left_error = comparison.left:read(chunk_size)
  local right_chunk, right_error = comparison.right:read(chunk_size)
  if left_error or right_error then
    comparison.error = left_error or right_error or "read"
    comparison.result = "failed"
  elseif left_chunk ~= right_chunk then
    comparison.result = "different"
  elseif not left_chunk then
    comparison.result = "equal"
  else
    comparison.bytes_compared = comparison.bytes_compared + #left_chunk
    return "pending"
  end

  close_duplicate_comparison(comparison)
  return comparison.result
end
