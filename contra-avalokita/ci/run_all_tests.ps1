param(
    [string]$GodotBin = "C:\Users\jisub\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe"
)

$ProjectDir = (Get-Location).Path
$testFiles = Get-ChildItem -Path "$ProjectDir\tests" -Filter "*_test.gd" -Recurse

Write-Host "Found $($testFiles.Count) test files."

$results = @()
foreach ($file in $testFiles) {
    $relPath = "res://" + ($file.FullName.Substring($ProjectDir.Length + 1) -replace '\\', '/')
    $tscnPath = $file.FullName -replace '\.gd$', '.tscn'
    
    Write-Host "Running: $relPath ... " -NoNewline
    
    if (Test-Path $tscnPath) {
        $tscnRel = "res://" + ($tscnPath.Substring($ProjectDir.Length + 1) -replace '\\', '/')
        $p = Start-Process -FilePath $GodotBin -ArgumentList @("--headless", "--path", $ProjectDir, $tscnRel) -NoNewWindow -Wait -PassThru
    } else {
        $p = Start-Process -FilePath $GodotBin -ArgumentList @("--headless", "--path", $ProjectDir, "--script", $relPath) -NoNewWindow -Wait -PassThru
    }
    
    if ($p.ExitCode -eq 0) {
        Write-Host "PASS" -ForegroundColor Green
        $results += [PSCustomObject]@{ Path = $relPath; Status = "PASS"; Code = 0 }
    } else {
        Write-Host "FAIL ($($p.ExitCode))" -ForegroundColor Red
        $results += [PSCustomObject]@{ Path = $relPath; Status = "FAIL"; Code = $p.ExitCode }
    }
}

$failed = $results | Where-Object { $_.Status -eq "FAIL" }
Write-Host "`nSummary: $($results.Count) tests, $($failed.Count) failed."
if ($failed.Count -gt 0) {
    Write-Host "Failures:" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host " - $($_.Path) (Code: $($_.Code))" -ForegroundColor Red }
    exit 1
} else {
    Write-Host "ALL TESTS PASSED!" -ForegroundColor Green
    exit 0
}
