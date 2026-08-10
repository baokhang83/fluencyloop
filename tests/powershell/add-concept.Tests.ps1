# add-concept.ps1 — mirrors tests/add-concept.bats.

Describe 'add-concept.ps1' {
    BeforeAll { . "$PSScriptRoot/_helper.ps1" }
    AfterEach {
        Set-Location -LiteralPath $PSScriptRoot
        if ($script:repo) { Remove-Item -Recurse -Force -LiteralPath $script:repo -ErrorAction SilentlyContinue }
    }

    BeforeEach {
        $script:repo = Initialize-TestRepo
        & $script:PwshExe -NoProfile -File "$script:Bin/new-feature.ps1" 'add caching' | Out-Null
        & $script:PwshExe -NoProfile -File "$script:Bin/new-session.ps1" '--slug' '001-add-caching' 'wire the cache' | Out-Null
        $script:store = "$script:repo/docs/fluencyloop/store/concepts.jsonl"
    }

    It 'appends a schema-complete concept to the global stream' {
        (Invoke-FlExit 'add-concept.ps1' '--name' 'read through cache' '--problem' 'avoid repeated remote reads' `
            '--how' 'look in the cache before calling the remote service' '--realized-by' 'src/cache.js') | Should -Be 0
        Test-Path -LiteralPath $script:store | Should -BeTrue

        $record = ([System.IO.File]::ReadAllLines($script:store) | Select-Object -Last 1) | ConvertFrom-Json
        $record.schema_version | Should -Be '1'
        $record.type | Should -Be 'concept'
        $record.ts | Should -Not -BeNullOrEmpty
        $record.feature | Should -Be '001-add-caching'
        $record.session | Should -Be '001-wire-the-cache'
        $record.commit | Should -Not -BeNullOrEmpty
        $record.name | Should -Be 'read through cache'
        $record.problem | Should -Be 'avoid repeated remote reads'
        $record.how | Should -Be 'look in the cache before calling the remote service'
        $record.realized_by | Should -Be 'src/cache.js'
    }

    It 're-stating a concept appends a newer record' {
        & $script:PwshExe -NoProfile -File "$script:Bin/add-concept.ps1" '--name' 'read through cache' '--problem' 'avoid repeated remote reads' `
            '--how' 'read the cache first' '--realized-by' 'src/cache.js' | Out-Null
        & $script:PwshExe -NoProfile -File "$script:Bin/add-concept.ps1" '--name' 'read through cache' '--problem' 'avoid repeated remote reads' `
            '--how' 'read the cache first and refresh after a miss' '--realized-by' 'src/cache.js' | Out-Null

        @([System.IO.File]::ReadAllLines($script:store)).Count | Should -Be 2
        $record = ([System.IO.File]::ReadAllLines($script:store) | Select-Object -Last 1) | ConvertFrom-Json
        $record.name | Should -Be 'read through cache'
        $record.how | Should -Be 'read the cache first and refresh after a miss'
    }

    It 'repeated --realized-by values stay in one concept record' {
        & $script:PwshExe -NoProfile -File "$script:Bin/add-concept.ps1" '--name' 'read through cache' '--problem' 'avoid repeated remote reads' `
            '--how' 'read the cache first' '--realized-by' 'src/cache.js' '--realized-by' 'CacheClient' | Out-Null

        @([System.IO.File]::ReadAllLines($script:store)).Count | Should -Be 1
        $record = ([System.IO.File]::ReadAllLines($script:store) | Select-Object -Last 1) | ConvertFrom-Json
        $realizedBy = @($record.realized_by -split "`n")
        $realizedBy.Count | Should -Be 2
        $realizedBy[0] | Should -Be 'src/cache.js'
        $realizedBy[1] | Should -Be 'CacheClient'
    }

    It 'repeated --tag values join into one newline-delimited field' {
        & $script:PwshExe -NoProfile -File "$script:Bin/add-concept.ps1" '--name' 'read through cache' '--problem' 'avoid repeated remote reads' `
            '--how' 'read the cache first' '--realized-by' 'src/cache.js' '--tag' 'read-through cache' '--tag' 'cache-aside' | Out-Null

        @([System.IO.File]::ReadAllLines($script:store)).Count | Should -Be 1
        $record = ([System.IO.File]::ReadAllLines($script:store) | Select-Object -Last 1) | ConvertFrom-Json
        $tags = @($record.tags -split "`n")
        $tags.Count | Should -Be 2
        $tags[0] | Should -Be 'read-through cache'
        $tags[1] | Should -Be 'cache-aside'
    }

    It 'omitting --tag writes no tags field, not an empty one' {
        & $script:PwshExe -NoProfile -File "$script:Bin/add-concept.ps1" '--name' 'read through cache' '--problem' 'avoid repeated remote reads' `
            '--how' 'read the cache first' '--realized-by' 'src/cache.js' | Out-Null

        $record = ([System.IO.File]::ReadAllLines($script:store) | Select-Object -Last 1) | ConvertFrom-Json
        ($record.PSObject.Properties.Name -contains 'tags') | Should -BeFalse
    }

    It 'appends relations even when their concepts are unknown' {
        (Invoke-FlExit 'add-concept.ps1' '--relate' 'unknown concept|CacheClient|realized_by') | Should -Be 0

        $record = ([System.IO.File]::ReadAllLines($script:store) | Select-Object -Last 1) | ConvertFrom-Json
        $record.type | Should -Be 'relation'
        $record.from | Should -Be 'unknown concept'
        $record.to | Should -Be 'CacheClient'
        $record.kind | Should -Be 'realized_by'
        $record.feature | Should -Be '001-add-caching'
        $record.session | Should -Be '001-wire-the-cache'
    }

    It 'attributes a concept to an imported feature without changing branch state' {
        (Invoke-FlExit 'add-concept.ps1' '--feature' 'legacy-caching' '--session' '000-legacy-import' `
            '--name' 'bounded cache history' '--problem' 'retain useful values without indefinite growth' `
            '--how' 'the cache keeps a bounded set of entries' '--realized-by' 'src/cache.js') | Should -Be 0
        $record = ([System.IO.File]::ReadAllLines($script:store) | Select-Object -Last 1) | ConvertFrom-Json
        $record.feature | Should -Be 'legacy-caching'
        $record.session | Should -Be '000-legacy-import'
    }

    It 'requires both historical target flags' {
        (Invoke-FlExit 'add-concept.ps1' '--feature' 'legacy-caching' '--relate' 'a|b|uses') | Should -Not -Be 0
    }
}
