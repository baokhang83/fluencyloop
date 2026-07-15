#!/usr/bin/env bash
# add-decision.sh — deterministically assemble a `## Decision:` block and append it to the active
# session. The model supplies only the irreducible field values (the taught *why*); the script
# does the mechanical markdown formatting (the bullet schema), so the journal is consistently
# structured and the model never hand-formats it.
#
# Usage: add-decision.sh --where <path> --why <text> [--title <text>] [--alternative <text>]
#          [--design <ref>] [--constitution <§N>] [--trust <verified|unverified>]
#          [--session <path>]
#
# The session defaults to the active feature's last session (state.json); pass --session to target
# a specific file. Emits nothing to the file's schema the model has to remember.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_fluency

TITLE=""; WHERE=""; WHY=""; ALT=""; DESIGN=""; CONST=""
TRUST="⚠ not independently verified"; SESSION=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --title) shift; TITLE="${1:-}" ;;
        --where) shift; WHERE="${1:-}" ;;
        --why) shift; WHY="${1:-}" ;;
        --alternative) shift; ALT="${1:-}" ;;
        --design) shift; DESIGN="${1:-}" ;;
        --constitution) shift; CONST="${1:-}" ;;
        --trust) shift; case "${1:-}" in
                     verified|✓*) TRUST="✓ verified" ;;
                     *) TRUST="⚠ not independently verified" ;;
                 esac ;;
        --session) shift; SESSION="${1:-}" ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

[ -n "$WHERE" ] || { echo "Error: --where is required (a file/area, never a line number)." >&2; exit 1; }
[ -n "$WHY" ]   || { echo "Error: --why is required (the taught rationale)." >&2; exit 1; }

# Resolve the session file: explicit --session, else the active feature's last session.
if [ -z "$SESSION" ]; then
    rel="$(state_get last_session)"
    [ -n "$rel" ] && SESSION="$(repo_root)/$rel"
fi
if [ -z "$SESSION" ] || [ ! -f "$SESSION" ]; then
    echo "Error: no session file — open one with 'fluencyloop session \"<slice>\"' or pass --session." >&2
    exit 1
fi

[ -n "$TITLE" ] || TITLE="decision"

{
    printf '\n## Decision: %s\n\n' "$TITLE"
    printf -- '- **where:** %s\n' "\`$WHERE\`"
    printf -- '- **why:** %s\n' "$WHY"
    [ -n "$ALT" ]    && printf -- '- **alternative:** %s\n' "$ALT"
    [ -n "$DESIGN" ] && printf -- '- **design:** %s\n' "$DESIGN"
    [ -n "$CONST" ]  && printf -- '- **constitution:** %s\n' "$CONST"
    printf -- '- **trust:** %s\n' "$TRUST"
} >> "$SESSION"

echo "Appended decision \"$TITLE\" to $SESSION"
