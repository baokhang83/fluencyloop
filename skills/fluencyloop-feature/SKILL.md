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

Confirm `.fluencyloop/` exists (run `.fluencyloop/scripts/common.sh` context). If it does not, tell
the user to run `fluencyloop init` first, and stop.

**Read the loop state.** If `.fluencyloop/state.json` exists, read it *first* — it is the loop's
single source of truth for the active feature (`feature` slug, `branch`, `stage`, `last_session`,
`base_ref`), written by `new-feature.sh` / `new-session.sh` and committed with the branch. Prefer
it over re-deriving from git each turn: it tells you which stage you're resuming at and which
session file is open. It's absent only before the feature is declared (§1 creates it).

**Load the learner's knowledge base — parse it, don't eyeball it.** First fold in what prior work
demonstrated: run `fluencyloop calibration compact` — deterministic bash that rolls the engagement
ledger (§3.4) into level promotions/demotions and clears it, so this feature starts from an
*adapted* profile rather than a reset one. Then read the per-developer calibration profile
*deterministically* via `fluencyloop calibration show --json`: a
`dimension → level` map, level ∈ {`fluent`, `familiar`, `learning`, `new`}, e.g.
`{"java":"fluent","reactive":"learning","k8s":"new"}`. Use each level to set the **starting
depth** for that domain — `fluent` → terse, flag only what's checkable; `familiar` → confirm,
don't re-derive; `learning` → teach the why and check understanding; `new` → from fundamentals.
A dimension that isn't listed is unknown — probe it (below) rather than guessing. The profile
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
.fluencyloop/scripts/new-feature.sh --json "<intent>"
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

1. **Review what you just built.** Identify the **one or two real decisions** in that slice
   — a genuine fork where a reasonable alternative was rejected. Ignore non-decisions.
2. **Teach the why — live, in the conversation.** This is the *during*, so it happens *here*,
   as an exchange — **not** by writing the journal and telling the user to go read it (that's
   the *after*). For each decision:
   - Explain the why and the rejected alternative in the chat, right now.
   - **Anchor it to the rendered design diagram** — point back to the Artifact from §2 and name
     the exact shape the decision concerns, so the *why* lands on something they can see, not
     just prose. If the decision changed the design, re-render and re-check the diagram.
   - When a slice carries several decisions to sign off at once, you may confirm them
     **interactively, one tab per decision** (`AskUserQuestion`) rather than in a wall of text —
     but the live teaching, not the prompt, stays the point.
   - **Pause and check understanding** — ask if it lands, and explicitly offer to go deeper
     ("want me to unpack how X works, or is this enough to trust it?"). Then *wait* for the
     answer before moving on. A monologue that ends in "see the journal" is the failure mode.
   - **Calibrate continuously (see §0).** Hold a live estimate of what they know and *update it
     every exchange*: a quick confirmation is evidence of solid ground (go terser next time); a
     surprised "wait, why?" or a follow-up question is evidence it's shaky (go deeper, now). Set
     this explanation's depth from that running estimate. Skip only what the knowledge base or
     their demonstrated engagement says they know — **never** skip because they authored the code.
     Name where knowledge ends and trust begins.
   - Tone: *"This is the right call here — here's the one-line why. If A and B feel shaky,
     that's where to dig, but you don't need to right now to trust this."* Not homework.
3. **Journal it** *(the byproduct, after the live teaching — not instead of it)*. Open (or
   create) the slice's session file:

   ```bash
   .fluencyloop/scripts/new-session.sh --json --slug "<feature-slug>" "<slice intent>"
   ```

   Append two things, from the live teaching you just did:
   - **Knowledge transfer** — under the session's `## Knowledge transfer` heading, record the
     ground this slice covers: one bullet per component/role/mechanism — the *subject*, *what it
     does and under what conditions*, and *status:* `documented` / `follow-up`. Make it **rich,
     not a token list**: capture the roles *and* the non-obvious conditions, gotchas, and hard-won
     lessons (a bug's root cause, why something is done an odd way, a documented limitation) —
     that is the highest-value fluency. It is the persistent record of the ground now covered — it
     does not evaporate with the chat, and it is separate from decisions (a role you explained is
     knowledge transfer even if no fork was chosen).
     **Keep it about the work, never the person:** record what the code does, never anyone's
     competence, prior knowledge, or "who learned what" — these files are committed and name an
     identifiable author via git (GDPR). The per-developer picture belongs only in the
     uncommitted global calibration profile.
   - **Decisions** — one `## Decision:` block per decision, using the schema in the session
     template. **Each field is a Markdown bullet** (`- **where:** …`, `- **why:** …`,
     `- **alternative:** …`, optional `- **design:**` / `- **constitution:**`, `- **trust:**`)
     — plain `key: value` lines collapse into one paragraph when the `.md` is rendered, so
     always use bullets. `where:` is a file/area, never a line number; `trust:` is `✓` verified
     / `⚠` not independently verified — about the **decision**, never the person.

   Remove the template's example blocks and HTML comment the first time you write real content.

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
   constitution principle**. Be **assertive**: name the candidate and ask outright (*"that reads
   like a standing rule, not a one-off — promote it to §N of the constitution?"*), rather than
   waiting to be asked. On a yes, append it to `docs/fluencyloop/constitution.md` under
   `## Principles` as the next `§N` (short title + the non-negotiable + the why), and cite that
   `§N` in the decision's `constitution:` field. On a no, leave it — a one-off is not a principle.
   This is how the constitution *grows*: harvested from real decisions, never a cold authoring pass.

Repeat per slice until the feature is built. The journal accretes as a byproduct — the
developer never writes it by hand.

## 4. Hand off to review — settle the recurring choice once

When the feature is ready for a PR, tell the user they can run **fluencyloop-review** to
assemble the reviewer-facing view from the sessions.

The commit + push + open-PR hand-off is a **behavioral pattern that recurs every feature** — so
decide it **once**, not once per feature. Check `~/.fluencyloop/preferences.md` (loaded in §0):

- **A preference is already recorded** — honor it silently, and **do not re-ask**. If it says
  automatic, go ahead and commit + push + open the PR yourself (run fluencyloop-review first) at
  completion; if manual, just point the user at fluencyloop-review and stop.
- **No preference yet (this is the first feature)** — ask **exactly once**, via a single
  `AskUserQuestion` confirmation rather than a per-feature prompt: from now on, should you commit
  + push + open the PR yourself at feature completion, or keep handing off manually each time?
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

## Rules

- **Never gate.** You flag exposure and unverified trust; you never block building or merging.
- **Honesty over polish.** A journaled `why` must be one the developer actually engaged with.
  If they waved a decision through, mark it `trust: ⚠`. Do not manufacture rationale.
- **Anchor every claim to code** (`where:`) — file/area, so it survives refactoring.
- **Estimate continuously, adapt depth, and persist it.** Probe the concepts a feature needs
  *before* diving in, re-estimate every exchange, and set explanation depth from that estimate.
  Build and maintain the learner's knowledge base in `~/.fluencyloop/calibration.md` so fluency
  compounds across features. Person-specific knowledge lives *only* there (global, uncommitted) —
  never in the repo journal.
- **Settle recurring hand-offs once.** A workflow choice you'd repeat verbatim every feature
  (e.g. auto commit + push + open PR vs. manual hand-off) is asked **once**, via a single
  confirmation, and persisted to `~/.fluencyloop/preferences.md` (global, uncommitted) — then
  honored silently. Never re-prompt for the same choice feature after feature.
- **The developer stays the architect.** Teach to keep them fluent; do not take authorship.
