[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]{0,62}$')]
    [string]$Hostname,

    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9_.@-]{1,50}$')]
    [string]$LarkAccount,

    [ValidateRange(1, 1440)]
    [int]$ExpiresInMinutes = 15,

    [string]$ConfigPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'glpi_config.ini')
)

. (Join-Path $PSScriptRoot 'lib\Read-IniFile.ps1')

function ConvertTo-Base64Url {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

$config = Read-IniFile -Path $ConfigPath
$registration = $config['REGISTRATION']
if (-not $registration) { throw 'Missing [REGISTRATION] section in config.' }

$secret = [string]$registration['REGISTRATION_TOKEN_SECRET']
$baseUrl = ([string]$registration['PUBLIC_BASE_URL']).TrimEnd('/')
if ($secret.Length -lt 32) { throw 'REGISTRATION_TOKEN_SECRET must be at least 32 characters.' }
if ($baseUrl -notmatch '^https://') { throw 'PUBLIC_BASE_URL must start with https://.' }

$normalizedHostname = $Hostname.ToUpperInvariant()
$expires = [DateTimeOffset]::UtcNow.AddMinutes($ExpiresInMinutes).ToUnixTimeSeconds()
$nonceBytes = New-Object byte[] 24
(New-Object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes($nonceBytes)
$nonce = ConvertTo-Base64Url -Bytes $nonceBytes
$payload = "$normalizedHostname|$LarkAccount|$expires|$nonce"
$hmac = New-Object System.Security.Cryptography.HMACSHA256 ([Text.Encoding]::UTF8.GetBytes($secret))
$signature = ConvertTo-Base64Url -Bytes $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($payload))
$hmac.Dispose()

$token = "v1.$expires.$nonce.$signature"
$url = "$baseUrl?hn=$([uri]::EscapeDataString($normalizedHostname))&rt=$([uri]::EscapeDataString($token))"

[pscustomobject]@{
    Hostname   = $normalizedHostname
    LarkAccount = $LarkAccount
    ExpiresAtUtc = [DateTimeOffset]::FromUnixTimeSeconds($expires).UtcDateTime
    RegistrationUrl = $url
}
