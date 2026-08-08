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

$store = FlFeatureStorePath $featureSlug

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

if ($jsonMode) {
    # The model/site reads the store; this script intentionally does not parse JSONL.
    $json = '{"feature":"' + (FlJsonEscape $featureSlug) + '","store":"' + (FlJsonEscape $store) +
            '","base":"' + (FlJsonEscape $base) + '","range":"' + (FlJsonEscape $range) +
            '","commits":' + $commitCount + ',"session_count":0,"sessions":[]}'
    FlOut $json
    exit 0
}

FlOut "# PR view — $featureSlug"
FlOut ''
if ($range) {
    FlOut ("_$commitCount commit(s) over ``$range``; feature branch ``$(FlBranchFor $featureSlug)``._")
    FlOut ''
}
FlOut "_Session and decision records: ``$store``._"
