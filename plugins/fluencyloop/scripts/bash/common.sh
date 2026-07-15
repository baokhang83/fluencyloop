#!/usr/bin/env bash
# common.sh — shared helpers for FluencyLoop scripts.
# Deterministic plumbing only: no LLM, no interactivity. Sourced by the other scripts.

set -euo pipefail

# --- repo + paths ---------------------------------------------------------

# Absolute path to the git repo root, or empty if not in a repo.
repo_root() {
    git rev-parse --show-toplevel 2>/dev/null || true
}

# Absolute path to the project's .fluencyloop directory. MACHINE STATE ONLY lives here:
# the vendored scripts/ and templates/ plumbing. Human-facing artifacts live under docs_dir.
fluency_dir() {
    local root; root="$(repo_root)"
    [ -n "$root" ] && printf '%s/.fluencyloop' "$root"
}

# Absolute path to the project's human-facing FluencyLoop docs. The constitution, per-feature
# design.md, and session journals live here — visible and committed, namespaced under docs/ so
# they don't collide with a project's own documentation.
docs_dir() {
    local root; root="$(repo_root)"
    [ -n "$root" ] && printf '%s/docs/fluencyloop' "$root"
}

# The project constitution (a human doc). Lives under docs_dir now, with the same back-compat
# fallback as feature_path: if only the pre-refactor copy (.fluencyloop/constitution.md) exists,
# resolve to it so init won't orphan it and readers find it until `fluencyloop migrate` runs.
constitution_path() {
    local new old
    new="$(docs_dir)/constitution.md"
    old="$(fluency_dir)/constitution.md"
    if [ ! -f "$new" ] && [ -f "$old" ]; then
        printf '%s' "$old"
    else
        printf '%s' "$new"
    fi
}

# Fail unless FluencyLoop has been initialised in this repo.
require_fluency() {
    local dir; dir="$(fluency_dir)"
    if [ -z "$dir" ] || [ ! -d "$dir" ]; then
        echo "Error: FluencyLoop is not initialised here. Run 'fluencyloop init' first." >&2
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

# slug -> feature dir. Lives under docs_dir now. Back-compat: if a feature still sits at the
# pre-refactor location (.fluencyloop/features/<slug>) and hasn't been migrated, resolve to
# that so existing repos keep working until they run `fluencyloop migrate`.
feature_path() {
    local slug="$1" new old
    new="$(docs_dir)/features/$slug"
    old="$(fluency_dir)/features/$slug"
    if [ ! -d "$new" ] && [ -d "$old" ]; then
        printf '%s' "$old"
    else
        printf '%s' "$new"
    fi
}

# slug -> plan dir. A plan is an initiative that spawns several features; it is a committed
# doc (no dedicated branch), and lives under docs_dir alongside features.
plan_path() { printf '%s/plans/%s' "$(docs_dir)" "$1"; }

# The active feature slug, derived from the current branch (empty if not on one).
current_feature_slug() {
    local b; b="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    case "$b" in
        feature/*) printf '%s' "${b#feature/}" ;;
        *) printf '' ;;
    esac
}

# --- loop state -----------------------------------------------------------
# One source of truth for the active feature's loop state, so a skill reads it instead of
# re-deriving from git every turn. Machine state, so it lives in .fluencyloop/; committed with
# the feature branch (part of the journal record). Written by new-feature.sh / new-session.sh.

state_path() { local d; d="$(fluency_dir)"; [ -n "$d" ] && printf '%s/state.json' "$d"; }

# A repo-relative path (state stores paths relative to the repo root, so they survive a move).
repo_rel() { local root; root="$(repo_root)"; printf '%s' "${1#"$root"/}"; }

# Read one string field from state.json (empty if the file or key is absent). Safe because we
# control the format write_state emits (one "key": "value" per line, values never contain ").
state_get() {
    local f; f="$(state_path)"
    [ -f "$f" ] || return 0
    sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$f" | head -n1
}

# Write state.json from alternating key value arguments (all string-valued), creating it.
#   write_state feature "$SLUG" branch "$BRANCH" stage design ...
write_state() {
    local f; f="$(state_path)"
    [ -n "$f" ] || return 0
    mkdir -p "$(dirname "$f")"
    local out="{" first=1 k v
    while [ "$#" -ge 2 ]; do
        k="$1"; v="$2"; shift 2
        [ "$first" -eq 1 ] || out+=","
        first=0
        out+=$'\n  '"\"$k\": \"$(json_escape "$v")\""
    done
    out+=$'\n}'
    printf '%s\n' "$out" > "$f"
}

# --- calibration ----------------------------------------------------------
# The per-developer knowledge profile: global, never committed. Lives under FLUENCYLOOP_HOME
# (default ~/.fluencyloop), NOT in the repo — it is the only place person-specific knowledge lives.
calibration_file() { printf '%s/calibration.md' "${FLUENCYLOOP_HOME:-$HOME/.fluencyloop}"; }

# Append-only ledger of engagement signals (wave/deeper/correct per dimension). Global, never
# committed. `calibration compact` rolls it into level changes in the profile above.
signals_file() { printf '%s/signals.log' "${FLUENCYLOOP_HOME:-$HOME/.fluencyloop}"; }
