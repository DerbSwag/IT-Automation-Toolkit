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

Describe 'GLPI registration portal hardening' {
    $portal = Get-Content "$here\..\glpi\web\register.php" -Raw

    It 'loads its config outside the web directory by default' {
        $portal | Should Match "dirname\(__DIR__\) . '/glpi_config.ini'"
    }

    It 'requires an allowed client subnet and has no VLAN fallback token' {
        $portal | Should Match 'isAllowedClient\(\$clientIp\)'
        $portal | Should Not Match 'default VLAN1'
    }

    It 'uses exact GLPI searches for computer, user, and group links' {
        $portal | Should Match 'search/Computer.*searchtype]=equals'
        $portal | Should Match 'search/User.*searchtype]=equals'
        $portal | Should Match 'search/Group.*searchtype]=equals'
    }

    It 'escapes the displayed hostname and never redirects from HTTP_HOST' {
        $portal | Should Match 'htmlspecialchars\(\$hostname \?:'
        $portal | Should Not Match 'HTTP_HOST'
    }

    It 'stores logs outside the web directory and supports one-time registration tokens' {
        $portal | Should Match "dirname\(__DIR__, 2\) . '/var/log/glpi-registration'"
        $portal | Should Match 'REQUIRE_REGISTRATION_TOKEN'
        $portal | Should Match 'consumeRegistrationToken'
    }

    It 'takes the GLPI computer state and asset field from configuration' {
        $portal | Should Match 'defaultComputerStateId'
        $portal | Should Match 'assetNumberField'
    }
}

Describe 'New-RegistrationToken.ps1' {
    $tokenScript = "$here\..\glpi\scripts\New-RegistrationToken.ps1"

    It 'parses without syntax errors' {
        $tokens = $null; $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($tokenScript, [ref]$tokens, [ref]$errors) | Out-Null
        $errors.Count | Should Be 0
    }

    It 'requires hostname, Lark account, and a local configuration file' {
        $content = Get-Content $tokenScript -Raw
        $content | Should Match '\$Hostname'
        $content | Should Match '\$LarkAccount'
        $content | Should Match 'REGISTRATION_TOKEN_SECRET'
        $content | Should Match 'PUBLIC_BASE_URL'
    }
}
