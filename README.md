<p align="center">
  <img src="https://github.com/user-attachments/assets/e3a04a63-4b68-4f61-ad58-60df8cc67045" alt="FluencyLoop Banner" width="1774" style="max-width: 100%; height: auto;">
</p>

# FluencyLoop

[![CI](https://github.com/baokhang83/fluencyloop/actions/workflows/ci.yml/badge.svg)](https://github.com/baokhang83/fluencyloop/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/baokhang83/fluencyloop)](LICENSE)
[![Top language](https://img.shields.io/github/languages/top/baokhang83/fluencyloop)](https://github.com/baokhang83/fluencyloop)
[![Status: alpha](https://img.shields.io/badge/status-alpha-orange)](#distribution-roadmap)

**Stay fluent in the code your AI agent writes.** FluencyLoop is a per-feature loop that
teaches you the *why* of each change as it ships — so the agent writes the code without you
losing the plot.

> The code and your fluency in it are produced together, or not at all.
> See [MANIFESTO.md](MANIFESTO.md) for the why.

## What it does

FluencyLoop is delivered as coding-agent **skills** + deterministic **bash scripts** +
committed **docs** in `docs/fluencyloop/` (the constitution, per-feature designs, and session
journals; the tool's own machine state stays in `.fluencyloop/`).

The core is a **per-feature loop**, with an optional planning step in front for big chunks:

<p align="center">
  <img width="500" height="195" alt="image" src="https://github.com/user-attachments/assets/fb5e1855-2ff7-4ff5-bb4b-4d0fc102bd54" />
</p>

- **plan** — *optional*, only when a chunk is too big for one feature: architecture + roadmap,
  broken into feature-sized tasks.
- **design** — the shapes, rendered so you actually *see* them before any code.
- **build (teach)** — the agent writes it; you get taught the *why* of each real decision at the
  slice boundary, journaled as it goes.
- **review** — the reviewer view assembles itself from the journal, because a feature *is* its branch.

The **constitution** (checkable project principles) is woven through the loop, not a stage you
author cold: it's **born from your first plan or feature** and grows as later features **harvest**
principles from real decisions. Nothing gates a merge — work that skips the loop is caught
**after** merge by `backfill`.

**Requires:** a coding agent ([Claude Code](https://claude.com/claude-code) or
[Codex](https://developers.openai.com/codex/)), `git`, and either `bash` (macOS/Linux/Git
Bash/WSL) or PowerShell (`pwsh`) on native Windows. The deterministic CLI is bundled inside the
agent plugins as both a bash and a PowerShell dispatcher; there is no separate machine-wide
installer or project skill vendoring step.

## Teaches to your level

FluencyLoop doesn't lecture at a fixed depth. Before a feature touches unfamiliar ground it
**asks** — *"For the new Maven plugin, are you familiar with `plugin.xml` and Mojo objects?"* — then keeps re-estimating what you
know from how you respond: terse on solid ground, deeper where it's shaky. What it learns is
persisted to a **per-developer knowledge base** in `~/.fluencyloop/` (global, never committed) —
a structured `dimension: level` profile (`java: fluent`, `reactive: learning`, `k8s: new`) the
loop parses to set teaching depth deterministically. It **adapts from how you engage**: as it
teaches it appends cheap signals (you waved a decision through, asked to go deeper, corrected it),
and `fluencyloop calibration compact` rolls repeated signals into level promotions/demotions — so
depth tracks your real fluency across features instead of resetting each session. Manage it with
`fluencyloop calibration init|show|edit`. Your knowledge profile stays private to your machine;
the committed journal only ever describes the work, never you.

## Install

### Claude Code

Install FluencyLoop through its marketplace — this is the standard Claude Code installation:

```
/plugin marketplace add baokhang83/fluencyloop
/plugin install fluencyloop@fluencyloop
```

The plugin includes the interactive skills and a bundled `fluencyloop` command for Claude Code's
Bash tool. Its skills are intentionally namespaced, for example
`/fluencyloop:feature`, so they cannot collide with another plugin's skills.

Claude Code checks enabled marketplace plugins during normal startup and applies available
FluencyLoop updates through its native plugin updater. If a developer has disabled marketplace
auto-updates in Claude Code, they can re-enable them in the marketplace settings.

### Codex

Install FluencyLoop from the same repository marketplace:

```bash
codex plugin marketplace add baokhang83/fluencyloop
codex plugin add fluencyloop@fluencyloop
```

The plugin makes the `$fluencyloop-*` skills available. Its bundled CLI stays private to the
plugin and is run by those skills, so it never needs to be copied onto your PATH.

After the first startup-hook release is installed and trusted, Codex checks FluencyLoop's own
marketplace every time a new session starts and installs an available update automatically. Codex
activates that update in the following session, not part-way through the one already running.
The hook never refreshes another plugin. Codex will ask for a one-time hook review; approve it
from `/hooks` to enable this behaviour.

Existing Codex installations need this one final manual refresh to receive the startup hook:

```bash
codex plugin marketplace upgrade fluencyloop
codex plugin add fluencyloop@fluencyloop
```

## Quickstart

Inside the repository you want to work on, invoke the workflow stage in your installed agent.
The plan and feature stages initialise `.fluencyloop/` automatically when needed.

| Goal | Claude Code | Codex |
|------|-------------|-------|
| Plan a large initiative — architecture + roadmap | `/fluencyloop:plan revamp the checkout flow` | `$fluencyloop-plan revamp the checkout flow` |
| Build a normal-sized feature — design → build + teach | `/fluencyloop:feature add rate limiting to the API` | `$fluencyloop-feature add rate limiting to the API` |
| Assemble the feature's PR view | `/fluencyloop:review` | `$fluencyloop-review` |
| Document merged work that skipped the loop | `/fluencyloop:backfill` | `$fluencyloop-backfill` |

Use **plan** only for work too large for one feature branch. It creates an architecture + roadmap
under `docs/fluencyloop/plans/`; build each roadmap item as a feature. A feature creates its
branch, design, and session journal under `docs/fluencyloop/`, teaches the *why* of each real
decision at the slice boundary, and records it. Review assembles the reviewer-facing view from
those journals, because a feature *is* its branch.

### Calibration

Calibration controls **how deeply** FluencyLoop explains a decision, never which technical choice
it makes. Your private `~/.fluencyloop/calibration.md` records domain levels—`fluent`,
`familiar`, `learning`, or `new`. During a feature, demonstrated engagement is appended to a
private ledger; `fluencyloop calibration compact` turns repeated signals into deterministic level
changes. The committed session records the work and its rationale, not a judgment about a person.
See [the calibration and privacy rationale](MANIFESTO.md#calibration-is-private-and-deterministic).

### Efficient by design

FluencyLoop keeps the agent's context focused. Scripts create files, calculate branch ranges, and
assemble slice context; the agent spends its effort on design, decisions, and teaching. It reads a
slice diff rather than whole files, asks only what the calibration profile does not settle, and
records rationale at the moment it is still grounded in the change. See [the efficiency
principle](MANIFESTO.md#efficiency-is-a-product-principle).

The **skills** carry the interactive, calibrated behaviour (teaching at slice boundaries,
one-question-at-a-time constitution authoring). The **scripts** carry the deterministic
plumbing (branches, files, PR-view assembly) so the journal is reliable rather than
left to the model.

## Layout

```
.claude-plugin/             Claude Code plugin manifest + self-hosted marketplace catalog
.agents/plugins/            Codex marketplace catalog
claude-skills/              Claude-only aliases: `plan`, `feature`, `review`, `backfill`
bin/                        the plugin's bundled `fluencyloop` launchers
plugins/fluencyloop/        Codex plugin and canonical runtime: CLI (bash + PowerShell), skills,
                            scripts, templates
tests/                      bats suite (bash) + tests/powershell Pester suite (parity)
MANIFESTO.md                the why
```

## Key rules baked in

- **A feature is a branch** (`feature/<slug>`) — the PR view assembles itself, no manual
  linking; session files store no commit SHAs.
- **Never gate.** Flag exposure and unverified trust; never block building or merging.
- **Sessions describe the work, not the person.** The `trust:` marker is about a decision's
  verification state, never an author's competence.
- **Calibrated to you, privately.** The loop probes what you know, adapts explanation depth as it
  goes, and builds a per-developer knowledge base in `~/.fluencyloop/` — global, never committed.
  Person-specific knowledge lives *only* there; the repo journal stays person-neutral.

## License

[Apache-2.0](LICENSE).

---

⭐ **If the "fluency *during* code" framing resonates, star the repo** — it's the clearest
signal this direction is worth pushing on.
