#!/usr/bin/env bash
# init.sh — scaffold FluencyLoop state into the current repo (Stage 0, once per project).
# Creates .fluency/ with a constitution stub and the features/ tree. Skills are installed
# user-wide by install.sh, so they are NOT vendored per-project unless you ask.
#
# Usage: init.sh [--json] [--vendor-skills]
#   --vendor-skills   also copy the skills into this repo's .claude/skills (commit them so
#                     contributors get them on clone — the OSS/team case)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

JSON_MODE=false
VENDOR_SKILLS=false
for arg in "$@"; do
    case "$arg" in
        --json) JSON_MODE=true ;;
        --vendor-skills) VENDOR_SKILLS=true ;;
    esac
done

ROOT="$(repo_root)"
if [ -z "$ROOT" ]; then
    echo "Error: 'fluency init' must be run inside a git repository." >&2
    exit 1
fi

# The distribution root is two levels up from scripts/bash.
DIST_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FLUENCY="$ROOT/.fluency"

mkdir -p "$FLUENCY/features" "$FLUENCY/scripts" "$FLUENCY/templates"

# Copy scripts + templates into the project so the tool is self-contained per repo.
cp "$DIST_ROOT/scripts/bash/"*.sh "$FLUENCY/scripts/"
cp "$DIST_ROOT/templates/"*.md   "$FLUENCY/templates/"

# Seed the constitution from the template if absent (never clobber an existing one).
CONSTITUTION="$FLUENCY/constitution.md"
CREATED_CONSTITUTION=false
if [ ! -f "$CONSTITUTION" ]; then
    cp "$DIST_ROOT/templates/constitution.md" "$CONSTITUTION"
    CREATED_CONSTITUTION=true
fi

# Skills are user-wide (install.sh -> ~/.claude/skills). Only vendor them into the repo when
# explicitly asked (so an OSS project can commit them for contributors).
SKILLS_DEST=""
if $VENDOR_SKILLS && [ -d "$DIST_ROOT/skills" ]; then
    SKILLS_DEST="$ROOT/.claude/skills"
    mkdir -p "$SKILLS_DEST"
    cp -R "$DIST_ROOT/skills/." "$SKILLS_DEST/"
fi

# A feature is a branch, and session journals are committed — but the per-developer
# calibration profile is global and must never be committed. Guard against a project
# accidentally vendoring one.
GITIGNORE="$ROOT/.gitignore"
if ! { [ -f "$GITIGNORE" ] && grep -qxF '.fluency/**/calibration.md' "$GITIGNORE"; }; then
    printf '\n# FluencyLoop: calibration is per-developer and never committed\n.fluency/**/calibration.md\n' >> "$GITIGNORE"
fi

if $JSON_MODE; then
    emit_json \
        fluency_dir "$FLUENCY" \
        constitution "$CONSTITUTION" \
        constitution_created "$CREATED_CONSTITUTION" \
        skills_vendored "$VENDOR_SKILLS" \
        skills_dir "$SKILLS_DEST"
else
    echo "Initialised FluencyLoop in $FLUENCY"
    $CREATED_CONSTITUTION && echo "  constitution: $CONSTITUTION (stub — run fluency-constitution to fill it)"
    if [ -n "$SKILLS_DEST" ]; then
        echo "  skills:       $SKILLS_DEST (vendored into repo)"
    else
        echo "  skills:       user-wide (~/.claude/skills); pass --vendor-skills to commit them here"
    fi
fi
