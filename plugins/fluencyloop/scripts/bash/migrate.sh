#!/usr/bin/env bash
# migrate.sh — one-time move of human-facing docs from the pre-refactor location
# (.fluencyloop/constitution.md and .fluencyloop/features/) to docs/fluencyloop/.
# Idempotent: safe to run more than once; a no-op once everything is already moved.
# Machine state (scripts/, templates/) is left in .fluencyloop/ untouched.
#
# Usage: migrate.sh [--json] [--dry-run]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

JSON_MODE=false
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --json) JSON_MODE=true ;;
        --dry-run) DRY_RUN=true ;;
    esac
done

require_fluency

OLD_FLUENCY="$(fluency_dir)"
DOCS="$(docs_dir)"
MOVED=()

# Move a tracked path with `git mv` (keeps history) or a plain `mv` if untracked/no git.
move_path() {
    local src="$1" dest="$2"
    [ -e "$src" ] || return 0
    if [ -e "$dest" ]; then
        echo "Skip: $dest already exists (leaving $src in place)." >&2
        return 0
    fi
    MOVED+=("$src -> $dest")
    $DRY_RUN && return 0
    mkdir -p "$(dirname "$dest")"
    if git ls-files --error-unmatch "$src" >/dev/null 2>&1; then
        git mv "$src" "$dest"
    else
        mv "$src" "$dest"
    fi
}

move_path "$OLD_FLUENCY/constitution.md" "$DOCS/constitution.md"
move_path "$OLD_FLUENCY/features"        "$DOCS/features"

if $JSON_MODE; then
    files=""
    for m in ${MOVED+"${MOVED[@]}"}; do files+="${files:+, }\"$(json_escape "$m")\""; done
    printf '{"docs_dir":"%s","dry_run":%s,"moved_count":%s,"moved":[%s]}\n' \
        "$(json_escape "$DOCS")" "$DRY_RUN" "${#MOVED[@]}" "$files"
else
    if [ "${#MOVED[@]}" -eq 0 ]; then
        echo "Nothing to migrate — docs are already under $DOCS (or none exist yet)."
    else
        $DRY_RUN && echo "Would migrate (dry run):" || echo "Migrated to $DOCS:"
        for m in "${MOVED[@]}"; do echo "  $m"; done
        $DRY_RUN || echo "Review and commit the move."
    fi
fi
