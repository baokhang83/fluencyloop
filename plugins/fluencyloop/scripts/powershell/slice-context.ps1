# slice-context.ps1 — PowerShell port of slice-context.sh. The current slice's hunks + metadata +
# decision pre-filter. Matches slice-context.sh --json.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

FlRequireFluency
Set-Location -LiteralPath (FlRepoRoot)   # normalize pathspecs to the repo root

$jsonMode = $false
foreach ($a in $args) {
    if ($a -eq '--json') { $jsonMode = $true }
    else { [Console]::Error.WriteLine("Unknown option: $a"); exit 1 }
}

# The slice is the developer's code, not FluencyLoop's own bookkeeping.
$exclude = @('--', '.', ':!.fluencyloop', ':!docs/fluencyloop')

$feature = FlStateGet 'feature'
if (-not $feature) { $feature = FlCurrentFeatureSlug }
$baseRef = FlStateGet 'base_ref'; if (-not $baseRef) { $baseRef = 'main' }

# Where the slice starts: last journaled session, else base ref, else HEAD.
$since = ''; $baseKind = 'base-ref'
if ($feature) {
    $sdir = "$(FlFeaturePath $feature)/sessions"
    $lastJournal = & git log -1 --format=%H -- $sdir 2>$null
    if ($LASTEXITCODE -eq 0 -and $lastJournal) { $since = ($lastJournal | Select-Object -First 1); $baseKind = 'last-session' }
}
if (-not $since) { $since = $baseRef }
& git rev-parse --verify --quiet $since *> $null
if ($LASTEXITCODE -ne 0) { $since = 'HEAD'; $baseKind = 'head' }

$untrackedFiles = @(& git ls-files --others --exclude-standard @exclude 2>$null)
$diffLines = @(& git diff $since @exclude 2>$null)
foreach ($f in $untrackedFiles) {
    $ud = @(& git diff --no-index -- /dev/null $f 2>$null)
    $diffLines += $ud
}
$diff = $diffLines -join "`n"

$ins = 0; $del = 0; $tracked = 0
foreach ($line in @(& git diff --numstat $since @exclude 2>$null)) {
    $p = $line -split "`t"
    if ($p.Count -ge 2) {
        if ($p[0] -ne '-') { $ins += [int]$p[0] }
        if ($p[1] -ne '-') { $del += [int]$p[1] }
        $tracked++
    }
}
$filesChanged = $tracked + $untrackedFiles.Count
$short = & git rev-parse --short $since 2>$null
if ($LASTEXITCODE -ne 0 -or -not $short) { $short = $since } else { $short = ($short | Select-Object -First 1) }

# --- decision pre-filter: cheap heuristics over ADDED lines ---
$manifest = $false; $code = 0; $imp = 0; $dep = 0; $api = 0; $ctl = 0
foreach ($ln in $diffLines) {
    if ($ln -match '^\+\+\+ ') {
        $ff = ($ln -split ' ')[1] -replace '^b/', ''
        $bn = Split-Path -Leaf $ff
        $manifest = ($bn -match '^(package\.json|pom\.xml|go\.mod|Cargo\.toml|Gemfile|composer\.json|pyproject\.toml|requirements[^ ]*\.txt|Pipfile|build\.gradle(\.kts)?)$')
        continue
    }
    if ($ln -match '^(---|diff |index |@@|new file|deleted file|similarity|rename|Binary)') { continue }
    if ($ln -match '^\+') {
        $t = $ln.Substring(1) -replace '^[ \t]+', ''
        if ($t -eq '') { continue }
        $iscomment = ($t -match '^(//|#|\*|/\*|--|<!--)')
        if (-not $iscomment) { $code++ }
        if (($t -cmatch '^(import|from|#include|using|use)[ \t]') -or ($t -cmatch 'require[ \t]*\(')) { $imp++ }
        if ($manifest -and -not $iscomment) { $dep++ }
        if (($t -cmatch '^(export|public)[ \t]') -or
            ($t -cmatch '^(export[ \t]+)?(default[ \t]+)?(async[ \t]+)?function[ \t]') -or
            ($t -cmatch '^(public[ \t]+|export[ \t]+|abstract[ \t]+)*(class|interface|enum|trait|struct)[ \t]') -or
            ($t -cmatch '^(pub[ \t]+)?fn[ \t]') -or ($t -cmatch '^func[ \t]') -or ($t -cmatch '^def[ \t]') -or
            ($t -cmatch '^@[A-Za-z_.]*(route|mapping|[GgPpDd][a-z]+)[(:]?')) { $api++ }
        if ($t -cmatch '(^|[^A-Za-z_])(if|else|for|while|switch|case|try|catch|except|match)([^A-Za-z_]|$)') { $ctl++ }
    }
}
$score = 0; $sigList = @()
if ($imp -gt 0 -or $dep -gt 0) { $score += 2; $sigList += 'dep-or-import' }
if ($api -gt 0) { $score += 2; $sigList += 'new-api' }
if ($ctl -gt 0 -and $code -ge 8) { $score += 2; $sigList += 'control-flow' }
if ($code -ge 15) { $score += 1; $sigList += 'size' }
if ($code -ge 40) { $score += 1 }
if ($code -eq 0) { $score = 0; $sigList = @('trivial') }
$likely = if ($score -ge 2) { 'true' } else { 'false' }

if ($jsonMode) {
    $files = @()
    foreach ($line in @(& git diff --name-status $since @exclude 2>$null)) {
        $p = $line -split "`t"
        if ($p.Count -ge 2) {
            $path = ($p[-1]).Replace('\', '\\').Replace('"', '\"')
            $files += '{"status":"' + $p[0] + '","path":"' + $path + '"}'
        }
    }
    $unt = @()
    foreach ($u in $untrackedFiles) { $unt += '"' + $u.Replace('\', '\\').Replace('"', '\"') + '"' }
    $sigJson = ($sigList | ForEach-Object { '"' + $_ + '"' }) -join ','
    $diffEsc = $diff.Replace('\', '\\').Replace('"', '\"').Replace("`t", '\t').Replace("`r", '\r').Replace("`n", '\n')
    $json = '{"feature":"' + (FlJsonEscape $feature) + '","base_kind":"' + $baseKind + '","base":"' + (FlJsonEscape $short) +
            '","files_changed":' + $filesChanged + ',"insertions":' + $ins + ',"deletions":' + $del +
            ',"likely_decision":' + $likely + ',"decision_score":' + $score +
            ',"decision_signals":[' + $sigJson + '],"files":[' + ($files -join ',') + '],"untracked":[' + ($unt -join ',') +
            '],"diff":"' + $diffEsc + '"}'
    FlOut $json
} else {
    $feat = if ($feature) { $feature } else { '<none>' }
    FlOut "# Slice context — feature: $feat (since $baseKind $short)"
    FlOut "# $filesChanged file(s), +$ins -$del"
    $sigStr = $sigList -join ' '
    $sigSuffix = if ($sigStr) { ": $sigStr" } else { '' }
    FlOut "# likely_decision: $likely (score $score$sigSuffix)"
    FlOut ''
    [Console]::Out.Write($diff + "`n")
}
