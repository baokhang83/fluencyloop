#!/usr/bin/env bats
# add-decision.sh — deterministic assembly of `## Decision:` blocks (the model supplies values).

load test_helper

setup() {
    setup_initialized_repo
    bash "$BIN/new-feature.sh" "add caching" >/dev/null
    bash "$BIN/new-session.sh" --slug add-caching "wire the cache" >/dev/null
    SESSION="$TESTREPO/docs/fluencyloop/features/add-caching/sessions/wire-the-cache.md"
}

dec() { bash "$BIN/add-decision.sh" "$@"; }

@test "appends a fully-formatted block, session resolved from state" {
    run dec --title "chose LRU over unbounded map" --where "src/cache.js" \
            --why "memory must stay bounded" \
            --alternative "unbounded Map — rejected: leaks" --constitution "§2" --trust unverified
    [ "$status" -eq 0 ]
    grep -qF -- '## Decision: chose LRU over unbounded map' "$SESSION"
    grep -qF -- '- **where:** `src/cache.js`' "$SESSION"
    grep -qF -- '- **why:** memory must stay bounded' "$SESSION"
    grep -qF -- '- **alternative:** unbounded Map — rejected: leaks' "$SESSION"
    grep -qF -- '- **constitution:** §2' "$SESSION"
    grep -qF -- '- **trust:** ⚠ not independently verified' "$SESSION"
}

@test "requires --where and --why" {
    run dec --why "x";    [ "$status" -ne 0 ]
    run dec --where "y";  [ "$status" -ne 0 ]
}

@test "trust: verified renders the check; default is unverified" {
    dec --where a --why b --trust verified
    grep -qF -- '- **trust:** ✓ verified' "$SESSION"
}

@test "optional fields are omitted when not supplied" {
    dec --where a --why b
    ! grep -q "alternative:" "$SESSION"
    ! grep -q "constitution:" "$SESSION"
    ! grep -q "design:" "$SESSION"
}

@test "errors clearly when there is no session to append to" {
    rm -f "$TESTREPO/.fluencyloop/state.json"
    run dec --where a --why b
    [ "$status" -ne 0 ]
}
