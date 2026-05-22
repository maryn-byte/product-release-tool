---
name: preview
description: Ensure the Project Planner dev server is running and open in Chrome. Use this skill whenever you make any code changes to this project, whenever verifying that a feature works, or whenever the user asks to run or preview the app. Never open index.html directly. Also use this skill when the user asks to stop, shut down, or kill the dev server.
---

# Preview Dev Server

Ensure the dev server is running and the app is open in the browser. No sidebar preview panel — the browser is the view.

## Shutdown

If the user wants to stop, shut down, or kill the server, run this and skip everything below:

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

## Launch / refresh

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

The launch script starts Flask and opens a browser tab automatically. Run it in a new visible terminal:

```powershell
$workDir = "C:\Users\cooki\Documents\GitHub\projectplanner"
if (Get-Command wt.exe -ErrorAction SilentlyContinue) {
    Start-Process wt.exe -ArgumentList "--startingDirectory `"$workDir`" cmd /c `"$workDir\windows_launch.bat`""
} else {
    Start-Process cmd.exe -ArgumentList "/c `"$workDir\windows_launch.bat`"" -WorkingDirectory $workDir
}
```

Then poll until ready (up to 30 seconds):

```powershell
$ready = $false
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Milliseconds 500
    try {
        Invoke-WebRequest -Uri "http://127.0.0.1:5000/" -UseBasicParsing -TimeoutSec 1 | Out-Null
        $ready = $true; break
    } catch {}
}
if ($ready) { Write-Output "ready" } else { Write-Output "timeout" }
```

If `timeout`, tell the user the server didn't start within 30 seconds and ask them to check the terminal window for errors. Do not proceed.

The browser tab is already open — the launch script handles that. Done.

### 2b. If already running — refresh the existing Chrome tab

The server is up. Always run the helper script — it closes duplicate tabs and reloads the surviving one via CDP, with no risk of opening a new tab:

```powershell
& ".claude\hooks\open-or-refresh.ps1"
```

Done.
