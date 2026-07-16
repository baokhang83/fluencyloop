---
name: backfill
description: 'FluencyLoop safety net. Reconstruct journal entries for work that shipped without going through the loop — reads a merged diff, drafts a feature + session with decision blocks, renders a fluency briefing that maps each decision onto the design diagrams, then confirms them with the human one decision at a time. Marks every entry trust: ⚠ unverified until confirmed. Use post-merge, or when the user says "fluencyloop backfill", "document this PR after the fact", or "we skipped the loop on this one".'
---

# Backfill — reconstruct, make fluent, then flag

FluencyLoop never blocks a merge. The safety net for work that skipped the loop is
**post-merge backfill**: it gives ad-hoc work a home retroactively. Backfilled rationale
*usually* had no real-time teaching in FluencyLoop's format to force honesty, so it is the entry
most at risk of plausible post-hoc fiction — which is why every backfilled entry is stamped
`trust: ⚠ unverified` and **must pass a human before it lands**. (Sometimes a contemporaneous
record *does* exist outside the loop — see step 1 — which strengthens, but does not replace, that
review.)

Backfill is not just bookkeeping. Its job is to **make the human fluent again** in the
components the work touched — the fluency the missing real-time loop never gave them. So you
don't just draft and ask "ok?"; you *show them the shapes, rendered,* map each decision onto
them, and confirm decision-by-decision.

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

These also write `.fluencyloop/state.json` (feature, branch, `stage: build`, the session as
`last_session`, `base_ref`), so the backfilled feature carries the **same committed state record**
as one built through the loop — commit it with the reconstructed journal. If the work's real base
wasn't the branch you ran this from, correct `base_ref` to the ref your §1 diff used.

Sketch the feature's `design.md` diagrams (class + sequence) from the code you just read —
these are what the briefing renders.

## 3. Make the reviewer fluent — a rendered briefing

Reconstruction on its own asks the human to rubber-stamp prose. Instead, show them the
components, **rendered**, with each decision tied to what it touches. Load the
`artifact-design` skill, then publish a **self-contained Artifact** the user opens in a browser:

- **Render the diagrams, don't link source.** The Artifact CSP blocks external scripts, so you
  **cannot** pull Mermaid (or any lib) from a CDN. Render the design.md diagrams as **inline
  SVG** (hand-authored) in the page. Do **not** inline a minified Mermaid/JS bundle to render
  client-side — those bundles carry lone surrogate/escape sequences that fail the Artifact
  deploy (see byte-check below). The committed `design.md` keeps the Mermaid as the canonical
  source; the Artifact is the rendered view.
- **If no visual Artifact can be published, say so; do not render an ASCII diagram or paste
  Mermaid source in chat.** Point to `design.md` and ask the user to open it in an IDE Markdown
  preview, for example VS Code's **Markdown: Open Preview** (`Cmd+Shift+V` on macOS), where the
  Mermaid is rendered properly. Leave the relevant `trust: ⚠` markers unconfirmed until the human
  can review that visual.
- **Map every decision onto the diagram.** For each decision, name the exact nodes it concerns
  and make the link visible (e.g. hovering a decision highlights those nodes). A decision the
  human can't see located on a rendered diagram teaches nothing.
- **Teach, briefly.** One or two plain sentences per component bringing them up to date on what
  it does and why — this is the fluency the real-time loop would have given.

**Byte-check before every publish** — the Artifact deploy rejects content with invalid or
unpaired escape sequences (lone surrogates / `U+FFFD`). Validate the file first and only
publish if clean:

```bash
python3 - "$FILE" <<'PY'
import sys
raw=open(sys.argv[1],'rb').read(); txt=raw.decode('utf-8','surrogatepass')
import json
lone=sum(1 for c in txt if 0xD800<=ord(c)<=0xDFFF); repl=txt.count('�')
try: json.dumps(txt); ok=True
except Exception: ok=False
na=sum(1 for b in raw if b>127)
print(f"non-ascii={na} lone-surrogates={lone} FFFD={repl} json-roundtrip={ok}")
print("PUBLISH-SAFE" if (lone==0 and repl==0 and ok) else "DIRTY — do not publish")
PY
```

On native Windows, use this PowerShell equivalent instead:

```powershell
$raw = [System.IO.File]::ReadAllBytes($FILE)
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)
try { $txt = $utf8.GetString($raw); $utf8Ok = $true } catch { $txt = ''; $utf8Ok = $false }
$lone = @($txt.ToCharArray() | Where-Object { [int][char]$_ -ge 0xD800 -and [int][char]$_ -le 0xDFFF }).Count
$repl = @($txt.ToCharArray() | Where-Object { [int][char]$_ -eq 0xFFFD }).Count
$nonAscii = @($raw | Where-Object { $_ -gt 127 }).Count
try { $null = $txt | ConvertTo-Json -Compress; $jsonOk = $true } catch { $jsonOk = $false }
"non-ascii=$nonAscii lone-surrogates=$lone FFFD=$repl json-roundtrip=$jsonOk"
if ($utf8Ok -and $lone -eq 0 -and $repl -eq 0 -and $jsonOk) { 'PUBLISH-SAFE' } else { 'DIRTY — do not publish' }
```

Prefer pure ASCII (HTML entities over literal box-drawing/dashes). If it reports `DIRTY`,
sanitize (or drop the offending inlined content) before calling the Artifact tool.

**Persist the coverage — make it rich, not a token list.** The components you brief become the
session's `## Knowledge transfer` record, and this is where the durable fluency lives, so invest
in it. A thin one-liner per class is not enough. Aim to cover:

- **The whole pipeline / component inventory**, grouped by area (not just the 3–4 classes a
  decision touched) — each with its *role* and *the conditions under which it does its job*.
- **The hard-won, non-obvious mechanism lessons** — the bugs found and fixed, the gotchas, the
  "why it's done this odd way," the documented limitations. These are the highest-value fluency
  and are exactly what a contemporaneous log (step 1) captures; mine it for them.
- Each bullet: *subject* / *what it does and under what conditions* / *status:* `documented` or
  `follow-up`.

Keep it strictly person-neutral: it records what the code does and why, never anyone's
competence, prior knowledge, or "who knew what" (GDPR — these files are committed and name an
identifiable author via git).

Give the user the rendered URL and let them read before you ask anything.

## 4. Confirm — interactively, one decision at a time

Do **not** ask for a blanket "looks good." Confirm **decision by decision**, using an
interactive prompt with **one tab per decision in Claude Code** (up to 4 per call; batch further
decisions in follow-up calls). In Codex, ask one clearly labelled decision at a time in chat and
wait for the answer. For each decision offer:

- **Confirm → ✓** — they can vouch for it firsthand; upgrade `trust: ⚠` to `✓`.
- **Keep as ⚠** — accurate enough, but they can't personally verify it; leave it flagged.
- **Needs fixing** — rationale is off; capture their correction (the free-text option) and rewrite.
- **Delete** — not a real decision; drop it.

Apply their verdicts to the session file (flip trust markers, rewrite corrected `why`/
`alternative`, resolve any noted constitution-numbering drift), reconcile the design.md
backfill banner, and only then commit. Nothing lands unreviewed.

## Rules

- **Every backfilled entry is `trust: ⚠` until a human confirms it.** The interactive
  confirmation is the gate on the *marker*, never on the merge.
- **Show, then ask.** Render the diagrams and map decisions onto them before requesting sign-off.
- **Byte-check every Artifact before publishing** — never ship content that fails the check.
- **Reconstruct, don't fabricate.** "Alternative unknown" is a truthful entry; a plausible
  invented tradeoff is not.
- **Describe the work, never the person.** Knowledge-transfer and decision entries record what
  the code does — never an individual's competence, knowledge state, or "who learned what."
  These files are committed and name an identifiable author (GDPR); the per-developer picture
  stays only in the global, uncommitted calibration profile.
- **Still never gates.** Backfill documents after the fact; it does not block anything.
