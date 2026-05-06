$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Describe 'Get-PCInfo' {
    It 'produces output to stdout' {
        $output = & "$here\..\inventory\Get-PCInfo.ps1" | Out-String
        $output | Should Not BeNullOrEmpty
        $output | Should Match 'SYSTEM INVENTORY'
    }

    It 'writes to file when -OutputPath specified' {
        $outFile = Join-Path $TestDrive 'inventory.txt'
        & "$here\..\inventory\Get-PCInfo.ps1" -OutputPath $outFile
        (Test-Path $outFile) | Should Be $true
        (Get-Content $outFile) -contains '=== SYSTEM INVENTORY ===' | Should Be $true
    }

    It 'includes hostname' {
        $output = & "$here\..\inventory\Get-PCInfo.ps1"
        ($output -join "`n") | Should Match "ComputerName: $env:COMPUTERNAME"
    }
}
