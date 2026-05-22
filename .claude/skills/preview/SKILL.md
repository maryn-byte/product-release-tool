---
name: preview
description: Show the Project Planner app running live in Chrome. Only use this skill when the user explicitly asks to see or interact with the running app — e.g. "show me the app", "open the preview", "show me the full app", "show me the interactive preview". Do NOT invoke automatically after code changes or for verification.
---

# Preview Dev Server

Launch the dev server (if not already running) and open the app in Chrome.

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
