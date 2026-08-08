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

# prefix + intent -> "<slugified-prefix>-<slugified-intent>", capped at the 60-char slugify
# ceiling. A ticket id, PR number, or sequential counter always becomes the leading segment of
# the feature dir name (e.g. "042-adding-rate-limiting").
function FlNumberedSlug([string]$prefix, [string]$intent) {
    $x = "$(FlSlugify $prefix)-$(FlSlugify $intent)"
    if ($x.Length -gt 60) { $x = $x.Substring(0, 60) }
    return $x.TrimEnd('-')
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

# The dir name can drift from the branch slug (e.g. renamed to carry a PR number once one
# exists — see rename-feature-dir.ps1), so for the *active* feature this checks state.json's
# `feature_dir` override before falling back to the computed path.
function FlFeaturePath([string]$slug) {
    $stateFeature = FlStateGet 'feature'
    if ($stateFeature -and $stateFeature -eq $slug) {
        $stored = FlStateGet 'feature_dir'
        if ($stored) { return "$(FlRepoRoot)/$stored" }
    }
    $new = "$(FlDocsDir)/features/$slug"
    $old = "$(FlFluencyDir)/features/$slug"
    if (-not (Test-Path -LiteralPath $new -PathType Container) -and (Test-Path -LiteralPath $old -PathType Container)) { return $old }
    return $new
}

function FlPlanPath([string]$slug) { "$(FlDocsDir)/plans/$slug" }

# Re-run index.ps1 after a feature/plan mutation. Spawned as a genuine child process (not called
# in-process via `&`) because FlOut writes straight to [Console]::Out — bypassing whatever
# PowerShell stream redirection (e.g. `*> $null`) the *in-process* caller applies. A real child
# process's stdout is a real OS-level handle, so the caller's redirection actually silences it,
# the same way bash's `index.sh >/dev/null` genuinely discards output as a subprocess.
function FlRefreshIndex {
    $exe = (Get-Process -Id $PID).Path
    & $exe -NoProfile -File "$PSScriptRoot/index.ps1" *> $null
}

# --- feature numbering ------------------------------------------------------
# Every feature dir is prefixed so `features/` sorts and scans instead of reading as a flat,
# unordered pile: a ticket id, a PR number (patched in after the fact — see
# rename-feature-dir.ps1), or, absent either, a zero-padded sequential counter.
function FlNextFeatureNumber {
    $dir = "$(FlDocsDir)/features"
    $n = 0
    if (Test-Path -LiteralPath $dir -PathType Container) {
        $n = @(Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue).Count
    }
    return ('{0:d3}' -f ($n + 1))
}

# Next sequential session number within a feature (zero-padded), so sessions/ sorts in build
# order instead of alphabetically by intent slug.
function FlNextSessionNumber([string]$dir) {
    $n = 0
    if (Test-Path -LiteralPath $dir -PathType Container) {
        $n = @(Get-ChildItem -LiteralPath $dir -Filter '*.md' -File -ErrorAction SilentlyContinue).Count
    }
    return ('{0:d3}' -f ($n + 1))
}

function FlCurrentFeatureSlug {
    $b = & git rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $b) { return '' }
    $b = ($b | Select-Object -First 1)
    if ($b -like 'feature/*') { return $b.Substring('feature/'.Length) }
    return ''
}

# --- loop state -----------------------------------------------------------

# The state file's data-model generation. Bump only when the on-disk shape changes in a way a
# reader has to branch on — it is how a later version tells an old project from a new one
# without guessing from which files happen to be present. Mirrors common.sh.
function FlSchemaVersion { 1 }

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

# The generation of the state file on disk. A file written before the field existed has none,
# and reads as 1 — so every pre-existing project is a valid schema 1 without being rewritten.
function FlStateSchemaVersion {
    $v = FlStateGet 'schema_version'
    if ($v) { $v } else { '1' }
}

# Write state.json from an alternating key/value array (all string-valued).
function FlWriteState([string[]]$kv) {
    $f = FlStatePath
    if (-not $f) { return }
    # schema_version leads every state file, written here rather than by each caller so no
    # write path can omit it. Quoted like every other value — FlStateGet only reads strings.
    $parts = @('  "schema_version": "' + (FlSchemaVersion) + '"')
    for ($i = 0; $i + 1 -lt $kv.Count; $i += 2) {
        $parts += '  "' + $kv[$i] + '": "' + (FlJsonEscape ([string]$kv[$i + 1])) + '"'
    }
    FlWriteText $f ("{`n" + ($parts -join ",`n") + "`n}`n")
}

# --- store ----------------------------------------------------------------
# The append-only record of what the loop observed: one JSON object per line. Mirrors the store
# section of common.sh — see there for why JSONL, and why features get a file each while concepts
# share one global stream.

function FlStoreDir { $d = FlDocsDir; if ($d) { "$d/store" } else { '' } }

function FlFeatureStorePath([string]$slug) { "$(FlStoreDir)/features/$slug.jsonl" }
function FlConceptsStorePath { "$(FlStoreDir)/concepts.jsonl" }

# Append one record from an alternating key/value array, creating the file and its parent dir.
# Pairs with an empty value are dropped — the only difference from FlEmitJson, which keeps them.
# Written with an explicit LF and no BOM, so a line is byte-identical to the bash runtime's.
function FlStoreAppend([string]$path, [string[]]$kv) {
    $pairs = @()
    if ($kv) {
        for ($i = 0; $i + 1 -lt $kv.Count; $i += 2) {
            if ([string]$kv[$i + 1] -ne '') { $pairs += $kv[$i]; $pairs += [string]$kv[$i + 1] }
        }
    }
    $dir = Split-Path -Parent $path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::AppendAllText($path, (FlEmitJson $pairs) + "`n", (New-Object System.Text.UTF8Encoding($false)))
}

# --- calibration ----------------------------------------------------------

function FlHomeDir { if ($env:FLUENCYLOOP_HOME) { $env:FLUENCYLOOP_HOME } else { "$HOME/.fluencyloop" } }
function FlCalibrationFile { "$(FlHomeDir)/calibration.md" }
function FlSignalsFile { "$(FlHomeDir)/signals.log" }
