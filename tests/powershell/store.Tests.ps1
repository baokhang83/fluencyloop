# common.ps1 — the append-only store: paths and FlStoreAppend. Mirrors tests/store.bats.

Describe 'store' {
    BeforeAll {
        . "$PSScriptRoot/_helper.ps1"
        . "$script:Bin/common.ps1"
        $script:repo = $null   # StrictMode (from common.ps1) needs this defined for AfterEach

        # Every line must parse on its own — the property the site and every reader depend on.
        function Assert-ValidJsonl([string]$path) {
            foreach ($line in [System.IO.File]::ReadAllLines($path)) {
                if ($line -eq '') { continue }
                { $line | ConvertFrom-Json } | Should -Not -Throw -Because "line: $line"
            }
        }
    }
    AfterEach {
        Set-Location -LiteralPath $PSScriptRoot
        if ($script:repo) { Remove-Item -Recurse -Force -LiteralPath $script:repo -ErrorAction SilentlyContinue; $script:repo = $null }
    }

    It 'store paths live under docs/fluencyloop/store' {
        $script:repo = Initialize-TestRepo
        FlStoreDir | Should -Be "$script:repo/docs/fluencyloop/store"
        FlFeatureStorePath 'add-caching' | Should -Be "$script:repo/docs/fluencyloop/store/features/add-caching.jsonl"
        FlConceptsStorePath | Should -Be "$script:repo/docs/fluencyloop/store/concepts.jsonl"
    }

    It 'FlStoreAppend creates the parent dir and writes one line' {
        $script:repo = Initialize-TestRepo
        $f = FlFeatureStorePath 'add-caching'
        Test-Path -LiteralPath (Split-Path -Parent $f) | Should -BeFalse
        FlStoreAppend $f @('type', 'decision', 'title', 'Chose a read-through cache')
        [System.IO.File]::ReadAllText($f) | Should -Be "{`"type`":`"decision`",`"title`":`"Chose a read-through cache`"}`n"
        Assert-ValidJsonl $f
    }

    It 'FlStoreAppend appends without truncating' {
        $script:repo = Initialize-TestRepo
        $f = FlConceptsStorePath
        FlStoreAppend $f @('type', 'concept', 'name', 'supersede-on-read')
        FlStoreAppend $f @('type', 'concept', 'name', 'per-feature stream')
        FlStoreAppend $f @('type', 'relation', 'from', 'supersede-on-read', 'to', 'per-feature stream')
        $lines = @([System.IO.File]::ReadAllLines($f) | Where-Object { $_ -ne '' })
        $lines.Count | Should -Be 3
        $lines[0] | Should -Be '{"type":"concept","name":"supersede-on-read"}'
        Assert-ValidJsonl $f
    }

    It 'FlStoreAppend skips pairs whose value is empty' {
        $script:repo = Initialize-TestRepo
        $f = FlFeatureStorePath 'opt'
        FlStoreAppend $f @('type', 'decision', 'alternative', '', 'why', 'measured, not guessed', 'design', '')
        $line = ([System.IO.File]::ReadAllLines($f))[0]
        $line | Should -Be '{"type":"decision","why":"measured, not guessed"}'
        # The keys are absent entirely, not present-and-empty.
        $line | Should -Not -Match 'alternative'
    }

    It 'FlStoreAppend round-trips quotes, backslashes, and newlines' {
        $script:repo = Initialize-TestRepo
        $f = FlFeatureStorePath 'esc'
        FlStoreAppend $f @('type', 'note', 'text', 'he said "no" \ then left', 'body', "one`ntwo")
        $lines = @([System.IO.File]::ReadAllLines($f) | Where-Object { $_ -ne '' })
        # Still exactly one line: the embedded newline is escaped, not written raw.
        $lines.Count | Should -Be 1
        Assert-ValidJsonl $f
        $o = $lines[0] | ConvertFrom-Json
        $o.text | Should -Be 'he said "no" \ then left'
        $o.body | Should -Be "one`ntwo"
    }

    It 'FlStoreAppend with no pairs writes an empty object rather than failing' {
        $script:repo = Initialize-TestRepo
        $f = FlFeatureStorePath 'empty'
        FlStoreAppend $f @()
        ([System.IO.File]::ReadAllLines($f))[0] | Should -Be '{}'
    }

    It 'FlStoreAppendRecord stamps the common envelope and requires context' {
        $script:repo = Initialize-TestRepo
        $f = FlFeatureStorePath 'add-caching'
        FlStoreAppendRecord $f 'decision' 'add-caching' '001-wire-cache' @('title', 'keep it bounded', 'where', 'src/cache.js', 'why', 'memory is finite')
        $record = ([System.IO.File]::ReadAllLines($f))[0] | ConvertFrom-Json
        $record.schema_version | Should -Be '1'
        $record.type | Should -Be 'decision'
        $record.feature | Should -Be 'add-caching'
        $record.session | Should -Be '001-wire-cache'
        $record.commit | Should -Be (git rev-parse HEAD)
        $record.title | Should -Be 'keep it bounded'
        { FlStoreAppendRecord $f 'decision' '' '001-wire-cache' @() } | Should -Throw
    }

    It 'store files are covered by the LF pin init.ps1 writes' {
        # Append correctness on Windows depends on the store subtree being pinned to LF. The glob
        # `docs/fluencyloop/**` matches across directories, so it already covers store/.
        $script:repo = Initialize-TestRepo
        (git check-attr text -- 'docs/fluencyloop/store/features/x.jsonl') | Should -Match 'text: set$'
        (git check-attr eol -- 'docs/fluencyloop/store/concepts.jsonl') | Should -Match 'eol: lf$'
    }

    It 'writes bytes identical to the bash runtime for the same input' {
        # The two runtimes are one contract: a line appended by either must be byte-for-byte the
        # same, or a repo written on Windows and read on Linux diverges silently.
        $script:repo = Initialize-TestRepo
        $f = FlFeatureStorePath 'parity'
        FlStoreAppend $f @('type', 'decision', 'why', 'he said "no" \ then left', 'skip', '')
        # Compared base64-encoded rather than as two byte arrays, so a mismatch is one clear
        # string diff and there is no ambiguity about how the assertion compares collections.
        $bytes = [System.IO.File]::ReadAllBytes($f)
        $expected = [System.Text.Encoding]::UTF8.GetBytes('{"type":"decision","why":"he said \"no\" \\ then left"}' + "`n")
        [System.Convert]::ToBase64String($bytes) | Should -Be ([System.Convert]::ToBase64String($expected))
    }
}
