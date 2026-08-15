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
        { $_ -eq '-h' -or $_ -eq '--help' } {
            FlOut 'Usage: new-plan.ps1 [--json] [--slug <slug>] <intent...>'
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
