# new-feature.ps1 + new-session.ps1 — mirrors tests/feature-session.bats.

Describe 'new-feature.ps1 + new-session.ps1' {
    BeforeAll { . "$PSScriptRoot/_helper.ps1" }
    AfterEach {
        Set-Location -LiteralPath $PSScriptRoot
        if ($script:repo) { Remove-Item -Recurse -Force -LiteralPath $script:repo -ErrorAction SilentlyContinue }
    }

    It 'new-feature creates the branch, design stub, and state (stage: design)' {
        $script:repo = Initialize-TestRepo
        $j = Get-FlJson 'new-feature.ps1' '--json' 'add rate limiting'
        $j.slug | Should -Be 'add-rate-limiting'
        $j.branch | Should -Be 'feature/add-rate-limiting'
        (git rev-parse --abbrev-ref HEAD) | Should -Be 'feature/add-rate-limiting'
        "$script:repo/docs/fluencyloop/features/add-rate-limiting/design.md" | Should -Exist
        $s = Get-Content -Raw "$script:repo/.fluencyloop/state.json" | ConvertFrom-Json
        $s.stage | Should -Be 'design'
        $s.base_ref | Should -Be 'main'
    }

    It 'new-feature errors (non-zero) with no intent' {
        $script:repo = Initialize-TestRepo
        (Invoke-FlExit 'new-feature.ps1') | Should -Not -Be 0
    }

    It 'new-feature is idempotent: re-run preserves base_ref' {
        $script:repo = Initialize-TestRepo
        & $script:PwshExe -NoProfile -File "$script:Bin/new-feature.ps1" 'add caching' | Out-Null
        & $script:PwshExe -NoProfile -File "$script:Bin/new-feature.ps1" 'add caching' | Out-Null
        $s = Get-Content -Raw "$script:repo/.fluencyloop/state.json" | ConvertFrom-Json
        $s.base_ref | Should -Be 'main'
    }

    It 'new-session moves state to build and records the last session' {
        $script:repo = Initialize-TestRepo
        & $script:PwshExe -NoProfile -File "$script:Bin/new-feature.ps1" 'add caching' | Out-Null
        $j = Get-FlJson 'new-session.ps1' '--json' '--slug' 'add-caching' 'wire the LRU cache'
        "$script:repo/docs/fluencyloop/features/add-caching/sessions/wire-the-lru-cache.md" | Should -Exist
        $s = Get-Content -Raw "$script:repo/.fluencyloop/state.json" | ConvertFrom-Json
        $s.stage | Should -Be 'build'
        $s.last_session | Should -Be 'docs/fluencyloop/features/add-caching/sessions/wire-the-lru-cache.md'
        $s.base_ref | Should -Be 'main'
    }

    It 'new-session errors with no active feature' {
        $script:repo = Initialize-TestRepo
        (Invoke-FlExit 'new-session.ps1' 'orphan slice') | Should -Not -Be 0
    }

    It 'base_ref records the true fork point, not always main' {
        $script:repo = Initialize-TestRepo
        git checkout -q -b trunk 2>&1 | Out-Null
        & $script:PwshExe -NoProfile -File "$script:Bin/new-feature.ps1" 'forked work' | Out-Null
        $s = Get-Content -Raw "$script:repo/.fluencyloop/state.json" | ConvertFrom-Json
        $s.base_ref | Should -Be 'trunk'
    }
}
