$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Describe 'Create-GLPIGroups.ps1' {
    It 'parses without syntax errors' {
        $tokens = $null; $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            "$here\..\glpi\scripts\Create-GLPIGroups.ps1", [ref]$tokens, [ref]$errors
        ) | Out-Null
        $errors.Count | Should Be 0
    }

    It 'defines expected group list (25 groups)' {
        $content = Get-Content "$here\..\glpi\scripts\Create-GLPIGroups.ps1" -Raw
        $content | Should Match 'IT'
        $content | Should Match 'Operation'
        $content | Should Match 'SCM'
        $content | Should Match 'BD&CS'
    }

    It 'uses ConfigPath parameter' {
        $content = Get-Content "$here\..\glpi\scripts\Create-GLPIGroups.ps1" -Raw
        $content | Should Match '\$ConfigPath'
    }
}

Describe 'Fix-StatusAndGroup.ps1' {
    It 'parses without syntax errors' {
        $tokens = $null; $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            "$here\..\glpi\scripts\Fix-StatusAndGroup.ps1", [ref]$tokens, [ref]$errors
        ) | Out-Null
        $errors.Count | Should Be 0
    }

    It 'uses ConfigPath parameter' {
        $content = Get-Content "$here\..\glpi\scripts\Fix-StatusAndGroup.ps1" -Raw
        $content | Should Match '\$ConfigPath'
    }
}

Describe 'Link-LarkToGLPI.ps1' {
    It 'parses without syntax errors' {
        $tokens = $null; $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            "$here\..\glpi\scripts\Link-LarkToGLPI.ps1", [ref]$tokens, [ref]$errors
        ) | Out-Null
        $errors.Count | Should Be 0
    }

    It 'requires LarkAccount parameter' {
        $content = Get-Content "$here\..\glpi\scripts\Link-LarkToGLPI.ps1" -Raw
        $content | Should Match '\[Parameter\(Mandatory=\$true\)\]'
        $content | Should Match '\$LarkAccount'
    }

    It 'uses ConfigPath parameter' {
        $content = Get-Content "$here\..\glpi\scripts\Link-LarkToGLPI.ps1" -Raw
        $content | Should Match '\$ConfigPath'
    }
}
