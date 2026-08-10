# new-feature.ps1 — PowerShell port of new-feature.sh. Declare a feature: create the branch,
# write state.json, and append the feature declaration to the store. Matches new-feature.sh --json.
#
# The feature dir name always leads with a number so `features/` sorts and scans instead of
# reading as a flat pile: pass -Prefix for a ticket id (e.g. "JIRA-1234") or a PR number
# (e.g. "pr-42"); omit it and a zero-padded sequential counter is used instead. --slug
# overrides the whole computed name outright.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

$jsonMode = $false; $slug = ''; $prefix = ''; $plan = ''; $requestedBase = ''; $rest = @()
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        '--json'   { $jsonMode = $true }
        '--slug'   { $i++; $slug = [string]$args[$i] }
        '--prefix' { $i++; $prefix = [string]$args[$i] }
        '--plan'   { $i++; $plan = [string]$args[$i] }
        '--base'   { $i++; $requestedBase = [string]$args[$i] }
        { $_ -eq '-h' -or $_ -eq '--help' } {
            FlOut 'Usage: new-feature.ps1 [--json] [--slug <slug>] [--prefix <ticket-or-pr-id>] [--plan <plan-slug>] [--base <ref>] <intent...>'
            exit 0
        }
        default {
            # An intent never starts with a dash, so a flag-shaped token here is a typo or an
            # unsupported option, not text to fold into the intent -- e.g. --help reaching this
            # point unhandled used to become the intent itself, minting a real "help" feature.
            if ([string]$args[$i] -like '-*') {
                [Console]::Error.WriteLine("Unknown option: $($args[$i])")
                exit 1
            }
            $rest += [string]$args[$i]
        }
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
    # Compare against both the prefix-stripped slug (numbered features) and the whole slug
    # (features declared before per-feature numbering existed, which carry no prefix at all —
    # stripping "^[a-z0-9]+-" from one of those mangles the first word instead of a real
    # prefix, so it would never match and would fork a duplicate numbered branch/dir here).
    $existingSlug = FlCurrentFeatureSlug
    if ($existingSlug) {
        $wantSlug = FlSlugify $intent
        $strippedSlug = $existingSlug -replace '^[a-z0-9]+-', ''
        if ($strippedSlug -eq $wantSlug -or $existingSlug -eq $wantSlug) {
            $slug = $existingSlug
        }
    }
}
if (-not $slug) {
    if ($prefix) { $slug = FlNumberedSlug $prefix $intent }
    else { $slug = FlNumberedSlug (FlNextFeatureNumber) $intent }
}
$branch = FlBranchFor $slug

# Switch to the feature branch. A new feature started while another feature is active must not
# silently become a stacked branch: reuse that active feature's recorded integration base. An
# explicit --base is the opt-in escape hatch for intentionally stacked work.
$createdBranch = 'false'
$baseRef = ''
& git show-ref --verify --quiet "refs/heads/$branch" 2>$null
if ($LASTEXITCODE -eq 0) {
    & git checkout $branch *> $null
} else {
    & git rev-parse --verify --quiet HEAD *> $null
    if ($LASTEXITCODE -eq 0) {
        $currentBranch = (& git branch --show-current | Select-Object -First 1)
        $baseRef = $requestedBase
        $stateBranch = FlStateGet 'branch'
        if (-not $baseRef -and $currentBranch -like 'feature/*' -and $stateBranch -eq $currentBranch) {
            $baseRef = FlStateGet 'base_ref'
        }
        if (-not $baseRef) { $baseRef = $currentBranch }
        & git rev-parse --verify --quiet $baseRef *> $null
        if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine("Error: feature base ref does not exist: $baseRef"); exit 1 }
        & git checkout -b $branch $baseRef *> $null
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

FlWriteState @('feature', $slug, 'branch', $branch, 'stage', 'design', 'last_session', '', 'base_ref', $baseRef, 'feature_dir', '', 'plan', $plan, 'updated', (FlToday))
$state = FlStatePath
$store = FlFeatureStorePath $slug
FlStoreAppendRecord $store 'feature' $slug 'none' @('slug', $slug, 'intent', $intent, 'branch', $branch, 'base_ref', $baseRef)

if ($jsonMode) {
    FlOut (FlEmitJson @(
        'slug', $slug, 'intent', $intent, 'branch', $branch, 'branch_created', $createdBranch,
        'store', $store, 'base_ref', $baseRef, 'plan', $plan, 'state', $state))
} else {
    FlOut "Feature: $intent"
    FlOut ("  branch:   $branch" + $(if ($createdBranch -eq 'true') { ' (created)' } else { '' }))
    FlOut "  store:    $store"
    if ($plan) { FlOut "  plan:     $plan" }
    FlOut "  state:    $state (stage: design, base: $baseRef)"
}
