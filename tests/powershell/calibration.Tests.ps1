# calibration.ps1 — mirrors tests/calibration.bats.

Describe 'calibration.ps1' {
    BeforeAll { . "$PSScriptRoot/_helper.ps1" }
    BeforeEach { $script:testHome = New-TestHome }
    AfterEach {
        Set-Location -LiteralPath $PSScriptRoot
        if ($script:testHome) { Remove-Item -Recurse -Force -LiteralPath $script:testHome -ErrorAction SilentlyContinue }
    }

    It 'show before init errors and points at init' {
        (Invoke-FlExit 'calibration.ps1' 'show') | Should -Not -Be 0
        (Invoke-FlAll 'calibration.ps1' 'show') | Should -Match 'calibration init'
    }

    It 'init creates the profile; a second init does not clobber it' {
        (Invoke-FlExit 'calibration.ps1' 'init') | Should -Be 0
        "$script:testHome/calibration.md" | Should -Exist
        Add-Content -LiteralPath "$script:testHome/calibration.md" -Value 'java: fluent'
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'init' | Out-Null
        (Get-Content -Raw "$script:testHome/calibration.md") | Should -Match 'java: fluent'
    }

    It 'the seeded profile documents the four levels' {
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'init' | Out-Null
        $c = Get-Content -Raw "$script:testHome/calibration.md"
        foreach ($lvl in 'fluent', 'familiar', 'learning', 'new') { $c | Should -Match $lvl }
    }

    It 'show --json is an empty map when no profile lines exist' {
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'init' | Out-Null
        (Invoke-Fl 'calibration.ps1' 'show' '--json') | Should -Be '{}'
    }

    It 'show --json parses dimension:level, keeps only the level, drops invalid' {
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'init' | Out-Null
        Add-Content -LiteralPath "$script:testHome/calibration.md" -Value "java: fluent`nreactive: learning — note · 2026-07-13`nk8s: new`nmaven.plugin: familiar`nbogus: banana"
        $j = Get-FlJson 'calibration.ps1' 'show' '--json'
        $j.java | Should -Be 'fluent'
        $j.reactive | Should -Be 'learning'
        $j.k8s | Should -Be 'new'
        $j.'maven.plugin' | Should -Be 'familiar'
        $j.PSObject.Properties.Name | Should -Not -Contain 'bogus'
    }

    It 'an unknown subcommand exits non-zero' {
        (Invoke-FlExit 'calibration.ps1' 'frobnicate') | Should -Not -Be 0
    }

    It 'signal appends to the ledger; a bad signal type is rejected' {
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'init' | Out-Null
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'signal' 'java' 'wave' | Out-Null
        "$script:testHome/signals.log" | Should -Exist
        (Get-Content -Raw "$script:testHome/signals.log") | Should -Match 'java wave'
        (Invoke-FlExit 'calibration.ps1' 'signal' 'java' 'bogus') | Should -Not -Be 0
    }

    It 'compact promotes after repeated wave-throughs (threshold 2)' {
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'init' | Out-Null
        Add-Content -LiteralPath "$script:testHome/calibration.md" -Value 'java: learning'
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'signal' 'java' 'wave' | Out-Null
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'signal' 'java' 'wave' | Out-Null
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'compact' | Out-Null
        (Get-FlJson 'calibration.ps1' 'show' '--json').java | Should -Be 'familiar'
    }

    It 'compact demotes on deeper-asks / corrections' {
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'init' | Out-Null
        Add-Content -LiteralPath "$script:testHome/calibration.md" -Value 'reactive: familiar'
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'signal' 'reactive' 'deeper' | Out-Null
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'signal' 'reactive' 'correct' | Out-Null
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'compact' | Out-Null
        (Get-FlJson 'calibration.ps1' 'show' '--json').reactive | Should -Be 'learning'
    }

    It 'signals below the threshold do not move the level' {
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'init' | Out-Null
        Add-Content -LiteralPath "$script:testHome/calibration.md" -Value 'k8s: new'
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'signal' 'k8s' 'wave' | Out-Null
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'compact' | Out-Null
        (Get-FlJson 'calibration.ps1' 'show' '--json').k8s | Should -Be 'new'
    }

    It 'compact consumes the ledger; --dry-run neither applies nor consumes' {
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'init' | Out-Null
        Add-Content -LiteralPath "$script:testHome/calibration.md" -Value 'java: learning'
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'signal' 'java' 'wave' | Out-Null
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'signal' 'java' 'wave' | Out-Null
        (Invoke-Fl 'calibration.ps1' 'compact' '--dry-run') | Should -Match 'java: learning -> familiar'
        (Get-FlJson 'calibration.ps1' 'show' '--json').java | Should -Be 'learning'          # not applied
        (Get-Content -Raw "$script:testHome/signals.log") | Should -Match 'java wave'             # not consumed
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'compact' | Out-Null
        (Get-FlJson 'calibration.ps1' 'show' '--json').java | Should -Be 'familiar'           # applied
        (Get-Content -Raw "$script:testHome/signals.log") | Should -Not -Match 'java wave'        # consumed
    }

    It 'levels clamp: promoting fluent stays fluent' {
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'init' | Out-Null
        Add-Content -LiteralPath "$script:testHome/calibration.md" -Value 'java: fluent'
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'signal' 'java' 'wave' | Out-Null
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'signal' 'java' 'wave' | Out-Null
        & $script:PwshExe -NoProfile -File "$script:Bin/calibration.ps1" 'compact' | Out-Null
        (Get-FlJson 'calibration.ps1' 'show' '--json').java | Should -Be 'fluent'
    }
}
