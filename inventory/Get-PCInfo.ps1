[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [ValidateSet('Text', 'Json')]
    [string]$Format = 'Text'
)

$ErrorActionPreference = 'Stop'

function Get-ClassData {
    param([Parameter(Mandatory = $true)][string]$ClassName)

    if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
        try { return Get-CimInstance -ClassName $ClassName -ErrorAction Stop }
        catch { return Get-WmiObject -Class $ClassName -ErrorAction Stop }
    }
    return Get-WmiObject -Class $ClassName
}

function Get-SafeValue {
    param([scriptblock]$Script, $Default = $null)
    try { & $Script 2>$null } catch { $Default }
}

function Test-PendingReboot {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    )
    if ($paths | Where-Object { Test-Path $_ }) { return $true }
    $pendingRename = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
    return $null -ne $pendingRename.PendingFileRenameOperations
}

try {
    $computerSystem = Get-SafeValue { Get-ClassData Win32_ComputerSystem } ([pscustomobject]@{ Domain = ''; Manufacturer = ''; Model = ''; TotalPhysicalMemory = 0 })
    $operatingSystem = Get-SafeValue { Get-ClassData Win32_OperatingSystem } ([pscustomobject]@{ Caption = ''; Version = ''; BuildNumber = ''; LastBootUpTime = (Get-Date) })
    $processor = Get-SafeValue { Get-ClassData Win32_Processor | Select-Object -First 1 } ([pscustomobject]@{ Name = ''; NumberOfLogicalProcessors = 0 })
    $bios = Get-SafeValue { Get-ClassData Win32_BIOS } ([pscustomobject]@{ SerialNumber = ''; SMBIOSBIOSVersion = '' })
    $disk = @(Get-SafeValue { Get-ClassData Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } } @())
    $networkAdapters = @(Get-SafeValue { Get-ClassData Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true } } @())
    $tpm = Get-SafeValue { Get-Tpm }
    $bitLocker = Get-SafeValue { Get-BitLockerVolume -MountPoint $env:SystemDrive }
    $defender = Get-SafeValue { Get-MpComputerStatus }

    $inventory = [ordered]@{
        schemaVersion = '1.0'
        collectedAt = (Get-Date).ToUniversalTime().ToString('o')
        device = [ordered]@{
            computerName = $env:COMPUTERNAME
            domain = $computerSystem.Domain
            manufacturer = $computerSystem.Manufacturer
            model = $computerSystem.Model
            serialNumber = $bios.SerialNumber
            biosVersion = $bios.SMBIOSBIOSVersion
        }
        operatingSystem = [ordered]@{
            caption = $operatingSystem.Caption
            version = $operatingSystem.Version
            buildNumber = $operatingSystem.BuildNumber
            lastBootUpTime = ([datetime]$operatingSystem.LastBootUpTime).ToUniversalTime().ToString('o')
        }
        hardware = [ordered]@{
            cpu = $processor.Name
            logicalProcessors = $processor.NumberOfLogicalProcessors
            memoryGb = [Math]::Round(($computerSystem.TotalPhysicalMemory / 1GB), 2)
        }
        storage = @($disk | ForEach-Object {
            [ordered]@{
                drive = $_.DeviceID
                fileSystem = $_.FileSystem
                totalGb = if ($_.Size) { [Math]::Round($_.Size / 1GB, 2) } else { 0 }
                freeGb = if ($_.FreeSpace) { [Math]::Round($_.FreeSpace / 1GB, 2) } else { 0 }
            }
        })
        network = @($networkAdapters | ForEach-Object {
            [ordered]@{
                adapter = $_.Description
                macAddress = $_.MACAddress
                ipAddresses = @($_.IPAddress)
                gateways = @($_.DefaultIPGateway)
                dnsServers = @($_.DNSServerSearchOrder)
            }
        })
        security = [ordered]@{
            bitLockerProtectionStatus = if ($bitLocker) { $bitLocker.ProtectionStatus.ToString() } else { 'Unknown' }
            secureBootEnabled = Get-SafeValue { Confirm-SecureBootUEFI } 'Unsupported'
            tpmPresent = if ($tpm) { [bool]$tpm.TpmPresent } else { $false }
            tpmReady = if ($tpm) { [bool]$tpm.TpmReady } else { $false }
            defenderAntivirusEnabled = if ($defender) { [bool]$defender.AntivirusEnabled } else { $null }
            pendingReboot = Test-PendingReboot
        }
        installedSoftware = @(
            @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*') |
                ForEach-Object { Get-ItemProperty $_ -ErrorAction SilentlyContinue } |
                Where-Object { $_.DisplayName } |
                Sort-Object DisplayName -Unique |
                ForEach-Object { [ordered]@{ name = $_.DisplayName; version = $_.DisplayVersion } }
        )
    }

    if ($Format -eq 'Json') {
        $output = $inventory | ConvertTo-Json -Depth 6
    } else {
        $output = @(
            '=== SYSTEM INVENTORY ==='
            "Timestamp: $($inventory.collectedAt)"
            "ComputerName: $($inventory.device.computerName)"
            "Domain: $($inventory.device.domain)"
            "Manufacturer: $($inventory.device.manufacturer)"
            "Model: $($inventory.device.model)"
            "SerialNumber: $($inventory.device.serialNumber)"
            "OS: $($inventory.operatingSystem.caption)"
            "OSBuild: $($inventory.operatingSystem.buildNumber)"
            "CPU: $($inventory.hardware.cpu)"
            "RAM_GB: $($inventory.hardware.memoryGb)"
            "BitLocker: $($inventory.security.bitLockerProtectionStatus)"
            "SecureBoot: $($inventory.security.secureBootEnabled)"
            "TPMReady: $($inventory.security.tpmReady)"
            "PendingReboot: $($inventory.security.pendingReboot)"
        )
    }

    if ($OutputPath) {
        $parent = Split-Path -Path $OutputPath -Parent
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            New-Item -Path $parent -ItemType Directory -Force | Out-Null
        }
        Set-Content -LiteralPath $OutputPath -Value $output -Encoding UTF8
    } else {
        $output
    }
}
catch {
    Write-Error "Inventory collection failed: $($_.Exception.Message)"
    exit 1
}
