[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Force
)

$repoBase = 'https://raw.githubusercontent.com/Villoh/powershell-profile/main'
$localRepoRoot = if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'Profile.ps1'))) { $PSScriptRoot } else { $null }
$powerShellRoot = Split-Path -Parent $PROFILE
$userHome = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$osName = if ($PSVersionTable.Platform -eq 'Win32NT' -or $env:OS -eq 'Windows_NT') { 'Windows' } elseif ($IsMacOS) { 'macOS' } elseif ($IsLinux) { 'Linux' } else { 'Unknown' }
$shellName = if ($PSVersionTable.PSEdition -eq 'Core') { 'PowerShell' } else { 'Windows PowerShell' }
$starshipConfigDir = Join-Path $userHome '.config'
$starshipConfigPath = Join-Path $starshipConfigDir 'starship.toml'
$fastfetchConfigDir = Join-Path $userHome '.config/fastfetch'
$fastfetchConfigPath = Join-Path $fastfetchConfigDir 'config.jsonc'
$wtSettingsPath = Join-Path $userHome 'AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
$customProfilePath = Join-Path $powerShellRoot 'profile.ps1'
$backupRootDir = Join-Path $powerShellRoot 'Backups'
$script:BackupTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$script:BackupDirLogged = $false
$script:UseAsciiUi = $PSVersionTable.PSEdition -ne 'Core'
$script:InstallLog = [ordered]@{
    Detect       = [System.Collections.Generic.List[string]]::new()
    Install      = [System.Collections.Generic.List[string]]::new()
    Backups      = [System.Collections.Generic.List[string]]::new()
    Migration    = [System.Collections.Generic.List[string]]::new()
    Dependencies = [System.Collections.Generic.List[string]]::new()
    Result       = [System.Collections.Generic.List[string]]::new()
}

function Add-Log {
    param(
        [ValidateSet('Detect', 'Install', 'Backups', 'Migration', 'Dependencies', 'Result')]
        [string]$Section,
        [string]$Message
    )

    $script:InstallLog[$Section].Add($Message)
}

function Get-UiRule {
    if ($script:UseAsciiUi) { return '----------------------------------------------------' }
    return '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
}

function Get-UiPointer {
    if ($script:UseAsciiUi) { return '>' }
    return '▶'
}

function Write-InstallSummary {
    if ($DryRun) {
        Write-Host '[DryRun] Pretty PowerShell preview' -ForegroundColor Cyan
    } else {
        Write-Host 'Pretty PowerShell installed.' -ForegroundColor Green
    }

    foreach ($section in $script:InstallLog.Keys) {
        $entries = $script:InstallLog[$section]
        if ($entries.Count -eq 0) { continue }
        Write-Host ''
        Write-Host "${section}:" -ForegroundColor Cyan
        foreach ($entry in $entries) {
            Write-Host "  - $entry" -ForegroundColor Gray
        }
    }

    Write-Host ''
    if ($DryRun) {
        Write-Host '[DryRun] No files were changed.' -ForegroundColor Cyan
    }
}

function Invoke-InteractiveMenu {
    param(
        [string]$Question,
        [string[]]$Options,
        [int]$Default = 0
    )

    $selected = $Default
    $optionCount = $Options.Count

    function Render {
        param([int]$Sel)
        $top = [Console]::CursorTop - $optionCount
        for ($i = 0; $i -lt $optionCount; $i++) {
            [Console]::SetCursorPosition(0, $top + $i)
            $marker = if ($i -eq $Sel) { (Get-UiPointer) } else { ' ' }
            $color  = if ($i -eq $Sel) { 'Cyan' } else { 'Gray' }
            $line = "  $marker $($Options[$i])"
            Write-Host ($line.PadRight([Console]::WindowWidth - 1)) -ForegroundColor $color -NoNewline
        }
        # Park cursor off-screen to prevent blink in menu area
        [Console]::SetCursorPosition(0, $top + $optionCount)
    }

    Write-Host "$Question" -ForegroundColor White
    for ($i = 0; $i -lt $optionCount; $i++) {
        $marker = if ($i -eq $selected) { (Get-UiPointer) } else { ' ' }
        $color  = if ($i -eq $selected) { 'Cyan' } else { 'Gray' }
        Write-Host "  $marker $($Options[$i])" -ForegroundColor $color
    }

    [Console]::CursorVisible = $false
    try {
        while ($true) {
            $key = [Console]::ReadKey($true)
            switch ($key.Key) {
                'UpArrow'   { if ($selected -gt 0) { $selected--; Render $selected } }
                'DownArrow' { if ($selected -lt $optionCount - 1) { $selected++; Render $selected } }
                'Enter'     { Write-Host ''; return $selected }
            }
        }
    } finally {
        [Console]::CursorVisible = $true
    }
}

function Invoke-InteractiveMultiSelect {
    param(
        [string]$Question,
        [string[]]$Options,
        [int[]]$Defaults = @()
    )

    $optionCount = $Options.Count
    $selected = @()
    foreach ($d in $Defaults) { $selected += $d }
    $cursor = 0

    function Render {
        $top = [Console]::CursorTop - $optionCount
        for ($i = 0; $i -lt $optionCount; $i++) {
            [Console]::SetCursorPosition(0, $top + $i)
            $checked = if ($selected -contains $i) { if ($script:UseAsciiUi) { '[x]' } else { '[x]' } } else { '[ ]' }
            $marker  = if ($i -eq $cursor) { (Get-UiPointer) } else { ' ' }
            $color   = if ($i -eq $cursor) { 'Cyan' } else { 'Gray' }
            $line = "  $marker $checked $($Options[$i])"
            Write-Host ($line.PadRight([Console]::WindowWidth - 1)) -ForegroundColor $color -NoNewline
        }
        [Console]::SetCursorPosition(0, $top + $optionCount)
    }

    Write-Host $Question -ForegroundColor White
    Write-Host '  (Space to toggle, Enter to confirm)' -ForegroundColor DarkGray
    for ($i = 0; $i -lt $optionCount; $i++) {
        $checked = if ($selected -contains $i) { '[x]' } else { '[ ]' }
        $marker  = if ($i -eq $cursor) { (Get-UiPointer) } else { ' ' }
        $color   = if ($i -eq $cursor) { 'Cyan' } else { 'Gray' }
        Write-Host "  $marker $checked $($Options[$i])" -ForegroundColor $color
    }

    [Console]::CursorVisible = $false
    try {
        while ($true) {
            $key = [Console]::ReadKey($true)
            switch ($key.Key) {
                'UpArrow'   { if ($cursor -gt 0) { $cursor--; Render } }
                'DownArrow' { if ($cursor -lt $optionCount - 1) { $cursor++; Render } }
                'Spacebar'  {
                    if ($selected -contains $cursor) {
                        $selected = @($selected | Where-Object { $_ -ne $cursor })
                    } else {
                        $selected = @($selected) + $cursor
                    }
                    Render
                }
                'Enter'     { Write-Host ''; return $selected }
            }
        }
    } finally {
        [Console]::CursorVisible = $true
    }
}

function Invoke-InteractiveBool {
    param(
        [string]$Question,
        [bool]$Default = $false
    )

    $options = @('Yes', 'No')
    $defaultIdx = if ($Default) { 0 } else { 1 }
    $result = Invoke-InteractiveMenu -Question $Question -Options $options -Default $defaultIdx
    return $result -eq 0
}

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        if ($DryRun) {
            Add-Log -Section Install -Message "Would create directory: $Path"
            return
        }
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
        Add-Log -Section Install -Message "Created directory: $Path"
    }
}

function Ensure-BackupDir {
    param([string]$BackupDir)

    if (-not $script:BackupDirLogged) {
        if ($DryRun) {
            Add-Log -Section Backups -Message "Would create backup folder: $BackupDir"
        } else {
            New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
            Add-Log -Section Backups -Message "Created backup folder: $BackupDir"
        }
        $script:BackupDirLogged = $true
    }
}

function Backup-File {
    param([string]$Path, [string]$BackupDir)

    if (-not (Test-Path $Path)) { return $null }

    $fileName = Split-Path -Leaf $Path
    $backupPath = Join-Path $BackupDir $fileName
    Ensure-BackupDir -BackupDir $BackupDir

    if ($DryRun) {
        Add-Log -Section Backups -Message "Would back up $Path to $backupPath"
    } else {
        Copy-Item -Path $Path -Destination $backupPath -Force
        Add-Log -Section Backups -Message "Backed up $Path to $backupPath"
    }

    return $backupPath
}

function Backup-Directory {
    param([string]$Path, [string]$Name, [string]$BackupDir)

    if (-not (Test-Path $Path)) { return $null }

    $backupPath = Join-Path $BackupDir $Name
    Ensure-BackupDir -BackupDir $BackupDir

    if ($DryRun) {
        Add-Log -Section Backups -Message "Would back up folder $Path to $backupPath"
    } else {
        Copy-Item -Path $Path -Destination $backupPath -Recurse -Force
        Add-Log -Section Backups -Message "Backed up folder $Path to $backupPath"
    }

    return $backupPath
}

function Resolve-RepoAsset {
    param([string]$RelativePath)

    if ($localRepoRoot) {
        $localPath = Join-Path $localRepoRoot $RelativePath
        if (Test-Path $localPath) {
            return [pscustomobject]@{ Type = 'local'; Source = $localPath }
        }
    }

    return [pscustomobject]@{ Type = 'remote'; Source = "$repoBase/$RelativePath" }
}

function Read-Utf8File {
    param([string]$Path)

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false, $true)
    $reader = New-Object System.IO.StreamReader($Path, $utf8NoBom, $true)
    try {
        return $reader.ReadToEnd()
    } finally {
        $reader.Dispose()
    }
}

function Write-Utf8File {
    param(
        [string]$Path,
        [string]$Content,
        [switch]$NoBom
    )

    $encoding = if ($NoBom) { New-Object System.Text.UTF8Encoding($false) } else { New-Object System.Text.UTF8Encoding($true) }
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Install-RepoFile {
    param([string]$RelativePath, [string]$Destination, [switch]$NoBom)

    $asset = Resolve-RepoAsset -RelativePath $RelativePath

    if ($DryRun) {
        if ($asset.Type -eq 'local') {
            Add-Log -Section Install -Message "Would copy $($asset.Source) to $Destination"
        } else {
            Add-Log -Section Install -Message "Would download $($asset.Source) to $Destination"
        }
        return
    }

    if ($asset.Type -eq 'local') {
        $content = Read-Utf8File -Path $asset.Source
        Write-Utf8File -Path $Destination -Content $content -NoBom:$NoBom
        Add-Log -Section Install -Message "Copied $($asset.Source) to $Destination"
    } else {
        $content = (Invoke-WebRequest -Uri $asset.Source).Content
        Write-Utf8File -Path $Destination -Content $content -NoBom:$NoBom
        Add-Log -Section Install -Message "Downloaded $($asset.Source) to $Destination"
    }
}

function Get-LoaderBlock {
    param([string]$ScriptPath)

    @"
# Pretty PowerShell loader
if (Test-Path '$ScriptPath') {
    . '$ScriptPath'
}
"@
}

function Ensure-ProfileLoader {
    param([string]$ScriptPath)

    Ensure-Directory -Path $powerShellRoot
    if (-not (Test-Path $PROFILE)) {
        if ($DryRun) {
            Add-Log -Section Install -Message "Would create profile file: $PROFILE"
        } else {
            New-Item -Path $PROFILE -ItemType File -Force | Out-Null
            Add-Log -Section Install -Message "Created profile file: $PROFILE"
        }
    }

    $loaderBlock = (Get-LoaderBlock -ScriptPath $ScriptPath).TrimEnd()
    $loaderPattern = "(?ms)^# Pretty PowerShell loader\r?\nif \(Test-Path '[^']+'\) \{\r?\n    \. '[^']+'\r?\n\}\r?\n?"
    $rawContent = if (Test-Path $PROFILE) { Get-Content $PROFILE -Raw } else { $null }
    $current = if ($rawContent) { $rawContent } else { '' }
    $loaderMatches = [regex]::Matches($current, $loaderPattern)

    if ($loaderMatches.Count -gt 0) {
        $firstMatch = $loaderMatches[0]
        $prefix = $current.Substring(0, $firstMatch.Index)
        $suffix = $current.Substring($firstMatch.Index + $firstMatch.Length)
        $suffix = [regex]::Replace($suffix, $loaderPattern, '')
        $suffix = $suffix.TrimStart("`r", "`n")
        $normalized = if ($suffix) {
            $prefix + $loaderBlock + "`r`n`r`n" + $suffix
        } else {
            $prefix + $loaderBlock + "`r`n"
        }

        if ($current -eq $normalized) {
            Add-Log -Section Migration -Message "Loader already present in: $PROFILE"
            return $false
        }

        if ($DryRun) {
            Add-Log -Section Migration -Message "Would normalize Pretty PowerShell loader entries in $PROFILE"
            return $true
        }

        Write-Utf8File -Path $PROFILE -Content $normalized
        Add-Log -Section Migration -Message "Normalized Pretty PowerShell loader entries in $PROFILE"
        return $true
    }

    if ($DryRun) {
        Add-Log -Section Migration -Message "Would append Pretty PowerShell loader to $PROFILE"
        return $true
    }

    Add-Content -Path $PROFILE -Value ("`r`n" + $loaderBlock + "`r`n")
    Add-Log -Section Migration -Message "Appended Pretty PowerShell loader to $PROFILE"
    return $true
}

function Test-LegacyManagedProfile {
    if (-not (Test-Path $PROFILE)) { return $false }

    $profileContent = Get-Content $PROFILE -Raw
    $legacySignals = @(
        "### Chris Titus Tech's PowerShell profile",
        'https://github.com/ChrisTitusTech/powershell-profile.git',
        '$repo_root = "https://raw.githubusercontent.com/ChrisTitusTech"'
    )

    foreach ($signal in $legacySignals) {
        if ($profileContent -like "*$signal*") { return $true }
    }

    return $false
}

function Migrate-LegacyProfile {
    param([string]$ScriptPath, [string]$BackupDir, [switch]$ForceMigration)

    Ensure-Directory -Path $powerShellRoot

    $legacyProfileDetected = Test-LegacyManagedProfile
    if (-not $legacyProfileDetected -and -not $ForceMigration) {
        Add-Log -Section Detect -Message 'Legacy repo-managed main profile not confidently detected.'
        if ($DryRun) {
            Add-Log -Section Migration -Message 'Would skip full migration and append loader instead.'
        } else {
            Add-Log -Section Migration -Message 'Skipped full migration. Appending loader instead.'
            Write-Warning 'Legacy repo-managed main profile not detected. Appending loader instead.'
        }
        $loaderAdded = Ensure-ProfileLoader -ScriptPath $ScriptPath
        return [pscustomobject]@{
            Migrated             = $false
            LoaderAdded          = $loaderAdded
            MainProfileBackup    = $null
            CustomProfileBackup  = $null
            CustomProfileMerged  = $false
            CustomProfileWasPresent = $false
        }
    }

    Add-Log -Section Detect -Message 'Legacy split-profile install detected.'

    $mainProfileBackup = Backup-File -Path $PROFILE -BackupDir $BackupDir
    $customProfileBackup = Backup-File -Path $customProfilePath -BackupDir $BackupDir
    $customProfileContent = $null

    if ((Test-Path $customProfilePath) -and ((Resolve-Path $customProfilePath).Path -ne (Resolve-Path $PROFILE).Path)) {
        $customProfileContent = Get-Content $customProfilePath -Raw
        if ($DryRun) {
            Add-Log -Section Migration -Message "Would remove migrated sidecar profile: $customProfilePath"
        } else {
            Remove-Item $customProfilePath -Force
            Add-Log -Section Migration -Message "Removed migrated sidecar profile: $customProfilePath"
        }
    }

    $loaderBlock = Get-LoaderBlock -ScriptPath $ScriptPath
    $migrationDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'
    $newProfileHeader = @(
        '# Migrated by Pretty PowerShell setup',
        "# Migration date: $migrationDate",
        '# Repo-managed logic lives in standalone PrettyPowerShell.ps1'
    )
    if ($mainProfileBackup) { $newProfileHeader += "# Previous main profile backup: $mainProfileBackup" }
    if ($customProfileBackup) { $newProfileHeader += "# Previous custom profile backup: $customProfileBackup" }

    $newProfileContent = @(($newProfileHeader -join "`r`n"), $loaderBlock.TrimEnd()) -join "`r`n`r`n"

    if ($customProfileContent -and $customProfileContent.Trim()) {
        $newProfileContent += "`r`n`r`n# ---- BEGIN MIGRATED USER CUSTOMIZATIONS ----`r`n`r`n"
        $newProfileContent += $customProfileContent.Trim()
        $newProfileContent += "`r`n`r`n# ---- END MIGRATED USER CUSTOMIZATIONS ----`r`n"
    } else {
        $newProfileContent += "`r`n`r`n# Add your personal customizations below`r`n"
    }

    if ($DryRun) {
        Add-Log -Section Migration -Message "Would rewrite $PROFILE as loader-based migrated profile"
    } else {
        Set-Content -Path $PROFILE -Value $newProfileContent -Encoding UTF8
        Add-Log -Section Migration -Message "Rewrote $PROFILE as loader-based migrated profile"
    }

    $customMerged = [bool]($customProfileContent -and $customProfileContent.Trim())
    if ($customMerged) {
        Add-Log -Section Migration -Message $(if ($DryRun) { 'Would merge custom profile.ps1 content into $PROFILE' } else { 'Merged custom profile.ps1 content into $PROFILE' })
    } elseif ($customProfileBackup) {
        Add-Log -Section Migration -Message $(if ($DryRun) { 'Custom profile.ps1 exists but is empty; backup kept, no content merged' } else { 'Custom profile.ps1 was empty; backup kept, no content merged' })
    }

    return [pscustomobject]@{
        Migrated             = $true
        LoaderAdded          = $true
        MainProfileBackup    = $mainProfileBackup
        CustomProfileBackup  = $customProfileBackup
        CustomProfileMerged  = $customMerged
        CustomProfileWasPresent = [bool]$customProfileBackup
    }
}

function Ensure-FastfetchConfig {
    if (Test-Path $fastfetchConfigPath) {
        Add-Log -Section Install -Message "Fastfetch config already exists: $fastfetchConfigDir"
        return $false
    }

    if ($DryRun) {
        Add-Log -Section Install -Message "Would create directory: $fastfetchConfigDir"
        Add-Log -Section Install -Message "Would download fastfetch config and ascii art to $fastfetchConfigDir"
        return $true
    }

    Ensure-Directory -Path $fastfetchConfigDir
    Install-RepoFile -RelativePath 'fastfetch/config.jsonc' -Destination $fastfetchConfigPath -NoBom
    Install-RepoFile -RelativePath 'fastfetch/ascii.txt' -Destination (Join-Path $fastfetchConfigDir 'ascii.txt') -NoBom
    Add-Log -Section Install -Message "Initialized fastfetch config at $fastfetchConfigDir"
    return $true
}

function Ensure-StarshipConfig {
    if (Test-Path $starshipConfigPath) {
        Add-Log -Section Install -Message "Starship config already exists: $starshipConfigPath"
        return $false
    }

    if ($DryRun) {
        Add-Log -Section Install -Message "Would create directory: $starshipConfigDir"
        Add-Log -Section Install -Message "Would initialize Starship preset catppuccin-powerline at $starshipConfigPath"
        return $true
    }

    Ensure-Directory -Path $starshipConfigDir
    $starshipExe = Get-Command starship -CommandType Application -ErrorAction SilentlyContinue
    if (-not $starshipExe) {
        Add-Log -Section Install -Message 'Starship not found; skipped config bootstrap. Run: starship preset catppuccin-powerline -o ~/.config/starship.toml'
        Write-Warning 'Starship not found. Install it first, then run: starship preset catppuccin-powerline -o ~/.config/starship.toml'
        return $false
    }

    & $starshipExe.Source preset catppuccin-powerline -o $starshipConfigPath
    Add-Log -Section Install -Message "Initialized Starship preset catppuccin-powerline at $starshipConfigPath"
    return $true
}

function Install-TerminalIcons {
    if ($DryRun) {
        Add-Log -Section Dependencies -Message 'Would install Terminal-Icons module.'
        return
    }

    try {
        Install-Module -Name Terminal-Icons -Force -Repository PSGallery -Scope CurrentUser -ErrorAction Stop
        Add-Log -Section Dependencies -Message 'Installed Terminal-Icons module.'
    } catch {
        Add-Log -Section Dependencies -Message "Terminal-Icons install failed: $($_.Exception.Message)"
        Write-Warning "Terminal-Icons install failed: $($_.Exception.Message)"
    }
}

function Install-Starship {
    if ($DryRun) {
        Add-Log -Section Dependencies -Message $(if (Get-Command winget -ErrorAction SilentlyContinue) { 'Would install Starship via winget.' } else { 'Would require manual install of Starship (winget not found).' })
        return
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Starship.Starship --source winget --silent
        Add-Log -Section Dependencies -Message 'Installed Starship via winget.'
    } else {
        Add-Log -Section Dependencies -Message 'winget not found. Install Starship manually.'
        Write-Warning 'winget not found. Install Starship manually.'
    }
}

function Install-Fastfetch {
    if ($DryRun) {
        Add-Log -Section Dependencies -Message $(if (Get-Command winget -ErrorAction SilentlyContinue) { 'Would install fastfetch via winget.' } else { 'Would require manual install of fastfetch (winget not found).' })
        return
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id fastfetch-cli.fastfetch --source winget --silent
        Add-Log -Section Dependencies -Message 'Installed fastfetch via winget.'
    } else {
        Add-Log -Section Dependencies -Message 'winget not found. Install fastfetch manually.'
        Write-Warning 'winget not found. Install fastfetch manually.'
    }
}

function Set-WindowsTerminalFont {
    param([string]$FontFace = 'CaskaydiaCove Nerd Font')

    if ($DryRun) {
        Add-Log -Section Install -Message 'Would install CaskaydiaCove Nerd Font via winget.'
        if (Test-Path $wtSettingsPath) {
            Add-Log -Section Install -Message "Would patch Windows Terminal font to '$FontFace' in: $wtSettingsPath"
        }
        return
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id DEVCOM.CascadiaCodeNerdFont --source winget --silent
        Add-Log -Section Dependencies -Message 'Installed CaskaydiaCove Nerd Font via winget.'
    } else {
        Add-Log -Section Dependencies -Message 'winget not found. Install CaskaydiaCove Nerd Font manually.'
        Write-Warning 'winget not found. Install CaskaydiaCove Nerd Font manually.'
    }

    if (-not (Test-Path $wtSettingsPath)) {
        Add-Log -Section Install -Message 'Windows Terminal settings not found; skipped font patch.'
        return
    }

    $json = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json
    if (-not $json.profiles) { $json | Add-Member -NotePropertyName 'profiles' -NotePropertyValue ([pscustomobject]@{}) }
    if (-not $json.profiles.defaults) { $json.profiles | Add-Member -NotePropertyName 'defaults' -NotePropertyValue ([pscustomobject]@{}) }
    if (-not $json.profiles.defaults.font) { $json.profiles.defaults | Add-Member -NotePropertyName 'font' -NotePropertyValue ([pscustomobject]@{}) }
    $json.profiles.defaults.font | Add-Member -NotePropertyName 'face' -NotePropertyValue $FontFace -Force
    $json | ConvertTo-Json -Depth 10 | Set-Content -Path $wtSettingsPath -Encoding UTF8
    Add-Log -Section Install -Message "Patched Windows Terminal font to '$FontFace'."
}

function Copy-WindowsTerminalConfig {
    if ($DryRun) {
        Add-Log -Section Install -Message "Would copy repo Windows Terminal config to: $wtSettingsPath"
        return
    }

    Install-RepoFile -RelativePath 'windowsterminal/settings.json' -Destination $wtSettingsPath -NoBom
    Add-Log -Section Install -Message "Copied repo Windows Terminal config to: $wtSettingsPath"
}

function Install-Extras {
    param([bool]$Zoxide)

    if (-not $Zoxide) { return }

    if ($DryRun) {
        Add-Log -Section Dependencies -Message 'Would install zoxide via winget.'
        return
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id ajeetdsouza.zoxide --source winget --silent
        Add-Log -Section Dependencies -Message 'Installed zoxide via winget.'
    } else {
        Add-Log -Section Dependencies -Message 'winget not found. Install zoxide manually.'
        Write-Warning 'winget not found. Install zoxide manually.'
    }
}

# ─── Interactive setup ────────────────────────────────────────────────────────

$isLegacy = Test-LegacyManagedProfile

if (-not $DryRun -and -not $Force) {
    Write-Host ''
    $rule = Get-UiRule
    Write-Host $rule -ForegroundColor Cyan
    Write-Host '  Pretty PowerShell Setup' -ForegroundColor White
    Write-Host $rule -ForegroundColor Cyan
    Write-Host ''
    Write-Host "OS: $osName" -ForegroundColor DarkGray
    Write-Host "PowerShell: $shellName $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray
    Write-Host "Profile root: $powerShellRoot" -ForegroundColor DarkGray
    Write-Host ''

    $installChoiceIdx = Invoke-InteractiveMenu `
        -Question 'Install location:' `
        -Options @(
            "$powerShellRoot/PrettyPowerShell  (recommended)",
            "$powerShellRoot"
        ) `
        -Default 0

    $installDir = if ($installChoiceIdx -eq 0) {
        Join-Path $powerShellRoot 'PrettyPowerShell'
    } else {
        $powerShellRoot
    }

    Write-Host ''
    $doMigrate    = if ($isLegacy) { Invoke-InteractiveBool 'Legacy profile detected. Migrate to loader-based layout?' $true } else { $false }
    Write-Host ''
    $doStarship   = Invoke-InteractiveBool 'Install and configure Starship?' $true
    Write-Host ''
    $doFastfetch  = Invoke-InteractiveBool 'Install and configure Fastfetch?' $true
    Write-Host ''
    $extrasOptions = @('zoxide')
    $extrasIdx     = Invoke-InteractiveMultiSelect -Question 'Select extras to install:' -Options $extrasOptions -Defaults @(0)
    $doZoxide      = $extrasIdx -contains 0

    Write-Host ''
    $doWtFullConfig = Invoke-InteractiveBool 'Use my Windows Terminal config?' $false

    Write-Host ''
    Write-Host $rule -ForegroundColor Cyan
    Write-Host '  Press Enter to install or Ctrl+C to cancel.' -ForegroundColor White
    Write-Host $rule -ForegroundColor Cyan
    Read-Host | Out-Null
    Write-Host ''
} else {
    # DryRun or Force: use safe defaults
    $installDir  = Join-Path $powerShellRoot 'PrettyPowerShell'
    $doMigrate   = $isLegacy
    $doStarship  = $true
    $doFastfetch = $true
    $doZoxide       = $true
    $doWtFullConfig = $false
}

$installPath = Join-Path $installDir 'PrettyPowerShell.ps1'
$backupDir   = Join-Path $backupRootDir $script:BackupTimestamp

# ─── Execute ──────────────────────────────────────────────────────────────────

Ensure-Directory -Path $installDir

if (Test-Path $installPath) { Backup-File -Path $installPath -BackupDir $backupDir | Out-Null }
if (Test-Path $starshipConfigPath) { Backup-File -Path $starshipConfigPath -BackupDir $backupDir | Out-Null }
if (Test-Path $fastfetchConfigDir) { Backup-Directory -Path $fastfetchConfigDir -Name 'fastfetch' -BackupDir $backupDir | Out-Null }
if (Test-Path $wtSettingsPath) { Backup-File -Path $wtSettingsPath -BackupDir $backupDir | Out-Null }

Install-RepoFile -RelativePath 'Profile.ps1' -Destination $installPath

Install-TerminalIcons
if ($doStarship)  { Install-Starship; Ensure-StarshipConfig | Out-Null }
if ($doFastfetch) { Install-Fastfetch; Ensure-FastfetchConfig | Out-Null }
Install-Extras -Zoxide $doZoxide
if ($doWtFullConfig) { Copy-WindowsTerminalConfig } else { Set-WindowsTerminalFont }

$migrationResult = if ($doMigrate) {
    Migrate-LegacyProfile -ScriptPath $installPath -BackupDir $backupDir -ForceMigration:$Force
} else {
    [pscustomobject]@{
        Migrated             = $false
        LoaderAdded          = (Ensure-ProfileLoader -ScriptPath $installPath)
        MainProfileBackup    = $null
        CustomProfileBackup  = $null
        CustomProfileMerged  = $false
        CustomProfileWasPresent = $false
    }
}

Add-Log -Section Result -Message "Standalone script: $installPath"
Add-Log -Section Result -Message "Starship config: $starshipConfigPath"
Add-Log -Section Result -Message "Windows Terminal config: $wtSettingsPath"

if ($migrationResult.Migrated) {
    if ($migrationResult.MainProfileBackup) {
        Add-Log -Section Result -Message "Main profile backup: $($migrationResult.MainProfileBackup)"
    }
    if ($migrationResult.CustomProfileBackup) {
        Add-Log -Section Result -Message "Custom profile backup: $($migrationResult.CustomProfileBackup)"
    }
} elseif ($migrationResult.LoaderAdded) {
    Add-Log -Section Result -Message "Loader added to: $PROFILE"
}

Write-InstallSummary
