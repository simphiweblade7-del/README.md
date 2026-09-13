# ============================================================
#  SystemBoost - Clean.ps1
#  Disk-space freeing routines (default = aggressive).
# ============================================================

# Free space from user + system temp locations
function Clean-TempFiles {
    Write-Step "Cleaning temporary files"
    $targets = @(
        $env:TEMP,
        $env:TMP,
        (Join-Path $env:windir "Temp"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\Windows\INetCache"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Explorer"),
        (Join-Path $env:LOCALAPPDATA "CrashDumps"),
        (Join-Path $env:LOCALAPPDATA "Temp"),
        (Join-Path $env:windir "Logs\CBS")
    ) | Where-Object { $_ } | Select-Object -Unique -First 30

    foreach ($t in $targets) {
        # Never touch the root of a drive or critical system dirs
        if (-not (Test-SbPathKnown -Path $t)) { continue }

        # For the Explorer cache, only delete thumbcache/iconcache files,
        # NOT the entire folder (Explorer keeps other state there).
        if ($t -like "*\Microsoft\Windows\Explorer") {
            Get-ChildItem -LiteralPath $t -File -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match "^thumbcache|^iconcache" } |
                Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Info "Thumbnail & icon cache cleared in $t"
            continue
        }
        # Clear contents of the folder (leave the folder itself)
        Clear-FolderContents -Path $t
    }
}

# Free space from Windows Update download cache
function Clean-WindowsUpdateCache {
    Write-Step "Cleaning Windows Update download cache"
    $d = Join-Path $env:windir "SoftwareDistribution\Download"
    Clear-FolderContents -Path $d -Silent
    Clear-FolderContents -Path (Join-Path $env:windir "SoftwareDistribution\DeliveryOptimization") -Silent
    Write-Ok "Windows Update cache cleaned"
}

# Clear browser caches (multiple profiles)
function Clear-BrowserCacheDir {
    param([string]$Pattern)
    if (-not $Pattern) { return }
    Get-ChildItem -LiteralPath $Pattern -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.PSIsContainer } |
        ForEach-Object {
            $cache = Join-Path $_.FullName "Cache"
            $code  = Join-Path $_.FullName "Code Cache"
            $gpu   = Join-Path $_.FullName "GPUCache"
            foreach ($c in @($cache, $code, $gpu)) {
                if (Test-Path -LiteralPath $c) { Clear-FolderContents -Path $c -Silent }
            }
        }
}

function Clean-BrowserCaches {
    Write-Step "Cleaning browser caches"
    $done = @()

    $chrome = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data"
    if (Test-Path -LiteralPath $chrome) {
        Get-ChildItem -LiteralPath $chrome -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -in @("Default","Profile 1","Profile 2","Profile 3","Profile 4") } |
            ForEach-Object {
                foreach ($c in @("Cache","Code Cache","GPUCache","Service Worker\CacheStorage",
                                 "Service Worker\ScriptCache")) {
                    $full = Join-Path $_.FullName $c
                    if (Test-Path -LiteralPath $full) { Clear-FolderContents -Path $full -Silent }
                }
            }
        $done += "Chrome"
    }

    foreach ($browser in @("Edge", "BraveSoftware\Brave-Browser", "Opera Software\Opera")) {
        $base = Join-Path $env:LOCALAPPDATA $browser
        if (Test-Path -LiteralPath $base) {
            Get-ChildItem -LiteralPath $base -Recurse -Directory -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -in @("Cache","Code Cache","GPUCache") } |
                ForEach-Object { Clear-FolderContents -Path $_.FullName -Silent }
            # Edge/Chromium also keeps a "User Data" cache
            Clear-BrowserCacheDir -Pattern (Join-Path $base "*\User Data")
            $done += $browser
        }
    }

    # Firefox
    $ffProfiles = Join-Path $env:LOCALAPPDATA "Mozilla\Firefox\Profiles"
    if (Test-Path -LiteralPath $ffProfiles) {
        Get-ChildItem -LiteralPath $ffProfiles -Directory -Force -ErrorAction SilentlyContinue |
            ForEach-Object {
                foreach ($c in @("cache2","startupCache","thumbnails")) {
                    $full = Join-Path $_.FullName $c
                    if (Test-Path -LiteralPath $full) { Clear-FolderContents -Path $full -Silent }
                }
            }
        $done += "Firefox"
    }

    if ($done.Count) { Write-Ok ("Browser caches cleared: " + ($done -join ", ")) }
    else             { Write-Info "No browser caches found." }
}

# Empty the Recycle Bin
function Clean-RecycleBin {
    Write-Step "Emptying the Recycle Bin"
    try {
        $drives = (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue).Name
        $cleared = $false
        foreach ($d in $drives) {
            Clear-RecycleBin -DriveLetter $d -Force -ErrorAction SilentlyContinue | Out-Null
            $cleared = $true
        }
        if ($cleared) { Write-Ok "Recycle Bin emptied" }
        else { Write-Info "Recycle Bin already empty" }
    } catch {
        # Fallback via Shell COM
        try {
            $sh = New-Object -ComObject Shell.Application
            $sh.NameSpace(10).Items() | ForEach-Object { $_.InvokeVerb("Delete") }
            Write-Ok "Recycle Bin emptied"
        } catch {
            Write-Warn "Could not empty Recycle Bin: $($_.Exception.Message)"
        }
    }
}

# Aggressive: prefetch, error reports, delivery optimization, crash dumps
function Clean-AggressiveExtras {
    Write-Step "Aggressive extras (freeing more space)"
    # Prefetch (old entries only would be ideal; safe enough to clear stale ones)
    Clear-FolderContents -Path (Join-Path $env:windir "Prefetch") -Silent

    # Windows Error Reporting queues
    Clear-FolderContents -Path (Join-Path $env:ProgramData "Microsoft\Windows\WER\ReportQueue") -Silent
    Clear-FolderContents -Path (Join-Path $env:ProgramData "Microsoft\Windows\WER\ReportArchive") -Silent
    Clear-FolderContents -Path (Join-Path $env:LOCALAPPDATA "Microsoft\Windows\WER") -Silent

    # Delivery Optimization cache
    Clear-FolderContents -Path (Join-Path $env:ProgramData "Microsoft\Windows\DeliveryOptimization\Cache") -Silent

    # Font cache
    Clear-FolderContents -Path (Join-Path $env:LOCALAPPDATA "Microsoft\Windows\FontCache") -Silent

    # Stale Sysinternals / temp under ProgramData
    Clear-FolderContents -Path (Join-Path $env:ProgramData "Temp") -Silent

    Write-Ok "Aggressive temp/error-report caches cleared"
}

# DISM component store cleanup (WinSxS) - can take several minutes
function Clean-ComponentStore {
    param([switch]$SkipAsk)
    Write-Step "Cleaning Windows component store (WinSxS) via DISM"
    if (-not $SkipAsk) {
        $c = Read-Host "  This can take 5-20 minutes. Run now? (y/n)"
        if ($c -notmatch "^[yY]") { Write-Info "Skipped."; return }
    }
    try {
        $out = & dism.exe /Online /Cleanup-Image /StartComponentCleanup 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Component store cleaned"
        } else {
            Write-Warn ("DISM returned exit code {0}. It may still have freed space." -f $LASTEXITCODE)
        }
        $script:TotalFreed = $script:TotalFreed + 0
    } catch {
        Write-Warn "DISM cleanup issue: $($_.Exception.Message)"
    }
}

# Remove Windows.old (previous installation) - aggressive
function Remove-WindowsOld {
    param([switch]$SkipAsk)
    $old = Join-Path $env:SystemDrive "Windows.old"
    if (-not (Test-Path -LiteralPath $old)) {
        Write-Info "No Windows.old folder present."
        return
    }
    Write-Warn "Windows.old holds your previous Windows install (~10-30 GB)."
    if (-not $SkipAsk) {
        $c = Read-Host "  Permanently delete Windows.old? (y/n)"
        if ($c -notmatch "^[yY]") { Write-Info "Skipped."; return }
    }
    $size = Get-FolderSizeMB -Path $old
    try {
        # take ownership so we can delete it
        takeown /f "$old" /r /d y 2>$null | Out-Null
        icacls "$old" /grant "*S-1-5-32-544:F" /t /c 2>$null | Out-Null
        Remove-Item -LiteralPath $old -Recurse -Force -ErrorAction Stop
        $script:TotalFreed += $size
        Write-Ok ("Windows.old removed (freed ~{0} MB)" -f $size)
    } catch {
        Write-Warn "Could not remove Windows.old: $($_.Exception.Message)"
        Write-Warn "It may be locked; try again after a restart, or use Disk Cleanup."
    }
}

# Master disk-space entry point.
#   -QuickOnly : only fast, obviously-safe cleaning
#   -SkipAsk   : do not prompt for the destructive items (aggressive, non-interactive)
function Invoke-CleanDiskSpace {
    param([switch]$QuickOnly, [switch]$SkipAsk)

    Write-Title "DISK SPACE CLEANUP"
    Write-Info ("Free space before: {0} MB on {1}" -f (Get-FreeSpaceMB -Path $env:SystemDrive), $env:SystemDrive)

    Clean-TempFiles
    Clean-WindowsUpdateCache
    Clean-BrowserCaches
    Clean-RecycleBin

    if (-not $QuickOnly) {
        Clean-AggressiveExtras
        Clean-ComponentStore -SkipAsk:$SkipAsk
        Remove-WindowsOld -SkipAsk:$SkipAsk
    }

    Write-Host ""
    Write-Host ("  Total freed this run: {0} MB" -f [math]::Round($script:TotalFreed, 2)) -ForegroundColor Green
    Write-Info ("Free space after: {0} MB on {1}" -f (Get-FreeSpaceMB -Path $env:SystemDrive), $env:SystemDrive)
    Add-SbLog ("DISK CLEANUP done, freed {0} MB" -f $script:TotalFreed)
}
