## Contributing & support

Questions, ideas, and bug reports are welcome — open an
[issue](https://github.com/baokhang83/fluencyloop/issues) or start a
[discussion](https://github.com/baokhang83/fluencyloop/discussions). This is alpha and
actively dogfooded, so expect rough edges and fast-moving changes.

The scripts switch branches and write files in your repo, so they're tested. CI runs
[`shellcheck`](https://www.shellcheck.net/) + a [`bats`](https://github.com/bats-core/bats-core)
suite on every push and PR; run them locally with
`shellcheck -x -P SCRIPTDIR plugins/fluencyloop/scripts/bash/*.sh` and `bats tests`.

<a id="distribution-roadmap"></a>
> **Distribution:** FluencyLoop ships through its Claude Code and Codex marketplace plugins.
> The canonical runtime lives in `plugins/fluencyloop/`; do not add a machine-wide installer or
> copy skills into a user's agent directory.
