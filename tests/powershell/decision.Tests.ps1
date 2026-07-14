# add-decision.ps1 — mirrors tests/decision.bats.

Describe 'add-decision.ps1' {
    BeforeAll { . "$PSScriptRoot/_helper.ps1" }
    AfterEach {
        Set-Location -LiteralPath $PSScriptRoot
        if ($script:repo) { Remove-Item -Recurse -Force -LiteralPath $script:repo -ErrorAction SilentlyContinue }
    }

    BeforeEach {
        $script:repo = Initialize-TestRepo
        & $script:PwshExe -NoProfile -File "$script:Bin/new-feature.ps1" 'add caching' | Out-Null
        & $script:PwshExe -NoProfile -File "$script:Bin/new-session.ps1" '--slug' 'add-caching' 'wire the cache' | Out-Null
        $script:session = "$script:repo/docs/fluencyloop/features/add-caching/sessions/wire-the-cache.md"
    }

    It 'appends a fully-formatted block, session resolved from state' {
        (Invoke-FlExit 'add-decision.ps1' '--title' 'chose LRU over unbounded map' '--where' 'src/cache.js' `
            '--why' 'memory must stay bounded' '--alternative' 'unbounded Map — rejected: leaks' `
            '--constitution' '§2' '--trust' 'unverified') | Should -Be 0
        $c = Get-Content -Raw $script:session
        $c | Should -Match '## Decision: chose LRU over unbounded map'
        $c | Should -Match '- \*\*where:\*\* `src/cache\.js`'
        $c | Should -Match '- \*\*why:\*\* memory must stay bounded'
        $c | Should -Match '- \*\*constitution:\*\* §2'
        $c | Should -Match '- \*\*trust:\*\* ⚠ not independently verified'
    }

    It 'requires --where and --why' {
        (Invoke-FlExit 'add-decision.ps1' '--why' 'x') | Should -Not -Be 0
        (Invoke-FlExit 'add-decision.ps1' '--where' 'y') | Should -Not -Be 0
    }

    It 'trust: verified renders the check; default is unverified' {
        & $script:PwshExe -NoProfile -File "$script:Bin/add-decision.ps1" '--where' 'a' '--why' 'b' '--trust' 'verified' | Out-Null
        (Get-Content -Raw $script:session) | Should -Match '- \*\*trust:\*\* ✓ verified'
    }

    It 'optional fields are omitted when not supplied' {
        & $script:PwshExe -NoProfile -File "$script:Bin/add-decision.ps1" '--where' 'a' '--why' 'b' | Out-Null
        # Check the APPENDED block (after the last "## Decision:"), not the whole file — the
        # template's example comment legitimately mentions alternative:/design:.
        $block = (Get-Content -Raw $script:session) -split '## Decision:' | Select-Object -Last 1
        $block | Should -Not -Match 'alternative:'
        $block | Should -Not -Match 'constitution:'
        $block | Should -Not -Match 'design:'
    }

    It 'errors clearly when there is no session to append to' {
        Remove-Item -LiteralPath "$script:repo/.fluencyloop/state.json" -Force
        (Invoke-FlExit 'add-decision.ps1' '--where' 'a' '--why' 'b') | Should -Not -Be 0
    }
}
