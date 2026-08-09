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
