@echo off
rem fluencyloop.cmd — PATH shim so `fluencyloop <verb>` works from cmd and PowerShell on Windows.
rem Prefers PowerShell 7 (pwsh); falls back to Windows PowerShell.
setlocal
set "FL_PS=pwsh"
where /q pwsh || set "FL_PS=powershell"
"%FL_PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0fluencyloop.ps1" %*
exit /b %ERRORLEVEL%
