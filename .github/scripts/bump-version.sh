#!/usr/bin/env bash
# bump-version.sh — plugins/fluencyloop/VERSION is the single source of truth for the plugin
# version; the JSON manifests are generated from it. They used to be bumped by hand, and drift
# between them breaks the SessionStart update hook, which resolves the plugin by its
# marketplace-qualified name — so the CI guard below matters more than the convenience.
#
# Usage:
#   bump-version.sh <version>   set VERSION and propagate it to every manifest
#   bump-version.sh --check     verify every manifest matches VERSION; exit 1 on drift

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION_FILE="$REPO_ROOT/plugins/fluencyloop/VERSION"
MANIFESTS=(
    ".claude-plugin/plugin.json"
    ".claude-plugin/marketplace.json"
    "plugins/fluencyloop/.codex-plugin/plugin.json"
)

manifest_version() {
    sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1" | head -n1
}

[ "$#" -eq 1 ] || { echo "Usage: bump-version.sh <version> | --check" >&2; exit 2; }

if [ "$1" = "--check" ]; then
    WANT="$(cat "$VERSION_FILE")"
    RC=0
    for m in "${MANIFESTS[@]}"; do
        got="$(manifest_version "$REPO_ROOT/$m")"
        if [ "$got" != "$WANT" ]; then
            echo "::error file=$m::version is '$got' but VERSION is '$WANT' — run .github/scripts/bump-version.sh $WANT" >&2
            RC=1
        fi
    done
    if [ "$RC" -eq 0 ]; then
        echo "version $WANT is consistent across ${#MANIFESTS[@]} manifests"
    fi
    exit "$RC"
fi

NEW="$1"
# A sanity guard against a typo landing in the manifests, not a full semver parser.
case "$NEW" in
    [0-9]*.[0-9]*.[0-9]*) ;;
    *) echo "Error: '$NEW' is not a MAJOR.MINOR.PATCH version." >&2; exit 2 ;;
esac

# No trailing newline: matches how VERSION is already written, so a bump diffs as one line.
printf '%s' "$NEW" > "$VERSION_FILE"

for m in "${MANIFESTS[@]}"; do
    f="$REPO_ROOT/$m"
    # Not `sed -i`: BSD and GNU disagree on its argument, and releases get cut from both.
    tmp="$f.tmp.$$"
    sed 's/"version"\([[:space:]]*\):\([[:space:]]*\)"[^"]*"/"version"\1:\2"'"$NEW"'"/' "$f" > "$tmp"
    mv "$tmp" "$f"
done

echo "version $NEW written to VERSION and ${#MANIFESTS[@]} manifests"
