#!/usr/bin/env bash
# common.sh — shared helpers for FluencyLoop scripts.
# Deterministic plumbing only: no LLM, no interactivity. Sourced by the other scripts.

set -euo pipefail

# --- repo + paths ---------------------------------------------------------

# Absolute path to the git repo root, or empty if not in a repo.
repo_root() {
    git rev-parse --show-toplevel 2>/dev/null || true
}

# Absolute path to the project's .fluency directory (state lives here).
fluency_dir() {
    local root; root="$(repo_root)"
    [ -n "$root" ] && printf '%s/.fluency' "$root"
}

# Fail unless FluencyLoop has been initialised in this repo.
require_fluency() {
    local dir; dir="$(fluency_dir)"
    if [ -z "$dir" ] || [ ! -d "$dir" ]; then
        echo "Error: FluencyLoop is not initialised here. Run 'fluency init' first." >&2
        exit 1
    fi
}

# --- text helpers ---------------------------------------------------------

# Turn a free-text intent into a filesystem/branch-safe slug.
#   "Adding Rate Limiting to the Gateway!" -> "adding-rate-limiting-to-the-gateway"
slugify() {
    printf '%s' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
        | cut -c1-60 \
        | sed -E 's/-+$//'
}

# Today, ISO date.
today() { date +%Y-%m-%d; }

# Minimal JSON string escaper (quotes, backslashes, newlines).
json_escape() {
    printf '%s' "$1" | sed -E 's/\\/\\\\/g; s/"/\\"/g' | awk 'BEGIN{ORS=""} {print (NR>1?"\\n":"") $0}'
}

# Emit a flat JSON object from alternating key value arguments.
#   emit_json k1 v1 k2 v2 ...
emit_json() {
    local out="{" first=1
    while [ "$#" -ge 2 ]; do
        [ "$first" -eq 1 ] || out+=","
        first=0
        out+="\"$1\":\"$(json_escape "$2")\""
        shift 2
    done
    out+="}"
    printf '%s\n' "$out"
}

# --- feature/branch model -------------------------------------------------
# A feature IS a branch: feature/<slug>. The feature dir mirrors the slug.

branch_for()      { printf 'feature/%s' "$1"; }         # slug -> branch name
feature_path()    { printf '%s/features/%s' "$(fluency_dir)" "$1"; }  # slug -> dir

# The active feature slug, derived from the current branch (empty if not on one).
current_feature_slug() {
    local b; b="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    case "$b" in
        feature/*) printf '%s' "${b#feature/}" ;;
        *) printf '' ;;
    esac
}
