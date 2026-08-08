# assemble-pr-view.ps1 — mirrors tests/pr-view.bats.

Describe 'assemble-pr-view.ps1' {
    BeforeAll { . "$PSScriptRoot/_helper.ps1" }
    AfterEach {
        Set-Location -LiteralPath $PSScriptRoot
        if ($script:repo) { Remove-Item -Recurse -Force -LiteralPath $script:repo -ErrorAction SilentlyContinue }
    }

    BeforeEach {
        $script:repo = Initialize-TestRepo
        & $script:PwshExe -NoProfile -File "$script:Bin/new-feature.ps1" 'add search' | Out-Null
        git add -A 2>&1 | Out-Null; git commit -q -m 'scaffold' 2>&1 | Out-Null
    }

    It '--json is valid with zero sessions' {
        $j = Get-FlJson 'assemble-pr-view.ps1' '--json'
        $j.session_count | Should -Be 0
    }

    It 'resolves the base from state.json, not a guess' {
        (Get-FlJson 'assemble-pr-view.ps1' '--json').base | Should -Be 'main'
    }

    It 'points readers to the store instead of parsing it in PowerShell' {
        & $script:PwshExe -NoProfile -File "$script:Bin/new-session.ps1" '--slug' '001-add-search' 'index the docs' | Out-Null
        $j = Get-FlJson 'assemble-pr-view.ps1' '--json'
        $j.store | Should -Match '001-add-search\.jsonl$'
        $j.sessions | Should -BeNullOrEmpty
    }

    It 'markdown form renders a title and range' {
        (Invoke-Fl 'assemble-pr-view.ps1') | Should -Match 'PR view'
    }
}
