param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path (Join-Path $root "pubspec.yaml"))) {
    throw "pubspec.yaml が見つかりません。Disney Planner のプロジェクト直下で実行してください。"
}

Write-Host "Disney Planner Stage 2 safe cleanup" -ForegroundColor Cyan

$targets = @(
    "assets\master.zip",
    "tool\master_data\output\migration_report.json",
    "tool\master_data\output\migration_report.txt",
    "tool\master_data\output\backups"
)

foreach ($relative in $targets) {
    $path = Join-Path $root $relative
    if (Test-Path $path) {
        Write-Host "Remove: $relative"
        Remove-Item -LiteralPath $path -Recurse -Force
    }
}

$outputDir = Join-Path $root "tool\master_data\output"
if (Test-Path $outputDir) {
    $remaining = Get-ChildItem -LiteralPath $outputDir -Force -ErrorAction SilentlyContinue
    if (-not $remaining) {
        Remove-Item -LiteralPath $outputDir -Force
        Write-Host "Remove empty directory: tool\master_data\output"
    }
}

Write-Host ""
Write-Host "Stage 2 cleanup completed." -ForegroundColor Green
Write-Host "lib / assets/master の展開済みJSON / test / docs / tool本体は変更していません。"
Write-Host "次に .\verify.ps1 を実行してください。" -ForegroundColor Yellow
