# new-feature.ps1 + new-session.ps1 — mirrors tests/feature-session.bats.

Describe 'new-feature.ps1 + new-session.ps1' {
    BeforeAll { . "$PSScriptRoot/_helper.ps1" }
    AfterEach {
        Set-Location -LiteralPath $PSScriptRoot
        if ($script:repo) { Remove-Item -Recurse -Force -LiteralPath $script:repo -ErrorAction SilentlyContinue }
    }

    function Get-LastStoreRecord([string]$path) {
        ([System.IO.File]::ReadAllLines($path) | Select-Object -Last 1) | ConvertFrom-Json
    }

    It 'new-feature creates the branch, a feature record, and state (stage: design)' {
        $script:repo = Initialize-TestRepo
        $j = Get-FlJson 'new-feature.ps1' '--json' 'add rate limiting'
        $j.slug | Should -Be '001-add-rate-limiting'
        $j.branch | Should -Be 'feature/001-add-rate-limiting'
        (git rev-parse --abbrev-ref HEAD) | Should -Be 'feature/001-add-rate-limiting'
        $store = "$script:repo/docs/fluencyloop/store/features/001-add-rate-limiting.jsonl"
        $j.store | Should -Be $store
        $store | Should -Exist
        $record = Get-LastStoreRecord $store
        $record.type | Should -Be 'feature'
        foreach ($field in @('schema_version', 'type', 'ts', 'feature', 'session', 'commit')) {
            $record.PSObject.Properties.Name | Should -Contain $field
        }
        $s = Get-Content -Raw "$script:repo/.fluencyloop/state.json" | ConvertFrom-Json
        $s.stage | Should -Be 'design'
        $s.base_ref | Should -Be 'main'
        "$script:repo/docs/fluencyloop/features/001-add-rate-limiting/design.md" | Should -Not -Exist
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

    It 'numbers the next store-backed feature without markdown directories' {
        $script:repo = Initialize-TestRepo
        & $script:PwshExe -NoProfile -File "$script:Bin/new-feature.ps1" 'first feature' | Out-Null
        $next = & $script:PwshExe -NoProfile -Command ". '$script:Bin/common.ps1'; FlNextFeatureNumber"
        ($next | Select-Object -Last 1) | Should -Be '002'
    }

    It 'new-session records the slice without creating markdown' {
        $script:repo = Initialize-TestRepo
        & $script:PwshExe -NoProfile -File "$script:Bin/new-feature.ps1" 'add caching' | Out-Null
        $j = Get-FlJson 'new-session.ps1' '--json' '--slug' '001-add-caching' 'wire the LRU cache'
        $store = "$script:repo/docs/fluencyloop/store/features/001-add-caching.jsonl"
        @([System.IO.File]::ReadAllLines($store)).Count | Should -Be 2
        (Get-LastStoreRecord $store).type | Should -Be 'session'
        $s = Get-Content -Raw "$script:repo/.fluencyloop/state.json" | ConvertFrom-Json
        $s.stage | Should -Be 'build'
        $s.last_session | Should -Be '001-wire-the-lru-cache'
        "$script:repo/docs/fluencyloop/features/001-add-caching/sessions/001-wire-the-lru-cache.md" | Should -Not -Exist
    }

    It 'new sessions advance from state without markdown filenames' {
        $script:repo = Initialize-TestRepo
        & $script:PwshExe -NoProfile -File "$script:Bin/new-feature.ps1" 'add caching' | Out-Null
        & $script:PwshExe -NoProfile -File "$script:Bin/new-session.ps1" '--slug' '001-add-caching' 'first slice' | Out-Null
        $j = Get-FlJson 'new-session.ps1' '--json' '--slug' '001-add-caching' 'second slice'
        $j.session_slug | Should -Be '002-second-slice'
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

    It 'new-feature reuses a legacy unnumbered branch without changing its markdown' {
        $script:repo = Initialize-TestRepo
        git checkout -q -b 'feature/add-caching' 2>&1 | Out-Null
        New-Item -ItemType Directory -Force -Path "$script:repo/docs/fluencyloop/features/add-caching" | Out-Null
        Set-Content -NoNewline -LiteralPath "$script:repo/docs/fluencyloop/features/add-caching/design.md" -Value '# Legacy design'

        $j = Get-FlJson 'new-feature.ps1' '--json' 'add caching'
        $j.slug | Should -Be 'add-caching'
        $j.branch_created | Should -Be 'false'
        (git rev-parse --abbrev-ref HEAD) | Should -Be 'feature/add-caching'
        (Get-Content -Raw "$script:repo/docs/fluencyloop/features/add-caching/design.md") | Should -Be '# Legacy design'
        & git show-ref --verify --quiet 'refs/heads/feature/001-add-caching' 2>$null
        $LASTEXITCODE | Should -Not -Be 0
    }
}
