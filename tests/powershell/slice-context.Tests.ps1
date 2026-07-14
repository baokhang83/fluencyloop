# slice-context.ps1 — mirrors tests/slice-context.bats.

Describe 'slice-context.ps1' {
    BeforeAll { . "$PSScriptRoot/_helper.ps1" }
    AfterEach {
        Set-Location -LiteralPath $PSScriptRoot
        if ($script:repo) { Remove-Item -Recurse -Force -LiteralPath $script:repo -ErrorAction SilentlyContinue }
    }

    BeforeEach {
        $script:repo = Initialize-TestRepo
        [System.IO.File]::WriteAllText("$script:repo/app.txt", "a`nb`n")
        git add -A 2>&1 | Out-Null; git commit -q -m 'seed app' 2>&1 | Out-Null
        & $script:PwshExe -NoProfile -File "$script:Bin/new-feature.ps1" 'add caching' | Out-Null
    }

    It '--json returns valid JSON with hunks + metadata' {
        [System.IO.File]::WriteAllText("$script:repo/app.txt", "a`nb changed`nc`n")
        $j = Get-FlJson 'slice-context.ps1' '--json'
        foreach ($k in 'feature', 'base_kind', 'base', 'files_changed', 'insertions', 'deletions', 'files', 'untracked', 'diff') {
            $j.PSObject.Properties.Name | Should -Contain $k
        }
        $j.diff | Should -Match 'b changed'
    }

    It 'includes tracked edits + untracked files; excludes FluencyLoop paths' {
        [System.IO.File]::WriteAllText("$script:repo/app.txt", "a`nb changed`n")
        [System.IO.File]::WriteAllText("$script:repo/new.txt", "x`n")
        $j = Get-FlJson 'slice-context.ps1' '--json'
        ($j.files | ForEach-Object { $_.path }) | Should -Contain 'app.txt'
        $j.untracked | Should -Be @('new.txt')
        foreach ($f in $j.files) { $f.path | Should -Not -Match '\.fluencyloop|docs/fluencyloop' }
    }

    It 'base_kind is base-ref before any journaled session' {
        [System.IO.File]::WriteAllText("$script:repo/app.txt", "a`nb changed`n")
        (Get-FlJson 'slice-context.ps1' '--json').base_kind | Should -Be 'base-ref'
    }

    It 'after a journaled session, the slice scopes to changes since it' {
        [System.IO.File]::WriteAllText("$script:repo/app.txt", "a`nb`nc`n")
        & $script:PwshExe -NoProfile -File "$script:Bin/new-session.ps1" '--slug' 'add-caching' 'slice one' | Out-Null
        git add -A 2>&1 | Out-Null; git commit -q -m 'slice one + journal' 2>&1 | Out-Null
        [System.IO.File]::WriteAllText("$script:repo/app.txt", "a`nb`nc`nd`n")
        $j = Get-FlJson 'slice-context.ps1' '--json'
        $j.base_kind | Should -Be 'last-session'
        $j.diff | Should -Match '\+d'
    }

    It 'plain form prints a header and the diff' {
        [System.IO.File]::WriteAllText("$script:repo/app.txt", "a`nb changed`n")
        $out = Invoke-Fl 'slice-context.ps1'
        $out | Should -Match 'Slice context'
        $out | Should -Match 'b changed'
    }

    It 'pre-filter: JSON carries likely_decision / decision_score / decision_signals' {
        [System.IO.File]::WriteAllText("$script:repo/app.txt", "a`nb changed`n")
        $j = Get-FlJson 'slice-context.ps1' '--json'
        foreach ($k in 'likely_decision', 'decision_score', 'decision_signals') { $j.PSObject.Properties.Name | Should -Contain $k }
        $j.likely_decision | Should -BeOfType [bool]
    }

    It 'pre-filter: a comment-only tweak is NOT a likely decision' {
        [System.IO.File]::WriteAllText("$script:repo/app.txt", "a`nb`n// just a note`n")
        (Get-FlJson 'slice-context.ps1' '--json').likely_decision | Should -Be $false
    }

    It 'pre-filter: a new import IS a likely decision (dep-or-import)' {
        [System.IO.File]::WriteAllText("$script:repo/app.txt", "import x from `"x`";`na`nb`n")
        $j = Get-FlJson 'slice-context.ps1' '--json'
        $j.likely_decision | Should -Be $true
        $j.decision_signals | Should -Contain 'dep-or-import'
    }

    It 'pre-filter: a new exported function IS a likely decision (new-api)' {
        [System.IO.File]::WriteAllText("$script:repo/app.txt", "export function foo(){ return 1; }`n")
        $j = Get-FlJson 'slice-context.ps1' '--json'
        $j.likely_decision | Should -Be $true
        $j.decision_signals | Should -Contain 'new-api'
    }

    It 'pre-filter: substantive branching logic IS a likely decision (control-flow)' {
        [System.IO.File]::WriteAllText("$script:repo/app.txt", "let t=0;`nfor(let i=0;i<9;i++){`n if(i>4){t+=i;}else{t-=i;}`n}`nlet a=t;`nlet b=a+1;`nlet c=b+1;`nlet d=c+1;`n")
        $j = Get-FlJson 'slice-context.ps1' '--json'
        $j.likely_decision | Should -Be $true
        $j.decision_signals | Should -Contain 'control-flow'
    }
}
