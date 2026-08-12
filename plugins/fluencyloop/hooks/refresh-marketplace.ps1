# Refresh the marketplace that supplied this plugin, then install its current FluencyLoop package.
# Codex and Claude Code both run this trusted SessionStart hook. A refreshed package is picked up
# by the next session.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Each host exports its own plugin-root variable, and that is the only trustworthy signal for which
# host started this session. Dispatch on it rather than on which CLI happens to be installed: a
# developer with both CLIs would otherwise have a Claude session upgrade the Codex package, since
# the two installs are separate trees that must refresh independently.
$pluginDir = $env:PLUGIN_ROOT
$hostKind = $null
if (-not [string]::IsNullOrWhiteSpace($pluginDir)) {
    $hostKind = 'codex'
}
else {
    $pluginDir = $env:CLAUDE_PLUGIN_ROOT
    if (-not [string]::IsNullOrWhiteSpace($pluginDir)) {
        $hostKind = 'claude'
    }
}
if ($null -eq $hostKind) {
    exit 0
}

$hookEvent = if ($args -contains '--session-end') { 'session-end' } else { 'session-start' }
$sessionId = $null
try {
    $payload = [Console]::In.ReadToEnd()
    if (-not [string]::IsNullOrWhiteSpace($payload)) {
        $candidate = [string](($payload | ConvertFrom-Json -ErrorAction Stop).session_id)
        if ($candidate -match '^[A-Za-z0-9._-]{1,256}$') { $sessionId = $candidate }
    }
} catch {
    $sessionId = $null
}

# Codex's PLUGIN_ROOT already points at this bundle (plugins/fluencyloop/), so the launcher sits
# right beside this hook. Claude's CLAUDE_PLUGIN_ROOT points at the repository root instead — the
# marketplace entry that supplies Claude uses `"source": "."`, so the whole checkout is the plugin
# root and the launcher is nested under plugins/fluencyloop/. Try both rather than assuming one.
function Resolve-Launcher {
    param([string]$Dir)
    foreach ($candidate in @((Join-Path $Dir 'fluencyloop.ps1'), (Join-Path $Dir 'plugins/fluencyloop/fluencyloop.ps1'))) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return $null
}

# A SessionStart lease keeps the reader alive even when no browser has requested it recently.
# SessionEnd removes only its own lease: two agents can use the same initialized project without
# either closing the other agent’s reader.
function Ensure-LocalSite {
    $launcher = Resolve-Launcher $pluginDir
    if (-not $launcher) { return }
    $root = (& git rev-parse --show-toplevel 2>$null | Select-Object -First 1)
    $gitExitCode = if (Test-Path Variable:LASTEXITCODE) { $LASTEXITCODE } else { 0 }
    if ($gitExitCode -ne 0 -or -not $root) { return }
    if (-not (Test-Path -LiteralPath (Join-Path $root '.fluencyloop') -PathType Container)) { return }
    # The dispatcher uses `exit`; run it in a child host so it cannot skip this hook's marketplace
    # refresh below.
    $hostExe = (Get-Process -Id $PID).Path
    if ($sessionId) {
        & $hostExe -NoProfile -ExecutionPolicy Bypass -File $launcher site --session-start $sessionId --json *> $null
        # Skills can announce the address, but opening the browser is an interaction guarantee.
        # Persist the first request with the managed reader so later workflow stages reuse its tab.
        & $hostExe -NoProfile -ExecutionPolicy Bypass -File $launcher site --ensure --open-once --json *> $null
    } else {
        # Retain compatibility with hosts that do not pass a hook payload.
        & $hostExe -NoProfile -ExecutionPolicy Bypass -File $launcher site --ensure --open-once --json *> $null
    }
}

function Release-LocalSite {
    if (-not $sessionId) { return }
    $launcher = Resolve-Launcher $pluginDir
    if (-not $launcher) { return }
    $root = (& git rev-parse --show-toplevel 2>$null | Select-Object -First 1)
    $gitExitCode = if (Test-Path Variable:LASTEXITCODE) { $LASTEXITCODE } else { 0 }
    if ($gitExitCode -ne 0 -or -not $root) { return }
    if (-not (Test-Path -LiteralPath (Join-Path $root '.fluencyloop') -PathType Container)) { return }
    $hostExe = (Get-Process -Id $PID).Path
    & $hostExe -NoProfile -ExecutionPolicy Bypass -File $launcher site --session-end $sessionId --json *> $null
}

if ($hookEvent -eq 'session-end') {
    Release-LocalSite
    exit 0
}

Ensure-LocalSite

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

# A local marketplace has nothing to refresh. Network and policy failures must never prevent an
# agent session from starting, so treat them as a no-op and let the host surface its own diagnostics.
if ($hostKind -eq 'codex') {
    if ($null -eq (Get-Command codex -ErrorAction SilentlyContinue)) {
        exit 0
    }

    & codex plugin marketplace upgrade $marketplace --json *> $null
    if ($LASTEXITCODE -ne 0) {
        exit 0
    }

    & codex plugin add "fluencyloop@$marketplace" --json *> $null
}
else {
    if ($null -eq (Get-Command claude -ErrorAction SilentlyContinue)) {
        exit 0
    }

    & claude plugin marketplace update $marketplace *> $null
    if ($LASTEXITCODE -ne 0) {
        exit 0
    }

    # Claude Code resolves an update only for a marketplace-qualified plugin name.
    & claude plugin update "fluencyloop@$marketplace" *> $null
}
exit 0
