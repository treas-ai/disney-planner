param(
    [switch]$SkipPubGet
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Test-Path (Join-Path $root "pubspec.yaml"))) {
    throw "pubspec.yaml が見つかりません。Disney Planner のプロジェクト直下に置いて実行してください。"
}

Write-Host "Disney Planner safe cleanup" -ForegroundColor Cyan

$targets = @(
    "build",
    ".dart_tool",
    ".flutter-plugins",
    ".flutter-plugins-dependencies",
    "windows\flutter\ephemeral",
    "linux\flutter\ephemeral",
    "macos\Flutter\ephemeral",
    "ios\Flutter\ephemeral",
    "android\.gradle"
)

foreach ($relative in $targets) {
    $path = Join-Path $root $relative
    if (Test-Path $path) {
        Write-Host "Remove: $relative"
        Remove-Item -LiteralPath $path -Recurse -Force
    }
}

Get-ChildItem -Path $root -Filter "*.iml" -File -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "Remove IDE file: $($_.Name)"
    Remove-Item -LiteralPath $_.FullName -Force
}

$androidIml = Join-Path $root "android\disney_planner_android.iml"
if (Test-Path $androidIml) {
    Write-Host "Remove IDE file: android\disney_planner_android.iml"
    Remove-Item -LiteralPath $androidIml -Force
}

Write-Host ""
Write-Host "生成物の削除が完了しました。" -ForegroundColor Green

if (-not $SkipPubGet) {
    Write-Host "flutter pub get を実行します..."
    Push-Location $root
    try {
        flutter pub get
    }
    finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "次に .\verify.ps1 を実行してください。" -ForegroundColor Yellow
