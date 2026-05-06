# ============================================================
#  Fix-StatusAndGroup.ps1
#  เช็ค Status IDs และ Group IDs ใน GLPI
#  รันครั้งเดียวเพื่อดูว่า "In use" = states_id เท่าไหร่
# ============================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\glpi_config.ini")
)

. "$PSScriptRoot\lib\Read-IniFile.ps1"

$config    = Read-IniFile $ConfigPath
$glpiUrl   = $config["GLPI"]["SERVER_URL"]
$userToken = $config["GLPI"]["USER_TOKEN"]
$appToken  = $config["APP_TOKENS"]["VLAN1"]

$headers = @{
    "App-Token"     = $appToken
    "Authorization" = "user_token $userToken"
    "Content-Type"  = "application/json"
}

try {
    $session = Invoke-RestMethod "$glpiUrl/apirest.php/initSession" -Method GET -Headers $headers -ErrorAction Stop
    $headers["Session-Token"] = $session.session_token

    Write-Host ""
    Write-Host "=== ALL STATES (Status) ==="
    $states = Invoke-RestMethod "$glpiUrl/apirest.php/State?range=0-50" -Method GET -Headers $headers
    foreach ($s in $states) {
        Write-Host "  ID: $($s.id)  Name: $($s.name)"
    }

    Write-Host ""
    Write-Host "=== ALL GROUPS ==="
    $groups = Invoke-RestMethod "$glpiUrl/apirest.php/Group?range=0-100" -Method GET -Headers $headers
    foreach ($g in $groups) {
        Write-Host "  ID: $($g.id)  Name: $($g.name)"
    }

} catch {
    Write-Host "[ERROR] $_"
} finally {
    try {
        Invoke-RestMethod "$glpiUrl/apirest.php/killSession" -Method GET -Headers $headers | Out-Null
    } catch {}
}
