#!/usr/bin/env bash
# add-principle.sh — append one developer-stated constitution principle to the global store.
# The numbered constitution remains the human-facing distillation; this record lets readers link
# decisions to the same §N without parsing Markdown.
#
# Usage: add-principle.sh --number <§N> --title <title> --rule <rule> --why <why>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_fluency

NUMBER=""; TITLE=""; RULE=""; WHY=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --number) shift; NUMBER="${1:-}" ;;
        --title) shift; TITLE="${1:-}" ;;
        --rule) shift; RULE="${1:-}" ;;
        --why) shift; WHY="${1:-}" ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

[ -n "$NUMBER" ] || { echo "Error: --number is required." >&2; exit 1; }
[ -n "$TITLE" ] || { echo "Error: --title is required." >&2; exit 1; }
[ -n "$RULE" ] || { echo "Error: --rule is required." >&2; exit 1; }
[ -n "$WHY" ] || { echo "Error: --why is required." >&2; exit 1; }
[[ "$NUMBER" =~ ^§[1-9][0-9]*$ ]] || {
    echo "Error: --number must be a constitution citation such as §1." >&2
    exit 1
}

STORE="$(concepts_store_path)"
store_append_record "$STORE" principle global none \
    number "$NUMBER" \
    title "$TITLE" \
    rule "$RULE" \
    why "$WHY"
echo "Appended principle $NUMBER to $STORE"
