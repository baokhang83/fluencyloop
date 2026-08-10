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

    It 'imports full and minimal decisions plus one explicit legacy declaration pair' {
        (Invoke-FlExit 'import-legacy.ps1') | Should -Be 0
        (Invoke-FlAll 'import-legacy.ps1') | Should -Match 'Warning: skipped malformed legacy record'

        $records = @([System.IO.File]::ReadAllLines($script:store) | ForEach-Object { $_ | ConvertFrom-Json })
        $records.Count | Should -Be 4
        $decisions = @($records | Where-Object { $_.type -eq 'decision' })
        $feature = $records | Where-Object { $_.type -eq 'feature' }
        $session = $records | Where-Object { $_.type -eq 'session' }
        $decisions[0].title | Should -Be 'choose an LRU cache'
        $decisions[0].where | Should -Be 'src/cache.js'
        $decisions[0].why | Should -Be 'memory must stay bounded'
        $decisions[0].alternative | Should -Be 'unbounded map - rejected: leaks'
        $decisions[0].design | Should -Be '../design.md#cache'
        $decisions[0].constitution | Should -Be 'section-2'
        $decisions[0].trust | Should -Be 'verified'
        $decisions[1].title | Should -Be 'cache failures remain visible'
        $decisions[1].trust | Should -Be 'unverified'
        foreach ($field in @('alternative', 'design', 'constitution')) {
            $decisions[1].PSObject.Properties.Name | Should -Not -Contain $field
        }
        for ($i = 0; $i -lt $decisions.Count; $i++) {
            $decisions[$i].feature | Should -Be '001-add-caching'
            $decisions[$i].session | Should -Be '001-wire-cache'
            $decisions[$i].imported_from | Should -Match "#decision-$($i + 1)$"
        }
        $feature.slug | Should -Be '001-add-caching'
        $feature.branch | Should -Be 'legacy-import/001-add-caching'
        $feature.base_ref | Should -Be 'legacy'
        $feature.imported_from | Should -Match '#feature$'
        $session.slug | Should -Be '000-legacy-import'
        $session.intent | Should -Be 'Backfill pre-0.3 session history.'
        $session.imported_from | Should -Match '#backfill-session$'
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

    It 'requires architectural records and an assessment for every imported feature before completion' {
        (Invoke-FlExit 'check.ps1' '--json') | Should -Be 0
        (Invoke-FlExit 'import-legacy.ps1' '--mark-semantic-complete') | Should -Be 1
        (Invoke-FlAll 'import-legacy.ps1' '--mark-semantic-complete') | Should -Match 'assessed 0 of 1 imported feature'

        $status = (& $script:PwshExe -NoProfile -File "$script:Bin/import-legacy.ps1" '--semantic-status' '--json') | ConvertFrom-Json
        $status.architectural_records | Should -Be 0
        @($status.unassessed_features) | Should -Contain '001-add-caching'

        (Invoke-FlExit 'add-concept.ps1' '--name' 'bounded cache' '--problem' 'keep repeated reads fast without unbounded memory' '--how' 'reuse values through an LRU cache' '--realized-by' 'src/cache.js' '--feature' '001-add-caching' '--session' '000-legacy-import') | Should -Be 0
        (Invoke-FlExit 'import-legacy.ps1' '--mark-semantic-complete') | Should -Be 1
        (Invoke-FlExit 'import-legacy.ps1' '--assess' '001-add-caching' '--summary' 'The imported cache decisions establish bounded reuse for repeated reads.' '--record' 'bounded cache') | Should -Be 0
        (Invoke-FlExit 'import-legacy.ps1' '--mark-semantic-complete') | Should -Be 0

        $j = (& $script:PwshExe -NoProfile -File "$script:Bin/check.ps1" '--json') | ConvertFrom-Json
        $j.legacy_migration_pending | Should -BeFalse
    }

    It 'a normal command repairs a store imported before declaration records existed' {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $script:store) | Out-Null
        [System.IO.File]::WriteAllText($script:store,
            '{"schema_version":"1","type":"decision","ts":"2026-08-09","feature":"001-add-caching","session":"001-wire-cache","commit":"abc","title":"choose an LRU cache","where":"src/cache.js","why":"memory must stay bounded","trust":"verified","imported_from":"docs/fluencyloop/features/001-add-caching/sessions/001-wire-cache.md#decision-1"}' + [Environment]::NewLine,
            (New-Object System.Text.UTF8Encoding($false)))

        $j = (& $script:PwshExe -NoProfile -File "$script:Bin/check.ps1" '--json') | ConvertFrom-Json
        $j.fluency | Should -Be $true

        $records = @([System.IO.File]::ReadAllLines($script:store) | ForEach-Object { $_ | ConvertFrom-Json })
        @($records | Where-Object { $_.type -eq 'feature' }).Count | Should -Be 1
        @($records | Where-Object { $_.type -eq 'session' -and $_.slug -eq '000-legacy-import' }).Count | Should -Be 1
        @($records | Where-Object { $_.type -eq 'decision' -and $_.title -eq 'choose an LRU cache' }).Count | Should -Be 1
    }

    It 'automatic repair leaves a native feature declaration with a legacy slug alone' {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $script:store) | Out-Null
        [System.IO.File]::WriteAllText($script:store,
            '{"schema_version":"1","type":"feature","ts":"2026-08-09","feature":"001-add-caching","session":"none","commit":"abc","slug":"001-add-caching","intent":"native 0.3 work","branch":"feature/001-add-caching","base_ref":"dev"}' + [Environment]::NewLine,
            (New-Object System.Text.UTF8Encoding($false)))

        $j = (& $script:PwshExe -NoProfile -File "$script:Bin/check.ps1" '--json') | ConvertFrom-Json
        $j.fluency | Should -Be $true

        $records = @([System.IO.File]::ReadAllLines($script:store) | ForEach-Object { $_ | ConvertFrom-Json })
        $records.Count | Should -Be 1
        $records[0].intent | Should -Be 'native 0.3 work'
    }

    It 'retries a completed legacy import once when the importer revision advances' {
        $text = @(
            '# Session',
            '### Hard-won conditions (gotchas, root causes, limitations)',
            '- **Windows pack-file locks**, so scratch cleanup is best effort while **isolated cleanup** is deterministic. · status: follow-up'
        ) -join "`n"
        [System.IO.File]::WriteAllText($script:legacy, $text + "`n", (New-Object System.Text.UTF8Encoding($false)))
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $script:store) | Out-Null
        [System.IO.File]::WriteAllText($script:store,
            '{"schema_version":"1","type":"feature","ts":"2026-08-09","feature":"001-add-caching","session":"none","commit":"abc","slug":"001-add-caching","intent":"Imported pre-0.3 session history.","branch":"legacy-import/001-add-caching","base_ref":"legacy","imported_from":"docs/fluencyloop/features/001-add-caching#feature"}' + [Environment]::NewLine +
            '{"schema_version":"1","type":"session","ts":"2026-08-09","feature":"001-add-caching","session":"000-legacy-import","commit":"abc","slug":"000-legacy-import","intent":"Backfill pre-0.3 session history.","imported_from":"docs/fluencyloop/features/001-add-caching#backfill-session"}' + [Environment]::NewLine,
            (New-Object System.Text.UTF8Encoding($false)))

        $j = (& $script:PwshExe -NoProfile -File "$script:Bin/check.ps1" '--json') | ConvertFrom-Json
        $j.fluency | Should -Be $true
        ([System.IO.File]::ReadAllText("$script:repo/docs/fluencyloop/store/.legacy-import-revision")).Trim() | Should -Be '2'

        $records = @([System.IO.File]::ReadAllLines($script:store) | ForEach-Object { $_ | ConvertFrom-Json })
        $record = $records | Where-Object { $_.type -eq 'condition' }
        $record.subject | Should -Be 'Windows pack-file locks'
        $record.why | Should -Match '^, so scratch cleanup'
        $record.why | Should -Match '\*\*isolated cleanup\*\*'
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

        It 'accepts punctuation immediately after a bold knowledge title' {
            $text = @(
                '# Session',
                '### Hard-won conditions (gotchas, root causes, limitations)',
                '- **Windows pack-file locks**, so scratch cleanup is best effort while **isolated cleanup** is deterministic. · status: follow-up'
            ) -join "`n"
            [System.IO.File]::WriteAllText($script:legacy, $text + "`n", (New-Object System.Text.UTF8Encoding($false)))

            $out = Invoke-FlAll 'import-legacy.ps1'
            $out | Should -Not -Match 'skipped malformed'
            $record = [System.IO.File]::ReadAllLines($script:store) | Select-Object -First 1 | ConvertFrom-Json
            $record.subject | Should -Be 'Windows pack-file locks'
            $record.why | Should -Match '^, so scratch cleanup'
            $record.why | Should -Match '\*\*isolated cleanup\*\*'
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
