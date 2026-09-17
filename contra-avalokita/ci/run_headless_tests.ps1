# PowerShell equivalent of ci/run_headless_tests.sh
param(
    [string]$GodotBin = "C:\Users\jisub\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe",
    [string]$Manifest = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = (Resolve-Path "$ScriptDir\..").Path
if (-not $Manifest) {
    $Manifest = "$ScriptDir\headless_tests.txt"
}

if (-not (Test-Path $GodotBin)) {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) {
        $GodotBin = $cmd.Source
    } else {
        Write-Error "Godot binary not found: $GodotBin"
        exit 1
    }
}

Write-Host "Godot runtime: $(& $GodotBin --version)"
Write-Host "Project: $ProjectDir"
Write-Host "Manifest: $Manifest"

$lines = Get-Content $Manifest
$ran = 0
$failed = 0
$failedTests = @()

foreach ($line in $lines) {
    $testPath = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($testPath) -or $testPath.StartsWith("#")) {
        continue
    }

    $ran++
    Write-Host "`n========================================================"
    Write-Host "[$ran] Running test: $testPath"
    Write-Host "========================================================"

    $process = Start-Process -FilePath $GodotBin -ArgumentList @("--headless", "--path", $ProjectDir, "--script", $testPath) -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Host "[-] FAILED ($($process.ExitCode)): $testPath" -ForegroundColor Red
        $failed++
        $failedTests += $testPath
    } else {
        Write-Host "[+] PASSED: $testPath" -ForegroundColor Green
    }
}

Write-Host "`n========================================================"
Write-Host "Results: $ran tests executed, $failed failed."
if ($failed -gt 0) {
    Write-Host "Failed tests:" -ForegroundColor Red
    foreach ($f in $failedTests) {
        Write-Host "  - $f" -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host "All tests passed successfully!" -ForegroundColor Green
    exit 0
}
