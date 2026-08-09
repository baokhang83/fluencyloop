# import-legacy.ps1 — PowerShell port of import-legacy.sh. Reads rigid legacy session markdown
# without changing it, then appends marked store records. The imported_from marker makes re-runs
# idempotent without parsing JSON.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"
$env:FLUENCYLOOP_IMPORTING = '1'

$auto = $false
foreach ($arg in $args) {
    if ($arg -eq '--auto') { $auto = $true }
    else { [Console]::Error.WriteLine("Unknown option: $arg"); exit 1 }
}
FlRequireFluency

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

function Clear-DecisionState {
    $script:inDecision = $false; $script:decisionTitle = ''; $script:decisionWhere = ''
    $script:decisionWhy = ''; $script:decisionAlt = ''; $script:decisionDesign = ''
    $script:decisionConst = ''; $script:decisionTrust = ''; $script:decisionBad = $false
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

function Import-LegacySession([string]$file) {
    $script:feature = Split-Path -Leaf (Split-Path -Parent (Split-Path -Parent $file))
    $script:session = [System.IO.Path]::GetFileNameWithoutExtension($file)
    $script:store = FlFeatureStorePath $script:feature
    $root = FlRepoRoot
    $script:sourceBase = $file.Substring($root.Length).TrimStart([char[]]@([char]92, [char]47)) -replace '\\', '/'
    $script:decisionNumber = 0; $script:componentNumber = 0; $script:conditionNumber = 0
    $script:inComment = $false; $section = ''
    Clear-DecisionState
    $verifiedTrust = ([string][char]0x2713) + ' verified'
    $unverifiedTrust = ([string][char]0x26A0) + ' not independently verified'
    $bulletPattern = '^- \*\*(.+)\*\* ' + [char]0x2014 + ' (.+) ' + [char]0x00B7 + ' status: (documented|follow-up)$'

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
            $script:inDecision = $true
            $script:decisionTitle = $line.Substring('## Decision: '.Length)
            $section = ''
            continue
        }
        if ($script:inDecision) {
            if ($line.StartsWith('## ')) {
                Complete-ImportedDecision
            } else {
                if ($line -eq "- **trust:** $verifiedTrust") { $script:decisionTrust = 'verified' }
                elseif ($line -eq "- **trust:** $unverifiedTrust") { $script:decisionTrust = 'unverified' }
                elseif ($line.StartsWith('- **trust:** ')) { $script:decisionBad = $true }
                elseif ($line -match '^- \*\*where:\*\* `([^`]*)`$') { $script:decisionWhere = $matches[1] }
                elseif ($line -match '^- \*\*why:\*\* (.*)$') { $script:decisionWhy = $matches[1] }
                elseif ($line -match '^- \*\*alternative:\*\* (.*)$') { $script:decisionAlt = $matches[1] }
                elseif ($line -match '^- \*\*design:\*\* (.*)$') { $script:decisionDesign = $matches[1] }
                elseif ($line -match '^- \*\*constitution:\*\* (.*)$') { $script:decisionConst = $matches[1] }
                elseif ($line.StartsWith('- **')) { $script:decisionBad = $true }
                continue
            }
        }
        if ($line.StartsWith('### Components')) { $section = 'components'; continue }
        if ($line.StartsWith('### Hard-won conditions')) { $section = 'conditions'; continue }
        if ($line.StartsWith('## ')) { $section = ''; continue }
        if ($line -match $bulletPattern) {
            if ($section -eq 'components') {
                $script:componentNumber++
                Add-ImportedRecord $script:store 'component' $script:feature $script:session "$script:sourceBase#component-$script:componentNumber" @(
                    'name', $matches[1], 'role', $matches[2], 'conditions', $matches[2], 'status', $matches[3])
            } elseif ($section -eq 'conditions') {
                $script:conditionNumber++
                Add-ImportedRecord $script:store 'condition' $script:feature $script:session "$script:sourceBase#condition-$script:conditionNumber" @('subject', $matches[1], 'why', $matches[2])
            }
        } elseif ($line.StartsWith('- **') -and ($section -eq 'components' -or $section -eq 'conditions')) {
            Write-ImportWarning "$script:sourceBase#knowledge"
        }
    }
    Complete-ImportedDecision
}

foreach ($featureDir in @(Get-ChildItem -LiteralPath $legacyRoot -Directory -ErrorAction SilentlyContinue)) {
    $sessionsDir = Join-Path $featureDir.FullName 'sessions'
    if (-not (Test-Path -LiteralPath $sessionsDir -PathType Container)) { continue }
    foreach ($sessionFile in @(Get-ChildItem -LiteralPath $sessionsDir -Filter '*.md' -File -ErrorAction SilentlyContinue)) {
        Import-LegacySession $sessionFile.FullName
    }
}

if (-not $auto) { FlOut "Imported $script:imported legacy record(s); skipped $script:skipped." }
