#!/usr/bin/env bats
# new-feature.sh + new-session.sh — branch, scaffolding, and the state.json contract.

load test_helper

setup() { setup_initialized_repo; }

@test "new-feature creates the branch, design stub, and state (stage: design)" {
    run bash "$BIN/new-feature.sh" --json "add rate limiting"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | json_field slug)" = "001-add-rate-limiting" ]
    [ "$(echo "$output" | json_field branch)" = "feature/001-add-rate-limiting" ]
    [ "$(git rev-parse --abbrev-ref HEAD)" = "feature/001-add-rate-limiting" ]
    [ -f "$TESTREPO/docs/fluencyloop/features/001-add-rate-limiting/design.md" ]
    [ "$(cat "$TESTREPO/.fluencyloop/state.json" | json_field stage)" = "design" ]
    [ "$(cat "$TESTREPO/.fluencyloop/state.json" | json_field base_ref)" = "main" ]
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

@test "new-session moves state to build and records the last session" {
    bash "$BIN/new-feature.sh" "add caching" >/dev/null
    run bash "$BIN/new-session.sh" --json --slug 001-add-caching "wire the LRU cache"
    [ "$status" -eq 0 ]
    [ -f "$TESTREPO/docs/fluencyloop/features/001-add-caching/sessions/001-wire-the-lru-cache.md" ]
    [ "$(cat "$TESTREPO/.fluencyloop/state.json" | json_field stage)" = "build" ]
    [ "$(cat "$TESTREPO/.fluencyloop/state.json" | json_field last_session)" = "docs/fluencyloop/features/001-add-caching/sessions/001-wire-the-lru-cache.md" ]
    [ "$(cat "$TESTREPO/.fluencyloop/state.json" | json_field base_ref)" = "main" ]
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

@test "new-feature reuses a legacy unnumbered branch instead of forking a numbered duplicate" {
    # Simulate a feature declared before per-feature numbering existed (pre-0.2.22): the dir
    # and branch carry a bare slugify(intent), with no <prefix>- segment.
    git checkout -q -b "feature/add-caching"
    mkdir -p "$TESTREPO/docs/fluencyloop/features/add-caching/sessions"
    echo "# Design" > "$TESTREPO/docs/fluencyloop/features/add-caching/design.md"

    run bash "$BIN/new-feature.sh" --json "add caching"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | json_field slug)" = "add-caching" ]
    [ "$(echo "$output" | json_field branch_created)" = "false" ]
    [ "$(git rev-parse --abbrev-ref HEAD)" = "feature/add-caching" ]
    # Must not have forked a new numbered branch off the legacy one.
    ! git show-ref --verify --quiet "refs/heads/feature/001-add-caching"
}
