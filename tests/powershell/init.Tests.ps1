# init.ps1 — mirrors tests/init.bats.

Describe 'init.ps1' {
    BeforeAll { . "$PSScriptRoot/_helper.ps1" }
    AfterEach {
        Set-Location -LiteralPath $PSScriptRoot
        if ($script:repo) { Remove-Item -Recurse -Force -LiteralPath $script:repo -ErrorAction SilentlyContinue }
    }

    It 'scaffolds machine state and docs dirs' {
        $script:repo = New-TestRepo
        & $script:PwshExe -NoProfile -File "$script:Bin/init.ps1" | Out-Null
        "$script:repo/.fluencyloop/scripts" | Should -Exist
        "$script:repo/.fluencyloop/templates" | Should -Exist
        "$script:repo/docs/fluencyloop" | Should -Exist
    }

    It 'seeds an EMPTY constitution stub, not the authoring scaffold' {
        $script:repo = Initialize-TestRepo
        $c = Get-Content -Raw "$script:repo/docs/fluencyloop/constitution.md"
        $c | Should -Match 'None yet'
        $c | Should -Not -Match '(?m)^### §[0-9]'
    }

    It 'is idempotent: a second run does not clobber the constitution' {
        $script:repo = Initialize-TestRepo
        Add-Content -LiteralPath "$script:repo/docs/fluencyloop/constitution.md" -Value '### §1 - real principle'
        & $script:PwshExe -NoProfile -File "$script:Bin/init.ps1" | Out-Null
        (Get-Content -Raw "$script:repo/docs/fluencyloop/constitution.md") | Should -Match 'real principle'
    }

    It 'adds the calibration .gitignore guard' {
        $script:repo = Initialize-TestRepo
        (Get-Content "$script:repo/.gitignore") | Should -Contain '.fluencyloop/**/calibration.md'
    }

    It 'adds its line-ending pins exactly once' {
        $script:repo = Initialize-TestRepo
        & $script:PwshExe -NoProfile -File "$script:Bin/init.ps1" | Out-Null
        @((Get-Content "$script:repo/.gitattributes") | Where-Object { $_ -eq '.fluencyloop/** text eol=lf' }).Count | Should -Be 1
        @((Get-Content "$script:repo/.gitattributes") | Where-Object { $_ -eq 'docs/fluencyloop/** text eol=lf' }).Count | Should -Be 1
    }

    It 'vendors skills for Claude Code by default' {
        $script:repo = New-TestRepo
        & $script:PwshExe -NoProfile -File "$script:Bin/init.ps1" '--vendor-skills' | Out-Null
        "$script:repo/.claude/skills/fluencyloop/SKILL.md" | Should -Exist
        "$script:repo/.codex/skills" | Should -Not -Exist
    }

    It 'can vendor skills for Codex' {
        $script:repo = New-TestRepo
        & $script:PwshExe -NoProfile -File "$script:Bin/init.ps1" '--vendor-skills' '--agent' 'codex' | Out-Null
        "$script:repo/.codex/skills/fluencyloop/SKILL.md" | Should -Exist
        "$script:repo/.claude/skills" | Should -Not -Exist
    }

    It 'sets push.autoSetupRemote' {
        $script:repo = Initialize-TestRepo
        (git -C $script:repo config --local push.autoSetupRemote) | Should -Be 'true'
    }

    It 'init --json emits a valid contract' {
        $script:repo = New-TestRepo
        $j = Get-FlJson 'init.ps1' '--json'
        $j.constitution_created | Should -Be 'true'
        $j.docs_dir | Should -Not -BeNullOrEmpty
    }
}
