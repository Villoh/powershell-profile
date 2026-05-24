# 🎨 Pretty PowerShell

Pretty PowerShell is a standalone PowerShell customization script that delivers a polished shell experience: Starship prompt, PSReadLine enhancements, zoxide navigation, Terminal-Icons, fastfetch, and a rich set of Unix-style utilities and git shortcuts.

It now supports both Windows PowerShell 5.1 and PowerShell 7+.

> This repository is a fork of `ChrisTitusTech/powershell-profile`, refactored around a standalone-script architecture.

## Why this fork exists

Original layout mixed repo-managed profile logic with user-owned PowerShell profile files. This fork moves repo code into a standalone script and keeps the user's main `$PROFILE` as a thin loader.

### Current architecture

- `Profile.ps1` → canonical repo-managed script
- `Setup.ps1` → interactive installer and migration entrypoint
- `Microsoft.PowerShell_profile.ps1` → compatibility loader
- `$PROFILE` → user-owned startup file that dot-sources Pretty PowerShell

## Support

- Windows PowerShell 5.1
- PowerShell 7+
- Windows-first project

Install target is shell-specific because `$PROFILE` differs by host:

- Windows PowerShell → `~/Documents/WindowsPowerShell`
- PowerShell 7+ → `~/Documents/PowerShell`

## Install

Run installer from shell you want to configure.

```powershell
irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1 | iex
```

Installer is interactive. It guides you through:

1. Install location
2. Legacy profile migration (auto-detected)
3. Install and configure Starship (opt-in, recommended)
4. Install and configure Fastfetch (opt-in, recommended)
5. Terminal-Icons (installed automatically)
6. Extras: zoxide, JetBrainsMono Nerd Font (multi-select)

## Flags

### Preview install without changes

```powershell
& ([scriptblock]::Create((irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1))) -DryRun
```

### Force refresh without prompts

```powershell
& ([scriptblock]::Create((irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1))) -Force
```

Skips interactive prompts and applies all defaults. Useful for scripted re-installs.

## Backups

All overwritten files are backed up under current shell profile root:

- Windows PowerShell → `~/Documents/WindowsPowerShell/Backups/<yyyyMMdd-HHmmss>/`
- PowerShell 7+ → `~/Documents/PowerShell/Backups/<yyyyMMdd-HHmmss>/`

Each run creates its own dated subfolder. Includes:

- `PrettyPowerShell.ps1`
- `starship.toml`
- `fastfetch/` folder
- `Microsoft.PowerShell_profile.ps1` (migration only)
- `profile.ps1` (migration only)

## Update behavior

`Update-Profile` updates installed standalone script for current shell. Backs up existing script and Starship config before overwrite.

## Prompt

Uses Starship. Default config based on Catppuccin Powerline preset.

Customize at `~/.config/starship.toml`.

## Startup

On interactive shell:

1. Starship prompt initializes
2. Fastfetch runs with config at `~/.config/fastfetch/config.jsonc`
3. `Show-Help` hint prints

Windows PowerShell automatically uses ASCII-safe installer and help UI plus compatible PSReadLine settings.

## Feature flags

To disable Starship or Fastfetch after install, edit `PrettyPowerShell.ps1` (use `ep` or `Edit-Profile`) and set:

```powershell
$script:EnableStarship  = $false
$script:EnableFastfetch = $false
```

This is useful if you want to use a different prompt (e.g. Oh My Posh) or a different fetch tool.

## Recommended extras

- `JetBrainsMono Nerd Font`
- `zoxide`

Install manually if skipped during setup:

```powershell
winget install ajeetdsouza.zoxide DEVCOM.JetBrainsMonoNerdFont
```

## Project support

If this fork helps you:

- Star repo
- Share it
- Sponsor development:
  https://github.com/sponsors/Villoh
