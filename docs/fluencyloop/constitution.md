# Constitution

<!--
The project's principles — the short set of hard constraints every feature's design is checked
against (fluencyloop-plan and fluencyloop-feature do the checking). It is NOT authored cold as a
ceremony. It starts empty and is *written from your first plan or feature*, then grows as later
features harvest repeatable stances from real decisions. Same law as the journal: it accretes
from building. Delete this comment once real principles land.
-->

**Project:** FluencyLoop

## Principles

§1 **Use the host lifecycle.** Distribution, refresh, and hook execution must use the
capabilities of Claude Code and Codex rather than reintroducing a machine-wide installer. This
keeps ownership and security review with the agent the developer chose.

§2 **Refresh only at a session boundary.** An update may be checked and installed when an agent
starts, but it takes effect in the next session. The active agent must never have its skills
silently replaced mid-task.

§3 **Keep automation narrowly scoped.** FluencyLoop may refresh its own marketplace package; it
must not update, configure, or otherwise affect unrelated plugins.

<!-- Real principles land here, numbered §1, §2, … (features cite these numbers in their
`constitution:` fields). Each: a short title, the non-negotiable in a sentence or two, and the
why (the failure it prevents). Keep them checkable, not platitudes. -->
