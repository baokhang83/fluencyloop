# import-legacy.ps1 — mirrors tests/import-legacy.bats.

Describe 'import-legacy.ps1' {
    BeforeAll { . "$PSScriptRoot/_helper.ps1" }
    AfterEach {
        Set-Location -LiteralPath $PSScriptRoot
        if ($script:repo) { Remove-Item -Recurse -Force -LiteralPath $script:repo -ErrorAction SilentlyContinue }
    }

    BeforeEach {
        $script:repo = Initialize-TestRepo
        $script:legacy = "$script:repo/docs/fluencyloop/features/001-add-caching/sessions/001-wire-cache.md"
        $script:store = "$script:repo/docs/fluencyloop/store/features/001-add-caching.jsonl"
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $script:legacy) | Out-Null
        $verified = ([string][char]0x2713) + ' verified'
        $unverified = ([string][char]0x26A0) + ' not independently verified'
        $text = @(
            '# Session: cache wiring',
            '## Decision: choose an LRU cache',
            '- **where:** `src/cache.js`',
            '- **why:** memory must stay bounded',
            '- **alternative:** unbounded map - rejected: leaks',
            '- **design:** ../design.md#cache',
            '- **constitution:** section-2',
            "- **trust:** $verified",
            '## Decision: cache failures remain visible',
            '- **where:** `src/cache.js`',
            '- **why:** callers must distinguish a miss from failure',
            "- **trust:** $unverified",
            '## Decision: malformed legacy block',
            '- **where:** `src/cache.js`',
            "- **trust:** $verified"
        ) -join "`n"
        [System.IO.File]::WriteAllText($script:legacy, $text + "`n", (New-Object System.Text.UTF8Encoding($false)))
    }

    It 'imports full and minimal decisions, both trust values, and skips malformed blocks' {
        (Invoke-FlExit 'import-legacy.ps1') | Should -Be 0
        (Invoke-FlAll 'import-legacy.ps1') | Should -Match 'Warning: skipped malformed legacy record'

        $records = @([System.IO.File]::ReadAllLines($script:store) | ForEach-Object { $_ | ConvertFrom-Json })
        $records.Count | Should -Be 2
        $records[0].title | Should -Be 'choose an LRU cache'
        $records[0].where | Should -Be 'src/cache.js'
        $records[0].why | Should -Be 'memory must stay bounded'
        $records[0].alternative | Should -Be 'unbounded map - rejected: leaks'
        $records[0].design | Should -Be '../design.md#cache'
        $records[0].constitution | Should -Be 'section-2'
        $records[0].trust | Should -Be 'verified'
        $records[1].title | Should -Be 'cache failures remain visible'
        $records[1].trust | Should -Be 'unverified'
        foreach ($field in @('alternative', 'design', 'constitution')) {
            $records[1].PSObject.Properties.Name | Should -Not -Contain $field
        }
        for ($i = 0; $i -lt $records.Count; $i++) {
            $records[$i].feature | Should -Be '001-add-caching'
            $records[$i].session | Should -Be '001-wire-cache'
            $records[$i].imported_from | Should -Match "#decision-$($i + 1)$"
        }
    }

    It 'leaves the legacy markdown untouched and a second run byte-identical' {
        $before = (git hash-object $script:legacy)
        & $script:PwshExe -NoProfile -File "$script:Bin/import-legacy.ps1" | Out-Null
        $first = (git hash-object $script:store)
        & $script:PwshExe -NoProfile -File "$script:Bin/import-legacy.ps1" | Out-Null
        $second = (git hash-object $script:store)
        (git hash-object $script:legacy) | Should -Be $before
        $first | Should -Be $second
    }

    It 'first normal command imports legacy history automatically' {
        $j = (& $script:PwshExe -NoProfile -File "$script:Bin/check.ps1" '--json') | ConvertFrom-Json
        $j.fluency | Should -Be $true
        Test-Path -LiteralPath $script:store | Should -BeTrue
    }
}
