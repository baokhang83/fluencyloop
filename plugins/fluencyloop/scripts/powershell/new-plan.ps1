# new-plan.ps1 — PowerShell port of new-plan.sh. Scaffold a plan.md for a large initiative on the
# current branch (a plan is a committed doc, not a branch). Matches new-plan.sh --json.

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
    [Console]::Error.WriteLine('Error: a plan needs an intent, e.g. fluencyloop plan "revamp the checkout flow"')
    exit 1
}

if (-not $slug) { $slug = FlSlugify $intent }
$planDir = FlPlanPath $slug
$plan = "$planDir/plan.md"

New-Item -ItemType Directory -Force -Path $planDir | Out-Null

$created = 'false'
if (-not (Test-Path -LiteralPath $plan)) {
    $tmpl = "$(FlFluencyDir)/templates/plan.md"
    $content = [System.IO.File]::ReadAllText($tmpl)
    $content = $content.Replace('{{INITIATIVE}}', $intent).Replace('{{DATE}}', (FlToday))
    FlWriteText $plan $content
    $created = 'true'
}

if ($jsonMode) {
    FlOut (FlEmitJson @('slug', $slug, 'intent', $intent, 'plan_dir', $planDir, 'plan', $plan, 'created', $created))
} else {
    FlOut "Plan: $intent"
    FlOut ("  file: $plan" + $(if ($created -eq 'true') { ' (stub)' } else { '' }))
}
