#!/usr/bin/env bash
# install.sh — install FluencyLoop onto this machine (run once, from a clone of this repo).
#
# It does three things:
#   1. copies the tool into ~/.fluencyloop/lib          (scripts, templates, skills, CLI)
#   2. symlinks the `fluencyloop` CLI onto your PATH          (~/.local/bin by default)
#   3. installs the interactive skills user-wide for the selected coding agent
#
# After this, `fluencyloop init` works in any repo, and your coding agent sees the skills
# everywhere. Per-project state still lives in each repo's .fluencyloop/ (via `fluencyloop init`).
#
# Usage: ./install.sh [--bin-dir <dir>] [--agent <claude|codex|both>] [--no-skills]

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="${FLUENCYLOOP_HOME:-$HOME/.fluencyloop}/lib"
BIN_DIR="$HOME/.local/bin"
INSTALL_SKILLS=true
SKILLS_AGENT="claude"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --bin-dir) shift; BIN_DIR="${1:?--bin-dir needs a value}" ;;
        --agent) shift; SKILLS_AGENT="${1:?--agent needs claude, codex, or both}" ;;
        --no-skills) INSTALL_SKILLS=false ;;
        -h|--help) sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

case "$SKILLS_AGENT" in claude|codex|both) ;; *)
    echo "--agent must be claude, codex, or both (got '$SKILLS_AGENT')" >&2; exit 1 ;;
esac

# 1. Copy the tool into the lib dir (idempotent: refresh in place).
mkdir -p "$LIB"
rm -rf "$LIB/scripts" "$LIB/templates" "$LIB/skills"
cp -R "$SRC/scripts" "$SRC/templates" "$SRC/skills" "$LIB/"
cp "$SRC/fluencyloop" "$LIB/fluencyloop"
cp "$SRC/VERSION" "$LIB/VERSION"
# Record where this install came from, so `fluencyloop self upgrade` knows what to pull.
printf '%s\n' "$SRC" > "$LIB/SOURCE"
chmod +x "$LIB/fluencyloop" "$LIB/scripts/bash/"*.sh

# 2. Put the CLI on the PATH.
mkdir -p "$BIN_DIR"
ln -sf "$LIB/fluencyloop" "$BIN_DIR/fluencyloop"

# 3. Install skills for the selected coding agent. Claude remains the default for backwards
# compatibility; `--agent both` is explicit for people who use both tools.
CLAUDE_SKILLS_DEST="$HOME/.claude/skills"
CODEX_SKILLS_DEST="${CODEX_HOME:-$HOME/.codex}/skills"
if $INSTALL_SKILLS; then
    install_skills() { mkdir -p "$1"; cp -R "$SRC/skills/." "$1/"; }
    case "$SKILLS_AGENT" in
        claude) SKILLS_DESTS="$CLAUDE_SKILLS_DEST"; install_skills "$CLAUDE_SKILLS_DEST" ;;
        codex)  SKILLS_DESTS="$CODEX_SKILLS_DEST"; install_skills "$CODEX_SKILLS_DEST" ;;
        both)   SKILLS_DESTS="$CLAUDE_SKILLS_DEST, $CODEX_SKILLS_DEST"; install_skills "$CLAUDE_SKILLS_DEST"; install_skills "$CODEX_SKILLS_DEST" ;;
    esac
fi

VERSION="$(cat "$SRC/VERSION" 2>/dev/null || echo unknown)"
echo "FluencyLoop $VERSION installed."
echo "  lib:     $LIB"
echo "  cli:     $BIN_DIR/fluencyloop  ->  $LIB/fluencyloop"
if $INSTALL_SKILLS; then
    echo "  skills:  $SKILLS_AGENT ($SKILLS_DESTS)"
fi
echo
if ! command -v fluencyloop >/dev/null 2>&1; then
    echo "Add the CLI to your PATH (then restart your shell):"
    echo "  echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.zshrc"
fi
echo "Next: cd into a project and run 'fluencyloop init'."
