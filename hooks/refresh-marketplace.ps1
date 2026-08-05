# Root-level entry point for Claude Code. The marketplace entry for this plugin declares
# `"source": "."`, so CLAUDE_PLUGIN_ROOT resolves to the repo root and Claude Code only ever
# discovers hooks/refresh-marketplace.ps1 here - never under plugins/fluencyloop/, which is the
# Codex bundle's own plugin root. Delegate to that bundle's implementation so there is exactly
# one copy of the refresh logic to maintain; this file's only job is to exist at the path
# Claude Code looks for.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$canonical = Join-Path $PSScriptRoot '..\plugins\fluencyloop\hooks\refresh-marketplace.ps1'
if (Test-Path -LiteralPath $canonical -PathType Leaf) {
    & $canonical
}
exit 0
