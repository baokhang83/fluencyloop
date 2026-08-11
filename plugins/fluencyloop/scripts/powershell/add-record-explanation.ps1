# add-record-explanation.ps1 — PowerShell port of the architectural-record explanation writer.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"
FlRequireFluency

$record = ''; $context = ''; $decision = ''; $mechanism = ''; $consequences = ''
$diagram = ''; $diagramType = ''; $diagramAlt = ''
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        '--record'       { $i++; $record = [string]$args[$i] }
        '--context'      { $i++; $context = [string]$args[$i] }
        '--decision'     { $i++; $decision = [string]$args[$i] }
        '--mechanism'    { $i++; $mechanism = [string]$args[$i] }
        '--consequences' { $i++; $consequences = [string]$args[$i] }
        '--diagram'      { $i++; $diagram = [string]$args[$i] }
        '--diagram-type' { $i++; $diagramType = [string]$args[$i] }
        '--diagram-alt'  { $i++; $diagramAlt = [string]$args[$i] }
        default { [Console]::Error.WriteLine("Unknown option: $($args[$i])"); exit 1 }
    }
}

foreach ($item in @(@{ Name = 'record'; Value = $record }, @{ Name = 'context'; Value = $context },
        @{ Name = 'decision'; Value = $decision }, @{ Name = 'mechanism'; Value = $mechanism },
        @{ Name = 'consequences'; Value = $consequences })) {
    if (-not $item.Value) { [Console]::Error.WriteLine("Error: --$($item.Name) is required."); exit 1 }
}

if ($diagram -or $diagramType -or $diagramAlt) {
    if (-not $diagram) { [Console]::Error.WriteLine('Error: --diagram is required with diagram metadata.'); exit 1 }
    if (-not $diagramType) { [Console]::Error.WriteLine('Error: --diagram-type is required with --diagram.'); exit 1 }
    if (-not $diagramAlt) { [Console]::Error.WriteLine('Error: --diagram-alt is required with --diagram.'); exit 1 }
    if ($diagram -notmatch '^docs/fluencyloop/diagrams/records/[A-Za-z0-9][A-Za-z0-9._-]*\.html$') {
        [Console]::Error.WriteLine('Error: --diagram must be a safe project-relative HTML file under docs/fluencyloop/diagrams/records/.')
        exit 1
    }
    if (-not (Test-Path -LiteralPath (Join-Path (FlRepoRoot) $diagram) -PathType Leaf)) {
        [Console]::Error.WriteLine('Error: --diagram must name an existing project file.')
        exit 1
    }
}

$feature = FlStateGet 'feature'
if (-not $feature) { $feature = FlCurrentFeatureSlug }
if (-not $feature) { $feature = 'global' }
$session = [System.IO.Path]::GetFileNameWithoutExtension((FlStateGet 'last_session'))
if (-not $session) { $session = 'none' }

$fields = @('record', $record, 'context', $context, 'decision', $decision, 'mechanism', $mechanism, 'consequences', $consequences)
if ($diagram) { $fields += @('diagram_path', $diagram, 'diagram_type', $diagramType, 'diagram_alt', $diagramAlt) }
FlStoreAppendRecord (FlConceptsStorePath) 'record_explanation' $feature $session $fields
FlOut "Appended explanation for architectural record `"$record`" to $(FlConceptsStorePath)"
