$ErrorActionPreference = 'Stop'

function Require-Path {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Required path not found: $Path"
    }
}

function Copy-IntoBundle {
    param(
        [string]$Source,
        [string]$DestinationRoot
    )

    Require-Path $Source
    Copy-Item -LiteralPath $Source -Destination $DestinationRoot -Recurse -Force
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcherPath = Join-Path $repoRoot 'windows_launcher.ps1'

Require-Path $launcherPath
Require-Path (Join-Path $repoRoot 'app.py')
Require-Path (Join-Path $repoRoot 'templates')
Require-Path (Join-Path $repoRoot 'pyproject.toml')
Require-Path (Join-Path $repoRoot 'uv.lock')

$ps2exeCommand = Get-Command Invoke-PS2EXE, Invoke-ps2exe, ps2exe -ErrorAction SilentlyContinue |
    Select-Object -First 1

if (-not $ps2exeCommand) {
    throw "PS2EXE is not installed. Install it in Windows PowerShell first with: Install-Module ps2exe -Scope CurrentUser"
}

$desktopPath = [Environment]::GetFolderPath('Desktop')
$bundleDir = Join-Path $desktopPath 'Project Planner'
$exePath = Join-Path $bundleDir 'Project Planner.exe'
$shortcutPath = Join-Path $desktopPath 'Project Planner.lnk'

New-Item -ItemType Directory -Force -Path $bundleDir | Out-Null

Copy-IntoBundle (Join-Path $repoRoot 'app.py') $bundleDir
Copy-IntoBundle (Join-Path $repoRoot 'pyproject.toml') $bundleDir
Copy-IntoBundle (Join-Path $repoRoot 'uv.lock') $bundleDir
Copy-IntoBundle (Join-Path $repoRoot 'templates') $bundleDir

& $ps2exeCommand.Source `
    -inputFile $launcherPath `
    -outputFile $exePath `
    -title 'Project Planner' `
    -product 'Project Planner' `
    -company 'Project Planner' `
    -noConsole

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $exePath
$shortcut.WorkingDirectory = $bundleDir
$shortcut.IconLocation = "$exePath,0"
$shortcut.Save()

Write-Host "Desktop bundle created at: $bundleDir"
Write-Host "Desktop shortcut created at: $shortcutPath"
Write-Host "Notes:"
Write-Host "- The EXE is a launcher, not a standalone Python build."
Write-Host "- The target Windows machine still needs 'uv' installed and reachable on PATH."
Write-Host "- The app database will be stored in %LOCALAPPDATA%\ProjectPlanner\planner.db."
