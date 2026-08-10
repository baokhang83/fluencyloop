#!/usr/bin/env bats
# add-knowledge.sh — session-close batches become component and condition store records.

load test_helper

setup() {
    setup_initialized_repo
    bash "$BIN/new-feature.sh" "add caching" >/dev/null
    bash "$BIN/new-session.sh" --slug 001-add-caching "wire the cache" >/dev/null
    STORE="$TESTREPO/docs/fluencyloop/store/features/001-add-caching.jsonl"
}

knowledge() { bash "$BIN/add-knowledge.sh" "$@"; }

@test "batches components and gotchas into one line each" {
    before="$(wc -l < "$STORE")"
    run knowledge \
        --component "store reader|selects current records|must use file order" \
        --component "cache client|keeps fetched values|only after a miss|follow-up" \
        --gotcha "read after correction|the final matching record wins"
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$STORE")" -eq $((before + 3)) ]

    python3 - "$STORE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    records = [json.loads(line) for line in fh][-3:]
assert [record['type'] for record in records] == ['component', 'component', 'condition']
assert records[0]['name'] == 'store reader'
assert records[0]['role'] == 'selects current records'
assert records[0]['conditions'] == 'must use file order'
assert records[0]['status'] == 'documented'
assert records[1]['status'] == 'follow-up'
assert records[2]['subject'] == 'read after correction'
assert records[2]['why'] == 'the final matching record wins'
for record in records:
    assert record['feature'] == '001-add-caching'
    assert record['session'] == '001-wire-the-cache'
PY
}

@test "escaped pipes and backslashes round-trip through both record kinds" {
    run knowledge \
        --component 'cache\|fallback|uses \\ local state|after a miss' \
        --gotcha 'read\|write|keeps \\ ordering'
    [ "$status" -eq 0 ]

    python3 - "$STORE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    component, condition = [json.loads(line) for line in fh][-2:]
assert component['name'] == 'cache|fallback'
assert component['role'] == 'uses \\ local state'
assert condition['subject'] == 'read|write'
assert condition['why'] == 'keeps \\ ordering'
PY
}

@test "an empty batch succeeds without writing records" {
    before="$(wc -l < "$STORE")"
    run knowledge
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$STORE")" -eq "$before" ]
}

@test "missing session state errors rather than silently writing" {
    rm -f "$TESTREPO/.fluencyloop/state.json"
    run knowledge --component "cache|keeps values|after a miss"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no active session"* ]]
    [ "$(wc -l < "$STORE")" -eq 2 ]
}

@test "can target a legacy feature/session without changing branch state" {
    run knowledge --feature "legacy-caching" --session "000-legacy-import" \
        --component "cache reader|serves historical cache entries|during a cache hit"
    [ "$status" -eq 0 ]
    python3 - "$TESTREPO/docs/fluencyloop/store/features/legacy-caching.jsonl" <<'PY'
import json, sys
r = json.loads(list(open(sys.argv[1], encoding='utf-8'))[-1])
assert r['feature'] == 'legacy-caching'
assert r['session'] == '000-legacy-import'
PY
    [ "$(git branch --show-current)" = "feature/001-add-caching" ]
}

@test "requires both historical target flags" {
    run knowledge --feature "legacy-caching" --component "cache|keeps values|after a miss"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--feature and --session"* ]]
}
