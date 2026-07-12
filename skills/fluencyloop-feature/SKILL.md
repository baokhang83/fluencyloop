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
the user to run `fluencyloop-constitution` / `fluencyloop init` first, and stop.

**Load the learner's knowledge base.** Read `~/.fluencyloop/calibration.md` — the persisted,
per-developer record of what this learner knows solidly, finds shaky, or hasn't met yet. It is
domain-dimensioned (e.g. "senior Java; Maven plugin internals new"). Use it to set the **starting
depth** of every explanation: terse on solid ground, deeper on shaky. If it's missing, that's
fine — you will *build* it (see §3.4); never block on it. This file is per-developer, global, and
**never committed** — it is the *only* place person-specific knowledge lives (the repo journal
stays person-neutral; see Rules).

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

4. **Update the learner's knowledge base** *(theirs, in `~/.fluencyloop/` — not the repo's)*.
   Persist what this slice revealed about the learner to `~/.fluencyloop/calibration.md`, so the
   estimate you built survives the conversation. Add or adjust one line per concept that moved:

   ```
   <concept>: <solid | learning | new | unknown> — <one-line note> · <YYYY-MM-DD>
   maven-mojo: learning — taught @Mojo/AbstractMojo params and plugin.xml binding · 2026-07-12
   junit5-platform: solid · 2026-07-11
   ```

   Refresh the free-text summary line too. Create the file if absent. This is how the base is
   *built and maintained* — so the next slice, session, and feature start already calibrated
   instead of cold. Keep it global and **uncommitted**; never write person-specific knowledge
   into the repo.

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
- **Estimate continuously, adapt depth, and persist it.** Probe the concepts a feature needs
  *before* diving in, re-estimate every exchange, and set explanation depth from that estimate.
  Build and maintain the learner's knowledge base in `~/.fluencyloop/calibration.md` so fluency
  compounds across features. Person-specific knowledge lives *only* there (global, uncommitted) —
  never in the repo journal.
- **The developer stays the architect.** Teach to keep them fluent; do not take authorship.
