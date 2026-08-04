param(
    [switch]$ForcePub
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

    if ($LASTEXITCODE -ne 0) {
        throw "flutter pub get failed."
    }
} else {
    Write-Host "Dependencies unchanged. Skipping pub get." -ForegroundColor Green
}

Write-Host ""
Write-Host "Running flutter analyze --no-pub..." -ForegroundColor Cyan
flutter analyze --no-pub

if ($LASTEXITCODE -ne 0) {
    throw "flutter analyze failed."
}

Write-Host ""
Write-Host "Running flutter test --no-pub..." -ForegroundColor Cyan
flutter test --no-pub

if ($LASTEXITCODE -ne 0) {
    throw "flutter test failed."
}

Write-Host ""
Write-Host "Launching Windows app for release check..." -ForegroundColor Cyan
flutter run --no-pub -d windows

if ($LASTEXITCODE -ne 0) {
    throw "flutter run failed."
}

Write-Host ""
Write-Host "Release check completed." -ForegroundColor Green
