param(
    [string]$Output = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path (Join-Path $root "pubspec.yaml"))) {
    throw "pubspec.yaml が見つかりません。Disney Planner のプロジェクト直下に置いて実行してください。"
}

if ([string]::IsNullOrWhiteSpace($Output)) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $Output = Join-Path (Split-Path $root -Parent) "disney_planner_source_$stamp.zip"
}

$excludeDirs = @(
    ".git",
    ".dart_tool",
    "build",
    ".idea",
    ".vscode",
    "android\.gradle",
    "windows\flutter\ephemeral",
    "linux\flutter\ephemeral",
    "macos\Flutter\ephemeral",
    "ios\Flutter\ephemeral"
)

$excludeFiles = @(
    ".flutter-plugins",
    ".flutter-plugins-dependencies",
    "disney_planner.iml",
    "android\disney_planner_android.iml"
)

$temp = Join-Path $env:TEMP ("disney_planner_export_" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $temp | Out-Null

try {
    Get-ChildItem -LiteralPath $root -Force | ForEach-Object {
        $name = $_.Name
        $relative = $name

        if ($excludeDirs -contains $relative -or $excludeFiles -contains $relative) {
            return
        }

        if ($_.PSIsContainer) {
            Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $temp $name) -Recurse -Force
        } else {
            Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $temp $name) -Force
        }
    }

    foreach ($relative in $excludeDirs) {
        $p = Join-Path $temp $relative
        if (Test-Path $p) { Remove-Item -LiteralPath $p -Recurse -Force }
    }
    foreach ($relative in $excludeFiles) {
        $p = Join-Path $temp $relative
        if (Test-Path $p) { Remove-Item -LiteralPath $p -Force }
    }

    if (Test-Path $Output) { Remove-Item -LiteralPath $Output -Force }
    Compress-Archive -Path (Join-Path $temp "*") -DestinationPath $Output -CompressionLevel Optimal

    Write-Host "Source ZIP created:" -ForegroundColor Green
    Write-Host $Output
}
finally {
    if (Test-Path $temp) {
        Remove-Item -LiteralPath $temp -Recurse -Force
    }
}
