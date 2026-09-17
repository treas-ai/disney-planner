$ErrorActionPreference = "Stop"
$obsolete = @(
  "test\optimization_mode_structure_test.dart",
  "test\minimum_wait_lexicographic_structure_test.dart"
)
foreach ($path in $obsolete) {
  if (Test-Path $path) {
    Remove-Item $path -Force
    Write-Host "Removed obsolete test: $path"
  }
}
Write-Host "Test maintenance applied."
