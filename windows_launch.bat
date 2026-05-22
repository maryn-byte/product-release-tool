@echo off
setlocal
for /f "delims=" %%E in ('echo prompt $E^| cmd') do set "ESC=%%E"

call :info "Opening Project Planner..."
PowerShell.exe -ExecutionPolicy Bypass -File "dev_launch.ps1"
set "EXIT_CODE=%ERRORLEVEL%"
echo.
if "%EXIT_CODE%"=="0" (
    call :ok "Done! Project Planner should now be opening in your browser."
    call :warn "Press any key to close this window..."
) else (
    call :err "Project Planner did not launch successfully."
    call :warn "Review the message above, then press any key to close this window..."
)
pause >nul
exit /b %EXIT_CODE%

:info
echo %ESC%[96m[INFO]%ESC%[0m %~1
exit /b 0

:ok
echo %ESC%[92m[OK]%ESC%[0m %~1
exit /b 0

:warn
echo %ESC%[93m[ATTENTION]%ESC%[0m %~1
exit /b 0

:err
echo %ESC%[91m[ERROR]%ESC%[0m %~1
exit /b 0
