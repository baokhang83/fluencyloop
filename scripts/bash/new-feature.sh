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
    echo "Error: a feature needs an intent, e.g. fluency feature \"adding rate limiting\"" >&2
    exit 1
fi

[ -z "$SLUG" ] && SLUG="$(slugify "$INTENT")"
BRANCH="$(branch_for "$SLUG")"
FEATURE="$(feature_path "$SLUG")"

# Switch to the feature branch (create it if new, from the current HEAD).
CREATED_BRANCH=false
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git checkout "$BRANCH" >/dev/null 2>&1
else
    git checkout -b "$BRANCH" >/dev/null 2>&1
    CREATED_BRANCH=true
fi

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

if $JSON_MODE; then
    emit_json \
        slug "$SLUG" \
        intent "$INTENT" \
        branch "$BRANCH" \
        branch_created "$CREATED_BRANCH" \
        feature_dir "$FEATURE" \
        design "$DESIGN" \
        design_created "$CREATED_DESIGN" \
        sessions_dir "$FEATURE/sessions"
else
    echo "Feature: $INTENT"
    echo "  branch:   $BRANCH$($CREATED_BRANCH && echo ' (created)')"
    echo "  design:   $DESIGN$($CREATED_DESIGN && echo ' (stub)')"
    echo "  sessions: $FEATURE/sessions/"
fi
