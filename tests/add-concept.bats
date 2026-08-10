#!/usr/bin/env bats
# add-concept.sh — concepts and relations append to the shared product-level stream.

load test_helper

setup() {
    setup_initialized_repo
    bash "$BIN/new-feature.sh" "add caching" >/dev/null
    bash "$BIN/new-session.sh" --slug 001-add-caching "wire the cache" >/dev/null
    STORE="$TESTREPO/docs/fluencyloop/store/concepts.jsonl"
}

concept() { bash "$BIN/add-concept.sh" "$@"; }

last_record() {
    python3 - "$STORE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    print(json.dumps(json.loads(list(fh)[-1])))
PY
}

@test "appends a schema-complete concept to the global stream" {
    run concept --name "read through cache" \
        --problem "avoid repeated remote reads" \
        --how "look in the cache before calling the remote service" \
        --realized-by "src/cache.js"
    [ "$status" -eq 0 ]
    [ -f "$STORE" ]

    last_record | python3 -c '
import json, sys
r = json.load(sys.stdin)
assert r["schema_version"] == "1"
assert r["type"] == "concept"
assert r["ts"]
assert r["feature"] == "001-add-caching"
assert r["session"] == "001-wire-the-cache"
assert r["commit"]
assert r["name"] == "read through cache"
assert r["problem"] == "avoid repeated remote reads"
assert r["how"] == "look in the cache before calling the remote service"
assert r["realized_by"] == "src/cache.js"
'
}

@test "re-stating a concept appends a newer record" {
    concept --name "read through cache" --problem "avoid repeated remote reads" \
        --how "read the cache first" --realized-by "src/cache.js"
    concept --name "read through cache" --problem "avoid repeated remote reads" \
        --how "read the cache first and refresh after a miss" --realized-by "src/cache.js"

    [ "$(wc -l < "$STORE")" -eq 2 ]
    last_record | python3 -c '
import json, sys
r = json.load(sys.stdin)
assert r["name"] == "read through cache"
assert r["how"] == "read the cache first and refresh after a miss"
'
}

@test "repeated --realized-by values stay in one concept record" {
    concept --name "read through cache" --problem "avoid repeated remote reads" \
        --how "read the cache first" --realized-by "src/cache.js" \
        --realized-by "CacheClient"

    [ "$(wc -l < "$STORE")" -eq 1 ]
    last_record | python3 -c '
import json, sys
r = json.load(sys.stdin)
assert r["realized_by"].splitlines() == ["src/cache.js", "CacheClient"]
'
}

@test "repeated --tag values join into one newline-delimited field" {
    concept --name "read through cache" --problem "avoid repeated remote reads" \
        --how "read the cache first" --realized-by "src/cache.js" \
        --tag "read-through cache" --tag "cache-aside"

    [ "$(wc -l < "$STORE")" -eq 1 ]
    last_record | python3 -c '
import json, sys
r = json.load(sys.stdin)
assert r["tags"].splitlines() == ["read-through cache", "cache-aside"]
'
}

@test "omitting --tag writes no tags field, not an empty one" {
    concept --name "read through cache" --problem "avoid repeated remote reads" \
        --how "read the cache first" --realized-by "src/cache.js"

    last_record | python3 -c '
import json, sys
r = json.load(sys.stdin)
assert "tags" not in r
'
}

@test "appends relations even when their concepts are unknown" {
    run concept --relate "unknown concept|CacheClient|realized_by"
    [ "$status" -eq 0 ]

    last_record | python3 -c '
import json, sys
r = json.load(sys.stdin)
assert r["type"] == "relation"
assert r["from"] == "unknown concept"
assert r["to"] == "CacheClient"
assert r["kind"] == "realized_by"
assert r["feature"] == "001-add-caching"
assert r["session"] == "001-wire-the-cache"
'
}
