@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "AWS_PROFILE=cf-production"
set "DOCKER_DESKTOP_EXE=%ProgramFiles%\Docker\Docker\Docker Desktop.exe"

where docker >nul 2>nul
if errorlevel 1 (
    echo Docker CLI was not found on PATH.
    exit /b 1
)

where aws >nul 2>nul
if errorlevel 1 (
    echo AWS CLI was not found on PATH.
    exit /b 1
)

where bash >nul 2>nul
if errorlevel 1 (
    echo bash was not found on PATH. Install Git Bash or another bash provider.
    exit /b 1
)

echo Checking Docker Desktop...
docker info >nul 2>nul
if errorlevel 1 (
    if exist "%DOCKER_DESKTOP_EXE%" (
        echo Starting Docker Desktop...
        start "" "%DOCKER_DESKTOP_EXE%"
    ) else (
        echo Docker Desktop is not running, and its default executable path was not found:
        echo   %DOCKER_DESKTOP_EXE%
        exit /b 1
    )
)

echo Waiting for Docker engine...
set /a DOCKER_WAIT_SECONDS=0
:wait_for_docker
docker info >nul 2>nul
if not errorlevel 1 goto docker_ready

if %DOCKER_WAIT_SECONDS% geq 120 (
    echo Docker did not become ready within 120 seconds.
    exit /b 1
)

timeout /t 2 /nobreak >nul
set /a DOCKER_WAIT_SECONDS+=2
goto wait_for_docker

:docker_ready
echo Docker is ready.

echo Logging into AWS with profile %AWS_PROFILE%...
aws sso login --profile "%AWS_PROFILE%"
if errorlevel 1 (
    echo AWS login failed.
    exit /b 1
)

echo Running deploy.sh with profile %AWS_PROFILE%...
pushd "%SCRIPT_DIR%"
bash -lc "export AWS_PROFILE=%AWS_PROFILE%; ./deploy.sh"
set "DEPLOY_EXIT=%ERRORLEVEL%"
popd

if not "%DEPLOY_EXIT%"=="0" (
    echo deploy.sh failed with exit code %DEPLOY_EXIT%.
    exit /b %DEPLOY_EXIT%
)

echo Deployment completed successfully.
exit /b 0
