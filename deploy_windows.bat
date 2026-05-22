@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "AWS_PROFILE=cf-production"
set "DOCKER_DESKTOP_EXE=%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
set "REPO=626635437662.dkr.ecr.us-east-2.amazonaws.com/project-planner"
set "REGION=us-east-2"
for /f "tokens=1 delims=/" %%A in ("%REPO%") do set "REGISTRY=%%A"
set "EXIT_CODE=0"

where docker >nul 2>nul
if errorlevel 1 (
    echo Docker CLI was not found on PATH.
    set "EXIT_CODE=1"
    goto end
)

where aws >nul 2>nul
if errorlevel 1 (
    echo AWS CLI was not found on PATH.
    set "EXIT_CODE=1"
    goto end
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
        set "EXIT_CODE=1"
        goto end
    )
)

echo Waiting for Docker engine...
set /a DOCKER_WAIT_SECONDS=0
:wait_for_docker
docker info >nul 2>nul
if not errorlevel 1 goto docker_ready

if %DOCKER_WAIT_SECONDS% geq 120 (
    echo Docker did not become ready within 120 seconds.
    set "EXIT_CODE=1"
    goto end
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
    set "EXIT_CODE=1"
    goto end
)

echo Logging Docker into ECR registry %REGISTRY%...
pushd "%SCRIPT_DIR%"
aws ecr get-login-password --region "%REGION%" --profile "%AWS_PROFILE%" | docker login --username AWS --password-stdin "%REGISTRY%"
if errorlevel 1 (
    echo ECR Docker login failed.
    set "EXIT_CODE=1"
    popd
    goto end
)

echo Building Docker image %REPO%:latest...
docker build -t "%REPO%:latest" .
if errorlevel 1 (
    echo Docker build failed.
    set "EXIT_CODE=1"
    popd
    goto end
)

echo Pushing Docker image %REPO%:latest...
docker push "%REPO%:latest"
if errorlevel 1 (
    echo Docker push failed.
    set "EXIT_CODE=1"
    popd
    goto end
)
popd

echo Deployment completed successfully.

:end
echo.
pause
exit /b %EXIT_CODE%
