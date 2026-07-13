---
name: fluencyloop-plan
description: 'FluencyLoop planning stage. Plan a large chunk of work before building it: design and document the overall architecture, break it into task items, sequence them into a roadmap with a critical path, and (optionally) open GitHub issues under a milestone. Produces a committed plan.md that the per-feature loop then builds from — one fluencyloop-feature per task item. Use when the work is too big for a single feature/branch, or when the user says "fluencyloop plan", "plan this", "design the architecture for", "break this down", or "make a roadmap".'
---

# fluencyloop-plan — map a big chunk before you build it

Sits **upstream of `fluencyloop-feature`**. A *feature* is one branch; a **plan** is an
*initiative* that will spawn several features. You will: (1) frame the chunk, (2) design and
show the overall architecture, (3) break it into task items, (4) sequence them into a roadmap
with a critical path, (5) offer to open GitHub tickets under a milestone, (6) hand each task
off to `fluencyloop-feature`. The plan is a **map you build against, not a spec to ratify** —
do not over-invest. Keep the developer the architect.

## 0. Preconditions

Confirm `.fluencyloop/` exists (`.fluencyloop/scripts/common.sh` context). If not, tell the user
to run `fluencyloop init` first, and stop.

**Read the constitution up front** — `docs/fluencyloop/constitution.md`, and **if it's a pointer**
(a `Source of truth:` line naming another file, e.g. `.specify/memory/constitution.md`), read
*that* file. The architecture you design in §2 is checked against it. If it's still the **empty
stub**, this plan is where the constitution is born — see §5.

**Load the learner's knowledge base** — parse it via `fluencyloop calibration show --json` (a
`dimension → level` map, level ∈ {`fluent`, `familiar`, `learning`, `new`}; per-developer, global,
never committed) — to set the depth you explain architectural choices at. Missing is fine.
Planning is also teaching: the same "teach the why, check understanding, don't lecture" posture
from `fluencyloop-feature` applies to the architecture decisions here.

Is this actually a plan? If the work fits one branch, skip straight to `fluencyloop-feature` —
don't manufacture an initiative. Plans are for chunks that genuinely decompose into several
features.

## 1. Frame the chunk

Take the user's initiative intent and scaffold the plan doc:

```bash
.fluencyloop/scripts/new-plan.sh --json "<intent>"
```

This creates `docs/fluencyloop/plans/<slug>/plan.md` from the template **on the current branch**
(a plan is a committed doc, not a branch). Parse the JSON for `slug`, `plan_dir`, `plan`.

Nail down **goal, in-scope, and non-goals** with the user before designing — a plan's value is
mostly in what it excludes. Fill the `## Goal & scope` section from that exchange.

## 2. Design the architecture — *shown*, at initiative altitude

Draft the **big shapes**: the components/modules and their relationships, and the main flow(s).
This is coarser than a feature's `design.md` — the load-bearing structure the features will fill
in, not the per-feature detail.

**Show it rendered — don't just write a file and point at it.** Publish the architecture as a
**self-contained Artifact** (load the `artifact-design` skill first). The CSP blocks external
scripts, so render diagrams as **inline SVG** (or clean HTML/CSS) — do **not** pull Mermaid from
a CDN, and do **not** inline a minified Mermaid/JS bundle (its lone surrogates fail the deploy).
**Byte-check before publishing:** valid UTF-8, no lone surrogates / `U+FFFD`, JSON-round-trips
(prefer ASCII — HTML entities over literal dashes/box-drawing). Then walk the user through it and
invite reactions — this is a conversation.

Persist the same diagrams as **Mermaid** in `plan.md` under `## Architecture` (blocks
**top-level**, never nested in another fence, so GitHub renders them). Check the shapes against
the constitution; if one conflicts with a principle, say so plainly in `## Constitution check` —
do not silently "fix" it. Refine once with the user's input, then move on.

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

## 5. Seed the constitution — if it's still the empty stub

Read `docs/fluencyloop/constitution.md`. **If it's still the empty stub** (`init` seeds an empty
`## Principles` — no real principles yet), this plan is the constitution's **birth**: the
architecture (§2) and roadmap (§4) you just drew are the richest early signal of what this
codebase values. Draft **3–5 initial principles** from them — the constraints and stances the
design actually evidences (a boundary the author insisted on, a coupling they refused, a quality
bar the roadmap protects). Each: a short **title**, the **non-negotiable** in a sentence or two,
and the **why** (the failure it prevents). Keep them **checkable** (*"no synchronous cross-service
calls in the request path"*), not platitudes. Show them, confirm, and write them into
`## Principles` numbered `§1, §2, …` — features cite these numbers.

- **Never author cold or pad to a count** — only principles the architecture evidences; fewer,
  sharper wins.
- **If a real constitution already exists** — a `Source of truth:` pointer, or SpecKit's
  `.specify/memory/constitution.md` — do **not** fork a second one; amend that in place following
  its own conventions (SpecKit carries a version + a Sync Impact Report).
- After birth it **grows** as features harvest principles from decisions (fluencyloop-feature §3)
  — you don't need to make it complete here.

## 6. GitHub tickets — offer, ask each plan

Offer to turn the task breakdown into **GitHub issues under a milestone** (one issue per task
item; the milestone is the initiative). This is confirmed **per plan** — ask before creating:
*"Create these N issues + the '<initiative>' milestone via `gh` now?"* Only proceed on a yes.

- **`gh` available and authed** (`gh auth status`) — create the milestone, then the issues
  (title = task intent, body = intent + dependencies, `--milestone` set). Record the created
  issue/milestone links back into `plan.md` under `## Tickets`. `gh` is cross-platform (Windows
  via winget/scoop/choco, macOS, Linux) — the commands are identical.
- **`gh` missing or unauthed, or the user declines the live create** — don't call `gh`. Instead
  write the runnable `gh issue create …` / `gh api …` commands into `## Tickets` for the user to
  run themselves. Never leave the plan blocked on tooling.

## 7. Hand off to the build loop

The plan is the map; each task item is built with **`fluencyloop-feature`** (one branch per
task, from `main`), in roadmap order along the critical path first. Tell the user that — and that
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
