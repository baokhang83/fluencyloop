#!/usr/bin/env bash
# new-session.sh — open a session inside the active feature (Stage 3). A session is a slice of
# the build. It is recorded in the feature store; no session markdown is created.
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
        -h|--help)
            echo "Usage: new-session.sh [--json] [--slug <feature-slug>] <session-intent...>"
            exit 0
            ;;
        # An intent never starts with a dash, so a flag-shaped token here is a typo or an
        # unsupported option, not text to fold into the intent.
        -*) echo "Unknown option: $1" >&2; exit 1 ;;
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

INTENT="${ARGS[*]:-}"
INTENT="$(printf '%s' "$INTENT" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
if [ -z "$INTENT" ]; then
    echo "Error: a session needs an intent, e.g. 'wiring the Redis store'." >&2
    exit 1
fi

# The append-only feature store is the durable session sequence. State only identifies the active
# session and can legitimately move backwards when a branch is reset or rebased.
SESSION_NUMBER="$(next_session_number "$FEATURE_SLUG")"
SESSION_SLUG="$(numbered_slug "$SESSION_NUMBER" "$INTENT")"

# Update loop state: opening a session moves the feature to the build stage and records its slug.
# write_state replaces the whole file, so carry forward every field, not just the ones this script
# cares about.
BASE_REF="$(state_get base_ref)"; [ -z "$BASE_REF" ] && BASE_REF="main"
write_state \
    feature "$FEATURE_SLUG" \
    branch "$(branch_for "$FEATURE_SLUG")" \
    stage "build" \
    last_session "$SESSION_SLUG" \
    base_ref "$BASE_REF" \
    feature_dir "$(state_get feature_dir)" \
    plan "$(state_get plan)" \
    updated "$(today)"
STATE="$(state_path)"
STORE="$(feature_store_path "$FEATURE_SLUG")"
store_append_record "$STORE" session "$FEATURE_SLUG" "$SESSION_SLUG" \
    slug "$SESSION_SLUG" \
    intent "$INTENT"

if $JSON_MODE; then
    emit_json \
        feature "$FEATURE_SLUG" \
        session_slug "$SESSION_SLUG" \
        intent "$INTENT" \
        store "$STORE" \
        state "$STATE"
else
    echo "Session: $INTENT"
    echo "  store: $STORE"
    echo "  state: $STATE (stage: build)"
fi
