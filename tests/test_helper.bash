# Shared setup for the FluencyLoop bats suite.
# Each test runs in a throwaway git repo with an isolated FLUENCYLOOP_HOME, so nothing touches
# the developer's real repo, branches, or calibration profile.

# The distribution under test = the Codex plugin package in this repo.
REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
DIST="$REPO_ROOT/plugins/fluencyloop"
BIN="$DIST/scripts/bash"

# Make a fresh git repo on `main` with one commit. Does NOT run init (some tests want a
# pre-init state). Sets TESTREPO and cd's into it; isolates FLUENCYLOOP_HOME.
setup_repo() {
    TESTREPO="$(mktemp -d "${BATS_TMPDIR:-/tmp}/flrepo.XXXXXX")"
    cd "$TESTREPO" || return 1
    git init -q -b main
    git config user.email test@example.com
    git config user.name "Test"
    git commit -q --allow-empty -m "init"
    # Canonicalize to git's view of the root: macOS mktemp yields /var/... but git reports the
    # real /private/var/..., and the path helpers derive from `git rev-parse`.
    TESTREPO="$(git rev-parse --show-toplevel)"
    cd "$TESTREPO" || return 1
    export FLUENCYLOOP_HOME="$TESTREPO/.home"
}

# Fresh repo that has already had `fluencyloop init` run in it.
setup_initialized_repo() {
    setup_repo
    bash "$BIN/init.sh" >/dev/null
}

# A plain directory that is NOT a git repository at all (no `.git`, no parent repo). Regression
# fixture: `check` must degrade gracefully, while `init` creates the repository before scaffolding.
setup_no_repo() {
    TESTREPO="$(mktemp -d "${BATS_TMPDIR:-/tmp}/flnorepo.XXXXXX")"
    cd "$TESTREPO" || return 1
    export FLUENCYLOOP_HOME="$TESTREPO/.home"
}

teardown() {
    [ -n "${TESTREPO:-}" ] && rm -rf "$TESTREPO"
    return 0
}

# Extract a top-level field from a JSON object on stdin (empty if absent). python3 is present
# on macOS and the GitHub ubuntu runners, so tests carry no jq dependency.
json_field() {
    python3 -c "import json,sys;print(json.load(sys.stdin).get('$1',''))"
}
