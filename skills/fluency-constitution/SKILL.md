---
name: fluency-constitution
description: 'FluencyLoop Stage 1. Author or revise the project constitution (.fluency/constitution.md) — the short, maintainer-owned set of principles every feature is checked against. Runs fluency init if needed. Use when setting up FluencyLoop in a project, or when the user says "fluency constitution", "set up fluency", "write the constitution", or wants to establish project principles.'
---

# fluency-constitution — Stage 1, once per project

The constitution is the **only** artifact the maintainer owns, written once and revised
rarely. It is deliberately **short**: a handful of hard constraints and values, each
concrete enough that a later feature's decision can be checked against it. It is not a
governance document.

## 1. Ensure FluencyLoop is initialised

If `.fluency/` does not exist in the repo, initialise it:

```bash
<path-to-fluency-dist>/scripts/bash/init.sh --json   # or: fluency init
```

This scaffolds `.fluency/` (scripts, templates, a constitution stub) and installs the
skills into `.claude/skills`. If `.fluency/constitution.md` already has real content, you
are **revising** — read it first and preserve what still holds.

## 2. Elicit principles — one at a time

Open `.fluency/constitution.md` (from `templates/constitution.md`). Interview the
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

## 3. Write and confirm

Write the principles into `.fluency/constitution.md`, numbered `§1, §2, …` (features will
cite these numbers in their `constitution:` fields). Fill `Project` and `Ratified` (today).
Show the result and confirm. Commit only if the user asks.

## Rules

- **Short beats complete.** Five sharp principles beat twenty vague ones.
- **Checkable, not aspirational.** If you can't imagine a code decision violating it, cut it.
- **Maintainer-owned.** This is the one top-down artifact; everything downstream
  (features, teaching, journals) is contributor-driven and must not be gated by it.
