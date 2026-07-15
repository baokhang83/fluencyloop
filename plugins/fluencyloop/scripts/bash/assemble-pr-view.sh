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

FEATURE="$(feature_path "$FEATURE_SLUG")"
[ -d "$FEATURE" ] || { echo "Error: feature '$FEATURE_SLUG' not found." >&2; exit 1; }

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

# Collect the sessions.
shopt -s nullglob
SESSIONS=("$FEATURE/sessions/"*.md)
shopt -u nullglob

if $JSON_MODE; then
    files=""
    # Guard the expansion: on bash < 4.4 (macOS ships 3.2) "${arr[@]}" errors under `set -u`
    # when the array is empty — which it is for a feature with no sessions yet.
    if [ "${#SESSIONS[@]}" -gt 0 ]; then
        for s in "${SESSIONS[@]}"; do files+="${files:+, }\"$(json_escape "$s")\""; done
    fi
    printf '{"feature":"%s","feature_dir":"%s","base":"%s","range":"%s","commits":%s,"session_count":%s,"sessions":[%s]}\n' \
        "$(json_escape "$FEATURE_SLUG")" "$(json_escape "$FEATURE")" \
        "$(json_escape "$BASE")" "$(json_escape "$RANGE")" \
        "$COMMIT_COUNT" "${#SESSIONS[@]}" "$files"
    exit 0
fi

# Human/markdown form: the raw material for the reviewer summary.
FEATURE_TITLE="$(sed -n 's/^# Design: //p' "$FEATURE/design.md" 2>/dev/null | head -1)"
[ -z "$FEATURE_TITLE" ] && FEATURE_TITLE="$FEATURE_SLUG"

echo "# PR view — $FEATURE_TITLE"
echo
[ -n "$RANGE" ] && echo "_$COMMIT_COUNT commit(s) over \`$RANGE\`; feature branch \`$(branch_for "$FEATURE_SLUG")\`._" && echo
if [ "${#SESSIONS[@]}" -eq 0 ]; then
    echo "_No sessions journaled yet for this feature._"
else
    for s in "${SESSIONS[@]}"; do
        echo "---"
        echo
        cat "$s"
        echo
    done
fi
