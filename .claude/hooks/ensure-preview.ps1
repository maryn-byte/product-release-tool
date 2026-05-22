# Resolve project root from this script's location (.claude/hooks/ -> project root)
$d = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

$conn = Get-NetTCPConnection -LocalPort 5000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $conn) {
    # Server not running — start it. The launch script calls open-or-refresh.ps1
    # once the server is up, so browser management is handled there.
    if (Get-Command wt.exe -ErrorAction SilentlyContinue) {
        Start-Process wt.exe -ArgumentList "--startingDirectory `"$d`" cmd /c `"$d\windows_launch.bat`""
    } else {
        Start-Process cmd.exe -ArgumentList "/c `"$d\windows_launch.bat`"" -WorkingDirectory $d
    }
} else {
    # Server already running — refresh without ever opening a new tab
    & "$PSScriptRoot\open-or-refresh.ps1"
}
