#!/usr/bin/env pwsh
# install.ps1 — install FluencyLoop onto a Windows machine (the PowerShell twin of install.sh).
# Copies the tool into %USERPROFILE%\.fluencyloop\lib, puts the `fluencyloop` CLI on PATH, installs
# the interactive skills user-wide (~/.claude/skills), and records VERSION/SOURCE for self upgrade.
#
# Usage: ./install.ps1 [-NoSkills]

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# $IsWindows is a read-only automatic var in PowerShell 7 but undefined in Windows PowerShell 5.x,
# so derive a portable flag (don't assign to the automatic var).
$onWindows = if (Test-Path variable:IsWindows) { $IsWindows } else { $env:OS -eq 'Windows_NT' }

$SRC = $PSScriptRoot
$installSkills = $true
foreach ($a in $args) { if ($a -eq '-NoSkills' -or $a -eq '--no-skills') { $installSkills = $false } }

$base = if ($env:FLUENCYLOOP_HOME) { $env:FLUENCYLOOP_HOME } else { Join-Path $HOME '.fluencyloop' }
$LIB = Join-Path $base 'lib'

function WriteTextLf([string]$path, [string]$text) {
    $dir = Split-Path -Parent $path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

# 1. Copy the tool into the lib dir (idempotent: refresh in place).
New-Item -ItemType Directory -Force -Path $LIB | Out-Null
foreach ($d in 'scripts', 'templates', 'skills') {
    $t = Join-Path $LIB $d
    if (Test-Path -LiteralPath $t) { Remove-Item -Recurse -Force $t }
}
Copy-Item -Recurse -Force -Path (Join-Path $SRC 'scripts') -Destination $LIB
Copy-Item -Recurse -Force -Path (Join-Path $SRC 'templates') -Destination $LIB
Copy-Item -Recurse -Force -Path (Join-Path $SRC 'skills') -Destination $LIB
Copy-Item -Force -Path (Join-Path $SRC 'fluencyloop.ps1') -Destination $LIB
Copy-Item -Force -Path (Join-Path $SRC 'fluencyloop.cmd') -Destination $LIB
Copy-Item -Force -Path (Join-Path $SRC 'VERSION') -Destination $LIB
WriteTextLf (Join-Path $LIB 'SOURCE') "$SRC`n"   # where `fluencyloop self upgrade` pulls from

# 2. Put the CLI on the PATH (Windows: add lib to the user PATH; the .cmd shim resolves the verb).
$pathAdded = $false
if ($onWindows) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User'); if (-not $userPath) { $userPath = '' }
    if (($userPath -split ';') -notcontains $LIB) {
        [Environment]::SetEnvironmentVariable('Path', ($LIB + ';' + $userPath), 'User')
        $pathAdded = $true
    }
}

# 3. Install skills user-wide so the agent sees them in every project.
$skillsDest = Join-Path $HOME '.claude/skills'
if ($installSkills) {
    New-Item -ItemType Directory -Force -Path $skillsDest | Out-Null
    Copy-Item -Recurse -Force -Path (Join-Path $SRC 'skills/*') -Destination $skillsDest
}

$version = (Get-Content -LiteralPath (Join-Path $SRC 'VERSION') -Raw).Trim()
Write-Output "FluencyLoop $version installed."
Write-Output "  lib:     $LIB"
Write-Output "  cli:     $(Join-Path $LIB 'fluencyloop.cmd')  (run as: fluencyloop)"
if ($installSkills) { Write-Output "  skills:  $skillsDest (user-wide)" }
Write-Output ''
if ($onWindows) {
    if ($pathAdded) { Write-Output "Added $LIB to your user PATH - open a new terminal for fluencyloop to resolve." }
} else {
    Write-Output "Non-Windows shell: add $LIB to your PATH to run fluencyloop (or use the bash install.sh)."
}
Write-Output "Next: cd into a project and run 'fluencyloop init'."
