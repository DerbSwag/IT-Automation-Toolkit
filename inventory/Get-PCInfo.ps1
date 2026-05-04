[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

function Get-ClassData {
    param(
        [Parameter(Mandatory = $true)][string]$ClassName
    )

    if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
        return Get-CimInstance -ClassName $ClassName
    }

    return Get-WmiObject -Class $ClassName
}

try {
    $computerSystem = Get-ClassData -ClassName Win32_ComputerSystem
    $operatingSystem = Get-ClassData -ClassName Win32_OperatingSystem
    $processor = Get-ClassData -ClassName Win32_Processor | Select-Object -First 1
    $bios = Get-ClassData -ClassName Win32_BIOS
    $networkAdapters = Get-ClassData -ClassName Win32_NetworkAdapterConfiguration |
        Where-Object { $_.IPEnabled -eq $true }
    $disk = Get-ClassData -ClassName Win32_LogicalDisk |
        Where-Object { $_.DriveType -eq 3 }

    $ramGb = [Math]::Round(($computerSystem.TotalPhysicalMemory / 1GB), 2)

    $lines = @(
        "=== SYSTEM INVENTORY ==="
        "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        "ComputerName: $($env:COMPUTERNAME)"
        "Username: $($env:USERNAME)"
        "Domain: $($computerSystem.Domain)"
        "Manufacturer: $($computerSystem.Manufacturer)"
        "Model: $($computerSystem.Model)"
        "SerialNumber: $($bios.SerialNumber)"
        "BIOSVersion: $($bios.SMBIOSBIOSVersion)"
        "OS: $($operatingSystem.Caption)"
        "OSVersion: $($operatingSystem.Version)"
        "CPU: $($processor.Name)"
        "RAM_GB: $ramGb"
        ""
        "=== DISK ==="
    )

    foreach ($d in $disk) {
        $sizeGb = if ($d.Size) { [Math]::Round(($d.Size / 1GB), 2) } else { 0 }
        $freeGb = if ($d.FreeSpace) { [Math]::Round(($d.FreeSpace / 1GB), 2) } else { 0 }
        $lines += "Drive $($d.DeviceID) TotalGB=$sizeGb FreeGB=$freeGb"
    }

    $lines += ""
    $lines += "=== NETWORK ==="

    foreach ($adapter in $networkAdapters) {
        $ip = ($adapter.IPAddress -join ', ')
        $gw = ($adapter.DefaultIPGateway -join ', ')
        $dns = ($adapter.DNSServerSearchOrder -join ', ')
        $lines += "Adapter: $($adapter.Description)"
        $lines += "  IP: $ip"
        $lines += "  Gateway: $gw"
        $lines += "  DNS: $dns"
    }

    $lines += ""
    $lines += "=== INSTALLED SOFTWARE ==="
    $regPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $software = $regPaths | ForEach-Object { Get-ItemProperty $_ -ErrorAction SilentlyContinue } |
        Where-Object { $_.DisplayName } |
        Sort-Object DisplayName -Unique |
        Select-Object DisplayName, DisplayVersion
    foreach ($app in $software) {
        $ver = if ($app.DisplayVersion) { " ($($app.DisplayVersion))" } else { "" }
        $lines += "  $($app.DisplayName)$ver"
    }

    if ($OutputPath) {
        $parent = Split-Path -Path $OutputPath -Parent
        if ($parent -and -not (Test-Path -Path $parent)) {
            New-Item -Path $parent -ItemType Directory -Force | Out-Null
        }
        $lines | Out-File -FilePath $OutputPath -Encoding UTF8
    }
    else {
        $lines
    }
}
catch {
    Write-Error "Inventory collection failed: $($_.Exception.Message)"
    exit 1
}
