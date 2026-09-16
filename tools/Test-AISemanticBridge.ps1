param(
    [string]$ModulePath = ""
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Security
$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ModulePath)) {
    $ModulePath = Join-Path $repoRoot "src/lua/44_ai_semantic_search.lua"
}
$source = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $ModulePath), [Text.Encoding]::UTF8)
$match = [regex]::Match(
    $source,
    'function ai_semantic_bridge_source\(\)\s+return \[=\[(?<script>[\s\S]*?)\]=\]\s+end'
)
if (-not $match.Success) { throw "Embedded AI bridge was not found." }

$work = Join-Path ([IO.Path]::GetTempPath()) ("PsyReaSFX-ai-bridge-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)

try {
    $bridge = Join-Path $work "bridge.ps1"
    $request = Join-Path $work "request.json"
    $status = Join-Path $work "status.json"
    $plaintext = Join-Path $work "plaintext.tmp"
    $secret = Join-Path $work "secret.dpapi"
    $expected = "sk-test-do-not-store-in-config"

    [void][ScriptBlock]::Create($match.Groups["script"].Value)
    [IO.File]::WriteAllText($bridge, $match.Groups["script"].Value, $utf8)
    [IO.File]::WriteAllText($plaintext, $expected, $utf8)
    [IO.File]::WriteAllText(
        $request,
        (@{
            operation = "protect-key"
            plaintextPath = $plaintext
            secretPath = $secret
            statusPath = $status
        } | ConvertTo-Json -Compress),
        $utf8
    )

    & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $bridge $request
    if ($LASTEXITCODE -ne 0) {
        $detail = if (Test-Path -LiteralPath $status) {
            Get-Content -LiteralPath $status -Raw -Encoding UTF8
        } else {
            "no status file"
        }
        throw "AI bridge returned exit code $LASTEXITCODE`: $detail"
    }
    $result = Get-Content -LiteralPath $status -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($result.state -ne "complete") { throw "AI bridge did not complete." }
    if (Test-Path -LiteralPath $plaintext) { throw "Plaintext API key was not removed." }
    $encrypted = Get-Content -LiteralPath $secret -Raw -Encoding UTF8
    if ($encrypted.Contains($expected)) { throw "Encrypted API key contains plaintext." }
    $encryptedBytes = [Convert]::FromBase64String($encrypted.Trim())
    $plainBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
        $encryptedBytes,
        $null,
        [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    try {
        $roundTrip = [Text.Encoding]::UTF8.GetString($plainBytes)
    }
    finally {
        [Array]::Clear($plainBytes, 0, $plainBytes.Length)
        [Array]::Clear($encryptedBytes, 0, $encryptedBytes.Length)
    }
    if ($roundTrip -cne $expected) { throw "DPAPI API-key round trip failed." }

    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try {
        $port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
        $bodyPath = Join-Path $work "body.json"
        $responsePath = Join-Path $work "response.json"
        $httpRequestPath = Join-Path $work "http-request.json"
        $httpStatusPath = Join-Path $work "http-status.json"
        [IO.File]::WriteAllText(
            $bodyPath,
            '{"model":"deepseek-flash","messages":[{"role":"user","content":"test"}]}',
            $utf8
        )
        [IO.File]::WriteAllText(
            $httpRequestPath,
            (@{
                operation = "chat-completions"
                url = "http://127.0.0.1:$port/chat/completions"
                secretPath = $secret
                bodyPath = $bodyPath
                responsePath = $responsePath
                statusPath = $httpStatusPath
                timeoutSeconds = 10
            } | ConvertTo-Json -Compress),
            $utf8
        )
        $bridgeProcess = Start-Process powershell.exe -WindowStyle Hidden -PassThru -ArgumentList @(
            '-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
            '-File', $bridge, $httpRequestPath
        )
        $deadline = [DateTime]::UtcNow.AddSeconds(10)
        while ((-not $listener.Pending()) -and (-not $bridgeProcess.HasExited) -and ([DateTime]::UtcNow -lt $deadline)) {
            Start-Sleep -Milliseconds 20
        }
        if (-not $listener.Pending()) {
            $detail = if (Test-Path -LiteralPath $httpStatusPath) {
                Get-Content -LiteralPath $httpStatusPath -Raw -Encoding UTF8
            } else {
                "no status file"
            }
            throw "AI bridge HTTP request was not received: $detail"
        }
        $client = $listener.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::UTF8, $false, 4096, $true)
            $requestLine = $reader.ReadLine()
            $headers = @{}
            while ($true) {
                $line = $reader.ReadLine()
                if ([string]::IsNullOrEmpty($line)) { break }
                $split = $line.IndexOf(':')
                if ($split -gt 0) {
                    $headers[$line.Substring(0, $split).Trim()] = $line.Substring($split + 1).Trim()
                }
            }
            $contentLength = [int]($headers['Content-Length'] ?? 0)
            $buffer = New-Object char[] $contentLength
            $read = 0
            while ($read -lt $contentLength) {
                $count = $reader.Read($buffer, $read, $contentLength - $read)
                if ($count -le 0) { break }
                $read += $count
            }
            $receivedBody = -join $buffer[0..([Math]::Max(0, $read - 1))]
            if ($requestLine -notmatch '^POST /chat/completions HTTP/') { throw "Unexpected HTTP request line." }
            if ($headers['Authorization'] -ne "Bearer $expected") { throw "AI bridge Authorization header was not restored from DPAPI." }
            if ($receivedBody -notmatch 'deepseek-flash') { throw "AI bridge request body was not forwarded." }
            $responseBody = '{"choices":[{"message":{"content":"{\"ok\":true}"}}]}'
            $responseBytes = $utf8.GetBytes($responseBody)
            $responseHeader = "HTTP/1.1 200 OK`r`nContent-Type: application/json`r`nContent-Length: $($responseBytes.Length)`r`nConnection: close`r`n`r`n"
            $headerBytes = [Text.Encoding]::ASCII.GetBytes($responseHeader)
            $stream.Write($headerBytes, 0, $headerBytes.Length)
            $stream.Write($responseBytes, 0, $responseBytes.Length)
            $stream.Flush()
        }
        finally {
            $client.Dispose()
        }
        if (-not $bridgeProcess.WaitForExit(10000)) {
            $bridgeProcess.Kill()
            throw "AI bridge HTTP test timed out."
        }
        if ($bridgeProcess.ExitCode -ne 0) { throw "AI bridge HTTP request failed." }
        $httpStatus = Get-Content -LiteralPath $httpStatusPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($httpStatus.state -ne 'complete') { throw "AI bridge HTTP status is incomplete." }
        $forwarded = Get-Content -LiteralPath $responsePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($forwarded.choices[0].message.content -ne '{"ok":true}') {
            throw "AI bridge response was not forwarded intact."
        }
    }
    finally {
        $listener.Stop()
    }
    Write-Host "AI semantic PowerShell bridge self-test passed"
}
finally {
    if (Test-Path -LiteralPath $work) {
        Remove-Item -LiteralPath $work -Recurse -Force
    }
}
