# Plan: FluencyLoop 1.0 — shared product direction and design

started: 2026-11-10
status: Draft for iteration; implementation has not started.
baseline: 0.3.18 on dev

## Product name and flagship promise

Keep **FluencyLoop**. Fluency means that people can reason about the product they are building.
The loop connects intent, design, implementation, and learning across agent sessions. The name
supports developers and designers without tying the product to a specific coding assistant.

Proposed positioning: **Stay fluent as people and agents evolve the product.**

The flagship describes the reasoning the agent must perform for consequential design choices:

> This serves this product goal. These principles and prior decisions apply. I propose this
> approach because of these tradeoffs. It preserves—or deliberately revises—this part of the
> existing design.

Its visible expression is proportional to the decision and the person's needs. Incorporate it
into the existing design explanation; do not recite the whole statement before every change.
At a natural completion boundary, reconcile the result and update the affected shared model.
People must remain able to understand, challenge, and change the design. Agent consistency
alone is not success.

## Interaction contract — preserve the strong principles

> Use retained product reasoning automatically. Explain consequential choices at the right depth.
> Recommend a path. Continue within agreed intent. Ask when human judgment is needed. Update the
> shared model at natural boundaries.

- **Recommend and continue:** Within authorized scope and agreed intent, state the recommended
  approach and its useful reason, then act. Existing authorization also covers its necessary
  implementation decisions. Do not request separate approval for a proposal record or routine
  choice. A recommendation is not an unranked menu of options.
- **Ask only for consequential unresolved judgment:** Batch independent material questions at
  the next useful boundary, include a recommendation, and reuse settled answers and preferences.
  Wait for an answer before dependent work. Continue independent work where possible. An explicit
  instruction that already resolves the choice does not need another confirmation.
- **Documentation is advisory:** Missing goals, unreviewed records, stale prose, broken historical
  links, and incomplete metadata do not by themselves block implementation or delivery. Ask only
  if the underlying uncertainty changes the requested work. Surface unrelated exposure briefly
  at handoff or in the site; do not demand a cleanup session.
- **No direction-document prerequisite:** Use the user's expressed intent and available evidence.
  Offer a brief distilled from that conversation at a natural boundary. Record uncertainty
  honestly; do not invent a goal or require a strategy workshop before ordinary work.
- **Explain without adding a checkpoint:** Use calibration and expressed needs for depth. Familiar
  work gets a short reason; routine edits need no flagship recital. Unknown familiarity does not
  mean fluent and does not automatically trigger a blocking probe or comprehension confirmation.
  A person who requests guided learning can choose deliberate teaching pauses. Preserve that
  preference, trust self-report, and never quiz or infer engagement from silence.
- **Capture once:** Link the existing design rationale and record only deviations at closure.
  Scripts assemble mechanical views. Distill once at wrap-up; do not duplicate rationale across
  proposals, decisions, outcomes, feature deltas, and review prose.
- **Prove value before machinery:** T1 runs a small pilot using existing records before new
  lifecycle/runtime infrastructure. Use the results to retain, narrow, or defer later tasks.

This explicitly resolves inherited tension between staying out of the way and the current
skills' automatic familiarity probes and mandatory understanding checks. T5 changes those rules
in both distributions; current runtime/skill behavior is not changed by this planning PR.

## Goal & scope

- **Goal:** A fresh agent session can recover product direction and relevant design decisions,
  recommend a grounded approach without unnecessary interruption, and leave a coherent current
  model after implementation that the person can understand and challenge.
- **Users:** Developers and designers working with agents and repository-owned artifacts.
  A designer can record a journey, interaction rule, terminology choice, accessibility constraint,
  or experience tradeoff without inventing a Java class or source-code implementation anchor.
- **In scope:** An authoritative product brief; stable references and decision lifecycle;
  bounded context retrieval; proposals and outcome reconciliation; changes to plan, feature,
  review, and backfill skills; a site organized around direction, current design, and decisions;
  migration, behavior evaluation, and release documentation.
- **Non-goals:** A project-management suite; hosted collaboration; Figma integration; vector
  search or a new database; automatic product strategy; comprehensive documentation of every
  code change; mandatory quizzes; new implementation or merge approval gates; mandatory product
  briefs; claims that readable records prove fluency.
- **Version:** 1.0 is a proposed first stable product contract. The current version is 0.3.18,
  so 2.0 would be misleading. Do not bump runtime versions until the release task.

## Agreed direction, recommendations, and open questions

Agreed in the product discussion: retain the name; make the flagship statement central; improve
the agent's ability to design consistently toward a product vision; give the constitution and
architectural decisions greater product weight than feature inventories. The user authorized
creation of the milestone and its task issues. The subsequent principle review established the
interaction contract above: preserve flow, recommend and continue within authorized intent,
avoid duplicated capture, and pilot the behavior before committing to more machinery.

This plan recommends the architecture and sequence below. A filed issue is scheduled work, not
evidence that its proposed product policy has already been approved or implemented.

Open product choices to resolve through T1 and dogfooding:

- Confirm the final positioning sentence and 1.0 release label before publication.
- Tune explanation/capture thresholds from the pilot. Consequential choices need grounded
  reasoning; this is not a new mandatory approval stage or fixed speech template.
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
| Product brief | Who is this for, what outcome matters, and what do we exclude? | Human-owned intent; draft from expressed intent. Material new direction needs human judgment unless already authorized. Absence does not block work. |
| Constitution | Which principles govern tradeoffs? | Explicit project rules; cite applicable rules and expose tension. |
| Current design | How does the product or experience work now? | Concepts, relationships, and inspectable evidence; distinguish planned from implemented. |
| Decision history | Why was an approach chosen, and does it still apply? | Scoped rationale and replacement links. Distinguish delegated agent choices from separately confirmed human choices; both can be valid working decisions. |
| Design rationale and outcome | How does this work serve or revise the shared model? | Reuse existing explanation; capture deviations at natural closure without another approval stage. |

When useful, distill one concise, versioned product brief at `docs/fluencyloop/direction.md` from
the user's expressed intent and existing agreements. Offer it at a natural boundary. Give goals and
non-goals stable anchors. The brief is the canonical source of intent. The site and agent context
read it directly; do not maintain a competing generated vision. Reference the relevant revision
when a proposal is made. Keep the existing product distillation as the explanation of current
behavior, separately labeled. An unfilled brief means direction is unknown, not agent-inferred.

Keep structured decisions and change records in the existing JSONL store. Extend the documented
schema with stable identities, explicit references, lifecycle transitions, proposals, and outcomes.
Preserve existing identifiers and historical records through a compatibility resolver. Separate
decision status from evidence trust: an agreed choice can still have an unverified rationale.
An agent's choice within delegated scope can be active without a separate human-approval event.
Preserve that provenance; do not relabel it as human-approved. Product or principle changes
outside current authorization need human judgment, not a default approval status. Add only the
fields the pilot justifies; missing lifecycle metadata must not freeze normal work.

### Context assembly

Add a core CLI context operation in both Bash and PowerShell. It supplies the brief and
constitution plus a bounded selection of current decisions, concepts, and open questions.
Select deterministically from explicit references, affected areas, existing relationships, and
tags. Let the agent expand the selection with a stated reason. Semantic search is deferred.

Reuse unchanged context within an active task. Refresh when intent, relevant files (including
uncommitted edits), principles, or referenced decisions change. Do not key freshness solely to
HEAD or repeatedly reload the whole model at every slice. Keep refresh metadata mechanical.

The result includes source references and revisions, selection reasons, unresolved references,
conflicts, and omitted-context warnings. A bounded result must never claim exhaustive coverage.
One explicit resolver contract governs core retrieval and site rendering; fixtures verify parity
between the two shell runtimes and Node reader. No Node dependency enters the core workflow.

Do not silently use file traversal order or timestamps to settle conflicting branch revisions.
Specify revision/replacement relationships and deterministic handling of unresolved conflicts.
Cycles and ambiguous active successors are visible warnings, not guessed authority.

### Design and implementation flow

1. Load or reuse applicable context automatically. Missing direction is an explicit unknown.
2. At the existing design boundary, explain the consequential reasoning at the right depth and
   recommend a path. Reference actual goals and precedents when they exist; never fabricate them.
3. Continue within authorized intent. Ask only for consequential unresolved judgment, with a
   recommendation. Record the existing rationale once; do not create a separate approval exchange.
4. Implement in proportional slices. Teach useful choices in context without repeating the
   proposal. Calibration changes explanation depth, never technical or product authority.
5. At natural completion, link the rationale and record actual deviations and outcome state.
   Do not rewrite unchanged reasoning or imply human approval/verified correctness from completion.
6. Update affected current-design records and distill once at wrap-up. Apply already-authorized
   direction changes; raise genuinely new direction choices together at a useful boundary.
7. Let the site and review assemble the human view from those records. Unrelated documentation
   gaps remain advisory rather than blocking completion of the requested work.

The same flow covers product design artifacts. Evidence may be a repository-owned journey,
interaction specification, prototype, or design asset. Validate its path and artifact kind; do
not claim it is deployed behavior or require a source-code path merely to satisfy a schema.

### Freshness and trust

Capture which source revisions support proposals and distillations. Changed dependencies can
mark an explanation as needing review. This is a mechanical exposure signal, not semantic proof
that every dependent sentence is wrong. Show evidence checked at a revision separately from the
date a record was written. Never relabel historical evidence as verified against current code.
Keep such exposure passive by default. A changed source reference does not automatically create
a user question or demand immediate prose repair.

Backfill reconstructs history from evidence. It must not invent a contemporaneous proposal,
human approval, or original product intent. Existing records without new links remain browsable;
unknown intent and missing associations stay explicit.

### Main architectural choice

Pilot the feedback loop using the existing store, skills, and a short direction note first.
This establishes behavior and cost before expanding the data model. Retain the shell-written
store and local reader for the durable implementation. Add retrieval, references, and lifecycle
only where observed failures justify them. A new knowledge platform remains outside scope.

## Site impact

The primary path explains intent, current design, and consequential choices. Change history
supports those views. The site remains a local reader; intent authoring stays in files and agent
conversation during this version.

The site helps a person understand and challenge the design. It is optional to open during work.
Do not turn it into a compliance dashboard with approval badges, completeness scores, blocking
warnings, or mandatory tasks to repair the knowledge base. Missing intent is a useful empty state,
not failed onboarding. Expose uncertainty and provenance on inspection without recurring nags.

| Screen | Content and reading path | Existing material reused |
|---|---|---|
| Product | Agreed direction and non-goals; separately labeled current behavior; major flow; unresolved gaps; links into design and decisions | Product distillation plus the new brief |
| Constitution | Principles, reasons, representative applications, and explicit tensions | Principle records and references |
| Architecture | Current technical or experience model; concepts, relationships, evidence, and decision links | Architectural records and explanations |
| Decisions | Active choices first; rationale, alternatives, assumptions, evidence trust, superseded history, and affected design | Existing decisions plus lifecycle and references |
| Changes | Human-readable title, intent/goal when known, actual change, deviations, and preserved/revised design; rationale on demand | Existing feature deltas and linked decision/outcome evidence |

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
| T1 | Pilot recommendation-first design and define the flow contract | M | — | [#177](https://github.com/baokhang83/fluencyloop/issues/177) |
| T2 | Add stable record references and explicit decision lifecycle | L | T1 | [#178](https://github.com/baokhang83/fluencyloop/issues/178) |
| T3 | Assemble bounded design context in Bash and PowerShell | L | T2 | [#179](https://github.com/baokhang83/fluencyloop/issues/179) |
| T4 | Link existing design rationale and capture outcome deviations once | M | T2 | [#180](https://github.com/baokhang83/fluencyloop/issues/180) |
| T5 | Recommend and continue within authorized intent in plan and feature workflows | M | T3, T4 | [#181](https://github.com/baokhang83/fluencyloop/issues/181) |
| T6 | Reconcile implementation and update review/backfill workflows | M | T5 | [#182](https://github.com/baokhang83/fluencyloop/issues/182) |
| T7 | Make Product and Constitution the human view of direction and principles | M | T1, T2 | [#183](https://github.com/baokhang83/fluencyloop/issues/183) |
| T8 | Separate current architecture from decision history in the site | L | T2, T7 | [#184](https://github.com/baokhang83/fluencyloop/issues/184) |
| T9 | Replace feature inventories with goal-linked changes and site-wide search | M | T4, T6, T8 | [#185](https://github.com/baokhang83/fluencyloop/issues/185) |
| T10 | Upgrade existing projects without inventing intent or rewriting history | M | T3, T4, T6 | [#186](https://github.com/baokhang83/fluencyloop/issues/186) |
| T11 | Evaluate fresh-session design behavior and dogfood developer/designer journeys | L | T6, T9, T10 | [#187](https://github.com/baokhang83/fluencyloop/issues/187) |
| T12 | Package and release the complete 1.0 experience | M | T11 | [#188](https://github.com/baokhang83/fluencyloop/issues/188) |

## Roadmap & critical path

- **A — Evidence before foundations:** T1 is a small observed pilot, not only a contract-writing
  task. Use existing records and a short direction note. Cover an authorized feature, a routine
  fix, a designer change, and a genuinely unresolved choice in fresh sessions. Compare with 0.3;
  measure useful reasoning, human understanding, interruption count, and context/attention cost.
  Record a proceed/narrow/defer recommendation before T2. Revise downstream scope from the results.
- **B — Justified foundations and working loop:** T2 → T3 and T4 → T5 → T6. Specify only the
  authority, identities, and references the pilot shows are needed. Demonstrate recommendation,
  delegated action, and natural closure without an extra approval workflow.
- **C — Human inspection:** T7 → T8 → T9. T7 can start after T2 while runtime work continues.
  Review the proposed page hierarchy using real content before implementing all views.
- **D — Adoption and evidence:** T10 → T11. T10 can start once T6 lands. Exercise both a
  populated 0.3 project and a project without an agreed product brief.
- **E — Release:** T12 after T11 provides evidence for the flagship promise and acceptable cost.

The expected critical chain is **T1 → T2 → T3 → T5 → T6 → T9 → T11 → T12**. T4 joins at
T5, T8 joins at T9, and T10 joins at T11. Relative sizes are provisional; revise the critical
path and task scope after the early pilot. T11 is the full regression evaluation, not the first
evidence of value. A polished site cannot compensate for an unproven agent loop.

## Validation and release criteria

Use deterministic fixtures for references, resolution, writers, migration, and rendering. Use
separate observed agent runs for semantic design behavior. Passing shell tests cannot establish
that an agent actually uses retrieved evidence appropriately.

Required scenarios:

1. A fresh session reuses applicable prior reasoning, recommends a grounded approach, and
   continues authorized work without asking for a separate proposal approval.
2. A request conflicts with a principle. The agent surfaces the conflict before the dependent work.
3. A changed assumption warrants a different design. The agent proposes a revision, preserves
   history, and avoids treating the replaced decision as active context.
4. A routine local fix proceeds without a full proposal ceremony or product brief rewrite.
5. A scope change during implementation is reconciled; the final explanation matches the result.
6. A designer changes a user journey and records an experience tradeoff with valid artifact evidence.
7. A legacy project has no brief. The agent uses expressed intent and proceeds where sufficient;
   it neither invents a vision nor requires a strategy workshop or documentation cleanup.
8. A record is reconstructed after merge. Its inferred rationale and provenance remain explicit.
9. An overview retains the mnemo-warmup fetch/run contradiction. Closure corrects the overview or
   reports the unresolved discrepancy; a new timestamp alone cannot count as correction.
10. Concurrent changes leave ambiguous successors or missing references. All readers expose the
    ambiguity consistently, without silently selecting a convenient active decision.
11. A person can locate, understand, and challenge a consequential design choice in the site
    without reading the original conversation. Approval counts cannot substitute for this.
12. A familiar task gets concise reasoning; unknown familiarity does not force a probe or
    comprehension checkpoint. Requested guided learning remains supported without quizzes.
13. A genuine unresolved choice receives a recommendation and a batched question; the agent
    waits only on dependent work and does not re-ask a choice the user already settled.
14. Missing references and unrelated stale documentation remain advisory. Unchanged rationale
    and context are reused rather than repeatedly summarized or loaded at each slice.

Run representative sessions in Claude Code and Codex. Save person-neutral evidence, observed
failures, record counts, context size, extra interactions, and time spent on the loop. Compare with
the 0.3 baseline. Count forced pauses and repeated questions separately from useful explanations.
Record whether the person could follow and challenge the design; never infer learning from
silence or journal volume. Agree release thresholds from T1 before making marketing claims.

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
- Human authorship: honor authorized intent, including explicit revisions; ask only for new
  consequential judgment. Record delegated agent decisions without inventing human approval.
- Proportionality: no new approval gate for implementation or merge. Explain and recommend at
  useful boundaries; missing documentation alone cannot hold the work hostage.
- Teaching: preserve useful calibrated explanation and private preferences. T5 deliberately
  replaces automatic blocking familiarity/understanding checks with the interaction contract;
  deliberate learning pauses remain available when requested.
- Efficiency: reuse context until relevant inputs change, capture rationale once, generate
  mechanical views, and distill only at wrap-up. T1 proves benefit before infrastructure grows.
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
| Proposals become repeated approval requests | Continue delegated work; ask only for unresolved human judgment and reuse settled answers. |
| Knowledge gaps block ordinary implementation | Keep absent briefs, missing links, and stale prose advisory unless the underlying ambiguity changes the work. |
| People become spectators of consistent agent output | Evaluate understanding and ability to challenge design alongside agent behavior. |
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

Start with T1's observed pilot using existing artifacts before committing to T2–T6 infrastructure.
Review its proceed/narrow/defer recommendation and adjust later issues. Keep the flagship as the
reasoning lens, with a concise visible recommendation at the existing design boundary. The loop
must improve design and human fluency without inserting a new approval ritual into normal work.
