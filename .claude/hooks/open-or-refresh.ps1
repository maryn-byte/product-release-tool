# Navigates to http://127.0.0.1:5000/ without ever creating a duplicate tab.
# If a Chrome tab already exists at that URL (even showing a connection error),
# it reloads that tab. A new tab is only opened when no such tab exists at all.

$url = 'http://127.0.0.1:5000/'

# 1. Chrome DevTools Protocol — works silently without stealing focus.
#    CDP reports the URL even for error pages, so this catches tabs that loaded
#    while the server was down (e.g. "ERR_CONNECTION_REFUSED").
$handled = $false
try {
    $tabs = Invoke-RestMethod -Uri 'http://localhost:9222/json' -TimeoutSec 1 -ErrorAction Stop
    $tab = $tabs | Where-Object { $_.url -like '*127.0.0.1:5000*' } | Select-Object -First 1
    if ($tab -and $tab.webSocketDebuggerUrl) {
        $ws  = New-Object System.Net.WebSockets.ClientWebSocket
        $cts = New-Object System.Threading.CancellationTokenSource
        $cts.CancelAfter(3000)
        $ws.ConnectAsync([uri]$tab.webSocketDebuggerUrl, $cts.Token).Wait()
        $bytes = [System.Text.Encoding]::UTF8.GetBytes('{"id":1,"method":"Page.reload","params":{}}')
        $ws.SendAsync([ArraySegment[byte]]$bytes,
            [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $cts.Token).Wait()
        $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure,
            '', [System.Threading.CancellationToken]::None).Wait()
        $handled = $true
    }
} catch {}

# 2. WScript fallback — briefly steals focus, but avoids opening a new tab.
#    Only fires if CDP is unavailable (Chrome not launched with --remote-debugging-port).
#    Matches on "127.0.0.1" so it catches both the running app and error pages.
if (-not $handled) {
    $chrome = Get-Process 'chrome' -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowTitle -ne '' -and $_.MainWindowTitle -match '127\.0\.0\.1' } |
        Select-Object -First 1
    if ($chrome) {
        $shell = New-Object -ComObject WScript.Shell
        $shell.AppActivate($chrome.Id) | Out-Null
        Start-Sleep -Milliseconds 200
        $shell.SendKeys('{F5}')
        $handled = $true
    }
}

# 3. No existing tab found — open Chrome for the first time with debug port enabled.
if (-not $handled) {
    $chromePaths = @(
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    )
    $chromeExe = $chromePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($chromeExe) {
        Start-Process $chromeExe -ArgumentList '--remote-debugging-port=9222', $url
    } else {
        Start-Process $url
    }
}
