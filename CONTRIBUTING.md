## Contributing & support

Questions, ideas, and bug reports are welcome — open an
[issue](https://github.com/baokhang83/fluencyloop/issues) or start a
[discussion](https://github.com/baokhang83/fluencyloop/discussions).

<a id="project-status"></a>
**Status: beta.** FluencyLoop is actively dogfooded and the workflow is stable enough for daily
use. It stays on `0.x` while the skill and CLI surfaces settle, so expect fast-moving changes and
read the [changelog](CHANGELOG.md) before updating.

The scripts switch branches and write files in your repo, so they're tested. CI runs
[`shellcheck`](https://www.shellcheck.net/) + a [`bats`](https://github.com/bats-core/bats-core)
suite on every push and PR; run them locally with
`shellcheck -x -P SCRIPTDIR plugins/fluencyloop/scripts/bash/*.sh` and `bats tests`.

`scripts/bash/` and `scripts/powershell/` are two implementations of one contract, with
`tests/powershell/` mirroring `tests/`. A change to one runtime needs the same change in the other,
or it ships behaviour that differs by platform; if you have no `pwsh` locally, say so in the PR and
let the Windows CI job be the check.

### Node boundary

Node.js is an optional dependency. The core loop — its Bash/PowerShell scripts, store writers,
skills, and normal feature flow — must run without Node installed. Only `fluencyloop site` may
execute Node, and it requires **Node.js 18 or newer** with built-in modules only. `fluencyloop
check` may report whether Node is available, but that result is informational and must never fail a
check. Do not add a Node invocation or package dependency to the core path because it happened to
be available on a development machine.

<a id="distribution-roadmap"></a>
> **Distribution:** FluencyLoop ships through its Claude Code and Codex marketplace plugins.
> The canonical runtime lives in `plugins/fluencyloop/`; do not add a machine-wide installer or
> copy skills into a user's agent directory. Both agents auto-update from `main` on every session,
> so merging there *is* releasing — see [RELEASING.md](RELEASING.md). Work that spans more than one
> release goes to `dev`.
