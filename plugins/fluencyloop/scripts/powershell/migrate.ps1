# migrate.ps1 — PowerShell port of migrate.sh. One-time move of human docs from the pre-refactor
# .fluencyloop/ location to docs/fluencyloop/. Idempotent. Matches migrate.sh --json.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

$jsonMode = $false; $dryRun = $false
foreach ($a in $args) {
    if ($a -eq '--json') { $jsonMode = $true }
    elseif ($a -eq '--dry-run') { $dryRun = $true }
}

FlRequireFluency

$oldFluency = FlFluencyDir
$docs = FlDocsDir
$moved = @()

function MovePath([string]$src, [string]$dest) {
    if (-not (Test-Path -LiteralPath $src)) { return }
    if (Test-Path -LiteralPath $dest) {
        [Console]::Error.WriteLine("Skip: $dest already exists (leaving $src in place).")
        return
    }
    $script:moved += "$src -> $dest"
    if ($dryRun) { return }
    $ddir = Split-Path -Parent $dest
    if ($ddir -and -not (Test-Path -LiteralPath $ddir)) { New-Item -ItemType Directory -Force -Path $ddir | Out-Null }
    & git ls-files --error-unmatch $src *> $null
    if ($LASTEXITCODE -eq 0) { & git mv $src $dest } else { Move-Item -LiteralPath $src -Destination $dest }
}

MovePath "$oldFluency/constitution.md" "$docs/constitution.md"
MovePath "$oldFluency/features" "$docs/features"

if ($jsonMode) {
    $files = ($moved | ForEach-Object { '"' + (FlJsonEscape $_) + '"' }) -join ', '
    $json = '{"docs_dir":"' + (FlJsonEscape $docs) + '","dry_run":' + ([string]$dryRun).ToLowerInvariant() +
            ',"moved_count":' + $moved.Count + ',"moved":[' + $files + ']}'
    FlOut $json
} else {
    if ($moved.Count -eq 0) {
        FlOut "Nothing to migrate — docs are already under $docs (or none exist yet)."
    } else {
        if ($dryRun) { FlOut 'Would migrate (dry run):' } else { FlOut "Migrated to ${docs}:" }
        foreach ($m in $moved) { FlOut "  $m" }
        if (-not $dryRun) { FlOut 'Review and commit the move.' }
    }
}
