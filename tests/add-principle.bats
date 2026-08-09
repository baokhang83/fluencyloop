#!/usr/bin/env bats
# add-principle.sh — constitution citations have matching append-only principle records.

load test_helper

setup() {
    setup_initialized_repo
    STORE="$TESTREPO/docs/fluencyloop/store/concepts.jsonl"
}

principle() { bash "$BIN/add-principle.sh" "$@"; }

@test "appends a schema-complete repository-wide principle" {
    run principle --number "§1" --title "append-only store" \
        --rule "Store writers only append JSONL records." \
        --why "Corrections must remain auditable."
    [ "$status" -eq 0 ]

    python3 - "$STORE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    record = json.loads(list(fh)[-1])
assert record['schema_version'] == '1'
assert record['type'] == 'principle'
assert record['ts']
assert record['feature'] == 'global'
assert record['session'] == 'none'
assert record['commit']
assert record['number'] == '§1'
assert record['title'] == 'append-only store'
assert record['rule'] == 'Store writers only append JSONL records.'
assert record['why'] == 'Corrections must remain auditable.'
PY
}

@test "a corrected principle appends a later record with the same number" {
    principle --number "§1" --title "append-only store" \
        --rule "Store writers append records." --why "History is auditable." >/dev/null
    principle --number "§1" --title "append-only store" \
        --rule "Store writers append one JSONL object per line." \
        --why "History is mergeable and auditable." >/dev/null

    [ "$(wc -l < "$STORE")" -eq 2 ]
    python3 - "$STORE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    earlier, later = map(json.loads, fh)
assert earlier['number'] == later['number'] == '§1'
assert later['rule'] == 'Store writers append one JSONL object per line.'
PY
}

@test "requires every principle field and a citation number" {
    run principle --number "one" --title "append-only store" \
        --rule "Store writers append records." --why "History is auditable."
    [ "$status" -ne 0 ]
    [[ "$output" == *"constitution citation"* ]]
    [ ! -e "$STORE" ]
}
