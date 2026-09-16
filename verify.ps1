param(
    [switch]$ForcePub,
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path "pubspec.yaml")) {
    throw "Run this script from the Flutter project root."
}

Write-Host "Running Disney Planner regression checks..." -ForegroundColor Cyan

if (Test-Path "lib/presentation") {
    throw "Unexpected lib/presentation directory exists. Use the current feature-based paths."
}

$settingsSource = Get-Content "lib/features/settings/settings_screen.dart" -Raw
$planReviewSource = Get-Content "lib/features/plan_review/plan_review_screen.dart" -Raw
$scheduleControllerSource = Get-Content "lib/features/plan_review/schedule_controller.dart" -Raw
$tripSettingsSource = Get-Content "lib/domain/entities/trip_settings.dart" -Raw
$scheduleEngineSource = Get-Content "lib/domain/services/schedule_engine.dart" -Raw

if ($settingsSource.Contains("_LiveDataSourceSettingsCard")) {
    throw "Removed live-data-source settings UI has returned."
}
if ($settingsSource.Contains("_OptimizationModeSettingsCard")) {
    throw "Optimization mode must be selected at plan generation, not in Travel Settings."
}
if (-not $planReviewSource.Contains("ScheduleOptimizationMode.minimumWait") -or
    -not $planReviewSource.Contains("copyWith(scheduleOptimizationMode: selectedMode)") -or
    -not $planReviewSource.Contains("if (hasExistingPlan)")) {
    throw "Baseline wait-first generation or post-generation optimization adjustment is not connected."
}
$enumMatch = [regex]::Match(
    $tripSettingsSource,
    'enum\s+ScheduleOptimizationMode\s*\{(?<body>[^}]*)\}',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $enumMatch.Success) {
    throw "ScheduleOptimizationMode enum declaration is missing."
}
$enumBody = $enumMatch.Groups["body"].Value
foreach ($mode in @("balanced", "minimumWait", "minimumWalking", "compactSchedule")) {
    if (-not [regex]::IsMatch($enumBody, "(?m)^\s*$mode\s*,")) {
        throw "TripSettings optimization mode is missing: $mode"
    }
}
if (-not $scheduleEngineSource.Contains("settings.scheduleOptimizationMode")) {
    throw "ScheduleEngine is not consuming scheduleOptimizationMode."
}
if ($scheduleControllerSource.Contains("Isolate.run(")) {
    throw "Schedule generation must not use Isolate.run closure capture."
}
if (-not $scheduleControllerSource.Contains("_scheduleGenerationIsolateEntry") -or
    -not $scheduleControllerSource.Contains("Isolate.spawn")) {
    throw "Dedicated schedule-generation isolate entry is missing."
}
if ($scheduleControllerSource.Contains("_scheduleEngine.generate(")) {
    throw "Coverage analysis must not run ScheduleEngine.generate on the UI isolate."
}
$offUiCalls = [regex]::Matches($scheduleControllerSource, '_generateScheduleOffUi\s*\(').Count
if ($offUiCalls -lt 3) {
    throw "Expected both main generation and coverage simulations to use the off-UI isolate path."
}

Write-Host "Disney Planner regression checks passed." -ForegroundColor Green
Write-Host ""

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


Write-Host ""
Write-Host "Starting Flutter Windows app..." -ForegroundColor Cyan
flutter run -d windows
if ($LASTEXITCODE -ne 0) { throw "flutter run -d windows failed." }
