---
name: fluencyloop
description: 'FluencyLoop — stay fluent in code as AI writes it. Router/overview for the four-stage workflow (constitution → design → build+teach → review), the optional up-front planning stage for large chunks, plus post-merge backfill. Use when the user mentions FluencyLoop, "fluency", the .fluencyloop/ directory, or wants to set up / understand the workflow but hasn''t named a specific stage.'
---

# FluencyLoop

*The code and your fluency in it are produced together, or not at all.*

FluencyLoop keeps the people behind a codebase fluent in it as AI writes more of it. It is a
four-stage workflow. **Stage 1 is maintainer-owned, once per project.** **Stages 2–4 are
contributor-driven, once per feature.** Nothing gates a merge — work that skips the loop is
caught after merge by backfill.

```
ONCE, PER PROJECT      [ PER BIG CHUNK ]     REPEATS, PER FEATURE (contributor-driven)
constitution        →  ( plan )          →   design      →  build (teach)   →  review
(maintainer)           architecture +        diagrams        session journal    PR view
                       roadmap, optional                                        assembles itself
```

Planning is **optional** and sits between the constitution and the per-feature loop: reach for it
only when a chunk of work is too big for one feature/branch and needs an architecture + roadmap
first. Small work goes straight to **fluencyloop-feature**.

## Route to the right stage

| The user wants to…                                   | Skill                  |
|------------------------------------------------------|------------------------|
| Set up the project / write its principles            | **fluencyloop-constitution** |
| Plan a large chunk — architecture, task breakdown, roadmap | **fluencyloop-plan**  |
| Start building something, stay fluent as they go     | **fluencyloop-feature**    |
| Prepare a PR / summarise a feature for a reviewer     | **fluencyloop-review**     |
| Document work that shipped without the loop           | **fluencyloop-backfill**   |

If the user just says "fluency" or "set up FluencyLoop" and `.fluencyloop/` does not exist yet,
start with **fluencyloop-constitution** (it runs `fluencyloop init` for you).

## Initialise a project

```bash
<fluencyloop-dist>/scripts/bash/init.sh   # scaffolds .fluencyloop/ and installs these skills
```

This creates `.fluencyloop/` (scripts, templates, constitution stub) and copies the skills into
`.claude/skills`. A feature is a branch (`feature/<slug>`); sessions are committed journals;
the per-developer calibration profile lives globally in `~/.fluencyloop/` and is never
committed.

## The four standing principles

- **Evidence over pitch** — probe demand cheaply before building.
- **Stay out of the way** — never block the fast path; flag exposure, don't gate.
- **The developer stays the architect** — the tool serves their authorship.
- **Honest about tradeoffs** — no claim of free comprehension.
