#!/usr/bin/env bats
# Architectural record explanations use the global stream and retain the feature/session envelope.

load test_helper

setup() {
    setup_initialized_repo
    bash "$BIN/new-feature.sh" "explain the cache" >/dev/null
    bash "$BIN/new-session.sh" --slug 001-explain-cache "write record explanation" >/dev/null
    STORE="$TESTREPO/docs/fluencyloop/store/concepts.jsonl"
}

explain() { bash "$BIN/add-record-explanation.sh" "$@"; }

explain_required() {
    explain --record "read through cache" \
        --context "Repeated remote reads add latency." \
        --decision "Read the cache before the remote service." \
        --mechanism "The client checks the local value and fetches only after a miss." \
        --consequences "Repeated reads are fast, while callers must accept bounded staleness." \
        "$@"
}

last_record() {
    python3 - "$STORE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    print(json.dumps(json.loads(list(fh)[-1])))
PY
}

@test "appends a schema-complete architectural record explanation" {
    run explain_required
    [ "$status" -eq 0 ]

    last_record | python3 -c '
import json, sys
r = json.load(sys.stdin)
assert r["schema_version"] == "1"
assert r["type"] == "record_explanation"
assert r["feature"] == "001-explain-cache"
assert r["session"] == "001-write-record-explanation"
assert r["record"] == "read through cache"
assert r["context"] == "Repeated remote reads add latency."
assert r["decision"] == "Read the cache before the remote service."
assert r["mechanism"] == "The client checks the local value and fetches only after a miss."
assert r["consequences"] == "Repeated reads are fast, while callers must accept bounded staleness."
assert "diagram_path" not in r
'
}

@test "correction appends a later explanation for the same record" {
    explain_required
    explain --record "read through cache" \
        --context "Repeated remote reads add latency." \
        --decision "Read the cache before the remote service." \
        --mechanism "The client refreshes the local value after a miss." \
        --consequences "Repeated reads are fast, while callers must accept bounded staleness."

    [ "$(wc -l < "$STORE")" -eq 2 ]
    last_record | python3 -c 'import json,sys; assert json.load(sys.stdin)["mechanism"] == "The client refreshes the local value after a miss."'
}

@test "stores a diagram only with complete safe metadata" {
    local diagram="$TESTREPO/docs/fluencyloop/diagrams/records/read-through-cache.html"
    mkdir -p "${diagram%/*}"
    cp "$REPO_ROOT/LICENSE" "$diagram"

    run explain_required \
        --diagram "docs/fluencyloop/diagrams/records/read-through-cache.html" \
        --diagram-type architecture \
        --diagram-alt "A cache client reads a local value before the remote service."
    [ "$status" -eq 0 ]

    last_record | python3 -c '
import json,sys
r = json.load(sys.stdin)
assert r["diagram_path"] == "docs/fluencyloop/diagrams/records/read-through-cache.html"
assert r["diagram_type"] == "architecture"
assert r["diagram_alt"] == "A cache client reads a local value before the remote service."
'
}

@test "rejects incomplete and unsafe diagram metadata" {
    run explain_required --diagram-type architecture
    [ "$status" -ne 0 ]
    [[ "$output" == *"--diagram is required"* ]]

    run explain_required --diagram "docs/fluencyloop/diagrams/records/../escape.html" \
        --diagram-type architecture --diagram-alt "bad path"
    [ "$status" -ne 0 ]
    [[ "$output" == *"safe project-relative HTML"* ]]
}

@test "requires every explanation section" {
    run explain --record "read through cache" --context "latency" --decision "cache first" \
        --mechanism "check local value"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--consequences is required"* ]]
}
