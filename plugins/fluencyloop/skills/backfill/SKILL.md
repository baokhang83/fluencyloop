---
name: backfill
description: 'FluencyLoop safety net. Reconstruct store records for work that shipped without going through the loop — reads a merged diff, records the feature, session, decisions, knowledge, and architectural concepts, then leaves reconstructed decisions unverified until independently confirmed. Use post-merge, or when the user says "fluencyloop backfill", "document this PR after the fact", or "we skipped the loop on this one".'
---

# Backfill — reconstruct, make fluent, then flag

FluencyLoop never blocks a merge. The safety net for work that skipped the loop is
**post-merge backfill**: it gives ad-hoc work a home retroactively. Backfilled rationale
*usually* had no real-time teaching in FluencyLoop's format to force honesty, so it is the entry
most at risk of plausible post-hoc fiction — which is why every backfilled entry is stamped
`trust: ⚠ unverified` and **must pass a human before it lands**. (Sometimes a contemporaneous
record *does* exist outside the loop — see step 1 — which strengthens, but does not replace, that
review.)

Backfill is not just bookkeeping. Its job is to recover the durable explanation of the
components the work touched — the fluency the missing real-time loop never gave them. Record
that explanation as the same feature, session, decision, knowledge, and concept records a live
loop would write, then confirm reconstructed decisions one at a time.

## Bundled CLI (Codex)

On macOS, Linux, Git Bash, and WSL, the trusted SessionStart hook maintains an owned
`~/.local/bin/fluencyloop` shim for this installed plugin. Invoke `fluencyloop …` directly so
Codex shows the readable command in its transcript. Do not resolve its path, check PATH, or
describe the shim to the developer.

If that command reports `command not found` because hooks have not run yet, invoke the bundled
dispatcher from the loaded skill path as a silent fallback. On native Windows, invoke the adjacent
`fluencyloop.ps1` with `pwsh`.

## Question delivery — preserve the pause

For a real answer, choice, or confirmation, use **`AskUserQuestion` in Claude Code**. Codex has
no equivalent question-form tool, so ask a concise standalone question in chat and stop; do not
update an entry's trust marker until the developer answers.

## 0. Preconditions

Run `fluencyloop check --json`. If `git_repo` or `fluency` is false, run `fluencyloop init --json`
without asking the developer. Backfill commonly starts in a repository that skipped FluencyLoop,
so this creates the state required by `fluencyloop feature` and `fluencyloop session` below.

For that `fluencyloop init --json` command in Codex, request sandbox elevation before its first
execution. It may create or update Codex-protected `.git` metadata; do not first attempt it in the
standard sandbox.

## 1. Scope the work

Identify what to backfill — a merged PR, a commit range, or the current branch's diff vs
its base:

```bash
git log --oneline <base>..<ref>
git diff <base>..<ref>
```

If `.fluencyloop/state.json` exists, read it for the `feature` slug and `base_ref` rather than
guessing. Usually it's **absent** for backfill (the work skipped the loop, so nothing wrote it) —
derive the base from git as above; §2 writes a fresh state record when it reconstructs the feature.

**Quantify the drift deterministically** with `fluencyloop check --json`: its `unjournaled_commits`
counts commits since the last journaled session. A non-zero count with no matching sessions is exactly the skipped-loop work
backfill exists to catch — let it scope how much there is to reconstruct.

**Look for a contemporaneous record first.** Work that skipped *FluencyLoop's* loop may still
have a real-time log — a `SESSION.md`, ADRs, a spec-kit session summary, design notes, a rich PR
description. If one exists, **reconstruct from it**, cite it as a source, and frame the entries
as backed by a contemporaneous record (stronger than post-hoc memory) — do **not** write "no
real-time teaching happened" when it did. Only a genuine from-nothing reconstruction gets the
blind-backfill framing. Such a log is also the best raw material for a rich knowledge-transfer
record (step 3).

## 2. Reconstruct — carefully

Read the diff, the history, and the code (plus any ADR/spec/notes the work cites) and infer
the **decisions that were actually made** — the genuine forks, not every line. For each, the
field values are:

- `where` — the file/area it lives in.
- `why` — your best reconstruction of the rationale **from the code and its cited sources**.
  Do not embellish beyond what they support.
- `alternative` — the plausible rejected option, if the code implies one; otherwise say the
  alternative is unknown rather than inventing a tidy story.
- `constitution` — the principle it serves, by the **current** constitution's numbering (if a
  cited source uses older numbers, map to current and note the drift for the human to confirm).
- `trust` — always **unverified** at this stage, with no exceptions.

Create the feature + session to hold them:

```bash
fluencyloop feature --json "<inferred feature intent>"
fluencyloop session --json --slug "<feature-slug>" "<inferred slice intent>"
```

Then append each block with `fluencyloop decision` (the script formats it — you supply only the
values), marking every one backfilled and unverified:

```bash
fluencyloop decision --title "chose X over Y" --where "<file/area>" --why "<reconstructed why>" --alternative "<rejected — why, or 'unknown'>" [--constitution §N] --trust unverified
```

These commands write `.fluencyloop/state.json` (feature, branch, `stage: build`, the session as
`last_session`, `base_ref`) and the same feature/session/decision records as a live loop. If the
work's real base was not the branch you ran this from, correct `base_ref` to the ref your §1 diff
used. **Do not create or edit session journals, `design.md`, diagrams, or any other Markdown.**

## 3. Capture the knowledge and concepts the code now embodies

Backfill the feature's component inventory and hard-won conditions in one batched store write.
Cover the whole relevant pipeline, not just the files that contained a decision; this is the
durable explanation a later reader needs:

```bash
fluencyloop knowledge \
  --component "<name>|<role>|<conditions>" \
  --component "<name>|<role>|<conditions>|follow-up" \
  --gotcha "<subject>|<why it is this way or what breaks otherwise>"
```

Then ask whether the already-shipped code establishes an architectural concept a new joiner would
need explained. This is often more valuable in backfill than another decision: the code exists, so
the transferable thing is how the product works. Capture only genuine concepts, never a ritual
concept per feature:

```bash
fluencyloop concept --name "<concept>" --problem "<product-specific problem>" --how "<how it works>" --realized-by "<component|file|area>" [--realized-by "<...>" ...]
fluencyloop concept --relate "<from>|<to>|<kind>"
```

Both commands append store records; neither creates Markdown. Keep their prose person-neutral:
record what the code does and why, never anyone's competence or prior knowledge.

## 4. Confirm corrections without rewriting history

Do not ask for a blanket "looks good." If the developer can independently verify or correct a
reconstructed decision, append a new `fluencyloop decision` record with the same `title` and
`where` identity, the confirmed or corrected values, and `--trust verified` when they can vouch
for it firsthand. A later line supersedes the earlier unverified record on read; never edit or
delete the original JSONL line. If they cannot verify it, leave the existing `trust: unverified`
record honest.

## Rules

- **Every backfilled decision defaults to `trust: unverified`.** It was reconstructed after the
  fact and must not overstate what was independently checked.
- **Store parity, no Markdown.** Use `fluencyloop decision`, `fluencyloop knowledge`, and
  `fluencyloop concept` so a backfilled feature reads exactly like a live one; never hand-write a
  journal, design, or other Markdown artifact.
- **Reconstruct, don't fabricate.** "Alternative unknown" is a truthful entry; a plausible
  invented tradeoff is not.
- **Describe the work, never the person.** Knowledge-transfer and decision entries record what
  the code does — never an individual's competence, knowledge state, or "who learned what."
  These files are committed and name an identifiable author (GDPR); the per-developer picture
  stays only in the global, uncommitted calibration profile.
- **Still never gates.** Backfill documents after the fact; it does not block anything.
