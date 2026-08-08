#!/usr/bin/env bats
# assemble-pr-view.sh — the review raw material: --json contract, base fallback, empty-safe.

load test_helper

setup() {
    setup_initialized_repo
    bash "$BIN/new-feature.sh" "add search" >/dev/null
    git add -A && git commit -q -m "scaffold"
}

@test "assemble-pr-view --json is valid with zero sessions (regression: empty array under set -u)" {
    run bash "$BIN/assemble-pr-view.sh" --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys;d=json.load(sys.stdin);assert d['session_count']==0,d"
}

@test "assemble-pr-view resolves the base from state.json, not a guess" {
    # feature was forked from main; base should be main even with no --base passed
    run bash "$BIN/assemble-pr-view.sh" --json
    [ "$(echo "$output" | json_field base)" = "main" ]
}

@test "assemble-pr-view points readers to the store instead of parsing it in shell" {
    bash "$BIN/new-session.sh" --slug 001-add-search "index the docs" >/dev/null
    run bash "$BIN/assemble-pr-view.sh" --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys;d=json.load(sys.stdin);assert d['store'].endswith('001-add-search.jsonl'),d;assert d['sessions']==[],d"
}

@test "assemble-pr-view markdown form renders a title and range" {
    run bash "$BIN/assemble-pr-view.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PR view"* ]]
}
