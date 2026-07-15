#!/usr/bin/env pwsh
# fluencyloop.ps1 — the FluencyLoop CLI dispatcher (PowerShell). The Windows-native twin of the
# bash `fluencyloop`: same verbs, resolving scripts/powershell/ the way the bash one resolves
# scripts/bash/.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SELF = $PSScriptRoot   # this script's bundled plugin directory

$VersionFile = Join-Path $SELF 'VERSION'
function ReadVersion([string]$p) { if (Test-Path -LiteralPath $p) { (Get-Content -LiteralPath $p -Raw).Trim() } else { 'unknown' } }

# Find the bundled scripts dir, the installed .fluencyloop/ copy, or the current repository's
# vendored copy after `fluencyloop init`.
if (Test-Path -LiteralPath (Join-Path $SELF 'scripts/powershell')) {
    $BIN = Join-Path $SELF 'scripts/powershell'
} elseif ((Test-Path -LiteralPath (Join-Path $SELF 'scripts/common.ps1'))) {
    $BIN = Join-Path $SELF 'scripts'
} else {
    $root = & git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and $root) { $BIN = Join-Path ($root | Select-Object -First 1) '.fluencyloop/scripts' } else { $BIN = '' }
}

$usage = @'
fluencyloop — the FluencyLoop CLI dispatcher.

Deterministic commands run directly; the interactive stages (constitution, feature, review,
backfill) are driven by the skills supplied by the installed Claude Code or Codex plugin.

Usage:
  fluencyloop init                       scaffold .fluencyloop/ state + docs/fluencyloop/
  fluencyloop plan "<intent>"            declare a plan (architecture + roadmap for a big chunk)
  fluencyloop feature "<intent>"         declare a feature (branch + design stub)
  fluencyloop session "<intent>"         open a session in the active feature
  fluencyloop decision --where .. --why ..  append a formatted decision block to the session
  fluencyloop review [--base <ref>]      assemble the PR view for the active feature
  fluencyloop check [--json]             doctor: loop state + un-journaled drift
  fluencyloop slice-context [--json]     changed hunks + metadata for the current slice
  fluencyloop calibration <init|show|edit|signal|compact>  your knowledge profile + its ledger
  fluencyloop migrate [--dry-run]        move docs from .fluencyloop/ to docs/fluencyloop/
  fluencyloop version                    print the installed version
  fluencyloop help
'@

$cmd = if ($args.Count -ge 1) { [string]$args[0] } else { 'help' }
$rest = @()
if ($args.Count -gt 1) { $rest = @($args[1..($args.Count - 1)]) }

function Run([string]$name) {
    & (Join-Path $BIN $name) @rest
    # $LASTEXITCODE is only set once a native command / `exit` has run; default to success.
    if (Test-Path Variable:LASTEXITCODE) { exit $LASTEXITCODE } else { exit 0 }
}

switch -Regex ($cmd) {
    '^init$'          { Run 'init.ps1' }
    '^plan$'          { Run 'new-plan.ps1' }
    '^feature$'       { Run 'new-feature.ps1' }
    '^session$'       { Run 'new-session.ps1' }
    '^decision$'      { Run 'add-decision.ps1' }
    '^review$'        { Run 'assemble-pr-view.ps1' }
    '^check$'         { Run 'check.ps1' }
    '^slice-context$' { Run 'slice-context.ps1' }
    '^calibration$'   { Run 'calibration.ps1' }
    '^migrate$'       { Run 'migrate.ps1' }
    '^(version|--version|-v)$' { [Console]::Out.Write((ReadVersion $VersionFile) + "`n"); exit 0 }
    '^(help|-h|--help)$' { [Console]::Out.Write($usage + "`n"); exit 0 }
    default { [Console]::Error.WriteLine("Unknown command: $cmd"); [Console]::Error.WriteLine($usage); exit 1 }
}
