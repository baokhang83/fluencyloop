# add-knowledge.ps1 — mirrors tests/add-knowledge.bats.

Describe 'add-knowledge.ps1' {
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

    It 'batches components and gotchas into one line each' {
        $before = @([System.IO.File]::ReadAllLines($script:store)).Count
        (Invoke-FlExit 'add-knowledge.ps1' '--component' 'store reader|selects current records|must use file order' `
            '--component' 'cache client|keeps fetched values|only after a miss|follow-up' `
            '--gotcha' 'read after correction|the final matching record wins') | Should -Be 0
        @([System.IO.File]::ReadAllLines($script:store)).Count | Should -Be ($before + 3)

        $records = @([System.IO.File]::ReadAllLines($script:store) | Select-Object -Last 3 | ForEach-Object { $_ | ConvertFrom-Json })
        $records[0].type | Should -Be 'component'
        $records[1].type | Should -Be 'component'
        $records[2].type | Should -Be 'condition'
        $records[0].name | Should -Be 'store reader'
        $records[0].role | Should -Be 'selects current records'
        $records[0].conditions | Should -Be 'must use file order'
        $records[0].status | Should -Be 'documented'
        $records[1].status | Should -Be 'follow-up'
        $records[2].subject | Should -Be 'read after correction'
        $records[2].why | Should -Be 'the final matching record wins'
        foreach ($record in $records) {
            $record.feature | Should -Be '001-add-caching'
            $record.session | Should -Be '001-wire-the-cache'
        }
    }

    It 'escaped pipes and backslashes round-trip through both record kinds' {
        (Invoke-FlExit 'add-knowledge.ps1' '--component' 'cache\|fallback|uses \\ local state|after a miss' `
            '--gotcha' 'read\|write|keeps \\ ordering') | Should -Be 0

        $records = @([System.IO.File]::ReadAllLines($script:store) | Select-Object -Last 2 | ForEach-Object { $_ | ConvertFrom-Json })
        $records[0].name | Should -Be 'cache|fallback'
        $records[0].role | Should -Be 'uses \ local state'
        $records[1].subject | Should -Be 'read|write'
        $records[1].why | Should -Be 'keeps \ ordering'
    }

    It 'an empty batch succeeds without writing records' {
        $before = @([System.IO.File]::ReadAllLines($script:store)).Count
        (Invoke-FlExit 'add-knowledge.ps1') | Should -Be 0
        @([System.IO.File]::ReadAllLines($script:store)).Count | Should -Be $before
    }

    It 'missing session state errors rather than silently writing' {
        Remove-Item -LiteralPath "$script:repo/.fluencyloop/state.json" -Force
        (Invoke-FlExit 'add-knowledge.ps1' '--component' 'cache|keeps values|after a miss') | Should -Not -Be 0
        (Invoke-FlAll 'add-knowledge.ps1' '--component' 'cache|keeps values|after a miss') | Should -Match 'no active session'
        @([System.IO.File]::ReadAllLines($script:store)).Count | Should -Be 2
    }
}
