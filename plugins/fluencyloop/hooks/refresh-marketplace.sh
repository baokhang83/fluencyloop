#!/usr/bin/env bash
# Refresh the marketplace that supplied this plugin, then install its current FluencyLoop package.
# Codex and Claude Code both run this trusted SessionStart hook. A refreshed package is picked up
# by the next session.

set -euo pipefail

# Each host exports its own plugin-root variable, and that is the only trustworthy signal for which
# host started this session. Dispatch on it rather than on which CLI happens to be installed: a
# developer with both CLIs would otherwise have a Claude session upgrade the Codex package, since
# the two installs are separate trees that must refresh independently.
if [ -n "${PLUGIN_ROOT:-}" ]; then
    HOST=codex
    PLUGIN_DIR="$PLUGIN_ROOT"
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    HOST=claude
    PLUGIN_DIR="$CLAUDE_PLUGIN_ROOT"
else
    exit 0
fi

# Give Codex a stable, readable command name without restoring a second runtime. This small
# wrapper dispatches to the plugin bundle currently loaded by the host and is refreshed each
# session. Unlike a symbolic link, it also works on hosts that restrict link creation. Never
# replace an unrelated executable a developer may already have at this name.
install_path_shim() {
    local shim_dir shim target cache_root existing temporary

    [ -n "${HOME:-}" ] || return 0
    target="$PLUGIN_DIR/fluencyloop"
    [ -x "$target" ] || return 0

    # A Codex update replaces the version directory while this hook is still running. Keep the
    # cache parent in the wrapper so a command issued before the next SessionStart can fall through
    # to the newly installed version instead of executing a path that was just pruned.
    case "$PLUGIN_DIR" in
        */plugins/cache/*/*/*) cache_root="${PLUGIN_DIR%/*}" ;;
        *) cache_root="" ;;
    esac

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
        printf 'primary=%q\n' "$target"
        printf 'cache_root=%q\n' "$cache_root"
        printf '%s\n' \
            'if [ -x "$primary" ]; then' \
            '    exec "$primary" "$@"' \
            'fi' \
            'if [ -n "$cache_root" ]; then' \
            '    replacement=""' \
            '    for candidate in "$cache_root"/*/fluencyloop; do' \
            '        [ -x "$candidate" ] || continue' \
            '        replacement="$candidate"' \
            '    done' \
            '    if [ -n "$replacement" ]; then' \
            '        exec "$replacement" "$@"' \
            '    fi' \
            'fi' \
            'printf "%s\\n" "fluencyloop: installed plugin runtime is unavailable" >&2' \
            'exit 127'
    } > "$temporary" 2>/dev/null || return 0
    chmod +x "$temporary" 2>/dev/null || {
        rm -f "$temporary"
        return 0
    }
    mv -f "$temporary" "$shim" 2>/dev/null || rm -f "$temporary"
}

# Both hosts have used a versioned cache root and a marketplace-snapshot root. Derive the
# marketplace instead of assuming the self-hosted catalog name: the same package can later be
# distributed through another marketplace.
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

# A local marketplace has nothing to refresh. Network and policy failures must never prevent an
# agent session from starting, so treat them as a no-op and let the host surface its own diagnostics.
case "$HOST" in
    codex)
        # Only Codex resolves the CLI through the PATH shim; the Claude skills address the bundled
        # binary through CLAUDE_PLUGIN_ROOT. Installing the shim from a Claude session would aim a
        # Codex-owned command at the Claude tree.
        install_path_shim
        command -v codex >/dev/null 2>&1 || exit 0
        codex plugin marketplace upgrade "$MARKETPLACE" --json >/dev/null 2>&1 || exit 0
        codex plugin add "fluencyloop@$MARKETPLACE" --json >/dev/null 2>&1 || true
        ;;
    claude)
        command -v claude >/dev/null 2>&1 || exit 0
        claude plugin marketplace update "$MARKETPLACE" >/dev/null 2>&1 || exit 0
        # Claude Code resolves an update only for a marketplace-qualified plugin name.
        claude plugin update "fluencyloop@$MARKETPLACE" >/dev/null 2>&1 || true
        ;;
esac
