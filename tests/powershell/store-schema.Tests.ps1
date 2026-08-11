# STORE.md is the one schema reference. Mirrors tests/store-schema.bats.

Describe 'store schema documentation' {
    It 'documents one valid JSON example for every record type' {
        $store = Join-Path $PSScriptRoot '../../plugins/fluencyloop/STORE.md'
        $text = [System.IO.File]::ReadAllText($store)
        $matches = [regex]::Matches($text, '(?s)```json\r?\n(.*?)\r?\n```')
        $examples = @($matches | ForEach-Object { $_.Groups[1].Value | ConvertFrom-Json })
        $expected = @('feature', 'session', 'decision', 'component', 'condition', 'concept', 'relation', 'record_explanation', 'principle', 'requirement', 'open_question')

        $examples.Count | Should -Be $expected.Count
        (($examples.type | Sort-Object) -join ',') | Should -Be (($expected | Sort-Object) -join ',')
        foreach ($example in $examples) {
            foreach ($field in @('schema_version', 'type', 'ts', 'feature', 'session', 'commit')) {
                $example.PSObject.Properties.Name | Should -Contain $field -Because "$($example.type) needs the common envelope"
            }
        }
    }
}
