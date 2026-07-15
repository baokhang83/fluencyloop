# Session: Add a trusted Codex startup hook that refreshes FluencyLoop updates

- **intent:** Add a trusted Codex startup hook that refreshes FluencyLoop updates
- **started:** 2026-07-15

<!--
FluencyLoop Stage 3 — a session is a slice of the build. It holds two persistent records:
  1. Knowledge transfer — what the developer was made fluent in this slice (you write it).
  2. Decisions — the genuine forks, appended by `fluencyloop decision` (the script formats them).

Everything below is scaffolding in comments — nothing to delete. Write knowledge transfer under
its headings; add each decision with
  fluencyloop decision --where <file/area> --why <rationale> [--alternative <rejected + why>] \
                       [--title <chose X over Y>] [--constitution §N] [--trust verified|unverified]
so the block is formatted deterministically and you never hand-write the bullet schema. No
`commits:` field: the feature is a branch, so the PR view derives commits live from git.

KNOWLEDGE-TRANSFER — one bullet per component/role/mechanism explained:
  **<subject>** — <what it does, under what conditions> · status: documented | follow-up
  Make it RICH: cover the inventory AND the non-obvious, hard-won lessons (a bug's root cause,
  why something is done an odd way, a documented limitation). Describe the WORK, never a person
  (no competence, no "who knew what") — these files are committed and name an author via git.

DECISION fields (assembled by `fluencyloop decision`):
  where        — file/area (NOT a line number — survives refactoring)
  why          — the rationale, taught live before it was written
  alternative  — the rejected option and why (what makes it rationale, not description)
  design       — (optional) ../design.md#anchor
  constitution — (optional) §N
  trust        — ✓ verified | ⚠ not independently verified (about the DECISION, never the person)
-->

---

## Knowledge transfer

_The ground this slice makes understandable — components, roles, and conditions explained,
persisted so the fluency doesn't evaporate with the conversation. About the work, never a person._

### Components (role, conditions)

<!-- - **<component / role / mechanism>** — <what it does, and under what conditions> · status: documented -->

- **Claude Code plugin updater** — refreshes enabled marketplace plugins during normal startup;
  FluencyLoop relies on that native lifecycle instead of shipping a second updater · status:
  documented
- **Codex `SessionStart` hook** — runs at a new-session boundary after the user has trusted the
  plugin hook; it derives the marketplace from the installed plugin cache and refreshes only that
  source · status: documented
- **Codex package cache** — keeps the package loaded for the current session stable; a package
  installed by the hook is available when the following session begins · status: documented

### Hard-won conditions (gotchas, root causes, limitations)

<!-- - **<the non-obvious thing>** — <why it's this way / what breaks otherwise> · status: documented -->

- **Startup is not a hot-reload boundary** — installing a package after Codex has loaded the
  current session cannot safely alter the active skills, so the update deliberately takes effect
  one session later · status: documented
- **An installed plugin cannot bootstrap itself retroactively** — existing 0.2.1 Codex users must
  refresh once manually to receive the new startup hook; later releases are then checked
  automatically · status: documented

---

<!-- Decisions are appended below by `fluencyloop decision`. For reference, a block looks like:
## Decision: chose X over Y
- **where:** `path/to/File.ext`
- **why:** the one-line why, engaged with — not post-hoc narration
- **alternative:** the rejected option — rejected: why
- **trust:** ⚠ not independently verified
-->

## Decision: use host-native startup lifecycles for marketplace refresh

- **where:** `plugins/fluencyloop/hooks and marketplace distribution`
- **why:** Claude Code already owns marketplace plugin refresh at startup. Codex exposes a trusted SessionStart hook, so refreshing only the package's supplying marketplace keeps the updater scoped, preserves the active session, and avoids restoring a global installer.
- **alternative:** revive fluencyloop self upgrade or install.sh — rejected: it would create a parallel, manual lifecycle outside the agent hosts and still could not safely replace skills in a running session
- **design:** ../design.md
- **constitution:** §1, §2, §3
- **trust:** ✓ verified
