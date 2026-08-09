# add-requirement.ps1 — PowerShell port of add-requirement.sh. Appends answered planning gaps
# and open questions without ever rewriting earlier JSONL records.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

$gap = ''; $answer = ''; $consequence = ''; $open = ''; $matters = ''
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        '--gap'         { $i++; $gap = [string]$args[$i] }
        '--answer'      { $i++; $answer = [string]$args[$i] }
        '--consequence' { $i++; $consequence = [string]$args[$i] }
        '--open'        { $i++; $open = [string]$args[$i] }
        '--matters'     { $i++; $matters = [string]$args[$i] }
        default         { [Console]::Error.WriteLine("Unknown option: $($args[$i])"); exit 1 }
    }
}

FlRequireFluency

$answeredRequested = [bool]($gap + $answer + $consequence)
$openRequested = [bool]($open + $matters)
if ($answeredRequested -and $openRequested) {
    [Console]::Error.WriteLine('Error: provide either an answered requirement or an open question, not both.')
    exit 1
}
if ($answeredRequested) {
    if (-not $gap) { [Console]::Error.WriteLine('Error: --gap is required for an answered requirement.'); exit 1 }
    if (-not $answer) { [Console]::Error.WriteLine('Error: --answer is required for an answered requirement.'); exit 1 }
    if (-not $consequence) { [Console]::Error.WriteLine('Error: --consequence is required for an answered requirement.'); exit 1 }
} elseif ($openRequested) {
    if (-not $open) { [Console]::Error.WriteLine('Error: --open is required for an open question.'); exit 1 }
    if (-not $matters) { [Console]::Error.WriteLine('Error: --matters is required for an open question.'); exit 1 }
} else {
    [Console]::Error.WriteLine('Error: provide --gap, --answer, and --consequence, or --open and --matters.')
    exit 1
}

# A plan may exist before any feature branch. Store those records globally; retain active feature
# context when there is one, so the schema identity can distinguish the same gap per initiative.
$feature = FlStateGet 'feature'
if (-not $feature) { $feature = FlCurrentFeatureSlug }
if ($feature) {
    $store = FlFeatureStorePath $feature
} else {
    $feature = 'global'
    $store = FlConceptsStorePath
}

if ($answeredRequested) {
    FlStoreAppendRecord $store 'requirement' $feature 'none' @(
        'gap', $gap, 'answer', $answer, 'consequence', $consequence)
    FlOut "Appended requirement to $store"
} else {
    FlStoreAppendRecord $store 'open_question' $feature 'none' @(
        'gap', $open, 'why_it_matters', $matters)
    FlOut "Appended open question to $store"
}
