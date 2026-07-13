#!/usr/bin/env bats
# calibration.sh — the global, structured per-developer profile and its deterministic parse.

load test_helper

# calibration is global (FLUENCYLOOP_HOME), not repo-scoped, but setup_repo gives us an
# isolated FLUENCYLOOP_HOME and teardown cleanup for free.
setup() { setup_repo; }

cal() { bash "$BIN/calibration.sh" "$@"; }

@test "show before init errors (non-zero) and points at init" {
    run cal show
    [ "$status" -ne 0 ]
    [[ "$output" == *"calibration init"* ]]
}

@test "init creates the profile; a second init doesn't clobber it" {
    run cal init
    [ "$status" -eq 0 ]
    [ -f "$FLUENCYLOOP_HOME/calibration.md" ]
    echo "java: fluent" >> "$FLUENCYLOOP_HOME/calibration.md"
    run cal init
    [ "$status" -eq 0 ]
    grep -q "java: fluent" "$FLUENCYLOOP_HOME/calibration.md"
}

@test "the seeded profile documents the four levels" {
    cal init >/dev/null
    for lvl in fluent familiar learning new; do
        grep -q "$lvl" "$FLUENCYLOOP_HOME/calibration.md"
    done
}

@test "show --json is an empty map when no profile lines exist" {
    cal init >/dev/null
    [ "$(cal show --json)" = "{}" ]
}

@test "show --json parses dimension:level, keeps only the level, and drops invalid levels" {
    cal init >/dev/null
    cat >> "$FLUENCYLOOP_HOME/calibration.md" <<'EOF'
java: fluent
reactive: learning — Mono/Flux backpressure · 2026-07-13
k8s: new
maven.plugin: familiar
bogus: banana
EOF
    run cal show --json
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c '
import json,sys
d=json.load(sys.stdin)
assert d["java"]=="fluent", d
assert d["reactive"]=="learning", d          # note/date stripped
assert d["k8s"]=="new" and d["maven.plugin"]=="familiar", d
assert "bogus" not in d, d                    # invalid level excluded
'
}

@test "an unknown subcommand exits non-zero" {
    run cal frobnicate
    [ "$status" -ne 0 ]
}
