# new-session.ps1 — PowerShell port of new-session.sh. Open a session in the active feature,
# record it in the store, and move state to the build stage. Matches new-session.sh --json.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

$jsonMode = $false; $featureSlug = ''; $rest = @()
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        '--json' { $jsonMode = $true }
        '--slug' { $i++; $featureSlug = [string]$args[$i] }
        { $_ -eq '-h' -or $_ -eq '--help' } {
            FlOut 'Usage: new-session.ps1 [--json] [--slug <feature-slug>] <session-intent...>'
            exit 0
        }
        default {
            # An intent never starts with a dash, so a flag-shaped token here is a typo or an
            # unsupported option, not text to fold into the intent.
            if ([string]$args[$i] -like '-*') {
                [Console]::Error.WriteLine("Unknown option: $($args[$i])")
                exit 1
            }
            $rest += [string]$args[$i]
        }
    }
}

FlRequireFluency

if (-not $featureSlug) { $featureSlug = FlCurrentFeatureSlug }
if (-not $featureSlug) {
    [Console]::Error.WriteLine('Error: no active feature. Checkout a feature/<slug> branch or pass --slug.')
    exit 1
}

$intent = ($rest -join ' ').Trim()
if (-not $intent) {
    [Console]::Error.WriteLine("Error: a session needs an intent, e.g. 'wiring the Redis store'.")
    exit 1
}

# The append-only feature store is the durable session sequence. State only identifies the active
# session and can legitimately move backwards when a branch is reset or rebased.
$sessionNumber = Get-FlNextSessionNumber $featureSlug
$sessionSlug = FlNumberedSlug $sessionNumber $intent

# write_state replaces the whole file, so carry forward every field, not just the ones this
# script cares about.
$baseRef = FlStateGet 'base_ref'; if (-not $baseRef) { $baseRef = 'main' }
FlWriteState @('feature', $featureSlug, 'branch', (FlBranchFor $featureSlug), 'stage', 'build',
    'last_session', $sessionSlug, 'base_ref', $baseRef,
    'feature_dir', (FlStateGet 'feature_dir'), 'plan', (FlStateGet 'plan'), 'updated', (FlToday))
$state = FlStatePath
$store = FlFeatureStorePath $featureSlug
FlStoreAppendRecord $store 'session' $featureSlug $sessionSlug @('slug', $sessionSlug, 'intent', $intent)

if ($jsonMode) {
    FlOut (FlEmitJson @('feature', $featureSlug, 'session_slug', $sessionSlug, 'intent', $intent,
        'store', $store, 'state', $state))
} else {
    FlOut "Session: $intent"
    FlOut "  store: $store"
    FlOut "  state: $state (stage: build)"
}
