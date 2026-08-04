function Test-PubGetRequired {
    param([switch]$ForcePub)
    if ($ForcePub) { return $true }
    if (-not (Test-Path ".dart_tool/package_config.json")) { return $true }
    if (Test-Path ".git") {
        git diff --quiet -- pubspec.yaml pubspec.lock
        $w = $LASTEXITCODE -ne 0
        git diff --cached --quiet -- pubspec.yaml pubspec.lock
        $s = $LASTEXITCODE -ne 0
        if ($w -or $s) { return $true }
    }
    return $false
}
function Invoke-CheckedFlutter {
    param([string[]]$Args,[string]$Err)
    & flutter @Args
    if ($LASTEXITCODE -ne 0){ throw $Err }
}
