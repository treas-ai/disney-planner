$ErrorActionPreference = "Stop"

Write-Host "== Disney Planner update =="

$patch = Get-ChildItem -Path "." -Filter "disney_planner_*.zip" -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if ($null -eq $patch) {
    throw "No disney_planner_*.zip patch found in the project root."
}

Write-Host ("[1/2] apply patch: {0}" -f $patch.Name)
Expand-Archive -Path $patch.FullName -DestinationPath "." -Force

Write-Host "[2/2] verify"
& ".\verify.ps1"
if ($LASTEXITCODE -ne 0) { throw "verify.ps1 failed." }
