#!/usr/bin/env bash
# new-feature.sh — declare a feature (Stage 2 entry). Deterministic: creates the branch
# and the feature dir with a design.md stub, then reports paths for the skill to fill in.
# A feature IS a branch (feature/<slug>); the design/build/journal all live under it.
#
# Usage: new-feature.sh [--json] [--slug <slug>] [--prefix <ticket-or-pr-id>] [--plan <plan-slug>] <intent...>
#
# The feature dir name always leads with a number so `features/` sorts and scans instead of
# reading as a flat pile: pass --prefix for a ticket id (e.g. "JIRA-1234") or a PR number
# (e.g. "pr-42"); omit it and a zero-padded sequential counter is used instead. --slug
# overrides the whole computed name outright.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

JSON_MODE=false
SLUG=""
PREFIX=""
PLAN=""
ARGS=()
while [ "$#" -gt 0 ]; do
    case "$1" in
        --json) JSON_MODE=true ;;
        --slug) shift; SLUG="${1:-}" ;;
        --prefix) shift; PREFIX="${1:-}" ;;
        --plan) shift; PLAN="${1:-}" ;;
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

if [ -z "$SLUG" ]; then
    # Idempotency: a bare re-run (no --slug/--prefix) with the same intent while already on
    # that feature's branch must reuse its slug rather than minting a new number each time —
    # next_feature_number() isn't a pure function of intent the way slugify(intent) alone was.
    # Compare against both the prefix-stripped slug (numbered features) and the whole slug
    # (features declared before per-feature numbering existed, which carry no prefix at all —
    # stripping "^[a-z0-9]+-" from one of those mangles the first word instead of a real
    # prefix, so it would never match and would fork a duplicate numbered branch/dir here).
    EXISTING_SLUG="$(current_feature_slug)"
    if [ -n "$EXISTING_SLUG" ]; then
        WANT_SLUG="$(slugify "$INTENT")"
        STRIPPED_SLUG="$(printf '%s' "$EXISTING_SLUG" | sed -E 's/^[a-z0-9]+-//')"
        if [ "$STRIPPED_SLUG" = "$WANT_SLUG" ] || [ "$EXISTING_SLUG" = "$WANT_SLUG" ]; then
            SLUG="$EXISTING_SLUG"
        fi
    fi
fi
if [ -z "$SLUG" ]; then
    if [ -n "$PREFIX" ]; then
        SLUG="$(numbered_slug "$PREFIX" "$INTENT")"
    else
        SLUG="$(numbered_slug "$(next_feature_number)" "$INTENT")"
    fi
fi
BRANCH="$(branch_for "$SLUG")"
FEATURE="$(feature_path "$SLUG")"

# Switch to the feature branch (create it if new, from the current HEAD). Capture what we
# forked from as the base ref (used later for the PR-view diff).
CREATED_BRANCH=false
BASE_REF=""
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git checkout "$BRANCH" >/dev/null 2>&1
else
    if git rev-parse --verify --quiet HEAD >/dev/null; then
        BASE_REF="$(git branch --show-current)"
        git checkout -b "$BRANCH" >/dev/null 2>&1
    else
        # `git init` leaves an unborn branch. Start this feature as the first branch without
        # creating an empty commit or requiring the developer's Git identity.
        git checkout --orphan "$BRANCH" >/dev/null 2>&1
    fi
    CREATED_BRANCH=true
fi
# On a re-run the branch already existed: keep the base ref state already recorded.
[ -z "$BASE_REF" ] && BASE_REF="$(state_get base_ref)"
if [ -z "$BASE_REF" ]; then
    for candidate in main master; do
        if git show-ref --verify --quiet "refs/heads/$candidate"; then
            BASE_REF="$candidate"
            break
        fi
    done
fi

mkdir -p "$FEATURE/sessions"

DESIGN="$FEATURE/design.md"
CREATED_DESIGN=false
if [ ! -f "$DESIGN" ]; then
    TEMPLATE="$(fluency_dir)/templates/design.md"
    sed -e "s/{{FEATURE}}/$(printf '%s' "$INTENT" | sed 's/[&/\]/\\&/g')/g" \
        -e "s/{{DATE}}/$(today)/g" \
        "$TEMPLATE" > "$DESIGN"
    # branch: is recorded here (not just in state.json) because the dir can later be renamed
    # to carry a PR number — see rename-feature-dir.sh — while the branch name stays put. The
    # index needs a durable way to map a feature dir back to its branch for merge status.
    awk -v line="branch: $BRANCH" '{print} /^started: /{print line}' "$DESIGN" > "$DESIGN.tmp" \
        && mv "$DESIGN.tmp" "$DESIGN"
    if [ -n "$PLAN" ]; then
        awk -v line="plan: $PLAN" '{print} /^branch: /{print line}' "$DESIGN" > "$DESIGN.tmp" \
            && mv "$DESIGN.tmp" "$DESIGN"
    fi
    CREATED_DESIGN=true
fi

# Record loop state: the single source of truth a skill reads instead of re-scanning git.
# Declaring a feature lands it at the design stage, with no session yet. feature_dir is stored
# explicitly (not just derived from slug) so the dir can later be renamed — e.g. once a PR
# number exists — without needing the branch name to change too.
write_state \
    feature "$SLUG" \
    branch "$BRANCH" \
    stage "design" \
    last_session "" \
    base_ref "$BASE_REF" \
    feature_dir "$(repo_rel "$FEATURE")" \
    plan "$PLAN" \
    updated "$(today)"
STATE="$(state_path)"

"$SCRIPT_DIR/index.sh" >/dev/null

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
        plan "$PLAN" \
        state "$STATE"
else
    echo "Feature: $INTENT"
    echo "  branch:   $BRANCH$($CREATED_BRANCH && echo ' (created)')"
    echo "  design:   $DESIGN$($CREATED_DESIGN && echo ' (stub)')"
    echo "  sessions: $FEATURE/sessions/"
    [ -n "$PLAN" ] && echo "  plan:     $PLAN"
    echo "  state:    $STATE (stage: design, base: $BASE_REF)"
fi
