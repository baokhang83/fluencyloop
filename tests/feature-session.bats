#!/usr/bin/env bats
# new-feature.sh + new-session.sh — branch, store records, and the state.json contract.

load test_helper

setup() { setup_initialized_repo; }

assert_store_record() {
    python3 - "$1" "$2" <<'PY'
import json, sys
path, expected_type = sys.argv[1:]
with open(path, encoding='utf-8') as fh:
    records = [json.loads(line) for line in fh]
assert records[-1]['type'] == expected_type, records[-1]
for field in ('schema_version', 'type', 'ts', 'feature', 'session', 'commit'):
    assert field in records[-1], (field, records[-1])
PY
}

@test "new-feature creates the branch, a feature record, and state (stage: design)" {
    run bash "$BIN/new-feature.sh" --json "add rate limiting"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | json_field slug)" = "001-add-rate-limiting" ]
    [ "$(echo "$output" | json_field branch)" = "feature/001-add-rate-limiting" ]
    [ "$(git rev-parse --abbrev-ref HEAD)" = "feature/001-add-rate-limiting" ]
    STORE="$TESTREPO/docs/fluencyloop/store/features/001-add-rate-limiting.jsonl"
    [ "$(echo "$output" | json_field store)" = "$STORE" ]
    [ -f "$STORE" ]
    [ "$(wc -l < "$STORE")" -eq 1 ]
    assert_store_record "$STORE" feature
    [ "$(cat "$TESTREPO/.fluencyloop/state.json" | json_field stage)" = "design" ]
    [ "$(cat "$TESTREPO/.fluencyloop/state.json" | json_field base_ref)" = "main" ]
    [ ! -e "$TESTREPO/docs/fluencyloop/features/001-add-rate-limiting/design.md" ]
}

@test "new-feature errors (non-zero) with no intent" {
    run bash "$BIN/new-feature.sh"
    [ "$status" -ne 0 ]
}

@test "new-feature is idempotent: re-run on the same branch preserves base_ref" {
    bash "$BIN/new-feature.sh" "add caching" >/dev/null
    run bash "$BIN/new-feature.sh" "add caching"
    [ "$status" -eq 0 ]
    [ "$(cat "$TESTREPO/.fluencyloop/state.json" | json_field base_ref)" = "main" ]
}

@test "new-feature numbers the next store-backed feature without markdown directories" {
    bash "$BIN/new-feature.sh" "first feature" >/dev/null
    run bash -c 'source "$1/common.sh"; next_feature_number' _ "$BIN"
    [ "$status" -eq 0 ]
    [ "$output" = "002" ]
}

@test "new-session records the slice without creating markdown" {
    bash "$BIN/new-feature.sh" "add caching" >/dev/null
    run bash "$BIN/new-session.sh" --json --slug 001-add-caching "wire the LRU cache"
    [ "$status" -eq 0 ]
    STORE="$TESTREPO/docs/fluencyloop/store/features/001-add-caching.jsonl"
    [ "$(wc -l < "$STORE")" -eq 2 ]
    assert_store_record "$STORE" session
    [ "$(cat "$TESTREPO/.fluencyloop/state.json" | json_field stage)" = "build" ]
    [ "$(cat "$TESTREPO/.fluencyloop/state.json" | json_field last_session)" = "001-wire-the-lru-cache" ]
    [ ! -e "$TESTREPO/docs/fluencyloop/features/001-add-caching/sessions/001-wire-the-lru-cache.md" ]
}

@test "new sessions advance from state without markdown filenames" {
    bash "$BIN/new-feature.sh" "add caching" >/dev/null
    bash "$BIN/new-session.sh" --slug 001-add-caching "first slice" >/dev/null
    run bash "$BIN/new-session.sh" --json --slug 001-add-caching "second slice"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | json_field session_slug)" = "002-second-slice" ]
}

@test "new-session errors with no active feature" {
    run bash "$BIN/new-session.sh" "orphan slice"
    [ "$status" -ne 0 ]
}

@test "base_ref records the true fork point, not always main" {
    git checkout -q -b trunk
    bash "$BIN/new-feature.sh" "forked work" >/dev/null
    [ "$(cat "$TESTREPO/.fluencyloop/state.json" | json_field base_ref)" = "trunk" ]
}

@test "new-feature reuses a legacy unnumbered branch without changing its markdown" {
    git checkout -q -b "feature/add-caching"
    mkdir -p "$TESTREPO/docs/fluencyloop/features/add-caching/sessions"
    printf '# Legacy design\n' > "$TESTREPO/docs/fluencyloop/features/add-caching/design.md"

    run bash "$BIN/new-feature.sh" --json "add caching"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | json_field slug)" = "add-caching" ]
    [ "$(echo "$output" | json_field branch_created)" = "false" ]
    [ "$(git rev-parse --abbrev-ref HEAD)" = "feature/add-caching" ]
    [ "$(cat "$TESTREPO/docs/fluencyloop/features/add-caching/design.md")" = "# Legacy design" ]
    ! git show-ref --verify --quiet "refs/heads/feature/001-add-caching"
}
