#!/usr/bin/env bats
# add-decision.sh — one schema-complete decision line per call, never a markdown edit.

load test_helper

setup() {
    setup_initialized_repo
    bash "$BIN/new-feature.sh" "add caching" >/dev/null
    bash "$BIN/new-session.sh" --slug 001-add-caching "wire the cache" >/dev/null
    STORE="$TESTREPO/docs/fluencyloop/store/features/001-add-caching.jsonl"
}

dec() { bash "$BIN/add-decision.sh" "$@"; }

decision_field() {
    python3 - "$STORE" "$1" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    record = json.loads(list(fh)[-1])
print(record.get(sys.argv[2], ''))
PY
}

@test "appends one schema-complete decision, resolved from state" {
    run dec --title "chose LRU over unbounded map" --where "src/cache.js" \
            --why "memory must stay bounded" \
            --alternative "unbounded Map - rejected: leaks" --constitution "section-2" --trust unverified
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$STORE")" -eq 3 ]
    [ "$(decision_field type)" = "decision" ]
    [ "$(decision_field title)" = "chose LRU over unbounded map" ]
    [ "$(decision_field where)" = "src/cache.js" ]
    [ "$(decision_field why)" = "memory must stay bounded" ]
    [ "$(decision_field alternative)" = "unbounded Map - rejected: leaks" ]
    [ "$(decision_field constitution)" = "section-2" ]
    [ "$(decision_field trust)" = "unverified" ]
    [ "$(decision_field feature)" = "001-add-caching" ]
    [ "$(decision_field session)" = "001-wire-the-cache" ]
}

@test "requires --where and --why" {
    run dec --why "x";    [ "$status" -ne 0 ]
    run dec --where "y";  [ "$status" -ne 0 ]
}

@test "trust: verified and default unverified are stored" {
    dec --where a --why b --trust verified
    [ "$(decision_field trust)" = "verified" ]
    dec --where c --why d
    [ "$(decision_field trust)" = "unverified" ]
}

@test "optional fields are absent rather than empty" {
    dec --where a --why b
    python3 - "$STORE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    record = json.loads(list(fh)[-1])
for field in ('alternative', 'constitution', 'design'):
    assert field not in record, (field, record)
PY
}

@test "pre-existing markdown stays untouched" {
    legacy="$TESTREPO/docs/fluencyloop/features/001-add-caching/sessions/legacy.md"
    mkdir -p "$(dirname "$legacy")"
    printf '# Legacy session\n' > "$legacy"
    dec --session "$legacy" --where a --why b
    [ "$(cat "$legacy")" = "# Legacy session" ]
}

@test "errors clearly when there is no session to append to" {
    rm -f "$TESTREPO/.fluencyloop/state.json"
    run dec --where a --why b
    [ "$status" -ne 0 ]
}

@test "can target an imported feature and session without changing branch state" {
    run dec --feature "legacy-caching" --session "000-legacy-import" \
        --title "kept the bounded cache" --where "src/cache.js" --why "the historical implementation bounds memory"
    [ "$status" -eq 0 ]
    python3 - "$TESTREPO/docs/fluencyloop/store/features/legacy-caching.jsonl" <<'PY'
import json, sys
r = json.loads(list(open(sys.argv[1], encoding='utf-8'))[-1])
assert r['feature'] == 'legacy-caching'
assert r['session'] == '000-legacy-import'
PY
    [ "$(git branch --show-current)" = "feature/001-add-caching" ]
}

@test "requires a session when targeting a historical feature" {
    run dec --feature "legacy-caching" --where "src/cache.js" --why "x"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--feature requires --session"* ]]
}
