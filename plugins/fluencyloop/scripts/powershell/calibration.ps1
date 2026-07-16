# calibration.ps1 — PowerShell port of calibration.sh. The per-developer profile + engagement
# ledger. Matches calibration.sh: init/show[--json]/edit/signal/compact, the deterministic
# profile parse, and the promote/demote rollup.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

$CAL = FlCalibrationFile
$SIG = FlSignalsFile
$ORDER = @('new', 'learning', 'familiar', 'fluent')   # low -> high; promote +1, demote -1
$THRESHOLD = 2

function Seed {
    $lines = @(
        '# FluencyLoop calibration'
        ''
        '<!--'
        'Your per-developer knowledge profile. Global, never committed. The loop reads it to set how deep'
        'to teach. Structured for deterministic parsing: under `## Profile`, one `dimension: level` line'
        'per domain; level is one of fluent | familiar | learning | new. Anything after the level (a'
        'free-text note and a · date) is optional and ignored by the parser. Levels adapt over time:'
        '`fluencyloop calibration compact` rolls demonstrated-engagement signals into promotions/demotions.'
        '-->'
        ''
        '## Levels'
        ''
        "- **fluent**   — reasons about it unaided; teach terse, flag only what's checkable."
        "- **familiar** — knows the shape; confirm, don't re-derive."
        '- **learning** — actively building it; teach the why and check understanding.'
        '- **new**      — first contact; teach from fundamentals.'
        ''
        '## Profile'
        ''
        '<!-- one `dimension: level` per line, e.g.'
        'java: fluent'
        'reactive: learning — Mono/Flux backpressure · 2026-01-01'
        'k8s: new'
        '-->'
    )
    FlWriteText $CAL (($lines -join "`n") + "`n")
}

# Emit dimension/level pairs from `## Profile`: skip HTML-comment blocks, other headings, and any
# line that isn't `<dimension>: <level>`. Returns an array of [pscustomobject]@{Dim;Lvl}.
function ProfilePairs {
    $out = @()
    if (-not (Test-Path -LiteralPath $CAL)) { return $out }
    $incomment = $false; $p = $false
    foreach ($line in [System.IO.File]::ReadAllLines($CAL)) {
        if ($incomment) { if ($line -match '-->') { $incomment = $false }; continue }
        if ($line -match '<!--') { if ($line -notmatch '-->') { $incomment = $true }; continue }
        if ($line -match '^## Profile') { $p = $true; continue }
        if ($line -match '^## ') { $p = $false }
        if ($p -and ($line -cmatch '^[A-Za-z0-9][A-Za-z0-9._+-]*:[ \t]*(fluent|familiar|learning|new)([ \t]|$)')) {
            $dim = ($line -replace ':.*', '') -replace '\s', ''
            $lvl = $line -creplace '^[^:]*:[ \t]*', '' -creplace '[ \t].*', ''
            $out += [pscustomobject]@{ Dim = $dim; Lvl = $lvl }
        }
    }
    return $out
}

function LevelsJson {
    $parts = @()
    foreach ($pair in ProfilePairs) { $parts += '"' + $pair.Dim + '":"' + $pair.Lvl + '"' }
    return '{' + ($parts -join ',') + '}'
}

function CurrentLevel([string]$dim) {
    foreach ($pair in ProfilePairs) { if ($pair.Dim -ceq $dim) { return $pair.Lvl } }
    return ''
}

function ShiftLevel([string]$cur, [string]$dir) {
    $idx = 0
    for ($i = 0; $i -lt 4; $i++) { if ($ORDER[$i] -eq $cur) { $idx = $i } }
    if ($dir -eq 'up') { $idx++; if ($idx -gt 3) { $idx = 3 } } else { $idx--; if ($idx -lt 0) { $idx = 0 } }
    return $ORDER[$idx]
}

# Set dimension's level under `## Profile`, preserving any trailing note; append if not present.
function ApplyLevel([string]$dim, [string]$newlvl) {
    $result = @(); $done = $false; $incomment = $false; $p = $false
    foreach ($line in [System.IO.File]::ReadAllLines($CAL)) {
        if ($incomment) { if ($line -match '-->') { $incomment = $false }; $result += $line; continue }
        if ($line -match '<!--') { if ($line -notmatch '-->') { $incomment = $true }; $result += $line; continue }
        if ($line -match '^## Profile') { $p = $true; $result += $line; continue }
        if ($line -match '^## ') { if ($p -and -not $done) { $result += "$dim`: $newlvl"; $done = $true }; $p = $false; $result += $line; continue }
        if ($p -and -not $done) {
            $d = ($line -replace ':.*', '') -replace '\s', ''
            if (($d -ceq $dim) -and ($line -cmatch ':[ \t]*(fluent|familiar|learning|new)([ \t]|$)')) {
                $rest = $line -creplace '^[^:]*:[ \t]*[A-Za-z]+', ''
                $result += "$dim`: $newlvl$rest"; $done = $true; continue
            }
        }
        $result += $line
    }
    if (-not $done) { $result += "$dim`: $newlvl" }
    FlWriteText $CAL (($result -join "`n") + "`n")
}

function ResetSignals {
    FlWriteText $SIG "# FluencyLoop calibration signals — append-only; rolled into levels by: fluencyloop calibration compact`n"
}

$sub = if ($args.Count -ge 1) { [string]$args[0] } else { 'show' }
# Direct assignment (not an if-expression) so an empty/single slice stays an array under StrictMode.
$rest = @()
if ($args.Count -gt 1) { $rest = @($args[1..($args.Count - 1)]) }

switch ($sub) {
    'init' {
        if (Test-Path -LiteralPath $CAL) { FlOut "Calibration profile already exists: $CAL" }
        else { Seed; FlOut "Created calibration profile: $CAL" }
    }
    'show' {
        if ($rest.Count -ge 1 -and $rest[0] -eq '--json') { FlOut (LevelsJson) }
        elseif (Test-Path -LiteralPath $CAL) { [Console]::Out.Write([System.IO.File]::ReadAllText($CAL)) }
        else { [Console]::Error.WriteLine("No calibration profile yet — run 'fluencyloop calibration init'."); exit 1 }
    }
    'edit' {
        if (-not (Test-Path -LiteralPath $CAL)) { Seed }
        $ed = if ($env:EDITOR) { $env:EDITOR } else { 'vi' }
        & $ed $CAL
    }
    'signal' {
        # Accept one OR MANY <dimension> <type> pairs in a single call, so a slice's signals are
        # one command (one approval prompt), not N.
        if ($rest.Count -lt 2 -or ($rest.Count % 2) -ne 0) {
            [Console]::Error.WriteLine('Usage: fluencyloop calibration signal <dimension> <wave|deeper|correct> [<dim> <type> ...]'); exit 1
        }
        for ($i = 1; $i -lt $rest.Count; $i += 2) {
            if ($rest[$i] -ne 'wave' -and $rest[$i] -ne 'deeper' -and $rest[$i] -ne 'correct') {
                $signal = $rest[$i]
                if ($signal -in @('fluent', 'familiar', 'learning', 'new')) {
                    [Console]::Error.WriteLine("signal type must be wave|deeper|correct; '$signal' is a calibration level, not a signal"); exit 1
                }
                [Console]::Error.WriteLine("signal type must be wave|deeper|correct (got '$signal')"); exit 1
            }
        }
        if (-not (Test-Path -LiteralPath $SIG)) { ResetSignals }
        $todayStr = FlToday
        $lines = ''
        for ($i = 0; $i + 1 -lt $rest.Count; $i += 2) { $lines += "$todayStr $($rest[$i]) $($rest[$i + 1])`n" }
        [System.IO.File]::AppendAllText($SIG, $lines, (New-Object System.Text.UTF8Encoding($false)))
    }
    'compact' {
        $dry = ($rest.Count -ge 1 -and $rest[0] -eq '--dry-run')
        if (-not (Test-Path -LiteralPath $SIG)) { FlOut 'No signals to compact.'; exit 0 }
        $agg = @{}
        foreach ($line in [System.IO.File]::ReadAllLines($SIG)) {
            if ($line -match '^#') { continue }
            $f = $line -split '\s+'
            if ($f.Count -lt 3) { continue }
            $v = 0
            if ($f[2] -eq 'wave') { $v = 1 } elseif ($f[2] -eq 'deeper' -or $f[2] -eq 'correct') { $v = -1 } else { continue }
            if ($agg.ContainsKey($f[1])) { $agg[$f[1]] += $v } else { $agg[$f[1]] = $v }
        }
        $changed = 0
        foreach ($dim in $agg.Keys) {
            $score = $agg[$dim]
            if ($score -ge $THRESHOLD) { $dir = 'up' } elseif ($score -le (-$THRESHOLD)) { $dir = 'down' } else { continue }
            $cur = CurrentLevel $dim; if (-not $cur) { $cur = 'new' }
            $new = ShiftLevel $cur $dir
            if ($new -eq $cur) { continue }
            if (-not $dry) { ApplyLevel $dim $new }
            $arrow = if ($dir -eq 'up') { '▲' } else { '▼' }
            FlOut "$arrow $dim`: $cur -> $new"
            $changed++
        }
        if ($changed -eq 0) { FlOut "No level changes (signals below the ±$THRESHOLD threshold)." }
        if (-not $dry) { ResetSignals }
    }
    default {
        [Console]::Error.WriteLine('Usage: fluencyloop calibration [init | show [--json] | edit | signal <dim> <wave|deeper|correct> | compact [--dry-run]]')
        exit 1
    }
}
