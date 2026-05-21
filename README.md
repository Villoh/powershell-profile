# 🎨 Pretty PowerShell

Clean, modern PowerShell setup. Now treated as **standalone script**, not replacement for user's main `$PROFILE`.

## Core direction

Repo now fits better as:

- standalone script in `~/Documents/PowerShell/Functions`
- or standalone script in `~/Documents/PowerShell`
- auto-linked from your PowerShell profile by installer

Installer adds dot-source loader to your existing `$PROFILE` so script loads on shell startup.

## Quick install

Install standalone script to `~/Documents/PowerShell/Functions/PrettyPowerShell.ps1`:

```powershell
irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1 | iex
```

Installer also appends loader to `$PROFILE`, so no manual dot-sourcing needed.

## Advanced install options

Migrate old split-profile install into new layout:

```powershell
$script = irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1
& ([scriptblock]::Create($script)) -MigrateLegacyProfile
```

This will:

- back up current `$PROFILE` with timestamped `.bak` files
- detect old repo-managed main profile
- replace it with loader-based profile
- merge old user-managed `profile.ps1` content into new `$PROFILE`

Install into PowerShell root instead of `Functions`:

```powershell
$script = irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1
& ([scriptblock]::Create($script)) -InstallMode PowerShellRoot
```

Install dependencies too:

```powershell
$script = irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1
& ([scriptblock]::Create($script)) -InstallDependencies
```

Force refresh existing standalone install:

```powershell
$script = irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1
& ([scriptblock]::Create($script)) -Force
```

Use `-Force` with `-MigrateLegacyProfile` to migrate even if legacy profile detection is inconclusive.

Preview installer actions without changing files:

```powershell
$script = irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1
& ([scriptblock]::Create($script)) -DryRun
```

Preview migration plan without changing files:

```powershell
$script = irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1
& ([scriptblock]::Create($script)) -MigrateLegacyProfile -DryRun
```

## Files

- `Profile.ps1` → canonical standalone script
- `Microsoft.PowerShell_profile.ps1` → compatibility loader
- `Setup.ps1` → installer for standalone layout

## Update behavior

`Update-Profile` updates installed standalone script and adjacent theme file. Installer wires script into `$PROFILE` automatically, and `-MigrateLegacyProfile` can convert old split-profile installs into loader-based layout.

Migration backups use timestamped filenames like `Microsoft.PowerShell_profile.ps1.20260521-143000.bak`.

## After install

If you use prompt/theme extras, recommended:

- `JetBrainsMono Nerd Font`
- `oh-my-posh`
- `zoxide`
- `Terminal-Icons`

## ⭐ Support Project

If project helps you:

- Star repo
- Share it
- Sponsor development:
  https://github.com/sponsors/Villoh
