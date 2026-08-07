param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path (Join-Path $root "pubspec.yaml"))) {
    throw "pubspec.yaml が見つかりません。Disney Planner のプロジェクト直下で実行してください。"
}

Write-Host "Disney Planner Stage 3 root cleanup (fixed)" -ForegroundColor Cyan

$dirs = @(
    "docs\current",
    "docs\development",
    "docs\audits",
    "docs\archive"
)
foreach ($d in $dirs) {
    New-Item -ItemType Directory -Force -Path (Join-Path $root $d) | Out-Null
}

$moves = @{
    "ARCHITECTURE.md"                       = "docs\development\ARCHITECTURE.md"
    "CONTRIBUTING.md"                       = "docs\development\CONTRIBUTING.md"
    "DEVELOPMENT_WORKFLOW.md"               = "docs\development\DEVELOPMENT_WORKFLOW.md"
    "GITHUB_PAGES_DEPLOYMENT.md"            = "docs\development\GITHUB_PAGES_DEPLOYMENT.md"
    "GIT_MAINTENANCE.md"                    = "docs\development\GIT_MAINTENANCE.md"

    "PROJECT_STATUS.md"                     = "docs\current\PROJECT_STATUS.md"
    "ROADMAP.md"                            = "docs\current\ROADMAP.md"
    "CURRENT_WISH_DATA_2026_08.md"          = "docs\current\CURRENT_WISH_DATA_2026_08.md"
    "SUMMER_2026_MENU_REVIEW_CHECKLIST.md"  = "docs\current\SUMMER_2026_MENU_REVIEW_CHECKLIST.md"
    "WISH_LIST_COMPLETION_SCOPE.md"         = "docs\current\WISH_LIST_COMPLETION_SCOPE.md"

    "MASTER_DATA_AUDIT_BASELINE.md"         = "docs\audits\MASTER_DATA_AUDIT_BASELINE.md"
    "MASTER_DATA_AUDIT_REPORT.md"           = "docs\audits\MASTER_DATA_AUDIT_REPORT.md"
    "WISH_DATA_AUDIT_REPORT.md"             = "docs\audits\WISH_DATA_AUDIT_REPORT.md"

    "DESIGN_V5_1_1.md"                     = "docs\archive\DESIGN_V5_1_1.md"
    "IMPLEMENTATION_V5_1_1.md"             = "docs\archive\IMPLEMENTATION_V5_1_1.md"
    "OPTIMIZATION_REPORT.md"                = "docs\archive\OPTIMIZATION_REPORT.md"
    "STAGE2_REPORT.md"                      = "docs\archive\STAGE2_REPORT.md"
}

foreach ($source in $moves.Keys) {
    $src = Join-Path $root $source
    $dst = Join-Path $root $moves[$source]
    if (Test-Path $src) {
        Write-Host "Move: $source -> $($moves[$source])"
        Move-Item -LiteralPath $src -Destination $dst -Force
    }
}

$rootReplacements = @{
    "CONTRIBUTING.md"              = "docs/development/CONTRIBUTING.md"
    "GIT_MAINTENANCE.md"           = "docs/development/GIT_MAINTENANCE.md"
    "PROJECT_STATUS.md"            = "docs/current/PROJECT_STATUS.md"
    "ROADMAP.md"                   = "docs/current/ROADMAP.md"
    "MASTER_DATA_AUDIT_REPORT.md"  = "docs/audits/MASTER_DATA_AUDIT_REPORT.md"
    "WISH_DATA_AUDIT_REPORT.md"    = "docs/audits/WISH_DATA_AUDIT_REPORT.md"
}

$rootTextFiles = @(
    "README.md",
    "CHANGELOG.md",
    "setup_git_maintenance.ps1"
)

foreach ($relative in $rootTextFiles) {
    $path = Join-Path $root $relative
    if (-not (Test-Path $path)) { continue }

    $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    foreach ($old in $rootReplacements.Keys) {
        $text = $text.Replace($old, $rootReplacements[$old])
    }
    Set-Content -LiteralPath $path -Value $text -Encoding UTF8
}

$masterAudit = Join-Path $root "tool\audit_master_data.dart"
if (Test-Path $masterAudit) {
    $text = Get-Content -LiteralPath $masterAudit -Raw -Encoding UTF8
    $text = $text.Replace("File('MASTER_DATA_AUDIT_REPORT.md')", "File('docs/audits/MASTER_DATA_AUDIT_REPORT.md')")
    Set-Content -LiteralPath $masterAudit -Value $text -Encoding UTF8
}

$wishAudit = Join-Path $root "tool\audit_wish_data.dart"
if (Test-Path $wishAudit) {
    $text = Get-Content -LiteralPath $wishAudit -Raw -Encoding UTF8
    $text = $text.Replace("'${root.path}/WISH_DATA_AUDIT_REPORT.md'", "'${root.path}/docs/audits/WISH_DATA_AUDIT_REPORT.md'")
    $text = $text.Replace("Report: WISH_DATA_AUDIT_REPORT.md", "Report: docs/audits/WISH_DATA_AUDIT_REPORT.md")
    Set-Content -LiteralPath $wishAudit -Value $text -Encoding UTF8
}

$status = Join-Path $root "docs\current\PROJECT_STATUS.md"
if (Test-Path $status) {
    $text = Get-Content -LiteralPath $status -Raw -Encoding UTF8

    # Single-quoted PowerShell strings avoid interpreting Markdown backticks.
    $text = $text.Replace('`DESIGN_V5_1_1.md`', '`../archive/DESIGN_V5_1_1.md`')
    $text = $text.Replace('`IMPLEMENTATION_V5_1_1.md`', '`../archive/IMPLEMENTATION_V5_1_1.md`')

    Set-Content -LiteralPath $status -Value $text -Encoding UTF8
}

Write-Host ""
Write-Host "Stage 3 root cleanup completed." -ForegroundColor Green
Write-Host "Flutter source/assets/test were not moved."
Write-Host "次に .\verify.ps1 を実行してください。" -ForegroundColor Yellow
