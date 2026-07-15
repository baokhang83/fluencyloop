# Changelog

All notable changes to FluencyLoop are documented here.

## Unreleased

### Changed

- FluencyLoop is now distributed as both a Claude Code marketplace plugin and a Codex marketplace
  plugin. The canonical runtime lives in `plugins/fluencyloop/`.
- Retired `install.sh`, `install.ps1`, and `fluencyloop self upgrade`; agent plugin managers now
  own installation and updates.

## 0.2.0

### Added

- A cross-platform `fluencyloop` CLI: Bash for macOS, Linux, Git Bash, and WSL; PowerShell for
  native Windows.
- Feature branches, per-feature design and session scaffolding, plan scaffolding, a deterministic
  reviewer view, slice context, and post-merge backfill.
- `fluencyloop check` for inexpensive state and drift diagnosis.
- Per-developer calibration with deterministic teaching-depth levels and an engagement ledger:
  `fluencyloop calibration init|show|edit|signal|compact`.
- `fluencyloop version` and `fluencyloop self upgrade` for installed-copy maintenance.
- CI coverage for Bash, Git Bash on Windows, and the PowerShell port.

### Changed

- Human-facing FluencyLoop artifacts now live in `docs/fluencyloop/`; `.fluencyloop/` is reserved
  for tool state and deterministic plumbing.
- The constitution starts empty and grows from real plans and feature decisions instead of being a
  standalone, up-front approval stage.
- Skills and scripts split responsibility: skills teach and elicit rationale; scripts create and
  assemble deterministic state.
