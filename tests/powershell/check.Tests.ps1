# check.ps1 — mirrors tests/check.bats.

Describe 'check.ps1' {
    BeforeAll { . "$PSScriptRoot/_helper.ps1" }
    AfterEach {
        Set-Location -LiteralPath $PSScriptRoot
        if ($script:repo) { Remove-Item -Recurse -Force -LiteralPath $script:repo -ErrorAction SilentlyContinue }
    }

    It 'reports fluency false before init' {
        $script:repo = New-TestRepo
        (Get-FlJson 'check.ps1' '--json').fluency | Should -Be $false
    }

    It 'reports the active feature and an empty constitution after init' {
        $script:repo = Initialize-TestRepo
        & $script:PwshExe -NoProfile -File "$script:Bin/new-feature.ps1" 'add search' | Out-Null
        $j = Get-FlJson 'check.ps1' '--json'
        $j.feature | Should -Be '001-add-search'
        $j.constitution | Should -Be 'empty'
    }

    It 'constitution states: present and pointer' {
        $script:repo = Initialize-TestRepo
        $c = "$script:repo/docs/fluencyloop/constitution.md"
        [System.IO.File]::WriteAllText($c, "# Constitution`n`n## Principles`n`n### §1 — no sync calls`n")
        (Get-FlJson 'check.ps1' '--json').constitution | Should -Be 'present'
        [System.IO.File]::WriteAllText($c, "# Constitution`n`nSource of truth: .specify/memory/constitution.md`n")
        (Get-FlJson 'check.ps1' '--json').constitution | Should -Be 'pointer'
    }

    It 'un-journaled drift counts commits past the last journaled session' {
        $script:repo = Initialize-TestRepo
        & $script:PwshExe -NoProfile -File "$script:Bin/new-feature.ps1" 'add search' | Out-Null
        git add -A 2>&1 | Out-Null; git commit -q -m 'scaffold, no session' 2>&1 | Out-Null
        (Get-FlJson 'check.ps1' '--json').unjournaled_commits | Should -Be 1
        & $script:PwshExe -NoProfile -File "$script:Bin/new-session.ps1" '--slug' '001-add-search' 'index' | Out-Null
        git add -A 2>&1 | Out-Null; git commit -q -m 'journal' 2>&1 | Out-Null
        (Get-FlJson 'check.ps1' '--json').unjournaled_commits | Should -Be 0
        [System.IO.File]::WriteAllText("$script:repo/more.txt", "x`n")
        git add -A 2>&1 | Out-Null; git commit -q -m 'more code' 2>&1 | Out-Null
        (Get-FlJson 'check.ps1' '--json').unjournaled_commits | Should -Be 1
    }

    It 'absent constitution informs without erroring' {
        $script:repo = Initialize-TestRepo
        Remove-Item -LiteralPath "$script:repo/docs/fluencyloop/constitution.md" -Force
        (Invoke-FlExit 'check.ps1') | Should -Be 0
        (Invoke-Fl 'check.ps1') | Should -Match 'no constitution yet'
    }

    It 'accepts a clean store' {
        $script:repo = Initialize-TestRepo
        $store = "$script:repo/docs/fluencyloop/store/concepts.jsonl"
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $store) | Out-Null
        [System.IO.File]::AppendAllText($store, "{`"schema_version`":`"1`",`"type`":`"concept`",`"ts`":`"2026-08-09`",`"feature`":`"global`",`"session`":`"none`",`"commit`":`"abc`",`"name`":`"cache`",`"problem`":`"slow reads`",`"how`":`"reuse results`",`"realized_by`":`"CacheClient`"}`n")

        $result = Get-FlJson 'check.ps1' '--json'
        $result.store_errors.Count | Should -Be 0
    }

    It 'reports unparseable store JSON with file and line' {
        $script:repo = Initialize-TestRepo
        $store = "$script:repo/docs/fluencyloop/store/concepts.jsonl"
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $store) | Out-Null
        [System.IO.File]::WriteAllText($store, '{"schema_version":"1"')

        (Invoke-FlExit 'check.ps1' '--json') | Should -Be 1
        $result = Get-FlJson 'check.ps1' '--json'
        $result.store_errors[0].file | Should -Match 'concepts\.jsonl'
        $result.store_errors[0].line | Should -Be 1
        $result.store_errors[0].message | Should -Be 'unparseable JSON'
    }

    It 'reports an unknown store record type' {
        $script:repo = Initialize-TestRepo
        $store = "$script:repo/docs/fluencyloop/store/concepts.jsonl"
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $store) | Out-Null
        [System.IO.File]::WriteAllText($store, '{"schema_version":"1","type":"invented","ts":"2026-08-09","feature":"global","session":"none","commit":"abc"}')

        (Invoke-FlExit 'check.ps1' '--json') | Should -Be 1
        $result = Get-FlJson 'check.ps1' '--json'
        $result.store_errors[0].line | Should -Be 1
        $result.store_errors[0].message | Should -Be 'unknown record type: invented'
    }

    It 'reports a missing required envelope field' {
        $script:repo = Initialize-TestRepo
        $store = "$script:repo/docs/fluencyloop/store/concepts.jsonl"
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $store) | Out-Null
        [System.IO.File]::WriteAllText($store, '{"schema_version":"1","type":"concept","ts":"2026-08-09","feature":"global","session":"none","name":"cache"}')

        (Invoke-FlExit 'check.ps1' '--json') | Should -Be 1
        $result = Get-FlJson 'check.ps1' '--json'
        $result.store_errors[0].line | Should -Be 1
        $result.store_errors[0].message | Should -Be 'missing required envelope field: commit'
    }

    It 'reports a dangling relation with file and line' {
        $script:repo = Initialize-TestRepo
        $store = "$script:repo/docs/fluencyloop/store/concepts.jsonl"
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $store) | Out-Null
        [System.IO.File]::WriteAllText($store, "{`"schema_version`":`"1`",`"type`":`"concept`",`"ts`":`"2026-08-09`",`"feature`":`"global`",`"session`":`"none`",`"commit`":`"abc`",`"name`":`"known`",`"problem`":`"p`",`"how`":`"h`",`"realized_by`":`"x`"}`n{`"schema_version`":`"1`",`"type`":`"relation`",`"ts`":`"2026-08-09`",`"feature`":`"global`",`"session`":`"none`",`"commit`":`"abc`",`"from`":`"missing`",`"to`":`"known`",`"kind`":`"uses`"}`n")

        (Invoke-FlExit 'check.ps1' '--json') | Should -Be 1
        $result = Get-FlJson 'check.ps1' '--json'
        $result.store_errors[0].line | Should -Be 2
        $result.store_errors[0].message | Should -Be 'dangling relation endpoint: missing'
    }

    It 'reports a feature directory without store records' {
        $script:repo = Initialize-TestRepo
        New-Item -ItemType Directory -Force -Path "$script:repo/docs/fluencyloop/features/001-empty" | Out-Null

        (Invoke-FlExit 'check.ps1' '--json') | Should -Be 1
        $result = Get-FlJson 'check.ps1' '--json'
        $result.store_errors[0].file | Should -Match '001-empty\.jsonl'
        $result.store_errors[0].line | Should -Be 0
        $result.store_errors[0].message | Should -Be 'feature directory has no store records: 001-empty'
    }
}
