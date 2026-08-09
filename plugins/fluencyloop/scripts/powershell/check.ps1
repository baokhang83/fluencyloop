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
$gitRepoStr = if ($root) { 'true' } else { 'false' }

$fdir = FlFluencyDir
$fluencyStr = if ($fdir -and (Test-Path -LiteralPath $fdir -PathType Container)) { 'true' } else { 'false' }
if ($fluencyStr -eq 'true') { FlMaybeImportLegacy }

$branch = & git rev-parse --abbrev-ref HEAD 2>$null
if ($LASTEXITCODE -ne 0 -or -not $branch) { $branch = '' } else { $branch = ($branch | Select-Object -First 1) }

$feature = FlStateGet 'feature'
if (-not $feature) { $feature = FlCurrentFeatureSlug }
$stage = FlStateGet 'stage'
$base = FlStateGet 'base_ref'; if (-not $base) { $base = 'main' }
$lastSession = FlStateGet 'last_session'

# Un-journaled drift: commits since the last committed session record; else since base. Legacy
# session markdown remains a read-only fallback for projects that have not imported it yet.
$unjournaled = 0
if ($root -and $feature) {
    $lastJournal = ''
    if ($lastSession) {
        $store = FlFeatureStorePath $feature
        if (Test-Path -LiteralPath $store -PathType Leaf) {
            $lastJournal = & git log -1 --format=%H -- $store 2>$null
        } else {
            $sdir = "$(FlFeaturePath $feature)/sessions"
            $lastJournal = & git log -1 --format=%H -- $sdir 2>$null
        }
    }
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

# Store writers only append and never read JSONL. The doctor is the deliberate read-time
# consistency boundary: it reports every finding but never repairs or rewrites a record.
$script:storeErrors = @()
$script:conceptNames = @{}
$script:componentNames = @{}
$script:featureNames = @{}
$script:relations = @()

function Add-StoreError([string]$File, [int]$Line, [string]$Message) {
    $script:storeErrors += [pscustomobject]@{ file = $File; line = $Line; message = $Message }
}

function Get-StoreStringField($Record, [string]$Name) {
    $property = $Record.PSObject.Properties[$Name]
    if ($null -eq $property -or $property.Value -isnot [string] -or -not $property.Value) { return $null }
    return [string]$property.Value
}

function Test-StoreRecordType([string]$Type) {
    return $Type -in @('feature', 'session', 'decision', 'component', 'condition', 'concept', 'relation', 'principle', 'requirement', 'open_question')
}

function Test-KnownIdentity([string]$Identity) {
    return $script:conceptNames.ContainsKey($Identity) -or
           $script:componentNames.ContainsKey($Identity) -or
           $script:featureNames.ContainsKey($Identity)
}

function Test-StoreRecord([string]$Raw, [string]$File, [int]$Line) {
    try { $record = $Raw | ConvertFrom-Json -ErrorAction Stop }
    catch {
        Add-StoreError $File $Line 'unparseable JSON'
        return
    }
    if ($record -isnot [pscustomobject]) {
        Add-StoreError $File $Line 'store record must be a JSON object'
        return
    }

    $type = Get-StoreStringField $record 'type'
    foreach ($field in @('schema_version', 'type', 'ts', 'feature', 'session', 'commit')) {
        if (-not (Get-StoreStringField $record $field)) {
            Add-StoreError $File $Line "missing required envelope field: $field"
        }
    }
    if ($type -and -not (Test-StoreRecordType $type)) {
        Add-StoreError $File $Line "unknown record type: $type"
        return
    }

    $feature = Get-StoreStringField $record 'feature'
    if ($feature -and $feature -ne 'global') { $script:featureNames[$feature] = $true }
    switch ($type) {
        'concept' {
            $name = Get-StoreStringField $record 'name'
            if ($name) { $script:conceptNames[$name] = $true }
        }
        'component' {
            $name = Get-StoreStringField $record 'name'
            if ($name) { $script:componentNames[$name] = $true }
        }
        'relation' {
            $script:relations += [pscustomobject]@{
                file = $File; line = $Line
                from = Get-StoreStringField $record 'from'
                to = Get-StoreStringField $record 'to'
            }
        }
    }
}

$storeRoot = FlStoreDir
if ($storeRoot -and (Test-Path -LiteralPath $storeRoot -PathType Container)) {
    Get-ChildItem -LiteralPath $storeRoot -Filter '*.jsonl' -File -Recurse | Sort-Object FullName | ForEach-Object {
        $file = $_.FullName
        $relativeFile = FlRepoRel $file
        $lines = [System.IO.File]::ReadAllLines($file)
        for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
            Test-StoreRecord $lines[$lineIndex] $relativeFile ($lineIndex + 1)
        }
    }

    # Relations can precede their defining concept, so validate targets only after the full scan.
    foreach ($relation in $script:relations) {
        if (-not (Test-KnownIdentity $relation.from)) {
            Add-StoreError $relation.file $relation.line "dangling relation endpoint: $($relation.from)"
        }
        if (-not (Test-KnownIdentity $relation.to)) {
            Add-StoreError $relation.file $relation.line "dangling relation endpoint: $($relation.to)"
        }
    }

    $featuresRoot = "$(FlDocsDir)/features"
    if (Test-Path -LiteralPath $featuresRoot -PathType Container) {
        Get-ChildItem -LiteralPath $featuresRoot -Directory | Sort-Object Name | ForEach-Object {
            $featureStore = FlFeatureStorePath $_.Name
            if (-not (Test-Path -LiteralPath $featureStore -PathType Leaf) -or (Get-Item -LiteralPath $featureStore).Length -eq 0) {
                Add-StoreError (FlRepoRel $featureStore) 0 "feature directory has no store records: $($_.Name)"
            }
        }
    }
}

if ($jsonMode) {
    $storeErrorsJson = ConvertTo-Json -InputObject @($script:storeErrors) -Compress -Depth 3
    $json = '{"git_repo":' + $gitRepoStr +
            ',"fluency":' + $fluencyStr +
            ',"branch":"' + (FlJsonEscape $branch) + '"' +
            ',"feature":"' + (FlJsonEscape $feature) + '"' +
            ',"stage":"' + (FlJsonEscape $stage) + '"' +
            ',"base_ref":"' + (FlJsonEscape $base) + '"' +
            ',"last_session":"' + (FlJsonEscape $lastSession) + '"' +
            ',"unjournaled_commits":' + $unjournaled +
            ',"calibration":' + $calStr +
            ',"constitution":"' + $cstate + '"' +
            ',"store_errors":' + $storeErrorsJson + '}'
    FlOut $json
    if ($script:storeErrors.Count -eq 0) { exit 0 }
    exit 1
}

function Mark([string]$b) { if ($b -eq 'true') { 'ok ' } else { 'XX ' } }
FlOut 'FluencyLoop check'
if ($gitRepoStr -eq 'false') {
    FlOut "  XX  not a git repository — run 'git init' (or cd into one), then 'fluencyloop init'"
}
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
if ($script:storeErrors.Count -eq 0) {
    FlOut '  ok  store: valid'
} else {
    foreach ($storeError in $script:storeErrors) {
        FlOut "  XX  store: $($storeError.file):$($storeError.line): $($storeError.message)"
    }
}
if ($script:storeErrors.Count -ne 0) { exit 1 }
