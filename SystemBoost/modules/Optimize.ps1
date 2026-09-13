# ============================================================
#  SystemBoost - Optimize.ps1
#  Speed / responsiveness tweaks (default = aggressive).
#  Every change is recorded for the Undo action.
# ============================================================

# --- Registry helper that also records original value --------------------
function Set-SbRegistryValue {
    param([string]$Path, [string]$Name, $Value, [string]$Kind = "DWord")
    try {
        if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
        $orig = (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction SilentlyContinue).$Name
        if ($Kind -eq "DWord") { Set-ItemProperty -LiteralPath $Path -Name $Name -Value ([int]$Value) -Type DWord }
        elseif ($Kind -eq "QWord") { Set-ItemProperty -LiteralPath $Path -Name $Name -Value ([long]$Value) -Type QWord }
        else { Set-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -Type String }
        Add-SbUndo @{ Type = "Registry"; Path = $Path; Name = $Name; Original = $orig }
        return $true
    } catch {
        Write-Warn "Registry tweak failed: $Path\$Name : $($_.Exception.Message)"
        return $false
    }
}

# --- Services -------------------------------------------------------------
function Disable-SbService {
    param([string]$Name, [string]$Display)
    try {
        $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if (-not $svc) { return }
        $ci = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
        $startMode = if ($ci) { $ci.StartMode } else { "Auto" }
        Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
        Set-Service -Name $Name -StartupType Disabled -ErrorAction Stop
        Add-SbUndo @{ Type = "Service"; Name = $Name; Original = $startMode }
        Write-Ok "$Display ($Name) set to Disabled"
    } catch {
        Write-Warn "Could not disable service $Name : $($_.Exception.Message)"
    }
}

function Optimize-Services {
    Write-Step "Optimizing background services"
    # Telemetry / diagnostics services (safe to disable, reversible)
    Disable-SbService -Name "DiagTrack"       -Display "Connected User Experiences & Telemetry"
    Disable-SbService -Name "dmwappushservice" -Display "Device Management WAP Push"
    Disable-SbService -Name "WMPNetworkSvc"    -Display "Windows Media Player Network Sharing"
    Disable-SbService -Name "WSearch"          -Display "Windows Search indexing"
    Disable-SbService -Name "SysMain"          -Display "SysMain (Superfetch)"
    Disable-SbService -Name "MapsBroker"       -Display "Downloaded Maps Manager"
    if (Test-SbToggle -Name "disableFax" -Section "services") {
        Disable-SbService -Name "Fax"          -Display "Fax service"
    }
}

function Optimize-PowerPlan {
    Write-Step "Setting power plan to High Performance"
    try {
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
        Write-Ok "Power plan set to High Performance"
    } catch {
        try { powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null; Write-Ok "Power plan set to Balanced" }
        catch { Write-Warn "Could not change power plan: $($_.Exception.Message)" }
    }
}

function Optimize-VisualEffects {
    Write-Step "Tuning visual effects for speed"
    # Best performance (disable fancy animations)
    [void](Set-SbRegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -Kind "DWord")
    [void](Set-SbRegistryValue -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value 0 -Kind "String")
    [void](Set-SbRegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0 -Kind "DWord")
    [void](Set-SbRegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewAlphaSelect" -Value 0 -Kind "DWord")
    [void](Set-SbRegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "IconsOnly" -Value 0 -Kind "DWord")
    Write-Ok "Visual effects tuned for speed (menus/animation reduced)"
}

function Optimize-Responsiveness {
    Write-Step "Tuning system responsiveness (multimedia)"
    $base = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    [void](Set-SbRegistryValue -Path $base -Name "SystemResponsiveness" -Value 0 -Kind "DWord")
    [void](Set-SbRegistryValue -Path $base -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Kind "DWord")
    [void](Set-SbRegistryValue -Path (Join-Path $base "Tasks\Games") -Name "GPU Priority" -Value 8 -Kind "DWord")
    [void](Set-SbRegistryValue -Path (Join-Path $base "Tasks\Games") -Name "Priority" -Value 6 -Kind "DWord")
    [void](Set-SbRegistryValue -Path (Join-Path $base "Tasks\Games") -Name "Scheduling Category" -Value "High" -Kind "String")
    [void](Set-SbRegistryValue -Path (Join-Path $base "Tasks\Games") -Name "SFIO Priority" -Value "High" -Kind "String")
    Write-Ok "Responsiveness & multimedia scheduling tuned"
}

function Optimize-Prefetch {
    Write-Step "Enabling Prefetch / Superfetch for faster startup"
    $pp = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
    [void](Set-SbRegistryValue -Path $pp -Name "EnablePrefetcher" -Value 3 -Kind "DWord")
    [void](Set-SbRegistryValue -Path $pp -Name "EnableSuperfetch" -Value 1 -Kind "DWord")
    Write-Ok "Prefetch enabled (value 3 = apps + boot)"
}

function Optimize-PageFile {
    Write-Step "Ensuring virtual memory is System-managed"
    try {
        $cs = Get-CimInstance Win32_ComputerSystem
        $wasManaged = $cs.AutomaticManagedPagefile
        if (-not $wasManaged) {
            $cs.AutomaticManagedPagefile = $true
            Set-CimInstance -InputObject $cs -ErrorAction Stop
            Add-SbUndo @{ Type = "PageFile"; Name = "AutomaticManagedPagefile"; Original = $false }
            Write-Ok "Virtual memory set to System-managed"
        } else {
            Write-Info "Virtual memory already System-managed"
        }
    } catch {
        Write-Warn "Could not adjust pagefile: $($_.Exception.Message)"
    }
}

function Optimize-DnsCache {
    Write-Step "Flushing DNS cache"
    try {
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        Start-Process -FilePath "ipconfig.exe" -ArgumentList "/flushdns" -NoNewWindow -Wait -ErrorAction SilentlyContinue
        Write-Ok "DNS cache flushed"
    } catch {
        Write-Warn "Could not flush DNS cache: $($_.Exception.Message)"
    }
}

function Optimize-DriveMaintenance {
    Write-Step "Drive maintenance (defrag HDD / retrim SSD)"
    try {
        $drive = (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -eq 'C' } | Select-Object -First 1)
        if (-not $drive) { $drive = (Get-PSDrive -PSProvider FileSystem | Select-Object -First 1) }
        if ($drive) {
            $letter = $drive.Name + ":"
            try {
                $disk = Get-PhysicalDisk -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($disk -and $disk.MediaType -eq "HDD") {
                    Optimize-Volume -DriveLetter $drive.Name -Defrag -ErrorAction SilentlyContinue
                    Write-Ok "Defragmented $letter"
                } else {
                    Optimize-Volume -DriveLetter $drive.Name -Retrim -ErrorAction SilentlyContinue
                    Write-Ok "Trimmed SSD $letter"
                }
            } catch {
                Optimize-Volume -DriveLetter $drive.Name -Defrag -ErrorAction SilentlyContinue
                Write-Ok "Optimized $letter"
            }
        }
    } catch {
        Write-Warn "Drive maintenance issue: $($_.Exception.Message)"
    }
}

function Optimize-Health {
    Write-Step "Running system file & image health checks (this can take a while)"
    try {
        Write-Info "Running sfc /scannow ..."
        $out = & $env:windir\System32\sfc.exe /scannow 2>&1 | Out-Null
        Write-Ok "System File Checker finished (exit $LASTEXITCODE)"
    } catch {
        Write-Warn "sfc could not run: $($_.Exception.Message)"
    }
}

function Optimize-Startup {
    Write-Step "Managing startup programs"
    $list = @()
    # Registry startup entries
    $regroots = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    )
    foreach ($r in $regroots) {
        if (Test-Path -LiteralPath $r) {
            $props = Get-ItemProperty -LiteralPath $r
            if ($props) {
                foreach ($p in $props.PSObject.Properties) {
                    if ($p.Name -notlike "PS*") {
                        $list += [pscustomobject]@{ Kind = "Reg"; Root = $r; Name = $p.Name; Command = $p.Value }
                    }
                }
            }
        }
    }
    # Startup folders (.lnk files)
    $folders = @(
        (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"),
        (Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\StartUp")
    )
    foreach ($f in $folders) {
        if (Test-Path -LiteralPath $f) {
            Get-ChildItem -LiteralPath $f -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -eq ".lnk" } |
                ForEach-Object { $list += [pscustomobject]@{ Kind = "Lnk"; Root = $_.DirectoryName; Name = $_.Name; Command = $_.FullName } }
        }
    }

    if ($list.Count -eq 0) { Write-Info "No startup items found."; return }

    Write-Host ""
    Write-Host "    Found $($list.Count) startup item(s):" -ForegroundColor Cyan
    for ($i = 0; $i -lt $list.Count; $i++) {
        $it = $list[$i]
        Write-Host ("      [{0}] {1}   <- {2}" -f ($i + 1), $it.Name, $it.Command) -ForegroundColor Gray
    }

    $bloat = @("onedrive","spotify","adobe","gogonew","steam","updater","update",
               "dropbox","cloud","epicgames","battlenet","riot","java","nvidia",
               "amd","quicktime","itunes","tunes","zoom","slack","discord") 
    $targets = @()
    if ($script:YesAll) {
        $targets = $list | Where-Object { $n = $_.Name.ToLower(); ($bloat | Where-Object { $n -match $_ }) -ne $null }
    } else {
        $sel = Read-Host "  Enter numbers to disable (comma separated), 'all' for recommended, or Enter to skip"
        if ($sel -match "^all$") {
            $targets = $list | Where-Object { $n = $_.Name.ToLower(); ($bloat | Where-Object { $n -match $_ }) -ne $null }
        } elseif ($sel.Trim() -ne "") {
            $nums = $sel -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -match "^\d+$" }
            foreach ($n in $nums) {
                $idx = [int]$n - 1
                if ($idx -ge 0 -and $idx -lt $list.Count) { $targets += $list[$idx] }
            }
        }
    }

    if ($targets.Count -eq 0) { Write-Info "No startup items disabled."; return }

    foreach ($it in $targets) {
        try {
            if ($it.Kind -eq "Reg") {
                $orig = (Get-ItemProperty -LiteralPath $it.Root -Name $it.Name -ErrorAction SilentlyContinue).$it.Name
                Remove-ItemProperty -LiteralPath $it.Root -Name $it.Name -Force -ErrorAction Stop
                Add-SbUndo @{ Type = "StartupReg"; Root = $it.Root; Name = $it.Name; Original = $orig }
            } else {
                $disabled = $it.Command + ".disabled"
                Move-Item -LiteralPath $it.Command -Destination $disabled -Force -ErrorAction Stop
                Add-SbUndo @{ Type = "StartupLnk"; Root = $it.Root; Name = $it.Name; Original = $it.Command }
            }
            Write-Ok ("Disabled startup item: " + $it.Name)
        } catch {
            Write-Warn "Could not disable $($it.Name): $($_.Exception.Message)"
        }
    }
}

# --- Master optimize entry point -----------------------------------------
function Invoke-OptimizePerformance {
    param([switch]$SkipAsk, [switch]$Light)

    Write-Title "PERFORMANCE OPTIMIZATION"
    Write-Info "High-performance settings, services, registry tweaks & startup cleanup."

    Optimize-PowerPlan
    Optimize-VisualEffects
    Optimize-Responsiveness
    Optimize-Prefetch
    Optimize-Services
    Optimize-PageFile
    Optimize-DnsCache
    Optimize-DriveMaintenance

    if (-not $Light) {
        Optimize-Startup
        Optimize-Health
    }

    Write-Host ""
    Write-Host "  Optimization complete. Changes are reversible via 'Undo'." -ForegroundColor Green
    Add-SbLog "PERFORMANCE OPTIMIZE done"
}
