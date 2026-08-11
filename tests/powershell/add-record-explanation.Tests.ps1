# add-record-explanation.ps1 — mirrors tests/add-record-explanation.bats.

Describe 'add-record-explanation.ps1' {
    BeforeAll { . "$PSScriptRoot/_helper.ps1" }
    AfterEach {
        Set-Location -LiteralPath $PSScriptRoot
        if ($script:repo) { Remove-Item -Recurse -Force -LiteralPath $script:repo -ErrorAction SilentlyContinue }
    }

    BeforeEach {
        $script:repo = Initialize-TestRepo
        & $script:PwshExe -NoProfile -File "$script:Bin/new-feature.ps1" 'explain the cache' | Out-Null
        & $script:PwshExe -NoProfile -File "$script:Bin/new-session.ps1" '--slug' '001-explain-cache' 'write record explanation' | Out-Null
        $script:store = "$script:repo/docs/fluencyloop/store/concepts.jsonl"
        $script:requiredExplanationArgs = @(
            '--record', 'read through cache',
            '--context', 'Repeated remote reads add latency.',
            '--decision', 'Read the cache before the remote service.',
            '--mechanism', 'The client checks the local value and fetches only after a miss.',
            '--consequences', 'Repeated reads are fast, while callers must accept bounded staleness.'
        )
    }

    It 'appends a schema-complete architectural record explanation' {
        & $script:PwshExe -NoProfile -File "$script:Bin/add-record-explanation.ps1" @($script:requiredExplanationArgs) | Out-Null
        $record = ([System.IO.File]::ReadAllLines($script:store) | Select-Object -Last 1) | ConvertFrom-Json
        $record.schema_version | Should -Be '1'
        $record.type | Should -Be 'record_explanation'
        $record.feature | Should -Be '001-explain-cache'
        $record.session | Should -Be '001-write-record-explanation'
        $record.record | Should -Be 'read through cache'
        $record.context | Should -Be 'Repeated remote reads add latency.'
        $record.decision | Should -Be 'Read the cache before the remote service.'
        $record.mechanism | Should -Be 'The client checks the local value and fetches only after a miss.'
        $record.consequences | Should -Be 'Repeated reads are fast, while callers must accept bounded staleness.'
        ($record.PSObject.Properties.Name -contains 'diagram_path') | Should -BeFalse
    }

    It 'stores an optional diagram only with complete safe metadata' {
        $diagram = "$script:repo/docs/fluencyloop/diagrams/records/read-through-cache.html"
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $diagram) | Out-Null
        Copy-Item -LiteralPath "$PSScriptRoot/../../LICENSE" -Destination $diagram
        $diagramArgs = @($script:requiredExplanationArgs) + @('--diagram', 'docs/fluencyloop/diagrams/records/read-through-cache.html', '--diagram-type', 'architecture', '--diagram-alt', 'A cache client reads a local value before the remote service.')
        & $script:PwshExe -NoProfile -File "$script:Bin/add-record-explanation.ps1" @diagramArgs | Out-Null

        $record = ([System.IO.File]::ReadAllLines($script:store) | Select-Object -Last 1) | ConvertFrom-Json
        $record.diagram_path | Should -Be 'docs/fluencyloop/diagrams/records/read-through-cache.html'
        $record.diagram_type | Should -Be 'architecture'
        $record.diagram_alt | Should -Be 'A cache client reads a local value before the remote service.'
    }

    It 'rejects incomplete diagram metadata' {
        (Invoke-FlExit 'add-record-explanation.ps1' '--record' 'read through cache' '--context' 'latency' '--decision' 'cache first' '--mechanism' 'check local value' '--consequences' 'bounded staleness' '--diagram-type' 'architecture') | Should -Not -Be 0
    }
}
