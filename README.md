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
[Codex](https://developers.openai.com/codex/)) plus `git`, and a
shell to run the CLI — `bash` (macOS/Linux/Git Bash/WSL) or **PowerShell 7** (Windows). The
`fluencyloop` CLI runs standalone; the interactive skills need the agent.

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
`/fluencyloop:fluencyloop-feature`, so they cannot collide with another plugin's skills.

### Codex or a standalone terminal CLI

Clone and install the CLI. Use `--agent codex` to install the current Codex skills as well; omit
that flag (or pass `--no-skills`) when you only want the terminal command.

```bash
git clone https://github.com/baokhang83/fluencyloop && cd fluencyloop
./install.sh --agent codex
```

This copies the tool into `~/.fluencyloop/lib` and puts `fluencyloop` on your PATH
(`~/.local/bin` — make sure that's on your `$PATH`).

### Initialise a project

Inside a repository you want to use FluencyLoop on:

```bash
fluencyloop init
```

This scaffolds that repo's `.fluencyloop/` state (scripts, templates, a constitution stub) and
adds the calibration `.gitignore` guard.

### On Windows

Two ways to run it:

**Native PowerShell CLI** ([PowerShell 7](https://aka.ms/powershell)). Use this when you want the
CLI outside Claude Code. From a clone:

```powershell
./install.ps1 -NoSkills
```

This copies the tool into `%USERPROFILE%\.fluencyloop\lib` and adds it to your user PATH. Then
`fluencyloop <verb>` works from PowerShell **and** cmd (via a `.cmd` shim), with the same verbs
and `--json` output as the bash CLI — `fluencyloop version` and `fluencyloop self upgrade`
included. Use `./install.ps1 -Agent codex` for Codex; install Claude Code through the marketplace
above.

**Git Bash / WSL.** The bash tool also runs unchanged in **Git Bash** (bundled with
[Git for Windows](https://git-scm.com/download/win)) or **WSL** — use `./install.sh` there.

Both shells are verified on a Windows CI runner: the bash suite via Git Bash, and the PowerShell
port via `PSScriptAnalyzer` + a `Pester` suite that mirrors the bash tests.

## Quickstart

From inside the repository you want to work on:

```bash
# Scaffold the project once.
fluencyloop init

# Choose one path. For a large initiative, make its architecture and roadmap first.
fluencyloop plan "revamp the checkout flow"

# For a normal-sized change, start a feature: this creates its branch, design stub, and session journal.
fluencyloop feature "add rate limiting to the API"
```

Use **one** of the last two commands: `plan` is optional and is for work too large for one
feature; it creates an architecture + roadmap under `docs/fluencyloop/plans/`. Build each roadmap
item as a feature. `feature` creates the `feature/add-rate-limiting` branch and drops a design doc
and a session journal under `docs/fluencyloop/`. As you build, your agent teaches the *why* of each
real decision at the slice boundary and records it in the journal. When you're ready to open a PR:

```bash
fluencyloop review
```

…assembles the reviewer-facing PR view straight from those journals — no manual linking,
because a feature *is* its branch. Shipped something without the loop? `fluencyloop backfill`
reconstructs the journal after merge.

### Useful commands

```bash
fluencyloop check              # inspect the active feature and un-journaled drift
fluencyloop version            # print the installed release
fluencyloop self upgrade       # refresh an installed copy from its source checkout
fluencyloop calibration show   # inspect your private teaching profile
fluencyloop calibration edit   # adjust it yourself, if you want to
```

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

## Use it

| Step | Claude Code | Codex |
|------|-------------|-------|
| *(optionally)* Plan a big chunk — architecture + roadmap | `/fluencyloop:fluencyloop-plan` | `$fluencyloop-plan` |
| Build a feature — design → build + teach *(per feature)* | `/fluencyloop:fluencyloop-feature` | `$fluencyloop-feature` |
| Review — the PR view assembles itself *(per feature)* | `/fluencyloop:fluencyloop-review` | `$fluencyloop-review` |
| Backfill — document work that skipped the loop *(post-merge)* | `/fluencyloop:fluencyloop-backfill` | `$fluencyloop-backfill` |

You can also describe the task naturally, but invoking the stage skill explicitly makes the
workflow unmistakable.

The **skills** carry the interactive, calibrated behaviour (teaching at slice boundaries,
one-question-at-a-time constitution authoring). The **scripts** carry the deterministic
plumbing (branches, files, PR-view assembly) so the journal is reliable rather than
left to the model.

## Layout

```
install.sh / install.ps1    machine install (bash / PowerShell): CLI on PATH; `--agent codex` adds Codex skills
.claude-plugin/             Claude Code plugin manifest + self-hosted marketplace catalog
bin/                        the plugin's bundled `fluencyloop` launchers
fluencyloop{,.ps1,.cmd}     CLI dispatcher — verbs: init / plan / feature / session / decision / review / check / slice-context / calibration / version / self upgrade
VERSION                     the current version (0.2.0); `fluencyloop version` prints it
scripts/bash/               deterministic plumbing — bash (the reference implementation)
scripts/powershell/         the same plumbing, ported to PowerShell (Windows-native)
templates/                  .fluencyloop state templates (constitution, design, session)
skills/                     the interactive skills (activated for Claude Code or Codex)
tests/                      bats suite (bash) + tests/powershell Pester suite (mirror)
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
