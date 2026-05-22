$ErrorActionPreference = 'Stop'

param(
    [string]$HostAddress = '127.0.0.1',
    [int]$Port = 5000
)

function Quote-Single {
    param([string]$Text)
    return $Text -replace "'", "''"
}

function Show-LauncherError {
    param([string]$Message)

    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        'Project Planner',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

$baseDir = [System.AppDomain]::CurrentDomain.BaseDirectory.TrimEnd('\', '/')
$appPath = Join-Path $baseDir 'app.py'
$templatesPath = Join-Path $baseDir 'templates'
$url = "http://${HostAddress}:$Port/"
$healthUrl = "${url}health"

if (-not (Test-Path -LiteralPath $appPath)) {
    Show-LauncherError "Could not find app.py in:`n$baseDir`n`nKeep the EXE in the desktop bundle folder created by dev_make_exe.ps1."
    exit 1
}

if (-not (Test-Path -LiteralPath $templatesPath)) {
    Show-LauncherError "Could not find the templates folder in:`n$baseDir`n`nKeep the EXE in the desktop bundle folder created by dev_make_exe.ps1."
    exit 1
}

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Show-LauncherError "The 'uv' command is not installed or not on PATH.`n`nInstall uv on this Windows machine before launching Project Planner."
    exit 1
}

try {
    Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 2 | Out-Null
    Start-Process $url
    exit 0
} catch {
}

$dataDir = Join-Path $env:LOCALAPPDATA 'ProjectPlanner'
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null

$dbPath = Join-Path $dataDir 'planner.db'
$dbUrl = 'sqlite:///' + ($dbPath -replace '\\', '/')

$quotedBaseDir = Quote-Single $baseDir
$quotedAppPath = Quote-Single $appPath
$quotedDbUrl = Quote-Single $dbUrl

$serverCommand = @"
`$Host.UI.RawUI.WindowTitle = 'Project Planner Server'
Set-Location -LiteralPath '$quotedBaseDir'
`$env:DATABASE_URL = '$quotedDbUrl'
Write-Host 'Project Planner is starting.'
Write-Host 'Close this window to stop the server.'
uv run flask --app '$quotedAppPath' run --debug --host $HostAddress --port $Port
"@

Start-Process -FilePath 'powershell.exe' `
    -ArgumentList @('-NoExit', '-ExecutionPolicy', 'Bypass', '-Command', $serverCommand) `
    -WorkingDirectory $baseDir | Out-Null

for ($attempt = 0; $attempt -lt 60; $attempt++) {
    Start-Sleep -Milliseconds 500

    try {
        Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 2 | Out-Null
        Start-Process $url
        exit 0
    } catch {
    }
}

Show-LauncherError "The server window was opened, but Project Planner did not respond at`n$url`nwithin 30 seconds.`n`nCheck the server window for the Flask error output."
exit 1
