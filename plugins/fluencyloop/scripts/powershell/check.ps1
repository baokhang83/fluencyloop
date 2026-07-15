# check.ps1 — PowerShell port of check.sh. Deterministic drift/state doctor. Never errors on an
# absent/empty constitution. Matches check.sh --json output.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

$jsonMode = $false
foreach ($a in $args) {
    if ($a -eq '--json') { $jsonMode = $true }
    else { [Console]::Error.WriteLine("Unknown option: $a"); exit 1 }
}

$root = FlRepoRoot

$fdir = FlFluencyDir
$fluencyStr = if ($fdir -and (Test-Path -LiteralPath $fdir -PathType Container)) { 'true' } else { 'false' }

$branch = & git rev-parse --abbrev-ref HEAD 2>$null
if ($LASTEXITCODE -ne 0 -or -not $branch) { $branch = '' } else { $branch = ($branch | Select-Object -First 1) }

$feature = FlStateGet 'feature'
if (-not $feature) { $feature = FlCurrentFeatureSlug }
$stage = FlStateGet 'stage'
$base = FlStateGet 'base_ref'; if (-not $base) { $base = 'main' }
$lastSession = FlStateGet 'last_session'

# Un-journaled drift: commits since the last commit touching the sessions dir; else since base.
$unjournaled = 0
if ($root -and $feature) {
    $sdir = "$(FlFeaturePath $feature)/sessions"
    $lastJournal = & git log -1 --format=%H -- $sdir 2>$null
    if ($LASTEXITCODE -eq 0 -and $lastJournal) {
        $lastJournal = ($lastJournal | Select-Object -First 1)
        $c = & git rev-list --count "$lastJournal..HEAD" 2>$null
        if ($LASTEXITCODE -eq 0 -and $c) { $unjournaled = [int]($c | Select-Object -First 1) }
    } else {
        & git rev-parse --verify --quiet $base *> $null
        if ($LASTEXITCODE -eq 0) {
            $c = & git rev-list --count "$base..HEAD" 2>$null
            if ($LASTEXITCODE -eq 0 -and $c) { $unjournaled = [int]($c | Select-Object -First 1) }
        }
    }
}

$calFile = FlCalibrationFile
$calStr = if (Test-Path -LiteralPath $calFile) { 'true' } else { 'false' }

# Constitution: absent / empty stub / a pointer / populated. Absent-or-empty is normal.
$const = FlConstitutionPath
$cstate = 'absent'
if ($const -and (Test-Path -LiteralPath $const)) {
    $txt = [System.IO.File]::ReadAllText($const)
    if ($txt -match 'Source of truth:') { $cstate = 'pointer' }
    elseif ($txt -match '(?i)none yet' -or $txt -notmatch '§') { $cstate = 'empty' }
    else { $cstate = 'present' }
}

if ($jsonMode) {
    $json = '{"fluency":' + $fluencyStr +
            ',"branch":"' + (FlJsonEscape $branch) + '"' +
            ',"feature":"' + (FlJsonEscape $feature) + '"' +
            ',"stage":"' + (FlJsonEscape $stage) + '"' +
            ',"base_ref":"' + (FlJsonEscape $base) + '"' +
            ',"last_session":"' + (FlJsonEscape $lastSession) + '"' +
            ',"unjournaled_commits":' + $unjournaled +
            ',"calibration":' + $calStr +
            ',"constitution":"' + $cstate + '"}'
    FlOut $json
    exit 0
}

function Mark([string]$b) { if ($b -eq 'true') { 'ok ' } else { 'XX ' } }
FlOut 'FluencyLoop check'
FlOut ("  $(Mark $fluencyStr) .fluencyloop/ present")
if ($feature) {
    $s = if ($stage) { " (stage: $stage)" } else { '' }
    FlOut "  ok  active feature: $feature$s"
} else {
    FlOut '  XX  no active feature'
}
if ($unjournaled -gt 0) {
    FlOut "  !!  $unjournaled commit(s) since the last journaled session — un-journaled drift"
} else {
    FlOut '  ok  no un-journaled drift'
}
FlOut ("  $(Mark $calStr) calibration profile ($calFile)")
switch ($cstate) {
    'present' { FlOut '  ok  constitution: populated' }
    'pointer' { FlOut '  ok  constitution: points to a source of truth' }
    default   { FlOut '  --  no constitution yet — written from your first plan or feature' }
}
