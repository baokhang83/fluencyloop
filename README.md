<p align="center">
  <img src="https://github.com/user-attachments/assets/e3a04a63-4b68-4f61-ad58-60df8cc67045" alt="FluencyLoop Banner" width="1774" style="max-width: 100%; height: auto;">
</p>

# FluencyLoop

[![CI](https://github.com/baokhang83/fluencyloop/actions/workflows/ci.yml/badge.svg)](https://github.com/baokhang83/fluencyloop/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/baokhang83/fluencyloop)](LICENSE)
[![Top language](https://img.shields.io/github/languages/top/baokhang83/fluencyloop)](https://github.com/baokhang83/fluencyloop)
[![Status: alpha](https://img.shields.io/badge/status-alpha-orange)](CONTRIBUTING.md#distribution-roadmap)

**Stay fluent in the code your AI agent writes.** FluencyLoop turns each feature into a documented
design, teaches the decisions at your level, tracks the rationale, and produces a reviewer-ready
summary. A private knowledge base keeps that teaching calibrated across features.

> The code and your fluency in it are produced together, or not at all.

## The workflow

Initialize the project once, then run one feature loop per branch. Use **plan** only when the work
is too large for a single feature.

| Step | Claude Code | Codex | What it does |
|------|-------------|-------|--------------|
| **1. Initialize** | `fluencyloop init` | `fluencyloop init` | Creates the project state and an empty constitution. Plan and feature also do this automatically if needed. |
| **2. Plan (optional)** | `/fluencyloop:plan <initiative>` | `$fluencyloop:plan <initiative>` | Designs the architecture and breaks a large initiative into feature-sized tasks. |
| **3. Build + learn** | `/fluencyloop:feature <feature>` | `$fluencyloop:feature <feature>` | Creates a feature branch and design, builds in slices, teaches each real decision, and journals it. |
| **4. Review** | `/fluencyloop:review` | `$fluencyloop:review` | Assembles the branch's sessions and decisions into a reviewer-facing PR view. |

For normal-sized work, the practical path is **init → feature → review**. For a large initiative,
run **plan** first, then repeat **feature → review** for each task in its roadmap.

If work was merged without the loop, use `/fluencyloop:backfill` in Claude Code or
`$fluencyloop:backfill` in Codex to reconstruct and verify its design and decisions.

## What it gives you

### A living constitution

The constitution is a short set of checkable engineering principles for the project. It starts
from the first real plan or feature and grows when a decision reveals a repeatable stance. Every
later design and review is checked against it, but it never blocks a conventional merge.

### Knowledge transfer, taught to your level

FluencyLoop teaches at the moment a meaningful decision is made. It explains the mechanism, the
reason for the chosen path, and the rejected alternative, then checks that the explanation landed
before continuing when the topic is unfamiliar.

It maintains a private, per-developer knowledge base of domain familiarity and demonstrated
engagement. That profile carries across projects and features, keeping explanations concise on
familiar ground and deeper where knowledge is still forming. It is never committed to a project;
only person-neutral knowledge-transfer notes about the software enter the documentation.

### Software documentation that follows the code

Plans, Mermaid design diagrams, feature sessions, and review summaries live beside the code under
`docs/fluencyloop/`. They are created from the actual branch and its changes, so documentation is
produced during delivery rather than reconstructed after context has been lost.

### Decision tracking with rationale

Each real fork records what was chosen, where it applies, why it was chosen, which alternative was
rejected, how it relates to the constitution and design, and whether the rationale was verified.
Reviewers get the decisions that shaped the feature instead of only a list of changed files.

## What gets committed

```text
docs/fluencyloop/
├── constitution.md
├── plans/<initiative>/plan.md
└── features/<feature>/
    ├── design.md
    └── sessions/*.md
```

`.fluencyloop/` contains project workflow state. The per-developer calibration profile lives in
`~/.fluencyloop/`; it controls teaching depth and is never committed. Session documents describe
the work, never the person.

## Install

### Claude Code

```text
/plugin marketplace add baokhang83/fluencyloop
/plugin install fluencyloop@fluencyloop
```

Use the namespaced slash commands shown above. The plugin bundles its deterministic CLI, so there
is no separate system-wide FluencyLoop installation.

<details>
<summary>Claude Code updates and Windows approvals</summary>

Claude Code leaves third-party marketplace updates off by default. To opt in once, open
`/plugin`, choose **Marketplaces**, select **fluencyloop**, then choose **Enable auto-update**.
When Claude reports an update, run `/reload-plugins` to activate it in the current session.

Without auto-update, run `/plugin marketplace update fluencyloop`, then
`/plugin update fluencyloop@fluencyloop`, and finally `/reload-plugins`.

On native Windows, use the project-scoped setup in
[Claude Code approvals](docs/claude-code-permissions.md) to reduce routine FluencyLoop, editing,
and read-only Git prompts without granting broad Git or Bash access.

</details>

### Codex

```bash
codex plugin marketplace add baokhang83/fluencyloop
codex plugin add fluencyloop@fluencyloop
```

Use the `$fluencyloop:<stage>` skills shown above. The plugin maintains its own `fluencyloop`
command shim on macOS, Linux, Git Bash, and WSL; no separate runtime installation is required.

<details>
<summary>Codex updates</summary>

Codex asks you to review FluencyLoop's startup hook once. Approve it from `/hooks` to enable
automatic updates. Each new session checks only FluencyLoop's marketplace and, when an update is
available, installs it for the next session without changing the active one.

</details>

## Requirements

FluencyLoop requires [Claude Code](https://claude.com/claude-code) or
[Codex](https://developers.openai.com/codex/), `git`, and either Bash on macOS/Linux/Git Bash/WSL
or PowerShell (`pwsh`) on native Windows.

## More detail

Read [MANIFESTO.md](MANIFESTO.md) for the product principles, calibration and privacy model, and
the boundary between deterministic tooling and agent reasoning. See [CONTRIBUTING.md](CONTRIBUTING.md)
for the repository layout, test commands, and distribution notes.

## License

[Apache-2.0](LICENSE).
