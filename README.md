# 🎨 Pretty PowerShell

Pretty PowerShell is a standalone PowerShell customization script focused on safer installation, easier updates, and clearer ownership boundaries.

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

```powershell
irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1 | iex
```

## Migration from old split-profile installs

If you used older layout with repo logic in `Microsoft.PowerShell_profile.ps1` and customizations in `profile.ps1`, use migration mode:

```powershell
& ([scriptblock]::Create((irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1))) -MigrateLegacyProfile
```

Migration will:

- back up current `$PROFILE` with timestamped `.bak` files
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

### Force refresh existing install

```powershell
& ([scriptblock]::Create((irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1))) -Force
```

Use `-Force` with `-MigrateLegacyProfile` if legacy detection is inconclusive.

### Preview install without changes

```powershell
& ([scriptblock]::Create((irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1))) -DryRun
```

### Preview migration without changes

```powershell
& ([scriptblock]::Create((irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1))) -MigrateLegacyProfile -DryRun
```

## Update behavior

`Update-Profile` updates installed standalone script and adjacent theme file.

Migration backups use timestamped filenames like:

- `Microsoft.PowerShell_profile.ps1.20260521-143000.bak`

## Recommended extras

- `JetBrainsMono Nerd Font`
- `oh-my-posh`
- `zoxide`
- `Terminal-Icons`

## Support

If this fork helps you:

- Star repo
- Share it
- Sponsor development:
  https://github.com/sponsors/Villoh
