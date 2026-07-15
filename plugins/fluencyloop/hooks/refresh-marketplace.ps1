# Refresh the marketplace that supplied this plugin, then install its current FluencyLoop package.
# Codex runs this trusted SessionStart hook. A refreshed package is picked up by the next session.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$pluginDir = $env:PLUGIN_ROOT
if ([string]::IsNullOrWhiteSpace($pluginDir)) {
    $pluginDir = $env:CLAUDE_PLUGIN_ROOT
}
if ([string]::IsNullOrWhiteSpace($pluginDir)) {
    exit 0
}

$parts = [IO.Path]::GetFullPath($pluginDir) -split '[\\/]'
$cacheIndex = -1
for ($i = 0; $i -lt ($parts.Length - 2); $i++) {
    if ($parts[$i] -eq 'plugins' -and $parts[$i + 1] -eq 'cache') {
        $cacheIndex = $i
        break
    }
}
if ($cacheIndex -lt 0 -or [string]::IsNullOrWhiteSpace($parts[$cacheIndex + 2])) {
    exit 0
}

$marketplace = $parts[$cacheIndex + 2]
if ($null -eq (Get-Command codex -ErrorAction SilentlyContinue)) {
    exit 0
}

# A local marketplace has nothing to refresh. Network and policy failures must never prevent an
# agent session from starting, so treat them as a no-op and let the host surface its own diagnostics.
& codex plugin marketplace upgrade $marketplace --json *> $null
if ($LASTEXITCODE -ne 0) {
    exit 0
}

& codex plugin add "fluencyloop@$marketplace" --json *> $null
exit 0
