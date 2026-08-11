#!/usr/bin/env bash
# add-record-explanation.sh — append a reader-facing explanation for one architectural record.
#
# Usage: add-record-explanation.sh --record <name> --context <text> --decision <text> \
#          --mechanism <text> --consequences <text> \
#          [--diagram <docs/fluencyloop/diagrams/records/*.html> \
#           --diagram-type <type> --diagram-alt <text>]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
require_fluency

RECORD=""; CONTEXT=""; DECISION=""; MECHANISM=""; CONSEQUENCES=""
DIAGRAM=""; DIAGRAM_TYPE=""; DIAGRAM_ALT=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --record) shift; RECORD="${1:-}" ;;
        --context) shift; CONTEXT="${1:-}" ;;
        --decision) shift; DECISION="${1:-}" ;;
        --mechanism) shift; MECHANISM="${1:-}" ;;
        --consequences) shift; CONSEQUENCES="${1:-}" ;;
        --diagram) shift; DIAGRAM="${1:-}" ;;
        --diagram-type) shift; DIAGRAM_TYPE="${1:-}" ;;
        --diagram-alt) shift; DIAGRAM_ALT="${1:-}" ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

for required in RECORD CONTEXT DECISION MECHANISM CONSEQUENCES; do
    if [ -z "${!required}" ]; then
        echo "Error: --$(printf '%s' "$required" | tr '[:upper:]_' '[:lower:]-') is required." >&2
        exit 1
    fi
done

if [ -n "$DIAGRAM$DIAGRAM_TYPE$DIAGRAM_ALT" ]; then
    [ -n "$DIAGRAM" ] || { echo "Error: --diagram is required with diagram metadata." >&2; exit 1; }
    [ -n "$DIAGRAM_TYPE" ] || { echo "Error: --diagram-type is required with --diagram." >&2; exit 1; }
    [ -n "$DIAGRAM_ALT" ] || { echo "Error: --diagram-alt is required with --diagram." >&2; exit 1; }
    if [[ ! "$DIAGRAM" =~ ^docs/fluencyloop/diagrams/records/[A-Za-z0-9][A-Za-z0-9._-]*\.html$ ]]; then
        echo "Error: --diagram must be a safe project-relative HTML file under docs/fluencyloop/diagrams/records/." >&2
        exit 1
    fi
    ROOT="$(repo_root)"
    if [ ! -f "$ROOT/$DIAGRAM" ]; then
        echo "Error: --diagram must name an existing project file." >&2
        exit 1
    fi
fi

FEATURE="$(state_get feature)"
[ -n "$FEATURE" ] || FEATURE="$(current_feature_slug)"
[ -n "$FEATURE" ] || FEATURE="global"
SESSION="$(state_get last_session)"
SESSION="${SESSION##*/}"
SESSION="${SESSION%.md}"
[ -n "$SESSION" ] || SESSION="none"

FIELDS=(
    record "$RECORD"
    context "$CONTEXT"
    decision "$DECISION"
    mechanism "$MECHANISM"
    consequences "$CONSEQUENCES"
)
if [ -n "$DIAGRAM" ]; then
    FIELDS+=(diagram_path "$DIAGRAM" diagram_type "$DIAGRAM_TYPE" diagram_alt "$DIAGRAM_ALT")
fi
store_append_record "$(concepts_store_path)" record_explanation "$FEATURE" "$SESSION" "${FIELDS[@]}"
echo "Appended explanation for architectural record \"$RECORD\" to $(concepts_store_path)"
