---
name: deploy
description: Deploy the Project Planner application to AWS. Use this skill whenever the user asks to deploy, ship to production, push a new build, run a deployment, or trigger the deployment script for this project — even if they phrase it casually like "can you deploy this?" or "push it live".
---

# Deploy

Launch `windows_deploy.bat` in a new visible terminal window so the user can watch all output in real time.

## Steps

1. Tell the user you're opening the deployment terminal now.

2. Run this PowerShell command via the PowerShell tool:

```powershell
$scriptPath = (Resolve-Path "windows_deploy.bat").Path
$workDir = (Get-Location).Path
if (Get-Command wt.exe -ErrorAction SilentlyContinue) {
    Start-Process wt.exe -ArgumentList "cmd /c `"$scriptPath`""
} else {
    Start-Process cmd.exe -ArgumentList "/c `"$scriptPath`"" -WorkingDirectory $workDir
}
```

3. Tell the user the deployment window is open. They should watch it for progress — it will walk through Docker startup, AWS SSO login (a browser window may open), image build, and push. The window stays open at the end until they press a key.

## Notes

- The script starts Docker Desktop automatically if it isn't running, and shuts it down after the push completes to free memory.
- AWS SSO login is interactive — the user needs to complete it in the browser window that opens.
- If the window closes immediately, Docker or the AWS CLI may not be installed; the script will have printed an error before closing.
