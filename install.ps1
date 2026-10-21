#requires -Version 5.1
<#
  Restore DSH (DeepSeek Harness) plugins from plugins.json.

  Usage:
    powershell -ExecutionPolicy Bypass -File install.ps1
    powershell -ExecutionPolicy Bypass -File install.ps1 -Profile desktop -DryRun

  Notes:
    - ASCII only on purpose: Windows PowerShell 5.1 reads BOM-less .ps1 as ANSI,
      so non-ASCII literals would turn into mojibake. Keep this file ASCII.
    - After installing you MUST fully quit DSH and start it again.
      Plugins are assembled at startup only.
#>
[CmdletBinding()]
param(
    [string]$Profile = 'desktop',
    [string]$DshPath = '',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Fail([string]$msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red; exit 1 }
function Info([string]$msg) { Write-Host "  $msg" }
function Step([string]$msg) { Write-Host "`n[*] $msg" -ForegroundColor Cyan }

# ---- 1. locate manifest ----------------------------------------------------
$rawBase = 'https://raw.githubusercontent.com/ctdlb/dsh-plugins/main'
$here = $PSScriptRoot
if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Definition }
$manifestPath = if ($here) { Join-Path $here 'plugins.json' } else { $null }

if ($manifestPath -and (Test-Path $manifestPath)) {
    $manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Step "Manifest: $manifestPath (updated $($manifest.updatedAt))"
} else {
    # Remote mode (Invoke-Expression / irm | iex): pull the manifest from GitHub.
    $url = "$rawBase/plugins.json"
    try {
        $manifest = Invoke-RestMethod -Uri $url -UseBasicParsing
    } catch {
        Fail "Cannot download manifest from $url : $($_.Exception.Message)"
    }
    Step "Manifest: $url (updated $($manifest.updatedAt))"
}

# ---- 2. locate dsh CLI -----------------------------------------------------
function Find-Dsh {
    $onPath = Get-Command dsh -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    $candidates = @(
        'D:\Program Files\DeepSeek Harness\resources\runtime\cli\bin\dsh.cmd',
        "$env:ProgramFiles\DeepSeek Harness\resources\runtime\cli\bin\dsh.cmd",
        "${env:ProgramFiles(x86)}\DeepSeek Harness\resources\runtime\cli\bin\dsh.cmd",
        "$env:LOCALAPPDATA\Programs\DeepSeek Harness\resources\runtime\cli\bin\dsh.cmd"
    )
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
    return $null
}

$dsh = if ($DshPath) { if (Test-Path $DshPath) { $DshPath } else { Fail "DshPath not found: $DshPath" } } else { Find-Dsh }
if (-not $dsh) {
    Fail "dsh CLI not found. Start DSH once, or pass -DshPath <...>\cli\bin\dsh.cmd"
}
Step "DSH CLI: $dsh"

# ---- 3. package list -------------------------------------------------------
$packages = @()
foreach ($prop in ($manifest.dependencies.PSObject.Properties | Sort-Object Name)) {
    $packages += "$($prop.Name)@$($prop.Value)"
}
if ($packages.Count -eq 0) { Fail "No dependencies listed in plugins.json" }

Step "Installing $($packages.Count) plugin(s) into profile '$Profile'"
foreach ($p in $packages) { Info $p }

if ($DryRun) {
    Write-Host "`n[DRY RUN] Nothing installed." -ForegroundColor Yellow
    exit 0
}

# ---- 4. install ------------------------------------------------------------
& $dsh plugin --profile $Profile add @packages
if ($LASTEXITCODE -ne 0) { Fail "pnpm/dsh returned exit code $LASTEXITCODE" }

# ---- 5. restore bundle order ----------------------------------------------
$dshHome = $env:DSH_HOME
if (-not $dshHome) { $dshHome = Join-Path $env:USERPROFILE '.dsh' }
$profileDir = Join-Path $dshHome (Join-Path 'profiles' $Profile)
$profilePkg = Join-Path $profileDir 'package.json'
if (Test-Path $profilePkg) {
    $pkg = Get-Content $profilePkg -Raw -Encoding UTF8 | ConvertFrom-Json
    $installed = @($pkg.dependencies.PSObject.Properties.Name)
    $ordered = @()
    foreach ($b in $manifest.bundles) { if ($installed -contains $b) { $ordered += $b } }
    foreach ($b in $pkg.dsh.profile.bundles) { if (($ordered -notcontains $b) -and ($installed -contains $b -or $b -like '@deepseek-ai/*')) { $ordered += $b } }
    $pkg.dsh.profile.bundles = $ordered
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($profilePkg, ($pkg | ConvertTo-Json -Depth 10), $utf8)
    Step "Bundle order restored ($($ordered.Count) entries) in $profilePkg"
}

# ---- 6. verify -------------------------------------------------------------
$nm = Join-Path $profileDir 'node_modules'
$missing = @()
foreach ($prop in $manifest.dependencies.PSObject.Properties) {
    if (-not (Test-Path (Join-Path $nm $prop.Name))) { $missing += $prop.Name }
}
if ($missing.Count -gt 0) {
    Write-Host "`n[WARN] Not found in node_modules: $($missing -join ', ')" -ForegroundColor Yellow
} else {
    Step "All $($manifest.dependencies.PSObject.Properties.Count) packages present in node_modules"
}

Write-Host "`n[DONE] Plugins installed." -ForegroundColor Green
Write-Host "Next: FULLY QUIT DSH (tray -> Exit) and start it again." -ForegroundColor Green
Write-Host "Plugins are assembled at startup only; closing the window is not enough." -ForegroundColor DarkGray
