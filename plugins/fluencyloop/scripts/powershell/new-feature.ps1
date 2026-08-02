# new-feature.ps1 — PowerShell port of new-feature.sh. Declare a feature: create the branch, the
# feature dir + design.md stub, write state.json. Matches new-feature.sh --json.
#
# The feature dir name always leads with a number so `features/` sorts and scans instead of
# reading as a flat pile: pass -Prefix for a ticket id (e.g. "JIRA-1234") or a PR number
# (e.g. "pr-42"); omit it and a zero-padded sequential counter is used instead. --slug
# overrides the whole computed name outright.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

$jsonMode = $false; $slug = ''; $prefix = ''; $plan = ''; $rest = @()
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        '--json'   { $jsonMode = $true }
        '--slug'   { $i++; $slug = [string]$args[$i] }
        '--prefix' { $i++; $prefix = [string]$args[$i] }
        '--plan'   { $i++; $plan = [string]$args[$i] }
        default    { $rest += [string]$args[$i] }
    }
}

FlRequireFluency

$intent = ($rest -join ' ').Trim()
if (-not $intent) {
    [Console]::Error.WriteLine('Error: a feature needs an intent, e.g. fluencyloop feature "adding rate limiting"')
    exit 1
}

if (-not $slug) {
    # Idempotency: a bare re-run (no --slug/--prefix) with the same intent while already on
    # that feature's branch must reuse its slug rather than minting a new number each time —
    # FlNextFeatureNumber isn't a pure function of intent the way FlSlugify(intent) alone was.
    $existingSlug = FlCurrentFeatureSlug
    if ($existingSlug -and (($existingSlug -replace '^[a-z0-9]+-', '') -eq (FlSlugify $intent))) {
        $slug = $existingSlug
    }
}
if (-not $slug) {
    if ($prefix) { $slug = FlNumberedSlug $prefix $intent }
    else { $slug = FlNumberedSlug (FlNextFeatureNumber) $intent }
}
$branch = FlBranchFor $slug
$feature = FlFeaturePath $slug

# Switch to the feature branch (create it if new). Capture the fork point as the base ref.
$createdBranch = 'false'
$baseRef = ''
& git show-ref --verify --quiet "refs/heads/$branch" 2>$null
if ($LASTEXITCODE -eq 0) {
    & git checkout $branch *> $null
} else {
    & git rev-parse --verify --quiet HEAD *> $null
    if ($LASTEXITCODE -eq 0) {
        $baseRef = (& git branch --show-current | Select-Object -First 1)
        & git checkout -b $branch *> $null
    } else {
        # `git init` leaves an unborn branch. Start this feature as the first branch without
        # creating an empty commit or requiring the developer's Git identity.
        & git checkout --orphan $branch *> $null
    }
    $createdBranch = 'true'
}
if (-not $baseRef) { $baseRef = FlStateGet 'base_ref' }
if (-not $baseRef) {
    foreach ($candidate in @('main', 'master')) {
        & git show-ref --verify --quiet "refs/heads/$candidate" 2>$null
        if ($LASTEXITCODE -eq 0) { $baseRef = $candidate; break }
    }
}

New-Item -ItemType Directory -Force -Path "$feature/sessions" | Out-Null

$design = "$feature/design.md"
$createdDesign = 'false'
if (-not (Test-Path -LiteralPath $design)) {
    $tmpl = "$(FlFluencyDir)/templates/design.md"
    $content = [System.IO.File]::ReadAllText($tmpl)
    $content = $content.Replace('{{FEATURE}}', $intent).Replace('{{DATE}}', (FlToday))
    FlWriteText $design $content
    # branch: is recorded here (not just in state.json) because the dir can later be renamed
    # to carry a PR number — see rename-feature-dir.ps1 — while the branch name stays put. The
    # index needs a durable way to map a feature dir back to its branch for merge status.
    $lines = [System.Collections.Generic.List[string]]::new([string[]](Get-Content -LiteralPath $design))
    $idx = ($lines | Select-String -Pattern '^started: ').LineNumber
    if ($idx) { $lines.Insert($idx, "branch: $branch") }
    if ($plan) {
        $idx2 = ($lines | Select-String -Pattern '^branch: ').LineNumber
        if ($idx2) { $lines.Insert($idx2, "plan: $plan") }
    }
    FlWriteText $design (($lines -join "`n") + "`n")
    $createdDesign = 'true'
}

FlWriteState @('feature', $slug, 'branch', $branch, 'stage', 'design', 'last_session', '', 'base_ref', $baseRef, 'feature_dir', (FlRepoRel $feature), 'plan', $plan, 'updated', (FlToday))
$state = FlStatePath

& "$PSScriptRoot/index.ps1" *> $null

if ($jsonMode) {
    FlOut (FlEmitJson @(
        'slug', $slug, 'intent', $intent, 'branch', $branch, 'branch_created', $createdBranch,
        'feature_dir', $feature, 'design', $design, 'design_created', $createdDesign,
        'sessions_dir', "$feature/sessions", 'base_ref', $baseRef, 'plan', $plan, 'state', $state))
} else {
    FlOut "Feature: $intent"
    FlOut ("  branch:   $branch" + $(if ($createdBranch -eq 'true') { ' (created)' } else { '' }))
    FlOut ("  design:   $design" + $(if ($createdDesign -eq 'true') { ' (stub)' } else { '' }))
    FlOut "  sessions: $feature/sessions/"
    if ($plan) { FlOut "  plan:     $plan" }
    FlOut "  state:    $state (stage: design, base: $baseRef)"
}
