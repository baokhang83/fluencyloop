---
name: plan
description: 'FluencyLoop planning stage. Plan a large chunk of work before building it: design and document the overall architecture, break it into task items, sequence them into a roadmap with a critical path, and (optionally) open GitHub issues under a milestone. Produces a committed plan.md that the per-feature loop then builds from — one fluencyloop-feature per task item. Use when the work is too big for a single feature/branch, or when the user says "fluencyloop plan", "plan this", "design the architecture for", "break this down", or "make a roadmap".'
---

# fluencyloop-plan — map a big chunk before you build it

Sits **upstream of `fluencyloop-feature`**. A *feature* is one branch; a **plan** is an
*initiative* that will spawn several features. You will: (1) frame the chunk, (2) analyse
requirements and surface material gaps, (3) design and show the overall architecture, (4) break
it into task items, (5) sequence them into a roadmap with a critical path, (6) offer to open
GitHub tickets under a milestone, (7) hand each task off to `fluencyloop-feature`. The plan is a
**map you build against, not a spec to ratify** —
do not over-invest. Keep the developer the architect.

## Bundled CLI (Claude Code)

Before invoking a deterministic command, use this plugin's bundled launcher:
`"${CLAUDE_PLUGIN_ROOT}/bin/fluencyloop" <arguments>`. Every `fluencyloop …` command below
means that exact Bash-tool command; it is never a chat instruction or a globally installed
command.

Do not hand-scaffold `.fluencyloop/`, `.claude/skills/`, designs, sessions, state, or helper
scripts. The bundled CLI creates the deterministic files and returns their paths.

## Local site — open once

Before the first user-visible response, invoke
`"${CLAUDE_PLUGIN_ROOT}/bin/fluencyloop" site --ensure --open-once --json`. This ensures the
reader for every workflow entry, but opens a browser tab only once while that managed reader is
alive. If it reports `running: true` and no earlier assistant message in this session starts with
`FluencyLoop site:`, say `FluencyLoop site: <url> (opened in browser).` once, using its returned
URL. Do not mention an unavailable site or repeat the announcement.

## Generated prose — ASD-STE100

Write generated user-facing technical prose in ASD-STE100 style: use short, direct sentences,
active voice, one main action per sentence, and stable, unambiguous terms. Preserve product names,
code identifiers, CLI commands, field names, and exact recorded values. Do not claim formal
ASD-STE100 compliance: that requires checking the official controlled dictionary and rules.

## Question delivery — preserve the pause

For a real answer, choice, or confirmation, use **`AskUserQuestion` in Claude Code**. Codex has
no equivalent question-form tool, so ask a concise standalone question in chat and stop; do not
create issues, write a settled choice, or advance the workflow until the developer answers.

**Understanding checks are self-report, never quizzes.** After teaching, ask only whether the
developer understands and whether anything needs clarification: *"Do you understand this
explanation, or should I clarify anything?"* Then trust their answer. Never ask them to prove
understanding by restating the mechanism, explaining it "in your own words," predicting behavior,
selecting an answer, or answering any other topic-specific question. Familiarity probes before
teaching and real technical choices remain valid, but they are not learning verification.

## 0. Preconditions

Run the bundled `fluencyloop check --json` and parse its output. If `git_repo` or `fluency` is
false, run the bundled `fluencyloop init --json` without asking the developer. It initialises Git
in the current project directory when needed, then creates FluencyLoop's state. Parse its
`docs_dir`, and verify that it is the repository's `docs/fluencyloop` directory before
continuing. Only stop if `init` itself fails. Do not hand-create `.fluencyloop`, `docs`, or
`.claude/skills`.

**Migrate imported history before planning.** Parse `legacy_migration_pending` from the bundled
`fluencyloop check --json` before reading the constitution, calibration, requirements, or the
initiative intent. When it is `true`, do not ask the developer anything or scaffold a plan. This
is an automatic, repository-wide migration. Build its architectural record map up front without
opening every historical feature separately:

1. Run `fluencyloop import --assess-unconfirmed`. This records one unconfirmed assessment for each
   imported feature; legacy Markdown is not independent verification.
2. Run `fluencyloop import --semantic-map` once. Review that compact repository map rather than
   reading all imported feature directories one by one.
3. Add only shared, evidence-backed architectural records and relations from the map with
   `fluencyloop concept --feature <representative-slug> --session 000-legacy-import`. Reuse records,
   add one to three familiar, filter-useful tags to **every** record, and do not invent one per
   feature. The map lists existing records: append a replacement for each legacy record with
   missing tags, keeping its name and complete fields and adding tags. This is append-only. Do not
   mark the migration complete while `tagged_architectural_records` is zero.
4. Run `fluencyloop import --semantic-status --json`; once it reports an architectural record, run
   `fluencyloop import --mark-semantic-complete` and then `fluencyloop check --json`. Continue to
   planning only when `legacy_migration_pending` is `false`.

**Read the constitution up front** — `docs/fluencyloop/constitution.md`, and **if it's a pointer**
(a `Source of truth:` line naming another file, e.g. `.specify/memory/constitution.md`), read
*that* file. The architecture you design in §2 is checked against it. If it's still the **empty
stub**, this plan is where the constitution is born — see §5.

**Load the learner's knowledge base** — parse it via `fluencyloop calibration show --json` (a
`dimension → level` map, level ∈ {`fluent`, `familiar`, `learning`, `new`}; per-developer, global,
never committed) — to set the depth you explain architectural choices at. Missing is fine.
Planning is also teaching: the same "teach the why, ask whether it is understood, don't lecture"
posture from `fluencyloop-feature` applies to the architecture decisions here. Apply the
self-report-only rule above to every architecture explanation.

Is this actually a plan? If the work fits one branch, skip straight to `fluencyloop-feature` —
don't manufacture an initiative. Plans are for chunks that genuinely decompose into several
features.

## 1. Frame the chunk

Take the user's initiative intent and scaffold the plan doc:

```bash
fluencyloop plan --json "<intent>"
```

This creates `docs/fluencyloop/plans/<slug>/plan.md` from the template **on the current branch**
(a plan is a committed doc, not a branch). Parse the JSON for `slug`, `plan_dir`, `plan`.

Nail down **goal, in-scope, and non-goals** with the user before designing — a plan's value is
mostly in what it excludes. Fill the `## Goal & scope` section from that exchange.

## 1.5 Requirements analysis — surface material gaps

Before §2, analyse the initiative intent against all three sources of evidence:

- **The codebase** — the relevant existing behavior, boundaries, and conventions.
- **The constitution** — including the source file behind a `Source of truth:` pointer, as read
  in §0.
- **The store** — the existing records under `docs/fluencyloop/store/`, which may capture
  established concepts, decisions, requirements, and open questions that the intent does not
  repeat.

Identify only gaps whose answer would materially change the work. Name the category for each:

1. **Unstated requirements** — work the intent implies but never names.
2. **Contradictions with an existing explicit rule** — the intent requires something the codebase,
   constitution, or a skill file currently forbids. These are the highest-value gaps: changing
   the rule is a decision, not a quiet violation.
3. **Forks whose different answers lead to materially different work** — real technical choices,
   not preferences with an obvious default.

Do **not** ask about anything with an obvious default. This is a focused analysis pass, not a
ritual that turns every plan into a questionnaire.

### Ask once, then design

Reuse **Question delivery — preserve the pause** above; do not invent a second delivery
mechanism. Gap questions are real technical choices. Ask all material gaps **once, batched** in
one round, then continue to §2 with the answers. Do not trickle questions through architecture,
decomposition, and roadmap work.

If the developer explicitly leaves a gap unanswered, or directs you to proceed without resolving
it, add it to `## Open questions` in `plan.md` with why it matters. Never resolve an unanswered gap silently or convert it into an assumed requirement.

Record the same outcome in the store exactly once per gap. For each answer the developer provides,
run:

```bash
fluencyloop requirement --gap "<what was unstated or conflicted>" \
  --answer "<the developer's decision>" \
  --consequence "<what it changes about the work>"
```

For each explicitly unanswered gap, run:

```bash
fluencyloop requirement --open "<the unresolved gap>" \
  --matters "<why leaving it open matters>"
```

When a later planning round resolves an earlier open question, append the answered
`requirement` for the same gap. Never edit or delete the earlier `open_question`; readers
supersede it on read.

## 2. Design the architecture — concepts and relationships at initiative altitude

Draft the **big concepts**: the components/modules, their boundaries and relationships, and the
main flow(s). This is coarser than feature-level implementation detail — the load-bearing structure
the features will fill in.

Architecture is a model of concepts and relationships, not a fixed visual form. Capture the
reasoning directly in `plan.md` under `## Architecture`: name the concepts, state how they connect
or depend on one another, and describe the important flow and choice. A small relationship table
is fine when it is clearer than prose.

Do not require class or sequence diagrams, publish a rendered artifact, or direct the developer to
a preview. Diagrams are not banned: F5 may later choose one for the site when it genuinely explains
the subject better than prose or a table. Check the concepts and relationships against the
constitution; if one conflicts with a principle, say so plainly in `## Constitution check`. Refine
once with the user's input, then move on.

When the plan genuinely establishes or changes an architectural concept a new joiner would need
explained, capture it in the global stream — not as a once-per-plan ritual and not for ordinary
component inventory:

```bash
fluencyloop concept --name "<concept>" --problem "<product-specific problem>" --how "<how it works>" --realized-by "<component|file|area>" [--realized-by "<...>" ...]
fluencyloop concept --relate "<from>|<to>|<kind>"
```

Use a later record with the same name to refine it as the implementation teaches more; relations
may connect concepts to other concepts, components, or planned features.

## 3. Break it into task items

Decompose the initiative into **task items — each a future `fluencyloop-feature`**. For each,
capture in the `## Task breakdown` table: an `id` (T1, T2, …), a slug-able **intent**, a rough
**size** (S/M/L), and its **dependencies** (by id). Aim for items that are independently
build-and-mergeable. Keep them coarse; a task that's really two features is two rows.

## 4. Sequence — roadmap & critical path

Order the tasks by dependency into `## Roadmap & critical path`:

- **Milestones / phases** — group tasks into shippable chunks in dependency order.
- **Critical path** — the longest chain of dependent tasks; the sequence that sets the earliest
  finish. Call it out explicitly (`T1 → T3 → T6`) so it's scheduled first and watched. Teach
  *why* it's the critical path — that's an architectural insight worth the developer holding.

## 5. Elicit the constitution — every project needs a stated position

Read `docs/fluencyloop/constitution.md`. If it contains a `Source of truth:` pointer, leave
that pointer in place and amend the cited source instead, following its conventions. In particular,
amend SpecKit's `.specify/memory/constitution.md` rather than forking a second constitution; keep
its version and Sync Impact Report conventions intact. Otherwise amend the existing local
constitution in place — whether it is the empty stub or already has principles.

Raise the following **fixed areas**. The model raises each area; it never supplies the stance.
Ask the developer for their position on every area in one clearly labelled, batched set of
questions, using **Question delivery — preserve the pause** above:

1. **Guardrails** — what must never happen in this codebase?
2. **Architecture principles** — which boundaries, coupling, or layering rules matter?
3. **Test methodology** — what must be tested, and how, before work is done?
4. **Data and state** — what is persisted, derived, or never stored?
5. **Dependencies** — what earns a new dependency?
6. **Security and privacy** — what never leaves the machine or is never committed?

Do not infer, fill, or soften an answer from the architecture, existing code, or general best
practice. A question with no answer is still useful: retain that area in `constitution.md` as
`_No stance recorded yet._` so the gap stays visible. Do not pad it with a platitude.

For every developer-stated stance, distill only what they supplied into a checkable principle:
a short title, a non-negotiable `rule`, and the failure its `why` prevents. Append it to the
active constitution under `## Principles` using the next matching citation `§N`, then append
the same values to the store:

```bash
fluencyloop principle --number "§N" --title "<title>" --rule "<developer-stated rule>" --why "<failure it prevents>"
```

The Markdown citation and record `number` must match exactly. Later corrections append another
`principle` record with the same number; do not rewrite the earlier JSONL line. The constitution
may grow from later decisions, but the model must always ask rather than invent a new stance.

## 6. GitHub tickets — create them live, or offer a one-time `gh` setup

Check `gh auth status` **first**:

- **`gh` is available and authed** — offer to turn the task breakdown into **GitHub issues under a
  milestone** (one issue per task item; the milestone is the initiative), confirmed **per plan**:
  *"Create these N issues + the '<initiative>' milestone now?"* On yes, create the milestone then
  the issues (title = task intent, body = intent + dependencies, `--milestone` set) and record the
  links back into `plan.md` under `## Tickets`.

- **`gh` is missing or unauthed** — this is worth a **one-time** setup offer, because `gh` unlocks
  real automation. Check `~/.fluencyloop/preferences.md` for a settled `gh-setup` choice:
  - **Not settled yet** — offer **once** using the delivery rule above, and *sell what it unlocks*: with
    `gh`, FluencyLoop files your whole task breakdown as GitHub issues under a milestone **for you**,
    and opens prepopulated PRs at review — instead of you running commands by hand. Frame it so
    **yes** is the easy call, e.g. *"Want me to set up `gh` so I can file these N tasks as issues +
    a milestone for you? One-time — I won't ask again."* Options: **Yes, set it up** *(recommended,
    list first)* / **Not now**. Record the answer to `preferences.md` as `gh-setup: done` or
    `gh-setup: declined`, and **never ask again**.
    - On **yes** — install `gh` the way that fits **their** OS. Don't work from a hardcoded list of
      package managers (it rots); the canonical, always-current installer for every platform is
      <https://cli.github.com> — point there and pick the obvious command for their environment.
      Then `gh auth login` (uniform everywhere), and create the issues + milestone.
    - On **not now** — write the runnable `gh issue create …` commands into `## Tickets` and move on.
  - **Already `declined`** — don't re-offer; just save the runnable commands to `## Tickets`.

The plan is complete either way — no friction.

## 7. Hand off to the build loop

The plan is the map; each task item is built with **`fluencyloop-feature`** (one branch per
task, from the active development branch — `dev` for the 0.3 milestone), in roadmap order along
the critical path first. Tell the user that — and that
`fluencyloop-review` assembles each feature's PR view when it's done. Do not open feature
branches yourself here; §7 hands off, it doesn't build.

## Rules

- **A map, not a spec.** Don't over-invest — the plan is a shape to build against; the features
  are where it's ratified. Refine once, then start building.
- **Never gate.** Flag where the architecture tensions a principle; never block. A plan is
  advisory scaffolding, not an approval checkpoint.
- **The developer stays the architect.** Teach the architecture and the critical path so they
  hold them; do not take authorship. Set depth from the calibration profile (§0).
- **Tickets are opt-in, per plan.** Ask before touching `gh`; fall back to a runnable script if
  `gh` is unavailable or declined.
- **Person-neutral, like the rest of the loop.** `plan.md` is committed — record the work, never
  anyone's competence. Per-developer knowledge stays only in `~/.fluencyloop/` (uncommitted).
