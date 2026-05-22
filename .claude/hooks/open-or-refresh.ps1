# Refreshes or opens the app in the dedicated dev Chrome window.
#
# Dev Chrome uses its own --user-data-dir so it is always a separate process
# from the user's regular Chrome, meaning --remote-debugging-port=9222 reliably
# takes effect regardless of whether regular Chrome is open.
#
# DUPLICATE TAB PREVENTION
# The URL is never passed to Start-Process. Chrome opening is just "start the
# window"; tab creation happens only via CDP once Chrome is ready. This means
# even if this script is called multiple times in quick succession (e.g. rapid
# PostToolUse hooks), at most one app tab is ever created.

param(
    # When set, wait up to 15 s for Chrome to finish starting before returning.
    # Use this for explicit invocations (skill, launch script) where the caller
    # needs to know Chrome is actually ready. Omit for hook invocations so the
    # hook returns immediately and doesn't block Claude between edits.
    [switch]$Wait
)

$url        = 'http://127.0.0.1:5000/'
$projectDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$devProfile = Join-Path $projectDir '.claude\chrome-dev-profile'
$chromeExe  = @(
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

# Activate a tab by ID via CDP REST (brings it to the foreground).
function Invoke-CdpActivate([string]$id) {
    Invoke-RestMethod "http://127.0.0.1:9222/json/activate/$id" `
        -TimeoutSec 2 -ErrorAction SilentlyContinue | Out-Null
}

# Tries CDP, manages tabs, returns $true on success.
# Polls for up to $seconds if CDP isn't immediately available.
function Invoke-CdpManage([int]$seconds = 0) {
    $deadline = (Get-Date).AddSeconds($seconds)
    do {
        try {
            $tabs    = Invoke-RestMethod 'http://127.0.0.1:9222/json' -TimeoutSec 1 -ErrorAction Stop
            $appTabs = @($tabs | Where-Object { $_.url -like '*127.0.0.1:5000*' })

            if ($appTabs.Count -gt 0) {
                # Close every duplicate, keep the first
                $appTabs | Select-Object -Skip 1 | ForEach-Object {
                    Invoke-RestMethod "http://127.0.0.1:9222/json/close/$($_.id)" `
                        -ErrorAction SilentlyContinue | Out-Null
                }
                # Reload the surviving tab
                $primary = $appTabs[0]
                if ($primary.webSocketDebuggerUrl) {
                    $ws  = New-Object System.Net.WebSockets.ClientWebSocket
                    $cts = New-Object System.Threading.CancellationTokenSource
                    $cts.CancelAfter(3000)
                    $ws.ConnectAsync([uri]$primary.webSocketDebuggerUrl, $cts.Token).Wait()
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes(
                        '{"id":1,"method":"Page.reload","params":{}}')
                    $ws.SendAsync([ArraySegment[byte]]$bytes,
                        [System.Net.WebSockets.WebSocketMessageType]::Text,
                        $true, $cts.Token).Wait()
                    $ws.CloseAsync(
                        [System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure,
                        '', [System.Threading.CancellationToken]::None).Wait()
                }
                # Bring the tab to the foreground
                Invoke-CdpActivate $primary.id
            } else {
                # Dev Chrome is open but the app tab was closed — reopen it
                $newTab = Invoke-RestMethod "http://127.0.0.1:9222/json/new?$url" -Method PUT `
                    -TimeoutSec 2 -ErrorAction SilentlyContinue
                if ($newTab -and $newTab.id) {
                    Invoke-CdpActivate $newTab.id
                }
            }
            return $true
        } catch {}

        if ((Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500 }
    } while ((Get-Date) -lt $deadline)

    return $false
}

# ── 1. Fast path: CDP already up (dev Chrome running and ready) ───────────────
if (Invoke-CdpManage -seconds 0) { return }

# ── 2. Port 9222 is bound but CDP HTTP not ready yet (Chrome still starting) ──
# Return immediately (hook case) or wait (explicit invocation).
$port9222Bound = $null -ne (
    Get-NetTCPConnection -LocalPort 9222 -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1)

if ($port9222Bound) {
    if ($Wait) { Invoke-CdpManage -seconds 15 | Out-Null }
    # else: hook fires again on the next edit and will catch CDP when it's ready
    return
}

# ── 3. Dev Chrome is not running — launch it ─────────────────────────────────
# IMPORTANT: do NOT pass $url here. Passing a URL causes Chrome to open it as a
# new tab if the process is already running (e.g. called twice in quick
# succession). Tab creation is handled by CDP in Invoke-CdpManage instead.
if ($chromeExe) {
    Start-Process $chromeExe -ArgumentList (
        "--user-data-dir=`"$devProfile`"",
        '--remote-debugging-port=9222',
        '--no-first-run',
        '--no-default-browser-check'
    )
    if ($Wait) { Invoke-CdpManage -seconds 15 | Out-Null }
} else {
    Start-Process $url
}
