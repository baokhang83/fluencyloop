#!/usr/bin/env bash
# add-requirement.sh — append answered planning gaps and open questions to the store.
# Requirements are initiative-level context, so records are outside a build session. A later
# answer is a new requirement line; it never rewrites the open question it resolves.
#
# Usage: add-requirement.sh --gap <gap> --answer <answer> --consequence <consequence>
#        add-requirement.sh --open <gap> --matters <why it matters>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_fluency

GAP=""; ANSWER=""; CONSEQUENCE=""; OPEN=""; MATTERS=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --gap) shift; GAP="${1:-}" ;;
        --answer) shift; ANSWER="${1:-}" ;;
        --consequence) shift; CONSEQUENCE="${1:-}" ;;
        --open) shift; OPEN="${1:-}" ;;
        --matters) shift; MATTERS="${1:-}" ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

ANSWERED_REQUESTED=false
[ -n "$GAP$ANSWER$CONSEQUENCE" ] && ANSWERED_REQUESTED=true
OPEN_REQUESTED=false
[ -n "$OPEN$MATTERS" ] && OPEN_REQUESTED=true

if $ANSWERED_REQUESTED && $OPEN_REQUESTED; then
    echo "Error: provide either an answered requirement or an open question, not both." >&2
    exit 1
fi
if $ANSWERED_REQUESTED; then
    [ -n "$GAP" ] || { echo "Error: --gap is required for an answered requirement." >&2; exit 1; }
    [ -n "$ANSWER" ] || { echo "Error: --answer is required for an answered requirement." >&2; exit 1; }
    [ -n "$CONSEQUENCE" ] || { echo "Error: --consequence is required for an answered requirement." >&2; exit 1; }
elif $OPEN_REQUESTED; then
    [ -n "$OPEN" ] || { echo "Error: --open is required for an open question." >&2; exit 1; }
    [ -n "$MATTERS" ] || { echo "Error: --matters is required for an open question." >&2; exit 1; }
else
    echo "Error: provide --gap, --answer, and --consequence, or --open and --matters." >&2
    exit 1
fi

# A plan may be created before its first feature branch. In that case its requirements belong in
# the repository-wide stream; otherwise retain the active feature context so the schema identity
# can distinguish the same gap across initiatives.
FEATURE="$(state_get feature)"
[ -n "$FEATURE" ] || FEATURE="$(current_feature_slug)"
if [ -n "$FEATURE" ]; then
    STORE="$(feature_store_path "$FEATURE")"
else
    FEATURE="global"
    STORE="$(concepts_store_path)"
fi

if $ANSWERED_REQUESTED; then
    store_append_record "$STORE" requirement "$FEATURE" none \
        gap "$GAP" \
        answer "$ANSWER" \
        consequence "$CONSEQUENCE"
    echo "Appended requirement to $STORE"
else
    store_append_record "$STORE" open_question "$FEATURE" none \
        gap "$OPEN" \
        why_it_matters "$MATTERS"
    echo "Appended open question to $STORE"
fi
