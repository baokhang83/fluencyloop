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
        $script:siteProcess = Start-Process -FilePath $script:PwshExe `
            -ArgumentList @('-NoProfile', '-File', $script:Cli, 'site', '--port', '0') `
            -WorkingDirectory $script:repo -RedirectStandardOutput $script:siteLog `
            -RedirectStandardError $script:siteError -PassThru

        $url = ''
        for ($i = 0; $i -lt 100; $i++) {
            if (Test-Path -LiteralPath $script:siteLog) {
                $line = Get-Content -LiteralPath $script:siteLog -Raw -ErrorAction SilentlyContinue
                if ($line -match 'FluencyLoop site: (http://127\.0\.0\.1:\d+)') { $url = $matches[1]; break }
            }
            Start-Sleep -Milliseconds 100
        }
        $url | Should -Match '^http://127\.0\.0\.1:\d+$'

        $home = Invoke-WebRequest -Uri "$url/" -UseBasicParsing
        $home.StatusCode | Should -Be 200
        $home.Headers['Content-Type'] | Should -Match 'text/html'
        $home.Content | Should -Match 'FluencyLoop'

        $data = Invoke-WebRequest -Uri "$url/api/site-data" -UseBasicParsing
        $data.StatusCode | Should -Be 200
        $data.Headers['Content-Type'] | Should -Match 'application/json'
        ($data.Content | ConvertFrom-Json).project | Should -Not -BeNullOrEmpty
    }
}
