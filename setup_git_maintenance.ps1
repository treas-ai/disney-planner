param(
    [switch]$SkipVerification
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path ".git")) {
    throw "Run this script from the Git repository root."
}

Write-Host "Removing Flutter generated files from Git tracking..." -ForegroundColor Cyan

$trackedPaths = @(
    ".dart_tool",
    ".flutter-plugins",
    ".flutter-plugins-dependencies",
    "build"
)

foreach ($path in $trackedPaths) {
    git ls-files --error-unmatch -- "$path" *> $null

    if ($LASTEXITCODE -eq 0) {
        git rm -r --cached --ignore-unmatch -- "$path"
    }
}

$filesToStage = @(
    ".gitignore",
    "README.md",
    "docs/development/CONTRIBUTING.md",
    "CHANGELOG.md",
    "docs/current/PROJECT_STATUS.md",
    "docs/current/ROADMAP.md",
    "pubspec.yaml",
    "docs/development/GIT_MAINTENANCE.md",
    "setup_git_maintenance.ps1"
)

foreach ($file in $filesToStage) {
    if (Test-Path $file) {
        git add -- "$file"
    }
}

Write-Host ""
Write-Host "Current Git status:" -ForegroundColor Cyan
git status

if (-not $SkipVerification) {
    Write-Host ""
    Write-Host "Running quality checks..." -ForegroundColor Cyan

    flutter analyze --no-pub
    if ($LASTEXITCODE -ne 0) {
        throw "flutter analyze failed."
    }

    flutter test --no-pub
    if ($LASTEXITCODE -ne 0) {
        throw "flutter test failed."
    }
}

Write-Host ""
Write-Host "Git maintenance preparation completed." -ForegroundColor Green
Write-Host "Review git status, then run:"
Write-Host 'git commit -m "Release v3.3.2 Git Maintenance"'
Write-Host "git push"
Write-Host "git tag v3.3.2"
Write-Host "git push origin v3.3.2"

