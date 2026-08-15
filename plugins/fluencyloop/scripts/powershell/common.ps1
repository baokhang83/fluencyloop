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
    FlMaybeImportLegacy
}

# First 0.3 use must carry legacy history forward without asking. Check the importer's
# per-feature declaration marker as well as the store directory: an early 0.3 importer may have
# copied decisions without the declarations added later. Marked retries are idempotent.
#
# Bump this when a legacy parser correction can recover records that an earlier importer skipped.
# It gives already-migrated repositories one automatic, idempotent repair pass without running the
# full legacy scan on every normal command thereafter.
$script:FlLegacyImportRevision = '2'
# Revision 5 reopens earlier semantic passes that completed before tag coverage was required. The
# reader resolves records by identity, so tagged record replacements are additive and retain their
# original provenance.
$script:FlLegacySemanticMigrationRevision = '5'

function Get-FlLegacyImportRevisionPath { "$(FlStoreDir)/.legacy-import-revision" }
function Get-FlLegacySemanticMigrationPath { "$(FlStoreDir)/.legacy-semantic-migration-revision" }
function Get-FlLegacyImportedFeatureCount {
    $features = "$(FlStoreDir)/features"
    if (-not (Test-Path -LiteralPath $features -PathType Container)) { return 0 }
    $count = 0
    foreach ($store in @(Get-ChildItem -LiteralPath $features -Filter '*.jsonl' -File -ErrorAction SilentlyContinue)) {
        if (Select-String -LiteralPath $store.FullName -Pattern '"type":"feature".*"imported_from":"' -Quiet) { $count++ }
    }
    return $count
}
function Get-FlLegacyImportedFeatureSlug {
    $features = "$(FlStoreDir)/features"
    if (-not (Test-Path -LiteralPath $features -PathType Container)) { return @() }
    return @(
        Get-ChildItem -LiteralPath $features -Filter '*.jsonl' -File -ErrorAction SilentlyContinue |
            Sort-Object Name |
            Where-Object { Select-String -LiteralPath $_.FullName -Pattern '"type":"feature".*"imported_from":"' -Quiet } |
            ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }
    )
}
function Get-FlLegacySemanticAssessmentCount {
    $count = 0
    foreach ($feature in @(Get-FlLegacyImportedFeatureSlug)) {
        $store = FlFeatureStorePath $feature
        if (Select-String -LiteralPath $store -Pattern ('"type":"semantic_assessment".*"semantic_migration_revision":"' + $script:FlLegacySemanticMigrationRevision + '"') -Quiet) { $count++ }
    }
    return $count
}
function Get-FlLegacyArchitecturalRecordCount {
    $store = FlConceptsStorePath
    if (-not (Test-Path -LiteralPath $store -PathType Leaf)) { return 0 }
    return @([System.IO.File]::ReadAllLines($store) | Where-Object { $_ -match '"type":"concept"' }).Count
}
function Get-FlLegacyTaggedArchitecturalRecordCount {
    $store = FlConceptsStorePath
    if (-not (Test-Path -LiteralPath $store -PathType Leaf)) { return 0 }
    return @([System.IO.File]::ReadAllLines($store) | Where-Object { $_ -match '"type":"concept".*"tags":"[^\"]+' }).Count
}
function Get-FlLegacySemanticUnassessedFeature {
    $missing = @()
    foreach ($feature in @(Get-FlLegacyImportedFeatureSlug)) {
        $store = FlFeatureStorePath $feature
        if (-not (Select-String -LiteralPath $store -Pattern ('"type":"semantic_assessment".*"semantic_migration_revision":"' + $script:FlLegacySemanticMigrationRevision + '"') -Quiet)) { $missing += $feature }
    }
    return $missing
}
function Test-FlLegacySemanticMigrationPending {
    if ((Get-FlLegacyImportedFeatureCount) -eq 0) { return $false }
    $marker = Get-FlLegacySemanticMigrationPath
    return -not ((Test-Path -LiteralPath $marker -PathType Leaf) -and
        (([System.IO.File]::ReadAllText($marker)).Trim() -eq $script:FlLegacySemanticMigrationRevision))
}

function Test-FlLegacyImportNeedsRevision([string]$legacy) {
    $revisionPath = Get-FlLegacyImportRevisionPath
    if ((Test-Path -LiteralPath $revisionPath -PathType Leaf) -and
        (([System.IO.File]::ReadAllText($revisionPath)).Trim() -eq $script:FlLegacyImportRevision)) {
        return $false
    }
    foreach ($featureDir in @(Get-ChildItem -LiteralPath $legacy -Directory -ErrorAction SilentlyContinue)) {
        $feature = $featureDir.Name
        $store = FlFeatureStorePath $feature
        if (-not (Test-Path -LiteralPath $store -PathType Leaf)) { continue }
        $root = FlRepoRoot
        $source = $featureDir.FullName.Substring($root.Length).TrimStart([char[]]@([char]92, [char]47)) -replace '\\', '/'
        $marker = '"imported_from":"' + (FlJsonEscape "$source#feature") + '"'
        # Only retry a repository that has actually received a legacy import. A native 0.3
        # feature can legitimately share the same docs layout and must not be imported as legacy.
        if (Select-String -LiteralPath $store -SimpleMatch -Quiet -Pattern $marker) { return $true }
    }
    return $false
}

function Test-FlLegacyImportIncomplete([string]$legacy) {
    foreach ($featureDir in @(Get-ChildItem -LiteralPath $legacy -Directory -ErrorAction SilentlyContinue)) {
        $sessions = Join-Path $featureDir.FullName 'sessions'
        if (-not (Test-Path -LiteralPath $sessions -PathType Container) -or -not @(Get-ChildItem -LiteralPath $sessions -Filter '*.md' -File -ErrorAction SilentlyContinue).Count) {
            continue
        }
        $feature = $featureDir.Name
        $store = FlFeatureStorePath $feature
        $root = FlRepoRoot
        $source = $featureDir.FullName.Substring($root.Length).TrimStart([char[]]@([char]92, [char]47)) -replace '\\', '/'
        $marker = '"imported_from":"' + (FlJsonEscape "$source#feature") + '"'
        if (-not (Test-Path -LiteralPath $store -PathType Leaf)) {
            return $true
        }
        if (Select-String -LiteralPath $store -SimpleMatch -Quiet -Pattern $marker) { continue }
        # Only repair a pre-declaration import. A native 0.3 feature may share a legacy slug;
        # without an imported marker, appending a synthetic record would supersede it on read.
        $legacyMarker = '"imported_from":"' + (FlJsonEscape "$source/")
        if (Select-String -LiteralPath $store -SimpleMatch -Quiet -Pattern $legacyMarker) { return $true }
    }
    return $false
}

function FlMaybeImportLegacy {
    if ($env:FLUENCYLOOP_IMPORTING -eq '1') { return }
    $legacy = "$(FlDocsDir)/features"
    $store = FlStoreDir
    if (-not (Test-Path -LiteralPath $legacy -PathType Container)) { return }
    if ((Test-Path -LiteralPath $store -PathType Container) -and
        -not (Test-FlLegacyImportIncomplete $legacy) -and
        -not (Test-FlLegacyImportNeedsRevision $legacy)) { return }
    $importer = Join-Path $PSScriptRoot 'import-legacy.ps1'
    if (-not (Test-Path -LiteralPath $importer -PathType Leaf)) { return }
    $previous = $env:FLUENCYLOOP_IMPORTING
    try {
        $env:FLUENCYLOOP_IMPORTING = '1'
        & (Get-Process -Id $PID).Path -NoProfile -File $importer --auto
        if ($LASTEXITCODE -ne 0) { throw "legacy import failed with exit code $LASTEXITCODE" }
    } finally {
        if ($null -eq $previous) { Remove-Item Env:FLUENCYLOOP_IMPORTING -ErrorAction SilentlyContinue }
        else { $env:FLUENCYLOOP_IMPORTING = $previous }
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

# --- feature numbering ------------------------------------------------------
# Every feature slug is prefixed with a ticket id, PR number, or a zero-padded counter. Since 0.3
# no longer creates feature directories, count the committed per-feature store files and local
# feature branches as well as legacy dirs. This stays structural: it never reads JSONL.
function FlNextFeatureNumber {
    $dir = "$(FlDocsDir)/features"
    $store = "$(FlStoreDir)/features"
    $dirs = if (Test-Path -LiteralPath $dir -PathType Container) { @(Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue).Count } else { 0 }
    $stores = if (Test-Path -LiteralPath $store -PathType Container) { @(Get-ChildItem -LiteralPath $store -Filter '*.jsonl' -File -ErrorAction SilentlyContinue).Count } else { 0 }
    $branches = @(& git for-each-ref --format='%(refname)' refs/heads/feature 2>$null).Count
    $n = [Math]::Max($dirs, [Math]::Max($stores, $branches))
    return ('{0:d3}' -f ($n + 1))
}

# Next sequential session number within a feature (zero-padded), derived from its append-only
# store rather than the mutable active-session pointer. Imported records retain their legacy
# session slug in the common envelope even when no native session record exists.
function Get-FlNextSessionNumber([string]$feature) {
    $store = FlFeatureStorePath $feature
    $highest = 0
    if (-not (Test-Path -LiteralPath $store -PathType Leaf)) { return '001' }
    foreach ($line in [System.IO.File]::ReadAllLines($store)) {
        if ($line -match '"session":"(\d+)-[^\"]*"') {
            $number = [int]$matches[1]
            if ($number -gt $highest) { $highest = $number }
        }
    }
    return ('{0:d3}' -f ($highest + 1))
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

# Append a schema-complete record. Store writers supply the contextual fields that vary per call;
# this wrapper owns the invariant envelope so no future writer can forget it. Keep FlStoreAppend
# generic: it is also the low-level primitive A1 promises to callers.
function FlStoreCommit {
    $commit = & git rev-parse --verify --quiet HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $commit) { return ($commit | Select-Object -First 1) }
    return 'uncommitted'
}

# Example: FlStoreAppendRecord (FlFeatureStorePath 'add-caching') 'decision' 'add-caching' '001-wire-cache' @(...)
function FlStoreAppendRecord([string]$path, [string]$type, [string]$feature, [string]$session, [string[]]$kv) {
    if (-not $path -or -not $type -or -not $feature -or -not $session) {
        throw 'store record requires file, type, feature, and session.'
    }
    $record = @(
        'schema_version', (FlSchemaVersion),
        'type', $type,
        'ts', (FlToday),
        'feature', $feature,
        'session', $session,
        'commit', (FlStoreCommit)
    ) + $kv
    FlStoreAppend $path $record
}

# --- calibration ----------------------------------------------------------

function FlHomeDir { if ($env:FLUENCYLOOP_HOME) { $env:FLUENCYLOOP_HOME } else { "$HOME/.fluencyloop" } }
function FlCalibrationFile { "$(FlHomeDir)/calibration.md" }
function FlSignalsFile { "$(FlHomeDir)/signals.log" }
