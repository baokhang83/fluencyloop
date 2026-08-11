#!/usr/bin/env bash
# assemble-pr-view.sh — Stage 4. A feature IS a branch, so the PR view assembles itself:
# gather the active feature's sessions and emit the raw material for a reviewer-facing
# summary. Deterministic collection only; the skill turns this into prose.
#
# Usage: assemble-pr-view.sh [--json] [--base <ref>] [--slug <feature-slug>]
#   --base defaults to the repo's main branch; used only to report the commit range.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

JSON_MODE=false
BASE=""
FEATURE_SLUG=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --json) JSON_MODE=true ;;
        --base) shift; BASE="${1:-}" ;;
        --slug) shift; FEATURE_SLUG="${1:-}" ;;
    esac
    shift
done

require_fluency

[ -z "$FEATURE_SLUG" ] && FEATURE_SLUG="$(current_feature_slug)"
if [ -z "$FEATURE_SLUG" ]; then
    echo "Error: no active feature branch. Checkout feature/<slug> or pass --slug." >&2
    exit 1
fi

STORE="$(feature_store_path "$FEATURE_SLUG")"

# Resolve the base ref for the commit range (best-effort): explicit --base, else the base the
# feature recorded in state.json, else the repo's main/master.
[ -z "$BASE" ] && BASE="$(state_get base_ref)"
if [ -z "$BASE" ]; then
    for cand in main master; do
        git show-ref --verify --quiet "refs/heads/$cand" && { BASE="$cand"; break; }
    done
fi
RANGE=""
COMMIT_COUNT=0
if [ -n "$BASE" ] && git rev-parse --verify --quiet "$BASE" >/dev/null; then
    RANGE="$BASE..HEAD"
    COMMIT_COUNT="$(git rev-list --count "$RANGE" 2>/dev/null || echo 0)"
fi

# Session declarations are append-only store records in 0.3. Preserve their complete JSON lines
# rather than reconstructing fields in shell; that keeps the reviewer view faithful to the writer.
SESSION_LINES=""
if [ -f "$STORE" ]; then
    SESSION_LINES="$(grep '"type":"session"' "$STORE" || true)"
fi
if [ -n "$SESSION_LINES" ]; then
    SESSION_COUNT="$(printf '%s\n' "$SESSION_LINES" | wc -l | tr -d ' ')"
    SESSIONS_JSON="$(printf '%s\n' "$SESSION_LINES" | awk 'BEGIN { first=1 } { printf "%s%s", first ? "" : ",", $0; first=0 }')"
else
    SESSION_COUNT=0
    SESSIONS_JSON=""
fi

if $JSON_MODE; then
    printf '{"feature":"%s","store":"%s","base":"%s","range":"%s","commits":%s,"session_count":%s,"sessions":[%s]}\n' \
        "$(json_escape "$FEATURE_SLUG")" "$(json_escape "$STORE")" \
        "$(json_escape "$BASE")" "$(json_escape "$RANGE")" \
        "$COMMIT_COUNT" "$SESSION_COUNT" "$SESSIONS_JSON"
    exit 0
fi

# Human/markdown form: the raw material for the reviewer summary.
echo "# PR view — $FEATURE_SLUG"
echo
[ -n "$RANGE" ] && echo "_$COMMIT_COUNT commit(s) over \`$RANGE\`; feature branch \`$(branch_for "$FEATURE_SLUG")\`._" && echo
echo "_Session and decision records: \`$STORE\`._"
