param(
    [switch]$ForcePub,
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path "pubspec.yaml")) {
    throw "Run this script from the Flutter project root."
}

$needsPubGet = $ForcePub -or (-not (Test-Path ".dart_tool/package_config.json"))

if ((-not $needsPubGet) -and (Test-Path ".git")) {
    git diff --quiet --ignore-space-at-eol -- pubspec.yaml pubspec.lock
    $workingTreeChanged = $LASTEXITCODE -ne 0

    git diff --cached --quiet --ignore-space-at-eol -- pubspec.yaml pubspec.lock
    $stagedChanged = $LASTEXITCODE -ne 0

    $needsPubGet = $workingTreeChanged -or $stagedChanged
}

if ($needsPubGet) {
    Write-Host "Running flutter pub get..." -ForegroundColor Cyan
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed." }
} else {
    Write-Host "Dependencies unchanged. Skipping pub get." -ForegroundColor Green
}

Write-Host ""
Write-Host "Running flutter analyze --no-pub..." -ForegroundColor Cyan
flutter analyze --no-pub
if ($LASTEXITCODE -ne 0) { throw "flutter analyze failed." }

if (-not $SkipTests) {
    Write-Host ""
    Write-Host "Running flutter test --no-pub..." -ForegroundColor Cyan
    flutter test --no-pub
    if ($LASTEXITCODE -ne 0) { throw "flutter test failed." }
}

Write-Host ""
Write-Host "Verification completed." -ForegroundColor Green

# Delete every ZIP file located directly in the project root.
# ZIP files inside subfolders are intentionally left untouched.
$zipFiles = @(Get-ChildItem -Path . -Filter "*.zip" -File)

if ($zipFiles.Count -eq 0) {
    Write-Host "No ZIP files to clean up." -ForegroundColor Green
} else {
    foreach ($zipFile in $zipFiles) {
        Remove-Item -LiteralPath $zipFile.FullName -Force
        Write-Host "Deleted ZIP: $($zipFile.Name)" -ForegroundColor Yellow
    }
    Write-Host "ZIP cleanup completed: $($zipFiles.Count) file(s)." -ForegroundColor Green
}
