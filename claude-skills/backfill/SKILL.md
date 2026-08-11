---
name: backfill
description: 'FluencyLoop safety net. Reconstruct store records for work that shipped without going through the loop — reads a merged diff, records the feature, session, decisions, knowledge, and architectural concepts, and defaults reconstructed decisions to unverified. Use post-merge, or when the user says "fluencyloop backfill", "document this PR after the fact", or "we skipped the loop on this one".'
---

# fluencyloop-backfill — reconstruct, make fluent, then flag

FluencyLoop never blocks a merge. The safety net for work that skipped the loop is
**post-merge backfill**: it gives ad-hoc work a home retroactively. Backfilled rationale
*usually* had no real-time teaching in FluencyLoop's format to force honesty, so it is the entry
most at risk of plausible post-hoc fiction — which is why every backfilled entry is stamped
`trust: ⚠ unverified` by default. It lands immediately and never asks for a confirmation; a
contemporaneous record can strengthen the reconstruction without changing that default.

Backfill is not just bookkeeping. Its job is to recover the durable explanation of the
components the work touched — the fluency the missing real-time loop never gave them. Record
that explanation as the same feature, session, decision, knowledge, and concept records a live
loop would write, while making uncertainty visible in the record rather than turning it into a conversation gate.

## Bundled CLI (Claude Code)

Before invoking a deterministic command, use this plugin's bundled launcher:
`"${CLAUDE_PLUGIN_ROOT}/bin/fluencyloop" <arguments>`. Every `fluencyloop …` command below
means that exact Bash-tool command; it is never a chat instruction or a globally installed
command.

Do not hand-scaffold `.fluencyloop/`, `.claude/skills/`, designs, sessions, state, or helper
scripts. The bundled CLI creates the deterministic files and returns their paths.

## Local site — open once

Before the first user-visible response, invoke
`"${CLAUDE_PLUGIN_ROOT}/bin/fluencyloop" site --ensure --open --json`. If it reports `running: true`
and no earlier assistant message in this session starts with `FluencyLoop site:`, say
`FluencyLoop site: <url> (opened in browser).` once, using its returned URL. Do not mention an
unavailable site or repeat the announcement. The CLI opens the browser safely for the loopback URL.

## Generated prose — ASD-STE100

Write generated user-facing technical prose in ASD-STE100 style: use short, direct sentences,
active voice, one main action per sentence, and stable, unambiguous terms. Preserve product names,
code identifiers, CLI commands, field names, and exact recorded values. Do not claim formal
ASD-STE100 compliance: that requires checking the official controlled dictionary and rules.

## Automatic trust handling

Backfill never asks for a trust confirmation. It records uncertainty as `trust: unverified`; only
a later, volunteered correction may append a superseding `trust: verified` record.

## 1. Scope the work

Identify what to backfill — a merged PR, a commit range, or the current branch's diff vs
its base:

```bash
git log --oneline <base>..<ref>
git diff <base>..<ref>
```

If `.fluencyloop/state.json` exists, read it for the `feature` slug and `base_ref` rather than
guessing. Usually it's **absent** for backfill (the work skipped the loop, so nothing wrote it) —
derive the base from git as above; §3 writes a fresh state record when it reconstructs the feature.

**Quantify the drift deterministically** with `fluencyloop check --json`: its `unjournaled_commits`
counts commits since the last journaled session. A non-zero count with no matching sessions is exactly the skipped-loop work
backfill exists to catch — let it scope how much there is to reconstruct.

**Look for a contemporaneous record first.** Work that skipped *FluencyLoop's* loop may still
have a real-time log — a `SESSION.md`, ADRs, a spec-kit session summary, design notes, a rich PR
description. If one exists, **reconstruct from it**, cite it as a source, and frame the entries
as backed by a contemporaneous record (stronger than post-hoc memory) — do **not** write "no
real-time teaching happened" when it did. Only a genuine from-nothing reconstruction gets the
blind-backfill framing. Such a log is also the best raw material for a rich knowledge-transfer
record (step 4).

### Legacy repository migration

When automatic import has found a pre-0.3 history (feature records carry `imported_from` and
`docs/fluencyloop/features/` contains multiple historical feature directories), the default scope
is **every imported feature**, not the current branch or the first plausible release. Enumerate
those feature directories in a stable order, read their imported decisions and knowledge plus the
relevant history, and examine every one before reporting migration complete. Only use a narrower
scope when the developer explicitly names one PR, commit range, or feature.

The importer has already declared each historical feature and its `000-legacy-import` session.
Do **not** call `fluencyloop feature` or `fluencyloop session` for them: those commands create or
switch branches. Attribute concrete reconstructed records directly to the existing imported
session instead:

```bash
fluencyloop decision --feature "<legacy-slug>" --session 000-legacy-import ...
fluencyloop knowledge --feature "<legacy-slug>" --session 000-legacy-import ...
fluencyloop concept --feature "<legacy-slug>" --session 000-legacy-import ...
```

Every legacy feature must be assessed, but not every feature merits a new architectural record.
Skip unsupported records rather than inventing a concept per feature. At completion, report the
number of imported features examined and the decisions, knowledge records, concepts, and relations
actually added; never call a one-feature reconstruction a completed repository migration.

## 2. Assemble records before writing

Do the evidence work first. Before running `fluencyloop feature`, `fluencyloop session`, or any
writer, prepare a concrete, non-empty record plan in the conversation: feature intent, session
intent, and the exact fields for each supported decision, component, condition, concept, or
relationship. Examples below are templates, never commands to execute with placeholders omitted.

**Never invoke a bare writer to discover its syntax.** Do not run `fluencyloop decision`,
`fluencyloop knowledge`, or `fluencyloop concept` without arguments. If the evidence supports no
record of one type, skip that command entirely and say why; an empty command is neither a check
nor a harmless no-op.

Each command has a complete minimum payload:

- decision: `--title`, `--where`, `--why`, `--alternative`, and `--trust unverified`;
- knowledge: at least one complete `--component "name|role|conditions"` or
  `--gotcha "subject|why"`;
- concept: `--name`, `--problem`, `--how`, and at least one `--realized-by`; or a complete
  `--relate "from|to|kind"`.

Only after that plan exists, create the feature and session for a new backfill, or use the existing
legacy target above, then append the concrete records. This keeps an evidence-free reconstruction
from changing branches or leaving an empty session behind.

## 3. Reconstruct — carefully

Read the diff, the history, and the code (plus any ADR/spec/notes the work cites) and infer
the **decisions that were actually made** — the genuine forks, not every line. For each, the
field values are:

- `where` — the file/area it lives in.
- `why` — your best reconstruction of the rationale **from the code and its cited sources**.
  Do not embellish beyond what they support.
- `alternative` — the plausible rejected option, if the code implies one; otherwise say the
  alternative is unknown rather than inventing a tidy story.
- `constitution` — the principle it serves, by the **current** constitution's numbering (if a
  cited source uses older numbers, map it when the evidence is clear; otherwise omit it rather
  than asking for confirmation.
- `trust` — always **unverified** at this stage, with no exceptions.

Create the feature + session to hold them:

```bash
fluencyloop feature --json "<inferred feature intent>"
fluencyloop session --json --slug "<feature-slug>" "<inferred slice intent>"
```

Then append each block with `fluencyloop decision` (the script formats it — you supply only the
values), marking every one backfilled and unverified:

```bash
fluencyloop decision --title "chose X over Y" --where "<file/area>" --why "<reconstructed why>" \
  --alternative "<rejected — why, or 'unknown'>" [--constitution §N] --trust unverified
```

These commands write `.fluencyloop/state.json` (feature, branch, `stage: build`, the session as
`last_session`, `base_ref`) and the same feature/session/decision records as a live loop. If the
work's real base was not the branch you ran this from, correct `base_ref` to the ref your §1 diff
used. **Do not create or edit session journals, `design.md`, diagrams, or any other Markdown.**

## 4. Capture the knowledge and concepts the code now embodies

Backfill the feature's component inventory and hard-won conditions in one batched store write.
Cover the whole relevant pipeline, not just the files that contained a decision; this is the
durable explanation a later reader needs:

```bash
fluencyloop knowledge \
  --component "<name>|<role>|<conditions>" \
  --component "<name>|<role>|<conditions>|follow-up" \
  --gotcha "<subject>|<why it is this way or what breaks otherwise>"
```

Decide from the already-shipped code whether it establishes an architectural concept a new joiner
would need explained. This is often more valuable in backfill than another decision: the code
exists, so the transferable thing is how the product works. Capture only genuine concepts, never a
ritual concept per feature:

```bash
fluencyloop concept --name "<concept>" --problem "<product-specific problem>" --how "<how it works>" --realized-by "<component|file|area>" [--realized-by "<...>" ...]
fluencyloop concept --relate "<from>|<to>|<kind>"
```

Both commands append store records; neither creates Markdown. Keep their prose person-neutral:
record what the code does and why, never anyone's competence or prior knowledge.

## 5. Correct later without rewriting history

Do not ask for trust confirmation. If the developer later volunteers an independent verification
or correction, append a new `fluencyloop decision` record with the same `title` and `where`
identity, the corrected values, and `--trust verified` when they can vouch for it firsthand. A
later line supersedes the earlier unverified record on read; never edit or delete the original
JSONL line. Otherwise, leave the existing `trust: unverified` record honest.

## 6. Recommend one distillation pass after the reconstruction settles

After the decisions, knowledge, and concepts are settled, recommend one bounded distillation
pass. Do not create a turn-by-turn summary while reconstructing: the store already preserves the
evidence and the individual decision rationale. Start with `docs/fluencyloop/distillations/product.md`
when the recovered history makes the product's problem, shape, or major flow legible. Then add
feature deltas for the most consequential backfilled features and concept explanations only where
the store's problem/how fields are not enough for a reader to hold the model. Do not distill
individual decisions.

Keep the prose person-neutral and product-level. This is the same wrap-up pass used by a live
feature, delayed until the reconstructed record is stable rather than omitted because the work was
backfilled.

## Rules

- **Every backfilled decision defaults to `trust: unverified`.** It was reconstructed after the
  fact and must not overstate what was independently checked.
- **No trust prompts.** Record uncertainty automatically; only a later volunteered correction may
  supersede it with `trust: verified`.
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
- **No empty writer calls.** Omit a record type that has no evidence; never invoke a writer with
  missing required fields.
