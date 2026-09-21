-- Optional AI semantic search service.
--
-- This is deliberately separate from audio-content similarity. It asks an
-- OpenAI-compatible chat-completions endpoint to expand a natural-language
-- sound request, recalls a bounded candidate set from local text metadata,
-- then ranks the bounded candidate set locally. Candidate metadata and audio
-- are never uploaded. On Windows, API keys are encrypted for the current user by
-- DPAPI and are never written to config.tsv, backups, logs, or command lines.

AISemantic = {
  schema = "PsyReaSFX-AI-Semantic-v1",
  candidate_page_size = 120,
  candidate_pool_limit = 2400,
  result_page_limit = 120,
  frame_records = 12000,
  frame_budget = 0.008,
  poll_interval = 0.10,
  request_timeout = 90,
}

function ai_semantic_paths()
  local root = DATA_DIR .. SEP .. "ai_semantic"
  return {
    root = root,
    jobs = root .. SEP .. "jobs",
    bridge = root .. SEP .. "PsyReaSFX-AIBridge.ps1",
    secret = root .. SEP .. "api-key.dpapi",
    plaintext = root .. SEP .. "api-key-plaintext.tmp",
  }
end

function ai_semantic_read_file(path, maximum)
  local file = io.open(path, "rb")
  if not file then return nil end
  local limit = maximum or 4 * 1024 * 1024
  local content = file:read(limit + 1) or ""
  file:close()
  if #content > limit then return nil, "too_large" end
  return content
end

function ai_semantic_write_atomic(path, content)
  local temporary_path = path .. ".tmp"
  local backup_path = path .. ".bak"
  os.remove(temporary_path)
  local writer, open_error = io.open(temporary_path, "wb")
  if not writer then return false, open_error end
  local written, write_error = writer:write(content)
  local flushed, flush_error = writer:flush()
  local closed, close_error = writer:close()
  if not written or not flushed or not closed then
    os.remove(temporary_path)
    return false, write_error or flush_error or close_error or "write_failed"
  end
  local committed = commit_atomic_temporary(
    path,
    temporary_path,
    backup_path
  )
  if not committed then
    os.remove(temporary_path)
    return false, "could_not_install_completed_file"
  end
  return true
end

function ai_semantic_bridge_source()
  return [=[param([Parameter(Mandatory=$true)][string]$RequestPath)
$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
Add-Type -AssemblyName System.Security

function Write-Utf8Atomic([string]$Path, [string]$Content) {
  $Temporary = "$Path.tmp"
  [IO.File]::WriteAllText($Temporary, $Content, $Utf8NoBom)
  Move-Item -LiteralPath $Temporary -Destination $Path -Force
}

function Write-Status([string]$Path, [hashtable]$Value) {
  Write-Utf8Atomic $Path ($Value | ConvertTo-Json -Compress -Depth 8)
}

$Request = Get-Content -LiteralPath $RequestPath -Raw -Encoding UTF8 | ConvertFrom-Json
try {
  Write-Status ([string]$Request.statusPath) @{ state = 'running'; pid = $PID }
  if ($Request.operation -eq 'protect-key') {
    $Plain = [IO.File]::ReadAllText([string]$Request.plaintextPath, [Text.Encoding]::UTF8)
    $PlainBytes = [Text.Encoding]::UTF8.GetBytes($Plain)
    try {
      $EncryptedBytes = [System.Security.Cryptography.ProtectedData]::Protect(
        $PlainBytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
      Write-Utf8Atomic ([string]$Request.secretPath) ([Convert]::ToBase64String($EncryptedBytes))
    } finally {
      if ($PlainBytes) { [Array]::Clear($PlainBytes, 0, $PlainBytes.Length) }
      if ($EncryptedBytes) { [Array]::Clear($EncryptedBytes, 0, $EncryptedBytes.Length) }
      $Plain = $null
    }
    Write-Status ([string]$Request.statusPath) @{ state = 'complete' }
    exit 0
  }

  if ($Request.operation -ne 'chat-completions') {
    throw 'Unsupported AI bridge operation.'
  }

  $Headers = @{}
  if ($Request.secretPath -and (Test-Path -LiteralPath ([string]$Request.secretPath))) {
    $Encrypted = Get-Content -LiteralPath ([string]$Request.secretPath) -Raw -Encoding UTF8
    $EncryptedBytes = [Convert]::FromBase64String($Encrypted.Trim())
    $PlainBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
      $EncryptedBytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    try {
      $ApiKey = [Text.Encoding]::UTF8.GetString($PlainBytes).Trim()
      if ($ApiKey) { $Headers.Authorization = "Bearer $ApiKey" }
    } finally {
      if ($PlainBytes) { [Array]::Clear($PlainBytes, 0, $PlainBytes.Length) }
      if ($EncryptedBytes) { [Array]::Clear($EncryptedBytes, 0, $EncryptedBytes.Length) }
      $ApiKey = $null
    }
  }

  $Body = [IO.File]::ReadAllText([string]$Request.bodyPath, [Text.Encoding]::UTF8)
  $Response = Invoke-WebRequest -UseBasicParsing -Method Post `
    -Uri ([string]$Request.url) -Headers $Headers `
    -Body ([Text.Encoding]::UTF8.GetBytes($Body)) `
    -ContentType 'application/json; charset=utf-8' `
    -TimeoutSec ([int]$Request.timeoutSeconds)
  Write-Utf8Atomic ([string]$Request.responsePath) ([string]$Response.Content)
  Write-Status ([string]$Request.statusPath) @{ state = 'complete'; statusCode = [int]$Response.StatusCode }
} catch {
  $Message = [string]$_.Exception.Message
  if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
    $Message = "$Message $($_.ErrorDetails.Message)"
  }
  $Message = $Message -replace '(?i)Bearer\s+[^\s"'']+', 'Bearer [redacted]'
  Write-Status ([string]$Request.statusPath) @{ state = 'error'; message = $Message }
  exit 1
} finally {
  if ($Request.plaintextPath) {
    Remove-Item -LiteralPath ([string]$Request.plaintextPath) -Force -ErrorAction SilentlyContinue
  }
}]=]
end

function ai_semantic_initialize()
  local paths = ai_semantic_paths()
  AppState.apply({
    ai_semantic_paths = paths,
    ai_semantic_available = false,
    ai_semantic_unavailable_reason = "unsupported_platform",
    ai_api_key_saved = false,
  })
  local host = Host
  if not host or type(host.GetOS) ~= "function"
    or not tostring(host.GetOS()):match("Win") then
    return false
  end
  if type(host.ExecProcess) ~= "function"
    or type(host.RecursiveCreateDirectory) ~= "function" then
    AppState.set("ai_semantic_unavailable_reason", "host_api_unavailable")
    return false
  end
  host.RecursiveCreateDirectory(paths.root, 0)
  host.RecursiveCreateDirectory(paths.jobs, 0)
  -- A terminated save attempt must never leave plaintext credentials behind.
  os.remove(paths.plaintext)
  os.remove(paths.plaintext .. ".tmp")
  os.remove(paths.plaintext .. ".bak")
  if type(host.EnumerateFiles) == "function" then
    local stale_files = {}
    local index = 0
    while true do
      local filename = host.EnumerateFiles(paths.jobs, index)
      if not filename then break end
      stale_files[#stale_files + 1] = filename
      index = index + 1
    end
    for _, filename in ipairs(stale_files) do
      os.remove(paths.jobs .. SEP .. filename)
    end
  end
  local bridge_ok = ai_semantic_write_atomic(
    paths.bridge,
    ai_semantic_bridge_source()
  )
  if not bridge_ok then
    AppState.set("ai_semantic_unavailable_reason", "bridge_write_failed")
    return false
  end
  AppState.apply({
    ai_semantic_available = true,
    ai_semantic_unavailable_reason = "",
    ai_api_key_saved = host.file_exists(paths.secret),
  })
  return true
end

function ai_semantic_provider_defaults(provider)
  if provider == "openai" then
    return "https://api.openai.com/v1/chat/completions", "gpt-4.1-mini"
  elseif provider == "custom" then
    return "", ""
  end
  return "https://api.deepseek.com/chat/completions", "deepseek-flash"
end

function ai_semantic_migrate_legacy_settings()
  if state.ai_provider ~= "deepseek" then return false end
  local legacy_models = {
    ["deepseek-chat"] = "deepseek-flash",
    ["deepseek-reasoner"] = "deepseek-v4-pro",
  }
  local replacement = legacy_models[trim(state.ai_model or "")]
  if not replacement then return false end
  AppState.apply({ ai_model = replacement, config_dirty = true })
  return true
end

function ai_semantic_validate_endpoint(url)
  url = trim(url or "")
  if url:match("^https://") then return true end
  if url:match("^http://127%.0%.0%.1[:/]")
    or url:match("^http://localhost[:/]")
    or url:match("^http://%[::1%][:/]") then
    return true
  end
  return false, "API 地址必须使用 HTTPS；本机 127.0.0.1/localhost 可使用 HTTP"
end

function ai_semantic_key_required()
  local url = safe_lower(trim(state.ai_api_url or ""))
  return not (url:match("^http://127%.0%.0%.1[:/]")
    or url:match("^http://localhost[:/]")
    or url:match("^http://%[::1%][:/]"))
end

function ai_semantic_unique_job_path(prefix, extension)
  AppState.set("ai_request_sequence", (state.ai_request_sequence or 0) + 1)
  local stamp = math.floor((Host.time_precise() or 0) * 1000)
  return state.ai_semantic_paths.jobs .. SEP
    .. prefix .. "-" .. tostring(stamp) .. "-"
    .. tostring(state.ai_request_sequence) .. (extension or "")
end

function ai_semantic_launch_bridge(request, synchronous)
  local host = Host
  local request_path = ai_semantic_unique_job_path("request", ".json")
  local status_path = ai_semantic_unique_job_path("status", ".json")
  request.statusPath = status_path
  local ok, reason = ai_semantic_write_atomic(
    request_path,
    neural_json_encode(request)
  )
  if not ok then return nil, tostring(reason or "request_write_failed") end
  local command = table.concat({
    neural_windows_quote_argument("powershell.exe"),
    "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
    "-File", neural_windows_quote_argument(state.ai_semantic_paths.bridge),
    neural_windows_quote_argument(request_path),
  }, " ")
  local launched, result = pcall(
    host.ExecProcess,
    command,
    synchronous and 15000 or -2
  )
  if not launched or result == nil then
    os.remove(request_path)
    return nil, tostring(result or "launch_failed")
  end
  return {
    request_path = request_path,
    status_path = status_path,
    started = host.time_precise(),
  }
end

function ai_semantic_read_status(job)
  local content = ai_semantic_read_file(job.status_path, 256 * 1024)
  if not content then return nil end
  local ok, status = pcall(neural_json_decode, content)
  if not ok or type(status) ~= "table" then
    return { state = "error", message = "AI 状态文件无效" }
  end
  return status
end

function ai_semantic_cleanup_job(job)
  if not job then return end
  os.remove(job.request_path or "")
  os.remove(job.status_path or "")
  os.remove(job.body_path or "")
  os.remove(job.response_path or "")
  os.remove(job.plaintext_path or "")
  if job.plaintext_path then
    os.remove(job.plaintext_path .. ".tmp")
    os.remove(job.plaintext_path .. ".bak")
  end
end

function ai_semantic_stop_job_process(job)
  if not job then return end
  local status = ai_semantic_read_status(job)
  local pid = status and math.floor(tonumber(status.pid) or 0) or 0
  if pid <= 0 then return end
  pcall(
    Host.ExecProcess,
    "powershell.exe -NoLogo -NoProfile -NonInteractive -Command "
      .. neural_windows_quote_argument(
        "Stop-Process -Id " .. tostring(pid) .. " -Force -ErrorAction SilentlyContinue"
      ),
    -1
  )
end

function ai_semantic_save_api_key(value)
  local function fail(reason)
    reason = tostring(reason or "无法加密保存 API Key")
    AppState.apply({
      ai_api_key_status = "保存失败：" .. reason,
      ai_api_key_status_error = true,
    })
    return false, reason
  end

  value = trim(value or "")
  if value == "" then return fail("API Key 不能为空") end
  if not state.ai_semantic_available then
    return fail("AI 语义搜索在当前环境不可用")
  end
  AppState.apply({
    ai_api_key_status = "正在使用 Windows DPAPI 加密保存…",
    ai_api_key_status_error = false,
  })
  local plaintext_path = state.ai_semantic_paths.plaintext
  os.remove(plaintext_path)
  local ok, reason = ai_semantic_write_atomic(plaintext_path, value)
  if not ok then return fail(reason or "key_write_failed") end
  local job, launch_reason = ai_semantic_launch_bridge({
    operation = "protect-key",
    plaintextPath = plaintext_path,
    secretPath = state.ai_semantic_paths.secret,
  }, true)
  if not job then
    os.remove(plaintext_path)
    return fail(launch_reason)
  end
  job.plaintext_path = plaintext_path
  local status = ai_semantic_read_status(job)
  ai_semantic_cleanup_job(job)
  os.remove(plaintext_path)
  if not status or status.state ~= "complete" then
    return fail(status and status.message or "无法加密保存 API Key")
  end
  local encrypted = ai_semantic_read_file(state.ai_semantic_paths.secret, 64 * 1024)
  if not encrypted or trim(encrypted) == "" then
    return fail("加密文件未生成，请检查 REAPER 对脚本目录的写入权限")
  end
  AppState.apply({
    ai_api_key_saved = true,
    ai_api_key_input = "",
    ai_api_key_status = "API Key 已安全保存",
    ai_api_key_status_error = false,
  })
  return true
end

function ai_semantic_delete_api_key()
  if not state.ai_semantic_paths then return false end
  os.remove(state.ai_semantic_paths.secret)
  AppState.apply({
    ai_api_key_saved = false,
    ai_api_key_input = "",
    ai_api_key_status = "已删除保存的 API Key",
    ai_api_key_status_error = false,
  })
  return true
end

function ai_semantic_clear_results()
  AppState.apply({
    ai_semantic_lookup = {},
    ai_semantic_result_count = 0,
    ai_semantic_last_query = "",
    ai_semantic_last_summary = "",
    ai_semantic_paging = nil,
    ai_semantic_has_more = false,
    ai_semantic_loaded_candidates = 0,
    ai_semantic_total_candidates = 0,
  })
  if "ai_semantic" == state.view then
    AppState.apply({ view = "all", sort_mode = "name", sort_desc = false })
  end
  AppState.mark_dirty("results_dirty")
end

function ai_semantic_chat_body(system_prompt, user_prompt, maximum_tokens)
  local provider = state.ai_provider
  local body = {
    model = trim(state.ai_model or ""),
    messages = {
      { role = "system", content = system_prompt },
      { role = "user", content = user_prompt },
    },
    temperature = 0.1,
    max_tokens = maximum_tokens or 1200,
  }
  if provider == "deepseek" then
    -- Current DeepSeek models enable thinking by default. Structured search
    -- planning is more reliable and uses fewer tokens with thinking disabled.
    body.thinking = { type = "disabled" }
  end
  if provider ~= "custom" then
    body.response_format = { type = "json_object" }
  end
  return neural_json_encode(body)
end

function ai_semantic_start_api_job(kind, system_prompt, user_prompt, maximum_tokens)
  local valid, reason = ai_semantic_validate_endpoint(state.ai_api_url)
  if not valid then return nil, reason end
  if trim(state.ai_model or "") == "" then return nil, "请先填写模型名称" end
  if ai_semantic_key_required() and not state.ai_api_key_saved then
    return nil, "请先在设置中保存 API Key"
  end
  local body_path = ai_semantic_unique_job_path(kind .. "-body", ".json")
  local response_path = ai_semantic_unique_job_path(kind .. "-response", ".json")
  local body_ok, body_reason = ai_semantic_write_atomic(
    body_path,
    ai_semantic_chat_body(system_prompt, user_prompt, maximum_tokens)
  )
  if not body_ok then return nil, tostring(body_reason or "body_write_failed") end
  local job, launch_reason = ai_semantic_launch_bridge({
    operation = "chat-completions",
    url = trim(state.ai_api_url or ""),
    secretPath = state.ai_api_key_saved and state.ai_semantic_paths.secret or "",
    bodyPath = body_path,
    responsePath = response_path,
    timeoutSeconds = AISemantic.request_timeout,
  }, false)
  if not job then
    os.remove(body_path)
    return nil, launch_reason
  end
  job.kind = kind
  job.body_path = body_path
  job.response_path = response_path
  return job
end

function ai_semantic_decode_content_json(content)
  content = trim(content or "")
  if content == "" then return nil end
  content = content:gsub("^```[%w_-]*%s*", ""):gsub("%s*```$", "")
  local decoded_ok, decoded = pcall(neural_json_decode, content)
  if decoded_ok and type(decoded) == "table" then return decoded end

  local depth = 0
  local start_index = nil
  local quoted = false
  local escaped = false
  for index = 1, #content do
    local byte = content:byte(index)
    if quoted then
      if escaped then
        escaped = false
      elseif byte == 92 then
        escaped = true
      elseif byte == 34 then
        quoted = false
      end
    elseif byte == 34 then
      quoted = true
    elseif byte == 123 then
      if depth == 0 then start_index = index end
      depth = depth + 1
    elseif byte == 125 and depth > 0 then
      depth = depth - 1
      if depth == 0 and start_index then
        local candidate = content:sub(start_index, index)
        local candidate_ok, candidate_value = pcall(neural_json_decode, candidate)
        if candidate_ok and type(candidate_value) == "table" then
          return candidate_value
        end
        start_index = nil
      end
    end
  end
  return nil
end

function ai_semantic_message_content(message)
  if type(message) ~= "table" then return nil end
  if type(message.content) == "string" then return message.content end
  if type(message.content) ~= "table" then return nil end
  local parts = {}
  for _, block in ipairs(message.content) do
    if type(block) == "string" then
      parts[#parts + 1] = block
    elseif type(block) == "table" and type(block.text) == "string" then
      parts[#parts + 1] = block.text
    end
  end
  return #parts > 0 and table.concat(parts, "\n") or nil
end

function ai_semantic_extract_content(response_text)
  local ok, response = pcall(neural_json_decode, response_text or "")
  if not ok or type(response) ~= "table" then
    return nil, "API 返回的 JSON 无效"
  end
  if type(response.error) == "table" then
    return nil, tostring(response.error.message or "API 请求失败")
  end
  local choice = type(response.choices) == "table" and response.choices[1] or nil
  local message = choice and choice.message or nil
  local content = ai_semantic_message_content(message)
  if type(content) ~= "string" or trim(content) == "" then
    return nil, "API 没有返回可用内容"
  end
  local decoded = ai_semantic_decode_content_json(content)
  if not decoded then
    return nil, "模型没有返回要求的 JSON 结构"
  end
  return decoded
end

function ai_semantic_retryable_response_error(reason)
  return reason == "API 没有返回可用内容"
    or reason == "模型没有返回要求的 JSON 结构"
end

function ai_semantic_retry_api(session, phase, reason)
  local retry_key = phase .. "_retry_count"
  if not ai_semantic_retryable_response_error(reason)
    or (session[retry_key] or 0) >= 1 then return false end
  if phase ~= "plan" then return false end

  if session.api_job then
    ai_semantic_cleanup_job(session.api_job)
    session.api_job = nil
  end

  local api_job = ai_semantic_start_api_job(
    "plan-retry",
    ai_semantic_plan_system_prompt()
      .. "\nReturn one complete JSON object only. Do not include analysis, prose, or markdown fences.",
    session.query,
    600
  )
  if not api_job then return false end
  session[retry_key] = (session[retry_key] or 0) + 1
  session.api_job = api_job
  set_status("AI 返回格式异常，正在自动重试搜索计划…")
  return true
end

function ai_semantic_plan_system_prompt()
  return [[You are the semantic query planner embedded in a professional sound-effects library manager. Convert the user's natural-language sound request into compact bilingual retrieval terms for matching filenames and metadata. Return JSON only with this schema: {"positive_terms":["..."],"negative_terms":["..."],"concepts":["..."],"summary":"..."}. Include useful English sound-library terms and concise Chinese equivalents. Keep at most 24 positive terms, 8 negative terms, and 8 concepts. Do not add markdown.]]
end

function ai_semantic_asset_scope_match(asset)
  if not asset or not asset.ready or asset.pending_batch then return false end
  if state.root_filter and not path_is_inside(asset.path, state.root_filter) then return false end
  if state.library_filter_id and asset.library_id ~= state.library_filter_id then return false end
  if state.status_filter
    and (asset.workflow_status or "none") ~= state.status_filter then return false end
  if state.active_collection_id then
    local collection = state.collection_by_id[state.active_collection_id]
    if not collection or not collection.items[path_key(asset.path)] then return false end
  end
  return true
end

function ai_semantic_normalize_terms(values, maximum)
  local output = {}
  local seen = {}
  for _, value in ipairs(type(values) == "table" and values or {}) do
    value = trim(tostring(value or ""))
    local key = safe_lower(value)
    if value ~= "" and #value <= 80 and not seen[key] then
      seen[key] = true
      output[#output + 1] = value
      if #output >= maximum then break end
    end
  end
  return output
end

function ai_semantic_validate_plan(value)
  if type(value) ~= "table" then return nil, "搜索计划无效" end
  local plan = {
    positive_terms = ai_semantic_normalize_terms(value.positive_terms, 24),
    negative_terms = ai_semantic_normalize_terms(value.negative_terms, 8),
    concepts = ai_semantic_normalize_terms(value.concepts, 8),
    summary = trim(tostring(value.summary or "")),
  }
  if #plan.positive_terms == 0 then return nil, "模型没有生成可用搜索词" end
  return plan
end

function ai_semantic_term_score(text, term, weight)
  text = safe_lower(text or "")
  term = safe_lower(trim(term or ""))
  if term == "" or text == "" then return 0 end
  if text:find(term, 1, true) then return weight end
  local score = 0
  local pieces = 0
  for piece in term:gmatch("[%w\128-\255]+") do
    if #piece >= 2 then
      pieces = pieces + 1
      if text:find(piece, 1, true) then score = score + weight * 0.35 end
    end
  end
  if pieces > 0 then return math.min(weight * 0.8, score) end
  return 0
end

function ai_semantic_compile_term(term)
  local value = safe_lower(trim(term or ""))
  local pieces = {}
  local seen = {}
  for piece in value:gmatch("[%w\128-\255]+") do
    if #piece >= 2 and not seen[piece] then
      seen[piece] = true
      pieces[#pieces + 1] = piece
    end
  end
  return { value = value, pieces = pieces }
end

function ai_semantic_compile_plan(plan)
  local compiled = { positive_terms = {}, negative_terms = {} }
  for _, term in ipairs(plan.positive_terms or {}) do
    compiled.positive_terms[#compiled.positive_terms + 1] =
      ai_semantic_compile_term(term)
  end
  for _, term in ipairs(plan.negative_terms or {}) do
    compiled.negative_terms[#compiled.negative_terms + 1] =
      ai_semantic_compile_term(term)
  end
  return compiled
end

function ai_semantic_compiled_term_score(text, term, weight)
  if term.value == "" or text == "" then return 0 end
  if text:find(term.value, 1, true) then return weight end
  local score = 0
  for _, piece in ipairs(term.pieces) do
    if text:find(piece, 1, true) then score = score + weight * 0.35 end
  end
  if #term.pieces > 0 then return math.min(weight * 0.8, score) end
  return 0
end

function ai_semantic_asset_recall_blob(asset)
  -- Reuse a normal-search blob only when it already exists. Building a
  -- persistent blob for every row during AI recall would retain substantial
  -- extra memory in catalogs containing hundreds of thousands of assets.
  if asset._search_blob then return asset._search_blob end
  return safe_lower(table.concat({
    asset.name or "", asset.path or "", asset.library or "",
    asset.description or "", asset.keywords or "", asset.catid or "",
    asset.category or "", asset.subcategory or "",
  }, "\n"))
end

function ai_semantic_asset_score(asset, plan, compiled_plan)
  local compiled = compiled_plan or ai_semantic_compile_plan(plan)
  local blob = ai_semantic_asset_recall_blob(asset)
  local matched_terms = {}
  for index, term in ipairs(compiled.positive_terms) do
    if ai_semantic_compiled_term_score(blob, term, 1) > 0 then
      matched_terms[#matched_terms + 1] = index
    end
  end
  if #matched_terms == 0 then return 0 end

  local fields = {
    { safe_lower(asset.name or ""), 8 },
    { safe_lower(asset.keywords or ""), 7 },
    { safe_lower(asset.description or ""), 6 },
    { safe_lower(asset.category or ""), 6 },
    { safe_lower(asset.subcategory or ""), 5 },
    { safe_lower(asset.catid or ""), 4 },
    { safe_lower(asset.library or ""), 2 },
    { safe_lower(asset.path or ""), 1 },
  }
  local score = 0
  local matched = 0
  for _, index in ipairs(matched_terms) do
    local term = compiled.positive_terms[index]
    local term_score = 0
    for _, field in ipairs(fields) do
      term_score = math.max(
        term_score,
        ai_semantic_compiled_term_score(field[1], term, field[2])
      )
    end
    if term_score > 0 then matched = matched + 1 score = score + term_score end
  end
  for _, term in ipairs(compiled.negative_terms) do
    if ai_semantic_compiled_term_score(blob, term, 1) > 0 then
      for _, field in ipairs(fields) do
        if ai_semantic_compiled_term_score(field[1], term, 1) > 0 then
          score = score - 12
          break
        end
      end
    end
  end
  return score + matched * 0.75
end

function ai_semantic_rank_is_worse(left, right)
  if left.score == right.score then return left.sort_path > right.sort_path end
  return left.score < right.score
end

function ai_semantic_heap_sift_up(heap, index)
  while index > 1 do
    local parent = math.floor(index / 2)
    if not ai_semantic_rank_is_worse(heap[index], heap[parent]) then break end
    heap[index], heap[parent] = heap[parent], heap[index]
    index = parent
  end
end

function ai_semantic_heap_sift_down(heap, index)
  while true do
    local left = index * 2
    if left > #heap then return end
    local right = left + 1
    local worst = left
    if right <= #heap and ai_semantic_rank_is_worse(heap[right], heap[left]) then
      worst = right
    end
    if not ai_semantic_rank_is_worse(heap[worst], heap[index]) then return end
    heap[index], heap[worst] = heap[worst], heap[index]
    index = worst
  end
end

function ai_semantic_insert_candidate(session, asset, score)
  if score <= 0 then return end
  local entry = { asset = asset, score = score, sort_path = path_key(asset.path) }
  if #session.candidates < AISemantic.candidate_pool_limit then
    session.candidates[#session.candidates + 1] = entry
    ai_semantic_heap_sift_up(session.candidates, #session.candidates)
  elseif ai_semantic_rank_is_worse(session.candidates[1], entry) then
    session.candidates[1] = entry
    ai_semantic_heap_sift_down(session.candidates, 1)
  end
end

function ai_semantic_sort_candidates(candidates)
  table.sort(candidates, function(left, right)
    if left.score == right.score then return left.sort_path < right.sort_path end
    return left.score > right.score
  end)
end

function ai_semantic_prepare_page(session, page_index)
  local pool = session.candidate_pool or session.candidates or {}
  local first = (page_index - 1) * AISemantic.candidate_page_size + 1
  local last = math.min(#pool, first + AISemantic.candidate_page_size - 1)
  local page = {}
  for index = first, last do page[#page + 1] = pool[index] end
  session.page_index = page_index
  session.page_start = first
  session.page_end = last
  session.candidates = page
  return #page > 0
end

function ai_semantic_finish_local(session)
  local lookup = {}
  if session.append_results then
    for key, value in pairs(state.ai_semantic_lookup or {}) do lookup[key] = value end
  end
  local count = session.append_results and (state.ai_semantic_result_count or 0) or 0
  for index, entry in ipairs(session.candidates) do
    if index > AISemantic.result_page_limit then break end
    count = count + 1
    lookup[path_key(entry.asset.path)] = {
      local_score = entry.score,
      page = session.page_index or 1,
      page_rank = index,
    }
  end
  local pool = session.candidate_pool or session.candidates or {}
  local loaded_candidates = math.min(session.page_end or #session.candidates, #pool)
  local has_more = loaded_candidates < #pool
  AppState.apply({
    ai_semantic_lookup = lookup,
    ai_semantic_result_count = count,
    ai_semantic_last_query = session.query,
    ai_semantic_last_summary = session.plan and session.plan.summary or "",
    ai_semantic_session = nil,
    ai_semantic_paging = {
      query = session.query,
      plan = session.plan,
      compiled_plan = session.compiled_plan,
      candidate_pool = pool,
      page_index = session.page_index or 1,
      next_offset = loaded_candidates + 1,
    },
    ai_semantic_has_more = has_more,
    ai_semantic_loaded_candidates = loaded_candidates,
    ai_semantic_total_candidates = #pool,
    view = "ai_semantic",
    search = session.query,
    sort_mode = "ai_order",
    sort_desc = true,
    results_dirty = true,
  })
  if session.job_token then Jobs.finish(session.job_token, true, "complete") end
  set_status(string.format(
    "AI 语义搜索完成：已显示 %d 条%s",
    count,
    has_more and "，可继续加载下一批" or ""
  ))
end

function start_ai_semantic_next_page()
  if state.ai_semantic_session then return false, "已有 AI 请求正在运行" end
  local paging = state.ai_semantic_paging
  local pool = paging and paging.candidate_pool or nil
  if not pool or (paging.next_offset or 1) > #pool then
    AppState.set("ai_semantic_has_more", false)
    return false, "没有更多 AI 候选"
  end
  local session = {
    query = paging.query,
    plan = paging.plan,
    compiled_plan = paging.compiled_plan,
    candidate_pool = pool,
    candidates = {},
    page_index = (paging.page_index or 1) + 1,
    append_results = true,
  }
  if not ai_semantic_prepare_page(session, session.page_index) then
    AppState.set("ai_semantic_has_more", false)
    return false, "没有更多 AI 候选"
  end
  ai_semantic_finish_local(session)
  return true
end

function ai_semantic_fail(session, message)
  if session.api_job then ai_semantic_cleanup_job(session.api_job) end
  Jobs.finish(session.job_token, false, message)
  AppState.set("ai_semantic_session", nil)
  set_status("AI 语义搜索失败：" .. tostring(message or "未知错误"), true)
end

function ai_semantic_cancel()
  local session = state.ai_semantic_session
  if not session then return end
  Jobs.cancel(session.job_token)
  if session.api_job then
    ai_semantic_stop_job_process(session.api_job)
    ai_semantic_cleanup_job(session.api_job)
  end
  Jobs.finish(session.job_token, true, "canceled")
  AppState.set("ai_semantic_session", nil)
  set_status("已取消 AI 语义搜索")
end

function ai_semantic_asset_snapshot()
  local snapshot = {}
  for index, asset in ipairs(state.assets or {}) do
    snapshot[index] = asset
  end
  return snapshot
end

function start_ai_semantic_search(query)
  query = trim(query or state.search or "")
  if query == "" then set_status("请输入需要查找的声音描述", true) return false end
  if not state.ai_semantic_available then
    set_status("AI 语义搜索在当前环境不可用", true)
    return false
  end
  if state.ai_semantic_session then ai_semantic_cancel() end
  -- AI semantic search only reads a stable array snapshot. It must not share
  -- the long-lived catalog maintenance lock used by waveform precaching,
  -- cache verification, background snapshots, and directory scans.
  local token, reason = Jobs.begin("ai_semantic_search", "ai_semantic_api", true, 72)
  if not token then set_status("无法启动 AI 搜索：" .. tostring(reason), true) return false end
  local source = ai_semantic_asset_snapshot()
  local api_job, api_reason = ai_semantic_start_api_job(
    "plan",
    ai_semantic_plan_system_prompt(),
    query,
    600
  )
  if not api_job then
    Jobs.finish(token, false, api_reason)
    set_status("无法启动 AI 搜索：" .. tostring(api_reason), true)
    return false
  end
  AppState.apply({
    ai_semantic_paging = nil,
    ai_semantic_has_more = false,
    ai_semantic_loaded_candidates = 0,
    ai_semantic_total_candidates = 0,
    ai_semantic_lookup = {},
    ai_semantic_result_count = 0,
    results_dirty = true,
    ai_semantic_session = {
    query = query,
    phase = "plan_wait",
    api_job = api_job,
    -- The shared toolbar field contains the natural-language request, so it
    -- must not also narrow the candidate pool through ordinary text matching.
    source = source,
    source_index = 1,
    total = #source,
    scanned = 0,
    candidates = {},
    job_token = token,
    },
  })
  set_status("AI 语义搜索：正在理解声音描述…")
  return true
end

function ai_semantic_poll_api(session)
  local job = session.api_job
  local now = Host.time_precise()
  if now - (job.last_poll or 0) < AISemantic.poll_interval then return nil end
  job.last_poll = now
  local status = ai_semantic_read_status(job)
  if now - job.started > AISemantic.request_timeout + 10 then
    ai_semantic_stop_job_process(job)
    return false, "API 请求超时"
  end
  if not status then return nil end
  if status.state == "running" then return nil end
  if status.state ~= "complete" then
    return false, tostring(status.message or "API 请求失败")
  end
  local response, reason = ai_semantic_read_file(job.response_path, 8 * 1024 * 1024)
  if not response then return false, tostring(reason or "API 响应文件不存在") end
  local decoded, decode_reason = ai_semantic_extract_content(response)
  ai_semantic_cleanup_job(job)
  session.api_job = nil
  if not decoded then return false, decode_reason end
  return true, decoded
end

function process_ai_semantic_search()
  local session = state.ai_semantic_session
  if not session or not Jobs.is_current(session.job_token) then return end
  if session.phase == "test_wait" then
    process_ai_semantic_connection_test(session)
    return
  end
  if session.phase == "plan_wait" then
    local ready, value = ai_semantic_poll_api(session)
    if ready == nil then return end
    if not ready then
      if ai_semantic_retry_api(session, "plan", value) then return end
      ai_semantic_fail(session, value)
      return
    end
    local plan, reason = ai_semantic_validate_plan(value)
    if not plan then
      if ai_semantic_retry_api(session, "plan", "模型没有返回要求的 JSON 结构") then return end
      ai_semantic_fail(session, reason)
      return
    end
    session.plan = plan
    session.compiled_plan = ai_semantic_compile_plan(plan)
    session.phase = "recall"
    set_status("AI 语义搜索：正在本地召回候选素材…")
    return
  end
  if session.phase == "recall" then
    if not can_run_heavy_job() then return end
    local processed = 0
    local deadline = Host.time_precise() + AISemantic.frame_budget
    while session.source_index <= session.total
      and processed < AISemantic.frame_records
      and (processed == 0 or Host.time_precise() < deadline) do
      local asset = session.source[session.source_index]
      if ai_semantic_asset_scope_match(asset) then
        ai_semantic_insert_candidate(
          session,
          asset,
          ai_semantic_asset_score(asset, session.plan, session.compiled_plan)
        )
      end
      session.source_index = session.source_index + 1
      session.scanned = session.scanned + 1
      processed = processed + 1
    end
    if session.source_index <= session.total then return end
    if #session.candidates == 0 then
      session.candidate_by_id = {}
      ai_semantic_finish_local(session)
      return
    end
    ai_semantic_sort_candidates(session.candidates)
    session.candidate_pool = session.candidates
    ai_semantic_prepare_page(session, 1)
    ai_semantic_finish_local(session)
    return
  end
end

function start_ai_semantic_connection_test()
  if state.ai_semantic_session then return false, "已有 AI 请求正在运行" end
  local token, reason = Jobs.begin("ai_semantic_search", "ai_semantic_api", true, 72)
  if not token then return false, reason end
  local api_job, api_reason = ai_semantic_start_api_job(
    "test",
    [[Return JSON only: {"ok":true}.]],
    "Connection test",
    20
  )
  if not api_job then Jobs.finish(token, false, api_reason) return false, api_reason end
  AppState.set("ai_semantic_session", {
    query = "",
    phase = "test_wait",
    api_job = api_job,
    job_token = token,
  })
  set_status("正在测试 AI API 连接…")
  return true
end

function process_ai_semantic_connection_test(session)
  local ready, value = ai_semantic_poll_api(session)
  if ready == nil then return true end
  if not ready then ai_semantic_fail(session, value) return true end
  Jobs.finish(session.job_token, true, "connection test")
  AppState.set("ai_semantic_session", nil)
  set_status(value.ok == true and "AI API 连接成功" or "AI API 已响应")
  return true
end
