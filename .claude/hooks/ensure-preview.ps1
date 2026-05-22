$conn = Get-NetTCPConnection -LocalPort 5000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
$d = 'C:\Users\cooki\Documents\GitHub\projectplanner'
if (-not $conn) {
    if (Get-Command wt.exe -ErrorAction SilentlyContinue) {
        Start-Process wt.exe -ArgumentList "--startingDirectory `"$d`" cmd /c `"$d\windows_launch.bat`""
    } else {
        Start-Process cmd.exe -ArgumentList "/c `"$d\windows_launch.bat`"" -WorkingDirectory $d
    }
} else {
    Start-Process 'http://127.0.0.1:5000/'
}
