#!/usr/bin/env bash
# new-session.sh — open a session inside the active feature (Stage 3). A session is a
# slice of the build; the skill appends decision blocks to it as it teaches. Deterministic:
# creates the file from the template; the LLM supplies the content.
#
# Usage: new-session.sh [--json] [--slug <feature-slug>] <session-intent...>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

JSON_MODE=false
FEATURE_SLUG=""
ARGS=()
while [ "$#" -gt 0 ]; do
    case "$1" in
        --json) JSON_MODE=true ;;
        --slug) shift; FEATURE_SLUG="${1:-}" ;;
        *) ARGS+=("$1") ;;
    esac
    shift
done

require_fluency

# Default the feature to whatever the current branch says.
[ -z "$FEATURE_SLUG" ] && FEATURE_SLUG="$(current_feature_slug)"
if [ -z "$FEATURE_SLUG" ]; then
    echo "Error: no active feature. Checkout a feature/<slug> branch or pass --slug." >&2
    exit 1
fi

FEATURE="$(feature_path "$FEATURE_SLUG")"
if [ ! -d "$FEATURE" ]; then
    echo "Error: feature '$FEATURE_SLUG' not found at $FEATURE. Run 'fluency feature' first." >&2
    exit 1
fi

INTENT="${ARGS[*]:-}"
INTENT="$(printf '%s' "$INTENT" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
if [ -z "$INTENT" ]; then
    echo "Error: a session needs an intent, e.g. 'wiring the Redis store'." >&2
    exit 1
fi

SESSION_SLUG="$(slugify "$INTENT")"
SESSION="$FEATURE/sessions/$SESSION_SLUG.md"

CREATED=false
if [ ! -f "$SESSION" ]; then
    TEMPLATE="$(fluency_dir)/templates/session.md"
    esc_intent="$(printf '%s' "$INTENT" | sed 's/[&/\]/\\&/g')"
    sed -e "s/{{SESSION}}/$esc_intent/g" \
        -e "s/{{INTENT}}/$esc_intent/g" \
        -e "s/{{DATE}}/$(today)/g" \
        "$TEMPLATE" > "$SESSION"
    CREATED=true
fi

if $JSON_MODE; then
    emit_json \
        feature "$FEATURE_SLUG" \
        session_slug "$SESSION_SLUG" \
        intent "$INTENT" \
        session "$SESSION" \
        created "$CREATED"
else
    echo "Session: $INTENT"
    echo "  file: $SESSION$($CREATED && echo ' (created)')"
fi
