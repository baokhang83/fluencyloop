# rename-feature-dir.ps1 — PowerShell port of rename-feature-dir.sh. Swaps a feature's docs dir
# to carry its PR number once one exists. The branch name is left untouched: renaming a branch
# that may already be pushed and open as a PR is riskier than renaming a doc dir, and design.md's
# own `branch:` line (see new-feature.ps1) means nothing downstream depends on the dir name
# matching the branch name anyway. Deterministic: git mv's the dir and updates feature_dir (and,
# if needed, last_session) in state.json.
#
# Usage: rename-feature-dir.ps1 [--json] --pr <number> [--slug <feature-slug>]

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

$jsonMode = $false; $pr = ''; $slug = ''
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        '--json' { $jsonMode = $true }
        '--pr'   { $i++; $pr = [string]$args[$i] }
        '--slug' { $i++; $slug = [string]$args[$i] }
        default  { [Console]::Error.WriteLine("Error: unknown argument '$($args[$i])'"); exit 1 }
    }
}

FlRequireFluency

if (-not $slug) { $slug = FlCurrentFeatureSlug }
if (-not $slug) {
    [Console]::Error.WriteLine('Error: no active feature. Checkout a feature/<slug> branch or pass --slug.')
    exit 1
}
if (-not $pr) {
    [Console]::Error.WriteLine('Error: --pr <number> is required, e.g. rename-feature-dir.ps1 --pr 42')
    exit 1
}

$old = FlFeaturePath $slug
if (-not (Test-Path -LiteralPath $old -PathType Container)) {
    [Console]::Error.WriteLine("Error: feature '$slug' not found at $old.")
    exit 1
}

# Strip a leading numeric/ticket segment (up to and including the first '-') off the current
# dir name and rebuild it under the pr- prefix; keeps the rest of the slug recognizable.
$basename = Split-Path -Leaf $old
$suffix = $basename -replace '^[a-z0-9]+-', ''
if (-not $suffix) { $suffix = $basename }
$newSlug = FlNumberedSlug "pr-$pr" $suffix
$new = (Split-Path -Parent $old) + "/$newSlug"

$renamed = $false
if ($old -ne $new) {
    if (Test-Path -LiteralPath $new) {
        [Console]::Error.WriteLine("Error: target dir already exists: $new")
        exit 1
    }
    & git mv $old $new
    if ($LASTEXITCODE -ne 0) { exit 1 }
    $renamed = $true

    $oldRel = FlRepoRel $old
    $newRel = FlRepoRel $new
    $lastSession = FlStateGet 'last_session'
    if ($lastSession.StartsWith("$oldRel/")) {
        $lastSession = $newRel + '/' + $lastSession.Substring("$oldRel/".Length)
    }

    # FlWriteState replaces the whole file, so carry forward every field, not just the one
    # that changed.
    FlWriteState @(
        'feature', (FlStateGet 'feature'), 'branch', (FlStateGet 'branch'), 'stage', (FlStateGet 'stage'),
        'last_session', $lastSession, 'base_ref', (FlStateGet 'base_ref'), 'feature_dir', $newRel,
        'plan', (FlStateGet 'plan'), 'updated', (FlToday))

}

if ($jsonMode) {
    FlOut (FlEmitJson @('slug', $slug, 'old_dir', $old, 'new_dir', $new, 'renamed', $renamed.ToString().ToLowerInvariant()))
} else {
    if ($renamed) {
        FlOut "Renamed: $old"
        FlOut "     ->  $new"
    } else {
        FlOut "Already at target name: $new"
    }
}
