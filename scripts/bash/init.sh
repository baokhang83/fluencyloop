#!/usr/bin/env bash
# init.sh — scaffold FluencyLoop state into the current repo (Stage 0, once per project).
# Creates .fluency/ with a constitution stub and the features/ tree, and installs the
# skills into .claude/skills so the interactive commands are available in this repo.
#
# Usage: init.sh [--json]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

JSON_MODE=false
[ "${1:-}" = "--json" ] && JSON_MODE=true

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

# Install the interactive skills into this repo's .claude/skills.
SKILLS_DEST="$ROOT/.claude/skills"
mkdir -p "$SKILLS_DEST"
if [ -d "$DIST_ROOT/skills" ]; then
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
        skills_dir "$SKILLS_DEST"
else
    echo "Initialised FluencyLoop in $FLUENCY"
    $CREATED_CONSTITUTION && echo "  constitution: $CONSTITUTION (stub — run fluency-constitution to fill it)"
    echo "  skills:       $SKILLS_DEST"
fi
