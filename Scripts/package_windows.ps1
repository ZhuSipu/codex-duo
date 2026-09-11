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

$portablePublish = Join-Path $projectRoot "build\windows-$Runtime-portable"
$installerPublish = Join-Path $projectRoot "build\windows-$Runtime-installer"
$dist = Join-Path $projectRoot "dist"
$architecture = $Runtime.Replace("win-", "")
$zip = Join-Path $dist "Codex-Duo-$version-Windows-$architecture-portable.zip"
$setup = Join-Path $dist "Codex-Duo-$version-Windows-$architecture-Setup.exe"

foreach ($publishDirectory in @($portablePublish, $installerPublish)) {
    $resolvedPublish = [IO.Path]::GetFullPath($publishDirectory)
    $buildRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'build')) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedPublish.StartsWith($buildRoot, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe publish directory: $resolvedPublish" }
    if (Test-Path -LiteralPath $resolvedPublish) { Remove-Item -LiteralPath $resolvedPublish -Recurse -Force }
}
New-Item -ItemType Directory -Force -Path $portablePublish, $installerPublish, $dist | Out-Null
foreach ($artifact in @($zip, $setup)) {
    if (Test-Path -LiteralPath $artifact) { Remove-Item -LiteralPath $artifact -Force }
}

dotnet test (Join-Path $projectRoot "Windows\CodexDuo.Windows.Tests\CodexDuo.Windows.Tests.csproj") -c Release -p:SyncInstalledCodexDuo=false --nologo
if ($LASTEXITCODE -ne 0) { throw "Windows tests failed." }

dotnet publish $project -c Release -r $Runtime --self-contained true `
    -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:PublishReadyToRun=false -p:EnableCompressionInSingleFile=true `
    -p:DebugType=None -o $portablePublish --nologo
if ($LASTEXITCODE -ne 0) { throw "Windows portable publish failed." }

dotnet publish $project -c Release -r $Runtime --self-contained true `
    -p:PublishSingleFile=false -p:DebugType=None -o $installerPublish --nologo
if ($LASTEXITCODE -ne 0) { throw "Windows installer publish failed." }

$portableExecutable = Join-Path $portablePublish "CodexDuo.exe"
$installerExecutable = Join-Path $installerPublish "CodexDuo.exe"
foreach ($publishedExecutable in @($portableExecutable, $installerExecutable)) {
    if (-not (Test-Path -LiteralPath $publishedExecutable)) { throw "CodexDuo.exe was not produced: $publishedExecutable" }
}

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

foreach ($publishDirectory in @($portablePublish, $installerPublish)) {
    & (Join-Path $PSScriptRoot 'verify_windows_package.ps1') -PublishDirectory $publishDirectory
    $helper = Join-Path $publishDirectory 'Helpers\codex-auth.exe'
    Invoke-AuthenticodeSign $helper
    # Authenticode changes the on-disk hash. Record the signed payload for runtime integrity checks.
    $manifestPath = Join-Path $publishDirectory 'Helpers\manifest.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $manifest.executableSha256 = (Get-FileHash -LiteralPath $helper -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifest | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding utf8
}
Invoke-AuthenticodeSign $portableExecutable
Invoke-AuthenticodeSign $installerExecutable
Compress-Archive -LiteralPath (Get-ChildItem -LiteralPath $portablePublish).FullName -DestinationPath $zip -CompressionLevel Optimal

if (-not $SkipInstaller) {
    $iscc = (Get-Command ISCC.exe -ErrorAction SilentlyContinue).Source
    if (-not $iscc) {
        $candidates = @((Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe"), "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe")
        $iscc = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }
    if (-not $iscc) { throw "Inno Setup 6 was not found. Install it with winget install JRSoftware.InnoSetup." }
    & $iscc "/DPublishDir=$installerPublish" "/DOutputDir=$dist" "/DAppVersion=$version" "/DArchitecture=$architecture" (Join-Path $projectRoot "Windows\installer.iss")
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
