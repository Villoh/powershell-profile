# Changelog

All notable changes to this project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added `Profile.ps1` as canonical standalone Pretty PowerShell script.
- Added compatibility loader behavior to `Microsoft.PowerShell_profile.ps1`.
- Added installer support for `-InstallMode`, `-InstallDependencies`, `-MigrateLegacyProfile`, `-DryRun`, and `-Force`.
- Added loader-based migration from legacy split-profile installs.
- Added timestamped backup generation during migration and install refresh.
- Added dry-run preview mode for install and migration actions.
- Added documentation for standalone install, migration, and dry-run workflows.
- Added `.pi/` and `openspec/` to `.gitignore`.

### Changed

- Changed project architecture from repo-managed main `$PROFILE` replacement to standalone script installation.
- Changed installer to place repo-managed logic in `PrettyPowerShell.ps1` and wire it into `$PROFILE` via dot-sourcing.
- Changed repository script filenames to PascalCase for consistency (`Profile.ps1`, `Setup.ps1`).
- Changed `Update-Profile` to update standalone installed script and adjacent theme file instead of replacing the user's main profile.
- Changed repository references from `ChrisTitusTech` to `Villoh` in install and update URLs.
- Changed README to document current standalone-first architecture and migration flow.

### Deprecated

- Deprecated legacy split-profile layout where repo logic lived in `Microsoft.PowerShell_profile.ps1` and user customizations lived in sidecar `profile.ps1`.

### Removed

- Removed default behavior of overwriting the user's main `$PROFILE` with repo-managed profile content.

### Fixed

- Fixed long-term maintainability issue caused by mixing repo-managed profile logic with user-owned PowerShell profile content.
- Fixed migration path for users coming from old profile layout by preserving custom `profile.ps1` content during migration.
