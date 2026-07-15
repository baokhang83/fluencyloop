#!/usr/bin/env bash
# Refresh the marketplace that supplied this plugin, then install its current FluencyLoop package.
# Codex runs this trusted SessionStart hook. A refreshed package is picked up by the next session.

set -euo pipefail

PLUGIN_DIR="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
[ -n "$PLUGIN_DIR" ] || exit 0

# Give Codex a stable, readable command name without restoring a second runtime. This small
# wrapper dispatches to the plugin bundle currently loaded by the host and is refreshed each
# session. Unlike a symbolic link, it also works on hosts that restrict link creation. Never
# replace an unrelated executable a developer may already have at this name.
install_path_shim() {
    local shim_dir shim target existing temporary

    [ -n "${HOME:-}" ] || return 0
    target="$PLUGIN_DIR/fluencyloop"
    [ -x "$target" ] || return 0

    shim_dir="$HOME/.local/bin"
    shim="$shim_dir/fluencyloop"
    if [ -e "$shim" ] || [ -L "$shim" ]; then
        if [ -L "$shim" ]; then
            existing="$(readlink "$shim" 2>/dev/null || true)"
            case "$existing" in
                "$HOME"/.codex/plugins/cache/*/fluencyloop/*/fluencyloop|\
                "$HOME"/.codex/.tmp/marketplaces/*/plugins/fluencyloop/fluencyloop|\
                "$HOME"/.fluencyloop/lib/fluencyloop)
                    ;;
                *) return 0 ;;
            esac
        elif ! grep -Fqx '# FluencyLoop managed PATH shim' "$shim" 2>/dev/null; then
            return 0
        fi
    fi

    mkdir -p "$shim_dir" 2>/dev/null || return 0
    temporary="$shim_dir/.fluencyloop-shim.$$"
    {
        printf '%s\n' '#!/usr/bin/env bash' '# FluencyLoop managed PATH shim'
        printf 'exec %q "$@"\n' "$target"
    } > "$temporary" 2>/dev/null || return 0
    chmod +x "$temporary" 2>/dev/null || {
        rm -f "$temporary"
        return 0
    }
    mv -f "$temporary" "$shim" 2>/dev/null || rm -f "$temporary"
}

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
install_path_shim
command -v codex >/dev/null 2>&1 || exit 0

# A local marketplace has nothing to refresh. Network and policy failures must never prevent an
# agent session from starting, so treat them as a no-op and let the host surface its own diagnostics.
codex plugin marketplace upgrade "$MARKETPLACE" --json >/dev/null 2>&1 || exit 0
codex plugin add "fluencyloop@$MARKETPLACE" --json >/dev/null 2>&1 || true
