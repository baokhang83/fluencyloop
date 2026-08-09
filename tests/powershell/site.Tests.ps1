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

        $data = Invoke-WebRequest -Uri "$url/api/site-data" -UseBasicParsing
        $data.StatusCode | Should -Be 200
        $data.Headers['Content-Type'] | Should -Match 'application/json'
        ($data.Content | ConvertFrom-Json).project | Should -Not -BeNullOrEmpty
    }
}
