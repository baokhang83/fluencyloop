---
name: fluency-review
description: 'FluencyLoop Stage 4. Assemble the reviewer-facing PR view from a feature''s sessions — a feature is a branch, so it assembles itself from git. Use when preparing a PR description, reviewing a FluencyLoop feature, or when the user says "fluency review", "assemble the PR view", or "summarise this feature for review".'
---

# fluency-review — Stage 4, assemble the PR view

A **feature is a branch**, so the review view assembles itself: no manual linking. You turn
the feature's sessions into a summary a reviewer can read to get fluent fast.

## 1. Gather the raw material

From the feature branch (or pass `--slug`):

```bash
.fluency/scripts/assemble-pr-view.sh --json           # paths, commit range, session list
.fluency/scripts/assemble-pr-view.sh                  # the raw markdown (sessions inlined)
```

The `--json` form gives `feature`, `range`, `commits`, and the session files. The plain
form inlines every session's decisions under the feature title.

## 2. Render the reviewer view

Produce a concise, reviewer-facing summary:

- **One-line feature intent** (from `design.md`'s `# Design:` title).
- **Decisions that matter**, grouped by session — each as *chose X over Y because Z*, with
  its `where:` code anchor. Lead with the decisions carrying `trust: ⚠` — those are where a
  reviewer should look hardest.
- **Constitution check:** scan each decision's `constitution:` field and the
  `.fluency/constitution.md` principles; **flag** any decision that appears to conflict, or
  any principle-relevant decision that was never checked. Flag as a surfaced note — never a
  blocker.
- **Design pointer:** link the feature's `design.md` so the reviewer can see the shape.

## 3. Output

Offer the summary as a PR description the user can paste. If they ask, write it to the PR
body — but put any external link in the first comment, not the body. Do not open or merge
the PR unless explicitly asked.

## Rules

- **Surface, don't gate.** Flag unverified trust and constitution conflicts; never block.
- **Truthful assembly.** Summarise what the sessions actually say; if a decision has no
  journaled `why`, say it's undocumented rather than inventing one — or suggest
  **fluency-backfill**.
