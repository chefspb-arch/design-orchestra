# install.ps1 - registers the `orchestra` command in your PowerShell profile.
# Run ONCE, from anywhere, any way you like:
#
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
#
# The repository path comes from this file's own location ($PSScriptRoot),
# so the folder can be named anything and live anywhere.
#
#   .\install.ps1 -Uninstall   - remove the command from the profile

param(
  [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$root   = $PSScriptRoot
$script = Join-Path $root "dist\init-orchestra.ps1"
$begin  = "# >>> design-orchestra >>>"
$end    = "# <<< design-orchestra <<<"

if (-not (Test-Path $script)) {
  Write-Host "Not found: $script" -ForegroundColor Red
  Write-Host "Run install.ps1 from the root of the unpacked repository." -ForegroundColor Red
  exit 1
}

if (-not (Test-Path $PROFILE)) {
  New-Item -Path $PROFILE -ItemType File -Force | Out-Null
  Write-Host "Created PowerShell profile: $PROFILE"
}

# Idempotency: the old block is cut out whole, then a fresh one is appended
# if needed. Running this twice never produces duplicates.
$lines = @(Get-Content $PROFILE -Encoding UTF8)
$kept  = @()
$skip  = $false
$found = $false
foreach ($ln in $lines) {
  if ($ln.Trim() -eq $begin) { $skip = $true; $found = $true; continue }
  if ($ln.Trim() -eq $end)   { $skip = $false; continue }
  if (-not $skip) { $kept += $ln }
}

if ($Uninstall) {
  if (-not $found) {
    Write-Host "No orchestra command found in the profile - nothing to remove."
    exit 0
  }
  Set-Content -Path $PROFILE -Value $kept -Encoding UTF8
  Write-Host "The orchestra command was removed. Restart PowerShell." -ForegroundColor Green
  exit 0
}

$block = @(
  $begin,
  "function orchestra { & `"$script`" @args }",
  $end
)
Set-Content -Path $PROFILE -Value (@($kept) + $block) -Encoding UTF8

# Windows marks files downloaded from the internet as blocked and PowerShell
# refuses to run them. We clear that mark on scripts only.
Get-ChildItem -Path $root -Recurse -Include *.ps1 -ErrorAction SilentlyContinue |
  Unblock-File -ErrorAction SilentlyContinue

Write-Host ""
if ($found) {
  Write-Host "The orchestra command was updated in your profile." -ForegroundColor Green
} else {
  Write-Host "The orchestra command was added to your profile." -ForegroundColor Green
}
Write-Host "Profile: $PROFILE"
Write-Host "Script:  $script"
Write-Host ""
Write-Host "Restart PowerShell, then in your project folder:" -ForegroundColor Yellow
Write-Host "  orchestra"
Write-Host ""

$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq "Restricted" -or $policy -eq "Undefined") {
  Write-Host "Current execution policy: $policy - orchestra will not start." -ForegroundColor Yellow
  Write-Host "Allow local scripts (once):" -ForegroundColor Yellow
  Write-Host "  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
}

# Explicit exit for the same reason as in dist/init-orchestra.ps1: without it
# $LASTEXITCODE keeps whatever the caller had before, and success looks like
# failure.
exit 0
