# Changelog

All notable changes to FluencyLoop are documented here.

## 0.2.12

### Fixed

- Codex planning now requires a visible architecture teaching turn before task decomposition,
  roadmap, constitution, or ticket work. Unknown, `learning`, and `new` domains pause for the
  developer's response. Claude Code's planning workflow is unchanged.

## 0.2.11

### Fixed

- Codex feature runs now require a user-visible teaching turn before decisions are journaled.
  Unknown, `learning`, and `new` domains pause for the developer's response; calibration signals
  require actual engagement. Claude Code's workflow is unchanged.

## 0.2.10

### Fixed

- For literal `fluencyloop init` requests, the Codex router now requests sandbox elevation before
  its first execution. This avoids a denied first attempt when the initializer creates protected
  Git metadata. Claude Code's workflow is unchanged.

## 0.2.9

### Fixed

- Codex stage skills now use the plugin-qualified names `$fluencyloop:plan`,
  `$fluencyloop:feature`, `$fluencyloop:review`, and `$fluencyloop:backfill`, without repeating
  the plugin name in the picker. Claude Code commands remain `/fluencyloop:<stage>`.
- Codex skills now invoke the bundled dispatcher without exposing its internal path variable, and
  `fluencyloop init` preserves Git's original error when repository initialisation fails.
- Literal Codex CLI requests now run without preflight narration, inspection, or an automatic
  transition into a FluencyLoop stage.
- Codex now maintains a managed `fluencyloop` PATH shim on macOS, Linux, Git Bash, and WSL, so
  its command transcript shows the stable command name instead of a versioned plugin-cache path.

## 0.2.6

### Fixed

- `fluencyloop slice-context` now handles an unborn Git branch without attempting to diff an
  invalid `HEAD`; it returns the staged and untracked first-project files as the initial slice.
- When a live design Artifact cannot be rendered, feature, plan, and backfill workflows now show
  an ASCII sketch in chat before pointing to the committed Mermaid document.

## 0.2.5

### Fixed

- Codex startup refresh hooks now use only Codex's `PLUGIN_ROOT` and no-op safely when it is
  absent, preventing a session-start failure with exit code 127. The Windows hook follows the
  same guard.
- Plugin package tests now read repository text as UTF-8, keeping them reliable on Windows
  code-page defaults.

## 0.2.4

### Fixed

- Claude Code skills now invoke the plugin's bundled launcher explicitly, validate the paths it
  returns, and refuse to hand-scaffold legacy `.fluencyloop` session files.
- Codex's startup hook now recognises both supported installed-plugin root layouts, so its
  marketplace refresh reaches the current snapshot layout.
- The Claude and Codex plan/feature stages now initialise Git automatically in a project directory
  that does not already have a repository, without prompting the developer.
- Claude installation guidance now distinguishes slash commands from Bash-tool commands and
  documents third-party marketplace update behaviour accurately.

## 0.2.3

### Fixed

- `fluencyloop check` (and every command that first calls `require_fluency`, e.g. `feature`,
  `plan`, `session`, `decision`) used to abort silently with exit code 1 and no message when run
  outside a git repository — a `set -e` interaction with three bash helpers (`fluency_dir`,
  `docs_dir`, `state_path`) that returned a non-zero status instead of an empty string when there
  was no repo root. They now return empty cleanly, and `fluencyloop check` reports "not a git
  repository" explicitly (also surfaced as `"git_repo"` in `--json`) instead of failing before it
  can print anything.

## 0.2.2

### Added

- Codex now checks FluencyLoop's supplying marketplace at every session startup through a trusted,
  plugin-bundled hook, and installs an available update for the following session.

### Changed

- Documented the host-native automatic update behaviour for both Claude Code and Codex.

## 0.2.1

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
