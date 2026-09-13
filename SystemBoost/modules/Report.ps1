# ============================================================
#  SystemBoost - Report.ps1
#  System info, disk usage & diagnostics.
# ============================================================

function Get-SizeMB {
    param([string]$Path)
    $s = Get-FolderSizeMB -Path $Path
    return $s
}

function Invoke-SystemReport {
    param([switch]$TopConsumers)

    Write-Title "SYSTEM REPORT"

    # OS / computer basics
    Write-Step "System"
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    if ($os) {
        Write-Info ("OS:            {0}  (build {1})" -f $os.Caption, $os.BuildNumber)
        Write-Info ("Version:       {0}" -f $os.Version)
        Write-Info ("Computer:      {0}" -f $cs.Name)
        $up = (Get-Date) - $os.LastBootUpTime
        Write-Info ("Uptime:        {0}d {1}h {2}m" -f $up.Days, $up.Hours, $up.Minutes)
    }

    Write-Step "CPU & Memory"
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cpu) {
        $cores = $cpu.NumberOfCores; $threads = $cpu.NumberOfLogicalProcessors
        Write-Info ("CPU:           {0}  ({1} cores / {2} threads)" -f $cpu.Name.Trim(), $cores, $threads)
    }
    if ($os) {
        $total = [math]::Round($os.TotalVisibleMemorySize / 1KB, 1)
        $free  = [math]::Round($os.FreePhysicalMemory / 1KB, 1)
        Write-Info ("RAM:           {0} GB total, {1} GB free" -f $total, $free)
    }

    Write-Step "Disks"
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue |
        ForEach-Object {
            $total = [math]::Round($_.Size / 1GB, 1)
            $free  = [math]::Round($_.FreeSpace / 1GB, 1)
            $used  = [math]::Round($total - $free, 2)
            $pct   = if ($total -gt 0) { [math]::Round((($used) / $total) * 100, 0) } else { 0 }
            Write-Info ("  {0}  total {1} GB | used {2} GB ({3}%) | free {4} GB" -f $_.DeviceID, $total, $used, $pct, $free)
        }

    if ($TopConsumers) {
        Write-Step "Biggest space consumers on C: (top level folders)"
        $base = $env:SystemDrive + "\"
        try {
            Get-ChildItem -LiteralPath $base -Directory -Force -ErrorAction SilentlyContinue |
                ForEach-Object {
                    $m = Get-FolderSizeMB -Path $_.FullName
                    [pscustomobject]@{ Name = $_.Name; MB = [math]::Round($m, 1) }
                } | Sort-Object MB -Descending | Select-Object -First 12 |
                ForEach-Object {
                    $bar = "#" * [int][math]::Max(0, [math]::Min(30, $_.MB / 100))
                    Write-Host ("    {0,-22} {1,8} MB  {2}" -f $_.Name, $_.MB, $bar) -ForegroundColor Gray
                }
        } catch {
            Write-Warn "Could not compute top-level folder sizes (takes a while): $($_.Exception.Message)"
        }
    }

    Write-Step "Top memory consumers right now"
    Get-Process -ErrorAction SilentlyContinue |
        Sort-Object WS -Descending | Select-Object -First 10 |
        ForEach-Object {
            $mb = [math]::Round($_.WS / 1MB, 0)
            Write-Host ("    {0,-28} {1,7} MB   {2}" -f $_.ProcessName, $mb, $_.MainWindowTitle) -ForegroundColor Gray
        }

    Write-Host ""
    Write-Host ("  Script log: {0}" -f $script:LogFile) -ForegroundColor DarkGray
}
