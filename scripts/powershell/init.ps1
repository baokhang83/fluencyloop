# init.ps1 — PowerShell port of init.sh. Scaffold FluencyLoop into the current repo. Matches
# init.sh --json. Vendors the PowerShell scripts (the Windows-native equivalent of init.sh's
# scripts/bash) + templates into .fluencyloop/.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

$jsonMode = $false; $vendorSkills = $false
foreach ($a in $args) {
    if ($a -eq '--json') { $jsonMode = $true }
    elseif ($a -eq '--vendor-skills') { $vendorSkills = $true }
}

$root = FlRepoRoot
if (-not $root) {
    [Console]::Error.WriteLine("Error: 'fluencyloop init' must be run inside a git repository.")
    exit 1
}

$distRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$fluency = "$root/.fluencyloop"
$docs = FlDocsDir

New-Item -ItemType Directory -Force -Path "$fluency/scripts", "$fluency/templates", $docs | Out-Null
Copy-Item -Force -Path "$distRoot/scripts/powershell/*.ps1" -Destination "$fluency/scripts/"
Copy-Item -Force -Path "$distRoot/templates/*.md" -Destination "$fluency/templates/"

$constitution = FlConstitutionPath
$createdConstitution = 'false'
if (-not (Test-Path -LiteralPath $constitution)) {
    Copy-Item -Force -Path "$distRoot/templates/constitution.md" -Destination $constitution
    $createdConstitution = 'true'
}

$skillsDest = ''
if ($vendorSkills -and (Test-Path -LiteralPath "$distRoot/skills")) {
    $skillsDest = "$root/.claude/skills"
    New-Item -ItemType Directory -Force -Path $skillsDest | Out-Null
    Copy-Item -Recurse -Force -Path "$distRoot/skills/*" -Destination $skillsDest
}

# calibration is per-developer and never committed — guard against a repo vendoring one.
$gitignore = "$root/.gitignore"
$needle = '.fluencyloop/**/calibration.md'
$hasGuard = (Test-Path -LiteralPath $gitignore) -and (@(Get-Content -LiteralPath $gitignore) -contains $needle)
if (-not $hasGuard) {
    [System.IO.File]::AppendAllText($gitignore, "`n# FluencyLoop: calibration is per-developer and never committed`n$needle`n", (New-Object System.Text.UTF8Encoding($false)))
}

# push.autoSetupRemote so the first push on a new feature branch sets upstream automatically.
$autoRemoteSet = 'false'
$cur = & git -C $root config --local push.autoSetupRemote 2>$null
if ($cur -ne 'true') { & git -C $root config --local push.autoSetupRemote true; $autoRemoteSet = 'true' }

if ($jsonMode) {
    FlOut (FlEmitJson @(
        'fluency_dir', $fluency, 'docs_dir', $docs, 'constitution', $constitution,
        'constitution_created', $createdConstitution, 'skills_vendored', ([string]$vendorSkills).ToLowerInvariant(),
        'skills_dir', $skillsDest, 'push_autoremote_set', $autoRemoteSet))
} else {
    FlOut 'Initialised FluencyLoop'
    FlOut "  state:        $fluency (scripts + templates)"
    FlOut "  docs:         $docs (constitution, designs, session journals)"
    if ($autoRemoteSet -eq 'true') { FlOut '  git:          push.autoSetupRemote=true (feature branches push without --set-upstream)' }
    if ($createdConstitution -eq 'true') { FlOut "  constitution: $constitution (empty — written from your first plan or feature)" }
    if ($skillsDest) { FlOut "  skills:       $skillsDest (vendored into repo)" }
    else { FlOut '  skills:       user-wide (~/.claude/skills); pass --vendor-skills to commit them here' }
}
