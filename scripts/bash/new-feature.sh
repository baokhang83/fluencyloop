#!/usr/bin/env bash
# new-feature.sh — declare a feature (Stage 2 entry). Deterministic: creates the branch
# and the feature dir with a design.md stub, then reports paths for the skill to fill in.
# A feature IS a branch (feature/<slug>); the design/build/journal all live under it.
#
# Usage: new-feature.sh [--json] [--slug <slug>] <intent...>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

JSON_MODE=false
SLUG=""
ARGS=()
while [ "$#" -gt 0 ]; do
    case "$1" in
        --json) JSON_MODE=true ;;
        --slug) shift; SLUG="${1:-}" ;;
        *) ARGS+=("$1") ;;
    esac
    shift
done

require_fluency

INTENT="${ARGS[*]:-}"
INTENT="$(printf '%s' "$INTENT" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
if [ -z "$INTENT" ]; then
    echo "Error: a feature needs an intent, e.g. fluencyloop feature \"adding rate limiting\"" >&2
    exit 1
fi

[ -z "$SLUG" ] && SLUG="$(slugify "$INTENT")"
BRANCH="$(branch_for "$SLUG")"
FEATURE="$(feature_path "$SLUG")"

# Switch to the feature branch (create it if new, from the current HEAD). Capture what we
# forked from as the base ref (used later for the PR-view diff).
CREATED_BRANCH=false
BASE_REF=""
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git checkout "$BRANCH" >/dev/null 2>&1
else
    BASE_REF="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
    git checkout -b "$BRANCH" >/dev/null 2>&1
    CREATED_BRANCH=true
fi
# On a re-run the branch already existed: keep the base ref state already recorded.
[ -z "$BASE_REF" ] && BASE_REF="$(state_get base_ref)"
[ -z "$BASE_REF" ] && BASE_REF="main"

mkdir -p "$FEATURE/sessions"

DESIGN="$FEATURE/design.md"
CREATED_DESIGN=false
if [ ! -f "$DESIGN" ]; then
    TEMPLATE="$(fluency_dir)/templates/design.md"
    sed -e "s/{{FEATURE}}/$(printf '%s' "$INTENT" | sed 's/[&/\]/\\&/g')/g" \
        -e "s/{{DATE}}/$(today)/g" \
        "$TEMPLATE" > "$DESIGN"
    CREATED_DESIGN=true
fi

# Record loop state: the single source of truth a skill reads instead of re-scanning git.
# Declaring a feature lands it at the design stage, with no session yet.
write_state \
    feature "$SLUG" \
    branch "$BRANCH" \
    stage "design" \
    last_session "" \
    base_ref "$BASE_REF" \
    updated "$(today)"
STATE="$(state_path)"

if $JSON_MODE; then
    emit_json \
        slug "$SLUG" \
        intent "$INTENT" \
        branch "$BRANCH" \
        branch_created "$CREATED_BRANCH" \
        feature_dir "$FEATURE" \
        design "$DESIGN" \
        design_created "$CREATED_DESIGN" \
        sessions_dir "$FEATURE/sessions" \
        base_ref "$BASE_REF" \
        state "$STATE"
else
    echo "Feature: $INTENT"
    echo "  branch:   $BRANCH$($CREATED_BRANCH && echo ' (created)')"
    echo "  design:   $DESIGN$($CREATED_DESIGN && echo ' (stub)')"
    echo "  sessions: $FEATURE/sessions/"
    echo "  state:    $STATE (stage: design, base: $BASE_REF)"
fi
