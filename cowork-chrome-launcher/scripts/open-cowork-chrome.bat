@echo off
REM Open Cowork Chrome profile (Windows)
REM Double-click this file to launch Chrome with the "Cowork" profile.
REM If your profile has a different display name, change PROFILE_NAME below.

setlocal enabledelayedexpansion

set "PROFILE_NAME=Cowork"
set "LOCAL_STATE=%LOCALAPPDATA%\Google\Chrome\User Data\Local State"
set "CHROME_EXE=C:\Program Files\Google\Chrome\Application\chrome.exe"

if not exist "%CHROME_EXE%" set "CHROME_EXE=C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"

if not exist "%CHROME_EXE%" (
  echo Google Chrome was not found in the standard install locations.
  pause
  exit /b 1
)

if not exist "%LOCAL_STATE%" (
  echo Chrome Local State not found. Launch Chrome at least once first.
  pause
  exit /b 1
)

set "PROFILE_DIR="
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "try { $target = $env:PROFILE_NAME.Trim().ToLower(); (Get-Content -LiteralPath $env:LOCAL_STATE -Raw | ConvertFrom-Json).profile.info_cache.PSObject.Properties ^| Where-Object { ($_.Value.name ?? '').Trim().ToLower() -eq $target } ^| Select-Object -ExpandProperty Name -First 1 } catch { }"`) do set "PROFILE_DIR=%%i"

if "%PROFILE_DIR%"=="" (
  echo Profile '%PROFILE_NAME%' not found.
  echo Make sure you have a Chrome profile named '%PROFILE_NAME%'.
  pause
  exit /b 1
)

start "" "%CHROME_EXE%" --profile-directory="%PROFILE_DIR%"
endlocal
