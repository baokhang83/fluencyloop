---
name: fluencyloop-feature
description: 'FluencyLoop Stage 2–3. Declare a feature and build it while staying fluent: creates the feature branch + design diagrams, then builds in slices, teaching the why of each real decision at the slice boundary and journaling it. Probes the concepts the work needs up front, adapts explanation depth to the developer''s knowledge, and builds/maintains a per-developer knowledge base in ~/.fluencyloop. Use when starting a new unit of work in a repo that has a .fluencyloop/ directory, or when the user says "fluencyloop feature", "start a feature", or describes something they want to build with FluencyLoop.'
---

# fluencyloop-feature — declare a feature, build it fluent

This is the contributor's entry point. A **feature is a branch** (`feature/<slug>`); it owns
the design diagrams and the session journals. You will: (1) declare the feature, (2) sketch
its design, (3) build it in slices — teaching and journaling one or two real decisions at
each slice boundary. Never gate; never lecture. Keep the developer the author.

## 0. Preconditions

Confirm `.fluencyloop/` exists (`fluencyloop check` reports it). If it does not, tell
the user to run `fluencyloop init` first, and stop.

**Read the loop state.** If `.fluencyloop/state.json` exists, read it *first* — it is the loop's
single source of truth for the active feature (`feature` slug, `branch`, `stage`, `last_session`,
`base_ref`), written by `fluencyloop feature` / `fluencyloop session` and committed with the branch. Prefer
it over re-deriving from git each turn: it tells you which stage you're resuming at and which
session file is open. It's absent only before the feature is declared (§1 creates it).

**Load the learner's knowledge base — parse it, don't eyeball it.** First fold in what prior work
demonstrated: run `fluencyloop calibration compact` — deterministic bash that rolls the engagement
ledger (§3.4) into level promotions/demotions and clears it, so this feature starts from an
*adapted* profile rather than a reset one. Then read the per-developer calibration profile
*deterministically* via `fluencyloop calibration show --json`: a
`dimension → level` map, level ∈ {`fluent`, `familiar`, `learning`, `new`}, e.g.
`{"java":"fluent","reactive":"learning","k8s":"new"}`. Each level maps to a **starting teaching
depth** for that domain via the deterministic **depth policy** in §3 (`fluent` → name it and move
on … `new` → unpack, slow down, offer to go deeper) — apply it, don't re-derive it. A dimension
that isn't listed is unknown — probe it (below) rather than guessing. The profile
lives globally under `~/.fluencyloop/` and is **never committed** — it is the *only* place
person-specific knowledge lives (the repo journal stays person-neutral; see Rules). Missing
entirely is fine — you'll *build* it (see §3.4); `fluencyloop calibration init` seeds it. Never
block on it.

**Load the learner's preferences.** Also read `~/.fluencyloop/preferences.md` — a sibling to
`calibration.md` (global, per-developer, **never committed**) that records recurring *workflow*
choices already settled once, so you never re-ask them. The one you'll meet first is the
completion hand-off: whether to commit + push + open the PR automatically, or hand off manually
each feature (see §4). Honor whatever it records without re-asking. If it's missing, that's fine —
you'll create it the first time a recurring choice comes up.

**Probe before you dive in.** Continuously estimating the learner's knowledge is critical, and it
starts *before* the first explanation. From the feature's intent and the code, list the domain
concepts this work will actually require, and for each one the knowledge base doesn't already
settle, **ask** — concisely and batched (one tab per concept via `AskUserQuestion` when there are
several). For example, before building a Maven plugin: *"Are you familiar with `plugin.xml` and
Mojo objects (`@Mojo` / `AbstractMojo`)?"* — rather than silently guessing and either boring or
losing them. Record the answers into the knowledge base and let them set your opening depth.

**A probe answer sets *teaching depth*, never the technical decision.** What the developer knows
changes how *tersely* you explain — it must **never** steer which approach you take. If they say
they know Angular async pipes, that makes async pipes the *cheap-to-teach* option, **not** the one
to avoid; do not swap to an unfamiliar approach "so they learn more." The choice of approach is
driven by what's right for the code and the developer's intent — they are the architect — not by
what they'd learn most from. Steering the design off someone's familiarity is a violation of their
authorship; flag the honest tradeoff and let them choose.

**Never infer fluency from authorship.** That the developer wrote — or generated — the code
you're touching does **not** mean they understand it. AI-generated / vibecoded code is
exactly where the author is *least* fluent: they typed the intent, the model made the
decisions. Git authorship tells you who committed it, not who can reason about it. So the
default is to *explain how it works and check understanding*, not to skip on the basis of
"they own this file." Fluency comes from being taught *through* the code (this loop), not
from having produced it. Only the calibration profile or the developer's demonstrated
engagement — never authorship — justifies skipping.

## 1. Declare the feature

Take the user's one-line intent. Run:

```bash
fluencyloop feature --json "<intent>"
```

This creates the `feature/<slug>` branch (switching to it), the feature dir, and a
`design.md` stub. Parse the JSON for `slug`, `branch`, `design`, `sessions_dir`.

## 2. Design (Stage 2) — diagrams first, *shown* not filed

Draft the two defaults from the intent and the codebase:

- a **class diagram** (the shapes and their relationships), and
- a **sequence diagram** (the main flow).

**Show them rendered — don't just write a file and point at it.** Publish the diagrams as a
**self-contained Artifact** (a web page the user opens in a browser tab and actually sees) —
load the `artifact-design` skill first. The Artifact CSP blocks external scripts, so you
**cannot** pull Mermaid from a CDN: render the diagrams as **inline SVG** (or clean HTML/CSS)
in the page itself, self-contained. Do **not** inline a minified Mermaid/JS bundle to render
client-side — those bundles carry lone surrogate/escape sequences that make the Artifact
deploy fail. **Byte-check before publishing:** the file must be valid UTF-8 with no lone
surrogates / `U+FFFD` and must JSON-round-trip (prefer pure ASCII — HTML entities over literal
dashes/box-drawing); publish only if the check is clean, or the deploy bounces. Then walk the
user through what they're looking at and invite reactions — this is a conversation, not a handoff.

**If the Artifact tool isn't available** (the environment can't publish one, or the deploy keeps
bouncing), **say so explicitly** — don't silently skip the "show" step — and point the user to the
Mermaid diagrams in the feature's **`design.md`**: those render on GitHub, so the design is still
*shown*, just in the committed doc instead of a live page. Give them the path and walk them through
it there.

Persist the same diagrams as **Mermaid** in `design.md` (blocks **top-level**, never nested
in another fence, so GitHub renders them) — that's the durable, committed copy. The Artifact
is the "see it now" view; `design.md` is the record.

Refine once with the user's input. Check the design against the constitution — read
`docs/fluencyloop/constitution.md`, and **if it's a pointer** (a `Source of truth:` line naming
another file, e.g. `.specify/memory/constitution.md`), read *that* file for the real
principles. If a shape conflicts with a principle, say so plainly; do not silently "fix" it.

**Birth the constitution if it's still the empty stub.** If it has no real principles yet and no
plan ran to seed it, this first feature is the constitution's **guaranteed backstop birth**
(planning is optional; this is not). From this feature's intent and the design conversation you
just had, draft **3–5 initial principles** — the checkable constraints and stances this work
evidences, each a short **title** + the **non-negotiable** + the **why** (the failure it
prevents). Show them, confirm, and write them into `## Principles` numbered `§1, §2, …` (decisions
will cite these numbers). Don't author cold or pad to a count — only what the work evidences; and
if a real constitution already lives elsewhere (a `Source of truth:` pointer / SpecKit's
`.specify/memory/constitution.md`), amend that in place rather than forking one. After birth it
grows by harvest (§3).

Do not over-invest here: the design is a shape to build against, not a spec to ratify.

## 3. Build in slices (Stage 3) — teach at the boundary

Build the feature one **meaningful slice** at a time (a logical, commit-worthy chunk). Do
**not** interrupt mid-thought. At each slice boundary:

1. **Review what you just built — from the slice, not the whole files.** Run `fluencyloop
   slice-context` (add `--json` for the structured form) to get *just this slice's* changed hunks
   + metadata — the diff since the last journaled
   session, or the feature's base if none yet, with FluencyLoop's own files filtered out.
   Identify the **one or two real decisions** in it — a genuine fork where a reasonable
   alternative was rejected — from those hunks. Only open a full file when the hunks don't carry
   enough context to judge a decision; re-reading whole files by default is the token waste this
   replaces. Ignore non-decisions.

   **Let the pre-filter gate the expensive pass.** slice-context also emits `likely_decision`
   (with a `decision_score` and the `decision_signals` that fired — new dep/import, new API,
   control-flow, size). When it is **false**, don't spend a full teaching pass: glance at the
   hunks, and unless something is plainly a fork, journal the slice **lightly** (a one-line
   knowledge-transfer note, no decision block) and move on — this is how trivial slices stay
   near-zero cost. When it is **true**, run the full teach (step 2). The filter gates, it doesn't
   gag: a real decision you can plainly see in a low-scored slice still gets taught — but the
   default on a low score is light-touch, not deliberation.
2. **Teach the why — live, in the conversation.** This is the *during*, so it happens *here*,
   as an exchange — **not** by writing the journal and telling the user to go read it (that's
   the *after*).

   **How much you teach is a lookup, not a deliberation.** Depth is a *function of the developer's
   level in the decision's domain* (from §0's profile) — apply this policy rather than re-deciding
   each time:

   | level in the domain | teach the decision like this |
   |---------------------|------------------------------|
   | `fluent`   | **name it and move on** — state the call in a clause; no *why* unless they ask. |
   | `familiar` | **one-line why** — the decision plus its single load-bearing reason; don't unpack. |
   | `learning` | **unpack + check understanding** — the why *and* the rejected alternative, then pause and confirm it landed. |
   | `new`      | **unpack, slow down, offer to go deeper** — build from fundamentals at a gentler pace, and explicitly offer to dig further. |

   A decision spanning several domains takes the depth of its **least-known** one. This mapping is
   the payoff of calibration: it stops you *deliberating* about how much to teach (token-cheap) and
   pitches each decision to their real level (calibrated). The only things that lower depth are the
   **calibration level** and **demonstrated engagement** — *never* authorship (see below).

   For each decision, at the depth the policy sets:
   - Explain to that depth — for `learning`/`new` the why *and* the rejected alternative, right
     now; for `familiar` the one-line why; for `fluent` just name the call.
   - **Anchor it to the rendered design diagram** — point back to the Artifact from §2 and name
     the exact shape the decision concerns, so the *why* lands on something they can see, not
     just prose. If the decision changed the design, re-render and re-check the diagram.
   - **Real questions go through a form, never buried in prose.** Any genuine question you put to
     the developer — a decision to sign off, a fork to choose, "which way do you want this?" —
     **must** use `AskUserQuestion` (one tab per decision/question), not a plain-text question in
     the middle of an explanation. (A rhetorical aside — *"if that feels shaky, say so"* — is not
     a real question; those stay inline.) The live teaching, not the prompt, stays the point, but
     every actual choice is a form so it's unmistakable and easy to answer.
   - **Pause and check understanding** *(where the policy calls for it — `learning` / `new`)* —
     ask if it lands, and explicitly offer to go deeper ("want me to unpack how X works, or is
     this enough to trust it?"). Then *wait* for the answer before moving on. A monologue that
     ends in "see the journal" is the failure mode.
   - **Calibrate continuously (see §0), but let the policy set depth.** Hold a live estimate of
     what they know and *update it every exchange*: a quick confirmation is evidence of fluency
     (log a `wave`, §3.4); a surprised "wait, why?" or a follow-up is evidence it's shaky (log a
     `deeper`). That estimate moves the *level* — the **depth policy** above, not a fresh judgment
     call, then maps level → how much you teach. A sharp mismatch you may act on mid-slice (they're
     clearly lost on a `fluent`-tagged domain → drop to unpacking now), but the table is the
     default. Skip only what the calibration level or demonstrated engagement justifies — **never**
     skip because they authored the code. Name where knowledge ends and trust begins.
   - Tone: *"This is the right call here — here's the one-line why. If A and B feel shaky,
     that's where to dig, but you don't need to right now to trust this."* Not homework.
3. **Journal it** *(the byproduct, after the live teaching — not instead of it)*. Open (or
   create) the slice's session file:

   ```bash
   fluencyloop session --json --slug "<feature-slug>" "<slice intent>"
   ```

   Then record two things — you supply the *content*; the template's scaffolding is already there
   (all in comments, nothing to delete):
   - **Knowledge transfer** *(you write this — it's irreducible)* — under the session's
     `## Knowledge transfer` headings, one bullet per component/role/mechanism: the *subject*,
     *what it does and under what conditions*, and *status:* `documented` / `follow-up`. Make it
     **rich, not a token list**: the roles *and* the non-obvious conditions, gotchas, and hard-won
     lessons (a bug's root cause, why something is done an odd way, a documented limitation) — the
     highest-value fluency. Separate from decisions (a role you explained is knowledge transfer
     even if no fork was chosen). **About the work, never the person** — no competence, prior
     knowledge, or "who learned what" (committed files, GDPR); the per-developer picture lives only
     in the calibration profile.
   - **Decisions** *(the script formats them — you supply only the field values)* — for each, run
     `fluencyloop decision` so the block is assembled deterministically; never hand-write the
     bullet schema:

     ```bash
     fluencyloop decision --title "chose X over Y" --where "<file/area>" --why "<the taught why>" \
       --alternative "<rejected option> — rejected: <why>" [--constitution §N] \
       [--design ../design.md#anchor] --trust unverified   # or: verified
     ```

     `where` is a file/area, never a line number; `trust` is about the **decision**, never the
     person — `unverified` unless you independently checked it.

4. **Log the engagement signal** *(cheap: one append, no level-guessing)*. Levels *adapt from
   demonstrated engagement* — you don't hand-edit them each slice. For each decision you just
   taught, judge how the developer engaged and append **one signal per domain dimension** it
   touched:

   ```
   fluencyloop calibration signal <dimension> wave      # waved it through — evidence of fluency
   fluencyloop calibration signal <dimension> deeper    # asked you to unpack it — still building it
   fluencyloop calibration signal <dimension> correct   # corrected you / drove it — keep teaching rich here
   ```

   Appending is the whole job — trivial, and honest (it records what actually happened, not a
   guess). The deterministic `fluencyloop calibration compact` (run at the next feature's §0)
   rolls repeated signals into level changes: promote on repeated wave-throughs, demote on
   deeper-asks or corrections. This is how calibration adapts across features instead of resetting
   each session. *(For a brand-new dimension, set its initial level from your §0 probe by editing
   the profile; ongoing movement comes from signals.)* The ledger is global and **uncommitted** —
   never write person-specific knowledge into the repo.

5. **Harvest to the constitution** *(the growth beat — now the only ongoing way principles are
   added, so don't let it stay dormant)*. When a decision's *why* is a **repeatable stance** — a
   rule you'd apply again, not a one-off (*"no synchronous cross-service calls in the request
   path"*, *"config is validated at load, never at use"*) — **offer to promote it to a
   constitution principle**. Be **assertive**, and ask it as a form: put the candidate to the
   developer via `AskUserQuestion` — name the proposed principle and offer **Promote to §N** vs
   **Leave as a one-off** — rather than a plain-text question they might skim past. Don't wait to
   be asked. On **promote**, append it to `docs/fluencyloop/constitution.md` under `## Principles`
   as the next `§N` (short title + the non-negotiable + the why), and cite that `§N` in the
   decision's `constitution:` field. On **leave**, it stays a one-off — not a principle.
   This is how the constitution *grows*: harvested from real decisions, never a cold authoring pass.

Repeat per slice until the feature is built. The journal accretes as a byproduct — the
developer never writes it by hand.

## 4. Hand off to review — settle the recurring choice once

When the feature is ready for a PR, tell the user they can run **fluencyloop-review** to
assemble the reviewer-facing view from the sessions.

**Check what's actually possible here first** — run `gh auth status`. If `gh` isn't installed or
authed, **opening a PR isn't available on this machine**, so don't offer it or make the user weigh
it. The hand-off is then at most *commit + push*: default to a manual hand-off (or ask only the
simpler *commit + push* vs *manual* choice), and mention a PR can be opened later — via
`fluencyloop-review` — once `gh` is set up. Only offer the full **commit + push + open-PR**
automation where `gh` actually works.

The hand-off is a **behavioral pattern that recurs every feature** — so decide it **once**, not
once per feature. Check `~/.fluencyloop/preferences.md` (loaded in §0):

- **A preference is already recorded** — honor it silently, and **do not re-ask**. If it says
  automatic, go ahead and commit + push + open the PR yourself (run fluencyloop-review first) at
  completion; if manual, just point the user at fluencyloop-review and stop.
- **No preference yet (this is the first feature)** — ask **exactly once**, via a single
  `AskUserQuestion` confirmation rather than a per-feature prompt: from now on, should you commit
  + push **(+ open the PR, when `gh` is available)** yourself at feature completion, or keep
  handing off manually each time? (Drop the PR clause entirely if `gh` isn't available here.)
  Persist the answer to `~/.fluencyloop/preferences.md` (create it — global, uncommitted, sibling
  to `calibration.md`) and honor it now and on every later feature. Never pose this per-feature
  question again. Format:

  ```
  # FluencyLoop preferences (per-developer, global, uncommitted)
  feature-handoff: automatic — commit + push + open PR at completion · 2026-07-13
  ```

More generally, at the end of the first feature: notice any hand-off you would otherwise repeat
verbatim next time, and settle it with a single confirmation you record — never re-prompt for the
same choice run after run.

## Token budget (rough)

FluencyLoop is meant to be **cheap to run**. Treat these as smell tests, not hard caps:

- **Design (§2):** skim the codebase to the *shapes*, not exhaustively — a few K tokens. You're
  sketching diagrams, not auditing.
- **Build, per slice (§3):** read the **slice context** (the diff via `slice-context`), not whole
  files — typically a few hundred to ~2K tokens. If a slice's context balloons well past that, the
  slice is too big — split it. Open a full file only when a hunk lacks the context to judge a
  decision.
- **Review (§4):** the assembled session journal (already distilled), not the code — ~1–2K.

Read loop state through the deterministic commands — `slice-context --json`, `calibration show
--json`, `check --json` — which are cheap structured reads, not file scans or git re-derivation.

## Rules

- **Never gate.** You flag exposure and unverified trust; you never block building or merging.
- **Honesty over polish.** A journaled `why` must be one the developer actually engaged with.
  If they waved a decision through, mark it `trust: ⚠`. Do not manufacture rationale.
- **Anchor every claim to code** (`where:`) — file/area, so it survives refactoring.
- **Depth is a function of level, not whim.** Probe the concepts a feature needs *before* diving
  in; then teach each decision to the **depth policy** in §3 (`fluent` → name it and move on …
  `new` → unpack, slow down, offer to go deeper). Your live estimate moves the *level* (logged as
  signals, §3.4; rolled up by `calibration compact`) — it does not re-decide depth ad hoc. Build
  and maintain the learner's profile in `~/.fluencyloop/calibration.md` so fluency compounds across
  features. Person-specific knowledge lives *only* there (global, uncommitted) — never in the repo
  journal.
- **Settle recurring hand-offs once.** A workflow choice you'd repeat verbatim every feature
  (e.g. auto commit + push + open PR vs. manual hand-off) is asked **once**, via a single
  confirmation, and persisted to `~/.fluencyloop/preferences.md` (global, uncommitted) — then
  honored silently. Never re-prompt for the same choice feature after feature.
- **The developer stays the architect.** Teach to keep them fluent; do not take authorship.
