#!/usr/bin/env bats
# The site is a live reader: it must bind only locally, derive the repo from the caller's current
# directory, and re-read current records without generating an artifact in the project.

load test_helper

SITE_PID=''
BLOCKER_PID=''

stop_servers() {
    for pid in "$SITE_PID" "$BLOCKER_PID"; do
        [ -n "$pid" ] || continue
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    done
}

teardown() {
    stop_servers
    [ -n "${TESTREPO:-}" ] && rm -rf "$TESTREPO"
}

start_site() {
    SITE_LOG="$BATS_TEST_TMPDIR/fluencyloop-site-${RANDOM}.log"
    bash "$DIST/fluencyloop" site "$@" >"$SITE_LOG" 2>&1 &
    SITE_PID=$!
    for attempt in $(seq 1 100); do
        if grep -q '^FluencyLoop site: http://127.0.0.1:' "$SITE_LOG"; then
            SITE_URL="$(sed -n 's/^FluencyLoop site: //p' "$SITE_LOG")"
            return 0
        fi
        if ! kill -0 "$SITE_PID" 2>/dev/null; then
            cat "$SITE_LOG" >&2
            return 1
        fi
        sleep 0.1
    done
    cat "$SITE_LOG" >&2
    return 1
}

request() {
    python3 - "$SITE_URL$1" <<'PY'
import sys
import urllib.request

with urllib.request.urlopen(sys.argv[1]) as response:
    print(response.status)
    print(response.headers['Content-Type'])
    print(response.read().decode('utf-8'))
PY
}

@test "site serves live project data from a subdirectory without writing the project" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the site test"
    setup_initialized_repo
    bash "$DIST/fluencyloop" concept --name "live reader" \
        --problem "read current project knowledge" \
        --how "renders store records on each request" \
        --realized-by "site server" >/dev/null
    mkdir -p docs/fluencyloop/distillations
    printf '%s\n' '# Live reader' > docs/fluencyloop/distillations/live-reader.md
    git add -A && git commit -qm "seed store"
    before="$(git status --porcelain)"

    mkdir -p nested/reader
    cd nested/reader
    start_site --port 0

    run request /
    [ "$status" -eq 0 ]
    [[ "$output" == *"200"* ]]
    [[ "$output" == *"text/html"* ]]
    [[ "$output" == *"live reader"* ]]
    [[ "$output" == *"live-reader.md"* ]]

    run request /api/site-data
    [ "$status" -eq 0 ]
    [[ "$output" == *"application/json"* ]]
    [[ "$output" == *'"name":"live reader"'* ]]

    run request /health
    [ "$status" -eq 0 ]
    [[ "$output" == *"application/json"* ]]
    [[ "$output" == *'"status":"ok"'* ]]

    after="$(git status --porcelain)"
    [ "$after" = "$before" ]
}

@test "site reloads changed store records without restart" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the site test"
    setup_initialized_repo
    start_site --port 0
    store="$TESTREPO/docs/fluencyloop/store/features/live.jsonl"
    mkdir -p "$(dirname "$store")"
    printf '%s\n' '{"schema_version":"1","type":"decision","ts":"2026-08-09","feature":"live","session":"001","commit":"uncommitted","title":"live decision","where":"site","why":"first"}' >> "$store"
    printf '%s\n' '{"schema_version":"1","type":"decision","ts":"2026-08-09","feature":"live","session":"001","commit":"uncommitted","title":"live decision","where":"site","why":"corrected"}' >> "$store"

    run python3 - "$SITE_URL/api/site-data" <<'PY'
import json
import sys
import urllib.request

with urllib.request.urlopen(sys.argv[1]) as response:
    data = json.load(response)
records = [record for record in data['store']['records'] if record.get('title') == 'live decision']
assert len(records) == 1
assert records[0]['why'] == 'corrected'
PY
    [ "$status" -eq 0 ]
}

@test "site tries the next loopback port when the default is busy" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the site test"
    setup_initialized_repo
    node -e 'require("node:http").createServer(() => {}).listen(4173, "127.0.0.1")' >/dev/null 2>&1 &
    BLOCKER_PID=$!
    for attempt in $(seq 1 100); do
        if python3 - <<'PY'
import socket
s = socket.socket()
try:
    s.connect(('127.0.0.1', 4173))
except OSError:
    raise SystemExit(1)
finally:
    s.close()
PY
        then
            break
        fi
        sleep 0.1
    done

    start_site
    [ "$SITE_URL" = "http://127.0.0.1:4174" ]
}
