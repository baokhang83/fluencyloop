#!/usr/bin/env bash
# check.sh — the FluencyLoop doctor. A deterministic drift/state detector so skills make cheap
# decisions without the model scanning git. Reports whether the loop is set up, the active
# feature (from state.json), how many commits have landed since the last journaled session
# (un-journaled drift — the signal review/backfill care about), and whether the per-developer
# calibration profile exists.
#
# Usage: check.sh [--json]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

JSON_MODE=false
for arg in "$@"; do
    case "$arg" in
        --json) JSON_MODE=true ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

ROOT="$(repo_root)"

# --- is the loop set up here? ---
FLUENCY_DIR="$(fluency_dir)"
FLUENCY_PRESENT=false
[ -n "$FLUENCY_DIR" ] && [ -d "$FLUENCY_DIR" ] && FLUENCY_PRESENT=true

# --- active feature: from state.json, falling back to the branch ---
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
FEATURE="$(state_get feature)"
[ -z "$FEATURE" ] && FEATURE="$(current_feature_slug)"
STAGE="$(state_get stage)"
BASE="$(state_get base_ref)"; [ -z "$BASE" ] && BASE="main"
LAST_SESSION="$(state_get last_session)"

# --- un-journaled drift: commits since the last commit that touched the sessions dir. If no
# session has ever been committed, everything since the base ref counts as un-journaled. ---
UNJOURNALED=0
if [ -n "$ROOT" ] && [ -n "$FEATURE" ]; then
    SESSIONS_DIR="$(feature_path "$FEATURE")/sessions"
    LAST_JOURNAL_COMMIT="$(git log -1 --format=%H -- "$SESSIONS_DIR" 2>/dev/null || true)"
    if [ -n "$LAST_JOURNAL_COMMIT" ]; then
        UNJOURNALED="$(git rev-list --count "$LAST_JOURNAL_COMMIT..HEAD" 2>/dev/null || echo 0)"
    elif git rev-parse --verify --quiet "$BASE" >/dev/null 2>&1; then
        UNJOURNALED="$(git rev-list --count "$BASE..HEAD" 2>/dev/null || echo 0)"
    fi
fi

# --- per-developer calibration profile (global, never committed) ---
CAL_FILE="${FLUENCYLOOP_HOME:-$HOME/.fluencyloop}/calibration.md"
CAL_PRESENT=false
[ -f "$CAL_FILE" ] && CAL_PRESENT=true

if $JSON_MODE; then
    printf '{"fluency":%s,"branch":"%s","feature":"%s","stage":"%s","base_ref":"%s","last_session":"%s","unjournaled_commits":%s,"calibration":%s}\n' \
        "$FLUENCY_PRESENT" \
        "$(json_escape "$BRANCH")" \
        "$(json_escape "$FEATURE")" \
        "$(json_escape "$STAGE")" \
        "$(json_escape "$BASE")" \
        "$(json_escape "$LAST_SESSION")" \
        "$UNJOURNALED" \
        "$CAL_PRESENT"
    exit 0
fi

# Human form.
mark() { [ "$1" = true ] && printf 'ok ' || printf 'XX '; }
echo "FluencyLoop check"
echo "  $(mark "$FLUENCY_PRESENT") .fluencyloop/ present"
if [ -n "$FEATURE" ]; then
    echo "  ok  active feature: $FEATURE${STAGE:+ (stage: $STAGE)}"
else
    echo "  XX  no active feature"
fi
if [ "$UNJOURNALED" -gt 0 ]; then
    echo "  !!  $UNJOURNALED commit(s) since the last journaled session — un-journaled drift"
else
    echo "  ok  no un-journaled drift"
fi
echo "  $(mark "$CAL_PRESENT") calibration profile ($CAL_FILE)"
