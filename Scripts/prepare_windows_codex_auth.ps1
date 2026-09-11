[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Destination)

$ErrorActionPreference = 'Stop'
$env:PSModulePath = (Join-Path $PSHOME 'Modules') + ';' + $env:PSModulePath
$vendor = Join-Path (Split-Path -Parent $PSScriptRoot) 'Windows\Vendor\codex-auth\0.3.0-alpha.10'
$manifestPath = Join-Path $vendor 'manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$archive = Join-Path $vendor $manifest.archive
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $manifest.archiveSha256) {
    throw 'The bundled codex-auth archive checksum does not match.'
}
if ($manifest.architecture -ne 'x64') { throw 'Only the native Windows x64 helper is supported.' }
New-Item -ItemType Directory -Force -Path $Destination | Out-Null
Expand-Archive -LiteralPath $archive -DestinationPath $Destination -Force
$executable = Join-Path $Destination 'codex-auth.exe'
if ((Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash -ne $manifest.executableSha256) {
    throw 'The extracted codex-auth checksum does not match.'
}
$bytes = [IO.File]::ReadAllBytes($executable)
$pe = [BitConverter]::ToInt32($bytes, 0x3c)
if ($bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a -or
    [BitConverter]::ToUInt32($bytes, $pe) -ne 0x4550 -or
    [BitConverter]::ToUInt16($bytes, $pe + 4) -ne 0x8664) {
    throw 'The bundled codex-auth executable is not Windows x64 PE code.'
}
$version = & $executable --version
if ($LASTEXITCODE -ne 0 -or $version -cne "codex-auth $($manifest.version)") {
    throw 'The bundled codex-auth version does not match.'
}
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $Destination 'manifest.json') -Force
Copy-Item -LiteralPath (Join-Path $vendor 'LICENSE') -Destination (Join-Path $Destination 'LICENSE') -Force
