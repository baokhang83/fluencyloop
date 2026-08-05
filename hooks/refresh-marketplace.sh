#!/usr/bin/env bash
# Root-level entry point for Claude Code. The marketplace entry for this plugin declares
# `"source": "."`, so CLAUDE_PLUGIN_ROOT resolves to the repo root and Claude Code only ever
# discovers hooks/hooks.json here — never under plugins/fluencyloop/, which is the Codex bundle's
# own plugin root. Delegate to that bundle's implementation so there is exactly one copy of the
# refresh logic to maintain; this file's only job is to exist at the path Claude Code looks for.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
canonical="$here/../plugins/fluencyloop/hooks/refresh-marketplace.sh"

if [ -f "$canonical" ]; then
    exec bash "$canonical" "$@"
fi
exit 0
