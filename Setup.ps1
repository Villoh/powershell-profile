[CmdletBinding()]
param(
    [ValidateSet('Functions', 'PowerShellRoot')]
    [string]$InstallMode = 'Functions',
    [switch]$InstallDependencies,
    [switch]$MigrateLegacyProfile,
    [switch]$DryRun,
    [switch]$Force
)

$repoBase = 'https://raw.githubusercontent.com/Villoh/powershell-profile/main'
$powerShellRoot = Split-Path -Parent $PROFILE
$installDir = switch ($InstallMode) {
    'Functions' { Join-Path $powerShellRoot 'Functions' }
    'PowerShellRoot' { $powerShellRoot }
}
$installPath = Join-Path $installDir 'PrettyPowerShell.ps1'
$starshipConfigDir = Join-Path $HOME '.config'
$starshipConfigPath = Join-Path $starshipConfigDir 'starship.toml'
$customProfilePath = Join-Path $powerShellRoot 'profile.ps1'
$backupDir = Join-Path $powerShellRoot 'Backups'
$script:BackupDirLogged = $false
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

function Write-InstallSummary {
    if ($DryRun) {
        Write-Host '[DryRun] Pretty PowerShell preview' -ForegroundColor Cyan
    } else {
        Write-Host 'Pretty PowerShell installed.' -ForegroundColor Green
    }

    foreach ($section in $script:InstallLog.Keys) {
        $entries = $script:InstallLog[$section]
        if ($entries.Count -eq 0) {
            continue
        }

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

function Backup-File {
    param([string]$Path)

    if (Test-Path $Path) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $fileName = Split-Path -Leaf $Path
        $backupPath = Join-Path $backupDir "$fileName.$timestamp.bak"

        if (-not (Test-Path $backupDir) -and -not $script:BackupDirLogged) {
            if ($DryRun) {
                Add-Log -Section Backups -Message "Would create backup folder: $backupDir"
            } else {
                Ensure-Directory -Path $backupDir
                Add-Log -Section Backups -Message "Created backup folder: $backupDir"
            }
            $script:BackupDirLogged = $true
        }

        if ($DryRun) {
            Add-Log -Section Backups -Message "Would back up $Path to $backupPath"
        } else {
            if (-not (Test-Path $backupDir)) {
                Ensure-Directory -Path $backupDir
            }
            Copy-Item -Path $Path -Destination $backupPath -Force
            Add-Log -Section Backups -Message "Backed up $Path to $backupPath"
        }

        return $backupPath
    }

    return $null
}

function Install-RemoteFile {
    param(
        [string]$Uri,
        [string]$Destination
    )

    if ($DryRun) {
        Add-Log -Section Install -Message "Would download $Uri to $Destination"
        return
    }

    Invoke-WebRequest -Uri $Uri -OutFile $Destination
    Add-Log -Section Install -Message "Downloaded $Uri to $Destination"
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

    $loaderBlock = Get-LoaderBlock -ScriptPath $ScriptPath
    $current = if (Test-Path $PROFILE) { Get-Content $PROFILE -Raw } else { '' }
    if ($current -match [regex]::Escape($loaderBlock.Trim())) {
        Add-Log -Section Migration -Message "Loader already present in: $PROFILE"
        return $false
    }

    if ($DryRun) {
        Add-Log -Section Migration -Message "Would append Pretty PowerShell loader to $PROFILE"
        return $true
    }

    Add-Content -Path $PROFILE -Value ("`r`n" + $loaderBlock)
    Add-Log -Section Migration -Message "Appended Pretty PowerShell loader to $PROFILE"
    return $true
}

function Test-LegacyManagedProfile {
    if (-not (Test-Path $PROFILE)) {
        return $false
    }

    $profileContent = Get-Content $PROFILE -Raw
    $legacySignals = @(
        "Chris Titus Tech's PowerShell profile",
        'function Update-Profile',
        'function Show-Help',
        'oh-my-posh init pwsh',
        'zoxide init --cmd z powershell'
    )

    foreach ($signal in $legacySignals) {
        if ($profileContent -like "*$signal*") {
            return $true
        }
    }

    return $false
}

function Migrate-LegacyProfile {
    param(
        [string]$ScriptPath,
        [switch]$ForceMigration
    )

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

    $mainProfileBackup = Backup-File -Path $PROFILE
    $customProfileBackup = Backup-File -Path $customProfilePath
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
    if ($mainProfileBackup) {
        $newProfileHeader += "# Previous main profile backup: $mainProfileBackup"
    }
    if ($customProfileBackup) {
        $newProfileHeader += "# Previous custom profile backup: $customProfileBackup"
    }
    $newProfileContent = @(
        ($newProfileHeader -join "`r`n"),
        $loaderBlock.TrimEnd()
    ) -join "`r`n`r`n"

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
        if ($DryRun) {
            Add-Log -Section Migration -Message 'Would merge custom profile.ps1 content into $PROFILE'
        } else {
            Add-Log -Section Migration -Message 'Merged custom profile.ps1 content into $PROFILE'
        }
    } elseif ($customProfileBackup) {
        if ($DryRun) {
            Add-Log -Section Migration -Message 'Custom profile.ps1 exists but is empty; backup kept, no content merged'
        } else {
            Add-Log -Section Migration -Message 'Custom profile.ps1 was empty; backup kept, no content merged'
        }
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

function Install-Dependencies {
    if (-not $InstallDependencies) {
        return
    }

    if ($DryRun) {
        Add-Log -Section Dependencies -Message 'Would install Terminal-Icons module.'
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Add-Log -Section Dependencies -Message 'Would install Starship, zoxide, and JetBrainsMono Nerd Font via winget.'
        } else {
            Add-Log -Section Dependencies -Message 'Would require manual install of Starship, zoxide, and JetBrainsMono Nerd Font (winget not found).'
        }
        return
    }

    try {
        Install-Module -Name Terminal-Icons -Force -Repository PSGallery -Scope CurrentUser -ErrorAction Stop
        Add-Log -Section Dependencies -Message 'Installed Terminal-Icons module.'
    } catch {
        Add-Log -Section Dependencies -Message "Terminal-Icons install failed: $($_.Exception.Message)"
        Write-Warning "Terminal-Icons install failed: $($_.Exception.Message)"
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Starship.Starship --source winget --silent
        winget install ajeetdsouza.zoxide DEVCOM.JetBrainsMonoNerdFont --source winget --silent
        Add-Log -Section Dependencies -Message 'Installed Starship, zoxide, and JetBrainsMono Nerd Font via winget.'
    } else {
        Add-Log -Section Dependencies -Message 'winget not found. Install Starship, zoxide, and JetBrainsMono Nerd Font manually.'
        Write-Warning 'winget not found. Install Starship, zoxide, and JetBrainsMono Nerd Font manually if needed.'
    }
}

Ensure-Directory -Path $installDir

if (Test-Path $installPath) {
    Backup-File -Path $installPath | Out-Null
}
if (Test-Path $starshipConfigPath) {
    Backup-File -Path $starshipConfigPath | Out-Null
}

Install-RemoteFile -Uri "$repoBase/Profile.ps1" -Destination $installPath
Install-Dependencies
Ensure-StarshipConfig | Out-Null

$migrationResult = if ($MigrateLegacyProfile) {
    Migrate-LegacyProfile -ScriptPath $installPath -ForceMigration:$Force
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
