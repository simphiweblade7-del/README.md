# ============================================================
#  SystemBoost  v1.0.0
#  Free disk space & make Windows run faster.
#  Portable: run from any folder / USB. Admin rights required.
#
#  Usage (command line):
#    SystemBoost.bat            -> interactive menu
#    SystemBoost.bat /clean     -> aggressive disk space cleanup
#    SystemBoost.bat /quickclean-> safe, fast cleanup only
#    SystemBoost.bat /optimize  -> performance & speed tweaks
#    SystemBoost.bat /full      -> clean + optimize
#    SystemBoost.bat /report    -> system report (no changes)
#    SystemBoost.bat /undo      -> revert the last SystemBoost run
#    SystemBoost.bat /yes       -> auto-confirm (no prompts)
#    SystemBoost.bat /norestore -> skip creating a restore point
#    SystemBoost.bat /build-usb=DRIVE -> copy the tool to a USB drive
# ============================================================

$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Load modules (each defines functions into this scope)
. (Join-Path $script:ScriptDir "modules\Common.ps1")
. (Join-Path $script:ScriptDir "modules\Clean.ps1")
. (Join-Path $script:ScriptDir "modules\Optimize.ps1")
. (Join-Path $script:ScriptDir "modules\Report.ps1")

# --- Parse arguments (handle both /flag  and  -flag) ----------------------
$script:YesAll   = $false
$script:Silent   = $false
$script:NoRestore= $false
$script:BuildUsb = ""
$script:Quick    = $false
$script:Top      = $false
$script:DoClean  = $false
$script:DoOpt    = $false
$script:DoReport = $false
$script:DoUndo   = $false

foreach ($a in $args) {
    $t = "$a"
    $t = $t.TrimStart("-", "/")
    $t = $t.Trim()
    if ($t -match "^(build-usb|usb)=(.*)$") {
        $script:BuildUsb = $Matches[2]
        $script:BuildUsb = $script:BuildUsb.Trim('"').Trim()
    }
    elseif ($t -in @("clean","space","diskclean"))     { $script:DoClean = $true }
    elseif ($t -in @("quickclean","quick"))            { $script:DoClean = $true; $script:Quick = $true }
    elseif ($t -in @("optimize","speed","fast"))       { $script:DoOpt   = $true }
    elseif ($t -in @("full","boost","all","thorough")) { $script:DoClean = $true; $script:DoOpt = $true }
    elseif ($t -in @("report","info","diagnostics"))   { $script:DoReport = $true; $script:Top = $true }
    elseif ($t -in @("info","sysinfo"))                { $script:DoReport = $true }
    elseif ($t -in @("restore","undo","revert"))       { $script:DoUndo  = $true }
    elseif ($t -in @("yes","y","all","auto"))          { $script:YesAll  = $true }
    elseif ($t -in @("silent","s"))                    { $script:Silent  = $true }
    elseif ($t -in @("norestore","nor"))               { $script:NoRestore= $true }
    elseif ($t -eq "top")                              { $script:Top = $true }
}

$script:SkipAsk = ($script:YesAll -or $script:Silent)

# --- Load config ----------------------------------------------------------
Get-SbConfig

# --- Undo / restore -------------------------------------------------------
function Invoke-SbRestore {
    Write-Title "UNDO SYSTEMBOOST CHANGES"
    $data = Read-SbUndo
    if ($null -eq $data -or $null -eq $data.items -or $data.items.Count -eq 0) {
        Write-Info "No previous SystemBoost changes to undo."
        return
    }
    Write-Info ("Found {0} recorded change(s) from {1}." -f $data.items.Count, $data.saved)
    if (-not $script:YesAll) {
        $c = Read-Host "  Revert these now? (y/n)"
        if ($c -notmatch "^[yY]") { Write-Info "Cancelled."; return }
    }
    New-SbRestorePoint -Description "SystemBoost - BEFORE undo"

    $items = @($data.items)
    $n = 0
    for ($i = $items.Count - 1; $i -ge 0; $i--) {
        $it = $items[$i]
        $t = $it.Type
        try {
            if ($t -eq "Registry") {
                $path = $it.Path; $name = $it.Name; $orig = $it.Original
                if ($null -ne $orig -and "$orig" -ne "") {
                    if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -Force | Out-Null }
                if ($orig -is [int] -or $orig -is [long] -or $orig -is [double]) { Set-ItemProperty -LiteralPath $path -Name $name -Value ([int]$orig) -Type DWord }
                else { Set-ItemProperty -LiteralPath $path -Name $name -Value "$orig" -Type String }
                } else {
                    Remove-ItemProperty -LiteralPath $path -Name $name -Force -ErrorAction SilentlyContinue
                }
                Write-Ok ("Restored registry: {0}\{1}" -f $path, $name); $n++
            }
            elseif ($t -eq "Service") {
                $name = $it.Name; $mode = $it.Original
                $map = @{ "Auto" = "Automatic"; "Manual" = "Manual"; "Disabled" = "Disabled" }
                $st = if ($map[ $mode ]) { $map[ $mode ] } else { "Manual" }
                Set-Service -Name $name -StartupType $st -ErrorAction SilentlyContinue
                Start-Service -Name $name -ErrorAction SilentlyContinue
                Write-Ok ("Restored service: {0} -> {1}" -f $name, $st); $n++
            }
            elseif ($t -eq "StartupReg") {
                Set-ItemProperty -LiteralPath $it.Root -Name $it.Name -Value $it.Original -ErrorAction SilentlyContinue
                Write-Ok ("Re-enabled startup: {0}" -f $it.Name); $n++
            }
            elseif ($t -eq "StartupLnk") {
                $disabled = $it.Original + ".disabled"
                if (Test-Path -LiteralPath $disabled) {
                    Move-Item -LiteralPath $disabled -Destination $it.Original -Force -ErrorAction SilentlyContinue
                    Write-Ok ("Re-enabled startup: {0}" -f $it.Name); $n++
                }
            }
            elseif ($t -eq "PageFile") {
                $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
                if ($cs) { $cs.AutomaticManagedPagefile = $it.Original; Set-CimInstance -InputObject $cs -ErrorAction SilentlyContinue }
                Write-Ok "Restored virtual memory setting."
            }
        } catch {
            Write-Warn ("Could not undo item: {0} - {1}" -f $t, $_.Exception.Message)
        }
    }
    Clear-SbUndo
    Write-Host ""
    Write-Host ("  Undo complete. {0} item(s) restored." -f $n) -ForegroundColor Green
}

# --- Build USB package ----------------------------------------------------
function Invoke-BuildUsb {
    param([string]$Drive)
    Write-Title "BUILD USB PACKAGE"
    if (-not $Drive) {
        Write-Host "  Type the USB drive letter (e.g.  E  or  F:  )" -ForegroundColor Cyan
        $Drive = (Read-Host "  USB drive").Trim()
    }
    $Drive = $Drive.TrimEnd(":\/") -replace "[:/\\]", ""
    if ($Drive -notmatch "^[a-zA-Z]$") { Write-Err "Invalid drive letter: '$Drive'"; return }
    $root = "$($Drive.ToUpper()):\"
    if (-not (Test-Path -LiteralPath $root)) { Write-Err "Drive $root not found. Is the USB inserted?"; return }

    $dest = Join-Path $root "SystemBoost"
    if (Test-Path -LiteralPath $dest) {
        Write-Info "Removing old SystemBoost folder on the USB ..."
        Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    # Copy everything except the git folder
    Get-ChildItem -LiteralPath $script:ScriptDir -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne ".git" } |
        ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $dest -Recurse -Force -ErrorAction SilentlyContinue }

    # Root convenience launcher on the USB
    $rootLauncher = Join-Path $root "START-SystemBoost.bat"
    @(
      "@echo off",
      "echo.",
      "echo   Starting SystemBoost from USB ...",
      "echo.",
      "cd /d \"%~dp0SystemBoost\"",
      "call \"%~dp0SystemBoost\SystemBoost.bat\"",
      "pause"
    ) | Set-Content -LiteralPath $rootLauncher -Encoding ASCII

    # Short instructions on the USB
    $readme = Join-Path $root "README-SYSTEMBOOST.txt"
    @(
      "============================================================",
      " SYSTEMBOOST  -  free space + faster Windows (v1.0.0)",
      "============================================================",
      "",
      "HOW TO USE:",
      "  1. Keep this USB plugged in.",
      "  2. Double-click the file  START-SystemBoost.bat",
      "  3. SYSTEMBOOST requires Administrator rights.",
      "     If a blue 'User Account Control' box appears, click YES.",
      "",
      "MENU:  choose Free Space / Boost Speed / Full Boost / Report.",
      "",
      "SAFETY: a System Restore point is created before changes and",
      "        everything is logged. Use the 'Undo' menu option to",
      "        revert the last run.",
      "",
      "Works on Windows 10 and Windows 11.",
      ""
    ) | Set-Content -LiteralPath $readme -Encoding ASCII

    Write-Ok ("SystemBoost copied to {0}" -f $root)
    Write-Info ("Launcher: {0}" -f $rootLauncher)
    Write-Info ("Instructions: {0}" -f $readme)
    Write-Host "  --- USB build complete. You can now safely eject the drive. ---" -ForegroundColor Green
}

# --- Run an action --------------------------------------------------------
function Invoke-SbAction {
    if ($script:DoUndo) { Invoke-SbRestore; return }
    if ($script:BuildUsb) { Invoke-BuildUsb -Drive $script:BuildUsb; return }
    if ($script:DoReport -and -not $script:DoClean -and -not $script:DoOpt) {
        Invoke-SystemReport -TopConsumers:$script:Top
        return
    }

    if ($script:DoClean -or $script:DoOpt) {
        if (-not $script:NoRestore) {
            New-SbRestorePoint -Description "SystemBoost - before maintenance"
        } else {
            Write-Info "Restore point creation skipped (/norestore)."
        }
    }
    if ($script:DoClean) { Invoke-CleanDiskSpace -QuickOnly:$script:Quick -SkipAsk:$script:SkipAsk }
    if ($script:DoOpt)   { Invoke-OptimizePerformance -SkipAsk:$script:SkipAsk -Light:$script:Quick }

    if ($script:UndoItems.Count -gt 0) {
        $uf = Save-SbUndo
        Write-Host ""
        Write-Host ("  Changes were recorded so you can UNDO them. Undo file: {0}" -f $uf) -ForegroundColor Yellow
    }
    Write-Host ("  Log file: {0}" -f $script:LogFile) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Done." -ForegroundColor Green
}

# --- Interactive menu -----------------------------------------------------
function Invoke-SbMenu {
    while ($true) {
        Write-SbBanner
        Write-Host "  Choose an option:" -ForegroundColor White
        Write-Host "     1)  Free up disk space  (aggressive clean)"
        Write-Host "     2)  Quick clean          (fast, safe)"
        Write-Host "     3)  Boost speed          (performance tweaks)"
        Write-Host "     4)  FULL BOOST           (clean + speed, easiest)"
        Write-Host "     5)  System report        (info, no changes)"
        Write-Host "     6)  Undo last changes    (revert SystemBoost)"
        Write-Host "     7)  Build USB package    (copy tool to a USB)"
        Write-Host "     0)  Exit"
        Write-Host ""
        $sel = (Read-Host "  Enter your choice").Trim()
        switch ($sel) {
            "1" { if (-not $script:NoRestore) { New-SbRestorePoint -Description "SystemBoost - before maintenance" }; Invoke-CleanDiskSpace -SkipAsk:$script:SkipAsk; Save-UndoIfAny }
            "2" { if (-not $script:NoRestore) { New-SbRestorePoint -Description "SystemBoost - before quick clean" }; Invoke-CleanDiskSpace -QuickOnly -SkipAsk:$script:SkipAsk; Save-UndoIfAny }
            "3" { if (-not $script:NoRestore) { New-SbRestorePoint -Description "SystemBoost - before boost" }; Invoke-OptimizePerformance -SkipAsk:$script:SkipAsk; Save-UndoIfAny }
            "4" { if (-not $script:NoRestore) { New-SbRestorePoint -Description "SystemBoost - before full boost" }; Invoke-CleanDiskSpace -SkipAsk:$script:SkipAsk; Invoke-OptimizePerformance -SkipAsk:$script:SkipAsk; Save-UndoIfAny }
            "5" { Invoke-SystemReport -TopConsumers }
            "6" { Invoke-SbRestore }
            "7" { Invoke-BuildUsb }
        }
        Write-Host ""
        Read-Host "  Press Enter to return to the menu"
    }
}

function Save-UndoIfAny {
    if ($script:UndoItems.Count -gt 0) {
        $uf = Save-SbUndo
        Write-Host ("  Changes recorded so you can UNDO. File: {0}" -f $uf) -ForegroundColor Yellow
    }
}

# --- Entry point ----------------------------------------------------------
Confirm-AdminOrDie
Clear-Host
Write-SbBanner

$hasAction = ($script:DoClean -or $script:DoOpt -or $script:DoReport -or $script:DoUndo -or $script:BuildUsb)
if ($hasAction) {
    Invoke-SbAction
} else {
    Write-Info "Starting interactive menu (or use /clean, /optimize, /full, /report ...)"
    Invoke-SbMenu
}
