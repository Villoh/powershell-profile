@{
    ExcludeRules = @(
        # Write-Host is used intentionally for interactive installer UI and profile output
        'PSAvoidUsingWriteHost'
    )
}
