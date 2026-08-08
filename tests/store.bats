#!/usr/bin/env bats
# common.sh — the append-only store: paths and store_append.
# Mirrored by tests/powershell/store.Tests.ps1.

load test_helper

setup() { setup_initialized_repo; source "$BIN/common.sh"; }

# Every line of a store file must parse on its own — that is the whole point of JSONL, and the
# property the site and every reader depend on.
assert_valid_jsonl() {
    python3 - "$1" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    for n, line in enumerate(fh, 1):
        try:
            obj = json.loads(line)
        except Exception as e:
            raise SystemExit("line %d is not JSON: %s" % (n, e))
        if not isinstance(obj, dict):
            raise SystemExit("line %d is not an object" % n)
PY
}

@test "store paths live under docs/fluencyloop/store" {
    [ "$(store_dir)" = "$TESTREPO/docs/fluencyloop/store" ]
    [ "$(feature_store_path add-caching)" = "$TESTREPO/docs/fluencyloop/store/features/add-caching.jsonl" ]
    [ "$(concepts_store_path)" = "$TESTREPO/docs/fluencyloop/store/concepts.jsonl" ]
}

@test "store_append creates the parent dir and writes one line" {
    local f; f="$(feature_store_path add-caching)"
    [ ! -d "$(dirname "$f")" ]
    store_append "$f" type decision title "Chose a read-through cache"
    [ -f "$f" ]
    [ "$(wc -l < "$f")" -eq 1 ]
    [ "$(cat "$f")" = '{"type":"decision","title":"Chose a read-through cache"}' ]
    assert_valid_jsonl "$f"
}

@test "store_append appends without truncating" {
    local f; f="$(concepts_store_path)"
    store_append "$f" type concept name "supersede-on-read"
    store_append "$f" type concept name "per-feature stream"
    store_append "$f" type relation from "supersede-on-read" to "per-feature stream"
    [ "$(wc -l < "$f")" -eq 3 ]
    run head -1 "$f"
    [ "$output" = '{"type":"concept","name":"supersede-on-read"}' ]
    assert_valid_jsonl "$f"
}

@test "store_append skips pairs whose value is empty" {
    local f; f="$(feature_store_path opt)"
    store_append "$f" type decision alternative "" why "measured, not guessed" design ""
    [ "$(cat "$f")" = '{"type":"decision","why":"measured, not guessed"}' ]
    # The keys are absent entirely, not present-and-empty.
    run grep -c 'alternative' "$f"
    [ "$status" -ne 0 ]
}

@test "store_append round-trips quotes, backslashes, and newlines" {
    local f; f="$(feature_store_path esc)"
    store_append "$f" type note text 'he said "no" \ then left' body "$(printf 'one\ntwo')"
    # Still exactly one line: the embedded newline is escaped, not written raw.
    [ "$(wc -l < "$f")" -eq 1 ]
    assert_valid_jsonl "$f"
    # Compared inside python rather than by capturing its stdout: python's text mode rewrites \n
    # to \r\n on Windows, so a value with a newline in it comes back through the shell mangled
    # and the test fails on a platform where the stored data is perfectly correct.
    python3 - "$f" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    obj = json.loads(fh.readline())
assert obj["text"] == 'he said "no" \\ then left', repr(obj["text"])
assert obj["body"] == "one\ntwo", repr(obj["body"])
PY
}

@test "store_append with no pairs writes an empty object rather than failing" {
    # Guards the bash 3.2 empty-array expansion under `set -u`.
    local f; f="$(feature_store_path empty)"
    store_append "$f"
    [ "$(cat "$f")" = '{}' ]
}

@test "store files are covered by the LF pin init.sh writes" {
    # Append correctness on Windows depends on the store subtree being pinned to LF. The glob
    # `docs/fluencyloop/**` matches across directories, so it already covers store/.
    run git check-attr text -- "docs/fluencyloop/store/features/x.jsonl"
    [ "$status" -eq 0 ]
    [[ "$output" == *": text: set" ]]
    run git check-attr eol -- "docs/fluencyloop/store/concepts.jsonl"
    [[ "$output" == *": eol: lf" ]]
}
