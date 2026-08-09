# add-requirement.ps1 — mirrors tests/add-requirement.bats.

Describe 'add-requirement.ps1' {
    BeforeAll { . "$PSScriptRoot/_helper.ps1" }
    AfterEach {
        Set-Location -LiteralPath $PSScriptRoot
        if ($script:repo) { Remove-Item -Recurse -Force -LiteralPath $script:repo -ErrorAction SilentlyContinue }
    }

    BeforeEach {
        $script:repo = Initialize-TestRepo
        $script:store = "$script:repo/docs/fluencyloop/store/concepts.jsonl"
    }

    It 'appends a schema-complete answered requirement' {
        (Invoke-FlExit 'add-requirement.ps1' '--gap' 'Which store format should the site read?' `
            '--answer' 'Append-only JSONL.' '--consequence' 'Readers select the last line for an identity.') | Should -Be 0

        $record = ([System.IO.File]::ReadAllLines($script:store) | Select-Object -Last 1) | ConvertFrom-Json
        $record.schema_version | Should -Be '1'
        $record.type | Should -Be 'requirement'
        $record.ts | Should -Not -BeNullOrEmpty
        $record.feature | Should -Be 'global'
        $record.session | Should -Be 'none'
        $record.commit | Should -Not -BeNullOrEmpty
        $record.gap | Should -Be 'Which store format should the site read?'
        $record.answer | Should -Be 'Append-only JSONL.'
        $record.consequence | Should -Be 'Readers select the last line for an identity.'
    }

    It 'appends a schema-complete open question' {
        (Invoke-FlExit 'add-requirement.ps1' '--open' 'Which visual form best explains a concept?' `
            '--matters' 'The site should choose the representation deliberately.') | Should -Be 0

        $record = ([System.IO.File]::ReadAllLines($script:store) | Select-Object -Last 1) | ConvertFrom-Json
        $record.type | Should -Be 'open_question'
        $record.feature | Should -Be 'global'
        $record.session | Should -Be 'none'
        $record.gap | Should -Be 'Which visual form best explains a concept?'
        $record.why_it_matters | Should -Be 'The site should choose the representation deliberately.'
    }

    It 'an answered open question appends a requirement without changing the earlier line' {
        & $script:PwshExe -NoProfile -File "$script:Bin/add-requirement.ps1" '--open' 'Which visual form best explains a concept?' `
            '--matters' 'The site needs a deliberate representation.' | Out-Null
        & $script:PwshExe -NoProfile -File "$script:Bin/add-requirement.ps1" '--gap' 'Which visual form best explains a concept?' `
            '--answer' 'Use a concept graph.' '--consequence' 'The site renders relationships between concepts.' | Out-Null

        $records = @([System.IO.File]::ReadAllLines($script:store) | ForEach-Object { $_ | ConvertFrom-Json })
        $records.Count | Should -Be 2
        $records[0].type | Should -Be 'open_question'
        $records[0].gap | Should -Be $records[1].gap
        $records[1].type | Should -Be 'requirement'
        $records[1].answer | Should -Be 'Use a concept graph.'
    }

    It 'requires one complete record form' {
        (Invoke-FlExit 'add-requirement.ps1' '--gap' 'Which store format should the site read?' '--answer' 'JSONL') | Should -Not -Be 0
        (Invoke-FlAll 'add-requirement.ps1' '--gap' 'Which store format should the site read?' '--answer' 'JSONL') | Should -Match '--consequence'
        Test-Path -LiteralPath $script:store | Should -BeFalse
    }
}
