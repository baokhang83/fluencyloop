#!/usr/bin/env bash
# rename-feature-dir.sh — swap a feature's docs dir to carry its PR number once one exists.
# The branch name (feature/<original-slug>) is left untouched: renaming a branch that may
# already be pushed and open as a PR is a much bigger, riskier operation than renaming a doc
# dir, and design.md's own `branch:` line (see new-feature.sh) means nothing downstream
# depends on the dir name matching the branch name anyway. Deterministic: git mv's the dir and
# updates feature_dir (and, if needed, last_session) in state.json.
#
# Usage: rename-feature-dir.sh [--json] --pr <number> [--slug <feature-slug>]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

JSON_MODE=false
PR=""
SLUG=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --json) JSON_MODE=true ;;
        --pr) shift; PR="${1:-}" ;;
        --slug) shift; SLUG="${1:-}" ;;
        *) echo "Error: unknown argument '$1'" >&2; exit 1 ;;
    esac
    shift
done

require_fluency

[ -z "$SLUG" ] && SLUG="$(current_feature_slug)"
if [ -z "$SLUG" ]; then
    echo "Error: no active feature. Checkout a feature/<slug> branch or pass --slug." >&2
    exit 1
fi
if [ -z "$PR" ]; then
    echo "Error: --pr <number> is required, e.g. rename-feature-dir.sh --pr 42" >&2
    exit 1
fi

OLD="$(feature_path "$SLUG")"
if [ ! -d "$OLD" ]; then
    echo "Error: feature '$SLUG' not found at $OLD." >&2
    exit 1
fi

# Strip a leading numeric/ticket segment (up to and including the first '-') off the current
# dir name and rebuild it under the pr- prefix; keeps the rest of the slug recognizable.
BASENAME="$(basename "$OLD")"
SUFFIX="$(printf '%s' "$BASENAME" | sed -E 's/^[a-z0-9]+-//')"
[ -z "$SUFFIX" ] && SUFFIX="$BASENAME"
NEW_SLUG="$(numbered_slug "pr-$PR" "$SUFFIX")"
NEW="$(dirname "$OLD")/$NEW_SLUG"

RENAMED=false
if [ "$OLD" != "$NEW" ]; then
    if [ -e "$NEW" ]; then
        echo "Error: target dir already exists: $NEW" >&2
        exit 1
    fi
    git mv "$OLD" "$NEW"
    RENAMED=true

    OLD_REL="$(repo_rel "$OLD")"
    NEW_REL="$(repo_rel "$NEW")"
    LAST_SESSION="$(state_get last_session)"
    case "$LAST_SESSION" in
        "$OLD_REL/"*) LAST_SESSION="$NEW_REL/${LAST_SESSION#"$OLD_REL"/}" ;;
    esac

    # write_state replaces the whole file, so carry forward every field, not just the one
    # that changed.
    write_state \
        feature "$(state_get feature)" \
        branch "$(state_get branch)" \
        stage "$(state_get stage)" \
        last_session "$LAST_SESSION" \
        base_ref "$(state_get base_ref)" \
        feature_dir "$NEW_REL" \
        plan "$(state_get plan)" \
        updated "$(today)"
fi

if $JSON_MODE; then
    emit_json \
        slug "$SLUG" \
        old_dir "$OLD" \
        new_dir "$NEW" \
        renamed "$RENAMED"
else
    if $RENAMED; then
        echo "Renamed: $OLD"
        echo "     ->  $NEW"
    else
        echo "Already at target name: $NEW"
    fi
fi
