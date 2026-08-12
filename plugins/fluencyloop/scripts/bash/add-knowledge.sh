#!/usr/bin/env bash
# add-knowledge.sh — append a session's component inventory and hard-won conditions in one batch.
# The primary form uses explicit fields, so prose and Windows paths need no escape grammar. The
# older pipe form remains accepted for compatibility; \| still represents a literal pipe.
#
# Usage: add-knowledge.sh [--feature <feature-slug> --session <session-slug-or-legacy-path>]
#          [--component <name> --role <role> --conditions <conditions> [--status <documented|follow-up>] ...]
#          [--gotcha <subject> --why <why> ...]
#          [--component <name|role|conditions[|status]> ...] [--gotcha <subject|why> ...]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_fluency

declare -a COMPONENTS=() GOTCHAS=() PARSED_FIELDS=()
declare -a STRUCTURED_COMPONENT_NAMES=() STRUCTURED_COMPONENT_ROLES=() STRUCTURED_COMPONENT_CONDITIONS=() STRUCTURED_COMPONENT_STATUSES=()
declare -a STRUCTURED_GOTCHA_SUBJECTS=() STRUCTURED_GOTCHA_WHYS=()
FEATURE_OVERRIDE=""; SESSION_OVERRIDE=""; TARGET_OVERRIDE=false
HAS_INPUT=false
ACTIVE_COMPONENT=-1
ACTIVE_GOTCHA=-1
while [ "$#" -gt 0 ]; do
    case "$1" in
        --component)
            shift; value="${1:-}"; HAS_INPUT=true
            if [[ "$value" == *"|"* && "${2:-}" != "--role" ]]; then
                COMPONENTS+=("$value"); ACTIVE_COMPONENT=-1
            else
                STRUCTURED_COMPONENT_NAMES+=("$value")
                STRUCTURED_COMPONENT_ROLES+=("")
                STRUCTURED_COMPONENT_CONDITIONS+=("")
                STRUCTURED_COMPONENT_STATUSES+=("documented")
                ACTIVE_COMPONENT=$((${#STRUCTURED_COMPONENT_NAMES[@]} - 1))
            fi
            ACTIVE_GOTCHA=-1
            ;;
        --role)
            shift
            [ "$ACTIVE_COMPONENT" -ge 0 ] || { echo "Error: --role must follow an explicit --component." >&2; exit 1; }
            STRUCTURED_COMPONENT_ROLES[ACTIVE_COMPONENT]="${1:-}"
            ;;
        --conditions)
            shift
            [ "$ACTIVE_COMPONENT" -ge 0 ] || { echo "Error: --conditions must follow an explicit --component." >&2; exit 1; }
            STRUCTURED_COMPONENT_CONDITIONS[ACTIVE_COMPONENT]="${1:-}"
            ;;
        --status)
            shift
            [ "$ACTIVE_COMPONENT" -ge 0 ] || { echo "Error: --status must follow an explicit --component." >&2; exit 1; }
            STRUCTURED_COMPONENT_STATUSES[ACTIVE_COMPONENT]="${1:-}"
            ;;
        --gotcha)
            shift; value="${1:-}"; HAS_INPUT=true
            if [[ "$value" == *"|"* && "${2:-}" != "--why" ]]; then
                GOTCHAS+=("$value"); ACTIVE_GOTCHA=-1
            else
                STRUCTURED_GOTCHA_SUBJECTS+=("$value")
                STRUCTURED_GOTCHA_WHYS+=("")
                ACTIVE_GOTCHA=$((${#STRUCTURED_GOTCHA_SUBJECTS[@]} - 1))
            fi
            ACTIVE_COMPONENT=-1
            ;;
        --why)
            shift
            [ "$ACTIVE_GOTCHA" -ge 0 ] || { echo "Error: --why must follow an explicit --gotcha." >&2; exit 1; }
            STRUCTURED_GOTCHA_WHYS[ACTIVE_GOTCHA]="${1:-}"
            ;;
        --feature) shift; FEATURE_OVERRIDE="${1:-}"; TARGET_OVERRIDE=true ;;
        --session) shift; SESSION_OVERRIDE="${1:-}"; TARGET_OVERRIDE=true ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

# Split a legacy pipe-delimited argument. \| represents a literal pipe; all other backslashes stay
# literal so ordinary prose and Windows paths do not need a special escape vocabulary.
split_knowledge_fields() {
    local value="$1" min_fields="$2" max_fields="$3" flag="$4"
    local current="" char escaped=false i
    PARSED_FIELDS=()
    for ((i = 0; i < ${#value}; i++)); do
        char="${value:i:1}"
        if $escaped; then
            if [ "$char" = '|' ] || [ "$char" = "\\" ]; then
                current+="$char"
            else
                current+="\\$char"
            fi
            escaped=false
        else
            case "$char" in
                \\) escaped=true ;;
                '|') PARSED_FIELDS+=("$current"); current="" ;;
                *) current+="$char" ;;
            esac
        fi
    done
    $escaped && current+="\\"
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

if $TARGET_OVERRIDE && { [ -z "$FEATURE_OVERRIDE" ] || [ -z "$SESSION_OVERRIDE" ]; }; then
    echo "Error: --feature and --session must be used together for a historical record." >&2
    exit 1
fi

# Feature and session are always the active state, never caller-selected flags. Keep the legacy
# basename handling so a pre-0.3 state file still resolves to its session identity.
SESSION="$SESSION_OVERRIDE"
[ -n "$SESSION" ] || SESSION="$(state_get last_session)"
SESSION="${SESSION##*/}"
SESSION="${SESSION%.md}"
if [ -z "$SESSION" ]; then
    echo "Error: no active session — open one with 'fluencyloop session \"<slice>\"' before recording knowledge." >&2
    exit 1
fi
FEATURE="$FEATURE_OVERRIDE"
[ -n "$FEATURE" ] || FEATURE="$(state_get feature)"
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
for ((i = 0; i < ${#STRUCTURED_COMPONENT_NAMES[@]}; i++)); do
    if [ -z "${STRUCTURED_COMPONENT_NAMES[i]}" ] || [ -z "${STRUCTURED_COMPONENT_ROLES[i]}" ] || [ -z "${STRUCTURED_COMPONENT_CONDITIONS[i]}" ]; then
        echo "Error: an explicit --component requires nonempty --role and --conditions fields." >&2
        exit 1
    fi
    case "${STRUCTURED_COMPONENT_STATUSES[i]}" in
        documented|follow-up) ;;
        *) echo "Error: --status must be documented or follow-up." >&2; exit 1 ;;
    esac
done
for gotcha in ${GOTCHAS[@]+"${GOTCHAS[@]}"}; do
    split_knowledge_fields "$gotcha" 2 2 --gotcha
done
for ((i = 0; i < ${#STRUCTURED_GOTCHA_SUBJECTS[@]}; i++)); do
    if [ -z "${STRUCTURED_GOTCHA_SUBJECTS[i]}" ] || [ -z "${STRUCTURED_GOTCHA_WHYS[i]}" ]; then
        echo "Error: an explicit --gotcha requires a nonempty --why field." >&2
        exit 1
    fi
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
for ((i = 0; i < ${#STRUCTURED_COMPONENT_NAMES[@]}; i++)); do
    store_append_record "$STORE" component "$FEATURE" "$SESSION" \
        name "${STRUCTURED_COMPONENT_NAMES[i]}" \
        role "${STRUCTURED_COMPONENT_ROLES[i]}" \
        conditions "${STRUCTURED_COMPONENT_CONDITIONS[i]}" \
        status "${STRUCTURED_COMPONENT_STATUSES[i]}"
    WRITTEN=$((WRITTEN + 1))
done
for gotcha in ${GOTCHAS[@]+"${GOTCHAS[@]}"}; do
    split_knowledge_fields "$gotcha" 2 2 --gotcha
    store_append_record "$STORE" condition "$FEATURE" "$SESSION" \
        subject "${PARSED_FIELDS[0]}" \
        why "${PARSED_FIELDS[1]}"
    WRITTEN=$((WRITTEN + 1))
done
for ((i = 0; i < ${#STRUCTURED_GOTCHA_SUBJECTS[@]}; i++)); do
    store_append_record "$STORE" condition "$FEATURE" "$SESSION" \
        subject "${STRUCTURED_GOTCHA_SUBJECTS[i]}" \
        why "${STRUCTURED_GOTCHA_WHYS[i]}"
    WRITTEN=$((WRITTEN + 1))
done

echo "Appended $WRITTEN knowledge record(s) to $STORE"
