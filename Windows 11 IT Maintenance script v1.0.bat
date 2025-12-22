@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Windows Windows 11 IT Maintenance script v1.0.bat

rem ============================================================
rem  - Runs elevated (self-relaunches as admin if needed)
rem  - Per-run logging with retries and summary
rem ============================================================

set "SCRIPT_NAME=Windows Windows 11 IT Maintenance script v1.0.bat"
set "SCRIPT_VERSION=1.0"

rem --------------------------
rem Admin privilege check
rem --------------------------
net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo.
    echo ============================================================
    echo  Elevation required. Relaunching with administrative rights...
    echo ============================================================
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

rem --------------------------
rem Log directory
rem --------------------------
set "LOGDIR=C:\IT Maintenance Logs"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1

rem --------------------------
rem Main menu loop
rem --------------------------
:MENU
cls
echo ============================================================
echo                Windows 11 IT Maintenance MENU
echo                Script version: 1.0
echo ============================================================
echo.
echo  1^) Standard maintenance
echo  2^) Advanced maintenance
echo  3^) Recovery maintenance
echo  4^) Open log file folder
echo  5^) Shut down script
echo.
set "CHOICE="
set /p "CHOICE=Select an option (1-5): "

if "%CHOICE%"=="1" goto RUN_STANDARD
if "%CHOICE%"=="2" goto RUN_ADVANCED
if "%CHOICE%"=="3" goto RUN_RECOVERY
if "%CHOICE%"=="4" goto OPEN_LOGS
if "%CHOICE%"=="5" goto EXIT_SCRIPT

echo.
echo [!] Invalid selection. Please choose 1-5.
timeout /t 2 >nul
goto MENU

rem ============================================================
rem Option 1 - Standard Maintenance
rem ============================================================
:RUN_STANDARD
call :InitRun "Standard maintenance"
call :RunCmd "DISM /Online /Cleanup-Image /RestoreHealth" "DISM /Online /Cleanup-Image /RestoreHealth"
call :RunCmd "SFC /scannow" "SFC /scannow"
call :RunCmd "DISM /Online /Cleanup-Image /StartComponentCleanup" "DISM /Online /Cleanup-Image /StartComponentCleanup"
call :RunCmd "chkdsk C: /scan" "chkdsk C: /scan"
call :RunCmd "UsoClient StartScan" "UsoClient StartScan"
call :RunCmd "ipconfig /flushdns" "ipconfig /flushdns"
call :RunCmd "cleanmgr /sageset:1" "cleanmgr /sageset:1"
call :RunCmd "cleanmgr /sagerun:1" "cleanmgr /sagerun:1"
call :FinalizeRun
goto MENU

rem ============================================================
rem Option 2 - Advanced Maintenance
rem ============================================================
:RUN_ADVANCED
call :InitRun "Advanced maintenance"
call :RunCmd "net stop wuauserv" "net stop wuauserv"
call :RunCmd "net stop bits" "net stop bits"
call :RunCmd "net stop cryptsvc" "net stop cryptsvc"

rem ren requires a target and a new name; we perform the intended Windows Update cache renames safely.
call :RunCmd "ren SoftwareDistribution" "cmd /c if exist ""%windir%\SoftwareDistribution"" ren ""%windir%\SoftwareDistribution"" ""SoftwareDistribution.old_!RUNSTAMP!"""
call :RunCmd "ren catroot2" "cmd /c if exist ""%windir%\System32\catroot2"" ren ""%windir%\System32\catroot2"" ""catroot2.old_!RUNSTAMP!"""

call :RunCmd "netsh winsock reset" "netsh winsock reset"
call :RunCmd "netsh int ip reset" "netsh int ip reset"
call :FinalizeRun
goto MENU

rem ============================================================
rem Option 3 - Recovery Maintenance
rem ============================================================
:RUN_RECOVERY
call :InitRun "Recovery maintenance"
call :RunCmd "DISM /ResetBase" "DISM /ResetBase"
call :RunCmd "bootrec /fixboot" "bootrec /fixboot"
call :RunCmd "bootrec /rebuildbcd" "bootrec /rebuildbcd"
call :FinalizeRun
goto MENU

rem ============================================================
rem Option 4 - Open Log Folder
rem ============================================================
:OPEN_LOGS
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
explorer "%LOGDIR%"
goto MENU

rem ============================================================
rem Option 5 - Exit
rem ============================================================
:EXIT_SCRIPT
echo.
echo Exiting script...
endlocal
exit /b


rem ============================================================
rem Subroutines
rem ============================================================

:InitRun
rem %~1 = Run Type (Standard/Advanced/Recovery)
set "RUNTYPE=%~1"

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "RUNSTAMP=%%i"
set "COMPNAME=%COMPUTERNAME%"
set "USERNAME=%USERNAME%"

set "LOGFILE=%LOGDIR%\Computer %COMPNAME% IT Maintenance script run by %USERNAME% %RUNSTAMP%.log"
rem Prevent overwriting (extra safety)
if exist "%LOGFILE%" (
    set /a "N=1"
    :LOGNAME_LOOP
    set "LOGFILE=%LOGDIR%\Computer %COMPNAME% IT Maintenance script run by %USERNAME% %RUNSTAMP%_(%N%).log"
    if exist "%LOGFILE%" (
        set /a N+=1
        goto LOGNAME_LOOP
    )
)

set "SUCCESS_TMP=%TEMP%\ITMaint_Success_%RUNSTAMP%.tmp"
set "FAIL_TMP=%TEMP%\ITMaint_Fail_%RUNSTAMP%.tmp"
if exist "%SUCCESS_TMP%" del /f /q "%SUCCESS_TMP%" >nul 2>&1
if exist "%FAIL_TMP%" del /f /q "%FAIL_TMP%" >nul 2>&1

echo Computer %COMPNAME% IT Maintenance script run by %USERNAME%>"%LOGFILE%"
echo run on this time frame %RUNSTAMP%>>"%LOGFILE%"
echo Run type: %RUNTYPE%>>"%LOGFILE%"
echo Log path: %LOGFILE%>>"%LOGFILE%"
echo ============================================================>>"%LOGFILE%"
echo.

echo ============================================================
echo  %RUNTYPE%
echo ============================================================
echo Logging to:
echo  %LOGFILE%
echo.

call :LogEcho "============================================================"
call :LogEcho "%RUNTYPE%"
call :LogEcho "============================================================"
exit /b


:RunCmd
rem %~1 = Display/Log label (the command text shown in summary)
rem %~2 = Actual command to execute
set "CMD_LABEL=%~1"
set "CMD_LINE=%~2"

call :LogEcho ""
call :LogEcho "------------------------------------------------------------"
call :LogEcho "Starting: %CMD_LABEL%"
call :LogEcho "------------------------------------------------------------"

set /a "ATTEMPT=1"
set "CMD_OK=0"

:TRY_AGAIN
call :LogEcho "Attempt !ATTEMPT! of 3 ..."

rem Log the raw command line
>>"%LOGFILE%" echo [COMMAND] %CMD_LINE%

rem Execute command; command output goes to log file, progress stays on screen
cmd /c %CMD_LINE% >>"%LOGFILE%" 2>&1
set "RC=%errorlevel%"

>>"%LOGFILE%" echo [RESULT] ExitCode=!RC!

if "!RC!"=="0" (
    set "CMD_OK=1"
    call :LogEcho "SUCCESS: %CMD_LABEL%"
    >>"%SUCCESS_TMP%" echo %CMD_LABEL%
) else (
    call :LogEcho "FAILED (ExitCode=!RC!): %CMD_LABEL%"
    set /a "ATTEMPT+=1"
    if !ATTEMPT! LEQ 3 (
        call :LogEcho "Retrying..."
        timeout /t 2 >nul
        goto TRY_AGAIN
    ) else (
        call :LogEcho "FAILED AFTER 3 ATTEMPTS: %CMD_LABEL%"
        >>"%FAIL_TMP%" echo %CMD_LABEL%
    )
)

exit /b


:FinalizeRun
call :LogEcho ""
call :LogEcho "============================================================"
call :LogEcho "SUMMARY"
call :LogEcho "============================================================"

call :LogEcho ""
call :LogEcho "Successful commands:"
if exist "%SUCCESS_TMP%" (
    for /f "usebackq delims=" %%S in ("%SUCCESS_TMP%") do (
        call :LogEcho "  - %%S"
    )
) else (
    call :LogEcho "  (none)"
)

call :LogEcho ""
call :LogEcho "Failed commands (after 3 attempts):"
if exist "%FAIL_TMP%" (
    for /f "usebackq delims=" %%F in ("%FAIL_TMP%") do (
        call :LogEcho "  - %%F"
    )
) else (
    call :LogEcho "  (none)"
)

call :LogEcho ""
call :LogEcho "Log file location:"
call :LogEcho "  %LOGFILE%"

call :LogEcho "============================================================"
call :LogEcho "Run complete."
call :LogEcho "============================================================"

rem Cleanup temp summary files
if exist "%SUCCESS_TMP%" del /f /q "%SUCCESS_TMP%" >nul 2>&1
if exist "%FAIL_TMP%" del /f /q "%FAIL_TMP%" >nul 2>&1

echo.
pause
exit /b


:LogEcho
rem Echo to screen AND append to log (if log exists)
echo %~1
if defined LOGFILE (
    >>"%LOGFILE%" echo %~1
)

exit /b

