#!/usr/bin/env bash
# common.sh — shared helpers for FluencyLoop scripts.
# Deterministic plumbing only: no LLM, no interactivity. Sourced by the other scripts.

set -euo pipefail

# --- repo + paths ---------------------------------------------------------

# Absolute path to the git repo root, or empty if not in a repo.
repo_root() {
    git rev-parse --show-toplevel 2>/dev/null || true
}

# Absolute path to the project's .fluencyloop directory. MACHINE STATE ONLY lives here:
# the vendored scripts/ and templates/ plumbing. Human-facing artifacts live under docs_dir.
fluency_dir() {
    local root; root="$(repo_root)"
    if [ -n "$root" ]; then printf '%s/.fluencyloop' "$root"; fi
}

# Absolute path to the project's human-facing FluencyLoop docs. The constitution, per-feature
# design.md, and session journals live here — visible and committed, namespaced under docs/ so
# they don't collide with a project's own documentation.
docs_dir() {
    local root; root="$(repo_root)"
    if [ -n "$root" ]; then printf '%s/docs/fluencyloop' "$root"; fi
}

# The project constitution (a human doc). Lives under docs_dir now, with the same back-compat
# fallback as feature_path: if only the pre-refactor copy (.fluencyloop/constitution.md) exists,
# resolve to it so init won't orphan it and readers find it until `fluencyloop migrate` runs.
constitution_path() {
    local new old
    new="$(docs_dir)/constitution.md"
    old="$(fluency_dir)/constitution.md"
    if [ ! -f "$new" ] && [ -f "$old" ]; then
        printf '%s' "$old"
    else
        printf '%s' "$new"
    fi
}

# Fail unless FluencyLoop has been initialised in this repo.
require_fluency() {
    local dir; dir="$(fluency_dir)"
    if [ -z "$dir" ] || [ ! -d "$dir" ]; then
        echo "Error: FluencyLoop is not initialised here. Run 'fluencyloop init' first." >&2
        exit 1
    fi
    maybe_import_legacy
}

# First 0.3 use must carry legacy history forward without asking. The importer itself sets the
# guard so this call is never recursive. Check for its per-feature declaration marker, rather than
# only an absent store directory: an early 0.3 importer may already have copied decisions but not
# the feature/session declarations added later. Retrying is safe because every imported record has
# a stable marker.
#
# Bump this when a legacy parser correction can recover records that an earlier importer skipped.
# It gives already-migrated repositories one automatic, idempotent repair pass without running the
# full legacy scan on every normal command thereafter.
LEGACY_IMPORT_REVISION=3

legacy_import_revision_path() {
    printf '%s/.legacy-import-revision' "$(store_dir)"
}

# Semantic reconstruction needs model judgment, unlike the deterministic Markdown importer. The
# completed marker is only valid after every imported feature has an explicit assessment and the
# migration has produced architectural records; otherwise later work must resume the migration.
# Revision 5 reopens earlier semantic passes that completed before tag coverage was required. The
# reader resolves records by identity, so tagged record replacements are additive and retain their
# original provenance.
LEGACY_SEMANTIC_MIGRATION_REVISION=5
legacy_semantic_migration_path() { printf '%s/.legacy-semantic-migration-revision' "$(store_dir)"; }

legacy_imported_feature_count() {
    local store count=0
    while IFS= read -r store; do
        grep -Eq '"type":"feature".*"imported_from":"' "$store" && count=$((count + 1))
    done < <(find "$(store_dir)/features" -maxdepth 1 -type f -name '*.jsonl' -print 2>/dev/null)
    printf '%s' "$count"
}

legacy_imported_feature_slugs() {
    local store slug
    while IFS= read -r store; do
        grep -Eq '"type":"feature".*"imported_from":"' "$store" || continue
        slug="$(basename "$store" .jsonl)"
        printf '%s\n' "$slug"
    done < <(find "$(store_dir)/features" -maxdepth 1 -type f -name '*.jsonl' -print 2>/dev/null | LC_ALL=C sort)
}

legacy_semantic_assessment_count() {
    local store count=0
    while IFS= read -r store; do
        grep -Eq '"type":"semantic_assessment".*"semantic_migration_revision":"'"$LEGACY_SEMANTIC_MIGRATION_REVISION"'"' "$store" && count=$((count + 1))
    done < <(find "$(store_dir)/features" -maxdepth 1 -type f -name '*.jsonl' -print 2>/dev/null)
    printf '%s' "$count"
}

legacy_architectural_record_count() {
    local store count
    store="$(concepts_store_path)"
    [ -f "$store" ] || { printf '0'; return; }
    count="$(grep -c '"type":"concept"' "$store" || true)"
    printf '%s' "${count:-0}"
}

legacy_tagged_architectural_record_count() {
    local store count
    store="$(concepts_store_path)"
    [ -f "$store" ] || { printf '0'; return; }
    count="$(grep -Ec '"type":"concept".*"tags":"[^"]+' "$store" || true)"
    printf '%s' "${count:-0}"
}

legacy_semantic_unassessed_features() {
    local feature store
    while IFS= read -r feature; do
        store="$(feature_store_path "$feature")"
        grep -Eq '"type":"semantic_assessment".*"semantic_migration_revision":"'"$LEGACY_SEMANTIC_MIGRATION_REVISION"'"' "$store" || printf '%s\n' "$feature"
    done < <(legacy_imported_feature_slugs)
}

legacy_semantic_migration_pending() {
    local count marker
    count="$(legacy_imported_feature_count)"
    [ "$count" -gt 0 ] || return 1
    marker="$(legacy_semantic_migration_path)"
    [ -f "$marker" ] && [ "$(tr -d '\r\n' < "$marker")" = "$LEGACY_SEMANTIC_MIGRATION_REVISION" ] && return 1
    return 0
}

legacy_import_needs_revision() {
    local legacy="$1" revision feature_dir feature source store marker
    revision="$(legacy_import_revision_path)"
    if [ -f "$revision" ] && [ "$(tr -d '\r\n' < "$revision")" = "$LEGACY_IMPORT_REVISION" ]; then
        return 1
    fi
    while IFS= read -r -d '' feature_dir; do
        feature="$(basename "$feature_dir")"
        source="$(repo_rel "$feature_dir")#feature"
        store="$(feature_store_path "$feature")"
        [ -f "$store" ] || continue
        marker="\"imported_from\":\"$(json_escape "$source")\""
        # Only retry a repository that has actually received a legacy import. A native 0.3
        # feature can legitimately share the same docs layout and must not be imported as legacy.
        grep -Fq "$marker" "$store" && return 0
    done < <(find "$legacy" -mindepth 1 -maxdepth 1 -type d -print0)
    return 1
}

legacy_import_incomplete() {
    local legacy="$1" feature_dir sessions_dir feature source store marker legacy_marker
    while IFS= read -r -d '' feature_dir; do
        sessions_dir="$feature_dir/sessions"
        [ -d "$sessions_dir" ] || continue
        if ! find "$sessions_dir" -mindepth 1 -maxdepth 1 -type f -name '*.md' -print -quit | grep -q .; then
            continue
        fi
        feature="$(basename "$feature_dir")"
        source="$(repo_rel "$feature_dir")#feature"
        store="$(feature_store_path "$feature")"
        [ ! -f "$store" ] && return 0
        marker="\"imported_from\":\"$(json_escape "$source")\""
        grep -Fq "$marker" "$store" && continue
        # Only repair a pre-declaration import. A native 0.3 feature may share a legacy slug;
        # without an imported marker, appending a synthetic feature record would supersede its
        # real declaration on read.
        legacy_marker="\"imported_from\":\"$(json_escape "$(repo_rel "$feature_dir")/")"
        if grep -Fq "$legacy_marker" "$store"; then
            return 0
        fi
    done < <(find "$legacy" -mindepth 1 -maxdepth 1 -type d -print0)
    return 1
}

maybe_import_legacy() {
    [ "${FLUENCYLOOP_IMPORTING:-}" = "1" ] && return 0
    local legacy store importer
    legacy="$(docs_dir)/features"
    store="$(store_dir)"
    [ -d "$legacy" ] || return 0
    [ ! -d "$store" ] || legacy_import_incomplete "$legacy" || legacy_import_needs_revision "$legacy" || return 0
    importer="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/import-legacy.sh"
    [ -f "$importer" ] || return 0
    FLUENCYLOOP_IMPORTING=1 bash "$importer" --auto
}

# --- text helpers ---------------------------------------------------------

# Turn a free-text intent into a filesystem/branch-safe slug.
#   "Adding Rate Limiting to the Gateway!" -> "adding-rate-limiting-to-the-gateway"
slugify() {
    printf '%s' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
        | cut -c1-60 \
        | sed -E 's/-+$//'
}

# prefix + intent -> "<slugified-prefix>-<slugified-intent>", capped at the same 60-char
# ceiling as slugify. Used so a ticket id, PR number, or sequential counter always reads as
# the leading segment of the feature dir name (e.g. "042-adding-rate-limiting").
numbered_slug() {
    printf '%s-%s' "$(slugify "$1")" "$(slugify "$2")" | cut -c1-60 | sed -E 's/-+$//'
}

# Today, ISO date.
today() { date +%Y-%m-%d; }

# Minimal JSON string escaper (quotes, backslashes, newlines).
json_escape() {
    printf '%s' "$1" | sed -E 's/\\/\\\\/g; s/"/\\"/g' | awk 'BEGIN{ORS=""} {print (NR>1?"\\n":"") $0}'
}

# Emit a flat JSON object from alternating key value arguments.
#   emit_json k1 v1 k2 v2 ...
emit_json() {
    local out="{" first=1
    while [ "$#" -ge 2 ]; do
        [ "$first" -eq 1 ] || out+=","
        first=0
        out+="\"$1\":\"$(json_escape "$2")\""
        shift 2
    done
    out+="}"
    printf '%s\n' "$out"
}

# --- feature/branch model -------------------------------------------------
# A feature IS a branch: feature/<slug>. The feature dir mirrors the slug.

branch_for()      { printf 'feature/%s' "$1"; }         # slug -> branch name

# slug -> feature dir. Lives under docs_dir now. Back-compat: if a feature still sits at the
# pre-refactor location (.fluencyloop/features/<slug>) and hasn't been migrated, resolve to
# that so existing repos keep working until they run `fluencyloop migrate`.
#
# The dir name can drift from the branch slug (e.g. renamed to carry a PR number once one
# exists — see rename-feature-dir.sh), so for the *active* feature this checks state.json's
# `feature_dir` override before falling back to the computed path.
feature_path() {
    local slug="$1" new old state_feature stored
    state_feature="$(state_get feature)"
    if [ -n "$state_feature" ] && [ "$state_feature" = "$slug" ]; then
        stored="$(state_get feature_dir)"
        if [ -n "$stored" ]; then
            printf '%s/%s' "$(repo_root)" "$stored"
            return
        fi
    fi
    new="$(docs_dir)/features/$slug"
    old="$(fluency_dir)/features/$slug"
    if [ ! -d "$new" ] && [ -d "$old" ]; then
        printf '%s' "$old"
    else
        printf '%s' "$new"
    fi
}

# slug -> plan dir. A plan is an initiative that spawns several features; it is a committed
# doc (no dedicated branch), and lives under docs_dir alongside features.
plan_path() { printf '%s/plans/%s' "$(docs_dir)" "$1"; }

# --- feature numbering ------------------------------------------------------
# Every feature slug is prefixed with a ticket id, PR number, or a zero-padded counter. Since 0.3
# no longer creates feature directories, count the committed per-feature store files and local
# feature branches as well as legacy dirs. This stays structural: it never reads JSONL.
next_feature_number() {
    local dir store n dirs stores branches
    dir="$(docs_dir)/features"
    store="$(store_dir)/features"
    dirs=0; stores=0; branches=0
    if [ -d "$dir" ]; then
        dirs="$(find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
    fi
    if [ -d "$store" ]; then
        stores="$(find "$store" -mindepth 1 -maxdepth 1 -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')"
    fi
    branches="$(git for-each-ref --format='%(refname)' refs/heads/feature 2>/dev/null | wc -l | tr -d ' ')"
    n="$dirs"; [ "$stores" -gt "$n" ] && n="$stores"; [ "$branches" -gt "$n" ] && n="$branches"
    printf '%03d' "$((n + 1))"
}

# Next sequential session number within a feature (zero-padded), derived from its append-only
# store rather than the mutable active-session pointer. Imported decisions retain their legacy
# session slug in the common envelope even when pre-0.3 history has no native session record.
next_session_number() {
    local feature="$1" store record number n=0
    store="$(feature_store_path "$feature")"
    [ -f "$store" ] || { printf '001'; return; }
    while IFS= read -r record; do
        number="$(printf '%s' "$record" | sed -n 's/.*"session":"\([0-9][0-9]*\)-[^"]*".*/\1/p')"
        [ -n "$number" ] || continue
        [ "$((10#$number))" -gt "$n" ] && n="$((10#$number))"
    done < "$store"
    printf '%03d' "$((n + 1))"
}

# The active feature slug, derived from the current branch (empty if not on one).
current_feature_slug() {
    local b; b="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    case "$b" in
        feature/*) printf '%s' "${b#feature/}" ;;
        *) printf '' ;;
    esac
}

# --- loop state -----------------------------------------------------------
# One source of truth for the active feature's loop state, so a skill reads it instead of
# re-deriving from git every turn. Machine state, so it lives in .fluencyloop/; committed with
# the feature branch (part of the journal record). Written by new-feature.sh / new-session.sh.

# The state file's data-model generation. Bump only when the on-disk shape changes in a way a
# reader has to branch on — it is how a later version tells an old project from a new one
# without guessing from which files happen to be present.
FLUENCYLOOP_SCHEMA_VERSION=1

state_path() { local d; d="$(fluency_dir)"; if [ -n "$d" ]; then printf '%s/state.json' "$d"; fi; }

# A repo-relative path (state stores paths relative to the repo root, so they survive a move).
repo_rel() { local root; root="$(repo_root)"; printf '%s' "${1#"$root"/}"; }

# Read one string field from state.json (empty if the file or key is absent). Safe because we
# control the format write_state emits (one "key": "value" per line, values never contain ").
state_get() {
    local f; f="$(state_path)"
    [ -f "$f" ] || return 0
    sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$f" | head -n1
}

# The generation of the state file on disk. A file written before the field existed has none,
# and reads as 1 — so every pre-existing project is a valid schema 1 without being rewritten.
state_schema_version() {
    local v; v="$(state_get schema_version)"
    printf '%s' "${v:-1}"
}

# Write state.json from alternating key value arguments (all string-valued), creating it.
#   write_state feature "$SLUG" branch "$BRANCH" stage design ...
write_state() {
    local f; f="$(state_path)"
    [ -n "$f" ] || return 0
    mkdir -p "$(dirname "$f")"
    # schema_version leads every state file, written here rather than by each caller so no
    # write path can omit it. Quoted like every other value — state_get only reads strings.
    local out="{" first=0 k v
    out+=$'\n  '"\"schema_version\": \"$FLUENCYLOOP_SCHEMA_VERSION\""
    while [ "$#" -ge 2 ]; do
        k="$1"; v="$2"; shift 2
        [ "$first" -eq 1 ] || out+=","
        first=0
        out+=$'\n  '"\"$k\": \"$(json_escape "$v")\""
    done
    out+=$'\n}'
    printf '%s\n' "$out" > "$f"
}

# --- store ----------------------------------------------------------------
# The append-only record of what the loop observed: one JSON object per line, JSONL rather than
# JSON so shell can add a line with `>>` and no parser. Nothing here ever reads or rewrites what
# it wrote — a correction is a new line, and readers take the last record for an identity.
#
# One file per feature, because a feature is a branch: two branches then never append to the same
# file, so there is nothing to conflict. concepts.jsonl is the single global stream, and the one
# place a line-based merge actually earns its keep.

store_dir() { local d; d="$(docs_dir)"; if [ -n "$d" ]; then printf '%s/store' "$d"; fi; }

feature_store_path() { printf '%s/features/%s.jsonl' "$(store_dir)" "$1"; }
concepts_store_path() { printf '%s/concepts.jsonl' "$(store_dir)"; }

# Append one record to a store file from alternating key value arguments, creating the file and
# its parent dir. Pairs with an empty value are dropped, so an unused optional field costs nothing
# on every line rather than writing "alternative":"" forever. That skip is the only difference
# from emit_json, which keeps empties and has callers depending on it — hence the filter here.
#   store_append "$(feature_store_path add-caching)" type decision title "Chose a read-through cache"
store_append() {
    local f="$1"; shift
    local -a pairs=()
    while [ "$#" -ge 2 ]; do
        if [ -n "$2" ]; then pairs+=("$1" "$2"); fi
        shift 2
    done
    mkdir -p "$(dirname "$f")"
    # Guard the expansion: on bash < 4.4 (macOS ships 3.2) "${arr[@]}" errors under `set -u`.
    emit_json ${pairs[@]+"${pairs[@]}"} >> "$f"
}

# Append a schema-complete record. Store writers supply the contextual fields that vary per call;
# this wrapper owns the invariant envelope so no future writer can forget it. Keep store_append
# generic: it is also the low-level primitive A1 promises to callers.
store_commit() {
    git rev-parse --verify --quiet HEAD 2>/dev/null || printf 'uncommitted'
}

#   store_append_record "$(feature_store_path add-caching)" decision add-caching 001-wire-cache \
#       title "Keep the cache bounded" where src/cache.js why "..."
store_append_record() {
    local f="${1:-}" type="${2:-}" feature="${3:-}" session="${4:-}"
    shift 4 || true
    if [ -z "$f" ] || [ -z "$type" ] || [ -z "$feature" ] || [ -z "$session" ]; then
        echo "Error: store_append_record requires file, type, feature, and session." >&2
        return 1
    fi
    store_append "$f" \
        schema_version "$FLUENCYLOOP_SCHEMA_VERSION" \
        type "$type" \
        ts "$(today)" \
        feature "$feature" \
        session "$session" \
        commit "$(store_commit)" \
        "$@"
}

# --- calibration ----------------------------------------------------------
# The per-developer knowledge profile: global, never committed. Lives under FLUENCYLOOP_HOME
# (default ~/.fluencyloop), NOT in the repo — it is the only place person-specific knowledge lives.
calibration_file() { printf '%s/calibration.md' "${FLUENCYLOOP_HOME:-$HOME/.fluencyloop}"; }

# Append-only ledger of engagement signals (wave/deeper/correct per dimension). Global, never
# committed. `calibration compact` rolls it into level changes in the profile above.
signals_file() { printf '%s/signals.log' "${FLUENCYLOOP_HOME:-$HOME/.fluencyloop}"; }
