#!/usr/bin/env bats
# new-plan.sh — a plan is a committed doc on the current branch, NOT a new branch.

load test_helper

setup() { setup_initialized_repo; }

@test "new-plan scaffolds plan.md under docs/fluencyloop/plans without switching branches" {
    run bash "$BIN/new-plan.sh" --json "revamp the checkout flow"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | json_field slug)" = "revamp-the-checkout-flow" ]
    [ -f "$TESTREPO/docs/fluencyloop/plans/revamp-the-checkout-flow/plan.md" ]
    # still on main — a plan does not create/switch a branch
    [ "$(git rev-parse --abbrev-ref HEAD)" = "main" ]
}

@test "new-plan substitutes the initiative title into the doc" {
    bash "$BIN/new-plan.sh" "revamp the checkout flow" >/dev/null
    grep -q "revamp the checkout flow" "$TESTREPO/docs/fluencyloop/plans/revamp-the-checkout-flow/plan.md"
}

@test "new-plan errors (non-zero) with no intent" {
    run bash "$BIN/new-plan.sh"
    [ "$status" -ne 0 ]
}

@test "new-plan --help prints usage and does not scaffold a plan" {
    run bash "$BIN/new-plan.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: new-plan.sh"* ]]
    [ ! -d "$TESTREPO/docs/fluencyloop/plans" ]
}

@test "new-plan rejects an unknown flag instead of folding it into the intent" {
    run bash "$BIN/new-plan.sh" --bogus "should not scaffold"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown option: --bogus"* ]]
    [ ! -d "$TESTREPO/docs/fluencyloop/plans" ]
}
