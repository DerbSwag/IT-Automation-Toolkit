param(
    [Parameter(Mandatory=$true)]
    [string]$LarkAccount,
    [string]$Hostname = $env:COMPUTERNAME,
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\glpi_config.ini")
)

. "$PSScriptRoot\lib\Read-IniFile.ps1"

function Get-AppToken($t) {
    $ips = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
        $_.IPAddress -notmatch '^127\.' -and $_.IPAddress -notmatch '^169\.'
    }).IPAddress
    foreach ($ip in $ips) {
        if ($ip -match '^192\.168\.1\.')   { return $t["VLAN1"] }
        if ($ip -match '^192\.168\.2\.')   { return $t["VLAN2"] }
        if ($ip -match '^192\.168\.100\.') { return $t["VLAN100"] }
        if ($ip -match '^192\.168\.101\.') { return $t["VLAN101"] }
    }
    return $null
}

Write-Host ""
Write-Host "============================================="
Write-Host "  GLPI - Link Lark Account to Asset"
Write-Host "============================================="
Write-Host "  Hostname : $Hostname"
Write-Host "  Lark     : $LarkAccount"
Write-Host ""

$config    = Read-IniFile $ConfigPath
$glpiUrl   = $config["GLPI"]["SERVER_URL"]
$userToken = $config["GLPI"]["USER_TOKEN"]
$appToken  = Get-AppToken $config["APP_TOKENS"]
if (-not $appToken) { $appToken = $config["APP_TOKENS"]["VLAN1"] }

Write-Host "[INFO] GLPI Server: $glpiUrl"

$headers = @{
    "App-Token"     = $appToken
    "Authorization" = "user_token $userToken"
    "Content-Type"  = "application/json"
}

$linked = $false

try {
    $session = Invoke-RestMethod "$glpiUrl/apirest.php/initSession" -Method GET -Headers $headers -ErrorAction Stop
    $headers["Session-Token"] = $session.session_token
    Write-Host "[OK] Session started"

    $enc = [uri]::EscapeDataString($Hostname)
    $url = "$glpiUrl/apirest.php/search/Computer?criteria[0][field]=1&criteria[0][searchtype]=equals&criteria[0][value]=$enc&forcedisplay[0]=2&forcedisplay[1]=1"
    $computers = Invoke-RestMethod $url -Method GET -Headers $headers -ErrorAction Stop

    if (-not $computers.data -or $computers.data.Count -eq 0) {
        Write-Host "[WARN] Computer '$Hostname' not found in GLPI yet."
        exit 1
    }

    $computerId = $computers.data[0]."2"
    Write-Host "[OK] Found computer ID: $computerId"

    $larkEnc = [uri]::EscapeDataString($LarkAccount)
    $uUrl    = "$glpiUrl/apirest.php/search/User?criteria[0][field]=1&criteria[0][searchtype]=equals&criteria[0][value]=$larkEnc&forcedisplay[0]=2"
    $users   = Invoke-RestMethod $uUrl -Method GET -Headers $headers -ErrorAction Stop

    if (-not $users.data -or $users.data.Count -eq 0) {
        Write-Host "[WARN] User '$LarkAccount' not found. Saving to comment."
        $now  = Get-Date -Format "yyyy-MM-dd HH:mm"
        $body = @{ input = @{ id = $computerId; comment = "Lark: $LarkAccount (auto $now)" } } | ConvertTo-Json
        Invoke-RestMethod "$glpiUrl/apirest.php/Computer/$computerId" -Method PUT -Headers $headers -Body $body | Out-Null
        Write-Host "[OK] Comment saved."
        $linked = $true
    } else {
        $userId = $users.data[0]."2"
        Write-Host "[OK] Found user ID: $userId"
        $body = @{ input = @{ id = $computerId; users_id = $userId } } | ConvertTo-Json
        Invoke-RestMethod "$glpiUrl/apirest.php/Computer/$computerId" -Method PUT -Headers $headers -Body $body | Out-Null
        Write-Host "[SUCCESS] Linked '$LarkAccount' to '$Hostname'."
        $linked = $true
    }

} catch {
    Write-Host "[ERROR] $_"
    exit 1
} finally {
    try {
        Invoke-RestMethod "$glpiUrl/apirest.php/killSession" -Method GET -Headers $headers | Out-Null
        Write-Host "[OK] Session closed."
    } catch {}
}

if ($linked) { exit 0 } else { exit 1 }
