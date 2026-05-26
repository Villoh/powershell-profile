### Pretty PowerShell standalone script

# Feature flags - set to $false to disable
$script:EnableStarship  = $true
$script:EnableFastfetch = $true

$script:PrettyPowerShellSourcePath = $PSCommandPath
$script:PrettyPowerShellRoot = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { $null }
$script:IsInteractiveShell = $Host.Name -eq 'ConsoleHost' -and -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected
$script:PrettyPowerShellBackupRoot = if ($PROFILE) { Join-Path (Split-Path -Parent $PROFILE) 'Backups' } else { $null }
$script:PrettyPowerShellUserHome = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$script:UseAsciiUi = $PSVersionTable.PSEdition -ne 'Core'
$script:PrettyPowerShellStarshipConfigPath = Join-Path $script:PrettyPowerShellUserHome '.config/starship.toml'
$script:PrettyPowerShellFastfetchConfigPath = Join-Path $script:PrettyPowerShellUserHome '.config/fastfetch/config.jsonc'

function Get-PrettyPowerShellInstallPath {
    $script:PrettyPowerShellSourcePath
}

function Get-PrettyPowerShellStarshipConfigPath {
    if (Test-Path $script:PrettyPowerShellStarshipConfigPath) {
        return $script:PrettyPowerShellStarshipConfigPath
    }

    return $null
}

function Backup-PrettyPowerShellFile {
    param([string]$Path)

    if (-not $Path -or -not (Test-Path $Path)) {
        return $null
    }

    if (-not $script:PrettyPowerShellBackupRoot) {
        return $null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupDir = Join-Path $script:PrettyPowerShellBackupRoot $timestamp
    $fileName = Split-Path -Leaf $Path
    $backupPath = Join-Path $backupDir $fileName

    if (-not (Test-Path $backupDir)) {
        New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
    }

    Copy-Item -Path $Path -Destination $backupPath -Force
    return $backupPath
}

function Initialize-PrettyPrompt {
    if (-not $script:IsInteractiveShell -or -not $script:EnableStarship) {
        return
    }

    $starshipExe = Get-Command starship -CommandType Application -ErrorAction Ignore |
        Select-Object -First 1 -ExpandProperty Source

    if ($starshipExe) {
        Invoke-Expression (& $starshipExe init powershell)
    }
}

function Initialize-PrettyNavigation {
    if (-not $script:IsInteractiveShell) {
        return
    }

    $zoxideExe = Get-Command zoxide -CommandType Application -ErrorAction Ignore |
        Select-Object -First 1 -ExpandProperty Source

    if ($zoxideExe) {
        Set-Variable -Name __zoxide_hooked -Scope Script -Value $false -Force
        Set-Variable -Name __zoxide_hooked -Scope Global -Value $false -Force
        & $zoxideExe init --cmd z powershell | Out-String | Invoke-Expression 2>$null
    }
}

function Initialize-PrettyModules {
    if (Get-Module -ListAvailable -Name Terminal-Icons) {
        Import-Module -Name Terminal-Icons
    }
}

function Initialize-PrettyReadLine {
    if (-not $script:IsInteractiveShell) {
        return
    }

    if (-not (Get-Module -ListAvailable -Name PSReadLine)) {
        return
    }

    $options = @{
        Colors = @{
            Command   = '#87CEEB'
            Parameter = '#98FB98'
            Operator  = '#FFB6C1'
            Variable  = '#DDA0DD'
            String    = '#FFDAB9'
            Number    = '#B0E0E6'
            Type      = '#F0E68C'
            Comment   = '#D3D3D3'
            Keyword   = '#8367c7'
            Error     = '#FF6347'
        }
    }

    if ($PSVersionTable.PSEdition -eq 'Core') {
        $options.PredictionViewStyle = 'ListView'
    }

    Set-PSReadLineOption @options
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
    Set-PSReadLineKeyHandler -Chord 'Ctrl+w' -Function BackwardDeleteWord
    Set-PSReadLineKeyHandler -Chord 'Alt+d' -Function DeleteWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
    Set-PSReadLineKeyHandler -Chord 'Ctrl+y' -Function Redo
}

function Update-Profile {
    [CmdletBinding()]
    param(
        [string]$Ref = 'main'
    )

    $installPath = Get-PrettyPowerShellInstallPath
    if (-not $installPath) {
        Write-Error 'Unable to determine Pretty PowerShell install path.'
        return
    }

    $baseUrl = "https://raw.githubusercontent.com/Villoh/powershell-profile/$Ref"
    $scriptBackup = Backup-PrettyPowerShellFile -Path $installPath

    Invoke-WebRequest -Uri "$baseUrl/Profile.ps1" -OutFile $installPath -UseBasicParsing

    Write-Host "Updated Pretty PowerShell script at $installPath" -ForegroundColor Green
    if ($scriptBackup) {
        Write-Host "Backup created: $scriptBackup" -ForegroundColor Yellow
    }
}

function Get-PrettyPowerShellEditor {
    $fromEnv = if ($env:VISUAL) { $env:VISUAL } elseif ($env:EDITOR) { $env:EDITOR } else { $null }
    if ($fromEnv -and (Get-Command $fromEnv -ErrorAction SilentlyContinue)) {
        return $fromEnv
    }

    foreach ($editor in @('nvim', 'code', 'notepad++')) {
        $command = Get-Command $editor -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }

    return 'notepad'
}

function Edit-Profile {
    $editor = Get-PrettyPowerShellEditor
    & $editor $script:PrettyPowerShellSourcePath
}

Set-Alias -Name ep -Value Edit-Profile

function Invoke-Profile {
    & $PROFILE
}

function touch ($File) {
    if (Test-Path $File) {
        (Get-Item $File).LastWriteTime = Get-Date
    } else {
        New-Item $File -ItemType File | Out-Null
    }
}

function pubip {
    (Invoke-WebRequest http://ifconfig.me/ip).Content
}

function admin {
    $cwd = (Get-Location).ProviderPath
    $terminal = Get-Command wt -ErrorAction SilentlyContinue
    if ($terminal) {
        if ($args.Count -gt 0) {
            $argList = $args -join ' '
            Start-Process $terminal.Source -Verb RunAs -ArgumentList @('-d', $cwd, 'pwsh.exe', '-NoExit', '-Command', $argList)
        } else {
            Start-Process $terminal.Source -Verb RunAs -ArgumentList @('-d', $cwd, 'pwsh.exe', '-NoExit')
        }
        return
    }

    if ($args.Count -gt 0) {
        $argList = $args -join ' '
        Start-Process pwsh -Verb RunAs -ArgumentList @('-NoExit', '-Command', "Set-Location '$cwd'; $argList")
    } else {
        Start-Process pwsh -Verb RunAs -ArgumentList @('-NoExit', '-Command', "Set-Location '$cwd'")
    }
}

Set-Alias -Name su -Value admin

function mkcd ($Path) {
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
    Set-Location -Path $Path
}

function trash ($Path) {
    if (Test-Path $Path -PathType Container) {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($Path, 'OnlyErrorDialogs', 'SendToRecycleBin')
    } else {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($Path, 'OnlyErrorDialogs', 'SendToRecycleBin')
    }
}

function ff ($Name) {
    Get-ChildItem -Recurse -Filter $Name -File | Select-Object -ExpandProperty FullName
}

function head ($Path) {
    Get-Content $Path -Head 10
}

function tail {
    param($Path, $n = 10, [switch]$f = $false)
    Get-Content $Path -Tail $n -Wait:$f
}

function sed ($File, $Find, $Replace) {
    (Get-Content $File).replace("$Find", $Replace) | Set-Content $File
}

function which ($Name) {
    (Get-Command $Name).Source
}

function df {
    Get-Volume
}

function export($Name, $Value) {
    Set-Item -Force -Path "env:$Name" -Value $Value
}

function unzip ($File) {
    if (-not (Test-Path $File -PathType Leaf)) {
        Write-Error "File not found: $File"
        return
    }

    Expand-Archive -Path $File -DestinationPath (Get-Location) -Force
}

function pgrep ($Name) {
    Get-Process -Name $Name -ErrorAction SilentlyContinue
}

function pkill ($Name) {
    Get-Process -Name $Name -ErrorAction SilentlyContinue | Stop-Process -Force
}

function k9 ($Name) {
    pkill $Name
}

function grep ($Pattern, $Path) {
    if ($Path) {
        Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | Select-String -Pattern $Pattern
    } elseif ($input) {
        $input | Select-String -Pattern $Pattern
    } else {
        Write-Error 'Usage: grep <pattern> [path] or pipe input to grep'
    }
}

function nf {
    param($Name)
    New-Item -ItemType File -Path . -Name $Name
}

function uptime {
    if (Get-Command Get-Uptime -ErrorAction SilentlyContinue) {
        $boot = Get-Uptime -Since
    } else {
        $boot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    }
    (Get-Date) - $boot | Select-Object Days, Hours, Minutes, Seconds
}

function winutil {
    Invoke-RestMethod https://christitus.com/win | Invoke-Expression
}

function winutildev {
    Invoke-RestMethod https://christitus.com/windev | Invoke-Expression
}

function gs { git status }
function ga { git add . }
function gc { param($m) git commit -m "$m" }
function gp { git push }
function gpush { git push }
function gpull { git pull }
function gcl { git clone $args }

function gcom {
    git add .
    git commit -m "$args"
}

function lazyg {
    git add .
    git commit -m "$args"
    git push
}

function g {
    if (Get-Command __zoxide_z -ErrorAction SilentlyContinue) {
        __zoxide_z github
    } elseif (Test-Path "$HOME/github") {
        Set-Location "$HOME/github"
    }
}

function docs {
    Set-Location -Path ([Environment]::GetFolderPath('MyDocuments'))
}

function dtop {
    Set-Location -Path ([Environment]::GetFolderPath('Desktop'))
}

function la {
    Get-ChildItem | Format-Table -AutoSize
}

function ll {
    Get-ChildItem -Force | Format-Table -AutoSize
}

function sysinfo {
    Get-ComputerInfo
}

function flushdns {
    Clear-DnsClientCache
    Write-Host 'DNS has been flushed'
}

function cpy {
    Set-Clipboard $args[0]
}

function pst {
    Get-Clipboard
}

function Show-Help {
    $title    = $PSStyle.Foreground.BrightMagenta
    $section  = $PSStyle.Foreground.BrightBlue
    $command  = $PSStyle.Foreground.BrightGreen
    $desc     = $PSStyle.Foreground.BrightWhite
    $accent   = $PSStyle.Foreground.BrightYellow
    $dim      = $PSStyle.Foreground.BrightBlack
    $reset    = $PSStyle.Reset
    $installPath = Get-PrettyPowerShellInstallPath
    $rule = if ($script:UseAsciiUi) { '----------------------------------------------------' } else { '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' }
    $subrule = if ($script:UseAsciiUi) { '----------------------------------------------------' } else { '────────────────────────────────────────────────────' }
    $arrow = if ($script:UseAsciiUi) { '->' } else { '→' }
    $helpTitle = if ($script:UseAsciiUi) { 'Pretty PowerShell Help' } else { '󰘳 Pretty PowerShell Help' }
    $scriptTitle = if ($script:UseAsciiUi) { 'Script' } else { '󰊢 Script' }
    $gitTitle = if ($script:UseAsciiUi) { 'Git Shortcuts' } else { '󰊢 Git Shortcuts' }
    $systemTitle = if ($script:UseAsciiUi) { 'System Shortcuts' } else { '󰘴 System Shortcuts' }

    Write-Host @"
${title}$helpTitle${reset}
${dim}$rule${reset}

${section}$scriptTitle${reset}
${dim}$subrule${reset}
  ${command}Loaded from${reset}        ${accent}$arrow${reset} ${desc}$installPath${reset}
  ${command}Edit-Profile / ep${reset}  ${accent}$arrow${reset} ${desc}Open profile for editing.${reset}
  ${command}Invoke-Profile${reset}     ${accent}$arrow${reset} ${desc}Reload current profile.${reset}
  ${command}Update-Profile${reset}     ${accent}$arrow${reset} ${desc}Update standalone Pretty PowerShell script.${reset}

${section}$gitTitle${reset}
${dim}$subrule${reset}
  ${command}g${reset}                  ${accent}$arrow${reset} ${desc}Changes to GitHub directory${reset}
  ${command}ga${reset}                 ${accent}$arrow${reset} ${desc}git add .${reset}
  ${command}gc <message>${reset}       ${accent}$arrow${reset} ${desc}git commit -m${reset}
  ${command}gcl <repo>${reset}         ${accent}$arrow${reset} ${desc}git clone${reset}
  ${command}gcom <message>${reset}     ${accent}$arrow${reset} ${desc}add + commit${reset}
  ${command}gp / gpush${reset}         ${accent}$arrow${reset} ${desc}git push${reset}
  ${command}gpull${reset}              ${accent}$arrow${reset} ${desc}git pull${reset}
  ${command}gs${reset}                 ${accent}$arrow${reset} ${desc}git status${reset}
  ${command}lazyg <message>${reset}    ${accent}$arrow${reset} ${desc}add + commit + push${reset}

${section}$systemTitle${reset}
${dim}$subrule${reset}
  ${command}admin / su [cmd]${reset}   ${accent}$arrow${reset} ${desc}Open elevated shell or run command.${reset}
  ${command}cpy <text>${reset}         ${accent}$arrow${reset} ${desc}Copy text to clipboard.${reset}
  ${command}df${reset}                 ${accent}$arrow${reset} ${desc}Show volumes.${reset}
  ${command}docs${reset}               ${accent}$arrow${reset} ${desc}Documents folder.${reset}
  ${command}dtop${reset}               ${accent}$arrow${reset} ${desc}Desktop folder.${reset}
  ${command}export <k> <v>${reset}     ${accent}$arrow${reset} ${desc}Set environment variable.${reset}
  ${command}ff <name>${reset}          ${accent}$arrow${reset} ${desc}Search files${reset}
  ${command}flushdns${reset}           ${accent}$arrow${reset} ${desc}Clear DNS cache.${reset}
  ${command}grep <pattern> [path]${reset} ${accent}$arrow${reset} ${desc}Search text${reset}
  ${command}head <file>${reset}        ${accent}$arrow${reset} ${desc}First lines${reset}
  ${command}k9 <name>${reset}          ${accent}$arrow${reset} ${desc}Kill process by name${reset}
  ${command}ll / la${reset}            ${accent}$arrow${reset} ${desc}List files${reset}
  ${command}mkcd <dir>${reset}         ${accent}$arrow${reset} ${desc}Create + enter dir${reset}
  ${command}nf <name>${reset}          ${accent}$arrow${reset} ${desc}Create new file.${reset}
  ${command}pgrep <name>${reset}       ${accent}$arrow${reset} ${desc}Find process by name${reset}
  ${command}pkill <name>${reset}       ${accent}$arrow${reset} ${desc}Stop process by name${reset}
  ${command}pst${reset}                ${accent}$arrow${reset} ${desc}Paste clipboard text.${reset}
  ${command}pubip${reset}              ${accent}$arrow${reset} ${desc}Show public IP.${reset}
  ${command}sed <file> <find> <replace>${reset} ${accent}$arrow${reset} ${desc}Replace text${reset}
  ${command}sysinfo${reset}            ${accent}$arrow${reset} ${desc}Show system info.${reset}
  ${command}tail <file> [n]${reset}    ${accent}$arrow${reset} ${desc}Last lines, optional follow.${reset}
  ${command}touch <file>${reset}       ${accent}$arrow${reset} ${desc}Create file${reset}
  ${command}unzip <file>${reset}       ${accent}$arrow${reset} ${desc}Extract zip${reset}
  ${command}uptime${reset}             ${accent}$arrow${reset} ${desc}System uptime${reset}
  ${command}which <name>${reset}       ${accent}$arrow${reset} ${desc}Locate command${reset}
  ${command}winutil${reset}            ${accent}$arrow${reset} ${desc}Run WinUtil${reset}
  ${command}winutildev${reset}         ${accent}$arrow${reset} ${desc}Run WinUtil Dev${reset}

${dim}$rule${reset}
"@
}

Initialize-PrettyPrompt
Initialize-PrettyNavigation
Initialize-PrettyModules
Initialize-PrettyReadLine

if ($script:IsInteractiveShell) {
    if ($script:EnableFastfetch) {
        $fastfetchExe = Get-Command fastfetch -CommandType Application -ErrorAction Ignore |
            Select-Object -First 1 -ExpandProperty Source
        if ($fastfetchExe -and (Test-Path $script:PrettyPowerShellFastfetchConfigPath)) {
            & $fastfetchExe --config $script:PrettyPowerShellFastfetchConfigPath
        }
    }

    Write-Host "Use 'Show-Help' to list all available functions" -ForegroundColor Yellow
}
