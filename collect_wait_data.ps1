param(
    [ValidateSet('all','tokyo_disneyland','tokyo_disneysea')]
    [string]$Park = 'all',
    [int]$IntervalMinutes = 5,
    [int]$Count = 1,
    [switch]$Continuous,
    [switch]$NoRebuild
)

$ErrorActionPreference = 'Stop'
$argsList = @('run', 'tool/collect_themeparks_wiki_waits.dart', '--park', $Park, '--interval-minutes', $IntervalMinutes.ToString())
if ($Continuous) {
    $argsList += '--continuous'
} else {
    $argsList += @('--count', $Count.ToString())
}
if ($NoRebuild) { $argsList += '--no-rebuild' }

Write-Host 'Disney Planner wait-time collector'
Write-Host 'Source: ThemeParks.wiki (minimum 5-minute interval)'
& dart @argsList
if ($LASTEXITCODE -ne 0) { throw 'wait data collection failed.' }
