#!/usr/bin/env bash
# new-feature.sh — declare a feature (Stage 2 entry). Deterministic: creates the branch, records
# it in state, and appends the feature declaration to the store. A feature IS a branch.
#
# Usage: new-feature.sh [--json] [--slug <slug>] [--prefix <ticket-or-pr-id>] [--plan <plan-slug>] [--base <ref>] <intent...>
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
REQUESTED_BASE=""
ARGS=()
while [ "$#" -gt 0 ]; do
    case "$1" in
        --json) JSON_MODE=true ;;
        --slug) shift; SLUG="${1:-}" ;;
        --prefix) shift; PREFIX="${1:-}" ;;
        --plan) shift; PLAN="${1:-}" ;;
        --base) shift; REQUESTED_BASE="${1:-}" ;;
        -h|--help)
            echo "Usage: new-feature.sh [--json] [--slug <slug>] [--prefix <ticket-or-pr-id>] [--plan <plan-slug>] [--base <ref>] <intent...>"
            exit 0
            ;;
        # An intent never starts with a dash, so a flag-shaped token here is a typo or an
        # unsupported option, not text to fold into the intent -- e.g. `--help` reaching this
        # point unhandled used to become the intent itself, minting a real "help" feature.
        -*) echo "Unknown option: $1" >&2; exit 1 ;;
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

# Switch to the feature branch. A new feature started while another feature is active must not
# silently become a stacked branch: reuse that active feature's recorded integration base. An
# explicit --base is the opt-in escape hatch for intentionally stacked work.
CREATED_BRANCH=false
BASE_REF=""
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git checkout "$BRANCH" >/dev/null 2>&1
else
    if git rev-parse --verify --quiet HEAD >/dev/null; then
        CURRENT_BRANCH="$(git branch --show-current)"
        BASE_REF="$REQUESTED_BASE"
        if [ -z "$BASE_REF" ] && [[ "$CURRENT_BRANCH" = feature/* ]] && [ "$(state_get branch)" = "$CURRENT_BRANCH" ]; then
            BASE_REF="$(state_get base_ref)"
        fi
        [ -n "$BASE_REF" ] || BASE_REF="$CURRENT_BRANCH"
        git rev-parse --verify --quiet "$BASE_REF" >/dev/null || {
            echo "Error: feature base ref does not exist: $BASE_REF" >&2
            exit 1
        }
        git checkout -b "$BRANCH" "$BASE_REF" >/dev/null 2>&1
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

# Record loop state: the single source of truth a skill reads instead of re-scanning git.
# Declaring a feature lands it at the design stage, with no session yet. `feature_dir` stays
# empty for compatibility with existing state readers; 0.3 creates no feature markdown path.
write_state \
    feature "$SLUG" \
    branch "$BRANCH" \
    stage "design" \
    last_session "" \
    base_ref "$BASE_REF" \
    feature_dir "" \
    plan "$PLAN" \
    updated "$(today)"
STATE="$(state_path)"
STORE="$(feature_store_path "$SLUG")"
store_append_record "$STORE" feature "$SLUG" none \
    slug "$SLUG" \
    intent "$INTENT" \
    branch "$BRANCH" \
    base_ref "$BASE_REF"

if $JSON_MODE; then
    emit_json \
        slug "$SLUG" \
        intent "$INTENT" \
        branch "$BRANCH" \
        branch_created "$CREATED_BRANCH" \
        store "$STORE" \
        base_ref "$BASE_REF" \
        plan "$PLAN" \
        state "$STATE"
else
    echo "Feature: $INTENT"
    echo "  branch:   $BRANCH$($CREATED_BRANCH && echo ' (created)')"
    echo "  store:    $STORE"
    [ -n "$PLAN" ] && echo "  plan:     $PLAN"
    echo "  state:    $STATE (stage: design, base: $BASE_REF)"
fi
