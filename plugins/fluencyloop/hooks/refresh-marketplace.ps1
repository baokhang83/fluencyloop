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
$marketplace = $null
for ($i = 0; $i -lt ($parts.Length - 2); $i++) {
    if ($parts[$i] -eq 'plugins' -and $parts[$i + 1] -eq 'cache') {
        $marketplace = $parts[$i + 2]
        break
    }
    if ($parts[$i] -eq 'marketplaces' -and $parts[$i + 2] -eq 'plugins') {
        $marketplace = $parts[$i + 1]
        break
    }
}
if ([string]::IsNullOrWhiteSpace($marketplace)) {
    exit 0
}

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
