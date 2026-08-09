#!/usr/bin/env bats
# check.sh — the doctor: state, un-journaled drift, constitution status. Never errors.

load test_helper

@test "check --json reports fluency false before init, and never errors" {
    setup_repo
    run bash "$BIN/check.sh" --json
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | json_field fluency)" = "False" ] || [ "$(echo "$output" | json_field fluency)" = "false" ]
}

@test "check reports the active feature and an empty constitution after init" {
    setup_initialized_repo
    bash "$BIN/new-feature.sh" "add search" >/dev/null
    run bash "$BIN/check.sh" --json
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | json_field feature)" = "001-add-search" ]
    [ "$(echo "$output" | json_field constitution)" = "empty" ]
}

@test "check: constitution states - present and pointer" {
    setup_initialized_repo
    printf '# Constitution\n\n## Principles\n\n### §1 — no sync calls in the request path\n' \
        > "$TESTREPO/docs/fluencyloop/constitution.md"
    [ "$(bash "$BIN/check.sh" --json | json_field constitution)" = "present" ]

    printf '# Constitution\n\nSource of truth: .specify/memory/constitution.md\n' \
        > "$TESTREPO/docs/fluencyloop/constitution.md"
    [ "$(bash "$BIN/check.sh" --json | json_field constitution)" = "pointer" ]
}

@test "check: un-journaled drift counts commits past the last journaled session" {
    setup_initialized_repo
    bash "$BIN/new-feature.sh" "add search" >/dev/null
    git add -A && git commit -q -m "scaffold, no session"
    [ "$(bash "$BIN/check.sh" --json | json_field unjournaled_commits)" = "1" ]

    bash "$BIN/new-session.sh" --slug 001-add-search "index" >/dev/null
    git add -A && git commit -q -m "journal"
    [ "$(bash "$BIN/check.sh" --json | json_field unjournaled_commits)" = "0" ]

    echo x > "$TESTREPO/app.txt"; git add -A && git commit -q -m "more code"
    [ "$(bash "$BIN/check.sh" --json | json_field unjournaled_commits)" = "1" ]
}

@test "check: outside any git repository, reports git_repo false without crashing" {
    setup_no_repo
    run bash "$BIN/check.sh" --json
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | json_field git_repo)" = "False" ] || [ "$(echo "$output" | json_field git_repo)" = "false" ]
    [ "$(echo "$output" | json_field fluency)" = "False" ] || [ "$(echo "$output" | json_field fluency)" = "false" ]

    run bash "$BIN/check.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"not a git repository"* ]]
}

@test "check: absent constitution informs without erroring" {
    setup_initialized_repo
    rm -f "$TESTREPO/docs/fluencyloop/constitution.md"
    run bash "$BIN/check.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no constitution yet"* ]]
}

store_record() {
    printf '%s\n' "$1" >> "$TESTREPO/docs/fluencyloop/store/concepts.jsonl"
}

store_errors() {
    python3 -c 'import json,sys; print(json.load(sys.stdin)["store_errors"])'
}

@test "check: accepts a clean store" {
    setup_initialized_repo
    mkdir -p "$TESTREPO/docs/fluencyloop/store"
    store_record '{"schema_version":"1","type":"concept","ts":"2026-08-09","feature":"global","session":"none","commit":"abc","name":"cache","problem":"slow reads","how":"reuse results","realized_by":"CacheClient"}'

    run bash "$BIN/check.sh" --json
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | store_errors)" = "[]" ]
}

@test "check: reports unparseable store JSON with file and line" {
    setup_initialized_repo
    mkdir -p "$TESTREPO/docs/fluencyloop/store"
    store_record '{"schema_version":"1"'

    run bash "$BIN/check.sh" --json
    [ "$status" -eq 1 ]
    [[ "$output" == *'concepts.jsonl'* ]]
    [[ "$output" == *'"line":1'* ]]
    [[ "$output" == *'unparseable JSON'* ]]
}

@test "check: reports an unknown store record type" {
    setup_initialized_repo
    mkdir -p "$TESTREPO/docs/fluencyloop/store"
    store_record '{"schema_version":"1","type":"invented","ts":"2026-08-09","feature":"global","session":"none","commit":"abc"}'

    run bash "$BIN/check.sh" --json
    [ "$status" -eq 1 ]
    [[ "$output" == *'"line":1'* ]]
    [[ "$output" == *'unknown record type: invented'* ]]
}

@test "check: reports a missing required envelope field" {
    setup_initialized_repo
    mkdir -p "$TESTREPO/docs/fluencyloop/store"
    store_record '{"schema_version":"1","type":"concept","ts":"2026-08-09","feature":"global","session":"none","name":"cache"}'

    run bash "$BIN/check.sh" --json
    [ "$status" -eq 1 ]
    [[ "$output" == *'"line":1'* ]]
    [[ "$output" == *'missing required envelope field: commit'* ]]
}

@test "check: reports a dangling relation with file and line" {
    setup_initialized_repo
    mkdir -p "$TESTREPO/docs/fluencyloop/store"
    store_record '{"schema_version":"1","type":"concept","ts":"2026-08-09","feature":"global","session":"none","commit":"abc","name":"known","problem":"p","how":"h","realized_by":"x"}'
    store_record '{"schema_version":"1","type":"relation","ts":"2026-08-09","feature":"global","session":"none","commit":"abc","from":"missing","to":"known","kind":"uses"}'

    run bash "$BIN/check.sh" --json
    [ "$status" -eq 1 ]
    [[ "$output" == *'"line":2'* ]]
    [[ "$output" == *'dangling relation endpoint: missing'* ]]
}

@test "check: reports a feature directory without store records" {
    setup_initialized_repo
    mkdir -p "$TESTREPO/docs/fluencyloop/features/001-empty"

    run bash "$BIN/check.sh" --json
    [ "$status" -eq 1 ]
    [[ "$output" == *'store/features/001-empty.jsonl'* ]]
    [[ "$output" == *'"line":0'* ]]
    [[ "$output" == *'feature directory has no store records: 001-empty'* ]]
}
