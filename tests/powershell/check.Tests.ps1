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
        $j.feature | Should -Be 'add-search'
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
        & $script:PwshExe -NoProfile -File "$script:Bin/new-session.ps1" '--slug' 'add-search' 'index' | Out-Null
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
}
