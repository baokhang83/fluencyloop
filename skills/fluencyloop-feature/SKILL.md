---
name: fluencyloop-feature
description: 'FluencyLoop Stage 2–3. Declare a feature and build it while staying fluent: creates the feature branch + design diagrams, then builds in slices, teaching the why of each real decision at the slice boundary and journaling it. Use when starting a new unit of work in a repo that has a .fluencyloop/ directory, or when the user says "fluencyloop feature", "start a feature", or describes something they want to build with FluencyLoop.'
---

# fluencyloop-feature — declare a feature, build it fluent

This is the contributor's entry point. A **feature is a branch** (`feature/<slug>`); it owns
the design diagrams and the session journals. You will: (1) declare the feature, (2) sketch
its design, (3) build it in slices — teaching and journaling one or two real decisions at
each slice boundary. Never gate; never lecture. Keep the developer the author.

## 0. Preconditions

Confirm `.fluencyloop/` exists (run `.fluencyloop/scripts/common.sh` context). If it does not, tell
the user to run `fluencyloop-constitution` / `fluencyloop init` first, and stop.

Read the calibration profile if present: `~/.fluencyloop/calibration.md`. It is
domain-dimensioned (e.g. "senior Java, reactive is new"). Use it to decide what to skip and
where to slow down. If it is missing, proceed and teach a little more until you learn what
to skip — never block on it.

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
in the page itself, self-contained. Then walk the user through what they're looking at and
invite reactions — this is a conversation, not a handoff.

Persist the same diagrams as **Mermaid** in `design.md` (blocks **top-level**, never nested
in another fence, so GitHub renders them) — that's the durable, committed copy. The Artifact
is the "see it now" view; `design.md` is the record.

Refine once with the user's input. Check the design against the constitution — read
`.fluencyloop/constitution.md`, and **if it's a pointer** (a `Source of truth:` line naming
another file, e.g. `.specify/memory/constitution.md`), read *that* file for the real
principles. If a shape conflicts with a principle, say so plainly; do not silently "fix" it.

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
   - **Pause and check understanding** — ask if it lands, and explicitly offer to go deeper
     ("want me to unpack how X works, or is this enough to trust it?"). Then *wait* for the
     answer before moving on. A monologue that ends in "see the journal" is the failure mode.
   - Calibrate (see §0): skip only what the profile or their demonstrated engagement says
     they know — **never** skip because they authored the code. Slow down on unfamiliar
     ground. Name where knowledge ends and trust begins.
   - Tone: *"This is the right call here — here's the one-line why. If A and B feel shaky,
     that's where to dig, but you don't need to right now to trust this."* Not homework.
3. **Journal it** *(the byproduct, after the live teaching — not instead of it)*. Open (or
   create) the slice's session file:

   ```bash
   .fluencyloop/scripts/new-session.sh --json --slug "<feature-slug>" "<slice intent>"
   ```

   Append one `## Decision:` block per decision, using the schema in the session template:
   `where:` (file/area, never a line number), `why:` (the rationale you just taught),
   `alternative:` (the rejected option and why), optional `design:` / `constitution:`
   anchors, and `trust:` (`✓` verified / `⚠` not independently verified — about the
   **decision**, never the person). Remove the template's example block and HTML comment
   the first time you write a real decision.

Repeat per slice until the feature is built. The journal accretes as a byproduct — the
developer never writes it by hand.

## 4. Hand off to review

When the feature is ready for a PR, tell the user they can run **fluencyloop-review** to
assemble the reviewer-facing view from the sessions. Do not open the PR yourself unless
asked.

## Rules

- **Never gate.** You flag exposure and unverified trust; you never block building or merging.
- **Honesty over polish.** A journaled `why` must be one the developer actually engaged with.
  If they waved a decision through, mark it `trust: ⚠`. Do not manufacture rationale.
- **Anchor every claim to code** (`where:`) — file/area, so it survives refactoring.
- **The developer stays the architect.** Teach to keep them fluent; do not take authorship.
