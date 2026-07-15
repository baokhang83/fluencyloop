# new-session.ps1 — PowerShell port of new-session.sh. Open a session in the active feature and
# move state to the build stage. Matches new-session.sh --json.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

$jsonMode = $false; $featureSlug = ''; $rest = @()
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        '--json' { $jsonMode = $true }
        '--slug' { $i++; $featureSlug = [string]$args[$i] }
        default  { $rest += [string]$args[$i] }
    }
}

FlRequireFluency

if (-not $featureSlug) { $featureSlug = FlCurrentFeatureSlug }
if (-not $featureSlug) {
    [Console]::Error.WriteLine('Error: no active feature. Checkout a feature/<slug> branch or pass --slug.')
    exit 1
}

$feature = FlFeaturePath $featureSlug
if (-not (Test-Path -LiteralPath $feature -PathType Container)) {
    [Console]::Error.WriteLine("Error: feature '$featureSlug' not found at $feature. Run 'fluencyloop feature' first.")
    exit 1
}

$intent = ($rest -join ' ').Trim()
if (-not $intent) {
    [Console]::Error.WriteLine("Error: a session needs an intent, e.g. 'wiring the Redis store'.")
    exit 1
}

$sessionSlug = FlSlugify $intent
$session = "$feature/sessions/$sessionSlug.md"

$created = 'false'
if (-not (Test-Path -LiteralPath $session)) {
    $tmpl = "$(FlFluencyDir)/templates/session.md"
    $content = [System.IO.File]::ReadAllText($tmpl)
    $content = $content.Replace('{{SESSION}}', $intent).Replace('{{INTENT}}', $intent).Replace('{{DATE}}', (FlToday))
    FlWriteText $session $content
    $created = 'true'
}

$baseRef = FlStateGet 'base_ref'; if (-not $baseRef) { $baseRef = 'main' }
FlWriteState @('feature', $featureSlug, 'branch', (FlBranchFor $featureSlug), 'stage', 'build',
    'last_session', (FlRepoRel $session), 'base_ref', $baseRef, 'updated', (FlToday))
$state = FlStatePath

if ($jsonMode) {
    FlOut (FlEmitJson @('feature', $featureSlug, 'session_slug', $sessionSlug, 'intent', $intent,
        'session', $session, 'created', $created, 'state', $state))
} else {
    FlOut "Session: $intent"
    FlOut ("  file:  $session" + $(if ($created -eq 'true') { ' (created)' } else { '' }))
    FlOut "  state: $state (stage: build)"
}
