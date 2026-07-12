---
name: fluencyloop-constitution
description: 'FluencyLoop Stage 1. Author or revise the project constitution (docs/fluencyloop/constitution.md) — the short, maintainer-owned set of principles every feature is checked against. Runs fluencyloop init if needed. Use when setting up FluencyLoop in a project, or when the user says "fluency constitution", "set up fluency", "write the constitution", or wants to establish project principles.'
---

# fluencyloop-constitution — Stage 1, once per project

The constitution is the **only** artifact the maintainer owns, written once and revised
rarely. It is deliberately **short**: a handful of hard constraints and values, each
concrete enough that a later feature's decision can be checked against it. It is not a
governance document.

## 1. Check for an existing constitution FIRST — never create a duplicate

Before authoring anything, look for a constitution the project already has:

- SpecKit: `.specify/memory/constitution.md`
- any `constitution.md` / `CONSTITUTION.md` at the repo root or under `docs/`

**If one exists with real content, do not write a parallel constitution** — two sources of
truth silently drift, and features end up checked against stale principles. Instead:

1. Tell the user it should be the **single source of truth**, and make
   `docs/fluencyloop/constitution.md` a thin **pointer** to it rather than a copy:

   ```markdown
   # Constitution

   Source of truth: .specify/memory/constitution.md

   FluencyLoop features are checked against the principles in that file. This project keeps
   its constitution there (e.g. SpecKit-governed, versioned); duplicating it here would drift.
   ```

2. If principles need to **change**, amend the existing constitution **in place**, following
   *its own* conventions (SpecKit constitutions carry a version + a Sync Impact Report —
   bump the version and update that report). Never fork a second copy to hold the new wording.

Only if **no** constitution exists anywhere do you author fresh principles (steps 2–4 below).

## 2. Ensure FluencyLoop is initialised

If `.fluencyloop/` does not exist in the repo, initialise it:

```bash
<path-to-fluencyloop-dist>/scripts/bash/init.sh --json   # or: fluencyloop init
```

This scaffolds `.fluencyloop/` (scripts, templates) plus `docs/fluencyloop/` (a constitution
stub) and installs the skills into `.claude/skills`. If `docs/fluencyloop/constitution.md`
already has real content
(and isn't just a pointer), you are **revising** — read it first and preserve what still holds.

## 3. Elicit principles — one at a time  *(only when no constitution already exists)*

Open `docs/fluencyloop/constitution.md` (from `templates/constitution.md`). Interview the
maintainer **one question at a time** (like a focused clarify loop), aiming for **3–5
principles total** — resist more. For each principle, capture:

- a short **title**,
- the **non-negotiable** itself, in one or two sentences, and
- the **why** — the failure it prevents.

Good principles are checkable (*"no synchronous cross-service calls in the request path"*),
not platitudes (*"write clean code"*). After each answer, reflect it back in one line and
move to the next. Stop as soon as the maintainer has no more hard constraints — do not pad
to a target count.

Optionally capture an **Out of scope** note: what the constitution deliberately does *not*
constrain, so contributors don't over-ask it.

## 4. Write and confirm

Write the principles into `docs/fluencyloop/constitution.md`, numbered `§1, §2, …` (features will
cite these numbers in their `constitution:` fields). Fill `Project` and `Ratified` (today).
Show the result and confirm. Commit only if the user asks.

## Rules

- **Single source of truth.** Never maintain two constitutions. If the project already has
  one, point to it and amend it in place; do not fork a FluencyLoop copy.
- **Short beats complete.** Five sharp principles beat twenty vague ones.
- **Checkable, not aspirational.** If you can't imagine a code decision violating it, cut it.
- **Maintainer-owned.** This is the one top-down artifact; everything downstream
  (features, teaching, journals) is contributor-driven and must not be gated by it.
