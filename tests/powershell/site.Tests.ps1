# The PowerShell dispatcher starts the same bundled Node reader as Bash. This catches argument
# forwarding and process-lifetime differences on native Windows.

Describe 'fluencyloop site' {
    BeforeAll {
        . "$PSScriptRoot/_helper.ps1"
        $script:Cli = (Resolve-Path "$PSScriptRoot/../../plugins/fluencyloop/fluencyloop.ps1").Path
        $script:Node = Get-Command node -CommandType Application -ErrorAction SilentlyContinue
        $script:repo = $null
        $script:siteProcess = $null
        $script:siteLog = $null
        $script:siteError = $null
    }
    AfterEach {
        Set-Location -LiteralPath $PSScriptRoot
        if ($script:siteProcess -and -not $script:siteProcess.HasExited) {
            Stop-Process -Id $script:siteProcess.Id -Force -ErrorAction SilentlyContinue
        }
        if ($script:repo) { Remove-Item -Recurse -Force -LiteralPath $script:repo -ErrorAction SilentlyContinue }
        if ($script:siteLog) { Remove-Item -Force -LiteralPath $script:siteLog -ErrorAction SilentlyContinue }
        if ($script:siteError) { Remove-Item -Force -LiteralPath $script:siteError -ErrorAction SilentlyContinue }
        $script:siteProcess = $null; $script:siteLog = $null; $script:siteError = $null
    }

    It 'serves the current repository through the PowerShell dispatcher' {
        if (-not $script:Node) { Set-ItResult -Skipped -Because 'Node.js is required for the site test'; return }
        $script:repo = Initialize-TestRepo
        $script:siteLog = Join-Path $script:repo 'site.stdout'
        $script:siteError = Join-Path $script:repo 'site.stderr'
        $storeDir = Join-Path $script:repo 'docs/fluencyloop/store'
        New-Item -ItemType Directory -Force -Path (Join-Path $storeDir 'features') | Out-Null
        $distillationDir = Join-Path $script:repo 'docs/fluencyloop/distillations'
        New-Item -ItemType Directory -Force -Path (Join-Path $distillationDir 'features') | Out-Null
        [System.IO.File]::WriteAllLines((Join-Path $storeDir 'features/ps-navigation.jsonl'), @(
            '{"schema_version":"1","type":"feature","ts":"2026-08-09","feature":"ps-navigation","session":"none","commit":"abc","slug":"ps-navigation","intent":"prove native route dispatch","branch":"feature/ps-navigation","base_ref":"dev"}',
            '{"schema_version":"1","type":"requirement","ts":"2026-08-09","feature":"ps-navigation","session":"none","commit":"abc","gap":"Can deep links load directly?","answer":"Yes, via server routes.","consequence":"Links are durable."}',
            '{"schema_version":"1","type":"decision","ts":"2026-08-09","feature":"ps-navigation","session":"001","commit":"abc","title":"deep-route","where":"site","why":"the dispatcher shares the bundled reader"}'
        ), [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllLines((Join-Path $storeDir 'concepts.jsonl'), @(
            '{"schema_version":"1","type":"concept","ts":"2026-08-09","feature":"ps-navigation","session":"001","commit":"abc","name":"PowerShell concept","problem":"verify the Windows entry point","how":"serve the same local routes","realized_by":"fluencyloop.ps1","tags":"native dispatch"}',
            '{"schema_version":"1","type":"relation","ts":"2026-08-09","feature":"ps-navigation","session":"001","commit":"abc","from":"PowerShell concept","to":"ps-navigation","kind":"realized_by"}'
        ), [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllLines((Join-Path $distillationDir 'product.md'), @(
            'The prose explains the reader before the diagram supports it.',
            '```mermaid',
            'flowchart LR',
            '  Writer[Writer] --> Reader[Reader]',
            '```',
            'Diagram: The reader observes records after the writer appends them.'
        ), [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllLines((Join-Path $distillationDir 'features/ps-navigation.md'), @(
            'The feature still has a written explanation.',
            '```mermaid',
            'not a supported diagram',
            '```',
            'Diagram: A bad visual never hides the written explanation.'
        ), [System.Text.UTF8Encoding]::new($false))
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $listener.Start()
        $port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
        $listener.Stop()
        $script:siteProcess = Start-Process -FilePath $script:PwshExe `
            -ArgumentList @('-NoProfile', '-File', $script:Cli, 'site', '--port', $port) `
            -WorkingDirectory $script:repo -RedirectStandardOutput $script:siteLog `
            -RedirectStandardError $script:siteError -PassThru

        $url = "http://127.0.0.1:$port"
        $ready = $false
        for ($i = 0; $i -lt 100; $i++) {
            try {
                $health = Invoke-WebRequest -Uri "$url/health" -UseBasicParsing -ErrorAction Stop
                if ($health.StatusCode -eq 200) { $ready = $true; break }
            } catch { }
            Start-Sleep -Milliseconds 100
        }
        if (-not $ready) {
            $stdout = if (Test-Path -LiteralPath $script:siteLog) { Get-Content -LiteralPath $script:siteLog -Raw } else { '' }
            $stderr = if (Test-Path -LiteralPath $script:siteError) { Get-Content -LiteralPath $script:siteError -Raw } else { '' }
            throw "Site did not bind to $url. stdout: $stdout stderr: $stderr"
        }

        $page = Invoke-WebRequest -Uri "$url/" -UseBasicParsing
        $page.StatusCode | Should -Be 200
        $page.Headers['Content-Type'] | Should -Match 'text/html'
        $page.Content | Should -Match 'FluencyLoop'
        $page.Content | Should -Match 'href="/assets/site.css"'
        $page.Content | Should -Match 'data-theme-toggle'
        $page.Content | Should -Match 'class="diagram"'
        $page.Content | Should -Match 'The reader observes records after the writer appends them.'

        $styles = Invoke-WebRequest -Uri "$url/assets/site.css" -UseBasicParsing
        $styles.StatusCode | Should -Be 200
        $styles.Headers['Content-Type'] | Should -Match 'text/css'
        $styles.Content | Should -Not -Match 'http://|https://'
        # The reader ships no bundled typeface: it sets type in the system UI font.
        $styles.Content | Should -Not -Match '@font-face'

        { Invoke-WebRequest -Uri "$url/assets/fonts/dm-sans.woff2" -UseBasicParsing } | Should -Throw -ExpectedMessage '*404*'

        $scripts = Invoke-WebRequest -Uri "$url/assets/site.js" -UseBasicParsing
        $scripts.StatusCode | Should -Be 200
        $scripts.Headers['Content-Type'] | Should -Match 'javascript'
        $scripts.Content | Should -Not -Match 'http://|https://'

        $data = Invoke-WebRequest -Uri "$url/api/site-data" -UseBasicParsing
        $data.StatusCode | Should -Be 200
        $data.Headers['Content-Type'] | Should -Match 'application/json'
        ($data.Content | ConvertFrom-Json).project | Should -Not -BeNullOrEmpty

        $conceptPage = Invoke-WebRequest -Uri "$url/records/powershell-concept" -UseBasicParsing
        $conceptPage.StatusCode | Should -Be 200
        $conceptPage.Content | Should -Match 'PowerShell concept'
        $conceptPage.Content | Should -Match 'href="/features/ps-navigation"'
        $conceptPage.Content | Should -Match 'class="tag tone-0" data-tag="native-dispatch"'

        $featurePage = Invoke-WebRequest -Uri "$url/features/ps-navigation" -UseBasicParsing
        $featurePage.StatusCode | Should -Be 200
        $featurePage.Content | Should -Match 'Can deep links load directly?'
        $featurePage.Content | Should -Match 'href="/decisions/ps-navigation/001/site/deep-route"'
        $featurePage.Content | Should -Match 'class="diagram-unavailable"'
        $featurePage.Content | Should -Match 'A bad visual never hides the written explanation.'
        $featurePage.Content | Should -Not -Match 'not a supported diagram'

        $decisionPage = Invoke-WebRequest -Uri "$url/decisions/ps-navigation/001/site/deep-route" -UseBasicParsing
        $decisionPage.StatusCode | Should -Be 200
        $decisionPage.Content | Should -Match 'the dispatcher shares the bundled reader'
    }

    It 'ensures and reuses a managed local site through the PowerShell dispatcher' {
        if (-not $script:Node) { Set-ItResult -Skipped -Because 'Node.js is required for the site test'; return }
        $script:repo = Initialize-TestRepo
        $siteHome = New-TestHome
        try {
            $first = (& $script:PwshExe -NoProfile -File $script:Cli 'site' '--ensure' '--json' | ForEach-Object { $_.ToString() }) -join "`n" | ConvertFrom-Json
            $first.running | Should -BeTrue
            $first.url | Should -Be 'http://127.0.0.1:44444'
            $first.reused | Should -BeFalse

            $health = Invoke-WebRequest -Uri "$($first.url)/health" -UseBasicParsing
            $health.StatusCode | Should -Be 200

            $second = (& $script:PwshExe -NoProfile -File $script:Cli 'site' '--ensure' '--json' | ForEach-Object { $_.ToString() }) -join "`n" | ConvertFrom-Json
            $second.running | Should -BeTrue
            $second.url | Should -Be $first.url
            $second.reused | Should -BeTrue
        } finally {
            & $script:PwshExe -NoProfile -File $script:Cli 'site' '--stop' '--json' *> $null
            Remove-Item -Recurse -Force -LiteralPath $siteHome -ErrorAction SilentlyContinue
        }
    }
}
