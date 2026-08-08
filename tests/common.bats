#!/usr/bin/env bats
# common.sh — the shared helpers (slugify, branch/feature/plan paths, state, json).

load test_helper

setup() { setup_initialized_repo; source "$BIN/common.sh"; }

@test "slugify: lowercases, hyphenates, trims to a safe branch name" {
    [ "$(slugify 'Adding Rate Limiting to the Gateway!')" = "adding-rate-limiting-to-the-gateway" ]
    [ "$(slugify '  spaces  and--dashes  ')" = "spaces-and-dashes" ]
    [ "$(slugify 'UPPER/slash:colon')" = "upper-slash-colon" ]
}

@test "slugify: caps length and strips a trailing hyphen" {
    local out; out="$(slugify "$(printf 'a%.0s' {1..80})")"
    [ "${#out}" -le 60 ]
    [ "${out: -1}" != "-" ]
}

@test "branch_for: slug -> feature/<slug>" {
    [ "$(branch_for 'add-caching')" = "feature/add-caching" ]
}

@test "feature_path and plan_path live under docs/fluencyloop" {
    [ "$(feature_path foo)" = "$TESTREPO/docs/fluencyloop/features/foo" ]
    [ "$(plan_path bar)" = "$TESTREPO/docs/fluencyloop/plans/bar" ]
}

@test "json_escape: escapes quotes, backslashes, and newlines" {
    [ "$(json_escape 'a"b\c')" = 'a\"b\\c' ]
    [ "$(json_escape "$(printf 'x\ny')")" = 'x\ny' ]
}

@test "emit_json: produces a valid flat object from key/value pairs" {
    run bash -c "source '$BIN/common.sh'; emit_json a 1 b 'two words'"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys;d=json.load(sys.stdin);assert d=={'a':'1','b':'two words'},d"
}

@test "write_state then state_get round-trips fields" {
    write_state feature foo branch feature/foo stage design base_ref main
    [ "$(state_get feature)" = "foo" ]
    [ "$(state_get stage)" = "design" ]
    [ "$(state_get base_ref)" = "main" ]
    # state.json is valid JSON
    python3 -c "import json;json.load(open('$TESTREPO/.fluencyloop/state.json'))"
}

@test "state_get returns empty for a missing key or missing file" {
    [ -z "$(state_get nope)" ]
    rm -f "$TESTREPO/.fluencyloop/state.json"
    [ -z "$(state_get feature)" ]
}

@test "write_state stamps schema_version without the caller passing it" {
    write_state feature foo branch feature/foo stage design
    [ "$(state_get schema_version)" = "$FLUENCYLOOP_SCHEMA_VERSION" ]
    [ "$(state_schema_version)" = "$FLUENCYLOOP_SCHEMA_VERSION" ]
    python3 -c "import json;json.load(open('$TESTREPO/.fluencyloop/state.json'))"
}

@test "state_schema_version reads a pre-existing state file as generation 1" {
    # A project initialised before the field existed. It must read as schema 1 rather than
    # empty, so a later version can branch on the generation without rewriting anyone's state.
    printf '{\n  "feature": "legacy",\n  "stage": "build"\n}\n' > "$TESTREPO/.fluencyloop/state.json"
    [ -z "$(state_get schema_version)" ]
    [ "$(state_schema_version)" = "1" ]
}

@test "fluency_dir/docs_dir/state_path return empty (not a crash) outside a git repo" {
    # Regression: these used to end in a bare `[ -n "$root" ] && printf ...`, whose failing
    # exit status aborted the whole calling script under `set -e` the moment it was captured
    # via command substitution (e.g. `X="$(fluency_dir)"`) — silently, with no message, in any
    # repo-less directory. See check.bats: "outside any git repository ...".
    local outside; outside="$(mktemp -d "${BATS_TMPDIR:-/tmp}/flnorepo.XXXXXX")"
    cd "$outside" || return 1
    [ "$(fluency_dir)" = "" ]
    [ "$(docs_dir)" = "" ]
    [ "$(state_path)" = "" ]
    rm -rf "$outside"
}

@test "repo_rel makes a path relative to the repo root" {
    [ "$(repo_rel "$TESTREPO/docs/fluencyloop/x.md")" = "docs/fluencyloop/x.md" ]
}

@test "every deterministic script sets -euo pipefail" {
    for f in "$BIN"/*.sh; do
        grep -q 'set -euo pipefail' "$f" || { echo "missing in $f"; return 1; }
    done
}
