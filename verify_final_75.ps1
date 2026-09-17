$ErrorActionPreference = "Stop"

if (-not (Test-Path "pubspec.yaml")) {
    throw "Run this script from the Flutter project root."
}

Write-Host "== Disney Planner v7.5 final gate =="
Write-Host ""

Write-Host "[1/4] Full verification"
& .\verify.ps1
if ($LASTEXITCODE -ne 0) { throw "verify.ps1 failed." }

Write-Host ""
Write-Host "[2/4] Four-mode differentiation"
$modeOutput = & .\verify_modes.ps1 2>&1
$modeOutput | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) { throw "verify_modes.ps1 failed." }

$modeText = $modeOutput -join "`n"
$requiredModes = @("balanced", "minimumWait", "minimumWalking", "compactSchedule")
foreach ($mode in $requiredModes) {
    if ($modeText -notmatch "MODE_PROBE $mode ") {
        throw "Missing MODE_PROBE output for $mode."
    }
}
if ($modeText -notmatch "MODE_PROBE distinct_orders=4/4") {
    throw "Four-mode differentiation gate failed: distinct_orders is not 4/4."
}

function Get-Metric([string]$mode, [string]$metric) {
    $pattern = "MODE_PROBE $mode .*?$metric=(\d+)"
    $match = [regex]::Match($modeText, $pattern)
    if (-not $match.Success) { throw "Missing metric $metric for $mode." }
    return [int]$match.Groups[1].Value
}

$balancedWait = Get-Metric "balanced" "wait"
$minimumWait = Get-Metric "minimumWait" "wait"
$balancedMove = Get-Metric "balanced" "move"
$minimumWalkingMove = Get-Metric "minimumWalking" "move"
$balancedLargest = Get-Metric "balanced" "largest"
$compactLargest = Get-Metric "compactSchedule" "largest"
$balancedBlocks = Get-Metric "balanced" "blocks"
$compactBlocks = Get-Metric "compactSchedule" "blocks"

if ($minimumWait -gt $balancedWait) {
    throw "minimumWait mode regressed versus balanced."
}
if ($minimumWalkingMove -gt $balancedMove) {
    throw "minimumWalking mode regressed versus balanced."
}
if ($compactLargest -lt $balancedLargest) {
    throw "compactSchedule largest free block regressed versus balanced."
}
if ($compactBlocks -gt $balancedBlocks) {
    throw "compactSchedule free-block count regressed versus balanced."
}

Write-Host "Mode differentiation gate passed."

Write-Host ""
Write-Host "[3/4] Wait prediction audit"
$waitAudit = ".\tool\audit_wait_prediction_accuracy.py"
if (Test-Path $waitAudit) {
    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if ($null -eq $pythonCommand) {
        Write-Host "WAIT_AUDIT=NOT_RUN reason=python_not_found"
    } else {
        & python $waitAudit
        $waitExit = $LASTEXITCODE
        if ($waitExit -ne 0) {
            Write-Host "WAIT_AUDIT=INCOMPLETE exit=$waitExit"
            Write-Host "Do not treat G4 as measured until enough historical data exists."
        } else {
            Write-Host "WAIT_AUDIT=COMPLETED"
        }
    }
} else {
    Write-Host "WAIT_AUDIT=NOT_RUN reason=audit_script_not_found"
}

Write-Host ""
Write-Host "[4/4] Manual representative-plan gate"
Write-Host "Confirm the 10/5 TDL representative plan in the Windows app:"
Write-Host "  - hard wishes: 10/10"
Write-Host "  - optional additions: 1/2"
Write-Host "  - MMW 11:20 adopted"
Write-Host "  - D-Groovationz4 12:20 retained/rejected without dropping hard wishes"
Write-Host "  - no overlap or fixed-time contradiction"
Write-Host "  - delay stress +5/+10/+20 is visible and plausible"
Write-Host "  - minimumWait representative wait remains 280 min unless data changed"
Write-Host ""
Write-Host "FINAL75_AUTOMATED_GATE=PASS"
Write-Host "Do not create v7.5.22 tag until the manual representative-plan gate is confirmed."
