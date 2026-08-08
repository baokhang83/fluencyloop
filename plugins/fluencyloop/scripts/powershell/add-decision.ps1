# add-decision.ps1 — PowerShell port of add-decision.sh. Append one decision record to the active
# feature store. Matches add-decision.sh's CLI surface.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

$title = ''; $where = ''; $why = ''; $alt = ''; $design = ''; $const = ''
$trust = 'unverified'; $session = ''
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        '--title'        { $i++; $title = [string]$args[$i] }
        '--where'        { $i++; $where = [string]$args[$i] }
        '--why'          { $i++; $why = [string]$args[$i] }
        '--alternative'  { $i++; $alt = [string]$args[$i] }
        '--design'       { $i++; $design = [string]$args[$i] }
        '--constitution' { $i++; $const = [string]$args[$i] }
        '--trust'        { $i++; $t = [string]$args[$i]
                           if ($t -eq 'verified' -or $t -like '✓*') { $trust = 'verified' } else { $trust = 'unverified' } }
        '--session'      { $i++; $session = [string]$args[$i] }
        default          { [Console]::Error.WriteLine("Unknown option: $($args[$i])"); exit 1 }
    }
}

FlRequireFluency

if (-not $where) { [Console]::Error.WriteLine('Error: --where is required (a file/area, never a line number).'); exit 1 }
if (-not $why)   { [Console]::Error.WriteLine('Error: --why is required (the taught rationale).'); exit 1 }

if (-not $session) { $session = FlStateGet 'last_session' }
$session = [System.IO.Path]::GetFileNameWithoutExtension($session)
if (-not $session) {
    [Console]::Error.WriteLine("Error: no active session — open one with 'fluencyloop session `"<slice>`"' or pass --session.")
    exit 1
}

if (-not $title) { $title = 'decision' }
$feature = FlStateGet 'feature'
if (-not $feature) { $feature = FlCurrentFeatureSlug }
if (-not $feature) {
    [Console]::Error.WriteLine('Error: no active feature. Checkout a feature/<slug> branch first.')
    exit 1
}
$store = FlFeatureStorePath $feature
FlStoreAppendRecord $store 'decision' $feature $session @(
    'title', $title, 'where', $where, 'why', $why, 'alternative', $alt,
    'design', $design, 'constitution', $const, 'trust', $trust)

FlOut "Appended decision `"$title`" to $store"
