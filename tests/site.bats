#!/usr/bin/env bats
# The site is a live reader: it must bind only locally, derive the repo from the caller's current
# directory, and re-read current records without generating an artifact in the project.

load test_helper

SITE_PID=''
BLOCKER_PID=''
MANAGED_SITE=false

stop_servers() {
    for pid in "$SITE_PID" "$BLOCKER_PID"; do
        [ -n "$pid" ] || continue
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    done
    if $MANAGED_SITE && [ -n "${TESTREPO:-}" ] && [ -d "$TESTREPO" ]; then
        (cd "$TESTREPO" && bash "$DIST/fluencyloop" site --stop --json >/dev/null 2>&1 || true)
    fi
}

teardown() {
    stop_servers
    [ -n "${TESTREPO:-}" ] && rm -rf "$TESTREPO"
}

start_site() {
    SITE_LOG="$BATS_TEST_TMPDIR/fluencyloop-site-${RANDOM}.log"
    bash "$DIST/fluencyloop" site "$@" >"$SITE_LOG" 2>&1 &
    SITE_PID=$!
    # Git Bash runners occasionally take longer than the nominal ten seconds to launch their
    # first Node process after a repository setup. Polling remains cheap when it starts normally,
    # but give that cold start a deterministic 30-second window instead of a timing-dependent fail.
    for attempt in $(seq 1 300); do
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

@test "record detail renders its structured explanation and safe diagram companion" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the site test"
    setup_initialized_repo
    store="$TESTREPO/docs/fluencyloop/store/concepts.jsonl"
    mkdir -p "$(dirname "$store")" "$TESTREPO/docs/fluencyloop/diagrams/records"
    printf '%s\n' '{"schema_version":"1","type":"concept","ts":"2026-08-11","feature":"cache","session":"001","commit":"abc","name":"read through cache","problem":"avoid repeated remote reads","how":"read local state before the remote service","realized_by":"CacheClient"}' >> "$store"
    printf '%s\n' '{"schema_version":"1","type":"record_explanation","ts":"2026-08-11","feature":"cache","session":"001","commit":"abc","record":"read through cache","context":"Repeated remote reads add latency.","decision":"Read the cache before the remote service.","mechanism":"The client fetches only after a cache miss.","consequences":"Reads are fast, with bounded staleness.","diagram_path":"docs/fluencyloop/diagrams/records/read-through-cache.html","diagram_type":"architecture","diagram_alt":"A client checks a cache before the remote service."}' >> "$store"
    cp "$REPO_ROOT/tests/fixtures/record-diagram.html" "$TESTREPO/docs/fluencyloop/diagrams/records/read-through-cache.html"
    start_site --port 0

    run request /records/read-through-cache
    [ "$status" -eq 0 ]
    [[ "$output" == *"Repeated remote reads add latency."* ]]
    [[ "$output" == *"Read the cache before the remote service."* ]]
    [[ "$output" == *"The client fetches only after a cache miss."* ]]
    [[ "$output" == *"Reads are fast, with bounded staleness."* ]]
    [[ "$output" == *'src="/records/read-through-cache/diagram"'* ]]
    [[ "$output" == *"A client checks a cache before the remote service."* ]]

    run python3 - "$SITE_URL/records/read-through-cache/diagram" <<'PY'
import sys
import urllib.request

with urllib.request.urlopen(sys.argv[1]) as response:
    print(response.status)
    print(response.headers['Content-Security-Policy'])
    print(response.read().decode('utf-8'))
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"200"* ]]
    [[ "$output" == *"default-src 'none'"* ]]
    [[ "$output" == *'data-fluencyloop-theme="light"'* ]]
    [[ "$output" == *"Client checks cache before remote service"* ]]

    run python3 - "$SITE_URL/records/read-through-cache/diagram?theme=dark" <<'PY'
import sys
import urllib.request

with urllib.request.urlopen(sys.argv[1]) as response:
    print(response.read().decode('utf-8'))
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *'data-fluencyloop-theme="dark"'* ]]
    [[ "$output" == *'id="fluencyloop-embedded-dark-theme"'* ]]
    [[ "$output" == *'--color-paper: #151a21;'* ]]
}

@test "site renders a safe diagram companion below the product technical overview" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the site test"
    setup_initialized_repo
    mkdir -p "$TESTREPO/docs/fluencyloop/distillations" "$TESTREPO/docs/fluencyloop/diagrams"
    printf '%s\n' 'The client reads its local cache before it asks the remote service.' \
        > "$TESTREPO/docs/fluencyloop/distillations/product.md"
    cp "$REPO_ROOT/tests/fixtures/record-diagram.html" "$TESTREPO/docs/fluencyloop/diagrams/product-overview.html"
    start_site --port 0

    run request /
    [ "$status" -eq 0 ]
    [[ "$output" == *"The client reads its local cache before it asks the remote service."* ]]
    [[ "$output" == *'src="/overview/diagram"'* ]]
    [[ "$output" == *"System diagram supporting the technical overview."* ]]

    run python3 - "$SITE_URL/overview/diagram" <<'PY'
import sys
import urllib.request

with urllib.request.urlopen(sys.argv[1]) as response:
    print(response.status)
    print(response.headers['Content-Security-Policy'])
    print(response.read().decode('utf-8'))
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"200"* ]]
    [[ "$output" == *"default-src 'none'"* ]]
    [[ "$output" == *'data-fluencyloop-theme="light"'* ]]
    [[ "$output" == *"Client checks cache before remote service"* ]]
}

@test "site explains why an embedded overview diagram with remote fonts is unavailable" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the site test"
    setup_initialized_repo
    mkdir -p "$TESTREPO/docs/fluencyloop/distillations" "$TESTREPO/docs/fluencyloop/diagrams"
    printf '%s\n' 'The product overview remains readable without its companion diagram.' \
        > "$TESTREPO/docs/fluencyloop/distillations/product.md"
    printf '%s\n' '<!doctype html><link href="https://fonts.googleapis.com/css2?family=Geist" rel="stylesheet">' \
        > "$TESTREPO/docs/fluencyloop/diagrams/product-overview.html"
    start_site --port 0

    run request /
    [ "$status" -eq 0 ]
    [[ "$output" == *'class="diagram-unavailable"'* ]]
    [[ "$output" == *"embedded diagrams must be self-contained"* ]]
    [[ "$output" == *"Remove remote fonts, URLs, and executable content."* ]]

    run request /overview/diagram
    [ "$status" -ne 0 ]
    [[ "$output" == *"404"* ]]
}

@test "site keeps indented Markdown list continuations in their list item" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the site test"
    setup_initialized_repo
    mkdir -p "$TESTREPO/docs/fluencyloop/distillations"
    printf '%s\n' '# Product overview' '**Shape:**' \
        '- `AppComponent` is a pure two-column layout host; it lays the list and detail panels side by' \
        '  side and owns no state of its own.' > "$TESTREPO/docs/fluencyloop/distillations/product.md"
    start_site --port 0

    run request /
    [ "$status" -eq 0 ]
    [[ "$output" == *'<li><code>AppComponent</code> is a pure two-column layout host; it lays the list and detail panels side by side and owns no state of its own.</li>'* ]]
    [[ "$output" != *'</li></ul><p>side and owns no state of its own.</p>'* ]]
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

@test "managed site ensures, reuses, and stops a user-local server" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the site test"
    setup_initialized_repo
    export FLUENCYLOOP_HOME="$BATS_TEST_TMPDIR/managed-home-$RANDOM"
    MANAGED_SITE=true
    before="$(git status --porcelain)"

    run bash "$DIST/fluencyloop" site --ensure --json
    [ "$status" -eq 0 ]
    first="$output"
    first_url="$(printf '%s' "$first" | json_field url)"
    [ "$first_url" = "http://127.0.0.1:44444" ]
    SITE_URL="$first_url"
    printf '%s' "$first" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert d["running"] and not d["reused"],d'

    run request /
    [ "$status" -eq 0 ]
    [[ "$output" == *"200"* ]]

    run bash "$DIST/fluencyloop" site --ensure --json
    [ "$status" -eq 0 ]
    second="$output"
    [ "$(printf '%s' "$second" | json_field url)" = "$first_url" ]
    printf '%s' "$second" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert d["running"] and d["reused"],d'

    run bash "$DIST/fluencyloop" site --stop --json
    [ "$status" -eq 0 ]
    printf '%s' "$output" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert d["stopped"] and not d["running"],d'
    MANAGED_SITE=false
    [ "$(git status --porcelain)" = "$before" ]
}

@test "managed site opens the ensured loopback reader on request" {
    setup_initialized_repo
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the site test"
    case "$(uname -s)" in Linux) opener_name=xdg-open ;; Darwin) opener_name=open ;; *) skip "browser-opener interception is unsupported" ;; esac
    export FLUENCYLOOP_HOME="$BATS_TEST_TMPDIR/managed-home-$RANDOM"
    opener_dir="$BATS_TEST_TMPDIR/browser-opener-$RANDOM"
    opened_url="$BATS_TEST_TMPDIR/opened-url-$RANDOM"
    mkdir -p "$opener_dir"
    printf '#!/usr/bin/env bash\nprintf %%s "$1" > "%s"\n' "$opened_url" > "$opener_dir/$opener_name"
    chmod +x "$opener_dir/$opener_name"
    MANAGED_SITE=true

    run env PATH="$opener_dir:$PATH" bash "$DIST/fluencyloop" site --ensure --open --port 0 --json
    [ "$status" -eq 0 ]
    printf '%s' "$output" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert d["running"] and d["browser_opened"],d'
    expected_url="$(printf '%s' "$output" | json_field url)"
    for attempt in $(seq 1 50); do
        [ -f "$opened_url" ] && break
        sleep 0.1
    done
    [ "$(cat "$opened_url")" = "$expected_url" ]
}

@test "managed site opens once when successive workflow entries request it" {
    setup_initialized_repo
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the site test"
    case "$(uname -s)" in Linux) opener_name=xdg-open ;; Darwin) opener_name=open ;; *) skip "browser-opener interception is unsupported" ;; esac
    export FLUENCYLOOP_HOME="$BATS_TEST_TMPDIR/managed-home-$RANDOM"
    opener_dir="$BATS_TEST_TMPDIR/browser-opener-$RANDOM"
    opened_urls="$BATS_TEST_TMPDIR/opened-urls-$RANDOM"
    mkdir -p "$opener_dir"
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$1" >> "%s"\n' "$opened_urls" > "$opener_dir/$opener_name"
    chmod +x "$opener_dir/$opener_name"
    MANAGED_SITE=true

    run env PATH="$opener_dir:$PATH" bash "$DIST/fluencyloop" site --ensure --open-once --port 0 --json
    [ "$status" -eq 0 ]
    printf '%s' "$output" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert d["running"] and d["browser_opened"],d'

    run env PATH="$opener_dir:$PATH" bash "$DIST/fluencyloop" site --ensure --open-once --json
    [ "$status" -eq 0 ]
    printf '%s' "$output" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert d["running"] and not d["browser_opened"],d'

    for attempt in $(seq 1 50); do
        [ -f "$opened_urls" ] && [ "$(wc -l < "$opened_urls")" -eq 1 ] && break
        sleep 0.1
    done
    [ "$(wc -l < "$opened_urls")" -eq 1 ]
}

@test "managed site stays up for concurrent agent sessions, then idles after the last one ends" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the site test"
    setup_initialized_repo
    export FLUENCYLOOP_HOME="$BATS_TEST_TMPDIR/managed-home-$RANDOM"
    # The child receives its first lease at spawn time. A one-millisecond idle window makes the
    # former parent/child lease hand-off race fail deterministically instead of only on slow CI.
    export FLUENCYLOOP_SITE_IDLE_MS=1
    export FLUENCYLOOP_SITE_IDLE_CHECK_MS=1
    MANAGED_SITE=true

    run bash "$DIST/fluencyloop" site --session-start codex-session --json
    [ "$status" -eq 0 ]
    printf '%s' "$output" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert d["running"] and d["session_count"] == 1,d'

    run bash "$DIST/fluencyloop" site --session-start claude-session --json
    [ "$status" -eq 0 ]
    printf '%s' "$output" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert d["running"] and d["session_count"] == 2,d'

    sleep 0.3
    run bash "$DIST/fluencyloop" site --status --json
    [ "$status" -eq 0 ]
    printf '%s' "$output" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert d["running"] and d["session_count"] == 2,d'

    run bash "$DIST/fluencyloop" site --session-end codex-session --json
    [ "$status" -eq 0 ]
    printf '%s' "$output" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert d["running"] and d["session_count"] == 1,d'

    sleep 0.3
    run bash "$DIST/fluencyloop" site --status --json
    [ "$status" -eq 0 ]
    printf '%s' "$output" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert d["running"] and d["session_count"] == 1,d'

    run bash "$DIST/fluencyloop" site --session-end claude-session --json
    [ "$status" -eq 0 ]
    printf '%s' "$output" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert d["running"] and d["session_count"] == 0,d'

    sleep 0.3
    run bash "$DIST/fluencyloop" site --status --json
    [ "$status" -eq 0 ]
    printf '%s' "$output" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert not d["running"],d'
    MANAGED_SITE=false
}

@test "managed site falls forward from busy port 44444 without killing its owner" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the site test"
    setup_initialized_repo
    export FLUENCYLOOP_HOME="$BATS_TEST_TMPDIR/managed-home-$RANDOM"
    node -e 'require("node:http").createServer(() => {}).listen(44444, "127.0.0.1")' >/dev/null 2>&1 &
    BLOCKER_PID=$!
    for attempt in $(seq 1 100); do
        if kill -0 "$BLOCKER_PID" 2>/dev/null; then
            break
        fi
        sleep 0.1
    done
    MANAGED_SITE=true

    run bash "$DIST/fluencyloop" site --ensure --json
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | json_field url)" = "http://127.0.0.1:44445" ]
    kill -0 "$BLOCKER_PID"
}

@test "managed site replaces stale lifecycle state" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the site test"
    setup_initialized_repo
    export FLUENCYLOOP_HOME="$BATS_TEST_TMPDIR/managed-home-$RANDOM"
    root="$(git rev-parse --show-toplevel)"
    site_id="$(node -e 'const crypto=require("node:crypto");console.log(crypto.createHash("sha256").update(process.argv[1]).digest("hex").slice(0,32))' "$root")"
    mkdir -p "$FLUENCYLOOP_HOME/sites"
    printf '{"id":"%s","root":"%s","pid":999999,"port":44444,"url":"http://127.0.0.1:44444"}\n' "$site_id" "$root" \
        > "$FLUENCYLOOP_HOME/sites/$site_id.json"
    MANAGED_SITE=true

    run bash "$DIST/fluencyloop" site --ensure --json
    [ "$status" -eq 0 ]
    printf '%s' "$output" | python3 -c 'import json,sys;d=json.load(sys.stdin);assert d["running"] and not d["reused"],d'
}

@test "site renders an empty store and a concept without relationships" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the site test"
    setup_initialized_repo
    start_site --port 0

    run request /
    [ "$status" -eq 0 ]
    [[ "$output" == *"No architectural records have been recorded yet."* ]]

    mkdir -p "$TESTREPO/docs/fluencyloop/store"
    printf '%s\n' '{"schema_version":"1","type":"concept","ts":"2026-08-09","feature":"global","session":"none","commit":"abc","name":"standalone reader","problem":"make the store legible","how":"serve its current records","realized_by":"site server"}' >> "$TESTREPO/docs/fluencyloop/store/concepts.jsonl"

    run request /records/standalone-reader
    [ "$status" -eq 0 ]
    [[ "$output" == *"standalone reader"* ]]
    [[ "$output" == *"This architectural record has no recorded relationships yet."* ]]
}

@test "site points a migrated project with decisions but no concepts at backfill, not at authoring cold" {
    # A project fresh off `fluencyloop import` has decisions/components/conditions -- deterministically
    # parsed from old markdown -- but zero concepts, since import never synthesizes one. The generic
    # "capture one with fluencyloop concept" empty state is the wrong next step there; backfill is.
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the site test"
    setup_initialized_repo
    mkdir -p "$TESTREPO/docs/fluencyloop/store/features"
    printf '%s\n' '{"schema_version":"1","type":"decision","ts":"2026-08-09","feature":"add-caching","session":"001-wire-cache","commit":"abc","title":"Chose an LRU cache","where":"src/cache.js","why":"memory must stay bounded","trust":"verified"}' \
        >> "$TESTREPO/docs/fluencyloop/store/features/add-caching.jsonl"
    start_site --port 0

    run request /
    [ "$status" -eq 0 ]
    [[ "$output" == *'fluencyloop backfill'* ]]
    [[ "$output" != *"Capture one with fluencyloop concept.<"* ]]

    run request /records
    [ "$status" -eq 0 ]
    [[ "$output" == *'fluencyloop backfill'* ]]
}

@test "site redirects retired concept URLs to architectural records" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the site test"
    setup_initialized_repo
    start_site --port 0

    run python3 - "$SITE_URL/concepts/example-record?tag=event-sourcing" <<'PY'
import sys
import urllib.error
import urllib.request

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        return None

try:
    urllib.request.build_opener(NoRedirect).open(sys.argv[1])
except urllib.error.HTTPError as error:
    print(error.code)
    print(error.headers['Location'])
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"308"* ]]
    [[ "$output" == *"/records/example-record?tag=event-sourcing"* ]]
}

@test "site navigates product, records, features, and current decisions" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the site test"
    setup_initialized_repo
    store="$TESTREPO/docs/fluencyloop/store/features/site-navigation.jsonl"
    mkdir -p "$(dirname "$store")" "$TESTREPO/docs/fluencyloop/store" "$TESTREPO/docs/fluencyloop/distillations/concepts" "$TESTREPO/docs/fluencyloop/distillations/features"
    printf '%s\n' '{"schema_version":"1","type":"feature","ts":"2026-08-09","feature":"site-navigation","session":"none","commit":"abc","slug":"site-navigation","intent":"make the project readable","branch":"feature/site-navigation","base_ref":"dev"}' >> "$store"
    printf '%s\n' '{"schema_version":"1","type":"requirement","ts":"2026-08-09","feature":"site-navigation","session":"none","commit":"abc","gap":"How should developers descend through detail?","answer":"Use linked levels.","consequence":"Every detail view needs up-navigation."}' >> "$store"
    printf '%s\n' '{"schema_version":"1","type":"open_question","ts":"2026-08-09","feature":"site-navigation","session":"none","commit":"abc","gap":"Which graph layout best explains relations?","why_it_matters":"The model-chosen visual is future work."}' >> "$store"
    printf '%s\n' '{"schema_version":"1","type":"decision","ts":"2026-08-09","feature":"site-navigation","session":"001-routes","commit":"abc","title":"render deep routes","where":"site/server.js","why":"old rationale"}' >> "$store"
    printf '%s\n' '{"schema_version":"1","type":"decision","ts":"2026-08-10","feature":"site-navigation","session":"001-routes","commit":"def","title":"render deep routes","where":"site/server.js","why":"the URL is the durable navigation contract"}' >> "$store"
    printf '%s\n' '{"schema_version":"1","type":"concept","ts":"2026-08-09","feature":"site-navigation","session":"001-routes","commit":"abc","name":"concept graph","problem":"show how the product ideas fit together","how":"link concepts, features, and decisions","realized_by":"site/server.js"}' >> "$TESTREPO/docs/fluencyloop/store/concepts.jsonl"
    printf '%s\n' '{"schema_version":"1","type":"relation","ts":"2026-08-09","feature":"site-navigation","session":"001-routes","commit":"abc","from":"concept graph","to":"site-navigation","kind":"realized_by"}' >> "$TESTREPO/docs/fluencyloop/store/concepts.jsonl"
    printf '%s\n' '# Product overview' 'The product is navigable.' > "$TESTREPO/docs/fluencyloop/distillations/product.md"
    printf '%s\n' '# Concept graph' 'Relationships carry architectural meaning.' > "$TESTREPO/docs/fluencyloop/distillations/concepts/concept-graph.md"
    printf '%s\n' '# Site navigation' 'Before: a record list. After: linked levels.' > "$TESTREPO/docs/fluencyloop/distillations/features/site-navigation.md"
    start_site --port 0

    run request /
    [ "$status" -eq 0 ]
    [[ "$output" == *"The product is navigable."* ]]
    [[ "$output" == *'href="/records/concept-graph"'* ]]
    [[ "$output" == *'href="/features/site-navigation"'* ]]

    run request /records
    [ "$status" -eq 0 ]
    [[ "$output" == *"Relationship graph"* ]]
    [[ "$output" == *"realized_by"* ]]
    [[ "$output" == *'href="/records/concept-graph"'* ]]
    [[ "$output" == *'href="/features/site-navigation"'* ]]

    run request /records/concept-graph
    [ "$status" -eq 0 ]
    [[ "$output" == *"Relationships carry architectural meaning."* ]]
    [[ "$output" == *"realized_by"* ]]
    [[ "$output" == *'href="/records/concept-graph"'* ]]
    [[ "$output" == *'href="/features/site-navigation"'* ]]

    run request /features/site-navigation
    [ "$status" -eq 0 ]
    [[ "$output" == *"Before: a record list. After: linked levels."* ]]
    [[ "$output" == *"Use linked levels."* ]]
    [[ "$output" == *"Which graph layout best explains relations?"* ]]
    [[ "$output" == *"the URL is the durable navigation contract"* ]]
    [[ "$output" != *"old rationale"* ]]
    [[ "$output" == *'href="/decisions/site-navigation/001-routes/site%2Fserver.js/render%20deep%20routes"'* ]]

    run request /decisions/site-navigation/001-routes/site%2Fserver.js/render%20deep%20routes
    [ "$status" -eq 0 ]
    [[ "$output" == *"the URL is the durable navigation contract"* ]]
    [[ "$output" == *'href="/features/site-navigation"'* ]]
    [[ "$output" == *'href="/records/concept-graph"'* ]]
    [[ "$output" == *'href="/"'* ]]
}

@test "site colors record cards by widely-known tags and filters records by them" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the site test"
    setup_initialized_repo
    mkdir -p "$TESTREPO/docs/fluencyloop/store/features"
    printf '%s\n' '{"schema_version":"1","type":"feature","ts":"2026-08-11","feature":"tag-filter","session":"none","commit":"abcdef123","slug":"tag-filter","intent":"make project records scannable","branch":"feature/tag-filter","base_ref":"dev"}' \
        >> "$TESTREPO/docs/fluencyloop/store/features/tag-filter.jsonl"
    printf '%s\n' '{"schema_version":"1","type":"feature","ts":"2026-08-10","feature":"unlinked","session":"none","commit":"uncommitted","slug":"unlinked","intent":"remain visible until a tag is selected","branch":"feature/unlinked","base_ref":"dev"}' \
        >> "$TESTREPO/docs/fluencyloop/store/features/unlinked.jsonl"
    printf '%s\n' '{"schema_version":"1","type":"decision","ts":"2026-08-12","feature":"tag-filter","session":"001","commit":"fedcba987","title":"filter on tags","where":"site","why":"tags make the record easier to scan"}' \
        >> "$TESTREPO/docs/fluencyloop/store/features/tag-filter.jsonl"
    printf '%s\n' '{"schema_version":"1","type":"concept","ts":"2026-08-11","feature":"tag-filter","session":"001","commit":"abcdef123","name":"supersede on read","problem":"find connected work","how":"filter cards in place","realized_by":"site","tags":"append-only log\nevent sourcing\nfaceted search\nread model\nstatic site"}' \
        >> "$TESTREPO/docs/fluencyloop/store/concepts.jsonl"
    printf '%s\n' '{"schema_version":"1","type":"concept","ts":"2026-08-11","feature":"global","session":"none","commit":"abcdef123","name":"untagged idea","problem":"stay renderable without a tag","how":"omit the field"}' \
        >> "$TESTREPO/docs/fluencyloop/store/concepts.jsonl"
    printf '%s\n' '{"schema_version":"1","type":"relation","ts":"2026-08-11","feature":"tag-filter","session":"001","commit":"abcdef123","from":"supersede on read","to":"tag-filter","kind":"realized_by"}' \
        >> "$TESTREPO/docs/fluencyloop/store/concepts.jsonl"
    start_site --port 0

    run request /records
    [ "$status" -eq 0 ]
    [[ "$output" == *'data-catalog'* ]]
    [[ "$output" == *'data-tag-filter="append-only-log"'* ]]
    [[ "$output" == *'data-tag-filter="event-sourcing"'* ]]
    # Tags inside a catalog row reuse the toolbar's filter button contract; a click filters
    # without navigating away. Dense rows cap visible chips while retaining all filter metadata.
    [[ "$output" == *'class="tag tag-button tone-0" data-tag-filter="append-only-log"'* ]]
    [[ "$output" == *'class="tag tag-button tone-1" data-tag-filter="event-sourcing"'* ]]
    [[ "$output" == *'data-record-row data-tags="append-only-log event-sourcing faceted-search read-model static-site"'* ]]
    [[ "$output" == *'+1 more</span>'* ]]
    # A concept without --tag still renders: tags are optional, never a hard requirement.
    [[ "$output" == *"untagged idea"* ]]

    run request /features
    [ "$status" -eq 0 ]
    [[ "$output" == *'data-tags="append-only-log event-sourcing faceted-search read-model static-site"'* ]]
    [[ "$output" == *'<time class="record-date" datetime="2026-08-11" title="Recorded 2026-08-11">2026-08-11</time>'* ]]
    [[ "$output" == *'data-record-row data-tags=""'* ]]

    run request /decisions/tag-filter/001/site/filter%20on%20tags
    [ "$status" -eq 0 ]
    [[ "$output" == *'class="tag tone-0" data-tag="append-only-log"'* ]]
    [[ "$output" == *'class="tag tone-4" data-tag="static-site"'* ]]
}

@test "site serves its visual layer locally with theme and motion safeguards" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the site test"
    setup_initialized_repo
    start_site --port 0

    for resource in / /assets/site.css /assets/site.js; do
        run request "$resource"
        [ "$status" -eq 0 ]
        [[ "$output" != *"http://"* ]]
        [[ "$output" != *"https://"* ]]
    done

    run request /assets/site.css
    [ "$status" -eq 0 ]
    [[ "$output" == *":root[data-theme=\"light\"]"* ]]
    [[ "$output" == *":root[data-theme=\"dark\"]"* ]]
    [[ "$output" == *"prefers-reduced-motion"* ]]
    [[ "$output" == *"overflow-x: hidden"* ]]
    # The reader ships no bundled typeface: it sets type in the system UI font, so no @font-face
    # or font asset should be served at all.
    [[ "$output" != *"@font-face"* ]]

    run request /assets/site.js
    [ "$status" -eq 0 ]
    [[ "$output" == *"syncEmbeddedDiagramThemes"* ]]
    [[ "$output" == *"url.searchParams.set('theme', theme)"* ]]

    run python3 - "$SITE_URL/assets/fonts/dm-sans.woff2" <<'PY'
import sys
import urllib.error
import urllib.request

try:
    urllib.request.urlopen(sys.argv[1])
    print("unexpectedly served")
except urllib.error.HTTPError as error:
    print(error.status)
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"404"* ]]

    run request /
    [ "$status" -eq 0 ]
    [[ "$output" == *'href="/assets/site.css"'* ]]
    [[ "$output" == *'src="/assets/site.js"'* ]]
    [[ "$output" == *"data-theme-toggle"* ]]
}

@test "site renders supported diagrams and keeps invalid or absent diagrams readable" {
    command -v node >/dev/null 2>&1 || skip "Node.js is required for the site test"
    setup_initialized_repo
    mkdir -p "$TESTREPO/docs/fluencyloop/store/features" "$TESTREPO/docs/fluencyloop/distillations/features"
    printf '%s\n' '{"schema_version":"1","type":"feature","ts":"2026-08-09","feature":"invalid-diagram","session":"none","commit":"abc","slug":"invalid-diagram","intent":"test diagram fallbacks","branch":"feature/invalid-diagram","base_ref":"dev"}' > "$TESTREPO/docs/fluencyloop/store/features/invalid-diagram.jsonl"
    printf '%s\n' '{"schema_version":"1","type":"feature","ts":"2026-08-09","feature":"plain-diagram","session":"none","commit":"abc","slug":"plain-diagram","intent":"test plain prose","branch":"feature/plain-diagram","base_ref":"dev"}' > "$TESTREPO/docs/fluencyloop/store/features/plain-diagram.jsonl"
    printf '%s\n' 'The writer and reader stay independently simple.' '```mermaid' 'flowchart LR' '  Writer[Writer] --> Reader[Reader]' '```' 'Diagram: The reader consumes records after the writer appends them.' > "$TESTREPO/docs/fluencyloop/distillations/product.md"
    printf '%s\n' 'The prose still explains this subject.' '```mermaid' 'this is not a supported diagram' '```' 'Diagram: The invalid visual must not hide this caption.' > "$TESTREPO/docs/fluencyloop/distillations/features/invalid-diagram.md"
    printf '%s\n' 'This subject is clearer as prose alone.' > "$TESTREPO/docs/fluencyloop/distillations/features/plain-diagram.md"
    start_site --port 0

    run request /
    [ "$status" -eq 0 ]
    [[ "$output" == *'class="diagram"'* ]]
    [[ "$output" == *'data-mermaid="'* ]]
    [[ "$output" == *"The reader consumes records after the writer appends them."* ]]
    [[ "$output" == *"The writer and reader stay independently simple."* ]]
    [[ "$output" != *"flowchart LR"* ]]

    run request /features/invalid-diagram
    [ "$status" -eq 0 ]
    [[ "$output" == *'class="diagram-unavailable"'* ]]
    [[ "$output" == *"The invalid visual must not hide this caption."* ]]
    [[ "$output" == *"The prose still explains this subject."* ]]
    [[ "$output" != *"this is not a supported diagram"* ]]

    run request /features/plain-diagram
    [ "$status" -eq 0 ]
    [[ "$output" == *'<p>This subject is clearer as prose alone.</p>'* ]]
    [[ "$output" != *'<pre class="distillation-prose">'* ]]
    [[ "$output" == *"This subject is clearer as prose alone."* ]]
    [[ "$output" != *'class="diagram"'* ]]
    [[ "$output" != *'class="diagram-unavailable"'* ]]
}
