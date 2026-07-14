# assemble-pr-view.ps1 — PowerShell port of assemble-pr-view.sh. Gather the active feature's
# sessions + commit range. Matches assemble-pr-view.sh --json.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

$jsonMode = $false; $base = ''; $featureSlug = ''
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        '--json' { $jsonMode = $true }
        '--base' { $i++; $base = [string]$args[$i] }
        '--slug' { $i++; $featureSlug = [string]$args[$i] }
    }
}

FlRequireFluency

if (-not $featureSlug) { $featureSlug = FlCurrentFeatureSlug }
if (-not $featureSlug) {
    [Console]::Error.WriteLine('Error: no active feature branch. Checkout feature/<slug> or pass --slug.')
    exit 1
}

$feature = FlFeaturePath $featureSlug
if (-not (Test-Path -LiteralPath $feature -PathType Container)) {
    [Console]::Error.WriteLine("Error: feature '$featureSlug' not found.")
    exit 1
}

# Resolve base: explicit --base, else the recorded base_ref, else main/master.
if (-not $base) { $base = FlStateGet 'base_ref' }
if (-not $base) {
    foreach ($cand in @('main', 'master')) {
        & git show-ref --verify --quiet "refs/heads/$cand" 2>$null
        if ($LASTEXITCODE -eq 0) { $base = $cand; break }
    }
}
$range = ''; $commitCount = 0
if ($base) {
    & git rev-parse --verify --quiet $base *> $null
    if ($LASTEXITCODE -eq 0) {
        $range = "$base..HEAD"
        $c = & git rev-list --count $range 2>$null
        if ($LASTEXITCODE -eq 0 -and $c) { $commitCount = [int]($c | Select-Object -First 1) }
    }
}

$sessions = @()
if (Test-Path -LiteralPath "$feature/sessions") {
    $sessions = @(Get-ChildItem -LiteralPath "$feature/sessions" -Filter '*.md' -File -ErrorAction SilentlyContinue |
        Sort-Object Name | ForEach-Object { "$feature/sessions/$($_.Name)" })
}

if ($jsonMode) {
    $files = ($sessions | ForEach-Object { '"' + (FlJsonEscape $_) + '"' }) -join ', '
    $json = '{"feature":"' + (FlJsonEscape $featureSlug) + '","feature_dir":"' + (FlJsonEscape $feature) +
            '","base":"' + (FlJsonEscape $base) + '","range":"' + (FlJsonEscape $range) +
            '","commits":' + $commitCount + ',"session_count":' + $sessions.Count + ',"sessions":[' + $files + ']}'
    FlOut $json
    exit 0
}

# Human/markdown form.
$title = ''
$dpath = "$feature/design.md"
if (Test-Path -LiteralPath $dpath) {
    foreach ($l in [System.IO.File]::ReadAllLines($dpath)) {
        if ($l -match '^# Design: ') { $title = $l -replace '^# Design: ', ''; break }
    }
}
if (-not $title) { $title = $featureSlug }

FlOut "# PR view — $title"
FlOut ''
if ($range) {
    FlOut ("_$commitCount commit(s) over ``$range``; feature branch ``$(FlBranchFor $featureSlug)``._")
    FlOut ''
}
if ($sessions.Count -eq 0) {
    FlOut '_No sessions journaled yet for this feature._'
} else {
    foreach ($s in $sessions) {
        FlOut '---'
        FlOut ''
        [Console]::Out.Write([System.IO.File]::ReadAllText($s))
        FlOut ''
    }
}
