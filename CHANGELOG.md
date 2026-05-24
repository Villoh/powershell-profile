# Changelog

All notable changes to this project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.3] - 2026-05-24

### Added

- Added `windowsterminal/settings.json` to repo as recommended Windows Terminal config.
- Added `Set-WindowsTerminalFont` to surgically patch `defaults.font.face` in the existing Windows Terminal `settings.json` (always runs during install).
- Added `Copy-WindowsTerminalConfig` to replace Windows Terminal config with the repo config (opt-in).
- Added **"Use my Windows Terminal config?"** prompt to installer.
- Windows Terminal `settings.json` is now backed up on every install run.

[1.1.3]: https://github.com/Villoh/powershell-profile/compare/v1.1.2...v1.1.3

## [1.1.2] - 2026-05-24

### Fixed

- Fixed fastfetch `config.jsonc` and `ascii.txt` being written with UTF-8 BOM, which fastfetch does not support.

[1.1.2]: https://github.com/Villoh/powershell-profile/compare/v1.1.1...v1.1.2

## [1.1.1] - 2026-05-24

### Fixed

- Fixed `MethodInvocationException` in `Ensure-ProfileLoader` when `$PROFILE` exists but is empty — `Get-Content -Raw` returns `$null` on empty files, not an empty string.

[1.1.1]: https://github.com/Villoh/powershell-profile/compare/v1.1.0...v1.1.1

## [1.1.0] - 2026-05-24

### Added

- Added `$script:EnableStarship` and `$script:EnableFastfetch` feature flags in `Profile.ps1` to allow disabling Starship or Fastfetch without reinstalling.
- Added `Invoke-InteractiveMultiSelect` to `Setup.ps1` for multi-select extras picker (zoxide, JetBrainsMono Nerd Font).

### Changed

- Split `Install-Dependencies` into focused functions: `Install-TerminalIcons`, `Install-Starship`, `Install-Fastfetch`, and `Install-Extras`.
- Terminal-Icons is now installed unconditionally as a mandatory dependency.
- Installer questions for Starship and Fastfetch now cover both install and config bootstrap in a single step ("Install and configure Starship?", "Install and configure Fastfetch?").
- Extras (zoxide, JetBrainsMono) moved to a dedicated multi-select prompt, both pre-selected by default.
- All installer prompts now default to Yes.

[1.1.0]: https://github.com/Villoh/powershell-profile/compare/v1.0.3...v1.1.0

## [1.0.3] - 2026-05-21

### Added

- Restored utility commands from upstream profile: `Edit-Profile`, `ep`, `Invoke-Profile`, `pubip`, `admin`, `su`, `df`, `export`, `tail`, `nf`, `dtop`, `gc`, `sysinfo`, `flushdns`, `cpy`, and `pst`.
- Added shell-aware setup details showing detected OS, PowerShell edition/version, and actual profile root before install choices.

### Changed

- Improved installer prompts with arrow-key menu navigation for choice and yes/no flows.
- Adjusted installer menu rendering to keep cursor out of prompt area during interactive selection.
- Preferred local repo assets when running `Setup.ps1` from a checkout, while keeping remote asset downloads for `irm ... | iex` installs.
- Tightened legacy migration detection to repo-specific Chris Titus Tech markers.

### Fixed

- Fixed PSReadLine initialization so Windows PowerShell avoids unsupported `PredictionViewStyle` while PowerShell 7 keeps list predictions.
- Fixed installer UI rendering on Windows PowerShell by using ASCII-safe separators and selection markers.
- Fixed `Show-Help` rendering on Windows PowerShell by using ASCII-safe titles, separators, and arrows.
- Fixed local asset installation on Windows PowerShell by reading repo files as UTF-8 and writing installed files as UTF-8 with BOM.
- Fixed duplicate Pretty PowerShell loader blocks by normalizing repeated loader entries down to a single canonical block.

[1.0.3]: https://github.com/Villoh/powershell-profile/compare/v1.0.2...v1.0.3

## [1.0.2] - 2026-05-21

### Changed

- Replaced all installer flags (`-InstallMode`, `-InstallDependencies`, `-MigrateLegacyProfile`) with interactive guided setup flow.
- Installer now prompts for install location, legacy migration, Starship bootstrap, Fastfetch bootstrap, and dependency install.
- `-DryRun` and `-Force` remain as non-interactive overrides.
- `$HOME` replaced with `$env:USERPROFILE` in `Setup.ps1` and `Profile.ps1` to fix path casing on Windows.
- Fixed Fastfetch config detection using correct `$env:USERPROFILE` path.
- Added manual version input to release workflow `workflow_dispatch`.
- Updated README to reflect interactive installer.

[1.0.2]: https://github.com/Villoh/powershell-profile/compare/v1.0.1...v1.0.2

## [1.0.1] - 2026-05-21

### Added

- Added dedicated `PrettyPowerShell/` install folder to avoid wildcard sourcing collisions with user-owned `Functions/` folder.
- Added fastfetch integration on shell startup using custom config at `~/.config/fastfetch/config.jsonc` when present.
- Added fastfetch folder backup (`config.jsonc` + `ascii.txt`) into dated `Backups/<timestamp>/fastfetch/` subfolder.
- Added `fastfetch-cli.fastfetch` to `-InstallDependencies` winget install list.
- Added `Backup-Directory` helper for recursive folder backups.
- Added `fastfetch/config.jsonc` and `fastfetch/ascii.txt` to repo as default fastfetch config bootstrapped when user has no existing config.
- Added `Ensure-FastfetchConfig` to installer mirroring `Ensure-StarshipConfig` behavior — installs default config if missing, skips if already present.
- Added collapsible commit history and contributors sections to GitHub release body, generated dynamically since last tag.

### Changed

- Replaced Oh My Posh with Starship for prompt initialization.
- Moved backup storage from alongside source files to `~/Documents/PowerShell/Backups/` with timestamped filenames.
- Changed backup layout from flat timestamped filenames to dated subfolders `Backups/<yyyyMMdd-HHmmss>/<Files>` so all files from the same run are grouped together.
- Changed default install location from `Functions/` to dedicated `PrettyPowerShell/` subfolder.
- Removed cobalt2.omp.json theme download and all Oh My Posh theme references.
- Added pre-update backup in `Update-Profile` and all refresh/force runs for rollback safety.
- Unified install and migration output into grouped sectioned summary format matching dry-run output.

### Fixed

- Fixed dry-run output to correctly show hypothetical wording for all actions.

[1.0.1]: https://github.com/Villoh/powershell-profile/compare/v1.0.0...v1.0.1

## [1.0.0] - 2026-05-21

### Added

- Added `Profile.ps1` as canonical standalone Pretty PowerShell script.
- Added compatibility loader behavior to `Microsoft.PowerShell_profile.ps1`.
- Added installer support for `-InstallMode`, `-InstallDependencies`, `-MigrateLegacyProfile`, `-DryRun`, and `-Force`.
- Added loader-based migration from legacy split-profile installs.
- Added timestamped backup generation during migration and install refresh.
- Added dry-run preview mode for install and migration actions.
- Added documentation for standalone install, migration, and dry-run workflows.
- Added `.pi/` and `openspec/` to `.gitignore`.
- Added backup folder `~/Documents/PowerShell/Backups/` with timestamped `.bak` files for all overwritten files.
- Added pre-update backup in `Update-Profile` for rollback safety.
- Added `-MigrateLegacyProfile` with legacy detection, main profile rewrite, and user sidecar merge.
- Added Starship prompt support replacing Oh My Posh.
- Added Starship config bootstrap with Catppuccin Powerline preset when no config exists.
- Added fork attribution and copyright in `LICENSE` and `README.md`.
- Added `CHANGELOG.md` following Keep a Changelog format.
- Added GitHub Actions release workflow triggered on push to main and manual dispatch.

### Changed

- Changed project architecture from repo-managed main `$PROFILE` replacement to standalone script installation.
- Changed installer to place repo-managed logic in `PrettyPowerShell.ps1` and wire it into `$PROFILE` via dot-sourcing.
- Changed repository script filenames to PascalCase for consistency (`Profile.ps1`, `Setup.ps1`).
- Changed `Update-Profile` to update standalone installed script instead of replacing the user's main profile.
- Changed repository references from `ChrisTitusTech` to `Villoh` in install and update URLs.
- Changed README to document current standalone-first architecture and migration flow.
- Changed dependency installer from Oh My Posh to Starship.
- Changed backup storage from alongside source files to dedicated `Backups/` folder.
- Changed dry-run output from flat action stream to grouped sectioned summary.

### Deprecated

- Deprecated legacy split-profile layout where repo logic lived in `Microsoft.PowerShell_profile.ps1` and user customizations lived in sidecar `profile.ps1`.

### Removed

- Removed default behavior of overwriting the user's main `$PROFILE` with repo-managed profile content.
- Removed Oh My Posh theme download and initialization.

### Fixed

- Fixed long-term maintainability issue caused by mixing repo-managed profile logic with user-owned PowerShell profile content.
- Fixed migration path for users coming from old profile layout by preserving custom `profile.ps1` content during migration.

[1.0.0]: https://github.com/Villoh/powershell-profile/releases/tag/v1.0.0
