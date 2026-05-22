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
        Start-Process $url
        break
    } catch {
    }
}