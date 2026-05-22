@echo off
setlocal
for /f "delims=" %%E in ('echo prompt $E^| cmd') do set "ESC=%%E"

set "SCRIPT_DIR=%~dp0"

:: ============================================================
:: PROJECT CONFIGURATION — update these three lines for each
:: new project before running a deployment for the first time.
:: ============================================================
set "AWS_PROFILE=cf-production"
set "REPO=626635437662.dkr.ecr.us-east-2.amazonaws.com/project-planner"
set "REGION=us-east-2"
:: ============================================================

set "DOCKER_DESKTOP_EXE=%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
set "DOCKER_CLI_EXE=%ProgramFiles%\Docker\Docker\DockerCli.exe"
for /f "tokens=1 delims=/" %%A in ("%REPO%") do set "REGISTRY=%%A"
set "EXIT_CODE=0"

call :info "Starting Project Planner deployment..."
echo.

where docker >nul 2>nul
if errorlevel 1 (
    call :err "Docker is not installed or is not available on this computer."
    set "EXIT_CODE=1"
    goto end
)

where aws >nul 2>nul
if errorlevel 1 (
    call :err "AWS CLI is not installed or is not available on this computer."
    set "EXIT_CODE=1"
    goto end
)

call :info "Checking Docker Desktop..."
docker info >nul 2>nul
if errorlevel 1 (
    if exist "%DOCKER_DESKTOP_EXE%" (
        call :warn "Docker Desktop is not running yet. Starting it now..."
        start "" "%DOCKER_DESKTOP_EXE%"
    ) else (
        call :err "Docker Desktop is not running, and it could not be found in the usual install location."
        echo     %DOCKER_DESKTOP_EXE%
        set "EXIT_CODE=1"
        goto end
    )
)

call :info "Waiting for Docker Desktop to finish starting..."
set /a DOCKER_WAIT_SECONDS=0
:wait_for_docker
docker info >nul 2>nul
if not errorlevel 1 goto docker_ready

if %DOCKER_WAIT_SECONDS% geq 120 (
    call :err "Docker Desktop did not finish starting within 120 seconds."
    set "EXIT_CODE=1"
    goto end
)

timeout /t 2 /nobreak >nul
set /a DOCKER_WAIT_SECONDS+=2
goto wait_for_docker

:docker_ready
call :ok "Docker is ready."

call :info "Opening AWS sign-in for profile %AWS_PROFILE%..."
aws sso login --profile "%AWS_PROFILE%"
if errorlevel 1 (
    call :err "AWS sign-in was not completed."
    set "EXIT_CODE=1"
    goto end
)

call :info "Signing Docker into the deployment registry..."
pushd "%SCRIPT_DIR%"
aws ecr get-login-password --region "%REGION%" --profile "%AWS_PROFILE%" | docker login --username AWS --password-stdin "%REGISTRY%"
if errorlevel 1 (
    call :err "Docker could not sign in to the deployment registry."
    set "EXIT_CODE=1"
    popd
    goto end
)

call :info "Building the Project Planner image..."
docker build -t "%REPO%:latest" .
if errorlevel 1 (
    call :err "Docker could not build the Project Planner image."
    set "EXIT_CODE=1"
    popd
    goto end
)

call :info "Uploading the Project Planner image..."
docker push "%REPO%:latest"
if errorlevel 1 (
    call :err "Docker could not upload the Project Planner image."
    set "EXIT_CODE=1"
    popd
    goto end
)
popd

call :ok "Deployment completed successfully."

:end
call :shutdown_docker
echo.
if "%EXIT_CODE%"=="0" (
    call :ok "Done! Press any key to close this window..."
) else (
    call :err "Deployment did not finish successfully."
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

:shutdown_docker
call :info "Closing Docker Desktop to free up memory..."
if exist "%DOCKER_CLI_EXE%" (
    "%DOCKER_CLI_EXE%" -Shutdown >nul 2>nul
)
taskkill /IM "Docker Desktop.exe" /F >nul 2>nul
taskkill /IM "com.docker.backend.exe" /F >nul 2>nul
taskkill /IM "com.docker.build.exe" /F >nul 2>nul
taskkill /IM "vpnkit.exe" /F >nul 2>nul
wsl -t docker-desktop >nul 2>nul
wsl -t docker-desktop-data >nul 2>nul
wsl --shutdown >nul 2>nul
call :ok "Docker Desktop and WSL have been closed."
exit /b 0
