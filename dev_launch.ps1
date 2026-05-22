# run-projectplanner.ps1

$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$url = 'http://127.0.0.1:5000/'

$serverCommand = @"
Set-Location '$repo'
`$env:DATABASE_URL = 'sqlite:///./planner.db'
uv run flask --app app.py run --debug --host 127.0.0.1 --port 5000
"@

Start-Process powershell `
  -ArgumentList '-NoExit', '-Command', $serverCommand `
  -WorkingDirectory $repo

for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Milliseconds 500
    try {
        Invoke-WebRequest -Uri $url -UseBasicParsing | Out-Null
        # Launch Chrome with remote debugging so the hook can refresh without stealing focus
        $chromePaths = @(
            "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
        )
        $chromeExe = $chromePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($chromeExe) {
            Start-Process $chromeExe -ArgumentList "--remote-debugging-port=9222", $url
        } else {
            Start-Process $url
        }
        break
    } catch {
    }
}