# Changelog

All notable changes to FluencyLoop are documented here.

## 0.3.2

### Fixed

- Embedded diagrams now default to unlabelled arrows for compact architecture views, preventing
  connector text from being hidden by cards. Labels remain mandatory for flowchart decision exits
  and sequence-diagram messages.
- The embedded-diagram path now preserves the shared routing rules: non-aligned connectors use
  rounded orthogonal routes, connector paths and attachment points remain distinct, and the local
  reader must be visually checked for occluded text or clipping before handoff.

## 0.3.1

### Fixed

- Architectural records may now use a `realized_by` relation to name an ordinary code area such
  as `AppComponent`; those targets no longer need duplicate knowledge-component records. Other
  relation types retain dangling-endpoint validation in both runtimes.
- Embedded product-overview and record diagrams now use a compact, deterministic diagram path.
  It creates self-contained HTML only, so remote Google Fonts and other network resources cannot
  be rejected by the local reader. When a manually authored companion is unsafe, the site explains
  the requirement instead of leaving a broken iframe.

## 0.3.0

### Added

- FluencyLoop now records feature, session, decision, knowledge, architectural-record, and
  requirement data in an append-only JSONL store. The bundled local reader turns those records
  into a tag-filterable project overview, architectural-record catalog, feature deltas, and
  decision detail pages.
- `fluencyloop site --ensure` manages a loopback-only local reader. Node.js 18+ is required only
  for that reader; the core workflow remains usable without Node. Agent sessions start the reader
  when available and announce its actual local URL.
- The first 0.3 command in a 0.2 project imports legacy session history automatically. It writes
  new store records only, leaves all existing Markdown untouched, and defaults reconstructed
  evidence to unverified.

### Fixed

- Plugin manifests now identify the 0.3 runtime. Claude Code can refresh its installed cache when
  the development branch advances instead of retaining the old 0.2.27 package.
- Legacy semantic migration revision 5 reopens earlier untagged migrations. It reports tag
  coverage, requires at least one tagged architectural record before completion, and shows existing
  records so the agent can append tagged corrections without rewriting history.
- Session numbering now derives from the feature store rather than the mutable state pointer, so a
  reset state file or imported legacy session cannot make a later session restart at `001`.

## 0.2.27

### Fixed

- The `schema_version` marker added in 0.2.26 was only stamped by the bash runtime. On Windows,
  `FlWriteState` wrote state files without it, so Windows installs would have stayed unmarked no
  matter how long 0.2.26 propagated — defeating the point of shipping the marker early. `common.ps1`
  now mirrors `common.sh`: `FlSchemaVersion` holds the generation, `FlWriteState` prepends it, and
  `FlStateSchemaVersion` reads a field-less file as generation 1.

## 0.2.26

### Added

- `.fluencyloop/state.json` now carries a `schema_version` field, stamped by `write_state` itself
  so no write path can omit it. Nothing branches on it yet — it exists so that a later version can
  tell an old project from a new one directly, instead of inferring the generation from which files
  happen to be present. A state file written before this shipped has no field and reads as
  generation 1 via the new `state_schema_version` helper, so no existing project is rewritten or
  invalidated. Shipped ahead of any change that needs it, because the marker is only useful once it
  has propagated to installs that predate it.
- `.github/scripts/bump-version.sh` makes `plugins/fluencyloop/VERSION` the single source of truth
  for the plugin version and generates the three JSON manifests from it, replacing four hand-edited
  copies. CI now fails on drift: a mismatch between them breaks the `SessionStart` update hook,
  which resolves the plugin by its marketplace-qualified name, and that failure is silent for
  everyone already installed.

## 0.2.25

### Fixed

- The `SessionStart` hook that refreshes the marketplace and updates the installed plugin
  never actually registered under Claude Code. The marketplace entry declares `"source": "."`
  (repo root), so `CLAUDE_PLUGIN_ROOT` resolves to the repo root and Claude Code only ever looks
  for `hooks/hooks.json` there — but that file only ever existed under `plugins/fluencyloop/hooks/`,
  the Codex bundle's own plugin root. The hook was silently never discovered (not a runtime
  failure — the wrapper's `|| exit 0` fallbacks made this indistinguishable from a network/policy
  no-op), so installed Claude Code plugins stopped picking up updates entirely after the initial
  install. Added a root-level `hooks/hooks.json`, `hooks/refresh-marketplace.sh`, and
  `hooks/refresh-marketplace.ps1` that delegate to the existing Codex-bundle implementation, so
  there is one source of truth for the refresh logic and Claude Code can find it where it looks.

## 0.2.24

### Fixed

- `fluencyloop feature`'s idempotency check — re-running the same intent on the current
  feature branch to avoid minting a new numbered dir — assumed the existing slug always had a
  `<prefix>-` segment to strip. On a feature declared before per-feature numbering shipped
  (0.2.22), stripping `^[a-z0-9]+-` from its bare slug mangled the first word instead of a real
  prefix, so the comparison never matched: a bare re-run forked a brand-new numbered
  branch/dir off the legacy one instead of reusing it. The check now also matches the
  un-stripped slug, so legacy features stay on their original branch and dir.

## 0.2.23

### Fixed

- On native Windows, `fluencyloop feature`, `fluencyloop plan`, and `fluencyloop rename-feature-dir`
  no longer leak an extra `Index: ...` line into their own output (breaking `--json` parsing for
  anything consuming it, including the feature/plan skills themselves). PowerShell's `FlOut` writes
  directly to the console, which bypasses stream redirection when a script calls another script
  in-process; the index refresh after each mutation is now spawned as a genuine child process so
  redirection actually applies, matching how the Bash port already behaved.

## 0.2.22

### Added

- `docs/fluencyloop/` now gets a generated `README.md` index (`fluencyloop index`) listing every
  plan and feature with its status (in progress / shipped), linking features back to the plan that
  spawned them.
- Feature dirs now carry a numeric prefix (`docs/fluencyloop/features/<prefix>-<slug>`) instead of
  a flat, unordered pile of bare slugs — a ticket id (`--prefix`), a PR number (assigned after the
  fact once one exists, via the new `fluencyloop rename-feature-dir --pr <n>`), or a zero-padded
  sequential counter, in that order of preference. The `feature` skill now asks once, per developer,
  which mode to use and remembers the choice in `~/.fluencyloop/preferences.md`.
- Sessions within a feature are similarly numbered so `sessions/` sorts in build order.
- `design.md` now records its own `branch:` (and, when declared from a plan, `plan:`) line, so a
  feature's docs dir can be renamed independently of its branch name.

## 0.2.21

### Fixed

- The backfill skills for Claude Code and Codex now apply the same GitHub Mermaid label check as
  plan and feature: a bare semicolon in a sequence arrow label or `Note` is rewritten before the
  generated `design.md` is committed.

## 0.2.20

### Fixed

- The `plan`, `feature`, and `backfill` skills (Claude Code and Codex) no longer tell the agent to
  hand-author diagrams as inline SVG to work around a CDN block that no longer applies. Artifacts
  render Mermaid natively, but only inside `<pre class="mermaid">` — a ` ```mermaid ` fence or a
  plain `<pre><code>` block is left as literal text. The skills now say so directly, instead of
  steering toward the SVG workaround that was itself producing plain-text diagrams.

## 0.2.19

### Fixed

- The `plan` and `feature` skills (Claude Code and Codex) now warn against bare semicolons in
  Mermaid `Note`/label text before committing `design.md` or `plan.md`. GitHub's Mermaid parser
  treats `;` as a statement terminator even inside note text, so a diagram that renders fine
  locally could still fail to render on github.com with a `Parse error ... got 'INVALID'`.

## 0.2.18

### Fixed

- Claude Code and Codex now verify whether teaching landed exclusively through developer
  self-report: they ask whether the explanation is understood or needs clarification and trust the
  answer. The skills explicitly prohibit quiz-style checks such as restating a mechanism,
  explaining it in the developer's own words, predicting behavior, selecting an answer, or
  responding to another topic-specific question.

## 0.2.17

### Fixed

- Codex no longer reports a `SessionStart` error when an update prunes the versioned plugin root
  before its hook launches. The launcher either recovers through the newly installed sibling
  version or safely no-ops when no replacement exists; Windows also guards the hook path.
- The managed `fluencyloop` PATH shim now falls through to the replacement runtime in the same
  trusted plugin cache when its original version is removed during startup.

## 0.2.16

### Added

- Claude Code installations now refresh themselves at startup, as Codex installations already did.
  The `SessionStart` hook dispatches on the plugin-root variable the host exports, so a Claude
  session refreshes the Claude package through `claude plugin` and a Codex session refreshes the
  Codex package through `codex plugin`. Neither host can refresh the other's tree, and the managed
  PATH shim stays Codex-only because the Claude skills address the bundled CLI through
  `CLAUDE_PLUGIN_ROOT`.

### Fixed

- A Claude Code install could sit indefinitely on the version it was first installed at, silently
  running skills from a stale package, because no hook ever refreshed it.

## 0.2.15

### Fixed

- Claude Code and Codex feature skills now distinguish calibration levels from engagement signals.
  A probe answer such as `learning` or `new` sets teaching depth; it cannot be passed to
  `fluencyloop calibration signal`. The CLI now explains that error directly.
- Claude Code treats "not comfortable" answers as `new`, gives the substantive explanation, and
  waits for an `AskUserQuestion` response before journaling, calibrating, or continuing.
- Added a project-scoped Claude Code permissions guide for native Windows that reduces routine
  FluencyLoop, editing, and read-only Git prompts without granting broad Git or Bash access.

## 0.2.14

### Fixed

- Codex no longer substitutes ASCII diagrams when an Artifact is unavailable. It points to the
  generated Markdown file and recommends opening it in an IDE Markdown preview, such as VS Code.
- Codex probes now frame explanation neutrally. `learning` and `new` answers require a substantive
  explanation and a standalone comprehension question before the workflow can continue. Claude
  Code workflows are unchanged.

## 0.2.13

### Fixed

- Codex stage skills now request elevation for their own initialization, including backfill's
  skipped-loop setup path. Feature design has a visible teaching gate before implementation, and
  planning and feature gates distinguish a learning pause from a build or merge block.
- Codex review now honors the settled `feature-handoff: automatic` preference instead of asking
  again before opening the PR, and uses the feature's recorded base when it creates that PR.
  Claude Code workflows are unchanged.

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
