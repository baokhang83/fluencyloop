#!/usr/bin/env bash
# check.sh — the FluencyLoop doctor. A deterministic drift/state detector so skills make cheap
# decisions without the model scanning git. Reports whether the loop is set up, the active
# feature (from state.json), how many commits have landed since the last journaled session
# (un-journaled drift — the signal review/backfill care about), and whether the per-developer
# calibration profile exists.
#
# Usage: check.sh [--json]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

JSON_MODE=false
for arg in "$@"; do
    case "$arg" in
        --json) JSON_MODE=true ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

ROOT="$(repo_root)"
IN_GIT_REPO=false
[ -n "$ROOT" ] && IN_GIT_REPO=true

# --- is the loop set up here? ---
FLUENCY_DIR="$(fluency_dir)"
FLUENCY_PRESENT=false
[ -n "$FLUENCY_DIR" ] && [ -d "$FLUENCY_DIR" ] && FLUENCY_PRESENT=true
[ "$FLUENCY_PRESENT" = true ] && maybe_import_legacy
LEGACY_IMPORTED_FEATURES="$(legacy_imported_feature_count)"
LEGACY_MIGRATION_PENDING=false
legacy_semantic_migration_pending && LEGACY_MIGRATION_PENDING=true

# --- active feature: from state.json, falling back to the branch ---
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
STATE_BRANCH="$(state_get branch)"
FEATURE="$(state_get feature)"
[ -z "$FEATURE" ] && FEATURE="$(current_feature_slug)"
STAGE="$(state_get stage)"
BASE="$(state_get base_ref)"; [ -z "$BASE" ] && BASE="main"
LAST_SESSION="$(state_get last_session)"
STATE_MATCHES_BRANCH=true
DETACHED_HEAD=false
[ "$BRANCH" = "HEAD" ] && DETACHED_HEAD=true
if [ -n "$STATE_BRANCH" ] && [ -n "$BRANCH" ] && [ "$STATE_BRANCH" != "$BRANCH" ]; then
    # A detached checkout at the recorded branch tip, or an earlier commit reachable from that
    # branch, is a recoverable transport state. Reattaching moves only along the saved feature's
    # history, so it cannot discard detached work. A detached descendant or divergent commit is
    # still a genuine split state and needs the developer's decision.
    if $DETACHED_HEAD && git show-ref --verify --quiet "refs/heads/$STATE_BRANCH" \
        && git merge-base --is-ancestor HEAD "$STATE_BRANCH" 2>/dev/null; then
        : # The feature skill reattaches this clean, recorded feature history before it writes.
    else
        STATE_MATCHES_BRANCH=false
    fi
fi

# --- un-journaled drift: commits since the last committed session record. Before the first
# session, everything since the base ref counts as un-journaled. Legacy session markdown remains
# a read-only fallback for projects that have not imported it yet. ---
UNJOURNALED=0
if [ -n "$ROOT" ] && [ -n "$FEATURE" ]; then
    LAST_JOURNAL_COMMIT=""
    if [ -n "$LAST_SESSION" ]; then
        STORE="$(feature_store_path "$FEATURE")"
        if [ -f "$STORE" ]; then
            LAST_JOURNAL_COMMIT="$(git log -1 --format=%H -- "$STORE" 2>/dev/null || true)"
        else
            SESSIONS_DIR="$(feature_path "$FEATURE")/sessions"
            LAST_JOURNAL_COMMIT="$(git log -1 --format=%H -- "$SESSIONS_DIR" 2>/dev/null || true)"
        fi
    fi
    if [ -n "$LAST_JOURNAL_COMMIT" ]; then
        UNJOURNALED="$(git rev-list --count "$LAST_JOURNAL_COMMIT..HEAD" 2>/dev/null || echo 0)"
    elif git rev-parse --verify --quiet "$BASE" >/dev/null 2>&1; then
        UNJOURNALED="$(git rev-list --count "$BASE..HEAD" 2>/dev/null || echo 0)"
    fi
fi

# --- per-developer calibration profile (global, never committed) ---
CAL_FILE="$(calibration_file)"
CAL_PRESENT=false
[ -f "$CAL_FILE" ] && CAL_PRESENT=true

# Informational only: Node.js is optional for the loop and needed solely by `fluencyloop site`.
NODE_PRESENT=false
command -v node >/dev/null 2>&1 && NODE_PRESENT=true

# --- constitution: absent / empty stub / a pointer / populated. It's born from the first plan
# or feature and grows by harvest, so an absent-or-empty constitution is normal, never an error. ---
CONSTITUTION="$(constitution_path)"
CONSTITUTION_STATE="absent"
if [ -n "$CONSTITUTION" ] && [ -f "$CONSTITUTION" ]; then
    if grep -q "Source of truth:" "$CONSTITUTION" 2>/dev/null; then
        CONSTITUTION_STATE="pointer"
    elif grep -qi "none yet" "$CONSTITUTION" 2>/dev/null || ! grep -q "§" "$CONSTITUTION" 2>/dev/null; then
        CONSTITUTION_STATE="empty"
    else
        CONSTITUTION_STATE="present"
    fi
fi

# --- store integrity ------------------------------------------------------
# Store writers only append and never read JSONL. The doctor is the deliberate read-time
# consistency boundary: it reports every finding but never repairs or rewrites a record.
STORE_ERROR_COUNT=0
STORE_ERROR_JSON=()
STORE_ERROR_TEXT=()
CONCEPT_NAMES=()
COMPONENT_NAMES=()
FEATURE_NAMES=()
RELATION_FILES=()
RELATION_LINES=()
RELATION_FROMS=()
RELATION_TOS=()
RELATION_KINDS=()

store_error() {
    local file="$1" line="$2" message="$3"
    STORE_ERROR_COUNT=$((STORE_ERROR_COUNT + 1))
    STORE_ERROR_TEXT+=("$file:$line: $message")
    STORE_ERROR_JSON+=("{\"file\":\"$(json_escape "$file")\",\"line\":$line,\"message\":\"$(json_escape "$message")\"}")
}

# Schema records are compact objects whose keys and values are JSON strings. This recognises that
# writer format without a runtime JSON dependency; malformed or differently-shaped JSON is still
# a finding because it cannot be a valid generation-1 store record.
is_store_json_object() {
    local value="$1"
    local string='"([^"\\]|\\(["\\/bfnrt]|u[[:xdigit:]]{4}))*"'
    local pair="${string}[[:space:]]*:[[:space:]]*${string}"
    [[ "$value" =~ ^[[:space:]]*\{[[:space:]]*($pair([[:space:]]*,[[:space:]]*$pair)*)?[[:space:]]*\}[[:space:]]*$ ]]
}

# Sets STORE_FIELD_FOUND and STORE_FIELD_VALUE. Values stay JSON-escaped: identities written by
# the shell are compared in that same representation, so no reader needs to reinterpret escapes.
store_field() {
    local record="$1" key="$2" content re
    STORE_FIELD_FOUND=false
    STORE_FIELD_VALUE=""
    content='([^"\\]|\\.)*'
    re="\"$key\"[[:space:]]*:[[:space:]]*\"($content)\""
    if [[ "$record" =~ $re ]]; then
        STORE_FIELD_FOUND=true
        STORE_FIELD_VALUE="${BASH_REMATCH[1]}"
    fi
}

known_identity() {
    local wanted="$1" item
    for item in ${CONCEPT_NAMES[@]+"${CONCEPT_NAMES[@]}"} ${COMPONENT_NAMES[@]+"${COMPONENT_NAMES[@]}"} ${FEATURE_NAMES[@]+"${FEATURE_NAMES[@]}"}; do
        [ "$item" = "$wanted" ] && return 0
    done
    return 1
}

valid_record_type() {
    case "$1" in
        feature|session|decision|component|condition|concept|relation|semantic_assessment|principle|requirement|open_question) return 0 ;;
        *) return 1 ;;
    esac
}

validate_store_record() {
    local record="$1" file="$2" line="$3" type="" field
    if ! is_store_json_object "$record"; then
        store_error "$file" "$line" "unparseable JSON"
        return
    fi

    store_field "$record" type
    if $STORE_FIELD_FOUND; then type="$STORE_FIELD_VALUE"; fi
    for field in schema_version type ts feature session commit; do
        store_field "$record" "$field"
        if ! $STORE_FIELD_FOUND || [ -z "$STORE_FIELD_VALUE" ]; then
            store_error "$file" "$line" "missing required envelope field: $field"
        fi
    done
    if [ -n "$type" ] && ! valid_record_type "$type"; then
        store_error "$file" "$line" "unknown record type: $type"
        return
    fi

    store_field "$record" feature
    if $STORE_FIELD_FOUND && [ -n "$STORE_FIELD_VALUE" ] && [ "$STORE_FIELD_VALUE" != global ]; then
        FEATURE_NAMES+=("$STORE_FIELD_VALUE")
    fi
    case "$type" in
        concept)
            store_field "$record" name
            $STORE_FIELD_FOUND && [ -n "$STORE_FIELD_VALUE" ] && CONCEPT_NAMES+=("$STORE_FIELD_VALUE")
            ;;
        component)
            store_field "$record" name
            $STORE_FIELD_FOUND && [ -n "$STORE_FIELD_VALUE" ] && COMPONENT_NAMES+=("$STORE_FIELD_VALUE")
            ;;
        relation)
            store_field "$record" from
            local from="$STORE_FIELD_VALUE"
            store_field "$record" to
            local to="$STORE_FIELD_VALUE"
            store_field "$record" kind
            local kind="$STORE_FIELD_VALUE"
            RELATION_FILES+=("$file")
            RELATION_LINES+=("$line")
            RELATION_FROMS+=("$from")
            RELATION_TOS+=("$to")
            RELATION_KINDS+=("$kind")
            ;;
    esac
}

store_errors_json() {
    local joined="" item
    for item in ${STORE_ERROR_JSON[@]+"${STORE_ERROR_JSON[@]}"}; do
        [ -n "$joined" ] && joined="${joined},"
        joined+="$item"
    done
    printf '%s' "$joined"
}

STORE_ROOT="$(store_dir)"
if [ -n "$STORE_ROOT" ] && [ -d "$STORE_ROOT" ]; then
    while IFS= read -r store_file; do
        STORE_FILE_REL="$(repo_rel "$store_file")"
        STORE_LINE=0
        while IFS= read -r store_line || [ -n "$store_line" ]; do
            STORE_LINE=$((STORE_LINE + 1))
            validate_store_record "$store_line" "$STORE_FILE_REL" "$STORE_LINE"
        done < "$store_file"
    done < <(find "$STORE_ROOT" -type f -name '*.jsonl' -print | LC_ALL=C sort)

    # Relations can precede their defining concept, so validate targets only after the full scan.
    for ((relation_index = 0; relation_index < ${#RELATION_FILES[@]}; relation_index++)); do
        if ! known_identity "${RELATION_FROMS[relation_index]}"; then
            store_error "${RELATION_FILES[relation_index]}" "${RELATION_LINES[relation_index]}" \
                "dangling relation endpoint: ${RELATION_FROMS[relation_index]}"
        fi
        # A realization relation intentionally points from a record to a code area. Code areas
        # such as AppComponent need not also be knowledge-component records, so only its source
        # must resolve in the store. Other relation kinds still require both endpoints.
        if [ "${RELATION_KINDS[relation_index]}" != realized_by ] && ! known_identity "${RELATION_TOS[relation_index]}"; then
            store_error "${RELATION_FILES[relation_index]}" "${RELATION_LINES[relation_index]}" \
                "dangling relation endpoint: ${RELATION_TOS[relation_index]}"
        fi
    done

    FEATURES_ROOT="$(docs_dir)/features"
    if [ -d "$FEATURES_ROOT" ]; then
        while IFS= read -r feature_dir; do
            feature_slug="$(basename "$feature_dir")"
            feature_store="$(feature_store_path "$feature_slug")"
            if [ ! -s "$feature_store" ]; then
                store_error "$(repo_rel "$feature_store")" 0 "feature directory has no store records: $feature_slug"
            fi
        done < <(find "$FEATURES_ROOT" -mindepth 1 -maxdepth 1 -type d -print | LC_ALL=C sort)
    fi
fi

if $JSON_MODE; then
    printf '{"git_repo":%s,"fluency":%s,"legacy_imported_features":%s,"legacy_migration_pending":%s,"branch":"%s","detached_head":%s,"state_branch":"%s","state_matches_branch":%s,"feature":"%s","stage":"%s","base_ref":"%s","last_session":"%s","unjournaled_commits":%s,"calibration":%s,"node":%s,"constitution":"%s","store_errors":[%s]}\n' \
        "$IN_GIT_REPO" \
        "$FLUENCY_PRESENT" \
        "$LEGACY_IMPORTED_FEATURES" \
        "$LEGACY_MIGRATION_PENDING" \
        "$(json_escape "$BRANCH")" \
        "$DETACHED_HEAD" \
        "$(json_escape "$STATE_BRANCH")" \
        "$STATE_MATCHES_BRANCH" \
        "$(json_escape "$FEATURE")" \
        "$(json_escape "$STAGE")" \
        "$(json_escape "$BASE")" \
        "$(json_escape "$LAST_SESSION")" \
        "$UNJOURNALED" \
        "$CAL_PRESENT" \
        "$NODE_PRESENT" \
        "$CONSTITUTION_STATE" \
        "$(store_errors_json)"
    [ "$STORE_ERROR_COUNT" -eq 0 ] && $STATE_MATCHES_BRANCH && exit 0 || exit 1
fi

# Human form.
mark() { [ "$1" = true ] && printf 'ok ' || printf 'XX '; }
echo "FluencyLoop check"
if ! $IN_GIT_REPO; then
    echo "  XX  not a git repository — run 'git init' (or cd into one), then 'fluencyloop init'"
fi
echo "  $(mark "$FLUENCY_PRESENT") .fluencyloop/ present"
if $LEGACY_MIGRATION_PENDING; then
    echo "  !!  $LEGACY_IMPORTED_FEATURES imported legacy feature(s) await semantic migration"
fi
if [ -n "$FEATURE" ]; then
    echo "  ok  active feature: $FEATURE${STAGE:+ (stage: $STAGE)}"
else
    echo "  XX  no active feature"
fi
if ! $STATE_MATCHES_BRANCH; then
    echo "  XX  state belongs to $STATE_BRANCH, but checkout is $BRANCH — reconcile before starting or recording work"
fi
if [ "$UNJOURNALED" -gt 0 ]; then
    echo "  !!  $UNJOURNALED commit(s) since the last journaled session — un-journaled drift"
else
    echo "  ok  no un-journaled drift"
fi
echo "  $(mark "$CAL_PRESENT") calibration profile ($CAL_FILE)"
if $NODE_PRESENT; then
    echo "  --  Node.js available (only needed for fluencyloop site)"
else
    echo "  --  Node.js not installed (only needed for fluencyloop site)"
fi
case "$CONSTITUTION_STATE" in
    present) echo "  ok  constitution: populated" ;;
    pointer) echo "  ok  constitution: points to a source of truth" ;;
    *)       echo "  --  no constitution yet — written from your first plan or feature" ;;
esac
if [ "$STORE_ERROR_COUNT" -eq 0 ] && $STATE_MATCHES_BRANCH; then
    echo "  ok  store: valid"
else
    for store_error_text in ${STORE_ERROR_TEXT[@]+"${STORE_ERROR_TEXT[@]}"}; do
        echo "  XX  store: $store_error_text"
    done
fi
[ "$STORE_ERROR_COUNT" -eq 0 ]
