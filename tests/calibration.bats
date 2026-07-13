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

# --- signals + compact (demonstrated-engagement adaptation) ---------------

level_of() { cal show --json | python3 -c "import json,sys;print(json.load(sys.stdin).get('$1',''))"; }

@test "signal appends to the ledger; a bad signal type is rejected" {
    cal init >/dev/null
    cal signal java wave
    [ -f "$FLUENCYLOOP_HOME/signals.log" ]
    grep -q "java wave" "$FLUENCYLOOP_HOME/signals.log"
    run cal signal java bogus
    [ "$status" -ne 0 ]
}

@test "compact promotes after repeated wave-throughs (threshold 2)" {
    cal init >/dev/null
    echo "java: learning" >> "$FLUENCYLOOP_HOME/calibration.md"
    cal signal java wave; cal signal java wave
    run cal compact
    [ "$status" -eq 0 ]
    [ "$(level_of java)" = "familiar" ]
}

@test "compact demotes on deeper-asks / corrections" {
    cal init >/dev/null
    echo "reactive: familiar" >> "$FLUENCYLOOP_HOME/calibration.md"
    cal signal reactive deeper; cal signal reactive correct
    cal compact >/dev/null
    [ "$(level_of reactive)" = "learning" ]
}

@test "signals below the threshold don't move the level" {
    cal init >/dev/null
    echo "k8s: new" >> "$FLUENCYLOOP_HOME/calibration.md"
    cal signal k8s wave      # only 1 — below ±2
    cal compact >/dev/null
    [ "$(level_of k8s)" = "new" ]
}

@test "compact consumes the ledger; --dry-run neither applies nor consumes" {
    cal init >/dev/null
    echo "java: learning" >> "$FLUENCYLOOP_HOME/calibration.md"
    cal signal java wave; cal signal java wave
    run cal compact --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"java: learning -> familiar"* ]]
    [ "$(level_of java)" = "learning" ]                      # not applied
    grep -q "java wave" "$FLUENCYLOOP_HOME/signals.log"      # not consumed
    cal compact >/dev/null
    [ "$(level_of java)" = "familiar" ]                      # applied
    ! grep -q "java wave" "$FLUENCYLOOP_HOME/signals.log"    # consumed
}

@test "levels clamp: promoting fluent stays fluent" {
    cal init >/dev/null
    echo "java: fluent" >> "$FLUENCYLOOP_HOME/calibration.md"
    cal signal java wave; cal signal java wave
    cal compact >/dev/null
    [ "$(level_of java)" = "fluent" ]
}
