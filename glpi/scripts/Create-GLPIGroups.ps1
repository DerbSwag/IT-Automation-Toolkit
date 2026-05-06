param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\glpi_config.ini")
)

. "$PSScriptRoot\lib\Read-IniFile.ps1"

$config    = Read-IniFile $ConfigPath
$glpiUrl   = $config["GLPI"]["SERVER_URL"]
$userToken = $config["GLPI"]["USER_TOKEN"]
$appToken  = $config["APP_TOKENS"]["VLAN1"]

$groups = @(
    @{ name="IT";        parent="" },
    @{ name="SH";        parent="" },
    @{ name="MM";        parent="" },
    @{ name="QA";        parent="" },
    @{ name="HR";        parent="" },
    @{ name="AC";        parent="" },
    @{ name="CP";        parent="" },
    @{ name="Sr. Mgt";   parent="" },
    @{ name="RD";        parent="" },
    @{ name="SCM";       parent="" },
    @{ name="PU";        parent="SCM" },
    @{ name="OS";        parent="SCM" },
    @{ name="EX";        parent="SCM" },
    @{ name="WH";        parent="SCM" },
    @{ name="Operation"; parent="" },
    @{ name="PE";        parent="Operation" },
    @{ name="PD1";       parent="Operation" },
    @{ name="PD2";       parent="Operation" },
    @{ name="PD3";       parent="Operation" },
    @{ name="EN";        parent="Operation" },
    @{ name="PC";        parent="Operation" },
    @{ name="BD&CS";     parent="" },
    @{ name="CS";        parent="BD&CS" },
    @{ name="BD";        parent="BD&CS" },
    @{ name="EC";        parent="BD&CS" }
)

$headers = @{
    "App-Token"     = $appToken
    "Authorization" = "user_token $userToken"
    "Content-Type"  = "application/json"
}

Write-Host ""
Write-Host "============================================="
Write-Host "  GLPI - Create Department Groups"
Write-Host "============================================="
Write-Host ""

try {
    $session = Invoke-RestMethod "$glpiUrl/apirest.php/initSession" -Method GET -Headers $headers -ErrorAction Stop
    $headers["Session-Token"] = $session.session_token
    Write-Host "[OK] Session started"
    Write-Host ""

    $createdIds = @{}

    # สร้าง top-level groups ก่อน
    foreach ($g in ($groups | Where-Object { $_.parent -eq "" })) {
        $body = @{ input = @{ name = $g.name; is_usergroup = 1 } } | ConvertTo-Json
        $res  = Invoke-RestMethod "$glpiUrl/apirest.php/Group" -Method POST -Headers $headers -Body $body -ErrorAction Stop
        $createdIds[$g.name] = $res.id
        Write-Host "[OK] Created: $($g.name) (ID: $($res.id))"
    }

    Write-Host ""

    # สร้าง sub-groups
    foreach ($g in ($groups | Where-Object { $_.parent -ne "" })) {
        $parentId = [int]$createdIds[$g.parent]
        $body = @{ input = @{
            name         = $g.name
            groups_id    = $parentId
            is_usergroup = 1
        }} | ConvertTo-Json
        $res = Invoke-RestMethod "$glpiUrl/apirest.php/Group" -Method POST -Headers $headers -Body $body -ErrorAction Stop
        $createdIds[$g.name] = $res.id
        Write-Host "[OK] Created: $($g.parent) / $($g.name) (ID: $($res.id))"
    }

    Write-Host ""
    Write-Host "============================================="
    Write-Host "  DONE - $($groups.Count) groups created"
    Write-Host "============================================="

} catch {
    Write-Host "[ERROR] $_"
} finally {
    try {
        Invoke-RestMethod "$glpiUrl/apirest.php/killSession" -Method GET -Headers $headers | Out-Null
        Write-Host "[OK] Session closed."
    } catch {}
}
