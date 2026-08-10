# add-concept.ps1 — PowerShell port of add-concept.sh. Appends architectural concepts and
# relations to the global store stream without reading JSONL.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

$name = ''; $problem = ''; $how = ''; $realizedBy = @(); $tags = @(); $relations = @(); $featureOverride = ''; $sessionOverride = ''; $targetOverride = $false
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        '--name'        { $i++; $name = [string]$args[$i] }
        '--problem'     { $i++; $problem = [string]$args[$i] }
        '--how'         { $i++; $how = [string]$args[$i] }
        '--realized-by' { $i++; $realizedBy += [string]$args[$i] }
        '--tag'         { $i++; $tags += [string]$args[$i] }
        '--relate'      { $i++; $relations += [string]$args[$i] }
        '--feature'     { $i++; $featureOverride = [string]$args[$i]; $targetOverride = $true }
        '--session'     { $i++; $sessionOverride = [string]$args[$i]; $targetOverride = $true }
        default         { [Console]::Error.WriteLine("Unknown option: $($args[$i])"); exit 1 }
    }
}

FlRequireFluency

$conceptRequested = [bool]($name + $problem + $how)
if ($conceptRequested) {
    if (-not $name) { [Console]::Error.WriteLine('Error: --name is required for a concept.'); exit 1 }
    if (-not $problem) { [Console]::Error.WriteLine('Error: --problem is required for a concept.'); exit 1 }
    if (-not $how) { [Console]::Error.WriteLine('Error: --how is required for a concept.'); exit 1 }
    if ($realizedBy.Count -eq 0) { [Console]::Error.WriteLine('Error: --realized-by is required for a concept.'); exit 1 }
} elseif ($realizedBy.Count -gt 0) {
    [Console]::Error.WriteLine('Error: --realized-by requires --name, --problem, and --how.')
    exit 1
} elseif ($tags.Count -gt 0) {
    [Console]::Error.WriteLine('Error: --tag requires --name, --problem, and --how.')
    exit 1
}

if (-not $conceptRequested -and $relations.Count -eq 0) {
    [Console]::Error.WriteLine('Error: provide a concept or at least one --relate <from|to|kind>.')
    exit 1
}

if ($targetOverride -and ((-not $featureOverride) -or (-not $sessionOverride))) {
    [Console]::Error.WriteLine('Error: --feature and --session must be used together for a historical record.')
    exit 1
}

$feature = $featureOverride
if (-not $feature) { $feature = FlStateGet 'feature' }
if (-not $feature) { $feature = FlCurrentFeatureSlug }
if (-not $feature) { $feature = 'global' }
$session = $sessionOverride
if (-not $session) { $session = FlStateGet 'last_session' }
$session = [System.IO.Path]::GetFileNameWithoutExtension($session)
if (-not $session) { $session = 'none' }
$store = FlConceptsStorePath

if ($conceptRequested) {
    $fields = @('name', $name, 'problem', $problem, 'how', $how, 'realized_by', ($realizedBy -join "`n"))
    # Tags are optional, so an absent one leaves the field out entirely rather than writing an
    # empty string: the schema asks writers to omit what they have nothing to say about.
    if ($tags.Count -gt 0) { $fields += @('tags', ($tags -join "`n")) }
    FlStoreAppendRecord $store 'concept' $feature $session $fields
}

foreach ($relation in $relations) {
    $parts = @($relation -split '\|', 4)
    if ($parts.Count -ne 3 -or -not $parts[0] -or -not $parts[1] -or -not $parts[2]) {
        [Console]::Error.WriteLine('Error: --relate must be <from|to|kind>.')
        exit 1
    }
    FlStoreAppendRecord $store 'relation' $feature $session @('from', $parts[0], 'to', $parts[1], 'kind', $parts[2])
}

if ($conceptRequested) {
    FlOut "Appended concept `"$name`" to $store"
} elseif ($relations.Count -eq 1) {
    FlOut "Appended relation to $store"
} else {
    FlOut "Appended $($relations.Count) relations to $store"
}
