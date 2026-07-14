---
name: fluencyloop-review
description: 'FluencyLoop Stage 4. Assemble the reviewer-facing PR view from a feature''s sessions — a feature is a branch, so it assembles itself from git. Use when preparing a PR description, reviewing a FluencyLoop feature, or when the user says "fluencyloop review", "assemble the PR view", or "summarise this feature for review".'
---

# fluencyloop-review — Stage 4, assemble the PR view

A **feature is a branch**, so the review view assembles itself: no manual linking. You turn
the feature's sessions into a summary a reviewer can read to get fluent fast.

## 1. Gather the raw material

**Read `.fluencyloop/state.json` first** if it exists — it is the loop's source of truth for the
active feature (`feature` slug, `branch`, `base_ref`), so you don't re-derive them from git. Use
its `base_ref` as the diff base (`--base`) rather than guessing the default branch.

From the feature branch (or pass `--slug`):

```bash
fluencyloop review --json                    # paths, commit range, session list
fluencyloop review --base "<base_ref>"       # scope the diff to the recorded base
```

The `--json` form gives `feature`, `range`, `commits`, and the session files. The plain
form inlines every session's decisions under the feature title.

## 2. Render the reviewer view

Produce a concise, reviewer-facing summary:

- **One-line feature intent** (from `design.md`'s `# Design:` title).
- **Decisions that matter**, grouped by session — each as *chose X over Y because Z*, with
  its `where:` code anchor. Lead with the decisions carrying `trust: ⚠` — those are where a
  reviewer should look hardest.
- **Constitution check:** scan each decision's `constitution:` field against the project's
  principles — read `docs/fluencyloop/constitution.md`, and **if it's a pointer** (`Source of
  truth:` naming another file, e.g. `.specify/memory/constitution.md`), read *that* for the
  real principles. **Flag** any decision that appears to conflict, or any principle-relevant
  decision that was never checked. Flag as a surfaced note — never a blocker.
- **Design pointer:** link the feature's `design.md` so the reviewer can see the shape.
- **Un-journaled drift:** run `fluencyloop check --json` and read `unjournaled_commits`. If it's > 0, warn that N commit(s) landed since the
  last journaled session — the reviewer is looking at code the journal doesn't explain, so nudge
  the author to journal it or run backfill. Surface it as a note; never block.

## 3. Output — create the PR, don't hand over text to paste

The point is to remove friction, so **create a prepopulated PR** rather than leaving the user
to copy-paste into GitHub.

1. Make sure the branch is pushed (`git push -u origin <branch>` if it has no upstream).
2. If `gh` is available (`command -v gh`), create the PR with the assembled view as the body:

   ```bash
   gh pr create --title "<feature intent>" --body-file <tmpfile>   # base defaults to main
   ```

   Confirm the title/base with the user first; show them the body you're about to use. On
   success, give them the PR URL.
3. If `gh` is **not** available, still deliver — and make a **one-time** setup offer, because `gh`
   is what lets FluencyLoop open the PR for you. First hand over the reviewer view **rendered**, and
   a **prepopulated compare URL** that opens a ready-to-file PR in the browser (no `gh`, any OS):
   `https://github.com/<owner>/<repo>/compare/<base>...<branch>?expand=1&title=<t>&body=<url-encoded>`
   (mind the URL length limit; fall back to the pasteable body if it's too long). Then check
   `~/.fluencyloop/preferences.md` for a settled `gh-setup` choice:
   - **Not settled yet** — offer **once** via `AskUserQuestion`, selling it: *"Want me to set up
     `gh` so I open your PRs (and file your plan's issues) automatically from here on? One-time —
     I won't ask again."* Options **Yes, set it up** *(recommended, list first)* / **Not now**.
     Record `gh-setup: done` / `gh-setup: declined` to `preferences.md`; never ask again. On **yes**,
     install `gh` the way that fits their OS — don't work from a hardcoded package-manager list; the
     canonical installer for every platform is <https://cli.github.com> — then `gh auth login` and
     create the PR (step 2).
   - **Already `declined`** — don't re-offer; the compare URL above is the path.

Put any external link in the PR's first comment, not the body. Do **not** merge the PR unless
explicitly asked.

## Rules

- **Surface, don't gate.** Flag unverified trust and constitution conflicts; never block.
- **Truthful assembly.** Summarise what the sessions actually say; if a decision has no
  journaled `why`, say it's undocumented rather than inventing one — or suggest
  **fluencyloop-backfill**.
