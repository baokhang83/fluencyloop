# Shared setup for the FluencyLoop Pester suite — the PowerShell mirror of tests/test_helper.bash.
# Each test runs in a throwaway git repo with an isolated FLUENCYLOOP_HOME, so nothing touches the
# developer's real repo, branches, or calibration profile.
#
# Scripts are invoked as `pwsh -File` subprocesses (like bats runs bash): they write to OS stdout
# via [Console]::Out.Write, which the call operator would not otherwise capture.

$script:Bin = (Resolve-Path "$PSScriptRoot/../../scripts/powershell").Path
$script:PwshExe = (Get-Process -Id $PID).Path
if (-not $script:PwshExe) { $script:PwshExe = 'pwsh' }

# Fresh git repo on `main` with one commit. Sets FLUENCYLOOP_HOME, cd's in, returns the repo path.
function New-TestRepo {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("fltest-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Set-Location -LiteralPath $dir
    git init -q -b main 2>&1 | Out-Null
    git config user.email 'test@example.com' 2>&1 | Out-Null
    git config user.name 'Test' 2>&1 | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $dir 'app.txt'), "a`nb`n")
    git add -A 2>&1 | Out-Null; git commit -q -m 'init' 2>&1 | Out-Null
    $top = (git rev-parse --show-toplevel)   # canonical path (git's view)
    Set-Location -LiteralPath $top
    $env:FLUENCYLOOP_HOME = Join-Path $top '.home'
    return $top
}

function Initialize-TestRepo {
    $dir = New-TestRepo
    & $script:PwshExe -NoProfile -File "$script:Bin/init.ps1" | Out-Null
    return $dir
}

# Isolated global FLUENCYLOOP_HOME (for the calibration profile/ledger — no repo needed).
function New-TestHome {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("flhome-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $env:FLUENCYLOOP_HOME = $dir
    return $dir
}

# Run a ported script in a subprocess; return its stdout as one string.
function Invoke-Fl {
    param([string]$Name)
    $out = & $script:PwshExe -NoProfile -File "$script:Bin/$Name" @args 2>$null
    return ($out -join "`n")
}

# Run a script; return its process exit code (for error-path assertions).
function Invoke-FlExit {
    param([string]$Name)
    & $script:PwshExe -NoProfile -File "$script:Bin/$Name" @args *> $null
    return $LASTEXITCODE
}

# Run a script; return stdout AND stderr merged as one string (like bats `run`).
function Invoke-FlAll {
    param([string]$Name)
    $out = & $script:PwshExe -NoProfile -File "$script:Bin/$Name" @args 2>&1
    return (($out | ForEach-Object { $_.ToString() }) -join "`n")
}

# Parse the last --json output into an object.
function Get-FlJson {
    param([string]$Name)
    (Invoke-Fl $Name @args) | ConvertFrom-Json
}
