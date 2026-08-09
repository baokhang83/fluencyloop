# add-knowledge.ps1 — PowerShell port of add-knowledge.sh. Appends one session's component
# inventory and hard-won conditions as a validated batch.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

$components = @(); $gotchas = @(); $hasInput = $false
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        '--component' { $i++; $components += [string]$args[$i]; $hasInput = $true }
        '--gotcha'    { $i++; $gotchas += [string]$args[$i]; $hasInput = $true }
        default        { [Console]::Error.WriteLine("Unknown option: $($args[$i])"); exit 1 }
    }
}

FlRequireFluency

# Split a pipe-delimited argument. A literal pipe is \| and a literal backslash is \\; accepting
# other escapes would silently alter prose. Returning values instead of printing them preserves
# whitespace and newlines inside a field.
function Split-FlKnowledgeField([string]$value, [int]$minFields, [int]$maxFields, [string]$flag) {
    $fields = [System.Collections.Generic.List[string]]::new()
    $field = [System.Text.StringBuilder]::new()
    $escaped = $false
    foreach ($character in $value.ToCharArray()) {
        if ($escaped) {
            if ($character -ne [char]124 -and $character -ne [char]92) {
                throw "Error: $flag only permits \| and \\ escapes."
            }
            [void]$field.Append($character)
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
    if ($escaped) { throw "Error: $flag cannot end with an escape." }
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

# Feature and session are always read from state, never caller-selected flags. The basename step
# preserves the transition path for a pre-0.3 state file containing a legacy session markdown path.
$session = FlStateGet 'last_session'
$session = [System.IO.Path]::GetFileNameWithoutExtension($session)
if (-not $session) {
    [Console]::Error.WriteLine("Error: no active session — open one with 'fluencyloop session `"<slice>`"' before recording knowledge.")
    exit 1
}
$feature = FlStateGet 'feature'
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
foreach ($gotcha in $gotchas) { $null = @(Split-FlKnowledgeField $gotcha 2 2 '--gotcha') }

$store = FlFeatureStorePath $feature
$written = 0
foreach ($component in $components) {
    $parts = @(Split-FlKnowledgeField $component 3 4 '--component')
    $status = if ($parts.Count -eq 4) { $parts[3] } else { 'documented' }
    FlStoreAppendRecord $store 'component' $feature $session @(
        'name', $parts[0], 'role', $parts[1], 'conditions', $parts[2], 'status', $status)
    $written++
}
foreach ($gotcha in $gotchas) {
    $parts = @(Split-FlKnowledgeField $gotcha 2 2 '--gotcha')
    FlStoreAppendRecord $store 'condition' $feature $session @('subject', $parts[0], 'why', $parts[1])
    $written++
}

FlOut "Appended $written knowledge record(s) to $store"
