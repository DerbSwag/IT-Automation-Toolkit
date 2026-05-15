param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\glpi\glpi_config.ini"),
    [string]$LarkWebhook = ""
)

. "$PSScriptRoot\..\glpi\scripts\lib\Read-IniFile.ps1"

$results = @()

# --- 1. Check GLPI Agent service ---
$svc = Get-Service -Name "GLPI-Agent" -ErrorAction SilentlyContinue
if ($svc) {
    if ($svc.Status -eq 'Running') {
        $results += @{ check = "GLPI Agent Service"; status = "OK"; detail = "Running" }
    } else {
        $results += @{ check = "GLPI Agent Service"; status = "FAIL"; detail = "Status: $($svc.Status)" }
    }
} else {
    $results += @{ check = "GLPI Agent Service"; status = "WARN"; detail = "Not installed" }
}

# --- 2. Check GLPI server connectivity ---
$config = Read-IniFile $ConfigPath
$server = $config["GLPI"]["SERVER_URL"] -replace '/glpi.*', '' -replace 'https?://', ''
$ping = Test-Connection $server -Count 1 -Quiet -ErrorAction SilentlyContinue
if ($ping) {
    $results += @{ check = "GLPI Server Ping"; status = "OK"; detail = $server }
} else {
    $results += @{ check = "GLPI Server Ping"; status = "FAIL"; detail = "Cannot reach $server" }
}

# --- 3. Check GLPI API response ---
$apiUrl = $config["GLPI"]["SERVER_URL"] -replace '/front/.*', '/apirest.php'
try {
    $resp = Invoke-WebRequest "$apiUrl" -Method GET -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
    if ($resp.StatusCode -eq 200) {
        $results += @{ check = "GLPI API"; status = "OK"; detail = "HTTP 200" }
    } else {
        $results += @{ check = "GLPI API"; status = "WARN"; detail = "HTTP $($resp.StatusCode)" }
    }
} catch {
    $results += @{ check = "GLPI API"; status = "FAIL"; detail = $_.Exception.Message }
}

# --- 4. Check last inventory submission ---
$invDir = "$env:ProgramData\GLPI-Agent"
if (Test-Path $invDir) {
    $lastFile = Get-ChildItem $invDir -Recurse -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($lastFile -and $lastFile.LastWriteTime -gt (Get-Date).AddDays(-7)) {
        $results += @{ check = "Last Inventory"; status = "OK"; detail = "Updated $($lastFile.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))" }
    } else {
        $results += @{ check = "Last Inventory"; status = "WARN"; detail = "No recent activity (>7 days)" }
    }
} else {
    $results += @{ check = "Last Inventory"; status = "WARN"; detail = "ProgramData folder not found" }
}

# --- Output ---
$hasFailure = ($results | Where-Object { $_.status -eq 'FAIL' }).Count -gt 0

Write-Host ""
Write-Host "===== GLPI Health Check ====="
foreach ($r in $results) {
    $sym = switch ($r.status) { "OK" { "[OK]" } "WARN" { "[!!]" } "FAIL" { "[XX]" } }
    Write-Host "  $sym $($r.check): $($r.detail)"
}
Write-Host ""

# --- Lark notification (only on failure or if webhook provided) ---
if ($LarkWebhook -and $hasFailure) {
    $lines = $results | ForEach-Object {
        $sym = switch ($_.status) { "OK" { "[OK]" } "WARN" { "[WARN]" } "FAIL" { "[FAIL]" } }
        "$sym $($_.check): $($_.detail)"
    }
    $title = if ($hasFailure) { "[ALERT]" } else { "[OK]" }
    $body = @{
        msg_type = "text"
        content  = @{ text = "$title GLPI Health Check - $env:COMPUTERNAME`n$($lines -join "`n")" }
    } | ConvertTo-Json -Depth 3

    try {
        Invoke-RestMethod $LarkWebhook -Method POST -Body $body -ContentType "application/json" | Out-Null
        Write-Host "[OK] Lark notification sent."
    } catch {
        Write-Host "[WARN] Failed to send Lark notification: $_"
    }
}

if ($hasFailure) { exit 1 } else { exit 0 }
