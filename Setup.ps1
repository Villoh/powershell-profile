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
$themePath = Join-Path $installDir 'cobalt2.omp.json'
$customProfilePath = Join-Path $powerShellRoot 'profile.ps1'
$backupDir = Join-Path $powerShellRoot 'Backups'
$script:DryRunBackupDirPlanned = $false
$script:DryRunActions = [ordered]@{
    Detect = [System.Collections.Generic.List[string]]::new()
    Install = [System.Collections.Generic.List[string]]::new()
    Backups = [System.Collections.Generic.List[string]]::new()
    Migration = [System.Collections.Generic.List[string]]::new()
    Dependencies = [System.Collections.Generic.List[string]]::new()
    Result = [System.Collections.Generic.List[string]]::new()
}

function Add-DryRunAction {
    param(
        [ValidateSet('Detect', 'Install', 'Backups', 'Migration', 'Dependencies', 'Result')]
        [string]$Section,
        [string]$Message
    )

    $script:DryRunActions[$Section].Add($Message)
}

function Write-DryRunSummary {
    Write-Host '[DryRun] Pretty PowerShell preview' -ForegroundColor Cyan

    foreach ($section in $script:DryRunActions.Keys) {
        $entries = $script:DryRunActions[$section]
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
    Write-Host '[DryRun] No files were changed.' -ForegroundColor Cyan
}

function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        if ($DryRun) {
            Add-DryRunAction -Section Install -Message "Would create directory: $Path"
            return
        }
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Backup-File {
    param([string]$Path)

    if (Test-Path $Path) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $fileName = Split-Path -Leaf $Path
        $backupPath = Join-Path $backupDir "$fileName.$timestamp.bak"
        if ($DryRun) {
            if (-not (Test-Path $backupDir) -and -not $script:DryRunBackupDirPlanned) {
                Add-DryRunAction -Section Backups -Message "Would create backup folder: $backupDir"
                $script:DryRunBackupDirPlanned = $true
            }
            Add-DryRunAction -Section Backups -Message "Would back up $Path to $backupPath"
            return $backupPath
        }
        Ensure-Directory -Path $backupDir
        Copy-Item -Path $Path -Destination $backupPath -Force
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
        Add-DryRunAction -Section Install -Message "Would download $Uri to $Destination"
        return
    }

    Invoke-WebRequest -Uri $Uri -OutFile $Destination
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
            Add-DryRunAction -Section Install -Message "Would create profile file: $PROFILE"
        } else {
            New-Item -Path $PROFILE -ItemType File -Force | Out-Null
        }
    }

    $loaderBlock = Get-LoaderBlock -ScriptPath $ScriptPath
    $current = if (Test-Path $PROFILE) { Get-Content $PROFILE -Raw } else { '' }
    if ($current -match [regex]::Escape($loaderBlock.Trim())) {
        return $false
    }

    if ($DryRun) {
        Add-DryRunAction -Section Migration -Message "Would append Pretty PowerShell loader to $PROFILE"
        return $true
    }

    Add-Content -Path $PROFILE -Value ("`r`n" + $loaderBlock)
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
        if ($DryRun) {
            Add-DryRunAction -Section Detect -Message 'Legacy repo-managed main profile not confidently detected.'
            Add-DryRunAction -Section Migration -Message 'Would skip full migration and append loader instead.'
        } else {
            Write-Warning 'Legacy repo-managed main profile not detected. Skipping migration and appending loader instead.'
        }
        $loaderAdded = Ensure-ProfileLoader -ScriptPath $ScriptPath
        return [pscustomobject]@{
            Migrated = $false
            LoaderAdded = $loaderAdded
            MainProfileBackup = $null
            CustomProfileBackup = $null
            CustomProfileMerged = $false
            CustomProfileWasPresent = $false
        }
    }

    if ($DryRun) {
        Add-DryRunAction -Section Detect -Message 'Legacy split-profile install detected. Migration plan ready.'
    }

    $mainProfileBackup = Backup-File -Path $PROFILE
    $customProfileBackup = Backup-File -Path $customProfilePath
    $customProfileContent = $null

    if ((Test-Path $customProfilePath) -and ((Resolve-Path $customProfilePath).Path -ne (Resolve-Path $PROFILE).Path)) {
        $customProfileContent = Get-Content $customProfilePath -Raw
        if ($DryRun) {
            Add-DryRunAction -Section Migration -Message "Would remove migrated sidecar profile: $customProfilePath"
        } else {
            Remove-Item $customProfilePath -Force
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
        Add-DryRunAction -Section Migration -Message "Would rewrite $PROFILE as loader-based migrated profile"
    } else {
        Set-Content -Path $PROFILE -Value $newProfileContent -Encoding UTF8
    }

    return [pscustomobject]@{
        Migrated = $true
        LoaderAdded = $true
        MainProfileBackup = $mainProfileBackup
        CustomProfileBackup = $customProfileBackup
        CustomProfileMerged = [bool]($customProfileContent -and $customProfileContent.Trim())
        CustomProfileWasPresent = [bool]$customProfileBackup
    }
}

function Install-Dependencies {
    if (-not $InstallDependencies) {
        return
    }

    if ($DryRun) {
        Add-DryRunAction -Section Dependencies -Message 'Would install Terminal-Icons module.'
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Add-DryRunAction -Section Dependencies -Message 'Would install Oh My Posh, zoxide, and JetBrainsMono Nerd Font via winget.'
        } else {
            Add-DryRunAction -Section Dependencies -Message 'Would require manual install of Oh My Posh, zoxide, and JetBrainsMono Nerd Font because winget was not found.'
        }
        return
    }

    try {
        Install-Module -Name Terminal-Icons -Force -Repository PSGallery -Scope CurrentUser -ErrorAction Stop
    } catch {
        Write-Warning "Terminal-Icons install failed: $($_.Exception.Message)"
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install JanDeDobbeleer.OhMyPosh ajeetdsouza.zoxide DEVCOM.JetBrainsMonoNerdFont --source winget --silent
    } else {
        Write-Warning 'winget not found. Install Oh My Posh, zoxide, and JetBrainsMono Nerd Font manually if needed.'
    }
}

Ensure-Directory -Path $installDir

if ((Test-Path $installPath) -and -not $Force) {
    Backup-File -Path $installPath | Out-Null
}
if ((Test-Path $themePath) -and -not $Force) {
    Backup-File -Path $themePath | Out-Null
}

Install-RemoteFile -Uri "$repoBase/Profile.ps1" -Destination $installPath
Install-RemoteFile -Uri 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/cobalt2.omp.json' -Destination $themePath
Install-Dependencies

$migrationResult = if ($MigrateLegacyProfile) {
    Migrate-LegacyProfile -ScriptPath $installPath -ForceMigration:$Force
} else {
    [pscustomobject]@{
        Migrated = $false
        LoaderAdded = (Ensure-ProfileLoader -ScriptPath $installPath)
        MainProfileBackup = $null
        CustomProfileBackup = $null
        CustomProfileMerged = $false
        CustomProfileWasPresent = $false
    }
}

if ($DryRun) {
    Add-DryRunAction -Section Result -Message "Standalone script path: $installPath"
    Add-DryRunAction -Section Result -Message "Theme path: $themePath"

    if ($migrationResult.Migrated) {
        Add-DryRunAction -Section Result -Message "Would migrate legacy main profile: $PROFILE"
        if ($migrationResult.MainProfileBackup) {
            Add-DryRunAction -Section Result -Message "Would create main profile backup: $($migrationResult.MainProfileBackup)"
        }
        if ($migrationResult.CustomProfileMerged) {
            Add-DryRunAction -Section Result -Message 'Would merge custom profile content into $PROFILE.'
        } elseif ($migrationResult.CustomProfileWasPresent) {
            Add-DryRunAction -Section Result -Message 'Custom profile exists but appears empty; backup would be kept and no custom content would be merged.'
        }
        if ($migrationResult.CustomProfileBackup) {
            Add-DryRunAction -Section Result -Message "Would create custom profile backup: $($migrationResult.CustomProfileBackup)"
        }
    } elseif ($migrationResult.LoaderAdded) {
        Add-DryRunAction -Section Result -Message "Would add loader to: $PROFILE"
    } else {
        Add-DryRunAction -Section Result -Message "Loader already present in: $PROFILE"
    }

    Write-DryRunSummary
} else {
    Write-Host 'Pretty PowerShell installed as standalone script.' -ForegroundColor Green
    Write-Host "Script path: $installPath" -ForegroundColor Green
    Write-Host "Theme path:  $themePath" -ForegroundColor Green

    if ($migrationResult.Migrated) {
        Write-Host "Legacy main profile migrated: $PROFILE" -ForegroundColor Green
        if ($migrationResult.MainProfileBackup) {
            Write-Host "Main profile backup: $($migrationResult.MainProfileBackup)" -ForegroundColor Yellow
        }
        if ($migrationResult.CustomProfileMerged) {
            Write-Host 'Custom profile content merged into migrated $PROFILE.' -ForegroundColor Green
        } elseif ($migrationResult.CustomProfileWasPresent) {
            Write-Warning 'Custom profile existed but was empty. Backup kept; no custom content was merged.'
        }
        if ($migrationResult.CustomProfileBackup) {
            Write-Host "Custom profile backup: $($migrationResult.CustomProfileBackup)" -ForegroundColor Yellow
        }
    } elseif ($migrationResult.LoaderAdded) {
        Write-Host "Loader added to: $PROFILE" -ForegroundColor Green
    } else {
        Write-Host "Loader already present in: $PROFILE" -ForegroundColor Yellow
    }
}
