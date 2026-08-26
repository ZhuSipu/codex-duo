[CmdletBinding()]
param(
    [ValidateSet("win-x64")]
    [string]$Runtime = "win-x64",
    [switch]$SkipInstaller
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $projectRoot "Windows\CodexDuo.Windows\CodexDuo.Windows.csproj"
$projectXml = [xml](Get-Content -LiteralPath $project)
$version = [string]$projectXml.Project.PropertyGroup.Version
if ([string]::IsNullOrWhiteSpace($version)) { throw "The Windows project version is missing." }

$publish = Join-Path $projectRoot "build\windows-$Runtime"
$dist = Join-Path $projectRoot "dist"
$architecture = $Runtime.Replace("win-", "")
$zip = Join-Path $dist "Codex-Duo-$version-Windows-$architecture-portable.zip"
$setup = Join-Path $dist "Codex-Duo-$version-Windows-$architecture-Setup.exe"

if (Test-Path -LiteralPath $publish) { Remove-Item -LiteralPath $publish -Recurse -Force }
New-Item -ItemType Directory -Force -Path $publish, $dist | Out-Null
foreach ($artifact in @($zip, $setup)) {
    if (Test-Path -LiteralPath $artifact) { Remove-Item -LiteralPath $artifact -Force }
}

dotnet test (Join-Path $projectRoot "Windows\CodexDuo.Windows.Tests\CodexDuo.Windows.Tests.csproj") -c Release --nologo
if ($LASTEXITCODE -ne 0) { throw "Windows tests failed." }

dotnet publish $project -c Release -r $Runtime --self-contained true `
    -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:PublishReadyToRun=true -p:DebugType=None -o $publish --nologo
if ($LASTEXITCODE -ne 0) { throw "Windows publish failed." }

$publishedExecutable = Join-Path $publish "CodexDuo.exe"
if (-not (Test-Path -LiteralPath $publishedExecutable)) { throw "CodexDuo.exe was not produced." }

function Invoke-AuthenticodeSign([string]$Path) {
    if (-not $env:CODEX_DUO_SIGN_THUMBPRINT) { return }
    $signTool = (Get-Command signtool.exe -ErrorAction SilentlyContinue).Source
    if (-not $signTool) {
        $signTool = Get-ChildItem -Path "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe" -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $signTool) { throw "signtool.exe was not found." }
    $timestamp = if ($env:CODEX_DUO_TIMESTAMP_URL) { $env:CODEX_DUO_TIMESTAMP_URL } else { "http://timestamp.digicert.com" }
    & $signTool sign /sha1 $env:CODEX_DUO_SIGN_THUMBPRINT /fd SHA256 /tr $timestamp /td SHA256 $Path
    if ($LASTEXITCODE -ne 0) { throw "Authenticode signing failed: $Path" }
}

Invoke-AuthenticodeSign $publishedExecutable
Compress-Archive -LiteralPath (Get-ChildItem -LiteralPath $publish).FullName -DestinationPath $zip -CompressionLevel Optimal

if (-not $SkipInstaller) {
    $iscc = (Get-Command ISCC.exe -ErrorAction SilentlyContinue).Source
    if (-not $iscc) {
        $candidates = @((Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe"), "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe")
        $iscc = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }
    if (-not $iscc) { throw "Inno Setup 6 was not found. Install it with winget install JRSoftware.InnoSetup." }
    & $iscc "/DPublishDir=$publish" "/DOutputDir=$dist" "/DAppVersion=$version" "/DArchitecture=$architecture" (Join-Path $projectRoot "Windows\installer.iss")
    if ($LASTEXITCODE -ne 0) { throw "Inno Setup packaging failed." }
    if (-not (Test-Path -LiteralPath $setup)) { throw "The Windows installer was not produced." }
    Invoke-AuthenticodeSign $setup
}

$artifacts = @($zip)
if (Test-Path -LiteralPath $setup) { $artifacts += $setup }
$hashFile = Join-Path $dist "SHA256SUMS-Windows-$architecture.txt"
$artifacts | Get-FileHash -Algorithm SHA256 | ForEach-Object {
    "$($_.Hash.ToLowerInvariant())  $(Split-Path -Leaf $_.Path)"
} | Set-Content -LiteralPath $hashFile -Encoding ascii
Get-Item -LiteralPath ($artifacts + $hashFile) | Select-Object Name, Length, LastWriteTime
