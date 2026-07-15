# fluencyloop.ps1 dispatcher — mirrors tests/cli.bats.

Describe 'fluencyloop.ps1 (dispatcher)' {
    BeforeAll {
        . "$PSScriptRoot/_helper.ps1"
        $script:Cli = (Resolve-Path "$PSScriptRoot/../../plugins/fluencyloop/fluencyloop.ps1").Path
        $script:Version = (Get-Content -Raw (Resolve-Path "$PSScriptRoot/../../plugins/fluencyloop/VERSION").Path).Trim()
    }
    AfterEach {
        Set-Location -LiteralPath $PSScriptRoot
        if ($script:repo) { Remove-Item -Recurse -Force -LiteralPath $script:repo -ErrorAction SilentlyContinue }
    }

    It 'version prints the VERSION file' {
        $out = (& $script:PwshExe -NoProfile -File $script:Cli 'version') -join "`n"
        $out.Trim() | Should -Be $script:Version
    }

    It 'help lists core commands without legacy self upgrade' {
        $out = (& $script:PwshExe -NoProfile -File $script:Cli 'help' 2>&1 | ForEach-Object { $_.ToString() }) -join "`n"
        $out | Should -Match 'feature'
        $out | Should -Match 'check'
        $out | Should -Not -Match 'self upgrade'
    }

    It 'an unknown command exits non-zero and prints usage' {
        & $script:PwshExe -NoProfile -File $script:Cli 'bogus' *> $null
        $LASTEXITCODE | Should -Not -Be 0
        $out = (& $script:PwshExe -NoProfile -File $script:Cli 'bogus' 2>&1 | ForEach-Object { $_.ToString() }) -join "`n"
        $out | Should -Match 'Unknown command'
    }

    It 'check --json is wired through the dispatcher inside a repo' {
        $script:repo = Initialize-TestRepo
        $j = (& $script:PwshExe -NoProfile -File $script:Cli 'check' '--json') | ConvertFrom-Json
        $j.fluency | Should -Be $true
    }
}
