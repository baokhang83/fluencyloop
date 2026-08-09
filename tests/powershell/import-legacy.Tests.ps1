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

    # The five cases below are regressions found by running the importer against a real 47-feature
    # corpus (blastradius): none are synthetic edge cases. Backfilled decisions there wrap `why:`
    # and `alternative:` across lines, cite more than one file in `where:`, annotate `trust:` with
    # a review note, and add a hand-written `- **note:**` field the schema doesn't define. Before
    # this fix, each of those independently caused the whole decision — or, compounded, the whole
    # feature — to import as zero records with no summary indicating a total loss.
    Context 'legacy dialects found in a real corpus' {
        BeforeEach {
            $em = [string][char]0x2014
            $dot = [string][char]0x00B7
            $check = [string][char]0x2713
        }

        It 'reflows a why/alternative field the legacy writer wrapped across lines' {
            $text = @(
                '## Decision: JGit in-process for commit traversal',
                '- **where:** `git/CommitCheckout.java`',
                '- **why:** JGit walks the commit range and materializes each commit',
                "  in-process, never touching the target repo's HEAD.",
                "- **alternative:** shell out to the ``git`` CLI $em rejected: harder to",
                '  unit test and brittle across git versions.',
                "- **trust:** $check verified"
            ) -join "`n"
            [System.IO.File]::WriteAllText($script:legacy, $text + "`n", (New-Object System.Text.UTF8Encoding($false)))

            $out = Invoke-FlAll 'import-legacy.ps1'
            $out | Should -Not -Match 'skipped malformed'
            $record = [System.IO.File]::ReadAllLines($script:store) | Select-Object -First 1 | ConvertFrom-Json
            $record.why | Should -Be "JGit walks the commit range and materializes each commit in-process, never touching the target repo's HEAD."
            $record.alternative | Should -Be "shell out to the ``git`` CLI $em rejected: harder to unit test and brittle across git versions."
        }

        It 'accepts a where field naming more than one path' {
            $text = @(
                '## Decision: shared resolver for two files',
                '- **where:** `git/CommitCheckout.java`, `git/CommitWindowResolver.java`',
                '- **why:** one resolver keeps both in lockstep',
                "- **trust:** $check verified"
            ) -join "`n"
            [System.IO.File]::WriteAllText($script:legacy, $text + "`n", (New-Object System.Text.UTF8Encoding($false)))

            $out = Invoke-FlAll 'import-legacy.ps1'
            $out | Should -Not -Match 'skipped malformed'
            $record = [System.IO.File]::ReadAllLines($script:store) | Select-Object -First 1 | ConvertFrom-Json
            $record.where | Should -Be '`git/CommitCheckout.java`, `git/CommitWindowResolver.java`'
        }

        It 'normalizes an annotated trust line and does not fail the decision' {
            $text = @(
                '## Decision: annotated trust',
                '- **where:** `src/x.java`',
                '- **why:** because',
                "- **trust:** $check verified $em maintainer-confirmed on backfill review (2026-07-12)"
            ) -join "`n"
            [System.IO.File]::WriteAllText($script:legacy, $text + "`n", (New-Object System.Text.UTF8Encoding($false)))

            $out = Invoke-FlAll 'import-legacy.ps1'
            $out | Should -Not -Match 'skipped malformed'
            $record = [System.IO.File]::ReadAllLines($script:store) | Select-Object -First 1 | ConvertFrom-Json
            $record.trust | Should -Be 'verified'
        }

        It 'drops an unrecognized well-formed field instead of failing the whole decision' {
            $text = @(
                '## Decision: has an extra note',
                '- **where:** `src/x.java`',
                '- **why:** because',
                '- **note:** shipped as a binary classifier; a later refinement is separate work.',
                "- **trust:** $check verified"
            ) -join "`n"
            [System.IO.File]::WriteAllText($script:legacy, $text + "`n", (New-Object System.Text.UTF8Encoding($false)))

            $out = Invoke-FlAll 'import-legacy.ps1'
            $out | Should -Not -Match 'skipped malformed'
            $record = [System.IO.File]::ReadAllLines($script:store) | Select-Object -First 1 | ConvertFrom-Json
            $record.why | Should -Be 'because'
            $record.PSObject.Properties.Name | Should -Not -Contain 'note'
        }

        It 'reflows a components bullet the legacy writer wrapped across lines, ending in the status marker' {
            $text = @(
                '# Session',
                '### Components (role, conditions)',
                "- **``BuildCache``** $em a disk-backed store of successful builds keyed by",
                '  a sha, living at `<report>.cache/`. `store` writes atomically so a',
                "  crash mid-write never leaves a truncated file. $dot status: documented",
                '### Hard-won conditions (gotchas, root causes, limitations)',
                "- **linear heap growth, not a leak in one build** $em Phase 1",
                "  accumulated every commit into one map held for the whole run. $dot status: documented"
            ) -join "`n"
            [System.IO.File]::WriteAllText($script:legacy, $text + "`n", (New-Object System.Text.UTF8Encoding($false)))

            $out = Invoke-FlAll 'import-legacy.ps1'
            $out | Should -Not -Match 'skipped malformed'
            $records = @([System.IO.File]::ReadAllLines($script:store) | ForEach-Object { $_ | ConvertFrom-Json })
            $component = $records | Where-Object { $_.type -eq 'component' }
            $condition = $records | Where-Object { $_.type -eq 'condition' }
            $component.name | Should -Be '`BuildCache`'
            $component.role | Should -Match 'never leaves a truncated file\.$'
            $component.status | Should -Be 'documented'
            $condition.why | Should -Match 'held for the whole run\.$'
        }

        It 'accepts a condition bullet whose name ends its own sentence instead of using an em dash' {
            $text = @(
                '# Session',
                '### Hard-won conditions (gotchas, root causes, limitations)',
                '- **The OOM was linear heap growth, not a leak in one build.** Phase 1',
                "  accumulated every commit into one map held for the whole run. $dot status: documented"
            ) -join "`n"
            [System.IO.File]::WriteAllText($script:legacy, $text + "`n", (New-Object System.Text.UTF8Encoding($false)))

            $out = Invoke-FlAll 'import-legacy.ps1'
            $out | Should -Not -Match 'skipped malformed'
            $record = [System.IO.File]::ReadAllLines($script:store) | Select-Object -First 1 | ConvertFrom-Json
            $record.subject | Should -Be 'The OOM was linear heap growth, not a leak in one build.'
            $record.why | Should -Match 'held for the whole run\.$'
        }

        It "an em-dash-separated bullet's role text has no leftover leading dash" {
            $text = @(
                '# Session',
                '### Components (role, conditions)',
                "- **``Widget``** $em does the thing $dot status: documented"
            ) -join "`n"
            [System.IO.File]::WriteAllText($script:legacy, $text + "`n", (New-Object System.Text.UTF8Encoding($false)))

            $out = Invoke-FlAll 'import-legacy.ps1'
            $out | Should -Not -Match 'skipped malformed'
            $record = [System.IO.File]::ReadAllLines($script:store) | Select-Object -First 1 | ConvertFrom-Json
            $record.role | Should -Be 'does the thing'
        }

        It 'reports a components bullet abandoned by a heading with no status marker, without double-counting' {
            $text = @(
                '# Session',
                '### Components (role, conditions)',
                "- **Broken** $em this bullet never reaches its status marker",
                '## Next section'
            ) -join "`n"
            [System.IO.File]::WriteAllText($script:legacy, $text + "`n", (New-Object System.Text.UTF8Encoding($false)))

            $out = Invoke-FlAll 'import-legacy.ps1'
            $out | Should -Match 'skipped malformed legacy record.*#component-1'
            ($out -split "`n" | Where-Object { $_ -match 'skipped malformed' }).Count | Should -Be 1
        }
    }
}
