# FluencyLoop

*Keep the people behind a codebase collectively fluent in it, as AI writes more of it.*

The code and your fluency in it are produced together, or not at all. See
[MANIFESTO.md](MANIFESTO.md) for the why.

FluencyLoop is a four-stage workflow, delivered as coding-agent **skills** + deterministic
**bash scripts** + committed **state** in `.fluency/` — the same three-layer shape as
SpecKit, aimed at the opposite point on the timeline (during & after code, not before).

```
ONCE, PER PROJECT        REPEATS, PER FEATURE (contributor-driven)
constitution          →  design      →  build (teach)   →  review
(maintainer)             diagrams        session journal    PR view assembles itself
```

Nothing gates a merge. Work that skips the loop is caught **after** merge by `backfill`.

## Install into a project

From this checkout, run the dispatcher inside your target repo:

```bash
/path/to/fluency-loop/fluency init
```

This scaffolds `.fluency/` (scripts, templates, a constitution stub) and installs the
interactive skills into the repo's `.claude/skills/`. From then on your coding agent can run
the stages by name.

## Use it

| Stage | Skill (in your agent) | Or directly |
|-------|-----------------------|-------------|
| 1. Constitution *(maintainer, once)* | `fluency-constitution` | — |
| 2–3. Feature: design → build + teach *(per feature)* | `fluency-feature` | `fluency feature "<intent>"` |
| 4. Review *(per feature)* | `fluency-review` | `fluency review` |
| Safety net *(post-merge)* | `fluency-backfill` | — |

The **skills** carry the interactive, calibrated behaviour (teaching at slice boundaries,
one-question-at-a-time constitution authoring). The **scripts** carry the deterministic
plumbing (branches, files, PR-view assembly) so the journal is reliable rather than
left to the model.

## Layout

```
fluency                     CLI dispatcher (init / feature / session / review)
scripts/bash/               deterministic plumbing (common, init, new-feature, …)
templates/                  .fluency state templates (constitution, design, session)
skills/                     the interactive skills installed into .claude/skills
MANIFESTO.md                the why
```

## Key rules baked in

- **A feature is a branch** (`feature/<slug>`) — the PR view assembles itself, no manual
  linking; session files store no commit SHAs.
- **Never gate.** Flag exposure and unverified trust; never block building or merging.
- **Sessions describe the work, not the person.** The `trust:` marker is about a decision's
  verification state, never an author's competence.
- **Calibration is per-developer and global** (`~/.fluencyloop/`), never committed.
