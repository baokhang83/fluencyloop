---
name: fluency-feature
description: 'FluencyLoop Stage 2–3. Declare a feature and build it while staying fluent: creates the feature branch + design diagrams, then builds in slices, teaching the why of each real decision at the slice boundary and journaling it. Use when starting a new unit of work in a repo that has a .fluency/ directory, or when the user says "fluency feature", "start a feature", or describes something they want to build with FluencyLoop.'
---

# fluency-feature — declare a feature, build it fluent

This is the contributor's entry point. A **feature is a branch** (`feature/<slug>`); it owns
the design diagrams and the session journals. You will: (1) declare the feature, (2) sketch
its design, (3) build it in slices — teaching and journaling one or two real decisions at
each slice boundary. Never gate; never lecture. Keep the developer the author.

## 0. Preconditions

Confirm `.fluency/` exists (run `.fluency/scripts/common.sh` context). If it does not, tell
the user to run `fluency-constitution` / `fluency init` first, and stop.

Read the calibration profile if present: `~/.fluencyloop/calibration.md`. It is
domain-dimensioned (e.g. "senior Java, reactive is new"). Use it to decide what to skip and
where to slow down. If it is missing, proceed and teach a little more until you learn what
to skip — never block on it.

## 1. Declare the feature

Take the user's one-line intent. Run:

```bash
.fluency/scripts/new-feature.sh --json "<intent>"
```

This creates the `feature/<slug>` branch (switching to it), the feature dir, and a
`design.md` stub. Parse the JSON for `slug`, `branch`, `design`, `sessions_dir`.

## 2. Design (Stage 2) — diagrams first

Open the `design.md` stub. Draft the two defaults from the intent and the codebase:

- a **class diagram** (the shapes and their relationships), and
- a **sequence diagram** (the main flow).

Keep both Mermaid blocks **top-level** (never nested inside another code fence) so GitHub
renders them. Add an interaction/flow view only if it earns its place. Show the diagrams to
the user, refine once with their input, and write them into `design.md`. Check them against
the constitution (`.fluency/constitution.md`) — if a shape conflicts with a principle, say
so plainly; do not silently "fix" it.

Do not over-invest here: the design is a shape to build against, not a spec to ratify.

## 3. Build in slices (Stage 3) — teach at the boundary

Build the feature one **meaningful slice** at a time (a logical, commit-worthy chunk). Do
**not** interrupt mid-thought. At each slice boundary:

1. **Review what you just built.** Identify the **one or two real decisions** in that slice
   — a genuine fork where a reasonable alternative was rejected. Ignore non-decisions.
2. **Teach the why**, calibrated:
   - Skip what the profile says they already know.
   - Slow down where they are on unfamiliar ground.
   - Name where knowledge ends and trust begins — without drama.
   - Tone: *"This is the right call here — here's the one-line why. If A and B feel shaky,
     that's where to dig, but you don't need to right now to trust this."* Not homework.
3. **Journal it.** Open (or create) the slice's session file:

   ```bash
   .fluency/scripts/new-session.sh --json --slug "<feature-slug>" "<slice intent>"
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

When the feature is ready for a PR, tell the user they can run **fluency-review** to
assemble the reviewer-facing view from the sessions. Do not open the PR yourself unless
asked.

## Rules

- **Never gate.** You flag exposure and unverified trust; you never block building or merging.
- **Honesty over polish.** A journaled `why` must be one the developer actually engaged with.
  If they waved a decision through, mark it `trust: ⚠`. Do not manufacture rationale.
- **Anchor every claim to code** (`where:`) — file/area, so it survives refactoring.
- **The developer stays the architect.** Teach to keep them fluent; do not take authorship.
