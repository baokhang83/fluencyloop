# add-principle.ps1 — mirrors tests/add-principle.bats.

Describe 'add-principle.ps1' {
    BeforeAll { . "$PSScriptRoot/_helper.ps1" }
    AfterEach {
        Set-Location -LiteralPath $PSScriptRoot
        if ($script:repo) { Remove-Item -Recurse -Force -LiteralPath $script:repo -ErrorAction SilentlyContinue }
    }

    BeforeEach {
        $script:repo = Initialize-TestRepo
        $script:store = "$script:repo/docs/fluencyloop/store/concepts.jsonl"
    }

    It 'appends a schema-complete repository-wide principle' {
        (Invoke-FlExit 'add-principle.ps1' '--number' '§1' '--title' 'append-only store' `
            '--rule' 'Store writers only append JSONL records.' '--why' 'Corrections must remain auditable.') | Should -Be 0

        $record = ([System.IO.File]::ReadAllLines($script:store) | Select-Object -Last 1) | ConvertFrom-Json
        $record.schema_version | Should -Be '1'
        $record.type | Should -Be 'principle'
        $record.ts | Should -Not -BeNullOrEmpty
        $record.feature | Should -Be 'global'
        $record.session | Should -Be 'none'
        $record.commit | Should -Not -BeNullOrEmpty
        $record.number | Should -Be '§1'
        $record.title | Should -Be 'append-only store'
        $record.rule | Should -Be 'Store writers only append JSONL records.'
        $record.why | Should -Be 'Corrections must remain auditable.'
    }

    It 'a corrected principle appends a later record with the same number' {
        & $script:PwshExe -NoProfile -File "$script:Bin/add-principle.ps1" '--number' '§1' '--title' 'append-only store' `
            '--rule' 'Store writers append records.' '--why' 'History is auditable.' | Out-Null
        & $script:PwshExe -NoProfile -File "$script:Bin/add-principle.ps1" '--number' '§1' '--title' 'append-only store' `
            '--rule' 'Store writers append one JSONL object per line.' '--why' 'History is mergeable and auditable.' | Out-Null

        $records = @([System.IO.File]::ReadAllLines($script:store) | ForEach-Object { $_ | ConvertFrom-Json })
        $records.Count | Should -Be 2
        $records[0].number | Should -Be '§1'
        $records[1].number | Should -Be '§1'
        $records[1].rule | Should -Be 'Store writers append one JSONL object per line.'
    }

    It 'requires every principle field and a citation number' {
        (Invoke-FlExit 'add-principle.ps1' '--number' 'one' '--title' 'append-only store' `
            '--rule' 'Store writers append records.' '--why' 'History is auditable.') | Should -Not -Be 0
        (Invoke-FlAll 'add-principle.ps1' '--number' 'one' '--title' 'append-only store' `
            '--rule' 'Store writers append records.' '--why' 'History is auditable.') | Should -Match 'constitution citation'
        Test-Path -LiteralPath $script:store | Should -BeFalse
    }
}
