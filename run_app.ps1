$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "verify.ps1"

if (-not (Test-Path $scriptPath)) {
    throw "verify.ps1 was not found."
}

& $scriptPath -Run

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
