$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here

Describe 'Batch Files' {
    It 'endpoint_toolkit.bat exists and is not empty' {
        $f = "$root\portable\endpoint_toolkit.bat"
        (Test-Path $f) | Should Be $true
        (Get-Item $f).Length | Should BeGreaterThan 0
    }

    It 'Install_GLPI_Agent.bat exists and is not empty' {
        $f = "$root\glpi\Install_GLPI_Agent.bat"
        (Test-Path $f) | Should Be $true
        (Get-Item $f).Length | Should BeGreaterThan 0
    }

    It 'inventory_glpi_agent.bat exists and is not empty' {
        $f = "$root\inventory\inventory_glpi_agent.bat"
        (Test-Path $f) | Should Be $true
        (Get-Item $f).Length | Should BeGreaterThan 0
    }

    It 'batch files use setlocal EnableExtensions' {
        $bats = git -C $root ls-files -- '*.bat' | ForEach-Object {
            Join-Path $root $_
        }
        foreach ($b in $bats) {
            $content = Get-Content $b -Raw
            $content | Should Match 'setlocal'
        }
    }

    It 'no hardcoded credentials in batch files' {
        $bats = Get-ChildItem $root -Recurse -Filter *.bat | Where-Object {
            $_.FullName -notmatch '_local-only'
        }
        foreach ($b in $bats) {
            $content = Get-Content $b.FullName -Raw
            $content | Should Not Match 'USER_TOKEN=(?!YOUR_)'
            $content | Should Not Match 'APP_TOKEN.*=(?!YOUR_)'
        }
    }
}
