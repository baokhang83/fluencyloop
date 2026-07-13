#!/usr/bin/env bash
# new-plan.sh — declare a plan (the planning stage). Deterministic: scaffolds a plan.md for a
# large initiative from the template and reports paths for the skill to fill in. Unlike a
# feature, a plan does NOT create a branch — it is a committed doc on the current branch that
# maps out the architecture, task breakdown, roadmap, and critical path the features build from.
#
# Usage: new-plan.sh [--json] [--slug <slug>] <intent...>

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
    echo "Error: a plan needs an intent, e.g. fluencyloop plan \"revamp the checkout flow\"" >&2
    exit 1
fi

[ -z "$SLUG" ] && SLUG="$(slugify "$INTENT")"
PLAN_DIR="$(plan_path "$SLUG")"
PLAN="$PLAN_DIR/plan.md"

mkdir -p "$PLAN_DIR"

CREATED=false
if [ ! -f "$PLAN" ]; then
    TEMPLATE="$(fluency_dir)/templates/plan.md"
    esc_intent="$(printf '%s' "$INTENT" | sed 's/[&/\]/\\&/g')"
    sed -e "s/{{INITIATIVE}}/$esc_intent/g" \
        -e "s/{{DATE}}/$(today)/g" \
        "$TEMPLATE" > "$PLAN"
    CREATED=true
fi

if $JSON_MODE; then
    emit_json \
        slug "$SLUG" \
        intent "$INTENT" \
        plan_dir "$PLAN_DIR" \
        plan "$PLAN" \
        created "$CREATED"
else
    echo "Plan: $INTENT"
    echo "  file: $PLAN$($CREATED && echo ' (stub)')"
fi
