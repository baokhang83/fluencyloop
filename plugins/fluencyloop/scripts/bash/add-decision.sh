#!/usr/bin/env bash
# add-decision.sh — append one decision record to the active feature's store. The model supplies
# only the irreducible field values (the taught *why*); the script assembles the schema envelope.
#
# Usage: add-decision.sh --where <path> --why <text> [--title <text>] [--alternative <text>]
#          [--design <ref>] [--constitution <§N>] [--trust <verified|unverified>]
#          [--feature <feature-slug> --session <session-slug-or-legacy-path>]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_fluency

TITLE=""; WHERE=""; WHY=""; ALT=""; DESIGN=""; CONST=""
TRUST="unverified"; SESSION=""; FEATURE_OVERRIDE=""; SESSION_OVERRIDE=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --title) shift; TITLE="${1:-}" ;;
        --where) shift; WHERE="${1:-}" ;;
        --why) shift; WHY="${1:-}" ;;
        --alternative) shift; ALT="${1:-}" ;;
        --design) shift; DESIGN="${1:-}" ;;
        --constitution) shift; CONST="${1:-}" ;;
        --trust) shift; case "${1:-}" in
                     verified|✓*) TRUST="verified" ;;
                     *) TRUST="unverified" ;;
                 esac ;;
        --session) shift; SESSION="${1:-}"; SESSION_OVERRIDE=true ;;
        --feature) shift; FEATURE_OVERRIDE="${1:-}" ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

[ -z "$FEATURE_OVERRIDE" ] || { $SESSION_OVERRIDE && [ -n "$SESSION" ]; } || { echo "Error: --feature requires --session so a historical record cannot attach to the active session." >&2; exit 1; }
[ -n "$WHERE" ] || { echo "Error: --where is required (a file/area, never a line number)." >&2; exit 1; }
[ -n "$WHY" ]   || { echo "Error: --why is required (the taught rationale)." >&2; exit 1; }

# Resolve the session slug: explicit --session, else the active feature's last session. Legacy
# markdown paths stay accepted as input, but only their filename is persisted in new records.
if [ -z "$SESSION" ]; then
    SESSION="$(state_get last_session)"
fi
SESSION="${SESSION##*/}"
SESSION="${SESSION%.md}"
if [ -z "$SESSION" ]; then
    echo "Error: no active session — open one with 'fluencyloop session \"<slice>\"' or pass --session." >&2
    exit 1
fi

[ -n "$TITLE" ] || TITLE="decision"
FEATURE="$FEATURE_OVERRIDE"
[ -n "$FEATURE" ] || FEATURE="$(state_get feature)"
[ -n "$FEATURE" ] || FEATURE="$(current_feature_slug)"
if [ -z "$FEATURE" ]; then
    echo "Error: no active feature. Checkout a feature/<slug> branch first." >&2
    exit 1
fi
STORE="$(feature_store_path "$FEATURE")"
store_append_record "$STORE" decision "$FEATURE" "$SESSION" \
    title "$TITLE" \
    where "$WHERE" \
    why "$WHY" \
    alternative "$ALT" \
    design "$DESIGN" \
    constitution "$CONST" \
    trust "$TRUST"

echo "Appended decision \"$TITLE\" to $STORE"
