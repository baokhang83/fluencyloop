# add-decision.ps1 — PowerShell port of add-decision.sh. Assemble a `## Decision:` block from
# field values and append it to the active session. Matches add-decision.sh formatting.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

$title = ''; $where = ''; $why = ''; $alt = ''; $design = ''; $const = ''
$trust = "⚠ not independently verified"; $session = ''
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        '--title'        { $i++; $title = [string]$args[$i] }
        '--where'        { $i++; $where = [string]$args[$i] }
        '--why'          { $i++; $why = [string]$args[$i] }
        '--alternative'  { $i++; $alt = [string]$args[$i] }
        '--design'       { $i++; $design = [string]$args[$i] }
        '--constitution' { $i++; $const = [string]$args[$i] }
        '--trust'        { $i++; $t = [string]$args[$i]
                           if ($t -eq 'verified' -or $t -like '✓*') { $trust = "✓ verified" } else { $trust = "⚠ not independently verified" } }
        '--session'      { $i++; $session = [string]$args[$i] }
        default          { [Console]::Error.WriteLine("Unknown option: $($args[$i])"); exit 1 }
    }
}

FlRequireFluency

if (-not $where) { [Console]::Error.WriteLine('Error: --where is required (a file/area, never a line number).'); exit 1 }
if (-not $why)   { [Console]::Error.WriteLine('Error: --why is required (the taught rationale).'); exit 1 }

if (-not $session) {
    $rel = FlStateGet 'last_session'
    if ($rel) { $session = "$(FlRepoRoot)/$rel" }
}
if (-not $session -or -not (Test-Path -LiteralPath $session)) {
    [Console]::Error.WriteLine("Error: no session file — open one with 'fluencyloop session `"<slice>`"' or pass --session.")
    exit 1
}

if (-not $title) { $title = 'decision' }

$block = "`n## Decision: $title`n`n"
$block += '- **where:** `' + $where + '`' + "`n"
$block += '- **why:** ' + $why + "`n"
if ($alt)    { $block += '- **alternative:** ' + $alt + "`n" }
if ($design) { $block += '- **design:** ' + $design + "`n" }
if ($const)  { $block += '- **constitution:** ' + $const + "`n" }
$block += '- **trust:** ' + $trust + "`n"

$existing = [System.IO.File]::ReadAllText($session)
FlWriteText $session ($existing + $block)

FlOut "Appended decision `"$title`" to $session"
