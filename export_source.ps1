$ErrorActionPreference = "Stop"

Write-Host "== Disney Planner source export =="

$projectRoot = (Get-Location).Path
$parent = Split-Path $projectRoot -Parent
$projectName = Split-Path $projectRoot -Leaf
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$temp = Join-Path $parent ("{0}_source_export_tmp" -f $projectName)
$zip = Join-Path $parent ("{0}_working_{1}.zip" -f $projectName, $timestamp)

Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "[1/3] copy source tree"
& robocopy $projectRoot $temp /E /XD ".git" ".dart_tool" "build" "ephemeral" /XF "*.zip"
if ($LASTEXITCODE -ge 8) {
    throw "robocopy failed with exit code $LASTEXITCODE"
}

Write-Host "[2/3] create ZIP"
Compress-Archive -Path (Join-Path $temp "*") -DestinationPath $zip -Force

Write-Host "[3/3] clean temporary copy"
Remove-Item $temp -Recurse -Force

Write-Host ("Created: {0}" -f $zip)
