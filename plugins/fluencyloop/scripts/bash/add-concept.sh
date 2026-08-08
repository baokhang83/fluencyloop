#!/usr/bin/env bash
# add-concept.sh — append architectural concepts and relations to the global store stream.
# Concepts describe product-level ideas, so they outlive an individual feature. The model supplies
# the irreducible explanation; this script assembles the schema record and never reads JSONL.
#
# Usage: add-concept.sh --name <name> --problem <problem> --how <how> \
#          --realized-by <component|file|area> [--realized-by <...> ...]
#        add-concept.sh --relate <from|to|kind> [--relate <...> ...]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_fluency

NAME=""; PROBLEM=""; HOW=""
declare -a REALIZED_BY=() RELATIONS=()
while [ "$#" -gt 0 ]; do
    case "$1" in
        --name) shift; NAME="${1:-}" ;;
        --problem) shift; PROBLEM="${1:-}" ;;
        --how) shift; HOW="${1:-}" ;;
        --realized-by) shift; REALIZED_BY+=("${1:-}") ;;
        --relate) shift; RELATIONS+=("${1:-}") ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

CONCEPT_REQUESTED=false
[ -n "$NAME$PROBLEM$HOW" ] && CONCEPT_REQUESTED=true
if $CONCEPT_REQUESTED; then
    [ -n "$NAME" ] || { echo "Error: --name is required for a concept." >&2; exit 1; }
    [ -n "$PROBLEM" ] || { echo "Error: --problem is required for a concept." >&2; exit 1; }
    [ -n "$HOW" ] || { echo "Error: --how is required for a concept." >&2; exit 1; }
    [ -n "${REALIZED_BY[*]-}" ] || { echo "Error: --realized-by is required for a concept." >&2; exit 1; }
elif [ -n "${REALIZED_BY[*]-}" ]; then
    echo "Error: --realized-by requires --name, --problem, and --how." >&2
    exit 1
fi

if ! $CONCEPT_REQUESTED && [ -z "${RELATIONS[*]-}" ]; then
    echo "Error: provide a concept or at least one --relate <from|to|kind>." >&2
    exit 1
fi

FEATURE="$(state_get feature)"
[ -n "$FEATURE" ] || FEATURE="$(current_feature_slug)"
[ -n "$FEATURE" ] || FEATURE="global"
SESSION="$(state_get last_session)"
SESSION="${SESSION##*/}"
SESSION="${SESSION%.md}"
[ -n "$SESSION" ] || SESSION="none"
STORE="$(concepts_store_path)"

if $CONCEPT_REQUESTED; then
    REALIZED_LIST="$(IFS=$'\n'; printf '%s' "${REALIZED_BY[*]}")"
    store_append_record "$STORE" concept "$FEATURE" "$SESSION" \
        name "$NAME" \
        problem "$PROBLEM" \
        how "$HOW" \
        realized_by "$REALIZED_LIST"
fi

for relation in ${RELATIONS[@]+"${RELATIONS[@]}"}; do
    IFS='|' read -r from to kind extra <<< "$relation"
    if [ -z "${from:-}" ] || [ -z "${to:-}" ] || [ -z "${kind:-}" ] || [ -n "${extra:-}" ]; then
        echo "Error: --relate must be <from|to|kind>." >&2
        exit 1
    fi
    store_append_record "$STORE" relation "$FEATURE" "$SESSION" \
        from "$from" \
        to "$to" \
        kind "$kind"
done

if $CONCEPT_REQUESTED; then
    echo "Appended concept \"$NAME\" to $STORE"
elif [ "${#RELATIONS[@]}" -eq 1 ]; then
    echo "Appended relation to $STORE"
else
    echo "Appended ${#RELATIONS[@]} relations to $STORE"
fi
