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
  fluencyloop feature "<intent>"         declare a feature (branch + store record)
  fluencyloop session "<intent>"         open a session in the active feature
  fluencyloop decision --where .. --why ..  append a formatted decision block to the session
  fluencyloop knowledge --component ..    batch session knowledge records
  fluencyloop concept --name ..           capture an architectural concept or relation
  fluencyloop requirement --gap ..        capture a planning requirement or open question
  fluencyloop principle --number §N ..    capture a constitution principle
  fluencyloop import                     import legacy session markdown into the store
  fluencyloop review [--base <ref>]      assemble the PR view for the active feature
  fluencyloop check [--json]             doctor: loop state + un-journaled drift
  fluencyloop site [--port <port>]       serve the local 0.3 site (requires Node.js 18+)
  fluencyloop slice-context [--json]     changed hunks + metadata for the current slice
  fluencyloop calibration <init|show|edit|signal|compact>  your knowledge profile + its ledger
  fluencyloop index                      regenerate docs/fluencyloop/README.md
  fluencyloop rename-feature-dir --pr <n>  swap the active feature's dir to carry its PR number
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

# Node is deliberately optional: only the forthcoming local site server may execute it. Keep the
# rest of the loop runnable on an agent host with no Node installation at all.
function RequireNodeForSite {
    $nodeCommand = Get-Command node -CommandType Application -ErrorAction SilentlyContinue
    if (-not $nodeCommand) {
        [Console]::Error.WriteLine("Node.js 18 or newer is required only for 'fluencyloop site'.")
        [Console]::Error.WriteLine('The rest of FluencyLoop works without Node.js. Install it from https://nodejs.org/ and rerun this command.')
        exit 1
    }
    $version = (& $nodeCommand.Source --version 2>$null | Select-Object -First 1)
    $nodeExitCode = if (Test-Path Variable:LASTEXITCODE) { $LASTEXITCODE } else { 0 }
    $versionMatch = [regex]::Match([string]$version, '^v?(\d+)')
    if ($nodeExitCode -ne 0 -or -not $version -or -not $versionMatch.Success) {
        [Console]::Error.WriteLine("Could not determine the installed Node.js version for 'fluencyloop site'.")
        [Console]::Error.WriteLine('Node.js 18 or newer is required only for the local site. Install or update it at https://nodejs.org/.')
        exit 1
    }
    if ([int]$versionMatch.Groups[1].Value -lt 18) {
        [Console]::Error.WriteLine("Node.js $version is too old for 'fluencyloop site'; Node.js 18 or newer is required.")
        [Console]::Error.WriteLine('The rest of FluencyLoop works without Node.js. Update it at https://nodejs.org/.')
        exit 1
    }
    return $nodeCommand.Source
}

function StartSite {
    $nodeExe = RequireNodeForSite
    $projectRoot = (& git rev-parse --show-toplevel 2>$null | Select-Object -First 1)
    $gitExitCode = if (Test-Path Variable:LASTEXITCODE) { $LASTEXITCODE } else { 0 }
    if ($gitExitCode -ne 0 -or -not $projectRoot) {
        [Console]::Error.WriteLine("Error: 'fluencyloop site' must run inside a Git repository.")
        exit 1
    }
    & $nodeExe (Join-Path $SELF 'site/server.js') '--root' $projectRoot @rest
    exit $LASTEXITCODE
}

switch -Regex ($cmd) {
    '^init$'          { Run 'init.ps1' }
    '^plan$'          { Run 'new-plan.ps1' }
    '^feature$'       { Run 'new-feature.ps1' }
    '^session$'       { Run 'new-session.ps1' }
    '^decision$'      { Run 'add-decision.ps1' }
    '^knowledge$'     { Run 'add-knowledge.ps1' }
    '^concept$'       { Run 'add-concept.ps1' }
    '^requirement$'   { Run 'add-requirement.ps1' }
    '^principle$'     { Run 'add-principle.ps1' }
    '^import$'        { Run 'import-legacy.ps1' }
    '^review$'        { Run 'assemble-pr-view.ps1' }
    '^check$'         { Run 'check.ps1' }
    '^site$'          { StartSite }
    '^slice-context$' { Run 'slice-context.ps1' }
    '^calibration$'   { Run 'calibration.ps1' }
    '^index$'         { Run 'index.ps1' }
    '^rename-feature-dir$' { Run 'rename-feature-dir.ps1' }
    '^migrate$'       { Run 'migrate.ps1' }
    '^(version|--version|-v)$' { [Console]::Out.Write((ReadVersion $VersionFile) + "`n"); exit 0 }
    '^(help|-h|--help)$' { [Console]::Out.Write($usage + "`n"); exit 0 }
    default { [Console]::Error.WriteLine("Unknown command: $cmd"); [Console]::Error.WriteLine($usage); exit 1 }
}
