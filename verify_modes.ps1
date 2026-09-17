$ErrorActionPreference = "Stop"
Write-Host "== Disney Planner optimization mode probe =="
flutter test tool/mode_differentiation_probe_test.dart -r expanded
if ($LASTEXITCODE -ne 0) { throw "optimization mode probe failed." }
Write-Host "Mode probe completed. Copy the MODE_PROBE lines for comparison."
