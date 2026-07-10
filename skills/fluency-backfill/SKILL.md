---
name: fluency-backfill
description: 'FluencyLoop safety net. Reconstruct journal entries for work that shipped without going through the loop — reads a merged diff, drafts a feature + session with decision blocks, marks every entry trust: ⚠ unverified for human review. Use post-merge, or when the user says "fluency backfill", "document this PR after the fact", or "we skipped the loop on this one".'
---

# fluency-backfill — reconstruct-and-flag, never gate

FluencyLoop never blocks a merge. The safety net for work that skipped the loop is
**post-merge backfill**: it gives ad-hoc work a home retroactively. Backfilled rationale had
**no real-time teaching to force honesty**, so it is the entry most at risk of plausible
post-hoc fiction — which is exactly why every backfilled entry is stamped `trust: ⚠
unverified` and **must pass a human before it lands**.

## 1. Scope the work

Identify what to backfill — a merged PR, a commit range, or the current branch's diff vs
its base:

```bash
git log --oneline <base>..<ref>
git diff <base>..<ref>
```

## 2. Reconstruct — carefully

Read the diff and history and infer the **decisions that were actually made** — the genuine
forks, not every line. For each, draft a `## Decision:` block:

- `where:` — the file/area it lives in.
- `why:` — your best reconstruction of the rationale **from the code**. Do not embellish
  beyond what the diff supports.
- `alternative:` — the plausible rejected option, if the code implies one; otherwise say the
  alternative is unknown rather than inventing a tidy story.
- `trust: ⚠ unverified — backfilled` — **always**, with no exceptions.

Create the feature + session to hold them:

```bash
.fluency/scripts/new-feature.sh --json "<inferred feature intent>"
.fluency/scripts/new-session.sh --json --slug "<feature-slug>" "<inferred slice intent>"
```

Then write the drafted decision blocks into the session file.

## 3. Human review — required

Present every drafted entry to the user and ask them to confirm, correct, or delete each
`why`/`alternative` before anything is committed. Where they confirm from real knowledge,
they may upgrade `⚠` to `✓`. Nothing lands unreviewed.

## Rules

- **Every backfilled entry is `trust: ⚠` until a human says otherwise.**
- **Reconstruct, don't fabricate.** "Alternative unknown" is a truthful entry; a plausible
  invented tradeoff is not.
- **Still never gates.** Backfill documents after the fact; it does not block anything.
