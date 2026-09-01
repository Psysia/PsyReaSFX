local DUPLICATE_COMPARE_CHUNK_SIZE = 256 * 1024
local DUPLICATE_FINGERPRINT_VERSION = "sample-fnv1a-head-mid-tail-v1"

function duplicate_file_stat(path, fallback_size)
  local result = {
    size = tonumber(fallback_size) or 0,
    modified = "",
    source = "unavailable",
  }
  if not reaper or type(reaper.JS_File_Stat) ~= "function" then
    return result
  end
  local values = { pcall(reaper.JS_File_Stat, path) }
  if not values[1] or tonumber(values[2]) ~= 0 then
    return result
  end
  result.size = tonumber(values[3]) or result.size
  result.modified = tostring(values[5] or "")
  result.source = result.modified ~= "" and "js_file_stat" or "unavailable"
  return result
end

function clear_asset_fingerprint(asset)
  asset.fingerprint = ""
  asset.fingerprint_size = 0
  asset.fingerprint_version = ""
  asset.fingerprint_modified = ""
  asset.fingerprint_stat_source = ""
end

function fingerprint_metadata_is_compatible(asset)
  return tostring(asset.fingerprint or "") ~= ""
    and tostring(asset.fingerprint_version or "")
      == DUPLICATE_FINGERPRINT_VERSION
    and (tonumber(asset.fingerprint_size) or 0) > 0
    and tostring(asset.fingerprint_stat_source or "") == "js_file_stat"
    and tostring(asset.fingerprint_modified or "") ~= ""
end

function fingerprint_metadata_is_current(asset, stat)
  return fingerprint_metadata_is_compatible(asset)
    and tonumber(asset.fingerprint_size) == tonumber(stat.size)
    and stat.source == "js_file_stat"
    and stat.modified ~= ""
    and tostring(asset.fingerprint_modified or "") == stat.modified
end

function record_asset_fingerprint(asset, fingerprint, stat)
  asset.fingerprint = tostring(fingerprint or "")
  asset.fingerprint_size = tonumber(stat.size) or 0
  asset.fingerprint_version = DUPLICATE_FINGERPRINT_VERSION
  asset.fingerprint_modified = tostring(stat.modified or "")
  asset.fingerprint_stat_source = tostring(stat.source or "unavailable")
end

function duplicate_file_stats_match(left, right)
  return left.source == "js_file_stat"
    and right.source == "js_file_stat"
    and left.size == right.size
    and left.modified == right.modified
end

function duplicate_file_changed_since(before, after)
  return before.source == "js_file_stat"
    and not duplicate_file_stats_match(before, after)
end

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
    left_stat = duplicate_file_stat(left_path, left_size),
    right_stat = duplicate_file_stat(right_path, right_size),
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
    local left_changed = duplicate_file_changed_since(
      comparison.left_stat,
      duplicate_file_stat(comparison.left_path, comparison.bytes_compared)
    )
    local right_changed = duplicate_file_changed_since(
      comparison.right_stat,
      duplicate_file_stat(comparison.right_path, comparison.bytes_compared)
    )
    comparison.result = (left_changed or right_changed) and "failed" or "equal"
  else
    comparison.bytes_compared = comparison.bytes_compared + #left_chunk
    return "pending"
  end

  close_duplicate_comparison(comparison)
  return comparison.result
end
