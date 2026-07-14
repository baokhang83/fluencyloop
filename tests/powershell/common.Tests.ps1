# common.ps1 helpers — mirrors tests/common.bats.

Describe 'common.ps1' {
    BeforeAll {
        . "$PSScriptRoot/_helper.ps1"
        . "$script:Bin/common.ps1"
        $script:repo = $null   # StrictMode (from common.ps1) needs this defined for AfterEach
    }
    AfterEach {
        Set-Location -LiteralPath $PSScriptRoot
        if ($script:repo) { Remove-Item -Recurse -Force -LiteralPath $script:repo -ErrorAction SilentlyContinue; $script:repo = $null }
    }

    It 'slugify lowercases, hyphenates, trims' {
        FlSlugify 'Adding Rate Limiting to the Gateway!' | Should -Be 'adding-rate-limiting-to-the-gateway'
        FlSlugify '  spaces  and--dashes  ' | Should -Be 'spaces-and-dashes'
        FlSlugify 'UPPER/slash:colon' | Should -Be 'upper-slash-colon'
    }

    It 'slugify caps length at 60 and strips a trailing hyphen' {
        $out = FlSlugify ('a' * 80)
        $out.Length | Should -BeLessOrEqual 60
        $out[-1] | Should -Not -Be '-'
    }

    It 'branch_for maps a slug to a feature branch' {
        $b = FlBranchFor 'add-caching'
        $b | Should -Be 'feature/add-caching'
    }

    It 'feature_path and plan_path live under docs/fluencyloop' {
        $script:repo = Initialize-TestRepo
        FlFeaturePath 'foo' | Should -Be "$script:repo/docs/fluencyloop/features/foo"
        FlPlanPath 'bar' | Should -Be "$script:repo/docs/fluencyloop/plans/bar"
    }

    It 'json_escape escapes quotes, backslashes, newlines' {
        FlJsonEscape 'a"b\c' | Should -Be 'a\"b\\c'
        FlJsonEscape "x`ny" | Should -Be 'x\ny'
    }

    It 'emit_json produces a valid flat object' {
        $o = (FlEmitJson @('a', '1', 'b', 'two words')) | ConvertFrom-Json
        $o.a | Should -Be '1'
        $o.b | Should -Be 'two words'
    }

    It 'write_state then state_get round-trips fields' {
        $script:repo = Initialize-TestRepo
        FlWriteState @('feature', 'foo', 'branch', 'feature/foo', 'stage', 'design', 'base_ref', 'main')
        FlStateGet 'feature' | Should -Be 'foo'
        FlStateGet 'stage' | Should -Be 'design'
        FlStateGet 'base_ref' | Should -Be 'main'
        { Get-Content -Raw "$script:repo/.fluencyloop/state.json" | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'state_get returns empty for a missing key or missing file' {
        $script:repo = Initialize-TestRepo
        FlWriteState @('feature', 'foo')
        FlStateGet 'nope' | Should -Be ''
        Remove-Item -LiteralPath "$script:repo/.fluencyloop/state.json" -Force
        FlStateGet 'feature' | Should -Be ''
    }

    It 'repo_rel makes a path relative to the repo root' {
        $script:repo = Initialize-TestRepo
        FlRepoRel "$script:repo/docs/fluencyloop/x.md" | Should -Be 'docs/fluencyloop/x.md'
    }

    It 'every ported script sets StrictMode' {
        Get-ChildItem -LiteralPath $script:Bin -Filter '*.ps1' | ForEach-Object {
            (Get-Content -Raw $_.FullName) | Should -Match 'Set-StrictMode' -Because $_.Name
        }
    }
}
