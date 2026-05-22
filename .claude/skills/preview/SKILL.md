---
name: preview
description: Launch or shut down the Project Planner dev server, and open it interactively in the sidebar. This is the REQUIRED way to show changes in this project — use it whenever you would normally open a static HTML file to show the user a change, whenever verifying that a feature works, whenever the user asks to run or preview the app, or any time you want to confirm something looks correct in the browser. Never open index.html directly as a file preview when this skill can be used instead. Also use this skill when the user asks to stop, shut down, or kill the dev server.
---

# Preview Dev Server

Show a running, interactive instance of the app in the sidebar whenever verifying or demonstrating changes. Can also shut the server down cleanly.

## Shutdown

If the user wants to stop, shut down, or kill the server, run this and skip the launch steps below:

```powershell
$conn = Get-NetTCPConnection -LocalPort 5000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($conn) {
    Stop-Process -Id $conn.OwningProcess -Force
    Write-Output "stopped"
} else {
    Write-Output "not running"
}
```

Tell the user the server has been stopped, or that it wasn't running.

## Launch steps

### 1. Check if the server is already running

```powershell
try {
    Invoke-WebRequest -Uri "http://127.0.0.1:5000/" -UseBasicParsing -TimeoutSec 2 | Out-Null
    Write-Output "running"
} catch {
    Write-Output "stopped"
}
```

### 2a. If stopped — launch the server

Tell the user you're starting the dev server, then open a new terminal window with the launch script:

```powershell
$workDir = (Get-Location).Path
if (Get-Command wt.exe -ErrorAction SilentlyContinue) {
    Start-Process wt.exe -ArgumentList "cmd /c `"$workDir\windows_launch.bat`""
} else {
    Start-Process cmd.exe -ArgumentList "/c `"$workDir\windows_launch.bat`"" -WorkingDirectory $workDir
}
```

Then poll until the server responds (up to 30 seconds):

```powershell
$ready = $false
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Milliseconds 500
    try {
        Invoke-WebRequest -Uri "http://127.0.0.1:5000/" -UseBasicParsing -TimeoutSec 1 | Out-Null
        $ready = $true
        break
    } catch {}
}
Write-Output $(if ($ready) { "ready" } else { "timeout" })
```

If the result is `timeout`, tell the user the server didn't respond within 30 seconds and ask them to check the terminal window for errors.

### 2b. If already running — skip launch

The server is up. Proceed directly to step 3 — no new terminal needed.

### 3. Open in the sidebar

Call `preview_start` with name `"project-planner"`. This loads `http://127.0.0.1:5000/` in the interactive sidebar preview where the user can click around and save state.
