#!/usr/bin/env bash
# init.sh — scaffold FluencyLoop into the current repo (Stage 0, once per project).
# Creates .fluencyloop/ for machine state (scripts + templates) and docs/fluencyloop/ for the
# human-facing artifacts (constitution stub; per-feature design + sessions land here later).
# Skills are activated by the coding agent's own installation mechanism; they are never copied
# into a project.
#
# Usage: init.sh [--json]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

JSON_MODE=false
while [ "$#" -gt 0 ]; do
    arg="$1"
    case "$arg" in
        --json) JSON_MODE=true ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
    shift
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

# A feature is a branch, and session journals are committed — but the per-developer
# calibration profile is global and must never be committed. Guard against a project
# accidentally vendoring one.
GITIGNORE="$ROOT/.gitignore"
if ! { [ -f "$GITIGNORE" ] && grep -qxF '.fluencyloop/**/calibration.md' "$GITIGNORE"; }; then
    printf '\n# FluencyLoop: calibration is per-developer and never committed\n.fluencyloop/**/calibration.md\n' >> "$GITIGNORE"
fi

# FluencyLoop writes its state + docs with LF. Pin those paths in .gitattributes so Git doesn't
# warn ("LF will be replaced by CRLF") or convert them on Windows checkouts (autocrlf). Scoped to
# FluencyLoop's own paths — the project's own line-ending policy is left to the project.
GITATTR="$ROOT/.gitattributes"
if ! { [ -f "$GITATTR" ] && grep -qF '.fluencyloop/** text eol=lf' "$GITATTR"; }; then
    printf '\n# FluencyLoop writes these LF; pin so Git does not warn/convert on Windows.\n.fluencyloop/** text eol=lf\ndocs/fluencyloop/** text eol=lf\n' >> "$GITATTR"
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
        push_autoremote_set "$AUTO_REMOTE_SET"
else
    echo "Initialised FluencyLoop"
    echo "  state:        $FLUENCY (scripts + templates)"
    echo "  docs:         $DOCS (constitution, designs, session journals)"
    if $AUTO_REMOTE_SET; then
        echo "  git:          push.autoSetupRemote=true (feature branches push without --set-upstream)"
    fi
    if $CREATED_CONSTITUTION; then
        echo "  constitution: $CONSTITUTION (empty — written from your first plan or feature)"
    fi
fi
