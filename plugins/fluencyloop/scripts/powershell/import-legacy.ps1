# import-legacy.ps1 — PowerShell port of import-legacy.sh. Reads rigid legacy session markdown
# without changing it, then appends marked store records. The imported_from marker makes re-runs
# idempotent without parsing JSON.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"
$env:FLUENCYLOOP_IMPORTING = '1'

$auto = $false; $markSemanticComplete = $false; $assessFeature = ''; $assessSummary = ''; $assessRecords = @(); $semanticStatus = $false; $semanticMap = $false; $assessUnconfirmed = $false; $json = $false; $help = $false
for ($i = 0; $i -lt $args.Count; $i++) {
    $arg = $args[$i]
    if ($arg -eq '--auto') { $auto = $true }
    elseif ($arg -eq '--mark-semantic-complete') { $markSemanticComplete = $true }
    elseif ($arg -eq '--assess') { $i++; if ($i -ge $args.Count) { [Console]::Error.WriteLine('Error: --assess requires an imported feature slug.'); exit 1 }; $assessFeature = $args[$i] }
    elseif ($arg -eq '--summary') { $i++; if ($i -ge $args.Count) { [Console]::Error.WriteLine('Error: --summary requires text.'); exit 1 }; $assessSummary = $args[$i] }
    elseif ($arg -eq '--record') { $i++; if ($i -ge $args.Count) { [Console]::Error.WriteLine('Error: --record requires a record name.'); exit 1 }; $assessRecords += $args[$i] }
    elseif ($arg -eq '--semantic-status') { $semanticStatus = $true }
    elseif ($arg -eq '--semantic-map') { $semanticMap = $true }
    elseif ($arg -eq '--assess-unconfirmed') { $assessUnconfirmed = $true }
    elseif ($arg -eq '--json') { $json = $true }
    elseif ($arg -eq '--help' -or $arg -eq '-h') { $help = $true }
    else { [Console]::Error.WriteLine("Unknown option: $arg"); exit 1 }
}

if ($help) {
    FlOut 'Usage: fluencyloop import [--auto]'
    FlOut '       fluencyloop import --semantic-status [--json]'
    FlOut '       fluencyloop import --semantic-map'
    FlOut '       fluencyloop import --assess-unconfirmed'
    FlOut '       fluencyloop import --assess <feature> --summary <text> [--record <name> ...]'
    FlOut '       fluencyloop import --mark-semantic-complete'
    FlOut ''
    FlOut 'Import legacy Markdown records, print a compact record map, stamp all imported features as unconfirmed, record one reviewed assessment, or mark a fully assessed migration complete.'
    exit 0
}
FlRequireFluency

if ($semanticStatus) {
    if ($auto) { [Console]::Error.WriteLine('Error: --auto cannot be combined with --semantic-status.'); exit 1 }
    if ($markSemanticComplete) { [Console]::Error.WriteLine('Error: --semantic-status and --mark-semantic-complete cannot be combined.'); exit 1 }
    if ($assessFeature -or $assessSummary -or $semanticMap -or $assessUnconfirmed) { [Console]::Error.WriteLine('Error: --semantic-status cannot be combined with another migration action.'); exit 1 }
    $imported = @(Get-FlLegacyImportedFeatureSlug)
    $unassessed = @(Get-FlLegacySemanticUnassessedFeature)
    $architecturalRecords = Get-FlLegacyArchitecturalRecordCount
    if ($json) { [pscustomobject]@{ imported_features = $imported; unassessed_features = $unassessed; architectural_records = $architecturalRecords; tagged_architectural_records = (Get-FlLegacyTaggedArchitecturalRecordCount) } | ConvertTo-Json -Compress }
    else {
        FlOut "Imported legacy features: $($imported.Count)"
        FlOut "Assessed: $(Get-FlLegacySemanticAssessmentCount)"
        FlOut "Architectural records: $architecturalRecords"
        FlOut "Tagged architectural records: $(Get-FlLegacyTaggedArchitecturalRecordCount)"
        FlOut 'Unassessed features:'
        $unassessed | ForEach-Object { FlOut $_ }
    }
    exit 0
}

if ($semanticMap) {
    if ($auto -or $markSemanticComplete -or $assessFeature -or $assessSummary -or $assessUnconfirmed -or $semanticStatus) { [Console]::Error.WriteLine('Error: --semantic-map cannot be combined with another migration action.'); exit 1 }
    FlOut '# Imported legacy record map'
    foreach ($feature in @(Get-FlLegacyImportedFeatureSlug)) {
        $store = FlFeatureStorePath $feature
        FlOut ''
        FlOut "## $feature"
        $records = @([System.IO.File]::ReadAllLines($store) | ForEach-Object { $_ | ConvertFrom-Json })
        $featureRecord = @($records | Where-Object { $_.type -eq 'feature' } | Select-Object -Last 1)[0]
        if ($featureRecord.intent) { FlOut "Intent: $($featureRecord.intent)" }
        foreach ($record in $records) {
            switch ($record.type) {
                'decision' { FlOut "Decision: $($record.title) — $($record.where)" }
                'component' { FlOut "Component: $($record.name)" }
                'condition' { FlOut "Condition: $($record.subject)" }
            }
        }
    }
    $conceptStore = FlConceptsStorePath
    if (Test-Path -LiteralPath $conceptStore -PathType Leaf) {
        FlOut ''
        FlOut '# Existing architectural records'
        foreach ($record in @([System.IO.File]::ReadAllLines($conceptStore) | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { $_.type -eq 'concept' })) {
            $tags = if ($record.PSObject.Properties.Name -contains 'tags' -and $record.tags) { $record.tags } else { '(missing)' }
            FlOut "Record: $($record.name) — tags: $tags"
        }
    }
    exit 0
}

if ($assessUnconfirmed) {
    if ($auto -or $markSemanticComplete -or $assessFeature -or $assessSummary -or $semanticStatus) { [Console]::Error.WriteLine('Error: --assess-unconfirmed cannot be combined with another migration action.'); exit 1 }
    $recorded = 0
    foreach ($feature in @(Get-FlLegacyImportedFeatureSlug)) {
        $store = FlFeatureStorePath $feature
        $assessmentPattern = '"type":"semantic_assessment".*"semantic_migration_revision":"' + $script:FlLegacySemanticMigrationRevision + '"'
        if (Select-String -LiteralPath $store -Pattern $assessmentPattern -Quiet) { continue }
        FlStoreAppendRecord $store 'semantic_assessment' $feature '000-legacy-import' @(
            'summary', 'Imported pre-0.3 history is unconfirmed pending independent review.',
            'trust', 'unverified', 'semantic_migration_revision', $script:FlLegacySemanticMigrationRevision)
        $recorded++
    }
    FlOut "Recorded $recorded unconfirmed legacy assessment(s)."
    exit 0
}

if ($assessFeature -or $assessSummary) {
    if ($auto) { [Console]::Error.WriteLine('Error: --auto cannot be combined with --assess.'); exit 1 }
    if ($markSemanticComplete) { [Console]::Error.WriteLine('Error: --assess and --mark-semantic-complete cannot be combined.'); exit 1 }
    if (-not $assessFeature) { [Console]::Error.WriteLine('Error: --assess requires an imported feature slug.'); exit 1 }
    if (-not $assessSummary) { [Console]::Error.WriteLine('Error: --summary is required with --assess.'); exit 1 }
    $featureStore = FlFeatureStorePath $assessFeature
    if (-not (Test-Path -LiteralPath $featureStore -PathType Leaf) -or -not (Select-String -LiteralPath $featureStore -Pattern '"type":"feature".*"imported_from":"' -Quiet)) {
        [Console]::Error.WriteLine("Error: $assessFeature is not an imported legacy feature."); exit 1
    }
    $assessmentPattern = '"type":"semantic_assessment".*"semantic_migration_revision":"' + $script:FlLegacySemanticMigrationRevision + '"'
    if (Select-String -LiteralPath $featureStore -Pattern $assessmentPattern -Quiet) { FlOut "Semantic migration assessment already recorded for $assessFeature."; exit 0 }
    $kv = @('summary', $assessSummary, 'semantic_migration_revision', $script:FlLegacySemanticMigrationRevision)
    if ($assessRecords.Count -gt 0) { $kv += @('architectural_records', ($assessRecords -join "`n")) }
    FlStoreAppendRecord $featureStore 'semantic_assessment' $assessFeature '000-legacy-import' $kv
    FlOut "Recorded semantic migration assessment for $assessFeature."
    exit 0
}

if ($markSemanticComplete) {
    if ($auto) { [Console]::Error.WriteLine('Error: --auto and --mark-semantic-complete cannot be combined.'); exit 1 }
    $count = Get-FlLegacyImportedFeatureCount
    if ($count -eq 0) { [Console]::Error.WriteLine('Error: no imported legacy features are available to mark.'); exit 1 }
    $assessed = Get-FlLegacySemanticAssessmentCount
    $missing = @(Get-FlLegacySemanticUnassessedFeature)
    if ($missing.Count -gt 0) { [Console]::Error.WriteLine("Error: semantic migration is incomplete: assessed $assessed of $count imported feature(s). Missing: $($missing -join ',')."); exit 1 }
    $architecturalRecords = Get-FlLegacyArchitecturalRecordCount
    if ($architecturalRecords -eq 0) { [Console]::Error.WriteLine('Error: semantic migration is incomplete: no evidence-backed architectural records were recorded.'); exit 1 }
    if ((Get-FlLegacyTaggedArchitecturalRecordCount) -eq 0) { [Console]::Error.WriteLine('Error: semantic migration is incomplete: no architectural records have tags for site filtering.'); exit 1 }
    $store = FlStoreDir
    if (-not (Test-Path -LiteralPath $store -PathType Container)) { New-Item -ItemType Directory -Force -Path $store | Out-Null }
    [System.IO.File]::WriteAllText((Get-FlLegacySemanticMigrationPath), $script:FlLegacySemanticMigrationRevision + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
    FlOut "Marked semantic migration complete for $count imported feature(s), $assessed assessment(s), and $architecturalRecords architectural record(s)."
    exit 0
}

$legacyRoot = "$(FlDocsDir)/features"
$storeRoot = FlStoreDir
if (-not (Test-Path -LiteralPath $legacyRoot -PathType Container)) {
    if (-not $auto) { FlOut "Nothing to import — no legacy sessions under $legacyRoot." }
    exit 0
}
if (-not (Test-Path -LiteralPath $storeRoot -PathType Container)) { New-Item -ItemType Directory -Force -Path $storeRoot | Out-Null }
$script:imported = 0; $script:skipped = 0

function Test-ImportedRecord([string]$store, [string]$source) {
    if (-not (Test-Path -LiteralPath $store -PathType Leaf)) { return $false }
    $marker = '"imported_from":"' + (FlJsonEscape $source) + '"'
    return [bool](Select-String -LiteralPath $store -SimpleMatch -Quiet -Pattern $marker)
}

function Add-ImportedRecord([string]$store, [string]$type, [string]$feature, [string]$session, [string]$source, [string[]]$kv) {
    if (Test-ImportedRecord $store $source) { $script:skipped++; return }
    FlStoreAppendRecord $store $type $feature $session ($kv + @('imported_from', $source))
    $script:imported++
}

function Write-ImportWarning([string]$source) {
    [Console]::Error.WriteLine("Warning: skipped malformed legacy record in $source")
    $script:skipped++
}

# `where:` is written as a single backtick-quoted path by add-decision.sh, but backfilled
# decisions sometimes name two paths as two separate spans on the same line. Strip a wrapping
# pair only when the whole value is exactly that shape; otherwise keep the line as written rather
# than mis-strip and lose structure.
function ConvertFrom-WrappingBacktick([string]$s) {
    if ($s -match '^`([^`]*)`$') { return $matches[1] }
    return $s
}

function Clear-DecisionState {
    $script:inDecision = $false; $script:decisionTitle = ''; $script:decisionWhere = ''
    $script:decisionWhy = ''; $script:decisionAlt = ''; $script:decisionDesign = ''
    $script:decisionConst = ''; $script:decisionTrust = ''; $script:decisionBad = $false
    $script:lastField = ''
}

# Appends a wrapped continuation line to whichever decision field last matched. `trust` has
# nowhere to put prose (the store field is the binary verified/unverified the marker already set)
# so its continuation is consumed and discarded rather than accumulated.
function Add-Continuation([string]$text) {
    switch ($script:lastField) {
        'where' { $script:decisionWhere = "$script:decisionWhere $text" }
        'why' { $script:decisionWhy = "$script:decisionWhy $text" }
        'alternative' { $script:decisionAlt = "$script:decisionAlt $text" }
        'design' { $script:decisionDesign = "$script:decisionDesign $text" }
        'constitution' { $script:decisionConst = "$script:decisionConst $text" }
        default { } # 'trust', or empty: nothing to append to
    }
}

function Complete-ImportedDecision {
    if (-not $script:inDecision) { return }
    $script:decisionNumber++
    $source = "$script:sourceBase#decision-$script:decisionNumber"
    if (-not $script:decisionTitle -or -not $script:decisionWhere -or -not $script:decisionWhy -or -not $script:decisionTrust -or $script:decisionBad) {
        Write-ImportWarning $source
    } else {
        Add-ImportedRecord $script:store 'decision' $script:feature $script:session $source @(
            'title', $script:decisionTitle, 'where', $script:decisionWhere, 'why', $script:decisionWhy,
            'alternative', $script:decisionAlt, 'design', $script:decisionDesign,
            'constitution', $script:decisionConst, 'trust', $script:decisionTrust)
    }
    Clear-DecisionState
}

# A components/hard-won-condition bullet ends wherever `· status: (documented|follow-up)` lands,
# which the legacy writer sometimes put on the opening line and sometimes several wrapped lines
# later. Complete-KnowledgeBullet is only ever called once that suffix is present (or the bullet
# is abandoned by a heading/new bullet/EOF, in which case it is reported as malformed).
function Complete-KnowledgeBullet {
    if (-not $script:inKnowledge) { return }
    $marker = $null
    if ($script:knSection -eq 'components') {
        $script:componentNumber++
        $marker = "$script:sourceBase#component-$script:componentNumber"
    } else {
        $script:conditionNumber++
        $marker = "$script:sourceBase#condition-$script:conditionNumber"
    }
    $status = $null
    if ($script:knBody -match '^(.*)· status: (documented|follow-up)$') {
        $script:knBody = $matches[1].Trim()
        $status = $matches[2]
    }
    if (-not $script:knName -or -not $script:knBody -or -not $status) {
        Write-ImportWarning $marker
    } elseif ($script:knSection -eq 'components') {
        # The legacy template kept role and conditions in one prose field. Preserve that exact
        # text in both schema fields rather than guessing a split that was never encoded.
        Add-ImportedRecord $script:store 'component' $script:feature $script:session $marker @(
            'name', $script:knName, 'role', $script:knBody, 'conditions', $script:knBody, 'status', $status)
    } else {
        Add-ImportedRecord $script:store 'condition' $script:feature $script:session $marker @('subject', $script:knName, 'why', $script:knBody)
    }
    $script:inKnowledge = $false; $script:knName = ''; $script:knBody = ''; $script:knSection = ''
}

function Complete-KnowledgeBulletIfClosed {
    if ($script:knBody -match '· status: (documented|follow-up)$') { Complete-KnowledgeBullet }
}

function Import-LegacySession([string]$file) {
    $script:feature = Split-Path -Leaf (Split-Path -Parent (Split-Path -Parent $file))
    $script:session = [System.IO.Path]::GetFileNameWithoutExtension($file)
    $script:store = FlFeatureStorePath $script:feature
    $root = FlRepoRoot
    $script:sourceBase = $file.Substring($root.Length).TrimStart([char[]]@([char]92, [char]47)) -replace '\\', '/'
    $script:decisionNumber = 0; $script:componentNumber = 0; $script:conditionNumber = 0
    $script:inComment = $false; $section = ''
    Clear-DecisionState
    $script:inKnowledge = $false; $script:knName = ''; $script:knBody = ''; $script:knSection = ''
    # Split at the first closing bold span. A greedy regular expression would mistake later
    # emphasis in the explanatory prose for the close, and requiring a space after the close
    # rejects valid prose such as "**Windows**, so ...".
    $bulletPattern = '^- \*\*(.+?)\*\*(.*)$'
    $emDashPrefix = [string][char]0x2014 + ' '

    foreach ($line in [System.IO.File]::ReadAllLines($file)) {
        if ($script:inComment) {
            if ($line.Contains('-->')) { $script:inComment = $false }
            continue
        }
        if ($line.Contains('<!--')) {
            if (-not $line.Contains('-->')) { $script:inComment = $true }
            continue
        }
        if ($line.StartsWith('## Decision: ')) {
            Complete-ImportedDecision
            Complete-KnowledgeBullet
            $script:inDecision = $true
            $script:decisionTitle = $line.Substring('## Decision: '.Length)
            $section = ''
            continue
        }
        if ($script:inDecision) {
            if ($line.StartsWith('## ')) {
                Complete-ImportedDecision
            } else {
                # Trust only needs the leading ✓/⚠ marker; a backfilled decision often appends a
                # review note after it ("✓ verified — maintainer-confirmed …"), which the exact
                # string match this used to be would have flagged as malformed.
                if ($line.StartsWith('- **trust:** ' + [char]0x2713)) { $script:decisionTrust = 'verified'; $script:lastField = 'trust' }
                elseif ($line.StartsWith('- **trust:** ' + [char]0x26A0)) { $script:decisionTrust = 'unverified'; $script:lastField = 'trust' }
                elseif ($line.StartsWith('- **trust:** ')) { $script:decisionBad = $true; $script:lastField = '' }
                elseif ($line -match '^- \*\*where:\*\* (.*)$') { $script:decisionWhere = ConvertFrom-WrappingBacktick $matches[1]; $script:lastField = 'where' }
                elseif ($line -match '^- \*\*why:\*\* (.*)$') { $script:decisionWhy = $matches[1]; $script:lastField = 'why' }
                elseif ($line -match '^- \*\*alternative:\*\* (.*)$') { $script:decisionAlt = $matches[1]; $script:lastField = 'alternative' }
                elseif ($line -match '^- \*\*design:\*\* (.*)$') { $script:decisionDesign = $matches[1]; $script:lastField = 'design' }
                elseif ($line -match '^- \*\*constitution:\*\* (.*)$') { $script:decisionConst = $matches[1]; $script:lastField = 'constitution' }
                elseif ($line.StartsWith('- **')) {
                    # A well-formed field this schema doesn't define — e.g. a hand-added
                    # `- **note:**` on a backfilled decision. STORE.md has no slot for it, but
                    # every other field on this decision is still real, so drop just this bullet
                    # rather than fail the whole record the way a genuinely malformed line does.
                    if ($line -match '^- \*\*[A-Za-z][A-Za-z _-]*:\*\* ') { $script:lastField = '' }
                    else { $script:decisionBad = $true; $script:lastField = '' }
                } elseif ($script:lastField -and $line.Trim()) {
                    # A soft-wrapped continuation of the previous field's prose: markdown reflows
                    # a line break inside a paragraph as a space, so join the same way.
                    Add-Continuation $line.Trim()
                }
                continue
            }
        }
        if ($line.StartsWith('### Components')) { Complete-KnowledgeBullet; $section = 'components'; continue }
        if ($line.StartsWith('### Hard-won conditions')) { Complete-KnowledgeBullet; $section = 'conditions'; continue }
        if ($line.StartsWith('## ')) { Complete-KnowledgeBullet; $section = ''; continue }
        if ($section -eq 'components' -or $section -eq 'conditions') {
            if ($line -match $bulletPattern) {
                # A new bullet opening mid-accumulation means the previous one never reached its
                # status marker; complete it now so it is reported rather than silently discarded.
                Complete-KnowledgeBullet
                $script:inKnowledge = $true; $script:knSection = $section
                $script:knName = $matches[1]; $script:knBody = $matches[2]
                if ($script:knBody.StartsWith(' ')) { $script:knBody = $script:knBody.Substring(1) }
                if ($script:knBody.StartsWith($emDashPrefix)) { $script:knBody = $script:knBody.Substring($emDashPrefix.Length) }
                Complete-KnowledgeBulletIfClosed
            } elseif ($script:inKnowledge -and $line.StartsWith('- **')) {
                # A bullet-looking line broke the accumulation before its status marker.
                # Complete-KnowledgeBullet already reports the abandoned bullet with its own
                # numbered marker — do not warn twice.
                Complete-KnowledgeBullet
            } elseif ($script:inKnowledge -and $line.Trim()) {
                $script:knBody = "$script:knBody $($line.Trim())"
                Complete-KnowledgeBulletIfClosed
            } elseif ($line.StartsWith('- **')) {
                Write-ImportWarning "$script:sourceBase#knowledge"
            }
        }
    }
    Complete-ImportedDecision
    Complete-KnowledgeBullet
}

function Import-LegacyFeature([System.IO.DirectoryInfo]$featureDir) {
    $feature = $featureDir.Name
    $sessionsDir = Join-Path $featureDir.FullName 'sessions'
    if (-not (Test-Path -LiteralPath $sessionsDir -PathType Container)) { return }
    $sessionFiles = @(Get-ChildItem -LiteralPath $sessionsDir -Filter '*.md' -File -ErrorAction SilentlyContinue)
    if (-not $sessionFiles.Count) { return }
    foreach ($sessionFile in $sessionFiles) {
        Import-LegacySession $sessionFile.FullName
    }

    # Legacy Markdown establishes the feature but cannot truthfully recreate its historic branch
    # or native 0.3 sessions. Declare one explicit import session while leaving the imported
    # decisions/components/conditions attached to their original legacy session slugs.
    $store = FlFeatureStorePath $feature
    $root = FlRepoRoot
    $source = $featureDir.FullName.Substring($root.Length).TrimStart([char[]]@([char]92, [char]47)) -replace '\\', '/'
    Add-ImportedRecord $store 'feature' $feature 'none' "$source#feature" @(
        'slug', $feature, 'intent', 'Imported pre-0.3 session history.',
        'branch', "legacy-import/$feature", 'base_ref', 'legacy')
    Add-ImportedRecord $store 'session' $feature '000-legacy-import' "$source#backfill-session" @(
        'slug', '000-legacy-import', 'intent', 'Backfill pre-0.3 session history.')
}

foreach ($featureDir in @(Get-ChildItem -LiteralPath $legacyRoot -Directory -ErrorAction SilentlyContinue)) {
    Import-LegacyFeature $featureDir
}

# A parser correction can safely ask an already-migrated repository for one more scan. Mark this
# completed pass so ordinary commands do not repeatedly walk its legacy Markdown afterwards.
[System.IO.File]::WriteAllText((Get-FlLegacyImportRevisionPath), $script:FlLegacyImportRevision + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))

if (-not $auto) { FlOut "Imported $script:imported legacy record(s); skipped $script:skipped." }
