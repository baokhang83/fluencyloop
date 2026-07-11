#!/usr/bin/env bash
# install.sh — install FluencyLoop onto this machine (run once, from a clone of this repo).
#
# It does three things:
#   1. copies the tool into ~/.fluencyloop/lib          (scripts, templates, skills, CLI)
#   2. symlinks the `fluency` CLI onto your PATH          (~/.local/bin by default)
#   3. installs the interactive skills user-wide          (~/.claude/skills)
#
# After this, `fluency init` works in any repo, and your coding agent sees the skills
# everywhere. Per-project state still lives in each repo's .fluency/ (via `fluency init`).
#
# Usage: ./install.sh [--bin-dir <dir>] [--no-skills]

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="${FLUENCYLOOP_HOME:-$HOME/.fluencyloop}/lib"
BIN_DIR="$HOME/.local/bin"
INSTALL_SKILLS=true

while [ "$#" -gt 0 ]; do
    case "$1" in
        --bin-dir) shift; BIN_DIR="${1:?--bin-dir needs a value}" ;;
        --no-skills) INSTALL_SKILLS=false ;;
        -h|--help) sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

# 1. Copy the tool into the lib dir (idempotent: refresh in place).
mkdir -p "$LIB"
rm -rf "$LIB/scripts" "$LIB/templates" "$LIB/skills"
cp -R "$SRC/scripts" "$SRC/templates" "$SRC/skills" "$LIB/"
cp "$SRC/fluency" "$LIB/fluency"
chmod +x "$LIB/fluency" "$LIB/scripts/bash/"*.sh

# 2. Put the CLI on the PATH.
mkdir -p "$BIN_DIR"
ln -sf "$LIB/fluency" "$BIN_DIR/fluency"

# 3. Install skills user-wide so the agent sees them in every project.
SKILLS_DEST="$HOME/.claude/skills"
if $INSTALL_SKILLS; then
    mkdir -p "$SKILLS_DEST"
    cp -R "$SRC/skills/." "$SKILLS_DEST/"
fi

echo "FluencyLoop installed."
echo "  lib:     $LIB"
echo "  cli:     $BIN_DIR/fluency  ->  $LIB/fluency"
$INSTALL_SKILLS && echo "  skills:  $SKILLS_DEST (user-wide)"
echo
if ! command -v fluency >/dev/null 2>&1; then
    echo "Add the CLI to your PATH (then restart your shell):"
    echo "  echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.zshrc"
fi
echo "Next: cd into a project and run 'fluency init'."
