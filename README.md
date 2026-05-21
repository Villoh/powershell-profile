# 🎨 Pretty PowerShell

Pretty PowerShell is a standalone PowerShell customization script focused on safer installation, easier updates, clearer ownership boundaries, and a Starship-based prompt.

> This repository is a fork of `ChrisTitusTech/powershell-profile`, refactored around a standalone-script architecture.

## Why this fork exists

Original layout mixed repo-managed profile logic with user-owned PowerShell profile files. This fork moves repo code into a standalone script and keeps the user's main `$PROFILE` as a thin loader.

### Current architecture

- `Profile.ps1` → canonical repo-managed script
- `Setup.ps1` → installer and migration entrypoint
- `Microsoft.PowerShell_profile.ps1` → compatibility loader
- `$PROFILE` → user-owned startup file that dot-sources Pretty PowerShell

## Install

Default install downloads Pretty PowerShell to:

- `~/Documents/PowerShell/Functions/PrettyPowerShell.ps1`

and appends a loader to your main `$PROFILE`.

Prompt setup uses Starship. If `~/.config/starship.toml` does not exist yet, installer bootstraps it with Starship's recommended Catppuccin Powerline preset.

```powershell
irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1 | iex
```

## Migration from old split-profile installs

If you used older layout with repo logic in `Microsoft.PowerShell_profile.ps1` and customizations in `profile.ps1`, use migration mode:

```powershell
& ([scriptblock]::Create((irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1))) -MigrateLegacyProfile
```

Migration will:

- back up current `$PROFILE` into `~/Documents/PowerShell/Backups/` with timestamped `.bak` files
- detect old repo-managed main profile
- rewrite `$PROFILE` as loader-based profile
- merge old user-managed `profile.ps1` contents into new `$PROFILE`

## Installer options

### Install into PowerShell root

```powershell
& ([scriptblock]::Create((irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1))) -InstallMode PowerShellRoot
```

### Install dependencies

```powershell
& ([scriptblock]::Create((irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1))) -InstallDependencies
```

This installs:

- `Starship`
- `zoxide`
- `JetBrainsMono Nerd Font`
- `Terminal-Icons`

### Force refresh existing install

```powershell
& ([scriptblock]::Create((irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1))) -Force
```

Existing installed script and Starship config are backed up before refresh when present. Use `-Force` with `-MigrateLegacyProfile` if legacy detection is inconclusive.

### Preview install without changes

```powershell
& ([scriptblock]::Create((irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1))) -DryRun
```

### Preview migration without changes

```powershell
& ([scriptblock]::Create((irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1))) -MigrateLegacyProfile -DryRun
```

## Update behavior

`Update-Profile` updates installed standalone script.

Before overwrite, `Update-Profile`, reinstall, refresh, and `-Force` runs back up existing installed files into `~/Documents/PowerShell/Backups/`.

When present, Starship config is backed up there too.

Migration backups are stored in:

- `~/Documents/PowerShell/Backups/`

with timestamped filenames like:

- `Backups/Microsoft.PowerShell_profile.ps1.20260521-143000.bak`

## Prompt styling

Pretty PowerShell now uses Starship instead of Oh My Posh.

Recommended baseline:

- install Starship
- use preset command from Starship docs:
  - `starship preset catppuccin-powerline -o ~/.config/starship.toml`
- customize `C:\Users\mikel\.config\starship.toml` to taste

## Recommended extras

- `JetBrainsMono Nerd Font`
- `zoxide`
- `Terminal-Icons`

## Support

If this fork helps you:

- Star repo
- Share it
- Sponsor development:
  https://github.com/sponsors/Villoh
