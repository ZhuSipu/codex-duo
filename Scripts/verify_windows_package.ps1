[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$PublishDirectory)

$ErrorActionPreference = 'Stop'
foreach ($relative in @('CodexDuo.exe', 'Helpers\codex-auth.exe', 'Helpers\manifest.json', 'Helpers\LICENSE', 'THIRD_PARTY_NOTICES.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PublishDirectory $relative) -PathType Leaf)) {
        throw "Missing package content: $relative"
    }
}
$manifest = Get-Content -LiteralPath (Join-Path $PublishDirectory 'Helpers\manifest.json') -Raw | ConvertFrom-Json
$helper = Join-Path $PublishDirectory 'Helpers\codex-auth.exe'
if ($manifest.version -ne '0.3.0-alpha.10' -or $manifest.architecture -ne 'x64' -or
    (Get-FileHash -LiteralPath $helper -Algorithm SHA256).Hash -ne $manifest.executableSha256) {
    throw 'The packaged helper identity or checksum is invalid.'
}
$version = & $helper --version
if ($LASTEXITCODE -ne 0 -or $version -cne "codex-auth $($manifest.version)") { throw 'The packaged helper cannot run.' }
if (-not (Select-String -LiteralPath (Join-Path $PublishDirectory 'Helpers\LICENSE') -SimpleMatch 'Permission is hereby granted')) {
    throw 'The upstream license is incomplete.'
}
$runtimeConfig = Join-Path $PublishDirectory 'CodexDuo.runtimeconfig.json'
if (Test-Path -LiteralPath $runtimeConfig) {
    $config = Get-Content -LiteralPath $runtimeConfig -Raw | ConvertFrom-Json
    if (-not $config.runtimeOptions.includedFrameworks -or -not (Test-Path -LiteralPath (Join-Path $PublishDirectory 'coreclr.dll'))) {
        throw 'The primary installer must contain the .NET runtime.'
    }
}
Write-Host "Verified Windows package: $PublishDirectory"
