# new-feature.ps1 — PowerShell port of new-feature.sh. Declare a feature: create the branch, the
# feature dir + design.md stub, write state.json. Matches new-feature.sh --json.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

$jsonMode = $false; $slug = ''; $rest = @()
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        '--json' { $jsonMode = $true }
        '--slug' { $i++; $slug = [string]$args[$i] }
        default  { $rest += [string]$args[$i] }
    }
}

FlRequireFluency

$intent = ($rest -join ' ').Trim()
if (-not $intent) {
    [Console]::Error.WriteLine('Error: a feature needs an intent, e.g. fluencyloop feature "adding rate limiting"')
    exit 1
}

if (-not $slug) { $slug = FlSlugify $intent }
$branch = FlBranchFor $slug
$feature = FlFeaturePath $slug

# Switch to the feature branch (create it if new). Capture the fork point as the base ref.
$createdBranch = 'false'
$baseRef = ''
& git show-ref --verify --quiet "refs/heads/$branch" 2>$null
if ($LASTEXITCODE -eq 0) {
    & git checkout $branch *> $null
} else {
    $cur = & git rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $cur) { $baseRef = 'main' } else { $baseRef = ($cur | Select-Object -First 1) }
    & git checkout -b $branch *> $null
    $createdBranch = 'true'
}
if (-not $baseRef) { $baseRef = FlStateGet 'base_ref' }
if (-not $baseRef) { $baseRef = 'main' }

New-Item -ItemType Directory -Force -Path "$feature/sessions" | Out-Null

$design = "$feature/design.md"
$createdDesign = 'false'
if (-not (Test-Path -LiteralPath $design)) {
    $tmpl = "$(FlFluencyDir)/templates/design.md"
    $content = [System.IO.File]::ReadAllText($tmpl)
    $content = $content.Replace('{{FEATURE}}', $intent).Replace('{{DATE}}', (FlToday))
    FlWriteText $design $content
    $createdDesign = 'true'
}

FlWriteState @('feature', $slug, 'branch', $branch, 'stage', 'design', 'last_session', '', 'base_ref', $baseRef, 'updated', (FlToday))
$state = FlStatePath

if ($jsonMode) {
    FlOut (FlEmitJson @(
        'slug', $slug, 'intent', $intent, 'branch', $branch, 'branch_created', $createdBranch,
        'feature_dir', $feature, 'design', $design, 'design_created', $createdDesign,
        'sessions_dir', "$feature/sessions", 'base_ref', $baseRef, 'state', $state))
} else {
    FlOut "Feature: $intent"
    FlOut ("  branch:   $branch" + $(if ($createdBranch -eq 'true') { ' (created)' } else { '' }))
    FlOut ("  design:   $design" + $(if ($createdDesign -eq 'true') { ' (stub)' } else { '' }))
    FlOut "  sessions: $feature/sessions/"
    FlOut "  state:    $state (stage: design, base: $baseRef)"
}
