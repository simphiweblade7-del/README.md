# ============================================================
#  SystemBoost - Common.ps1
#  Shared helper functions used across all SystemBoost modules.
#  Target: Windows 10/11, built-in Windows PowerShell 5.1
# ============================================================

# force strict-ish behavior but keep it PowerShell 5.1 compatible
Set-StrictMode -Off

# --- Script globals -------------------------------------------------------
$script:ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ProductName  = "SystemBoost"
$script:ProductVer   = "1.0.0"
$script:LogFile      = Join-Path $env:TEMP "SystemBoost.log"
$script:CfgFile      = Join-Path $script:ScriptDir "SystemBoost.config.json"
$script:Config       = @{}
$script:TotalFreed   = 0
$script:Failed       = 0

# --- Logging --------------------------------------------------------------
function Add-SbLog {
    param([string]$Message)
    try {
        $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
        Add-Content -LiteralPath $script:LogFile -Value $line -ErrorAction SilentlyContinue
    } catch { }
}

# --- Console helpers ------------------------------------------------------
function Write-Step   { param([string]$m) Write-Host ""; Write-Host "  $m" -ForegroundColor Cyan }
function Write-Info   { param([string]$m) Write-Host "    $m" -ForegroundColor Gray }
function Write-Ok     { param([string]$m) Write-Host "    [ OK ] $m" -ForegroundColor Green }
function Write-Warn   { param([string]$m) Write-Host "    [ ! ] $m" -ForegroundColor Yellow }
function Write-Err    { param([string]$m) Write-Host "    [ !! ] $m" -ForegroundColor Red; $script:Failed++ }
function Write-Title  { param([string]$m) Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor DarkCyan
    Write-Host ("  " + $m) -ForegroundColor White
    Write-Host ("=" * 70) -ForegroundColor DarkCyan }

function Write-SbBanner {
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor DarkCyan
    Write-Host ("  " + $script:ProductName + "  v" + $script:ProductVer) -ForegroundColor White
    Write-Host "  Free up disk space & make Windows run faster." -ForegroundColor Gray
    Write-Host ("  " + (Get-Date -Format "yyyy-MM-dd HH:mm")) -ForegroundColor DarkGray
    Write-Host ("=" * 70) -ForegroundColor DarkCyan
}

# --- Elevation / environment ---------------------------------------------
function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Confirm-AdminOrDie {
    if (-not (Test-IsAdmin)) {
        Write-Host ""
        Write-Host "  SystemBoost needs Administrator rights." -ForegroundColor Red
        Write-Host "  Right-click 'SystemBoost.bat' and choose 'Run as administrator',"
        Write-Host "  or re-launch from your USB drive so the script auto-elevates." -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
}

# --- Config ---------------------------------------------------------------
function Get-SbConfig {
    if (Test-Path -LiteralPath $script:CfgFile) {
        try {
            $script:Config = Get-Content -LiteralPath $script:CfgFile -Raw | ConvertFrom-Json
        } catch {
            $script:Config = @{}
            Write-Warn "Could not read config: $($_.Exception.Message)"
        }
    } else {
        $script:Config = @{}
    }
}

function Test-SbToggle {
    # test a boolean config switch, defaulting to $true
    param([string]$Name, [string]$Section = "general")
    try {
        $val = $script:Config.$Section.$Name
        if ($null -eq $val) { return $true }
        return ($val -ne $false -and "$val" -ne "false")
    } catch { return $true }
}

function Get-SbExclude {
    # returns an array of paths the user asked us to NEVER touch
    $ex = @()
    try {
        if ($script:Config.exclusions) { $ex = @($script:Config.exclusions) }
    } catch { }
    return $ex
}

function Test-Excluded {
    param([string]$Path)
    foreach ($e in (Get-SbExclude)) {
        if ($Path -eq $e) { return $true }
    }
    return $false
}

# --- Sizes ----------------------------------------------------------------
function Get-FolderSizeMB {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    try {
        $sum = (Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
        if ($null -eq $sum) { return 0 }
        return [math]::Round($sum / 1MB, 2)
    } catch { return 0 }
}

# --- Safe delete ----------------------------------------------------------
# Always removes the *contents* of a folder. Optionally removes the folder
# itself. Uses -LiteralPath so paths containing {GUID} are not treated as
# wildcards. Returns freed MB.
function Clear-FolderContents {
    param(
        [string]$Path,
        [switch]$RemoveFolder,
        [switch]$Silent
    )
    if (Test-Excluded -Path $Path) {
        if (-not $Silent) { Write-Warn "Skipped (excluded in config): $Path" }
        return 0
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        if (-not $Silent) { Write-Info "Not present, skipping: $Path" }
        return 0
    }
    $before = Get-FolderSizeMB -Path $Path
    try {
        if ($RemoveFolder) {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        } else {
            Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
        $after = Get-FolderSizeMB -Path $Path
        $freed = [math]::Round($before - $after, 2)
        if ($freed -lt 0) { $freed = 0 }
        $script:TotalFreed += $freed
        if (-not $Silent) {
            if ($freed -gt 0) { Write-Ok ("{0}  (freed ~{1} MB)" -f $Path, $freed) }
            else            { Write-Info ("{0}  (nothing to remove)" -f $Path) }
        }
        Add-SbLog ("CLEAN {0} -> {1} MB" -f $Path, $freed)
        return $freed
    } catch {
        $e = $_.Exception.Message
        $after = Get-FolderSizeMB -Path $Path
        $freed = [math]::Round($before - $after, 2)
        if ($freed -gt 0) {
            $script:TotalFreed += $freed
            if (-not $Silent) { Write-Ok ("{0}  (freed ~{1} MB, some files busy)" -f $Path, $freed) }
        } else {
            if (-not $Silent) { Write-Warn ("{0}  ({1})" -f $Path, $e) }
        }
        Add-SbLog ("CLEAN(PART) {0} -> {1} MB err={2}" -f $Path, $freed, $e)
        return $freed
    }
}

# --- Restore point --------------------------------------------------------
function New-SbRestorePoint {
    param([string]$Description = "SystemBoost - before maintenance")
    try {
        if (-not (Test-SbToggle -Name "allowRestorePoint" -Section "general")) {
            Write-Warn "System Restore point creation disabled in config."
            return $false
        }
        # make sure restore is enabled for the system drive
        $sys = $env:SystemDrive + "\"
        Enable-ComputerRestore -Drive $sys -ErrorAction SilentlyContinue | Out-Null
        if (-not (Get-ComputerRestorePoint -ErrorAction SilentlyContinue)) {
            Enable-ComputerRestore -Drive $sys -ErrorAction SilentlyContinue | Out-Null
        }
        Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Ok "System Restore point created: $Description"
        Add-SbLog ("RESTORE POINT created: " + $Description)
        return $true
    } catch {
        # Checkpoint-Computer is not always available; that is acceptable.
        Write-Warn "Could not create a System Restore point: $($_.Exception.Message)"
        Add-SbLog ("RESTORE POINT failed: " + $_.Exception.Message)
        return $false
    }
}

# --- Shortcuts ------------------------------------------------------------
function New-SbShortcut {
    param([string]$LnkPath, [string]$TargetPath, [string]$Arguments = "", [string]$IconPath = "")
    try {
        $ws = New-Object -ComObject WScript.Shell
        $sc = $ws.CreateShortcut($LnkPath)
        $sc.TargetPath = $TargetPath
        if ($Arguments) { $sc.Arguments = $Arguments }
        if ($IconPath)  { $sc.IconLocation = $IconPath }
        $sc.WorkingDirectory = (Split-Path -Parent $TargetPath)
        $sc.Save()
        return $true
    } catch {
        Write-Warn "Could not create shortcut $LnkPath : $($_.Exception.Message)"
        return $false
    }
}

# --- Undo / state persistence --------------------------------------------
# Aggressive actions are recorded so they can be reverted later.
$script:UndoItems = New-Object System.Collections.ArrayList

function Add-SbUndo {
    param([hashtable]$Item)
    [void]$script:UndoItems.Add($Item)
}

function Get-SbStateDir {
    $d = Join-Path $env:ProgramData "SystemBoost"
    if (-not (Test-Path -LiteralPath $d)) {
        try { New-Item -ItemType Directory -Path $d -Force -ErrorAction Stop | Out-Null } catch { }
    }
    return $d
}

function Save-SbUndo {
    try {
        $file = Join-Path (Get-SbStateDir) "undo.json"
        $obj = @{ saved = (Get-Date -Format "s"); items = @($script:UndoItems) }
        Set-Content -LiteralPath $file -Value ($obj | ConvertTo-Json -Depth 8) -Encoding UTF8
        return $file
    } catch { return $null }
}

function Read-SbUndo {
    $file = Join-Path (Get-SbStateDir) "undo.json"
    if (Test-Path -LiteralPath $file) {
        try { return (Get-Content -LiteralPath $file -Raw | ConvertFrom-Json) } catch { return $null }
    }
    return $null
}

function Clear-SbUndo {
    $file = Join-Path (Get-SbStateDir) "undo.json"
    if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue }
}

# --- Misc -----------------------------------------------------------------
function Get-FreeSpaceMB {
    param([string]$Path)
    try {
        $d = Get-PSDrive -PSProvider FileSystem | Where-Object { $Path -match "^$($_.Name):" } | Select-Object -First 1
        if ($d) { return [math]::Round($d.Free / 1MB, 2) }
        return 0
    } catch { return 0 }
}

function Test-SbPathKnown {
    # guard: don't let someone clean a folder that clearly isn't intended
    param([string]$Path)
    if (-not $Path) { return $false }
    $p = $Path.ToLower()
    $bad = @("c:\", "c:\windows", "c:\windows\system32", "c:\program files",
             "c:\program files (x86)", "c:\programdata", "c:\users")
    foreach ($b in $bad) { if ($p -eq $b) { return $false } }
    return $true
}
