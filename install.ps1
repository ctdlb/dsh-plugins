#requires -Version 5.1
<#
  Restore DSH (DeepSeek Harness) plugins AND their config from plugins.json.

  Usage:
    powershell -ExecutionPolicy Bypass -File install.ps1
    powershell -ExecutionPolicy Bypass -File install.ps1 -DryRun
    powershell -ExecutionPolicy Bypass -File install.ps1 -SkipInstall   # config only
    powershell -ExecutionPolicy Bypass -File install.ps1 -KeepConfig    # leave existing config alone

  What it restores:
    1. every dependency pinned in plugins.json
    2. the bundles load order inside the profile package.json
    3. every file listed in plugins.json.configFiles
       (patch layer = model/UI/plugin settings, market state, pnpm workspace exclusions)

  Notes:
    - ASCII only on purpose: Windows PowerShell 5.1 reads BOM-less .ps1 as ANSI,
      so non-ASCII literals would turn into mojibake. Keep this file ASCII.
    - Config files are overwritten by default; the previous copy stays as <file>.bak.
      Pass -KeepConfig to skip files that already exist.
    - After installing you MUST fully quit DSH and start it again.
      Plugins are assembled at startup only.
#>
[CmdletBinding()]
param(
    [string]$Profile = 'desktop',
    [string]$DshPath = '',
    [switch]$DryRun,
    [switch]$SkipInstall,
    [switch]$KeepConfig
)

$ErrorActionPreference = 'Stop'

function Fail([string]$msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red; exit 1 }
function Info([string]$msg) { Write-Host "  $msg" }
function Step([string]$msg) { Write-Host "`n[*] $msg" -ForegroundColor Cyan }

$rawBase = 'https://raw.githubusercontent.com/ctdlb/dsh-plugins/main'

# ---- 1. locate manifest ----------------------------------------------------
$here = $PSScriptRoot
if (-not $here) {
    try {
        $p = $MyInvocation.MyCommand.Path
        if ($p) { $here = Split-Path -Parent $p }
    } catch { $here = $null }
}
$manifestPath = if ($here) { Join-Path $here 'plugins.json' } else { $null }

if ($manifestPath -and (Test-Path $manifestPath)) {
    $manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Step "Manifest: $manifestPath (updated $($manifest.updatedAt))"
} else {
    # Remote mode (irm | iex): pull the manifest from GitHub.
    $url = "$rawBase/plugins.json"
    try {
        $manifest = Invoke-RestMethod -Uri $url -UseBasicParsing
    } catch {
        Fail "Cannot download manifest from $url : $($_.Exception.Message)"
    }
    Step "Manifest: $url (updated $($manifest.updatedAt))"
}

# ---- 2. profile paths ------------------------------------------------------
$dshHome = $env:DSH_HOME
if (-not $dshHome) { $dshHome = Join-Path $env:USERPROFILE '.dsh' }
$profileDir = Join-Path $dshHome (Join-Path 'profiles' $Profile)
$profilePkg = Join-Path $profileDir 'package.json'

# ---- 3. package list -------------------------------------------------------
$packages = @()
foreach ($prop in ($manifest.dependencies.PSObject.Properties | Sort-Object Name)) {
    $packages += "$($prop.Name)@$($prop.Value)"
}
if ($packages.Count -eq 0) { Fail "No dependencies listed in plugins.json" }

# ---- 4. config plan --------------------------------------------------------
$configSpecs = @()
$cf = $manifest.PSObject.Properties | Where-Object { $_.Name -eq 'configFiles' }
if ($cf -and $cf.Value) { $configSpecs = @($cf.Value) }

if ($DryRun) {
    Step "Plan for profile '$Profile' (dry run)"
    Write-Host "  DSH home : $dshHome"
    Write-Host "  Profile  : $profileDir"
    Write-Host "  Plugins  : $($packages.Count)"
    foreach ($p in $packages) { Info $p }
    Write-Host "  Config   : $($configSpecs.Count) file(s)"
    foreach ($spec in $configSpecs) {
        $t = ([string]$spec.target) -replace '\{profile\}', $Profile
        $exists = Test-Path -LiteralPath (Join-Path $dshHome $t)
        $note = if ($exists -and $KeepConfig) { ' (exists, would skip)' }
                elseif ($exists) { ' (exists, would overwrite, .bak kept)' }
                else { ' (new)' }
        Info "$t$note"
    }
    Write-Host "`n[DRY RUN] Nothing changed." -ForegroundColor Yellow
    exit 0
}

# ---- 5. install packages ---------------------------------------------------
if (-not $SkipInstall) {
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
    Step "Installing $($packages.Count) plugin(s) into profile '$Profile'"
    foreach ($p in $packages) { Info $p }

    & $dsh plugin --profile $Profile add @packages
    if ($LASTEXITCODE -ne 0) { Fail "pnpm/dsh returned exit code $LASTEXITCODE" }
}

# ---- 6. restore bundle order ----------------------------------------------
if (Test-Path -LiteralPath $profilePkg) {
    $pkg = Get-Content $profilePkg -Raw -Encoding UTF8 | ConvertFrom-Json
    $installed = @($pkg.dependencies.PSObject.Properties.Name)
    $ordered = @()
    foreach ($b in $manifest.bundles) { if ($installed -contains $b) { $ordered += $b } }
    foreach ($b in $pkg.dsh.profile.bundles) { if (($ordered -notcontains $b) -and ($installed -contains $b -or $b -like '@deepseek-ai/*')) { $ordered += $b } }
    $pkg.dsh.profile.bundles = $ordered
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($profilePkg, ($pkg | ConvertTo-Json -Depth 10), $utf8)
    Step "Bundle order restored ($($ordered.Count) entries) in $profilePkg"
} else {
    Write-Host "`n[WARN] profile package.json not found: $profilePkg" -ForegroundColor Yellow
}

# ---- 7. restore config files ----------------------------------------------
if ($configSpecs.Count -gt 0) {
    Step "Restoring $($configSpecs.Count) config file(s)"
    foreach ($spec in $configSpecs) {
        $targetRel = ([string]$spec.target) -replace '\{profile\}', $Profile
        $dest = Join-Path $dshHome $targetRel
        $src = if ($here) { Join-Path $here ([string]$spec.source) } else { $null }

        if (Test-Path -LiteralPath $dest) {
            if ($KeepConfig) { Info "skip (exists): $targetRel"; continue }
            Copy-Item -LiteralPath $dest -Destination ($dest + '.bak') -Force
            Info "backup: $targetRel.bak"
        }
        $destDir = Split-Path -Parent $dest
        if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

        if ($src -and (Test-Path -LiteralPath $src)) {
            Copy-Item -LiteralPath $src -Destination $dest -Force
        } else {
            $u = "$rawBase/$([string]$spec.source)"
            Invoke-WebRequest -Uri $u -OutFile $dest -UseBasicParsing
        }
        Info "wrote: $targetRel"
    }
}

# ---- 8. verify -------------------------------------------------------------
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

Write-Host "`n[DONE] Plugins and config restored." -ForegroundColor Green
Write-Host "Next: FULLY QUIT DSH (tray -> Exit) and start it again." -ForegroundColor Green
Write-Host "Plugins are assembled at startup only; closing the window is not enough." -ForegroundColor DarkGray
