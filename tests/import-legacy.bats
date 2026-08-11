#!/usr/bin/env bats
# import-legacy.sh — rigid legacy decision blocks become marked, idempotent store records.

load test_helper

setup() {
    setup_initialized_repo
    LEGACY="$TESTREPO/docs/fluencyloop/features/001-add-caching/sessions/001-wire-cache.md"
    STORE="$TESTREPO/docs/fluencyloop/store/features/001-add-caching.jsonl"
    mkdir -p "$(dirname "$LEGACY")"
    printf '%s\n' '# Design: add a bounded cache to the request path' \
        > "$TESTREPO/docs/fluencyloop/features/001-add-caching/design.md"
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

@test "imports full and minimal decisions plus one explicit legacy declaration pair" {
    run bash "$BIN/import-legacy.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning: skipped malformed legacy record"* ]]

    python3 - "$STORE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    records = [json.loads(line) for line in fh]
assert len(records) == 4, records
full, minimal = [record for record in records if record['type'] == 'decision']
feature = next(record for record in records if record['type'] == 'feature')
session = next(record for record in records if record['type'] == 'session')
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
    if record['type'] == 'decision':
        assert record['feature'] == '001-add-caching'
        assert record['session'] == '001-wire-cache'
        assert record['imported_from'].endswith(f'#decision-{n}')
assert feature['slug'] == '001-add-caching'
assert feature['intent'] == 'add a bounded cache to the request path'
assert feature['branch'] == 'legacy-import/001-add-caching'
assert feature['base_ref'] == 'legacy'
assert feature['imported_from'].endswith('#feature')
assert session['slug'] == '000-legacy-import'
assert session['intent'] == 'Backfill pre-0.3 session history.'
assert session['imported_from'].endswith('#backfill-session')
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
    [ "$(tr -d '\r\n' < "$(dirname "$STORE")/../.legacy-import-revision")" = "3" ]
    result="$(printf '%s\n' "$output" | tail -n 1)"
    [ "$(echo "$result" | json_field legacy_imported_features)" = "1" ]
    [ "$(echo "$result" | json_field legacy_migration_pending)" = "True" ] || [ "$(echo "$result" | json_field legacy_migration_pending)" = "true" ]
}

@test "shows import help without running the legacy importer" {
    [ ! -e "$STORE" ]
    run bash "$BIN/import-legacy.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--semantic-status"* ]]
    [ ! -e "$STORE" ]
}

@test "requires architectural records and an assessment for every imported feature before completion" {
    bash "$BIN/check.sh" --json >/dev/null
    run bash "$BIN/import-legacy.sh" --mark-semantic-complete
    [ "$status" -ne 0 ]
    [[ "$output" == *"assessed 0 of 1 imported feature"* ]]

    run bash "$BIN/import-legacy.sh" --assess-unconfirmed
    [ "$status" -eq 0 ]
    [ "$output" = "Recorded 1 unconfirmed legacy assessment(s)." ]

    run bash "$BIN/import-legacy.sh" --semantic-status --json
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | json_field architectural_records)" = "0" ]
    printf '%s' "$output" | python3 -c 'import json,sys;assert json.load(sys.stdin)["unassessed_features"] == []'

    python3 - "$STORE" <<'PY'
import json, sys
records = [json.loads(line) for line in open(sys.argv[1], encoding='utf-8')]
assessment = next(record for record in records if record['type'] == 'semantic_assessment')
assert assessment['trust'] == 'unverified', assessment
assert assessment['summary'] == 'Imported pre-0.3 history is unconfirmed pending independent review.', assessment
PY

    bash "$BIN/add-concept.sh" \
        --name "bounded cache" \
        --problem "keep repeated reads fast without unbounded memory" \
        --how "reuse values through an LRU cache" \
        --realized-by "src/cache.js" \
        --feature 001-add-caching --session 000-legacy-import >/dev/null
    run bash "$BIN/import-legacy.sh" --mark-semantic-complete
    [ "$status" -ne 0 ]
    [[ "$output" == *"no architectural records have tags for site filtering"* ]]

    bash "$BIN/add-concept.sh" \
        --name "bounded cache" \
        --problem "keep repeated reads fast without unbounded memory" \
        --how "reuse values through an LRU cache" \
        --realized-by "src/cache.js" \
        --tag "cache" --tag "bounded memory" \
        --feature 001-add-caching --session 000-legacy-import >/dev/null
    run bash "$BIN/import-legacy.sh" --mark-semantic-complete
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 assessment(s), and 1 architectural record(s)"* ]]

    run bash "$BIN/import-legacy.sh" --semantic-status --json
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | json_field tagged_architectural_records)" = "1" ]

    run bash "$BIN/check.sh" --json
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | json_field legacy_migration_pending)" = "False" ] || [ "$(echo "$output" | json_field legacy_migration_pending)" = "false" ]

    printf '3\n' > "$TESTREPO/docs/fluencyloop/store/.legacy-semantic-migration-revision"
    run bash "$BIN/check.sh" --json
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | json_field legacy_migration_pending)" = "True" ] || [ "$(echo "$output" | json_field legacy_migration_pending)" = "true" ]
}

@test "prints one compact map for shared architectural synthesis" {
    bash "$BIN/check.sh" --json >/dev/null
    bash "$BIN/add-concept.sh" \
        --name "bounded cache" \
        --problem "keep repeated reads fast without unbounded memory" \
        --how "reuse values through an LRU cache" \
        --realized-by "src/cache.js" \
        --feature 001-add-caching --session 000-legacy-import >/dev/null
    run bash "$BIN/import-legacy.sh" --semantic-map
    [ "$status" -eq 0 ]
    [[ "$output" == *"# Imported legacy record map"* ]]
    [[ "$output" == *"## 001-add-caching"* ]]
    [[ "$output" == *"Decision: choose an LRU cache — src/cache.js"* ]]
    [[ "$output" == *"# Existing architectural records"* ]]
    [[ "$output" == *"Record: bounded cache — tags: (missing)"* ]]
}

@test "a normal command repairs a store imported before declaration records existed" {
    mkdir -p "$(dirname "$STORE")"
    printf '%s\n' '{"schema_version":"1","type":"decision","ts":"2026-08-09","feature":"001-add-caching","session":"001-wire-cache","commit":"abc","title":"choose an LRU cache","where":"src/cache.js","why":"memory must stay bounded","trust":"verified","imported_from":"docs/fluencyloop/features/001-add-caching/sessions/001-wire-cache.md#decision-1"}' > "$STORE"

    run bash "$BIN/check.sh" --json
    [ "$status" -eq 0 ]

    python3 - "$STORE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    records = [json.loads(line) for line in fh]
assert sum(record['type'] == 'feature' for record in records) == 1, records
assert sum(record['type'] == 'session' and record['slug'] == '000-legacy-import' for record in records) == 1, records
assert sum(record['type'] == 'decision' and record['title'] == 'choose an LRU cache' for record in records) == 1, records
PY
}

@test "automatic repair leaves a native feature declaration with a legacy slug alone" {
    mkdir -p "$(dirname "$STORE")"
    printf '%s\n' '{"schema_version":"1","type":"feature","ts":"2026-08-09","feature":"001-add-caching","session":"none","commit":"abc","slug":"001-add-caching","intent":"native 0.3 work","branch":"feature/001-add-caching","base_ref":"dev"}' > "$STORE"

    run bash "$BIN/check.sh" --json
    [ "$status" -eq 0 ]

    python3 - "$STORE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    records = [json.loads(line) for line in fh]
assert len(records) == 1, records
assert records[0]['intent'] == 'native 0.3 work', records
PY
}

@test "a completed legacy import is retried once when the importer revision advances" {
    printf '%s\n' \
        '# Session' \
        '### Hard-won conditions (gotchas, root causes, limitations)' \
        '- **Windows pack-file locks**, so scratch cleanup is best effort while **isolated cleanup** is deterministic. · status: follow-up' > "$LEGACY"
    mkdir -p "$(dirname "$STORE")"
    printf '%s\n' \
        '{"schema_version":"1","type":"feature","ts":"2026-08-09","feature":"001-add-caching","session":"none","commit":"abc","slug":"001-add-caching","intent":"Imported pre-0.3 session history.","branch":"legacy-import/001-add-caching","base_ref":"legacy","imported_from":"docs/fluencyloop/features/001-add-caching#feature"}' \
        '{"schema_version":"1","type":"session","ts":"2026-08-09","feature":"001-add-caching","session":"000-legacy-import","commit":"abc","slug":"000-legacy-import","intent":"Backfill pre-0.3 session history.","imported_from":"docs/fluencyloop/features/001-add-caching#backfill-session"}' > "$STORE"

    run bash "$BIN/check.sh" --json
    [ "$status" -eq 0 ]
    [ "$(tr -d '\r\n' < "$(dirname "$STORE")/../.legacy-import-revision")" = "3" ]

    python3 - "$STORE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    records = [json.loads(line) for line in fh]
record = next(record for record in records if record['type'] == 'condition')
assert record['subject'] == 'Windows pack-file locks', record
assert record['why'].startswith(', so scratch cleanup'), record
assert '**isolated cleanup**' in record['why'], record
feature = [record for record in records if record['type'] == 'feature'][-1]
assert feature['intent'] == 'add a bounded cache to the request path', feature
PY
}

# The four cases below are regressions found by running the importer against a real 47-feature
# corpus (blastradius): none are synthetic edge cases. Backfilled decisions there wrap `why:` and
# `alternative:` across lines, cite more than one file in `where:`, annotate `trust:` with a
# review note, and add a hand-written `- **note:**` field the schema doesn't define. Before this
# fix, each of those independently caused the whole decision — or, compounded, the whole feature
# — to import as zero records with no summary indicating a total loss.
@test "reflows a why/alternative field the legacy writer wrapped across lines" {
    printf '%s\n' \
        '## Decision: JGit in-process for commit traversal' \
        '- **where:** `git/CommitCheckout.java`' \
        '- **why:** JGit walks the commit range and materializes each commit' \
        '  in-process, never touching the target repo'"'"'s HEAD.' \
        '- **alternative:** shell out to the `git` CLI — rejected: harder to' \
        '  unit test and brittle across git versions.' \
        '- **trust:** ✓ verified' > "$LEGACY"
    run bash "$BIN/import-legacy.sh"
    [ "$status" -eq 0 ]
    [[ "$output" != *"skipped malformed"* ]]
    python3 - "$STORE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    record = json.loads(fh.readline())
assert record['why'] == "JGit walks the commit range and materializes each commit in-process, never touching the target repo's HEAD.", record['why']
assert record['alternative'] == "shell out to the `git` CLI — rejected: harder to unit test and brittle across git versions.", record['alternative']
PY
}

@test "accepts a where field naming more than one path" {
    printf '%s\n' \
        '## Decision: shared resolver for two files' \
        '- **where:** `git/CommitCheckout.java`, `git/CommitWindowResolver.java`' \
        '- **why:** one resolver keeps both in lockstep' \
        '- **trust:** ✓ verified' > "$LEGACY"
    run bash "$BIN/import-legacy.sh"
    [ "$status" -eq 0 ]
    [[ "$output" != *"skipped malformed"* ]]
    where="$(python3 -c "import json; print(json.loads(open('$STORE').readline())['where'])")"
    [ "$where" = '`git/CommitCheckout.java`, `git/CommitWindowResolver.java`' ]
}

@test "normalizes an annotated trust line and does not fail the decision" {
    printf '%s\n' \
        '## Decision: annotated trust' \
        '- **where:** `src/x.java`' \
        '- **why:** because' \
        '- **trust:** ✓ verified — maintainer-confirmed on backfill review (2026-07-12)' > "$LEGACY"
    run bash "$BIN/import-legacy.sh"
    [ "$status" -eq 0 ]
    [[ "$output" != *"skipped malformed"* ]]
    [ "$(python3 -c "import json;print(json.loads(open('$STORE').readline())['trust'])")" = "verified" ]
}

@test "drops an unrecognized well-formed field instead of failing the whole decision" {
    printf '%s\n' \
        '## Decision: has an extra note' \
        '- **where:** `src/x.java`' \
        '- **why:** because' \
        '- **note:** shipped as a binary classifier; a later refinement is separate work.' \
        '- **trust:** ✓ verified' > "$LEGACY"
    run bash "$BIN/import-legacy.sh"
    [ "$status" -eq 0 ]
    [[ "$output" != *"skipped malformed"* ]]
    python3 - "$STORE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    record = json.loads(fh.readline())
assert record['why'] == 'because', record
assert 'note' not in record, record
PY
}

@test "reflows a components bullet the legacy writer wrapped across lines, ending in the status marker" {
    printf '%s\n' \
        '# Session' \
        '### Components (role, conditions)' \
        '- **`BuildCache`** — a disk-backed store of successful builds keyed by' \
        '  a sha, living at `<report>.cache/`. `store` writes atomically so a' \
        '  crash mid-write never leaves a truncated file. · status: documented' \
        '### Hard-won conditions (gotchas, root causes, limitations)' \
        '- **linear heap growth, not a leak in one build** — Phase 1' \
        '  accumulated every commit into one map held for the whole run. · status: documented' > "$LEGACY"
    run bash "$BIN/import-legacy.sh"
    [ "$status" -eq 0 ]
    [[ "$output" != *"skipped malformed"* ]]
    python3 - "$STORE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    records = [json.loads(line) for line in fh]
component = next(r for r in records if r['type'] == 'component')
condition = next(r for r in records if r['type'] == 'condition')
assert component['name'] == '`BuildCache`', component
assert component['role'].endswith('never leaves a truncated file.'), component
assert component['status'] == 'documented'
assert condition['why'].endswith('held for the whole run.'), condition
PY
}

@test "accepts a condition bullet whose name ends its own sentence instead of using an em dash" {
    printf '%s\n' \
        '# Session' \
        '### Hard-won conditions (gotchas, root causes, limitations)' \
        '- **The OOM was linear heap growth, not a leak in one build.** Phase 1' \
        '  accumulated every commit into one map held for the whole run. · status: documented' > "$LEGACY"
    run bash "$BIN/import-legacy.sh"
    [ "$status" -eq 0 ]
    [[ "$output" != *"skipped malformed"* ]]
    python3 - "$STORE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    record = json.loads(fh.readline())
assert record['subject'] == 'The OOM was linear heap growth, not a leak in one build.', record
assert record['why'].endswith('held for the whole run.'), record
PY
}

@test "accepts punctuation immediately after a bold knowledge title" {
    printf '%s\n' \
        '# Session' \
        '### Hard-won conditions (gotchas, root causes, limitations)' \
        '- **Windows pack-file locks**, so scratch cleanup is best effort while **isolated cleanup** is deterministic. · status: follow-up' > "$LEGACY"
    run bash "$BIN/import-legacy.sh"
    [ "$status" -eq 0 ]
    [[ "$output" != *"skipped malformed"* ]]
    python3 - "$STORE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    record = json.loads(fh.readline())
assert record['subject'] == 'Windows pack-file locks', record
assert record['why'].startswith(', so scratch cleanup'), record
assert '**isolated cleanup**' in record['why'], record
PY
}

@test "an em-dash-separated bullet's role text has no leftover leading dash" {
    printf '%s\n' \
        '# Session' \
        '### Components (role, conditions)' \
        '- **`Widget`** — does the thing · status: documented' > "$LEGACY"
    run bash "$BIN/import-legacy.sh"
    [ "$status" -eq 0 ]
    [ "$(python3 -c "import json; print(json.loads(open('$STORE').readline())['role'])")" = "does the thing" ]
}

@test "a components bullet abandoned by a heading with no status marker is reported, not silently dropped" {
    printf '%s\n' \
        '# Session' \
        '### Components (role, conditions)' \
        '- **Broken** — this bullet never reaches its status marker' \
        '## Next section' > "$LEGACY"
    run bash "$BIN/import-legacy.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipped malformed legacy record"*"#component-1"* ]]
}
