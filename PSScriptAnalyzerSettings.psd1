@{
    ExcludeRules = @(
        # Write-Host is used intentionally for interactive installer UI and profile output
        'PSAvoidUsingWriteHost',
        # Invoke-Expression is required for Starship and zoxide shell init
        'PSAvoidUsingInvokeExpression',
        # Ensure-* and Migrate-* are internal helpers, not exported cmdlets
        'PSUseApprovedVerbs',
        # Install-TerminalIcons, Install-Extras, Initialize-PrettyModules are internal helpers
        'PSUseSingularNouns',
        # Update-Profile modifies state intentionally without pipeline input
        'PSUseShouldProcessForStateChangingFunctions',
        # UTF-8 BOM requirement conflicts with fastfetch and cross-platform compat
        'PSUseBOMForUnicodeEncodedFile',
        # GitHubOutputPath is used inside Add-GitHubOutput nested function; analyzer false positive
        'PSReviewUnusedParameter'
    )
}
