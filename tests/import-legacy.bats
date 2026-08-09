#!/usr/bin/env bats
# import-legacy.sh — rigid legacy decision blocks become marked, idempotent store records.

load test_helper

setup() {
    setup_initialized_repo
    LEGACY="$TESTREPO/docs/fluencyloop/features/001-add-caching/sessions/001-wire-cache.md"
    STORE="$TESTREPO/docs/fluencyloop/store/features/001-add-caching.jsonl"
    mkdir -p "$(dirname "$LEGACY")"
    printf '%s\n' \
        '# Session: cache wiring' \
        '## Decision: choose an LRU cache' \
        '- **where:** `src/cache.js`' \
        '- **why:** memory must stay bounded' \
        '- **alternative:** unbounded map - rejected: leaks' \
        '- **design:** ../design.md#cache' \
        '- **constitution:** section-2' > "$LEGACY"
    printf '%b\n' '- **trust:** \342\234\223 verified' >> "$LEGACY"
    printf '%s\n' \
        '## Decision: cache failures remain visible' \
        '- **where:** `src/cache.js`' \
        '- **why:** callers must distinguish a miss from failure' >> "$LEGACY"
    printf '%b\n' '- **trust:** \342\232\240 not independently verified' >> "$LEGACY"
    printf '%s\n' \
        '## Decision: malformed legacy block' \
        '- **where:** `src/cache.js`' >> "$LEGACY"
    printf '%b\n' '- **trust:** \342\234\223 verified' >> "$LEGACY"
}

@test "imports full and minimal decisions, both trust values, and skips malformed blocks" {
    run bash "$BIN/import-legacy.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning: skipped malformed legacy record"* ]]

    python3 - "$STORE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    records = [json.loads(line) for line in fh]
assert len(records) == 2, records
full, minimal = records
assert full['title'] == 'choose an LRU cache'
assert full['where'] == 'src/cache.js'
assert full['why'] == 'memory must stay bounded'
assert full['alternative'] == 'unbounded map - rejected: leaks'
assert full['design'] == '../design.md#cache'
assert full['constitution'] == 'section-2'
assert full['trust'] == 'verified'
assert minimal['title'] == 'cache failures remain visible'
assert minimal['trust'] == 'unverified'
for field in ('alternative', 'design', 'constitution'):
    assert field not in minimal, (field, minimal)
for n, record in enumerate(records, 1):
    assert record['feature'] == '001-add-caching'
    assert record['session'] == '001-wire-cache'
    assert record['imported_from'].endswith(f'#decision-{n}')
PY
}

@test "leaves the legacy markdown untouched and a second run byte-identical" {
    before="$(git hash-object "$LEGACY")"
    bash "$BIN/import-legacy.sh" >/dev/null
    first="$(git hash-object "$STORE")"
    bash "$BIN/import-legacy.sh" >/dev/null
    second="$(git hash-object "$STORE")"
    [ "$(git hash-object "$LEGACY")" = "$before" ]
    [ "$first" = "$second" ]
}

@test "first normal command imports legacy history automatically" {
    run bash "$BIN/check.sh" --json
    [ "$status" -eq 0 ]
    [ -f "$STORE" ]
}
