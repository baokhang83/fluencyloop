#!/usr/bin/env bash
# Refresh the marketplace that supplied this plugin, then install its current FluencyLoop package.
# Codex runs this trusted SessionStart hook. A refreshed package is picked up by the next session.

set -euo pipefail

PLUGIN_DIR="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
[ -n "$PLUGIN_DIR" ] || exit 0

# Codex has used both a versioned cache root and a marketplace-snapshot root. Derive the
# marketplace instead of assuming the self-hosted catalog name: the same package can later be
# distributed through another Codex marketplace.
case "$PLUGIN_DIR" in
    */plugins/cache/*/*/*)
        CACHE_TAIL="${PLUGIN_DIR#*/plugins/cache/}"
        MARKETPLACE="${CACHE_TAIL%%/*}"
        ;;
    */marketplaces/*/plugins/*)
        MARKETPLACE_TAIL="${PLUGIN_DIR#*/marketplaces/}"
        MARKETPLACE="${MARKETPLACE_TAIL%%/plugins/*}"
        ;;
    *) exit 0 ;;
esac

[ -n "$MARKETPLACE" ] || exit 0
command -v codex >/dev/null 2>&1 || exit 0

# A local marketplace has nothing to refresh. Network and policy failures must never prevent an
# agent session from starting, so treat them as a no-op and let the host surface its own diagnostics.
codex plugin marketplace upgrade "$MARKETPLACE" --json >/dev/null 2>&1 || exit 0
codex plugin add "fluencyloop@$MARKETPLACE" --json >/dev/null 2>&1 || true
