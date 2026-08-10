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
        & $script:PwshExe -NoProfile -File "$script:Bin/new-session.ps1" '--slug' '001-add-caching' 'wire the cache' | Out-Null
        $script:store = "$script:repo/docs/fluencyloop/store/features/001-add-caching.jsonl"
    }

    It 'appends one schema-complete decision, resolved from state' {
        (Invoke-FlExit 'add-decision.ps1' '--title' 'chose LRU over unbounded map' '--where' 'src/cache.js' `
            '--why' 'memory must stay bounded' '--alternative' 'unbounded Map — rejected: leaks' `
            '--constitution' '§2' '--trust' 'unverified') | Should -Be 0
        @([System.IO.File]::ReadAllLines($script:store)).Count | Should -Be 3
        $record = ([System.IO.File]::ReadAllLines($script:store) | Select-Object -Last 1) | ConvertFrom-Json
        $record.type | Should -Be 'decision'
        $record.title | Should -Be 'chose LRU over unbounded map'
        $record.where | Should -Be 'src/cache.js'
        $record.why | Should -Be 'memory must stay bounded'
        $record.alternative | Should -Be 'unbounded Map — rejected: leaks'
        $record.constitution | Should -Be '§2'
        $record.trust | Should -Be 'unverified'
        $record.feature | Should -Be '001-add-caching'
        $record.session | Should -Be '001-wire-the-cache'
    }

    It 'requires --where and --why' {
        (Invoke-FlExit 'add-decision.ps1' '--why' 'x') | Should -Not -Be 0
        (Invoke-FlExit 'add-decision.ps1' '--where' 'y') | Should -Not -Be 0
    }

    It 'trust: verified and default unverified are stored' {
        & $script:PwshExe -NoProfile -File "$script:Bin/add-decision.ps1" '--where' 'a' '--why' 'b' '--trust' 'verified' | Out-Null
        (([System.IO.File]::ReadAllLines($script:store) | Select-Object -Last 1) | ConvertFrom-Json).trust | Should -Be 'verified'
        & $script:PwshExe -NoProfile -File "$script:Bin/add-decision.ps1" '--where' 'c' '--why' 'd' | Out-Null
        (([System.IO.File]::ReadAllLines($script:store) | Select-Object -Last 1) | ConvertFrom-Json).trust | Should -Be 'unverified'
    }

    It 'omits optional fields rather than writing empty values' {
        & $script:PwshExe -NoProfile -File "$script:Bin/add-decision.ps1" '--where' 'a' '--why' 'b' | Out-Null
        $record = ([System.IO.File]::ReadAllLines($script:store) | Select-Object -Last 1) | ConvertFrom-Json
        foreach ($field in @('alternative', 'constitution', 'design')) {
            $record.PSObject.Properties.Name | Should -Not -Contain $field
        }
    }

    It 'pre-existing markdown stays untouched' {
        $legacy = "$script:repo/docs/fluencyloop/features/001-add-caching/sessions/legacy.md"
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $legacy) | Out-Null
        Set-Content -NoNewline -LiteralPath $legacy -Value '# Legacy session'
        & $script:PwshExe -NoProfile -File "$script:Bin/add-decision.ps1" '--session' $legacy '--where' 'a' '--why' 'b' | Out-Null
        (Get-Content -Raw $legacy) | Should -Be '# Legacy session'
    }

    It 'errors clearly when there is no session to append to' {
        Remove-Item -LiteralPath "$script:repo/.fluencyloop/state.json" -Force
        (Invoke-FlExit 'add-decision.ps1' '--where' 'a' '--why' 'b') | Should -Not -Be 0
    }

    It 'targets an imported feature without changing branch state' {
        (Invoke-FlExit 'add-decision.ps1' '--feature' 'legacy-caching' '--session' '000-legacy-import' `
            '--where' 'src/cache.js' '--why' 'the imported implementation bounds memory') | Should -Be 0
        $store = "$script:repo/docs/fluencyloop/store/features/legacy-caching.jsonl"
        $record = ([System.IO.File]::ReadAllLines($store) | Select-Object -Last 1) | ConvertFrom-Json
        $record.feature | Should -Be 'legacy-caching'
        $record.session | Should -Be '000-legacy-import'
    }

    It 'requires a session when targeting an imported feature' {
        (Invoke-FlExit 'add-decision.ps1' '--feature' 'legacy-caching' '--where' 'src/cache.js' '--why' 'x') | Should -Not -Be 0
    }
}
