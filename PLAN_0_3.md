# FluencyLoop 0.3 — comprehension over documentation

## Context

FluencyLoop produces markdown that developers don't have time to study. Realtime artifacts don't
land either, because the developer didn't author them and has to take them at face value. And the
knowledge transfer leans on class and sequence diagrams, which are the wrong altitude for AI
handover — what transfers is the product's big picture, each feature as a delta to it, and the
architectural concepts underneath. Details kill understanding.

0.3 replaces the markdown pile with a navigable site, served on a local port, generated from an
append-only JSONL store the loop fills as it already runs. Coverage is exactly what the loop has
touched. The developer is never asked to author or approve anything mid-flow.

Constraint that governs every choice below: **FluencyLoop is lightweight and goes easy on tokens.**

### Settled decisions

- Store is append-only JSONL, written only by shell (`>>`, no JSON parser on the core path).
  The model and the site only ever read it.
- Distillations are model-written prose, rewritten in place, produced **at wrap-up only** — never
  per turn. This is the entire token argument.
- The site has **no build tier**: pages render per request from store + distillations. Nothing is
  persisted for the site itself. Calibration stays in `~/.fluencyloop/` and is applied at serve
  time, so it never reaches the repo.
- Site *code* ships in the plugin, **not** copied into each project by `init.sh`.
- Components and hard-won conditions are captured in **one batched call at session close**, not
  one call per item — the flow is never broken per-item.
- **Mandatory** class and sequence diagrams stop being generated, at both the plan and feature
  stages, and the rendered-Artifact step is removed. The site becomes the only place architecture
  is shown. This is not a ban on diagrams: it moves the choice from a template that demands two
  fixed diagram types per feature to the model, which decides per subject whether prose, a table,
  or a diagram explains it best — and renders it in the site.
- The site is a **first-class visual product**, not a document dump. It has to look genuinely good,
  respond well, and hold attention, because a site nobody wants to open fails for exactly the same
  reason the markdown pile failed.
- The constitution moves from harvest-only to **guided elicitation**: the model walks a fixed set
  of areas and asks the developer their stance per area. Areas with no answer stay explicitly
  empty. Authorship stays with the developer.
- The **plan skill gains requirements analysis**: before designing anything, it analyses the
  initiative against the codebase and the constitution, identifies gaps, and asks the developer
  about the ones whose answers change the work. Gaps that stay unanswered are recorded as open
  questions rather than silently assumed away.
- **Session markdown stops being written in 0.3.** Existing markdown files are never modified —
  the importer reads them and writes store records alongside.

### Risk this plan accepts

Stopping markdown is a breaking change shipped over a **silent, unpinned auto-update** hook
(`refresh-marketplace.sh` runs on every `SessionStart`). Two constraints follow, and they are not
optional:

1. The importer must run **automatically** on a project's first 0.3 use. Otherwise an existing
   user's site is empty on the day they're upgraded without asking.
2. 0.3 lands as a **single fast-forward promotion** from `dev` to `main`. Partial promotion would
   ship a loop that has stopped writing markdown but cannot yet show a site.

## Milestone

`0.3 — comprehension over documentation` — milestone **#2**.
Every issue carries `pillar:comprehension` plus a type label.

**Issues are written to be implementable by another agent (Codex) without this conversation.** Each
one therefore carries: why it exists, the exact files and existing helpers to reuse, acceptance
criteria, the tests that must pass, and the project-wide constraints it can't violate — bash and
PowerShell move together, the store is append-only and shell-written, nothing rewrites a path 0.2
created, and `main` is the release channel so nothing lands there until G1.

## Issues

Every item below is filed on milestone #2. The issue body is the implementable version — it carries
the acceptance criteria and the tests; this document carries the reasoning.

| | Item | Issue | Phase | Needs |
|---|---|---|---|---|
| A1 | Store foundation: paths and the append primitive | [#76](https://github.com/baokhang83/fluencyloop/issues/76) | 1 | — |
| A2 | Record schema, documented once | [#77](https://github.com/baokhang83/fluencyloop/issues/77) | 1 | A1 |
| A3 | Loop scripts write the store, and stop writing markdown | [#78](https://github.com/baokhang83/fluencyloop/issues/78) | 2 | A2 |
| A4 | `fluencyloop knowledge` — batched session close | [#79](https://github.com/baokhang83/fluencyloop/issues/79) | 2 | A2 |
| A5 | `fluencyloop concept` — capture architectural concepts | [#80](https://github.com/baokhang83/fluencyloop/issues/80) | 2 | A2 |
| A6 | Import legacy markdown into the store | [#81](https://github.com/baokhang83/fluencyloop/issues/81) | 2 | A2 |
| A7 | `backfill` skill writes store records | [#82](https://github.com/baokhang83/fluencyloop/issues/82) | 3 | A3 |
| A8 | `check` doctor validates the store | [#83](https://github.com/baokhang83/fluencyloop/issues/83) | 2 | A2 |
| B1 | Plan skill analyses requirements and asks about gaps | [#84](https://github.com/baokhang83/fluencyloop/issues/84) | 2 | — |
| B2 | Capture requirement answers and open questions | [#85](https://github.com/baokhang83/fluencyloop/issues/85) | 3 | A2, B1 |
| C1 | Guided elicitation for the constitution | [#86](https://github.com/baokhang83/fluencyloop/issues/86) | 3 | A2 |
| D1 | Wrap-up distillations | [#87](https://github.com/baokhang83/fluencyloop/issues/87) | 3 | A5 |
| E1 | Remove mandated diagrams and the rendered-Artifact step | [#88](https://github.com/baokhang83/fluencyloop/issues/88) | 3 | — |
| F1 | Node as an optional dependency | [#89](https://github.com/baokhang83/fluencyloop/issues/89) | 2 | — |
| F2 | `fluencyloop site` — serve on a port | [#90](https://github.com/baokhang83/fluencyloop/issues/90) | 4 | A2, F1 |
| F3 | Navigation across the four levels | [#91](https://github.com/baokhang83/fluencyloop/issues/91) | 4 | F2, D1 |
| F4 | Visual design and interaction quality | [#92](https://github.com/baokhang83/fluencyloop/issues/92) | 4 | F2 |
| F5 | Model-chosen diagrams, rendered in the site | [#93](https://github.com/baokhang83/fluencyloop/issues/93) | 4 | D1, F2 |
| F6 | Managed local-site service | [#123](https://github.com/baokhang83/fluencyloop/issues/123) | 5 | F1, F2 |
| F7 | Autostart and announce the local site | [#124](https://github.com/baokhang83/fluencyloop/issues/124) | 5 | F6 |
| F8 | Keep the managed site alive for active agent sessions | [#129](https://github.com/baokhang83/fluencyloop/issues/129) | 5 | F7 |
| G1 | Release 0.3 | [#94](https://github.com/baokhang83/fluencyloop/issues/94) | 5 | everything |

### Track A — Store

**A1 · Store foundation: paths and the append primitive** · `type:infra` · S

`store_append <file> k v …` appends one compact JSON object per line, reusing the existing
`emit_json` in `plugins/fluencyloop/scripts/bash/common.sh:81` (already emits exactly the right
one-line shape) and `FlEmitJson` in `scripts/powershell/common.ps1:73`. Skips empty-valued keys so
optional fields don't bloat every line.

Paths: `docs/fluencyloop/store/features/<slug>.jsonl` — per-feature, so two branches never append
to the same file — and `docs/fluencyloop/store/concepts.jsonl`, the one global stream where
line-based merge actually earns its keep. Both runtimes, plus bats and Pester tests.

`init.sh` already pins `docs/fluencyloop/** text eol=lf` in `.gitattributes`, which append
correctness depends on; confirm it covers the new subtree.

**A2 · Record schema, documented once** · `type:infra` · S · needs A1

Envelope (`type`, `ts`, `feature`, `session`, `commit`) plus per-type payloads for `feature`,
`session`, `decision`, `component`, `condition`, `concept`, `relation`, `principle`, `requirement`,
`open_question`. One documented source of truth so the model never invents a field. Carries its own
version, following the `schema_version` precedent set in 0.2.26. Append-only means corrections
supersede on read — document that read rule, since it is the non-obvious part.

**A3 · Loop scripts write the store, and stop writing markdown** · `type:feature` · M · needs A2

`new-feature.sh`, `new-session.sh`, `add-decision.sh` emit store records. `add-decision.sh`'s field
set (`where`/`why`/`alternative`/`design`/`constitution`/`trust`) is already exactly right — it is
writing to the wrong place, not capturing the wrong thing. Session and design markdown generation is
removed. Existing files on disk are left untouched.

**A4 · `fluencyloop knowledge` — batched session close** · `type:feature` · M · needs A2

One invocation, many records: `--component "name|role|conditions"` and `--gotcha "…"`, repeatable.
Replaces the prose Knowledge-transfer section of `templates/session.md`, which already captures the
right material (components with role and conditions; hard-won conditions) in the wrong form.

**A5 · `fluencyloop concept` — capture architectural concepts** · `type:feature` · M · needs A2

The main new capture surface, and the one the whole redesign turns on. Records a concept's name, the
problem it solves *in this product*, how it works, and what realizes it; plus `relation` records for
concept↔concept, concept↔component, feature↔concept.

**A6 · Import legacy markdown into the store** · `type:feature` · M · needs A2

Parses the `## Decision:` blocks and Knowledge-transfer bullets out of existing
`docs/fluencyloop/features/*/sessions/*.md`. These are machine-generated with a rigid bullet schema
(`add-decision.sh:56-66`), so this is deterministic parsing, not interpretation.
**Read-only on originals. Idempotent. Runs automatically on first 0.3 use.** `migrate.sh` is the
precedent for shape.

**A7 · `backfill` skill writes store records** · `type:feature` · S · needs A3

Otherwise every backfilled feature is invisible to the site.

**A8 · `check` doctor validates the store** · `type:test` · S · needs A2

Unparseable lines, unknown record types, dangling relations, features with no records.

### Track B — Plan skill: requirements analysis

**B1 · Plan skill analyses requirements and asks about gaps** · `type:feature` · L

A new step in `skills/plan/SKILL.md`, before §2's architecture work: analyse the initiative intent
against the codebase and the constitution, then surface the **gaps** — requirements the intent
leaves unstated, points where it contradicts an existing explicit rule, and decisions whose
different answers lead to materially different work. Ask about those; do not ask about anything with
an obvious default, or the step becomes a tax on every plan.

The delivery mechanism already exists and must be reused, not reinvented: `SKILL.md:26-37`
"Question delivery — preserve the pause" defines `AskUserQuestion` for Claude Code and a concise
standalone chat question for Codex, and the self-report-only rule for understanding checks. Gap
questions are real technical choices, which that section already marks as valid.

Two rules make this cheap rather than ceremonial: ask **once**, batched, rather than trickling
questions through the plan; and record every gap that goes **unanswered** as an open question in the
plan rather than resolving it silently — an assumed requirement is the failure mode this step exists
to prevent.

**B2 · Capture requirement answers and open questions in the store** · `type:feature` · M · needs A2, B1

A `fluencyloop requirement` verb writing `requirement` records (the gap, the answer, the consequence
for the work) and `open_question` records (the gap, why it matters, still unanswered). This is what
lets the site answer *why is the product shaped this way* — the level above a decision's `why`, which
explains a fork inside a feature rather than the constraints the whole initiative was built under.

### Track C — Constitution

**C1 · Guided elicitation for the constitution** · `type:feature` · M · needs A2

Replaces plan `SKILL.md:156-174` §5. The model walks a fixed area set — guardrails, architecture
principles, test methodology, and the rest — and **asks** the developer their stance per area rather
than inventing one. This reverses the current explicit rule *"Never author cold"*; that rule was
written for harvest and must be rewritten, not silently contradicted. Unanswered areas stay visibly
empty rather than padded. Principles become `principle` store records so the site can link a decision
to the principle it cites, while `constitution.md` stays the numbered `§N` distillation that
decisions already reference.

### Track D — Distillation

**D1 · Wrap-up distillations** · `pillar:calibration` · `type:feature` · L · needs A5

Product overview (one per repo, refreshed only when a feature materially changes the product's
shape), feature delta (one per feature, at wrap-up), concept explanations (one per concept, revised
only when a decision contradicts it). Pitched at the developer's level via
`fluencyloop calibration show --json`. **Decisions get no distillation** — the why was taught and
captured at the moment it happened; re-synthesizing it would cost tokens to produce something worse.

### Track E — Diagrams

**E1 · Remove mandated diagrams and the rendered-Artifact step** · `type:infra` · M

Strip the class/sequence Mermaid from `templates/plan.md` and `templates/design.md`; rewrite plan
`SKILL.md:79-100` §2 to describe architecture as concepts and relationships rather than diagrams, and
drop the Artifact publication and the Markdown-preview fallback.

Scope note for whoever picks this up: this removes the *obligation* to emit two fixed diagram types
per feature. It does not remove diagrams from the product — F5 gives the model the ability to choose
one when it actually explains something. Do not read this issue as "diagrams are banned."

**Test fallout:** `tests/plugin.bats` asserts `"Mermaid source"`, `"ASCII"`, and
`"Markdown: Open Preview"` are present in the skill files. Those assertions become wrong and must
move with the change — they are currently the guard that keeps the diagrams there.

### Track F — Site

**F1 · Node as an optional dependency** · `type:infra` · S

FluencyLoop is pure bash/PowerShell today with no Node dependency. The loop must stay fully
functional without Node; only `fluencyloop site` may require it, with a clear message when it is
absent. Decide and document.

**F2 · `fluencyloop site` — serve on a port** · `type:feature` · L · needs A2, F1

Node server, code shipped in the plugin, reads the project's store and distillations. Renders per
request; no build step, no `dist/`, nothing gitignored. Default port plus conflict handling.
Personalization applied at serve time from `~/.fluencyloop/`.

**F3 · Navigation across the four levels** · `type:feature` · L · needs F2, D1

Product overview → architectural concepts → features as deltas → decisions, with each initiative's
`requirement` and `open_question` records surfaced at the level above a feature. Concept
relationships are the thing worth rendering. Static export is explicitly **out of scope** for 0.3.

**F4 · Visual design and interaction quality** · `type:feature` · L · needs F2

The site has to look genuinely good and feel responsive — this is a requirement, not polish applied
at the end, and it should be treated as its own piece of work rather than smeared across F3.

Scope: a deliberate design system (palette, type scale, two paired typefaces, spacing) carried as
tokens; light and dark handled at token level; responsive down to a laptop split-pane; motion that
serves comprehension — progressive disclosure as you descend the four levels — and respects
`prefers-reduced-motion`; keyboard navigation and visible focus throughout.

Constraint: **fully offline.** The server is localhost, but fonts, styles, and scripts must be
bundled with the plugin, not fetched. A site that breaks on a plane is not the site this is for.

**F5 · Model-chosen diagrams, rendered in the site** · `type:feature` · M · needs D1, F2

At distillation time the model decides *per subject* how it is best explained — prose, a table, or a
diagram — and when it picks a diagram, it emits the source. The site renders it. Reads as the
opposite of E1 and is not: E1 removes the template's demand for two fixed diagram types per feature;
this restores diagrams as a deliberate choice where one earns its place.

Mermaid is the obvious carrier since the model already writes it fluently, but it must be **bundled
with the plugin**, not pulled from a CDN — see F4's offline constraint. The distillation format needs
a slot for a diagram plus its caption, so define that in the same change.

**F6 · Managed local-site service** · `type:feature` · M · needs F1, F2

`fluencyloop site --ensure --json`, `--status --json`, and `--stop` manage one loopback-only,
per-repository background reader. The normal address is `http://127.0.0.1:44444`; a busy port
falls forward without touching the process that owns it. Lifecycle state is user-local, never
written to the project, validates reuse through a repository-specific health identity, and expires
after inactivity.

**F7 · Autostart and announce the local site** · `type:feature` · S · needs F6

The trusted SessionStart hook silently ensures the managed site when the session starts in an
initialized FluencyLoop repository. At the first FluencyLoop interaction, the skill reports the
actual URL once. Hook output is not relied on for the announcement; Node remains optional and
missing Node is a quiet no-op.

**F8 · Keep the managed site alive for active agent sessions** · `type:bugfix` · S · needs F7

SessionStart acquires a user-local site lease keyed by the host session, and SessionEnd releases
only that lease. The reader ignores its idle timer while one or more Claude Code or Codex sessions
remain active in the initialized project, then resumes its regular inactivity expiry after the last
session ends.

### Track G — Ship

**G1 · Release 0.3** · `type:infra` · M · needs everything

Version via `.github/scripts/bump-version.sh`, CHANGELOG, README, and an explicit migration note
covering what stops being written and what the importer does. Single fast-forward promotion
`dev` → `main`, per `RELEASING.md`.

## Sequencing

| Phase | Items | Gate |
|---|---|---|
| 1 — store | A1, A2 | nothing else can start; A2 is the schema every other track writes against |
| 2 — capture | A3, A4, A5, A6, A8 · B1 · F1 | the loop fills the store; markdown generation stops |
| 3 — meaning | A7, B2, C1, D1, E1 | the store gains the levels above a decision |
| 4 — reading | F2, F3, F4, F5, F6, F7, F8 | the site renders what phases 2–3 produced, is ready when a session opens, and is worth opening |
| 5 — ship | G1 | single fast-forward promotion `dev` → `main` |

### Critical path

**A1 → A2 → A5 → D1 → (F3 ‖ F5) → F6 → F7 → F8 → G1**

The chain runs through *meaning*, not through the server. The site's two most valuable levels — the
product overview and the architectural concepts — cannot exist until concepts are captured (**A5**)
and distilled (**D1**), and F3 renders them. F2, the Node server, is equally large but sits on a
shorter chain: it can be built in parallel against a hand-seeded store, because it only needs the
*schema* from A2, not real content. Building the server first would feel like progress and move the
finish date not at all.

Two scheduling consequences worth holding:

- **B1 is the longest item with no dependencies at all.** It is skill prose — it needs nothing from
  the store. Start it in phase 2 alongside the capture work; deferring it is the one easy way to
  accidentally pull it onto the critical path.
- **A2 is the highest-leverage item in the plan.** It is small, but every other track writes against
  it, and it is append-only — a field the schema gets wrong is a field already written to users'
  repos by the time it is noticed. It deserves more care than its size suggests.

## Verification

- `bats tests` and the Pester suite green on every issue; both runtimes move together, per the
  parity rule in `CONTRIBUTING.md`.
- Store correctness: run a real feature loop end to end on `dev`, then confirm every taught decision
  appears as exactly one line in `docs/fluencyloop/store/features/<slug>.jsonl`, and that the file is
  valid JSONL (`python3 -c "…json.loads per line…"`).
- Importer: run against this repo's own `docs/fluencyloop/`, diff the originals to prove they were
  not modified, and run it twice to prove idempotence.
- Site: `fluencyloop site` on a project with an imported store, and navigate all four levels.
- Managed site: ensure, reuse, stale-state repair, and a busy `44444` fallback without writing the
  project; then confirm SessionStart announces the resulting URL once.
- Token check: compare a wrap-up before and after **D1** — distillation must not make the loop
  measurably more expensive per feature.
