# Changelog

All notable changes to this project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added dedicated `PrettyPowerShell/` install folder to avoid wildcard sourcing collisions with user-owned `Functions/` folder.
- Added fastfetch integration on shell startup using custom config at `~/.config/fastfetch/config.jsonc` when present.
- Added fastfetch folder backup (`config.jsonc` + `ascii.txt`) into dated `Backups/<timestamp>/fastfetch/` subfolder.
- Added `fastfetch-cli.fastfetch` to `-InstallDependencies` winget install list.
- Added `Backup-Directory` helper for recursive folder backups.

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
