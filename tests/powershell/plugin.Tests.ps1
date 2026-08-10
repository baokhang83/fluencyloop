Describe 'FluencyLoop SessionStart hook' {
    BeforeAll {
        . "$PSScriptRoot/_helper.ps1"
        $script:Hook = (Resolve-Path "$PSScriptRoot/../../plugins/fluencyloop/hooks/refresh-marketplace.ps1").Path
        $script:OriginalLocation = Get-Location
    }

    AfterEach {
        Set-Location -LiteralPath $script:OriginalLocation
        if ($script:repo) { Remove-Item -Recurse -Force -LiteralPath $script:repo -ErrorAction SilentlyContinue }
        $script:repo = $null
        Remove-Item Env:PLUGIN_ROOT -ErrorAction SilentlyContinue
        Remove-Item Env:CLAUDE_PLUGIN_ROOT -ErrorAction SilentlyContinue
        Remove-Item Env:SITE_CALLS -ErrorAction SilentlyContinue
    }

    It 'ensures a managed site only after FluencyLoop is initialized' {
        $script:repo = Initialize-TestRepo
        $pluginRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("fl-plugin-" + [guid]::NewGuid().ToString('N'))
        $calls = Join-Path ([System.IO.Path]::GetTempPath()) ("fl-site-calls-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $pluginRoot | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $pluginRoot 'fluencyloop.ps1'), '[System.IO.File]::AppendAllText($env:SITE_CALLS, (($args -join '' '') + "`n"))')
        $env:PLUGIN_ROOT = $pluginRoot
        $env:SITE_CALLS = $calls
        try {
            & $script:PwshExe -NoProfile -File $script:Hook
            $LASTEXITCODE | Should -Be 0
            (Get-Content -LiteralPath $calls -Raw).Trim() | Should -Be 'site --ensure --json'
        } finally {
            Remove-Item -Recurse -Force -LiteralPath $pluginRoot -ErrorAction SilentlyContinue
            Remove-Item -Force -LiteralPath $calls -ErrorAction SilentlyContinue
        }
    }
}
