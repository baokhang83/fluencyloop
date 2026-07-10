# Session: {{SESSION}}

intent:   {{INTENT}}
started:  {{DATE}}

<!--
FluencyLoop Stage 3 — a session is a slice of the build. One block per meaningful decision,
appended at the slice boundary as it's taught. No `commits:` header: the feature is a branch,
so the PR view derives commits live from git. Fields per decision:

  where:        file/area the decision lives in (NOT a line number — survives refactoring)
  why:          the rationale, taught in real time before it's written
  alternative:  the rejected option and why — this is what makes it rationale, not description
  design:       (optional) ../design.md#anchor — the diagram this decision shaped or used
  constitution: (optional) §N — the principle this decision serves or trades off against
  trust:        ✓ verified  |  ⚠ not independently verified   (about the DECISION, never the person)

Delete this comment and the example below once real decisions land.
-->

---

## Decision: <chose X over Y>

where:        <path/to/File.ext>
why:          <the one-line why, engaged with — not post-hoc narration>
alternative:  <the rejected option> — rejected: <why>
trust:        ⚠ not independently verified
