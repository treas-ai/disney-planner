$ErrorActionPreference = 'Stop'

Write-Host 'Disney Planner: live-data branch setup'
Write-Host 'Fetching the latest main branch...'
git fetch origin main
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$existing = git ls-remote --heads origin live-data
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($existing) {
    Write-Host 'Remote branch live-data already exists. Nothing to create.'
    exit 0
}

Write-Host 'Creating remote branch live-data from the current origin/main...'
git push origin refs/remotes/origin/main:refs/heads/live-data
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'live-data branch was created successfully.'
