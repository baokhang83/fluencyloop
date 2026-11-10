# Plan: FluencyLoop 1.0 — shared product direction and design

started: 2026-11-10
status: Draft for iteration; implementation has not started.
baseline: 0.3.18 on dev

## Product name and flagship promise

Keep **FluencyLoop**. Fluency means that people can reason about the product they are building.
The loop connects intent, design, implementation, and learning across agent sessions. The name
supports developers and designers without tying the product to a specific coding assistant.

Proposed positioning: **Keep people and agents aligned as the product evolves.**

The flagship behavior is the agent's explanation before a meaningful change:

> This serves this product goal. These principles and prior decisions apply. I propose this
> approach because of these tradeoffs. It preserves—or deliberately revises—this part of the
> existing design.

The loop is complete only when the implemented result is reconciled with that proposal and the
shared product model is updated. Explanation and human understanding remain essential. The
primary improvement is that retained knowledge actively informs the next design decision.

## Goal & scope

- **Goal:** A fresh agent session can recover product direction and relevant design decisions,
  explain a grounded proposal, and leave a coherent current model after implementation.
- **Users:** Developers and designers working with agents and repository-owned artifacts.
  A designer can record a journey, interaction rule, terminology choice, accessibility constraint,
  or experience tradeoff without inventing a Java class or source-code implementation anchor.
- **In scope:** An authoritative product brief; stable references and decision lifecycle;
  bounded context retrieval; proposals and outcome reconciliation; changes to plan, feature,
  review, and backfill skills; a site organized around direction, current design, and decisions;
  migration, behavior evaluation, and release documentation.
- **Non-goals:** A project-management suite; hosted collaboration; Figma integration; vector
  search or a new database; automatic product strategy; comprehensive documentation of every
  code change; mandatory quizzes; new merge gates; claims that readable records prove fluency.
- **Version:** 1.0 is a proposed first stable product contract. The current version is 0.3.18,
  so 2.0 would be misleading. Do not bump runtime versions until the release task.

## Agreed direction, recommendations, and open questions

Agreed in the product discussion: retain the name; make the flagship statement central; improve
the agent's ability to design consistently toward a product vision; give the constitution and
architectural decisions greater product weight than feature inventories. The user authorized
creation of the milestone and its task issues.

This plan recommends the architecture and sequence below. A filed issue is scheduled work, not
evidence that its proposed product policy has already been approved or implemented.

Open product choices to resolve through T1 and dogfooding:

- Confirm the final positioning sentence and 1.0 release label before publication.
- Agree which changes deserve a proposal. Starting recommendation: consequential behavior,
  interaction, dependency, boundary, or principle changes; routine local fixes stay lightweight.
- Agree acceptable attention and context cost from measured baseline runs. Do not invent a
  retention benefit or a universal token/time budget before collecting evidence.

## Current position

The existing runtime already writes principles, decisions, requirements, concepts, relationships,
and explanations to an append-only store. The local site reads current records and distillations.
Feature design checks the constitution. Planning explicitly consults existing records. The
feature skill does not establish an equally explicit, bounded retrieval step for prior decisions
and product intent before each design.

The present overview describes implemented software rather than authoritative product intent.
Decision identity currently depends on feature, session, location, and title. Corrections resolve
by identity; this is not an explicit lifecycle for replacing one architectural choice with another.
The site presents features prominently and gives many small decisions similar visual weight.

The mnemo-warmup example contains useful rationale, but its overview says fetch/run remain to be
built while feature records describe implemented behavior. This is a concrete reconciliation
failure to reproduce in evaluation, not proof that all overview statements can be checked by code.

## Architecture

### Sources of authority

| Source | Question it answers | Authority and boundary |
|---|---|---|
| Product brief | Who is this for, what outcome matters, and what do we exclude? | Human-owned intent; agent amendments remain proposals until explicitly agreed. |
| Constitution | Which principles govern tradeoffs? | Explicit project rules; cite applicable rules and expose tension. |
| Current design | How does the product or experience work now? | Concepts, relationships, and inspectable evidence; distinguish planned from implemented. |
| Decision history | Why was an approach chosen, and does it still apply? | Scoped rationale, alternatives, assumptions, status, and replacement links. |
| Change proposal and outcome | How does this work serve or revise the shared model? | Bounded pre-change reasoning followed by an evidence-backed reconciliation. |

Start with one concise, versioned product brief at `docs/fluencyloop/direction.md`. Give goals and
non-goals stable anchors. The brief is the canonical source of intent. The site and agent context
read it directly; do not maintain a competing generated vision. Reference the relevant revision
when a proposal is made. Keep the existing product distillation as the explanation of current
behavior, separately labeled. An unfilled brief means direction is unknown, not agent-inferred.

Keep structured decisions and change records in the existing JSONL store. Extend the documented
schema with stable identities, explicit references, lifecycle transitions, proposals, and outcomes.
Preserve existing identifiers and historical records through a compatibility resolver. Separate
decision status from evidence trust: an agreed choice can still have an unverified rationale.
An agent's suggestion must not become a human-approved decision through a default status.

### Context assembly

Add a core CLI context operation in both Bash and PowerShell. It supplies the brief and
constitution plus a bounded selection of current decisions, concepts, and open questions.
Select deterministically from explicit references, affected areas, existing relationships, and
tags. Let the agent expand the selection with a stated reason. Semantic search is deferred.

The result includes source references and revisions, selection reasons, unresolved references,
conflicts, and omitted-context warnings. A bounded result must never claim exhaustive coverage.
One explicit resolver contract governs core retrieval and site rendering; fixtures verify parity
between the two shell runtimes and Node reader. No Node dependency enters the core workflow.

Do not silently use file traversal order or timestamps to settle conflicting branch revisions.
Specify revision/replacement relationships and deterministic handling of unresolved conflicts.
Cycles and ambiguous active successors are visible warnings, not guessed authority.

### Design and implementation flow

1. Load direction and applicable context before selecting the approach.
2. Explain the goal, applicable rules and precedents, alternatives, and preserved/revised design.
3. Record a compact proposal with references to its context. Reuse an existing goal or state
   that no agreed goal covers the request. Ask only when a missing answer materially changes work.
4. Implement in proportional slices. Use existing teaching calibration to choose explanation
   depth. Familiarity must not change technical or product authority.
5. Reconcile intended and actual behavior. Record deviations and supporting evidence. Mark a
   proposal implemented, changed, abandoned, or incomplete as appropriate; do not equate code
   completion with human approval or independently verified correctness.
6. Update affected current-design records and distillations. Propose changes to direction or
   principles separately. Preserve history and flag unresolved differences.
7. Present the resulting shared model and supporting changes in the site and review output.

The same flow covers product design artifacts. Evidence may be a repository-owned journey,
interaction specification, prototype, or design asset. Validate its path and artifact kind; do
not claim it is deployed behavior or require a source-code path merely to satisfy a schema.

### Freshness and trust

Capture which source revisions support proposals and distillations. Changed dependencies can
mark an explanation as needing review. This is a mechanical exposure signal, not semantic proof
that every dependent sentence is wrong. Show evidence checked at a revision separately from the
date a record was written. Never relabel historical evidence as verified against current code.

Backfill reconstructs history from evidence. It must not invent a contemporaneous proposal,
human approval, or original product intent. Existing records without new links remain browsable;
unknown intent and missing associations stay explicit.

### Main architectural choice

Reuse the shell-written store and local reader. Add the missing feedback loop around them.
A prompt-only change is cheaper but leaves retrieval, lifecycle, and freshness unreliable.
A new knowledge platform adds operating cost and migration risk before the behavior is proven.
The proposed approach adds structured references only where they support a real decision.

## Site impact

The primary path explains intent, current design, and consequential choices. Change history
supports those views. The site remains a local reader; intent authoring stays in files and agent
conversation during this version.

| Screen | Content and reading path | Existing material reused |
|---|---|---|
| Product | Agreed direction and non-goals; separately labeled current behavior; major flow; unresolved gaps; links into design and decisions | Product distillation plus the new brief |
| Constitution | Principles, reasons, representative applications, and explicit tensions | Principle records and references |
| Architecture | Current technical or experience model; concepts, relationships, evidence, and decision links | Architectural records and explanations |
| Decisions | Active choices first; rationale, alternatives, assumptions, evidence trust, superseded history, and affected design | Existing decisions plus lifecycle and references |
| Changes | Human-readable title, goal served, proposal, outcome, preserved/revised design, and evidence | Feature deltas, proposal/outcome records, and sessions |

Architecture and decisions are different views: one explains the current model, the other why
it took that shape. Use progressive disclosure for small implementation decisions. Do not require
a graph, chatbot, or generated diagram when a short explanation is clearer. Reuse current visual
tokens; prioritize information hierarchy over a cosmetic redesign.

Replace slug-first feature headings with human-readable titles. Keep stable URLs and identifiers
as secondary metadata. Hide empty sections, label uncertainty, and support search across direction,
concepts, decisions, and changes with navigable results. Preserve deep links or redirect them.

## Task breakdown

Sizes express relative scope, not calendar estimates. Each row becomes one feature branch and PR
against `dev`. Detailed acceptance and validation live in the linked issue.

| ID | Task | Size | Dependencies | Issue |
|---|---|---|---|---|
| T1 | Define the flagship contract and authoritative product brief | M | — | [#177](https://github.com/baokhang83/fluencyloop/issues/177) |
| T2 | Add stable record references and explicit decision lifecycle | L | T1 | [#178](https://github.com/baokhang83/fluencyloop/issues/178) |
| T3 | Assemble bounded design context in Bash and PowerShell | L | T2 | [#179](https://github.com/baokhang83/fluencyloop/issues/179) |
| T4 | Write proposals and reconciled outcomes with evidence references | M | T2 | [#180](https://github.com/baokhang83/fluencyloop/issues/180) |
| T5 | Make grounded proposals part of plan and feature workflows | M | T3, T4 | [#181](https://github.com/baokhang83/fluencyloop/issues/181) |
| T6 | Reconcile implementation and update review/backfill workflows | M | T5 | [#182](https://github.com/baokhang83/fluencyloop/issues/182) |
| T7 | Make Product and Constitution the human view of direction and principles | M | T1, T2 | [#183](https://github.com/baokhang83/fluencyloop/issues/183) |
| T8 | Separate current architecture from decision history in the site | L | T2, T7 | [#184](https://github.com/baokhang83/fluencyloop/issues/184) |
| T9 | Replace feature inventories with goal-linked changes and site-wide search | M | T4, T6, T8 | [#185](https://github.com/baokhang83/fluencyloop/issues/185) |
| T10 | Upgrade existing projects without inventing intent or rewriting history | M | T3, T4, T6 | [#186](https://github.com/baokhang83/fluencyloop/issues/186) |
| T11 | Evaluate fresh-session design behavior and dogfood developer/designer journeys | L | T6, T9, T10 | [#187](https://github.com/baokhang83/fluencyloop/issues/187) |
| T12 | Package and release the complete 1.0 experience | M | T11 | [#188](https://github.com/baokhang83/fluencyloop/issues/188) |

## Roadmap & critical path

- **A — Contract and foundations:** T1 → T2. Specify authority, identities, and reference
  resolution before extending writers or screens. Create evaluation scenarios during T1.
- **B — First working loop:** T3 and T4 → T5 → T6. Demonstrate one meaningful change in a
  fresh session with retained prior rationale and an honest reconciled result.
- **C — Human inspection:** T7 → T8 → T9. T7 can start after T2 while runtime work continues.
  Review the proposed page hierarchy using real content before implementing all views.
- **D — Adoption and evidence:** T10 → T11. T10 can start once T6 lands. Exercise both a
  populated 0.3 project and a project without an agreed product brief.
- **E — Release:** T12 after T11 provides evidence for the flagship promise and acceptable cost.

The expected critical chain is **T1 → T2 → T3 → T5 → T6 → T9 → T11 → T12**. T4 joins at
T5, T8 joins at T9, and T10 joins at T11. Relative sizes are provisional; revise the critical
path after task estimation. A polished site cannot compensate for an unproven agent loop.

## Validation and release criteria

Use deterministic fixtures for references, resolution, writers, migration, and rendering. Use
separate observed agent runs for semantic design behavior. Passing shell tests cannot establish
that an agent actually uses retrieved evidence appropriately.

Required scenarios:

1. A fresh session reuses an applicable prior decision and cites its real goal and principle.
2. A request conflicts with a principle. The agent surfaces the conflict before the dependent work.
3. A changed assumption warrants a different design. The agent proposes a revision, preserves
   history, and avoids treating the replaced decision as active context.
4. A routine local fix proceeds without a full proposal ceremony or product brief rewrite.
5. A scope change during implementation is reconciled; the final explanation matches the result.
6. A designer changes a user journey and records an experience tradeoff with valid artifact evidence.
7. A legacy project has no agreed direction. The agent exposes the gap without inventing a vision.
8. A record is reconstructed after merge. Its inferred rationale and provenance remain explicit.
9. An overview retains the mnemo-warmup fetch/run contradiction. Closure corrects the overview or
   reports the unresolved discrepancy; a new timestamp alone cannot count as correction.
10. Concurrent changes leave ambiguous successors or missing references. All readers expose the
    ambiguity consistently, without silently selecting a convenient active decision.

Run representative sessions in Claude Code and Codex. Save person-neutral evidence, observed
failures, record counts, context size, extra interactions, and time spent on the loop. Compare with
the 0.3 baseline. Agree release thresholds from the pilot before making marketing claims.

The release needs green Linux/Git Bash Bats, native-Windows Pester, ShellCheck/PSScriptAnalyzer,
Node-optional checks, schema/compatibility fixtures, and relevant site/browser checks. Validate
navigation, readable layouts, keyboard interaction, and honest empty/conflict/stale states.

## Compatibility, constraints, and constitution check

The repository constitution is currently an unfilled template. This draft does not turn
recommendations into developer-approved constitutional principles.

Existing documented constraints remain applicable:

- `CONTRIBUTING.md`: Node stays optional for the core loop. Implement core changes in Bash and
  PowerShell under the same observable contract.
- Existing store contract: preserve append-only history and legacy Markdown inputs. Migration
  must be idempotent and retain provenance; avoid retroactive intent or approval claims.
- Privacy model: calibration remains private and local. Shared records describe the product and
  work, never a person's inferred competence.
- Human authorship: propose material changes to intent and principles; do not silently ratify them.
- Proportionality: the new workflow surfaces conflicts without adding a merge gate or requiring
  a full design ceremony for routine edits.
- `RELEASING.md`: build on `dev`. Promotion to `main` distributes the new plugin through startup
  updates, so release only the complete experience with compatibility behavior in place.

T10 must distinguish a runtime update from a project data upgrade. Do not make historical
enrichment or semantic reconstruction a compulsory startup task. Specify behavior for old records,
partial upgrades, and recoverable failures before release. Keep copies of original data available
where a migration adds metadata. Document forward recovery; do not promise client pinning or a
rollback capability the current updater does not provide.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Plausible goal citations disguise weak product reasoning | Inspect semantic behavior in observed runs, including deliberately irrelevant goals. |
| Retrieval omits the important prior choice | Show selection reasons and omissions; permit bounded expansion; test known missed-decision cases. |
| Old decisions freeze the design | Capture scope and assumptions; support explicit reconsideration and replacement. |
| Record volume overwhelms humans and agents | Select consequential choices, bound context, and progressively disclose detail. |
| Direction and implemented behavior drift | Keep authority distinct; reconcile outcomes and expose changed supporting references. |
| Designer support becomes a label on code-only records | Include a genuine journey/specification scenario and typed artifact evidence. |
| Two runtimes and the site disagree | Share contract fixtures for identity, lifecycle, and current-context resolution. |
| An automatic update ships a partial transition | Integrate on dev and promote only after runtime, site, migration, and observed runs agree. |

## Tickets

Milestone: [1.0 — shared product direction and design](https://github.com/baokhang83/fluencyloop/milestone/3).

All 12 issues are linked in the task table. Each includes rationale, scope, dependencies, acceptance
criteria, validation, starting implementation paths, and shared constraints. Issues are planning
artifacts; no feature implementation or release has started.

## First delivery

Start with T1, then prove T2–T6 on one meaningful change before completing the site transition.
Use the flagship statement as the review lens for every task. Preserve FluencyLoop's teaching
strength while making the retained knowledge change what the next agent actually does.
