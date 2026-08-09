#!/usr/bin/env bash
# add-knowledge.sh — append a session's component inventory and hard-won conditions in one batch.
# Fields use | as their separator; write literal | as \| and literal \ as \\. The script unescapes
# those two sequences before writing records, and validates the complete batch before it appends.
#
# Usage: add-knowledge.sh [--component <name|role|conditions[|status]> ...]
#          [--gotcha <subject|why> ...]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_fluency

declare -a COMPONENTS=() GOTCHAS=() PARSED_FIELDS=()
HAS_INPUT=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --component) shift; COMPONENTS+=("${1:-}"); HAS_INPUT=true ;;
        --gotcha) shift; GOTCHAS+=("${1:-}"); HAS_INPUT=true ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

# Split a pipe-delimited argument. Only \| and \\ are escapes: accepting other escapes would
# silently change prose. The result is assigned to PARSED_FIELDS rather than printed, so callers
# can preserve newlines and whitespace in a field.
split_knowledge_fields() {
    local value="$1" min_fields="$2" max_fields="$3" flag="$4"
    local current="" char escaped=false i
    PARSED_FIELDS=()
    for ((i = 0; i < ${#value}; i++)); do
        char="${value:i:1}"
        if $escaped; then
            case "$char" in
                '|'|\\) current+="$char" ;;
                *) printf 'Error: %s only permits \\| and \\\\ escapes.\n' "$flag" >&2; return 1 ;;
            esac
            escaped=false
        else
            case "$char" in
                \\) escaped=true ;;
                '|') PARSED_FIELDS+=("$current"); current="" ;;
                *) current+="$char" ;;
            esac
        fi
    done
    if $escaped; then
        echo "Error: $flag cannot end with an escape." >&2
        return 1
    fi
    PARSED_FIELDS+=("$current")
    if [ "${#PARSED_FIELDS[@]}" -lt "$min_fields" ] || [ "${#PARSED_FIELDS[@]}" -gt "$max_fields" ]; then
        echo "Error: $flag needs $min_fields-$max_fields pipe-separated fields; escape literal pipes as \\|." >&2
        return 1
    fi
    local field
    for field in "${PARSED_FIELDS[@]}"; do
        if [ -z "$field" ]; then
            echo "Error: $flag fields cannot be empty." >&2
            return 1
        fi
    done
}

if ! $HAS_INPUT; then
    echo "No knowledge records to append."
    exit 0
fi

# Feature and session are always the active state, never caller-selected flags. Keep the legacy
# basename handling so a pre-0.3 state file still resolves to its session identity.
SESSION="$(state_get last_session)"
SESSION="${SESSION##*/}"
SESSION="${SESSION%.md}"
if [ -z "$SESSION" ]; then
    echo "Error: no active session — open one with 'fluencyloop session \"<slice>\"' before recording knowledge." >&2
    exit 1
fi
FEATURE="$(state_get feature)"
if [ -z "$FEATURE" ]; then
    echo "Error: no active feature in state." >&2
    exit 1
fi

# Validate every argument before writing the first JSONL line. This keeps a malformed later entry
# from turning a batch close into a partially captured session.
for component in ${COMPONENTS[@]+"${COMPONENTS[@]}"}; do
    split_knowledge_fields "$component" 3 4 --component
    status="${PARSED_FIELDS[3]:-documented}"
    case "$status" in
        documented|follow-up) ;;
        *) echo "Error: --component status must be documented or follow-up." >&2; exit 1 ;;
    esac
done
for gotcha in ${GOTCHAS[@]+"${GOTCHAS[@]}"}; do
    split_knowledge_fields "$gotcha" 2 2 --gotcha
done

STORE="$(feature_store_path "$FEATURE")"
WRITTEN=0
for component in ${COMPONENTS[@]+"${COMPONENTS[@]}"}; do
    split_knowledge_fields "$component" 3 4 --component
    status="${PARSED_FIELDS[3]:-documented}"
    store_append_record "$STORE" component "$FEATURE" "$SESSION" \
        name "${PARSED_FIELDS[0]}" \
        role "${PARSED_FIELDS[1]}" \
        conditions "${PARSED_FIELDS[2]}" \
        status "$status"
    WRITTEN=$((WRITTEN + 1))
done
for gotcha in ${GOTCHAS[@]+"${GOTCHAS[@]}"}; do
    split_knowledge_fields "$gotcha" 2 2 --gotcha
    store_append_record "$STORE" condition "$FEATURE" "$SESSION" \
        subject "${PARSED_FIELDS[0]}" \
        why "${PARSED_FIELDS[1]}"
    WRITTEN=$((WRITTEN + 1))
done

echo "Appended $WRITTEN knowledge record(s) to $STORE"
