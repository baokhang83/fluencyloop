# FluencyLoop

*The code and your fluency in it are produced together, or not at all.*

## The problem

AI can produce a working change before a developer has held its structure, alternatives, or
tradeoffs in their head. The result can be correct code with an expiring explanation: the model
had the rationale for a turn, then nobody has it when the next change, review, or incident arrives.

FluencyLoop makes understanding a byproduct of building. It does not try to slow generation down
into a ceremony or turn a coding agent into a tutor who lectures constantly. It captures the few
decisions that are real, explains them at a useful depth, and leaves a durable record for the next
reader.

## The thesis

Fluency is active, not passive. A fluent developer can read, reason about, and safely change the
code. They may still choose to trust an unfamiliar area, but that trust should be explicit rather
than mistaken for comprehension.

The goal is therefore not perfect understanding at zero cost. The goal is a useful tradeoff:
generation remains fast while the reasoning worth retaining is made visible during the work.

## The loop

FluencyLoop has one optional planning path and one repeated feature loop:

```text
optional, for a large initiative       repeats for each feature
plan                                  design -> build + teach -> review
architecture + roadmap                 diagrams   slices        PR view
```

- **Plan** is for work too large for one branch. It maps the architecture and breaks it into
  feature-sized tasks.
- **Design** gives a feature a legible shape before implementation: normally a class diagram and
  a sequence diagram.
- **Build + teach** happens at meaningful slice boundaries. The agent explains the actual decision
  it just made, names the rejected alternative, and journals the rationale.
- **Review** assembles a PR-facing view from the feature's journals and branch range.
- **Backfill** is the post-merge safety net for work that skipped the loop. It reconstructs a
  journal from evidence and marks it unverified until a human confirms it.

A feature is a branch. That is the key simplifying constraint: the branch supplies the scope, the
diff range, and the PR relationship without manual linking or stored commit hashes.

## The constitution grows from work

The constitution is a short set of checkable project principles. It is not a standalone approval
stage that blocks a contributor before they can start.

`fluencyloop init` creates an empty constitution stub. The first real plan or feature proposes the
principles its design actually evidences; later decisions can promote a repeatable stance into a
new principle. A principle such as “validate configuration at load, never at use” earns its place
because it was a real decision, not because someone filled in a governance form.

The constitution guides design and explains decisions, but it never gates a merge. FluencyLoop
flags tension and missing evidence; the developer remains the architect.

## Durable records, in the right places

Human-facing artifacts are committed under `docs/fluencyloop/`:

```text
docs/fluencyloop/
  constitution.md
  plans/<plan>/plan.md
  features/<feature>/design.md
  features/<feature>/sessions/<session>.md
```

`.fluencyloop/` contains the tool's deterministic state, copied scripts, and templates. This split
keeps the project record visible and reviewable while keeping the implementation plumbing separate.

Mermaid in a design document is durable source, not a terminal UI. When a visual Artifact surface
is available, diagrams are rendered as self-contained inline SVG/HTML. When it is not, the agent
must say so plainly and direct the user to browser or GitHub rendering; it must not pretend a
Mermaid fence in a terminal is a diagram.

## Calibration is private and deterministic

People need different explanations in different domains. FluencyLoop keeps a per-developer,
machine-local profile at `~/.fluencyloop/calibration.md` with four levels:

| Level | Teaching depth |
|---|---|
| `fluent` | Name the decision and move on. |
| `familiar` | Give the one load-bearing reason. |
| `learning` | Explain the why and the rejected alternative; check that it landed. |
| `new` | Build from fundamentals, slow down, and offer to go deeper. |

An unknown domain is probed rather than guessed. During a feature, small engagement signals—wave
through, ask for depth, or correct the agent—go to a private append-only ledger. `fluencyloop
calibration compact` applies deterministic promotion or demotion rules to the profile. The profile
sets explanatory depth only; it must never choose the architecture on the developer's behalf.

This information is about the developer, so it is local, user-controlled, and never committed.
Sessions describe the work: what was chosen, where, why, and what was rejected. They do not contain
competence labels, inferred personal profiles, or a “who knows what” dossier.

## Questions must pause the workflow

FluencyLoop only asks questions that move the work forward: a calibration probe, a design fork, a
constitution proposal, or a one-time workflow preference.

In Claude Code, a real question uses `AskUserQuestion`. Codex has no equivalent question-form
tool, so it is asked as a concise standalone chat prompt. In either surface, the agent pauses for
the answer before making the dependent change. A real choice must not disappear inside explanatory
prose.

## Efficiency is a product principle

FluencyLoop is intentionally split between deterministic scripts and interactive skills:

| Scripts do the mechanical work | Skills spend context on the irreducible work |
|---|---|
| create branches, files, session skeletons, and state | design the shape and explain the why |
| calculate feature ranges and assemble the review view | identify the decisions that matter |
| return the changed slice and likely-decision signals | teach at the calibrated depth |
| read and update calibration state | elicit choices and record rationale |

This is not merely an implementation detail. It protects the developer's attention and the
agent's context window. The agent reads the changed slice rather than whole files, does not rebuild
file skeletons that a script can create, and does not repeatedly ask a question already settled in
private preferences. The journal is more reliable because its structure is deterministic; the
model spends its tokens on the reasoning a script cannot supply.

## Agent command surface

FluencyLoop is activated through its agent plugins, not a global installer. Start an explicit
stage command in the agent you use:

| Goal | Claude Code | Codex |
|---|---|---|
| Plan a large initiative | `/fluencyloop:plan` | `$fluencyloop-plan` |
| Build a feature | `/fluencyloop:feature` | `$fluencyloop-feature` |
| Assemble its PR view | `/fluencyloop:review` | `$fluencyloop-review` |
| Backfill skipped work | `/fluencyloop:backfill` | `$fluencyloop-backfill` |

The skills invoke the bundled deterministic CLI for `init`, feature/session scaffolding, review
assembly, and private calibration. The CLI is deliberately not a separate machine-wide install:
the agent's plugin manager owns installation and updates. Claude Code refreshes marketplace
plugins at startup; Codex's FluencyLoop plugin uses a trusted `SessionStart` hook to refresh only
its supplying marketplace and activate an update in the following session. This keeps updates
visible, host-native, and outside the middle of a task.

## What FluencyLoop refuses to be

- **Not a gate.** Missing journals, weak evidence, and constitution tension are surfaced, not
  used to block building or merging.
- **Not a competence database.** Calibration is private; committed artifacts describe work, not
  people.
- **Not a generic tutorial layer.** Teaching follows actual slices and actual decisions.
- **Not free comprehension.** The developer can choose speed or depth moment by moment; the tool
  makes the cost visible and keeps it small.
- **Not a replacement for review.** A clear journal improves a reviewer's starting point; it does
  not certify correctness.

## Honest risks

The design has real costs.

1. A feature-level design can drift as code changes or duplicate another feature's view of the
   same area.
2. A journal can become plausible post-hoc narration. Slice-boundary capture, named alternatives,
   code anchors, and review reduce that risk; backfill remains the sharpest edge and is marked
   unverified.
3. Any additional ceremony can repel developers who adopted AI for speed. The mitigation is not a
   promise that it is free: plan is optional, a feature starts with one command, and nothing gates.
4. Agent surfaces differ. Skills must preserve the workflow's pauses and visuals without assuming
   every host has the same forms, renderers, or installation model.

## Status: 0.2.2

0.2.2 is a working cross-agent loop, not a manifesto-only concept: its Claude Code and Codex
plugins ship the same deterministic runtime to scaffold and inspect state, construct feature and
session records, assemble review context, maintain private calibration, and check for package
updates through each host's lifecycle. The next measure of success is not a more elaborate
process; it is whether real contributors stay more fluent with a cost they are willing to pay.

## Standing principles

- **Evidence over pitch.** Dogfood the loop and measure its friction before adding ceremony.
- **Stay out of the way.** Flag exposure; never gate the fast path.
- **The developer stays the architect.** Calibration changes explanation depth, never ownership of
  the technical decision.
- **Honest about tradeoffs.** Comprehension has a cost; FluencyLoop's job is to make that cost
  worthwhile and visible.
