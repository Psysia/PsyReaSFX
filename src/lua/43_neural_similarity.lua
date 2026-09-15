-- Optional neural-similarity bridge.
--
-- The helper is never required for browsing or for the existing 15-feature
-- search. It is used only after an explicit capability handshake succeeds and
-- only for source formats advertised by the installed sidecar. The sidecar
-- decodes, downmixes, and resamples in memory without creating converted audio.
-- Any protocol, process, cache, or result failure returns the active search to
-- the dependency-free similarity implementation.

NeuralSimilarity = {
  profile = "mn04_as_scene_320_v1",
  dimensions = 320,
  protocol_version = 1,
  result_limit = 1000,
  acoustic_weight = 0.25,
  neural_weight = 0.75,
  poll_interval = 0.10,
  capability_timeout = 30,
  job_stall_timeout = 600,
}

local function neural_host_api()
  return Host or reaper
end

function neural_json_escape(value)
  return tostring(value or ""):gsub('[%z\1-\31\\"]', function(character)
    local escapes = {
      ['"'] = '\\"',
      ['\\'] = '\\\\',
      ['\b'] = '\\b',
      ['\f'] = '\\f',
      ['\n'] = '\\n',
      ['\r'] = '\\r',
      ['\t'] = '\\t',
    }
    return escapes[character]
      or string.format("\\u%04x", string.byte(character))
  end)
end

function neural_json_encode(value)
  local kind = type(value)
  if kind == "nil" then return "null" end
  if kind == "boolean" then return value and "true" or "false" end
  if kind == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      error("cannot encode a non-finite JSON number")
    end
    return tostring(value)
  end
  if kind == "string" then return '"' .. neural_json_escape(value) .. '"' end
  if kind ~= "table" then error("unsupported JSON value: " .. kind) end

  local maximum = 0
  local count = 0
  local array = true
  for key in pairs(value) do
    count = count + 1
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      array = false
      break
    end
    maximum = math.max(maximum, key)
  end
  if array and maximum == count then
    local output = {}
    for index = 1, maximum do
      output[index] = neural_json_encode(value[index])
    end
    return "[" .. table.concat(output, ",") .. "]"
  end

  local keys = {}
  for key in pairs(value) do
    if type(key) ~= "string" then error("JSON object keys must be strings") end
    keys[#keys + 1] = key
  end
  table.sort(keys)
  local output = {}
  for _, key in ipairs(keys) do
    output[#output + 1] = neural_json_encode(key)
      .. ":" .. neural_json_encode(value[key])
  end
  return "{" .. table.concat(output, ",") .. "}"
end

function neural_json_decode(text)
  text = tostring(text or "")
  local position = 1
  local length = #text
  local function skip_space()
    local _, last = text:find("^[ \t\r\n]*", position)
    position = (last or position - 1) + 1
  end
  local parse_value
  local function parse_string()
    if text:sub(position, position) ~= '"' then error("expected JSON string") end
    position = position + 1
    local output = {}
    while position <= length do
      local character = text:sub(position, position)
      if character == '"' then
        position = position + 1
        return table.concat(output)
      end
      if character == "\\" then
        local escape = text:sub(position + 1, position + 1)
        local mapped = ({ ['"'] = '"', ['\\'] = '\\', ['/'] = '/',
          b = '\b', f = '\f', n = '\n', r = '\r', t = '\t' })[escape]
        if mapped then
          output[#output + 1] = mapped
          position = position + 2
        elseif escape == "u" then
          local hex = text:sub(position + 2, position + 5)
          local code = tonumber(hex, 16)
          if not code or #hex ~= 4 then error("invalid JSON unicode escape") end
          position = position + 6
          if code >= 0xd800 and code <= 0xdbff then
            if text:sub(position, position + 1) ~= "\\u" then
              error("incomplete JSON surrogate pair")
            end
            local low = tonumber(text:sub(position + 2, position + 5), 16)
            if not low or low < 0xdc00 or low > 0xdfff then
              error("invalid JSON surrogate pair")
            end
            code = 0x10000 + (code - 0xd800) * 0x400 + (low - 0xdc00)
            position = position + 6
          elseif code >= 0xdc00 and code <= 0xdfff then
            error("invalid JSON low surrogate")
          end
          output[#output + 1] = utf8.char(code)
        else
          error("invalid JSON escape")
        end
      else
        if string.byte(character) < 32 then error("invalid JSON string character") end
        output[#output + 1] = character
        position = position + 1
      end
    end
    error("unterminated JSON string")
  end
  local function parse_array()
    position = position + 1
    local output = {}
    skip_space()
    if text:sub(position, position) == "]" then position = position + 1 return output end
    while true do
      output[#output + 1] = parse_value()
      skip_space()
      local character = text:sub(position, position)
      if character == "]" then position = position + 1 return output end
      if character ~= "," then error("expected JSON array separator") end
      position = position + 1
    end
  end
  local function parse_object()
    position = position + 1
    local output = {}
    skip_space()
    if text:sub(position, position) == "}" then position = position + 1 return output end
    while true do
      skip_space()
      local key = parse_string()
      skip_space()
      if text:sub(position, position) ~= ":" then error("expected JSON property separator") end
      position = position + 1
      output[key] = parse_value()
      skip_space()
      local character = text:sub(position, position)
      if character == "}" then position = position + 1 return output end
      if character ~= "," then error("expected JSON object separator") end
      position = position + 1
    end
  end
  function parse_value()
    skip_space()
    local character = text:sub(position, position)
    if character == '"' then return parse_string() end
    if character == "[" then return parse_array() end
    if character == "{" then return parse_object() end
    local literals = { ["true"] = true, ["false"] = false }
    for literal, value in pairs(literals) do
      if text:sub(position, position + #literal - 1) == literal then
        position = position + #literal
        return value
      end
    end
    if text:sub(position, position + 3) == "null" then
      position = position + 4
      return nil
    end
    local first, last = text:find("^-?%d+%.?%d*[eE]?[+-]?%d*", position)
    if not first then error("invalid JSON value") end
    local number = tonumber(text:sub(first, last))
    if not number then error("invalid JSON number") end
    position = last + 1
    return number
  end
  local value = parse_value()
  skip_space()
  if position <= length then error("trailing JSON data") end
  return value
end

function neural_windows_quote_argument(value)
  value = tostring(value or "")
  if value ~= "" and not value:find('[%s"]') then return value end
  local output = {'"'}
  local slashes = 0
  for index = 1, #value do
    local character = value:sub(index, index)
    if character == "\\" then
      slashes = slashes + 1
    elseif character == '"' then
      output[#output + 1] = string.rep("\\", slashes * 2 + 1) .. '"'
      slashes = 0
    else
      if slashes > 0 then output[#output + 1] = string.rep("\\", slashes) end
      output[#output + 1] = character
      slashes = 0
    end
  end
  if slashes > 0 then output[#output + 1] = string.rep("\\", slashes * 2) end
  output[#output + 1] = '"'
  return table.concat(output)
end

local function neural_read_file(path, maximum)
  local file = io.open(path, "rb")
  if not file then return nil end
  local content = file:read((maximum or 2 * 1024 * 1024) + 1) or ""
  file:close()
  if #content > (maximum or 2 * 1024 * 1024) then return nil, "too_large" end
  return content
end

local function neural_write_atomic(path, content)
  local writer, reason = atomic_file_writer(path)
  if not writer then return false, reason end
  local written, write_error = writer:write(content)
  if not written then writer:abort() return false, write_error end
  return writer:close()
end

local function neural_file_exists(path)
  local host = neural_host_api()
  return host and type(host.file_exists) == "function" and host.file_exists(path) or false
end

local function neural_first_file(candidates)
  for _, path in ipairs(candidates) do
    if neural_file_exists(path) then return path end
  end
  return nil
end

function neural_similarity_paths()
  local root = DATA_DIR .. SEP .. "neural_similarity"
  local jobs = root .. SEP .. "jobs"
  local development_output = SCRIPT_DIR .. "neural" .. SEP
    .. "PsyReaSFX.NeuralSidecar" .. SEP .. "bin" .. SEP .. "Release"
    .. SEP .. "net8.0" .. SEP .. "PsyReaSFX.NeuralSidecar.exe"
  local executable = neural_first_file({
    root .. SEP .. "PsyReaSFX.NeuralSidecar.exe",
    SCRIPT_DIR .. "PsyReaSFX.NeuralSidecar.exe",
    development_output,
  })
  local model_candidates = {
    root .. SEP .. "models" .. SEP .. NeuralSimilarity.profile,
    SCRIPT_DIR .. "assets" .. SEP .. "neural" .. SEP .. NeuralSimilarity.profile,
  }
  local model_directory = nil
  for _, directory in ipairs(model_candidates) do
    if neural_file_exists(directory .. SEP .. "manifest-v1.json") then
      model_directory = directory
      break
    end
  end
  return {
    root = root,
    jobs = jobs,
    executable = executable,
    model_directory = model_directory,
    cache = root .. SEP .. "embeddings-" .. NeuralSimilarity.profile .. "-v2.bin",
    index = root .. SEP .. "hnsw-" .. NeuralSimilarity.profile .. "-v2.bin",
    capabilities = root .. SEP .. "capabilities-v1.json",
  }
end

local function neural_launch(arguments)
  local host = neural_host_api()
  if not host or type(host.ExecProcess) ~= "function" then return false, "exec_unavailable" end
  local command = {}
  for _, argument in ipairs(arguments) do
    command[#command + 1] = neural_windows_quote_argument(argument)
  end
  local ok, result = pcall(host.ExecProcess, table.concat(command, " "), -2)
  if not ok or result == nil then return false, tostring(result or "launch_failed") end
  return true
end

local function neural_has_value(values, expected)
  for _, value in ipairs(values or {}) do
    if value == expected then return true end
  end
  return false
end

function neural_validate_capabilities(capabilities)
  if type(capabilities) ~= "table"
    or capabilities.schema ~= "PsyReaSFX-Neural-Capabilities-v1"
    or tonumber(capabilities.protocolVersion) ~= NeuralSimilarity.protocol_version
    or not neural_has_value(capabilities.operations, "run-job")
    or not neural_has_value(capabilities.jobOperations, "build-cache")
    or not neural_has_value(capabilities.jobOperations, "build-index")
    or not neural_has_value(capabilities.jobOperations, "query") then
    return false, "protocol_mismatch"
  end
  for _, profile in ipairs(capabilities.profiles or {}) do
    if profile.profile == NeuralSimilarity.profile
      and tonumber(profile.dimensions) == NeuralSimilarity.dimensions
      and tonumber(profile.sampleRate) == 32000 then
      return true
    end
  end
  return false, "profile_mismatch"
end

function initialize_neural_similarity()
  local host = neural_host_api()
  local paths = neural_similarity_paths()
  AppState.apply({
    neural_similarity_state = "unavailable",
    neural_similarity_reason = "not_installed",
    neural_similarity_paths = paths,
  })
  if state.persistence_read_only then
    AppState.set("neural_similarity_reason", "persistence_read_only")
    return false
  end
  if not host or type(host.GetOS) ~= "function" or not host.GetOS():match("Win") then
    AppState.set("neural_similarity_reason", "unsupported_platform")
    return false
  end
  if not paths.executable or not paths.model_directory then return false end
  if type(host.RecursiveCreateDirectory) ~= "function" then
    AppState.set("neural_similarity_reason", "directory_api_unavailable")
    return false
  end
  host.RecursiveCreateDirectory(paths.root, 0)
  host.RecursiveCreateDirectory(paths.jobs, 0)
  os.remove(paths.capabilities)
  local launched, reason = neural_launch({
    paths.executable,
    "capabilities",
    paths.model_directory,
    paths.capabilities,
  })
  if not launched then
    AppState.set("neural_similarity_reason", reason)
    return false
  end
  AppState.apply({
    neural_similarity_state = "probing",
    neural_similarity_reason = "",
    neural_similarity_probe_started = host.time_precise(),
  })
  return true
end

function process_neural_similarity_probe()
  if state.neural_similarity_state ~= "probing" then return end
  local host = neural_host_api()
  local paths = state.neural_similarity_paths
  if neural_file_exists(paths.capabilities) then
    local content, read_error = neural_read_file(paths.capabilities, 64 * 1024)
    local ok, capabilities = pcall(neural_json_decode, content or "")
    local valid = false
    local reason = read_error or "invalid_capabilities"
    if ok then valid, reason = neural_validate_capabilities(capabilities) end
    if valid then
      AppState.apply({
        neural_similarity_state = "available",
        neural_similarity_reason = "",
        neural_similarity_capabilities = capabilities,
      })
    else
      AppState.apply({
        neural_similarity_state = "unavailable",
        neural_similarity_reason = reason,
      })
    end
    return
  end
  if host.time_precise() - (state.neural_similarity_probe_started or 0)
      > NeuralSimilarity.capability_timeout then
    AppState.apply({
      neural_similarity_state = "unavailable",
      neural_similarity_reason = "capability_timeout",
    })
  end
end

function neural_similarity_asset_supported(asset)
  local source_type = tostring(asset and asset.source_type or ""):lower()
  local path = tostring(asset and asset.path or ""):lower()
  if not (asset and asset.ready and path ~= "") then return false end
  local extension = path:match("%.([^%.\\/]+)$") or source_type
  if extension == "wave" then extension = "wav" end
  local profile = nil
  for _, candidate in ipairs(
      state.neural_similarity_capabilities
      and state.neural_similarity_capabilities.profiles or {}) do
    if candidate.profile == NeuralSimilarity.profile then
      profile = candidate
      break
    end
  end
  if profile and tonumber(profile.decoderVersion or 0) >= 1 then
    for _, supported in ipairs(profile.supportedExtensions or {}) do
      if tostring(supported):lower() == extension then return true end
    end
    return false
  end
  local is_wave = extension == "wav"
  return is_wave
    and tonumber(asset.sample_rate) == 32000
    and tonumber(asset.bit_depth) == 16
end

local function neural_add_prepared_asset(session, asset)
  if not asset then return true end
  if not asset.ready then return false end
  if not neural_similarity_asset_supported(asset) then return false end
  local signature = similarity_asset_signature(asset)
  if signature == "" then return false end
  if not session.neural_signatures[signature] then
    session.neural_signatures[signature] = true
    session.neural_assets_by_signature[signature] = asset
    session.neural_assets[#session.neural_assets + 1] = asset
  end
  return true
end

local function neural_request_id()
  local host = neural_host_api()
  return string.format("lua-%d-%08x", os.time(),
    math.floor((host.time_precise() % 1) * 0xffffffff))
end

local function neural_job_paths(paths, request_id, operation)
  local prefix = paths.jobs .. SEP .. request_id .. "-" .. operation
  return {
    request = prefix .. ".request.json",
    status = prefix .. ".status.json",
    result = prefix .. ".result.json",
    cancel = prefix .. ".cancel",
    assets = prefix .. ".assets.tsv",
    candidates = prefix .. ".candidates.txt",
  }
end

local function neural_start_job(session, operation, extra)
  local paths = state.neural_similarity_paths
  local job_paths = neural_job_paths(paths, session.neural_request_id, operation)
  os.remove(job_paths.status)
  os.remove(job_paths.result)
  os.remove(job_paths.cancel)
  local request = {
    schema = "PsyReaSFX-Neural-Job-v1",
    requestId = session.neural_request_id .. "-" .. operation,
    operation = operation,
    cachePath = paths.cache,
    indexPath = paths.index,
    statusPath = job_paths.status,
    resultPath = job_paths.result,
    cancelPath = job_paths.cancel,
  }
  for key, value in pairs(extra or {}) do request[key] = value end
  local written, reason = neural_write_atomic(
    job_paths.request,
    neural_json_encode(request) .. "\n"
  )
  if not written then return false, reason end
  local launched, launch_error = neural_launch({
    paths.executable,
    "run-job",
    paths.model_directory,
    job_paths.request,
  })
  if not launched then return false, launch_error end
  session.neural_job = {
    operation = operation,
    request_id = request.requestId,
    paths = job_paths,
    started = neural_host_api().time_precise(),
    last_change = neural_host_api().time_precise(),
    last_status = "",
    next_poll = 0,
  }
  session.phase = "neural_wait"
  return true
end

local function neural_cleanup_job(job, include_result, keep_cancel)
  if not job or not job.paths then return end
  os.remove(job.paths.request)
  os.remove(job.paths.status)
  if not keep_cancel then os.remove(job.paths.cancel) end
  if include_result then os.remove(job.paths.result) end
  os.remove(job.paths.assets)
  os.remove(job.paths.candidates)
end

function neural_write_lines_atomic(path, lines)
  local temporary_path = path .. ".tmp"
  os.remove(temporary_path)
  local file, reason = io.open(temporary_path, "wb")
  if not file then return false, reason end
  for _, line in ipairs(lines) do
    local written, write_error = file:write(line)
    if not written then
      file:close()
      os.remove(temporary_path)
      return false, write_error
    end
  end
  local flushed, flush_error = file:flush()
  local closed, close_error = file:close()
  if not flushed or not closed then
    os.remove(temporary_path)
    return false, flush_error or close_error
  end
  os.remove(path)
  local installed, install_error = os.rename(temporary_path, path)
  if not installed then
    os.remove(temporary_path)
    return false, install_error
  end
  return true
end

local function neural_begin_asset_manifest(session)
  local paths = neural_job_paths(
    state.neural_similarity_paths,
    session.neural_request_id,
    "build-cache"
  )
  local temporary_path = paths.assets .. ".tmp"
  os.remove(temporary_path)
  local file, reason = io.open(temporary_path, "wb")
  if not file then return nil, reason end
  session.neural_manifest = {
    path = paths.assets,
    temporary_path = temporary_path,
    file = file,
    index = 1,
  }
  return paths.assets
end

local function neural_abort_manifest(session)
  local manifest = session and session.neural_manifest
  if not manifest then return end
  if manifest.file then pcall(function() manifest.file:close() end) end
  os.remove(manifest.temporary_path)
  session.neural_manifest = nil
end

local function neural_finish_manifest(session)
  local manifest = session.neural_manifest
  local flushed, flush_error = manifest.file:flush()
  local closed, close_error = manifest.file:close()
  manifest.file = nil
  if not flushed or not closed then
    neural_abort_manifest(session)
    return nil, flush_error or close_error
  end
  os.remove(manifest.path)
  local installed, install_error = os.rename(
    manifest.temporary_path,
    manifest.path
  )
  if not installed then
    neural_abort_manifest(session)
    return nil, install_error
  end
  session.neural_manifest = nil
  return manifest.path
end

local neural_begin_query

function neural_similarity_try_start(session)
  session.neural_attempted = true
  if state.neural_similarity_state ~= "available" then return false end
  if state.persistence_read_only then return false end
  session.neural_request_id = neural_request_id()
  session.neural_assets_by_signature = {}
  session.neural_signatures = {}
  session.neural_assets = {}
  session.neural_prepare_index = 1
  if not neural_add_prepared_asset(session, session.reference) then
    return false
  end
  session.phase = "neural_prepare"
  set_status(string.format("正在准备神经相似度范围：0 / %d", session.total))
  return true
end

function neural_similarity_cancel(session)
  local job = session and session.neural_job
  if not job then return false end
  local file = io.open(job.paths.cancel, "wb")
  if not file then return false end
  file:write("cancel\n")
  file:close()
  return true
end

function neural_similarity_cleanup_session(session, keep_cancel)
  neural_abort_manifest(session)
  neural_cleanup_job(session and session.neural_job, true, keep_cancel)
end

local function neural_fallback(session, reason)
  neural_similarity_cancel(session)
  neural_similarity_cleanup_session(session, true)
  session.neural_failure = tostring(reason or "unknown")
  session.neural_job = nil
  session.neural_assets = nil
  session.neural_signatures = nil
  session.neural_assets_by_signature = nil
  session.phase = "reference"
  set_status("神经相似度不可用，已回退到基础声学检索")
end

local function neural_parse_job_file(path, maximum)
  local content, read_error = neural_read_file(path, maximum)
  if not content then return nil, read_error or "read_failed" end
  local ok, value = pcall(neural_json_decode, content)
  if not ok or type(value) ~= "table" then return nil, "invalid_json" end
  return value, nil, content
end

local function neural_write_query_candidates(session)
  local mode = session.scope == "all" and "auto" or "exact"
  if mode == "auto" then return nil end
  local paths = neural_job_paths(
    state.neural_similarity_paths,
    session.neural_request_id,
    "query"
  )
  local signatures = {}
  for signature in pairs(session.neural_assets_by_signature or {}) do
    signatures[#signatures + 1] = signature
  end
  table.sort(signatures)
  for index, signature in ipairs(signatures) do
    signatures[index] = signature .. "\n"
  end
  local written, write_error = neural_write_lines_atomic(
    paths.candidates,
    signatures
  )
  if not written then return nil, write_error end
  return paths.candidates
end

neural_begin_query = function(session)
  local candidates, candidates_error = neural_write_query_candidates(session)
  if candidates_error then return false, candidates_error end
  local request = {
    referenceSignature = session.reference_signature,
    topK = NeuralSimilarity.result_limit,
    searchMode = session.scope == "all" and "auto" or "exact",
    efSearch = 800,
  }
  if candidates then request.candidateSignaturesFile = candidates end
  return neural_start_job(session, "query", request)
end

local function neural_accept_query_result(session, result)
  if result.schema ~= "PsyReaSFX-Neural-Job-Result-v1"
    or result.requestId ~= session.neural_job.request_id
    or result.operation ~= "query"
    or result.profile ~= NeuralSimilarity.profile
    or tonumber(result.dimensions) ~= NeuralSimilarity.dimensions
    or result.cancelled == true
    or type(result.matches) ~= "table" then
    return false, "invalid_query_result"
  end
  local matches = {}
  for _, match in ipairs(result.matches) do
    local signature = tostring(match.signature or "")
    local score = tonumber(match.score)
    local asset = session.neural_assets_by_signature[signature]
    if asset and score and score == score and score >= -1.000001 and score <= 1.000001 then
      matches[#matches + 1] = {
        asset = asset,
        signature = signature,
        neural_score = math.max(-1, math.min(1, score)),
      }
    end
  end
  session.neural_matches = matches
  if #matches == 0 then return false, "empty_query_result" end
  session.neural_match_index = 1
  session.neural_job = nil
  session.phase = "neural_rerank"
  return true
end

local function neural_complete_job(session, result)
  local completed_job = session.neural_job
  local operation = completed_job.operation
  if result.schema ~= "PsyReaSFX-Neural-Job-Result-v1"
    or result.requestId ~= completed_job.request_id
    or result.operation ~= operation
    or result.profile ~= NeuralSimilarity.profile
    or tonumber(result.dimensions) ~= NeuralSimilarity.dimensions
    or result.cancelled == true then
    neural_fallback(session, "invalid_" .. operation .. "_result")
    return
  end
  neural_cleanup_job(completed_job, true)
  if operation == "build-cache" then
    os.remove(completed_job.paths.assets)
    local written = tonumber(result.written)
    if not written or written < 1 or written > session.neural_asset_count then
      neural_fallback(session, "incomplete_embedding_cache")
      return
    end
    session.neural_decode_failed = math.max(
      tonumber(result.failed) or 0,
      session.neural_asset_count - written
    )
    if session.scope == "all"
      and (not neural_file_exists(state.neural_similarity_paths.index)
        or result.cacheChanged == true) then
      local started = neural_start_job(session, "build-index", {
        m = 16,
        efConstruction = 128,
      })
      if not started then
        local query_started, query_error = neural_begin_query(session)
        if not query_started then neural_fallback(session, query_error) end
      else
        set_status("正在建立神经相似度索引…")
      end
    else
      local started, reason = neural_begin_query(session)
      if not started then neural_fallback(session, reason) end
    end
  elseif operation == "build-index" then
    local started, reason = neural_begin_query(session)
    if not started then neural_fallback(session, reason) end
  elseif operation == "query" then
    os.remove(completed_job.paths.candidates)
    local accepted, reason = neural_accept_query_result(session, result)
    if not accepted then neural_fallback(session, reason) end
  end
end

local function neural_process_wait(session)
  local job = session.neural_job
  if not job then neural_fallback(session, "missing_job") return end
  local host = neural_host_api()
  local now = host.time_precise()
  if now < (job.next_poll or 0) then return end
  job.next_poll = now + NeuralSimilarity.poll_interval
  if neural_file_exists(job.paths.status) then
    local status, reason, content = neural_parse_job_file(job.paths.status, 64 * 1024)
    if not status then neural_fallback(session, reason) return end
    if content ~= job.last_status then
      job.last_status = content
      job.last_change = now
    end
    if status.schema ~= "PsyReaSFX-Neural-Job-Status-v1"
      or status.requestId ~= job.request_id
      or status.operation ~= job.operation then
      neural_fallback(session, "invalid_status")
      return
    end
    if status.state == "failed" then
      if job.operation == "build-index" then
        neural_cleanup_job(job, true)
        local started, start_error = neural_begin_query(session)
        if not started then neural_fallback(session, start_error or status.error) end
      else
        neural_fallback(session, status.error)
      end
      return
    end
    if status.state == "cancelled" then neural_fallback(session, "cancelled") return end
    if status.state == "completed" then
      if not neural_file_exists(job.paths.result) then
        neural_fallback(session, "missing_result")
        return
      end
      local result, result_error = neural_parse_job_file(
        job.paths.result,
        2 * 1024 * 1024
      )
      if not result then neural_fallback(session, result_error) return end
      neural_complete_job(session, result)
      return
    end
    local completed = tonumber(status.completed) or 0
    local total = tonumber(status.total) or 0
    if total > 0 then
      local phase = ({
        ["building-cache"] = "建立缓存",
        ["building-index"] = "建立索引",
        ["querying-hnsw"] = "HNSW 查询",
        ["querying-exact"] = "精确查询",
        ["querying-exact-filtered"] = "范围内精确查询",
      })[status.phase] or tostring(status.phase or job.operation)
      set_status(string.format("神经相似度 %s：%d / %d",
        phase, completed, total))
    end
  end
  if now - (job.last_change or job.started) > NeuralSimilarity.job_stall_timeout then
    neural_similarity_cancel(session)
    neural_fallback(session, "job_stalled")
  end
end

local function neural_process_prepare(session)
  if not can_run_heavy_job() then return end
  local host = neural_host_api()
  local processed = 0
  local deadline = host.time_precise() + Similarity.frame_budget
  while session.neural_prepare_index <= session.total
    and processed < Similarity.frame_records
    and (processed == 0 or host.time_precise() < deadline) do
    local asset = session.source[session.neural_prepare_index]
    if not neural_add_prepared_asset(session, asset) then
      neural_fallback(session, "candidate_format")
      return
    end
    session.neural_prepare_index = session.neural_prepare_index + 1
    processed = processed + 1
  end
  if session.neural_prepare_index <= session.total then
    set_status(string.format(
      "正在准备神经相似度范围：%d / %d",
      session.neural_prepare_index - 1,
      session.total
    ))
    return
  end
  session.neural_asset_count = #session.neural_assets
  if session.scope ~= "all" then
    local started, start_error = neural_begin_query(session)
    if not started then neural_fallback(session, start_error) end
    return
  end
  local assets_file, reason = neural_begin_asset_manifest(session)
  if not assets_file then neural_fallback(session, reason) return end
  session.phase = "neural_manifest"
end

local function neural_process_manifest(session)
  if not can_run_heavy_job() then return end
  local manifest = session.neural_manifest
  if not manifest or not manifest.file then
    neural_fallback(session, "missing_manifest")
    return
  end
  local host = neural_host_api()
  local processed = 0
  local deadline = host.time_precise() + Similarity.frame_budget
  while manifest.index <= session.neural_asset_count
    and processed < Similarity.frame_records
    and (processed == 0 or host.time_precise() < deadline) do
    local asset = session.neural_assets[manifest.index]
    local size = tonumber(asset.size) or 0
    if size <= 0 then size = file_size(asset.path) asset.size = size end
    if size <= 0 then neural_fallback(session, "asset_size") return end
    local written, write_error = manifest.file:write(table.concat({
      similarity_asset_signature(asset),
      "\t", tostring(math.floor(size)),
      "\t-1\t", neural_json_encode(asset.path), "\n",
    }))
    if not written then neural_fallback(session, write_error) return end
    manifest.index = manifest.index + 1
    processed = processed + 1
  end
  if manifest.index <= session.neural_asset_count then
    set_status(string.format(
      "正在写入神经相似度清单：%d / %d",
      manifest.index - 1,
      session.neural_asset_count
    ))
    return
  end
  local assets_file, reason = neural_finish_manifest(session)
  if not assets_file then neural_fallback(session, reason) return end
  local started, start_error = neural_start_job(session, "build-cache", {
    assetsFile = assets_file,
  })
  if not started then neural_fallback(session, start_error) return end
  set_status(string.format(
    "正在建立神经相似度缓存：0 / %d",
    session.neural_asset_count
  ))
end

local function neural_process_rerank(session)
  if not can_run_heavy_job() then return end
  local processed = 0
  local deadline = neural_host_api().time_precise() + Similarity.frame_budget
  while session.neural_match_index <= #session.neural_matches
    and processed < Similarity.frame_records
    and (processed == 0 or neural_host_api().time_precise() < deadline) do
    local match = session.neural_matches[session.neural_match_index]
    session.current = match.asset
    local features, _, status = similarity_features_for_asset(
      session,
      match.asset,
      true
    )
    if status == "waiting" then break end
    session.neural_match_index = session.neural_match_index + 1
    processed = processed + 1
    if features then
      local packed = type(features) == "string" and features
        or similarity_pack_features(features)
      local acoustic_score = similarity_compare_encoded(
        session.reference_features,
        packed
      )
      local normalized_neural = (match.neural_score + 1) * 0.5
      local combined = normalized_neural * NeuralSimilarity.neural_weight
        + acoustic_score * NeuralSimilarity.acoustic_weight
      local entry = similarity_insert_ranked(
        session,
        match.asset,
        combined,
        packed
      )
      if entry then
        entry.neural_score = match.neural_score
        entry.acoustic_score = acoustic_score
      end
    else
      session.failed = session.failed + 1
    end
  end
  if session.neural_match_index > #session.neural_matches then
    session.neural_used = true
    finish_similarity_search(false)
  end
end

function process_neural_similarity_search(session)
  if session.phase == "neural_prepare" then
    neural_process_prepare(session)
    return true
  end
  if session.phase == "neural_manifest" then
    neural_process_manifest(session)
    return true
  end
  if session.phase == "neural_wait" then
    neural_process_wait(session)
    return true
  end
  if session.phase == "neural_rerank" then
    neural_process_rerank(session)
    return true
  end
  return false
end
