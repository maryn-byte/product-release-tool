@echo off
setlocal

echo Opening Project Planner...
PowerShell.exe -ExecutionPolicy Bypass -File "dev_launch.ps1"
set "EXIT_CODE=%ERRORLEVEL%"
echo.
if "%EXIT_CODE%"=="0" (
    echo Done! Project Planner should now be opening in your browser.
    echo Press any key to close this window...
) else (
    echo Project Planner did not launch successfully.
    echo Review the message above, then press any key to close this window...
)
pause >nul
exit /b %EXIT_CODE%
