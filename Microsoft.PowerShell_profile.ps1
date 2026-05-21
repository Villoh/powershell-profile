### Pretty PowerShell compatibility loader

$candidatePaths = @(
    if ($PSScriptRoot) { Join-Path $PSScriptRoot 'Profile.ps1' }
    if ($PSScriptRoot) { Join-Path $PSScriptRoot 'PrettyPowerShell.ps1' }
    if ($PROFILE) { Join-Path (Split-Path -Parent $PROFILE) 'Functions/PrettyPowerShell.ps1' }
    if ($PROFILE) { Join-Path (Split-Path -Parent $PROFILE) 'PrettyPowerShell.ps1' }
) | Where-Object { $_ } | Select-Object -Unique

$prettyPowerShell = $candidatePaths |
    Where-Object { $_ -ne $PSCommandPath -and (Test-Path $_) } |
    Select-Object -First 1

if ($prettyPowerShell) {
    . $prettyPowerShell
    return
}

Write-Warning 'Pretty PowerShell standalone script not found. Run Setup.ps1 or dot-source Profile.ps1 manually.'
