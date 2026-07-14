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
    [ "$(echo "$output" | json_field feature)" = "add-search" ]
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

    bash "$BIN/new-session.sh" --slug add-search "index" >/dev/null
    git add -A && git commit -q -m "journal"
    [ "$(bash "$BIN/check.sh" --json | json_field unjournaled_commits)" = "0" ]

    echo x > "$TESTREPO/app.txt"; git add -A && git commit -q -m "more code"
    [ "$(bash "$BIN/check.sh" --json | json_field unjournaled_commits)" = "1" ]
}

@test "check: absent constitution informs without erroring" {
    setup_initialized_repo
    rm -f "$TESTREPO/docs/fluencyloop/constitution.md"
    run bash "$BIN/check.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no constitution yet"* ]]
}
