<#
.SYNOPSIS
    Deploy Zabbix Agent 2 to multiple Windows servers via PowerShell Remoting.
.USAGE
    .\Deploy-ZabbixAgent2.ps1
.NOTES
    Requires WinRM enabled on target servers.
    Edit $servers and $zbxServer before running.
#>

# === CONFIG - แก้ตรงนี้ ===
$servers = @(
    "192.168.x.x",
    "192.168.x.x"
)

$zbxServer      = "CHANGE_ME"
$zbxServerActive = ""
$msiUrl         = "https://cdn.zabbix.com/zabbix/binaries/stable/7.0/7.0.0/zabbix_agent2-7.0.0-windows-amd64-openssl.msi"
# === END CONFIG ===

$cred = Get-Credential -Message "Enter credentials for remote servers"

foreach ($ip in $servers) {
    Write-Host "[$ip] Deploying..." -ForegroundColor Cyan
    try {
        Invoke-Command -ComputerName $ip -Credential $cred -ScriptBlock {
            param($url, $server, $serverActive)
            $hostname = $env:COMPUTERNAME

            New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null
            Invoke-WebRequest -Uri $url -OutFile "C:\Temp\zabbix_agent2.msi"

            Start-Process msiexec.exe -ArgumentList "/i C:\Temp\zabbix_agent2.msi /qn SERVER=$server SERVERACTIVE=$serverActive HOSTNAME=$hostname LISTENPORT=10050" -Wait

            New-NetFirewallRule -DisplayName "Zabbix Agent 2" -Direction Inbound -Protocol TCP -LocalPort 10050 -Action Allow -ErrorAction SilentlyContinue

            Set-Service -Name "Zabbix Agent 2" -StartupType Automatic
            Start-Service -Name "Zabbix Agent 2"

            Write-Output "OK - $hostname installed and running"
        } -ArgumentList $msiUrl, $zbxServer, $zbxServerActive

        Write-Host "[$ip] Done" -ForegroundColor Green
    }
    catch {
        Write-Host "[$ip] FAILED: $_" -ForegroundColor Red
    }
}
