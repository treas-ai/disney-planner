function Test-PubGetRequired {
    if (-not (Test-Path ".dart_tool/package_config.json")) {
        return $true
    }

    if (-not (Test-Path ".git")) {
        return $false
    }

    git diff --quiet -- pubspec.yaml pubspec.lock
    $workingTreeChanged = $LASTEXITCODE -ne 0

    git diff --cached --quiet -- pubspec.yaml pubspec.lock
    $stagedChanged = $LASTEXITCODE -ne 0

    return ($workingTreeChanged -or $stagedChanged)
}

function Invoke-Flutter {
    param(
        [string[]]$Arguments,
        [string]$FailureMessage
    )

    & flutter @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw $FailureMessage
    }
}

function Initialize-FlutterDependencies {
    param(
        [switch]$ForcePub
    )

    $needsPubGet = $ForcePub -or (Test-PubGetRequired)

    if ($needsPubGet) {
        Write-Host "Running flutter pub get..." -ForegroundColor Cyan
        Invoke-Flutter `
            -Arguments @("pub", "get") `
            -FailureMessage "flutter pub get failed."

        return @()
    }

    Write-Host "Dependencies unchanged. Using --no-pub." -ForegroundColor Green
    return @("--no-pub")
}

param(
    [switch]$ForcePub,
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path "pubspec.yaml")) {
    throw "Run this script from the Flutter project root."
}

$pubOption = Initialize-FlutterDependencies -ForcePub:$ForcePub

Write-Host ""
Write-Host "Running flutter analyze..." -ForegroundColor Cyan
Invoke-Flutter `
    -Arguments (@("analyze") + $pubOption) `
    -FailureMessage "flutter analyze failed."

if (-not $SkipTests) {
    Write-Host ""
    Write-Host "Running flutter test..." -ForegroundColor Cyan
    Invoke-Flutter `
        -Arguments (@("test") + $pubOption) `
        -FailureMessage "flutter test failed."
}

Write-Host ""
Write-Host "Verification completed." -ForegroundColor Green
