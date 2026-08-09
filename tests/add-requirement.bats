#!/usr/bin/env bats
# add-requirement.sh — planning answers and unresolved gaps become append-only store records.

load test_helper

setup() {
    setup_initialized_repo
    STORE="$TESTREPO/docs/fluencyloop/store/concepts.jsonl"
}

requirement() { bash "$BIN/add-requirement.sh" "$@"; }

@test "appends a schema-complete answered requirement" {
    run requirement --gap "Which store format should the site read?" \
        --answer "Append-only JSONL." \
        --consequence "Readers select the last line for an identity."
    [ "$status" -eq 0 ]

    python3 - "$STORE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    record = json.loads(list(fh)[-1])
assert record['schema_version'] == '1'
assert record['type'] == 'requirement'
assert record['ts']
assert record['feature'] == 'global'
assert record['session'] == 'none'
assert record['commit']
assert record['gap'] == 'Which store format should the site read?'
assert record['answer'] == 'Append-only JSONL.'
assert record['consequence'] == 'Readers select the last line for an identity.'
PY
}

@test "appends a schema-complete open question" {
    run requirement --open "Which visual form best explains a concept?" \
        --matters "The site should choose the representation deliberately."
    [ "$status" -eq 0 ]

    python3 - "$STORE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    record = json.loads(list(fh)[-1])
assert record['type'] == 'open_question'
assert record['feature'] == 'global'
assert record['session'] == 'none'
assert record['gap'] == 'Which visual form best explains a concept?'
assert record['why_it_matters'] == 'The site should choose the representation deliberately.'
PY
}

@test "an answered open question appends a requirement without changing the earlier line" {
    requirement --open "Which visual form best explains a concept?" \
        --matters "The site needs a deliberate representation." >/dev/null
    requirement --gap "Which visual form best explains a concept?" \
        --answer "Use a concept graph." \
        --consequence "The site renders relationships between concepts." >/dev/null

    [ "$(wc -l < "$STORE")" -eq 2 ]
    python3 - "$STORE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    open_question, requirement = map(json.loads, fh)
assert open_question['type'] == 'open_question'
assert open_question['gap'] == requirement['gap']
assert requirement['type'] == 'requirement'
assert requirement['answer'] == 'Use a concept graph.'
PY
}

@test "requires one complete record form" {
    run requirement --gap "Which store format should the site read?" --answer "JSONL"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--consequence"* ]]
    [ ! -e "$STORE" ]
}
