# ============================================================
#  SystemBoost - build-standalone.ps1
#  Optional: wrap the SystemBoost folder into ONE deliverable file.
#
#  Two options:
#    Option 1 (default): a ZIP that auto-extracts + runs.
#    Option 2: a single self-extracting .exe using Windows' iexpress.
#
#  Run ON WINDOWS (PowerShell 5.1). Requires Administrator? No, but
#  run it from the folder that contains this script.
# ============================================================

$script:Dir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "SystemBoost - standalone package builder" -ForegroundColor Cyan
Write-Host "Source folder: $script:Dir" -ForegroundColor Gray

# -- 1) Bundle the files into a cabinet/zip --------------------------------
$zipPath = Join-Path $script:Dir "SystemBoost-portable.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

Write-Host "Creating $zipPath ..." -ForegroundColor Gray
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')
# Add each file/folder except the .git dir and the zip itself
Get-ChildItem -LiteralPath $script:Dir -Force -Recurse |
    Where-Object { $_.FullName -notmatch "\\.git\\" -and $_.Name -ne "SystemBoost-portable.zip" } |
    ForEach-Object {
        $rel = $_.FullName.Substring($script:Dir.Length).TrimStart('\')
        if ($_.PSIsContainer) { return }
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, "SystemBoost/" + $rel) | Out-Null
    }
$zip.Dispose()
Write-Host "ZIP created: $zipPath" -ForegroundColor Green

# -- 2) Optionally build a self-extracting .exe via IExpress --------------
Write-Host ""
$ans = Read-Host "Also build a single .exe (requires IExpress on Windows)? (y/n)"
if ($ans -match "^[yY]") {
    # Prepare the source for iexpress: a folder containing the zip + launcher
    $expDir = Join-Path $env:TEMP "SystemBoost-iexpress"
    New-Item -ItemType Directory -Path $expDir -Force | Out-Null
    Copy-Item $zipPath (Join-Path $expDir "SystemBoost-portable.zip") -Force

    # iexpress SED (self-extraction directive) file
    $sed = @(
        "[Version]",
        "Class=IEXPRESS",
        "SEDVersion=3",
        "[Options]",
        "PackagePurpose=InstallApp",
        "ShowInstallProgramWindow=1",
        "HideExtractAnimation=0",
        "UseLongFileName=1",
        "InsideCompressed=0",
        "CAB_FixedSize=0",
        "CAB_ResvCodeSigning=0",
        "RebootMode=N",
        "InstallPrompt=",
        "DisplayLicense=",
        "FinishMessage=SystemBoost extracted. Open the SystemBoost folder and run SystemBoost.bat.",
        "TargetName=$env:TEMP\SystemBoost-Setup.exe",
        "FriendlyName=SystemBoost",
        "AppLaunched=extract-and-run.cmd",
        "PostInstallCmd=",
        "AdminQuietInstCmd=",
        "UserQuietInstCmd=",
        "SourceFiles=SourceFiles",
        "[Strings]",
        "FILE0=SystemBoost-portable.zip",
        "FILE1=extract-and-run.cmd",
        "[SourceFiles]",
        "SourceFiles0=$expDir",
        "[SourceFiles0]",
        "%FILE0%=",
        "%FILE1%="
    )

    # extract-and-run.cmd: unzip to a folder then launch
    $cmd = @(
        "@echo off",
        "cd /d \"%~dp0\"",
        "if not exist SystemBoost mkdir SystemBoost",
        "powershell -NoProfile -ExecutionPolicy Bypass -Command \"Expand-Archive -Force -Path 'SystemBoost-portable.zip' -DestinationPath 'SystemBoost'\"",
        "echo.",
        "echo   SystemBoost ready. Open the SystemBoost folder and run SystemBoost.bat",
        "echo.",
        "pause"
    )
    Set-Content -LiteralPath (Join-Path $expDir "extract-and-run.cmd") -Value $cmd -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $expDir "package.sed") -Value $sed -Encoding ASCII

    Write-Host "Building .exe with IExpress ..." -ForegroundColor Gray
    # iexpress silent mode using the SED file
    Start-Process -FilePath "$env:windir\System32\iexpress.exe" -ArgumentList "/N `"$expDir\package.sed`"" -Wait -ErrorAction SilentlyContinue

    $exe = Join-Path $env:TEMP "SystemBoost-Setup.exe"
    if (Test-Path $exe) {
        $dest = Join-Path $script:Dir "SystemBoost-Setup.exe"
        Copy-Item $exe $dest -Force
        Write-Host "EXE created: $dest" -ForegroundColor Green
    } else {
        Write-Host "IExpress could not produce the exe (it may be disabled)." -ForegroundColor Yellow
        Write-Host "You still have the ZIP: $zipPath" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Done. Deliverables:" -ForegroundColor Cyan
Write-Host "  - $zipPath" -ForegroundColor Gray
if (Test-Path (Join-Path $script:Dir "SystemBoost-Setup.exe")) {
    Write-Host "  - $(Join-Path $script:Dir 'SystemBoost-Setup.exe')" -ForegroundColor Gray
}
