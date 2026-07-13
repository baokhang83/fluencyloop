<img width="1983" height="793" alt="image" src="https://github.com/user-attachments/assets/24b508b0-0332-45e3-bd0b-6681220fc796" />

# FluencyLoop

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

```
[ plan ]  →  design  →  build (teach)  →  review
```

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

**Requires:** a coding agent ([Claude Code](https://claude.com/claude-code)) plus `bash` and
`git`. The `fluencyloop` CLI runs standalone; the interactive skills need the agent.

## Teaches to your level

FluencyLoop doesn't lecture at a fixed depth. Before a feature touches unfamiliar ground it
**asks** — *"For the new Maven plugin, are you familiar with `plugin.xml` and Mojo objects?"* — then keeps re-estimating what you
know from how you respond: terse on solid ground, deeper where it's shaky. What it learns is
persisted to a **per-developer knowledge base** in `~/.fluencyloop/` (global, never committed),
so the next feature starts already calibrated instead of cold — and the fluency compounds. Your
knowledge profile stays private to your machine; the committed journal only ever describes the
work, never you.

## Install

**1. Once per machine** — from a clone of this repo:

```bash
git clone https://github.com/baokhang83/fluencyloop && cd fluencyloop
./install.sh
```

This copies the tool into `~/.fluencyloop/lib`, puts the `fluencyloop` CLI on your PATH
(`~/.local/bin` — make sure that's on your `$PATH`), and installs the interactive skills
**user-wide** (`~/.claude/skills`) so your coding agent sees them in every project.
(`./install.sh --no-skills` skips the last step; `--bin-dir <dir>` changes where the CLI is linked.)

**2. Once per project** — inside a repo you want to use FluencyLoop on:

```bash
fluencyloop init
```

This scaffolds that repo's `.fluencyloop/` state (scripts, templates, a constitution stub) and
adds the calibration `.gitignore` guard. Skills are already user-wide, so they are *not*
copied into the repo — unless you want contributors to get them on clone, in which case:

```bash
fluencyloop init --vendor-skills   # commits the skills into the repo's .claude/skills
```

## Quickstart

From inside an `init`-ed project, start a feature:

```bash
fluencyloop feature "add rate limiting to the API"
```

This creates the `feature/add-rate-limiting` branch and drops a design doc + session journal
under `.fluencyloop/`. As you build, your agent teaches the *why* of each real decision at the
slice boundary and records it in the journal. When you're ready to open a PR:

```bash
fluencyloop review
```

…assembles the reviewer-facing PR view straight from those journals — no manual linking,
because a feature *is* its branch. Shipped something without the loop? `fluencyloop backfill`
(or `/fluencyloop-backfill`) reconstructs the journal after merge.

## Use it

| Step | Slash command (in your agent) |
|------|-------------------------------|
| Plan a big chunk *(optional)* — architecture + roadmap | `/fluencyloop-plan` |
| Build a feature — design → build + teach *(per feature)* | `/fluencyloop-feature` |
| Review — the PR view assembles itself *(per feature)* | `/fluencyloop-review` |
| Backfill — document work that skipped the loop *(post-merge)* | `/fluencyloop-backfill` |

You invoke a stage two ways: **type the slash command** (e.g. `/fluencyloop-feature`), or just
**describe the task** ("start a feature to add rate limiting") and your agent triggers the
matching skill from its description. Both run the same skill.

The **skills** carry the interactive, calibrated behaviour (teaching at slice boundaries,
one-question-at-a-time constitution authoring). The **scripts** carry the deterministic
plumbing (branches, files, PR-view assembly) so the journal is reliable rather than
left to the model.

## Layout

```
install.sh                  machine install: CLI on PATH + skills user-wide
fluency                     CLI dispatcher (init / plan / feature / session / review / check / version / self upgrade)
VERSION                     the current version (0.2.0); `fluencyloop version` prints it
scripts/bash/               deterministic plumbing (common, init, new-feature, …)
templates/                  .fluencyloop state templates (constitution, design, session)
skills/                     the interactive skills (installed into ~/.claude/skills)
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

## Contributing & support

Questions, ideas, and bug reports are welcome — open an
[issue](https://github.com/baokhang83/fluencyloop/issues) or start a
[discussion](https://github.com/baokhang83/fluencyloop/discussions). This is alpha and
actively dogfooded, so expect rough edges and fast-moving changes.

<a id="distribution-roadmap"></a>
> **Distribution roadmap:** today it's clone + `install.sh`. Packaging the skills as a Claude
> Code **plugin/marketplace** entry (one-click install for others) and publishing the CLI
> (homebrew/npm) are the next distribution steps — not required to use.

## License

[Apache-2.0](LICENSE).

---

⭐ **If the "fluency *during* code" framing resonates, star the repo** — it's the clearest
signal this direction is worth pushing on.
