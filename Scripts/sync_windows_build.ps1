[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BuildExecutable
)

$ErrorActionPreference = "Stop"
$sourceExecutable = (Resolve-Path -LiteralPath $BuildExecutable).Path
if (-not (Test-Path -LiteralPath $sourceExecutable -PathType Leaf)) {
    throw "The Windows build did not produce CodexDuo.exe: $BuildExecutable"
}
$source = Split-Path -Parent $sourceExecutable

$installDirectory = Join-Path $env:LOCALAPPDATA "Programs\Codex Duo"
$installedExecutable = Join-Path $installDirectory "CodexDuo.exe"
if (-not (Test-Path -LiteralPath $installedExecutable)) {
    Write-Host "Codex Duo live sync skipped because the per-user installation was not found."
    exit 0
}

$running = Get-Process -Name "CodexDuo" -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -and $_.Path.StartsWith($installDirectory, [StringComparison]::OrdinalIgnoreCase) }
foreach ($process in $running) {
    Stop-Process -Id $process.Id
}
foreach ($process in $running) {
    try { $process.WaitForExit(5000) | Out-Null } catch [InvalidOperationException] { }
}

Copy-Item -Path (Join-Path $source "*") -Destination $installDirectory -Recurse -Force

$launcher = Start-Process -FilePath $installedExecutable -WindowStyle Hidden -PassThru
$launcherExited = $launcher.WaitForExit(5000)
$started = if (-not $launcherExited) { $launcher } else { $null }
if (-not $started) {
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        Start-Sleep -Milliseconds 100
        $started = Get-Process -Name "CodexDuo" -ErrorAction SilentlyContinue |
            Where-Object { $_.Id -ne $launcher.Id -and $_.Path -and $_.Path.Equals($installedExecutable, [StringComparison]::OrdinalIgnoreCase) } |
            Select-Object -First 1
        if ($started) { break }
    }
}
if (-not $started) {
    throw "The synchronized Codex Duo build did not start."
}

Write-Host "Codex Duo live sync complete: $installedExecutable (PID $($started.Id))"
