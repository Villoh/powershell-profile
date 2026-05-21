# 🎨 Pretty PowerShell

Pretty PowerShell is a standalone PowerShell customization script focused on safer installation, easier updates, clearer ownership boundaries, and a Starship-based prompt.

> This repository is a fork of `ChrisTitusTech/powershell-profile`, refactored around a standalone-script architecture.

## Why this fork exists

Original layout mixed repo-managed profile logic with user-owned PowerShell profile files. This fork moves repo code into a standalone script and keeps the user's main `$PROFILE` as a thin loader.

### Current architecture

- `Profile.ps1` → canonical repo-managed script
- `Setup.ps1` → interactive installer and migration entrypoint
- `Microsoft.PowerShell_profile.ps1` → compatibility loader
- `$PROFILE` → user-owned startup file that dot-sources Pretty PowerShell

## Install

```powershell
irm https://github.com/Villoh/powershell-profile/raw/main/Setup.ps1 | iex
```

Installer is interactive. It guides you through:

1. Install location
2. Legacy profile migration (auto-detected)
3. Starship config bootstrap (opt-in)
4. Fastfetch config bootstrap (opt-in)
5. Dependency installation (opt-in)

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

All overwritten files are backed up to:

```
~/Documents/PowerShell/Backups/<yyyyMMdd-HHmmss>/
```

Each run creates its own dated subfolder. Includes:

- `PrettyPowerShell.ps1`
- `starship.toml`
- `fastfetch/` folder
- `Microsoft.PowerShell_profile.ps1` (migration only)
- `profile.ps1` (migration only)

## Update behavior

`Update-Profile` updates installed standalone script. Backs up existing script and Starship config before overwrite.

## Prompt

Uses Starship. Default config based on Catppuccin Powerline preset.

Customize at `~/.config/starship.toml`.

## Startup

On interactive shell:

1. Starship prompt initializes
2. Fastfetch runs with config at `~/.config/fastfetch/config.jsonc`
3. `Show-Help` hint prints

## Recommended extras

- `JetBrainsMono Nerd Font`
- `Starship`
- `fastfetch`
- `zoxide`
- `Terminal-Icons`

Install all via installer dependency option or manually:

```powershell
winget install Starship.Starship fastfetch-cli.fastfetch ajeetdsouza.zoxide DEVCOM.JetBrainsMonoNerdFont
```

## Support

If this fork helps you:

- Star repo
- Share it
- Sponsor development:
  https://github.com/sponsors/Villoh
