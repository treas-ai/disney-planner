$ErrorActionPreference = "Stop"

Write-Host "== Disney Planner verify =="

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "flutter command not found."
}

Write-Host "[1/4] flutter analyze"
flutter analyze --no-pub
if ($LASTEXITCODE -ne 0) { throw "flutter analyze failed." }

Write-Host "[2/4] flutter test"
flutter test --no-pub
if ($LASTEXITCODE -ne 0) { throw "flutter test failed." }

Write-Host "[3/4] remove project-root ZIP files"
$zipFiles = @(Get-ChildItem -Path "." -Filter "*.zip" -File -ErrorAction SilentlyContinue)
if ($zipFiles.Count -gt 0) {
    $zipFiles | Remove-Item -Force
    Write-Host ("Removed {0} ZIP file(s)." -f $zipFiles.Count)
} else {
    Write-Host "No project-root ZIP files to remove."
}

Write-Host "[4/4] launch Windows app"
flutter run -d windows
if ($LASTEXITCODE -ne 0) { throw "flutter run failed." }
