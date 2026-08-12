# add-knowledge.ps1 — PowerShell port of add-knowledge.sh. Appends one session's component
# inventory and hard-won conditions as a validated batch. Its primary explicit-field form needs no
# pipe escaping; the historical compact pipe form remains supported for compatibility.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

$components = @(); $gotchas = @(); $structuredComponents = @(); $structuredGotchas = @()
$hasInput = $false; $featureOverride = ''; $sessionOverride = ''; $targetOverride = $false
$activeComponent = -1; $activeGotcha = -1
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        '--component' {
            $i++; $value = [string]$args[$i]; $hasInput = $true
            if ($value.Contains('|') -and ($i + 1 -ge $args.Count -or $args[$i + 1] -ne '--role')) { $components += $value; $activeComponent = -1 }
            else {
                $structuredComponents += [pscustomobject]@{ name = $value; role = ''; conditions = ''; status = 'documented' }
                $activeComponent = $structuredComponents.Count - 1
            }
            $activeGotcha = -1
        }
        '--role' {
            $i++; if ($activeComponent -lt 0) { throw 'Error: --role must follow an explicit --component.' }
            $structuredComponents[$activeComponent].role = [string]$args[$i]
        }
        '--conditions' {
            $i++; if ($activeComponent -lt 0) { throw 'Error: --conditions must follow an explicit --component.' }
            $structuredComponents[$activeComponent].conditions = [string]$args[$i]
        }
        '--status' {
            $i++; if ($activeComponent -lt 0) { throw 'Error: --status must follow an explicit --component.' }
            $structuredComponents[$activeComponent].status = [string]$args[$i]
        }
        '--gotcha' {
            $i++; $value = [string]$args[$i]; $hasInput = $true
            if ($value.Contains('|') -and ($i + 1 -ge $args.Count -or $args[$i + 1] -ne '--why')) { $gotchas += $value; $activeGotcha = -1 }
            else {
                $structuredGotchas += [pscustomobject]@{ subject = $value; why = '' }
                $activeGotcha = $structuredGotchas.Count - 1
            }
            $activeComponent = -1
        }
        '--why' {
            $i++; if ($activeGotcha -lt 0) { throw 'Error: --why must follow an explicit --gotcha.' }
            $structuredGotchas[$activeGotcha].why = [string]$args[$i]
        }
        '--feature'   { $i++; $featureOverride = [string]$args[$i]; $targetOverride = $true }
        '--session'   { $i++; $sessionOverride = [string]$args[$i]; $targetOverride = $true }
        default        { [Console]::Error.WriteLine("Unknown option: $($args[$i])"); exit 1 }
    }
}

FlRequireFluency

# Split a legacy pipe-delimited argument. A literal pipe is \|; other backslashes remain literal
# so ordinary prose and Windows paths do not need a special escape vocabulary.
function Split-FlKnowledgeField([string]$value, [int]$minFields, [int]$maxFields, [string]$flag) {
    $fields = [System.Collections.Generic.List[string]]::new()
    $field = [System.Text.StringBuilder]::new()
    $escaped = $false
    foreach ($character in $value.ToCharArray()) {
        if ($escaped) {
            if ($character -eq [char]124 -or $character -eq [char]92) { [void]$field.Append($character) }
            else { [void]$field.Append([char]92); [void]$field.Append($character) }
            $escaped = $false
            continue
        }
        if ($character -eq [char]92) {
            $escaped = $true
        } elseif ($character -eq [char]124) {
            $fields.Add($field.ToString())
            [void]$field.Clear()
        } else {
            [void]$field.Append($character)
        }
    }
    if ($escaped) { [void]$field.Append([char]92) }
    $fields.Add($field.ToString())
    if ($fields.Count -lt $minFields -or $fields.Count -gt $maxFields) {
        throw "Error: $flag needs $minFields-$maxFields pipe-separated fields; escape literal pipes as \|."
    }
    foreach ($item in $fields) {
        if (-not $item) { throw "Error: $flag fields cannot be empty." }
    }
    return $fields.ToArray()
}

if (-not $hasInput) {
    FlOut 'No knowledge records to append.'
    exit 0
}

if ($targetOverride -and ((-not $featureOverride) -or (-not $sessionOverride))) {
    [Console]::Error.WriteLine('Error: --feature and --session must be used together for a historical record.')
    exit 1
}

# Feature and session are always read from state, never caller-selected flags. The basename step
# preserves the transition path for a pre-0.3 state file containing a legacy session markdown path.
$session = $sessionOverride
if (-not $session) { $session = FlStateGet 'last_session' }
$session = [System.IO.Path]::GetFileNameWithoutExtension($session)
if (-not $session) {
    [Console]::Error.WriteLine("Error: no active session — open one with 'fluencyloop session `"<slice>`"' before recording knowledge.")
    exit 1
}
$feature = $featureOverride
if (-not $feature) { $feature = FlStateGet 'feature' }
if (-not $feature) {
    [Console]::Error.WriteLine('Error: no active feature in state.')
    exit 1
}

# Validate all entries before appending the first line, so a malformed later value cannot leave a
# batch partially captured.
foreach ($component in $components) {
    $parts = @(Split-FlKnowledgeField $component 3 4 '--component')
    $status = if ($parts.Count -eq 4) { $parts[3] } else { 'documented' }
    if ($status -notin @('documented', 'follow-up')) {
        [Console]::Error.WriteLine('Error: --component status must be documented or follow-up.')
        exit 1
    }
}
foreach ($component in $structuredComponents) {
    if (-not $component.name -or -not $component.role -or -not $component.conditions) {
        throw 'Error: an explicit --component requires nonempty --role and --conditions fields.'
    }
    if ($component.status -notin @('documented', 'follow-up')) {
        throw 'Error: --status must be documented or follow-up.'
    }
}
foreach ($gotcha in $gotchas) { $null = @(Split-FlKnowledgeField $gotcha 2 2 '--gotcha') }
foreach ($gotcha in $structuredGotchas) {
    if (-not $gotcha.subject -or -not $gotcha.why) {
        throw 'Error: an explicit --gotcha requires a nonempty --why field.'
    }
}

$store = FlFeatureStorePath $feature
$written = 0
foreach ($component in $components) {
    $parts = @(Split-FlKnowledgeField $component 3 4 '--component')
    $status = if ($parts.Count -eq 4) { $parts[3] } else { 'documented' }
    FlStoreAppendRecord $store 'component' $feature $session @(
        'name', $parts[0], 'role', $parts[1], 'conditions', $parts[2], 'status', $status)
    $written++
}
foreach ($component in $structuredComponents) {
    FlStoreAppendRecord $store 'component' $feature $session @(
        'name', $component.name, 'role', $component.role, 'conditions', $component.conditions, 'status', $component.status)
    $written++
}
foreach ($gotcha in $gotchas) {
    $parts = @(Split-FlKnowledgeField $gotcha 2 2 '--gotcha')
    FlStoreAppendRecord $store 'condition' $feature $session @('subject', $parts[0], 'why', $parts[1])
    $written++
}
foreach ($gotcha in $structuredGotchas) {
    FlStoreAppendRecord $store 'condition' $feature $session @('subject', $gotcha.subject, 'why', $gotcha.why)
    $written++
}

FlOut "Appended $written knowledge record(s) to $store"
