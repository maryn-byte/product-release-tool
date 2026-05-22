# Resolve project root from this script's location (.claude/hooks/ -> project root)
$d = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

$conn = Get-NetTCPConnection -LocalPort 5000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $conn) {
    # Server not running — start it (launch script opens Chrome with debug port)
    if (Get-Command wt.exe -ErrorAction SilentlyContinue) {
        Start-Process wt.exe -ArgumentList "--startingDirectory `"$d`" cmd /c `"$d\windows_launch.bat`""
    } else {
        Start-Process cmd.exe -ArgumentList "/c `"$d\windows_launch.bat`"" -WorkingDirectory $d
    }
} else {
    # Server running — refresh via Chrome DevTools Protocol (no focus steal)
    $refreshed = $false
    try {
        $tabs = Invoke-RestMethod -Uri 'http://localhost:9222/json' -TimeoutSec 1 -ErrorAction Stop
        $tab = $tabs | Where-Object { $_.url -like '*127.0.0.1:5000*' } | Select-Object -First 1
        if ($tab -and $tab.webSocketDebuggerUrl) {
            $ws = New-Object System.Net.WebSockets.ClientWebSocket
            $cts = New-Object System.Threading.CancellationTokenSource
            $cts.CancelAfter(3000)
            $ws.ConnectAsync([uri]$tab.webSocketDebuggerUrl, $cts.Token).Wait()
            $bytes = [System.Text.Encoding]::UTF8.GetBytes('{"id":1,"method":"Page.reload","params":{}}')
            $ws.SendAsync([ArraySegment[byte]]$bytes, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $cts.Token).Wait()
            $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, '', [System.Threading.CancellationToken]::None).Wait()
            $refreshed = $true
        }
    } catch {}

    if (-not $refreshed) {
        # CDP not available — fall back to WScript (briefly steals focus)
        $chrome = Get-Process 'chrome' -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowTitle -ne '' -and $_.MainWindowTitle -match '127\.0\.0\.1:5000' } |
            Select-Object -First 1
        if ($chrome) {
            $shell = New-Object -ComObject WScript.Shell
            $shell.AppActivate($chrome.Id) | Out-Null
            Start-Sleep -Milliseconds 200
            $shell.SendKeys('{F5}')
        } else {
            Start-Process 'http://127.0.0.1:5000/'
        }
    }
}
