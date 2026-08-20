$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $projectRoot "Windows\CodexDuo.Windows\CodexDuo.Windows.csproj"
$version = ([xml](Get-Content $project)).Project.PropertyGroup.Version
$publish = Join-Path $projectRoot "build\windows-x64"
$dist = Join-Path $projectRoot "dist"
$zip = Join-Path $dist "Codex-Duo-$version-Windows-x64-portable.zip"
$setup = Join-Path $dist "Codex-Duo-$version-Windows-x64-Setup.exe"
if ((Test-Path $zip) -or (Test-Path $setup)) { throw "Release output already exists for version $version" }
New-Item -ItemType Directory -Force $dist | Out-Null
dotnet publish $project -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:DebugType=None -o $publish

function Invoke-AuthenticodeSign([string]$Path) {
  if (-not $env:CODEX_DUO_SIGN_THUMBPRINT) { return }
  $signTool = (Get-Command signtool.exe -ErrorAction SilentlyContinue).Source
  if (-not $signTool) {
    $signTool = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe" | Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
  }
  if (-not $signTool) { throw "signtool.exe was not found" }
  $timestamp = if ($env:CODEX_DUO_TIMESTAMP_URL) { $env:CODEX_DUO_TIMESTAMP_URL } else { "http://timestamp.digicert.com" }
  & $signTool sign /sha1 $env:CODEX_DUO_SIGN_THUMBPRINT /fd SHA256 /tr $timestamp /td SHA256 $Path
  if ($LASTEXITCODE -ne 0) { throw "Authenticode signing failed: $Path" }
}

Invoke-AuthenticodeSign (Join-Path $publish "CodexDuo.exe")
Compress-Archive -Path "$publish\*" -DestinationPath $zip
$iscc = (Get-Command iscc.exe -ErrorAction SilentlyContinue).Source
if (-not $iscc) { $iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" }
if (-not (Test-Path $iscc)) { throw "Inno Setup 6 was not found. Install it with: choco install innosetup" }
& $iscc "/DPublishDir=$publish" "/DOutputDir=$dist" (Join-Path $projectRoot "Windows\installer.iss")
if ($LASTEXITCODE -ne 0) { throw "Inno Setup packaging failed" }
Invoke-AuthenticodeSign $setup
$hashes = Get-FileHash $zip, $setup -Algorithm SHA256
$hashes | ForEach-Object { "$($_.Hash.ToLowerInvariant())  $(Split-Path -Leaf $_.Path)" } | Set-Content -Encoding ascii (Join-Path $dist "SHA256SUMS-Windows.txt")
$hashes | Format-Table -AutoSize
