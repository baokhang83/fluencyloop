# new-plan.ps1 — mirrors tests/plan.bats.

Describe 'new-plan.ps1' {
    BeforeAll { . "$PSScriptRoot/_helper.ps1" }
    AfterEach {
        Set-Location -LiteralPath $PSScriptRoot
        if ($script:repo) { Remove-Item -Recurse -Force -LiteralPath $script:repo -ErrorAction SilentlyContinue }
    }

    It 'scaffolds plan.md under docs/fluencyloop/plans without switching branches' {
        $script:repo = Initialize-TestRepo
        $j = Get-FlJson 'new-plan.ps1' '--json' 'revamp the checkout flow'
        $j.slug | Should -Be 'revamp-the-checkout-flow'
        "$script:repo/docs/fluencyloop/plans/revamp-the-checkout-flow/plan.md" | Should -Exist
        (git rev-parse --abbrev-ref HEAD) | Should -Be 'main'
    }

    It 'substitutes the initiative title into the doc' {
        $script:repo = Initialize-TestRepo
        & $script:PwshExe -NoProfile -File "$script:Bin/new-plan.ps1" 'revamp the checkout flow' | Out-Null
        (Get-Content -Raw "$script:repo/docs/fluencyloop/plans/revamp-the-checkout-flow/plan.md") | Should -Match 'revamp the checkout flow'
    }

    It 'errors (non-zero) with no intent' {
        $script:repo = Initialize-TestRepo
        (Invoke-FlExit 'new-plan.ps1') | Should -Not -Be 0
    }

    It '--help prints usage and does not scaffold a plan' {
        $script:repo = Initialize-TestRepo
        $out = Invoke-FlAll 'new-plan.ps1' '--help'
        $out | Should -Match 'Usage: new-plan.ps1'
        "$script:repo/docs/fluencyloop/plans" | Should -Not -Exist
    }

    It 'rejects an unknown flag instead of folding it into the intent' {
        $script:repo = Initialize-TestRepo
        $out = Invoke-FlAll 'new-plan.ps1' '--bogus' 'should not scaffold'
        $out | Should -Match 'Unknown option: --bogus'
        "$script:repo/docs/fluencyloop/plans" | Should -Not -Exist
    }
}
