#!/usr/bin/env bash
# init.sh — scaffold FluencyLoop into the current repo (Stage 0, once per project).
# Creates .fluencyloop/ for machine state (scripts + templates) and docs/fluencyloop/ for the
# human-facing artifacts (constitution stub; per-feature design + sessions land here later).
# Skills are installed user-wide by install.sh, so they are NOT vendored per-project unless you ask.
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
    echo "Error: 'fluencyloop init' must be run inside a git repository." >&2
    exit 1
fi

# The distribution root is two levels up from scripts/bash.
DIST_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FLUENCY="$ROOT/.fluencyloop"          # machine state: scripts + templates
DOCS="$(docs_dir)"                    # human-facing docs: constitution, designs, sessions

mkdir -p "$FLUENCY/scripts" "$FLUENCY/templates" "$DOCS"

# Copy scripts + templates into the project so the tool is self-contained per repo.
cp "$DIST_ROOT/scripts/bash/"*.sh "$FLUENCY/scripts/"
cp "$DIST_ROOT/templates/"*.md   "$FLUENCY/templates/"

# Seed the constitution from the template if absent (never clobber an existing one).
CONSTITUTION="$(constitution_path)"
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
if ! { [ -f "$GITIGNORE" ] && grep -qxF '.fluencyloop/**/calibration.md' "$GITIGNORE"; }; then
    printf '\n# FluencyLoop: calibration is per-developer and never committed\n.fluencyloop/**/calibration.md\n' >> "$GITIGNORE"
fi

# FluencyLoop creates a branch per feature. Set push.autoSetupRemote (repo-local) so the
# first `git push` on a new feature branch sets its upstream automatically — no
# `git push --set-upstream` friction. (git >= 2.37; ignored on older versions.)
AUTO_REMOTE_SET=false
if [ "$(git -C "$ROOT" config --local push.autoSetupRemote 2>/dev/null)" != "true" ]; then
    git -C "$ROOT" config --local push.autoSetupRemote true
    AUTO_REMOTE_SET=true
fi

if $JSON_MODE; then
    emit_json \
        fluency_dir "$FLUENCY" \
        docs_dir "$DOCS" \
        constitution "$CONSTITUTION" \
        constitution_created "$CREATED_CONSTITUTION" \
        skills_vendored "$VENDOR_SKILLS" \
        skills_dir "$SKILLS_DEST" \
        push_autoremote_set "$AUTO_REMOTE_SET"
else
    echo "Initialised FluencyLoop"
    echo "  state:        $FLUENCY (scripts + templates)"
    echo "  docs:         $DOCS (constitution, designs, session journals)"
    $AUTO_REMOTE_SET && echo "  git:          push.autoSetupRemote=true (feature branches push without --set-upstream)"
    $CREATED_CONSTITUTION && echo "  constitution: $CONSTITUTION (stub — run fluencyloop-constitution to fill it)"
    if [ -n "$SKILLS_DEST" ]; then
        echo "  skills:       $SKILLS_DEST (vendored into repo)"
    else
        echo "  skills:       user-wide (~/.claude/skills); pass --vendor-skills to commit them here"
    fi
fi
