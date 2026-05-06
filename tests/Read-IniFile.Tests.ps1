$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$here\..\glpi\scripts\lib\Read-IniFile.ps1"

Describe 'Read-IniFile' {
    $testIni = Join-Path $TestDrive 'test.ini'

    BeforeEach {
        @'
[GLPI]
SERVER_URL=http://example.local
USER_TOKEN=abc123

[APP_TOKENS]
VLAN1=token1
VLAN2=token2
'@ | Set-Content $testIni
    }

    It 'parses sections correctly' {
        $result = Read-IniFile $testIni
        ($result.Keys -contains 'GLPI') | Should Be $true
        ($result.Keys -contains 'APP_TOKENS') | Should Be $true
    }

    It 'parses key-value pairs' {
        $result = Read-IniFile $testIni
        $result['GLPI']['SERVER_URL'] | Should Be 'http://example.local'
        $result['GLPI']['USER_TOKEN'] | Should Be 'abc123'
        $result['APP_TOKENS']['VLAN1'] | Should Be 'token1'
    }

    It 'throws on missing file' {
        { Read-IniFile 'C:\nonexistent\fake.ini' } | Should Throw
    }

    It 'handles empty values' {
        $emptyIni = Join-Path $TestDrive 'empty.ini'
        "[SECTION]`nKEY=" | Set-Content $emptyIni
        $result = Read-IniFile $emptyIni
        $result['SECTION']['KEY'] | Should Be ''
    }
}
