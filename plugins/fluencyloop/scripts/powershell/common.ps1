# common.ps1 — PowerShell port of common.sh. Shared helpers, dot-sourced by the other scripts.
# The bash tree under scripts/bash is the reference implementation; this must match its behaviour
# and its --json output. Deterministic plumbing only.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- repo + paths ---------------------------------------------------------

function FlRepoRoot {
    $r = & git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $r) { return '' }
    return ($r | Select-Object -First 1)
}

function FlFluencyDir {
    $root = FlRepoRoot
    if ($root) { return "$root/.fluencyloop" } else { return '' }
}

function FlDocsDir {
    $root = FlRepoRoot
    if ($root) { return "$root/docs/fluencyloop" } else { return '' }
}

# Constitution: lives under docs_dir now; fall back to the pre-refactor .fluencyloop/ copy.
function FlConstitutionPath {
    $new = "$(FlDocsDir)/constitution.md"
    $old = "$(FlFluencyDir)/constitution.md"
    if (-not (Test-Path -LiteralPath $new) -and (Test-Path -LiteralPath $old)) { return $old }
    return $new
}

function FlRequireFluency {
    $dir = FlFluencyDir
    if (-not $dir -or -not (Test-Path -LiteralPath $dir -PathType Container)) {
        [Console]::Error.WriteLine("Error: FluencyLoop is not initialised here. Run 'fluencyloop init' first.")
        exit 1
    }
}

# --- text helpers ---------------------------------------------------------

function FlSlugify([string]$s) {
    if ($null -eq $s) { return '' }
    $x = $s.ToLowerInvariant()
    $x = [regex]::Replace($x, '[^a-z0-9]+', '-')
    $x = $x.Trim('-')
    if ($x.Length -gt 60) { $x = $x.Substring(0, 60) }
    return $x.Trim('-')
}

function FlToday { (Get-Date).ToString('yyyy-MM-dd') }

# Minimal JSON string escaper (quotes, backslashes, newlines) — matches common.sh json_escape.
function FlJsonEscape([string]$s) {
    if ($null -eq $s) { return '' }
    $s = $s.Replace('\', '\\').Replace('"', '\"')
    $s = $s.Replace("`r`n", "`n").Replace("`n", '\n')
    return $s
}

# Emit a flat JSON object from an alternating key/value array. emit_json k1 v1 k2 v2 ...
function FlEmitJson([string[]]$kv) {
    $parts = @()
    for ($i = 0; $i + 1 -lt $kv.Count; $i += 2) {
        $parts += '"' + $kv[$i] + '":"' + (FlJsonEscape ([string]$kv[$i + 1])) + '"'
    }
    return '{' + ($parts -join ',') + '}'
}

# Write text to a file as UTF-8 (no BOM) with exactly the given bytes — LF preserved.
function FlWriteText([string]$path, [string]$text) {
    $dir = Split-Path -Parent $path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

# Write a line to stdout with a trailing LF (not the platform CRLF).
function FlOut([string]$s) { [Console]::Out.Write($s + "`n") }

# --- feature/branch model -------------------------------------------------

function FlBranchFor([string]$slug) { "feature/$slug" }

function FlFeaturePath([string]$slug) {
    $new = "$(FlDocsDir)/features/$slug"
    $old = "$(FlFluencyDir)/features/$slug"
    if (-not (Test-Path -LiteralPath $new -PathType Container) -and (Test-Path -LiteralPath $old -PathType Container)) { return $old }
    return $new
}

function FlPlanPath([string]$slug) { "$(FlDocsDir)/plans/$slug" }

function FlCurrentFeatureSlug {
    $b = & git rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $b) { return '' }
    $b = ($b | Select-Object -First 1)
    if ($b -like 'feature/*') { return $b.Substring('feature/'.Length) }
    return ''
}

# --- loop state -----------------------------------------------------------

function FlStatePath { $d = FlFluencyDir; if ($d) { "$d/state.json" } else { '' } }

function FlRepoRel([string]$path) {
    $root = FlRepoRoot
    if ($root -and $path.StartsWith("$root/")) { return $path.Substring("$root/".Length) }
    return $path
}

# Read one string field from state.json (empty if the file or key is absent).
function FlStateGet([string]$key) {
    $f = FlStatePath
    if (-not $f -or -not (Test-Path -LiteralPath $f)) { return '' }
    $pat = '"' + [regex]::Escape($key) + '"\s*:\s*"([^"]*)"'
    foreach ($line in [System.IO.File]::ReadAllLines($f)) {
        if ($line -match $pat) { return $matches[1] }
    }
    return ''
}

# Write state.json from an alternating key/value array (all string-valued).
function FlWriteState([string[]]$kv) {
    $f = FlStatePath
    if (-not $f) { return }
    $parts = @()
    for ($i = 0; $i + 1 -lt $kv.Count; $i += 2) {
        $parts += '  "' + $kv[$i] + '": "' + (FlJsonEscape ([string]$kv[$i + 1])) + '"'
    }
    FlWriteText $f ("{`n" + ($parts -join ",`n") + "`n}`n")
}

# --- calibration ----------------------------------------------------------

function FlHomeDir { if ($env:FLUENCYLOOP_HOME) { $env:FLUENCYLOOP_HOME } else { "$HOME/.fluencyloop" } }
function FlCalibrationFile { "$(FlHomeDir)/calibration.md" }
function FlSignalsFile { "$(FlHomeDir)/signals.log" }
