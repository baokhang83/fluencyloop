# add-principle.ps1 — PowerShell port of add-principle.sh. Appends a developer-stated
# constitution principle to the global store without reading or rewriting prior records.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

$number = ''; $title = ''; $rule = ''; $why = ''
for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        '--number' { $i++; $number = [string]$args[$i] }
        '--title'  { $i++; $title = [string]$args[$i] }
        '--rule'   { $i++; $rule = [string]$args[$i] }
        '--why'    { $i++; $why = [string]$args[$i] }
        default    { [Console]::Error.WriteLine("Unknown option: $($args[$i])"); exit 1 }
    }
}

FlRequireFluency

if (-not $number) { [Console]::Error.WriteLine('Error: --number is required.'); exit 1 }
if (-not $title) { [Console]::Error.WriteLine('Error: --title is required.'); exit 1 }
if (-not $rule) { [Console]::Error.WriteLine('Error: --rule is required.'); exit 1 }
if (-not $why) { [Console]::Error.WriteLine('Error: --why is required.'); exit 1 }
if ($number -notmatch '^§[1-9][0-9]*$') {
    [Console]::Error.WriteLine('Error: --number must be a constitution citation such as §1.')
    exit 1
}

$store = FlConceptsStorePath
FlStoreAppendRecord $store 'principle' 'global' 'none' @(
    'number', $number, 'title', $title, 'rule', $rule, 'why', $why)
FlOut "Appended principle $number to $store"
